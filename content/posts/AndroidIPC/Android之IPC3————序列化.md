# Android之IPC3————序列化
@[toc]
### 一.前言
说起序列化，大家应该都不会陌生，在Android中的应用也比较多，特别是在Activity直接传递对象时。就需要使用序列化，我一般是使用Serialization对对象进行序列化，然后进行传递。而在上篇文章中，在使用AIDL时，对跨进程传递的对象也进行了序列化，当时我们使用的是Parcelable。它也是一种序列化的方法。

在这篇文章里，我分别介绍一下两者的使用以及区别


### 二.序列化
#### 1.什么是序列化
序列化 (Serialization)将对象的状态信息转换为可以存储或传输的形式的过程。在序列化期间，对象将其当前状态写入到临时或持久性存储区。以后，可以通过从存储区中读取或反序列化对象的状态，重新创建该对象。

简单来说就是讲对象进行保存，在下次使用时可以顺利还原该对象。

#### 2.序列化保存的内容
对象是类的一个实例，一个类中包含变量和函数两部分。同一个类的不同对象只是变量不同，所以序列化是只保存对象的变量部分。同样，由于静态变量是由一个类的各个对象共用的，所以序列化过程中也不保存。 

#### 3.序列化的作用
序列化的用途主要有三个：

* 对象的持久化，对象持久化是指延长对象的存在时间，比如通过序列化功能，将对象保存在文件中，就可以延长对象的存在时间，在下次运行程序是再恢复该对象
* 对象复制,通过序列化后，将对象保存在内存中，可以在用过次数据得到多个对象的副本
* 对象传输，通过序列化，可以通过网络传递对象，以及跨进程通信。


### 三.Serialization
#### 1.实现接口
使用Serialization进行序列化，是比较简单的一件事，只要将需要序列化的类实现Serialization接口，并声明一个SerialVersionUID即可，甚至SerialVersionUID也不是必须的。没有它依然可以序列化，只是对反序列化造成影响

下面我们声明一个类，并将它实现Serialization接口
```java
public class User implements Serializable {


    private int userId;
    private String userName;
    private boolean isMale;

    public User(int UserId,String UserName,boolean IsMale){
        userId = UserId;
        userName = UserName;
        isMale = IsMale;
    }
    public int getUserId() {
        return userId;
    }

    public void setUserId(int userId) {
        this.userId = userId;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public boolean isMale() {
        return isMale;
    }

    public void setMale(boolean male) {
        isMale = male;
    }
}

```

#### 2.序列化和反序列化
```java
public class Main {

    public static void main(String[] args) {
        //序列化过程
        User user = new User(1,"shucheng",true);
        try {
            ObjectOutputStream  out = new ObjectOutputStream(new FileOutputStream("cache.txt"));
            out.writeObject(user);
            out.close();
        } catch (IOException e) {
            e.printStackTrace();
        }


        //反序列化过程
        try {
            ObjectInputStream in = new ObjectInputStream(new FileInputStream("cache.txt"));
            User newUser  = (User)in.readObject();
            in.close();

            System.out.println(newUser.getUserName());
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

}
```
上面就是采用Serializable方式实现序列化对象的典型过程。恢复后的对象和之前的对象内容一样，但并不是同样的对象

#### 3.SerialVersionUID的作用
SerialVersionUID是序列化的机制判断类的版本一致性的。进行反序列化时，JVM会把传来的字节流中的serialVersionUID与本地相应实体类的serialVersionUID进行比较，如果相同就认为是一致的，可以进行反序列化，否则就会出现序列化版本不一致的异常，即是InvalidCastException。

serialVersionUID有两种显示的生成方式：        
一是默认的1L，比如：private static final long serialVersionUID = 1L;        
二是根据类名、接口名、成员方法及属性等来生成一个64位的哈希字段，比如：        
private static final  long   serialVersionUID = xxxxL;

当序列化前后的SerialVersionUID发生变化，对应的类发生变化时，有以下几种情况

情况一：假设User类序列化之后，从A端传输到B端，然后在B端进行反序列化。在序列化Person和反序列化Person的时候，A端和B端都需要存在一个相同的类。如果两处的serialVersionUID不一致，会产生什么错误呢?  
结果：结果报错

情况二：假设两处serialVersionUID一致，如果A端增加一个字段，然后序列化，而B端不变，然后反序列化，会是什么情况呢?  
结果：执行序列化，反序列化正常，但是A端增加的字段丢失(被B端忽略)。

情况三：假设两处serialVersionUID一致，如果B端减少一个字段，A端不变，会是什么情况呢?  
结果:序列化，反序列化正常，B端字段少于A端，A端多的字段值丢失(被B端忽略)。

情况四：假设两处serialVersionUID一致，如果B端增加一个字段，A端不变，会是什么情况呢?  
结果：反序列化正常，B端新增加的int字段被赋予了默认值0。

### 四.Parcelable
前面介绍了序列化和Java中使用Serializable来实现序列化。我们继续来看android中的序列化Parcelable

#### 1.为什么使用Parcelable
在Android中是可以使用Serializable进行序列化，而且使用起来也很简单，为什么Android要自己在实现一个Parcelable方法。因为Serializable是Java中的序列化方法，虽然很简单但是开销很大。序列化和反序列化中需要大量的I/O操作。

Parcelable是Android中序列化的实现，它的缺点是使用起来稍微麻烦些，但是效率很高，这是Android推荐的序列化方式。Parcelable主要作用在内存序列化上。所以如果用了进行Intent和Binder传输，建议使用Parcelable。如果用来将对象序列化到本地或者用来进行网络传输时，还是推荐使用Serializable。

#### 2.使用
以上一篇文章的序列化的类为例，在里面也为其中的方法进行了注释。
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

    /**
     * 返回当前对象的描述内容，如果含有文件描述符，返回1，否则返回0
     * @return
     */
    @Override
    public int describeContents() {
        return 0;
    }

    /**
     * 将当前对象写入序列化结构中
     * @param dest
     * @param flags：有两种0/1 为1时表示当前对象需要作为返回值返回，不能立即释放资源，大部分情况下为0
     */
    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeString(name);
        dest.writeInt(price);
    }

    /**
     * 从序列化后的对象中创建原始对象
     * @param in
     */
    protected Book(Parcel in) {
        name = in.readString();
        price = in.readInt();
    }

    public static final Creator<Book> CREATOR = new Creator<Book>() {

        /**
         * 从序列化后的对象中创建原始对象
         * @param in
         * @return
         */
        @Override
        public Book createFromParcel(Parcel in) {
            return new Book(in);
        }

        /**
         * 创建指定长度的原始对象数组
         * @param size
         * @return
         */
        @Override
        public Book[] newArray(int size) {
            return new Book[size];
        }
    };
}


```

### 五.参考资料
《Android艺术开发探索》
[Java序列化(Serialization)的理解](https://www.cnblogs.com/wczy999/p/5961956.html)
[Java 的序列化 (Serialization)教程](https://www.oschina.net/translate/serialization-in-java)
[java类中serialversionuid 作用](https://www.cnblogs.com/duanxz/p/3511695.html)
