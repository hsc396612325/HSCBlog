---
title: "Android之网络请求8————OkHttp源码5:缓存相关"
date: 2019-02-08T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.前言
这是OKHttp的源码分析第五篇，主要分析的是OKHttp的缓存相关。在前面的文章中，我们也简单写过OKHttp的缓存相关。在[ Android之网络请求2————OkHttp的基本使用 ](https://blog.csdn.net/qq_38499859/article/details/82290738)中写了如何使用缓存。在[Android之网络请求6————OkHttp源码3:拦截器链 ](https://blog.csdn.net/qq_38499859/article/details/82630630)中写了缓存拦截器，并在其中分析了缓存策略相关的源码。

在这里我们来详细的分析一下OKHttp的缓存相关。

### 二.Cache-Control
OkHttp根据HTTP头部中的CacheControl进行缓存控制。
#### 1.HTTP中的Cache-Control首部
HTTP中关于缓存部分的可以查看这篇博客[彻底弄懂HTTP缓存机制及原理](https://www.cnblogs.com/chenqf/p/6386163.html)，看完之后对OKHttp中关于缓存的部分有很大的帮助。

HTTP头部中的Cache-Control首部可以指示对应请求该如何获取响应，比如应该直接使用缓存的响应还是应该从网络获取响应；可以指示响应该如何缓存，比如是否应该缓存下来还是设置一个过期时间等。Cache-Control首部的一些值既可以用于请求首部又可以用于响应首部。具体的值有no-cache、nostore、max-age、s-maxage、only-if-cached等。

#### 2.  OkHttp中的CacheControl类 
CacheControl类是对HTTP的Cache-Control首部的描述。CacheControl没有公共的构造方法，内部通过一个Builder进行设置值，获取值可以通过CacheControl对象进行获取。Builder中具体有如下设置方法： 
```java
 CacheControl(Builder builder) {
    this.noCache = builder.noCache;
    this.noStore = builder.noStore;
    this.maxAgeSeconds = builder.maxAgeSeconds;
    this.sMaxAgeSeconds = -1;
    this.isPrivate = false;
    this.isPublic = false;
    this.mustRevalidate = false;
    this.maxStaleSeconds = builder.maxStaleSeconds;
    this.minFreshSeconds = builder.minFreshSeconds;
    this.onlyIfCached = builder.onlyIfCached;
    this.noTransform = builder.noTransform;
    this.immutable = builder.immutable;
  }

```
- noCache()
对应于“no-cache”，如果出现在响应首部，不是表示不允许对响应进行缓存，而是表示客户端需要与服务器进行再验证，进行一个额外的GET请求得到最新的响应；如果出现在请求首部，表示不适用缓存响应，即进行网络请求得到响应
- noStore()
对应于“no-store”，只能出现在响应首部，表明该响应不应该被缓存
- maxAge(int maxAge, TimeUnit timeUnit)
对应于“max-age”，设置缓存响应的最大存活时间。如果缓存响应达到了最大存活时间，那么将不会再使用而会进行网络请求
- maxStale(int maxStale,TimeUnit timeUnit)
对应于“max-stale”，缓存响应可以接受的最大过期时间，如果没有指定该参数，那么过期缓存响应将不会使用。
- minFresh(int minFresh,TimeUnit timeUnit)
对应于“min-fresh”，设置一个响应将会持续刷新的最小秒数。如果一个响应当minFresh过去后过期了，那么缓存响应不会再使用了，会进行网络请求。
- onlyIfCached()
对应于“onlyIfCached”，用于请求首部，表明该请求只接受缓存中的响应。如果缓存中没有响应，那么返回一个状态码为504的响应。
CacheControl类中还有其他方法，这里就不一一介绍了。想了解的可以去API文档查看。 
### 三.Cache类
Cache中很多方法都是通过DiskLruCache实现的，对于DiskLruCache的使用可以参考下面两篇博客。 
[Android DiskLruCache完全解析，硬盘缓存的最佳方案](https://blog.csdn.net/guolin_blog/article/details/28863651)
[Android DiskLruCache 源码解析 硬盘缓存的绝佳方案](http://blog.csdn.net/lmj623565791/article/details/47251585)
OKHttp在DiskLruCache的基础上进行了修改，将IO操作改成了OKio

在OkHttp中Cache负责将响应缓存到文件中，以便可以重用和减少带宽。
在Cache类内部又一个InternalCache的实现了类
```java
 //根据请求得到响应
 final InternalCache internalCache = new InternalCache() {
    @Override public Response get(Request request) throws IOException {
      return Cache.this.get(request);
    }
 //缓存响应
    @Override public CacheRequest put(Response response) throws IOException {
      return Cache.this.put(response);
    }

//移出响应
    @Override public void remove(Request request) throws IOException {
      Cache.this.remove(request);
    }

//更新响应
    @Override public void update(Response cached, Response network) {
      Cache.this.update(cached, network);
    }

    @Override public void trackConditionalCacheHit() {
      Cache.this.trackConditionalCacheHit();
    }

    @Override public void trackResponse(CacheStrategy cacheStrategy) {
      Cache.this.trackResponse(cacheStrategy);
    }
  };
```
在代码中可以看出来，ternalCache接口中的每个方法的实现都交给了外部类Cache，所以主要看Cache类中的各个方法，而Cache类的这些方法又主要交给了DiskLruCache来实现。 
#### 1.缓存响应
首先来看缓存响应的Put方法
```java
@Nullable CacheRequest put(Response response) {
    //得到请求的方法
    String requestMethod = response.request().method();

    if (HttpMethod.invalidatesCache(response.request().method())) {
      try {
        remove(response.request());
      } catch (IOException ignored) {
        // The cache cannot be written.
      }
      return null;
    }
    
//不缓存非GET方法
    if (!requestMethod.equals("GET")) {
      // Don't cache non-GET responses. We're technically allowed to cache
      // HEAD requests and some POST requests, but the complexity of doing
      // so is high and the benefit is low.
      return null;
    }

    //如果请求头中如果含有星号，也不进行缓存
    if (HttpHeaders.hasVaryAll(response)) {
      return null;
    }

   //使用DiskLruCache进行缓冲
    Entry entry = new Entry(response);
    DiskLruCache.Editor editor = null;
    try {
      editor = cache.edit(key(response.request().url()));
      if (editor == null) {
        return null;
      }
      entry.writeTo(editor);
      return new CacheRequestImpl(editor);
    } catch (IOException e) {
      abortQuietly(editor);
      return null;
    }
  }
```
上面的代码对请求进行判断，如果满足条件，则使用响应创建一个Entry，然后使用DiskLruCache写入缓存，最终返回一个CacheRequestImpl对象。cache是DiskLruCache的实例，调用edit方法传入响应的key值。下面是Key方法的实现：
```java
public static String key(HttpUrl url) {
    return ByteString.encodeUtf8(url.toString()).md5().hex(); //对其请求的Url做MD5，然后获得其值。
  }
```
然后查看edit方法
```java
 /**
   * Returns an editor for the entry named {@code key}, or null if another edit is in progress.
   */
  public @Nullable Editor edit(String key) throws IOException {
    return edit(key, ANY_SEQUENCE_NUMBER);
  }

  synchronized Editor edit(String key, long expectedSequenceNumber) throws IOException {
    initialize(); //初始化

    checkNotClosed();
    validateKey(key);
    Entry entry = lruEntries.get(key);//通过key获得entry
    if (expectedSequenceNumber != ANY_SEQUENCE_NUMBER && (entry == null
        || entry.sequenceNumber != expectedSequenceNumber)) {
      return null; // Snapshot is stale.
    }
    if (entry != null && entry.currentEditor != null) {
      return null; // Another edit is in progress. // 当前cache entry正在被其他对象操作
    }
    if (mostRecentTrimFailed || mostRecentRebuildFailed) {
      // The OS has become our enemy! If the trim job failed, it means we are storing more data than
      // requested by the user. Do not allow edits so we do not go over that limit any further. If
      // the journal rebuild failed, the journal writer will not be active, meaning we will not be
      // able to record the edit, causing file leaks. In both cases, we want to retry the clean up
      // so we can get out of this state!
      executor.execute(cleanupRunnable);
      return null;
    }
    
  // 日志接入DIRTY记录
    // Flush the journal before creating files to prevent file leaks.
    journalWriter.writeUtf8(DIRTY).writeByte(' ').writeUtf8(key).writeByte('\n');
    journalWriter.flush();

    if (hasJournalErrors) {
      return null; // Don't edit; the journal can't be written.
    }

    if (entry == null) {
      entry = new Entry(key);
      lruEntries.put(key, entry);
    }
    Editor editor = new Editor(entry);
    entry.currentEditor = editor;
    return editor;
  }
```
在这里获得Editor后，然后调用editor.writeTo(editor),将editor写入
```java
public void writeTo(DiskLruCache.Editor editor) throws IOException {
      BufferedSink sink = Okio.buffer(editor.newSink(ENTRY_METADATA));

      //缓存请求有关信息
      sink.writeUtf8(url)
          .writeByte('\n');
      sink.writeUtf8(requestMethod)
          .writeByte('\n');
      sink.writeDecimalLong(varyHeaders.size())
          .writeByte('\n');
      for (int i = 0, size = varyHeaders.size(); i < size; i++) {
        sink.writeUtf8(varyHeaders.name(i))
            .writeUtf8(": ")
            .writeUtf8(varyHeaders.value(i))
            .writeByte('\n');
      }
       
       //缓存Http响应行
      sink.writeUtf8(new StatusLine(protocol, code, message).toString())
          .writeByte('\n');
       //缓存响应首部
      sink.writeDecimalLong(responseHeaders.size() + 2)
          .writeByte('\n');
      for (int i = 0, size = responseHeaders.size(); i < size; i++) {
        sink.writeUtf8(responseHeaders.name(i))
            .writeUtf8(": ")
            .writeUtf8(responseHeaders.value(i))
            .writeByte('\n');
      }
      sink.writeUtf8(SENT_MILLIS)
          .writeUtf8(": ")
          .writeDecimalLong(sentRequestMillis)
          .writeByte('\n');
      sink.writeUtf8(RECEIVED_MILLIS)
          .writeUtf8(": ")
          .writeDecimalLong(receivedResponseMillis)
          .writeByte('\n');

   //是Https请求，缓存握手，证书信息
      if (isHttps()) {
        sink.writeByte('\n');
        sink.writeUtf8(handshake.cipherSuite().javaName())
            .writeByte('\n');
        writeCertList(sink, handshake.peerCertificates());
        writeCertList(sink, handshake.localCertificates());
        sink.writeUtf8(handshake.tlsVersion().javaName()).writeByte('\n');
      }
      sink.close();
    }
```
上面的代码里面有，将响应头的头部信息还有请求头的部分信息(URL 请求方法 请求头部)进行缓存。同时对于一个请求和响应而言，缓存中的key值是请求的URL的MD5值，而value包括请求和响应部分。Entry的writeTo()方法只把请求的头部和响应的头部保存了，最关键的响应主体部分在哪里保存呢？它就在put方法的返回体CacheRequestImpl，下面是这个类的实现：
```java
private final class CacheRequestImpl implements CacheRequest {
    private final DiskLruCache.Editor editor;
    private Sink cacheOut;
    private Sink body;
    boolean done;

    CacheRequestImpl(final DiskLruCache.Editor editor) {
      this.editor = editor;
      this.cacheOut = editor.newSink(ENTRY_BODY);
      this.body = new ForwardingSink(cacheOut) {
        @Override public void close() throws IOException {
          synchronized (Cache.this) {
            if (done) {
              return;
            }
            done = true;
            writeSuccessCount++;
          }
          super.close();
          editor.commit();
        }
      };
    }

    @Override public void abort() {
      synchronized (Cache.this) {
        if (done) {
          return;
        }
        done = true;
        writeAbortCount++;
      }
      Util.closeQuietly(cacheOut);
      try {
        editor.abort();
      } catch (IOException ignored) {
      }
    }

    @Override public Sink body() {
      return body;
    }
  }
```
中close,abort方法会调用editor.abort和editor.commit来更新日志，editor.commit还会将dirtyFile重置为cleanFile作为稳定可用的缓存，先看adort方法
```java
public void abort() throws IOException {
      synchronized (DiskLruCache.this) {
        if (done) {
          throw new IllegalStateException();
        }
        if (entry.currentEditor == this) {
          completeEdit(this, false);
        }
        done = true;
      }
    }
```
继续来看 completeEdit()方法
```java
  synchronized void completeEdit(Editor editor, boolean success) throws IOException {
    Entry entry = editor.entry;
    if (entry.currentEditor != editor) {
      throw new IllegalStateException();
    }

    // If this edit is creating the entry for the first time, every index must have a value.
    //如果这辑第一次创建条目，那么每个索引都必须有一个值。
    if (success && !entry.readable) {
      for (int i = 0; i < valueCount; i++) {
        if (!editor.written[i]) {
          editor.abort();
          throw new IllegalStateException("Newly created entry didn't create value for index " + i);
        }
        if (!fileSystem.exists(entry.dirtyFiles[i])) {
          editor.abort();
          return;
        }
      }
    }

    for (int i = 0; i < valueCount; i++) {
      File dirty = entry.dirtyFiles[i];
      if (success) {
        if (fileSystem.exists(dirty)) {
          File clean = entry.cleanFiles[i];
          fileSystem.rename(dirty, clean);
          long oldLength = entry.lengths[i];
          long newLength = fileSystem.size(clean);
          entry.lengths[i] = newLength;
          size = size - oldLength + newLength;
        }
      } else {
        fileSystem.delete(dirty);//若失败则删除dirtyfile
      }
    }

    redundantOpCount++;
    entry.currentEditor = null;
    //更新日志
    if (entry.readable | success) {
      entry.readable = true;
      journalWriter.writeUtf8(CLEAN).writeByte(' ');
      journalWriter.writeUtf8(entry.key);
      entry.writeLengths(journalWriter);
      journalWriter.writeByte('\n');
      if (success) {
        entry.sequenceNumber = nextSequenceNumber++;
      }
    } else {
      lruEntries.remove(entry.key);
      journalWriter.writeUtf8(REMOVE).writeByte(' ');
      journalWriter.writeUtf8(entry.key);
      journalWriter.writeByte('\n');
    }
    journalWriter.flush();

    if (size > maxSize || journalRebuildRequired()) {
      executor.execute(cleanupRunnable);
    }
  }
```
#### 2.获取缓存
获取缓存在get方法里
```java
  @Nullable Response get(Request request) {
    //获得key值
    String key = key(request.url());
     //从DiskLruCache中得到缓存
    DiskLruCache.Snapshot snapshot;
    Entry entry;
    try {
      snapshot = cache.get(key);
      if (snapshot == null) {  //如果没有找到
        return null;
      }
    } catch (IOException e) {
      // Give up because the cache cannot be read.
      return null;
    }

    try {
      entry = new Entry(snapshot.getSource(ENTRY_METADATA)); //创建entry对象
    } catch (IOException e) {
      Util.closeQuietly(snapshot);
      return null;
    }

    Response response = entry.response(snapshot); //获得响应对象

    if (!entry.matches(request, response)) { //如果请求和响应不匹配
      Util.closeQuietly(response.body());
      return null;
    }

    return response;
  }
```
#### 3.Entry
首先来看其构造方法
```java
 Entry(Source in) throws IOException {
      try {
        BufferedSource source = Okio.buffer(in);
        //读取请求相关的信息
        url = source.readUtf8LineStrict();
        requestMethod = source.readUtf8LineStrict();
        Headers.Builder varyHeadersBuilder = new Headers.Builder();
        int varyRequestHeaderLineCount = readInt(source);
        for (int i = 0; i < varyRequestHeaderLineCount; i++) {
          varyHeadersBuilder.addLenient(source.readUtf8LineStrict());
        }
        varyHeaders = varyHeadersBuilder.build();

          //读响应状态行
        StatusLine statusLine = StatusLine.parse(source.readUtf8LineStrict());
        protocol = statusLine.protocol;
        code = statusLine.code;
        message = statusLine.message;

       //读响应行状态
        Headers.Builder responseHeadersBuilder = new Headers.Builder();
        int responseHeaderLineCount = readInt(source);
        for (int i = 0; i < responseHeaderLineCount; i++) {
          responseHeadersBuilder.addLenient(source.readUtf8LineStrict());
        }
        String sendRequestMillisString = responseHeadersBuilder.get(SENT_MILLIS);
        String receivedResponseMillisString = responseHeadersBuilder.get(RECEIVED_MILLIS);
        responseHeadersBuilder.removeAll(SENT_MILLIS);
        responseHeadersBuilder.removeAll(RECEIVED_MILLIS);
        sentRequestMillis = sendRequestMillisString != null
            ? Long.parseLong(sendRequestMillisString)
            : 0L;
        receivedResponseMillis = receivedResponseMillisString != null
            ? Long.parseLong(receivedResponseMillisString)
            : 0L;
        responseHeaders = responseHeadersBuilder.build();

        //是Https协议，读握手，证书信息
        if (isHttps()) {
          String blank = source.readUtf8LineStrict();
          if (blank.length() > 0) {
            throw new IOException("expected \"\" but was \"" + blank + "\"");
          }
          String cipherSuiteString = source.readUtf8LineStrict();
          CipherSuite cipherSuite = CipherSuite.forJavaName(cipherSuiteString);
          List<Certificate> peerCertificates = readCertificateList(source);
          List<Certificate> localCertificates = readCertificateList(source);
          TlsVersion tlsVersion = !source.exhausted()
              ? TlsVersion.forJavaName(source.readUtf8LineStrict())
              : TlsVersion.SSL_3_0;
          handshake = Handshake.get(tlsVersion, cipherSuite, peerCertificates, localCertificates);
        } else {
          handshake = null;
        }
      } finally {
        in.close();
      }
    }

```
在put方法中我们知道了缓存中保存了请求的信息和响应的信息，这个构造方法主要用于从缓存中解析出各个字段。当获得这些信息后，就可以用过response() (get方法最后的调用)获得对应的响应
```java
public Response response(DiskLruCache.Snapshot snapshot) {
      String contentType = responseHeaders.get("Content-Type");
      String contentLength = responseHeaders.get("Content-Length");
      Request cacheRequest = new Request.Builder()  //缓存的请求
          .url(url)
          .method(requestMethod, null)
          .headers(varyHeaders)
          .build();
      return new Response.Builder()//缓存的响应
          .request(cacheRequest)
          .protocol(protocol)
          .code(code)
          .message(message)
          .headers(responseHeaders)
          .body(new CacheResponseBody(snapshot, contentType, contentLength)) //获得请求体
          .handshake(handshake)
          .sentRequestAtMillis(sentRequestMillis)
          .receivedResponseAtMillis(receivedResponseMillis)
          .build();
    }
```
查看 CacheResponseBody类的构造方法
```java
  CacheResponseBody(final DiskLruCache.Snapshot snapshot,
        String contentType, String contentLength) {
      this.snapshot = snapshot;
      this.contentType = contentType;
      this.contentLength = contentLength;

      Source source = snapshot.getSource(ENTRY_BODY);
      bodySource = Okio.buffer(new ForwardingSource(source) {
        @Override public void close() throws IOException {
          snapshot.close();
          super.close();
        }
      });
    }
```

上面那个是get方法是的构造方法，Entry还有一种构造方法,即将响应里的内容保存起来。
```java
    Entry(Response response) {
      this.url = response.request().url().toString();
      this.varyHeaders = HttpHeaders.varyHeaders(response);
      this.requestMethod = response.request().method();
      this.protocol = response.protocol();
      this.code = response.code();
      this.message = response.message();
      this.responseHeaders = response.headers();
      this.handshake = response.handshake();
      this.sentRequestMillis = response.sentRequestAtMillis();
      this.receivedResponseMillis = response.receivedResponseAtMillis();
    }
```

#### 4.小结
上面的代码，基本将cache里的内容看了个差不多，分析了缓存的取出和存入，当然还有其他的方法，都比较简单。这里就不过多分析，关于里面涉及的DiskLruCache类，我看的不是很多，之后应该会去看看它以及Okio相关的内容。
### 四.缓存的使用
在okHttp中，如何应用缓存。可以参考我的这篇博客[ Android之网络请求2————OkHttp的基本使用 ](https://blog.csdn.net/qq_38499859/article/details/82290738)

Cache的设置均在OkHttpClient的Builder中设置，有两个方法可以设置，分别是setInternalCache()和cache()方法，如下：
```java
/** Sets the response cache to be used to read and write cached responses. */
    void setInternalCache(InternalCache internalCache) {
      this.internalCache = internalCache;
      this.cache = null;
    }

    public Builder cache(Cache cache) {
      this.cache = cache;
      this.internalCache = null;
      return this;
    }
```

从代码中可以看出，这两个方法会互相消除彼此。在之前讲到的InternalCache类，该类是一个接口，文档中说应用不应该实现该类，所以这儿，我也明白为什么OkHttpClient为什么还提供这样一个接口。
当设置好Cache后，我们再来看下Cache的构造方法：
```java
public Cache(File directory, long maxSize) {
    this(directory, maxSize, FileSystem.SYSTEM);
  }

  Cache(File directory, long maxSize, FileSystem fileSystem) {
    this.cache = DiskLruCache.create(fileSystem, directory, VERSION, ENTRY_COUNT, maxSize);
  }
```
可以看到暴露对外的构造方法只有两个参数，一个目录，一个最大尺寸，而其内部使用的DiskLruCache的create静态工厂方法。这里面FileSystem.SYSTEM是FileSystem接口的一个实现类，该类的各个方法使用Okio对文件I/O进行封装。
DiskLruCache的create()方法中传入的目录将会是缓存的父目录，其中ENTRY_COUNT表示每一个缓存实体中的值的个数，这儿是2。（第一个是请求头部和响应头部，第二个是响应主体部分）至此，Cache和其底层的DiskLruCache创建成功了。 
### 五.CacheInterceptor
在Okhttp缓存的具体执行时机是在缓存拦截器中，关于这一部分在[Android之网络请求6————OkHttp源码3:拦截器链 ](https://blog.csdn.net/qq_38499859/article/details/82630630)中，有比较详细的描述，这里我在简单的写一下
#### 1. intercept
```java
@Override public Response intercept(Chain chain) throws IOException {
    //得到候选缓存响应，可能为空
    Response cacheCandidate = cache != null
        ? cache.get(chain.request())
        : null;

    long now = System.currentTimeMillis();

    //得到缓存策略
    CacheStrategy strategy = new CacheStrategy.Factory(now, chain.request(), cacheCandidate).get();
    Request networkRequest = strategy.networkRequest;
    Response cacheResponse = strategy.cacheResponse;

    if (cache != null) {
      cache.trackResponse(strategy);
    }


    if (cacheCandidate != null && cacheResponse == null) {
      closeQuietly(cacheCandidate.body()); // The cache candidate wasn't applicable. Close it.
    }

    // 只要缓存响应，但是缓存响应不存在，返回504错误
    if (networkRequest == null && cacheResponse == null) {
      return new Response.Builder()
          .request(chain.request())
          .protocol(Protocol.HTTP_1_1)
          .code(504)
          .message("Unsatisfiable Request (only-if-cached)")
          .body(EMPTY_BODY)
          .sentRequestAtMillis(-1L)
          .receivedResponseAtMillis(System.currentTimeMillis())
          .build();
    }

    // 不使用网络，直接返回缓存响应
    if (networkRequest == null) {
      return cacheResponse.newBuilder()
          .cacheResponse(stripBody(cacheResponse))
          .build();
    }

    //进行网络操作获取响应
    Response networkResponse = null;
    try {
      networkResponse = chain.proceed(networkRequest);
    } finally {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        closeQuietly(cacheCandidate.body());
      }
    }

    // 如果也有缓存响应，则需要检查缓存响应是否需要进行更新
    if (cacheResponse != null) {
      //需要更新
      if (validate(cacheResponse, networkResponse)) {
        Response response = cacheResponse.newBuilder()
            .headers(combine(cacheResponse.headers(), networkResponse.headers()))
            .cacheResponse(stripBody(cacheResponse))
            .networkResponse(stripBody(networkResponse))
            .build();
        networkResponse.body().close();

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
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

    //保存缓存
    if (HttpHeaders.hasBody(response)) {
      CacheRequest cacheRequest = maybeCache(response, networkResponse.request(), cache);
      response = cacheWritingResponse(cacheRequest, response);
    }

    return response;
  }
```
#### 2.缓存策略
进入查看CacheStrategy中的Factory类(工厂类)
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
       
### 六.总结
OKHttp的缓存部分，一个是设置缓存这一方面由用户(程序员自己调用)，还有进行缓存的时机，在缓存拦截器中发生。在获取缓存时，主要是缓存的存和取，这两个是由DiskLruCache+Okio一同实现的，同时在缓存拦截器跟据请求来进行不同的缓存策略。
### 七.参考资料
[深入理解OkHttp源码（四）——缓存](https://blog.csdn.net/qq_19431333/article/details/53513734)
[OkHttp 3.7源码分析（四）——缓存策略](https://yq.aliyun.com/articles/78102?spm=a2c4e.11153940.blogcont78105.14.182237be211CfX)

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
