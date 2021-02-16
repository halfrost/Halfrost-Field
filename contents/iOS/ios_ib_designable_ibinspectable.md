# 关于 IB_DESIGNABLE / IBInspectable 的那些需要注意的事


![](https://img.halfrost.com/Blog/ArticleTitleImage/17_0.png)



#### 前言

IB_DESIGNABLE / IBInspectable 这两个关键字是在WWDC 2014年"What's New in Interface Builder"这个Session里面，用Swift讲过一个例子。也是随着Xcode 6 新加入的关键字。

这两个关键字是用在我们自定义View上的，**目前暂时只能用在UIView的子类中**所以系统自带的原生的那些控件使用这个关键字都没有效果。

>Live RenderingYou can use two different attributes—@IBDesignable and @IBInspectable—to enable live, interactive custom view design in Interface Builder. When you create a custom view that inherits from the UIView class or the NSView class, you can add the @IBDesignable attribute just before the class declaration. After you add the custom view to Interface Builder (by setting the custom class of the view in the inspector pane), Interface Builder renders your view in the canvas.You can also add the @IBInspectable attribute to properties with types compatible with user defined runtime attributes. After you add your custom view to Interface Builder, you can edit these properties in the inspector.

其大意就是说，“所见即所得”的思想，我们可以将自定义的代码实时渲染到Interface Builder中。而它们之间的桥梁就是通过两个指令来完成，即@IBDesignable和@IBInspectable。我们通过@IBDesignable告诉Interface Builder这个类可以实时渲染到界面中，无论我们drawRect里面多么复杂，自定义有多复杂，Xib / Storyboard都可以把它编译出来，并且渲染展示出来。但是这个类必须是UIView或者NSView的子类。通过@IBInspectable可以定义动态属性，即可在Attributes inspector面板中可视化修改属性值。

```objectivec    
 @IBInspectable var integer: Int = 0
 @IBInspectable var float: CGFloat = 0
 @IBInspectable var double: Double = 0
 @IBInspectable var point: CGPoint = CGPointZero
 @IBInspectable var size: CGSize = CGSizeZero
 @IBInspectable var customFrame: CGRect = CGRectZero
 @IBInspectable var color: UIColor = UIColor.clearColor()
 @IBInspectable var string: String = ""
 @IBInspectable var bool: Bool = false
```

![](https://img.halfrost.com/Blog/ArticleImage/17_2.png) 


这两个关键字不是今天的重点，看个Demo就会使用了。
[Demo地址](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/CircleSlider-master)

如果想看Session的话，可以看这两个WWDC 2014的链接  
[whats\_new\_in\_xcode\_6](http://devstreaming.apple.com/videos/wwdc/2014/401xxfkzfrjyb93/401/401_whats_new_in_xcode_6.pdf?dl=1)  
[whats\_new\_in\_interface\_builder](http://devstreaming.apple.com/videos/wwdc/2014/411xx0xo98zzoor/411/411_whats_new_in_interface_builder.pdf?dl=1)  
[苹果官方文档](https://developer.apple.com/library/ios/recipes/xcode_help-IB_objects_media/Chapters/CreatingaLiveViewofaCustomObject.html#//apple_ref/doc/uid/TP40014224-CH41-SW1)

今天来分享一下我使用这两个关键字的时候遇到的一些问题和解决过程。

#### 1.The agent raised a "NSInternalInconsistencyException" exception

```objectivec    
file://BottomCommentView-master/BottomCommentView/Base.lproj/Main.storyboard: error: 
IB Designables: Failed to update auto layout status: The agent raised a "NSInternalInconsistencyException" exception: Could not load NIB in bundle: 'NSBundle </Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Overlays> (loaded)' with name 'BottomCommentView'

file://BottomCommentView/Base.lproj/Main.storyboard: error:
 IB Designables: Failed to render instance of BottomCommentView: The agent threw an exception.

```
我们会看到面板上Designables这里显示的是一个Crashed，Xib / Storyboard 居然也会Crashed！整个app是跑起来了，但是报了2个错，不能忍！这两个错其实是编译时候Xib报的错误，并不是运行时的错误。

![](https://img.halfrost.com/Blog/ArticleImage/17_3.png) 


当我们看到Debug的时候，肯定第一想到的就是点Debug。但是很不幸的是，在这种情况下，点击Debug，每次都会告诉你“Finishing debugging instance of XXXX for interface Builder”，即使你在你自定义的View里面打了断点，也无济于事。

回到问题上来，我们来仔细看看崩溃信息。信息上说Could not load NIB in bundle，并且还给了我们一个类似地址一样的东西
```vim  
'NSBundle </Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Overlays> (loaded)'
```  
我们可以定位到时Xib在从bundle中读取出来出错了。

通过在网上查找资料，问题其实是这样的。

>When loading the nib, we're relying on the fact that passing bundle: nil defaults to your app's mainBundle at run time.

每次我们取mainBundle的时候，都是用的默认的方法
```objectivec    
let nib = UINib(nibName: String(StripyView), bundle: nil)
```
这里在Xib / Storyboard 编译的时候，我们需要告诉iOS系统，我们要指定哪一个bundle类去读取。把上面的代码改成下面这样就可以了。

```objectivec    
let bundle = NSBundle(forClass: self.dynamicType)
let nib = UINib(nibName: String(StripyView), bundle: bundle)
```
或者这样  
```objectivec    
#if TARGET_INTERFACE_BUILDER
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        [bundle loadNibNamed:@"BottomCommentView" owner:self options:nil];
#else
        [[NSBundle mainBundle] loadNibNamed:@"BottomCommentView" owner:self options:nil];
        
#endif
```

PS:如果你自定义的View不显示在Xib / Storyboard上，但是程序一运行就又能显示出View来，原因也有可能是这个原因，虽然Xib / Storyboard没有报错，因为app没有运行起来，Xib / Storyboard并不知道上下文，所以没有把我们自定义的View加载出来。

#### 2.代码或者Xib依旧不显示自定义控件的样子

如果你按照上面的第一个问题里面加上了bundle的代码之后还是不显示，那可能是你代码加的地方不对。

如果是代码手动创建控件的话，会调用initWithFrame方法

```objectivec    

- (instancetype)initWithFrame:(CGRect)frame
```
如果是通过Xib / Storyboard 拖拽显示控件的话，会调用initWithCoder方法

```objectivec    

- (instancetype)initWithCoder:(NSCoder *)aDecoder
```

需要在对应的这两个方法里面去加上bundle的方法。如果为了保险起见，那这两个init方法里面都加上问题一里面的代码吧。

#### 3.Failed to update auto layout status: The agent crashed / Failed to render instance of XXXXXXX: The agent crashed

```objectivec    
file://BottomCommentView/Base.lproj/Main.storyboard: error: 
IB Designables: Failed to update auto layout status: The agent crashed

file://BottomCommentView/Base.lproj/Main.storyboard: error: 
IB Designables: Failed to render instance of BottomCommentView: The agent crashed

```

如果是遇到了这个问题，是比较严重的，这个问题不像问题一，问题一整个app是可以运行的，错误来源于Xib / Storyboard编译时候的错误，但是并不影响这个app的运行。

但是这个问题会直接导致整个app闪退，直接Crashed掉！没办法，我们只能打断点debug一下。

如果你在Designables 那里把Debug打开，然后断点打到initWithCoder 和 initWithFrame那里，会发现程序总是运行到这一行  

```objectivec     

self = [super initWithCoder:aDecoder];
```  

或者这一行  

```objectivec    

self = [super initWithFrame:frame];
```  

就崩溃了。其实从下面的栈信息也可以很快看出发生了什么：


![](https://img.halfrost.com/Blog/ArticleImage/17_4.png) 

![](https://img.halfrost.com/Blog/ArticleImage/17_5.png) 




可以很明显的看到，是initWithCoder这个方法陷入了死循环。由于这个死循环导致了程序Crashed了。

可是这里为什么会死循环呢？其实根本原因在于，我们自定义的类的class写成自己了。

来看看到底发生了什么。现在在Xode 7中，我们默认创建一个View，是不给我们默认生成一个XIB文件，ViewController会有下面那个选项，可以选择勾上。

![](https://img.halfrost.com/Blog/ArticleImage/17_6.png) 


在我们创建完这个类的时候，我们还要再创建一个Xib和这个类进行关联。

再对比一下我们创建TableviewCell的过程  

![](https://img.halfrost.com/Blog/ArticleImage/17_7.png) 


一般我们会勾选上那个“Also create XIB file”，创建完成之后，我们就会在Custom Class里面把我们这个cell的类名填上。

如果我们现在自定义View的时候也是相同做法，创建完Xib文件之后，File‘s owner关联好了之后。然后在Custom Class里面填上了我们自定义的类之后，这个时候就错了！

为什么我们平时相同的做法，到这里就错误了呢？

我们来考虑一下我们自定义View加载的过程。我们这个自定义View肯定是放在了一个ViewController上面，代码创建出来或者直接拖拽到Xib / Storyboard 上。用代码或者SB上面拖一个View，这个时候我们需要指定这个类是什么，这个毋庸置疑，是绝对没有问题的。SB上面拖的View的class肯定要选择我们自定义的这个View。

但是在加载我们这个View的时候，会走initWithCoder / initWithFrame 方法，在这里方法里面又会去调用super的这个方法，现在我们把这个class写成了自己，依照我们上面调试的log，可以看到，initWithCoder以后，会按照以下的路线去调用.

[NSBundle loadNibName] —— [UINib instantiateWithOwner:options] ——[UINibDecoder decodeObjectForKey:]——UINibDecoderDecodeObjectForValue——[UIRuntimeConnection initWithCoder]——[UINibDecoder decodeObjectForKey:]——UINibDecoderDecodeObjectForValue——[UIClassSwapper initWithCoder:]——[BottomCommentView initWithCoder:]

从NSBundle加载开始，解析完之后会调用到ClassSwapper 的initWithCoder，由于我们class写了自己，这里就陷入死循环了。程序崩溃！这里就跟set方法里面调用点语法赋值一样，无限的递归调用了。


经过上面的分析之后，我们就知道了问题就出在我们在initWithCoder里面又调用了loadNibName，loadNibName又会去最终调UIClassSwapper initWithCoder。难道是我们custom class不对么？对比一下我们自定义tableViewCell的class就是本身，怎么就没有这个问题呢。

我们来仔细看看tableViewCell我们是怎么加载的，我们的Xib的class还是自己，但是registerWithNibName的方法调用在tableView中，这样就不会无限递归了。

这里当然我们也可以仿照这个方法做，那我们需要把loadNibName写到另外一个类中去。class还是写自己本身，用那个类来加载我们这个View，这样就可以不崩溃，不会无限递归了。但是问题又来了，我们无法在Xib/Storyboard上实时预览到我们的View了。

这里需要提一下IB_DESIGNABLE的工作原理。当我们用了IB_DESIGNABLE关键字以后，Xib/StoryBoard会在不运行整个程序的情况下，把这个View代码编译跑一遍，由于没有程序上下文，所有的编译就只在这个view的代码中进行。

我们在ViewController里面拖拽了一个View，并且更改它的class为我们自定义的class，那么接下来所有view的绘制都会交给我们这个自定义view的class，由这个class来管理。这里就分两种情况了。第一种情况就是我文章一开头给的Demo的例子，用DrawRect代码绘制出这个View的样子。这里不会出现任何问题。第二种情况就是我们还想用一个Xib来显示View，这种情况就是Xib/StoryBoard里面再次加载Xib的情况了。由于现在我们自定义的class有了接管整个view的绘制权利，那么我们就应该在initWithCoder中loadNibName，把整个View在初始化的时候load出来。根据上面的分析，我们找到崩溃的原因是无限递归，这里又必须要调用initWithCoder，我们的唯一办法就是把class改成父类的class，即UIView，这时候一切就好了，Xib/Storyboard不报错，也能及时显示出view的样子来了。

总结一下：
> when using loadNibNamed:owner:options:, the File's Owner should be NSObject, the main view should be your class type, and all outlets should be hooked up to the view, not the File's Owner.

PS.这里说的仅仅是loadNibNamed而不是initWithNibName。顺带提一下他们俩的不同点。initWithNibName要加载的Xib的类为我们定义的ViewController。loadNibNamed要加载的Xib的类为NSOjbect。他们的加载方式也不同，initWithNibName方法：是延迟加载，这个View上的控件是 nil 的，只有到需要显示时，才会不是 nil。loadNibNamed是立即加载，调用这个方法加载的xib对象中的各个元素都已经存在。


#### 总结
当我第一次知道IB_DESIGNABLE / IBInspectable之后，感觉到特别的神奇，连我们自定义化的View也可以及时可见了。不过经过一段研究以后就发现。IB_DESIGNABLE / IBInspectable还是有一些缺陷的。IB_DESIGNABLE暂时只能在UIView的子类中用，常用的UIButton加圆角这些暂时也没法预览。IBInspectable实质是在Runtime Attributes设置了值，这也使得IBInspectable只能使用常用类型。NSDate这种类型没法设置成IBInspectable。

以上就是我和大家分享的IB_DESIGNABLE / IBInspectable使用过程中遇到的一些“坑”。



#### 更新：
下面这一段要感谢@**Andy矢倉** 微博上面指点我，其实系统的子类可以这么做：抽了几个常用的控件的公共类，顺便用External剥离常用属性，更复杂的移步这个库[IBAnimatable](https://github.com/JakeLin/IBAnimatable)

@**Andy矢倉**还提醒说，用这个特性最好是iOS8 + Swift，OC或者iOS7都会出现Failed to update而且无解，再次感谢@**Andy矢倉**大神的指点！！！下图是他对系统控件的可视化改造！

![](https://img.halfrost.com/Blog/ArticleImage/17_8.png)

