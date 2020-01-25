---
title: "Android之Rxjava2.X 9————Rxjava源码阅读1"
date: 2019-04-09T22:40:54+08:00
draft: false
categories: ["Android","Android之Rxjava"]
tags: ["Android","Rxjava"]
---

### 一.目录
@[toc]
### 二.目的
这次分析源码有如下目的：

1. 知道被观察者(Observable)是如何将数据发送出去的
2. 知道观察者(Observer)是如何接收数据的
3. 何时将源头和终点关联起来的
4. 知道操作符值怎么实现的
5. 知道线程调度如何实现的
6. 背压Flowable是如何实现的

本文的目的是1，2，3点。下一篇文章分析4，5点。下下一篇文章分析第6点
### 三.源码分析
#### 1.简单的Rxjava的例子
```java
Observable.create(
                new ObservableOnSubscribe<String>() {
            @Override
            public void subscribe(ObservableEmitter<String> e) throws Exception {
                e.onNext("1");
                e.onComplete();
            }
        }).subscribe(new Observer<String>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "onSubscribe: "+d);
            }

            @Override
            public void onNext(String value) {
                Log.d(TAG, "onNext: "+value);
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
运行结果:
![这里写图片描述](/image/Android_Rxjava/10_0.png)

#### 3.从create开始
create方法：
```java
public static <T> Observable<T> create(ObservableOnSubscribe<T> source)
```
从create方法可以得出

* 调用对象：Observable
* 返回对象：Observable
* 传入参数: ObservableOnSubscribe 即发射器

查看ObservableOnSubscribe接口
```java
public interface ObservableOnSubscribe<T> {
    //其中只有一个方法，这个方法就是我们在create中实现的方法
    void subscribe(@NonNull ObservableEmitter<T> e) throws Exception;
}

```
查看subscribe方法的参数:ObservableEmitter
```java
//ObservableEmitter是一个接口，继承自Emitter方法
public interface ObservableEmitter<T> extends Emitter<T> {

    void setDisposable(@Nullable Disposable d);

    void setCancellable(@Nullable Cancellable c);

    boolean isDisposed();
    
    @NonNull
    ObservableEmitter<T> serialize();
    
    @Experimental
    boolean tryOnError(@NonNull Throwable t);
}
```
继续查看Emitter
```java
public interface Emitter<T> {

    void onNext(@NonNull T value);

    void onError(@NonNull Throwable error);

    void onComplete();
}

```
可以看出来，这里的Emitter接口定义了我们在重写ObservableOnSubscribe的subscrib方法时，最常调用的三个函数

看完了create方法的参数相关，追踪查看create的方法
```java
//所在类Observable
public static <T> Observable<T> create(ObservableOnSubscribe<T> source) {
        ObjectHelper.requireNonNull(source, "source is null"); //判空，如果为空则抛出异常
        return RxJavaPlugins.onAssembly(new ObservableCreate<T>(source));
    }
```
在create的方法中返回值为：RxJavaPlugins.onAssembly(new ObservableCreate<T>(source))。查看这个方法
```java
//所在类RxJavaPlugins
public static <T> Observable<T> onAssembly(@NonNull Observable<T> source) {
        Function<? super Observable, ? extends Observable> f = onObservableAssembly;
        if (f != null) { //这是一个关于hook的方法，暂且不看，不牵扯主流程，默认为空
            return apply(f, source);
        }
        return source;
    }
```
很明显的发现在onAssembly方法中，传入参数和返回值都是Observable，所以可以判断出， ObservableCreate这个类中，将ObservableOnSubscribe适配为Observable类。这里的 ObservableCreate就是一种是适配器的体现

返回，继续进入ObservableCreate类中：
```java
public final class ObservableCreate<T> extends Observable<T> {
    final ObservableOnSubscribe<T> source;

   //构造函数，传入参数source 被观察者创建时传入的ObservableOnSubscribe对象
    public ObservableCreate(ObservableOnSubscribe<T> source) {
        this.source = source;
    }


	// 订阅
    @Override
    //传入参数Observer，即观察者
    protected void subscribeActual(Observer<? super T> observer) {
	
	//1 创建CreateEmitter，也是一个适配器
        CreateEmitter<T> parent = new CreateEmitter<T>(observer);
  
       //2调用观察者(Observer）的onSubscribe（），此出会进行打log 即：  Log.d(TAG, "onSubscribe: "+d);
       // onSubscribe（）参数是Disposable ，所以CreateEmitter可以将Observer->Disposable 。
       // 还有一点要注意的是`onSubscribe()`是在我们执行`subscribe()`这句代码的那个线程回调的，并不受线程调度影响。
        observer.onSubscribe(parent);


        try {
            //source 即被观察者创建时传入的ObservableOnSubscribe对象        
            //parent即subscribeActual被调用是传入的观察者进行适配后的对象
            
            //所以subscribe的回调参数ObservableEmitter实际上就是观察者
            //所以，也是在这一处中，将观察者和被观察者联系起来
            source.subscribe(parent);
        } catch (Throwable ex) {
            //错误处理，
            Exceptions.throwIfFatal(ex);
            parent.onError(ex);
        }
    }
}
```
看完了ObservableCreate.subscribeActual的方法，发现在其中将两种进行联系，但subscribeActual是在何时被调用的，我们重新回到Activity中，查看subscribe方法

目前结论：

* create方法返回值是Observable。
* ObservableCreate这个适配类将create传入的参数ObservableOnSubscribe适配为Observable。
* ObservableOnSubscribe.subscribe中的参数 ObservableEmitter实际是观察者
* CreateEmitter这个适配类中将Observer观察者适配为ObservableEmitter
* ObservableCreate.subscribeActual方法中， source.subscribe(parent);语句将两者联系起来
#### 2.从subscribe继续阅读
进入subscribe方法中
```java
//所在类Observable

//传入参数，观察者Observer
public final void subscribe(Observer<? super T> observer) {
        ObjectHelper.requireNonNull(observer, "observer is null"); //判空
        try {
	    //hook相关，略过
            observer = RxJavaPlugins.onSubscribe(this, observer);

            ObjectHelper.requireNonNull(observer, "Plugin returned null Observer");

	   //真正的订阅处
            subscribeActual(observer);
        } catch (NullPointerException e) { // NOPMD
            throw e;
        } catch (Throwable e) {
            Exceptions.throwIfFatal(e);
            // can't call onError because no way to know if a Disposable has been set or not
            // can't call onSubscribe because the call might have set a Subscription already
            RxJavaPlugins.onError(e);

            NullPointerException npe = new NullPointerException("Actually not, but can't throw other exceptions due to RS");
            npe.initCause(e);
            throw npe;
        }
    }

```
我们发现在subscribe，在其中调用了 subscribeActual方法，进入其中
```java
//所在类Observable

  protected abstract void subscribeActual(Observer<? super T> observer);
```
//进入后发现，Observable中subscribeActual是一个抽象方法，所以具体实现还是在其子类中，也就是ObservableCreate.subscribeActual。

目前结论:

*  在subscribe实质是调用了ObservableCreate.subscribeActual方法，也是在其中完成了观察者和被观察者的联系

#### 4.从Observer中继续
我们现在看了观察者的创建过程，以及两者如何联系的，现在我们回到Activity去看一看，Observer相关的
```java
public interface Observer<T> {

    void onSubscribe(@NonNull Disposable d);
    void onNext(@NonNull T t);
    void onError(@NonNull Throwable e);
    void onComplete();
}

```
Observer中很简单只有4个抽象方法，而这个抽象方法我们在简单都有实现，即
```java
new Observer<String>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "onSubscribe: "+d);
            }

            @Override
            public void onNext(String value) {
                Log.d(TAG, "onNext: "+value);
            }

            @Override
            public void onError(Throwable e) {
                Log.d(TAG, "onError: "+e);
            }
            

            @Override
            public void onComplete() {
                Log.d(TAG, "onComplete: ");
            }
        }
```
在上文中，我们说过在ObservableCreate中的CreateEmitter类中，对观察者进行了适配。我们重新进入ObservableCreate的CreateEmitter，进行阅读
```java
 //对观察者的封装
    static final class CreateEmitter<T>
            extends AtomicReference<Disposable>
            implements ObservableEmitter<T>, Disposable {


        private static final long serialVersionUID = -3434801548987643227L;

        final Observer<? super T> observer;

        //构造函数 参数：观察者
        CreateEmitter(Observer<? super T> observer) {
            this.observer = observer;
        }


        @Override
        public void onNext(T t) {
            //如果没有被dispose，则调用观察者的onError函数
            if (t == null) {
                onError(new NullPointerException("onNext called with null. Null values are generally not allowed in 2.x operators and sources."));
                return;
            }
            // 若无断开连接（调用Disposable.dispose()），则调用观察者（Observer）的同名方法 = onNext（）
            //onNext = 观察者复写的函数
            if (!isDisposed()) {
                observer.onNext(t);
            }
        }

        @Override
        public void onError(Throwable t) {
            if (!tryOnError(t)) {  //判断是否抛出错误

                //抛出异常
                RxJavaPlugins.onError(t);
            }
        }

        @Override
        public boolean tryOnError(Throwable t) {
            if (t == null) {
                t = new NullPointerException("onError called with null. Null values are generally not allowed in 2.x operators and sources.");
            }
            if (!isDisposed()) {
                try {
                    observer.onError(t);
                } finally {
                    //2 一定会自动dispose()
                    dispose();
                }
                return true;
            }
            return false;
        }

        @Override
        public void onComplete() {
            //1 如果没有被dispose，会调用Observer的onComplete()方法
            if (!isDisposed()) {
                try {
                    observer.onComplete();
                } finally {
                    dispose();
                }
            }
        }

        @Override
        public void setDisposable(Disposable d) {
            DisposableHelper.set(this, d);
        }

        @Override
        public void setCancellable(Cancellable c) {
            setDisposable(new CancellableDisposable(c));
        }

        @Override
        public ObservableEmitter<T> serialize() {
            return new SerializedEmitter<T>(this);
        }

        @Override
        public void dispose() {
            DisposableHelper.dispose(this);
        }

        @Override
        public boolean isDisposed() {
            return DisposableHelper.isDisposed(get());
        }
    }
```
目前结论：

* Observable和Observer的关系没有被dispose，才会回调Observer的onXXXX()方法
* Observer的onComplete()和onError() 互斥只能执行一次，因为CreateEmitter在回调他们两中任意一个后，都会自动dispose()。
* Observable和Observer关联时（订阅时），Observable才会开始发送数据。

#### 5.数据的流动
看到这里差不多也就明白了被观察者如何发送数据，观察者如何接收数据了，

回到最开始的例子中
```java
Observable.create(
                new ObservableOnSubscribe<String>() {
            @Override
            public void subscribe(ObservableEmitter<String> e) throws Exception {
                e.onNext("1");
                e.onComplete();
            }
        })
```
上文我们说过，在create中的ObservableOnSubscribe.subscribe中的参数ObservableEmitter，实际上将观察者Observer适配封装之后的结果

所以e.onNext("1") -->CreateEmitter.onNext---->Observer.onNext-->Log.d(TAG, "onNext: "+value);

 至此rxjava最简单一个流程我们只搞清了，当然这个流程例不牵扯进程调度，不牵扯操作符，关于这两个我们下一篇博客进行阅读
### 四.参考资料
[RxJava2 源码解析（一）](https://www.jianshu.com/p/23c38a4ed360)
[Android RxJava 2.0：手把手带你 源码分析RxJava](https://www.jianshu.com/p/e1c48a00951a)
[RxJava2 源码解析——流程](https://www.jianshu.com/p/e5be2fa8701c)


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
