---
title: "Android之Rxjava2.X 7————Rxjava 条件操作符"
date: 2019-04-07T22:40:54+08:00
draft: false
categories: ["Android","Android之Rxjava"]
tags: ["Android","Rxjava"]
---

### 一. 目录
@[toc]
### 二. 概述
#### 1.作用
通过设置函数，判断被观察者（Observable）发送的事件是否符合条件
#### 2.类型
![这里写图片描述](/image/Android_Rxjava/8_0.png)
### 三. 具体操作符详解
#### 1.all（）
作用：判定是否Observable发射的所有数据都满足某个条件
![这里写图片描述](/image/Android_Rxjava/8_1.png)

具体使用：
```java
 private void rxJavaDemo10() {
        Observable.just(1, 2, 3, 4, 5).
                all(new Predicate<Integer>() {
            @Override
            public boolean test(Integer integer) throws Exception {
                return integer <= 10;
            }
        }).subscribe(new Consumer<Boolean>() {
            @Override
            public void accept(Boolean aBoolean) throws Exception {
                Log.d(TAG, "accept: "+aBoolean);
            }
        });


    }
```
![这里写图片描述](/image/Android_Rxjava/8_2.png )
#### 2.takeWhile（）
* 作用：发射Observable发射的数据，直到一个指定的条件不成立

原理图：
![这里写图片描述](/image/Android_Rxjava/8_3.png)

具体使用
```java
  Observable.just(1, 2, 3, 4, 5)
                .takeWhile(new Predicate<Integer>() {
                    @Override
                    public boolean test(Integer integer) throws Exception {
                         return (integer!=3);
                    }
                }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(Integer integer) throws Exception {
                Log.d(TAG, "accept: "+integer);

            }
        });
```
![这里写图片描述](/image/Android_Rxjava/8_4.png)

#### 3.skipWhile（）
* 作用:丢弃Observable发射的数据，直到一个指定的条件不成立

原理图:
[外链图片转存中...(img-d2GyVdTj-1579436018931)]

具体使用
```java
Observable.just(1, 2, 3, 4, 5)
                .skipWhile(new Predicate<Integer>() {
                    @Override
                    public boolean test(Integer integer) throws Exception {
                         return (integer!=3);
                    }
                }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(Integer integer) throws Exception {
                Log.d(TAG, "accept: "+integer);

            }
        });
```
![这里写图片描述](/image/Android_Rxjava/8_5.png)
#### 4.takeUntil（）
* 作用1：takeUntil（new Predicate） 执行到某个条件时，停止发送事件
* 作用2：takeUntil（new Observer） takeUntil（） 传入的Observable开始发送数据，（原始）第1个Observable的数据停止发送数据

原理图
[外链图片转存中...(img-I1eDDkDX-1579436018932)]
![这里写图片描述](/image/Android_Rxjava/8_6.png)
具体使用1:
```java
 Observable.just(1, 2, 3, 4, 5)
                .takeUntil(new Predicate<Integer>() {
                    @Override
                    public boolean test(Integer integer) throws Exception {
                         return (integer==3);
                    }
                }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(Integer integer) throws Exception {
                Log.d(TAG, "accept: "+integer);

            }
        });
```
![这里写图片描述](/image/Android_Rxjava/8_7.png)

具体使用2
```java
Observable.interval(1, TimeUnit.SECONDS)
                // 第2个Observable：延迟5s后开始发送1个Long型数据
                .takeUntil(Observable.timer(5, TimeUnit.SECONDS))
                .subscribe(new Consumer<Long>() {
                    @Override
                    public void accept(Long integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/8_8.png)
#### 5.skipUntil（）
* 作用：等到 skipUntil（） 传入的Observable开始发送数据，（原始）第1个Observable的数据才开始发送数据

原理图:
[外链图片转存中...(img-DRBqP1Fk-1579436018932)]

具体使用
```java
Observable.interval(1, TimeUnit.SECONDS)
                // 第2个Observable：延迟5s后开始发送1个Long型数据
                .skipUntil(Observable.timer(5, TimeUnit.SECONDS))
                .subscribe(new Consumer<Long>() {
                    @Override
                    public void accept(Long integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/8_9.png)
#### 6.SequenceEqual（）
* 作用：判定两个Observables是否发射相同的数据序列。若相同，返回 true；否则，返回 false

原理图：
[外链图片转存中...(img-vVvun1TX-1579436018933)]

具体使用：
```java
 Observable
                .sequenceEqual(Observable.just(1,2,3,4),Observable.just(1,2,3,4))
                .subscribe(new Consumer<Boolean>() {
                    @Override
                    public void accept(Boolean integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/8_10.png)
#### 7.contains（）
* 作用：判断发送的数据中是否包含指定数据

原理图：
![这里写图片描述](/image/Android_Rxjava/8_11.png)

具体使用
```java
Observable.just(1, 2, 3, 4, 5, 6)
                .contains(4)
                .subscribe(new Consumer<Boolean>() {
                    @Override
                    public void accept(Boolean integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/8_12.png)
#### 8.isEmpty（）
* 作用:判断发送的数据是否为空

原理图：
![这里写图片描述](/image/Android_Rxjava/8_13.png)

具体使用
```java
Observable.just(1, 2, 3, 4, 5, 6)
                .isEmpty()
                .subscribe(new Consumer<Boolean>() {
                    @Override
                    public void accept(Boolean integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });

```
![这里写图片描述](/image/Android_Rxjava/8_14.png)
#### 9.amb（）
* 作用:当需要发送多个 Observable时，只发送 先发送数据的Observable的数据，而其余 Observable则被丢弃。

原理图：
[外链图片转存中...(img-TjTy3fH9-1579436018934)]

具体使用
```java
 List<ObservableSource<Integer>> list= new ArrayList <>();
        list.add( Observable.just(1,2,3).delay(1,TimeUnit.SECONDS));
        list.add( Observable.just(4,5,6));

        Observable.amb(list)
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });
```

#### 10.defaultIfEmpty（）
* 作用: 在不发送任何有效事件（ Next事件）、仅发送了 Complete 事件的前提下，发送一个默认值

原理图：
![这里写图片描述](/image/Android_Rxjava/8_15.png)

具体使用
```java
  Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> e) throws Exception {
                e.onComplete();
            }
        }).defaultIfEmpty(10)
                .subscribe(new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) throws Exception {
                        Log.d(TAG, "accept: " + integer);

                    }
                });

```
![这里写图片描述](/image/Android_Rxjava/8_16.png?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 四. 参考资料
[Rxjava中文文档](https://mcxiaoke.gitbooks.io/rxdocs/content/operators/Conditional.html)
[Android RxJava2(六)条件操作符](https://blog.csdn.net/mixin716/article/details/80624445)
[Android RxJava：详解 条件 / 布尔操作符](https://www.jianshu.com/p/954426f90325)

### 五.文章索引
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
