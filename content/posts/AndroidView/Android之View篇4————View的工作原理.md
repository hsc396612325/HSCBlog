---
title: "Android之View篇4————View的工作原理"
date: 2019-03-02T22:40:54+08:00
draft: false
categories: ["Android","Android之网络请求"]
tags: ["Android","网络"]
---

### 一. 目录
@[toc]
### 二. 初识DecorView和ViewRoot
#### 1. DecorView
DecorView是整个Window界面的最顶层View。DecorView只有一个子元素为LinearLayout。代表整个Window界面，包含通知栏，标题栏，内容显示栏三块区域。LinearLayout里有两个FrameLayout子元素。如图：
![这里写图片描述](https://img-blog.csdn.net/20160808132027415?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQv/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/Center)

所以在Activity中，设定View是设定给cintent的。获得content的方法 ViewGroup = （ViewGroup）findViewById（R.id.content）。如何得到设定的View，content.getChildAt(0)
#### 2. ViewRoot
ViewRoot对应的是ViewRootImpl类，它是连接WindowManager和DecorView的纽带，View的三大流程都是通过ViewRoot来完成。在ActivityThread中，当Activity对象被创建时，会将DecorView添加到Window，同时会创建ViewRootImpl对象，并将ViewRootImpl对象和DecorView对象。
#### 3. View的工作流程概述
view的绘制是从ViewRoot的performTraversals方法开始的，它经历过measure，layout和draw三个过程才最终将一个View绘制出来。其中measure用来测量View的宽和高，layout用来确定View在父容器的放置位置，而Draw则负责将View绘制在屏幕上。大致流程如下：
![这里写图片描述](https://img-blog.csdn.net/2018061015384765?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 三. MeasureSpec
#### 1.  MeasureSpec源码
MeasureSpec代表一个32位int值。高2位表示SpecMode（测量模式），低30位表示specSize（当前测量模式下的规格大小）

MeasureSpec源码:
```java
//部分重点代码
        private static final int MODE_SHIFT = 30;
        private static final int MODE_MASK  = 0x3 << MODE_SHIFT; 
        
        public static final int UNSPECIFIED = 0 << MODE_SHIFT;  //父容器不对View有任何限制，要多大给到大
                                                                //这种情况一般用于系统内部，表示一直测量出状态
        
        public static final int EXACTLY     = 1 << MODE_SHIFT; //父容器已经检测出View的精确的大小，这时候View的最终大小就是SpecSize确定的值
                                                               //它对于LayoutParams中的match_parent和具体数值这两种模式

        public static final int AT_MOST     = 2 << MODE_SHIFT;//父容器指定一个可用大小，View的大小不能大于这个值。它对应LayoutParent中的wrap_content


        public static int makeMeasureSpec(@IntRange(from = 0, to = (1 << MeasureSpec.MODE_SHIFT) - 1) int size,  //将 size和mode打包成一个MeasureSpec
                                          @MeasureSpecMode int mode) {
            if (sUseBrokenMakeMeasureSpec) {
                return size + mode;
            } else {
                return (size & ~MODE_MASK) | (mode & MODE_MASK);
            }
        }

        
        public static int getMode(int measureSpec) {     //MeasureSpec解包出mode
            //noinspection ResourceType
            return (measureSpec & MODE_MASK);
        }
        
        public static int getSize(int measureSpec) {  //MeasureSpec解包出size
            return (measureSpec & ~MODE_MASK);
        }

```

通过源码可知，MeasureSpec共有3种模式，同时可以将size和mode打包成一个MeasureSpec，也可以解包出size和mode。

#### 2.  MeasureSpec和LayoutParams对应关系
在View进行测量时，系统会将**LayoutParams在父容器的约束**下转换成相应的MeasureSpec，然后根据这个MeasureSpec来确定View测量后的宽/高。 对于DecorView的MeasureSpec确定略有不同，不是由父容器和LayoutParams确定，而是由窗户的尺寸和自身的LayoutParams共同确定的。 MeasureSpec一旦确定后monMeasure就可以确定View的测量宽/高。

**a.DecorView的MeasureSpec确定**
在DecorView的measureHierarchy方法中，有MeasureSpec 的获取
```java
childWidthMeasureSpec = getRootMeasureSpec(desiredWindowWidth, lp.width);  //desiredWindowWidth 是屏幕尺寸
childHeightMeasureSpec = getRootMeasureSpec(desiredWindowHeight, lp.height); //desiredWindowWidth 是屏幕尺寸
performMeasure(childWidthMeasureSpec, childHeightMeasureSpec);
```
getRootMeasureSpec源码
```java
    private static int getRootMeasureSpec(int windowSize, int rootDimension) {
        int measureSpec;
        switch (rootDimension) {

        case ViewGroup.LayoutParams.MATCH_PARENT://精确模式，大小就是窗口的大小
            // Window can't resize. Force root view to be windowSize.
            measureSpec = MeasureSpec.makeMeasureSpec(windowSize, MeasureSpec.EXACTLY);
            break;
        case ViewGroup.LayoutParams.WRAP_CONTENT: //最大模式，大小不定，但不能超酷窗口大小
            // Window can resize. Set max size for root view.
            measureSpec = MeasureSpec.makeMeasureSpec(windowSize, MeasureSpec.AT_MOST);
            break;
        default:   //精确模式，大小为LayoutParams中指定的大小
            // Window wants to be an exact size. Force root view to be that size.
            measureSpec = MeasureSpec.makeMeasureSpec(rootDimension, MeasureSpec.EXACTLY);
            break;
        }
        return measureSpec;
    }
```

**b.  View的MeasureSpec确定**
对于View来说，view的measure过程有ViewGroup传递而来，先看看ViewGeoup的measureChildWithMargins方法
```java
    protected void measureChildWithMargins(View child,
            int parentWidthMeasureSpec, int widthUsed,
            int parentHeightMeasureSpec, int heightUsed) {
        final MarginLayoutParams lp = (MarginLayoutParams) child.getLayoutParams();

        final int childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec,
                mPaddingLeft + mPaddingRight + lp.leftMargin + lp.rightMargin
                        + widthUsed, lp.width);  //获得子元素的MeasureSpec，可以看出子元素MeasureSpec的确
		                        //定不止和父元素的MeasureSpec，自身的LayoutParams有关
		                        //还和View的margin和padding有关
                   
        final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,
                mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin
                        + heightUsed, lp.height);

        child.measure(childWidthMeasureSpec, childHeightMeasureSpec);
    }

```
 getChildMeasureSpec的源码
```java
    public static int getChildMeasureSpec(int spec, int padding, int childDimension) {
        int specMode = MeasureSpec.getMode(spec);
        int specSize = MeasureSpec.getSize(spec);

        int size = Math.max(0, specSize - padding);

        int resultSize = 0;
        int resultMode = 0;

        switch (specMode) {
        // Parent has imposed an exact size on us
        case MeasureSpec.EXACTLY:
            if (childDimension >= 0) {
                resultSize = childDimension;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.MATCH_PARENT) {
                // Child wants to be our size. So be it.
                resultSize = size;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.WRAP_CONTENT) {
                // Child wants to determine its own size. It can't be
                // bigger than us.
                resultSize = size;
                resultMode = MeasureSpec.AT_MOST;
            }
            break;

        // Parent has imposed a maximum size on us
        case MeasureSpec.AT_MOST:
            if (childDimension >= 0) {
                // Child wants a specific size... so be it
                resultSize = childDimension;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.MATCH_PARENT) {
                // Child wants to be our size, but our size is not fixed.
                // Constrain child to not be bigger than us.
                resultSize = size;
                resultMode = MeasureSpec.AT_MOST;
            } else if (childDimension == LayoutParams.WRAP_CONTENT) {
                // Child wants to determine its own size. It can't be
                // bigger than us.
                resultSize = size;
                resultMode = MeasureSpec.AT_MOST;
            }
            break;

        // Parent asked to see how big we want to be
        case MeasureSpec.UNSPECIFIED:
            if (childDimension >= 0) {
                // Child wants a specific size... let him have it
                resultSize = childDimension;
                resultMode = MeasureSpec.EXACTLY;
            } else if (childDimension == LayoutParams.MATCH_PARENT) {
                // Child wants to be our size... find out how big it should
                // be
                resultSize = View.sUseZeroUnspecifiedMeasureSpec ? 0 : size;
                resultMode = MeasureSpec.UNSPECIFIED;
            } else if (childDimension == LayoutParams.WRAP_CONTENT) {
                // Child wants to determine its own size.... find out how
                // big it should be
                resultSize = View.sUseZeroUnspecifiedMeasureSpec ? 0 : size;
                resultMode = MeasureSpec.UNSPECIFIED;
            }
            break;
        }
        //noinspection ResourceType
        return MeasureSpec.makeMeasureSpec(resultSize, resultMode);
    }

```
 将上述代码转化为图表：
 ![这里写图片描述](https://img-blog.csdn.net/20180610171921234?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### 四. Measure过程
measure确定Veiw的测量宽/高
#### 1.view的measure过程
View的measure由其measure方法完成。而measure方法中会调用View的onMeasure方法。
onMeasure方法：
```java
  protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        setMeasuredDimension(getDefaultSize(getSuggestedMinimumWidth(), widthMeasureSpec),
                getDefaultSize(getSuggestedMinimumHeight(), heightMeasureSpec));
    }
```
getDefaultSize方法
```java
    public static int getDefaultSize(int size, int measureSpec) {
        int result = size;
        int specMode = MeasureSpec.getMode(measureSpec);
        int specSize = MeasureSpec.getSize(measureSpec);

        switch (specMode) {
        case MeasureSpec.UNSPECIFIED:
            result = size;
            break;
        case MeasureSpec.AT_MOST:
        case MeasureSpec.EXACTLY://从这里可以看出，直接继承View的自定义控件，需要重写onMeasure方法并设置
                                //wrap_comtent时，自身大小。否则wrap_comtent 就相当与使用match_parent
            result = specSize;
            break;
        }
        return result; //返回测量后的大小，即MeasureSpec的getSize
    }
```
getSuggestedMinimumWidth()和getSuggestedMinimumHeight()
```java
 protected int getSuggestedMinimumWidth() {
        return (mBackground == null) ? mMinWidth : max(mMinWidth, mBackground.getMinimumWidth());
 }
//如果View没有设置背景，那么View的长度为mMinWidth（即android：minWidth这个属性指定的值，如果不指定为0）
//如果指向的背景，则为 max(mMinWidth, mBackground.getMinimumWidth())
 protected int getSuggestedMinimumHeight() {
        return (mBackground == null) ? mMinHeight : max(mMinHeight, mBackground.getMinimumHeight());

 }

// mBackground.getMinimumWidth()
 public int getMinimumHeight() {
        final int intrinsicHeight = getIntrinsicHeight();
        return intrinsicHeight > 0 ? intrinsicHeight : 0;//Drawable的原始高度
 }
```

#### 2.ViewGroup的measure过程
对于ViewGroup来说，除了完成自己的measure过程外，还会遍历去调用所有子元素的measure方法。和ViewGroup是一个抽象类，因此没有重写View的onMeasure，但是提供了一个叫measureChildren的方法。
ViewGroup.measureChildren
```java
    protected void measureChildren(int widthMeasureSpec, int heightMeasureSpec) {
        final int size = mChildrenCount;
        final View[] children = mChildren;
        for (int i = 0; i < size; ++i) {
            final View child = children[i];
            if ((child.mViewFlags & VISIBILITY_MASK) != GONE) {
                measureChild(child, widthMeasureSpec, heightMeasureSpec);  //调用子元素的measure
            }
        }
    }

```
 ViewGroup.measureChild
```java
    protected void measureChild(View child, int parentWidthMeasureSpec,
            int parentHeightMeasureSpec) {
        final LayoutParams lp = child.getLayoutParams();//1.获取子元素的LayoutParams

	//2.根据getChildMeasureSpec创建子元素的MeasureSpec
        final int childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec,
                mPaddingLeft + mPaddingRight, lp.width);
        final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,
                mPaddingTop + mPaddingBottom, lp.height);

	//3.调用子元素的measure
        child.measure(childWidthMeasureSpec, childHeightMeasureSpec);
    }
```
在ViewGroup并没有定义其测量的具体的过程，其测量过程的onMeasure方法有各个子类具体实现。以LinearLayout为例
LinearLayout.onMeasure
```
    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        if (mOrientation == VERTICAL) {
            measureVertical(widthMeasureSpec, heightMeasureSpec);//竖直布局
        } else {
            measureHorizontal(widthMeasureSpec, heightMeasureSpec);//水平布局
        }
    }
```
以竖直布局的 measureVertical为例
```
 //仅看核心代码
 // See how tall everyone is. Also remember max width.
        for (int i = 0; i < count; ++i) {
            final View child = getVirtualChildAt(i);
            ···

                // Determine how big this child would like to be. If this or
                // previous children have given a weight, then we allow it to
                // use all available space (and we will shrink things later
                // if needed).
                final int usedHeight = totalWeight == 0 ? mTotalLength : 0;
                measureChildBeforeLayout(child, i, widthMeasureSpec, 0,
                        heightMeasureSpec, usedHeight); //这个方法内部会调用子元素法measure方法，对子元素进行measure过程

                final int childHeight = child.getMeasuredHeight();
                if (useExcessSpace) {
                    // Restore the original height and record how much space
                    // we've allocated to excess-only children so that we can
                    // match the behavior of EXACTLY measurement.
                    lp.height = 0;
                    consumedExcessSpace += childHeight;
                }

                final int totalLength = mTotalLength;
                mTotalLength = Math.max(totalLength, totalLength + childHeight + lp.topMargin +
                       lp.bottomMargin + getNextLocationOffset(child)); //mTotalLength存储LinearLayout初步高度。每测量一个子元素，mTotalLength就会增加。
                   

                if (useLargestChild) {
                    largestChildHeight = Math.max(childHeight, largestChildHeight);
                }
            }
            
···
//子元素测量完之后，linearLayout会测量自己的大小
        mTotalLength += mPaddingTop + mPaddingBottom;

        int heightSize = mTotalLength;

        // Check against our minimum height
        heightSize = Math.max(heightSize, getSuggestedMinimumHeight());

        // Reconcile our calculated size with the heightMeasureSpec
        int heightSizeAndState = resolveSizeAndState(heightSize, heightMeasureSpec, 0);
···
       setMeasuredDimension(resolveSizeAndState(maxWidth, widthMeasureSpec, childState),
                heightSizeAndState);//如果布局采用的match_parent或者具体数值，那么测量过程和View一致
			             //如果采用的是wrap_content,那么他的高度是所有子元素所占有的高度总和。详见下面的源码
			            
```
resolveSizeAndState
```
    public static int resolveSizeAndState(int size, int measureSpec, int childMeasuredState) {
        final int specMode = MeasureSpec.getMode(measureSpec);
        final int specSize = MeasureSpec.getSize(measureSpec);
        final int result;
        switch (specMode) {
            case MeasureSpec.AT_MOST:
                if (specSize < size) {
                    result = specSize | MEASURED_STATE_TOO_SMALL;
                } else {
                    result = size;
                }
                break;
            case MeasureSpec.EXACTLY:
                result = specSize;
                break;
            case MeasureSpec.UNSPECIFIED:
            default:
                result = size;
        }
        return result | (childMeasuredState & MEASURED_STATE_MASK);
    }
```
#### 3.获取View的高/宽
**a.Activity/View#onWindowFocusChanged**
此方法的含义是View已经初始化完毕，高宽已经准备好了。需要注意的是，当Activity的窗口获得焦点或者失去焦点是，进行onResume和onPause时，onWindowFocusChange均会被调用。

代码
```
 @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if(hasFocus){
            int width = view.getMeasuredWidth();
            int height = view.getMeasuredHeight()；
        }
    }
```
**b.view.post(runnable)**
通过post可以将runnable投递到消息队列的尾部，然后等待Looper调用runnable的时候，View也初始化好了。典型代码如下。
```
 @Override
    protected void onStart() {
        super.onStart();
        view.post(new Runnable() {
            @Override
            public void run() {
                int width = view.getMeasuredWidth();
                int height = view.getMeasuredHeight();
            }
        });
    }
```

**c.ViewTreeObserer**
使用ViewTreeObserer的众多回调可以完成这个功能。比如使用onGlobalLayoutListener这个借口。当View树改变是，onGlobalLayout方法将会被调用，但注意，伴随View树的改变，onGlobalLayout方法将会被多次调用，

代码
```
 @Override
    protected void onStart() {
        super.onStart();
        ViewTreeObserver observer = view.getViewTreeObserver();
        observer.addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                view.getViewTreeObserver().removeGlobalOnLayoutListener(this);
                int width= view.getMeasuredWidth();
                int height = view.getMeasuredHeight();
            }
        });
    }
```
**d.view.measure(int widthMeasureSpec,int heightMeasureSpec)**  
通过手动对View进行measure来得到View的宽高，这种方法比较复杂，需要分情况进行讨论。根据View的LayoutParams来分

**match_parent**
这种情况直接放弃，无法measure的具体宽高。

**具体的数值**
比如都是100dp。如：
```
int widthMeasureSpec = MeasureSpec.makeMeasureSpec(100,MeasureSpec.EXACTLY);
int heightMeasureSpec = MeasureSpec.makeMeasureSpec(100,MeasureSpec.EXACTLY);
view.measure(widthMeasureSpec,heightMeasureSpec);
```

**wrap_content**
```
int widthMeasureSpec = MeasureSpec.makeMeasureSpec((1<<30)-1,MeasureSpec.AT.MOST);
int heightMeasureSpec = MeasureSpec.makeMeasureSpec((1<<30)-1,MeasureSpec.AT.MOST);
view.measure(widthMeasureSpec,heightMeasureSpec);
```
### 五. Layout过程
Layout的作用是ViewGroup来确定子元素的位置，当ViewGroup的位置被确定后，它会在onLayout中遍历所有的子元素并调用其layout发布方法

#### 1.View的Layout过程
layout方法：
```
/**
  * 源码分析：layout（）
  * 作用：确定View本身的位置，即设置View本身的四个顶点位置
  */ 
    public void layout(int l, int t, int r, int b) {
        if ((mPrivateFlags3 & PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT) != 0) {
            onMeasure(mOldWidthMeasureSpec, mOldHeightMeasureSpec);
            mPrivateFlags3 &= ~PFLAG3_MEASURE_NEEDED_BEFORE_LAYOUT;
        }
        
	 // 当前视图的四个顶点
        int oldL = mLeft;
        int oldT = mTop;
        int oldB = mBottom;
        int oldR = mRight;

        boolean changed = isLayoutModeOptical(mParent) ?
                setOpticalFrame(l, t, r, b) : setFrame(l, t, r, b);//通过setFrame来设定View的四个顶点位置，即对mLeft，mTopm，Bottom，mRight

        if (changed || (mPrivateFlags & PFLAG_LAYOUT_REQUIRED) == PFLAG_LAYOUT_REQUIRED) {
            onLayout(changed, l, t, r, b);//父容器确定子元素的位置，但View和ViewGroup中均没有真正实现。因为其具体实现和布局有关

         ····
    }

```
setOpticalFrame(l, t, r, b) ：
```
/**
  * setOpticalFrame（）
  * 作用：根据传入的4个位置值，设置View本身的四个顶点位置
  * 即：最终确定View本身的位置
  */ 
 private boolean setOpticalFrame(int left, int top, int right, int bottom) {
        Insets parentInsets = mParent instanceof View ?
                ((View) mParent).getOpticalInsets() : Insets.NONE;
        Insets childInsets = getOpticalInsets();

        // 内部实际上是调用setFrame（）
        return setFrame( 
             left + parentInsets.left - childInsets.left, 
             top + parentInsets.top - childInsets.top, 
             right + parentInsets.left + childInsets.right, 
             bottom + parentInsets.top + childInsets.bottom);
}

```
setFrame（）
```
/**
  *setFrame（）
  * 作用：根据传入的4个位置值，设置View本身的四个顶点位置
  * 即：最终确定View本身的位置
  */ 
  protected boolean setFrame(int left, int top, int right, int bottom) {
        ...
    // 通过以下赋值语句记录下了视图的位置信息，即确定View的四个顶点
    // 从而确定了视图的位置
     mLeft = left;
    mTop = top;
    mRight = right;
    mBottom = bottom;

    mRenderNode.setLeftTopRightBottom(mLeft, mTop, mRight, mBottom);

    }
```
onLayout（）
```
/**
  * onLayout（）
  * 注：对于单一View的laytou过程
  *    a. 由于单一View是没有子View的，故onLayout（）是一个空实现
  * b. 由于在layout（）中已经对自身View进行了位置计算，所以单一View的layout过程在layout（）后就已完成了
  */ 
   protected void onLayout(boolean changed, int left, int top, int right, int bottom) {

   // 参数说明
   // changed 当前View的大小和位置改变了 
    // left 左部位置
   // top 顶部位置
   // right 右部位置
   // bottom 底部位置

}  
```
#### 2. ViewGroup的layout过程
ViewGroup的layout步骤：

* 计算自身的ViewGroup的位置：layout()
*  遍历子view&确定子veiw在VeiwGroup的位置 （调用子View的layout）


View和ViewGroup同样拥有layout()和onLayout(),但两者不同：

*  一开始计算ViewGroup位置时，调用的是ViewGroup的layout()和onLayout() 
*  当遍历子View时，调用的是子View1的layout()和onLayout()

源码：
ViewGroup.layout()源码基本和View的相同。

#### 3. LinearLayout的layout过程
 LinearLayout的Layout和View的源码也是一样的，就不继续看了。
我们来看看 LinearLayout复写的onLayout（View和ViewGroup都没有实现onLayout）

LinearLayout.onLayout()
```
@Override
    protected void onLayout(boolean changed, int l, int t, int r, int b) {
        if (mOrientation == VERTICAL) {
            layoutVertical(l, t, r, b);
        } else {
            layoutHorizontal(l, t, r, b);
        }
    }

```

 layoutVertical(l, t, r, b); 
```java
    void layoutVertical(int left, int top, int right, int bottom) {
        // 子View的数量 
        final int count = getVirtualChildCount();

        // 1. 遍历子View 
        for (int i = 0; i < count; i++) {
            final View child = getVirtualChildAt(i);
            if (child == null) {
                childTop += measureNullChild(i);
            } else if (child.getVisibility() != GONE) {
                // 2. 计算子View的测量宽 / 高值 
                final int childWidth = child.getMeasuredWidth();
                final int childHeight = child.getMeasuredHeight();

···
                // 3. 确定自身子View的位置 
                // 即：递归调用子View的setChildFrame()，实际上是调用了子View的layout() ->>源码见下：
                setChildFrame(child, childLeft, childTop + getLocationOffset(child), childWidth, childHeight);
                // childTop逐渐增大，即后面的子元素会被放置在靠下的位置 
                // 这符合垂直方向的LinearLayout的特性 

                childTop += childHeight + lp.bottomMargin + getNextLocationOffset(child);
                i += getChildrenSkipCount(child, i);
            }
        }
    }
```

setChildFrame（）
```
   private void setChildFrame(View child, int left, int top, int width, int height) {
        child.layout(left, top, left + width, top + height);  // setChildFrame（）仅仅只是调用了子View的layout（）而已
    }

// 在子View的layout（）又通过调用setFrame（）确定View的四个顶点
// 即确定了子View的位置
// 如此不断循环确定所有子View的位置，最终确定ViewGroup的位置
```

#### 4.细节问题：getWidth() （ getHeight()）与 getMeasuredWidth() （getMeasuredHeight()）获取的宽 （高）有什么区别？
* getWidth() / getHeight()：获得View最终的宽 / 高
*  getMeasuredWidth() / getMeasuredHeight()：获得 View测量的宽 / 高

```
// 获得View测量的宽 / 高
  public final int getMeasuredWidth() {  
      return mMeasuredWidth & MEASURED_SIZE_MASK;  
      // measure过程中返回的mMeasuredWidth
  }  

  public final int getMeasuredHeight() {  
      return mMeasuredHeight & MEASURED_SIZE_MASK;  
      // measure过程中返回的mMeasuredHeight
  }  

// 获得View最终的宽 / 高
  public final int getWidth() {  
      return mRight - mLeft;  
      // View最终的宽 = 子View的右边界 - 子view的左边界。
  } 

  public final int getHeight() {  
      return mBottom - mTop;  
     // View最终的高 = 子View的下边界 - 子view的上边界。
  }   
```

两者区别
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtNmIyN2I5ODM1ZDkyN2UwNC5wbmc?x-oss-process=image/format,png)

当重写view的layout()强行设置是。两者结果可能不同
```

@Override
public void layout( int l , int t, int r , int b){
      // 改变传入的顶点位置参数
      super.layout(l，t，r+100，b+100)；
      // 如此一来，在任何情况下，getWidth() / getHeight()获得的宽/高 总比 getMeasuredWidth() /      getMeasuredHeight()获取的宽/高大100px
     // 即：View的最终宽/高 总比 测量宽/高 大100px
   }
```

### 六. Draw过程
Draw的作用就是将View绘制到屏幕上，View的绘制有如下步骤:

* 绘制背景brckground，draw(canvas)
* 绘制自己(onDraw）
* 绘制children（dispatchDraw）
* 绘制装饰（onDrawScrollBars)

#### 1.Draw的源码
下面是Draw的源码(View和ViewGroup差不多)
```
public void draw(Canvas canvas) {
        final int privateFlags = mPrivateFlags;
        final boolean dirtyOpaque = (privateFlags & PFLAG_DIRTY_MASK) == PFLAG_DIRTY_OPAQUE &&
                (mAttachInfo == null || !mAttachInfo.mIgnoreDirtyState);
        mPrivateFlags = (privateFlags & ~PFLAG_DIRTY_MASK) | PFLAG_DRAWN;

        /*
         * Draw traversal performs several drawing steps which must be executed
         * in the appropriate order:
         *
         *      1. Draw the background
         *      2. If necessary, save the canvas' layers to prepare for fading
         *      3. Draw view's content
         *      4. Draw children
         *      5. If necessary, draw the fading edges and restore layers
         *      6. Draw decorations (scrollbars for instance)
         */

        // Step 1, draw the background, if needed
        int saveCount;

        if (!dirtyOpaque) {
            drawBackground(canvas);
        }

        // skip step 2 & 5 if possible (common case)
        final int viewFlags = mViewFlags;
        boolean horizontalEdges = (viewFlags & FADING_EDGE_HORIZONTAL) != 0;
        boolean verticalEdges = (viewFlags & FADING_EDGE_VERTICAL) != 0;
        if (!verticalEdges && !horizontalEdges) {
            // Step 3, draw the content
            if (!dirtyOpaque) onDraw(canvas);

            // Step 4, draw the children
            dispatchDraw(canvas);

            drawAutofilledHighlight(canvas);

            // Overlay is part of the content and draws beneath Foreground
            if (mOverlay != null && !mOverlay.isEmpty()) {
                mOverlay.getOverlayView().dispatchDraw(canvas);
            }

            // Step 6, draw decorations (foreground, scrollbars)
            onDrawForeground(canvas);

            // Step 7, draw the default focus highlight
            drawDefaultFocusHighlight(canvas);

            if (debugDraw()) {
                debugDrawFocus(canvas);
            }

            // we're done...
            return;
        }
```
#### 2. setWillNotDraw源码
```
/**
  * 源码分析：setWillNotDraw()
  * 定义：View 中的特殊方法
  * 作用：设置 WILL_NOT_DRAW 标记位；
  * 注：
  *   a. 该标记位的作用是：当一个View不需要绘制内容时，系统进行相应优化
  *   b. 默认情况下：View 不启用该标记位（设置为false）；ViewGroup 默认启用（设置为true）
  */ 
public void setWillNotDraw(boolean willNotDraw) {

    setFlags(willNotDraw ? WILL_NOT_DRAW : 0, DRAW_MASK);

}
// 应用场景
// a. setWillNotDraw参数设置为true：当自定义View继承自 ViewGroup 、且本身并不具备任何绘制时，设置为 true 后，系统会进行相应的优化。
//b. setWillNotDraw参数设置为false：当自定义View继承自 ViewGroup 、且需要绘制内容时，那么设置为 false，来关闭 WILL_NOT_DRAW 这个标记位。

```
### 七.参考资料
《Android艺术开发探索》
[自定义View基础 - 最易懂的自定义View原理系列（1）](https://www.jianshu.com/p/146e5cec4863)
[自定义View Measure过程 - 最易懂的自定义View原理系列（2）](https://www.jianshu.com/p/1dab927b2f36)
[自定义View Layout过程 - 最易懂的自定义View原理系列3](https://www.jianshu.com/p/158736a2549d)
[自定义View Draw过程- 最易懂的自定义View原理系列4](https://www.jianshu.com/p/95afeb7c8335)
