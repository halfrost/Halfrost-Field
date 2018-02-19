# Weex 事件传递的那些事儿



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-cc51f3fa785a0464.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>





### 前言

在前两篇文章里面分别谈了 Weex 如何在 Native 端初始化的和 Weex 是如何高效的渲染 Native 的原生 UI 的。Native 这边还缺一块，那就是 Native 产生的一些事件，是怎么传回给 JS 的。这篇文章就详细分析这一部分。



### 目录

- 1.Weex 的事件类型
- 2.Weex 的事件传递


### 一.Weex的事件类型

在 Weex 中，目前最新版本中事件总共分为 4 种类型，通用事件，Appear 事件，Disappear 事件，Page 事件。


在 Weex 的组件里面只包含前三种事件，即通用事件，Appear 事件，Disappear 事件。

当 WXComponent 添加事件的时候，会调用以下函数：

```objectivec


- (void)_addEventOnMainThread:(NSString *)addEventName
{
    WX_ADD_EVENT(appear, addAppearEvent)
    WX_ADD_EVENT(disappear, addDisappearEvent)
    
    WX_ADD_EVENT(click, addClickEvent)
    WX_ADD_EVENT(swipe, addSwipeEvent)
    WX_ADD_EVENT(longpress, addLongPressEvent)
    
    WX_ADD_EVENT(panstart, addPanStartEvent)
    WX_ADD_EVENT(panmove, addPanMoveEvent)
    WX_ADD_EVENT(panend, addPanEndEvent)
    
    WX_ADD_EVENT(horizontalpan, addHorizontalPanEvent)
    WX_ADD_EVENT(verticalpan, addVerticalPanEvent)
    
    WX_ADD_EVENT(touchstart, addTouchStartEvent)
    WX_ADD_EVENT(touchmove, addTouchMoveEvent)
    WX_ADD_EVENT(touchend, addTouchEndEvent)
    WX_ADD_EVENT(touchcancel, addTouchCancelEvent)
    
    [self addEvent:addEventName];
}



```


WX\_ADD\_EVENT 是一个宏：

```objectivec


#define WX_ADD_EVENT(eventName, addSelector) \
if ([addEventName isEqualToString:@#eventName]) {\
    [self addSelector];\
}

```

即是判断待添加的事件 addEventName 的名字和默认支持的事件名字 eventName 是否一致，如果一致，就执行 addSelector 方法。

最后会执行一个 addEvent: 方法，每个组件里面会可以重写这个方法。在这个方法里面做的就是对组件的状态的标识。

比如 WXWebComponent 组件里面的 addEvent: 方法：

```objectivec

- (void)addEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"pagestart"]) {
        _startLoadEvent = YES;
    }
    else if ([eventName isEqualToString:@"pagefinish"]) {
        _finishLoadEvent = YES;
    }
    else if ([eventName isEqualToString:@"error"]) {
        _failLoadEvent = YES;
    }
}


```


在这个方法里面即对 Web 组件里面的状态进行了标识。

接下来就看看这几个组件是怎么识别事件的触发的。


#### 1. 通用事件

在 WXComponent 的定义里，定义了如下和事件相关的变量：

```objectivec

@interface WXComponent ()
{
@package

    BOOL _appearEvent;
    BOOL _disappearEvent;
    UITapGestureRecognizer *_tapGesture;
    NSMutableArray *_swipeGestures;
    UILongPressGestureRecognizer *_longPressGesture;
    UIPanGestureRecognizer *_panGesture;
    
    BOOL _listenPanStart;
    BOOL _listenPanMove;
    BOOL _listenPanEnd;
    
    BOOL _listenHorizontalPan;
    BOOL _listenVerticalPan;
    
    WXTouchGestureRecognizer* _touchGesture;
}


```

上述变量里面就包含有4个手势识别器和1个自定义手势识别器。所以Weex的通用事件里面就包含这5种，点击事件，轻扫事件，长按事件，拖动事件，通用触摸事件。


#### （一）点击事件

首先看点击事件：


```objectivec


    WX_ADD_EVENT(click, addClickEvent)


```

点击事件是通过上面这个宏加到指定视图上的。这个宏上面提到过了。这里直接把宏展开

```objectivec

#define WX_ADD_EVENT(click, addClickEvent) \
if ([addEventName isEqualToString:@“click”]) {\
    [self addClickEvent];\
}

```

如果 addEventName 传进来 event 的是 @“click”，那么就是执行 addClickEvent 方法。

```objectivec

- (void)addClickEvent
{
    if (!_tapGesture) {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onClick:)];
        _tapGesture.delegate = self;
        [self.view addGestureRecognizer:_tapGesture];
    }
}


```


给当前的视图增加一个点击手势，触发的方法是 onClick: 方法。

```objectivec


- (void)onClick:(__unused UITapGestureRecognizer *)recognizer
{
    NSMutableDictionary *position = [[NSMutableDictionary alloc] initWithCapacity:4];
    CGFloat scaleFactor = self.weexInstance.pixelScaleFactor;
    
    if (!CGRectEqualToRect(self.calculatedFrame, CGRectZero)) {
        CGRect frame = [self.view.superview convertRect:self.calculatedFrame toView:self.view.window];
        position[@"x"] = @(frame.origin.x/scaleFactor);
        position[@"y"] = @(frame.origin.y/scaleFactor);
        position[@"width"] = @(frame.size.width/scaleFactor);
        position[@"height"] = @(frame.size.height/scaleFactor);
    }

    [self fireEvent:@"click" params:@{@"position":position}];
}

```

一旦用户点击屏幕，就会触发点击手势，点击手势就会执行上述的 onClick: 方法。在这个方法中，Weex 会计算点击出点击到的视图的坐标以及宽高尺寸。

说到这里就需要提到 Weex 的坐标计算方法了。

#### （1）计算缩放比例因子

在日常 iOS 开发中，开发者使用的计算单位是 pt。

iPhone5 分辨率320pt x 568pt   
iPhone6 分辨率375pt x 667pt  
iPhone6 Plus 分辨率414pt x 736pt  

由于每个屏幕的 ppi 不同(ppi:Pixels Per Inch，即每英寸所拥有的像素数目，屏幕像素密度。)，最终会导致分辨率的不同。




![](http://upload-images.jianshu.io/upload_images/1194012-a02a52ecc0fd8691.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-07d0847d907f8fa9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这也就是我们日常说的@1x，@2x，@3x，目前 iPhone 手机也就3种 ppi

@1x，163ppi（iPhone3gs）  
@2x，326ppi（iPhone4、4s、5、5s、6，6s，7）  
@3x，401ppi（iPhone6+、6s+、7+）  


![](http://upload-images.jianshu.io/upload_images/1194012-7a8ad495c476db65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

px 即 pixels 像素，1px 代表屏幕上一个物理的像素点。

iPhone5 像素640px x 1136px  
iPhone6 像素750px x 1334px  
iPhone6 Plus 像素1242px x 2208px  

而 Weex 的开发中，目前都是用的 px，而且 **Weex 对于长度值目前只支持像素 px 值，还不支持相对单位（em、rem）**。

那么就需要 pt 和 px 的换算了。


在 Weex 的世界里，定义了一个默认屏幕尺寸，用来适配 iOS，Android 各种不同大小的屏幕。

```c

// The default screen width which helps us to calculate the real size or scale in different devices.
static const CGFloat WXDefaultScreenWidth = 750.0;


```

在 Weex 中定义的默认的屏幕宽度是750，注意是宽度。


```objectivec


+ (CGFloat)defaultPixelScaleFactor
{
    static CGFloat defaultScaleFactor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultScaleFactor = [self portraitScreenSize].width / WXDefaultScreenWidth;
    });
    
    return defaultScaleFactor;
}


```

这里计算了一个默认的缩放比例因子，portraitScreenSize 里面计算出了屏幕在 portrait 方向下的大小，即如果方向是 landscape，那么缩放比例因子应该等于 WXScreenSize().height / WXDefaultScreenWidth，反之应该等于 WXScreenSize().width / WXDefaultScreenWidth。


这里计算的是 pt。

iPhone 4、4s、5、5s、5c、SE的比例因子是 0.42666667  
iPhone 6、6s、7比例因子是0.5  
iPhone 6+、6s+、7+比例因子是0.552  


#### （2）计算视图的缩放尺寸

计算视图的缩放尺寸主要在这个方法里面被计算。

```objectivec


- (void)_calculateFrameWithSuperAbsolutePosition:(CGPoint)superAbsolutePosition
                           gatherDirtyComponents:(NSMutableSet<WXComponent *> *)dirtyComponents
{
    if (!_cssNode->layout.should_update) {
        return;
    }
    _cssNode->layout.should_update = false;
    _isLayoutDirty = NO;
    
    // 计算视图的Frame
    CGRect newFrame = CGRectMake(WXRoundPixelValue(_cssNode->layout.position[CSS_LEFT]),
                                 WXRoundPixelValue(_cssNode->layout.position[CSS_TOP]),
                                 WXRoundPixelValue(_cssNode->layout.dimensions[CSS_WIDTH]),
                                 WXRoundPixelValue(_cssNode->layout.dimensions[CSS_HEIGHT]));
    
    BOOL isFrameChanged = NO;
    // 比较newFrame和_calculatedFrame，第一次_calculatedFrame为CGRectZero
    if (!CGRectEqualToRect(newFrame, _calculatedFrame)) {
        isFrameChanged = YES;
        _calculatedFrame = newFrame;
        [dirtyComponents addObject:self];
    }
    
    CGPoint newAbsolutePosition = [self computeNewAbsolutePosition:superAbsolutePosition];
    
    _cssNode->layout.dimensions[CSS_WIDTH] = CSS_UNDEFINED;
    _cssNode->layout.dimensions[CSS_HEIGHT] = CSS_UNDEFINED;
    _cssNode->layout.position[CSS_LEFT] = 0;
    _cssNode->layout.position[CSS_TOP] = 0;
    
    [self _frameDidCalculated:isFrameChanged];
    
    for (WXComponent *subcomponent in _subcomponents) {
        [subcomponent _calculateFrameWithSuperAbsolutePosition:newAbsolutePosition gatherDirtyComponents:dirtyComponents];
    }
}


```

newFrame 就是计算出来的缩放过的 Frame。

如果尝试自己手动计算 Vue.js 上设置的 px 与实际的视图坐标值相比，你会发现永远都差一点，虽然偏差不多，但是总有误差，原因在哪里呢？就在 WXRoundPixelValue 这个函数里面。


```objectivec

CGFloat WXRoundPixelValue(CGFloat value)
{
    CGFloat scale = WXScreenScale();
    return round(value * scale) / scale;
}


```

WXRoundPixelValue 这个函数里面进行了一次四舍五入的计算，这里会对精度有所损失，所以就会导致最终 Native 的组件的坐标会偏差一点。


举个例子：


```javascript


<style>

    .pic{
        width: 200px;
        height: 200px;
        margin-top: 100px;
        left: 200px;
        background-color: #a88859;
    }

</style>



```

这里是一个 imageComponent，坐标是距离上边距 100px，距离左边距 200px，宽 200px，高 200px。

假设我们是在 iPhone 7+ 的屏幕上，ppi 对应的应该是 scale = 3（即@3x）。

按照 Weex 的上述的计算方法算，那么对应缩放的 px 为：

```c

x = 200 * ( 414.0 / 750.0 ) = 110.400000
y = 100 * ( 414.0 / 750.0 ) = 55.200000
width = 200 * ( 414.0 / 750.0 ) = 110.400000
height = 200 * ( 414.0 / 750.0 ) = 110.400000

```

再转换成 pt：

```c

x = round ( 110.400000 * 3 ) / 3 = 110.333333
y = round ( 55.200000 * 3 ) / 3 = 55.333333
width = round ( 110.400000 * 3 ) / 3 = 110.333333
height = round ( 110.400000 * 3 ) / 3 = 110.333333

```

如果只是单纯的认为是针对 750 的成比缩放，那么这里 110.333333 / ( 414.0 / 750.0 ) = 199.87922101，你会发现这个数字距离 200 还是差了零点几。精度就是损失在了 round函数上了


那么当前的 imageComponent 在父视图里面的 Frame = （110.333333，55.333333，110.333333，110.333333）。

回到 onClick: 方法里面。

```objectivec

- (void)onClick:(__unused UITapGestureRecognizer *)recognizer
{
    NSMutableDictionary *position = [[NSMutableDictionary alloc] initWithCapacity:4];
    CGFloat scaleFactor = self.weexInstance.pixelScaleFactor;
    
    if (!CGRectEqualToRect(self.calculatedFrame, CGRectZero)) {
        CGRect frame = [self.view.superview convertRect:self.calculatedFrame toView:self.view.window];
        position[@"x"] = @(frame.origin.x/scaleFactor);
        position[@"y"] = @(frame.origin.y/scaleFactor);
        position[@"width"] = @(frame.size.width/scaleFactor);
        position[@"height"] = @(frame.size.height/scaleFactor);
    }

    [self fireEvent:@"click" params:@{@"position":position}];
}

```

如果点击到视图，就会触发点击手势的处理方法，就会进入到上述方法里。

这里会计算出点击到的视图相对于 window 的绝对坐标。

```objectivec

CGRect frame = [self.view.superview convertRect:self.calculatedFrame toView:self.view.window];

```

上面这句话会进行一个坐标转换。坐标系转换到全局的 window 的左边。


还是按照上面举的例子，如果 imageComponent 经过转换以后，frame = （110.33333333333333, 119.33333333333334, 110.33333333333333, 110.33333333333331），这里就是 y 轴的距离发生了变化，因为就加上了 navigation + statusBar 的64的高度。

计算出了这个 window 绝对坐标之后，还要还原成相对于 750.0 宽度的“尺寸”。这里之所以打引号，就是因为这里有精度损失，在 round 函数那里丢了一些精度。


```c

x = 110.33333333333333 / ( 414.0 / 750.0 ) = 199.8792270531401
y = 119.33333333333334 / ( 414.0 / 750.0 ) = 216.1835748792271
width = 110.33333333333333 / ( 414.0 / 750.0 ) = 199.8792270531401
height = 110.33333333333333 / ( 414.0 / 750.0 ) = 199.8792270531401


```

上述就是点击以后经过转换最终得到的坐标，这个坐标会传递给 JS。




![](http://upload-images.jianshu.io/upload_images/1194012-9bf2beec8ba1fb3f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




#### （二）轻扫事件

接着是轻扫事件。

```objectivec


    WX_ADD_EVENT(swipe, addSwipeEvent)


```

这个宏和上面点击事件的展开原理一样，这里不再赘述。

如果 addEventName 传进来event的是@“swipe”，那么就是执行 addSwipeEvent 方法。

```objectivec

- (void)addSwipeEvent
{
    if (_swipeGestures) {
        return;
    }
    
    _swipeGestures = [NSMutableArray arrayWithCapacity:4];
    

    // 下面的代码写的比较“奇怪”，原因在于UISwipeGestureRecognizer的direction属性，是一个可选的位掩码，但是每个手势识别器又只能处理一个方向的手势，所以就导致了下面需要生成四个UISwipeGestureRecognizer的手势识别器。

    SEL selector = @selector(onSwipe:);

    // 新建一个upSwipeRecognizer
    UISwipeGestureRecognizer *upSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                            action:selector];
    upSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    upSwipeRecognizer.delegate = self;
    [_swipeGestures addObject:upSwipeRecognizer];
    [self.view addGestureRecognizer:upSwipeRecognizer];
    

    // 新建一个downSwipeRecognizer
    UISwipeGestureRecognizer *downSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                              action:selector];
    downSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    downSwipeRecognizer.delegate = self;
    [_swipeGestures addObject:downSwipeRecognizer];
    [self.view addGestureRecognizer:downSwipeRecognizer];
    
    // 新建一个rightSwipeRecognizer
    UISwipeGestureRecognizer *rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                               action:selector];
    rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    rightSwipeRecognizer.delegate = self;
    [_swipeGestures addObject:rightSwipeRecognizer];
    [self.view addGestureRecognizer:rightSwipeRecognizer];
    
    // 新建一个leftSwipeRecognizer
    UISwipeGestureRecognizer *leftSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                              action:selector];
    leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    leftSwipeRecognizer.delegate = self;
    [_swipeGestures addObject:leftSwipeRecognizer];
    [self.view addGestureRecognizer:leftSwipeRecognizer];
}

```

上面会新建4个方向上的手势识别器。因为每个手势识别器又只能处理一个方向的手势，所以就导致了需要生成四个 UISwipeGestureRecognizer 的手势识别器。


给当前的视图增加一个轻扫手势，触发的方法是 onSwipe: 方法。


```objectivec


- (void)onSwipe:(UISwipeGestureRecognizer *)gesture
{
    UISwipeGestureRecognizerDirection direction = gesture.direction;
    
    NSString *directionString;
    switch(direction) {
        case UISwipeGestureRecognizerDirectionLeft:
            directionString = @"left";
            break;
        case UISwipeGestureRecognizerDirectionRight:
            directionString = @"right";
            break;
        case UISwipeGestureRecognizerDirectionUp:
            directionString = @"up";
            break;
        case UISwipeGestureRecognizerDirectionDown:
            directionString = @"down";
            break;
        default:
            directionString = @"unknown";
    }
    
    CGPoint screenLocation = [gesture locationInView:self.view.window];
    CGPoint pageLoacation = [gesture locationInView:self.weexInstance.rootView];
    NSDictionary *resultTouch = [self touchResultWithScreenLocation:screenLocation pageLocation:pageLoacation identifier:gesture.wx_identifier];
    [self fireEvent:@"swipe" params:@{@"direction":directionString, @"changedTouches":resultTouch ? @[resultTouch] : @[]}];
}


```

当用户轻扫以后，会触发轻扫手势，于是会在 window 上和 rootView 上会获取到2个坐标。


```objectivec

- (NSDictionary *)touchResultWithScreenLocation:(CGPoint)screenLocation pageLocation:(CGPoint)pageLocation identifier:(NSNumber *)identifier
{
    NSMutableDictionary *resultTouch = [[NSMutableDictionary alloc] initWithCapacity:5];
    CGFloat scaleFactor = self.weexInstance.pixelScaleFactor;
    resultTouch[@"screenX"] = @(screenLocation.x/scaleFactor);
    resultTouch[@"screenY"] = @(screenLocation.y/scaleFactor);
    resultTouch[@"pageX"] = @(pageLocation.x/scaleFactor);
    resultTouch[@"pageY"] = @(pageLocation.y/scaleFactor);
    resultTouch[@"identifier"] = identifier;
    
    return resultTouch;
}



```

screenLocation 和 pageLocation 两个坐标点，还是会根据缩放比例还原成相对于750宽度的页面的坐标。screenLocation 的 X 值和 Y 值、pageLocation 的 X 值和 Y 值分别封装到 resultTouch 字典里。


```objectivec



@implementation UIGestureRecognizer (WXGesture)

- (NSNumber *)wx_identifier
{
    NSNumber *identifier = objc_getAssociatedObject(self, _cmd);
    if (!identifier) {
        static NSUInteger _gestureIdentifier;
        identifier = @(_gestureIdentifier++);
        self.wx_identifier = identifier;
    }
    
    return identifier;
}

- (void)setWx_identifier:(NSNumber *)wx_identifier
{
    objc_setAssociatedObject(self, @selector(wx_identifier), wx_identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

```

最后 resultTouch 里面还包含一个 identifier 的参数，这个 identifier 是一个全局唯一的 NSUInteger。wx\_identifier 被关联到了各个手势识别器上了。





![](http://upload-images.jianshu.io/upload_images/1194012-d539c86914cdc7ad.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



#### （三）长按事件


接着是轻扫事件。

```objectivec


    WX_ADD_EVENT(longpress, addLongPressEvent)


```

这个宏和上面点击事件的展开原理一样，这里不再赘述。

如果 addEventName 传进来 event 的是 @“longpress”，那么就是执行 addLongPressEvent 方法。

```objectivec

- (void)addLongPressEvent
{
    if (!_longPressGesture) {
        _longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
        _longPressGesture.delegate = self;
        [self.view addGestureRecognizer:_longPressGesture];
    }
}


```

给当前的视图增加一个长按手势，触发的方法是 onLongPress: 方法。


```objectivec


- (void)onLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint screenLocation = [gesture locationInView:self.view.window];
        CGPoint pageLoacation = [gesture locationInView:self.weexInstance.rootView];
        NSDictionary *resultTouch = [self touchResultWithScreenLocation:screenLocation pageLocation:pageLoacation identifier:gesture.wx_identifier];
        [self fireEvent:@"longpress" params:@{@"changedTouches":resultTouch ? @[resultTouch] : @[]}];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        gesture.wx_identifier = nil;
    }
}


```

长按手势传给 JS 的参数和轻扫的参数 changedTouches 几乎一致。在长按手势开始的时候就传递给 JS 两个 Point，screenLocation 和 pageLoacation，以及手势的wx\_identifier。这部分和轻扫手势基本一样，不多赘述。




![](http://upload-images.jianshu.io/upload_images/1194012-f55d817e6397b58d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





#### （四）拖动事件

拖动事件在 Weex 里面包含5个事件。分别对应着拖动的5种状态：拖动开始，拖动中，拖动结束，水平拖动，竖直拖动。

```objectivec

    WX_ADD_EVENT(panstart, addPanStartEvent)
    WX_ADD_EVENT(panmove, addPanMoveEvent)
    WX_ADD_EVENT(panend, addPanEndEvent)
    WX_ADD_EVENT(horizontalpan, addHorizontalPanEvent)
    WX_ADD_EVENT(verticalpan, addVerticalPanEvent)


```

为了区分上面5种状态，Weex 还对每个状态增加了一个 BOOL 变量来判断当前的状态。分别如下：


```objectivec


    BOOL _listenPanStart;
    BOOL _listenPanMove;
    BOOL _listenPanEnd;
    BOOL _listenHorizontalPan;
    BOOL _listenVerticalPan;

```

通过宏增加的5个事件，实质都是执行了 addPanGesture 方法，只不过每个状态的事件都会跟对应的BOOL变量。


```objectivec


- (void)addPanStartEvent
{
   // 拖动开始
    _listenPanStart = YES;
    [self addPanGesture];
}

- (void)addPanMoveEvent
{
   // 拖动中
    _listenPanMove = YES;
    [self addPanGesture];
}

- (void)addPanEndEvent
{
   // 拖动结束
    _listenPanEnd = YES;
    [self addPanGesture];
}

- (void)addHorizontalPanEvent
{
   // 水平拖动
    _listenHorizontalPan = YES;
    [self addPanGesture];
}

- (void)addVerticalPanEvent
{
   // 竖直拖动
    _listenVerticalPan = YES;
    [self addPanGesture];
}


```

最终都是调用addPanGesture方法：

```objectivec


- (void)addPanGesture
{
    if (!_panGesture) {
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        _panGesture.delegate = self;
        [self.view addGestureRecognizer:_panGesture];
    }
}


```

给当前的视图增加一个拖动手势，触发的方法是 onPan: 方法。

```obectivec

- (void)onPan:(UIPanGestureRecognizer *)gesture
{
    CGPoint screenLocation = [gesture locationInView:self.view.window];
    CGPoint pageLoacation = [gesture locationInView:self.weexInstance.rootView];
    NSString *eventName;
    NSString *state = @"";
    NSDictionary *resultTouch = [self touchResultWithScreenLocation:screenLocation pageLocation:pageLoacation identifier:gesture.wx_identifier];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (_listenPanStart) {
            eventName = @"panstart";
        }
        state = @"start";
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        if (_listenPanEnd) {
            eventName = @"panend";
        }
        state = @"end";
        gesture.wx_identifier = nil;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        if (_listenPanMove) {
             eventName = @"panmove";
        }
        state = @"move";
    }
    
    
    CGPoint translation = [_panGesture translationInView:self.view];
    
    if (_listenHorizontalPan && fabs(translation.y) <= fabs(translation.x)) {
        [self fireEvent:@"horizontalpan" params:@{@"state":state, @"changedTouches":resultTouch ? @[resultTouch] : @[]}];
    }
        
    if (_listenVerticalPan && fabs(translation.y) > fabs(translation.x)) {
        [self fireEvent:@"verticalpan" params:@{@"state":state, @"changedTouches":resultTouch ? @[resultTouch] : @[]}];
    }
        
    if (eventName) {
        [self fireEvent:eventName params:@{@"changedTouches":resultTouch ? @[resultTouch] : @[]}];
    }
}


```

拖动事件最终传给 JS 的 resultTouch 字典和前两个手势的原理一样，也是需要传入两个 Point，screenLocation 和 pageLoacation，这里不再赘述。



![](http://upload-images.jianshu.io/upload_images/1194012-7045d54290886db8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





根据 \_listenPanStart，\_listenPanEnd，\_listenPanMove 判断当前的状态，并生成与之对应的 eventName 和 state 字符串。


根据 \_panGesture 在当前视图上拖动形成的有方向的向量，进行判断当前拖动的方向。



![](http://upload-images.jianshu.io/upload_images/1194012-f5bc628a35e0623e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



#### （五）通用触摸事件

最后就是通用的触摸事件。

Weex 里面对每个 Component 都新建了一个手势识别器。

```objectivec

@interface WXTouchGestureRecognizer : UIGestureRecognizer

@property (nonatomic, assign) BOOL listenTouchStart;
@property (nonatomic, assign) BOOL listenTouchMove;
@property (nonatomic, assign) BOOL listenTouchEnd;
@property (nonatomic, assign) BOOL listenTouchCancel;
@property (nonatomic, assign) BOOL listenPseudoTouch;
{
    __weak WXComponent *_component;
    NSUInteger _touchIdentifier;
}

- (instancetype)initWithComponent:(WXComponent *)component NS_DESIGNATED_INITIALIZER;

@end

```

WXTouchGestureRecognizer 是继承自 UIGestureRecognizer。里面就5个 BOOL。分别表示5种状态。

WXTouchGestureRecognizer 会弱引用当前的 WXComponent，并且也依旧有touchIdentifier。



Weex 通过以下4个宏注册触摸事件方法。

```objectivec

    WX_ADD_EVENT(touchstart, addTouchStartEvent)
    WX_ADD_EVENT(touchmove, addTouchMoveEvent)
    WX_ADD_EVENT(touchend, addTouchEndEvent)
    WX_ADD_EVENT(touchcancel, addTouchCancelEvent)

```

通过上述宏增加的4个事件，实质都是改变每个状态的事件都会跟对应的BOOL变量。

```objectivec

- (void)addTouchStartEvent
{
    self.touchGesture.listenTouchStart = YES;
}

- (void)addTouchMoveEvent
{
    self.touchGesture.listenTouchMove = YES;
}

- (void)addTouchEndEvent
{
    self.touchGesture.listenTouchEnd = YES;
}

- (void)addTouchCancelEvent
{
    self.touchGesture.listenTouchCancel = YES;
}


```

当用户开始触摸屏幕，在屏幕上移动，手指从屏幕上结束触摸，取消触摸，分别都会触发touchesBegan:，touchesMoved:，touchesEnded:，touchesCancelled:方法。


```objectivec

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if (_listenTouchStart) {
        [self fireTouchEvent:@"touchstart" withTouches:touches];
    }
    if(_listenPseudoTouch) {
        NSMutableDictionary *styles = [_component getPseudoClassStyles:@"active"];
        [_component updatePseudoClassStyles:styles];
    }

}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    
    if (_listenTouchMove) {
        [self fireTouchEvent:@"touchmove" withTouches:touches];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
    [super touchesEnded:touches withEvent:event];
    
    if (_listenTouchEnd) {
        [self fireTouchEvent:@"touchend" withTouches:touches];
    }
    if(_listenPseudoTouch) {
        [self recoveryPseudoStyles:_component.styles];
    }

}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    if (_listenTouchCancel) {
        [self fireTouchEvent:@"touchcancel" withTouches:touches];
    }
    if(_listenPseudoTouch) {
        [self recoveryPseudoStyles:_component.styles];
    }
}




```

上述的4个事件里面实质都是在调用 fireTouchEvent:withTouches: 方法：

```objectivec

- (void)fireTouchEvent:(NSString *)eventName withTouches:(NSSet<UITouch *> *)touches
{
    NSMutableArray *resultTouches = [NSMutableArray new];
    
    for (UITouch *touch in touches) {
        CGPoint screenLocation = [touch locationInView:touch.window];
        CGPoint pageLocation = [touch locationInView:_component.weexInstance.rootView];
        if (!touch.wx_identifier) {
            touch.wx_identifier = @(_touchIdentifier++);
        }
        NSDictionary *resultTouch = [_component touchResultWithScreenLocation:screenLocation pageLocation:pageLocation identifier:touch.wx_identifier];
        [resultTouches addObject:resultTouch];
    }
    
    [_component fireEvent:eventName params:@{@"changedTouches":resultTouches ?: @[]}];
}

```

最终这个方法和前3个手势一样，都需要给 resultTouches 传入2个Point和1个wx\_identifier。原理一致。

至于坐标如何传递给JS见第二章。

#### 2. Appear 事件

如果一个位于某个可滚动区域内的组件被绑定了 appear 事件，那么当这个组件的状态变为在屏幕上可见时，该事件将被触发。

所以绑定了 Appear 事件的都是可以滚动的视图。



![](http://upload-images.jianshu.io/upload_images/1194012-54c227c43a2d3c20.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





```objectivec


    WX_ADD_EVENT(appear, addAppearEvent)

```

通过上述的宏给可以滚动的视图增加 Appear 事件。也就是当前视图执行 addAppearEvent 方法。


```objectivec

- (void)addAppearEvent
{
    _appearEvent = YES;
    [self.ancestorScroller addScrollToListener:self];
}


```

在 Weex 的每个组件里面都有2个 BOOL 记录着当前 \_appearEvent 和 \_disappearEvent 的状态。

```objectivec

    BOOL _appearEvent;
    BOOL _disappearEvent;

```

当增加对应的事件的时候，就会把对应的 BOOL 变成 YES。

```objectivec

- (id<WXScrollerProtocol>)ancestorScroller
{
    if(!_ancestorScroller) {
        WXComponent *supercomponent = self.supercomponent;
        while (supercomponent) {
            if([supercomponent conformsToProtocol:@protocol(WXScrollerProtocol)]) {
                _ancestorScroller = (id<WXScrollerProtocol>)supercomponent;
                break;
            }
            supercomponent = supercomponent.supercomponent;
        }
    }
    
    return _ancestorScroller;
}

```

由于 Appear 事件和 Disappear 事件都必须要求是滚动视图，所以这里会遍历当前视图的 supercomponent，直到找到一个遵循 WXScrollerProtocol 的 supercomponent。


```objectivec


- (void)addScrollToListener:(WXComponent *)target
{
    BOOL has = NO;
    for (WXScrollToTarget *targetData in self.listenerArray) {
        if (targetData.target == target) {
            has = YES;
            break;
        }
    }
    if (!has) {
        WXScrollToTarget *scrollTarget = [[WXScrollToTarget alloc] init];
        scrollTarget.target = target;
        scrollTarget.hasAppear = NO;
        [self.listenerArray addObject:scrollTarget];
    }
}

```

在滚动视图里面包含有一个 listenerArray，数组里面装的都是被监听的对象。添加进这个数组会先判断当前是否有相同的 WXScrollToTarget，避免重复添加，如果没有重复的就新建一个 WXScrollToTarget，再添加进 listenerArray中。

```objectivec


@interface WXScrollToTarget : NSObject
@property (nonatomic, weak)   WXComponent *target;
@property (nonatomic, assign) BOOL hasAppear;
@end

```

WXScrollToTarget 是一个普通的对象，里面弱引用了当前需要监听的 WXComponent，以及一个 BOOL 变量记录当前是否 Appear 了。


当滚动视图滚动的时候，就会触发 scrollViewDidScroll: 方法。

```objectivec

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    //apply block which are registered
    WXSDKInstance *instance = self.weexInstance;
    if ([self.ref isEqualToString:WX_SDK_ROOT_REF] &&
        [self isKindOfClass:[WXScrollerComponent class]]) {
        if (instance.onScroll) {
            instance.onScroll(scrollView.contentOffset);
        }
    }
    
    if (_lastContentOffset.x > scrollView.contentOffset.x) {
        _direction = @"right";
    } else if (_lastContentOffset.x < scrollView.contentOffset.x) {
        _direction = @"left";
    } else if(_lastContentOffset.y > scrollView.contentOffset.y) {
        _direction = @"down";
    } else if(_lastContentOffset.y < scrollView.contentOffset.y) {
        _direction = @"up";
    }
    
    _lastContentOffset = scrollView.contentOffset;
    
    // check sticky
    [self adjustSticky];
    [self handleLoadMore];
    [self handleAppear];
    
    if (self.onScroll) {
        self.onScroll(scrollView);
    }
}


```

在上面的方法中[self handleAppear]就是触发了判断是否 Appear 了。

```objectivec

- (void)handleAppear
{
    if (![self isViewLoaded]) {
        return;
    }
    UIScrollView *scrollView = (UIScrollView *)self.view;
    CGFloat vx = scrollView.contentInset.left + scrollView.contentOffset.x;
    CGFloat vy = scrollView.contentInset.top + scrollView.contentOffset.y;
    CGFloat vw = scrollView.frame.size.width - scrollView.contentInset.left - scrollView.contentInset.right;
    CGFloat vh = scrollView.frame.size.height - scrollView.contentInset.top - scrollView.contentInset.bottom;
    CGRect scrollRect = CGRectMake(vx, vy, vw, vh);;
    
    // notify action for appear
    for(WXScrollToTarget *target in self.listenerArray){
        [self scrollToTarget:target scrollRect:scrollRect];
    }
}


```

上面这个方法会把 listenerArray 数组里面的每个 WXScrollToTarget 对象都调用 scrollToTarget:scrollRect: 方法。根据当前滚动的情况传入一个 CGRect，这个 CGRect 就是当前滚动到那个矩形区域的坐标信息以及宽和高。

```objectivec

- (void)scrollToTarget:(WXScrollToTarget *)target scrollRect:(CGRect)rect
{
    WXComponent *component = target.target;
    if (![component isViewLoaded]) {
        return;
    }
    
    // 计算出当前的可见区域的顶部坐标
    CGFloat ctop;
    if (component && component->_view && component->_view.superview) {
        ctop = [component->_view.superview convertPoint:component->_view.frame.origin toView:_view].y;
    } else {
        ctop = 0.0;
    }
    // 计算出当前的可见区域的底部坐标
    CGFloat cbottom = ctop + CGRectGetHeight(component.calculatedFrame);
    // 计算出当前的可见区域的左边界坐标
    CGFloat cleft;
    if (component && component->_view && component->_view.superview) {
        cleft = [component->_view.superview convertPoint:component->_view.frame.origin toView:_view].x;
    } else {
        cleft = 0.0;
    }
    // 计算出当前的可见区域的右边界坐标
    CGFloat cright = cleft + CGRectGetWidth(component.calculatedFrame);
    
    // 获取传入的滚动的区域
    CGFloat vtop = CGRectGetMinY(rect), vbottom = CGRectGetMaxY(rect), vleft = CGRectGetMinX(rect), vright = CGRectGetMaxX(rect);
    
    // 判断当前可见区域是否包含在传入的滚动区域内，如果在，并且监听了appear事件，就触发appear事件，否则如果监听了disappear事件就触发disappear事件
    if(cbottom > vtop && ctop <= vbottom && cleft <= vright && cright > vleft){
        if(!target.hasAppear && component){
            target.hasAppear = YES;
            // 如果当前监听了appear，就触发appear事件
            if (component->_appearEvent) {
                [component fireEvent:@"appear" params:_direction ? @{@"direction":_direction} : nil];
            }
        }
    } else {
        if(target.hasAppear && component){
            target.hasAppear = NO;
            // 如果当前监听了disappear，就触发disappear事件
            if(component->_disappearEvent){
                [component fireEvent:@"disappear" params:_direction ? @{@"direction":_direction} : nil];
            }
        }
    }
}


```



![](http://upload-images.jianshu.io/upload_images/1194012-4ce6ab0c48383c8b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




scrollToTarget:scrollRect: 方法的核心就是拿当前可视区域和传入的滚动区域进行对比，如果在该区域内，且监听了 appear 事件，就会触发 appear 事件，如果不在该区域内，且监听了 disappear 事件，就会触发 disappear 事件。

#### 3. Disappear 事件

如果一个位于某个可滚动区域内的组件被绑定了 disappear 事件，那么当这个组件被滑出屏幕变为不可见状态时，该事件将被触发。

同理，绑定了 Disappear 事件的都是可以滚动的视图。




![](http://upload-images.jianshu.io/upload_images/1194012-18f16117ad60e038.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



```objectivec


    WX_ADD_EVENT(disappear, addDisappearEvent)

```

通过上述的宏给可以滚动的视图增加 Disappear 事件。也就是当前视图执行 addDisappearEvent 方法。


```objectivec

- (void)addDisappearEvent
{
    _disappearEvent = YES;
    [self.ancestorScroller addScrollToListener:self];
}


```

接下去的和 Appear 事件的原理就一模一样了。


#### 4. Page 事件


**暂时 Weex 只支持 iOS 和 Android，H5 暂不支持。**

Weex 通过 viewappear 和 viewdisappear 事件提供了简单的页面状态管理能力。

viewappear 事件会在页面就要显示或配置的任何页面动画被执行前触发，例如，当调用 navigator 模块的 push 方法时，该事件将会在打开新页面时被触发。viewdisappear 事件会在页面就要关闭时被触发。

与组件 Component的 appear 和 disappear 事件不同的是，viewappear 和 viewdisappear 事件关注的是整个页面的状态，所以它们必须绑定到页面的根元素上。

特殊情况下，这两个事件也能被绑定到非根元素的 body 组件上，例如 wxc-navpage 组件。

举个例子：

```objectivec

- (void)_updateInstanceState:(WXState)state
{
    if (_instance && _instance.state != state) {
        _instance.state = state;
        
        if (state == WeexInstanceAppear) {
            [[WXSDKManager bridgeMgr] fireEvent:_instance.instanceId ref:WX_SDK_ROOT_REF type:@"viewappear" params:nil domChanges:nil];
        } else if (state == WeexInstanceDisappear) {
            [[WXSDKManager bridgeMgr] fireEvent:_instance.instanceId ref:WX_SDK_ROOT_REF type:@"viewdisappear" params:nil domChanges:nil];
        }
    }
}


```

比如在 WXBaseViewController 里面，有这样一个更新当前 Instance 状态的方法，这个方法里面就会触发 viewappear 和 viewdisappear 事件。


其中 WX\_SDK\_ROOT\_REF 就是 \_root

```objectivec

#define WX_SDK_ROOT_REF     @"_root"

```

上述更新状态的方法同样出现在 WXEmbedComponent 组件中。

```objectivec

- (void)_updateState:(WXState)state
{
    if (_renderFinished && _embedInstance && _embedInstance.state != state) {
        _embedInstance.state = state;
        
        if (state == WeexInstanceAppear) {
            [self setNavigationWithStyles:self.embedInstance.naviBarStyles];
            [[WXSDKManager bridgeMgr] fireEvent:self.embedInstance.instanceId ref:WX_SDK_ROOT_REF type:@"viewappear" params:nil domChanges:nil];
        }
        else if (state == WeexInstanceDisappear) {
            [[WXSDKManager bridgeMgr] fireEvent:self.embedInstance.instanceId ref:WX_SDK_ROOT_REF type:@"viewdisappear" params:nil domChanges:nil];
        }
    }
}

```


### 二.Weex 的事件传递


在 Weex 中，iOS Native 把事件传递给 JS 目前只有2种方式，一是 Module 模块的 callback，二是通过 Component 组件自定义的通知事件。



#### （1）callback




![](http://upload-images.jianshu.io/upload_images/1194012-489fe952c028acc3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在 WXModuleProtocol 中定义了2种可以 callback 给 JS 的闭包。

```objectivec


/**
 * @abstract the module callback , result can be string or dictionary.
 * @discussion callback data to js, the id of callback function will be removed to save memory.
 */
typedef void (^WXModuleCallback)(id result);

/**
 * @abstract the module callback , result can be string or dictionary.
 * @discussion callback data to js, you can specify the keepAlive parameter to keep callback function id keepalive or not. If the keepAlive is true, it won't be removed until instance destroyed, so you can call it repetitious.
 */
typedef void (^WXModuleKeepAliveCallback)(id result, BOOL keepAlive);

```

两个闭包都可以 callback 把 data 传递回给 JS，data 可以是字符串或者字典。

这两个闭包的区别在于：

1. WXModuleCallback 用于 Module 组件，为了节约内存，该回调只能回调通知 JS 一次，之后会被释放，多用于一次结果。
2. WXModuleKeepAliveCallback 同样是用于 Module 组件，但是该回调可以设置是否为多次回调类型，如果设置了 keepAlive，那么可以进行持续监听变化，多次回调，并返回给 JS。

在 Weex 中使用 WXModuleCallback 回调，很多情况是把状态回调给 JS，比如成功或者失败的状态，还有一些出错的信息回调给 JS。

比如在 WXStorageModule 中

```objectivec


- (void)setItem:(NSString *)key value:(NSString *)value callback:(WXModuleCallback)callback
{
    if ([self checkInput:key]) {
        callback(@{@"result":@"failed",@"data":@"key must a string or number!"});
        return;
    }
    if ([self checkInput:value]) {
        callback(@{@"result":@"failed",@"data":@"value must a string or number!"});
        return;
    }
    
    if ([key isKindOfClass:[NSNumber class]]) {
        key = [((NSNumber *)key) stringValue];
    }
    
    if ([value isKindOfClass:[NSNumber class]]) {
        value = [((NSNumber *)value) stringValue];
    }
    
    if ([WXUtility isBlankString:key]) {
        callback(@{@"result":@"failed",@"data":@"invalid_param"});
        return ;
    }
    [self setObject:value forKey:key persistent:NO callback:callback];
}

```

在调用 setItem:value:callback: 方法里面，如果 setKey-value 的时候失败了，会把错误信息通过 WXModuleCallback 回调给JS。

当然，如果调用存储模块 WXStorageModule 的某些查询信息的方法：


```objectivec


- (void)length:(WXModuleCallback)callback
{
    callback(@{@"result":@"success",@"data":@([[WXStorageModule memory] count])});
}

- (void)getAllKeys:(WXModuleCallback)callback
{
    callback(@{@"result":@"success",@"data":[WXStorageModule memory].allKeys});
}

```

length: 和 getAllKeys: 方法调用成功，会把成功的状态和数据通过 WXModuleCallback 回调给JS。





在 Weex 中使用了 WXModuleKeepAliveCallback 的模块总共只有以下4个：

WXDomModule，WXStreamModule，WXWebSocketModule，WXGlobalEventModule


在 WXDomModule 模块中，JS 调用获取 Component 组件的位置信息和宽高信息的时候，需要把这些坐标和尺寸信息回调给 JS，不过这里虽然用到了WXModuleKeepAliveCallback，但是 keepAlive 是 false，并没有用到多次回调的功能。


在 WXStreamModule 模块中，由于这是一个传输流的模块，所以肯定需要用到WXModuleKeepAliveCallback，需要持续不断的监听数据的变化，并把进度回调给 JS，这里用到了 keepAlive。WXStreamModule 模块中也会用到 WXModuleCallback，WXModuleCallback 会即时把各个状态回调给 JS。

在 WXWebSocketModule 模块中


```objectivec


@interface WXWebSocketModule()

@property(nonatomic,copy)WXModuleKeepAliveCallback errorCallBack;
@property(nonatomic,copy)WXModuleKeepAliveCallback messageCallBack;
@property(nonatomic,copy)WXModuleKeepAliveCallback openCallBack;
@property(nonatomic,copy)WXModuleKeepAliveCallback closeCallBack;

@end

```


用到了4个 WXModuleKeepAliveCallback 回调，这4个 callback 分别是把 error 错误信息，message 收到的数据，open 打开链接的状态，close 关闭链接的状态，持续的回调给 JS。


在 WXGlobalEventModule 模块中，有一个 fireGlobalEvent: 方法。

```objectivec


- (void)fireGlobalEvent:(NSNotification *)notification
{
    NSDictionary * userInfo = notification.userInfo;
    NSString * userWeexInstanceId = userInfo[@"weexInstance"];

    WXSDKInstance * userWeexInstance = [WXSDKManager instanceForID:userWeexInstanceId];
   // 防止userInstanceId存在，但是instance实际已经被销毁了
    if (!userWeexInstanceId || userWeexInstance == weexInstance) {
        
        for (WXModuleKeepAliveCallback callback in _eventCallback[notification.name]) {
            callback(userInfo[@"param"], true);
        }
    }
}

```

开发者可以通过 WXGlobalEventModule 进行全局的通知，在 userInfo 里面可以夹带 weexInstance 的参数。native 是不需要关心 userWeexInstanceId，这个参数是给 JS 用的。

Native 开发者只需要在用到了 WXGlobalEventModule 的模块里加上事件的监听者，然后发送全局通知即可。userInfo[@"param"]会被回调给 JS。


#### （2）fireEvent:params:domChanges:



![](http://upload-images.jianshu.io/upload_images/1194012-38a401738793eae9.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





在开头我们介绍的 Weex 事件的4种类型，通用事件，Appear 事件，Disappear 事件，Page 事件，全部都是通过 fireEvent:params:domChanges: 这种方式，Native 触发事件之后，Native 把参数传递给 JS 的。

在 WXComponent 里面定义了2个可以给 JS 发送消息的方法：

```objectivec


/**
 * @abstract Fire an event to the component in Javascript.
 *
 * @param eventName The name of the event to fire
 * @param params The parameters to fire with
 **/
- (void)fireEvent:(NSString *)eventName params:(nullable NSDictionary *)params;

/**
 * @abstract Fire an event to the component and tell Javascript which value has been changed. 
 * Used for two-way data binding.
 *
 * @param eventName The name of the event to fire
 * @param params The parameters to fire with
 * @param domChanges The values has been changed, used for two-way data binding.
 **/
- (void)fireEvent:(NSString *)eventName params:(nullable NSDictionary *)params domChanges:(nullable NSDictionary *)domChanges;


```


这两个方法的区别就在于最后一个 domChanges 的参数，有这个参数的方法主要多用于 Weex 的 Native 和 JS 的双向数据绑定。


```objectivec


- (void)fireEvent:(NSString *)eventName params:(NSDictionary *)params
{
    [self fireEvent:eventName params:params domChanges:nil];
}

- (void)fireEvent:(NSString *)eventName params:(NSDictionary *)params domChanges:(NSDictionary *)domChanges
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSTimeInterval timeSp = [[NSDate date] timeIntervalSince1970] * 1000;
    [dict setObject:@(timeSp) forKey:@"timestamp"];
    if (params) {
        [dict addEntriesFromDictionary:params];
    }
    
    [[WXSDKManager bridgeMgr] fireEvent:self.weexInstance.instanceId ref:self.ref type:eventName params:dict domChanges:domChanges];
}

```

上述就是两个方法的具体实现。可以看到 fireEvent:params: 方法就是调用了 fireEvent:params:domChanges: 方法，只不过最后的 domChanges 参数传了 nil。

在fireEvent:params:domChanges: 方法中会对 params 字典做了一次加工，加上了 timestamp 的键值。最终还是会调用 WXBridgeManager 里面的 fireEvent:ref: type:params:domChanges: 方法。

在 WXBridgeManager 中具体实现了上述的两个方法。

```objectivec


- (void)fireEvent:(NSString *)instanceId ref:(NSString *)ref type:(NSString *)type params:(NSDictionary *)params
{
    [self fireEvent:instanceId ref:ref type:type params:params domChanges:nil];
}

- (void)fireEvent:(NSString *)instanceId ref:(NSString *)ref type:(NSString *)type params:(NSDictionary *)params domChanges:(NSDictionary *)domChanges
{
    if (!type || !ref) {
        WXLogError(@"Event type and component ref should not be nil");
        return;
    }
    
    NSArray *args = @[ref, type, params?:@{}, domChanges?:@{}];
    WXSDKInstance *instance = [WXSDKManager instanceForID:instanceId];
    
    WXCallJSMethod *method = [[WXCallJSMethod alloc] initWithModuleName:nil methodName:@"fireEvent" arguments:args instance:instance];
    [self callJsMethod:method];
}


```

入参 ref, type, params, domChanges 封装到最终的 args 参数数组里面，最后会封装出 WXCallJSMethod 方法，通过 WXBridgeManager 的 callJsMethod 调用到 JS 的 fireEvent 方法。





![](http://upload-images.jianshu.io/upload_images/1194012-c8282fcd911caaa2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





这里可以举个例子：

假设一个场景，用户点击了一张图片，于是就会改变 label 上的一段文字。

首先图片是 imageComponent，用户点击会触发该 Component 的 onclick: 方法

组件里面会调用 fireEvent:params: 方法：

```objectivec

[self fireEvent:@"click" params:@{@"position":position}];

```

最终通过 fireEvent:params:domChanges: 方法，发送给 JS 的参数字典大概如下：


```c

args:(
    0,
        (
                {
            args =             (
                3,
                click,
                                {
                    position =                     {
                        height = "199.8792270531401";
                        width = "199.8792270531401";
                        x = "274.7584541062802";
                        y = "115.9420289855072";
                    };
                    timestamp = "1489932655404.133";
                },
                                {
                }
            );
            method = fireEvent;
            module = "";
        }
    )
)

```

JSFramework 收到了 fireEvent 方法调用以后，处理完，知道 label 需要更新，于是又会开始 call Native，调用 Native 的方法。调用 Native 的 callNative 方法，发过来的参数如下：

```c


(
        {
        args =         (
            4,
                        {
                value = "\U56fe\U7247\U88ab\U70b9\U51fb";
            }
        );
        method = updateAttrs;
        module = dom;
    }
)

```

最终会调用 Dom 的 updateAttrs 方法，会去更新 id 为4的 value，id 为4对应的就是 label，更新它的值就是刷新 label。

接着 JSFramework 还会继续调用 Native 的 callNative 方法，发过来的参数如下：

```c


(
        {
        args =         (
        );
        method = updateFinish;
        module = dom;
    }
)


```

调用 Dom 的 updateFinish 方法，即页面刷新完毕。


### 最后

至此，Weex 从 View 的创建，到渲染，产生事件回调 JSFramework，这一系列的流程源码都解析完成了。

![](http://upload-images.jianshu.io/upload_images/1194012-c990ddac97537e7b.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


中间涉及到了3个子线程，mainThread，com.taobao.weex.component，com.taobao.weex.bridge，分别是 UI 主线程，DOM 线程，JSbridge 线程。


Native 端目前还差神秘的 JSFramework 的源码解析。请大家多多指点。




------------------------------------------------------

Weex 源码解析系列文章：

[Weex 是如何在 iOS 客户端上跑起来的](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_how_to_work_in_iOS.md)  
[由 FlexBox 算法强力驱动的 Weex 布局引擎](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_layout_engine_powered_by_Flexbox's_algorithm.md)  
[Weex 事件传递的那些事儿](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_events.md)     
[Weex 中别具匠心的 JS Framework](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_ingenuity_JS_framework.md)  
[iOS 开发者的 Weex 伪最佳实践指北](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOS/Weex/Weex_pseudo-best_practices_for_iOS_developers.md)  

------------------------------------------------------