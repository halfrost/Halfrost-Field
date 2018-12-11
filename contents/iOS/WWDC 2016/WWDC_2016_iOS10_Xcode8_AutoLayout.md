# WWDC2016 Session 笔记 - Xcode 8 Auto Layout 新特性

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-520084e0dda3ed1e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## 目录
- 1.Incrementally Adopting Auto Layout
- 2.Design and Runtime Constraints
- 3.NSGridView
- 4.Layout Feedback Loop Debugging


## 一.Incrementally Adopting Auto Layout
Incrementally Adopting Auto Layout是什么意思呢？在我们IB里面布局我们的View的时候，我们并不需要一次性就添加好所有的constraints。我们可以一步步的增加constraints，简化我们的步骤，而且能让我们的设置起来更加灵活。 

再谈新特性之前，先介绍一下这个特性对应的背景来源。  

有这样一种场景，试想，我们把一个view放在父view上，这个时候并没有设置constraints，当我们运行完程序，就会出现下图的样子。
![](http://upload-images.jianshu.io/upload_images/1194012-637527eb1a0ca498.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

看上去一切都还正常。但是一旦当我们把设备旋转90°以后，就会出现下图的样子。

![](http://upload-images.jianshu.io/upload_images/1194012-d716316a84356bf1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个时候可以发现，这个View的长，宽，以及top和left的边距都没有发生变化。这时我们并没有设置constraints，这是怎么做到的呢？

在程序的编译期，Auto Layout的引擎会自动隐式的给View加上一些constraints约束，以保证View的大小不会发生变化。这个例子中，View被加上了top，left，width，height这4个约束。

如果我们需要更加动态的resize的行为，就需要我们在IB里面自定义约束了。现在问题就来了，有没有更好的方式来做这件事情？最好是能有一种不用约束的方法，也能达到简单的resize的效果。

现在这个问题有了解决办法。在Xcode8中，我们可以给View指定autoresizing masks，而不用去设置constraints。这就意味着我们可以不用约束，我们也能做到简单的resize的效果。

在Autolayout时代之前，可能会有人认出这种UI方式。这是一种Springs & Struts的UI。我们可以设定边缘约束(注：这里的约束并不是指的是Autolayout里面的constraints，是autoresizing masks里面的规则)，无论View的长宽如何变化，这些View都会跟随着设置了约束的view一起变化。


![](http://upload-images.jianshu.io/upload_images/1194012-d66036d42faa95e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


上述的例子中，Xcode 8 中在没有加如何constraint就可以做到旋转屏幕之后，View的边距并没有发生变化。这是怎么做到的呢？事实上，Xcode 8的做法是先取出autoresizing masks，然后把它转换成对应的constraints，这个转换的时机发生在Runtime期间。生成对应的constraints是发生在运行时，而不是编译时的原因是可以给我们开发者更加便利的方式为View添加更加细致的约束。

在View上，我们可以设置translatesAutoresizingMaskIntoConstraints属性。  
```objc
translatesAutoresizingMaskIntoConstraints == true
```

假设如果View已经在Interface Builder里面加过constraints，“Show the Size inspector”面板依旧会和以前一样。点击View，查看给它加的所有的constraints，这个时候Autoresizing masks就被忽略了，而且translatesAutoresizingMask的属性也会变成false。如下图，我们这个时候在“Show the Size inspector”面板上面就已经看不到AutoresizingMask的设置面板了。

![](http://upload-images.jianshu.io/upload_images/1194012-8fa2f4a12705805d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-a572a36604c85ffd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
上图就是在Autolayout时代之前，我们一直使用的是autoresizing masks，但是Autolayout时代来临之后，一旦勾选上了这个Autolayout，之前的AutoresizingMask也就失效了。

回到我们最原始的问题上来，Xcode 8 现在针对View可以支持增量的适用Autolayout。这就意味着我们可以从AutoresizingMask开始，先做简单的resize的工作，然后如果有更加复杂的需求，我们再加上适当的约束constraints来进行适配。简而概之，Xcode 8 Autolayout ≈ AutoresizingMask + Autolayout 。


接下来用一个demo的例子来说明一下Xcode 8 Autolayout新特性。  
在说例子之前我们先来说一下Xcode 8在storyboard上新增了哪些功能。如下图，我们可以看到，在最下方新增加了一栏，可以切换不同的屏幕大小，可以看出，iPhone现在已经分化成6种屏幕大小需要我们适配了，从大到小，依次是：iPad pro 12.9, iPad 9.7 , iPhone 6s Plus/iPhone 6 Plus , iPhone 6s/iPhone 6, iPhone SE/iPhone5s/iPhone5, iPhone4s/iPhone4。下面还可以选择横竖屏，和不用屏幕百分比的适应性。
![](http://upload-images.jianshu.io/upload_images/1194012-ccd7ee3afb97128c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


回到例子，我们现在对页面上这些view来做简单的AutoresizingMask。右边的那个预览界面是可以看到我们加上这些Mask之后的效果。

先是粉色的父View，我们给它加上如下的AutoresizingMask。
![](http://upload-images.jianshu.io/upload_images/1194012-541263982f9d5004.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

给"雨天"的imageView加上如下AutoresizingMask
![](http://upload-images.jianshu.io/upload_images/1194012-a72576207ebe4447.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

给"阴天"的imageView加上如下的AutoresizingMask

![](http://upload-images.jianshu.io/upload_images/1194012-c17df0eec79dd816.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

最后给我们的中间的Label加上AutoresizingMask

![](http://upload-images.jianshu.io/upload_images/1194012-d8df43f7952321be.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个时候我们旋转一下屏幕，一切正常，View的排版都如我们所愿。

![](http://upload-images.jianshu.io/upload_images/1194012-4df96205a8480096.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这个时候我们再选择一下，3：2分屏，这个时候就出现了不对的情况了。Label的Width被挤压了。

![](http://upload-images.jianshu.io/upload_images/1194012-55bf242088854780.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

原因是因为Autoresizing masks并不会向Autolayout一样，会考虑View的content，所以这里被挤压了。

想fix这个Label，我们可以很容易的添加一个constraints来修复。不过这里我们来谈谈另外一种做法。

进入到Attributes Inspector面板，找到Autoshrink属性，把“fixed font size”切换成“minimum font size”


![](http://upload-images.jianshu.io/upload_images/1194012-79b7038d7df03eb8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个时候就fix上述的问题了。

![](http://upload-images.jianshu.io/upload_images/1194012-d140165f6ca54036.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

此时就算是回到landscape，分屏的情况下，已经可以显示正常。

![](http://upload-images.jianshu.io/upload_images/1194012-02e1709fd25a60e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

接着我们再来处理一下中间的温度的Label。这个时候我们有比较复杂的需求。这个时候我们就需要用到constraint了。

这个时候我们按时control键，然后拖到父View上，释放，会弹出菜单。我们再按住shift，这样我们可以一次性选择多个constraints。

![](http://upload-images.jianshu.io/upload_images/1194012-793f4205c747a333.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-95aab84ae9baace3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


我们一次性选择“Center Horizontally in Container” 和 “Center Vertically in Container”。注意这个时候右边还是AutoresizingMask的面板，因为这个时候Label还没有任何的constraint。当我们点击“Add Constraints”的时候，就给Label加上了约束，右边的面板也变成了constraints面板了。

我们再给这个Label继续加2个constraints。“Horizontal Spacing”和“Baseline”。


![](http://upload-images.jianshu.io/upload_images/1194012-48e850a152987d86.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

同样的，从Label拖拽到“太阳”的那个imageView上，再添加“Horizontal Spacing”和“Baseline”约束。

这个时候我们更新一下frame。如下图所示，选择“Update Frames”，这个时候所有的frame就都完成了。

![](http://upload-images.jianshu.io/upload_images/1194012-23546d448e5c177d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-04a9232b13c71d6d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个时候我们更新一下中间温度的Label的字体大小，这时候计算变大，由于我们的constraints都是正确的，两边的View也会随着Label字体变大而变大。


![](http://upload-images.jianshu.io/upload_images/1194012-3da0a819491ff184.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Xocde 8在这个时候就变得更加智能了，会立即自动更新frame。



我们在继续给晴天的上海加上一个背景图。添加一个imageView，然后大小铺满整个父View，把mode 选择成“Aspect Fill”

![](http://upload-images.jianshu.io/upload_images/1194012-7639cec83cd526d3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


接下面一般的做法就是在这个imageView上面添加constraints，来使这个View和父View大小一样。但是这种简单的resize的行为在Xocde 8里面就不需要再添加Constraint了，这里我们改用Autoresizing masks来实现。给imageView添加一下这些mask。
![](http://upload-images.jianshu.io/upload_images/1194012-badadb886e9ff91e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们把imageView放到背景去。这时，我们所有的界面就布局完成了。


![](http://upload-images.jianshu.io/upload_images/1194012-4917418adeac2aec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

测试一下横屏的效果
![](http://upload-images.jianshu.io/upload_images/1194012-9c3f8c4a5c4db2b3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

甚至分屏的一样可以完成任务！
![](http://upload-images.jianshu.io/upload_images/1194012-29ed778b3ce5e7aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
 

[Demo的Github地址](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/Xcode8AutolayoutDemo-master)，这个demo没啥难的，就是看看效果。

这就是Xcode 8 的Incrementally Adopting Auto Layout，Autoresizing masks + Auto Layout Constraint 一起协同工作！



## 二.Design and Runtime Constraints  

在我们开发过程中有这样一种情况，View的constraints会依据你所加载的数据来添加的。所以在app运行之前，我们是无法知道所有的constraints的。

这里有3种方法可以对应以上的情况。

### 1.Placeholder Constraints

假设现在我们需要把一张图片放在View的垂直和水平的中间，并且距离左边的边缘有一个leading margin。并且还需要保持其长宽的比例。而这种图片的最终样子，我们并不知道。只有到运行时，我们才能知道这样图片的样子。

为了能在Interface Builder看到我们的图片，我们要先预估一下图片的长宽比例。假设我们估计为4：3。这时候就给图片加上constraints，并且勾上“place order constraint”，这个约束会在build time的时候被移除。


![](http://upload-images.jianshu.io/upload_images/1194012-ed8c011d75371e39.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当我们在运行时拿到图片之后，这个是时候我们再给它加上适当的约束和长宽比例即可。


### 2.Intrinsic Content Size

还是类似上面那种场景，我们有时候会自定义一些UIView或者NSView，这些View里面的content是动态的。Interface Builder并不会运行我们的代码，所以不到app运行的时候我们并不知道里面的大小。我们可以给它设置一个内在的content的大小。

![](http://upload-images.jianshu.io/upload_images/1194012-5f22d602933155e2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

>Setting a design time intrinsic content size only affects a view while editing in Interface Builder.The view will not have this intrinsic content size at runtime.  

注意一下上面的说明intrinsic content size仅仅相当于是在布局的时候一个placeholder，在运行时这个size就没有了。所以如果开发过程中真的需要用到这个内在的content的大小，那么我们需要overriding的content size

```objc

override var intrinsicContentSize: CGSize
```

### 3.Turn Off Ambiguity Per View

这个是Xcode 8的一个新特性。当上述2种方法都无法解决我们的需求的时候。这个时候就需要用到这种方法了。Xcode 8给了我们可以在constraints产生歧义的时候，可以动态调整警告级别的能力。

![](http://upload-images.jianshu.io/upload_images/1194012-4f433ddf72781326.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在这个场景中，我们仅仅只知道我们需要把这个imageView放在水平位置的中央，但是imageView的大小和它的水平位置我们并不知道。如果我们仅仅只加上了这一个约束的话，Interface Builder就会报红，因为IB这时候根据我们给的constraints，并不能唯一确定当前的view的位置。

如果我们在之后的运行时，拿到图片的完整信息之后，我们自己知道该如何去加constraints，我们知道该如何去排版保证imageView能唯一确定位置的时候，这时我们可以关掉IB的红色警告。找到“Ambiguous”，这里是警告的级别，我们这里选择“Never Verify”，这时就没有红色的警告和错误提醒了。但是选择这一项的前提是，我们能保证之后运行时我们可以加上足够的constraints保证view的位置信息完整。

以上3种方法就是我们在运行时给view增加constraints的解决办法。


## 三.NSGridView  

这是macOS给我们带来的一个新的layout容器。

有时候我们为了维护constraints的正确性是件比较麻烦的事情，比如即使我们就是一组简单的checkboxes，维护constraints也不容易。这个时候我们会选择用stack view来让我们开发更容易一些。

下图是macOS的app常见到的一组checkboxes。
![](http://upload-images.jianshu.io/upload_images/1194012-9cc9080a7861603d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这时候我们选用NS/UIStackView来实现，因为它有以下的优点，它可以排列一组items，重要的是它可以处理好content size并且可以控制好每个item之间的spacing。

但是stack view依旧有一些场景无法很顺手的处理。例如下图的场景。

![](http://upload-images.jianshu.io/upload_images/1194012-e7c6eb85adbd76db.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这时依旧可以用stack view来实现，但是它不能帮我们根据content完成行和列的对齐。

这就是为什么要引入新的NSGridView的原因。

使用NSGridView，我们可以很容易的做到content在X轴和Y轴上的对齐。仅仅只需要我们把content放进预先定义好的网格中即可，NSGridView会帮我们管理好接下来对齐的一切事情。

我们来看看下面的例子。
![](http://upload-images.jianshu.io/upload_images/1194012-a7194363c60b4d99.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


NSGridView有2个子类，NSGridRow 和 NSGridColumn，它们俩会自动的管理好content的大小。当然我们可以在需要的时候指定size的大小，padding和spacing的大小。我们也可以动态的隐藏一些rows行和colunms列。

NSGridCell的工作就是管理每个cell里面content view的layout。如果某个cell的内容超出cell的边界，cell会合并起来，就像普通的电子表格app的做法一样。

![](http://upload-images.jianshu.io/upload_images/1194012-0240de67714b42b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


我们来构建一个简单的界面。设计图如下：
![](http://upload-images.jianshu.io/upload_images/1194012-ef33742918f3879a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


我们并不需要去关心网格的sizing，我们只用关心每一行每一列究竟有多少个content需要被显示出来。

```objc
let empty = NSGridCell.emptyContentView
let gridView = NSGridView(views: [
 [brailleTranslationLabel, brailleTranslationPopup], 
 [empty, showContractedCheckbox], 
 [empty, showEightDotCheckbox], 
 [statusCellsLabel, showGeneralDisplayCB],
 [empty, textStyleCB], 
 [showAlertCB] 
])
```
用上述代码运行出来的界面是这样的：

![](http://upload-images.jianshu.io/upload_images/1194012-a561bbdcb0ff07c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

虽然我们调用构造函数没错，但是出来的界面和设计的明显有一些差距。最明显的问题就是UI被拉开了，有很多空白的地方。

产生问题的原因就在于，网格被约束到了window的边缘。我们的意图应该是window来匹配我们的网格大小，但是现在出现的问题变成了，网格被拉伸了，去匹配window的大小了。

我们解决这个问题的办法就是去改变 grid view内容的hugging的优先级。尽管页面上的constraints已经具有了高优先级，但是我们现在仍可以继续提高优先级，来让constraints推动content，使其远离window的边缘。我们提高一些优先级：

```objc
gridView.setContentHuggingPriority(600, for: .horizontal)
gridView.setContentHuggingPriority(600, for: .vertical)
```


![](http://upload-images.jianshu.io/upload_images/1194012-a1dd15524cd1dcf0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们会发现，window里面的content更加聚合了，中间的大段空白消失了。

我们再来解决一下window中间的空白，左边的label和右边的content距离太远。根据设计，我们应该让label居右排列。这件事很容易，只要我们调整一下cell的位置信息即可完成。排列的位置信息会影响到cell，行，列，网格视图。

如果没有指定cell的placement这个属性值，那么行列就会根据gridview的placement属性值来确定。这个规则可以使我们在一处设定好placement，瞬间可以改变大量的cell的布局。


```objc
//first column needs to be right-justified:
gridView.column(at: 0).xPlacement = .trailing
```
我们找到gridView的第一列，改变它的xPlacement属性值，这样一列的cell都会变成居右排列。


![](http://upload-images.jianshu.io/upload_images/1194012-1225a9d45ea39661.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


居右之后，我们又会出现新的问题，baseline不对齐了。

![](http://upload-images.jianshu.io/upload_images/1194012-74949bdfced19d16.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

行的对齐和列的对齐原理一样的，同理，我们只需要设置一处，将会影响整个网格视图。
```objc
// all cells use firstBaseline alignment
gridView.rowAlignment = .firstBaseline
```

![](http://upload-images.jianshu.io/upload_images/1194012-a61900a27d2bd610.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

设置完成之后，整个网格视图就对齐了。

接下来我们再来改变一下pop-up button的边距。

![](http://upload-images.jianshu.io/upload_images/1194012-3201fb8701df1ed6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```objc
let row = gridView.cell(for: brailleTranslationPopup)!.row!
row.topPadding = 5
row.bottomPadding = 5
```
这里取第一行的做法也可以和之前取第一列的做法一样，直接取下标0的row即可。这里换一种更好的做法来做。在gridView里面找到包含pop-up button的cell，根据cell找到对应的row行。这种方式比直接去下标index的好处在于，日后如果有人在index 0的位置又增加了一行，那么代码就出错了，而我们这里的代码一直都不会出错，因为保证是取出了包含pop-up button的cell。所以代码里面尽量不要写死固定的index，这样以后维护起来比较困难。

同理，我们也给“status cells”也一起加上Padding

```objc
ridView.cell(for:statusCellsLabel)!.row!.topPadding = 6
```

这里需要对比一下padding 和 spacing的区别。

padding是针对每个行或者每个列之间的间距，我们可以增加padding来改变两两之间的间距。
spacing是针对整个gridview来说的，改变了它，将会影响整个网格视图的布局。

再来看看我们的设计图：
![](http://upload-images.jianshu.io/upload_images/1194012-ef33742918f3879a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果没有padding那么就是下图的样子：
![](http://upload-images.jianshu.io/upload_images/1194012-a44097139cef38b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果没有spacing那么就会出现下图的样子：
![](http://upload-images.jianshu.io/upload_images/1194012-559a56f9aa2f175e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果spacing和padding都没有的话，那就都挤在一起了：

![](http://upload-images.jianshu.io/upload_images/1194012-13509a34450af8b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


最后我们来处理一下最下面那一行包含checkbox的cell

![](http://upload-images.jianshu.io/upload_images/1194012-73c75d29bd25b172.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里就需要用到之前提到了，合并2个cell了。

```objc
// Special treatment for centered checkbox:
let cell = gridView.cell(for: showAlertCB)!
cell.row!.topPadding = 4
cell.row!.mergeCells(in: NSMakeRange(0, 2))
```
这里我们直接指出了，合并前2个cell。

执行完代码之后，就会是这个样子。
![](http://upload-images.jianshu.io/upload_images/1194012-b181efe7718f5ae4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

最后一行的cell就会横跨2个cell的位置。虽然占了2个cell的位置，但是它依旧还继承着第一列的居右的排列规则。

现在我们的需求是既不希望它居右，也不希望它居左。
checkbox其实是支持排列在2个列之间的，但是由于这相邻的2个列的宽度并不相等，所以gridview不知道该怎么排列了。这时就需要我们手动来改变布局了。

这里可能有人会想，直接把
```objc
cell.xPlacement = .none
```
把cell的xPlacement直接变成none，这样做会一下子打乱整个gridview的constraints布局，我们不能这样做。我们需要再继续给cell加上额外的constraints来维护整个gridview的constraints的平衡。

```objc
cell.xPlacement = .none
let centering = showAlertCB.centerXAnchor.constraint(equalTo: textStyleCB.leadingAnchor)
cell.customPlacementConstraints = [centering]
```
我们只需要在给出checkbox在x轴方面的锚点即可。这时候checkbox就会排列成我们想要的样子了。

![](http://upload-images.jianshu.io/upload_images/1194012-6d6d0fdb84291a2d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

至此，我们就完成了需求。总结一下，NSGridView是一个新的控件，能很好的帮助我们进行网格似布局。它能很快很方便的把我们需要展示的content排列整齐。之后我们仅仅只需要调整一下padding和spacing这些信息即可。

## 四.Layout Feedback Loop Debugging

有时候我们设置好了constraint之后，没有报任何错误，但是有些情况当我们运行起来的时候就有一堆constraint冲突在debug窗口里面，严重的还会使app直接崩溃。崩溃的情况就是遇到了layout feedback loop。

遇到这种情况，往往是发生在“过渡期”，开始或者结束的时候。如果说你点击了一个button，button相应了你的点击，但是之后button不弹起，一直保持着被按下的状态。


![](http://upload-images.jianshu.io/upload_images/1194012-c7f7e77d4a5642a3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后会观察到CPU使用率爆表，内存倍增，然后app就崩溃了，与此同时返回了一大堆的layout的栈回溯信息。

![](http://upload-images.jianshu.io/upload_images/1194012-614c97ca5d350293.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


发生这个情况的原因是某个view的layout被一直执行，一直执行，陷入了死循环中。Runloop就不会停下，CPU的使用率会一直处于峰值。所有的消息都会被收集到自动释放的对象中去，消息一直发送，就会一直收集。所以内存也会倍增。


导致这个原因之一，是setNeedsLayout这个方法。
![](http://upload-images.jianshu.io/upload_images/1194012-775542406d024aca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当其中一个view调用完setNeedsLayout之后，会传递到父视图继续调用setNeedsLayout，父视图的setNeedsLayout可能又会调用到其他视图的layout信息。如果我们能在这相互之后调用找到调用者，也就是那个view调用了这个方法，那我们就可以分析清楚这些setNeedsLayout从哪里来，到哪里去，就能找到死循环的地方了。

这些信息确实很难收集，这也是为何苹果要为我们专门开发这样一个工具，方便我们来调试，查找问题的原因。


开启这个工具的开关在“Arguments”选项里面。如下图。

![](http://upload-images.jianshu.io/upload_images/1194012-a46ee65eca84ff69.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```objc
-UIViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
-NSViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
// Logs to com.apple.UIKit:LayoutLoop or com.apple.AppKit:LayoutLoop
```
UIView是在iOS里面使用的，NSView是在macOS里面使用的。一旦我们开启了这个开关，那么layout feedback loop debugger就会开始记录每一个调用了setNeedsLayout的信息。

这里我给它设置了阀值是100。

如果发现在一个Runloop中，layout在一个view上面调用的次数超过了阀值，这里设置的是100，也就是说次数超过100，这个死循环还会在跑一小段，因为这个时候要给debugger一个记录信息的时间。当记录完成之后，就会立即抛出异常。并且信息会显示在logs中。log会被记录在com.apple.UIKit:LayoutLoop(iOS)/com.apple.AppKit:LayoutLoop(macOS)中

我们也可以打全局的异常断点exception break point。
在调试窗口也可以用LLDB命令po出一些调试信息。
![](http://upload-images.jianshu.io/upload_images/1194012-a83832771675c027.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


接下来看2个实用的例子。

### 1.Upstream Geometry Change


![](http://upload-images.jianshu.io/upload_images/1194012-68dca9ff105c7c61.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这里有这么多个view，层级如上图。

现在右子串上面10个子view在一次的层级变化中，被移除了。

![](http://upload-images.jianshu.io/upload_images/1194012-4014b85c072a588b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

那么最上层圈起来的3个view都会被影响。~~于是这3个view的bounds就发生了变化。于是就会隐式的调用setNeedsLayout，来获取新的bounds的信息。~~**(这里经过@kuailejim @冬瓜争做全栈瓜 和大神们实验，setNeedsLayout是需要我们开发者手动调用的，系统并不会在bounds改变的时候隐式调用setNeedsLayout方法)**。当前view的bounds改变，但是如果父view没有layout完成，那么父view也会继续收到setNeedsLayout消息。这个消息就会一直被往上传递，直到传到最顶层的view，顶层的view layout完成之后，将会重置下面关联的view的bounds，调用layoutSubview()方法。这时候，死循环就产生了。

![](http://upload-images.jianshu.io/upload_images/1194012-8a4946f8c09e222c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
~~这3个view就是上面3个view，下面的view需要setNeedsLayout，需要获取最新的bounds信息，中间蓝色的view也同样需要setNeedsLayout，于是又会让上层的view调用setNeedsLayout()方法，这个时候死循环就产生了。上下各有2个环，共同的view就是中间蓝色的view。环内的view都在相互的请求setNeedsLayout()，并且在自己layout完成以后又会去重置关联的view的bounds。这就形成了triggers layout。~~

大家对这里产生2个环产生了极大的好奇，热烈讨论这里会产生环的情况。目前可以想到会产生环的场景是这样子的:在上面的3颗子树，当某种场景下，突然删掉了右边的子树，假设用户的屏幕现在是全屏，由于一下子突然删掉了一堆view，那么原来那里就会变成空白，这个时候开发者想要把其他的view平铺到屏幕上。这个时候就需要改变上面父view的bounds，最下面的view会代码里面手动调用上面蓝色的view，setNeedsLayout()方法，并且把蓝色view的bounds设置成全屏，由于蓝色view的bounds改变，这个时候开发者代码里面又手动调用了蓝色view的父view，去执行setNeedsLayout()方法。top view代码里面又写了bounds = origRect，这时候就触发了蓝色view的layout，更新bounds。这样就产生了循环。同理下面也会形成循环。这样就产生了2个死循环了。**这些总结需要感谢@kuailejim @冬瓜争做全栈瓜 给出的指点。**


![](http://upload-images.jianshu.io/upload_images/1194012-71863fde64ba8227.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里是我们用工具收集到的log，第一行就是top-level view，接下来的就是递归的过程。往下看，我们会看见一些数字，这些数字就是view接到layout的次数，并且这些数字是有序的。一次死循环中这些数字就是循环时候的顺序。当然一个循环中，每个view可以是起点也可以是终点。这里我们默认把top view设置成起点。这样就可以向我们展示出死循环中一共牵扯进来了多少个view。

从log上看，上面有3个view，下面有10个view，加起来也不等于23，这是为什么呢？我们继续往下看log，来看看“Views receiving layout in order”这里面记录了些什么吧。

![](http://upload-images.jianshu.io/upload_images/1194012-333285494519f9d2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里我们可以很明显的看到，view接收到layout的顺序，一共正好23个。也可以看出，在一起循环中，一个view接收到layout的次数不止一次。

![](http://upload-images.jianshu.io/upload_images/1194012-1a2647a8c347ad9e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如上图所标示的，有2段在循环，有10个view接收到layout之后，再是2个view，紧接着又是10个view，再是1个view。

回到最初我们使用这个工具的用途上来，最初我们使用这个工具是用来查看 top-level view 接收到setNeedsLayout消息到底从哪里来。继续往下查找，找到调用的栈信息那里。

![](http://upload-images.jianshu.io/upload_images/1194012-b10dc1deecd2a7e5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
从上往下看，前几行肯定都是UIViewLayoutFeedbackLoopDebugging的信息。往下看，看到第6行，可以看到DropShadowView接受到了信息，准备setBounds。回看之前的层级信息，我们会发现DropShadowView是TransitionView的子view。

引起DropShadowView触发setBounds的唯一途径是，它的父view，TransitionView触发了setNeedsLayout()方法。因为这个时候TransitionView还没有layout。

![](http://upload-images.jianshu.io/upload_images/1194012-415e97e9fcf8b94f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
回到“geometry change records”,这个时候我们可以看到选中的这3行信息在一遍遍的循环。看第2行和第3行，我们可以看到是来自于TransitionView的layout。这时是合理的。再看第一行，会发现这个时候有一个TransitionView的子view调用了viewLayoutSubviews。

这个时候我们就定位到了bug的根源了，只要想方设法在layout的时候，不要改变superview的bounds即可以去掉这个死循环。

### 2.Ambiguous Layout From Constraints

在我们设置constraints约束的时候，常常会产生一些歧义的constraints。歧义的constraints通常不可怕，我们只需要稍稍做些调整，然后update all frame即可。

但是有如下的场景会导出形成环：

当你的view在旋转之后，constraints也随之变化，然后有些view在旋转之后的constraint就会相互冲突。因次有些constraint就形成了环。

这个问题在没有这个debugger工具的时候，思考起来很烧脑，没有任何头绪，这也是为什么log把top-level view放在第一行的原因，给我们暗示，从这里开始找bug的原因。

![](http://upload-images.jianshu.io/upload_images/1194012-bd525917ccd858da.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
在log，我们会看到好多的“Ambiguous Layout”。注意：tAMIC是Translates Auto Resizing Mask into Constraints的缩写。

我们来看看详细的log。看log之前，我们应该知道，constraint虽然冲突很多，但是可能引起冲突的constraint只有一个，也就是说当我们更正了其中一个constraint，很可能所有的冲突都解决了。
![](http://upload-images.jianshu.io/upload_images/1194012-2cc7f461bc91b5e4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
如上图log所示，在minX这里我们设置了2个带有冲突性的constraint，一个是-60，一个是-120。我们可以一个个的检查约束，但是这个列表很长，检查起来也比较麻烦。

那我们画图来分析一下这个问题。

![](http://upload-images.jianshu.io/upload_images/1194012-be202345d46bf519.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如图，label有leading和trailing padding，label是container的子view，container是action的子父，action是representation的子view。container和action view之间有一个居中的centering constraint。action view在representation view上有一个autoresizing mask constraints。

然后每个representation view之间是alignment对齐的。自此看来，这些view并没有足够的constraints能让这些view都能确定位置信息。比如在X轴上，这一串view是可以存在在任何的位置，所以产生了歧义的constraint。

解决上面的歧义的

```objc
-UIViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
-NSViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
 //Logs to com.apple.UIKit:LayoutLoop or com.apple.AppKit:LayoutLoop
```
用debugger就可以解决上述的问题。


## 总结
这个Xcode 8 给我们的Autolayout融合了之前Autoresizing masks的用法，使两个合并在一起使用，这样不同场景我们可以有更多的选择，可以更加灵活的处理布局的问题。还允许我们能手动调节constraints警告优先级别。

针对macOS的布局问题，又给我们带来了新的控件NSGridView

最后给我们带来的新的调试Layout Feedback Loop Debugging的工具，能让我们平时调试起来比较头疼的问题，有了工具可以有据可循，迅速定位问题，查找问题。

最后，请大家多多指教。



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/wwdc2016\_xcode8autolayout\_features/](https://halfrost.com/wwdc2016_xcode8autolayout_features/)

