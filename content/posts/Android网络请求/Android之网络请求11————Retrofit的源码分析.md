---
title: "Android之网络请求11————Retrofit的源码分析"
date: 2019-02-11T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.前言
前两篇文章主要分析了Retrofit的应用，这一篇主要分析的源码。在分析源码的时候，发现了一篇很好的博客，以及一个讲解视频，这里分享给大家
[Retrofit分析-漂亮的解耦套路(视频版) ](http://www.stay4it.com/course/22)
[Android：手把手带你 深入读懂 Retrofit 2.0 源码](https://www.jianshu.com/p/0c055ad46b6c)
### 二.Retrofit的大致流程分析
一般网络请求的过程：
![在这里插入图片描述](/image/Android_jsjwl/6_0.png)

Retrofit和上面本质上是差不多的，只不过Retrofit通过使用大量的设计模式进行功能模块的解耦，使得上面的过程更加简单。

![在这里插入图片描述](/image/Android_jsjwl/6_1.png)

具体过程解释如下：
1. 通过解析网络请求接口的注解 配置网络请求参数
2. 通过动态代理生成网络请求对象
3. 通过网络请求适配器将网络请求对象进行平台适配
4. 通过网络请求执行器发送网络请求
5. 通过数据转换器解析服务器返回的数据
6. 通过回调执行器切换线程(子-->主线程)
7. 用户在主线程处理返回结果
### 三.Retrofit的简单使用
关于Retrofir的使用可以看我之前的博客
[Android之网络请求8————Retrofit的简单使用](https://blog.csdn.net/qq_38499859/article/details/82807496)

### 四.源码分析--创建Retrofit实例
#### 1.使用步骤
```java
     //a.创建Retrofit对象
        Retrofit retrofit = new Retrofit.Builder()
                //指定baseurl
                .baseUrl("https://api.douban.com/v2/movie/")
                //设置内容格式,这种对应的数据返回值是String类型
                .addConverterFactory(GsonConverterFactory.create())
                //创建
                .build();

```
我们在这里简单的创建了一个Retrofit对象，通过链式调用，总共进行了4项。我们一个个来看。

#### 2.Retrofit
先来看Retrofit的构造函数和它所持有的参数
```java
public final class Retrofit {

  //网络请求配置对象的集合。
  //ServiceMethod解析注解
  private final Map<Method, ServiceMethod<?, ?>> serviceMethodCache = new ConcurrentHashMap<>();

   //网络请求器的生产工厂
  final okhttp3.Call.Factory callFactory;
  
  //网络请求的URL对象
  final HttpUrl baseUrl;

  //数据转换器的工厂集合
  final List<Converter.Factory> converterFactories;

  //网络请求适配器的请求工厂集合
  final List<CallAdapter.Factory> callAdapterFactories;

  //回调方法的执行器
  final @Nullable Executor callbackExecutor;

  // 标志位 
  // 作用：是否提前对业务接口中的注解进行验证转换的标志位
  final boolean validateEagerly;

  Retrofit(okhttp3.Call.Factory callFactory, HttpUrl baseUrl,
      List<Converter.Factory> converterFactories, List<CallAdapter.Factory> callAdapterFactories,
      @Nullable Executor callbackExecutor, boolean validateEagerly) {
    this.callFactory = callFactory;
    this.baseUrl = baseUrl;
    this.converterFactories = converterFactories; // Copy+unmodifiable at call site.
    this.callAdapterFactories = callAdapterFactories; // Copy+unmodifiable at call site.
    this.callbackExecutor = callbackExecutor;
    this.validateEagerly = validateEagerly;
  }
}
```

#### 3.Builder()
来继续看Builder方法
```java
public static final class Builder {
    private final Platform platform;
    private @Nullable okhttp3.Call.Factory callFactory;
    private HttpUrl baseUrl;
    private final List<Converter.Factory> converterFactories = new ArrayList<>();
    private final List<CallAdapter.Factory> callAdapterFactories = new ArrayList<>();
    private @Nullable Executor callbackExecutor;
    private boolean validateEagerly;
    .....
 }
```
Builder方法中变量基本和Retrofit中的保持一致，所以Retrofit类的成员变量基本上是通过Builder类进行配置

 被调用的Builder的构造函数
 ```java
     Builder(Platform platform) {
      this.platform = platform;
    }

    public Builder() {
      this(Platform.get());
    }
 ```
 这里可以看出Builder里面设置了默认平台。

查看Platform.get()
```java
class Platform {
  private static final Platform PLATFORM = findPlatform();

  static Platform get() {
    return PLATFORM;
  }

  private static Platform findPlatform() {
    try {
      Class.forName("android.os.Build");
      if (Build.VERSION.SDK_INT != 0) {
         //Android平台
        return new Android(); 
      }
    } catch (ClassNotFoundException ignored) {
    }
    try {
    //Java8
      Class.forName("java.util.Optional");
      return new Java8();
    } catch (ClassNotFoundException ignored) {
    }
    return new Platform();
  }

}
```

继续来看Android（）
```java
 static class Android extends Platform {
    @Override public Executor defaultCallbackExecutor() {
      //默认的回调方法执行器。主要是子线程向主线程切换，并在主线程执行回调方法
      return new MainThreadExecutor();
    }

    @Override CallAdapter.Factory defaultCallAdapterFactory(@Nullable Executor callbackExecutor) {
      if (callbackExecutor == null) throw new AssertionError();
      return new ExecutorCallAdapterFactory(callbackExecutor);  
      //创建默认的网络请求配置工厂
    }

    static class MainThreadExecutor implements Executor {
      //获取与主线程绑定的Handler
      private final Handler handler = new Handler(Looper.getMainLooper());

      @Override public void execute(Runnable r) {
          // 在UI线程进行对网络请求返回数据处理等操作。
        handler.post(r);
      }
    }
  }
```

小结：Builder设置了默认的
* 平台类对象：Android
* 网络请求适配器工厂:CallAdapterFactory
 * 回调执行器：callbackExecutor

#### 4.baseUrl()
```java
public Builder baseUrl(String baseUrl) {
       //判空处理
      checkNotNull(baseUrl, "baseUrl == null");
      //下面分析
      HttpUrl httpUrl = HttpUrl.parse(baseUrl);
      if (httpUrl == null) {
        throw new IllegalArgumentException("Illegal URL: " + baseUrl);
      }
      //下面分析
      return baseUrl(httpUrl);
    }
```

继续来看baseUrl(httpUrl)源码
```java
    public Builder baseUrl(HttpUrl baseUrl) {
      checkNotNull(baseUrl, "baseUrl == null");
      //把URL分成几个路径碎片
      List<String> pathSegments = baseUrl.pathSegments();

      //如果URL不是以/结尾就抛出异常
      if (!"".equals(pathSegments.get(pathSegments.size() - 1))) {
        throw new IllegalArgumentException("baseUrl must end in /: " + baseUrl);
      }
      this.baseUrl = baseUrl;
      return this;
    }
```
小结：
* baseUrl（）用于配置Retrofit类的网络请求url地址

#### 5.addConverterFactory()
继续分析addConverterFactory(GsonConverterFactory.create())语句。首先来看GsonConverterFactory.create()
**a.GsonConverterFactory.create()**
```java
public final class GsonConverterFactory extends Converter.Factory {
  /**
   * Create an instance using a default {@link Gson} instance for conversion. Encoding to JSON and
   * decoding from JSON (when no charset is specified by a header) will use UTF-8.
   */
  public static GsonConverterFactory create() {
    return create(new Gson());
  }

  /**
   * Create an instance using {@code gson} for conversion. Encoding to JSON and
   * decoding from JSON (when no charset is specified by a header) will use UTF-8.
   */
  @SuppressWarnings("ConstantConditions") // Guarding public API nullability.
  public static GsonConverterFactory create(Gson gson) {
    if (gson == null) throw new NullPointerException("gson == null");
    return new GsonConverterFactory(gson);
  }
  private final Gson gson;

  private GsonConverterFactory(Gson gson) {
    this.gson = gson;
  }

}
```
GsonConverterFactory.creat()是创建了一个含有Gson对象实例的GsonConverterFactory，并返回给addConverterFactory（）,继续来看了addConverterFactory（）方法
**b.addConverterFactory（）**
```java
  /** Add converter factory for serialization and deserialization of objects. */
 // 将上面创建的GsonConverterFactory放入到 converterFactories数组
// 在第二步放入一个内置的数据转换器工厂BuiltInConverters(）后又放入了一个GsonConverterFactory
    public Builder addConverterFactory(Converter.Factory factory) {
      converterFactories.add(checkNotNull(factory, "factory == null"));
      return this;
    }
```

总结：这一步中将含有Gson对象实例的GsonConverterFactory并放入到数据转换器工厂converterFactories里

#### 6.build()
```java
  public Retrofit build() {
      if (baseUrl == null) {
        throw new IllegalStateException("Base URL required.");
      }

      //配置call
      //默认使用OkHttp的Call
      okhttp3.Call.Factory callFactory = this.callFactory;
      if (callFactory == null) {
        callFactory = new OkHttpClient();
      }

	  //配置回调方法执行器
	  //如果没有指定，则是使用默认的callbackExecutor
	  //即Android默认的callbackExecutor
      Executor callbackExecutor = this.callbackExecutor;
      if (callbackExecutor == null) {
        callbackExecutor = platform.defaultCallbackExecutor();
      }

      // Make a defensive copy of the adapters and add the default Call adapter.
      //配置网络请求适配器工厂
      List<CallAdapter.Factory> callAdapterFactories = new ArrayList<>(this.callAdapterFactories);
      // 向该集合中添加了步骤2中创建的CallAdapter.Factory请求适配器（添加在集合器末尾）
      callAdapterFactories.add(platform.defaultCallAdapterFactory(callbackExecutor));


      // Make a defensive copy of the converters.
      //配置数据转换器工厂：converterFactory 
      List<Converter.Factory> converterFactories =
          new ArrayList<>(1 + this.converterFactories.size());

      // Add the built-in converter factory first. This prevents overriding its behavior but also
      // ensures correct behavior when using converters that consume all types.
     //首先添加内置的转换器工厂。这可以防止重写它的行为，但是在使用所有类型的转换器时也能确保正确的行为。
      converterFactories.add(new BuiltInConverters());
      converterFactories.addAll(this.converterFactories);

	 // 最终返回一个Retrofit的对象，并传入上述已经配置好的成员变量
      return new Retrofit(callFactory, baseUrl, unmodifiableList(converterFactories),
          unmodifiableList(callAdapterFactories), callbackExecutor, validateEagerly);
    }
```
小结：最后一步中，通过前面步骤设置的变量，将Retrofit类的所有成员变量都配置完毕。

#### 7.总结
在构造Retrofit时，通过建造者模式Builder类，具体创建细节就是配置了：
*  平台类型对象（Platform - Android）
*  网络请求的url地址（baseUrl）
*  网络请求工厂（callFactory）
* 网络请求适配器工厂的集合（adapterFactories）
> 本质是配置了网络请求适配器工厂- 默认是ExecutorCallAdapterFactory
* 数据转换器工厂的集合（converterFactories）
* 回调方法执行器（callbackExecutor）


### 五.源码分析--创建网络请求接口的实例

#### 1.使用步骤
```java
<-- 步骤1：定义接收网络数据的类 -->
<-- JavaBean.java -->
public class JavaBean {
  .. // 这里就不介绍了
  }

<-- 步骤2：定义网络请求的接口类 -->
public interface RetrofitInterface {
    @GET("in_theaters")
    Call<Theaters> theaters(@QueryMap Map<String ,Object>map);
}

<-- 步骤3：在MainActivity创建接口类实例  -->
  RetrofitInterface retrofitInterface = retrofit.create(RetrofitInterface.class);
 ```


直接看retrofit.create的源码
```java
 public <T> T create(final Class<T> service) {
    Utils.validateServiceInterface(service);
    if (validateEagerly) {
     //判断是否需要提前验证
      eagerlyValidateMethods(service);
       // 具体方法作用： 
       // 1. 给接口中每个方法的注解进行解析并得到一个ServiceMethod对象 
       // 2. 以Method为键将该对象存入LinkedHashMap集合中 
       // 特别注意：如果不是提前验证则进行动态解析对应方法（下面会详细说明），得到一个ServiceMethod对象，最后存入到LinkedHashMap集合中，类似延迟加载（默认）
    }


	//创建了网络请求接口的动态代理
	//该动态地理为了拿到网络请求接口实例上的所有注解
    return (T) Proxy.newProxyInstance(
        service.getClassLoader(), //动态实现接口的实现类
        new Class<?>[] { service },//动态创建实例
        new InvocationHandler() {//将代理类的实现交给 InvocationHandler类作为具体的实现
          private final Platform platform = Platform.get();


          // 在 InvocationHandler类的invoke（）实现中，除了执行真正的逻辑（如再次转发给真正的实现类对象），还可以进行一些有用的操作
         // 如统计执行时间、进行初始化和清理、对接口调用进行检查等。
          @Override public Object invoke(Object proxy, Method method, @Nullable Object[] args)
              throws Throwable {
            // If the method is a method from Object then defer to normal invocation.
            if (method.getDeclaringClass() == Object.class) {
              return method.invoke(this, args);
            }
            if (platform.isDefaultMethod(method)) {
              return platform.invokeDefaultMethod(method, service, proxy, args);
            }
            // 作用：读取网络请求接口里的方法，并根据前面配置好的属性配置serviceMethod对象
            //下面详细分析小标题1
            ServiceMethod<Object, Object> serviceMethod =
                (ServiceMethod<Object, Object>) loadServiceMethod(method);

             //作用：根据配置好的serviceMethod对象创建okHttpCall对象 
             //下面分析
            OkHttpCall<Object> okHttpCall = new OkHttpCall<>(serviceMethod, args);

			//作用：调用OkHttp，并根据okHttpCall返回rejava的Observe对象或者返回Call
            return serviceMethod.adapt(okHttpCall);
          }
        });
  }


  //第五行代码代码的内容
  // 将传入的ServiceMethod对象加入LinkedHashMap<Method, ServiceMethod>集合
  // 使用LinkedHashMap集合的好处：lruEntries.values().iterator().next()获取到的是集合最不经常用到的元素，
  //提供了一种Lru算法的实现
  private void eagerlyValidateMethods(Class<?> service) {
    Platform platform = Platform.get();
    for (Method method : service.getDeclaredMethods()) {
      if (!platform.isDefaultMethod(method)) {
        loadServiceMethod(method);
      }
    }
  }
  
```

#### 2.loadServiceMethod
```java
// 一个 ServiceMethod 对象对应于网络请求接口里的一个方法
// loadServiceMethod（method）负责加载 ServiceMethod：
 ServiceMethod<?, ?> loadServiceMethod(Method method) {
    ServiceMethod<?, ?> result = serviceMethodCache.get(method);
    if (result != null) return result;

    synchronized (serviceMethodCache) {
    // ServiceMethod类对象采用了单例模式进行创建
      // 即创建ServiceMethod对象前，先看serviceMethodCache有没有缓存之前创建过的网络请求实例
      // 若没缓存，则通过建造者模式创建 serviceMethod 对象
      result = serviceMethodCache.get(method);
      if (result == null) {
        //下面详细分析ServiceMethod
        result = new ServiceMethod.Builder<>(this, method).build();
        serviceMethodCache.put(method, result);
      }
    }
    return result;
  }
```
我们继续来看ServiceMethod的构造过程

**a.ServiceMethod类 构造函数**
```java
final class ServiceMethod<R, T> {
  // Upper and lower characters, digits, underscores, and hyphens, starting with a character.
  static final String PARAM = "[a-zA-Z][a-zA-Z0-9_-]*";
  static final Pattern PARAM_URL_REGEX = Pattern.compile("\\{(" + PARAM + ")\\}");
  static final Pattern PARAM_NAME_REGEX = Pattern.compile(PARAM);

  private final okhttp3.Call.Factory callFactory; //网络请求工厂
  private final CallAdapter<R, T> callAdapter;//网络请求适配器

  private final HttpUrl baseUrl
  private final Converter<ResponseBody, R> responseConverter;//内容转换器
  private final String httpMethod;//Http的请求方法
  private final String relativeUrl;//网络请求的相对地址
  private final Headers headers;//http的请求头
  private final MediaType contentType;// 网络请求的http报文body的类型

  //这是三个变量是表明请求体的类型
  private final boolean hasBody;  
  private final boolean isFormEncoded;
  private final boolean isMultipart;
 // 方法参数处理器
  // 作用：负责解析 API 定义时每个方法的参数，并在构造 HTTP 请求时设置参数；
  // 下面会详细说明
  private final ParameterHandler<?>[] parameterHandlers;

  ServiceMethod(Builder<R, T> builder) {
    this.callFactory = builder.retrofit.callFactory();
    this.callAdapter = builder.callAdapter;
    this.baseUrl = builder.retrofit.baseUrl();
    this.responseConverter = builder.responseConverter;
    this.httpMethod = builder.httpMethod;
    this.relativeUrl = builder.relativeUrl;
    this.headers = builder.headers;
    this.contentType = builder.contentType;
    this.hasBody = builder.hasBody;
    this.isFormEncoded = builder.isFormEncoded;
    this.isMultipart = builder.isMultipart;
    this.parameterHandlers = builder.parameterHandlers;
  }

}
```
**b.Builder**
```java
Builder(Retrofit retrofit, Method method) {
      this.retrofit = retrofit;
      this.method = method;
      this.methodAnnotations = method.getAnnotations();
      this.parameterTypes = method.getGenericParameterTypes();
      this.parameterAnnotationsArray = method.getParameterAnnotations();
    }
```
**c.build()**
```java
 public ServiceMethod build() {
       // 根据网络请求接口方法的返回值和注解类型，从Retrofit对象中获取对应的网络请求适配器  -->关注点1
      callAdapter = createCallAdapter();
      
      // 根据网络请求接口方法的返回值和注解类型，从Retrofit对象中获取该网络适配器返回的数据类型
      responseType = callAdapter.responseType();
      if (responseType == Response.class || responseType == okhttp3.Response.class) {
        throw methodError("'"
            + Utils.getRawType(responseType).getName()
            + "' is not a valid response body type. Did you mean ResponseBody?");
      }

	 // 根据网络请求接口方法的返回值和注解类型，从Retrofit对象中获取对应的数据转换器 -->关注点3 
	 // 构造 HTTP 请求时，我们传递的参数都是String
	 // Retrofit 类提供 converter把传递的参数都转化为 String
	 // 其余类型的参数都利用 Converter.Factory 的stringConverter 进行转换 
	 // @Body 和 @Part 类型的参数利用Converter.Factory 提供的 requestBodyConverter 进行转换 
	 // 这三种 converter 都是通过“询问”工厂列表进行提供，而工厂列表我们可以在构造 Retrofit 对象时进行添加。
      responseConverter = createResponseConverter();

      // 解析网络请求接口中方法的注解
      // 主要是解析获取Http请求的方法
      // 注解包括：DELETE、GET、POST、HEAD、PATCH、PUT、OPTIONS、HTTP、retrofit2.http.Headers、Multipart、FormUrlEncoded 
      // 处理主要是调用方法 parseHttpMethodAndPath(String httpMethod, String value, boolean hasBody) ServiceMethod中的httpMethod、hasBody、relativeUrl、relativeUrlParamNames域进行赋值
      for (Annotation annotation : methodAnnotations) {
        parseMethodAnnotation(annotation);
      }

      if (httpMethod == null) {
        throw methodError("HTTP method annotation is required (e.g., @GET, @POST, etc.).");
      }

      if (!hasBody) {
        if (isMultipart) {
          throw methodError(
              "Multipart can only be specified on HTTP methods with request body (e.g., @POST).");
        }
        if (isFormEncoded) {
          throw methodError("FormUrlEncoded can only be specified on HTTP methods with "
              + "request body (e.g., @POST).");
        }
      }

     // 获取当前方法的参数数量
      int parameterCount = parameterAnnotationsArray.length;
      parameterHandlers = new ParameterHandler<?>[parameterCount];
      for (int p = 0; p < parameterCount; p++) {
        Type parameterType = parameterTypes[p];
        if (Utils.hasUnresolvableType(parameterType)) {
          throw parameterError(p, "Parameter type must not include a type variable or wildcard: %s",
              parameterType);
        }
        //为方法中的每个参数创建一个ParameterHandler<?>对象并解析每个参数使用的注解类型
        //该对象的创建过程就是对方法参数中注解进行解析
        //这里的注解包括：Body、PartMap、Part、FieldMap、Field、Header、QueryMap、Query、Path、Url 
        Annotation[] parameterAnnotations = parameterAnnotationsArray[p];
        if (parameterAnnotations == null) {
          throw parameterError(p, "No Retrofit annotation found.");
        }

        parameterHandlers[p] = parseParameter(p, parameterType, parameterAnnotations);
      }

      if (relativeUrl == null && !gotUrl) {
        throw methodError("Missing either @%s URL or @Url parameter.", httpMethod);
      }
      if (!isFormEncoded && !isMultipart && !hasBody && gotBody) {
        throw methodError("Non-body HTTP method cannot contain @Body.");
      }
      if (isFormEncoded && !gotField) {
        throw methodError("Form-encoded method must contain at least one @Field.");
      }
      if (isMultipart && !gotPart) {
        throw methodError("Multipart method must contain at least one @Part.");
      }

      return new ServiceMethod<>(this);
    }

```

**关注点1:createCallAdapter()**
```java
private CallAdapter<T, R> createCallAdapter() {

      //获取网络请求接口里方法的返回值类型
      Type returnType = method.getGenericReturnType();
      if (Utils.hasUnresolvableType(returnType)) {
        throw methodError(
            "Method return type must not include a type variable or wildcard: %s", returnType);
      }
      if (returnType == void.class) {
        throw methodError("Service methods cannot return void.");
      }
      
      //获取网络请求接口接口里的注解
      Annotation[] annotations = method.getAnnotations();
      try {
        //noinspection unchecked
		//根据网络请求接口方法的返回值和注解类型，从Retrofit对象中获取对应的网络请求
		//关注点2
        return (CallAdapter<T, R>) retrofit.callAdapter(returnType, annotations);
      } catch (RuntimeException e) { // Wide exception range because factories are user code.
        throw methodError(e, "Unable to create call adapter for %s", returnType);
      }
    }
```
**关注点2:CallAdapter<?>**
```java
  public CallAdapter<?, ?> callAdapter(Type returnType, Annotation[] annotations) {
    return nextCallAdapter(null, returnType, annotations);
  }

  public CallAdapter<?, ?> nextCallAdapter(@Nullable CallAdapter.Factory skipPast, Type returnType,
      Annotation[] annotations) {
    checkNotNull(returnType, "returnType == null");
    checkNotNull(annotations, "annotations == null");

    // 创建 CallAdapter 如下
    // 遍历 CallAdapter.Factory 集合寻找合适的工厂（该工厂集合在第一步构造 Retrofit 对象时进行添加（第一步时已经说明））
    // 如果最终没有工厂提供需要的 CallAdapter，将抛出异常
    int start = callAdapterFactories.indexOf(skipPast) + 1;
    for (int i = start, count = callAdapterFactories.size(); i < count; i++) {
      CallAdapter<?, ?> adapter = callAdapterFactories.get(i).get(returnType, annotations, this);
      if (adapter != null) {
        return adapter;
      }
    }


    //没有找到抛出异常
    StringBuilder builder = new StringBuilder("Could not locate call adapter for ")
        .append(returnType)
        .append(".\n");
    if (skipPast != null) {
      builder.append("  Skipped:");
      for (int i = 0; i < start; i++) {
        builder.append("\n   * ").append(callAdapterFactories.get(i).getClass().getName());
      }
      builder.append('\n');
    }
    builder.append("  Tried:");
    for (int i = start, count = callAdapterFactories.size(); i < count; i++) {
      builder.append("\n   * ").append(callAdapterFactories.get(i).getClass().getName());
    }
    throw new IllegalArgumentException(builder.toString());
  }
```
**关注点3：createResponseConverter（）**
```java
    private Converter<ResponseBody, T> createResponseConverter() {
      Annotation[] annotations = method.getAnnotations();
      try {
        // responseConverter 还是由 Retrofit 类提供  -->关注点4
        return retrofit.responseBodyConverter(responseType, annotations);
      } catch (RuntimeException e) { // Wide exception range because factories are user code.
        throw methodError(e, "Unable to create converter for %s", responseType);
      }
    }
```
**关注点4：responseBodyConverter()**
```java
 public <T> Converter<ResponseBody, T> responseBodyConverter(Type type, Annotation[] annotations) {
    return nextResponseBodyConverter(null, type, annotations);
  }
public <T> Converter<ResponseBody, T> nextResponseBodyConverter(
      @Nullable Converter.Factory skipPast, Type type, Annotation[] annotations) {
    checkNotNull(type, "type == null");
    checkNotNull(annotations, "annotations == null");

    int start = converterFactories.indexOf(skipPast) + 1;
    for (int i = start, count = converterFactories.size(); i < count; i++) {
      
      // 获取Converter 过程：（和获取 callAdapter 基本一致）
      Converter<ResponseBody, ?> converter =
          converterFactories.get(i).responseBodyConverter(type, annotations, this);
      if (converter != null) {
        //noinspection unchecked
        return (Converter<ResponseBody, T>) converter;
         // 遍历 Converter.Factory 集合并寻找合适的工厂（该工厂集合在构造 Retrofit 对象时进行添加（第一步时已经说明））
         // 由于构造Retroifit采用的是Gson解析方式，所以取出的是GsonResponseBodyConverter 
         // Retrofit - Converters 还提供了 JSON，XML，ProtoBuf 等类型数据的转换功能。 
         // 继续看responseBodyConverter（） -->关注点5

      }
    }

   //抛出异常
    StringBuilder builder = new StringBuilder("Could not locate ResponseBody converter for ")
        .append(type)
        .append(".\n");
    if (skipPast != null) {
      builder.append("  Skipped:");
      for (int i = 0; i < start; i++) {
        builder.append("\n   * ").append(converterFactories.get(i).getClass().getName());
      }
      builder.append('\n');
    }
    builder.append("  Tried:");
    for (int i = start, count = converterFactories.size(); i < count; i++) {
      builder.append("\n   * ").append(converterFactories.get(i).getClass().getName());
    }
    throw new IllegalArgumentException(builder.toString());
  }

```

* 关注点5：responseBodyConverter（）**

查看 GsonConverterFactory的实现类
```java

  @Override
  public Converter<ResponseBody, ?> responseBodyConverter(Type type, Annotation[] annotations,
      Retrofit retrofit) {
    TypeAdapter<?> adapter = gson.getAdapter(TypeToken.get(type));
    return new GsonResponseBodyConverter<>(gson, adapter);
  }

```
 做数据转换时调用 Gson 的 API 即可。
```java

final class GsonResponseBodyConverter<T> implements Converter<ResponseBody, T> {
  private final Gson gson;
  private final TypeAdapter<T> adapter;

  GsonResponseBodyConverter(Gson gson, TypeAdapter<T> adapter) {
    this.gson = gson;
    this.adapter = adapter;
  }

  @Override public T convert(ResponseBody value) throws IOException {
    JsonReader jsonReader = gson.newJsonReader(value.charStream());
    try {
      T result = adapter.read(jsonReader);
      if (jsonReader.peek() != JsonToken.END_DOCUMENT) {
        throw new JsonIOException("JSON document was not fully consumed.");
      }
      return result;
    } finally {
      value.close();
    }
  }
}

```
#### 3.  new OkHttpCall
回到Retrofit的 create函数中，查看 OkHttpCall<Object> okHttpCall = new OkHttpCall<>(serviceMethod, args);的内容
```java

final class OkHttpCall<T> implements Call<T> {
  private final ServiceMethod<T, ?> serviceMethod; //含有所有请求参数信息的对象
  private final @Nullable Object[] args;//网络请求接口的参数

  private volatile boolean canceled;

  @GuardedBy("this")
  private @Nullable okhttp3.Call rawCall;
  @GuardedBy("this") // Either a RuntimeException, non-fatal Error, or IOException.
  private @Nullable Throwable creationFailure;//几个状态标记位
  @GuardedBy("this")
  private boolean executed;

  OkHttpCall(ServiceMethod<T, ?> serviceMethod, @Nullable Object[] args) {
    this.serviceMethod = serviceMethod;
    this.args = args;
  }
}
```
#### 4.serviceMethod.adapt(okHttpCall);
回到Retrofit的 create函数中，return serviceMethod.adapt(okHttpCall);中的内容

将第二步创建的OkHttpCall对象传给第一步创建的serviceMethod对象中对应的网络请求适配器工厂的adapt（）
**adapt（）详解**
```java
  T adapt(Call<R> call) {
    return callAdapter.adapt(call);
  }
```
在这里调用了callAdapter的.adapt, Android默认的是Call<>；若设置了RxJavaCallAdapterFactory，返回的则是Observable<>
android默认：
```java
@Override public Call<Object> adapt(Call<Object> call) {
        return new ExecutorCallbackCall<>(callbackExecutor, call);
      }

ExecutorCallbackCall(Executor callbackExecutor, Call<T> delegate) {
      //传入上面定义的回调方法执行器
      this.callbackExecutor = callbackExecutor;

      //把上面创建并配置好参数的OkhttpCall对象交给静态代理delegate
      this.delegate = delegate;
    }
```
Rxjava
```java
@Override public <R> Object adapt(Call<R> call) {
    Observable<Response<R>> responseObservable = new CallObservable<>(call);

    Observable<?> observable;
    if (isResult) {
      observable = new ResultObservable<>(responseObservable);
    } else if (isBody) {
      observable = new BodyObservable<>(responseObservable);
    } else {
      observable = responseObservable;
    }

    if (scheduler != null) {
      observable = observable.subscribeOn(scheduler);
    }

    if (isFlowable) {
      return observable.toFlowable(BackpressureStrategy.LATEST);
    }
    if (isSingle) {
      return observable.singleOrError();
    }
    if (isMaybe) {
      return observable.singleElement();
    }
    if (isCompletable) {
      return observable.ignoreElements();
    }
    return observable;
  }
```
### 六.源码分析--生成Call对象
#### 1.使用步骤
```java
 Call<JavaBean> call = NetService.getCall();
```
#### 2.讲解
* NetService对象实际上是动态代理对象Proxy.newProxyInstance（）（步骤3中已说明），并不是真正的网络请求接口创建的对象
* 当NetService对象调用getCall（）时会被动态代理对象Proxy.newProxyInstance（）拦截，然后调用自身的InvocationHandler # invoke（）
* invoke(Object proxy, Method method, Object... args)会传入3个参数：Object proxy:（代理对象），Method method（调用的getCall()），Object... args（方法的参数，即getCall（*）中的*）
* 接下来利用Java反射获取到getCall（）的注解信息，配合args参数创建ServiceMethod对象。
* 最终通过getCall获得的是invoke的返回值。


### 七.源码分析--执行网络请求
Retrofit默认使用OkHttp，即OkHttpCall类（实现了 retrofit2.Call<T>接口）
 OkHttpCall提供了两种网络请求方式：
*  同步请求：OkHttpCall.execute()
* 异步请求：OkHttpCall.enqueue()
> 对于OkHttpCall的enqueue（）、execute（）的源码，有兴趣可以看看我前面的博客关于OKHttp的源码的文章

#### 1.同步请求
```java
Response<JavaBean> response = call.execute();  
```
此时call是ExecutorCallbackCall类型，来看其execute()实现
```java
 @Override public Response<T> execute() throws IOException {
      return delegate.execute();
    }
```
delegete是OkHttpCall类型的，来看其实现
```java
@Override public Response<T> execute() throws IOException {
    okhttp3.Call call;

    synchronized (this) {
      if (executed) throw new IllegalStateException("Already executed.");
      executed = true;

      if (creationFailure != null) {
        if (creationFailure instanceof IOException) {
          throw (IOException) creationFailure;
        } else if (creationFailure instanceof RuntimeException) {
          throw (RuntimeException) creationFailure;
        } else {
          throw (Error) creationFailure;
        }
      }

      call = rawCall;
      if (call == null) {
        try {
        // 步骤1：创建一个OkHttp的Request对象请求 -->关注1
          call = rawCall = createRawCall();
        } catch (IOException | RuntimeException | Error e) {
          throwIfFatal(e); //  Do not assign a fatal error to creationFailure.
          creationFailure = e;
          throw e;
        }
      }
    }

    if (canceled) {
      call.cancel();
    }
     // 步骤2：调用OkHttpCall的execute()发送网络请求（同步）
    // 步骤3：解析网络请求返回的数据parseResponse（） -->关注2
    return parseResponse(call.execute());
  }
```
**关注1**
```java
 private okhttp3.Call createRawCall() throws IOException {
    // 根据serviceMethod和request对象创建 一个okhttp3.Request
    okhttp3.Call call = serviceMethod.toCall(args);
    if (call == null) {
      throw new NullPointerException("Call.Factory returned null.");
    }
    return call;
  }
```
**关注2**
```java
  Response<T> parseResponse(okhttp3.Response rawResponse) throws IOException {
    ResponseBody rawBody = rawResponse.body();

    // Remove the body's source (the only stateful object) so we can pass the response along.
    rawResponse = rawResponse.newBuilder()
        .body(new NoContentResponseBody(rawBody.contentType(), rawBody.contentLength()))
        .build();

    int code = rawResponse.code();
     //检查返回码
    if (code < 200 || code >= 300) {
      try {
        // Buffer the entire body to avoid future I/O.
        ResponseBody bufferedBody = Utils.buffer(rawBody);
        return Response.error(bufferedBody, rawResponse);
      } finally {
        rawBody.close();
      }
    }

    if (code == 204 || code == 205) {
      rawBody.close();
      return Response.success(null, rawResponse);
    }

    ExceptionCatchingRequestBody catchingBody = new ExceptionCatchingRequestBody(rawBody);
    try {
      
      /// 等Http请求返回后 & 通过状态码检查后，将response body传入ServiceMethod中，
      //ServiceMethod通过调用Converter接口（之前设置的GsonConverterFactory）
      //将response body转成一个Java对象，即解析返回的数据
      T body = serviceMethod.toResponse(catchingBody);
      return Response.success(body, rawResponse);
    } catch (RuntimeException e) {
      // If the underlying source threw an exception, propagate that rather than indicating it was
      // a runtime exception.
      catchingBody.throwIfCaught();
      throw e;
    }
  }
```

注意：

* ServiceMethod几乎保存了一个网络请求所需要的数据
*    发送网络请求时，OkHttpCall需要从ServiceMethod中获得一个Request对象
*  解析数据时，还需要通过ServiceMethod使用Converter（数据转换器）转换成Java对象进行数据解析

>为了提高效率，Retrofit还会对解析过的请求ServiceMethod进行缓存，存放在Map<Method, ServiceMethod> serviceMethodCache = new LinkedHashMap<>();对象中，即第二步提到的单例模式
#### 2.异步请求
使用步骤
```java
 call.enqueue(new Callback<Theaters>() {
            //请求成功时回调
            @Override
            public void onResponse(Call<Theaters> call, Response<Theaters> response) {
            
                response.body().show();
            }

            //请求失败时回调
            @Override
            public void onFailure(Call<Theaters> call, Throwable throwable) {
                Log.e("retrofit", "onFailure: " + throwable);
            }
        });
```
同上面一样，此次的call是ExecutorCallbackCall类型，来看其execute()实现
```java
@Override public void enqueue(final Callback<T> callback) {
      checkNotNull(callback, "callback == null");

      delegate.enqueue(new Callback<T>() {
        @Override public void onResponse(Call<T> call, final Response<T> response) {
          //切换线程。从而在主线程中显示结果
          callbackExecutor.execute(new Runnable() {
          // 最后Okhttp的异步请求结果返回到callbackExecutor
          // callbackExecutor.execute（）通过Handler异步回调将结果传回到主线程进行处理
          //（如显示在Activity等等），即进行了线程切换
            @Override public void run() {
              if (delegate.isCanceled()) {
                // Emulate OkHttp's behavior of throwing/delivering an IOException on cancellation.
                callback.onFailure(ExecutorCallbackCall.this, new IOException("Canceled"));
              } else {
                callback.onResponse(ExecutorCallbackCall.this, response);
              }
            }
          });
        }

        @Override public void onFailure(Call<T> call, final Throwable t) {
          callbackExecutor.execute(new Runnable() {
            @Override public void run() {
              callback.onFailure(ExecutorCallbackCall.this, t);
            }
          });
        }
      });
    }
```

此处的delegate是OkHttpCall类型，来继续看enqueue的实现
```java
@Override public void enqueue(final Callback<T> callback) {
    checkNotNull(callback, "callback == null");

    okhttp3.Call call;
    Throwable failure;
  
// 步骤1：创建OkHttp的Request对象，再封装成OkHttp.call
     // delegate代理在网络请求前的动作：创建OkHttp的Request对象，再封装成OkHttp.call
    synchronized (this) {
      if (executed) throw new IllegalStateException("Already executed.");
      executed = true;

      call = rawCall;
      failure = creationFailure;
      if (call == null && failure == null) {
        try {
        // 创建OkHttp的Request对象，再封装成OkHttp.call
         // 方法同发送同步请
          call = rawCall = createRawCall();
        } catch (Throwable t) {
          throwIfFatal(t);
          failure = creationFailure = t;
        }
      }
    }

    if (failure != null) {
      callback.onFailure(this, failure);
      return;
    }

    if (canceled) {
      call.cancel();
    }

// 步骤2：发送网络请求
    // delegate是OkHttpcall的静态代理
    // delegate静态代理最终还是调用Okhttp.enqueue进行网络请求
    call.enqueue(new okhttp3.Callback() {
      @Override public void onResponse(okhttp3.Call call, okhttp3.Response rawResponse) {
        Response<T> response;
        try {

          //解析数据
          response = parseResponse(rawResponse);
        } catch (Throwable e) {
          callFailure(e);
          return;
        }

        try {
          callback.onResponse(OkHttpCall.this, response);
        } catch (Throwable t) {
          t.printStackTrace();
        }
      }

      @Override public void onFailure(okhttp3.Call call, IOException e) {
        callFailure(e);
      }

      private void callFailure(Throwable e) {
        try {
          callback.onFailure(OkHttpCall.this, e);
        } catch (Throwable t) {
          t.printStackTrace();
        }
      }
    });
  }

```

那么enqueue是在什么时候继续线程切换的？
线程切换是通过一开始创建Retrofit对象时Platform在检测到运行环境是Android时进行创建的，在前面也进行了分析
```java
static class Android extends Platform {
    @Override public Executor defaultCallbackExecutor() {
     // 返回一个默认的回调方法执行器
      // 该执行器负责在主线程（UI线程）中执行回调方法
      return new MainThreadExecutor();
    }

    // 创建默认的回调执行器工厂
    // 如果不将RxJava和Retrofit一起使用，一般都是使用该默认的CallAdapter.Factory
    @Override CallAdapter.Factory defaultCallAdapterFactory(@Nullable Executor callbackExecutor) {
      if (callbackExecutor == null) throw new AssertionError();
      return new ExecutorCallAdapterFactory(callbackExecutor);
    }

  // 获取主线程Handler
    static class MainThreadExecutor implements Executor {
      private final Handler handler = new Handler(Looper.getMainLooper());

      @Override public void execute(Runnable r) {
       // Retrofit获取了主线程的handler
        // 然后在UI线程执行网络请求回调后的数据显示等操作。
        handler.post(r);
      }
    }
  }
// 切换线程的流程：
 // 1. 回调ExecutorCallAdapterFactory生成了一个ExecutorCallbackCall对象
  // 2. 通过调用ExecutorCallbackCall.enqueue(CallBack)从而调用MainThreadExecutor的execute()通过handler切换到主线程处理返回结果（如显示在Activity等等）


```
### 八.Retrofit源码总结+流程图

#### 1.总结
Retrofit本质是一个一个 RESTful 的HTTP 网络请求框架的封装，即通过 大量的设计模式 封装了 OkHttp ，使得简洁易用。具体过程如下：
* Retrofit将Http请求抽象成java接口
* 在接口里用注解描述和配置网络请求参数
* 用动态代理的方式，动态将网络请求的注解解析成HTTP请求
* 最后执行HTTP请求

#### 2.源码分析图
![在这里插入图片描述](/image/Android_jsjwl/6_2.png)


#### 3.流程图
![在这里插入图片描述](/image/Android_jsjwl/6_3.png)
### 九.参考资料
[Retrofit分析-漂亮的解耦套路(视频版) ](http://www.stay4it.com/course/22)
[Android：手把手带你 深入读懂 Retrofit 2.0 源码](https://www.jianshu.com/p/0c055ad46b6c)

### 十.文章索引
[Android之网络请求1————HTTP协议](https://blog.csdn.net/qq_38499859/article/details/82153094)
[Android之网络请求2————OkHttp的基本使用](https://blog.csdn.net/qq_38499859/article/details/82290738)
[Android之网络请求3————OkHttp的拦截器和封装](https://blog.csdn.net/qq_38499859/article/details/82355954)
[Android之网络请求4————OkHttp源码1:框架](https://blog.csdn.net/qq_38499859/article/details/82469295)
[Android之网络请求5————OkHttp源码2:发送请求](https://blog.csdn.net/qq_38499859/article/details/82561675)
[Android之网络请求6————OkHttp源码3:拦截器链](https://blog.csdn.net/qq_38499859/article/details/82630630)
[Android之网络请求7————OkHttp源码4:网络操作](https://blog.csdn.net/qq_38499859/article/details/82745671)
[Android之网络请求8————OkHttp源码5:缓存相关](https://blog.csdn.net/qq_38499859/article/details/82778955)
[Android之网络请求9————Retrofit的简单使用](https://blog.csdn.net/qq_38499859/article/details/82807496)
[Android之网络请求10————Retrofit的进阶使用](https://blog.csdn.net/qq_38499859/article/details/83010604)
[Android之网络请求11————Retrofit的源码分析](https://blog.csdn.net/qq_38499859/article/details/83042782)
