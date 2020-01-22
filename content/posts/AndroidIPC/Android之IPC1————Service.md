# Android之IPC1————Service
@[toc]
### 一.Service的概述
最近打算看看AndroidIPC相关的内容，并进行总结。所以就先从IPC中很常用的Service开始。

Service作为Android四大组件之一，但并不想Activity一样，有很多的接触，对于我来言，大概只有在使用通知时用过它。接下来简单看一下Service的相关概念。

[官方文档](https://developer.android.com/reference/android/app/Service?hl=zh-cn)

#### 1.Service的使用时机
Service是四大组件，在应用程序希望不与用户交互的情况下，执行较长运行时间的操作，或者为其他应用程序提供要使用的功能。service也同Activit一样，需要声明AndroidManifest。

#### 2.Service是什么
如官网所言：它有两不是，两特点即

两不是：  
* Service不是一个单独的进程，Service对象本身并不意味着它运行在自己的进程；除非另有特别的指定，它将和应用程序运行的同一个进程中。
* Service不是一个线程。它并不是一种在主线程之外工作的方法。

两状态：
* 启动状态：当应用组件通过调用StartService()启动服务时，服务即处于"启动"状态，一旦启动，服务即可在后台无期限的运行下去，即使启动服务的组件已被销毁也不受影响。除非手动调用才能停止服务，已启动的服务通常是执行单一操作，而且不会将结果返回给调用方。
* 绑定状态: 当应用组件通过调用bindService() 绑定到服务时，服务即处于“绑定状态”，绑定服务提供了一个客户端-服务器接口，运行组件与服务进行交互，发送请求，获取结果，甚至利用ipc进行跨进程执行这些操作。仅当与另一个组件绑定时，绑定服务才会运行，多组件可以同时绑定到该服务，但全部取消绑定后，该服务会立即被销毁。

### 二.Service在AndroidManifext的声明
首先来看在AndroidManifest里Service的声明：

```xml
<service
    android:name=".MyService">
</service>
```

其他常见属性的说明

属性 | 说明|备注|
---|---|---|
android:name| service的类名||
android:label| Service的名字|若不设置，默认Service的类名|
android:icon|Service的图标||
android:permission|申明此Service的权限|有提供了该权限的应用才能控制或连接此服务|   
android;process|表示该服务是否在另一个进程中运行|不设置默认为本地服务；remote：则设置为远程服务|
android:enabled|系统默认启动|true：Service将会默认被系统启动，不设置则默认为false|
android:exported|该服务是否能够被其他应用程序所控制或连接 |不设置默认为false|


### 三.Service的创建与启动
#### 1.Service代码
```java
public class MyService extends Service {
    private static final String TAG = "MyService";

    public MyService() {
    }


    /**
     * 绑定服务时才会调用
     * 必须要实现的方法
     * @param intent
     * @return
     */
    @Override
    public IBinder onBind(Intent intent) {
        // TODO: Return the communication channel to the service.
        throw new UnsupportedOperationException("Not yet implemented");
    }

    /**
     * 首次创建服务时，系统将调用此方法来指向一次性设置程序，（在调用 onStartCommand() 或 onBind() 之前）。
     * 如果服务已经在运行，则不会调用此方法，该方法之被调用了一次
     */
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "onCreate: ");
    }

    /**
     * 每次通过startService()方法启动Service时都会被回调。
     *
     * @param intent 启动时，启动组件传递过来的Intent
     * @param flags 表示启动请求时是否有额外数据
     * @param startId指明当前服务的唯一ID，与stopSelfResult (int startId)配合使用，stopSelfResult 可以更安全地根据ID停止服务。
     * @return
     */
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "onStartCommand: ");
        return super.onStartCommand(intent, flags, startId);
    }

    /**
     * 服务销毁时的回调，即stopService()时
     */
    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "onDestroy:");
    }
}

```

#### 2.Activity代码
```java
public class MainActivity extends AppCompatActivity implements View.OnClickListener {
    private Button startBt;
    private Button stopBt;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        startBt = (Button) findViewById(R.id.startService);
        stopBt = (Button) findViewById(R.id.stopService);
        startBt.setOnClickListener(this);
        stopBt.setOnClickListener(this);

    }

    @Override
    public void onClick(View v) {
        Intent it = new Intent(this, MyService.class);
        switch (v.getId()) {
            case R.id.startService:
                startService(it);
                break;
            case R.id.stopService:
                stopService(it);
                break;
        }
    }

}

```

#### 3.运行结果
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181031175141840.png)
### 四.Service绑定服务概述

[绑定Service官方文档](https://developer.android.com/guide/components/bound-services?hl=zh-cn)

上面启动的Service只是启动状态，Activity只能启动或者停止Service，除此之外，并没有其他的关联。也就是说，两者之间无法通信。如果需要两者之间进行通信，则需要使Service进入绑定状态。当绑定后，我们就可以在Activity向Service（也就是服务端）发送请求，或者调用Service（服务端）的方法，甚至可以通过绑定服务进行执行ipc。

在进行Service的绑定上，我们必须提供一个iBinder的接口实现类，该类用以提供客户端用来与服务进行交互的编程接口，该类可以通过三种方法定义接口：

#### 1. 扩展的binder类
如果服务时提供仅供本地应用使用，不需要跨进程工作则应通过扩展 Binder 类并从 onBind() 返回它的一个实例来创建接口。客户端收到Binder后，可以利用它直接访问Binder实现中以及Service中公用的公共方法。如果我们的Service不牵扯跨进程，那么优先采用这种方法

#### 2. 使用Messenger
messenger即信使，通过它可以在不同的Message对象(Handler中的Messager，因此 Handler 是 Messenger 的基础)，在Message中存放我们需要传递的数据，然后在进程间传递，如果需要让接口跨不同的进程工作，则可以使用Messenger为服务创建接口，客户端就可以利用Message对象向服务发送命令，同时客户端也可以自定义自有的Messenger，以便服务回传消息。这是IPC最简单的方法。因为Messenger回在单一线程中创建包含所有请求的队列，也就是说Messenger是以串行的方式处理客户端发来的消息。这样我们就不必对服务进行线程安全设计。

#### 3. 使用AIDL
由于Messenger是以串行的方式处理客户端发来的消息。如果当前有大量消息同时发送到Service(服务端)，Service仍然只能一个个处理，这也就是Messenger跨进程通信的缺点了，因此如果有大量并发请求，Messenger就会显得力不从心了，这时AIDL（Android 接口定义语言）就派上用场了， 但实际上Messenger 的跨进程方式其底层实现 就是AIDL，只不过android系统帮我们封装成透明的Messenger罢了 。所以，当Service需要具备多个同时处理多个请求时，则可以直接使用AIDL。

> AIDL:Android接口定义语言，它可以定义客户端与服务使用IPC进行相互通信是都认可的编程接口，在android中，一个进程通常无法访问另一个进程的内存。尽管如此，进程需要将其对象分解成操作系统可以识别的原语，并将对象编组成跨越边界的对象。


上面的三种实现方式，在下面由更详细的介绍。

#### 4.绑定服务的注意点

* 多个客户端可以同时连接到一个服务。不过只有第一个客户端绑定时，系统才会调用服务的onBind()方法俩检索IBinder。系统随后无需再次调用onBind(),便可将同以IBinde传递至任何其他绑定的客户端,当最后一个客户端取消与服务的绑定时，系统会将服务销毁（除非 startService() 也启动了该服务）。
* 通常情况下我们应该在客户端生命周期的引入和退出时刻设置绑定和取消绑定操作，来控制绑定状态下的Service。
* 通常情况下。，切勿在 Activity 的 onResume() 和 onPause() 期间绑定和取消绑定，因为每一次生命周期转换都会发生这些回调，这样反复绑定与解绑是不合理的。此外，如果应用内的多个 Activity 绑定到同一服务，并且其中两个 Activity 之间发生了转换，则如果当前 Activity 在下一次绑定（恢复期间）之前取消绑定（暂停期间），系统可能会销毁服务并重建服务，因此服务的绑定不应该发生在 Activity 的 onResume() 和 onPause()中。
* 我们应该始终 DeadObjectException DeadObjectException 异常，该异常是在连接中断时引发的，表示调用的对象已死亡，也就是Service对象已销毁，这是远程方法引发的唯一异常，DeadObjectException继承自RemoteException，因此我们也可以捕获RemoteException异常。
* 客户端可以通过调用 bindService() 绑定到服务,Android 系统随后调用服务的 onBind() 方法，该方法返回用于与服务交互的 IBinder，而该绑定是异步执行的。

#### 5. 启动服务和绑定服务间的转换问题
前面说了，服务虽然只有两种状态，但其实者两种状态是可以共存的，根据状态的先后顺序可以分为下面者两种状态

* 先绑定服务后启动服务:如果当前Service先以绑定状态运行，再以启动台运行。那么绑定服务将会转为启动服务运行，这时如果之前绑定的宿主（Activity）被销毁了，也不会影响服务的运行，服务还是会一直运行下去，指定收到调用停止服务或者内存不足时才会销毁该服务。
* 先启动服务后绑定服务：如果当前Service实例先以启动状态运行，然后再以绑定状态运行，当前启动服务并不会转为绑定服务，但是还是会与宿主绑定，只是即使宿主解除绑定后，服务依然按启动服务的生命周期在后台运行，直到有Context调用了stopService()或是服务本身调用了stopSelf()方法抑或内存不足时才会销毁服务。

上面两种情况显示出启动服务的优先级确实比绑定服务要高，无论Service处于上面那种状态，我们都可以使用Intent 来使用服务(即使此服务来自另一应用)。

同时服务也是再主线程中运行的，它既不创建自己的线程，也不再单独的进程中执行(除非另行指定)

### 五.扩展Binder类
#### 1.使用场景
如果您的服务仅供本地应用使用，不需要跨进程工作，则可以实现自有 Binder 类，让您的客户端通过该类直接访问服务中的公共方法。

#### 2.使用步骤
* 创建一个Binder实例
* 从onBind()回调方法返回Binder实例
* 从客户端(Activity)中,从onServiceConnected() 回调方法接收 Binder，并使用提供的方法调用绑定服务。

#### 3.代码实现
Service

```java
public class LocalService extends Service {

    private static final String TAG = "LocalService";
    // 需要在onBind里面返回给客户端(Activity)的内容
    private final IBinder mBinder = new LocalBinder();

    private int count;
    private boolean quit;

    //类用于客户端绑定器。因为我们知道这个服务总是在与它的客户端相同的进程中运行，所以我们不需要处理IPC。
    public class LocalBinder extends Binder {
        LocalService getService() {
            // Return this instance of LocalService so clients can call public methods
            return LocalService.this;
        }
    }

    /**
     * 把IBinder返回给客户端Activity)
     *
     * @param intent
     * @return
     */
    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Log.w(TAG, "Service is onCreate: ");

        new Thread(new Runnable() {
            @Override
            public void run() {
                // 每间隔一秒count加1 ，直到quit为true。
                while (!quit) {
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                    count++;
                }
            }
        }).start();
    }

    /**
     * 公共方法
     */
    public int getCount() {
        return count;
    }

    /**
     * 解除绑定时调用
     *
     * @return
     */
    @Override
    public boolean onUnbind(Intent intent) {
        Log.w(TAG, "Service is  onUnbind");
        return super.onUnbind(intent);
    }


    @Override
    public void onDestroy() {
        Log.w(TAG, "Service is invoke Destroyed");
        this.quit = true;
        super.onDestroy();
    }

}

```
上面的代码简单而言，就是定义一个Binder对象，并在onBind中将其返回。在Binder对象中，将当前Service返回。


Activty
```java
public class MainActivity extends AppCompatActivity implements View.OnClickListener {

    private Button bindBt;
    private Button unbindBt;
    private Button getDatasBt;
    private static final String TAG = "MainActivity";

    /**
     * ServiceConnection代表与服务的连接，它只有两个方法，
     * onServiceConnected和onServiceDisconnected，
     * 前者是在操作者在连接一个服务成功时被调用，而后者是在服务崩溃或被杀死导致的连接中断时被调用
     */
    private ServiceConnection conn;
    private LocalService mService;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        bindBt = (Button) findViewById(R.id.bindBt);
        unbindBt = (Button) findViewById(R.id.unbindBt);
        getDatasBt = (Button) findViewById(R.id.getDatasBt);
        bindBt.setOnClickListener(this);
        unbindBt.setOnClickListener(this);
        getDatasBt.setOnClickListener(this);

        conn =new ServiceConnection() {
            /**
             * 与服务器端交互的接口方法 绑定服务的时候被回调，在这个方法获取绑定Service传递过来的IBinder对象，
             * 通过这个IBinder对象，实现宿主和Service的交互。
             */
            @Override public void onServiceConnected (ComponentName name, IBinder service){
                Log.w(TAG, "绑定成功调用：onServiceConnected");
                // 获取Binder
                LocalService.LocalBinder binder = (LocalService.LocalBinder) service;
                mService = binder.getService();
            }
            /**
             *当取消绑定的时候被回调。但正常情况下是不被调用的，它的调用时机是当Service服务被意外销毁时，
             *例如内存的资源不足时这个方法才被自动调用。
             */
            @Override public void onServiceDisconnected (ComponentName name){
                mService = null;
            }
        };
    }

    @Override
    public void onClick(View v) {
        Intent it = new Intent(this, LocalService.class);
        switch (v.getId()) {
            case R.id.bindBt:
                Log.w(TAG, "绑定调用：bindService");
                //调用绑定方法
                bindService(it, conn, Service.BIND_AUTO_CREATE);
                break;
            case R.id.unbindBt:
                Log.w(TAG, "解除绑定调用：unbindService"); // 解除绑定
                if (mService != null) {
                    mService = null;
                    unbindService(conn);
                }
                break;
            case R.id.getDatasBt:
                if (mService != null) { // 通过绑定服务传递的Binder对象，获取Service暴露出来的数据
                    Log.w(TAG, "从服务端获取数据：" + mService.getCount());
                } else {
                    Log.w(TAG, "还没绑定呢，先绑定,无法从服务端获取数据");
                }
                break;
        }
    }
}

```
上面的代码中，通过 bindService和unbindService对Service进行绑定和解绑。通过ServiceConnection获得对应的Service对象，从而调用对应的公用方法。

#### 4.运行结果
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181031175219683.png

通过Log可在，第一次点击绑定服务时，LocalService服务端的onCreate()、onBind方法会依次被调用，此时客户端的ServiceConnection#onServiceConnected()被调用并返回LocalBinder对象，接着调用LocalBinder#getService方法返回LocalService实例对象，此时客户端便持有了LocalService的实例对象，也就可以任意调用LocalService类中的声明公共方法了。解除绑定时，LocalService的onUnBind、onDestroy方法依次被回调。
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181031175325396.png)
### 六.使用Messenger

#### 1.使用场景
当Service需要进行跨进程通信（IPC）时，但是不需要执行多线程处理，此时就可以使用Messenger进行跨进程通信。

#### 2.使用步骤
* Service实现一个handler,由其接收来自客户端的每个调用的回调
* Handrer用于创建Messanger对象(对Handler的引用)
* Messanger创建一个IBinder对象，Service通过onBind()使其返回客户端
* 客户端使用IBingdr将Messenger(引用服务的Handler)实例化,然后使用后者将Message对象发送给Service。
* Service在其 Handler 中（具体地讲，是在 handleMessage() 方法中）接收每个 Message。

#### 3.代码
Service:
```java
public class MessengerService extends Service {
    //命令服务显示一条消息
    static final int MSG_SAY_HELLO = 1;
    private static final String TAG = "MessengerService";

    /**
     * 用于接收从客户端传递过来的数据
     * 并向就向客户端回复消息
     */
    class IncomingHandler extends Handler {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case MSG_SAY_HELLO:
                    Log.w(TAG, "Service收到 客户端的消息:" + msg.getData().getString("msg"));

                    //回复客户端信息,该对象由客户端传递过来
                    Messenger client = msg.replyTo;
                    //获取回复信息的消息实体
                    Message replyMsg = Message.obtain(null, MessengerService.MSG_SAY_HELLO,0,0);
                    Bundle bundle = new Bundle();
                    bundle.putString("reply", "收到，你好客户端");
                    replyMsg.setData(bundle);

                    Log.w(TAG, "Service回复 客户端的消息:收到，你好客户端" );
                    //向客户端发送消息
                    try {

                        client.send(replyMsg);

                    } catch (RemoteException e) {

                        e.printStackTrace();
                    }


                    break;
                default:
                    super.handleMessage(msg);
            }

        }
    }

    /**
     * 创建Messenger并传入Handler实例对象
     */
    final Messenger mMessenger = new Messenger(new IncomingHandler());

    @Override
    public IBinder onBind(Intent intent) {
        Log.w(TAG, "Service 绑定成功");
        return mMessenger.getBinder();
    }
}

```
在Service代码中，在Messenger中的获得从客户端发送的消息，并将回复发送客户端。


Activity
```java
public class ActivityMessenger extends Activity implements View.OnClickListener {

    private static final String TAG = "ActivityMessenger";
    /**
     * 与服务端交互的Messenger
     */
    private Messenger mService = null;

    /**
     * Flag indicating whether we have called bind on the service.
     */
    private boolean mBound;

    /**
     * 实现与服务端链接的对象
     */


    private Button bindBt;
    private Button unbindBt;
    private Button sendMsg;

    private ServiceConnection conn;

    //用来接收服务器返回的消息
    private Messenger mRecevierReplyMsg = new Messenger(new ReceiverReplyMsgHandler());

    private static class ReceiverReplyMsgHandler extends Handler {
        public void handleMessage(Message msg) {
            switch (msg.what) {
                //接收服务端回复
                case  MessengerService.MSG_SAY_HELLO:
                    Log.w(TAG, "客户端收到Service回复" + msg.getData().getString("reply"));
                    break;
                default:
                    super.handleMessage(msg);
            }
        }
    }

    public void sayHello(View v) {
        if (!mBound) return;
        // 创建与服务交互的消息实体Message
        Message msg = Message.obtain(null, MessengerService.MSG_SAY_HELLO, 0, 0);
        Bundle data = new Bundle();
        data.putString("msg", "你好，Service");
        msg.setData(data);
        msg.replyTo = mRecevierReplyMsg;
        try {
            Log.w(TAG, "客户端给Service发送消息:你好，Service" );
            //发送消息
            mService.send(msg);
        } catch (RemoteException e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_messenger);

        bindBt = (Button) findViewById(R.id.bindBt);
        unbindBt = (Button) findViewById(R.id.unbindBt);
        sendMsg = (Button) findViewById(R.id.sendMsg);
        bindBt.setOnClickListener(this);
        unbindBt.setOnClickListener(this);
        sendMsg.setOnClickListener(this);

        conn = new ServiceConnection() {
            @Override
            public void onServiceConnected(ComponentName name, IBinder service) {
                //通过服务端传递的IBingder对象，创建相应的Messenger
                mService = new Messenger(service);
                mBound = true;
            }

            @Override
            public void onServiceDisconnected(ComponentName name) {
                mService = null;
                mBound = false;
            }
        };
    }

    @Override
    public void onClick(View v) {
        Intent it = new Intent(ActivityMessenger.this, MessengerService.class);
        switch (v.getId()) {
            case R.id.bindBt:
                Log.w(TAG, "绑定调用：bindService"); //调用绑定方法
                bindService(it, conn, Context.BIND_AUTO_CREATE);
                break;
            case R.id.unbindBt:
                Log.w(TAG, "解除绑定调用：unbindService"); // 解除绑定
                if (mService != null) {
                    mService = null;
                    unbindService(conn);
                    mBound = false;
                }
                break;
            case R.id.sendMsg:
                sayHello(v);
                break;
        }
    }
}
```
在Activity通过bindService和unbindService对Service进行绑定个解绑，并通过 ServiceConnection()获得Service，进而向Service消息。同时定义一个ReceiverReplyMsgHandler，接收Service发送的消息。

指定Service在另一个进程中运行
```xml
    <service android:name=".MessengerService"
            android:process=":remote"
         />

```
#### 4.运行结果
客户端Log
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181031175437314.png)

ServiceLog
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181031175522500.png)


下图就是其通信过程
![image](https://img-blog.csdn.net/20161004221152656)

### 七.使用AIDL

#### 1.使用场景
上面我们使用Messenger来进行进程间通信的方法，可以发现，Messenger是以串行的方法处理客户端发来的消息，如果大量的消息同时发送的服务端，服务端仍然只能一个个处理，同时我们有时要跨进程调用Service的方法，再这些情况下，Messenger不能胜任，此时就应该使用AIDL

#### 2.使用步骤
* 创建.aidl文件：此文件带有方法签名的编程接口
* 实现接口：Android SDK工具根据,aidl文件，使用Java编程语言生成一个接口。此接口具有一个Sutb的内部抽象类，并用于扩展Binder类并实现AIDL接口中的方法。
* 向客户端公开该接口，实现Service并重写onBind() 以返回 Stub 类的实现。

关于AIDL的内容非常的多，所以我单独将其汇总成一篇博客。

### 八.前台Service
前台Service被认为是用户主动意识到一种服务，因此再内存不足时，系统也不考虑将其终止。前台Service必须为状态栏提供通知。这意味着，除非服务停止或者从前台移出，否则不能清除通知。

要请求让服务运行与前台，可以调用startForeground()。此方法采用两个参数：唯一标识通知的整型数和状态栏的 Notification。要从前台移除服务，请调用 stopForeground()。此方法采用一个布尔值，指示是否也移除状态栏通知。 此方法不会停止服务。 但是，如果您在服务正在前台运行时将其停止，则通知也会被移除。

[关于Android8.0 通知栏的适配](https://blog.csdn.net/guolin_blog/article/details/79854070)

#### 1.代码
```java
public class ForegroundService extends Service {
    private static final int NOTIFICATION_DOWNLOAD_PROGRESS_ID = 0x0001;

    private boolean isRemove = false;//是否需要移除

    /**
     * 创建通知栏
     * 并进行8.0适配
     * @return
     */

    public void createNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            String channelId = "chat";
            String channelName = "聊天消息";
            int importance = NotificationManager.IMPORTANCE_HIGH;
            createNotificationChannel(channelId, channelName, importance);

            sendChatMag();
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        int i = intent.getExtras().getInt("cmd");
        if (i == 0) {
            Log.d("11111", "onStartCommand: "+isRemove);
            if (!isRemove) {
                createNotification();
            }
            isRemove = true;
        } else {
            //移除前台服务
            if (isRemove) {
                stopForeground(true);
            }
            isRemove = false;
        }
        return super.onStartCommand(intent, flags, startId);
    }


    @Override
    public void onDestroy() {
        //移出前台服务
        if (isRemove) {
            stopForeground(true);
        }

        isRemove = false;
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @TargetApi(Build.VERSION_CODES.O)
    private void createNotificationChannel(String channelId, String channelName, int importance) {
        NotificationChannel channel = new NotificationChannel(channelId, channelName, importance);
        NotificationManager notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        notificationManager.createNotificationChannel(channel);

    }
    public void sendChatMag() {
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        Notification notification = new NotificationCompat.Builder(this, "chat")
                .setContentTitle("收到一条聊天消息")
                .setContentText("今天中午吃什么？")
                .setWhen(System.currentTimeMillis())
                .setSmallIcon(R.drawable.icon)
                .setLargeIcon(BitmapFactory.decodeResource(getResources(), R.drawable.icon))
                .setAutoCancel(true)
                .build();

        manager.notify(1,notification);
    }
}
```

activity
```java
public class ForegroundActivity extends AppCompatActivity implements View.OnClickListener {


    private Button bindBt;
    private Button unbindBt;
    private static final String TAG = "MainActivity";
     Intent intent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_foreground);
        bindBt = (Button) findViewById(R.id.bindBt);
        unbindBt = (Button) findViewById(R.id.unbindBt);
        intent = new Intent(this,ForegroundService.class);

        bindBt.setOnClickListener(this);
        unbindBt.setOnClickListener(this);

    }

    @Override
    public void onClick(View v) {

        switch (v.getId()) {
            case R.id.bindBt:
                Log.d(TAG, "onClick: ");
                intent.putExtra("cmd",0);//0,开启前台服务,1,关闭前台服务
                startService(intent);
                break;
            case R.id.unbindBt:
                Log.d(TAG, "onClick: ");
                intent.putExtra("cmd",1);//0,开启前台服务,1,关闭前台服务
                startService(intent);
                break;
        }
    }
}

```

#### 2.运行结果
![在这里插入图片描述](https://img-blog.csdnimg.cn/2018103117581373.jpg)
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181031175846776.jpg)
### 九.Servicr的生命周期

#### 1.生命周期的回调
与Activity类似,服务也有生命周期回调的方法。下面就是他每种生命周期方法
```java
public class ExampleService extends Service {
    int mStartMode;       // indicates how to behave if the service is killed
    IBinder mBinder;      // interface for clients that bind
    boolean mAllowRebind; // indicates whether onRebind should be used

    @Override
    public void onCreate() {
        // The service is being created
        //正在创建服务
    }
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // The service is starting, due to a call to startService()
        //由于调用startService()，服务正在启动
        return mStartMode;
    }
    @Override
    public IBinder onBind(Intent intent) {
        // A client is binding to the service with bindService()
        //客户端使用bindService()绑定到服务
        return mBinder;
    }
    @Override
    public boolean onUnbind(Intent intent) {
        // All clients have unbound with unbindService()
        //所有客户端都使用unbindService()解除绑定
        return mAllowRebind;
    }
    @Override
    public void onRebind(Intent intent) {
        // A client is binding to the service with bindService(),
        // after onUnbind() has already been called
        //在调用onUnbind()之后，客户机使用bindService()绑定到服务
    }
    @Override
    public void onDestroy() {
        // The service is no longer used and is being destroyed
        //服务不再使用，并且正在被销毁
    }
}
```
注:与 Activity 生命周期回调方法不同，您不需要调用这些回调方法的超类实现。
左图显示了使用 startService() 所创建的服务的生命周期，右图显示了使用 bindService() 所创建的服务的生命周期。


[外链图片转存中...(img-JM9AAPBu-1579438005937)]

* 从图中可以看出无论服务是通过 startService() 还是 bindService() 创建，都会为所有服务调用 onCreate() 和 onDestroy() 方法。
* 服务的有效生命周期从调用 onStartCommand() 或 onBind() 方法开始。每种方法均有 Intent 对象，该对象分别传递到 startService() 或 bindService()。
* 说明了服务的典型回调方法。尽管该图分开介绍通过 startService() 创建的服务和通过 bindService() 创建的服务，但是，不管启动方式如何，任何服务均有可能允许客户端与其绑定。

#### 2.管理绑定服务的生命周期
当服务与所有客户端之间的绑定全部取消时，Android 系统便会销毁服务（除非还使用 onStartCommand() 启动了该服务）。因此，如果您的服务是纯粹的绑定服务，则无需对其生命周期进行管理 — Android 系统会根据它是否绑定到任何客户端代您管理。

不过，如果您选择实现 onStartCommand() 回调方法，则您必须显式停止服务，因为系统现在已将服务视为已启动。在此情况下，服务将一直运行到其通过 stopSelf() 自行停止，或其他组件调用 stopService() 为止，无论其是否绑定到任何客户端。

此外，如果您的服务已启动并接受绑定，则当系统调用您的 onUnbind() 方法时，如果您想在客户端下一次绑定到服务时接收 onRebind() 调用，则可选择返回 true。onRebind() 返回空值，但客户端仍在其 onServiceConnected() 回调中接收 IBinder。下文图 说明了这种生命周期的逻辑。



### 十.参考资料
[服务官方文档](https://developer.android.com/guide/components/services?hl=zh-cn)  
[绑定服务官方文档](https://developer.android.com/guide/components/bound-services?hl=zh-cn)  
[关于Android Service真正的完全详解，你需要知道的一切](https://blog.csdn.net/javazejian/article/details/52709857)
