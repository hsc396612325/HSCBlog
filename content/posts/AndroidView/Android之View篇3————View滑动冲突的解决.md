---
title: "Android之View篇3————View滑动冲突的解决"
date: 2019-03-03T22:40:54+08:00
draft: false
categories: ["Android","Android之View"]
tags: ["Android","View"]
---

### 一. 目录
@[toc]
### 二. 前言
滑动冲突也算是在开发中经常遇到的问题，在去年做Everyday时，就碰到过这个问题，当时在百度中找到了问题的解决方法，只不过一直处于不知其所以然。今天我就想系统的整理下关于滑动冲突的解决。

阅读本篇前，建议阅读我的前一篇博客,View的事件分发机制。滑动冲突的解决方法就是基于View的事件分发机制的基础上的。
### 三. 常见滑动冲突的场景
常见的滑动冲突场景可以简单分为以下3种:

* 场景1——外部滑动方向和内部滑动方向不一致
* 场景2——外部滑动方向和内部滑动方向一致
* 场景3——上面两种情况的嵌套
![这里写图片描述](/image/Android_View/5_0.png?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

场景1:主要是将ViewPager和Fragment配合使用的情况，所组成的页面滑动效果，在这种效果中，可以通过左右滑动来切换画面，而每个页面内部往往又是一个listView，这种情况下本来是有滑动冲突的，但viewPager内部处理了这种滑动冲突，但如果我们采用的是ScrollView时，就必须手动处理滑动冲突。

场景2：这种情况下，当内外层都存在同一个方向可以滑动的时候，就存在一个逻辑问题时，当手指开始滑动时，系统无法知道用户到底想让那一层滑动，所以当手指滑动时，就会出现问题，要么只有一层滑动，要么滑动很卡顿。

场景3：场景三是场景一和场景2的嵌套，所以场景3的滑动冲突看起来更加复杂，但它只不过是几个单一的滑动冲突的叠加，因此，只要分别处理外层和中层，中层和内层的滑动冲突即可。
### 四. 滑动冲突的处理规则
#### 1. 场景1的处理规则
对于场景1的处理规则是，当用户左右滑动时，需要让外部的View拦截点击事件，当用户上下滑动时，需要让内部的View拦截点击事件。具体来说就是根据他是水平滑动还是竖直滑动来确定到底是由谁来解决滑动冲突。

如何判断水平滑动还是竖直滑动:

* 依据滑动路径和水平方向所形成的夹角
* 依据水平方向和竖直水平的距离差
* 依据水平速度和竖直水平的距离差

#### 2. 场景2的处理规则
场景2比较特殊，他无法根据滑动的角度，距离差和速度差来判断，但他一般都能在业务上找到突破点。比如，业务规定，当处于某种状态时是，外部View响应，当处于另一种状态时，内部View响应。根据这个规则对滑动进行相应的处理。

#### 3. 场景3的处理规则
对于场景3来说，它的滑动规则更复杂，和场景2一样，它也无法根据滑动的角度，距离差和速度差来判断，同样只能通过业务上找到突破点。


### 五. 滑动冲突的解决方式
针对滑动冲突，一般有两种解决方案，即内部拦截法和外部拦截法

#### 1. 外部拦截法
**思路**
外部拦截是指点击事件都要经过父容器的拦截处理，如果父容器需要次事件则拦截，如果不需要则不拦截。这种方法比较符合点击事件的分发机制。外部拦截法需要重写父容器的onInterceptTouchEvent方法，在内部做相应的拦截即可。
**伪代码**
```
    @Override
    public boolean onInterceptTouchEvent(MotionEvent ev) {
        boolean intercepted = false;

        int x = (int) ev.getX();
        int y = (int) ev.getY();
        switch (ev.getAction()){
            case MotionEvent.ACTION_DOWN:{
                intercepted = false;
                break;
            }
            case MotionEvent.ACTION_MOVE:{
                if(父容器需要当前点击事件){
                    intercepted = true;
                }else {
                    intercepted = false;
                }
            }
            case MotionEvent.ACTION_UP:{
                intercepted = false;
                break;
            }
            default:
                break;
        }
        mLastXIntercept = x;
        mLastYIntercept = y;
        return intercepted;
    }

```

**解释**
上面就是外部拦截法的典型逻辑，针对不同的滑动冲突，只需要修改当前点击事件这个条件即可。

在onInterceptTouchEvent方法中，首先是ACTION_DOWN这个事件，父容器必须返回false，即不拦截ACTION_DOWN,这是因为一旦父容器拦截ACTION _DOWM,那么后续的ACTION_MOVE和ACTION_UP事件都会直接交给父容器处理。其次ACTION_MOVE事件，这个事件可以根据需求是否拦截。最后是ACTION_UP事件，这里必须返回false,因为ACTION_UP事件本身没有太多意义。


#### 2. 内部拦截法
**思路**
内部拦截是指父容器不拦截任何事件，所有的事件都传递给子元素，如果子元素需要此事件就直接消耗掉，否则就交由父容器进行处理，这种方法和Android的事件分发机制不一样，需要配合requestDisallowInterceptTouchEvent方法才能运作。

**伪代码**
重写子元素的dispatchTouchEvent方法:
```
@Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        int x = (int) event.getX();
        int y = (int) event.getY();

        switch (event.getAction()){
            case MotionEvent.ACTION_DOWN:{
                parent.requestDisallowInterceptTouchEvent(true);
                break;
            }
            case MotionEvent.ACTION_MOVE:{
                int daltaX = x - nLastX;
                int daltaY = y - mLastY;
                if(父容器需要此点击事件){
                    parent.requestDisallowInterceptTouchEvent(false);
                }
                break;
            }
            case MotionEvent.ACTION_UP;{
                break;
            }
        }
        mLastX = x;
        mLsatY = y;
        return super.dispatchTouchEvent(event);
    }
```
重写父元素的onInterceptTouchEvent方法
```
   @Override
    public boolean onInterceptTouchEvent(MotionEvent ev) {
        int action = ev.getAction();
        if(action == MotionEvent.ACTION_DOWN){
            return false;
        }else {
            return true;
        }
    }
```
**解释**  
上面就是内部拦截法的典型逻辑，针对不同的滑动冲突，只需要修改当前点击事件这个条件即可。

在内部拦截法中，父元素要默认拦截除ACTION_DOWN以外的其他事件，这样当子元素调用parent.requestDisallowInterceptTouchEvent(false)方法时，父元素才能继续拦截所需的事件。、

父元素不能拦截ACTION_DOWN事件原因是，ACTION_DOWN不受FLAG_DISALLOW_DOWN这个标志位控制，所以一旦父容器拦截ACTION_DOWN事件，那么所有事件都无法传递给子元素。
### 六. 实例
关于滑动冲突解决的例子，推荐一篇博客
[android滑动冲突的解决方案](https://blog.csdn.net/a992036795/article/details/51735501)
### 七.参考资料
《Android艺术开发探索》
