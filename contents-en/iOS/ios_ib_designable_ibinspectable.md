# Things to Watch Out for with IB_DESIGNABLE / IBInspectable


![](https://img.halfrost.com/Blog/ArticleTitleImage/17_0.png)


#### Preface

The two keywords IB_DESIGNABLE / IBInspectable were introduced in Xcode 6. In the WWDC 2014 session "What's New in Interface Builder", Apple demonstrated an example using Swift.

These two keywords are used on custom Views. **Currently, they can only be used on subclasses of UIView**, so applying these keywords to the native controls provided by the system has no effect.

>Live RenderingYou can use two different attributes—@IBDesignable and @IBInspectable—to enable live, interactive custom view design in Interface Builder. When you create a custom view that inherits from the UIView class or the NSView class, you can add the @IBDesignable attribute just before the class declaration. After you add the custom view to Interface Builder (by setting the custom class of the view in the inspector pane), Interface Builder renders your view in the canvas.You can also add the @IBInspectable attribute to properties with types compatible with user defined runtime attributes. After you add your custom view to Interface Builder, you can edit these properties in the inspector.

The general idea is “what you see is what you get”: we can render custom code into Interface Builder in real time. The bridge that makes this possible consists of two directives: @IBDesignable and @IBInspectable. With @IBDesignable, we tell Interface Builder that this class can be rendered into the interface in real time. No matter how complex our drawRect implementation is, or how complex the customization is, Xib / Storyboard can compile it and render it for display. However, this class must be a subclass of UIView or NSView. With @IBInspectable, we can define dynamic properties, allowing their values to be visually modified in the Attributes inspector panel.
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


These two keywords are not today’s focus; you can learn how to use them by looking at a demo.
[Demo](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/CircleSlider-master)

If you want to watch the sessions, you can check out these two WWDC 2014 links  
[whats\_new\_in\_xcode\_6](http://devstreaming.apple.com/videos/wwdc/2014/401xxfkzfrjyb93/401/401_whats_new_in_xcode_6.pdf?dl=1)  
[whats\_new\_in\_interface\_builder](http://devstreaming.apple.com/videos/wwdc/2014/411xx0xo98zzoor/411/411_whats_new_in_interface_builder.pdf?dl=1)  
[Apple Official Documentation](https://developer.apple.com/library/ios/recipes/xcode_help-IB_objects_media/Chapters/CreatingaLiveViewofaCustomObject.html#//apple_ref/doc/uid/TP40014224-CH41-SW1)

Today I’d like to share some of the issues I ran into while using these two keywords, along with how I resolved them.

#### 1.The agent raised a "NSInternalInconsistencyException" exception
```objectivec    
file://BottomCommentView-master/BottomCommentView/Base.lproj/Main.storyboard: error: 
IB Designables: Failed to update auto layout status: The agent raised a "NSInternalInconsistencyException" exception: Could not load NIB in bundle: 'NSBundle </Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Overlays> (loaded)' with name 'BottomCommentView'

file://BottomCommentView/Base.lproj/Main.storyboard: error:
 IB Designables: Failed to render instance of BottomCommentView: The agent threw an exception.

```
We can see that the Designables section in the panel shows `Crashed`. Xib / Storyboard can actually crash too! The app itself runs, but there are two errors reported — unacceptable! These two errors are actually Xib errors reported at compile time, not runtime errors.

![](https://img.halfrost.com/Blog/ArticleImage/17_3.png) 


When we see `Debug`, the first thing that comes to mind is definitely to click `Debug`. Unfortunately, in this case, clicking `Debug` will always tell you “Finishing debugging instance of XXXX for interface Builder”. Even if you set a breakpoint inside your custom View, it won’t help.

Back to the issue. Let’s take a closer look at the crash message. It says `Could not load NIB in bundle`, and also gives us something that looks like a path.
```vim  
'NSBundle </Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Overlays> (loaded)'
```  
We can pinpoint that the error occurs when the Xib is being read from the bundle.

After looking up some information online, the issue is actually this:

>When loading the nib, we're relying on the fact that passing bundle: nil defaults to your app's mainBundle at run time.

Every time we retrieve mainBundle, we use the default method.
```objectivec    
let nib = UINib(nibName: String(StripyView), bundle: nil)
```
When compiling the Xib / Storyboard here, we need to tell iOS which bundle class to use for loading. Just change the code above to the following.
```objectivec    
let bundle = NSBundle(forClass: self.dynamicType)
let nib = UINib(nibName: String(StripyView), bundle: bundle)
```
Or like this
```objectivec    

#if TARGET_INTERFACE_BUILDER
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        [bundle loadNibNamed:@"BottomCommentView" owner:self options:nil];

#else
        [[NSBundle mainBundle] loadNibNamed:@"BottomCommentView" owner:self options:nil];
        
#endif
```
PS: If your custom View does not appear in the Xib / Storyboard, but the View shows up as soon as the program runs, this may also be the reason. Although Xib / Storyboard does not report an error, because the app has not run yet, Xib / Storyboard does not know the context, so it does not load our custom View.

#### 2. The custom control still does not appear correctly in code or Xib

If you added the bundle-related code mentioned in the first issue above and it still does not display, the code may have been added in the wrong place.

If the control is created manually in code, the initWithFrame method will be called.
```objectivec    

- (instancetype)initWithFrame:(CGRect)frame
```
If the control is added by dragging it in a Xib / Storyboard, the `initWithCoder` method will be called.
```objectivec    

- (instancetype)initWithCoder:(NSCoder *)aDecoder
```
You need to add the bundle method in the corresponding two methods. To be safe, add the code from Question 1 to both of these init methods.

#### 3.Failed to update auto layout status: The agent crashed / Failed to render instance of XXXXXXX: The agent crashed
```objectivec    
file://BottomCommentView/Base.lproj/Main.storyboard: error: 
IB Designables: Failed to update auto layout status: The agent crashed

file://BottomCommentView/Base.lproj/Main.storyboard: error: 
IB Designables: Failed to render instance of BottomCommentView: The agent crashed

```
If you run into this issue, it’s fairly serious. Unlike the first issue—where the entire app can still run and the error comes from a Xib / Storyboard compilation problem without affecting the app’s execution—this one is different.

This issue will directly cause the entire app to crash. There’s no way around it; we have to set breakpoints and debug it.

If you enable Debug under Designables and set breakpoints in `initWithCoder` and `initWithFrame`, you’ll find that the program always reaches this line  
```objectivec     

self = [super initWithCoder:aDecoder];
```  
Or this line  
```objectivec    

self = [super initWithFrame:frame];
```  
It crashed. In fact, you can quickly see what happened from the stack trace below:


![](https://img.halfrost.com/Blog/ArticleImage/17_4.png) 

![](https://img.halfrost.com/Blog/ArticleImage/17_5.png) 


It is very obvious that the initWithCoder method has fallen into an infinite loop. That infinite loop caused the program to crash.

But why would there be an infinite loop here? The root cause is that the class of our custom class was set to itself.

Let’s take a look at what actually happened. In Xcode 7, when we create a View by default, Xcode does not generate a XIB file for us by default. A ViewController has the option shown below, which we can choose to check.

![](https://img.halfrost.com/Blog/ArticleImage/17_6.png) 


After we create this class, we also need to create a Xib and associate it with the class.

Now compare this with the process of creating a TableviewCell.  

![](https://img.halfrost.com/Blog/ArticleImage/17_7.png) 


Generally, we check “Also create XIB file”. After creation, we fill in the class name of this cell in Custom Class.

If we do the same thing when customizing a View—after creating the Xib file and associating File’s Owner, we then fill in our custom class in Custom Class—then at this point it is wrong!

Why does the same approach we usually use become wrong here?

Let’s think about the loading process of our custom View. This custom View must be placed on a ViewController, either created in code or dragged directly onto a Xib / Storyboard. Whether we create it in code or drag a View onto the SB, we need to specify what class it is. There is no doubt about this; it is absolutely correct. The class of the View dragged onto the SB must be set to our custom View.

However, when loading this View, it will go through initWithCoder / initWithFrame. Inside these methods, it will call the corresponding super method. Now that we have set the class to itself, based on the debug log above, we can see that after initWithCoder, the following call path is taken.

[NSBundle loadNibName] —— [UINib instantiateWithOwner:options] ——[UINibDecoder decodeObjectForKey:]——UINibDecoderDecodeObjectForValue——[UIRuntimeConnection initWithCoder]——[UINibDecoder decodeObjectForKey:]——UINibDecoderDecodeObjectForValue——[UIClassSwapper initWithCoder:]——[BottomCommentView initWithCoder:]

Starting from NSBundle loading, after parsing, it calls ClassSwapper’s initWithCoder. Since we set the class to itself, it falls into an infinite loop here. The program crashes! This is just like calling dot-syntax assignment inside a setter method, resulting in infinite recursive calls.


After the analysis above, we know that the problem is that we call loadNibName again inside initWithCoder, and loadNibName eventually calls UIClassSwapper initWithCoder. Does that mean our custom class is wrong? If we compare it with our custom tableViewCell, its class is also itself, so why doesn’t it have this problem?

Let’s look carefully at how tableViewCell is loaded. The class of our Xib is still itself, but the registerWithNibName method is called in the tableView, so it will not recurse infinitely.

Of course, we can imitate that approach here as well. We would need to move loadNibName into another class. The class would still be set to itself, and that other class would load this View. This way, it would not crash and would not recurse infinitely. But then another problem arises: we can no longer preview our View in real time on the Xib/Storyboard.

Here we need to mention how IB_DESIGNABLE works. After we use the IB_DESIGNABLE keyword, Xib/StoryBoard will compile and run the code for this View without running the entire application. Since there is no application context, all compilation happens only within the code of this view.

We drag a View into the ViewController and change its class to our custom class. From that point on, all rendering of the view will be handed over to our custom view class, and managed by that class. There are two cases here. The first case is the Demo example I gave at the beginning of the article, where DrawRect code is used to draw the appearance of this View. This will not cause any problem. The second case is that we also want to use a Xib to display the View. This is a case where a Xib is loaded again inside a Xib/StoryBoard. Since our custom class has now taken over the rendering responsibility for the entire view, we should call loadNibName in initWithCoder to load the entire View during initialization. Based on the analysis above, we found that the crash is caused by infinite recursion, but we also must call initWithCoder here. The only solution is to change the class to the parent class, namely UIView. At that point everything works: Xib/Storyboard no longer reports an error, and it can also display the view’s appearance immediately.

To summarize:
> when using loadNibNamed:owner:options:, the File's Owner should be NSObject, the main view should be your class type, and all outlets should be hooked up to the view, not the File's Owner.

PS. What is being discussed here is only loadNibNamed, not initWithNibName. While we’re at it, let’s mention the difference between the two. The class of the Xib loaded by initWithNibName is the ViewController we define. The class of the Xib loaded by loadNibNamed is NSObject. They also load differently. The initWithNibName method uses lazy loading: the controls on this View are nil, and they only become non-nil when they need to be displayed. loadNibNamed loads immediately: all elements in the xib object loaded by calling this method already exist.


#### Summary
When I first learned about IB_DESIGNABLE / IBInspectable, I found it especially magical: even our customized Views could be visible immediately. However, after some research, I found that IB_DESIGNABLE / IBInspectable still have some limitations. IB_DESIGNABLE can currently only be used in subclasses of UIView. Common cases such as adding rounded corners to UIButton still cannot be previewed. IBInspectable essentially sets values in Runtime Attributes, which also means IBInspectable can only use common types. A type like NSDate cannot be set as IBInspectable.

The above are some of the “pitfalls” I encountered while using IB_DESIGNABLE / IBInspectable and wanted to share with you.


#### Update:
For the following section, I want to thank @**Andy矢倉** for pointing this out to me on Weibo. In fact, subclasses of system controls can be handled like this: extract common base classes for several commonly used controls, and use External to factor out common properties. For something more complex, see this library: [IBAnimatable](https://github.com/JakeLin/IBAnimatable)

@**Andy矢倉** also reminded me that when using this feature, it is best to use iOS 8 + Swift. With OC or iOS 7, Failed to update may occur and there is no solution. Thanks again to @**Andy矢倉** for the guidance!!! The image below shows his visual customization of system controls!

![](https://img.halfrost.com/Blog/ArticleImage/17_8.png)