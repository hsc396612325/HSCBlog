---
title: "Android之网络请求1————HTTP协议"
date: 2019-02-01T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.http协议简介

#### 1.http简介
HTTP协议是Hyper Text Transfer Protocol（超文本传输协议）的缩写,是用于从万维网（WWW:World Wide Web ）服务器传输超文本到本地浏览器的传送协议。。

HTTP是一个基于TCP/IP通信协议来传递数据（HTML 文件, 图片文件, 查询结果等）。

#### 2.http的工作原理
HTTP协议工作于客户端-服务端的框架上，即客户端向web服务器发送请求，web服务器接收到请求后，向服务器端发送响应信息。

#### 3.http的特点
http协议有如下特点:

* http是无连接:无连接的含义是限制每次连接值处理一个请求，服务器处理完客户的请求后，并受到客户的应答后，即断开连接
* http是媒体独立的:这意味着，只要客户端和服务器端知道如何处理数据内容，任何类型的数据类型都可以通过http协议发送，客户端和服务器端知道使用合适的MIMR-type内容类型
* http是无状态的：HHTP协议是无状态协议。无状态是指协议对事务处理没有记忆能力。

### 二.http协议的响应步骤
http的响应步骤分为7步，大致内容如下：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy8yMDkyNjk0LTJlNDI1NDc3OTE4OGEzNGMucG5n?x-oss-process=image/format,png)
#### 1. 建立TCP连接
在HTTP工作开始之前, Web浏览器首先要通过网络与Web服务器建立连接, 该连接是通过TCP来完成的, 该协议与IP协议共同构建Internet, 即著名的TCP/IP协议族, 因此Internet又被称作是TCP/IP网络.

HTTP是比TCP更高层次的应用层协议，根据规则，有低层协议建立之后才能进行更高层协议的连接, 因此, 首先要建立TCP连接, 一般TCP连接的端口号是80.

tcp/ip 连接就是我们比较熟悉的三次握手

#### 2. Web浏览器向Web服务器发送请求命令
一旦建立了TCP连接，Web浏览器就会向web服务器发送请求命令

例如：GET/sample/hello.jsp HTTP/1.1

#### 3. Web浏览器发送请求头信息
浏览器发送其请求命令后，还要以头信息的形式向web服务器发送一些别的信息，这些信息用来描述浏览器自己，之后浏览器发送一空白行来通知服务器，表示它已经结束了该头信息的发送. 若是post请求, 还会在发送完请求头信息之后发送请求体.

#### 4.Web服务器的应答
客户机向服务机发出请求后，服务器会向客户机会送应答

HTTP/1.1 200 OK

应答的第一部分是协议的版本号和应答状态码

#### 5. web服务器发送应答头信息
正如客户端会随同请求发送关于自身的信息一样,服务器也会随同应答向用户发送关于它自己的数据及被请求的文档. 最后以一个空白行来表示头信息发送到此结束.

#### 6. web服务器向浏览器发送数据
Web服务器向浏览器发送头信息后, 它就以Content-Type应答头信息所描述的格式发送用户所请求的实际数据

#### 7. web服务器关闭TCP连接
一般情况下, 一旦Web服务器向浏览器发送了请求数据, 它就要关闭TCP连接. 如果浏览器或者服务器在其头信息加入了这行代码

>Connection:keep-alive

TCP连接在发送后将仍然保持打开状态. 于是, 浏览器可以继续通过相同的连接发送请求. 保持连接节省了为每个请求建立新连接所需的时间, 还节约了网络带宽.。
### 三.http的消息结构
#### 1.客户端请求消息
客户端发送一个HTTP请求到服务器的请求消息包括以下格式：请求行（request line）、请求头部（header）、空行和请求数据四个部分组成，下面是一个客户端请求消息的示例。

```
GET/sample.jspHTTP/1.1       //请求头
Accept:image/gif.image/jpeg,*/*  //请求头部
Accept-Language:zh-cn
Connection:Keep-Alive
Host:localhost
User-Agent:Mozila/4.0(compatible;MSIE5.01;Window NT5.0)
Accept-Encoding:gzip,deflate
                             //空行
username=jinqiao&password=1234//请求数据
```

请求的第一行是“方法URL议/版本”：GET/sample.jsp HTTP/1.1:
>以上代码中“GET”代表请求方法，“/sample.jsp”表示URI，“HTTP/1.1代表协议和协议的版本。
根据HTTP标准，HTTP请求可以使用多种请求方法。例如：HTTP1.1支持7种请求方法：GET、POST、HEAD、OPTIONS、PUT、DELETE和TARCE。在Internet应用中，最常用的方法是GET和POST。
URL完整地指定了要访问的网络资源，通常只要给出相对于服务器的根目录的相对目录即可，因此总是以“/”开头，最后，协议版本声明了通信过程中使用HTTP的版本。

请求头包含许多有关的客户端环境和请求正文的有用信息。例如，请求头可以声明浏览器所用的语言，请求正文的长度等。
#### 2.服务器的响应消息
HTTP响应也由四个部分组成，分别是：状态行、消息报头、空行和响应正文。如下所示
```
HTTP/1.1 200 OK           //状态行
Server:Apache Tomcat/5.0.12   //消息报头
Date:Mon,6Oct2003 13:23:42 GMT  
Content-Length:112
                //空行
<html>         //响应正文
<head>
<title>HTTP响应示例<title>
</head>
<body>
Hello HTTP!
</body>
</html>
```

状态行:它表示通信所用的协议是HTTP1.1服务器已经成功的处理了客户端发出的请求（200表示成功）
> HTTP/1.1 200 OK

#### 3.响应头信息
这一节介绍上面请求，响应的请求头中各参数的含义：

| 应答头  |说明 |
| ------------- |:-------------:| 
| Allow  | 服务器支持哪些请求方法（如GET、POST等）。| 
| Content-Encoding|文档的编码（Encode）方法。只有在解码之后才可以得到Content-Type头指定的内容类型。利用gzip压缩文档能够显著地减少HTML文档的下载时间。Java的GZIPOutputStream可以很方便地进行gzip压缩，但只有Unix上的Netscape和Windows上的IE 4、IE 5才支持它。因此，Servlet应该通过查看Accept-Encoding头（即request.getHeader("Accept-Encoding")）检查浏览器是否支持gzip，为支持gzip的浏览器返回经gzip压缩的HTML页面，为其他浏览器返回普通页面。 | 
|Content-Length  | 表示内容长度。只有当浏览器使用持久HTTP连接时才需要这个数据。如果你想要利用持久连接的优势，可以把输出文档写入 ByteArrayOutputStream，完成后查看其大小，然后把该值放入Content-Length头，最后通过byteArrayStream.writeTo(response.getOutputStream()发送内容。 | 
| Content-Type | 表示后面的文档属于什么MIME类型。Servlet默认为text/plain，但通常需要显式地指定为text/html。由于经常要设置Content-Type，因此HttpServletResponse提供了一个专用的方法setContentType。| 
|Date  | 当前的GMT时间。你可以用setDateHeader来设置这个头以避免转换时间格式的麻烦。 | 
| Expires |  应该在什么时候认为文档已经过期，从而不再缓存它？ | 
| Last-Modified |文档的最后改动时间。客户可以通过If-Modified-Since请求头提供一个日期，该请求将被视为一个条件GET，只有改动时间迟于指定时间的文档才会返回，否则返回一个304（Not Modified）状态。Last-Modified也可用setDateHeader方法来设置。| 
| Location  |表示客户应当到哪里去提取文档。Location通常不是直接设置的，而是通过HttpServletResponse的sendRedirect方法，该方法同时设置状态代码为302。  | 
| Refresh |表示浏览器应该在多少时间之后刷新文档，以秒计。除了刷新当前文档之外，你还可以通过setHeader("Refresh", "5; URL=http://host/path")让浏览器读取指定的页面。| 
|Server| 服务器名字。Servlet一般不设置这个值，而是由Web服务器自己设置。 | 
| Set-Cookie  |  设置和页面关联的Cookie。Servlet不应使用response.setHeader("Set-Cookie", ...)，而是应使用HttpServletResponse提供的专用方法addCookie。参见下文有关Cookie设置的讨论。 |
|WWW-Authenticate | 客户应该在Authorization头中提供什么类型的授权信息？在包含401（Unauthorized）状态行的应答中这个头是必需的。例如，response.setHeader("WWW-Authenticate", "BASIC realm=＼"executives＼"")。|

### 四.Http协议版本
Http到现在一共经历了3个版本的演化，，第一个HTTP协议诞生于1989年3月。

#### 1.Http 0.9
HTTP 0.9是第一个版本的HTTP协议，已过时。它的组成极其简单，只允许客户端发送GET这一种请求，且不支持请求头。由于没有协议头，造成了HTTP 0.9协议只支持一种内容，即纯文本。不过网页仍然支持用HTML语言格式化，同时无法插入图片。

HTTP 0.9具有典型的无状态性，每个事务独立进行处理，事务结束时就释放这个连接。由此可见，HTTP协议的无状态特点在其第一个版本0.9中已经成型。一次HTTP 0.9的传输首先要建立一个由客户端到Web服务器的TCP连接，由客户端发起一个请求，然后由Web服务器返回页面内容，然后连接会关闭。如果请求的页面不存在，也不会返回任何错误码。

#### 2.HTTP 1.0
HTTP协议的第二个版本，第一个在通讯中指定版本号的HTTP协议版本，至今仍被广泛采用。相对于HTTP 0.9 增加了如下主要特性

* 请求和响应支持头域
* 响应对象以一共响应状态行开始
* 响应对象不止限于超文本
* 开始支持POST方法，支持GET，HEAD方法
* 支持长连接（但默认还是短连接），缓存机制，以及身份认证

#### 3.HTTP 1.1
HTTP协议的第三个版本是HTTP 1.1，是目前使用最广泛的协议版本 。HTTP 1.1是目前主流的HTTP协议版本.

HTTP 1.1引入了许多的关键的性能优化:keepalive连接，chunked编码传输，字节范围请求，请求流水线等

**a.keepalive连接**
允许HTTP设备在事务处理结束之后将TCP连接保持在打开的状态，一遍未来的HTTP请求重用现在的连接，直到客户端或服务器端决定将其关闭为止。

在HTTP1.0中使用长连接需要添加请求头 Connection: Keep-Alive，而在HTTP 1.1 所有的连接默认都是长连接，除非特殊声明不支持（ HTTP请求报文首部加上Connection: close ）
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL2F0YTItaW1nLmNuLWhhbmd6aG91LmltZy1wdWIuYWxpeXVuLWluYy5jb20vMGE3ZTIwY2JmYTczMmZjNjYxZTg4ZWI2NzBhYTRhYTkucG5n?x-oss-process=image/format,png)

**b.chunked编码传输**
该编码将实体分块传送并逐块标明长度,直到长度为0块表示传输结束, 这在实体长度未知时特别有用(比如由数据库动态产生的数据)

**c.字节请求范围**
HTTP1.1支持传送内容的一部分。比方说，当客户端已经有内容的一部分，为了节省带宽，可以只向服务器请求一部分。该功能通过在请求消息中引入了range头域来实现，它允许只请求资源的某个部分。在响应消息中Content-Range头域声明了返回的这部分对象的偏移值和长度。如果服务器相应地返回了对象所请求范围的内容，则响应码206（Partial Content）

**d.其他功能**

* 请求头和响应消息都支持Host头域
* 新增了一些方法
* 缓存处理，在1.0的基础上增加了新特性，引入了实体标签。

#### 3. HTTP 2.0
HTTP 2.0是下一代HTTP协议，目前应用还非常少。主要特点有：

**a.多路复用(二进制分帧)**
HTTP 2.0最大的特点: 不会改动HTTP 的语义，HTTP 方法、状态码、URI 及首部字段，等等这些核心概念上一如往常，却能致力于突破上一代标准的性能限制，改进传输性能，实现低延迟和高吞吐量。而之所以叫2.0，是在于新增的二进制分帧层。在二进制分帧层上， HTTP 2.0 会将所有传输的信息分割为更小的消息和帧,并对它们采用二进制格式的编码 ，其中HTTP1.x的首部信息会被封装到Headers帧，而我们的request body则封装到Data帧里面。

**b.头部压缩**
当一个客户端向相同服务器请求许多资源时，像来自同一个网页的图像，将会有大量的请求看上去几乎同样的，这就需要压缩技术对付这种几乎相同的信息。

**c.随时复位**
Http1.1一个缺点就是当Http信息由一定长度大小数据传输时，你不能方便地随时停止它，中断TCP连接的代价是昂贵的。使用HTTP2的RST_STREAM将能方便停止一个信息传输，启动新的信息，在不中断连接的情况下提高带宽利用效率。

**d.服务器端推流: Server Push**
客户端请求一个资源X，服务器端判断也许客户端还需要资源Z，在无需事先询问客户端情况下将资源Z推送到客户端，客户端接受到后，可以缓存起来以备后用。

**e.优先权和依赖**
每个流都有自己的优先级别，会表明哪个流是最重要的，客户端会指定哪个流是最重要的，有一些依赖参数，这样一个流可以依赖另外一个流。优先级别可以在运行时动态改变，当用户滚动页面时，可以告诉浏览器哪个图像是最重要的，你也可以在一组流中进行优先筛选，能够突然抓住重点流。 
### 五.http协议的请求方法
根据HTTP标准，HTTP请求可以使用多种请求方法。
HTTP1.0定义了三种请求方法： GET, POST 和 HEAD方法。
HTTP1.1新增了五种请求方法：OPTIONS, PUT, DELETE, TRACE 和 CONNECT 方法。

| 序号 | 方法| 描述 |
| ------------- |:-------------:| -----:|
| 1 | GET | 请求指定的页面信息，并返回主页内容 |
| 2 | HEAD| 类似于get请求，只不过返回的响应中没有具体的内容，用于获取报头 |
| 3 | POST| 向指定资源提交数据进行处理请求（例如提交表单或者上传文件）。数据被包含在请求体中。POST请求可能会导致新的资源的建立和/或已有资源的修改。| 
| 4 | PUT | 从客户端向服务器传送的数据取代指定的文档的内容。 |
| 5 |  DELETE | 请求服务器删除指定的页面。 |
| 6 | CONNECT |HTTP/1.1协议中预留给能够将连接改为管道方式的代理服务器。 | 
| 7 | OPTIONS | 允许客户端查看服务器的性能。 |
| 8 | TRACE | 	回显服务器收到的请求，主要用于测试或诊断。 |

### 六.http协议的状态码
当浏览者访问一个网页时，浏览者的浏览器会向网页所在服务器发出请求。当浏览器接收并显示网页前，此网页所在的服务器会返回一个包含HTTP状态码的信息头（server header）用以响应浏览器的请求。

HTTP状态码的英文为HTTP Status Code。
####1.http状态码分类
http状态码由三个十进制数组组成，第一个十进制数字定义了状态码的类型，后两个数字没有分类的作用，http状态码分为5种类型

| 序号 | 分类描述|
| ------------- |:-------------:| -----:|
| 1** | 信息，服务器收到请求，需要请求则继续执行操作 | 
| 2** | 成功，操作被成功接收并成功|
| 3** | 重定向，需要进一步的操作以完成请求|
| 4** | 客户端错误，请求包含语法错误或无法完成请求 |
| 5** | 服务器错误，服务器在处理请求的过程中发生了错误| 

#### 2.http状态码列表

| 状态码 | 状态码英文名称|描述|
| ------------- |:-------------:| :-----:|
| 100 | Continue  | 继续。客户端应继续其请求|
| 101 | Switching Protocols |切换协议。服务器根据客户端的请求切换协议。只能切换到更高级的协议，例如，切换到HTTP的新版本协议 |
| 200 |OK  |请求成功。一般用于GET与POST请求 |
| 201 |Created| 已创建。成功请求并创建了新的资源|
| 202| Accepted | 已接受。已经接受请求，但未处理完成 |
| 203 | Non-Authoritative Information | 非授权信息。请求成功。但返回的meta信息不在原始的服务器，而是一个副本|
|204 |No Content| 无内容。服务器成功处理，但未返回内容。在未更新网页的情况下，可确保浏览器继续显示当前文档|
|205|Reset Content|重置内容。服务器处理成功，用户终端（例如：浏览器）应重置文档视图。可通过此返回码清除浏览器的表单域|
|206| 	Partial Content| 	部分内容。服务器成功处理了部分GET请求|
|300|Multiple Choices|多种选择。请求的资源可包括多个位置，相应可返回一个资源特征与地址的列表用于用户终端（例如：浏览器）选择|
|301|Moved Permanently| 	永久移动。请求的资源已被永久的移动到新URI，返回信息会包括新的URI，浏览器会自动定向到新URI。今后任何新的请求都应使用新的URI代替|
|302|Found|临时移动。与301类似。但资源只是临时被移动。客户端应继续使用原有URI|
|303|See Other| 查看其它地址。与301类似。使用GET和POST请求查看|
|304|Not Modified|未修改。所请求的资源未修改，服务器返回此状态码时，不会返回任何资源。客户端通常会缓存访问过的资源，通过提供一个头信息指出客户端希望只返回在指定日期之后修改的资源|
|305|Use Proxy| 使用代理。所请求的资源必须通过代理访问|
|306| 	Unused| 	已经被废弃的HTTP状态码|
|307| 	Temporary Redirect| 	临时重定向。与302类似。使用GET请求重定向|
|400|Bad Request|客户端请求的语法错误，服务器无法理解|
|401 | 	Unauthorized| 	请求要求用户的身份认证|
|402 |	Payment Required| 	保留，将来使用|
| 403 | 	Forbidden | 	服务器理解请求客户端的请求，但是拒绝执行此请求|
| 404 | 	Not Found| 	服务器无法根据客户端的请求找到资源（网页）。通过此代码，网站设计人员可设置"您所请求的资源无法找到"的个性页面|
| 405| 	Method Not Allowed| 	客户端请求中的方法被禁止|
|406 |	Not Acceptable| 	服务器无法根据客户端请求的内容特性完成请求|
|407| 	Proxy Authentication Required |	请求要求代理的身份认证，与401类似，但请求者应当使用代理进行授权
|408 	|Request Time-out |	服务器等待客户端发送的请求时间过长，超时|
|409 |	Conflict| 	服务器完成客户端的PUT请求是可能返回此代码，服务器处理请求时发生了冲突|
|410 |	Gone 	|客户端请求的资源已经不存在。410不同于404，如果资源以前有现在被永久删除了可使用410代码，网站设计人员可通过301代码指定资源的新位置|
|411| 	Length Required |服务器无法处理客户端发送的不带Content-Length的请求信息|
|412 |	Precondition Failed 	|客户端请求信息的先决条件错误|
|413 |	Request Entity Too Large| 	由于请求的实体过大，服务器无法处理，因此拒绝请求。为防止客户端的连续请求，服务器可能会关闭连接。如果只是服务器暂时无法处理，则会包含一个Retry-After的响应信息|
|414 |	Request-URI Too Large| 	请求的URI过长（URI通常为网址），服务器无法处理|
|415| 	Unsupported Media Type| 	服务器无法处理请求附带的媒体格式|
|416| 	Requested range not satisfiable| 	客户端请求的范围无效|
|417 |	Expectation Failed| 	服务器无法满足Expect的请求头信息|
|500 |	Internal Server Error|	服务器内部错误，无法完成请求|
|501 |Not Implemented| 	服务器不支持请求的功能，无法完成请求|
|502 |	Bad Gateway| 	充当网关或代理的服务器，从远端服务器接收到了一个无效的请求|
|503| 	Service Unavailable| 	由于超载或系统维护，服务器暂时的无法处理客户端的请求。延时的长度可包含在服务器的Retry-After头信息中|
|504 |Gateway Time-out| 	充当网关或代理的服务器，未及时从远端服务器获取请求|
|505 |	HTTP Version not supported|服务器不支持请求的HTTP协议的版本，无法完成处理|
### 七.参考资料
[HTTP 教程](http://www.runoob.com/http/http-tutorial.html)
[文加图, 理解Http请求与响应](https://www.jianshu.com/p/51a61845e66a#)
[HTTP深入浅出 http请求](http://www.cnblogs.com/yin-jingyu/archive/2011/08/01/2123548.html)
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
