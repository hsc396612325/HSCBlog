---
title: "Android之网络请求10————Retrofit的进阶使用"
date: 2019-02-10T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.前言
上一节中我们对Retrofit进行了介绍，包括他的简单使用和注解。这一篇我们学习他的进阶使用，包括文件图片Json字符串的上传，以及大文件的断点下载，还有和Rxjava的混合使用

准备工作：
* 添加依赖
* 设置权限
### 二.Retrfit文件上传
#### 1.创建描述网络请求的接口
```java
 public interface FileUploadService {  
 @Multipart //表示发送form-encoded的数据（适用于 有文件 上传的场景）
 @POST("upload")
 Call<ResponseBody> upload(@Part("description") RequestBody description,
                          @Part MultipartBody.Part file);
}
```

#### 2.具体使用
```java
// 创建 RequestBody，用于封装 请求RequestBody
RequestBody requestFile =
        RequestBody.create(MediaType.parse("multipart/form-data"), file);

// MultipartBody.Part is used to send also the actual file name
MultipartBody.Part body =
        MultipartBody.Part.createFormData("image", file.getName(), requestFile);

// 添加描述
String descriptionString = "hello, 这是文件描述";
RequestBody description =
        RequestBody.create(
                MediaType.parse("multipart/form-data"), descriptionString);

// 执行请求
Call<ResponseBody> call = service.upload(description, body);
call.enqueue(new Callback<ResponseBody>() {
    @Override
    public void onResponse(Call<ResponseBody> call,
                           Response<ResponseBody> response) {
        Log.v("Upload", "success");
    }

    @Override
    public void onFailure(Call<ResponseBody> call, Throwable t) {
        Log.e("Upload error:", t.getMessage());
    }
});

```
### 三.Retrfit图片上传
#### 1.创建描述网络请求的接口
```java
//上传一张图片
@Multipart
 @POST("you methd url upload/")
Call<ResponseBody> uploadFile(@Part("avatar\\\\"; filename=\\\\"avatar.jpg") RequestBody file);

//上传图片数量不定
  @Multipart
@POST("{url}")
Observable<ResponseBody> uploadFiles(
        @Path("url") String url,
        @Part("filename") String description,
        @PartMap() Map<String, RequestBody> maps);

//上传图片数量不定方法2
@Multipart
@POST("{url}")
Observable<ResponseBody> uploads(
        @Path("url") String url,
        @Part("description") RequestBody description,
        @Part("filekey") MultipartBody.Part file);
```
#### 2.具体使用
具体的使用和上面文件的上传差不多，不过图片可以设置Content-Type,如
```
   RequestBody requestFile = RequestBody.create(MediaType.parse("image/jpg"), mFile);
```
### 四.Retrfit Json字符串上传
#### 1.创建描述网络请求的接口
```java
@POST("/uploadJson")
Observable<ResponseBody> uploadjson(@Body RequestBody jsonBody);
```

#### 2.具体使用
```java
RequestBody body= RequestBody.create(okhttp3.MediaType.parse("application/json; charset=utf-8"), jsonString);

// 执行请求
Call<ResponseBody> call = service.uploadJson(description, body);
call.enqueue(new Callback<ResponseBody>() {
    @Override
    public void onResponse(Call<ResponseBody> call,
                           Response<ResponseBody> response) {
        Log.v("Upload", "success");
    }

    @Override
    public void onFailure(Call<ResponseBody> call, Throwable t) {
        Log.e("Upload error:", t.getMessage());
    }
});
```
### 五.Retrfit大文件下载
#### 1.ApiService
```java
public interface ApiService {
  @Streaming//大文件官方建议用 @Streaming 来进行注解，不然会出现IO异常，小文件可以忽略不注入。
  @GET
  Observable<ResponseBody> downloadFile(@Url String   fileUrl);
}
```
#### 2.DownLoadManager
```java

/**
 * 下载管理者 来进行文件写入，类型判断等
 */

public class DownLoadManager {
    private static final String TAG = "DownLoadManager";
    private static String APK_CONTENTTYPE = "application/vnd.android.package-archive";
    private static String PNG_CONTENTTYPE = "image/png";
    private static String JPG_CONTENTTYPE = "image/jpg";
    private static String fileSuffix = "";

    public static boolean writeResponseBodyToDisk(Context context, ResponseBody body) {
        Log.d(TAG, "contentType:>>>>" + body.contentType().toString());
        String type = body.contentType().toString();
        if (type.equals(APK_CONTENTTYPE)) {
            fileSuffix = ".apk";
        } else if (type.equals(PNG_CONTENTTYPE)) {
            fileSuffix = ".png";
        } // 其他类型同上 自己判断加入.....
        String path = context.getExternalFilesDir(null) + File.separator + System.currentTimeMillis() + fileSuffix;
        Log.d(TAG, "path:>>>>" + path);
        
        //文件的写入
        try { 
            File futureStudioIconFile = new File(path);
            InputStream inputStream = null;
            OutputStream outputStream = null;
            try {
                byte[] fileReader = new byte[4096];
                long fileSize = body.contentLength();
                long fileSizeDownloaded = 0;
                inputStream = body.byteStream();
                outputStream = new FileOutputStream(futureStudioIconFile);
                while (true) {
                    int read = inputStream.read(fileReader);
                    if (read == -1) {
                        break;
                    }
                    outputStream.write(fileReader, 0, read);
                    fileSizeDownloaded += read;
                    Log.d(TAG, "file download: " + fileSizeDownloaded + " of " + fileSize);
                }
                outputStream.flush();
                return true;
            } catch (IOException e) {
                return false;
            } finally {
                if (inputStream != null) {
                    inputStream.close();
                }
                if (outputStream != null) {
                    outputStream.close();
                }
            }
        } catch (IOException e) {
            return false;
        }
    }
}
```
#### 3.具体使用
```java
 OkHttpClient okHttpClient = new OkHttpClient.Builder().build();
        Retrofit retrofit = new Retrofit.Builder().client(okHttpClient).baseUrl(url).build();
        Api Service apiService = retrofit.create(ApiService.class);
        apiService.download(url1, new Subscriber<ResponseBody>() {
            @Override
            public void onCompleted() {
            }

            @Override
            public void onError(Throwable e) {
            }

            @Override
            public void onNext(ResponseBody responseBody) {
                if (DownLoadManager.writeResponseBodyToDisk(MainActivity.this, responseBody)) {
                    Toast.makeText(MainActivity.this, "Download is sucess", Toast.LENGTH_LONG).show();
                }
            }
        });

```

#### 4.进一步优化
上面只是一些简单的下载，我们还可以加入更多的优化，比如在header中加入上次下载的进度大小，就可以实现基本的断点下载了。

我们可以请求到文件总长度的时候，均分三段大小区间，来开启三个新线程去下载，下载完后再以唯一的文件ID，将三段文件以此追加到一个文件就可以了，来实现多线程下载。
### 七.参考资料
[Retrofit 2.0 超能实践（三），轻松实现文件/多图片上传/Json字符串](https://blog.csdn.net/sk719887916/article/details/51755427)
[Retrofit 2.0 超能实践（四），完成大文件断点下载](https://www.jianshu.com/p/582e0a4a4ee9)

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
