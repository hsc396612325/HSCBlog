# Android之View篇6————仿陌陌卡片左右滑动选择控件
### 一.目录
@[toc]
### 二.效果图
![这里写图片描述](https://img-blog.csdn.net/20180801121016572?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzM4NDk5ODU5/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
### 三.业务需求梳理
1. 卡片随着手指的移动进行移动
2. 卡片在移动过程中，随着距离的加大，卡片绕z轴旋转
3. 判断手指的移动方向，显示选择/删除图标，同时图标随距离的增大，透明度增加
4. 手指离开卡片后，根据移动的距离，判断卡片是否移出屏幕，从左边移动还是右边移动
5. 显示的卡片移出完后，增加新的卡片。
6. 显示的4张卡片，需要展示出卡片的层次感

### 四.思路分析
根据上面的业务逻辑梳理，明显可以知道，实现该功能需要自定义两个View，一个是卡片View（TinderCardView），一个是卡片的容器（TinderStackLayout）。

需求1,2,3都是手指移动过程中发生，即MotionEvent的ACTION_MOVE事件中。
> MotionEvent 这一块不知道的可以看我前面写的博客[Android之View篇2————View的事件分发](https://blog.csdn.net/qq_38499859/article/details/80528275)

需求4是在手指离开屏幕后中发生的，即MotionEvent的MotionEvent.ACTION_UP事件中

需求5是卡片动画结束后，判断剩余卡片数量，选择是否要加载新的卡片

需求6是加载新卡片时，要求实现的。

#### 1. 新建TinderCardView类，并继承FrameLayout
**a.TinderCardView即展示信息的卡片类，重写其onTouch方法**
```
    @Override
    public boolean onTouch(final View view, MotionEvent motionEvent) {
        TinderStackLayout tinderStackLayout = ((TinderStackLayout) view.getParent());
        TinderCardView topCard = (TinderCardView) tinderStackLayout.getChildAt(tinderStackLayout.getChildCount() - 1);
        if (topCard.equals(view)) {
            switch (motionEvent.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    downX = motionEvent.getX();
                    downY = motionEvent.getY();
                    view.clearAnimation();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    newX = motionEvent.getX();
                    newY = motionEvent.getY();
                    dX = newX - downX; //手指移动距离
                    dY = newY - downY;
                    float posX = view.getX() + dX;
                    view.setX(view.getX() + dX);  //view的新距离 需求1，卡片随手指的移动而移动
                    view.setY(view.getY() + dY);

                    float rotation = (CARD_ROTATION_DEGREES * (posX)) / screenWidth;
                    int halfCardHeight = (view.getHeight() / 2);
                    if (downY < halfCardHeight - (2 * padding)) {
                        view.setRotation(rotation);  //设置View在Z轴上的旋转角度 需求2，卡片移动过程中，随距离的增大而，选择角度增大
                    } else {
                        view.setRotation(-rotation);
                    }
                    float alpha = (posX - padding) / (screenWidth * 0.3f);
                    if (alpha > 0) { //需求3, 判断手指的移动方向，显示选择/删除图标，同时图标随距离的增大，透明度增加
                        iv_tips.setAlpha(alpha);
                        iv_tips.setImageResource(R.drawable.ic_like);
                    } else {
                        iv_tips.setAlpha(-alpha);
                        iv_tips.setImageResource(R.drawable.ic_nope);

                    }

                    return true;
                case MotionEvent.ACTION_UP:  //需求4. 手指离开卡片后，根据移动的距离，判断卡片是否移出屏幕，从左边移动还是右边移动
                    if (isBeyondLeftBoundary(view)) {
                        removeCard(view, -(screenWidth * 2)); //移动view.向左边移出屏幕
                    } else if (isBeyondRightBoundary(view)) {
                        removeCard(view, (screenWidth * 2));

                    } else {
                        resetCard(view); //复原view
                    }


                    return true;
                default:
                    return super.onTouchEvent(motionEvent);
            }
        }
        return super.onTouchEvent(motionEvent);

    }
```
**b.判断是否左右移动距离是否达到要求**
```
private boolean isBeyondLeftBoundary(View view) {
        return (view.getX() + (view.getWidth() / 2) < leftBoundary);
    }

    private boolean isBeyondRightBoundary(View view) {
        return (view.getX() + (view.getWidth() / 2) > rightBoundary);
    }
```

c.卡片移出屏幕和复原动画
```
 private void removeCard(final View view, int xPos) { //移出屏幕动画
        view.animate()
                .x(xPos) //x轴移动距离
                .y(0) //y轴移动距离
                .setInterpolator(new AccelerateInterpolator())  //插值器   在动画开始的地方速率改变比较慢，然后开始加速
                .setDuration(DURATIONTIME) //移动距离
                .setListener(new Animator.AnimatorListener() { //监听
                    @Override
                    public void onAnimationStart(Animator animator) {

                    }

                    @Override
                    public void onAnimationEnd(Animator animator) {//移出后回调
                        ViewGroup viewGroup = (ViewGroup) view.getParent();

                        if (viewGroup != null) {
                            viewGroup.removeView(view);

                            int count = viewGroup.getChildCount();
                            if (count == 1 && listener != null) {  //需求5，增加新卡片
                                listener.onLoad();
                            }
                        }


                    }

                    @Override
                    public void onAnimationCancel(Animator animator) {

                    }

                    @Override
                    public void onAnimationRepeat(Animator animator) {

                    }
                });
    }


    private void resetCard(final View view) { //还原动画

        view.animate()
                .x(0) //x轴移动
                .y(0) //y轴移动
                .rotation(0) //循环次数
                .setInterpolator(new OvershootInterpolator()) //插值器       向前甩一定值后再回到原来位置
                .setDuration(DURATIONTIME);
        iv_tips.setAlpha(0f); //图标隐藏

    }
```

#### 2. 新建TinderStackLayout 类，并继承FrameLayout
**a.数据的初始化添加**
```
 public void setDatas(List<User> list) { //提供给activity调用
        this.mList = list;
        if (mList == null) {
            return;
        }
        for (int i = index; index < i + STACK_SIZE; index++) {
            tc = new TinderCardView(getContext());
            tc.bind(mList.get(index));
            tc.setOnLoadMoreListener(this);
            addCard(tc);
        }
    }

  private void addCard(TinderCardView view) {
        int count = getChildCount();
        addView(view, 0, params);
        float scaleX = 1 - (count / BASESCALE_X_VALUE);
        view.animate()
                .x(0)
                .y(count * scaleY)  //需求6，实现层次感
                .scaleX(scaleX)  //水平缩放比例
                .setInterpolator(new AnticipateOvershootInterpolator())
                .setDuration(DURATIONTIME);
    }
```
**b.实现接口onLoad() 供TinderCardView类调用**
```
@Override
    public void onLoad() {  //当显示卡片数量==1时，TinderCardView调用该方法添加新卡片
        for (int i = index; index < i + (STACK_SIZE - 1); index++) {
            if (index == mList.size()) {
                return;
            }
            tc = new TinderCardView(getContext());
            tc.bind(mList.get(index));
            tc.setOnLoadMoreListener(this);
            addCard(tc);
        }
        int childCount = getChildCount();
        for (int i = childCount - 1; i >= 0; i--) {
            TinderCardView tinderCardView = (TinderCardView) getChildAt(i);
            if (tinderCardView != null) {
                float scaleValue = 1 - ((childCount - 1 - i) / 50.0f);
                tinderCardView.animate()
                        .x(0)
                        .y((childCount - 1 - i) * scaleY)
                        .scaleX(scaleValue)
                        .rotation(0)
                        .setInterpolator(new AnticipateOvershootInterpolator())
                        .setDuration(DURATIONTIME);
            }
        }
    }
```
### 五.源码地址
[点位查看源码](https://github.com/hsc396612325/Blog/tree/master/text22/TinderStackView)
