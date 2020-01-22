---
title: "Android之网络请求8————Retrofit的简单使用"
date: 2019-02-09T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.Retrofit的介绍
Retreofit是什么，根据其官方文档的介绍，他就是一个适用于 Android 和 Java 的类型安全的 HTTP 客户端。特别说明Retrofit网络请求本质是有OkHttp完成的，而Retrofit仅负责网络请求接口的封装。


![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL3VwbG9hZC1pbWFnZXMuamlhbnNodS5pby91cGxvYWRfaW1hZ2VzLzk0NDM2NS1hMzEwOWFkMDQ0NmIwNTQwLnBuZw?x-oss-process=image/format,png)
### 二.Retrofit的简单使用
Retrofit的简单使用我们先从请求百度URL开始
**步骤1：**
添加第三方库依赖
```java
    compile 'com.squareup.retrofit2:retrofit:2.4.0'
    compile 'com.squareup.retrofit2:converter-scalars:2.3.0'
```

**步骤2：**
添加权限
```java
   <uses-permission android:name="android.permission.INTERNET"/>
```

**步骤3:**
创建用于描述请求的接口
```java
public interface BaiduInterface {
    //@GET指定请求方法,
    
    @GET
    Call<String> baidu(@Url String url);
}
```
**步骤4:**
进行请求
```java
        //a.创建Retrofit对象
        Retrofit retrofit = new Retrofit.Builder()
                //指定baseurl，这里有坑，最后后缀出带着“/”
                .baseUrl("http://www.baidu.com/")
                //设置内容格式,这种对应的数据返回值是String类型
                .addConverterFactory(ScalarsConverterFactory.create())
                //定义client类型
                .client(new OkHttpClient())
                //创建
                .build();


        //b,获得定义的接口的实例
        BaiduInterface baiduInterface = retrofit.create(BaiduInterface.class);

        //配置参数
        Call<String> baidu = baiduInterface.baidu("http://www.baidu.com");

        //c.执行异步请求
        baidu.enqueue(new Callback<String>() {
            @Override
            public void onResponse(Call<String> call, Response<String> response) {
                Log.d("1111", "onResponse: "+response.body());
            }
            @Override
            public void onFailure(Call<String> call, Throwable t) {
                Log.d("1111", "onResponse: "+t);
            }
        });
```

请求结果:
![在这里插入图片描述](https://img-blog.csdn.net/20180926213646477)
### 三.Retrofit的注解
上面我们简单使用了Retrofit请求了百度的。对Retrofit的使用有了简单的了解，在上面的代码中，出现了@GET和@URL，可以看出Retrofit大量使用了注解，对请求进行了封装，我们继续来看Retrofit中使用的注解。

#### 1.概述
在Retrofit中，注解的使用都在定义的接口中，分为3类:即网络请求方法，标记类，网络请求参数。
![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL3VwbG9hZC1pbWFnZXMuamlhbnNodS5pby91cGxvYWRfaW1hZ2VzLzk0NDM2NS1lZTc0N2QxZTMzMWVkNWE0LnBuZw?x-oss-process=image/format,png)
#### 2.网络请求方法
网络请求方法如下:
![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL3VwbG9hZC1pbWFnZXMuamlhbnNodS5pby91cGxvYWRfaW1hZ2VzLzk0NDM2NS1lOTczNzliOGUwOTQyNDU5LnBuZw?x-oss-process=image/format,png)
可以看出来这些都是Http的方法，我们一般常用的就是GET和POST

具体说明:
**a. @GET、@POST、@PUT、@DELETE、@HEAD**
以上方法分别对应 HTTP中的网络请求方式

每个注解后面都可以设置一个URL，也可以不设置
```java

public interface RetrofitInterface {
    @GET("https://www.baidu.com")
    Call<String> baidu();
    //@GE作用:采用Get方法发送请求
    //Call<String> String是请求返回数据的格式，可以是String,也可以是json，也可是GSON。
    //baidu() 即进行请求的方法
    //关于URL部分，在下面有教详细的讲解
}
```
**b.@HTTP**
作用:替换@GET、@POST、@PUT、@DELETE、@HEAD注解的作用 及 更多功能拓展
具体使用：通过属性method、path、hasBody进行设置
```java
public interface RetrofitInterface {
   /**
     * method：网络请求的方法（区分大小写）
     * path：网络请求地址路径
     * hasBody：是否有请求体
     */
    @HTTP(method = "GET", path ="https://www.baidu.com", hasBody = false)
    Call<ResponseBody> getCall(@Path("id") int id);
    // method 的值 retrofit 不会做处理，所以要自行保证准确
}

```
**c.关于URL**
Retrofit将URL分为两部分，一部分在请求接口的注解后，一部分在Retrofit的baseUrl中。即
```java
// 第1部分：在网络请求接口的注解设置
 @GET("openapi.do?keyfrom=Yanzhikai&key=2032414398&type=data&doctype=json&version=1.1&q=car")
Call<Translation>  getCall();

// 第2部分：在创建Retrofit实例时通过.baseUrl()设置
Retrofit retrofit = new Retrofit.Builder()
                .baseUrl("http://fanyi.youdao.com/") //设置网络请求的Url地址
                .addConverterFactory(GsonConverterFactory.create()) //设置数据解析器
                .build();
```
网络请求的完整 Url =在创建Retrofit实例时通过.baseUrl()设置 +网络请求接口的注解设置（下面称 “path“ ） 
具体整合规则
![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL3VwbG9hZC1pbWFnZXMuamlhbnNodS5pby91cGxvYWRfaW1hZ2VzLzk0NDM2NS0zZGM0MjAxNzAzODMwMmQzLnBuZw?x-oss-process=image/format,png)

path的URL还可以使用替换块
```java
@GET("group/{id}/users")
Call<List<User>> groupList(@Path("id") int groupId);
```

同时网络请求参数@URL也可以设置URL
```java
public interface RetrofitInterface {
    @GET
    Call<String> baidu(@Url String url);
}
```
#### 3.标记类
![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL3VwbG9hZC1pbWFnZXMuamlhbnNodS5pby91cGxvYWRfaW1hZ2VzLzk0NDM2NS1hNmYxZmM5OTdjMjNhMmUwLnBuZw?x-oss-process=image/format,png)
**a.FormUrlEncoded**
* 作用:表示发送form-encoded的数据
* 注意:每个键值对都需要用@Filed来注解键名，随后的对象需要提供值。

定义接口方法
```java
public interface RetrofitInterface {
    /**
     *表明是一个表单格式的请求（Content-Type:application/x-www-form-urlencoded）
     * <code>Field("username")</code> 表示将后面的 <code>String name</code> 中name的取值作为 username 的值
     */
    @POST("/form")
    @FormUrlEncoded
    Call<ResponseBody> testFormUrlEncoded1(@Field("username") String name, @Field("age") int age);

}
```
**b.Multipart**
* 作用:表示发送form-encoded的数据（适用于 有文件 上传的场景） 
* 注意:每个键值对都需要用@part来注解键名，随后对象需要提供值
```java
public interface RetrofitInterface {
    /**
     * {@link Part} 后面支持三种类型，{@link RequestBody}、{@link okhttp3.MultipartBody.Part} 、任意类型
     * 除 {@link okhttp3.MultipartBody.Part} 以外，
     * 其它类型都必须带上表单字段({@link okhttp3.MultipartBody.Part} 中已经包含了表单字段的信息)，
     */
    @POST("/form")
    @Multipart
    Call<ResponseBody> testFileUpload1(@Part("name") RequestBody name, @Part("age") RequestBody age, @Part MultipartBody.Part file);
}

```
**c.@Streaming**
* 作用:表示返回的数据以流的形式返回，场用于大文件传输的场景
* 注意:url由于是可变的，因此用 @URL 注解符号来进行指定，大文件官方建议用 @Streaming 来进行注解，不然会出现IO异常，小文件可以忽略不注入。如果想进行断点续传的话 可以在此加入header
```java
public interface ApiService {
  @Streaming
  @GET
  Observable<ResponseBody> downloadFile(@Url String   fileUrl);
}
```
#### 4.网络请求参数
![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL3VwbG9hZC1pbWFnZXMuamlhbnNodS5pby91cGxvYWRfaW1hZ2VzLzk0NDM2NS1jNTQ3ZjIzNDRlZWY2MzBiLnBuZw?x-oss-process=image/format,png)

**a.@Header & @Headers**
* 作用:添加请求头
具体使用:
```java
// @Header
@GET("user")
Call<User> getUser(@Header("Authorization") String authorization)

// @Headers
@Headers("Authorization: authorization")
@GET("user")
Call<User> getUser()

// 以上的效果是一致的。
// 区别在于使用场景和使用方式
// 1. 使用场景：@Header用于添加不固定的请求头，@Headers用于添加固定的请求头
// 2. 使用方式：@Header作用于方法的参数；@Headers作用于方法
```
**b.@Body**
* 作用：以Post方式传递自定义数据类型给服务器
* 注意: 如果提交的是一个Map，那么作用相当于@Field，不过Map要经过FormBody.Builder 类处理成为符合 Okhttp 格式的表单，如：
```java
FormBody.Builder builder = new FormBody.Builder();
builder.add("key","value");
```

**c.Field&FieldMap**
* 作用：发送 Post请求 时提交请求的表单字段
* 注意：与 @FormUrlEncoded 注解配合使用
Field的使用
```java
public interface RetrofitInterface {
    /**
     *表明是一个表单格式的请求（Content-Type:application/x-www-form-urlencoded）
     * <code>Field("username")</code> 表示将后面的 <code>String name</code> 中name的取值作为 username 的值
     */
    @POST("/form")
    @FormUrlEncoded
    Call<ResponseBody> testFormUrlEncoded1(@Field("username") String name, @Field("age") int age)；
}

//具体使用
 Call<ResponseBody> call1 = service.testFormUrlEncoded1("Carson", 24);
```

FieldMap的使用
```java
public interface RetrofitInterface {
    /**
     *表明是一个表单格式的请求（Content-Type:application/x-www-form-urlencoded）
     * <code>Field("username")</code> 表示将后面的 <code>String name</code> 中name的取值作为 username 的值
     */
    @POST("/form")
    @FormUrlEncoded
    Call<ResponseBody>testFormUrlEncoded2(@FieldMap Map<String, Object> map);
}

//具体使用
   Map<String, Object> map = new HashMap<>();
   map.put("username", "Carson");
   map.put("age", 24);
   Call<ResponseBody> call2 = service.testFormUrlEncoded2(map);
```

**d.@Part & @PartMap**
* 作用:发送的Post请求时提交的表单字段
* 注意:与 @Multipart 注解配合使用
* 与@Field的区别：功能相同，但携带的参数类型更加丰富，包括数据流，所以适用于 有文件上传 的场景

@Part的使用
```java
public interface RetrofitInterface {
        /**
         * {@link Part} 后面支持三种类型，{@link RequestBody}、{@link okhttp3.MultipartBody.Part} 、任意类型
         * 除 {@link okhttp3.MultipartBody.Part} 以外，其它类型都必须带上表单字段({@link okhttp3.MultipartBody.Part} 中已经包含了表单字段的信息)，
         */
        @POST("/form")
        @Multipart
        Call<ResponseBody> testFileUpload1(@Part("name") RequestBody name, @Part("age") RequestBody age, @Part MultipartBody.Part file);
}


        MediaType textType = MediaType.parse("text/plain");
        RequestBody name = RequestBody.create(textType, "Carson");
        RequestBody age = RequestBody.create(textType, "24");
        RequestBody file = RequestBody.create(MediaType.parse("application/octet-stream"), "这里是模拟文件的内容");
//调用
        MultipartBody.Part filePart = MultipartBody.Part.createFormData("file", "test.txt", file);
        Call<ResponseBody> call3 = service.testFileUpload1(name, age, filePart);
        ResponseBodyPrinter.printResponseBody(call3);
```

@PartMap的使用
```java
public interface RetrofitInterface {
   
        /**
         * PartMap 注解支持一个Map作为参数，支持 {@link RequestBody } 类型，
         * 如果有其它的类型，会被{@link retrofit2.Converter}转换，如后面会介绍的 使用{@link com.google.gson.Gson} 的 {@link retrofit2.converter.gson.GsonRequestBodyConverter}
         * 所以{@link MultipartBody.Part} 就不适用了,所以文件只能用<b> @Part MultipartBody.Part </b>
         */
        @POST("/form")
        @Multipart
        Call<ResponseBody> testFileUpload2(@PartMap Map<String, RequestBody> args, @Part MultipartBody.Part file);
}


        MediaType textType = MediaType.parse("text/plain");
        RequestBody name = RequestBody.create(textType, "Carson");
        RequestBody age = RequestBody.create(textType, "24");
        RequestBody file = RequestBody.create(MediaType.parse("application/octet-stream"), "这里是模拟文件的内容");
//调用
        Map<String, RequestBody> fileUpload2Args = new HashMap<>();
        fileUpload2Args.put("name", name);
        fileUpload2Args.put("age", age);
        //这里并不会被当成文件，因为没有文件名(包含在Content-Disposition请求头中)，但上面的 filePart 有
        //fileUpload2Args.put("file", file);
        Call<ResponseBody> call4 = service.testFileUpload2(fileUpload2Args, filePart); //单独处理文件
        ResponseBodyPrinter.printResponseBody(call4);
```

**e.@Query和@QueryMap**
* 作用：用于 @GET 方法的查询参数（Query = Url 中 ‘?’ 后面的 key-value）
* 使用：和上面的两个相同

**f. @Path**
* 作用:URL的省缺值
```java
@GET("group/{id}/users")
Call<List<User>> groupList(@Path("id") int groupId);
```

**g.@Url**
* 作用:直接传入一个请求的URL变量
* 具体使用
```java
public interface RetrofitInterface {
    @GET
    Call<String> baidu(@Url String url);
}
```
### 四.Retrofit的数据解析器和网络请求适配器
在上面的请求百度的例子中，我们使用了ScalarsConverterFactory.create()作为数据的解析器，同时Retrofit也支持多种网络请求适配器方式，比如：guava、Java8和rxjava 

数据解析器和网络请求的适配器的添加发生在创建 Retrofit 实例
```java
Retrofit retrofit = new Retrofit.Builder()
                .addConverterFactory(GsonConverterFactory.create()) // 设置数据解析器
                .addCallAdapterFactory(RxJavaCallAdapterFactory.create()) // 支持RxJava平台
                .build();
```

#### 1.数据解析器
Retrofit支持多种数据解析器，如下:
| 数据解析器 |Gradle依赖  |
|:--------:| -------------|
|Gson 	|com.squareup.retrofit2:converter-gson:2.0.2|
|Jackson 	|com.squareup.retrofit2:converter-jackson:2.0.2|
|Simple XML| 	com.squareup.retrofit2:converter-simplexml:2.0.2|
|Protobuf 	|com.squareup.retrofit2:converter-protobuf:2.0.2|
|Moshi 	|com.squareup.retrofit2:converter-moshi:2.0.2|
|Wire 	|com.squareup.retrofit2:converter-wire:2.0.2|
|Scalars 	|com.squareup.retrofit2:converter-scalars:2.0.2|

#### 2.网络请求适配器
Retrofit支持多种网络请求适配器方式：guava、Java8和rxjava.
使用时如使用的是 Android 默认的 CallAdapter，则不需要添加网络请求适配器的依赖
需要在Gradle添加依赖:
| 网络请求适配器|Gradle依赖 |
|:--------:| -------------|
|guava 	|com.squareup.retrofit2:adapter-guava:2.0.2|
|Java8 |	com.squareup.retrofit2:adapter-java8:2.0.2|
|rxjava| 	com.squareup.retrofit2:adapter-rxjava:2.0.2|


### 五.Retrofit和GSON
以豆瓣电影上映接口的请求为例:
[API接口](https://github.com/jokermonn/-Api/blob/master/DoubanMovie.md#photo)
请求URL:
![在这里插入图片描述](https://img-blog.csdn.net/20180927115344570)
返回的JSON数据（详细内容可查看链接）:
![在这里插入图片描述](https://img-blog.csdn.net/20180927115534608)
具体实现:
#### 1.步骤a：添加Retrofit库的依赖
添加Retrofit和GSON的依赖
```java
    compile 'com.squareup.retrofit2:retrofit:2.4.0'
    compile 'com.squareup.retrofit2:converter-gson:2.4.0'
```

添加权限
```java
   <uses-permission android:name="android.permission.INTERNET"/>
```
#### 2.步骤b：创建 接收服务器返回数据 的类
这里只接收了部分数据
```java
public class Theaters {
    private int count; //返回数量
    private int start; //分页量
    private int total; //数据库总数量
    @SerializedName("subjects")
    private List<Subjects> data; //电影的具体信息


    private class Subjects {
        private String title;//电影名
        private String mainland_pubdate;//大陆上映时间
        private String alt;//网页连接
    }

    //定义 输出返回数据 的方法
    public void show() {
        Log.d("返回数量", ""+count);
        Log.d("分页量", ""+start);
        Log.d("数据库总数量", ""+total);

        for (Subjects subjects: data){
            Log.d("电影名", ""+subjects.title);
            Log.d("大陆上映时间", ""+subjects.mainland_pubdate);
            Log.d("网页连接", ""+subjects.alt);
        }
    }
}

```
#### 3.步骤c：创建 用于描述网络请求 的接口
```java
public interface RetrofitInterface {

    @GET("in_theaters")
    Call<Theaters> theaters(@QueryMap Map<String ,Object>map);
}
```
#### 4.步骤d：进行网络请求
```java

        //a.创建Retrofit对象
        Retrofit retrofit = new Retrofit.Builder()
                //指定baseurl，这里有坑，最后后缀出带着“/”
                .baseUrl("https://api.douban.com/v2/movie/")
                //设置内容格式,这种对应的数据返回值是String类型
                .addConverterFactory(GsonConverterFactory.create())
                //创建
                .build();


        //b,获得定义的接口的实例
        RetrofitInterface retrofitInterface = retrofit.create(RetrofitInterface.class);
        // 实现的效果与上面相同，但要传入Map
        Map<String, Object> map = new HashMap<>();
        map.put("apikey", "0b2bdeda43b5688921839c8ecb20399b");
        map.put("start",0);
        map.put("count", 100);

        //配置参数
        Call<Theaters> call =  retrofitInterface.theaters(map);

        //c.进行网络请求
        call.enqueue(new Callback<Theaters>() {
            //请求成功时回调
            @Override
            public void onResponse(Call<Theaters> call, Response<Theaters> response) {
                // 处理返回的数据结果
                response.body().show();
            }

            //请求失败时回调
            @Override
            public void onFailure(Call<Theaters> call, Throwable throwable) {
                Log.e("retrofit", "onFailure: "+throwable);
            }
        });
```
#### 5.运行结果
![在这里插入图片描述](https://img-blog.csdn.net/20180927200245359?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 六.Retrofit和Rxjava的结合
还是以上面的接口为例:关于Rxjava更多详细的内容可以参看我之前的博客[Android之Rxjava2.X 1————Rxjava概述](https://blog.csdn.net/qq_38499859/article/details/81611870)

API接口同上

#### 1.步骤a：添加Retrofit库的依赖
添加Retrofit和GSON的依赖
```java
    // Android 支持 Rxjava
    // 此处一定要注意使用RxJava2的版本
    compile 'io.reactivex.rxjava2:rxjava:2.1.7'
    compile 'io.reactivex.rxjava2:rxandroid:2.0.1'

    // Android 支持 Retrofit
    compile 'com.squareup.retrofit2:retrofit:2.4.0'

    // 衔接 Retrofit & RxJava
    // 此处一定要注意使用RxJava2的版本
    compile 'com.jakewharton.retrofit:retrofit2-rxjava2-adapter:1.0.0'

    // 支持Gson解析
    compile 'com.squareup.retrofit2:converter-gson:2.4.0'

```

添加权限
```java
   <uses-permission android:name="android.permission.INTERNET"/>
```

#### 2.步骤b：创建 接收服务器返回数据 的类
这里只接收了部分数据
```java
public class Theaters {
    private int count; //返回数量
    private int start; //分页量
    private int total; //数据库总数量
    @SerializedName("subjects")
    private List<Subjects> data; //电影的具体信息


    private class Subjects {
        private String title;//电影名
        private String mainland_pubdate;//大陆上映时间
        private String alt;//网页连接
    }

    //定义 输出返回数据 的方法
    public void show() {
        Log.d("返回数量", ""+count);
        Log.d("分页量", ""+start);
        Log.d("数据库总数量", ""+total);

        for (Subjects subjects: data){
            Log.d("电影名", ""+subjects.title);
            Log.d("大陆上映时间", ""+subjects.mainland_pubdate);
            Log.d("网页连接", ""+subjects.alt);
        }
    }
}

```
#### 3.步骤c：创建 用于描述网络请求 的接口
```java
public interface RetrofitInterface {

    @GET("in_theaters")
    Observable<Theaters> theaters2(@QueryMap Map<String ,Object>map);
}
```
#### 4.步骤d：进行网络请求
```java
   //a.创建Retrofit对象
        Retrofit retrofit = new Retrofit.Builder()
                //指定baseurl，这里有坑，最后后缀出带着“/”
                .baseUrl("https://api.douban.com/v2/movie/")
                //设置内容格式,这种对应的数据返回值是String类型
                .addConverterFactory(GsonConverterFactory.create())
                .addCallAdapterFactory(RxJava2CallAdapterFactory.create()) // 支持RxJava
                //创建
                .build();


        //b,获得定义的接口的实例
        RetrofitInterface retrofitInterface = retrofit.create(RetrofitInterface.class);
        // 实现的效果与上面相同，但要传入Map
        Map<String, Object> map = new HashMap<>();
        map.put("apikey", "0b2bdeda43b5688921839c8ecb20399b");
        map.put("start", 0);
        map.put("count", 100);

        //配置参数
        Observable<Theaters> observable = retrofitInterface.theaters2(map);


        //c. 通过Rxjava进行网络请求
        observable.subscribeOn(Schedulers.io()) // 切换到IO线程进行网络请求
                .observeOn(AndroidSchedulers.mainThread()) // 切换回到主线程 处理请求结果
                .subscribe(new Observer<Theaters>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                    }

                    @Override
                    public void onNext(Theaters result) { // e.接收服务器返回的数据
                        result.show();
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d("Retrofit", "请求失败");
                    }

                    @Override
                    public void onComplete() {
                    }
                });
```
#### 5.运行结果

https://www.jianshu.com/p/0fda3132cf98![在这里插入图片描述](https://img-blog.csdn.net/20180927210633538?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 七.参考资料
[这是一份很详细的 Retrofit 2.0 使用教程](https://blog.csdn.net/carson_ho/article/details/73732076#t34)
[网络加载框架 - Retrofit](https://www.jianshu.com/p/0fda3132cf98)
[Retrofit 官方文档翻译](https://www.jianshu.com/p/dee484f28fc9)

### 八.文章索引
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
