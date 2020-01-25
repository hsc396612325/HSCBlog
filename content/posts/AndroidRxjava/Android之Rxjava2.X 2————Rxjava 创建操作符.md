---
title: "Android之Rxjava2.X 2————Rxjava 创建操作符"
date: 2019-04-02T22:40:54+08:00
draft: false
categories: ["Android","Android之Rxjava"]
tags: ["Android","Rxjava"]
---

### 一.目录
@[toc]
### 二.概述
#### 1.作用
创建 被观察者（ Observable） 对象 & 发送事件。
#### 2. 类型
![这里写图片描述](/image/Android_Rxjava/4_0.png)
### 三.基本创建
需求场景: 完整的创建被观察者对象
#### 1. create（）
你可以使用Create操作符创建一个完整的Observable，可以传递onNext，onError和onCompleted等事件。
![这里写图片描述](/image/Android_Rxjava/4_1.png)
代码示例：
```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                e.onNext(1);
                e.onNext(2);
                e.onNext(3);
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
                Log.d(TAG, "onError: "+e);
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete: ");
            }
        });
```
运行结果
![这里写图片描述](/image/Android_Rxjava/4_2.png)

注意:当观察者发送一个Complete/Error事件后，被观察者在，Complrte/Error事件将会继续发送，但观察者收到Complete/Error事件后，不会继续接收任何事件。被观察者可以不发生Complete/Erroe事件
### 四.快速创建
需求场景：快速的创建被观察者对象
#### 1.just()
* 作用:快速创建1个被观察者对象（Observable）
* 发送事件的特点：直接发送传入的事件
* 注意1:just最多只能发送9个参数
* 注意2：如果你传递null给Just，它会返回一个发射null值的Observable
![这里写图片描述](/image/Android_Rxjava/4_3.png)
代码示例
```java
  Observable.just(1, 2, 3)
               .subscribe(new Observer<Integer>() {
                   @Override
                   public void onSubscribe(Disposable d) {
                       Log.d(TAG, "onSubscribe: "+d);
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
![这里写图片描述](/image/Android_Rxjava/4_4.png)

#### 2.fromArray（）
* 作用：快速创建一个被观察者对象
* 发送事件的特点：直接发送传入的数据数组
* fromArray会将数组中的数据转换为Observable对象
* 应用场景:被观察者对象（Observable） & 发送10个以上事件（数组形式),数组遍历

图中的From包括fromArray（）以及下面的fromIterable（）
![这里写图片描述](/image/Android_Rxjava/4_5.png)

```java
Integer[] items = { 0, 1, 2, 3, 4 };
        Observable.fromArray(items)
               .subscribe(new Observer<Integer>() {
                   @Override
                   public void onSubscribe(Disposable d) {
                       Log.d(TAG, "onSubscribe: "+d);
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
![这里写图片描述](/image/Android_Rxjava/4_6.png)

#### 3.fromIterable（）
* 作用:快速创建1个被观察者对象（Observable）
* 发送事件的特点:直接发送 传入的集合List数据
* 应用场景:1.快速创建 被观察者对象（Observable） & 发送10个以上事件（集合形式）2.集合元素遍历

```java
  List<Integer> list = new ArrayList<>();
        list.add(1);
        list.add(2);
        list.add(3);
        Observable.fromIterable(list)
               .subscribe(new Observer<Integer>() {
                   @Override
                   public void onSubscribe(Disposable d) {
                       Log.d(TAG, "onSubscribe: "+d);
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
    }
```
![这里写图片描述](/image/Android_Rxjava/4_7.png)

#### 4.其他
 下列方法一般用于测试使用
empty():仅发送Complete事件，直接通知完成
error():仅发送Error事件，直接通知异常
never():不发送任何事件

```java
 Observable.empty()
               .subscribe(new Observer<Object>() {
                   @Override
                   public void onSubscribe(Disposable d) {
                       Log.d(TAG, "onSubscribe: "+d);
                   }

                   @Override
                   public void onNext(Object o) {
                       Log.d(TAG, "onNext: "+o);
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

 Observable.error(new RuntimeException())
               .subscribe(new Observer<Object>() {
                   @Override
                   public void onSubscribe(Disposable d) {
                       Log.d(TAG, "onSubscribe: "+d);
                   }

                   @Override
                   public void onNext(Object o) {
                       Log.d(TAG, "onNext: "+o);
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
Observable.never()
               .subscribe(new Observer<Object>() {
                   @Override
                   public void onSubscribe(Disposable d) {
                       Log.d(TAG, "onSubscribe: "+d);
                   }

                   @Override
                   public void onNext(Object o) {
                       Log.d(TAG, "onNext: "+o);
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
![这里写图片描述](/image/Android_Rxjava/4_8.png)

![这里写图片描述](/image/Android_Rxjava/4_9.png)

![这里写图片描述](/image/Android_Rxjava/4_10.png)

### 五. 延迟创建
需求场景：

* 定时操作：在经过了x秒后，需要自动执行y操作
*   周期性操作：每隔x秒后，需要自动执行y操作
#### 1.defer（）
* 作用:defer（）操作符会一直等待直到有观察者订阅它，然后它使用Observable工厂方法生成一个Observable。在某些情况下，等待直到最后一分钟（就是知道订阅发生时）才生成Observable可以确保Observable包含最新的数据。
* 使用场景：动态创建被观察者对象（Observable） & 获取最新的Observable对象数据

![这里写图片描述](/image/Android_Rxjava/4_11.png)

```java
  //  1. 第1次对i赋值
         i= 10;

        Observable<Integer> observable = Observable.defer(new Callable<ObservableSource<? extends Integer>>() {
            @Override
            public ObservableSource<? extends Integer> call() throws Exception {
                return Observable.just(i);
            }
        });

        //  1. 第1次对i赋值
        i = 15;
        observable
                .subscribe(new Observer<Object>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: " + d);
                    }

                    @Override
                    public void onNext(Object o) {
                        Log.d(TAG, "onNext: " + o);
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
![这里写图片描述](/image/Android_Rxjava/4_12.png)

#### 2.timer（）
* 作用:创建一个Observable，它在一个给定的延迟后发射一个特殊的值。
* 应用:延迟指定事件，发送一个0，一般用于检测
![这里写图片描述](/image/Android_Rxjava/4_13.png)
```java
        // 该例子 = 延迟2s后，发送一个long类型数值
        Observable.timer(2, TimeUnit.SECONDS).subscribe(new Observer<Long>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "开始采用subscribe连接");
            }

            @Override
            public void onNext(Long value) {
                Log.d(TAG, "接收到了事件" + value);
            }

            @Override
            public void onError(Throwable e) {
                Log.d(TAG, "对Error事件作出响应");
            }

            @Override
            public void onComplete() {
                Log.d(TAG, "对Complete事件作出响应");
            }
        });
```
![这里写图片描述](/image/Android_Rxjava/4_14.png)
#### 3.interval（）
* 作用 : 按固定的时间间隔发射一个无限递增的整数序列。
*  interval(long,TimeUnit,Scheduler)) 
*  参数说明： 参数1 = 第1次延迟时间，参数2 = 间隔时间数字，参数3 = 时间单位；
![这里写图片描述](/image/Android_Rxjava/4_15.png)
```java
    Observable.interval(3, 1, TimeUnit.SECONDS)
                // 该例子发送的事件序列特点：延迟3s后发送事件，每隔1秒产生1个数字（从0开始递增1，无限个）
                .subscribe(new Observer<Long>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "开始采用subscribe连接");
                    }

                    @Override
                    public void onNext(Long value) {
                        Log.d(TAG, "接收到了事件" + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "对Error事件作出响应");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "对Complete事件作出响应");
                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/4_16.png)
#### 4.intervalRange（）
* 作用:发送事件的特点：每隔指定时间 就发送 事件，可指定发送的数据（从0开始、无限递增1的的整数）的数量
```java
	// 参数1 = 事件序列起始点；
        // 参数2 = 事件数量；
        // 参数3 = 第1次事件延迟发送时间；
        // 参数4 = 间隔时间数字；
        // 参数5 = 时间单位
Observable.intervalRange(3, 10, 2, 1, TimeUnit.SECONDS)
                // 该例子发送的事件序列特点： 
                // 1. 从3开始，一共发送10个事件； 
                // 2. 第1次延迟2s发送，之后每隔2秒产生1个数字（从0开始递增1，无限个） 
                .subscribe(new Observer<Long>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "开始采用subscribe连接");
                    } // 默认最先调用复写的 onSubscribe（） 

                    @Override
                    public void onNext(Long value) {
                        Log.d(TAG, "接收到了事件" + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "对Error事件作出响应");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "对Complete事件作出响应");
                    }
                });

```
![这里写图片描述](/image/Android_Rxjava/4_17.png)
#### 5.range（） /rangeLong（）
range（） 作用：连续发送 1个事件序列，可指定范围,作用类似于intervalRange（），但区别在于：无延迟发送事件

rangeLong（）类似于range（），区别在于该方法支持数据类型 = Long
![这里写图片描述](/image/Android_Rxjava/4_18.png)
```java
 // 参数说明：
        // 参数1 = 事件序列起始点；
        // 参数2 = 事件数量；
        // 注：若设置为负数，则会抛出异常
        Observable.range(3,10)
                // 该例子发送的事件序列特点：从3开始发送，每次发送事件递增1，一共发送10个事件
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "开始采用subscribe连接");
                    } // 默认最先调用复写的 onSubscribe（）

                    @Override
                    public void onNext(Integer value) {
                        Log.d(TAG, "接收到了事件" + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "对Error事件作出响应");
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "对Complete事件作出响应");
                    }
                });

```
![这里写图片描述](/image/Android_Rxjava/4_19.png)

### 六. 总结
![这里写图片描述](/image/Android_Rxjava/4_20.png)
### 七.参考资料
[ReactiveX文档中文翻译](https://mcxiaoke.gitbooks.io/rxdocs/content/topics/Getting-Started.html)
[Android Rxjava：这是一篇 清晰 & 易懂的Rxjava 入门教程 ](https://www.jianshu.com/p/a406b94f3188)
[Rxjava2入门教程一：函数响应式编程及概述](Rxjava2%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B%E4%B8%80%EF%BC%9A%E5%87%BD%E6%95%B0%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B%E5%8F%8A%E6%A6%82%E8%BF%B0)
[这可能是最好的RxJava 2.x 教程（完结版）](https://www.jianshu.com/p/0cd258eecf60)
[那些年我们错过的响应式编程](https://github.com/kevinyaoo/android-tech-frontier/tree/master/androidweekly/%E9%82%A3%E4%BA%9B%E5%B9%B4%E6%88%91%E4%BB%AC%E9%94%99%E8%BF%87%E7%9A%84%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B)

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
