# Android之Rxjava2.X 6————Rxjava 功能操作符
### 一.目录
@[toc]
### 二.概述
#### 1.作用
辅助被观察者在发送事件是实现一些实时功能性的需求

#### 2.类型
RxJava 2 中，常见的功能性操作符 主要有：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtZmYzZGYyYjQyOTY4ODMzZC5wbmc?x-oss-process=image/format,png)

### 三.线程调度

#### 1.subscribeOn()
作用：指定被观察者的线程，有一点需要注意就是如果多次调用此方法，只有第一次有效。 
具体使用
```java
  Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                Log.e(TAG, "threadName:" + Thread.currentThread().getName());
                e.onNext(1);
            }
        }).subscribeOn(Schedulers.newThread())
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
![这里写图片描述](https://img-blog.csdn.net/20180815104258912)
#### 2.observerOn()
作用: 指定观察者的线程，每指定一次就会生效一次。 
具体使用
```java
  Observable.just(1).observeOn(Schedulers.newThread())
                .map(new Function<Integer, Integer>() {
                    @Override
                    public Integer apply(Integer integer) throws Exception {
                        Log.e("---", "threadName:" + Thread.currentThread().getName());
                        return integer * 2;
                    }
                }).observeOn(AndroidSchedulers.mainThread())
                .subscribeOn(Schedulers.newThread())
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
![这里写图片描述](https://img-blog.csdn.net/20180815104501494)

更多内容推荐博客：[Android RxJava：细说 线程控制（切换 / 调度 ）（含Retrofit实例讲解）](https://www.jianshu.com/p/5225b2baaecd)
### 四.延迟操作
需求场景：在被观察者发送事件之前进行一些延迟操作
#### 1.delay（）
* 作用：使得被观察者延迟一段时间在发送事件

* 方法介绍:delay具备多个重载方法，具体如下：
```java
// 1. 指定延迟时间
// 参数1 = 时间；参数2 = 时间单位
delay(long delay,TimeUnit unit)

// 2. 指定延迟时间 & 调度器
// 参数1 = 时间；参数2 = 时间单位；参数3 = 线程调度器
delay(long delay,TimeUnit unit,mScheduler scheduler)

 // 3. 指定延迟时间 & 错误延迟 
 // 错误延迟，即：若存在Error事件，则如常执行，执行后再抛出错误异常 
 // 参数1 = 时间；参数2 = 时间单位；参数3 = 错误延迟参数 
  delay(long delay,TimeUnit unit,boolean delayError)


// 4. 指定延迟时间 & 调度器 & 错误延迟
// 参数1 = 时间；参数2 = 时间单位；参数3 = 线程调度器；参数4 = 错误延迟参数
delay(long delay,TimeUnit unit,mScheduler scheduler,boolean delayError): 指定延迟多长时间并添加调度器，错误通知可以设置是否延迟
```
原理图:
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2RlbGF5LnBuZw?x-oss-process=image/format,png)

具体使用·：
```java
 Observable.just(1, 2, 3)
                .delay(5, TimeUnit.SECONDS)
                .subscribe(new Observer<Integer>() {
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
![这里写图片描述](https://img-blog.csdn.net/20180815090622925)
### 五.在事件的生命周期中操作
需求场景:在事件发送 & 接收的整个生命周期过程中进行操作
#### 1.do（）
* 作用：在某个事件的生命周期中调用
* 类型:

[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-0cvd3zzB-1579435995940)(https://upload-images.jianshu.io/upload_images/944365-3f411ad304df78d5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/700)]
原理图:
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2RvT25FYWNoLnBuZw?x-oss-process=image/format,png)

具体使用:
```java
  Observable.just(1, 2, 3)
                // 1. 当Observable每发送1次数据事件就会调用1次
                .doOnEach(new Consumer<Notification<Integer>>() {
                    @Override
                    public void accept(Notification<Integer> integerNotification) throws Exception {
                        Log.d(TAG, "doOnEach: " + integerNotification.getValue());
                    }
                })
                // 2. 执行Next事件前调用
                .doOnNext(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "doOnNext: " + integer);
                    }
                })
                // 3. 执行Next事件后调用
                .doAfterNext(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "doAfterNext: " + integer);
                    }
                })
                // 4. Observable正常发送事件完毕后调用
                .doOnComplete(new Action() {
                    @Override
                    public void run() throws Exception {
                        Log.e(TAG, "doOnComplete: ");
                    }
                })
                // 5. Observable发送错误事件时调用
                .doOnError(new Consumer<Throwable>() {
                    @Override
                    public void accept(Throwable throwable) throws Exception {
                        Log.d(TAG, "doOnError: " + throwable.getMessage());
                    }
                })
                // 6. 观察者订阅时调用
                .doOnSubscribe(new Consumer<Disposable>() {
                    @Override
                    public void accept(@NonNull Disposable disposable) throws Exception {
                        Log.e(TAG, "doOnSubscribe: ");
                    }
                })
                // 7. Observable发送事件完毕后调用，无论正常发送完毕 / 异常终止
                .doAfterTerminate(new Action() {
                    @Override
                    public void run() throws Exception {
                        Log.e(TAG, "doAfterTerminate: ");
                    }
                })

                // 8. 最后执行
                .doFinally(new Action() {
                    @Override
                    public void run() throws Exception {
                        Log.e(TAG, "doFinally: ");
                    }
                })
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
![这里写图片描述](https://img-blog.csdn.net/20180815091915132)
### 六.错误处理
需求场景:发送事件过程中，遇到错误时的处理机制
#### 1.onErrorReturn（）
* 作用:遇到错误时，发送1个特殊事件 & 正常终止

具体使用；
```java
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onError(new NullPointerException());
            }
        }).onErrorReturn(new Function<Throwable, Integer>() {
            @Override
            public Integer apply(Throwable throwable) throws Exception {
                return 3;
            }
        }).subscribe(new Observer<Integer>() {
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

![这里写图片描述](https://img-blog.csdn.net/2018081509264976)
#### 2.onErrorResumeNext（）/onExceptionResumeNext（）
* 作用:遇到错误时，发送1个新的Observable
* 注意：onExceptionResumeNext（）拦截的错误 = Exception,onErrorResumeNext（）拦截的错误 = Throwable

具体使用：
```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onError(new Throwable("发生错误了"));
            }
        }).onErrorResumeNext(new Function<Throwable, ObservableSource<? extends Integer>>() {
            @Override
            public ObservableSource<? extends Integer> apply(@NonNull Throwable throwable) throws Exception {
                // 1. 捕捉错误异常
                Log.e(TAG, "在onErrorReturn处理了错误: " + throwable.toString());

                // 2. 发生错误事件后，发送一个新的被观察者 & 发送事件序列
                return Observable.just(11, 22);
            }
        }).subscribe(new Observer<Integer>() {
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
![这里写图片描述](https://img-blog.csdn.net/20180815093655721)

#### 3.retry（）
* 作用：重试，即当出现错误时，让被观察者（Observable）重新发射数据
* 类型：

```java
<-- 1. retry（） -->
// 作用：出现错误时，让被观察者重新发送数据
// 注：若一直错误，则一直重新发送

<-- 2. retry（long time） -->
// 作用：出现错误时，让被观察者重新发送数据（具备重试次数限制
// 参数 = 重试次数

<-- 3. retry（Predicate predicate） -->
// 作用：出现错误后，判断是否需要重新发送数据（若需要重新发送& 持续遇到错误，则持续重试）
// 参数 = 判断逻辑

<--  4. retry（new BiPredicate<Integer, Throwable>） -->
// 作用：出现错误后，判断是否需要重新发送数据（若需要重新发送 & 持续遇到错误，则持续重试
// 参数 =  判断逻辑（传入当前重试次数 & 异常错误信息）

<-- 5. retry（long time,Predicate predicate） -->
// 作用：出现错误后，判断是否需要重新发送数据（具备重试次数限制
// 参数 = 设置重试次数 & 判断逻辑
```

具体使用：
```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onError(new Throwable("发生错误了"));
            }
        })
        .retry() // 遇到错误时，让被观察者重新发射数据（若一直错误，则一直重新发送
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

![这里写图片描述](https://img-blog.csdn.net/20180815094643444)
#### 4.retryUntil（）
* 作用：出现错误后，判断是否需要重新发送数据，作用类似于retry（Predicate predicate）
* 具体使用类似于retry（Predicate predicate），唯一区别：返回 true 则不重新发送数据事件。
#### 5.retryWhen（）
* 作用：遇到错误时，将发生的错误传递给一个新的被观察者（Observable），并决定是否需要重新订阅原始被观察者（Observable）& 发送事件

具体使用：
```java
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onError(new Throwable("发生错误了"));
                emitter.onNext(3);
            }
        }).retryWhen(new Function<Observable<Throwable>, ObservableSource<?>>() {
            @Override
            public ObservableSource<?> apply(@NonNull Observable<Throwable> throwableObservable) throws Exception {
                // 参数Observable<Throwable>中的泛型 = 上游操作符抛出的异常，可通过该条件来判断异常的类型
                // 返回Observable<?> = 新的被观察者 Observable（任意类型）
                // 此处有两种情况：

                // 1. 若 新的被观察者 Observable发送的事件 = Error事件，那么 原始Observable则不重新发送事件：
                // 2. 若 新的被观察者 Observable发送的事件 = Next事件 ，那么原始的Observable则重新发送事件：
                return throwableObservable.flatMap(new Function<Throwable, ObservableSource<?>>() {
                    @Override
                    public ObservableSource<?> apply(@NonNull Throwable throwable) throws Exception {
                        // 1. 若返回的Observable发送的事件 = Error事件，则原始的Observable不重新发送事件
                        // 该异常错误信息可在观察者中的onError（）中获得
                        return Observable.error(new Throwable("retryWhen终止啦"));
                        // 2. 若返回的Observable发送的事件 = Next事件，则原始的Observable重新发送事件（若持续遇到错误，则持续重试）
                        // return Observable.just(1);
                    }
                });
            }
        }).subscribe(new Observer<Integer>() {
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


    }
```
![这里写图片描述](https://img-blog.csdn.net/20180815101120781)
### 七.重复发生操作
需求场景：重复不断地发送被观察者事件
#### 1.repeat（）
* 作用：无条件地、重复发送 被观察者事件
* 具体使用

```java
   Observable.just(1, 2, 3, 4)
                .repeat(3) // 重复创建次数 =- 3次});
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
![这里写图片描述](https://img-blog.csdn.net/20180815101806919)
#### 2.repeatWhen（）
作用：有条件地、重复发送 被观察者事件
原理：将原始 Observable 停止发送事件的标识（Complete（） / Error（））转换成1个 Object 类型数据传递给1个新被观察者（Observable），以此决定是否重新订阅 & 发送原来的 Observable

具体使用：
```java
Observable.just(1, 2, 3, 4)
                .repeatWhen(new Function<Observable<Object>, ObservableSource<?>>() {
                    @Override
                    // 在Function函数中，必须对输入的 Observable<Object>进行处理，这里我们使用的是flatMap操作符接收上游的数据
                    public ObservableSource<?> apply(@NonNull Observable<Object> objectObservable) throws Exception {
                        // 将原始 Observable 停止发送事件的标识（Complete（） / Error（））转换成1个 Object 类型数据传递给1个新被观察者（Observable）
                        // 以此决定是否重新订阅 & 发送原来的 Observable
                        // 此处有2种情况：
                        // 1. 若新被观察者（Observable）返回1个Complete（） / Error（）事件，则不重新订阅 & 发送原来的 Observable
                        // 2. 若新被观察者（Observable）返回其余事件，则重新订阅 & 发送原来的 Observable
                        return objectObservable.flatMap(new Function<Object, ObservableSource<?>>() {
                            @Override
                            public ObservableSource<?> apply(@NonNull Object throwable) throws Exception {
                                // 情况1：若新被观察者（Observable）返回1个Complete（） / Error（）事件，则不重新订阅 & 发送原来的 Observable
                                return Observable.empty();
                                // Observable.empty() = 发送Complete事件，但不会回调观察者的onComplete（）
                                // return Observable.error(new Throwable("不再重新订阅事件"));
                                // 返回Error事件 = 回调onError（）事件，并接收传过去的错误信息。
                                // 情况2：若新被观察者（Observable）返回其余事件，则重新订阅 & 发送原来的 Observable
                                //return Observable.just(1);
                                // 仅仅是作为1个触发重新订阅被观察者的通知，发送的是什么数据并不重要，只要不是Complete（） / Error（）事件
                            }
                        });
                    }
                })
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
![这里写图片描述](https://img-blog.csdn.net/20180815102341701)
![这里写图片描述](https://img-blog.csdn.net/20180815102434202 )
### 八.参考资料
[Rxjava中文文档](https://mcxiaoke.gitbooks.io/rxdocs/content/operators/Materialize.html)
[Android RxJava：功能性操作符 全面讲解 ](https://www.jianshu.com/p/b0c3669affdb)
[Android RxJava2(五)功能操作符](https://blog.csdn.net/mixin716/article/details/80612510)


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
