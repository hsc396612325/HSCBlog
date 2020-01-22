# Android之Rxjava2.X 8————Rxjava 背压策略
### 一.目录
@[toc]
**注:本文大部分参考[Android RxJava ：图文详解 背压策略](https://www.jianshu.com/p/ceb48ed8719d)**
### 二.背压的引入
#### 1.同步订阅
* 定义：观察者和被观察者处于同一线程里。
* 被观察者发送事件的特点：被观察者没发送一个事件，必须等到观察者接收并处理后，才能继续发送下一个事件。
#### 2.异步订阅
* 定义：观察者和被观察者处于不同的线程中。
* 被观察者发送事件的特点：被观察者不需要等待观察者接收或者处理事件，而是不断发送，直到事件发生完毕。但此时的事件并不会直接发送给观察者。而是存在于缓存区，等待被观察者从中取出事件。

#### 3.存在的问题
在异步订阅的(比如网络请求)，被观察者发生事件的速度太快，观察者来不及接受所有的事件，从而缓存区中的事件越积越多，最终导致缓存区溢出，事件丢失并OOM
比如：
```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                int i = 0;
                while (true) {
                    i++;
                    e.onNext(i);
                }
            }
        }).subscribeOn(Schedulers.newThread()).observeOn(Schedulers.newThread()).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(Integer integer) throws Exception {
                Thread.sleep(5000);
                System.out.println(integer);
            }
        });
```
![这里写图片描述](https://img-blog.csdn.net/20180816111442735)
而背压策略就是为了解决上述的问题，而引入的
### 三.背压的概述
#### 1.背压定义
Backpressure，也称为Reactive Pull，就是下游需要多少（具体是通过下游的request请求指定需要多少），上游就发送多少。
#### 2.背压的作用
在异步场景中，被观察者发送事件速度远快于观察者的处理速度的情况下，一种告诉上游的被观察者降低发送速度的策略
#### 3.背压的原理
背压策略的原理：

* 对于观察者：响应式拉取，即观察者根据自己的实际需求接受事件
* 对于被观察者:反馈控制，即被观察者根据观察者的接受能力，从而控制发送事件的速度
* 对于缓存区：对超出缓存区大小的事件进行丢弃，保留，报错。

![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtZDM3Yjg5Yjg2YWVhMTA0ZC5wbmc?x-oss-process=image/format,png)
### 四.背压的实现Flowable
#### 1.Flowable 介绍
在Rxjava2.0中，被观察者(Observable)的一种新实现，但和Observable不同之处，在于Flowable实现了非阻塞式背压策略。
#### 2.Flowable 特点
* 对应的观察者变为Subscriber
* 所有操作符强制支持背压
* 默认的缓存区的大小为：128
* 缓存区的使用队列存放事件
#### 3.Flowable的基本使用
```java
Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                Log.d(TAG, "发送事件 1");
                                emitter.onNext(1);
                                Log.d(TAG, "发送事件 2");
                                emitter.onNext(2);
                                Log.d(TAG, "发送事件 3");
                                emitter.onNext(3);
                                Log.d(TAG, "发送完成");
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribe(new Subscriber<Integer>() {
            @Override
            public void onSubscribe(Subscription s) {
                Log.d(TAG, "onSubscribe");
                s.request(3);
            }

            @Override
            public void onNext(Integer integer) {
                Log.d(TAG, "接收到了事件" + integer);
            }

            @Override
            public void onError(Throwable t) {
                Log.w(TAG, "onError: ", t);
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete");
            }


        });
```
![这里写图片描述](https://img-blog.csdn.net/2018081615155320)
### 五.背压的使用
#### 1. 控制观察者接受事件的速度
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtYzAxNmI3MWEwODAyNjViMC5wbmc?x-oss-process=image/format,png)
##### 1.1 异步订阅情况
* 简介：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtYzAxNmI3MWEwODAyNjViMC5wbmc?x-oss-process=image/format,png)
* 具体使用
```java
 Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                Log.d(TAG, "发送事件 1");
                                emitter.onNext(1);
                                Log.d(TAG, "发送事件 2");
                                emitter.onNext(2);
                                Log.d(TAG, "发送事件 3");
                                emitter.onNext(3);
                                Log.d(TAG, "发送事件 4");
                                emitter.onNext(4);
                                Log.d(TAG, "发送完成");
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribeOn(Schedulers.io()) // 设置被观察者在io线程中进行
                .observeOn(AndroidSchedulers.mainThread()) // 设置观察者在主线程中进行
                .subscribe(new Subscriber<Integer>() {
                    @Override
                    public void onSubscribe(Subscription s) {
                        Log.d(TAG, "onSubscribe");
                        s.request(3);
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "接收到了事件" + integer);
                    }

                    @Override
                    public void onError(Throwable t) {
                        Log.w(TAG, "onError: ", t);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete");
                    }


                });
```
![这里写图片描述](https://img-blog.csdn.net/20180816153834482)

* 特别注意：对与异步订阅情况，如果观察者没有设置Subscription.request(long n),即说明观察者不接受事件，但此时
	
**代码演示**：观察者不接收事件的情况下，被观察者继续发送事件 & 存放到缓存区；再按需求取出
```java

        Button button = findViewById(R.id.bt);

        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mSubscription.request(2);
            }
        });


        Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                Log.d(TAG, "发送事件 1");
                                emitter.onNext(1);
                                Log.d(TAG, "发送事件 2");
                                emitter.onNext(2);
                                Log.d(TAG, "发送事件 3");
                                emitter.onNext(3);
                                Log.d(TAG, "发送事件 4");
                                emitter.onNext(4);
                                Log.d(TAG, "发送完成");
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribeOn(Schedulers.io()) // 设置被观察者在io线程中进行
                .observeOn(AndroidSchedulers.mainThread()) // 设置观察者在主线程中进行
                .subscribe(new Subscriber<Integer>() {
                    @Override
                    public void onSubscribe(Subscription s) {
                        Log.d(TAG, "onSubscribe");
                        mSubscription = s;
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "接收到了事件" + integer);
                    }

                    @Override
                    public void onError(Throwable t) {
                        Log.w(TAG, "onError: ", t);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete");
                    }


                });
```
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtODYzZDY1OWUxZjZmMDE5Yy5naWY)

**代码演示2**：观察者不接收事件的情况下，被观察者继续发送事件至超出缓存区大小
```java

        Button button = findViewById(R.id.bt);

        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mSubscription.request(2);
            }
        });


        Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                for (int i = 0;i< 129; i++) {
                                    Log.d(TAG, "发送了事件" + i);
                                    emitter.onNext(i);
                                }
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribeOn(Schedulers.io()) // 设置被观察者在io线程中进行
                .observeOn(AndroidSchedulers.mainThread()) // 设置观察者在主线程中进行
                .subscribe(new Subscriber<Integer>() {
                    @Override
                    public void onSubscribe(Subscription s) {
                        Log.d(TAG, "onSubscribe");
                        // 默认不设置可接收事件大小
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "接收到了事件" + integer);
                    }

                    @Override
                    public void onError(Throwable t) {
                        Log.w(TAG, "onError: ", t);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete");
                    }


                });
```
![这里写图片描述](https://img-blog.csdn.net/20180816161004697?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

##### 1.2 同步订阅情况
同步订阅 & 异步订阅 的区别在于：

* 同步订阅中，被观察者 & 观察者工作于同1线程
* 同步订阅关系中没有缓存区

被观察者在发送1个事件后，必须等待观察者接收后，才能继续发下1个事件
```java
 Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                for (int i = 0; i < 3; i++) {
                                    Log.d(TAG, "发送了事件" + i);
                                    emitter.onNext(i);
                                }
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribe(new Subscriber<Integer>() {
            @Override
            public void onSubscribe(Subscription s) {
                Log.d(TAG, "onSubscribe");
                // 默认不设置可接收事件大小
                s.request(3);
            }

            @Override
            public void onNext(Integer integer) {
                Log.d(TAG, "接收到了事件" + integer);
            }

            @Override
            public void onError(Throwable t) {
                Log.w(TAG, "onError: ", t);
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete");
            }


        });
```
![这里写图片描述](https://img-blog.csdn.net/20180816161828233)
示意图

所以，实际上并不会出现被观察者发送事件速度 > 观察者接收事件速度的情况。可是，却会出现被观察者发送事件数量 > 观察者接收事件数量的问题。

代码演示：被观察者发送事件数量 > 观察者接收事件数量
```java
Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                for (int i = 0; i < 4; i++) {
                                    Log.d(TAG, "发送了事件" + i);
                                    emitter.onNext(i);
                                }
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribe(new Subscriber<Integer>() {
            @Override
            public void onSubscribe(Subscription s) {
                Log.d(TAG, "onSubscribe");
                // 默认不设置可接收事件大小
                s.request(3);
            }

            @Override
            public void onNext(Integer integer) {
                Log.d(TAG, "接收到了事件" + integer);
            }

            @Override
            public void onError(Throwable t) {
                Log.w(TAG, "onError: ", t);
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete");
            }


        });
```
![这里写图片描述](https://img-blog.csdn.net/20180816162105794?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

* 有1个特殊情况需要注意:如果观察者没有设置Subscription.request(long n),此时被观察者开始发送事件，那么被观察者不会收到被观察者的任何事件，并且抛出MissingBackpreeureException异常


#### 2. 控制 被观察者发送事件 的速度
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtZjE4YTQwYjU5N2M2OGM4Zi5wbmc?x-oss-process=image/format,png)

* FlowableEmitter类的requested()介绍
```java
public interface FlowableEmitter<T> extends Emitter<T> {
// FlowableEmitter = 1个接口，继承自Emitter
// Emitter接口方法包括：onNext(),onComplete() & onError

 long requested();
  // 作用：返回当前线程中request（a）中的a值
  // 该request（a）则是措施1中讲解的方法，作用  = 设置
  }
```
每个线程中的requested（）的返回值 = 该线程中的request（a）的a值

原理图：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtODhlMWYzYzY0MWViNTRlMy5wbmc?x-oss-process=image/format,png)

##### 2.1 同步订阅情况
即在同步订阅情况中，被观察者 通过 FlowableEmitter.requested()获得了观察者自身接收事件能力，从而根据该信息控制事件发送速度，从而达到了观察者反向控制被观察者的效果

具体使用
下面的例子 = 被观察者根据观察者自身接收事件能力（3个事件），从而仅发送3个事件
```java
 Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                // 调用emitter.requested()获取当前观察者需要接收的事件数量
                                long n = emitter.requested();

                                Log.d(TAG, "subscribe: " + n);

                                for (int i = 0; i < n; i++) {
                                    Log.d(TAG, "发送了事件" + i);
                                    emitter.onNext(i);
                                }
                                emitter.onComplete();
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribe(new Subscriber<Integer>() {
            @Override
            public void onSubscribe(Subscription s) {
                Log.d(TAG, "onSubscribe");
                // 默认不设置可接收事件大小
                s.request(3);
            }

            @Override
            public void onNext(Integer integer) {
                Log.d(TAG, "接收到了事件" + integer);
            }

            @Override
            public void onError(Throwable t) {
                Log.w(TAG, "onError: ", t);
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete");
            }


        });
```
![这里写图片描述](https://img-blog.csdn.net/20180816164147567)
使用特性：

* 可叠加性： 观查者可连续接收事件，被观察者会进行叠加一起发送
* 实时更新性：每次发送事件后，FlowbleEmitter.requested() 的其发扭转会实时更新观察者能接受的事件。
* 异常：当FlowbleEmitter.requested()的返回值 = 0 时，则代表观察者已经不可接收事件，此时被观察者若继续发送事件，则会抛出MissgBackpressureException异常

##### 2.2 异步订阅情况
异步订阅不同与同步订阅的情形，异步订阅由于两者不在同一个线程中，，所以被观察者 无法通过 FlowableEmitter.requested()知道观察者自身接收事件能力，即 被观察者不能根据 观察者自身接收事件的能力 控制发送事件的速度。具体请看下面例子
```java
  Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                // 调用emitter.requested()获取当前观察者需要接收的事件数量
                                Log.d(TAG, "观察者可接收事件数量 = " + emitter.requested());


                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(new Subscriber<Integer>() {
                    @Override
                    public void onSubscribe(Subscription s) {
                        Log.d(TAG, "onSubscribe");
                        // 默认不设置可接收事件大小
                        s.request(150);
                }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "接收到了事件" + integer);
                    }

                    @Override
                    public void onError(Throwable t) {
                        Log.w(TAG, "onError: ", t);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete");
                    }


                });
```
![这里写图片描述](https://img-blog.csdn.net/20180816171934817)

**而在异步订阅关系中，反向控制的原理是：通过RxJava内部固定调用被观察者线程中的request(n) 从而 反向控制被观察者的发送事件速度**

关于RxJava内部调用request(n)（n = 128、96、0）的逻辑如下：
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtZjYzMTRhYmE2MGMwODQ1NS5wbmc?x-oss-process=image/format,png)

代码演示
```java
Button button = findViewById(R.id.bt);

        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mSubscription.request(48);
            }
        });


        Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                // 调用emitter.requested()获取当前观察者需要接收的事件数量
                                Log.d(TAG, "观察者可接收事件数量 = " + emitter.requested());
                                boolean flag; //设置标记位控制

                                // 被观察者一共需要发送500个事件
                                for (int i = 0; i < 500; i++) {
                                    flag = false;
                                    // 若requested() == 0则不发送
                                    while (emitter.requested() == 0) {
                                        if (!flag) {
                                            Log.d(TAG, "不再发送");
                                            flag = true;
                                        }
                                    }

                                    // requested() ≠ 0 才发送
                                    Log.d(TAG, "发送了事件" + i + "，观察者可接收事件数量 = " + emitter.requested());
                                    emitter.onNext(i);
                                }
                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(new Subscriber<Integer>() {
                    @Override
                    public void onSubscribe(Subscription s) {
                        Log.d(TAG, "onSubscribe");
                        mSubscription = s;
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "接收到了事件" + integer);
                    }

                    @Override
                    public void onError(Throwable t) {
                        Log.w(TAG, "onError: ", t);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete");
                    }


                });
```
![这里写图片描述](https://img-blog.csdn.net/20180816172709116)
点击两次按钮后
![这里写图片描述](https://img-blog.csdn.net/20180816172742683)

#### 3.采用背压策略模式
##### 3.1 背压模式介绍：
在Flowable的使用中，会被要求传入背压模式参数。
其作用是:当缓存区大小存满、被观察者仍然继续发送下1个事件时，该如何处理的策略方式

##### 3.2 背压模式类型
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtNDdiNTVlZGVjMjk5ZmFlYS5wbmc?x-oss-process=image/format,png)

**模式1：BackpressureStrategy.ERROR**
处理方法：直接抛出异常
代码演示
```java
Flowable.create(new FlowableOnSubscribe<Integer>() {
                            @Override
                            public void subscribe(FlowableEmitter<Integer> emitter) throws Exception {
                                // 发送 129个事件
                                for (int i = 0; i < 129; i++) {
                                    Log.d(TAG, "发送了事件" + i);
                                    emitter.onNext(i);
                                }
                                emitter.onComplete();

                            }
                        },
                BackpressureStrategy.ERROR

        ).subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(new Subscriber<Integer>() {
                    @Override
                    public void onSubscribe(Subscription s) {
                        Log.d(TAG, "onSubscribe");
                        
                    }

                    @Override
                    public void onNext(Integer integer) {
                        Log.d(TAG, "接收到了事件" + integer);
                    }

                    @Override
                    public void onError(Throwable t) {
                        Log.w(TAG, "onError: ", t);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete");
                    }


                });
```
![这里写图片描述](https://img-blog.csdn.net/20180816173852330)

**模式2：BackpressureStrategy.MISSING**
处理方法：友好提示：缓存区满了
代码同上 不过把BackpressureStrategy.ERROR-->BackpressureStrategy.MISSING

![这里写图片描述](https://img-blog.csdn.net/20180816174242526)

**模式3：BackpressureStrategy.BUFFER**
处理方法：将缓存区大小设置成无限大
代码同上 不过把BackpressureStrategy.ERROR-->BackpressureStrategy.BUFFER
![这里写图片描述](https://img-blog.csdn.net/20180816175342498)

**模式4： BackpressureStrategy.DROP**
处理方法：超过缓存区大小（128）的事件丢弃
代码同上 不过把BackpressureStrategy.ERROR-->BackpressureStrategy.DROP
![这里写图片描述](https://img-blog.csdn.net/20180816192300922)
**模式5：BackpressureStrategy.LATEST**
处理方法：只保存最新（最后）事件，超过缓存区大小（128）的事件丢弃（即如果发送了150个事件，缓存区里会保存129个事件（第1-第128 + 第150事件））
![这里写图片描述](https://img-blog.csdn.net/20180816192420748?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 六.参考资料
[Android RxJava ：图文详解 背压策略](https://www.jianshu.com/p/ceb48ed8719d)
[关于RxJava最友好的文章——背压（Backpressure）](https://www.jianshu.com/p/2c4799fa91a4)
[Rxjava2入门教程五：Flowable背压支持——对Flowable最全面而详细的讲解](https://www.jianshu.com/p/ff8167c1d191)


### 七.文章索引
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
