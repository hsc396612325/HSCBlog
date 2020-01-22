---
title: "Android之网络请求3————OkHttp的拦截器和封装"
date: 2019-02-03T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.OkHttp拦截器概述
关于OKHttp更多详细的内容，可以参考官网[OKHttp官网](https://github.com/square/okhttp/wiki/Interceptors)
在OKHttp中，中Interceptors拦截器是一种强大的机制，可以监视，重写和重试Call请求。

#### 1.OkHttp的拦截器的作用：

* 拦截器可以一次性对所有请求的返回值进行修改
* 拦截器可以一次性对请求的参数和返回的结果进行编码，比如统一设置为UTF-8.
* 拦截器可以对所有的请求做统一的日志记录，不需要在每个请求开始或者结束的位置都添加一个日志操作。
* 其他需要对请求和返回进行统一处理的需求....

#### 2.OkHttp拦截器的分类
OkHttp中的拦截器分2个：APP层面的拦截器（Application Interception）网络请求层面的拦截器(Network Interception)。

#### 3.两种的区别
Application：

* 不需要担心是否影响OKHttp的请求策略和请求速度
* 即使从缓存中取数据，也会执行Application拦截器
* 允许重试，即Chain.proceed()可以执行多次。
* 可以监听观察这个请求的最原始的未改变的意图(请求头，请求体等)，无法操作OKHttp为我们自动添加额外的请求头
* 无法操作中间的响应结果，比如当URL重定向发生以及请求重试，只能操作客户端主动第一次请求以及最终的响应结果

Network Interceptors

* 可以修改OkHttp框架自动添加的一些属性，即允许操作中间响应，比如当请求操作发生重定向或者重试等。
* 可以观察最终完整的请求参数（也就是最终服务器接收到的请求数据和熟悉）

### 二.两种拦截器的示例
#### 1.实例化appInterceptor拦截器
```java

/**
 * 应用拦截器
 */
Interceptor appInterceptor = new Interceptor() {
        @Override
        public Response intercept(Chain chain) throws IOException {
            Request request = chain.request();
            HttpUrl url = request.url();
            String s = url.url().toString();

            
            Log.d(TAG, "app intercept:begin ");
            Response response = chain.proceed(request);//请求
            Log.d(TAG, "app intercept:end");
            return response;
        }
    };
```
#### 2.实例化networkInterceptor拦截器
```java
    /**
     * 网络拦截器
     */
    Interceptor networkInterceptor = new Interceptor() {
                @Override
                public Response intercept(Chain chain) throws IOException {
                    Request request = chain.request();
                    Log.d(TAG,"network interceptor:begin");
                    Response  response = chain.proceed(request);//请求
                    Log.d(TAG,"network interceptor:end");
                    return response;
                }
            };

```
#### 3.将两个拦截器配置在Client中，并发送请求
```java
 @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        okHttpClient = new OkHttpClient
                .Builder()
                .addInterceptor(appInterceptor)
                .addNetworkInterceptor(networkInterceptor)
                .build();

        Button button = findViewById(R.id.bt);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Request request = new Request.Builder().url("http://www.baidu.cn").build();

                okHttpClient.newCall(request).enqueue(new Callback() {
                    @Override
                    public void onFailure(Call call, IOException e) {
                        e.printStackTrace();
                    }

                    @Override
                    public void onResponse(Call call, Response response) throws IOException {
                        Log.d(TAG,"--" + response.networkResponse());
                    }
                });
            }
        });

    }
```
#### 4.运行结果
![这里写图片描述](https://img-blog.csdn.net/20180903173107596)

### 三.拦截器的实际应用
#### 1.统一添加Header
应用场景:后台要求在请求API时，在每一个接口的请求头添加上对于的Token
这时候就可以使用拦截器对他们进行统一配置，
实例化拦截器
```java
  Interceptor  TokenHeaderInterceptor = new Interceptor() {
        @Override
        public Response intercept(Chain chain) throws IOException {
            // get token
            String token = AppService.getToken();
            Request originalRequest = chain.request();
            // get new request, add request header
            Request updateRequest = originalRequest.newBuilder()
                    .header("token", token)
                    .build();
            return chain.proceed(updateRequest);
        }
    };
```
在OKHttpClient中配置
```java
        okHttpClient = new OkHttpClient
                .Builder()
                .addInterceptor(TokenHeaderInterceptor)
                .addNetworkInterceptor(networkInterceptor)
                .build();


        Button button = findViewById(R.id.bt);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Request request = new Request.Builder().url("http://www.baidu.cn").build();

                okHttpClient.newCall(request).enqueue(new Callback() {
                    @Override
                    public void onFailure(Call call, IOException e) {
                        e.printStackTrace();
                    }

                    @Override
                    public void onResponse(Call call, Response response) throws IOException {
                        Log.d(TAG, "--" + response.networkResponse());
                    }
                });
            }
        });

```

#### 2.改变请求体
应用场景:在上面的 login 接口基础上，后台要求我们传过去的请求参数是要按照一定规则经过加密的。

规则：

* 请求参数名统一为content；
*  content值：JSON 格式的字符串经过 AES 加密后的内容；、

实例化拦截器
```java
    Interceptor  RequestEncryptInterceptor = new Interceptor() {

        private static final String FORM_NAME = "content";
        private static final String CHARSET = "UTF-8";
        @Override
        public Response intercept(Chain chain) throws IOException {
            // get token
            Request request = chain.request();

            RequestBody body = request.body();

            if (body instanceof FormBody){
                FormBody formBody = (FormBody) body;
                Map<String, String> formMap = new HashMap<>();

                // 从 formBody 中拿到请求参数，放入 formMap 中
                for (int i = 0; i < formBody.size(); i++) {
                    formMap.put(formBody.name(i), formBody.value(i));
                }

                // 将 formMap 转化为 json 然后 AES 加密
                Gson gson = new Gson();
                String jsonParams = gson.toJson(formMap);
                String encryptParams = AESCryptUtils.encrypt(jsonParams.getBytes(CHARSET), AppConstant.getAESKey());

                // 重新修改 body 的内容
                body = new FormBody.Builder().add(FORM_NAME, encryptParams).build();
            }

            if (body != null) {
                request = request.newBuilder()
                        .post(body)
                        .build();
            }
            return chain.proceed(request);
        }
    };
```
其他的同上。


### 四.OkHttp的封装
封装来源于博客：[OKHttp的基本使用和简单封装](https://blog.csdn.net/qq_16240393/article/details/54863646)

#### 1.封装
```java
public class NetRequest {
    private static NetRequest netRequest;
    private static OkHttpClient okHttpClient; // OKHttp网络请求
    private Handler mHandler;

    private NetRequest() {
        // 初始化okhttp 创建一个OKHttpClient对象，一个app里最好实例化一个此对象
        okHttpClient = new OkHttpClient();
        okHttpClient.newBuilder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS)
                .writeTimeout(10, TimeUnit.SECONDS);
        mHandler = new Handler(Looper.getMainLooper());
    }

    /**
     * 单例模式  获取NetRequest实例
     *
     * @return netRequest
     */
    private static NetRequest getInstance() {
        if (netRequest == null) {
            netRequest = new NetRequest();
        }
        return netRequest;
    }

    //-------------对外提供的方法Start--------------------------------

    /**
     * 建立网络框架，获取网络数据，异步get请求（Form）
     *
     * @param url      url
     * @param params   key value
     * @param callBack data
     */
    public static void getFormRequest(String url, Map<String, String> params, DataCallBack callBack) {
        getInstance().inner_getFormAsync(url, params, callBack);
    }

    /**
     * 建立网络框架，获取网络数据，异步post请求（Form）
     *
     * @param url      url
     * @param params   key value
     * @param callBack data
     */
    public static void postFormRequest(String url, Map<String, String> params, DataCallBack callBack) {
        getInstance().inner_postFormAsync(url, params, callBack);
    }

    /**
     * 建立网络框架，获取网络数据，异步post请求（json）
     *
     * @param url      url
     * @param params   key value
     * @param callBack data
     */
    public static void postJsonRequest(String url, Map<String, String> params, DataCallBack callBack) {
        getInstance().inner_postJsonAsync(url, params, callBack);
    }
    //-------------对外提供的方法End--------------------------------

    /**
     * 异步get请求（Form），内部实现方法
     *
     * @param url    url
     * @param params key value
     */
    private void inner_getFormAsync(String url, Map<String, String> params, final DataCallBack callBack) {
        if (params == null) {
            params = new HashMap<>();
        }
        // 请求url（baseUrl+参数）
        final String doUrl = urlJoint(url, params);
        // 新建一个请求
        final Request request = new Request.Builder().url(doUrl).build();
        //执行请求获得响应结果
        Call call = okHttpClient.newCall(request);
        call.enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                deliverDataFailure(request, e, callBack);
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                if (response.isSuccessful()) { // 请求成功
                    //执行请求成功的操作
                    String result = response.body().string();
                    deliverDataSuccess(result, callBack);
                } else {
                    throw new IOException(response + "");
                }
            }
        });
    }

    /**
     * 异步post请求（Form）,内部实现方法
     *
     * @param url      url
     * @param params   params
     * @param callBack callBack
     */
    private void inner_postFormAsync(String url, Map<String, String> params, final DataCallBack callBack) {
        RequestBody requestBody;
        if (params == null) {
            params = new HashMap<>();
        }
        FormBody.Builder builder = new FormBody.Builder();
        /**
         * 在这对添加的参数进行遍历
         */
        for (Map.Entry<String, String> map : params.entrySet()) {
            String key = map.getKey();
            String value;
            /**
             * 判断值是否是空的
             */
            if (map.getValue() == null) {
                value = "";
            } else {
                value = map.getValue();
            }
            /**
             * 把key和value添加到formbody中
             */
            builder.add(key, value);
        }
        requestBody = builder.build();
        //结果返回
        final Request request = new Request.Builder().url(url).post(requestBody).build();
        okHttpClient.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                deliverDataFailure(request, e, callBack);
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                if (response.isSuccessful()) { // 请求成功
                    //执行请求成功的操作
                    String result = response.body().string();
                    deliverDataSuccess(result, callBack);
                } else {
                    throw new IOException(response + "");
                }
            }
        });
    }

    /**
     * post请求传json
     *
     * @param url      url
     * @param callBack 成功或失败回调
     * @param params   params
     */
    private void inner_postJsonAsync(String url, Map<String, String> params, final DataCallBack callBack) {
        // 将map转换成json,需要引入Gson包
        String mapToJson = new Gson().toJson(params);
        final Request request = buildJsonPostRequest(url, mapToJson);
        okHttpClient.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                deliverDataFailure(request, e, callBack);
            }

            @Override
            public void onResponse(Call call, Response response) throws IOException {
                if (response.isSuccessful()) { // 请求成功
                    //执行请求成功的操作
                    String result = response.body().string();
                    deliverDataSuccess(result, callBack);
                } else {
                    throw new IOException(response + "");
                }
            }
        });
    }

    /**
     * Json_POST请求参数
     *
     * @param url  url
     * @param json json
     * @return requestBody
     */
    private Request buildJsonPostRequest(String url, String json) {
        RequestBody requestBody = RequestBody.create(MediaType.parse("application/json; charset=utf-8"), json);
        return new Request.Builder().url(url).post(requestBody).build();
    }

    /**
     * 分发失败的时候调用
     *
     * @param request  request
     * @param e        e
     * @param callBack callBack
     */
    private void deliverDataFailure(final Request request, final IOException e, final DataCallBack callBack) {
        /**
         * 在这里使用异步处理
         */
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                if (callBack != null) {
                    callBack.requestFailure(request, e);
                }
            }
        });
    }

    /**
     * 分发成功的时候调用
     *
     * @param result   result
     * @param callBack callBack
     */
    private void deliverDataSuccess(final String result, final DataCallBack callBack) {
        /**
         * 在这里使用异步线程处理
         */
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                if (callBack != null) {
                    try {
                        callBack.requestSuccess(result);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }
        });
    }

    /**
     * 数据回调接口
     */
    public interface DataCallBack {

        void requestSuccess(String result) throws Exception;

        void requestFailure(Request request, IOException e);
    }

    /**
     * 拼接url和请求参数
     *
     * @param url    url
     * @param params key value
     * @return String url
     */
    private static String urlJoint(String url, Map<String, String> params) {
        StringBuilder endUrl = new StringBuilder(url);
        boolean isFirst = true;
        Set<Map.Entry<String, String>> entrySet = params.entrySet();
        for (Map.Entry<String, String> entry : entrySet) {
            if (isFirst && !url.contains("?")) {
                isFirst = false;
                endUrl.append("?");
            } else {
                endUrl.append("&");
            }
            endUrl.append(entry.getKey());
            endUrl.append("=");
            endUrl.append(entry.getValue());
        }
        return endUrl.toString();
    }
}

```

#### 2.使用
```java

        String url = "网络请求的地址";
        HashMap<String, String> params = new HashMap<>();
        // 添加请求参数
        params.put("key", "value");
        // ...
        NetRequest.getFormRequest(url, params, new NetRequest.DataCallBack() {
            @Override
            public void requestSuccess(String result) throws Exception {
                // 请求成功的回调
            }

            @Override
            public void requestFailure(Request request, IOException e) {
                // 请求失败的回调
            }
        });
        
```

#### 3.升级版
还发现一篇封装的更彻底OKHttp
推荐一下

[OkHttp封装](https://blog.csdn.net/lowprofile_coding/article/details/77750810)
### 五. 参考资料
[OkHttp基本使用（五）拦截器](https://blog.csdn.net/muyi_amen/article/details/58586823)
[一起来写OKHttp的拦截器](https://blog.csdn.net/cuiyufeng2/article/details/73732309)
[OkHttp3-拦截器（Interceptor）](https://www.jianshu.com/p/fc4d4348dc58)
[OKHttp的基本使用和简单封装](https://blog.csdn.net/qq_16240393/article/details/54863646)
[OkHttp封装](https://blog.csdn.net/lowprofile_coding/article/details/77750810)

### 六.文章索引
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
