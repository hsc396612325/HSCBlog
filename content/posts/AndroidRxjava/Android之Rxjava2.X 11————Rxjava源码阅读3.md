# Android之Rxjava2.X 11————Rxjava源码阅读3 
### 一.目录
@[toc]
### 二.目的
这次分析源码有如下目的：

1.  知道被观察者(Observable)是如何将数据发送出去的
2.  知道观察者(Observer)是如何接收数据的
3. 何时将源头和终点关联起来的
4. 知道操作符值怎么实现的
5. 知道线程调度如何实现的
6. 背压Flowable是如何实现的

1~5点之前文章都分析，本文主要分析第6点
### 三.源码分析
#### 1.背压Flowable的简单示例
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
#### 2.从create开始
和第一篇一样，先从create开始
create方法
```java
public static <T> Flowable<T> create(FlowableOnSubscribe<T> source, BackpressureStrategy mode) 
```
对于Flowable的create方法而言:

* 调用对象：Flowable
* 返回对象：Flowable
* 传入参数：FlowableOnSubscrib，BackpressureStrategy 

FlowableOnSubscrib和Observable的ObservableOnSubscribe接口作用类似，而BackpressureStrategy 的作用是确定背压的策略，关于这一块可以看我之前的博客： [Android之Rxjava2.X 8————Rxjava 背压策略](https://blog.csdn.net/qq_38499859/article/details/81747334)

查看FlowableOnSubscribe接口
```java
public interface FlowableOnSubscribe<T> {
   //在create中实现的方法
    void subscribe(@NonNull FlowableEmitter<T> e) throws Exception;
}
```

查看subscribe的参数FlowableEmitte
```java
public interface FlowableEmitter<T> extends Emitter<T> {
    //添加Disposable
    void setDisposable(@Nullable Disposable s);

    //添加Cancellable
    void setCancellable(@Nullable Cancellable c);
    
    //返回未解决的请求的数量
    long requested();
 
    //返回下游是否取消序列化
    boolean isCancelled();

    //序列化
    @NonNull
    FlowableEmitter<T> serialize();

	
    @Experimental
    boolean tryOnError(@NonNull Throwable t);
}

```
//上面注释内容，是我根据源码里的注释和有道翻译的结果，如果有不对之处，请见谅

继续查看FlowableEmitter的父类Emitter
```java
public interface Emitter<T> {

   
    void onNext(@NonNull T value);
    
    void onError(@NonNull Throwable error);

    void onComplete();
}

```
到目前为止的内容，和Observable基本是一样的，我们重新回到create函数中，查看其具体方法
```java
 @CheckReturnValue
    @BackpressureSupport(BackpressureKind.SPECIAL)
    @SchedulerSupport(SchedulerSupport.NONE)
    public static <T> Flowable<T> create(FlowableOnSubscribe<T> source, BackpressureStrategy mode) {
        ObjectHelper.requireNonNull(source, "source is null");
        ObjectHelper.requireNonNull(mode, "mode is null");
        return RxJavaPlugins.onAssembly(new FlowableCreate<T>(source, mode));
    }
```
这里面还是和Observable一样，判空+ hook+装饰类

直接进入FlowableCreate类中
```java
public final class FlowableCreate<T> extends Flowable<T> {

    final FlowableOnSubscribe<T> source;

    final BackpressureStrategy backpressure;

    //构造函数
    public FlowableCreate(FlowableOnSubscribe<T> source, BackpressureStrategy backpressure) {
        this.source = source;
        this.backpressure = backpressure;
    }

    //订阅的重写
    @Override
    public void subscribeActual(Subscriber<? super T> t) {
        BaseEmitter<T> emitter;

        switch (backpressure) {
        case MISSING: {
            emitter = new MissingEmitter<T>(t);
            break;
        }
        case ERROR: {
            emitter = new ErrorAsyncEmitter<T>(t);
            break;
        }
        case DROP: {
            emitter = new DropAsyncEmitter<T>(t);
            break;
        }
        case LATEST: {
            emitter = new LatestAsyncEmitter<T>(t);
            break;
        }
        default: {
            emitter = new BufferAsyncEmitter<T>(t, bufferSize());
            break;
        }
        }

        t.onSubscribe(emitter);
        try {
            source.subscribe(emitter);
        } catch (Throwable ex) {
            Exceptions.throwIfFatal(ex);
            emitter.onError(ex);
        }
    }
    。。。。
}
```

到目前为止的内容，和Observable类大同小异，在之前博客中的结论依然可以用到这里。

#### 3.从subscribe继续阅读
我们重新返回Activity中，查看Subscribe方法的源码

进入Subsection方法中
```java
    @BackpressureSupport(BackpressureKind.SPECIAL)
    @SchedulerSupport(SchedulerSupport.NONE)
    @Override
    public final void subscribe(Subscriber<? super T> s) {
        if (s instanceof FlowableSubscriber) {
            subscribe((FlowableSubscriber<? super T>)s);
        } else {
            ObjectHelper.requireNonNull(s, "s is null");
            subscribe(new StrictSubscriber<T>(s)); //将Subscribe类进行封装
        }
    }
```
从这里开始，就和Observable类有些区别，在这里将Subscribe类进行了封装。

进入StrictSubscriber类中
```java
public class StrictSubscriber<T>
extends AtomicInteger
implements FlowableSubscriber<T>, Subscription {

    private static final long serialVersionUID = -4945028590049415624L;

    final Subscriber<? super T> actual;

    //各种原子类
    final AtomicThrowable error;
    final AtomicLong requested;
    final AtomicReference<Subscription> s;
    final AtomicBoolean once;
    
    volatile boolean done;

    public StrictSubscriber(Subscriber<? super T> actual) {
        this.actual = actual;
        this.error = new AtomicThrowable();
        this.requested = new AtomicLong();
        this.s = new AtomicReference<Subscription>();
        this.once = new AtomicBoolean();
    }

    @Override
    public void request(long n) {
        if (n <= 0) {
            cancel();
            onError(new IllegalArgumentException("§3.9 violated: positive request amount required but it was " + n));
        } else {
            SubscriptionHelper.deferredRequest(s, requested, n);
        }
    }

    @Override
    public void cancel() {
        if (!done) {
            SubscriptionHelper.cancel(s);
        }
    }

    @Override
    public void onSubscribe(Subscription s) {
        if (once.compareAndSet(false, true)) {

            actual.onSubscribe(this);

            SubscriptionHelper.deferredSetOnce(this.s, requested, s);
        } else {
            s.cancel();
            cancel();
            onError(new IllegalStateException("§2.12 violated: onSubscribe must be called at most once"));
        }
    }

    @Override
    public void onNext(T t) {
        HalfSerializer.onNext(actual, t, this, error);
    }

    @Override
    public void onError(Throwable t) {
        done = true;
        HalfSerializer.onError(actual, t, this, error);
    }

    @Override
    public void onComplete() {
        done = true;
        HalfSerializer.onComplete(actual, this, error);
    }
}

```
在StrictSubscriber类中，对onSubscribe， request等方法进行了重写

返回到subscribe方法中，进入到 subscribe(new StrictSubscriber<T>(s))的subscribe方法中
```java
public final void subscribe(FlowableSubscriber<? super T> s) {
        ObjectHelper.requireNonNull(s, "s is null");
        try {
            Subscriber<? super T> z = RxJavaPlugins.onSubscribe(this, s);

            ObjectHelper.requireNonNull(z, "Plugin returned null Subscriber");
	 //真正的订阅处
            subscribeActual(z);
        } catch (NullPointerException e) { // NOPMD
            throw e;
        } catch (Throwable e) {
            Exceptions.throwIfFatal(e);
            // can't call onError because no way to know if a Subscription has been set or not
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
protected abstract void subscribeActual(Subscriber<? super T> s);
```
这里的 subscribeActual是一个抽象的方法，真正的实现类在FlowableCreate中的 subscribeActual，重写进入FlowableCreate类中subscribeActual的方法中
```java
  @Override
  //参数t是StrictSubscriber
    public void subscribeActual(Subscriber<? super T> t) {
        BaseEmitter<T> emitter;

        switch (backpressure) {
        case MISSING: {
            emitter = new MissingEmitter<T>(t);
            break;
        }
        case ERROR: {
            emitter = new ErrorAsyncEmitter<T>(t);
            break;
        }
        case DROP: {
            emitter = new DropAsyncEmitter<T>(t);
            break;
        }
        case LATEST: {
            emitter = new LatestAsyncEmitter<T>(t);
            break;
        }
        default: {
            emitter = new BufferAsyncEmitter<T>(t, bufferSize());
            break;
        }
        }
	
	//调用StrictSubscriber的onSubscribe
        t.onSubscribe(emitter);
        try {
            source.subscribe(emitter);
        } catch (Throwable ex) {
            Exceptions.throwIfFatal(ex);
            emitter.onError(ex);
        }
    }

```
目前结论：

* Flowable将观察者和被观察者联系起来也是在FlowableCreate.subscribeActual方法
* 在FlowableCreate中，参数t是观察者经过 StrictSubscriber类包装后的结果
* 参数emitter是观察者经过StrictSubscriber类和对应该模式的XXXXEmitter包装后的结果


#### 4.XXXXEmitter类
在FlowableCreate.subscribeActual，根据 Flowable选择不同的策略，对Subscriber进行不同的封装。

**ERROR：直接抛异常**
进入 ErrorAsyncEmitter类中
```java

    static final class ErrorAsyncEmitter<T> extends NoOverflowBaseAsyncEmitter<T> {


        private static final long serialVersionUID = 338953216916120960L;

        ErrorAsyncEmitter(Subscriber<? super T> actual) {
            super(actual);
        }

        @Override
        void onOverflow() {
            onError(new MissingBackpressureException("create: could not emit value due to lack of requests"));
        }

    }
```
ErrorAsyncEmitter类很简单，只有一个onOverflow() ，其中调用的onError跑出了异常
但onOverflow是什么时候调用的？

我们进入它的父类NoOverflowBaseAsyncEmitter中
```java
abstract static class NoOverflowBaseAsyncEmitter<T> extends BaseEmitter<T> {

        private static final long serialVersionUID = 4127754106204442833L;

        NoOverflowBaseAsyncEmitter(Subscriber<? super T> actual) {
            super(actual);
        }

        @Override
        public final void onNext(T t) {
            if (isCancelled()) {
                return;
            }

            if (t == null) {
                onError(new NullPointerException("onNext called with null. Null values are generally not allowed in 2.x operators and sources."));
                return;
            }

            if (get() != 0) {  
                actual.onNext(t);
                BackpressureHelper.produced(this, 1);
            } else {
                onOverflow();
            }
        }

        abstract void onOverflow();
    }
```
在这其中可以看出，当get == 0时，调用了onOverflow()。

get方法在哪实现的呢，继续进入NoOverflowBaseAsyncEmitter父类 BaseEmitter中
```java
 abstract static class BaseEmitter<T>
    extends AtomicLong
    implements FlowableEmitter<T>, Subscription {
        private static final long serialVersionUID = 7326289992464377023L;

        final Subscriber<? super T> actual;

        final SequentialDisposable serial;

        BaseEmitter(Subscriber<? super T> actual) {
            this.actual = actual;
            this.serial = new SequentialDisposable();
        }

      。。。。。。
    }
```
在BaseEmitter类中，BaseEmitter继承了原子类AtomicLong方法，所以get是原子类的方法。

**DROP：丢弃超出缓存区的事件**
进入DropAsyncEmitter
```java

    static final class DropAsyncEmitter<T> extends NoOverflowBaseAsyncEmitter<T> {


        private static final long serialVersionUID = 8360058422307496563L;

        DropAsyncEmitter(Subscriber<? super T> actual) {
            super(actual);
        }

        @Override
        void onOverflow() {
            // nothing to do
        }

    }
```
发现DropAsyncEmitter和ErrorAsyncEmitter类一样，都实现了 onOverflow()抽象方法，也可以得出onOverflow()的调用时机也是一样，即get==0时

**LATEST：只保留最新的事件，超过缓存区部分丢弃**
一样，也是进入 LatestAsyncEmitter类中
```java
static final class LatestAsyncEmitter<T> extends BaseEmitter<T> {


        private static final long serialVersionUID = 4023437720691792495L;

        final AtomicReference<T> queue;

        Throwable error;
        volatile boolean done;

        final AtomicInteger wip;

        LatestAsyncEmitter(Subscriber<? super T> actual) {
            super(actual);
            this.queue = new AtomicReference<T>();
            this.wip = new AtomicInteger();
        }

        @Override
        public void onNext(T t) {
            if (done || isCancelled()) {
                return;
            }

            if (t == null) {
                onError(new NullPointerException("onNext called with null. Null values are generally not allowed in 2.x operators and sources."));
                return;
            }
            queue.set(t);
            drain();
        }

        @Override
        public boolean tryOnError(Throwable e) {
            if (done || isCancelled()) {
                return false;
            }
            if (e == null) {
                onError(new NullPointerException("onError called with null. Null values are generally not allowed in 2.x operators and sources."));
            }
            error = e;
            done = true;
            drain();
            return true;
        }

        @Override
        public void onComplete() {
            done = true;
            drain();
        }

        @Override
        void onRequested() {
            drain();
        }

        @Override
        void onUnsubscribed() {
            if (wip.getAndIncrement() == 0) {
                queue.lazySet(null);
            }
        }

        void drain() {
            if (wip.getAndIncrement() != 0) {
                return;
            }

            int missed = 1;
            final Subscriber<? super T> a = actual;
            final AtomicReference<T> q = queue;

            for (;;) {
                long r = get();
                long e = 0L;

                while (e != r) {
                    if (isCancelled()) {
                        q.lazySet(null);
                        return;
                    }

                    boolean d = done;

                    T o = q.getAndSet(null);

                    boolean empty = o == null;

                    if (d && empty) {
                        Throwable ex = error;
                        if (ex != null) {
                            error(ex);
                        } else {
                            complete();
                        }
                        return;
                    }

                    if (empty) {
                        break;
                    }

                    a.onNext(o);

                    e++;
                }

                if (e == r) {
                    if (isCancelled()) {
                        q.lazySet(null);
                        return;
                    }

                    boolean d = done;

                    boolean empty = q.get() == null;

                    if (d && empty) {
                        Throwable ex = error;
                        if (ex != null) {
                            error(ex);
                        } else {
                            complete();
                        }
                        return;
                    }
                }

                if (e != 0) {
                    BackpressureHelper.produced(this, e);
                }

                missed = wip.addAndGet(-missed);
                if (missed == 0) {
                    break;
                }
            }
        }
    }
```
其他的模式可以自己参考源码

#### 5.数据的流动
回到最开始的例子：
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
                BackpressureStrategy.LATEST

        )
```
emitter.onNext()的过程中都发生了什么，我们先看FlowableEmitter参数是谁？
根据之前的分析，我们知道FlowableEmitter其实是 Subscriber(观察者)被StrictSubscriber封装后，在被LatestAsyncEmitter封装。

所以说，onNext经历如下过程：emitter.onNext---->LatestAsyncEmitter.onNext--->StrictSubscriber.onNext---> Subscriber.onNext（在Activity中重写的方法）


### 四.文章索引
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
