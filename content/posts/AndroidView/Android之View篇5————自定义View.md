---
title: "Android之View篇5————自定义View"
date: 2019-03-02T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一.目录
@[toc]
### 二.自定义View的分类
#### 1.继承View重写onDraw方法
主要用来实现一些不规则的效果，这种效果不方便用布局组合的方式达到，通常需要静态或者动态的显示一些不规则的图形，这种需要绘制的需要自己支持wrap_content,并支持padding。

#### 2.继承ViewGroup派生出特殊的Layout
这种方式主要用于实现自定义布局，当某种效果看起来很像几种Veiw组合在一起的时候，可以采取这种方式来实现。这种方式复杂些，需要合适的处理ViewGroup的测量布局这两个过程，并同时处理子元素的测量和布局过程。

#### 3.继承特定的View
这种方法比较常见，一般用于扩展已有的View功能，比如TextView，这种方法比较容易实现，这种方法不需要自己支持wrap_content和padding。

#### 4.继承特定的ViewGroup
这种方发也比较常见，当某种效果看起来很想几种View组合在一起的时候，可以采用这种方法实现，这种方法不需要自己处理测量和布局两个过程，一般来说方法2介意实现的效果方法4也可以实现，区别在于方法2更接近低层。

### 三.自定义View注意事项
#### 1 支持特殊属性
* 支持wrap_content
    如果不在onMeasure（）中对wrap_content作特殊处理，那么wrap_content属性将失效
* 支持padding & margin
如果不支持，那么padding和margin（ViewGroup情况）的属性将失效
对于继承View的控件，padding是在draw()中处理
对于继承ViewGroup的控件，padding和margin会直接影响measure和layout过程

#### 2.多线程应直接使用post方式
View的内部本身提供了post系列的方法，完全可以替代Handler的作用，使用起来更加方便、直接。

#### 3.避免内存泄漏
主要针对View中含有线程或动画的情况：当View退出或不可见时，记得及时停止该View包含的线程和动画，否则会造成内存泄露问题。
> 启动或停止线程/ 动画的方式：  
> 
* 启动线程/动画：使用view.onAttachedToWindow（），因为该方法调用的时机是当包含View的Activity启动的时刻
* 停止线程/动画：使用view.onDetachedFromWindow（），因为该方法调用的时机是当包含View的Activity退出或当前View被remove的时刻

#### 4.处理好滑动冲突
详情可看[Android之View篇3————View滑动冲突的解决](https://blog.csdn.net/qq_38499859/article/details/80573602)
### 四.自定义View的实例
实例：继承View实现一个圆形控件
#### 1.继承View重写onDraw方法
**a.CircleView继承View并重写onDraw方法**
```
public class CircleView extends View {
    private int mColor = Color.RED;
    private Paint mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public CircleView(Context context) {
        super(context);
        init();
    }

    public CircleView(Context context, AttributeSet attrs) {
        super(context, attrs, 0);
        init();
    }

    public CircleView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        mPaint.setColor(mColor);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
     
        int width = getWidth() ;
        int height = getHeight();
        int radius = Math.min(width, height) / 2;

        canvas.drawCircle(paddingLeft + width / 2, paddingTop + height / 2, radius, mPaint);//画圆
    }
}

```

**b.布局文件**
```
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">

    <com.heshucheng.customviewdmeo.CircleView
        android:layout_width="match_parent"
        android:layout_height="100dp"
        android:background="#000000" />


</LinearLayout>
```
**c.效果图**
![这里写图片描述](https://img-blog.csdn.net/20180801113102813?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
#### 2.支持padding和wrap_content
**a.支持padding属性**
```
//修改onDraw方法
 @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int paddingLeft = getPaddingLeft();
        final int paddingRight = getPaddingRight();
        final int paddingTop = getPaddingTop();
        final int paddingBotton = getPaddingBottom();

        int width = getWidth() - paddingLeft - paddingRight;
        int height = getHeight() - paddingTop - paddingBotton;
        int radius = Math.min(width, height) / 2;

        canvas.drawCircle(paddingLeft + width / 2, paddingTop + height / 2, radius, mPaint);
    }
```
**b.支持wrap_content,重写onMeasure方法，设置wrap_content时的默认长度**
```
@Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        int widthSpecMode = MeasureSpec.getMode(widthMeasureSpec);
        int widthSpecSize = MeasureSpec.getSize(widthMeasureSpec);
        int heightSpecMode = MeasureSpec.getMode(heightMeasureSpec);
        int heightSpecSize = MeasureSpec.getSize(heightMeasureSpec);

        if (widthSpecMode == MeasureSpec.AT_MOST && heightSpecMode == MeasureSpec.AT_MOST) {
            setMeasuredDimension(200, 200);
        }else if(widthSpecMode == MeasureSpec.AT_MOST ){
            setMeasuredDimension(600, heightSpecSize);
        }else if(heightSpecMode == MeasureSpec.AT_MOST){
            setMeasuredDimension(widthSpecSize, 200);
        }
    }
```
**c.效果图**
![这里写图片描述](https://img-blog.csdn.net/20180801113026266?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
#### 3.提供自定义属性
**a.在valuse目录下创建自定义属性的XML，比如attrs.xml。文件内容如下：**
```
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <declare-styleable name="CircleView">
        <attr name="circle_color" format="color"/>
    </declare-styleable>

</resources>
```
**b.在View构造方法中解析自定义属性的值并作出相应的处理**
```
 public CircleView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        TypedArray a = context.obtainStyledAttributes(attrs, R.styleable.CircleView);
        mColor = a.getColor(R.styleable.CircleView_circle_color, Color.RED);
        a.recycle();
        init();
    }
```
**c.在布局文件中使用自定义属性**
```
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    xmlns:app="http://schemas.android.com/apk/res-auto" //使用自定义属性需要加入这个语句
    android:orientation="vertical">

    <com.heshucheng.customviewdmeo.CircleView
        android:layout_width="wrap_content"
        android:layout_height="100dp"
        android:background="#000000"
        android:padding="10dp"
        app:circle_color="#FFFFFF"
        />


</LinearLayout>
```
**d.效果图**
![这里写图片描述](https://img-blog.csdn.net/20180801113756541?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
#### 4.完整代码
```
public class CircleView extends View {
    private int mColor = Color.RED;
    private Paint mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public CircleView(Context context) {
        super(context);
        init();
    }

    public CircleView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
        init();
    }

    public CircleView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        TypedArray a = context.obtainStyledAttributes(attrs, R.styleable.CircleView);
        mColor = a.getColor(R.styleable.CircleView_circle_color, Color.RED);
        a.recycle();
        init();
    }

    private void init() {
        mPaint.setColor(mColor);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        int widthSpecMode = MeasureSpec.getMode(widthMeasureSpec);
        int widthSpecSize = MeasureSpec.getSize(widthMeasureSpec);
        int heightSpecMode = MeasureSpec.getMode(heightMeasureSpec);
        int heightSpecSize = MeasureSpec.getSize(heightMeasureSpec);

        if (widthSpecMode == MeasureSpec.AT_MOST && heightSpecMode == MeasureSpec.AT_MOST) {
            setMeasuredDimension(200, 200);
        }else if(widthSpecMode == MeasureSpec.AT_MOST ){
            setMeasuredDimension(600, heightSpecSize);
        }else if(heightSpecMode == MeasureSpec.AT_MOST){
            setMeasuredDimension(widthSpecSize, 200);
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int paddingLeft = getPaddingLeft();
        final int paddingRight = getPaddingRight();
        final int paddingTop = getPaddingTop();
        final int paddingBotton = getPaddingBottom();

        int width = getWidth() - paddingLeft - paddingRight;
        int height = getHeight() - paddingTop - paddingBotton;
        int radius = Math.min(width, height) / 2;

        canvas.drawCircle(paddingLeft + width / 2, paddingTop + height / 2, radius, mPaint);
    }
}

```
### 五.参考资料
《android艺术开发探索》
[手把手教你写一个完整的自定义View](https://www.jianshu.com/p/e9d8420b1b9c)
