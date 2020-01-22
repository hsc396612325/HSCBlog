# Android之IPC2————AIDL

@[toc]
### 一.AIDL概述

在上一篇博客中，我们讨论Service绑定时，所用的三种方法，即扩展的binder类，Messenger类，还有AIDL，上一章博客中当时我们只是简单的介绍了一下。在这里我们就详细的来看一看。


#### 1.AIDL是什么
AIDL即Android接口定义语言，是IDL语言的一种。主要用来定义跨进程通信时都让双方都认可的编程接口。

> IDL是Interface description language的缩写，指接口描述语言.IDL通常用于远程调用软件。在这种情况下，一般是由远程客户终端调用不同操作系统上的对象组件，并且这些对象组件可能是由不同计算机语言编写的。IDL建立起了两个不同操作系统间通信的桥梁。 

#### 2.使用场景
在Android中，一个进程通常无法访问另一个进程的内存，所以进程需要将其对象分解成操作系统可以识别的原语，并将对象编组成可以跨界.所以在Android中，它常常被用来进行跨进程通信。

#### 3.一些语法
在使用AIDL语言时，需要创建一个.aidl文件，此时AndroidSDK工具都会生成一个.aidl文件的IBinder接口，并且其报存在gen/目录中，Service视情况实现IBinder接口。然后将客户端与Service进行绑定，此时就可以调用IBindr的方法来执行IPC。

创建AIDL时，可以通过可带参数和返回值的一个或多个方法来声明接口。参数和返回值可以时任意类型，甚至可以是其他AIDL生成的接口

默认情况下，AIDL支持下列数据类似：

* JAVA中所有原语类型(如int,long,char,boolean等等)
* String
* CharSequence
* List：List中所有元素都必须是以上列表支持的数据类型，或者其他AIDL生成的接口或者声明的可打包类型。
* Map：同List一样，他也要求所有元素都必须是以上列表支持的数据类型，或者其他AIDL生成的接口或者声明的可打包类型。

对于不是默认数据的类型，应该使其实现Parcelable接口，并编写对应的AIDL文件。

定义接口时，注意：
* 方法可以带零个或者多个参数，返回值或者NULl
* 所有原语参数都需要指示数据走向方向标记，可以是in，out或者inout，原语默认是in,慎用inout参数，它会导致系统开销非常大。
* aidl 文件中包括的所有代码注释都包含在生成的 IBinder 接口中（import 和 package 语句之前的注释除外）
* 只客户端调用其中的方法，不支持调用其中的AIDL 中的静态字段。

### 二.AIDL实现跨进程通信
将一个Book类，在不同进程的客户端和服务中进行传递。

因为Book类并不默认类型，所以首先让它实现Parcelable接口(序列化)

关于序列化的问题，下一篇博客中进行分析。

#### 1.Book实现 Parcelable 接口
创建一个Book类，建立getter和setter
```java
public class Book {

    private String name;
    private int price;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getPrice() {
        return price;
    }

    public void setPrice(int price) {
        this.price = price;
    }

    @Override
    public String toString() {
        return "书名:"+name +",价格"+price;
    }

    public Book() {
    }

}

```
让其继承 Parcelable 接口，并根据AS的错误提醒，自动补全。或者自己手动补全。
```java
public class Book implements Parcelable {

    private String name;
    private int price;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getPrice() {
        return price;
    }

    public void setPrice(int price) {
        this.price = price;
    }

    @Override
    public String toString() {
        return "书名:"+name +",价格"+price;
    }

    public Book() {
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeString(name);
        dest.writeInt(price);
    }

    protected Book(Parcel in) {
        name = in.readString();
        price = in.readInt();
    }

    public static final Creator<Book> CREATOR = new Creator<Book>() {
        @Override
        public Book createFromParcel(Parcel in) {
            return new Book(in);
        }

        @Override
        public Book[] newArray(int size) {
            return new Book[size];
        }
    };
}

```

#### 2.生成AIDL文件
前面我们说过，因为Book类不是默认类型，所以也要生成关于Book类的AIDL文件。

鼠标移到app上面去，点击右键，然后 new->AIDL->AIDL File，按下鼠标左键就会弹出一个框提示生成AIDL文件了。此时在java包层级下，多了一个aidl文件夹，在里面就可以新建aidl文件。

Book.aidl文件
```java
// Book.aidl
//这个文件的作用是引入了一个序列化对象 Book 供其他的AIDL文件使用
//注意：Book.aidl与Book.java的包名应当是一样的

package com.heshucheng.servicedemo;

//注意parcelable是小写
parcelable Book;

```

BookManager.aidl文件
```java
// BookManager.aidl
//作用是定义方法接口

package com.heshucheng.servicedemo;
//导入所需要使用的非默认支持数据类型的包
import com.heshucheng.servicedemo.Book;
// Declare any non-default types here with import statements

interface  BookManager{

 //所有的返回值前都不需要加任何东西，不管是什么数据类型
   List<Book> getBooks();
   //传参时除了Java基本类型以及String，CharSequence之外的类型
   //都需要在前面加上定向tag，具体加什么量需而定
   void addBook(in Book book);

}

```
在BookManager中，定义了两个接口，一个活的书的list，一个是添加书。


#### 3.在Service中实现相关的接口
在AIDL的使用场景中经常在多次线程的情景下被调用，所以要考虑线程安全问题。同时完成请求的时间不止几毫秒，尽量避免在主线程中调用相关的接口。


```java
public class AIDLService extends Service {

    private static final String TAG = "AIDLService";

    //包含Book对象的List
    private List<Book> mBooks = new ArrayList<>();

    //由AIDL文件生成的BookManager
    private final BookManager.Stub mBookManager = new BookManager.Stub() {
        @Override
        public List<Book> getBooks() throws RemoteException { //实现对应的接口
            synchronized (this) {  //确保线程安全
                Log.w(TAG, "getBooks: " + mBooks.toString());
                if (mBooks != null){
                    return mBooks;
                }
                return new ArrayList<>();
            }

        }

        @Override
        public void addBook(Book book) throws RemoteException {//实现对应的接口
            synchronized (this){ //确保线程安全
                if (mBooks == null){
                    mBooks = new ArrayList<>();
                }

                if (book == null){
                    Log.w(TAG, "addBook: " );
                    book = new Book();
                }

                //尝试修改book的参数，主要是为了观察其客户端的反馈
                book.setPrice(2333);
                if (!mBooks.contains(book)){
                    mBooks.add(book);
                }

                //打印mBooks列表，观察客户端传过来的值
                Log.w(TAG, "addBook: "+mBooks.toString());
            }
        }
    };

    public AIDLService() {

    }

    @Override
    public void onCreate() {
        super.onCreate();
        Book book = new Book();
        book.setName("Android艺术开发探索");
        book.setPrice(28);
        mBooks.add(book);
    }

    @Override
    public IBinder onBind(Intent intent) {
        Log.w(TAG, "onBind: " +intent.toString());
        return mBookManager;
    }
}

```

在Service中，实现相关的接口，同时确保线程安全，并在onBind类中将对于的BookManager传第过去

#### 4.在客户端中调用相关的接口
注意，如果接口完成的时间不止几毫秒，尽量避免在主线程中调用相关的接口。
```java
public class AIDLActivity extends AppCompatActivity {

    private static final String TAG = "AIDLActivity";
    //由AIDL文件生成的Java类
    private BookManager mBookManager = null;

    //标志当前与服务端连接状况的情况
    private boolean mBound = false;

    private List<Book> mBooks;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_aidl);
    }

    //按钮的点击事件
    public void addBook(View view){
        if(!mBound){
            attemptToBindService();
            Toast.makeText(this,"当前与服务端处于未连接状态，正在尝试重连，请稍后再试", Toast.LENGTH_SHORT).show();
            return;
        }

        if (mBookManager == null)
            return;

        Book book = new Book();
        book.setName("App研发录");
        book.setPrice(30);

        try {
            mBookManager.addBook(book); //调用对应的接口
            Log.w(TAG, "addBook: "+book.toString());
        }catch (RemoteException e){
            e.printStackTrace();
        }
    }

    /**
     * 尝试与服务端建立连接
     */
    private void attemptToBindService(){
        Intent intent = new  Intent();

        intent.setAction("com.heshucheng.aidl");
        intent.setPackage("com.heshucheng.servicedemo");
        bindService(intent,mServiceConnection, Context.BIND_AUTO_CREATE);
    }

    @Override
    protected void onStart() {
        super.onStart();
        if(!mBound){
            attemptToBindService();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if(mBound){
            unbindService( mServiceConnection);
            mBound =false;
        }
    }

    //绑定接口
    private ServiceConnection mServiceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            Log.w(TAG, "绑定成功" );
            mBookManager = BookManager.Stub.asInterface(service);
            mBound = true;

            if (mBookManager !=null){
                try {
                    mBooks = mBookManager.getBooks();//调用接口
                    Log.w(TAG,"获取成功"+mBooks.toString());
                }catch (RemoteException e){
                    e.printStackTrace();
                }
            }
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            Log.e(TAG, "连接中断");
            mBound = false;
        }
    };
}

```
在Activity中调用对应的接口。

#### 5.运行结果
客户端
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181101225020582.png)

服务端
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181101225039473.png)


### 三.AIDL生成Binder类分析
在上面的代码中，我们发现，在客户端和服务端中都没有出现aidl文件，但依然通过BookManager完成相应的工作，而它就是aidl生成的java文件，它的完整路径在app->build->generated->source->aidl->debug->com->包名->BookManager.java

在上文中，我们在Service中实现相应的接口，并将其传递给客户端，在客户端中直接调用相关的接口。好像并没有关于进程方面的操作，但两个不同进程的相互调用，肯定需要进行IPC,那这一部分在哪实现的？

答案就是在BookManager.java中。

#### 1.asInterface
我们在获得BookManager类时，是通过这个语句
```java
 mBookManager = BookManager.Stub.asInterface(service);
```
通过asIbterface获得BookManager。我们进入asInterface方法中。
```java
         /**
         * Cast an IBinder object into an com.heshucheng.servicedemo.BookManager interface,
         * generating a proxy if needed.
         *将IBinder对象转换为BookManager接口，根据需要生成代理。
         */
        public static com.heshucheng.servicedemo.BookManager asInterface(android.os.IBinder obj) {
            //判断是否为空
            if ((obj == null)) {
                return null;
            }

            //搜索本地是否有可用对象，如果有就将其返回
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof com.heshucheng.servicedemo.BookManager))) {
                return ((com.heshucheng.servicedemo.BookManager) iin);
            }

            //如果没有，就新建一个
            return new com.heshucheng.servicedemo.BookManager.Stub.Proxy(obj);
        }
```
在上面的代码中，首先先进行了判空，然后调用了 queryLocalInterface() 方法，这个方法是 IBinder 接口里面的一个方法，它具体的源码涉及到IBinder相关内容，我们暂且不去深究。只说明它的作用，它就是去本地搜索是否有可以的对象

当本地没有BookManager对象时。会去通过Proxy来获得一个BookManager对象。让我们继续来看Proxy中的源码
#### 2.proxy
```java
        private static class Proxy implements com.heshucheng.servicedemo.BookManager {
            private android.os.IBinder mRemote;

            Proxy(android.os.IBinder remote) {
                mRemote = remote;
            }

            @Override
            public android.os.IBinder asBinder() {
                return mRemote;
            }

            public java.lang.String getInterfaceDescriptor() {
                return DESCRIPTOR;
            }

            @Override
            public java.util.List<com.heshucheng.servicedemo.Book> getBooks() throws android.os.RemoteException {
                //_data存心客户端流向服务的数据流
                //_reply存储服务流向客户端的数据流
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                java.util.List<com.heshucheng.servicedemo.Book> _result;
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);

                    //调用transact() 方法将方法id和两个 Parcel 容器传过去Service
                    mRemote.transact(Stub.TRANSACTION_getBooks, _data, _reply, 0);
                    _reply.readException();
                    //从_reply取出结果
                    _result = _reply.createTypedArrayList(com.heshucheng.servicedemo.Book.CREATOR);
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }

            @Override
            public void addBook(com.heshucheng.servicedemo.Book book) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if ((book != null)) {
                        //book存入
                        _data.writeInt(1);
                        book.writeToParcel(_data, 0);
                    } else {
                        _data.writeInt(0);
                    }
                    //调用transact() 方法将方法id和两个 Parcel 容器传给Service
                    mRemote.transact(Stub.TRANSACTION_addBook, _data, _reply, 0);
                    _reply.readException();
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
            }
        }

        static final int TRANSACTION_getBooks = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
        static final int TRANSACTION_addBook = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
    }
```
说明：
* 关于 Parcel ：简单的来说，Parcel 是一个用来存放和读取数据的容器。我们可以用它来进行客户端和服务端之间的数据传输，当然，它能传输的只能是可序列化的数据。具体 Parcel 的使用方法和相关原理可以参见这篇文章[Android中Parcel的分析以及使用](https://blog.csdn.net/qinjuning/article/details/6785517)
* 关于 transact() 方法：这是客户端和服务器端通信的核心方法。调用这个方法之后，客户端会挂起当前线程，等待服务端执行完先关任务后通知并接受返回的 _reply 数据流。
* transact()第一个参数，是方法ID，这个是客户端和服务器端约定好的给方法特殊编码，彼此一一对应，在AIDL文件转化为java文件的时候，系统会自动给AIDL每一个方法自动分配一个方法ID
* transact()第四个参数是一个int值，他的作用是设置IPC的模式，为0表示数据可以双向流动，即reply 流可以正常的携带数据回来，如果为 1 的话那么数据将只能单向流通，从服务端回来的 _reply 流将不携带任何数据。在AIDL生成的java文件里，这个参数均为0.
* 关于transact()设计到了Binder机制比较低层的东西，博主没有太深的研究，所以就直接借用别的结论。


总结一下Proxy类方法的一般工作流程
* 生成_data和_reply数据流，并向_data中存入客户端的数据
* 通过transact() 方法将它们传递给服务端，并请求服务端调用指定方法。
* 接收_reoly数据流，并从中取出服务端传回的数据


#### 3.onTransact

在前面说了客户端通过transact() 方法将数据和请求发送过去，那么很显然，在服务端也应该有个方法来接收这些传过来的东西：在 BookManager.java 里面我们可以很轻易的找到一个叫做 onTransact() 的方法——看这名字就知道，多半和它脱不了关系，再一看它的传参 (int code, android.os.Parcel data, android.os.Parcel reply, int flags) ——和 transact() 方法的传参是一样的。所以 onTransact和transac之间肯定有很大联系，我们来看其代码
```java
        @Override
        public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException {
            switch (code) {
                case INTERFACE_TRANSACTION: {
                    reply.writeString(DESCRIPTOR);
                    return true;
                }
                case TRANSACTION_getBooks: {
                    data.enforceInterface(DESCRIPTOR);
                    //调用 this.getBooks() 方法，在这里开始执行具体的事务逻辑
                    //此时result调用 getBooks() 方法的返回值
                    java.util.List<com.heshucheng.servicedemo.Book> _result = this.getBooks();
                    reply.writeNoException();
                    //将方法执行的结果写入 reply
                    reply.writeTypedList(_result);
                    return true;
                }
                case TRANSACTION_addBook: {
                    data.enforceInterface(DESCRIPTOR);
                    com.heshucheng.servicedemo.Book _arg0;
                    if ((0 != data.readInt())) {
                        _arg0 = com.heshucheng.servicedemo.Book.CREATOR.createFromParcel(data);
                    } else {
                        _arg0 = null;
                    }
                    this.addBook(_arg0);
                    reply.writeNoException();
                    return true;
                }
            }
            return super.onTransact(code, data, reply, flags);
        }

```
在 onTransact先进行switch选择，之后根剧不同的方法进入不同的分支，在分支中，获得客户端的参数，并服务的实现的方法，井参数传入，最后将返回值写入reply 流。

总结服务端的流程：

*  获取客户端传过来的数据，根剧方法ID执行相应的操作
*  将传过来的数据取出，调用本地对应的方法
*  将需要的数据写入reply流，传回客户端。


#### 5.全部代码
```java
public interface BookManager extends android.os.IInterface {
    /**
     * Local-side IPC implementation stub class.
     */
    public static abstract class Stub extends android.os.Binder implements com.heshucheng.servicedemo.BookManager {
        private static final java.lang.String DESCRIPTOR = "com.heshucheng.servicedemo.BookManager";

        /**
         * Construct the stub at attach it to the interface.
         */
        public Stub() {
            this.attachInterface(this, DESCRIPTOR);
        }

        /**
         * Cast an IBinder object into an com.heshucheng.servicedemo.BookManager interface,
         * generating a proxy if needed.
         */
        public static com.heshucheng.servicedemo.BookManager asInterface(android.os.IBinder obj) {
            //判断是否为空
            if ((obj == null)) {
                return null;
            }

            //搜索本地是否有可用对象，如果有就将其返回
            android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (((iin != null) && (iin instanceof com.heshucheng.servicedemo.BookManager))) {
                return ((com.heshucheng.servicedemo.BookManager) iin);
            }

            //如果没有，就新建一个
            return new com.heshucheng.servicedemo.BookManager.Stub.Proxy(obj);
        }

        @Override
        public android.os.IBinder asBinder() {
            return this;
        }

        @Override
        public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException {
            switch (code) {
                case INTERFACE_TRANSACTION: {
                    reply.writeString(DESCRIPTOR);
                    return true;
                }
                case TRANSACTION_getBooks: {
                    data.enforceInterface(DESCRIPTOR);
                    //调用 this.getBooks() 方法，在这里开始执行具体的事务逻辑
                    //此时result调用 getBooks() 方法的返回值
                    java.util.List<com.heshucheng.servicedemo.Book> _result = this.getBooks();
                    reply.writeNoException();
                    //将方法执行的结果写入 reply
                    reply.writeTypedList(_result);
                    return true;
                }
                case TRANSACTION_addBook: {
                    data.enforceInterface(DESCRIPTOR);
                    com.heshucheng.servicedemo.Book _arg0;
                    if ((0 != data.readInt())) {
                        _arg0 = com.heshucheng.servicedemo.Book.CREATOR.createFromParcel(data);
                    } else {
                        _arg0 = null;
                    }
                    this.addBook(_arg0);
                    reply.writeNoException();
                    return true;
                }
            }
            return super.onTransact(code, data, reply, flags);
        }

        private static class Proxy implements com.heshucheng.servicedemo.BookManager {
            private android.os.IBinder mRemote;

            Proxy(android.os.IBinder remote) {
                mRemote = remote;
            }

            @Override
            public android.os.IBinder asBinder() {
                return mRemote;
            }

            public java.lang.String getInterfaceDescriptor() {
                return DESCRIPTOR;
            }

            @Override
            public java.util.List<com.heshucheng.servicedemo.Book> getBooks() throws android.os.RemoteException {
                //_data存心客户端流向服务的数据流
                //_reply存储服务流向客户端的数据流
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                java.util.List<com.heshucheng.servicedemo.Book> _result;
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);

                    //调用transact() 方法将方法id和两个 Parcel 容器传过去Service
                    mRemote.transact(Stub.TRANSACTION_getBooks, _data, _reply, 0);
                    _reply.readException();
                    //从_reply取出结果
                    _result = _reply.createTypedArrayList(com.heshucheng.servicedemo.Book.CREATOR);
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
                return _result;
            }

            @Override
            public void addBook(com.heshucheng.servicedemo.Book book) throws android.os.RemoteException {
                android.os.Parcel _data = android.os.Parcel.obtain();
                android.os.Parcel _reply = android.os.Parcel.obtain();
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if ((book != null)) {
                        //book存入
                        _data.writeInt(1);
                        book.writeToParcel(_data, 0);
                    } else {
                        _data.writeInt(0);
                    }
                    //调用transact() 方法将方法id和两个 Parcel 容器传给Service
                    mRemote.transact(Stub.TRANSACTION_addBook, _data, _reply, 0);
                    _reply.readException();
                } finally {
                    _reply.recycle();
                    _data.recycle();
                }
            }
        }

        static final int TRANSACTION_getBooks = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
        static final int TRANSACTION_addBook = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
    }


    public java.util.List<com.heshucheng.servicedemo.Book> getBooks() throws android.os.RemoteException;
    public void addBook(com.heshucheng.servicedemo.Book book) throws android.os.RemoteException;
}

```

#### 6.示意图
通过上面的分析，我们大致明白的AIDL的过程，我们可以发现我们完全可以不使用AIDL文件提供的Binder文件，可以实际实现Binder。下图就是AIDL生成的Binder的工作过程

![在这里插入图片描述](https://img-blog.csdnimg.cn/20181103195717670.png)

### 四.参考资料
android艺术开发探索
[AIDL官方文档](https://developer.android.com/guide/components/aidl?hl=zh-cn)
[Android：学习AIDL，这一篇文章就够了(上)](https://blog.csdn.net/luoyanglizi/article/details/51980630)
[Android：学习AIDL，这一篇文章就够了(下)](https://blog.csdn.net/luoyanglizi/article/details/52029091)
