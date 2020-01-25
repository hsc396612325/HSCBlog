---
title: "Android之IPC4————Binder1 概述与Bander驱动"
date: 2019-05-04T22:40:54+08:00
draft: false
categories: ["Android","Android之IPC"]
tags: ["Android","IPC"]
---

### 一.概述

最近才看AndroidIPC中，Binder一直是绕不过的坎，他是AndroidIPC很重要的一种方式，在Android系统中也有着举足轻重的作用。在之前的博客里，特别是AIDL中，我们只是说了AIDL实际上是实现的binder的接口。也在文章的最后简单说了一下，binder是如何进行数据通信的。但是由于Binder的封装，我还是没有发现，binder是如何做的跨进程通信的。

在这段时间里，我也是翻看了许多资料，也查看了许多博客。但是，多数博客，要不然讲的只是Frameworks层，要不然只是云里雾里长篇大论，要不然是很简单的描述了一下大体框架。

不过，后来发现一位大神的博客，跟着他的思考路看源码，从Driver层看到native层，再从native看到Frameworks层，看的脑袋很晕，但是收获也很大。所以想将看的过程记录下来，做一个学习笔记。

[Binder系列—开篇](http://gityuan.com/2015/10/31/binder-prepare/)

### 二.储备知识
在正式讲之前，先简单介绍一些基础知识

#### 1.进程空间的划分
![进程空间](/image/Android_IPC/2_0.png)
每个Android的进程中，都只能运行在自己进程所拥有的虚拟地址空间，对应一个4GB的虚拟地址空间，其中3GB是用户空间，1GB是内核空间。当然两者的大小时可以进程跳转的。

用户空间：不同进程之间无法共享  
内核空间: 不同进程之间可以共享

#### 2.进程隔离和跨进程通信
进程隔离： 为了保证安全性和独立性，一个进程不能直接操作和访问另一个进程  
进程间通信： 不同进程之间传递数据

#### 3.Android的框架
让我们来看一看，Android的整体框架
![android框架](/image/Android_IPC/2_1.png)

从下往上依次为：

* 内核层:Linux内核和各类硬件设备的驱动，BInderIPC驱动也就是在这一层
* 硬件抽象层：封装内核层的硬件驱动，提供系统服务层统一的硬件接口
* 系统层:提供核心服务，并且提供可供「应用程序框架层」调用的接口
* BinderIPC层：作为系统服务层与应用程序框架的IPC桥梁，互相传递接口调用的数据，实现跨进层的停下
* 应用程序框架层：这一层可以理解为 Android SDK，提供四大组件，View 绘制体系等平时开发中用到的基础部件

在上面的层次里，内核层与硬件抽象层均使用C/C++实现，系统服务是以Java实现，硬件层抽象编译为so文件，以jni的形式提供给系统服务层使用，系统服务层中的服务随系统的启动而启动，这些服务提供给手机诸如，短信接收，电话的接听，Activity的管理等等功能。每一个服务都运行在一个独立进程的Dalvik虚拟机中，那么问题来了，开发者的app运行在一个新的进程空间，如果调用系统服务层中的接口呢？答案就是ipc，而Android中大多数的ipc都是通过Binder实现的。

### 三.Binder概述

#### 1.Binder是什么
Binder中文意思为粘合剂，意思是粘合了两个不同的进程

而在不同的语境下，Binder有不同的含义。

* 从机制，模型来说,Binder是指Android中实现Ipc的一种方式。
* 从模型的结构中来说,Binder来说是一种虚拟的物理层设备，即Binder驱动。
* 从代码的角度来说，Binder是一个类，实现类IBInder接口。

#### 2.Binder的优势
Android是基于linux的操作系统，而操作系统中已经有了多种IPC机制，为什么还要Binder机制?

看看Linux中现有的IPC机制：

* 管道:在创建是分配一个page大小的内存，缓存区比较有限
* 消息队列:信息复制两次，有额外的CPU消耗，不适合频繁或者信息量大的通信
* 共享内存:无需复制，共享缓冲区直接付附加到进程虚拟地址空间，速度快；但进程间的同步问题操作系统无法实现，必须各进程利用同步工具解决；
* socket：作为更通用的接口，传输效率低，主要用于不通机器或跨网络的通信；

多个角度说明为什么使用Binder：

* 从性能上来说：Binder数据拷贝只需要一次，而管道，消息内存，Socket都需要两次，共享内存不需要。从性能上来说，Binder性能仅次于共享内存。
* 从稳定性来说，Binder基于c/s架构，架构清晰，稳定性较好
* 从安全性来说，Binder中，客户端和服务端通信时，会根据UID/PID进行一次安全检查
* 从语言来说，linux中的机制都是基于c，也就是说面向过程。而android是基于Java,binder也正好是符合面向对象的思想。

#### 3.Binder原理
binder通信采用C/S架构，从组件的角度来说，Binder分为Client，Service，ServiceManager，binder驱动。构架图如下：
![binder](/image/Android_IPC/2_2.png)

图中处理客户端和服务端外，还有两个角色，即ServiceManager和BInder驱动。下面分别简单介绍一下。

* ServiceManager:此处的Service并非指framework层的，而是指Native层的。它是整个Binder通信机制的大管家。它的作用就是给服务端提供注册服务，给客户端提供获取服务的功能。
* Binder驱动，binder驱动是一种虚拟字符设备，没有直接操作硬件。它的作用是连接服务端进程，客户端进程，ServiceManager的桥梁。它提供了4个方法。驱动设备的初始化(binder_init)，打开 (binder_open)，映射(binder_mmap)，数据操作(binder_ioctl)

图中出现了IPC时需要的三步，即：

* 注册服务:Server进程要先注册Service到ServiceManager。该过程：Server是客户端，ServiceManager是服务端。
* 获取服务:Client进程使用某个Service前，须先向ServiceManager中获取相应的Service。该过程：Client是客户端，ServiceManager是服务端。
* 使用服务：Client根据得到的Service信息建立与Service所在的Server进程通信的通路，然后就可以直接与Service交互。该过程：client是客户端，server是服务端。


图中Client，Service，ServiceManager之间交互是虚线表示，但他们都处于不同的进程，所以他们之间并不是真正的交互，而是通过与Binder驱动进行交互，从而实现IPC通信方式。
#### 4.Binder框架
上面的图主要是native层Binder的框架，下面的图是Binder在android中整体框架
![在这里插入图片描述](/image/Android_IPC/2_3.png)
* 图中红色部分表示整个framwork层binder框架相关组件
* 蓝色组件表示Native层Binder架构相关组件；
* 上层framework层的Binder逻辑是建立在Native层架构基础之上的，核心逻辑都是交予Native层方法来处理。

Binder涉及的类
[外链图片转存失败,源站可能有防盗链机制,建议将图片保存下来直接上传(img-k5ZmyuPj-1579438039538)(http://gityuan.com/images/binder/java_binder_framework.jpg)]
#### 5. C/S模式
BpBinder(客户端)和BBinder(服务端)都是Android中Binder通信相关的代表，它们都从IBinder类中派生而来，关系图如下：

![image](/image/Android_IPC/2_4.png)

* 客户端：BpBinder.transact()来发送事物请求
* 服务端：BBinder.onTransact()会接收到相应事务。

### 四.Binder驱动
#### 1.概述
Binder驱动是Android专用的，但底层的驱动框架和Linux驱动一样，binder驱动在以misc设备进行注册，作为虚拟字符设备，没有直接操作硬件，只是对设备内存的处理。主要操作有：

* 通过init()创建/dev/binder设备节点
* 通过open()获取Binder1驱动文件描述符
* 通过mmap()在内核上分配一块内存，用于存放数据
* 通过ioctl()将IPC数据作为参数传递给binder驱动

#### 2.系统调用
用户态程序调用Kernel层驱动是需要陷入内核态，进行系统调用(syscall),比如调用Binder驱动方法调用链为：open-> __open() -> binder_open()。 open()为用户空间的方法，__open()便是系统调用中相应的处理方法，通过查找，对应调用到内核binder驱动的binder_open()方法，至于其他的从用户态陷入内核态的流程也基本一致。

简单来说，当用户空间调用open()方法，最终会调用binder驱动的binder_open()方法，mmap()/ioctl都是如此。


#### 3.binder_open
binder_init的主要工作就是注册misc设备。并没有什么可说的，我们就直接从第二个方法来看。

binder_open()作用是打开binder驱动，并进行如下过程：

* 创建binder_proc，将当前进程的信息保存保存在binder_porc对象总，该对象管理IPC所需的各种信息并具有其他结构体的根结构体，在把binder_proc对象保存到文件指针filp，以及把binder_proc加入到全局链表binder_procs。
* binder_proc结构体中包含了进程节点，binder实体/引用/线程所组成红黑树的根节点，内存信息，线程信息等等

#### 3. binder_mmap
主要功能：首先在内核虚拟地址空间中，申请一块与用户虚拟内存大小相同的内存。在申请一个page大小的物理内存，再讲同一块物理内存分别映射到内核虚拟地址空间个用户虚拟内存空间，从而实现了用户空间的Buffer和内核空间的Buffer同步操作的功能。最后创建一块Binder_buffer对象，并放入当前binder_proc的proc->buffers链表。

![内存机制](/image/Android_IPC/2_5.png)

上图就是，使用mmap后的内存机制，虚拟进程地址空间(vm_area_struct))和虚拟内核地址空间(vm_struct)都映射到同一块物理内存空间。当客户端和服务端发送数据是，客户端先从自己的进程空间吧ipc通信数据复制到内核空间，而Server端作为数据接受端与内核共享数据，所以不需要在拷贝数据，而是通过内存地址的偏移量，即可获得内存地址。整个过程只发送一次内存复制。 

比较关注的一个点就在，在这其中，空闲的内存块和已用的内存块都是用红黑树记录的。

#### 4.binder_ioctl
binder_ioctl()函数负责在两个进程间收发IPC数据和IPC reply数据

> ioctl(文件描述符，ioctl命令，数据类型)

* 文件描述符：是通过open()方法打开的binder内核后的返回层。
* ioctl命令

header 1 | header 2

row 1 col 1 | row 1 col 2
row 2 col 1 | row 2 col 2


ioctl命令 |	数据类型 |	操作| 使用场景|
---|---|---|---
BINDER_WRITE_READ |	struct binder_write_read |	收发Binder IPC数据|binder读写交互场景
BINDER_SET_MAX_THREADS |__u32|		设置Binder线程最大个数|	初始化ProcessState对象，初始化ProcessState对象
BINDER_SET_CONTEXT_MGR |__s32 |	设置Service Manager节点|servicemanager进程成为上下文管理
BINDER_THREAD_EXIT |__s32|	 释放Binder线程
BINDER_VERSION|	struct binder_version |	获取Binder版本信息|初始化ProcessState
BINDER_SET_IDLE_TIMEOUT |__s64 |	没有使用
BINDER_SET_IDLE_PRIORITY|__s32 |	没有使用



这一块，简单介绍了binder内核，包括binder内核提供的四个方法和binder是什么。更详细的内容，深入到源码层的分析可以查看文章：[Binder系列1—Binder Driver初探](http://gityuan.com/2015/11/01/binder-driver/)
### 五.启动ServiceManager
接下来来看binder机制另一个很重要的角色，ServiceManager是客户端和服务端沟通的桥梁。首先看看ServiceManager的启动。

ServiceManager是通过init进程通过解析init.rc文件，而创建的，所对应的可执行程序/system/bin/servicemanager，所对应的源文件是service_manager.c，进程名为/system/bin/servicemanager。

#### 1.启动过程
启动Service Manager的入口函数是service_manager.c中的main()方法，代码如下：
```c
int main(int argc, char **argv) {
    struct binder_state *bs;
    //打开binder驱动，申请128k字节大小的内存空间 
    bs = binder_open(128*1024);
    ...

    //成为上下文管理者 
    if (binder_become_context_manager(bs)) {
        return -1;
    }

    selinux_enabled = is_selinux_enabled(); //selinux权限是否使能
    sehandle = selinux_android_service_context_handle();
    selinux_status_open(true);

    if (selinux_enabled > 0) {
        if (sehandle == NULL) {  
            abort(); //无法获取sehandle
        }
        if (getcon(&service_manager_context) != 0) {
            abort(); //无法获取service_manager上下文
        }
    }
    ...

    //进入无限循环，处理client端发来的请求 
    binder_loop(bs, svcmgr_handler);
    return 0;
}
```
由上面的代码可以看到，启动过程主要涉及以下几个阶段：

* 打开binder驱动 binder_open
* 注册成为binder服务的大管家：binder_become_context_manager；
* 进入死循环，处理client端发来的请求：binder_loop

我们一点点来看

#### 2.打开binder驱动
```c
struct binder_state *binder_open(size_t mapsize)
{
    struct binder_state *bs;【见小节2.2.1】
    struct binder_version vers;

    bs = malloc(sizeof(*bs));
    if (!bs) {
        errno = ENOMEM;
        return NULL;
    }

    //通过系统调用陷入内核，打开Binder设备驱动
    bs->fd = open("/dev/binder", O_RDWR);
    if (bs->fd < 0) {
        goto fail_open; // 无法打开binder设备
    }

     //通过系统调用，ioctl获取binder版本信息
    if ((ioctl(bs->fd, BINDER_VERSION, &vers) == -1) ||
        (vers.protocol_version != BINDER_CURRENT_PROTOCOL_VERSION)) {
        goto fail_open; //内核空间与用户空间的binder不是同一版本
    }

    bs->mapsize = mapsize;
    //通过系统调用，mmap内存映射，mmap必须是page的整数倍
    bs->mapped = mmap(NULL, mapsize, PROT_READ, MAP_PRIVATE, bs->fd, 0);
    if (bs->mapped == MAP_FAILED) {
        goto fail_map; // binder设备内存无法映射
    }

    return bs;

fail_map:
    close(bs->fd);
fail_open:
    free(bs);
    return NULL;
}
```
打开binder驱动的先关操作：

先调用open()打开binder设备，open即上一节所说的binder内核提供的方法之一，最终会调用binder内核中的binder_open()，其方法作用间上一节.

之后调用mmap()方法进行内存映射。

#### 3.注册成为binder服务的大管家
```java
int binder_become_context_manager(struct binder_state *bs) {
    //通过ioctl，传递BINDER_SET_CONTEXT_MGR指令【见小节2.3.1】
    return ioctl(bs->fd, BINDER_SET_CONTEXT_MGR, 0);
}
```
在这里面用过调用ioctl方法，发送 BINDER_SET_CONTEXT_MGR，最终经过系统调用，进入binder驱动层的binder_ioctl()方法.

```c
static int binder_ioctl_set_ctx_mgr(struct file *filp)
{
    int ret = 0;
    struct binder_proc *proc = filp->private_data;
    kuid_t curr_euid = current_euid();

    //保证只创建一次mgr_node对象
    if (binder_context_mgr_node != NULL) {
        ret = -EBUSY; 
        goto out;
    }

    if (uid_valid(binder_context_mgr_uid)) {
        ...
    } else {
        //设置当前线程euid作为Service Manager的uid
        binder_context_mgr_uid = curr_euid;
    }

    //创建ServiceManager实体
    binder_context_mgr_node = binder_new_node(proc, 0, 0);
    ...
    binder_context_mgr_node->local_weak_refs++;
    binder_context_mgr_node->local_strong_refs++;
    binder_context_mgr_node->has_strong_ref = 1;
    binder_context_mgr_node->has_weak_ref = 1;
out:
    return ret;
}
```

创建一个ServiceManager实体
```c
static struct binder_node *binder_new_node(struct binder_proc *proc,
                       binder_uintptr_t ptr,
                       binder_uintptr_t cookie)
{
    struct rb_node **p = &proc->nodes.rb_node;
    struct rb_node *parent = NULL;
    struct binder_node *node;
    //首次进来为空
    while (*p) {
        parent = *p;
        node = rb_entry(parent, struct binder_node, rb_node);

        if (ptr < node->ptr)
            p = &(*p)->rb_left;
        else if (ptr > node->ptr)
            p = &(*p)->rb_right;
        else
            return NULL;
    }

    //给新创建的binder_node 分配内核空间
    node = kzalloc(sizeof(*node), GFP_KERNEL);
    if (node == NULL)
        return NULL;
    binder_stats_created(BINDER_STAT_NODE);
    
 
    rb_link_node(&node->rb_node, parent, p);
    rb_insert_color(&node->rb_node, &proc->nodes);
    node->debug_id = ++binder_last_id;
    
    node->proc = proc; //将open操作中创建的的proc赋值
    node->ptr = ptr; //指向用户空间binder_node的指针
    node->cookie = cookie;
    node->work.type = BINDER_WORK_NODE; //设置binder_work的type
    INIT_LIST_HEAD(&node->work.entry);
    INIT_LIST_HEAD(&node->async_todo);
    return node;
}
```

在这里面，在binder中创建ServiceManager实体()。并在创建是，将open操作中创建的proc，存入ServiceManager的proc中。

#### 4.进入死循环中
```c
void binder_loop(struct binder_state *bs, binder_handler func) {
    int res;
    struct binder_write_read bwr;
    uint32_t readbuf[32];

    bwr.write_size = 0;
    bwr.write_consumed = 0;
    bwr.write_buffer = 0;

    readbuf[0] = BC_ENTER_LOOPER;
    //将BC_ENTER_LOOPER命令发送给binder驱动，让Service Manager进入循环 
    binder_write(bs, readbuf, sizeof(uint32_t));

    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
        bwr.read_buffer = (uintptr_t) readbuf;

        //通过ioctl向binder驱动发起读写请求
        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr); //进入循环，不断地binder读写过程
        if (res < 0) {
            break;
        }

        // 解析binder信息 
        res = binder_parse(bs, 0, (uintptr_t) readbuf, bwr.read_consumed, func);
        if (res == 0) {
            break;
        }
        if (res < 0) {
            break;
        }
    }
}
```


解析Binder信息
```c
...
//初始化reply
     bio_init(&reply, rdata, sizeof(rdata), 4);
     
//从txn解析binder_io
      bio_init_from_txn(&msg, txn);
      
//调用Service_manager中的svcmgr_handler，进行它的工作
res = func(bs, txn, &msg, &reply);

binder_send_reply(bs, &reply, txn->data.ptr.buffer, res);
...
```

根据binder驱动返回的信息进行相应的操作
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

总结：在这个循环里，ServiceManager通过ioctl向binder驱动发起读写请求,根据请求返回的数据，去进行相应的注册服务和查询服务。

### 六.总结
本篇文章中，先简单介绍了一些操作系统中关于跨进程通信的基础知识，之后介绍了binder的优势以及binder的框架。

然后介绍了binder内核，主要介绍了binder内核提供的4个方法
* init()注册misc设备
* open()打开binder驱动。并创建binder_proc,并保存在全局链表中
* mmap()在内存中分配一块内存，用于存放数据，实现是采用的是内存映射机制，将内核和Service映射在同一块物理地址中
* ioctl()负责在两个进程间传递转发ipc数据和回复数据

之后介绍了ServiceManager的启动，ServiceManager是通过init进程加载init.rc文件而创建的，创建步骤如下：
* 首先调用open()打开binder驱动，并调用mmap()申请128k字节大小的内存空间。
* 之后使用ioctl发送BINDER_SET_CONTEXT_MGR，成为Service的管家，在这里会在binder内核中创建一个ServiceManager实体，该实体是内核全局变量，并把open操作中创建的proc，放入该实体中。
* 最后会启动一个死循环，在这个循环中，ServiceManager通过ioctl不断从binder内核中读写数据，并根据信息进行相应的操作，即注册服务，获取服务。


之后的文章：
* BinderNative层分析
* Binderframework层的分析
* Binder通信过程
* Binder线程池
* Binder的使用
* Binder总结

### 七.参考资料
[Binder系列—开篇](http://gityuan.com/2015/10/31/binder-prepare/)  
[Binder系列3—启动ServiceManager](http://gityuan.com/2015/ )  
[Android跨进程通信：图文详解 Binder机制 原理](https://blog.csdn.net/carson_ho/article/details/73560642)  
[轻松理解 Android Binder，只需要读这一篇](https://www.jianshu.com/p/bdef9e3178c9)
