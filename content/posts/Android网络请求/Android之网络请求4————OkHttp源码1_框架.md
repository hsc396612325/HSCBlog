---
title: "Android之网络请求4————OkHttp源码1:框架"
date: 2019-02-04T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.目的
本次阅读源码的目的有以下目的：

1. 发生请求的过程
2. 接收响应的过程
3. 网络操作的实现
4. 缓存的实现
5. 多路复用的实现

在接下来的几篇文章中，结合源码和多篇优先的文章一同分析这些问题。

关于OKHttp的使用可以看前面的文章
### 二.总体框架
![这里写图片描述](/image/Android_jsjwl/2_0.png)

上图是OkHttp的总体架构，大致可以分为以下几层：

1. Interface——接口层：接受网络访问请求
2. Protocol——协议层：处理协议逻辑
3. Connection——连接层：管理网络连接，发送新的请求，接收服务器访问
4. Cache——缓存层：管理本地缓存
5.  I/O——I/O层：实际数据读写实现 
6. Inteceptor——拦截器层：拦截网络访问，插入拦截逻辑

### 三.每层的含义
#### 1. Interface——接口层:
接口层接收用户的网络访问请求(同步/异步)，发起实际的网络访问。OKHttpClient是OkHttp框架的客户端，更确切的说是一个用户面板。用户使用OkHttp进行各种设置，发起各种网络请求都是通过OkHttpClient完成的。每个OkHttpClient内部都维护了属于自己的任务队列，连接池，Cache，拦截器等，所以在使用OkHttp作为网络框架时应该全局共享一个OkHttpClient实例。

Call描述了一个实际的访问请求，用户的每一个网络请求都是一个Call实例，Call本身是一个接口，定义了Call的接口方法，在实际执行过程中，OkHttp会为每一个请求创建一个RealCall，即Call的实现类。

Dispatcher是OkHttp的任务队列，其内部维护了一个线程池，当有接收到一个Call时，Dispatcher负责在线程池中找到空闲的线程并执行其execute方法。

上面这三个类会在下一篇博客中详细介绍

#### 2.Protocol——协议层:处理协议逻辑
Protocol层负责处理协议逻辑，OkHttp支持Http1/Http2/WebSocket协议，并在3.7版本中放弃了对Spdy协议，鼓励开发者使用Http/2。

#### 3.Connection——连接层：管理网络连接，发送新的请求，接收服务器访问
连接层顾名思义就是负责网络连接，在连接层中有一个连接池，统一管理所有的Scoke连接，当用户发起一个新的网络请求是，OKHttp会在连接池找是否有符合要求的连接，如果有则直接通过该连接发送网络请求；否则新创建一个网络连接。

RealConnection描述一个物理Socket连接，连接池中维护多个RealConnection实例，由于Http/2支持多路复用，一个RealConnection，所以OKHttp又引入了StreamAllocation来描述一个实际的网络请求开销（从逻辑上一个Stream对应一个Call，但在实际网络请求过程中一个Call常常涉及到多次请求。如重定向，Authenticate等场景。所以准确地说，一个Stream对应一次请求，而一个Call对应一组有逻辑关联的Stream），一个RealConnection对应一个或多个StreamAllocation，所以StreamAllocation，是以StreamAllocation可以看做是RealConenction的计数器，当RealConnection的引用计数变为0，且长时间没有被其他请求重新占用就将被释放。

这一部分也详见之后的文章
#### 4.Cache——缓存层：管理本地缓存
Cache层负责维护请求缓存，当用户的网络请求在本地已有符合要求的缓存时，OKHttp会直接从缓存中返回结果，从而节省 网络开销。

这一部分也详见之后的文章

#### 5.Inteceptor——拦截器层：拦截网络访问，插入拦截逻辑
拦截器层提供了一个类AOP接口，方便用户可以切入到各个层面对网络访问进行拦截并执行相关逻辑。在下一篇博客中，这个也在之后会想讲。

### 四. 参考资料
[OkHttp 3.7源码分析（一）——整体架构](https://yq.aliyun.com/articles/78105?spm=a2c4e.11153940.blogcont78101.12.7c213cbf85V2v2#9)

### 五.文章索引
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
