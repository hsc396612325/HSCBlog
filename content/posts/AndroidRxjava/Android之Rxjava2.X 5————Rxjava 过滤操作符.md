# Android之Rxjava2.X 5————Rxjava 过滤操作符
### 一. 目录
@[toc]
### 二. 概述
#### 1.作用
过滤 / 筛选 被观察者（Observable）发送的事件 & 观察者 （Observer）接收的事件
#### 2.类型
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtODNmYjhlNzAzOGRmZDUxYS5wbmc?x-oss-process=image/format,png)
### 三. 根据指定事件条件过滤事件
#### 1. filter()
* 作用：通过一定逻辑来过滤被观察者发送的事件，如果返回true则发送事件，否则不会发送 
* 应用场景：筛选符合要求的事件
原理图：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2ZpbHRlci5wbmc?x-oss-process=image/format,png)

具体使用：
```java
 Observable.just(1,2,3,4,5).filter(new Predicate<Integer>() {
            @Override
            public boolean test(Integer integer) throws Exception {
                return integer % 3 == 1;
            }
        }).subscribe(new Observer<Integer>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "onSubscribe: ");
            }

            @Override
            public void onNext(Integer integer) {
                Log.d(TAG, "onNext: "+integer);
            }

            @Override
            public void onError(Throwable e) {
                Log.d(TAG, "onError: ");
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete: ");
            }
        });
```
![这里写图片描述](https://img-blog.csdn.net/20180814195720365)
#### 2.ofType()
* 作用：ofType是filter操作符的一个特殊形式。它过滤一个Observable只返回指定类型的数据。
原理图：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL29mQ2xhc3MucG5n?x-oss-process=image/format,png)

具体使用:
```java
 Observable.just(1, 2, "hello", "world")
                .ofType(Integer.class)
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814201906593)

#### 3.skip() & skipLast()
* skip()作用：忽略Observable'发射的前N项数据，只保留之后的数据。
*  skipLast()作用:从结尾往前数跳过制定数量的事件 
原理图：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL3NraXAuYy5wbmc?x-oss-process=image/format,png)
[外链图片转存中...(img-zz5bYse0-1579435983422)]

具体使用：
```java
  Observable.just(1, 2, 3,4)
                .skip(2)
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });

```
![这里写图片描述](https://img-blog.csdn.net/20180814202606203)
```java
Observable.just(1, 2, 3,4)
                .skipLast(2)
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814202658100)
#### 4.distinct（） / distinctUntilChanged（）
* 作用：过滤事件序列中重复的事件 / 连续重复的事件

原理图：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2Rpc3RpbmN0LnBuZw?x-oss-process=image/format,png)
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2Rpc3RpbmN0VW50aWxDaGFuZ2VkLnBuZw?x-oss-process=image/format,png)

具体使用;
```java
  // 使用1：过滤事件序列中重复的事件
        Observable.just(1, 2, 3,4,1,2,1)
                .distinct()
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });

        //使用2：过滤事件序列中 连续重复的事件
        // 下面序列中，连续重复的事件 = 3、4
        Observable.just(1,2,3,1,2,3,3,4,4 )
                .distinctUntilChanged()
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814205651557)

### 四. 根据指定事件数量过滤事件
需求场景：通过设置指定的事件数量，仅发送特定数量的事件
#### 1.take（）
* 作用： 只发射前面的N项数据、
原理图：
[外链图片转存中...(img-ywZMpnIi-1579435983423)]

具体使用：
```java
 // 使用1：过滤事件序列中重复的事件
        Observable.just(1, 2, 3,4,1,2,1)
                .take(4)
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814210332658?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
#### 2.takeLast（）
* 作用:发射Observable发射的最后N项数据

原理图：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL3Rha2VMYXN0Lm4ucG5n?x-oss-process=image/format,png)

具体使用：
```java
 // 使用1：过滤事件序列中重复的事件
        Observable.just(1, 2, 3,4,1,2,1)
                .takeLast(2)
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/2018081421082066)
### 五. 根据指定时间过滤事件
#### 1.throttleFirst（）/ throttleLast（）
* 作用：在某段时间内，只发送该段时间内第1次事件 / 最后1次事件（1段时间内连续点击按钮，但只执行第1次的点击操作）

原理图：
[外链图片转存中...(img-Yl6QCapz-1579435983423)]

具体使用：
```java
   Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                e.onNext(1);
                Thread.sleep(500);
                e.onNext(2);
                Thread.sleep(400);
                e.onNext(3);
                Thread.sleep(300);
                e.onNext(4);
                Thread.sleep(300);
                e.onNext(5);
                Thread.sleep(300);
                e.onNext(6);
                Thread.sleep(400);
                e.onNext(7);
                Thread.sleep(300);
                e.onNext(8);
                Thread.sleep(300);
                e.onNext(9);
                Thread.sleep(300);
                e.onComplete();

            }
        }).throttleFirst(1, TimeUnit.SECONDS)//每1秒中采用数据
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814212618457)
```java
  Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                e.onNext(1);
                Thread.sleep(500);
                e.onNext(2);
                Thread.sleep(400);
                e.onNext(3);
                Thread.sleep(300);
                e.onNext(4);
                Thread.sleep(300);
                e.onNext(5);
                Thread.sleep(300);
                e.onNext(6);
                Thread.sleep(400);
                e.onNext(7);
                Thread.sleep(300);
                e.onNext(8);
                Thread.sleep(300);
                e.onNext(9);
                Thread.sleep(300);
                e.onComplete();

            }
        }).throttleLast(1, TimeUnit.SECONDS)//每1秒中采用数据
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/2018081421273630)
#### 2.Sample（）
* 作用:在某段时间内，只发送该段时间内最新（最后）1次事件
* 和throttleLast（） 操作符类似，仅需要把上文的 throttleLast（） 改成Sample（）操作符即可
#### 3.throttleWithTimeout （） / debounce（）
* 作用：发送数据事件时，若2次发送事件的间隔＜指定时间，就会丢弃前一次的数据，直到指定时间内都没有新数据发射时才会发送后一次的数据

原理图
[外链图片转存中...(img-DF1wvmGQ-1579435983424)]

具体使用：
```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                e.onNext(1);
                Thread.sleep(500);
                e.onNext(2);
                Thread.sleep(1011);
                e.onNext(3);
                Thread.sleep(300);
                e.onNext(4);
                Thread.sleep(600);
                e.onNext(5);
                Thread.sleep(1200);
                e.onNext(6);
                Thread.sleep(400);
                e.onNext(7);
                Thread.sleep(300);
                e.onNext(8);
                Thread.sleep(300);
                e.onNext(9);
                Thread.sleep(300);
                e.onComplete();

            }
        }).throttleWithTimeout(1, TimeUnit.SECONDS)//每1秒中采用数据
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "onNext: " + integer);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: ");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814213741635)
### 六. 根据指定事件位置过滤事件
#### 1.firstElement（） / lastElement（）
* 作用：仅选取第1个元素 / 最后一个元素
具体使用：
```java
 Observable.just(1, 2, 3, 4, 5)
                .firstElement()
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "获取到的第一个事件是： " + integer);
                    }
                });

        Observable.just(1, 2, 3, 4, 5)
                .lastElement()
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "获取到的第一个事件是： " + integer);
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814214302945)

#### 2.elementAt（）
* 作用：指定接收某个元素（通过 索引值 确定）
* 允许越界，即获取的位置索引 ＞ 发送事件序列长度
具体使用：
```java
 Observable.just(1, 2, 3, 4, 5)
                .elementAt(2)
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "获取到的第一个事件是： " + integer);
                    }
                });
```
![这里写图片描述](https://img-blog.csdn.net/20180814214701354)
#### 3.elementAtOrError（）
* 作用:在elementAt（）的基础上，当出现越界情况（即获取的位置索引 ＞ 发送事件序列长度）时，即抛出异常

 具体使用:
 ```java
 Observable.just(1, 2, 3, 4, 5)
                .elementAtOrError(7)
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "获取到的第一个事件是： " + integer);
                    }
                });
 ```
 ![这里写图片描述](https://img-blog.csdn.net/20180814215539132?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 七.参考资料
[Android RxJava：过滤操作符 全面讲解](https://www.jianshu.com/p/c3a930a03855)
[RxJava文档中文版](https://mcxiaoke.gitbooks.io/rxdocs/content/operators/First.html)
[Android RxJava2(四)过滤操作符](https://blog.csdn.net/mixin716/article/details/80607295#firstelement-lastelement)


### 八.文章索引
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
