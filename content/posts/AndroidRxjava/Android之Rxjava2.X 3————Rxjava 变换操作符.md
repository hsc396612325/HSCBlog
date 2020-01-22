# Android之Rxjava2.X 3————Rxjava 变换操作符
### 一. 目录
@[toc]
### 二.概述
#### 1.作用
对事件序列中的事件 / 整个事件序列 进行加工处理（即变换），使得其转变成不同的事件 / 整个事件序列

#### 2. 类型
常见的变化操作符如下
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtNzFlYjU2OWIyOTZjMWYxOC5wbmc?x-oss-process=image/format,png)
### 三.对应操作符的介绍
#### 1.Map()
* 作用：对Observable发射的每一项数据应用一个函数，执行变换操作
* 应用场景：数据类型转化
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-bDsNsOUP-1579367058397)(https://mcxiaoke.gitbooks.io/rxdocs/content/images/operators/map.png)]

代码示例：
```java
Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onNext(3);
            }

            // 使用Map变换操作符中的Function函数对被观察者发送的事件进行统一变换：整型变换成字符串类型
        }).map(new Function<Integer,String>() {
            @Override
            public String apply(Integer integer) throws Exception {
                return "使用Map操作符 将事件"+integer+"的参数从 整型"+integer + " 变换成 字符串类型" + integer ;
            }
        }).subscribe(new Observer<String>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "开始采用subscribe连接");
                    } // 默认最先调用复写的 onSubscribe（）

                    @Override
                    public void onNext(String value) {
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
![这里写图片描述](https://img-blog.csdn.net/20180814144900776)
#### 2.flatMap()
* 作用：将一个发射数据的Observable变换为多个Observables，然后将它们发射的数据合并后放进一个单独的Observable
* 应用场景:**无序**的将被观察者发送的整个事件序列进行变换
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2ZsYXRNYXAucG5n?x-oss-process=image/format,png)
```java
   Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onNext(3);
            }

            // 使用Map变换操作符中的Function函数对被观察者发送的事件进行统一变换：整型变换成字符串类型
        }).flatMap(new Function<Integer,  ObservableSource<String>>() {
            @Override
            public ObservableSource<String> apply(Integer integer) throws Exception {
                final List<String> list = new ArrayList<>();
                for (int i = 0; i < 3; i++) {
                    list.add("我是事件 " + integer + "拆分后的子事件" + i);
                    // 通过flatMap中将被观察者生产的事件序列先进行拆分，再将每个事件转换为一个新的发送三个String事件
                    // 最终合并，再发送给被观察者
                }
                return Observable.fromIterable(list);

            }
        }).subscribe(new Observer<String>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "开始采用subscribe连接");
            } // 默认最先调用复写的 onSubscribe（）

            @Override
            public void onNext(String value) {
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
![这里写图片描述](https://img-blog.csdn.net/20180814153010364)
#### 3.ConcatMap()
* 作用类似与FlatMap（）操作符
* 区别：拆分 & 重新合并生成的事件序列 的顺序 = 被观察者旧序列生产的顺序
* 用于场景:有序的将被观察者发送的整个事件序列进行变换
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-0aIQHof7-1579367058398)(https://mcxiaoke.gitbooks.io/rxdocs/content/images/operators/concatMap.png)]
```java
 Observable.create(new ObservableOnSubscribe<Integer>() {
            @Override
            public void subscribe(ObservableEmitter<Integer> emitter) throws Exception {
                emitter.onNext(1);
                emitter.onNext(2);
                emitter.onNext(3);
            }

            // 使用Map变换操作符中的Function函数对被观察者发送的事件进行统一变换：整型变换成字符串类型
        }).concatMap(new Function<Integer,  ObservableSource<String>>() {
            @Override
            public ObservableSource<String> apply(Integer integer) throws Exception {
                final List<String> list = new ArrayList<>();
                for (int i = 0; i < 3; i++) {
                    list.add("我是事件 " + integer + "拆分后的子事件" + i);
                    // 通过flatMap中将被观察者生产的事件序列先进行拆分，再将每个事件转换为一个新的发送三个String事件
                    // 最终合并，再发送给被观察者
                }
                return Observable.fromIterable(list);

            }
        }).subscribe(new Observer<String>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "开始采用subscribe连接");
            } // 默认最先调用复写的 onSubscribe（）

            @Override
            public void onNext(String value) {
                Log.d(TAG, "接收到了事件：" + value);
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
![这里写图片描述](https://img-blog.csdn.net/20180814153403162)
#### 4.Buffrt()
* 作用：定期从 被观察者（Obervable）需要发送的事件中 获取一定数量的事件 & 放到缓存区中，最终发送
* 应用场景：缓存被观察者发送的事件
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9tY3hpYW9rZS5naXRib29rcy5pby9yeGRvY3MvY29udGVudC9pbWFnZXMvb3BlcmF0b3JzL2J1ZmZlcjQucG5n?x-oss-process=image/format,png)
```java
Observable.just(1, 2, 3, 4, 5)
                .buffer(3, 1) // 设置缓存区大小 & 步长
                // 缓存区大小 = 每次从被观察者中获取的事件数量
                // 步长 = 每次获取新事件的数量
                .subscribe(new Observer<List<Integer>>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "开始采用subscribe连接");
                    } // 默认最先调用复写的 onSubscribe（）

                    @Override
                    public void onNext(List<Integer> stringList) {
                        Log.d(TAG, " 缓存区里的事件数量 = " + stringList.size());
                        for (Integer value : stringList) {
                            Log.d(TAG, " 事件 = " + value);
                        }
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
![这里写图片描述](https://img-blog.csdn.net/20180814154926756)
### 四.参考资料
[ReactiveX文档中文翻译](https://mcxiaoke.gitbooks.io/rxdocs/content/topics/Getting-Started.html)
[Android Rxjava：这是一篇 清晰 & 易懂的Rxjava 入门教程 ](https://www.jianshu.com/p/a406b94f3188)
[Rxjava2入门教程一：函数响应式编程及概述](Rxjava2%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B%E4%B8%80%EF%BC%9A%E5%87%BD%E6%95%B0%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B%E5%8F%8A%E6%A6%82%E8%BF%B0)
[这可能是最好的RxJava 2.x 教程（完结版）](https://www.jianshu.com/p/0cd258eecf60)
[那些年我们错过的响应式编程](https://github.com/kevinyaoo/android-tech-frontier/tree/master/androidweekly/%E9%82%A3%E4%BA%9B%E5%B9%B4%E6%88%91%E4%BB%AC%E9%94%99%E8%BF%87%E7%9A%84%E5%93%8D%E5%BA%94%E5%BC%8F%E7%BC%96%E7%A8%8B)


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
