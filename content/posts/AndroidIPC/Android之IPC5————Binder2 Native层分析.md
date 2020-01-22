
# Android之IPC5————Binder2 Native层分析
@[toc]
### 一.前言
在上一篇里，我们介绍了binder机制的简单介绍，以及binder内核，ServiceManager的启动。
在上一篇也简单提过，ServiceManager的作用，即注册服务，和获取服务。
![在这里插入图片描述](https://imgconvert.csdnimg.cn/aHR0cDovL2dpdHl1YW4uY29tL2ltYWdlcy9iaW5kZXIvamF2YV9iaW5kZXIvamF2YV9iaW5kZXIuanBn?x-oss-process=image/format,png)
在这一篇中，我们中 主要分析native层，主要分析其注册服务和获取服务的过程，大致流程就是获取BpServiceManager，通过它来和Binder驱动进行通信，ServiceManager在死循环中读写事物，对注册服务和获取服务进行处理，并将结果返回给Binder驱动，binder驱动在将结果返回给客户端或服务端。

本篇文章主要以下面几个方面展开：

* 获取BpServiceManager
* Native层的注册服务和获取服务
* Binder内核中的注册服务和获取服务
* ServiceManager中的注册服务和获取服务的

### 二.获取BpServiceManager
#### 1.概述
> BpServiceManagerton通过接口IServiceManager实现了接口中的业务逻辑函数(获取服务，注册服务)，并通过成员变量mRemote= new BpBinder(0)进行Binder通信工作


获取BpServiceManager是通过defaultServiceManager()方法来完成，当进程注册服务(addService)或 获取服务(getService)的过程之前，都需要先调用defaultServiceManager()方法来获取gDefaultServiceManager对象。对于gDefaultServiceManager对象，如果存在则直接返回；如果不存在则创建该对象

```cpp
sp<IServiceManager> defaultServiceManager()
{
    if (gDefaultServiceManager != NULL) return gDefaultServiceManager;
    {
        AutoMutex _l(gDefaultServiceManagerLock); //加锁
        while (gDefaultServiceManager == NULL) {
         
            gDefaultServiceManager = interface_cast<IServiceManager>(
                ProcessState::self()->getContextObject(NULL));
            if (gDefaultServiceManager == NULL)
                sleep(1);
        }
    }
    return gDefaultServiceManager;
}
```

上面就是获取BpServiceManager的过程
```cpp
gDefaultServiceManager = interface_cast<IServiceManager>(
                ProcessState::self()->getContextObject(NULL));
```
上面这行代码就是关键代码，分为3步,即

* ProcessState::self()，获取ProcessState对象，也是单例
* getContextObject：获取BpBinder，对于handle = 0的BpBinder对象，存在直接返回，否则创建
* 获取BpServiceManager对象

#### 2.获取ProcessState对象
```cpp
sp<ProcessState> ProcessState::self()
{
    Mutex::Autolock _l(gProcessMutex);
    if (gProcess != NULL) {
        return gProcess;
    }

    //实例化ProcessState 【见小节2.2】
    gProcess = new ProcessState;
    return gProcess;
}
```
获取ProcessState对象,也是单例模式.

ProcessState的初始化
```cpp
ProcessState::ProcessState()
    : mDriverFD(open_driver()) // 打开Binder驱动【见小节2.3】
    , mVMStart(MAP_FAILED)
    , mThreadCountLock(PTHREAD_MUTEX_INITIALIZER)
    , mThreadCountDecrement(PTHREAD_COND_INITIALIZER)
    , mExecutingThreadsCount(0)
    , mMaxThreads(DEFAULT_MAX_BINDER_THREADS)
    , mManagesContexts(false)
    , mBinderContextCheckFunc(NULL)
    , mBinderContextUserData(NULL)
    , mThreadPoolStarted(false)
    , mThreadPoolSeq(1)
{
    if (mDriverFD >= 0) {
        //采用内存映射函数mmap，给binder分配一块虚拟地址空间,用来接收事务
        mVMStart = mmap(0, BINDER_VM_SIZE, PROT_READ, MAP_PRIVATE | MAP_NORESERVE, mDriverFD, 0);
        if (mVMStart == MAP_FAILED) {
            close(mDriverFD); //没有足够空间分配给/dev/binder,则关闭驱动
            mDriverFD = -1;
        }
    }

```
在初始化时打开Binder设备，并设定binder支持的最大线程数，之后再使用mmap分配内存。

#### 3.获取BpBinder对象
```cpp
sp<IBinder> ProcessState::getContextObject(const sp<IBinder>& /*caller*/)
{
    return getStrongProxyForHandle(0);  
}
```
获取handle = 0的IBinder。

```cpp
sp<IBinder> ProcessState::getStrongProxyForHandle(int32_t handle)
{
    sp<IBinder> result;

    AutoMutex _l(mLock);
    //查找handle对应的资源项
    handle_entry* e = lookupHandleLocked(handle);

    if (e != NULL) {
        IBinder* b = e->binder;
        if (b == NULL || !e->refs->attemptIncWeak(this)) {
            if (handle == 0) {
                Parcel data;
                //通过ping操作测试binder是否准备就绪
                status_t status = IPCThreadState::self()->transact(
                        0, IBinder::PING_TRANSACTION, data, NULL, 0);
                if (status == DEAD_OBJECT)
                   return NULL;
            }
            //当handle值所对应的IBinder不存在或弱引用无效时，则创建BpBinder对象
            b = new BpBinder(handle);
            e->binder = b;
            if (b) e->refs = b->getWeakRefs();
            result = b;
        } else {
            result.force_set(b);
            e->refs->decWeak(this);
        }
    }
    return result;
}
```

#### 4.获取BpServiceManager
```cpp
template<typename INTERFACE>
inline sp<INTERFACE> interface_cast(const sp<IBinder>& obj)
{
    return INTERFACE::asInterface(obj); 
}
```
在源码中INTERFACE::asInterface(obj)使用宏的模的模拟代码。直接写出替换后的代码
```c++
const android::String16 IServiceManager::descriptor(“android.os.IServiceManager”);

const android::String16& IServiceManager::getInterfaceDescriptor() const
{
     return IServiceManager::descriptor;
}

 android::sp<IServiceManager> IServiceManager::asInterface(const android::sp<android::IBinder>& obj)
{
       android::sp<IServiceManager> intr;
        if(obj != NULL) {
           intr = static_cast<IServiceManager *>(
               obj->queryLocalInterface(IServiceManager::descriptor).get());
           if (intr == NULL) {
               intr = new BpServiceManager(obj);  
            }
        }
       return intr;
}

IServiceManager::IServiceManager () { }
IServiceManager::~ IServiceManager() { }
```

所有说IServiceManager::asInterface() 等价于 new BpServiceManager()。

接下来看BpServiceManager的初始化
```cpp
BpServiceManager(const sp<IBinder>& impl)
    : BpInterface<IServiceManager>(impl)
{    }
```

BpInterface的初始化
```cpp
inline BpInterface<INTERFACE>::BpInterface(const sp<IBinder>& remote)
    :BpRefBase(remote)
{    }
```
BpRefBase的初始化
```cpp
BpRefBase::BpRefBase(const sp<IBinder>& o)
    : mRemote(o.get()), mRefs(NULL), mState(0)
{
    extendObjectLifetime(OBJECT_LIFETIME_WEAK);

    if (mRemote) {
        mRemote->incStrong(this);
        mRefs = mRemote->createWeak(this);
    }
}
```

new BpServiceManager()，在初始化过程中，比较重要工作的是类BpRefBase的mRemote指向new BpBinder(0)，从而BpServiceManager能够利用Binder进行通过通信。

#### 5.总结
defaultServiceManager 等价于 new BpServiceManager(new BpBinder(0));

在这个过程中:
* 调用open()，打开/dev/binder驱动设备；
* 再利用mmap()，创建大小为1M-8K的内存地址空间；
* 设定当前进程最大的最大并发Binder线程个数为16
* BpBinder通过handler来指向所对应BBinder, 在整个Binder系统中handle=0代表ServiceManager所对应的BBinder。


### 三.Native层的注册服务和获取服务

#### 1.服务注册
我们以media服务注册为例
```cpp
int main(int argc __unused, char** argv)
{
    ...
    InitializeIcuOrDie();
    //获得ProcessState实例对象
    sp<ProcessState> proc(ProcessState::self());
    //获取BpServiceManager对象
    sp<IServiceManager> sm = defaultServiceManager();
    AudioFlinger::instantiate();
    //注册多媒体服务  
    MediaPlayerService::instantiate();
    ResourceManagerService::instantiate();
    CameraService::instantiate();
    AudioPolicyService::instantiate();
    SoundTriggerHwService::instantiate();
    RadioService::instantiate();
    registerExtensions();
    //启动Binder线程池
    ProcessState::self()->startThreadPool();
    //当前线程加入到线程池
    IPCThreadState::self()->joinThreadPool();
 }
```
上面是native层中media服务注册的过程。
分为下面几个过程：

* 获取ProcessState对象
* 获取ServiceManager对象
* 注册服务
* 启动binder线程池
* 加入到线程池

在这其中，获取ProcessState对象和获取ServiceManager对象的过程，在上一小节。

我们主要来看其注册服务的过程。

```cpp
void MediaPlayerService::instantiate() {
    //注册服务
    defaultServiceManager()->addService(String16("media.player"), new MediaPlayerService());
}
```
由上一小节可知 defaultServiceManager()返回的是BpServiceManager，所以相当于bpServiceManager调用addService。

BpSM.addService
```cpp
virtual status_t addService(const String16& name, const sp<IBinder>& service, bool allowIsolated) {
    Parcel data, reply; //Parcel是数据通信包
    //写入头信息"android.os.IServiceManager"
    data.writeInterfaceToken(IServiceManager::getInterfaceDescriptor());   
    data.writeString16(name);        
    // name为 "media.player"
    data.writeStrongBinder(service); 
    // MediaPlayerService对象
    data.writeInt32(allowIsolated ? 1 : 0);
    // allowIsolated= false
    //remote()指向的是BpBinder对象
    status_t err = remote()->transact(ADD_SERVICE_TRANSACTION, data, &reply);
    return err == NO_ERROR ? reply.readExceptionCode() : err;
}
```
可以看到，在addService中将Service对象和Service名都写入了data中。

之后调用BpBinder对象的transact方法。



#### 2.获取服务
上面是media在native层注册服务的过程，下面介绍一下madia服务被获取的过程
```cpp
sp<IMediaPlayerService>&
IMediaDeathNotifier::getMediaPlayerService()
{
    Mutex::Autolock _l(sServiceLock);
    if (sMediaPlayerService == 0) {
        sp<IServiceManager> sm = defaultServiceManager(); //获取ServiceManager
        sp<IBinder> binder;
        do {
            //获取名为"media.player"的服务
            binder = sm->getService(String16("media.player"));
            if (binder != 0) {
                break;
            }
            usleep(500000); // 0.5s
        } while (true);

        if (sDeathNotifier == NULL) {
            sDeathNotifier = new DeathNotifier(); //创建死亡通知对象
        }

        //将死亡通知连接到binder 
        binder->linkToDeath(sDeathNotifier);
        sMediaPlayerService = interface_cast<IMediaPlayerService>(binder);
    }
    return sMediaPlayerService;
}
```
上面的代码就是请求获取为”media.player”的服务过程中，采用不断获取的过程。

也是先获BpServiceManager，然后调用BpServiceManager的getService方法。

来看其获取服务的代码
```cpp
virtual sp<IBinder> getService(const String16& name) const
    {
        unsigned n;
        for (n = 0; n < 5; n++){
            sp<IBinder> svc = checkService(name); //见下
            if (svc != NULL) return svc;
            sleep(1);
        }
        return NULL;
    }
```
通过ServiceManager来获取服务，检索服务是否存在，存在直接返回，不存在时。暂停1s后，继续请求。最多5次

继续来看checkService(name)过程
```cpp
virtual sp<IBinder> checkService( const String16& name) const
{
    Parcel data, reply;
    //写入RPC头
    data.writeInterfaceToken(IServiceManager::getInterfaceDescriptor());
    //写入服务名
    data.writeString16(name);
    remote()->transact(CHECK_SERVICE_TRANSACTION, data, &reply); //见下
    return reply.readStrongBinder(); //见下
}
```
可以看出了获取服务和注册服务一样，最终都调用了Bpdineder的transact。
#### 3.注册服务中writeStrongBinder(service)
在注册服务中，将Service传入writeStrongBinder中
```cpp
  data.writeStrongBinder(service);
```

data是Parcel类。
```c
status_t Parcel::writeStrongBinder(const sp<IBinder>& val)
{
    return flatten_binder(ProcessState::self(), val, this);
}
```

```c
status_t flatten_binder(const sp<ProcessState>& /*proc*/,
    const sp<IBinder>& binder, Parcel* out)
{
    flat_binder_object obj;

    obj.flags = 0x7f | FLAT_BINDER_FLAG_ACCEPTS_FDS;
    if (binder != NULL) {
        IBinder *local = binder->localBinder(); //本地Binder不为空
        if (!local) {
            BpBinder *proxy = binder->remoteBinder();
            const int32_t handle = proxy ? proxy->handle() : 0;
            obj.type = BINDER_TYPE_HANDLE;
            obj.binder = 0;
            obj.handle = handle;
            obj.cookie = 0;
        } else { //进入该分支
            obj.type = BINDER_TYPE_BINDER;
            obj.binder = reinterpret_cast<uintptr_t>(local->getWeakRefs());
            obj.cookie = reinterpret_cast<uintptr_t>(local);
        }
    } else {
        ...
    }
   
    return finish_flatten_binder(binder, obj, out);
}
```

将Binder对象扁平化，转换成flat_binder_object对象。

* 对于Binder实体，则cookie记录Binder实体的指针；并且其类型为BINDER_TYPE_HANDLE
* 对于Binder代理，则用handle记录Binder代理的句柄，并且其类型为BINDER_TYPE_BINDER；

#### 4.获取服务的readStrongBinder()
在获取服务中，最后返回的是：
```c
return reply.readStrongBinder(); 
```

和data一样，reply也是Parcel类。
```c
sp<IBinder> Parcel::readStrongBinder() const
{
    sp<IBinder> val;
    unflatten_binder(ProcessState::self(), *this, &val);
    return val;
}
```
调用了 unflatten_binder
```c
status_t unflatten_binder(const sp<ProcessState>& proc, const Parcel& in, sp<IBinder>* out) {
    const flat_binder_object* flat = in.readObject(false);
    if (flat) {
        switch (flat->type) {
            case BINDER_TYPE_BINDER:
               // 当请求服务的进程与服务属于同一进程
                *out = reinterpret_cast<IBinder*>(flat->cookie);
                return finish_unflatten_binder(NULL, *flat, in);
            case BINDER_TYPE_HANDLE:
                //请求服务的进程与服务属于不同进程
                *out = proc->getStrongProxyForHandle(flat->handle);
                //创建BpBinder对象
                return finish_unflatten_binder(
                    static_cast<BpBinder*>(out->get()), *flat, in);
        }
    }
    return BAD_TYPE;
}
```


#### 5.BpBinder.transact
```cpp
status_t err = remote()->transact(ADD_SERVICE_TRANSACTION, data, &reply);
```
在注册服务和获取服务中，最终都调用了上面这行代码。即BpBinder.transact方法。

BpBinder.transact
```cpp
status_t BpBinder::transact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    if (mAlive) {
        // code=ADD_SERVICE_TRANSACTION
        status_t status = IPCThreadState::self()->transact(
            mHandle, code, data, reply, flags);
        if (status == DEAD_OBJECT) mAlive = 0;
        return status;
    }
    return DEAD_OBJECT;
}
```
可以看出在 BpBinder::transact中最终调用的是IPCThreadState::self()->transact方法。

先来看看IPCThreadState的初始化过程和self过程
#### 6. IPCThreadState的初始化
初始化：
```cpp
IPCThreadState::IPCThreadState()
    : mProcess(ProcessState::self()),
      mMyThreadId(gettid()),
      mStrictModePolicy(0),
      mLastTransactionBinderFlags(0)
{
    pthread_setspecific(gTLS, this);
    clearCaller();
    mIn.setDataCapacity(256);//接收来自binder数据
    mOut.setDataCapacity(256);//发往binder数据
}
```

self方法：
```cpp
IPCThreadState* IPCThreadState::self()
{
    if (gHaveTLS) {
restart:
        const pthread_key_t k = gTLS;
        IPCThreadState* st = (IPCThreadState*)pthread_getspecific(k);
        if (st) return st;
        return new IPCThreadState;  //初始IPCThreadState 
    }

    if (gShutdown) return NULL;

    pthread_mutex_lock(&gTLSMutex);
    if (!gHaveTLS) { //首次进入gHaveTLS为false
        if (pthread_key_create(&gTLS, threadDestructor) != 0) { //创建线程的TLS
            pthread_mutex_unlock(&gTLSMutex);
            return NULL;
        }
        gHaveTLS = true;
    }
    pthread_mutex_unlock(&gTLSMutex);
    goto restart;
}
```
在self中，对IPCThreadState进行了初始化，并创建了线程的TLS(线程本地存储空间)。

#### 7.IPC.transact方法。
BpBinder::transact中最终调用的是IPCThreadState::self()->transact方法。
上一小节中，我们查看了IPCThreadState::self()过程，接下来继续查看其transact方法。

```cpp
status_t IPCThreadState::transact(int32_t handle,
                                  uint32_t code, const Parcel& data,
                                  Parcel* reply, uint32_t flags)
{
    status_t err = data.errorCheck(); //数据错误检查
    flags |= TF_ACCEPT_FDS;
    ....
    if (err == NO_ERROR) { // 传输数据 
        err = writeTransactionData(BC_TRANSACTION, flags, handle, code, data, NULL);
    }
    ...

    if ((flags & TF_ONE_WAY) == 0) {
        if (reply) {
            //等待响应
            err = waitForResponse(reply);
        } else {
            Parcel fakeReply;
            err = waitForResponse(&fakeReply);
        }

    } else {
        //oneway，则不需要等待reply的场景
        err = waitForResponse(NULL, NULL);
    }
    return err;
}
```
在上面的代码中主要有三个过程，即数据错误检查,传输数据和等待响应。下两个小节来看数据传输过程和等待响应过程。

#### 8.IPC.writeTransactionData
writeTransactionData即传输数据过程
```cpp
status_t IPCThreadState::writeTransactionData(int32_t cmd, uint32_t binderFlags,
    int32_t handle, uint32_t code, const Parcel& data, status_t* statusBuffer)
{
    binder_transaction_data tr;
    tr.target.ptr = 0;
    tr.target.handle = handle; // handle = 0
    tr.code = code;            // code = ADD_SERVICE_TRANSACTION
    tr.flags = binderFlags;    // binderFlags = 0
    tr.cookie = 0;
    tr.sender_pid = 0;
    tr.sender_euid = 0;

    // data为记录Media服务信息的Parcel对象
    const status_t err = data.errorCheck();
    if (err == NO_ERROR) {
        tr.data_size = data.ipcDataSize();  // mDataSize
        tr.data.ptr.buffer = data.ipcData(); //mData
        tr.offsets_size = data.ipcObjectsCount()*sizeof(binder_size_t); //mObjectsSize
        tr.data.ptr.offsets = data.ipcObjects(); //mObjects
    } else if (statusBuffer) {
        ...
    } else {
        return (mLastError = err);
    }
    
    //cmd=BC_TRANSACTION
    mOut.writeInt32(cmd);        
    mOut.write(&tr, sizeof(tr));  //写入binder_transaction_data数据
    return NO_ERROR;
}
```
上面的handle值为用来标识，在注册服务和获取服务的过程中，目的端都是内核中的ServiceManager。

binder_transction_data是binder通信数据结构，最终是将Binder请求码和tr写入到mOut中。

接下来是waitForResponse()方法
#### 9.IPC.waitForResponse
waitForResponse即IPCThreadState.transact中等待响应过程
```cpp
tatus_t IPCThreadState::waitForResponse(Parcel *reply, status_t *acquireResult)
{
    int32_t cmd;
    int32_t err;
    while (1) {
        //【见下文】
        if ((err=talkWithDriver()) < NO_ERROR) break; 
        ...
        if (mIn.dataAvail() == 0) continue;

        cmd = mIn.readInt32();
        switch (cmd) {
            case BR_TRANSACTION_COMPLETE: ...
            case BR_DEAD_REPLY: ...
            case BR_FAILED_REPLY: ...
            case BR_ACQUIRE_RESULT: ...
            case BR_REPLY: ...
                goto finish;

            default:
                err = executeCommand(cmd);  
                if (err != NO_ERROR) goto finish;
                break;
        }
    }
    ...
    return err;
}
```
在waitForResponse中，先执行BR_TRANSACTION_COMPLET。另外，目标进程收到事物后，处理处理BR_TRANSACTION事务。 然后发送给当前进程，再执行BR_REPLY命令。

talkWithDriver()
```cpp
status_t IPCThreadState::talkWithDriver(bool doReceive)
{
    ...
    binder_write_read bwr;
    const bool needRead = mIn.dataPosition() >= mIn.dataSize();
    const size_t outAvail = (!doReceive || needRead) ? mOut.dataSize() : 0;

    bwr.write_size = outAvail;
    bwr.write_buffer = (uintptr_t)mOut.data();

    if (doReceive && needRead) {
        //接收数据缓冲区信息的填充。如果以后收到数据，就直接填在mIn中了。
        bwr.read_size = mIn.dataCapacity();
        bwr.read_buffer = (uintptr_t)mIn.data();
    } else {
        bwr.read_size = 0;
        bwr.read_buffer = 0;
    }
    //当读缓冲和写缓冲都为空，则直接返回
    if ((bwr.write_size == 0) && (bwr.read_size == 0)) return NO_ERROR;

    bwr.write_consumed = 0;
    bwr.read_consumed = 0;
    status_t err;
    do {
        //通过ioctl不停的读写操作，跟Binder Driver进行通信
        if (ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr) >= 0)
            err = NO_ERROR;
        ...
    } while (err == -EINTR); //当被中断，则继续执行
    ...
    return err;
}
```
在talkWithDriver方法中，是真正与binder驱动进行交换数据的结构，操作mOut和mIn变量。

经过ioctl()经过系统调用后进入Binder内核.

#### 10.总结
在这一小节中，我们以medie为例分析了Native注册服务和获取服务的过程。

* 即首先获得BpServiceManager对象，在调用ServiceManager对应的addService和gitService方法。在注册服务时，还要将当前线程放入binder线程池中。
* 两个方法都会去调用BpBinder的transact方法，但它只是一个代理方法。最终起用IPCThreadState的transact方法。
* IPCThreadState.transact方法中，首先会检查数据是否有误，通过ioctl和Binder内核进行数据传输。并等待响应。

### 四.Binder内核中的注册服务和获取服务
在上一节的最后，我们发现IPCThreadState通过ioctl和binder内核进行了通信。这一节中，我们看binder内核是如何处理注册服务和获取服务的。

ioctl -> binder_ioctl -> binder_ioctl_write_read

#### 1.binder_ioctl_write_read
```c
static int binder_ioctl_write_read(struct file *filp,
                unsigned int cmd, unsigned long arg,
                struct binder_thread *thread)
{
    struct binder_proc *proc = filp->private_data;
    void __user *ubuf = (void __user *)arg;
    struct binder_write_read bwr;

    //将用户空间bwr结构体拷贝到内核空间
    copy_from_user(&bwr, ubuf, sizeof(bwr));
    ...

    if (bwr.write_size > 0) {
        //将数据放入目标进程[见下文]
        ret = binder_thread_write(proc, thread,
                      bwr.write_buffer,
                      bwr.write_size,
                      &bwr.write_consumed);
        ...
    }
    if (bwr.read_size > 0) {
        //读取自己队列的数据 
        ret = binder_thread_read(proc, thread, bwr.read_buffer,
             bwr.read_size,
             &bwr.read_consumed,
             filp->f_flags & O_NONBLOCK);
        if (!list_empty(&proc->todo))
            wake_up_interruptible(&proc->wait);
        ...
    }

    //将内核空间bwr结构体拷贝到用户空间
    copy_to_user(ubuf, &bwr, sizeof(bwr));
    ...
}   
```
#### 2.binder_thread_write
```c
static int binder_thread_write(struct binder_proc *proc,
            struct binder_thread *thread,
            binder_uintptr_t binder_buffer, size_t size,
            binder_size_t *consumed)
{
    uint32_t cmd;
    void __user *buffer = (void __user *)(uintptr_t)binder_buffer;
    void __user *ptr = buffer + *consumed;
    void __user *end = buffer + size;
    while (ptr < end && thread->return_error == BR_OK) {
        //拷贝用户空间的cmd命令，此时为BC_TRANSACTION
        if (get_user(cmd, (uint32_t __user *)ptr)) -EFAULT;
        ptr += sizeof(uint32_t);
        switch (cmd) {
        case BC_TRANSACTION:
        case BC_REPLY: {
            struct binder_transaction_data tr;
            //拷贝用户空间的binder_transaction_data
            if (copy_from_user(&tr, ptr, sizeof(tr)))   return -EFAULT;
            ptr += sizeof(tr);
            // 见下文
            binder_transaction(proc, thread, &tr, cmd == BC_REPLY);
            break;
        }
        ...
    }
    *consumed = ptr - buffer;
  }
  return 0;
}
```
#### 3.binder_transaction
在经过内核中的调度后，最终调度到了binde_transaction方法中。binder_transaction方法代码非常长，所以仅展示和注册获取服务相关的操作。

对于flat_binder_object这个数据结构中，type类型
>1.当type等于BINDER_TYPE_BINDER或BINDER_TYPE_WEAK_BINDER类型时， 代表Server进程向ServiceManager进程注册服务，则创建binder_node对象；  
2.当type等于BINDER_TYPE_HANDLE或BINDER_TYPE_WEAK_HEANDLE类型时， 代表Client进程向Server进程请求代理，则创建binder_ref对象；  
3.当type等于BINDER_TYPE_FD类型时， 代表进程向另一个进程发送文件描述符，只打开文件，则无需创建任何对象。


```c
static void binder_transaction(struct binder_proc *proc,
               struct binder_thread *thread,
               struct binder_transaction_data *tr, int reply){
    struct binder_transaction *t;
   	struct binder_work *tcomplete;
    ...

    if (reply) {
        ...
    }else {
        if (tr->target.handle) {
            ...
        } else {
            // handle=0则找到servicemanager实体
            target_node = binder_context_mgr_node;
        }
        //target_proc为servicemanager进程
        target_proc = target_node->proc;
    }

    if (target_thread) {
        ...
    } else {
        //找到servicemanager进程的todo队列
        target_list = &target_proc->todo;
        target_wait = &target_proc->wait;
    }

    t = kzalloc(sizeof(*t), GFP_KERNEL);
    tcomplete = kzalloc(sizeof(*tcomplete), GFP_KERNEL);

    //非oneway的通信方式，把当前thread保存到transaction的from字段
    if (!reply && !(tr->flags & TF_ONE_WAY))
        t->from = thread;
    else
        t->from = NULL;

    t->sender_euid = task_euid(proc->tsk);
    t->to_proc = target_proc; //此次通信目标进程为servicemanager进程
    t->to_thread = target_thread;
    t->code = tr->code;  //此次通信code = ADD_SERVICE_TRANSACTION
    t->flags = tr->flags;  // 此次通信flags = 0
    t->priority = task_nice(current);

    //从servicemanager进程中分配buffer
    t->buffer = binder_alloc_buf(target_proc, tr->data_size,
        tr->offsets_size, !reply && (t->flags & TF_ONE_WAY));

    t->buffer->allow_user_free = 0;
    t->buffer->transaction = t;
    t->buffer->target_node = target_node;

    if (target_node)
        binder_inc_node(target_node, 1, 0, NULL); //引用计数加1
    offp = (binder_size_t *)(t->buffer->data + ALIGN(tr->data_size, sizeof(void *)));

    //分别拷贝用户空间的binder_transaction_data中ptr.buffer和ptr.offsets到内核
    copy_from_user(t->buffer->data,
        (const void __user *)(uintptr_t)tr->data.ptr.buffer, tr->data_size);
    copy_from_user(offp,
        (const void __user *)(uintptr_t)tr->data.ptr.offsets, tr->offsets_size);

    off_end = (void *)offp + tr->offsets_size;

    for (; offp < off_end; offp++) {
        struct flat_binder_object *fp;
        fp = (struct flat_binder_object *)(t->buffer->data + *offp);
        off_min = *offp + sizeof(struct flat_binder_object);
        switch (fp->type) {
            case BINDER_TYPE_BINDER:
            case BINDER_TYPE_WEAK_BINDER: { //注册服务
              struct binder_ref *ref;
              //【见4.3.1】
              struct binder_node *node = binder_get_node(proc, fp->binder);
              if (node == NULL) {
                //服务所在进程 创建binder_node实体
                node = binder_new_node(proc, fp->binder, fp->cookie);
                ...
              }
              //servicemanager进程binder_ref
              ref = binder_get_ref_for_node(target_proc, node);
              ...
              //调整type为HANDLE类型
              if (fp->type == BINDER_TYPE_BINDER)
                fp->type = BINDER_TYPE_HANDLE;
              else
                fp->type = BINDER_TYPE_WEAK_HANDLE;
              fp->binder = 0;
              fp->handle = ref->desc; //设置handle值
              fp->cookie = 0;
              binder_inc_ref(ref, fp->type == BINDER_TYPE_HANDLE,
                       &thread->todo);
            } break;
        
        
        case BINDER_TYPE_HANDLE:
        case BINDER_TYPE_WEAK_HANDLE: {
        //这是ServiceManager对处理完之后，获取服务
          struct binder_ref *ref = binder_get_ref(proc, fp->handle,
                fp->type == BINDER_TYPE_HANDLE);
          ...
          //此时运行在servicemanager进程，故ref->node是指向服务所在进程的binder实体，
          //而target_proc为请求服务所在的进程，此时并不相等。
          if (ref->node->proc == target_proc) {
            if (fp->type == BINDER_TYPE_HANDLE)
              fp->type = BINDER_TYPE_BINDER;
            else
              fp->type = BINDER_TYPE_WEAK_BINDER;
            fp->binder = ref->node->ptr;
            fp->cookie = ref->node->cookie; //BBinder服务的地址
            binder_inc_node(ref->node, fp->type == BINDER_TYPE_BINDER, 0, NULL);

          } else {
            struct binder_ref *new_ref;
            //请求服务所在进程并非服务所在进程，则为请求服务所在进程创建binder_ref
            new_ref = binder_get_ref_for_node(target_proc, ref->node);
            fp->binder = 0;
            fp->handle = new_ref->desc; //重新赋予handle值
            fp->cookie = 0;
            binder_inc_ref(new_ref, fp->type == BINDER_TYPE_HANDLE, NULL);
          }
        } break;

        case BINDER_TYPE_FD: ...
    }

    if (reply) {
        ..
    } else if (!(t->flags & TF_ONE_WAY)) {
        //BC_TRANSACTION 且 非oneway,则设置事务栈信息
        t->need_reply = 1;
        t->from_parent = thread->transaction_stack;
        thread->transaction_stack = t;
    } else {
        ...
    }

    //将BINDER_WORK_TRANSACTION添加到目标队列，本次通信的目标队列为target_proc->todo
    t->work.type = BINDER_WORK_TRANSACTION;
    list_add_tail(&t->work.entry, target_list);

    //将BINDER_WORK_TRANSACTION_COMPLETE添加到当前线程的todo队列
    tcomplete->type = BINDER_WORK_TRANSACTION_COMPLETE;
    list_add_tail(&tcomplete->entry, &thread->todo);

    //唤醒等待队列，本次通信的目标队列为target_proc->wait
    if (target_wait)
        wake_up_interruptible(target_wait);
    return;
}
```

#### 4.总结
在binder内核中，最终调用binder内核的binder_transaction方法。在这其中，对于注册服务和获取服务有不同的处理。  

对于注册服务：在服务所在的进程中创建该进程对应的binder实体,在ServiceManager中创建binder引用。
最后向servicemanager的binder_proc->todo添加BINDER_WORK_TRANSACTION事务。交给ServiceManager处理。


对于获取服务,binder内核会先将其发往ServiceManager中，ServiceManager处理完毕后，将其他type改为BINDER_TYPE_HANDLE。之后也是在binder_transaction中进行如下处理：
* 当请求服务的进程与服务属于不同的进程，则为请求服务所在的进程创建一个binder引用，指向服务进程中的binder_nodr
* 请求服务的进程与服务属于同一进程是。不在创建新对象，而是引用计数+1.并修改type为BINDER_TYPE_BINDER或BINDER_TYPE_WEAK_BINDER。


### 五.ServiceManager中的注册服务和获取服务的
在上面binder内核中，当创建好对应的对象时，最后向servicemanager的binder_proc->todo添加BINDER_WORK_TRANSACTION事务。将对应的事件交给了servicemanager来继续处理。

#### 1.svcmgr_handler
在上一篇博客中，我们知道ServiceManager中的注册服务和获取服务在svcmgr_handler方法中
```c
int svcmgr_handler(struct binder_state *bs,
                   struct binder_transaction_data *txn,
                   struct binder_io *msg,
                   struct binder_io *reply)
{
 .....

    switch(txn->code) {
    case SVC_MGR_GET_SERVICE:
    case SVC_MGR_CHECK_SERVICE: //查找
        s = bio_get_string16(msg, &len); //服务名
        //根据名称查找相应服务 
        handle = do_find_service(bs, s, len, txn->sender_euid, txn->sender_pid);
        //【见小节3.1.2】
        bio_put_ref(reply, handle);
        return 0;

    case SVC_MGR_ADD_SERVICE: //注册
        s = bio_get_string16(msg, &len); //服务名
        handle = bio_get_ref(msg); //handle
        allow_isolated = bio_get_uint32(msg) ? 1 : 0;
         //注册指定服务 
        if (do_add_service(bs, s, len, handle, txn->sender_euid,
            allow_isolated, txn->sender_pid))
            return -1;
        break;

    case SVC_MGR_LIST_SERVICES: {  
        uint32_t n = bio_get_uint32(msg);

        if (!svc_can_list(txn->sender_pid)) {
            return -1;
        }
        si = svclist;
        while ((n-- > 0) && si)
            si = si->next;
        if (si) {
            bio_put_string16(reply, si->name);
            return 0;
        }
        return -1;
    }
    default:
        return -1;
    }

    bio_put_uint32(reply, 0);
    return 0;
}

```
#### 2.注册服务
```c
int do_add_service(struct binder_state *bs,
                   const uint16_t *s, size_t len,
                   uint32_t handle, uid_t uid, int allow_isolated,
                   pid_t spid)
{
    struct svcinfo *si;

    if (!handle || (len == 0) || (len > 127))
        return -1;

    //权限检查
    if (!svc_can_register(s, len, spid)) {
        return -1;
    }

    //服务检索
    si = find_svc(s, len);
    if (si) {
        if (si->handle) {
            svcinfo_death(bs, si); //服务已注册时，释放相应的服务
        }
        si->handle = handle;
    } else {
        si = malloc(sizeof(*si) + (len + 1) * sizeof(uint16_t));
        if (!si) {  //内存不足，无法分配足够内存
            return -1;
        }
        si->handle = handle;
        si->len = len;
        memcpy(si->name, s, (len + 1) * sizeof(uint16_t)); //内存拷贝服务信息
        si->name[len] = '\0';
        si->death.func = (void*) svcinfo_death;
        si->death.ptr = si;
        si->allow_isolated = allow_isolated;
        si->next = svclist; // svclist保存所有已注册的服务
        svclist = si;
    }

    //以BC_ACQUIRE命令，handle为目标的信息，通过ioctl发送给binder驱动
    binder_acquire(bs, handle);
    //以BC_REQUEST_DEATH_NOTIFICATION命令的信息，通过ioctl发送给binder驱动，主要用于清理内存等收尾工作
    binder_link_to_death(bs, handle, &si->death);
    return 0;
}
```
注册服务分为以下4部分的工作：

* 权限检查:检查权限是否满足
* 服务检索：根据服务名来查询是否有匹配的服务。
* 释放服务：释放服务，当查询到已存在同名的服务，则先清理该服务信息，再将当前的服务加入到服务列表svclist(头插)
* 通知内核：最后通知binder驱动，完成注册。让驱动完成主要用于清理内存等收尾工作

#### 3.查询服务
```c
uint32_t do_find_service(struct binder_state *bs, const uint16_t *s, size_t len, uid_t uid, pid_t spid)
{
    //查询相应的服务 
    struct svcinfo *si = find_svc(s, len);

    if (!si || !si->handle) {
        return 0;
    }

    if (!si->allow_isolated) {
        uid_t appid = uid % AID_USER;
        //检查该服务是否允许孤立于进程而单独存在
        if (appid >= AID_ISOLATED_START && appid <= AID_ISOLATED_END) {
            return 0;
        }
    }

    //服务是否满足查询条件
    if (!svc_can_find(s, len, spid)) {
        return 0;
    }
    return si->handle;
}
```
在这里查询到目标服务，并返回对应的handle，查询成功后，在调用 bio_put_ref(reply, handle)方法,将handle封装到reply。


**bio_put_ref**
```c
void bio_put_ref(struct binder_io *bio, uint32_t handle) {
    struct flat_binder_object *obj;

    if (handle)//如果handle==0 即查找的是ServiceManager
        obj = bio_alloc_obj(bio); //见下
    else
        obj = bio_alloc(bio, sizeof(*obj));//见下

    if (!obj)
        return;

    obj->flags = 0x7f | FLAT_BINDER_FLAG_ACCEPTS_FDS;
    obj->type = BINDER_TYPE_HANDLE; //返回的是HANDLE类型
    obj->handle = handle;
    obj->cookie = 0;
}
```

**bio_alloc_obj**
```c
static struct flat_binder_object *bio_alloc_obj(struct binder_io *bio)
{
    struct flat_binder_object *obj;
    obj = bio_alloc(bio, sizeof(*obj));//见下

    if (obj && bio->offs_avail) {
        bio->offs_avail--;
        *bio->offs++ = ((char*) obj) - ((char*) bio->data0);
        return obj;
    }
    bio->flags |= BIO_F_OVERFLOW;
    return NULL;
}
```
**bio_alloc**
```c
static void *bio_alloc(struct binder_io *bio, size_t size)
{
    size = (size + 3) & (~3);
    if (size > bio->data_avail) {
        bio->flags |= BIO_F_OVERFLOW;
        return NULL;
    } else {
        void *ptr = bio->data;
        bio->data += size;
        bio->data_avail -= size;
        return ptr;
    }
}
```

#### 4. 返回reply结果
在查询成功后，最终通过调用binder_send_reply将reply(包含获取服务的结果)返回到binder内核中。
```c
void binder_send_reply(struct binder_state *bs, struct binder_io *reply, binder_uintptr_t buffer_to_free, int status) {
    struct {
        uint32_t cmd_free;
        binder_uintptr_t buffer;
        uint32_t cmd_reply;
        struct binder_transaction_data txn;
    } __attribute__((packed)) data;

    data.cmd_free = BC_FREE_BUFFER; //free buffer命令
    data.buffer = buffer_to_free;
    data.cmd_reply = BC_REPLY; // reply命令
    data.txn.target.ptr = 0;
    data.txn.cookie = 0;
    data.txn.code = 0;
    if (status) {
        data.txn.flags = TF_STATUS_CODE;
        data.txn.data_size = sizeof(int);
        data.txn.offsets_size = 0;
        data.txn.data.ptr.buffer = (uintptr_t)&status;
        data.txn.data.ptr.offsets = 0;
    } else {
        data.txn.flags = 0;
        data.txn.data_size = reply->data - reply->data0;
        data.txn.offsets_size = ((char*) reply->offs) - ((char*) reply->offs0);
        data.txn.data.ptr.buffer = (uintptr_t)reply->data0;
        data.txn.data.ptr.offsets = (uintptr_t)reply->offs0;
    }
    //向Binder驱动通信
    binder_write(bs, &data, sizeof(data));
}
```
在binder_send_reply，将BC_FREE_BUFFER和BC_REPLY命令协议发送给Binder驱动，在向客户端发送reply. 其中data的数据区中保存的是TYPE为HANDLE.

之后就是上一节中，binder_transaction中获取服务那一步。
### 六.总结
在进行获取服务和注册服务时，首先要获取BpServiceManager，BpServiceManager继承接口IServiceManager，并且含有binder内核中ServiceManager的binder(handle = 0)。

在获取BpServiceManager时：
* 首先获取ProcessState对象，并在其中打开binder驱动，调用mmap分配一块虚拟内存空间。
* 获取bpBinder时，就是ServiceManager的binder，
* C++中的宏函数创建bpServiceManager对象。

获取BpServiceManager之后，就可以调用对应的注册服务和获取服务方法，即addService和getService。之后都会去调用BpServiceManager中的BpBinadr的transact方法。

在BpBinder方法中，去调用了IPCThreadState的transact方法。在这个方法中，，首先会检查数据是否有误，通过ioctl和Binder内核进行数据传输。并等待响应。


之后就是内核对注册获取服务的处理。

在binder内核中，最终调用binder内核的binder_transaction方法。在这其中，对于注册服务和获取服务有不同的处理。  

对于注册服务：在服务所在的进程中创建该进程对应的binder实体,在ServiceManager中创建binder引用。
最后向servicemanager的binder_proc->todo添加BINDER_WORK_TRANSACTION事务。交给ServiceManager处理。

在ServiceManager中，经过了如下过程，权限检查，服务检索，释放同名服务，添加新服务，通知内核。


对于获取服务,binder内核会先将其发往ServiceManager中，在ServiceManager中，查询完成后，将查询的handle封装到reply，并将其他ype改为BINDER_TYPE_HANDLE。在发送给内核。

之后也是在binder_transaction中进行如下处理：
* 当请求服务的进程与服务属于不同的进程，则为请求服务所在的进程创建一个binder引用，指向服务进程中的binder_nodr
* 请求服务的进程与服务属于同一进程是。不在创建新对象，而是引用计数+1.并修改type为BINDER_TYPE_BINDER或BINDER_TYPE_WEAK_BINDER。

### 七.参考资料
[Binder系列3—启动ServiceManager](http://gityuan.com/2015/11/07/binder-start-sm//)  
[Binder系列4—获取ServiceManager](http://gityuan.com/2015/11/08/binder-get-sm/)  
[Binder系列5—注册服务(addService)](http://gityuan.com/2015/11/14/binder-add-service/)  
[Binder系列6—获取服务(getService)](http://gityuan.com/2015/11/15/binder-get-service/)
