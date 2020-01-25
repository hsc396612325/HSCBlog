---
title: "Android之Rxjava2.X 4————Rxjava 创建操作符"
date: 2019-04-04T22:40:54+08:00
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
![这里写图片描述](/image/Android_Rxjava/1_0.png)

### 三.组合多个被观察者
#### 1.concat()/concatArray()
* 作用：组合多个被观察者一起发送数据，合并后 按发送顺序串行执行
* 两者区别:组合被观察者的数量，即concat（）组合被观察者数量≤4个，而concatArray（）则可＞4个

原理图：
![这里写图片描述](/image/Android_Rxjava/1_1.png?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L21peGluNzE2/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

具体使用
```java

        Observable.concat(Observable.just(1, 2, 3),
                Observable.just("z", "x", "c")
        ).subscribe(new Observer() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "onSubscribe: ");
            }

            @Override
            public void onNext(Object value) {

                Log.d(TAG, "onNext: "+value);
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
![这里写图片描述](/image/Android_Rxjava/1_2.png)
#### 2.merge()/mergeArray()
* 作用:组合多个被观察者一起发送数据，合并后 按时间线并行执行
* merge()/mergeArray()的区别：组合被观察者的数量，即merge（）组合被观察者数量≤4个，而mergeArray（）则可＞4个
* 和concat（）操作符的区别:同样是组合多个被观察者一起发送数据，但concat（）操作符合并后是按发送顺序串行执行

原理图：
![这里写图片描述](/image/Android_Rxjava/1_3.png?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L21peGluNzE2/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
具体使用：
```java

        Observable.concat( Observable.intervalRange(0, 3, 1, 1, TimeUnit.SECONDS), // 从0开始发送、共发送3个数据、第1次事件延迟发送时间 = 1s、间隔时间 = 1s
                Observable.intervalRange(2, 3, 1, 1, TimeUnit.SECONDS) // 从2开始发送、共发送3个数据、第1次事件延迟发送时间 = 1s、间隔时间 = 1s
        ).subscribe(new Observer<Long>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "onSubscribe: ");
            }

            @Override
            public void onNext(Long value) {

                Log.d(TAG, "onNext: "+value);
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
![这里写图片描述](/image/Android_Rxjava/1_4.png)
#### 3.concatDelayError（） / mergeDelayError（）
作用:在mergeArray()和concatArray()两个方法中，如果其中一个Observable发送了一个Error事件，那么就会停止发送事件，如果想onError()事件延迟到所有Observable都发送完事件后再执行，就可以使用mergeArrayDelayError()和concatArrayDelayError() 

具体使用：无使用concatDelayError（）的情况
```java
 Observable.concat(
                Observable.create(new ObservableOnSubscribe<Integer>() {
                    @Override
                    public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                        emitter.onNext(1);
                        emitter.onNext(2);
                        emitter.onNext(3);
                        emitter.onError(new NullPointerException()); // 发送Error事件，因为无使用concatDelayError，所以第2个Observable将不会发送事件 emitter.onComplete();
                    }
                }),

                Observable.just(4, 5, 6))
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer value) {

                        Log.d(TAG, "onNext: " + value);
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
![这里写图片描述](/image/Android_Rxjava/1_5.png)

使用concatDelayError（）
```java
Observable.concatArrayDelayError(
                Observable.create(new ObservableOnSubscribe<Integer>() {
                    @Override
                    public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                        emitter.onNext(1);
                        emitter.onNext(2);
                        emitter.onNext(3);
                        emitter.onError(new NullPointerException()); // 发送Error事件，因为无使用concatDelayError，所以第2个Observable将不会发送事件 emitter.onComplete();
                    }
                }),

                Observable.just(4, 5, 6))
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer value) {

                        Log.d(TAG, "onNext: " + value);
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
![这里写图片描述](/image/Android_Rxjava/1_6.png)
### 四.合并多个事件
#### 1.zip（）
* 作用：用来合并两个Observable发射的事件，根据BiFunction函数生成一个新的值发射出去。当其中一个Observable发送数据结束或者出现异常后，另一个Observable也将停止发送数据。也就是说正常的情况下数据长度会与两个Observable中最少事件的数量一样。 
* 原理图
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-3SC5XLe1-1579435962670)(/image/Android_Rxjava/1_7.png)]
![这里写图片描述](/image/Android_Rxjava/1_8.png)

具体使用：
```java
 Observable.zip(
                Observable.just("a", "b", "c"),
                Observable.just(1, 2, 3),
                new BiFunction<String, Integer, String>() {

                    @Override
                    public String apply(String s, Integer integer) throws Exception {
                        return s + integer;
                    }
                }).subscribe(new Observer<String>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(String value) {

                        Log.d(TAG, "onNext: " + value);
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
![这里写图片描述](/image/Android_Rxjava/1_9.png)
#### 2.combineLatest（）
* 作用：当两个Observables中的任何一个发送了数据后，将先发送了数据的Observables 的最新（最后）一个数据 与 另外一个Observable发送的每个数据结合，最终基于该函数的结果发送数据
* 与Zip（）的区别：Zip（） = 按个数合并，即1对1合并；CombineLatest（） = 按时间合并，即在同一个时间点上合并

原理图：
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-RWsty10W-1579435962671)(/image/Android_Rxjava/1_10.png)]
![这里写图片描述](/image/Android_Rxjava/1_11.png)

具体使用
```java
Observable.combineLatest(
                Observable.just("a", "b", "c"),
                Observable.intervalRange(0, 3, 1, 1, TimeUnit.SECONDS), // 第2个发送数据事件的Observable：从0开始发送、共发送3个数据、第1次事件延迟发送时间 = 1s、间隔时间 = 1s
                new BiFunction<String, Long, String>() {

                    @Override
                    public String apply(String s, Long l) throws Exception {
                        return s + l;
                    }
                }).subscribe(new Observer<String>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(String value) {

                        Log.d(TAG, "onNext: " + value);
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
![这里写图片描述](/image/Android_Rxjava/1_12.png)
#### 3.combineLatestDelayError（）
* 作用类似于concatDelayError（） / mergeDelayError（） ,见上文
#### 4.reduce（）
* 作用：把被观察者需要发送的事件聚合成1个事件 & 发送
* 聚合的逻辑根据需求撰写，但本质都是前2个数据聚合，然后与后1个数据继续进行聚合，依次类推

具体使用：
```java
  Observable.just(1,2,3,4,5).reduce(new BiFunction<Integer, Integer, Integer>() {
            @Override
            public Integer apply(Integer integer, Integer integer2) throws Exception {
                return integer + integer2;
            }
        }).subscribe(new Consumer<Integer>() {
            @Override
            public void accept(Integer integer) throws Exception {
               Log.d(TAG, "accept: "+integer);
            }
        });
```
![这里写图片描述](/image/Android_Rxjava/1_13.png)
#### 5.collect（）
* 作用：将被观察者Observable发送的数据事件收集到一个数据结构里

具体使用
```java
 Observable.just("1","2","3","2")
                .collect(new Callable<List<Integer>>() { //创建数据结构
                    @Override
                    public List<Integer> call() throws Exception {
                        return new ArrayList<Integer>();
                    }
                }, new BiConsumer<List<Integer>, String>() {//收集器
                    @Override
                    public void accept(List<Integer> integers, String s) throws Exception {
                        integers.add(Integer.valueOf(s));
                    }
                }).subscribe(new Consumer<List<Integer>>() {
            @Override
            public void accept(List<Integer> integers) throws Exception {
                Log.e("---",integers+"");
            }
        });
```
![这里写图片描述](/image/Android_Rxjava/1_14.png?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 五.发送事件前追加发送事件
#### 1.startWith（） / startWithArray（）
* 作用：在一个被观察者发送事件前，追加发送一些数据 / 一个新的被观察者
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-1dvy3wrq-1579435962672)(/image/Android_Rxjava/1_15.png)]
![这里写图片描述](/image/Android_Rxjava/1_16.png)
具体使用：
```java
Observable.just(1, 2, 3)
                .startWith(0)  // 追加单个数据 = startWith()
                .startWithArray(1, 2, 3) // 追加多个数据 = startWithArray()
                .subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer value) {
                        Log.d(TAG, "onNext: " + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });


        Observable.just(1, 2, 3).
                startWith(Observable.just(4, 5, 6)).
                subscribe(new Observer<Integer>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: ");
                    }

                    @Override
                    public void onNext(Integer value) {
                        Log.d(TAG, "onNext: " + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/1_17.png)
### 六.统计发送事件的数量
#### 1.count（）
* 作用：统计被观察者发送事件的数量

具体使用：
```java
  Observable.just(1, 2, 3)
                .count()
                .subscribe(new Consumer<Long>() {
                    @Override
                    public void accept(Long aLong) throws Exception {
                        Log.e(TAG, "发送的事件数量 =  " + aLong);

                    }
                });
```
![这里写图片描述](/image/Android_Rxjava/1_18.png）

### 七.参考资料
[ReactiveX文档中文翻译](https://mcxiaoke.gitbooks.io/rxdocs/content/topics/Getting-Started.html)
[Android Rxjava：这是一篇 清晰 & 易懂的Rxjava 入门教程 ](https://www.jianshu.com/p/a406b94f3188)
[Rxjava2入门教程一：函数响应式编程及概述](Rxjava2%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B%E4%B8%80%EF%BC%9A%E5%87%BD%E6%95%B0%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B%E5%8F%8A%E6%A6%82%E8%BF%B0)
[这可能是最好的RxJava 2.x 教程（完结版）](https://www.jianshu.com/p/0cd258eecf60)
[那些年我们错过的响应式编程](https://github.com/kevinyaoo/android-tech-frontier/tree/master/androidweekly/%E9%82%A3%E4%BA%9B%E5%B9%B4%E6%88%91%E4%BB%AC%E9%94%99%E8%BF%87%E7%9A%84%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B)
