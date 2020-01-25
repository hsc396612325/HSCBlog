---
title: "Android之Rxjava2.X 1————Rxjava概述"
date: 2019-04-01T22:40:54+08:00
draft: false
categories: ["Android","Android之Rxjava"]
tags: ["Android","Rxjava"]
---

### 一.目录
@[toc]
### 二.前言
这个暑假看的最多内容也就是Rxjava相关的内容，虽然网上目前关于Rxjava的文章挺多的，但还是想自己总结一下，这个系列预计分为3个部分，概述，操作符，应用。文章内容会参考其他博主优秀的文章，也会在文末给出参考博文的地址。同时也参考了一下Rxjava的文档。
### 三.Rx的概述
#### 1.Rx介绍
ReactiveX是Reactive Extensions的缩写，一般简写为Rx，Rx是一个编程模型，目标是提供一致的编程接口，帮助开发者更方便的处理异步数据流。Rx的大部分语言库由ReactiveX这个组织负责维护，比较流行的有RxJava/RxJS/Rx.NET，社区网站是 [reactivex.io](http://reactivex.io/)。 ReactiveX.io给的定义是，Rx是一个使用可观察数据流进行异步编程的编程接口，ReactiveX结合了观察者模式、迭代器模式和函数式编程的精华。

#### 2.Rx的特点
1.使用的观察者模式
2.简化代码

*  函数式风格：对可观察数据流使用无副作用的输入输出函数，避免了程序里错综复杂的状态
*  简化代码 ：Rxjava的操作符通常可以将复杂的难题简化为很少的几行代码
*  异步错误处理：传统的try/catch没办法处理异步计算，Rx提供了合适的错误处理机制
* 轻松使用并发：Rx的Observables和Schedulers让开发者可以摆脱底层的线程同步和各种并发问题

3.响应式函数式编程

### 四.函数响应式编程
#### 1.响应式编程
响应式编程就是与异步数据流交互的编程范式，在响应式编程中，可以将**所有的事件视为数据流**，比如：点击，悬停，变量。用户输入，属性，换出，数据结构。举个栗子，你可以将自己的微博关注视为数据流，你可以监听这样的数据流，并作出相应的反应。
#### 2.函数响应式编程
函数响应式编程中（Rx中），你可以去调用许多非常棒的函数，去创建，结合，过滤任何一组数据流，这就是"函数式编程"的魔力所在。一个数据流可以作为另一个数据流的输入，甚至多个数据流也可以作为另一个数据流的输入。你可以_合并(merge)_两个数据流，也可以_过滤(filter)_一个数据流得到另一个只包含你感兴趣的事件的数据流，还可以_映射(map)_一个数据流的值到一个新的数据流里。

### 五.Rxjava的原理
#### 1.扩展的观察者模式
Rxjava的原理基于一种扩展的观察者模型，其实这个模式在android很常见，比如说button的setOnClickListener，就是一个典型的观察者模式，控件button是被观察者（Observable），它产生一个事件(点击)，被观察者OnClickListener接收到，做出相应的处理，而setOnClickListener就是订阅者，它将两者连接起来

Rxjava中扩展的观察者模式

| 角色 | 作用 | 类别 |
| ------------- |:-------------:| -----:|
|被观察者（Observable）  | 产生事件| 控件 |
| 观察者（Observer）| 接收事件，并给出响应动作 |OnClickListener|
| 订阅（Subscribe） |连接 被观察者 & 观察者 |setOnClickListener| 
|事件（Event） |  被观察者 & 观察者 沟通的载体 | 控件被点击 | 

#### 2.Rxjava的观察者模式流程
RxJava原理可总结为：被观察者 （Observable） 通过 订阅（Subscribe） 按顺序发送事件 给观察者 （Observer）， 观察者（Observer） 按顺序接收事件 & 作出对应的响应动作。具体如下图：
![这里写图片描述](/image/Android_Rxjava/9_0.png)

### 六.Rxjava的基本使用
#### 1. 分步骤实现
该方法主要为了深入说明Rxjava的原理 & 使用，主要用于演示说明，在实际应用中，很少使用（不够优雅简洁：）。
分步骤实现主要分为3步，即创建被观察者，创建观察者，通过订阅将两者链接起来。
**步骤1：创建被观察者 （Observable ）& 生产事件**
```java
  // 1. 创建被观察者 Observable 对象
        Observable<Integer> observable = Observable.create(new ObservableOnSubscribe<Integer>() {
            // create() 是 RxJava 最基本的创造事件序列的方法
            // 此处传入了一个 OnSubscribe 对象参数
            //当Observable被订阅时，OnSubscribe的call()方法会自动被调用，即事件序列会一次设定次序本被触发
            //即观察者会依此调用对应事件的复写方法从而响应事件
            //从而实现被观察者调用了观察者的回调方法&由被观察者向观察者的事件传递


            //2.在复写的subscribe（）里定义需要发送的事件
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                // 通过 ObservableEmitter类对象产生事件并通知观察者

                // ObservableEmitter类介绍
                // a. 定义：事件发射器
                // b. 作用：定义需要发送的事件 & 向观察者发送事件

                e.onNext(1);  //发送事件
                e.onNext(2);
                e.onNext(3);
                e.onComplete();//发送完成事件
            }
        });

```

Rxjava中不止提供了create这一种创建observable的方法，还创建了其他方法，这些在下一篇博客中做更多的介绍。

**步骤2：创建观察者 （Observer ）并 定义响应事件的行为**
发生的事件类型包括：Next事件、Complete事件 & Error事件。具体如下：

* onNext：用来发送数据，可多次调用，每调用一次发送一条数据
* onError：用来发送异常通知，只发送一次，若多次调用只发送第一条
* onComplete：用来发送完成通知，只发送一次，若多次调用只发送第一条

* onError与onComplete互斥，两个方法只能调用一个不能同时调用，数据在发送时，出现异常可以调用onError发送异常通知也可以不调用，因为其所在的方法subscribe会抛出异常，若数据在全部发送完之后均正常可以调用onComplete发送完成通知；其中，onError与onComplete不做强制性调用。
接口Observer中的三个方法（onNext,onError,onComplete）正好与Emitter中的三个方法相对应，分别对Emitter中对应方法的行为作出响应。

创建观察者有两种方式即，Observer接口和Subsceiber接口
Onsercer接口
```java
  // 1. 创建观察者 （Observer ）对象
        Observer<Integer> observer = new Observer<Integer>() {
            // 2. 创建对象时通过对应复写对应事件方法 从而 响应对应事件

            // 观察者接收事件前，默认最先调用复写 onSubscribe（）
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "开始采用subscribe连接");
            }

            // 当被观察者生产Next事件 & 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onNext(Integer value) {
                Log.d(TAG, "对Next事件作出响应" + value);
            }

            // 当被观察者生产Error事件& 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onError(Throwable e) {
                Log.d(TAG, "对Error事件作出响应");
            }

            // 当被观察者生产Complete事件& 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onComplete() {
                Log.d(TAG, "对Complete事件作出响应");
            }
        };
    }
```
 Subscriber接口
```java
   // 1. 创建观察者 （Observer ）对象
        Subscriber<Integer> subscriber = new Subscriber<Integer>() {
            // 2. 创建对象时通过对应复写对应事件方法 从而 响应对应事件

            // 观察者接收事件前，默认最先调用复写 onSubscribe（）
            @Override
            public void onSubscribe(Subscription s) {
                Log.d(TAG, "开始采用subscribe连接");
            }


            // 当被观察者生产Next事件 & 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onNext(Integer value) {
                Log.d(TAG, "对Next事件作出响应" + value);
            }

            // 当被观察者生产Error事件& 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onError(Throwable e) {
                Log.d(TAG, "对Error事件作出响应");
            }

            // 当被观察者生产Complete事件& 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onComplete() {
                Log.d(TAG, "对Complete事件作出响应");
            }
        };
```
Subscriber 抽象类与Observer 接口的区别

* 相同点：二者基本使用方式完全一致（实质上，在RxJava的 subscribe 过程中，Observer总是会先被转换成Subscriber再使用）
*  不同点：Subscriber抽象类对 Observer 接口进行了扩展，新增了两个方法：  
	* onStart()：在还未响应事件前调用，用于做一些初始化工作
	*  unsubscribe()：用于取消订阅。在该方法被调用后，观察者将不再接收 & 响应事件
	* 调用该方法前，先使用 isUnsubscribed() 判断状态，确定被观察者Observable是否还持有观察者Subscriber的引用，如果引用不能及时释放，就会出现内存泄露

**步骤3：通过订阅（Subscribe）连接观察者和被观察者**
```java
observable.subscribe(observer);
 // 或者 observable.subscribe(subscriber)；
```
#### 2. 基于事件流的链式编程
上面的写法只是为了描述Rxjava的使用，在实际使用中会将上面的代码连着一起，从而更加简洁，更加优雅，即链式编程。
```java
 // 1. 创建被观察者 Observable 对象
        Observable.create(new ObservableOnSubscribe<Integer>() {

            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {

                e.onNext(1);
                e.onNext(2);
                e.onNext(3);
                e.onComplete();
            }
        }).subscribe(  //订阅

        // 3. 创建观察者 （Observer ）对象
                new Observer<Integer>() {
            // 2. 创建对象时通过对应复写对应事件方法 从而 响应对应事件

            // 观察者接收事件前，默认最先调用复写 onSubscribe（）
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "开始采用subscribe连接");
            }


            // 当被观察者生产Next事件 & 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onNext(Integer value) {
                Log.d(TAG, "对Next事件作出响应" + value);
            }

            // 当被观察者生产Error事件& 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onError(Throwable e) {
                Log.d(TAG, "对Error事件作出响应");
            }

            // 当被观察者生产Complete事件& 观察者接收到时，会调用该复写方法 进行响应
            @Override
            public void onComplete() {
                Log.d(TAG, "对Complete事件作出响应");
            }
        });
```
![这里写图片描述](/image/Android_Rxjava/9_1.png)
更简洁的写法
```java
Observable.just(1,2,3).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(Integer integer) throws Exception {
                Log.d(TAG, "accept: "+i);
            }
        });
```

![这里写图片描述](/image/Android_Rxjava/9_2.png)

### 七.Rxjava操作符简述

* 创建操作 Create, Defer, Empty/Never/Throw, From, Interval, Just, Range, Repeat, Start, Timer
* 变换操作 Buffer, FlatMap, GroupBy, Map, Scan和Window
* 过滤操作 Debounce, Distinct, ElementAt, Filter, First, IgnoreElements, Last, Sample, Skip, SkipLast, Take, TakeLast
* 组合操作 And/Then/When, CombineLatest, Join, Merge, StartWith, Switch, Zip
* 错误处理 Catch和Retry
* 辅助操作 Delay, Do, Materialize/Dematerialize, ObserveOn, Serialize, Subscribe, SubscribeOn, TimeInterval, Timeout, Timestamp, Using
*  条件和布尔操作 All, Amb, Contains, DefaultIfEmpty, SequenceEqual, SkipUntil, SkipWhile, TakeUntil, TakeWhile
*  算术和集合操作 Average, Concat, Count, Max, Min, Reduce, Sum
* 转换操作 To
* 连接操作 Connect, Publish, RefCount, Replay
* 反压操作，用于增加特殊的流程控制策略的操作符

简单概述
[https://mcxiaoke.gitbooks.io/rxdocs/content/Operators.html](https://mcxiaoke.gitbooks.io/rxdocs/content/Operators.html)

### 八.参考资料
[ReactiveX文档中文翻译](https://mcxiaoke.gitbooks.io/rxdocs/content/topics/Getting-Started.html)
[Android Rxjava：这是一篇 清晰 & 易懂的Rxjava 入门教程 ](https://www.jianshu.com/p/a406b94f3188)
[Rxjava2入门教程一：函数响应式编程及概述](Rxjava2%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B%E4%B8%80%EF%BC%9A%E5%87%BD%E6%95%B0%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B%E5%8F%8A%E6%A6%82%E8%BF%B0)
[这可能是最好的RxJava 2.x 教程（完结版）](https://www.jianshu.com/p/0cd258eecf60)
[那些年我们错过的响应式编程](https://github.com/kevinyaoo/android-tech-frontier/tree/master/androidweekly/%E9%82%A3%E4%BA%9B%E5%B9%B4%E6%88%91%E4%BB%AC%E9%94%99%E8%BF%87%E7%9A%84%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B)

### 九.文章索引
* [Android之Rxjava2.X 1————Rxjava概述](https://blog.csdn.net/qq_38499859/article/details/81611870)
* [Android之Rxjava2.X 2————Rxjava 创建操作符](https://blog.csdn.net/qq_38499859/article/details/81637932)
* [Android之Rxjava2.X 3————Rxjava 变换操作符](https://blog.csdn.net/qq_38499859/article/details/81668545)
* [Android之Rxjava2.X 4————Rxjava 组合操作符](https://blog.csdn.net/qq_38499859/article/details/81670980)
* [Android之Rxjava2.X 5————Rxjava 过滤操作符](https://blog.csdn.net/qq_38499859/article/details/81675322)
* [Android之Rxjava2.X 6————Rxjava 功能操作符](https://blog.csdn.net/qq_38499859/article/details/81700187)
* [Android之Rxjava2.X 7————Rxjava 条件操作符](https://blog.csdn.net/qq_38499859/article/details/81705745)
* [Android之Rxjava2.X 8————Rxjava 背压策略](https://blog.csdn.net/qq_38499859/article/details/81747334)
* [Android之Rxjava2.X 9————Rxjava源码阅读1](https://blog.csdn.net/qq_38499859/article/details/81775520)
* [Android之Rxjava2.X 10————Rxjava源码阅读2](https://blog.csdn.net/qq_38499859/article/details/81839955)
* [Android之Rxjava2.X 11————Rxjava源码阅读3](https://blog.csdn.net/qq_38499859/article/details/82119900)
