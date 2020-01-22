---
title: "Android之网络请求6————OkHttp源码3:拦截器"
date: 2019-02-06T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.目的
本篇博客主要分析的是OkHttp获取响应的过程，以及拦截器链.
### 二.getResponseWithInterceptorChain方法
在上篇博客里，同步和异步响应中都出现了getResponseWithInterceptorChain方法，这一篇博客就接那里继续分析。

```java
Response getResponseWithInterceptorChain() throws IOException {
    // Build a full stack of interceptors.
    List<Interceptor> interceptors = new ArrayList<>();
    //添加应用拦截器
    interceptors.addAll(client.interceptors());
    //添加重试和重定向拦截器
    interceptors.add(retryAndFollowUpInterceptor);
    //添加转换拦截器
    interceptors.add(new BridgeInterceptor(client.cookieJar()));
    //添加缓存拦截器
    interceptors.add(new CacheInterceptor(client.internalCache()));
    //添加连接拦截器
    interceptors.add(new ConnectInterceptor(client));
    
    //添加网络拦截器
    if (!forWebSocket) {
      interceptors.addAll(client.networkInterceptors());
    }
    interceptors.add(new CallServerInterceptor(forWebSocket));

    //生成拦截器链	
    Interceptor.Chain chain = new RealInterceptorChain(interceptors, null, null, null, 0,
        originalRequest, this, eventListener, client.connectTimeoutMillis(),
        client.readTimeoutMillis(), client.writeTimeoutMillis());

    return chain.proceed(originalRequest);
  }
}

```

OkHttp的拦截器，其中应用拦截器和网络拦截器可以自定义添加，详情可以看之前的博客[ Android之网络请求3————OkHttp的拦截器和封装 ](https://blog.csdn.net/qq_38499859/article/details/82355954)

从上面的代码可以看出，向 interceptors添加了一系列的拦截器。最后构造了一个RealInterceptorChain对象，该类是拦截器链的具体体现，携带了整个拦截器链，包含了所有的应用拦截器，OKHttp的核心。

OKHppt这种拦截器链采用的是责任链模式，这样的好处就是讲请求的发送和处理分开处理，并且可以动态添加中间处理实现对请求的处理和短路操作。


### 三.RealInterceptorChain类
在上文中，生成了RealInterceptorChain类。
我们进入查看.RealInterceptorChain类
```java
public final class RealInterceptorChain implements Interceptor.Chain {
  private final List<Interceptor> interceptors;//传递的拦截器集合
  private final StreamAllocation streamAllocation;
  private final HttpCodec httpCodec;
  private final RealConnection connection;
  private final int index; //当前拦截器的索引
  private final Request request;//当前的realReques
  private final Call call;
  private final EventListener eventListener;
  private final int connectTimeout;
  private final int readTimeout;
  private final int writeTimeout;
  private int calls;

  public RealInterceptorChain(List<Interceptor> interceptors, StreamAllocation streamAllocation,
      HttpCodec httpCodec, RealConnection connection, int index, Request request, Call call,
      EventListener eventListener, int connectTimeout, int readTimeout, int writeTimeout) {
    this.interceptors = interceptors; 
    this.connection = connection;
    this.streamAllocation = streamAllocation;
    this.httpCodec = httpCodec;
    this.index = index;
    this.request = request;
    this.call = call;
    this.eventListener = eventListener;
    this.connectTimeout = connectTimeout;
    this.readTimeout = readTimeout;
    this.writeTimeout = writeTimeout;
  }
   .....
}
```
在getResponseWithInterceptorChain()最后返回代码时调用了拦截器链的prooceed方法，进入查看源码
```java
//RealInterceptorChain
 public Response proceed(Request request, StreamAllocation streamAllocation, HttpCodec httpCodec,
      RealConnection connection) throws IOException {
    if (index >= interceptors.size()) throw new AssertionError();

    calls++;

    //错误处理相关
    // If we already have a stream, confirm that the incoming request will use it.
    if (this.httpCodec != null && !this.connection.supportsUrl(request.url())) {
      throw new IllegalStateException("network interceptor " + interceptors.get(index - 1)
          + " must retain the same host and port");
    }

    // If we already have a stream, confirm that this is the only call to chain.proceed().
    if (this.httpCodec != null && calls > 1) {
      throw new IllegalStateException("network interceptor " + interceptors.get(index - 1)
          + " must call proceed() exactly once");
    }

    // Call the next interceptor in the chain.
    //核心代码
    RealInterceptorChain next = new RealInterceptorChain(interceptors, streamAllocation, httpCodec,
        connection, index + 1, request, call, eventListener, connectTimeout, readTimeout,
        writeTimeout);
    //获取下一个拦截器
    Interceptor interceptor = interceptors.get(index);
    //调用当前拦截器的intercept方法，并将下一个拦截器传入其中。
    Response response = interceptor.intercept(next);



    // Confirm that the next interceptor made its required call to chain.proceed().
    if (httpCodec != null && index + 1 < interceptors.size() && next.calls != 1) {
      throw new IllegalStateException("network interceptor " + interceptor
          + " must call proceed() exactly once");
    }

    // Confirm that the intercepted response isn't null.
    if (response == null) {
      throw new NullPointerException("interceptor " + interceptor + " returned null");
    }

    if (response.body() == null) {
      throw new IllegalStateException(
          "interceptor " + interceptor + " returned a response with no body");
    }

    return response;
  }
```

### 四.RetryAndFollowUpInterceptor
我们按照添加的顺序逐个分析各个拦截器

RetryAndFollowUpInterceptor拦截器可以从错误中恢复和重定向，如果Call被取消了，那么将会抛出IoException。
进入查看其intercept方法
#### 1.intercept
```java
 @Override public Response intercept(Chain chain) throws IOException {
    Request request = chain.request();
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Call call = realChain.call();
    EventListener eventListener = realChain.eventListener();

    //①
    StreamAllocation streamAllocation = new StreamAllocation(client.connectionPool(),
        createAddress(request.url()), call, eventListener, callStackTrace);
    this.streamAllocation = streamAllocation;

    int followUpCount = 0;
    Response priorResponse = null;
    //②
    while (true) {
      if (canceled) {
        streamAllocation.release();
        throw new IOException("Canceled");
      }

      Response response;
      boolean releaseConnection = true;
      try {
        response = realChain.proceed(request, streamAllocation, null, null);
        releaseConnection = false;
      } catch (RouteException e) {
        // The attempt to connect via a route failed. The request will not have been sent.
        if (!recover(e.getLastConnectException(), streamAllocation, false, request)) {
          throw e.getLastConnectException();
        }
        releaseConnection = false;
        continue;
      } catch (IOException e) {
        // An attempt to communicate with a server failed. The request may have been sent.
        boolean requestSendStarted = !(e instanceof ConnectionShutdownException);
        if (!recover(e, streamAllocation, requestSendStarted, request)) throw e;
        releaseConnection = false;
        continue;
      } finally {
        // We're throwing an unchecked exception. Release any resources.
        if (releaseConnection) {
          streamAllocation.streamFailed(null);
          streamAllocation.release();
        }
      }

      // Attach the prior response if it exists. Such responses never have a body.
      if (priorResponse != null) {
        response = response.newBuilder()
            .priorResponse(priorResponse.newBuilder()
                    .body(null)
                    .build())
            .build();
      }

      Request followUp = followUpRequest(response, streamAllocation.route());

      if (followUp == null) {
        if (!forWebSocket) {
          streamAllocation.release();
        }
        return response;
      }

      closeQuietly(response.body());

      if (++followUpCount > MAX_FOLLOW_UPS) {
        streamAllocation.release();
        throw new ProtocolException("Too many follow-up requests: " + followUpCount);
      }

      if (followUp.body() instanceof UnrepeatableRequestBody) {
        streamAllocation.release();
        throw new HttpRetryException("Cannot retry streamed HTTP body", response.code());
      }

      if (!sameConnection(response, followUp.url())) {
        streamAllocation.release();
        streamAllocation = new StreamAllocation(client.connectionPool(),
            createAddress(followUp.url()), call, eventListener, callStackTrace);
        this.streamAllocation = streamAllocation;
      } else if (streamAllocation.codec() != null) {
        throw new IllegalStateException("Closing the body of " + response
            + " didn't close its backing stream. Bad interceptor?");
      }

      request = followUp;
      priorResponse = response;
    }
  }
```
#### 2.StreamAllocation
源码①.创建了一个StreamAllocation，这个是用来做连接分配的，传递的参数有五个，第一个是前面创建的连接池，第二个是调用createAddress创建的Address，第三个是Call。
```java
//①
    StreamAllocation streamAllocation = new StreamAllocation(client.connectionPool(),
         createAddress(request.url()), call, eventListener, callStackTrace);
    this.streamAllocation = streamAllocation;
```
先查看createAddress方法
```java
private Address createAddress(HttpUrl url) {
    SSLSocketFactory sslSocketFactory = null;
    HostnameVerifier hostnameVerifier = null;
    CertificatePinner certificatePinner = null;
    //如果是https
    if (url.isHttps()) {
      sslSocketFactory = client.sslSocketFactory();
      hostnameVerifier = client.hostnameVerifier();
      certificatePinner = client.certificatePinner();
    }

    return new Address(url.host(), url.port(), client.dns(), client.socketFactory(),
        sslSocketFactory, hostnameVerifier, certificatePinner, client.proxyAuthenticator(),
        client.proxy(), client.protocols(), client.connectionSpecs(), client.proxySelector());
  }

```
查看Address类的构造方法
```java
 public Address(String uriHost, int uriPort, Dns dns, SocketFactory socketFactory,
      @Nullable SSLSocketFactory sslSocketFactory, @Nullable HostnameVerifier hostnameVerifier,
      @Nullable CertificatePinner certificatePinner, Authenticator proxyAuthenticator,
      @Nullable Proxy proxy, List<Protocol> protocols, List<ConnectionSpec> connectionSpecs,
      ProxySelector proxySelector) {
    this.url = new HttpUrl.Builder()
        .scheme(sslSocketFactory != null ? "https" : "http")
        .host(uriHost)
        .port(uriPort)
        .build();

    if (dns == null) throw new NullPointerException("dns == null");
    this.dns = dns;

    if (socketFactory == null) throw new NullPointerException("socketFactory == null");
    this.socketFactory = socketFactory;

    if (proxyAuthenticator == null) {
      throw new NullPointerException("proxyAuthenticator == null");
    }
    this.proxyAuthenticator = proxyAuthenticator;

    if (protocols == null) throw new NullPointerException("protocols == null");
    this.protocols = Util.immutableList(protocols);

    if (connectionSpecs == null) throw new NullPointerException("connectionSpecs == null");
    this.connectionSpecs = Util.immutableList(connectionSpecs);

    if (proxySelector == null) throw new NullPointerException("proxySelector == null");
    this.proxySelector = proxySelector;

    this.proxy = proxy;
    this.sslSocketFactory = sslSocketFactory;
    this.hostnameVerifier = hostnameVerifier;
    this.certificatePinner = certificatePinner;
  }
```
根据clent和请求的想换信息初始化了Address

查看StreamAllocation
```java
  public StreamAllocation(ConnectionPool connectionPool, Address address, Call call,
      EventListener eventListener, Object callStackTrace) {
    this.connectionPool = connectionPool;
    this.address = address;
    this.call = call;
    this.eventListener = eventListener;
    //路由选择器
    this.routeSelector = new RouteSelector(address, routeDatabase(), call, eventListener);
    this.callStackTrace = callStackTrace;
  }
```

#### 3.发生请求&接收响应
回到intercept，看源码②while处代码,先看上半部分
```java
while (true) {
      if (canceled) { //查看请求是否取消
        streamAllocation.release();
        throw new IOException("Canceled");
      }

      Response response;//响应
      boolean releaseConnection = true;//是否需要重连
      try {
        //调用拦截器链的proceed方法，在这个方法中，会调用下一个拦截器
        //这就是之前所说拦截器链的顺序调用
        response = realChain.proceed(request, streamAllocation, null, null);
        releaseConnection = false;
      } catch (RouteException e) {
        // The attempt to connect via a route failed. The request will not have been sent.
        if (!recover(e.getLastConnectException(), streamAllocation, false, request)) {
          throw e.getLastConnectException();
        }
        releaseConnection = false;
        continue;
      } catch (IOException e) {
        // An attempt to communicate with a server failed. The request may have been sent.
        boolean requestSendStarted = !(e instanceof ConnectionShutdownException);
        if (!recover(e, streamAllocation, requestSendStarted, request)) throw e;
        releaseConnection = false;
        continue;
      } finally {
        // We're throwing an unchecked exception. Release any resources.
	  //释放资源
        if (releaseConnection) {
  
          streamAllocation.streamFailed(null);
          streamAllocation.release();
        }
      }
    
     .......
    }
```
进入查看recover方法
```java
 private boolean recover(IOException e, StreamAllocation streamAllocation,
      boolean requestSendStarted, Request userRequest) {
    streamAllocation.streamFailed(e);

    // The application layer has forbidden retries.
    //应用层禁止重试
    if (!client.retryOnConnectionFailure()) return false;

    // We can't send the request body again.
    //不能再发送请求体了
    if (requestSendStarted && userRequest.body() instanceof UnrepeatableRequestBody) return false;

    // This exception is fatal.
    //这个异常无法重试
    if (!isRecoverable(e, requestSendStarted)) return false;

    // No more routes to attempt.
    //没有更多的attempt
    if (!streamAllocation.hasMoreRoutes()) return false;

    // For failure recovery, use the same route selector with a new connection.
    //上面的条件都不满足，此时就可以进行重试
    return true;
  }
```
#### 4.错误重试和重定向
接着来看while循环的下半部分


```java
while(true){
......
  // Attach the prior response if it exists. Such responses never have a body.
  //priorResponse不为空，说明之前已经获得响应
      if (priorResponse != null) {
      //结合当前的response和之前的response获得新的response。
        response = response.newBuilder()
            .priorResponse(priorResponse.newBuilder()
                    .body(null)
                    .build())
            .build();
      }
 
     //调用followUpRequest查看响应是否需要重定向，如果不需要重定向则返回当前请求,如果需要返回新的请求
     // followUpRequest源码见下
      Request followUp = followUpRequest(response, streamAllocation.route());

      //不需要重定向或者无法重定向
      if (followUp == null) {
        if (!forWebSocket) {
          streamAllocation.release();
        }
        return response;
      }

      closeQuietly(response.body());

     //重试次数+1
     //重试次数超过MAX_FOLLOW_UPS（默认20），抛出异常
      if (++followUpCount > MAX_FOLLOW_UPS) {
        streamAllocation.release();
        throw new ProtocolException("Too many follow-up requests: " + followUpCount);
      }

      //followUp与当前的响应对比，是否为同一个连接
      if (followUp.body() instanceof UnrepeatableRequestBody) {
        streamAllocation.release();
        throw new HttpRetryException("Cannot retry streamed HTTP body", response.code());
      }

     //followUp与当前请求的不是同一个连接时，则重写申请重新设置streamAllocation
      if (!sameConnection(response, followUp.url())) {
        streamAllocation.release();
        streamAllocation = new StreamAllocation(client.connectionPool(),
            createAddress(followUp.url()), call, eventListener, callStackTrace);
        this.streamAllocation = streamAllocation;
      } else if (streamAllocation.codec() != null) {
        throw new IllegalStateException("Closing the body of " + response
            + " didn't close its backing stream. Bad interceptor?");
      }
   
      //重新设置reques，并把当前的Response保存到priorResponse，继续while循环
      request = followUp;
      priorResponse = response;
    }
```

查看 followUpRequest的源码
```java
  private Request followUpRequest(Response userResponse, Route route) throws IOException {
    if (userResponse == null) throw new IllegalStateException();
    //返回的响应码
    int responseCode = userResponse.code();
    
    //请求方法
    final String method = userResponse.request().method();
    switch (responseCode) {
     //407请求要求代理的身份认证
      case HTTP_PROXY_AUTH:
        Proxy selectedProxy = route != null
            ? route.proxy()
            : client.proxy();
        if (selectedProxy.type() != Proxy.Type.HTTP) {
          throw new ProtocolException("Received HTTP_PROXY_AUTH (407) code while not using proxy");
        }
        return client.proxyAuthenticator().authenticate(route, userResponse);

      //401请求要求用户的身份认证
      case HTTP_UNAUTHORIZED:
        return client.authenticator().authenticate(route, userResponse);

      //307&308 临时重定向。使用GET请求重定向
      case HTTP_PERM_REDIRECT:
      case HTTP_TEMP_REDIRECT:
        // "If the 307 or 308 status code is received in response to a request other than GET
        // or HEAD, the user agent MUST NOT automatically redirect the request"
        if (!method.equals("GET") && !method.equals("HEAD")) {
          return null;
        }
        // fall-through
        
      case HTTP_MULT_CHOICE: //300多种选择。请求的资源可包括多个位置，相应可返回一个资源特征与地址的列表用于用户终端（例如：浏览器）选择
      case HTTP_MOVED_PERM://301永久移动。请求的资源已被永久的移动到新URI，返回信息会包括新的URI，浏览器会自动定向到新URI。
      case HTTP_MOVED_TEMP://302临时移动。与301类似。但资源只是临时被移动。
      case HTTP_SEE_OTHER://303查看其它地址。与301类似。使用GET和POST请求查看
        // Does the client allow redirects?
        if (!client.followRedirects()) return null;

        String location = userResponse.header("Location");
        if (location == null) return null;
        HttpUrl url = userResponse.request().url().resolve(location);

        // Don't follow redirects to unsupported protocols.
        if (url == null) return null;

        // If configured, don't follow redirects between SSL and non-SSL.
        boolean sameScheme = url.scheme().equals(userResponse.request().url().scheme());
        if (!sameScheme && !client.followSslRedirects()) return null;

        // Most redirects don't include a request body.
        Request.Builder requestBuilder = userResponse.request().newBuilder();
        if (HttpMethod.permitsRequestBody(method)) {
          final boolean maintainBody = HttpMethod.redirectsWithBody(method);
          if (HttpMethod.redirectsToGet(method)) {
            requestBuilder.method("GET", null);
          } else {
            RequestBody requestBody = maintainBody ? userResponse.request().body() : null;
            requestBuilder.method(method, requestBody);
          }
          if (!maintainBody) {
            
            requestBuilder.removeHeader("Transfer-Encoding");
            requestBuilder.removeHeader("Content-Length");
            requestBuilder.removeHeader("Content-Type");
          }
        }

        // When redirecting across hosts, drop all authentication headers. This
        // is potentially annoying to the application layer since they have no
        // way to retain them.
        if (!sameConnection(userResponse, url)) { 
        //移出请求头
          requestBuilder.removeHeader("Authorization");
        }

        return requestBuilder.url(url).build();

      case HTTP_CLIENT_TIMEOUT: //408 服务器无法根据客户端请求的内容特性完成请求
        // 408's are rare in practice, but some servers like HAProxy use this response code. The
        // spec says that we may repeat the request without modifications. Modern browsers also
        // repeat the request (even non-idempotent ones.)
        if (!client.retryOnConnectionFailure()) {
          // The application layer has directed us not to retry the request.
          return null;
        }

        if (userResponse.request().body() instanceof UnrepeatableRequestBody) {
          return null;
        }

        if (userResponse.priorResponse() != null
            && userResponse.priorResponse().code() == HTTP_CLIENT_TIMEOUT) {
          // We attempted to retry and got another timeout. Give up.
          return null;
        }

        if (retryAfter(userResponse, 0) > 0) {
          return null;
        }

        return userResponse.request();

      case HTTP_UNAVAILABLE://503 	由于超载或系统维护，服务器暂时的无法处理客户端的请求。延时的长度可包含在服务器的Retry-After头信息中
        if (userResponse.priorResponse() != null
            && userResponse.priorResponse().code() == HTTP_UNAVAILABLE) {
          // We attempted to retry and got another timeout. Give up.
          return null;
        }

        if (retryAfter(userResponse, Integer.MAX_VALUE) == 0) {
          // specifically received an instruction to retry without delay
          return userResponse.request();
        }

        return null;

      default:
        return null;
    }
  }

```
#### 5. 流程图
![这里写图片描述](https://img-blog.csdn.net/20180910172857699?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 五.BridgeInterceptor类
在RetryAndFollowUpInterceptor 执行response = realChain.proceed(request, streamAllocation, null, null)代码时，此时会调用下一个拦截器，即BridgeInterceptor拦截器

BridgeInterceptor转换拦截器主要工作就是为请求添加请求头，为响应添加响应头

直接查看源码
#### 1. intercept
我们分步来看BridgeInterceptor的intercept代码

下面代码主要为request添加Content-Type(文档类型)、Content-Length(内容长度)或Transfer-Encoding，从这里我们也可以发现其实这些头信息是不需要我们手动添加的.即使我们手动添加也会被覆盖掉。
```java
    if (body != null) {
      MediaType contentType = body.contentType();
      if (contentType != null) {
        requestBuilder.header("Content-Type", contentType.toString());
      }

      long contentLength = body.contentLength();
      if (contentLength != -1) {
        requestBuilder.header("Content-Length", Long.toString(contentLength));
        requestBuilder.removeHeader("Transfer-Encoding");
      } else {
        requestBuilder.header("Transfer-Encoding", "chunked");
        requestBuilder.removeHeader("Content-Length");
      }
    }

```

下面的代码时为Host、Connection和User-Agent字段添加默认值，不过不同于上面的，这几个属性只有用户没有设置时，OkHttp会自动添加，如果你收到添加时，不会被覆盖掉
```java
  if (userRequest.header("Host") == null) {
      requestBuilder.header("Host", hostHeader(userRequest.url(), false));
    }

    if (userRequest.header("Connection") == null) {
      requestBuilder.header("Connection", "Keep-Alive");
    }

    if (userRequest.header("User-Agent") == null) {
      requestBuilder.header("User-Agent", Version.userAgent());
    }

```

默认支持gzip压缩
```java
    // If we add an "Accept-Encoding: gzip" header field we're responsible for also decompressing
    // the transfer stream.
    boolean transparentGzip = false;
    if (userRequest.header("Accept-Encoding") == null && userRequest.header("Range") == null) {
      transparentGzip = true;
      requestBuilder.header("Accept-Encoding", "gzip");
    }
```

cookie部分
```java
   List<Cookie> cookies = cookieJar.loadForRequest(userRequest.url());
    if (!cookies.isEmpty()) {
      requestBuilder.header("Cookie", cookieHeader(cookies));
    }
```
进入cookHeader方法中
```java
/** Returns a 'Cookie' HTTP request header with all cookies, like {@code a=b; c=d}. */
  private String cookieHeader(List<Cookie> cookies) {
    StringBuilder cookieHeader = new StringBuilder();
    for (int i = 0, size = cookies.size(); i < size; i++) {
      if (i > 0) {
        cookieHeader.append("; ");
      }
      Cookie cookie = cookies.get(i);
      cookieHeader.append(cookie.name()).append('=').append(cookie.value());
    }
    return cookieHeader.toString();
  }
```

之后就是进入下一个拦截器中，并将最后的响应返回
```java
  Response networkResponse = chain.proceed(requestBuilder.build());
```

在获得响应后，如果有cookie，则保存
```java
HttpHeaders.receiveHeaders(cookieJar, userRequest.url(), networkResponse.headers());
```
```java
 public static void receiveHeaders(CookieJar cookieJar, HttpUrl url, Headers headers) {
    if (cookieJar == CookieJar.NO_COOKIES) return;

    List<Cookie> cookies = Cookie.parseAll(url, headers);
    if (cookies.isEmpty()) return;

    cookieJar.saveFromResponse(url, cookies);
  }
```

下面就是对response的解压工作，将流转换为直接能使用的response，然后对header进行了一些处理构建了一个response返回给上一个拦截器。
```java
 if (transparentGzip
        && "gzip".equalsIgnoreCase(networkResponse.header("Content-Encoding"))
        && HttpHeaders.hasBody(networkResponse)) {
      GzipSource responseBody = new GzipSource(networkResponse.body().source());
      Headers strippedHeaders = networkResponse.headers().newBuilder()
          .removeAll("Content-Encoding")
          .removeAll("Content-Length")
          .build();
      responseBuilder.headers(strippedHeaders);
      String contentType = networkResponse.header("Content-Type");
      responseBuilder.body(new RealResponseBody(contentType, -1L, Okio.buffer(responseBody)));
    }

    return responseBuilder.build();
```
#### 2. 总结
从上面的代码可以看出了，先获取原请求头，然后在请求中添加请求头，然后在根据需求，决定是否要填充Cookie，在对原始请求做出处理后，使用chain的procced方法得到响应，接下来对响应做处理得到用户响应，最后返回响应。
### 六.CacheInterceptor类
也同上一个拦截器一样，在执行 Response networkResponse = chain.proceed(requestBuilder.build())时，执行下一个拦截器，即CacheInterceptor类缓存拦截器。

#### 1.传入参数
先看CacheInterceptor创建时传入的参数
```java
interceptors.add(new CacheInterceptor(client.internalCache()));
```
查看client的internalCache方法，可以看出。CacheInterceptor使用OkHttpClient的internalCache方法的返回值作为参数
```java
  InternalCache internalCache() {
    return cache != null ? cache.internalCache : internalCache;
  }
```

而Cache和InternalCache都是OkHttpClient.Builder中可以设置的，而其设置会互相抵消，代码如下：
```java
   /** Sets the response cache to be used to read and write cached responses. */
    void setInternalCache(@Nullable InternalCache internalCache) {
      this.internalCache = internalCache;
      this.cache = null;
    }

    /** Sets the response cache to be used to read and write cached responses. */
    public Builder cache(@Nullable Cache cache) {
      this.cache = cache;
      this.internalCache = null;
      return this;
    }

```
默认的，如果没有对Builder进行缓存设置，那么cache和internalCache都为null，那么传入到CacheInterceptor中的也是null

具体的缓存类cache我会在之后的博客里进行详细的分析

#### 2.缓存策略
接下来进入CacheInterceptor的intercept方法中
下面这段代码是获得缓存响应 和获得响应策略
```java
//CacheInterceptor.intercept（）中
//得到候选响应
Response cacheCandidate = cache != null
        ? cache.get(chain.request())
        : null;

    long now = System.currentTimeMillis();

     //根据请求以及缓存响应得出缓存策略
    CacheStrategy strategy = new CacheStrategy.Factory(now, chain.request(), cacheCandidate).get();
    Request networkRequest = strategy.networkRequest; //网络请求，如果为null就代表不用进行网络请求
    Response cacheResponse = strategy.cacheResponse;//缓存响应，如果为null，则代表不使用缓存
```

进入查看CacheStrategy中的Factory类
```java
//CacheStrategy.Factory类
//构造方法
 public Factory(long nowMillis, Request request, Response cacheResponse) {
      this.nowMillis = nowMillis;
      this.request = request;
      this.cacheResponse = cacheResponse;

      if (cacheResponse != null) {
        this.sentRequestMillis = cacheResponse.sentRequestAtMillis();
        this.receivedResponseMillis = cacheResponse.receivedResponseAtMillis();
        Headers headers = cacheResponse.headers();

        //获取响应头的各种信息
        for (int i = 0, size = headers.size(); i < size; i++) {
          String fieldName = headers.name(i);
          String value = headers.value(i);
          if ("Date".equalsIgnoreCase(fieldName)) {
            servedDate = HttpDate.parse(value);
            servedDateString = value;
          } else if ("Expires".equalsIgnoreCase(fieldName)) {
            expires = HttpDate.parse(value);
          } else if ("Last-Modified".equalsIgnoreCase(fieldName)) {
            lastModified = HttpDate.parse(value);
            lastModifiedString = value;
          } else if ("ETag".equalsIgnoreCase(fieldName)) {
            etag = value;
          } else if ("Age".equalsIgnoreCase(fieldName)) {
            ageSeconds = HttpHeaders.parseSeconds(value, -1);
          }
        }
      }
    }
```
继续查看Factory的get方法
```java
//CacheStrategy.Factory类
    public CacheStrategy get() {
      CacheStrategy candidate = getCandidate();

      //如果设置取消缓存
      if (candidate.networkRequest != null && request.cacheControl().onlyIfCached()) {
        // We're forbidden from using the network and the cache is insufficient.
        return new CacheStrategy(null, null);
      }

      return candidate;
    }

```
继续查看getCandidate()方法,可以看出，在这个方法里，就是最终决定缓存策略的方法
```java
//CacheStrategy.Factory类
private CacheStrategy getCandidate() {
      // No cached response.
      //如果没有response的缓存，那就使用请求。
      if (cacheResponse == null) {
        return new CacheStrategy(request, null);
      }

      // Drop the cached response if it's missing a required handshake.
      //如果请求是https的并且没有握手，那么重新请求。
      if (request.isHttps() && cacheResponse.handshake() == null) {
        return new CacheStrategy(request, null);
      }

      // If this response shouldn't have been stored, it should never be used
      // as a response source. This check should be redundant as long as the
      // persistence store is well-behaved and the rules are constant.
      //如果response是不该被缓存的，就请求，isCacheable()内部是根据状态码判断的。
      if (!isCacheable(cacheResponse, request)) {
        return new CacheStrategy(request, null);
      }
       
      //如果请求指定不使用缓存响应，或者是可选择的，就重新请求。
      CacheControl requestCaching = request.cacheControl();
      if (requestCaching.noCache() || hasConditions(request)) {
        return new CacheStrategy(request, null);
      }

      //强制使用缓存
      CacheControl responseCaching = cacheResponse.cacheControl();
      if (responseCaching.immutable()) {
        return new CacheStrategy(null, cacheResponse);
      }

      long ageMillis = cacheResponseAge();
      long freshMillis = computeFreshnessLifetime();

      if (requestCaching.maxAgeSeconds() != -1) {
        freshMillis = Math.min(freshMillis, SECONDS.toMillis(requestCaching.maxAgeSeconds()));
      }

      long minFreshMillis = 0;
      if (requestCaching.minFreshSeconds() != -1) {
        minFreshMillis = SECONDS.toMillis(requestCaching.minFreshSeconds());
      }

      long maxStaleMillis = 0;
      if (!responseCaching.mustRevalidate() && requestCaching.maxStaleSeconds() != -1) {
        maxStaleMillis = SECONDS.toMillis(requestCaching.maxStaleSeconds());
      }

       //如果response有缓存，并且时间比较近，添加一些头部信息后，返回request = null的策略
       /（意味着虽过期，但可用，只是会在响应头添加warning）
      if (!responseCaching.noCache() && ageMillis + minFreshMillis < freshMillis + maxStaleMillis) {
        Response.Builder builder = cacheResponse.newBuilder();
        if (ageMillis + minFreshMillis >= freshMillis) {
          builder.addHeader("Warning", "110 HttpURLConnection \"Response is stale\"");
        }
        long oneDayMillis = 24 * 60 * 60 * 1000L;
        if (ageMillis > oneDayMillis && isFreshnessLifetimeHeuristic()) {
          builder.addHeader("Warning", "113 HttpURLConnection \"Heuristic expiration\"");
        }
        return new CacheStrategy(null, builder.build());
      }

      // Find a condition to add to the request. If the condition is satisfied, the response body
      // will not be transmitted.
      String conditionName;
      //流程走到这，说明缓存已经过期了
      //添加请求头：If-Modified-Since或者If-None-Match
      //etag与If-None-Match配合使用
      //lastModified与If-Modified-Since配合使用
      //前者和后者的值是相同的
      //区别在于前者是响应头，后者是请求头。
      //后者用于服务器进行资源比对，看看是资源是否改变了。
      // 如果没有，则本地的资源虽过期还是可以用的      String conditionValue;

      if (etag != null) {
        conditionName = "If-None-Match";
        conditionValue = etag;
      } else if (lastModified != null) {
        conditionName = "If-Modified-Since";
        conditionValue = lastModifiedString;
      } else if (servedDate != null) {
        conditionName = "If-Modified-Since";
        conditionValue = servedDateString;
      } else {
        return new CacheStrategy(request, null); // No condition! Make a regular request.
      }

      Headers.Builder conditionalRequestHeaders = request.headers().newBuilder();
      Internal.instance.addLenient(conditionalRequestHeaders, conditionName, conditionValue);

      Request conditionalRequest = request.newBuilder()
          .headers(conditionalRequestHeaders.build())
          .build();
      return new CacheStrategy(conditionalRequest, cacheResponse);
    }
```
CacheStrategy的构造方法
```java
 CacheStrategy(Request networkRequest, Response cacheResponse) {
    this.networkRequest = networkRequest;
    this.cacheResponse = cacheResponse;
  }
```
看完CacheStrategy吗，让我们重写回到intercept                                                                                           
#### 3.执行策略
intercept中执行策略的部分
```java
//intercept中
     //根据缓存策略，更新统计指标：请求次数、使用网络请求次数、使用缓存次数
    if (cache != null) {
      cache.trackResponse(strategy);
    }
 
    //缓存不可用，关闭
    if (cacheCandidate != null && cacheResponse == null) {
      closeQuietly(cacheCandidate.body()); // The cache candidate wasn't applicable. Close it.
    }

    //如果既无网络请求可用，又无缓存，返回504错误
    // If we're forbidden from using the network and the cache is insufficient, fail.
    if (networkRequest == null && cacheResponse == null) {
      return new Response.Builder()
          .request(chain.request())
          .protocol(Protocol.HTTP_1_1)
          .code(504)
          .message("Unsatisfiable Request (only-if-cached)")
          .body(Util.EMPTY_RESPONSE)
          .sentRequestAtMillis(-1L)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build();
    }

    // If we don't need the network, we're done.
    //缓存可用，直接返回缓存
    if (networkRequest == null) {
      return cacheResponse.newBuilder()
          .cacheResponse(stripBody(cacheResponse))
          .build();
    }
```
#### 4.进行网络请求
intercept中进行网络请求的部分
```java
//intercept中
 Response networkResponse = null;
    try {
      //进行网络请求-->调用下一个拦截器
      networkResponse = chain.proceed(networkRequest);
    } finally {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        closeQuietly(cacheCandidate.body());
      }
    }

    // If we have a cache response too, then we're doing a conditional get.
    if (cacheResponse != null) {

      //响应码为304，缓存有效，合并网络请求和缓存
      //304 请求资源未修改
      if (networkResponse.code() == HTTP_NOT_MODIFIED) {
        Response response = cacheResponse.newBuilder()
            .headers(combine(cacheResponse.headers(), networkResponse.headers()))
            .sentRequestAtMillis(networkResponse.sentRequestAtMillis())
            .receivedResponseAtMillis(networkResponse.receivedResponseAtMillis())
            .cacheResponse(stripBody(cacheResponse))
            .networkResponse(stripBody(networkResponse))
            .build();
        networkResponse.body().close();

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        //在合并头部之后更新缓存，但是在剥离内容编码头之前（由initContentStream（）执行）。
        cache.trackConditionalCacheHit();
        cache.update(cacheResponse, response);
        return response;
      } else {
        closeQuietly(cacheResponse.body());
      }
    }

    Response response = networkResponse.newBuilder()
        .cacheResponse(stripBody(cacheResponse))
        .networkResponse(stripBody(networkResponse))
        .build();

    if (cache != null) {
      //如果有响应体并且可缓存，那么将响应写入缓存。
      if (HttpHeaders.hasBody(response) && CacheStrategy.isCacheable(response, networkRequest)) {
        // Offer this request to the cache.
        CacheRequest cacheRequest = cache.put(response);
        return cacheWritingResponse(cacheRequest, response);
      }

      //如果request无效
      if (HttpMethod.invalidatesCache(networkRequest.method())) {
        try {
        //从缓存删除
          cache.remove(networkRequest);
        } catch (IOException ignored) {
          // The cache cannot be written.
        }
      }
    }

    return response;
```
#### 5.流程图
![这里写图片描述](https://img-blog.csdn.net/20180913192931430?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 七.ConnectInterceptor类
ConnectInterceptor,是一个连接相关的拦截器,作用就是打开与服务器之间的连接，正式开启OkHttp的网络请求

首先还是先看ConnectInterceptor类的intercept方法
#### 1. intercept
```java
 @Override public Response intercept(Chain chain) throws IOException {
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    Request request = realChain.request();
    //首先从realChain拿到了streamAllocation对象，这个对象在RetryAndFollowInterceptor中就已经初始化过了
    //只不过一直没有使用，到了ConnectTnterceptor才使用。
    StreamAllocation streamAllocation = realChain.streamAllocation();

    // We need the network to satisfy this request. Possibly for validating a conditional GET.
    //判断是否为GET请求
    boolean doExtensiveHealthChecks = !request.method().equals("GET");
    //生成一个HttpCodec对象。这个对象是用于编码request和解码response的一个封装好的对象。
    HttpCodec httpCodec = streamAllocation.newStream(client, chain, doExtensiveHealthChecks);
    RealConnection connection = streamAllocation.connection();

    //将创建好的HttpCode和connection对象传递给下一个拦截器
    return realChain.proceed(request, streamAllocation, httpCodec, connection);
  }
```
#### 2.总结
关于连接拦截器更多的内容，可以看下一篇博客，okHttp的网络操作部分。这里我们只是做一个简单的分析并不深入其中，我们继续来看下一个拦截器。即CallServerInterceptor拦截器。


### 八.CallServerInterceptor类
CallServerInterceptor是拦截器链中最后一个拦截器，负责将网络请求提交给服务器。它的intercept方法实现如下：

#### 1.intercept
准备工作，首先是获得各种对象，然后将请求写入 httpCodec中
```java
@Override public Response intercept(Chain chain) throws IOException {
    RealInterceptorChain realChain = (RealInterceptorChain) chain;
    HttpCodec httpCodec = realChain.httpStream();

  
    StreamAllocation streamAllocation = realChain.streamAllocation();
    //上一步已经完成连接工作的连接
    RealConnection connection = (RealConnection) realChain.connection();
    Request request = realChain.request();

    long sentRequestMillis = System.currentTimeMillis();

    realChain.eventListener().requestHeadersStart(realChain.call());
    //将请求头写入
    httpCodec.writeRequestHeaders(request);
    realChain.eventListener().requestHeadersEnd(realChain.call(), request)；
```
再将请求头写入后，会有一个关于Expect:100-continue的请求头处理。
> http 100-continue用于客户端在发送POST数据给服务器前，征询服务器情况，看服务器是否处理POST的数据，如果不处理，客户端则不上传POST数据，如果处理，则POST上传数据。在现实应用中，通过在POST大数据时，才会使用100-continue协议。如果服务器端可以处理，则会返回100，负责会返回错误码

```java
if ("100-continue".equalsIgnoreCase(request.header("Expect"))) { //如果有Expect:100-continue的请求头
        httpCodec.flushRequest();
        realChain.eventListener().responseHeadersStart(realChain.call());
        responseBuilder = httpCodec.readResponseHeaders(true); //读取响应头
      }
```
当返回的结果为null，或者不存在Expect:100-continue的请求头，则执行下面的代码，
```java
  if (responseBuilder == null) {
        // Write the request body if the "Expect: 100-continue" expectation was met.
        realChain.eventListener().requestBodyStart(realChain.call());
        long contentLength = request.body().contentLength();
        CountingSink requestBodyOut =
            new CountingSink(httpCodec.createRequestBody(request, contentLength));
        BufferedSink bufferedRequestBody = Okio.buffer(requestBodyOut);

        request.body().writeTo(bufferedRequestBody); //写响应体
        bufferedRequestBody.close();
        realChain.eventListener()
            .requestBodyEnd(realChain.call(), requestBodyOut.successfulCount);
      } else if (!connection.isMultiplexed()) { //判断是否为http2.0，如果不是则关闭
                                                // 因为http2.0可以多路复用，这个连接可以复用。
        // If the "Expect: 100-continue" expectation wasn't met, prevent the HTTP/1 connection
        // from being reused. Otherwise we're still obligated to transmit the request body to
        // leave the connection in a consistent state.
        streamAllocation.noNewStreams();//关闭连接
      }
```
如果没有经历上面的Expect:100-continue的请求头，则重新请求一次。
```java
  httpCodec.finishRequest();

    if (responseBuilder == null) {
      realChain.eventListener().responseHeadersStart(realChain.call());
      responseBuilder = httpCodec.readResponseHeaders(false);
    }

```
将请求的结果(可能是Expect:100-continue请求的结果，也可能是正常的情况下)包装成response。
```java
 Response response = responseBuilder
        .request(request)
        .handshake(streamAllocation.connection().handshake())
        .sentRequestAtMillis(sentRequestMillis)
        .receivedResponseAtMillis(System.currentTimeMillis())
        .build();
```
如果请求的返回码为100(继续。客户端应继续其请求)
```java
 int code = response.code();
    if (code == 100) {
      // server sent a 100-continue even though we did not request one.
      // try again to read the actual response
      responseBuilder = httpCodec.readResponseHeaders(false); //重新请求一次

      response = responseBuilder //覆盖之前的响应
              .request(request)
              .handshake(streamAllocation.connection().handshake())
              .sentRequestAtMillis(sentRequestMillis)
              .receivedResponseAtMillis(System.currentTimeMillis())
              .build();

      code = response.code();
    }
```
判断是否是是websocket并且响应码为101(切换协议)
```java
if (forWebSocket && code == 101) {
      // Connection is upgrading, but we need to ensure interceptors see a non-null response body.
      response = response.newBuilder()
          .body(Util.EMPTY_RESPONSE)//赋空值
          .build();
    } else {
      response = response.newBuilder()
          .body(httpCodec.openResponseBody(response)) //填充response的body
          .build();
    }

```
从请求头和响应头判断其中是否有表明需要保持连接打开
```java
  if ("close".equalsIgnoreCase(response.request().header("Connection"))  
        || "close".equalsIgnoreCase(response.header("Connection"))) {
      streamAllocation.noNewStreams();
    }
```
处理204(无内容)和205(重置内容)
```java
 if ((code == 204 || code == 205) && response.body().contentLength() > 0) {
      throw new ProtocolException(
          "HTTP " + code + " had non-zero Content-Length: " + response.body().contentLength());
    }
```
最后将response返回给上一个拦截器

#### 2.流程图

![这里写图片描述](https://img-blog.csdn.net/20180914141718167?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 九.总结
经过上面这一篇和上一篇文章的分析，大家应该对OkHttp的整体流程有了一个比较深入的了解了吧，这里我最后用一种流程图总结一下。

![这里写图片描述](https://img-blog.csdn.net/20180914142852842?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 十. 参考资料
[深入理解OkHttp源码（二）——获取响应](https://blog.csdn.net/qq_19431333/article/details/53207220)
[OkHttp 3.7源码分析（二）——拦截器&一个实际网络请求的实现](https://yq.aliyun.com/articles/78104?spm=a2c4e.11153940.blogcont78105.12.182237be0CB6ln)
[okhttp源码解析](https://blog.csdn.net/json_it/article/details/78404010)
[OkHttp源码（三）](https://www.jianshu.com/p/14b60bbedb01)

### 十一.文章索引
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
