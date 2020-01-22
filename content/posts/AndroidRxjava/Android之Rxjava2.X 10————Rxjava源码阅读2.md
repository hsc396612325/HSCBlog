# Android之Rxjava2.X 10————Rxjava源码阅读2 
### 一. 目录
@[toc]
### 二. 目的
如上篇文章所说，这次看源码有如下目的：

1. 知道被观察者(Observable)是如何将数据发送出去的
2.  知道观察者(Observer)是如何接收数据的
3. 何时将源头和终点关联起来的
4. 何时将源头和终点关联起来的
5. 知道线程调度如何实现的
6. 背压Flowable是如何实现的

上篇文章中，分析了前3点，这篇文章分析3，4点，下一篇分析第6点

### 三. 操作符源码分析
#### 1.简单的Map操作符例子
```java
Observable.create(new ObservableOnSubscribe<String>() {
            @Override
            public void subscribe(ObservableEmitter<String> e) throws Exception {
                e.onNext("1");
                e.onComplete();
            }
        }).map(new Function<String, Integer>() {
            @Override
            public Integer apply(String s) throws Exception {
                return Integer.parseInt(s);
            }
        }).subscribe(new Observer<Integer>() {
            @Override
            public void onSubscribe(Disposable d) {
                Log.d(TAG, "onSubscribe: "+d);
            }

            @Override
            public void onNext(Integer value) {
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
#### 2.从map开始
```java
  public final <R> Observable<R> map(Function<? super T, ? extends R> mapper)
```
小结论：
map的调用对象:Observable
map的返回对象:Observable
传入参数：Function

查看Function接口
```java
public interface Function<T, R> {
    //返回R， 传入参数T
    R apply(@NonNull T t) throws Exception;
}
```

进入map的具体方法里
```java
//所在类Observable
@CheckReturnValue
    @SchedulerSupport(SchedulerSupport.NONE)
    public final <R> Observable<R> map(Function<? super T, ? extends R> mapper) {
        ObjectHelper.requireNonNull(mapper, "mapper is null");
        return RxJavaPlugins.onAssembly(new ObservableMap<T, R>(this, mapper));
    }
```
这里可以看出，这里的map和上一篇create的方法中内容很像，可以推测出ObservableMap将调用它的被观察者和Function进行封装，最后返回一个Observable

进入ObservableMap中
```java
public final class ObservableMap<T, U> extends AbstractObservableWithUpstream<T, U> {
    final Function<? super T, ? extends U> function;
    
    //参数super-->上游的被观察者，function-->传入的Function对象
    //ObservableSource是Observable的父类
    public ObservableMap(ObservableSource<T> source, Function<? super T, ? extends U> function) {
        super(source); //将source 传入父类中
        this.function = function; //保存function
    }

    @Override
    public void subscribeActual(Observer<? super U> t) {
        source.subscribe(new MapObserver<T, U>(t, function));
    }
    ...
}
```
在ObservableMap的构造方法中，我们看到其将source传入父类中，ObservableMap继承自AbstractObservableWithUpstream类，我们进入AbstractObservableWithUpstream类中

```java
abstract class AbstractObservableWithUpstream<T, U> extends Observable<U> implements HasUpstreamObservableSource<T> {
    protected final ObservableSource<T> source;

    AbstractObservableWithUpstream(ObservableSource<T> source) {
    // 保存上游的被观察者
        this.source = source;
    }

    @Override
    public final ObservableSource<T> source() {
        return source;
    }

}

```
进入后发现AbstractObservableWithUpstream类继承自Observable，在AbstractObservableWithUpstream中将上游的被观察者进行了保存，这里的AbstractObservableWithUpstream就是装饰者模式的体现。

目前结论：

* map的传入参数为Function，返回值为Observable
* 在ObservableMap中，将Function和调用它的Observable对象一起封装成AbstractObservableWithUpstream，AbstractObservableWithUpstream继承自Observable，所以说是将两者封装成Observable
* AbstractObservableWithUpstream中保存者上游的


#### 2.从subscribe继续阅读
上一节中，我们看到了将map中将Function和上游的被观察者封装成一个Observable，我们返回Activity中，继续查看订阅的方式
 
```java
 @SchedulerSupport(SchedulerSupport.NONE)
    @Override
    public final void subscribe(Observer<? super T> observer) {
        ObjectHelper.requireNonNull(observer, "observer is null");
        try {
            observer = RxJavaPlugins.onSubscribe(this, observer);

            ObjectHelper.requireNonNull(observer, "Plugin returned null Observer");

            subscribeActual(observer); //真正的订阅处
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
 
 和create中一样，这里我们直接看ObservableMap中的 subscribeActual实现
```java
 public final class ObservableMap<T, U> extends AbstractObservableWithUpstream<T, U> {
    final Function<? super T, ? extends U> function;

    public ObservableMap(ObservableSource<T> source, Function<? super T, ? extends U> function) {
        super(source);
        this.function = function;
    }

    @Override
    public void subscribeActual(Observer<? super U> t) {
	//newObserver将下游的观察者和Function封装起来
	//然后订阅上游的被观察着
        source.subscribe(new MapObserver<T, U>(t, function));
    }
}

```
在subscribeActual将被观察者和观察者联系起来，而MapObserver也是装饰者模式，对Observer装饰
```java
//在ObservableMap类中
static final class MapObserver<T, U> extends BasicFuseableObserver<T, U> {
        final Function<? super T, ? extends U> mapper;

        MapObserver(Observer<? super U> actual, Function<? super T, ? extends U> mapper) {
            //super()将actual保存起来
            super(actual);
            //保存Function变量
            this.mapper = mapper;
        }


	//重写
        @Override
        public void onNext(T t) {
           //done在onError 和 onComplete以后才会是true，默认这里是false，所以跳过11
            if (done) {
                return;
            }

	   //默认sourceMode是0，所以跳过
            if (sourceMode != NONE) {
                actual.onNext(null);
                return;
            }
            //下游Observer接受的值
            U v;

            try {
	        //这一步执行变换,将上游传过来的T，利用Function转换成下游需要的U。
                v = ObjectHelper.requireNonNull(mapper.apply(t), "The mapper function returned a null value.");
            } catch (Throwable ex) {
                fail(ex);
                return;
            }
            //将变换后的值传递给下游的Observer中。
            actual.onNext(v);
        }

        @Override
        public int requestFusion(int mode) {
            return transitiveBoundaryFusion(mode);
        }

        @Nullable
        @Override
        public U poll() throws Exception {
            T t = qs.poll();
            return t != null ? ObjectHelper.<U>requireNonNull(mapper.apply(t), "The mapper function returned a null value.") : null;
        }
    }
```
·
目前结论：

* 订阅的发送：(Activity中)subscribe（observer)--->ObservableMap.subscribeActual(observer)-->ObservableCreate. subscribeActual(new MapObserver(observer,function)). 
* 数据的流动，(被观察者)e.next("1") -->ObservableMap.MapObserver.onNext--> Observer.onNext;
* 在ObservableMap.MapObserver.onNext完成了String-->int的转变

### 四. 线程程调度源码分析
#### 1.线程操作符subscribeOn的简单使用
```java
      Observable.create(new ObservableOnSubscribe<String>() {
            @Override
            public void subscribe(ObservableEmitter<String> e) throws Exception {
                e.onNext("1");
                e.onComplete();
            }
        }).subscribeOn(Schedulers.io())//指定被观察者的线程
         .subscribe(new Observer<String>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: " + d);
                    }

                    @Override
                    public void onNext(String value) {
                        Log.d(TAG, "onNext: " + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: " + e);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });
```
#### 2.从subscribeOn中开始
还是一样，进入SubscribeOn中，看其中的方法
```java
public final Observable<T> subscribeOn(Scheduler scheduler) {
        ObjectHelper.requireNonNull(scheduler, "scheduler is null");
        return RxJavaPlugins.onAssembly(new ObservableSubscribeOn<T>(this, scheduler));
    }
```
还是和之前的一样，ObservableSubscribeOn也是一个装饰类，我们直接进入查看
```java
public final class ObservableSubscribeOn<T> extends AbstractObservableWithUpstream<T, T> {
    final Scheduler scheduler;

    public ObservableSubscribeOn(ObservableSource<T> source, Scheduler scheduler) {
	 //保存super（上游被观察者）
        super(source);
        //保存Scheduler
        this.scheduler = scheduler;
    }

    @Override
    public void subscribeActual(final Observer<? super T> s) {
      //1  创建一个包装Observer
        final SubscribeOnObserver<T> parent = new SubscribeOnObserver<T>(s);
	  //2  调用 下游（终点）Observer.onSubscribe()方法,所以onSubscribe()方法执行在 订阅处
        s.onSubscribe(parent);
	 //3 setDisposable()是为了将子线程的操作加入Disposable管理中
        parent.setDisposable(scheduler.scheduleDirect(new SubscribeTask(parent)));
    }
}
```
根据之前的经验，subscribeActual负责订阅的实现，我们一点点来看这个方法

首先 是SubscribeOnObserver，是对下游的观察者进行封装，查看其具体内容：
```java
static final class SubscribeOnObserver<T> extends AtomicReference<Disposable> implements Observer<T>, Disposable {

        private static final long serialVersionUID = 8094547886072529208L;
       
        final Observer<? super T> actual;
        
        //用来保存上游的Disposable，以便在自身dispose时，连同上游一起dispose
        final AtomicReference<Disposable> s;

        SubscribeOnObserver(Observer<? super T> actual) {
            //下游的观察者
            this.actual = actual;
            this.s = new AtomicReference<Disposable>();
        }

        @Override
        public void onSubscribe(Disposable s) {
            //onSubscribe()方法由上游调用，传入Disposable。在本类中赋值给this.s，加入管理。
            DisposableHelper.setOnce(this.s, s);
        }

       //直接调用下游观察者的对应方法
        @Override
        public void onNext(T t) {
            actual.onNext(t);
        }

        @Override
        public void onError(Throwable t) {
            actual.onError(t);
        }

        @Override
        public void onComplete() {
            actual.onComplete();
        }

       //取消订阅时，连同上游Disposable一起取消
        @Override
        public void dispose() {
            DisposableHelper.dispose(s);
            DisposableHelper.dispose(this);
        }

        @Override
        public boolean isDisposed() {
            return DisposableHelper.isDisposed(get());
        }

       //这个方法在subscribeActual()中被手动调用，为了将Schedulers返回的Worker加入管理
        void setDisposable(Disposable d) {
            DisposableHelper.setOnce(this, d);
        }
    }
```
SubscribeOnObserver大部分都比较好理解，让我们重新回到subscribeActual中，这里面的大部分内容都比较好理解，但最后一句，还是比较难以理解
```java
  parent.setDisposable(scheduler.scheduleDirect(new SubscribeTask(parent)));
```
parent.setDisposable()在SubscribeOnObserver中有，我们主要关注new SubscribeTask(parent)和scheduler.scheduleDirect（）

先看scheduler.scheduleDirect
```java
 final class SubscribeTask implements Runnable {
        private final SubscribeOnObserver<T> parent;

        SubscribeTask(SubscribeOnObserver<T> parent) {
            this.parent = parent;
        }

        @Override
        public void run() {
        //此时已经运行在相应的Scheduler 的线程中
        //观察者和被观察者的订阅
            source.subscribe(parent);
        }
    }
```

继续来看scheduler.scheduleDirect（）
```java
//在Scheduler类中
@NonNull
    public Disposable scheduleDirect(@NonNull Runnable run) {
	//根据注释和方法名可以看出传入的Runnable会立刻执行。                    
        return scheduleDirect(run, 0L, TimeUnit.NANOSECONDS);
    }

```
继续进入scheduleDirect中
```java
@NonNull
    public Disposable scheduleDirect(@NonNull Runnable run, long delay, @NonNull TimeUnit unit) {
        //class Worker implements Disposable ，Worker本身是实现了Disposable  
        final Worker w = createWorker();

	  //hook略过
        final Runnable decoratedRun = RxJavaPlugins.onSchedule(run);

      //开始在Worker的线程执行任务，
        DisposeTask task = new DisposeTask(decoratedRun, w);

        w.schedule(task, delay, unit);

        return task;
    }
```
进入DisposeTask
```java
 static final class DisposeTask implements Runnable, Disposable {
        final Runnable decoratedRun;
        final Worker w;

        Thread runner;

        DisposeTask(Runnable decoratedRun, Worker w) {
            this.decoratedRun = decoratedRun;
            this.w = w;
        }

        @Override
        public void run() {
            runner = Thread.currentThread();
            try {
	            //调用的是 run()不是 start()方法执行的线程的方法。
                decoratedRun.run();
            } finally {
	            //执行完毕会 dispose()
                dispose();
                runner = null;
            }
        }

        @Override
        public void dispose() {
            if (runner == Thread.currentThread() && w instanceof NewThreadWorker) {
                ((NewThreadWorker)w).shutdown();
            } else {
                w.dispose();
            }
        }

        @Override
        public boolean isDisposed() {
            return w.isDisposed();
        }
    }
```
 createWorker()，  w.schedule(task, delay, unit)直接点进入后都是抽象类

```java
public abstract Worker createWorker();
public abstract Disposable schedule(@NonNull Runnable run, long delay, @NonNull TimeUnit unit);
```
通过断点调试，发现两个的实现类在IoScheduler中。

scheduleDirect目前结论：

*  传入的Runnable是立刻执行的。
*  返回的对象就是一个Disposable对象
*  Runnable执行时，是直接调用的run，而不是start方法
* 上一点是为了，能够控制run结束后（包括一次终止），都会自动执行Worke.dispose()
而返回的Worker对象也会被parent.setDisposable(...)加入管理中，以便在手动dispose()时能取消线程里的工作。


总结subscribeOn(Schedulers.xxx())的过程：

* 返回一个ObservableSubscribeOn包装类对象
* 上游被观察者被订阅时，回调该类中的subscribeActual()方法，在其中会立刻将线程切换到对应的Schedulers.xxx()线程。
* 在切换后的线程中，执行source.subscribe(parent)，对上游(终点)Observable订阅，所以订阅还是从下向上
* 上游的被观察者开始发送数据时，根据上一篇博客的，上游发送数据仅仅是调用下游观察者对应的onXXX()方法而已，所以此时操作是在切换后的线程中进行

 **subscribeOn(Schedulers.xxx())切换线程N次，总是以第一次为准，为什么呢？**
 原因是：
* 在上一篇博客中提到，订阅流程是从下游往上游传递
* 在subscribeActual()里开启了Scheduler的工作，source.subscribr(parent),从这一句开始切换线程，所以在这之上的代码都是都是在切换后的线程里
* 但如果连续切换，最上面的切换最晚执行，此时线程变成了最上面的subscribeOn(xxxx)指定的线程
* 而数据Push时，是从上游到下游的，所以会在离源头最近的那次subscribeOn(xxxx)的线程里push数据（onXXX()）给下游。
#### 3.线程调度observeOn符的简单示例
```java
Observable.create(new ObservableOnSubscribe<String>() {
            @Override
            public void subscribe(ObservableEmitter<String> e) throws Exception {
                e.onNext("1");
                e.onComplete();
            }
        }).subscribeOn(Schedulers.io())  //指顶被观察者的线程
                .observeOn(AndroidSchedulers.mainThread())//指定观察者的线程
                .subscribe(new Observer<String>() {
                    @Override
                    public void onSubscribe(Disposable d) {
                        Log.d(TAG, "onSubscribe: " + d);
                    }

                    @Override
                    public void onNext(String value) {
                        Log.d(TAG, "onNext: " + value);
                    }

                    @Override
                    public void onError(Throwable e) {
                        Log.d(TAG, "onError: " + e);
                    }

                    @Override
                    public void onComplete() {
                        Log.d(TAG, "onComplete: ");
                    }
                });

```

#### 4.从obsweveOn开始
```java
public final Observable<T> observeOn(Scheduler scheduler) {
        return observeOn(scheduler, false, bufferSize());
    }
```
继续查看
```java
@CheckReturnValue
    @SchedulerSupport(SchedulerSupport.CUSTOM)
    public final Observable<T> observeOn(Scheduler scheduler, boolean delayError, int bufferSize) {
        ObjectHelper.requireNonNull(scheduler, "scheduler is null");
        ObjectHelper.verifyPositive(bufferSize, "bufferSize");
        return RxJavaPlugins.onAssembly(new ObservableObserveOn<T>(this, scheduler, delayError, bufferSize));
    }
```
和之前的一样，hook+ObservableObserveOn，直接进入ObservableObserveOn中查看。
```java
public final class ObservableObserveOn<T> extends AbstractObservableWithUpstream<T, T> {
   //本例是 AndroidSchedulers.mainThread()
    final Scheduler scheduler;
       //默认false
    final boolean delayError;
       //默认128
    final int bufferSize;
    public ObservableObserveOn(ObservableSource<T> source, Scheduler scheduler, boolean delayError, int bufferSize) {
        super(source);
        this.scheduler = scheduler;
        this.delayError = delayError;
        this.bufferSize = bufferSize;
    }

    @Override
    protected void subscribeActual(Observer<? super T> observer) {
      // false
        if (scheduler instanceof TrampolineScheduler) {
            source.subscribe(observer);
        } else {
            //1 创建出一个 主线程的Worker
            Scheduler.Worker w = scheduler.createWorker();
             //2 订阅上游数据源，
            source.subscribe(new ObserveOnObserver<T>(observer, w, delayError, bufferSize));
        }
    }

```
查看ObserveOnObserver类
```java
static final class ObserveOnObserver<T> extends BasicIntQueueDisposable<T>
    implements Observer<T>, Runnable {

        private static final long serialVersionUID = 6576896619930983584L;
        //下游的观察者
        final Observer<? super T> actual;
        //对应Scheduler里的Worker
        final Scheduler.Worker worker;
        final boolean delayError;
        final int bufferSize;
	 //上游被观察者 push 过来的数据都存在这里
        SimpleQueue<T> queue;

        Disposable s;
        
         //如果onError了，保存对应的异常
        Throwable error;
         //是否完成
        volatile boolean done;
        //是否完成
        volatile boolean cancelled;
        // 代表同步发送 异步发送 
        int sourceMode;

        boolean outputFused;

        ObserveOnObserver(Observer<? super T> actual, Scheduler.Worker worker, boolean delayError, int bufferSize) {
            this.actual = actual;
            this.worker = worker;
            this.delayError = delayError;
            this.bufferSize = bufferSize;
        }

        @Override
        public void onSubscribe(Disposable s) {
            if (DisposableHelper.validate(this.s, s)) {
                this.s = s;
                ......
		
		 //创建一个queue 用于保存上游 onNext() push的数据
                queue = new SpscLinkedArrayQueue<T>(bufferSize);
		 //回调下游观察者onSubscribe方法
                actual.onSubscribe(this);
            }
        }

        @Override
        public void onNext(T t) {
             //1 执行过error / complete 会是tr
            if (done) {
                return;
            }
		 //2 如果数据源类型不是异步的， 默认不是
            if (sourceMode != QueueDisposable.ASYNC) {
                //3 将上游push过来的数据 加入 queue里
                queue.offer(t);
            }
             //4 开始进入对应Workder线程，在线程里 将queue里的t 取出 发送给下游Observer
            schedule();
        }

        @Override
        public void onError(Throwable t) {
        //已经done 会 抛异常 和 上一篇文章里提到的一样
            if (done) {
                RxJavaPlugins.onError(t);
                return;
            }
            //给error存个值 
            error = t;
            done = true;
            //开始调度
            schedule();
        }

        @Override
        public void onComplete() {
            if (done) {
                return;
            }
            done = true;
            schedule();
        }

        @Override
        public void dispose() {
            if (!cancelled) {
                cancelled = true;
                s.dispose();
                worker.dispose();
                if (getAndIncrement() == 0) {
                    queue.clear();
                }
            }
        }

        @Override
        public boolean isDisposed() {
            return cancelled;
        }

        void schedule() {
            if (getAndIncrement() == 0) {
             //该方法需要传入一个线程， 注意看本类实现了Runnable的接口，所以查看对应的run()方法
                worker.schedule(this);
            }
        }

        void drainNormal() {
            int missed = 1;

            final SimpleQueue<T> q = queue;
            final Observer<? super T> a = actual;

            for (;;) {
              // 1 如果已经 终止 或者queue空，则跳出函数，
                if (checkTerminated(done, q.isEmpty(), a)) {
                    return;
                }

                for (;;) {
                    boolean d = done;
                    T v;

                    try {
                    //2 从queue里取出一个值
                        v = q.poll();
                    } catch (Throwable ex) {
                     //3 异常处理 并跳出函数
                        Exceptions.throwIfFatal(ex);
                        s.dispose();
                        q.clear();
                        a.onError(ex);
                        worker.dispose();
                        return;
                    }
                    boolean empty = v == null;
			
	             //4 再次检查 是否 终止  如果满足条件 跳出函数
                    if (checkTerminated(d, empty, a)) {
                        return;
                    }

	             //5 上游还没结束数据发送，但是这边处理的队列已经是空的，不会push给下游 Observer
                    if (empty) {
                        break;
                    }
		  
		    //6 发送给下游了
                    a.onNext(v);
                }

                missed = addAndGet(-missed);
                if (missed == 0) {
                    break;
                }
            }
        }

        void drainFused() {
            int missed = 1;

            for (;;) {
                if (cancelled) {
                    return;
                }

                boolean d = done;
                Throwable ex = error;

                if (!delayError && d && ex != null) {
                    actual.onError(error);
                    worker.dispose();
                    return;
                }

                actual.onNext(null);

                if (d) {
                    ex = error;
                    if (ex != null) {
                        actual.onError(ex);
                    } else {
                        actual.onComplete();
                    }
                    worker.dispose();
                    return;
                }

                missed = addAndGet(-missed);
                if (missed == 0) {
                    break;
                }
            }
        }

        @Override
        public void run() { //实现开线程
            if (outputFused) {
                drainFused();
            } else {
                drainNormal();
            }
        }

	 //检查 是否 已经 结束（error complete）， 是否没数据要发送了(empty 空)， 
        boolean checkTerminated(boolean d, boolean empty, Observer<? super T> a) {
         //如果已经disposed 
            if (cancelled) {
                queue.clear();
                return true;
            }
             // 如果已经结束
            if (d) {
                Throwable e = error;
                //如果是延迟发送错误
                if (delayError) {
                //如果空
                    if (empty) {
                        if (e != null) {
                            a.onError(e);
                        } else {
                            a.onComplete();
                        }
                        //停止worker（线程）
                        worker.dispose();
                        return true;
                    }
                } else {
                //发送错误
                    if (e != null) {
                        queue.clear();
                        a.onError(e);
                        worker.dispose();
                        return true;
                    } else
                     //发送complete
                    if (empty) {
                        a.onComplete();
                        worker.dispose();
                        return true;
                    }
                }
            }
            return false;
        }

        @Override
        public int requestFusion(int mode) {
            if ((mode & ASYNC) != 0) {
                outputFused = true;
                return ASYNC;
            }
            return NONE;
        }

        @Nullable
        @Override
        public T poll() throws Exception {
            return queue.poll();
        }

        @Override
        public void clear() {
            queue.clear();
        }

        @Override
        public boolean isEmpty() {
            return queue.isEmpty();
        }
    }
```
目前结论：

* ObserverOnObserver实现了Obsercer和Runnable接口
* 在onNext里，先不切换线程，将数据加入到队列Queue，然后开始切换线程，在另一线程中，从Queue中取出数据，Push给下游Observer
*  onError() onComplete()除了和RxJava2 源码解析（一）提到的一样特性之外，也是将错误/完成信息先保存，切换线程后再发送。 
* 所以ObserverOn()影响的是其下游的代码，且多次调用仍然生效。
* 因为其切换线程是在Observer里的onXXX做的()，这是一个主动的oush行为（影响下游）

### 五. 参考资料
[RxJava2 源码解析（二）](https://www.jianshu.com/p/6ef45f8ee79d)


### 六.文章索引
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
