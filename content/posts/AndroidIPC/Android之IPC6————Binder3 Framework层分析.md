# Android之IPC6————Binder3 Framework层分析
@[toc]
### 一.概述
在前两篇我们分析了Binder在Native层的实现，我们今天来看在Framework层，Binder相关的内容，这一篇也是以注册服务和获取服务来看Binder的流程。

![image](https://imgconvert.csdnimg.cn/aHR0cDovL2dpdHl1YW4uY29tL2ltYWdlcy9iaW5kZXIvamF2YV9iaW5kZXIvamF2YV9iaW5kZXIuanBn?x-oss-process=image/format,png)

bidner在Framework层，采用JNI技术来调用native层的binder架构，从而为上层应用提供服务。
>java JNI本意是Java native interface,是为了方便javad调用C,C++等本地代码所封装的异常接口。jni也是JVM规范中的一部份，因此可以将我们写的 JNI 程序在任何实现了 JNI 规范的 Java 虚拟机中运行。
这篇文章主要讲下面几个方面：

* BinderJNI初始化(注册)
* FrameWork层的注册服务
* FrameWork层的获取服务


下面这个是framework的binder类关系图：
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-CWYxkjlN-1579438106374)(http://gityuan.com/images/binder/java_binder/class_ServiceManager.jpg)]
### 二.BinderJNI初始化
在Android系统开机的过程中，Zygote启动时会有一个虚拟机注册过程，该过程调用AndroidRuntime::startReg方法来完成jni方法的注册。

#### 1.注册JNI方法
```cpp
int AndroidRuntime::startReg(JNIEnv* env)
{
    androidSetCreateThreadFunc((android_create_thread_fn) javaCreateThreadEtc);

    env->PushLocalFrame(200);

    //注册jni方法 【见下】
    if (register_jni_procs(gRegJNI, NELEM(gRegJNI), env) < 0) {
        env->PopLocalFrame(NULL);
        return -1;
    }
    env->PopLocalFrame(NULL);

    return 0;
}
```

注册jni方法
```cpp
int register_android_os_Binder(JNIEnv* env) {
    // 注册Binder类的jni方法【见下】
    if (int_register_android_os_Binder(env) < 0)
        return -1;

    // 注册BinderInternal类的jni方法【见下】
    if (int_register_android_os_BinderInternal(env) < 0)
        return -1;

    // 注册BinderProxy类的jni方法【见下】
    if (int_register_android_os_BinderProxy(env) < 0)
        return -1;
    ...
    return 0;
}
```
#### 2.注册Binder类
```cpp
static int int_register_android_os_Binder(JNIEnv* env)
{
    //其中kBinderPathName = "android/os/Binder";查找kBinderPathName路径所属类

    jclass clazz;

    clazz = env->FindClass(kBinderPathName);
    LOG_FATAL_IF(clazz == NULL, "Unable to find class android.os.Binder");


	//将java层的Binder类保存到mClass变量；
    gBinderOffsets.mClass = (jclass) env->NewGlobalRef(clazz);

	//将Java层execTransact()方法保存到mExecTransact变量；
    gBinderOffsets.mExecTransact
        = env->GetMethodID(clazz, "execTransact", "(IJJI)Z");
    assert(gBinderOffsets.mExecTransact);

	//将Java层mObject属性保存到mObject变量
    gBinderOffsets.mObject
        = env->GetFieldID(clazz, "mObject", "J");
    assert(gBinderOffsets.mObject);

    return AndroidRuntime::registerNativeMethods(
        env, kBinderPathName,
        gBinderMethods, NELEM(gBinderMethods));
}
```

gBinderoffers是全局静态结构体，其定义如下：
```cpp
static struct bindernative_offsets_t
{
    // Class state.
    jclass mClass; //记录Binder类
    jmethodID mExecTransact;//记录execTransact()方法

    // Object state.
    jfieldID mObject; //记录mObject属性

} gBinderOffsets;
```
> gBinderoffers保存了Binder.java类本身的以及其成员方法，execTransact()和成员属性mObject，这为JNI层访问Java层提供通道。另外通过查询获取Java层 binder信息后保存到gBinderOffsets。

再看看registerNativeMethods中第三个参数，即 gBinderMethods
```cpp
//为Java层访问JNI层提供通道。

static const JNINativeMethod gBinderMethods[] = {
     /* name, signature, funcPtr */
    { "getCallingPid", "()I", (void*)android_os_Binder_getCallingPid },
    { "getCallingUid", "()I", (void*)android_os_Binder_getCallingUid },
    { "clearCallingIdentity", "()J", (void*)android_os_Binder_clearCallingIdentity },
    { "restoreCallingIdentity", "(J)V", (void*)android_os_Binder_restoreCallingIdentity },
    { "setThreadStrictModePolicy", "(I)V", (void*)android_os_Binder_setThreadStrictModePolicy },
    { "getThreadStrictModePolicy", "()I", (void*)android_os_Binder_getThreadStrictModePolicy },
    { "flushPendingCommands", "()V", (void*)android_os_Binder_flushPendingCommands },
    { "init", "()V", (void*)android_os_Binder_init },
    { "destroy", "()V", (void*)android_os_Binder_destroy }
};

```
在int_register_android_os_Binder中：

* 通过gBinderOffsets，保存Java层Binder类的信息，为JNI层访问Java层提供通道；
* 通过RegisterMethodsOrDie，将gBinderMethods数组完成映射关系，从而为Java层访问JNI层提供通道。

#### 3.注册BinderInternal
```cpp
static int int_register_android_os_BinderInternal(JNIEnv* env) {
    //其中kBinderInternalPathName = "com/android/internal/os/BinderInternal"
    jclass clazz = FindClassOrDie(env, kBinderInternalPathName);

    gBinderInternalOffsets.mClass = MakeGlobalRefOrDie(env, clazz);
    gBinderInternalOffsets.mForceGc = GetStaticMethodIDOrDie(env, clazz, "forceBinderGc", "()V");

    return RegisterMethodsOrDie(
        env, kBinderInternalPathName,
        gBinderInternalMethods, NELEM(gBinderInternalMethods));
}
```
上面是BinderInternal类的jni方法，gBinderInternalOffsets保存了BinderInternal的forceBinderGc()方法。

gBinderInternalOffsets:
```cpp
//BinderInternal类的JNI方法注册：
static const JNINativeMethod gBinderInternalMethods[] = {
     /* name, signature, funcPtr */
    { "getContextObject", "()Landroid/os/IBinder;", (void*)android_os_BinderInternal_getContextObject },
    { "joinThreadPool", "()V", (void*)android_os_BinderInternal_joinThreadPool },
    { "disableBackgroundScheduling", "(Z)V", (void*)android_os_BinderInternal_disableBackgroundScheduling },
    { "handleGc", "()V", (void*)android_os_BinderInternal_handleGc }
};

```
和上面的类似，也是给Native层与framework层之间的相互调用的桥梁。

#### 4. 注册BinderProxy
```cpp
static int int_register_android_os_BinderProxy(JNIEnv* env) {
    //gErrorOffsets保存了Error类信息
    jclass clazz = FindClassOrDie(env, "java/lang/Error");
    gErrorOffsets.mClass = MakeGlobalRefOrDie(env, clazz);

    //gBinderProxyOffsets保存了BinderProxy类的信息
    //其中kBinderProxyPathName = "android/os/BinderProxy"
    clazz = FindClassOrDie(env, kBinderProxyPathName);
    gBinderProxyOffsets.mClass = MakeGlobalRefOrDie(env, clazz);
    gBinderProxyOffsets.mConstructor = GetMethodIDOrDie(env, clazz, "<init>", "()V");
    gBinderProxyOffsets.mSendDeathNotice = GetStaticMethodIDOrDie(env, clazz, "sendDeathNotice", "(Landroid/os/IBinder$DeathRecipient;)V");
    gBinderProxyOffsets.mObject = GetFieldIDOrDie(env, clazz, "mObject", "J");
    gBinderProxyOffsets.mSelf = GetFieldIDOrDie(env, clazz, "mSelf", "Ljava/lang/ref/WeakReference;");
    gBinderProxyOffsets.mOrgue = GetFieldIDOrDie(env, clazz, "mOrgue", "J");

    //gClassOffsets保存了Class.getName()方法
    clazz = FindClassOrDie(env, "java/lang/Class");
    gClassOffsets.mGetName = GetMethodIDOrDie(env, clazz, "getName", "()Ljava/lang/String;");

    return RegisterMethodsOrDie(
        env, kBinderProxyPathName,
        gBinderProxyMethods, NELEM(gBinderProxyMethods));
}
```
gBinderProxyMethods中:
```cpp
//下面BinderProxy类的JNI方法注册：  
static const JNINativeMethod gBinderProxyMethods[] = {
     /* name, signature, funcPtr */
    {"pingBinder",          "()Z", (void*)android_os_BinderProxy_pingBinder},
    {"isBinderAlive",       "()Z", (void*)android_os_BinderProxy_isBinderAlive},
    {"getInterfaceDescriptor", "()Ljava/lang/String;", (void*)android_os_BinderProxy_getInterfaceDescriptor},
    {"transactNative",      "(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z", (void*)android_os_BinderProxy_transact},
    {"linkToDeath",         "(Landroid/os/IBinder$DeathRecipient;I)V", (void*)android_os_BinderProxy_linkToDeath},
    {"unlinkToDeath",       "(Landroid/os/IBinder$DeathRecipient;I)Z", (void*)android_os_BinderProxy_unlinkToDeath},
    {"destroy",             "()V", (void*)android_os_BinderProxy_destroy},
};
```
和上面一样，也是Native层与framework层之间的相互调用的桥梁
### 三.注册服务
#### 1.SM.addService
从framework的ServiceManager.java开始
```java
public static void addService(String name, IBinder service, boolean allowIsolated) {
    try {
        //先获取SMP对象，则执行注册服务操作【见小节3.2/3.4】
        getIServiceManager().addService(name, service, allowIsolated); 
    } catch (RemoteException e) {
        Log.e(TAG, "error in addService", e);
    }
}
```
在addService中先获去ServiceManagerProxy

#### 2.获取SMP
getIServiceManager
```java
private static IServiceManager getIServiceManager() {
    if (sServiceManager != null) {
        return sServiceManager;
    }

    sServiceManager = ServiceManagerNative.asInterface(BinderInternal.getContextObject());
    return sServiceManager;
}
```
获取SMP有两步关键步骤，即BinderInternal.getContextObject()，和ServiceManagerNative.asInterface()

BinderInternal.getContextObject()中最终会去获取JNI( android_util_binder.cpp)中android_os_BinderInternal_getContextObject方法，
```java
static jobject android_os_BinderInternal_getContextObject(JNIEnv* env, jobject clazz)
{
    sp<IBinder> b = ProcessState::self()->getContextObject(NULL);
    return javaObjectForIBinder(env, b); 
}
```
对于ProcessState::self()->getContextObject()，在上一节中以及解决过，即ProcessState::self()->getContextObject()等价于 new BpBinder(0);

继续看javaObjectForIBinder():
```java
object javaObjectForIBinder(JNIEnv* env, const sp<IBinder>& val) {
    if (val == NULL) return NULL;

    if (val->checkSubclass(&gBinderOffsets)) { //返回false
        jobject object = static_cast<JavaBBinder*>(val.get())->object();
        return object;
    }

    AutoMutex _l(mProxyLock);

    jobject object = (jobject)val->findObject(&gBinderProxyOffsets);
    if (object != NULL) { //第一次object为null
        jobject res = jniGetReferent(env, object);
        if (res != NULL) {
            return res;
        }
        android_atomic_dec(&gNumProxyRefs);
        val->detachObject(&gBinderProxyOffsets);
        env->DeleteGlobalRef(object);
    }

    //创建BinderProxy对象
    object = env->NewObject(gBinderProxyOffsets.mClass, gBinderProxyOffsets.mConstructor);
    if (object != NULL) {
        //BinderProxy.mObject成员变量记录BpBinder对象
        env->SetLongField(object, gBinderProxyOffsets.mObject, (jlong)val.get());
        val->incStrong((void*)javaObjectForIBinder);

        jobject refObject = env->NewGlobalRef(
                env->GetObjectField(object, gBinderProxyOffsets.mSelf));
        //将BinderProxy对象信息附加到BpBinder的成员变量mObjects中
        val->attachObject(&gBinderProxyOffsets, refObject,
                jnienv_to_javavm(env), proxy_cleanup);

        sp<DeathRecipientList> drl = new DeathRecipientList;
        drl->incStrong((void*)javaObjectForIBinder);
        //BinderProxy.mOrgue成员变量记录死亡通知对象
        env->SetLongField(object, gBinderProxyOffsets.mOrgue, reinterpret_cast<jlong>(drl.get()));

        android_atomic_inc(&gNumProxyRefs);
        incRefsCreated(env);
    }
    return object;
}
```
根据BpBinder(C++)生成BinderProxy(Java)对象. 主要工作是创建BinderProxy对象,并把BpBinder对象地址保存到BinderProxy.mObject成员变量. 到此，可知ServiceManagerNative.asInterface(BinderInternal.getContextObject()) 等价于
```java
ServiceManagerNative.asInterface(new BinderProxy())
```

回到上面的ServiceManagerNative.asInterface()中
```java
 static public IServiceManager asInterface(IBinder obj) {
    if (obj == null) { //obj为BpBinder
        return null;
    }
    //由于obj为BpBinder，该方法默认返回null
    IServiceManager in = (IServiceManager)obj.queryLocalInterface(descriptor);
    if (in != null) {
        return in;
    }
    return new ServiceManagerProxy(obj); 
}
```

所以ServiceManagerNative.asInterface(BinderInternal.getContextObject())等价于
```java
new ServiceManagerProxy(new BinderProxy()).
```

来看看 ServiceManagerProxy()的构造函数
```java
class ServiceManagerProxy implements IServiceManager {
    public ServiceManagerProxy(IBinder remote) {
        mRemote = remote;
    }
}
```
mRemote为BinderProxy对象，该BinderProxy对象对应于BpBinder(0)，其作为binder代理端，指向native层大管家service Manager。

#### 3.SMP.addService()
通过上面的分析可知getIServiceManager()最终获取的是ServiceManagerProxy()，所以我们来看看ServiceManagerProxy()的addService方法。
```java
public void addService(String name, IBinder service, boolean allowIsolated) throws RemoteException {
    Parcel data = Parcel.obtain();
    Parcel reply = Parcel.obtain();
    data.writeInterfaceToken(IServiceManager.descriptor);
    data.writeString(name);
    //【见下文】
    data.writeStrongBinder(service);
    data.writeInt(allowIsolated ? 1 : 0);
    //mRemote为BinderProxy【见下文】
    mRemote.transact(ADD_SERVICE_TRANSACTION, data, reply, 0);
    reply.recycle();
    data.recycle();
}
```
这里我们发现，和Native层注册服务的步骤几乎一模一样。
所以问题变为FrameWork层的Binder转换为Native层。

当时我们分析Native层的时候，主要看的是writeStrongBinder和transact方法，这里我们继续看这两个方法是如何从java到c++的。
#### 4.writeStrongBinder
```java
public writeStrongBinder(IBinder val){
    //此处为Native调用
    nativewriteStrongBinder(mNativePtr, val);
}
```
看调用JNI的方法
```cpp
static void android_os_Parcel_writeStrongBinder(JNIEnv* env, jclass clazz, jlong nativePtr, jobject object) {
    //将java层Parcel转换为native层Parcel
    Parcel* parcel = reinterpret_cast<Parcel*>(nativePtr);
    if (parcel != NULL) {
        //ibinderForJavaObject【见下】
        const status_t err = parcel->writeStrongBinder(ibinderForJavaObject(env, object));
        if (err != NO_ERROR) {
            signalExceptionForError(env, clazz, err);
        }
    }
}
```
继续看ibinderForJavaObject
```cpp
sp<IBinder> ibinderForJavaObject(JNIEnv* env, jobject obj)
{
    if (obj == NULL) return NULL;

    //Java层的Binder对象
    if (env->IsInstanceOf(obj, gBinderOffsets.mClass)) {
        JavaBBinderHolder* jbh = (JavaBBinderHolder*)
            env->GetLongField(obj, gBinderOffsets.mObject);
        return jbh != NULL ? jbh->get(env, obj) : NULL; 
    }
    //Java层的BinderProxy对象
    if (env->IsInstanceOf(obj, gBinderProxyOffsets.mClass)) {
        return (IBinder*)env->GetLongField(obj, gBinderProxyOffsets.mObject);
    }
    return NULL;
}
```
在这里面将Binde(Java)生成JavaBBinderHolder(C++)对象. 主要工作是创建JavaBBinderHolder对象,并把JavaBBinderHolder对象地址保存到Binder.mObject成员变量。

我们看看 ibinderForJavaObject最终返回的结果,即JavaBBinderHolder.get()
```java
sp<JavaBBinder> get(JNIEnv* env, jobject obj) {
    AutoMutex _l(mLock);
    sp<JavaBBinder> b = mBinder.promote();
    if (b == NULL) {
        //首次进来，创建JavaBBinder对象
        b = new JavaBBinder(env, obj);
        mBinder = b;
    }
    return b;
}
```

所以最终data.writeStrongBinder(service);转换为parcel->writeStrongBinder(new JavaBBinder(env, obj));

最后来看看parcel->writeStrongBinder。
```cpp
status_t Parcel::writeStrongBinder(const sp<IBinder>& val)
{
    return flatten_binder(ProcessState::self(), val, this);
}
```
没错，这就是我们上一篇博客中分析的writeStrongBinder的内容。


#### 5.mRemote.transact
在第一节中，我们知道mRemote 其实就BinderProxy。
```cpp
public boolean transact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
    //用于检测Parcel大小是否大于800k
    Binder.checkParcel(this, code, data, "Unreasonably large binder buffer");
    return transactNative(code, data, reply, flags); 
}
```
transactNative经过jni调用，进入方法 jni的android_os_BinderProxy_transact
```cpp
static jboolean android_os_BinderProxy_transact(JNIEnv* env, jobject obj,
    jint code, jobject dataObj, jobject replyObj, jint flags)
{
    ...
    //java Parcel转为native Parcel
    Parcel* data = parcelForJavaObject(env, dataObj);
    Parcel* reply = parcelForJavaObject(env, replyObj);
    ...
    
    //gBinderProxyOffsets.mObject中保存的是new BpBinder(0)对象
    IBinder* target = (IBinder*)
        env->GetLongField(obj, gBinderProxyOffsets.mObject);
    ...

    //此处便是BpBinder::transact(), 经过native层，进入Binder驱动程序
    status_t err = target->transact(code, *data, reply, flags);
    ...
    return JNI_FALSE;
}
```
Java层的BinderProxy.transact()最终交由Native层的BpBinder::transact()完成。之后的内容在就是上一篇博客的内容，也就是交给了Native。

#### 6.小结
在framework中，也是先获取ServiceManagerm,他最终获得的是一个ServiceManagermProxy,在它之中含有一个BinderProxy的成员变量，它含有Native层的BpBInder，而BpBinder含有Binder驱动中ServiceManager的binder对象。

之后和Native层一样，调用Parcel的writeStrongBinder和BinderProxy的transact
，最终经过JNI，调用Native层对应的方法。
### 四.获取服务
和注册服务一样，调用ServiceManager中的getService方法。

#### 1. SM.getService
```java
public static IBinder getService(String name) {
    try {
        IBinder service = sCache.get(name); //先从缓存中查看
        if (service != null) {
            return service;
        } else {
            return getIServiceManager().getService(name); 
        }
    } catch (RemoteException e) {
        Log.e(TAG, "error in getService", e);
    }
    return null;
}
```

 > return getIServiceManager().getService(name)
 
这行代码和获取服务一样，最终转换为ServiceManagerNative.getService(name);所以我们直接看对应代码

#### 2. SMP.getService
```java
lass ServiceManagerProxy implements IServiceManager {
    public IBinder getService(String name) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        data.writeInterfaceToken(IServiceManager.descriptor);
        data.writeString(name);
        //mRemote为BinderProxy 
        mRemote.transact(GET_SERVICE_TRANSACTION, data, reply, 0); 
        //从reply里面解析出获取的IBinder对象
        IBinder binder = reply.readStrongBinder(); 
        reply.recycle();
        data.recycle();
        return binder;
    }
}
```
这里的代码还是Native层几乎一样，我们一样关注reply.readStrongBinder和 mRemote.transact如何调用到Native层的代码

#### 3.mRemote.transact
```java
final class BinderProxy implements IBinder {
    public boolean transact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
        Binder.checkParcel(this, code, data, "Unreasonably large binder buffer");
        return transactNative(code, data, reply, flags);
    }
}
```

transactNative最后会调用jni中的android_os_BinderProxy_transact方法
```cpp
static jboolean android_os_BinderProxy_transact(JNIEnv* env, jobject obj,
    jint code, jobject dataObj, jobject replyObj, jint flags)
{
    ...
    //java Parcel转为native Parcel
    Parcel* data = parcelForJavaObject(env, dataObj);
    Parcel* reply = parcelForJavaObject(env, replyObj);
    ...

    //gBinderProxyOffsets.mObject中保存的是new BpBinder(0)对象
    IBinder* target = (IBinder*)
        env->GetLongField(obj, gBinderProxyOffsets.mObject);
    ...

    //此处便是BpBinder::transact()
    status_t err = target->transact(code, *data, reply, flags);
    ...
    return JNI_FALSE;
}
```

在这里的最后，发现调用了BpBinder的transact方法，之后就是上一篇博客的内容了。

#### 4.readStrongBinder
java层的
```java
public final IBinder readStrongBinder() {
        return nativeReadStrongBinder(mNativePtr);
    }
```

jni层
```cpp
static jobject android_os_Parcel_readStrongBinder(JNIEnv* env, jclass clazz, jlong nativePtr)
{
    Parcel* parcel = reinterpret_cast<Parcel*>(nativePtr);
    if (parcel != NULL) {
        return javaObjectForIBinder(env, parcel->readStrongBinder());
    }
    return NULL;
}
```
 parcel->readStrongBinder()此处就是Native层的方法，也就是我们上一篇文章分析的地方
 
 来看看javaObjectForIBinder是干什么的
 ```cpp
 jobject javaObjectForIBinder(JNIEnv* env, const sp<IBinder>& val)
{
    if (val == NULL) return NULL;

    if (val->checkSubclass(&gBinderOffsets)) {
        // One of our own!
        //本线程
        jobject object = static_cast<JavaBBinder*>(val.get())->object();
        LOGDEATH("objectForBinder %p: it's our own %p!\n", val.get(), object);
        return object;
    }

    // For the rest of the function we will hold this lock, to serialize
    // looking/creation of Java proxies for native Binder proxies.
    //加锁
    AutoMutex _l(mProxyLock);

    // Someone else's...  do we know about it?
    //其他线程的
    jobject object = (jobject)val->findObject(&gBinderProxyOffsets);
    if (object != NULL) {
        jobject res = jniGetReferent(env, object);
        if (res != NULL) {
            ALOGV("objectForBinder %p: found existing %p!\n", val.get(), res);
            return res;
        }
        LOGDEATH("Proxy object %p of IBinder %p no longer in working set!!!", object, val.get());
        android_atomic_dec(&gNumProxyRefs);
        val->detachObject(&gBinderProxyOffsets);
        env->DeleteGlobalRef(object);
    }

    object = env->NewObject(gBinderProxyOffsets.mClass, gBinderProxyOffsets.mConstructor);
    if (object != NULL) {
        LOGDEATH("objectForBinder %p: created new proxy %p !\n", val.get(), object);
        // The proxy holds a reference to the native object.
        env->SetLongField(object, gBinderProxyOffsets.mObject, (jlong)val.get());
        val->incStrong((void*)javaObjectForIBinder);

        // The native object needs to hold a weak reference back to the
        // proxy, so we can retrieve the same proxy if it is still active.
        //本机对象需要将一个弱引用保留回代理，以便我们可以检索相同的代理(如果它仍然是活动的)。
        jobject refObject = env->NewGlobalRef(
                env->GetObjectField(object, gBinderProxyOffsets.mSelf));
        val->attachObject(&gBinderProxyOffsets, refObject,
                jnienv_to_javavm(env), proxy_cleanup);

        // Also remember the death recipients registered on this proxy
        //还请记住在此代理上注册的死亡收件人
        sp<DeathRecipientList> drl = new DeathRecipientList;
        drl->incStrong((void*)javaObjectForIBinder);
        env->SetLongField(object, gBinderProxyOffsets.mOrgue, reinterpret_cast<jlong>(drl.get()));

        // Note that a new object reference has been created.
        //注意，已经创建了一个新的对象引用
        android_atomic_inc(&gNumProxyRefs);
        incRefsCreated(env);
    }

    return object;
}
 ```
在这里主要是将Native层返回的Binder，转换为Framework的Binder。

#### 5.总结
获取服务时，也是先获得ServiceManagerProxy，它其中包含BinderProxy的成员变量，它含有Native层的BpBInder，而BpBinder指向Binder驱动中ServiceManager的binder对象。

在SMP中，获取服务的代码和Native层中几乎一样，最终经过JNI，转换为NAtive层的代码

### 五.总结
这一篇来说，相对容易理解一下，特别是ServiceManager和BinderProxy在Native层都有对应的对象，可以类比。

在ServiceManagerProxy中的AddService和getService的代码几乎和Native层一样，之后利用JNI调用到Native层的代码。

### 六.参考资料
[Binder系列7—framework层分析](http://gityuan.com/2015/11/21/binder-framework/)

