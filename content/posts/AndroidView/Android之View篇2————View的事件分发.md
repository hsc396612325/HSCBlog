# Android之View篇1————View的事件分发

### 一.目录
@[toc]
### 二.事件分发的基础认识
#### 1. 事件分发是什么 
事件分发就是对MotionEvent事件进行分发的过程，即当一个MotionEvent产生后，系统需要把这个事件传递(处理)给一个具体的View，这个过程就是分发过程。
#### 2. 事件分发的简单过程
当一个点击事件产生后，一般顺序事件先传递到Activity，在传到ViewGroup，最终传到View。

#### 3. 事件分发涉及的方法
|方法|作用|调用时刻|返回值|
|-------------|:---|:---|:---|
|dispathchTouchEvent|分发(传递)点击事件|事件传递给当前View时被调用|表示是否消耗当前事件|
|onTouchEvent|处理点击事件|在dispathchTouchEvent内部调用|表示是否消耗当前事件|
|onInterceptTouchEvent(只存在于ViewGroup)|判断是否拦截某个事件|在ViewGroup的dispatchTouchEvent（）内部调用|表示是否拦截当前事件|

三者之间的关系可以用下面的伪代码表示
```java
//在一个ViewGroup中
public boolen dispatchTouchEvent（）{
	boolen consume = false；
	if(onInterceptTouchEvent){  
		consume = onTouchEvent(ev); //如果被拦截，调用当前viewGroup的onTouchEvent
	}else{
		consume = child.dispatchTouchEvent(); //如果未被拦截，调用当前的子view的dispatchTouchEvent，即事件传递给子view
	}
	return consume;
}
```
### 三.图解事件分发
#### 1. 图示事件分发 (ACTION_DOWN)
![这里写图片描述](https://img-blog.csdn.net/20180530201419741?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
#### 2. 图示事件分发的说明 
* 图分为3层，从上向下以此为Activity，ViewGroup，View
* 箭头中间的值代表方法返回值，（return true，return false ，return super.xxxx）,super意思是调用父类实现。
* dispatchTouchEvent和 onTouchEvent 对应的消费表示的意思是，该事件就此消费，不会继续往别的地方传来，事件终止。
* 上面图的事件是针对ACTION_DOWN的，对于ACTION_MOVE和ACTION_UP我们最后做分析。
#### 3. 图示事件分发的结论
**1.如果整个事件不被中断，那么整个事件就是一个类U型图。**
如果我们没有对控件里面的方法进行重写或者改变返回值。而直接调用super调用父类的默认实现，那么整个事件如下图所示。(前提:子Veiw都不消耗事件，即默认不可点击）
![这里写图片描述](https://img-blog.csdn.net/20180530202742502?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

**2. dispatchTouchEvent 和 onTouchEvent 一旦return true,事件就停止传递了（到达终点）**
如下图所示，只有return turn事件就不会继续传下去，也就是我们常说的事件被消费了。
![这里写图片描述](https://img-blog.csdn.net/20180530203229421?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

**3.dispatchTouchEvent和onTouchEven一旦return false事件都会回传给父控件onTouchEvent**
如下图所示，触Activity外，一旦进行了return false，都将事件传递给了父控件的onTouchEvent。

*  对于dispatchTouchEvent 返回false的含义：事件停止往子View传递和分发，同时开始往父控件回溯。
*  对于onTouchEvent返回false的含义:表示当前View不消耗次事件，并且让事件继续往父空间的方向流动，
![这里写图片描述](https://img-blog.csdn.net/20180530204523521?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

**4.onInterceptTouchEvent 的作用**
Intercept表示拦截，在ViewGroup进行分发是，会询问拦截器是否需要拦截。

* return false：不拦截，继续向子View传递事件
* return ture: 拦截，自己对事件进行处理，将事件传递给自己的onTouchEvebt。
* super：默认情况下不拦截，继续向子View传递事件
![这里写图片描述](https://img-blog.csdn.net/20180530205350426?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

#### 4. 关于ACTION_MOVE 和 ACTION_UP
**上面的讲解都是针对的ACTION_DOWN**,ACTION_MOVE和ACTION_UP和ACTION_DOWN在传递过程中和ACTION_DOWN并不相同。

简单来说，只有前一个事件返回了true时，才会收到ACTION_MOVE和ACTION_UP的事件。并且而最终会将ACTION_MOVE和ACTION_UP分发到消费到ACTION_DOWN的View手中。在分发的过程中，**ACTION_MOVE和ACTION_UP与ACTION_DOWN分发的路线可能不回完全相同**。

例如:
红色的箭头代表ACTION_DOWN 事件的流向
蓝色的箭头代表ACTION_MOVE 和 ACTION_UP 事件的流向
![在这里插入图片描述](https://img-blog.csdnimg.cn/20190613200417244.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5,size_16,color_FFFFFF,t_70)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20190613200515673.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5,size_16,color_FFFFFF,t_70)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20190613200546590.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5,size_16,color_FFFFFF,t_70)
### 四.事件分发的源码
从上面的图示分析，事件分发其实包含了三部分的事件分发，即:

* Activity的事件分发
* ViewGroup的事件分发
* View的事件分发。
所以要充分理解事件分发，要看上述这三块关于事件分发的处理。
#### 1. Activity的事件分发机制
当一个点击事件发生后，事件先传递到Activity的dispatchTouchEvent。
**源码分析**
```java
   /**
     * 源码分析Activity的dispatchTouchEvent方法
     */
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (ev.getAction() == MotionEvent.ACTION_DOWN) {
            //分析1
            onUserInteraction();
        }

        //分析2
        if (getWindow().superDispatchTouchEvent(ev)) {

            //如果getWindow().superDispatchTouchEvent(ev)返回ture
            //如果Activity的dispatchTouchEvent方法返回true/false，则事件分发结束，不会调用ctivity.onTouchEvent

            return true;
        }
        //分析4
        return onTouchEvent(ev);
    }

    /**
     * 分析1:Activity.1onUserInteraction()
     * 空方法
     */
    public void onUserInteraction() {
    }

    /**
     * 分析2:PhoneWindow.superDispatchTouchEvent
     * 说明1:
     *      1.getWindow()获得是Window的抽象类
     *      2.而window的唯一实现就是PhoneWindow
     */
    public boolean superDispatchTouchEvent(MotionEvent event) {

        //Decor即是DecorView，所以honeWindow将事件传递给了DecorView
        return mDecor.superDispatchTouchEvent(event);
        //分析3
    }

    /**
     *  分析3:DecorView.superDispatchTouchEvent()
     *  说明:
     *      1.DecorView是顶级View
     *      2.DecorView继承自FrameLayout
     *      3.FrameLayout继承子ViewGroup，所以DecorView的间接父类就是ViewGroup
     */
    public boolean superDispatchTouchEvent(MotionEvent event) {
        return super.dispatchTouchEvent(event);
        // super.dispatchTouchEvent(event); -->等于开始调用ViewGroup的方法，详见下面的ViewGroup源码
    }

    /**
     *  分析4 Activity.onTouchEvent方法
     */
    public boolean onTouchEvent(MotionEvent event) {
        //如果子view消费当前事件时
        //分析5
        if (mWindow.shouldCloseOnTouch(this, event)) {
            finish();
            return true;
        }

        return false;
    }


    /**
     * 分析5 Window.shouldCloseOnTouch方法
     */
    public boolean shouldCloseOnTouch(Context context, MotionEvent event) {
        // 主要是对于处理边界外点击事件的判断：是否是DOWN事件，event的坐标是否在边界内等
        if (mCloseOnTouchOutside && event.getAction() == MotionEvent.ACTION_DOWN
                && isOutOfBounds(context, event) && peekDecorView() != null) {
            return true;
        }
        return false;
        // 返回true：说明事件在边界外，即 消费事件
        // 返回false：未消费（默认）
    }
    // 回到分析4调用原处
```
**总结**
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtZjhmZGE3NmJiZGFkN2I5Ni5wbmc?x-oss-process=image/format,png)

总的来说:Activity的dispatchTouchEvent调用到了ViewGroup的dispatchTouchEvent方法。即:默认情况下Activity的dispatchTouchEvent调用ViewGroup的dispatchTouchEvent方法，而无论dispatchTouchEvent返回什么都结束分发
#### 2. ViewGroup的事件分发机制
**ViewGroup的 dispatchTouchEvent。**
```java
   @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (mInputEventConsistencyVerifier != null) {
            mInputEventConsistencyVerifier.onTouchEvent(ev, 1);
        }

        boolean handled = false;
        if (onFilterTouchEventForSecurity(ev)) { // view没有被遮罩，一般都成立
            final int action = ev.getAction();
            final int actionMasked = action & MotionEvent.ACTION_MASK;

            // Handle an initial down.
            if (actionMasked == MotionEvent.ACTION_DOWN) { // 一堆touch事件（从按下到松手）中的第一个down事件
                // Throw away all previous state when starting a new touch gesture.
                // The framework may have dropped the up or cancel event for the previous gesture
                // due to an app switch, ANR, or some other state change.
                cancelAndClearTouchTargets(ev);
                resetTouchState(); // 作为新一轮的开始，reset所有相关的状态
            }

            // Check for interception.
            final boolean intercepted; // 检查是否要拦截
            //mFirstTouchTarget :当时间有子元素成功处理后，mFirstTouchTarget会被赋值并指向子元素。
            //mFirstTouchTarget!=null 即表示ViewGroup表示未拦截当前事件，
            if (actionMasked == MotionEvent.ACTION_DOWN // down事件
                    || mFirstTouchTarget != null) { // 或者之前的某次事件已经经由此ViewGroup派发给children后被处理掉了

                //FLAG_DISALLOW_INTERCEPT设置后，ViewGroup无法栏除ACTION_DOWN之外的其他点击直接。
                //原因:在ViewGroup分发事件时，如果是ACTION_DOWN,会重置这个标志位
                //设置方法: requestDisallowInterceptTouchEvent
                final boolean disallowIntercept = (mGroupFlags & FLAG_DISALLOW_INTERCEPT) != 0;
                if (!disallowIntercept) { // 只有允许拦截才执行onInterceptTouchEvent方法
                    intercepted = onInterceptTouchEvent(ev); // 默认返回false，不拦截
                    ev.setAction(action); // restore action in case it was changed
                } else {
                    intercepted = false; // 不允许拦截的话，直接设为false
                }
            } else {
                // There are no touch targets and this action is not an initial down
                // so this view group continues to intercept touches.
                // 在这种情况下，actionMasked != ACTION_DOWN && mFirstTouchTarget == null
                // 第一次的down事件没有被此ViewGroup的children处理掉（要么是它们自己不处理，要么是ViewGroup从一
                // 开始的down事件就开始拦截），则接下来的所有事件
                // 也没它们的份，即不处理down事件的话，那表示你对后面接下来的事件也不感兴趣
                intercepted = true; // 这种情况下设置ViewGroup拦截接下来的事件
            }

            // Check for cancelation.
            //检查CANCEL事件
            final boolean canceled = resetCancelNextUpFlag(this)
                    || actionMasked == MotionEvent.ACTION_CANCEL; // 此touch事件是否取消了

            // Update list of touch targets for pointer down, if needed.
            // 是否拆分事件，3.0(包括)之后引入的，默认拆分
            final boolean split = (mGroupFlags & FLAG_SPLIT_MOTION_EVENTS) != 0;
            TouchTarget newTouchTarget = null; // 接下来ViewGroup判断要将此touch事件交给谁处理
            boolean alreadyDispatchedToNewTouchTarget = false;
            if (!canceled && !intercepted) { // 没取消也不拦截，即是个有效的touch事件
                if (actionMasked == MotionEvent.ACTION_DOWN // 第一个手指down
                        || (split && actionMasked == MotionEvent.ACTION_POINTER_DOWN) // 接下来的手指down
                        || actionMasked == MotionEvent.ACTION_HOVER_MOVE) {
                    final int actionIndex = ev.getActionIndex(); // always 0 for down
                    final int idBitsToAssign = split ? 1 << ev.getPointerId(actionIndex)
                            : TouchTarget.ALL_POINTER_IDS;

                    // Clean up earlier touch targets for this pointer id in case they
                    // have become out of sync.
                    removePointersFromTouchTargets(idBitsToAssign);

                    final int childrenCount = mChildrenCount;
                    if (newTouchTarget == null && childrenCount != 0) { // 基本都成立
                        final float x = ev.getX(actionIndex);
                        final float y = ev.getY(actionIndex);
                        // Find a child that can receive the event.
                        // Scan children from front to back.
                        final View[] children = mChildren;

                        final boolean customOrder = isChildrenDrawingOrderEnabled();
                        // 从最后一个向第一个找
                        for (int i = childrenCount - 1; i >= 0; i--) {
                            final int childIndex = customOrder ?
                                    getChildDrawingOrder(childrenCount, i) : i;
                            final View child = children[childIndex];
                            if (!canViewReceivePointerEvents(child)
                                    || !isTransformedTouchPointInView(x, y, child, null)) {
                                continue; // 不满足这2个条件直接跳过，看下一个child
                            }

                            // child view能receive touch事件而且touch坐标也在view边界内

                            newTouchTarget = getTouchTarget(child);// 查找child对应的TouchTarget
                            if (newTouchTarget != null) { // 比如在同一个child上按下了多跟手指
                                // Child is already receiving touch within its bounds.
                                // Give it the new pointer in addition to the ones it is handling.

                                //子View已经在自己的范围内得到了触摸。
                                //除了它正在处理的那个，给它一个新的指针。
                                newTouchTarget.pointerIdBits |= idBitsToAssign;
                                break; // newTouchTarget已经有了，跳出for循环
                            }

                            resetCancelNextUpFlag(child);
                            // 将此事件交给child处理
                            // 有这种情况，一个手指按在了child1上，另一个手指按在了child2上，以此类推
                            // 这样TouchTarget的链就形成了
                            //进行子View的分发
                            if (dispatchTransformedTouchEvent(ev, false, child, idBitsToAssign)) {
                                // Child wants to receive touch within its bounds.
                                mLastTouchDownTime = ev.getDownTime();
                                mLastTouchDownIndex = childIndex;
                                mLastTouchDownX = ev.getX();
                                mLastTouchDownY = ev.getY();
                                // 如果处理掉了的话，将此child添加到touch链的头部
                                // 注意这个方法内部会更新 mFirstTouchTarget
                                newTouchTarget = addTouchTarget(child, idBitsToAssign);
                                alreadyDispatchedToNewTouchTarget = true; // down或pointer_down事件已经被处理了
                                break; // 可以退出for循环了。。。
                            }
                        }
                    }

                    // 本次没找到newTouchTarget但之前的mFirstTouchTarget已经有了
                    if (newTouchTarget == null && mFirstTouchTarget != null) {
                        // Did not find a child to receive the event.
                        // Assign the pointer to the least recently added target.
                        newTouchTarget = mFirstTouchTarget;
                        while (newTouchTarget.next != null) {
                            newTouchTarget = newTouchTarget.next;
                        }
                        // while结束后，newTouchTarget指向了最初的TouchTarget
                        newTouchTarget.pointerIdBits |= idBitsToAssign;
                    }
                }
            }
            // 非down事件直接从这里开始处理，不会走上面的一大堆寻找TouchTarget的逻辑
            // Dispatch to touch targets.
            if (mFirstTouchTarget == null) {
                // 没有children处理则派发给自己处理
                // No touch targets so treat this as an ordinary view.
                handled = dispatchTransformedTouchEvent(ev, canceled, null,
                        TouchTarget.ALL_POINTER_IDS);
            } else {
                // Dispatch to touch targets, excluding the new touch target if we already
                // dispatched to it.  Cancel touch targets if necessary.
                TouchTarget predecessor = null;
                TouchTarget target = mFirstTouchTarget;
                while (target != null) { // 遍历TouchTarget形成的链表
                    final TouchTarget next = target.next;
                    if (alreadyDispatchedToNewTouchTarget && target == newTouchTarget) {
                        handled = true; // 已经处理过的不再让其处理事件
                    } else {
                        // 取消child标记
                        final boolean cancelChild = resetCancelNextUpFlag(target.child)
                                || intercepted;
                        // 如果ViewGroup从半路拦截了touch事件则给touch链上的child发送cancel事件
                        // 如果cancelChild为true的话
                        if (dispatchTransformedTouchEvent(ev, cancelChild,
                                target.child, target.pointerIdBits)) {
                            handled = true; // TouchTarget链中任意一个处理了则设置handled为true
                        }
                        if (cancelChild) { // 如果是cancelChild的话，则回收此target节点
                            if (predecessor == null) {
                                mFirstTouchTarget = next;
                            } else {
                                predecessor.next = next; // 相当于从链表中删除一个节点
                            }
                            target.recycle(); // 回收它
                            target = next;
                            continue;
                        }
                    }
                    predecessor = target; // 访问下一个节点
                    target = next;
                }
            }

            // Update list of touch targets for pointer up or cancel, if needed.
            if (canceled
                    || actionMasked == MotionEvent.ACTION_UP
                    || actionMasked == MotionEvent.ACTION_HOVER_MOVE) {
                // 取消或up事件时resetTouchState
                resetTouchState();
            } else if (split && actionMasked == MotionEvent.ACTION_POINTER_UP) {
                // 当某个手指抬起时，将其相关的信息移除
                final int actionIndex = ev.getActionIndex();
                final int idBitsToRemove = 1 << ev.getPointerId(actionIndex);
                removePointersFromTouchTargets(idBitsToRemove);
            }
        }

        if (!handled && mInputEventConsistencyVerifier != null) {
            mInputEventConsistencyVerifier.onUnhandledEvent(ev, 1);
        }
        return handled; // 返回处理的结果
    }
```
总结:简单来说，就是ViewGroup会去询问onInterceptTouchEvent(第33行)，是否对该事件进行拦截。默认是不拦截的。如果不拦截，则将事件向子View进行分发(第107行)。

**onInterceptTouchEvent(第33行)源码**
```java
/** 
* 分析1：ViewGroup.onInterceptTouchEvent() 
* 作用：是否拦截事件 * 说明： 
* b. 返回false = 不拦截（默认）
*  */

 public boolean onInterceptTouchEvent(MotionEvent ev) {
        if (ev.isFromSource(InputDevice.SOURCE_MOUSE)
                && ev.getAction() == MotionEvent.ACTION_DOWN
                && ev.isButtonPressed(MotionEvent.BUTTON_PRIMARY)
                && isOnScrollbarThumb(ev.getX(), ev.getY())) {
            return true;
        }
        return false;
    }
```
**dispatchTransformedTouchEvent(ev, false, child, idBitsToAssign)第107行**
```java
    private boolean dispatchTransformedTouchEvent(MotionEvent event, boolean cancel,
            View child, int desiredPointerIdBits) {
        final boolean handled;

       //仅分析核心代码
        // Perform any necessary transformations and dispatch.
        if (child == null) {
            handled = super.dispatchTouchEvent(transformedEvent);
        } else {
            final float offsetX = mScrollX - child.mLeft;
            final float offsetY = mScrollY - child.mTop;
            transformedEvent.offsetLocation(offsetX, offsetY);
            if (! child.hasIdentityMatrix()) {
                transformedEvent.transform(child.getInverseMatrix());
            }

	//分发给子View的dispatchTouchEvent
            handled = child.dispatchTouchEvent(transformedEvent);
        }

        // Done.
        transformedEvent.recycle();
        return handled;
    }
```
**总结：**
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtNmVjMmU4NjRhZjdmZmQzNy5wbmc?x-oss-process=image/format,png)
#### 3. View的事件分发机制
View的dispatchTouchEvent方法
```java
    public boolean dispatchTouchEvent(MotionEvent event) {
        if (mInputEventConsistencyVerifier != null) {
            mInputEventConsistencyVerifier.onTouchEvent(event, 0);
        }

        if (onFilterTouchEventForSecurity(event)) { // 一般都成立
            //noinspection SimplifiableIfStatement
            ListenerInfo li = mListenerInfo;

            //首先判断是否设置OnTouchListener,如果OnTouchListener中的onTouch方法中返回true，那么onTouchEvent就不会被调用，
            if (li != null && li.mOnTouchListener != null && (mViewFlags & ENABLED_MASK) == ENABLED
                    && li.mOnTouchListener.onTouch(this, event)) { // 先在ENABLED状态下尝试调用onTouch方法
                return true; // 如果被onTouch处理了，则直接返回true
            }
            // 从这里我们可以看出，当你既设置了OnTouchListener又设置了OnClickListener，那么当前者返回true的时候，
            // onTouchEvent没机会被调用，当然你的OnClickListener也就不会被触发；另外还有个区别就是onTouch里可以
            // 收到每次touch事件，而onClickListener只是在up事件到来时触发。
            if (onTouchEvent(event)) {
                return true;
            }
        }

        if (mInputEventConsistencyVerifier != null) {
            mInputEventConsistencyVerifier.onUnhandledEvent(event, 0);
        }
        return false; // 上面的都没处理，则返回false
    }
```
View的onTouchEvent
```java
    public boolean onTouchEvent(MotionEvent event) { // View对touch事件的默认处理逻辑
        final int viewFlags = mViewFlags;

        if ((viewFlags & ENABLED_MASK) == DISABLED) { // DISABLED的状态下
            if (event.getAction() == MotionEvent.ACTION_UP && (mPrivateFlags & PFLAG_PRESSED) != 0) {
                setPressed(false); // 复原，如果之前是PRESSED状态
            }
            // A disabled view that is clickable still consumes the touch
            // events, it just doesn't respond to them.
            return (((viewFlags & CLICKABLE) == CLICKABLE || // CLICKABLE或LONG_CLICKABLE的view标记为对事件处理了，
                    (viewFlags & LONG_CLICKABLE) == LONG_CLICKABLE)); // 只不过是以do nothing的方式处理了。
        }

        if (mTouchDelegate != null) {
            if (mTouchDelegate.onTouchEvent(event)) { // 如果有TouchDelegate的话，优先交给它处理
                return true; // 处理了返回true，否则接着往下走
            }
        }

        if (((viewFlags & CLICKABLE) == CLICKABLE || // View能对touch事件响应的前提要么是CLICKABLE要么是LONG_CLICKABLE
                (viewFlags & LONG_CLICKABLE) == LONG_CLICKABLE)) {
            switch (event.getAction()) {
                case MotionEvent.ACTION_UP: // UP事件
                    // 如果外围有可以滚动的parent的话，当按下时会设置这个标志位
                    boolean prepressed = (mPrivateFlags & PFLAG_PREPRESSED) != 0;
                    if ((mPrivateFlags & PFLAG_PRESSED) != 0 || prepressed) { // 按下了或者预按下了
                        // take focus if we don't have it already and we should in
                        // touch mode.
                        boolean focusTaken = false;
                        // 尝试requestFocus()，并将focusToken设置为true
                        if (isFocusable() && isFocusableInTouchMode() && !isFocused()) {
                            focusTaken = requestFocus(); // 能进来这个if，一般都会返回true
                        }

                        if (prepressed) {
                            // The button is being released before we actually
                            // showed it as pressed.  Make it show the pressed
                            // state now (before scheduling the click) to ensure
                            // the user sees it.
                            // 在前面down事件的时候我们延迟显示view的pressed状态
                            setPressed(true); // 直到up事件到来的时候才显示pressed状态
                        }

                        if (!mHasPerformedLongPress) { // 如果没有长按发生的话
                            // This is a tap, so remove the longpress check
                            removeLongPressCallback(); // 移除长按callback

                            // Only perform take click actions if we were in the pressed state
                            if (!focusTaken) { // 看到没，focusTaken是false才会进入下面的if语句
                                // Use a Runnable and post this rather than calling
                                // performClick directly. This lets other visual state
                                // of the view update before click actions start.
　　　　　　　　　　　　            // 也就是说在touch mode下，不take focus的view第一次点击的时候才会触发onClick事件
                                if (mPerformClick == null) {
                                    mPerformClick = new PerformClick();
                                }
                                if (!post(mPerformClick)) { // 如果post失败了，则直接调用performClick()方法
                                    performClick(); // 这2行代码会触发onClickListener
                                }
                            }
                        }

                        if (mUnsetPressedState == null) {
                            mUnsetPressedState = new UnsetPressedState(); // unset按下状态的
                        }

                        if (prepressed) {
                            postDelayed(mUnsetPressedState,
                                    ViewConfiguration.getPressedStateDuration());
                        } else if (!post(mUnsetPressedState)) {
                            // If the post failed, unpress right now
                            mUnsetPressedState.run();
                        }
                        removeTapCallback();
                    }
                    break;

                case MotionEvent.ACTION_DOWN: // DOWN事件
                    mHasPerformedLongPress = false;

                    if (performButtonActionOnTouchDown(event)) {
                        break;
                    }

                    // Walk up the hierarchy to determine if we're inside a scrolling container.
                    boolean isInScrollingContainer = isInScrollingContainer();

                    // For views inside a scrolling container, delay the pressed feedback for
                    // a short period in case this is a scroll.
                    if (isInScrollingContainer) { // 如果是在可以滚动的container里面的话
                        mPrivateFlags |= PFLAG_PREPRESSED; // 设置PREPRESSED标志位
                        if (mPendingCheckForTap == null) {
                            mPendingCheckForTap = new CheckForTap();
                        } // 延迟pressed feedback
                        postDelayed(mPendingCheckForTap, ViewConfiguration.getTapTimeout());
                    } else {
                        // Not inside a scrolling container, so show the feedback right away
                        setPressed(true); // 否则直接显示pressed feedback
                        checkForLongClick(0); // 并启动长按监测
                    }
                    break;

                case MotionEvent.ACTION_CANCEL: // 针对CANCEL事件的话，恢复各种状态，移除各种callback
                    setPressed(false);
                    removeTapCallback();
                    removeLongPressCallback();
                    break;

                case MotionEvent.ACTION_MOVE: // MOVE事件
                    final int x = (int) event.getX();
                    final int y = (int) event.getY();

                    // Be lenient about moving outside of buttons
                    if (!pointInView(x, y, mTouchSlop)) { // 如果移动到view的边界之外了，
                        // Outside button
                        removeTapCallback(); // 则取消Tap callback，这样当你松手的时候onClick不会被触发
                        if ((mPrivateFlags & PFLAG_PRESSED) != 0) { // 当已经是按下状态的话
                            // Remove any future long press/tap checks
                            removeLongPressCallback(); // 移除长按callback

                            setPressed(false); // 恢复按下状态
                        }
                    }
                    break;
            }
            return true; // 最后返回true，表示对touch事件处理过了，消费了
        }

        return false; // 既不能单击也不能长按的View，返回false，表示不处理touch事件
    }
```
**总结:**
![这里写图片描述](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy85NDQzNjUtNmVjMmU4NjRhZjdmZmQzNy5wbmc?x-oss-process=image/format,png)
### 五.事件分发的总结

1. 同一事件序列是指从手指接触到屏幕的那一刻起，到手指离开的屏幕的那一瞬间结束，在这个过程中所产生的一系列的事件，这个事件以down事件开始，中间含有数量不等的move事件，最终以up事件结束
2. 正常情况下，一个事件序列只能被一个View拦截且消耗，这一条的原因可以参考(3),因为一旦一个元素拦截了此事件，那么同一事件序列内的所有事件都会直接交给它处理，因此同一个事件序列中的事件不能分别由两个View同时处理，但通过特殊手段可以做到，比如同一个事件序列中的事件不能分别由两个View同时处理，但通过特殊手段/可以做到，比如一个View将本该自己处理的事情通过onTouchEvent强行传递给其他View处理。
3. 某个View一旦决定拦截，那么这一个事件序列都只能由他处理，并且onInterceptTouchEvent都不会在被调用。
4. 某个View如果不消耗ACTION_DOWN事件。那么同一事件序列的其他事件也不会嫁给他，并且把事件重新交给它的父元素处理，即调用父元素的onTouchEvent。
5. ViewGroup默认不拦截任何事件。即源码中onInterceptTouchEvent方法中默认 返回false
6. View没有onIntercept方法，一旦有点击事件传递给他，那么他的onTouchEvent就会被调用
7. View的onTouchEvent默认都会消耗事件，除非他是不可点击事件。（clickbale和longClickable同时为false），Veiw的longClickable默认属性都是false，chickable属性要分情况，比如button的clicjable属性默认是true，而TextView的clickanle的默认属性为fasle。
8. onClick会发生的前提是当前View是可点击的。并且它收到了down和up事件

### 六.参考资料
《Android艺术开发探索》

[Android事件分发机制详解：史上最全面、最易懂](https://www.jianshu.com/p/38015afcdb58)

[图解 Android 事件分发机制](https://www.jianshu.com/p/e99b5e8bd67b)

[Android touch事件处理流程](https://www.cnblogs.com/xiaoweiz/p/3838682.html)

[Android事件分发机制完全解析，带你从源码的角度彻底理解(上)](https://blog.csdn.net/guolin_blog/article/details/9097463)
