# WWDC 2016 Session Notes - New Auto Layout Features in Xcode 8

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-520084e0dda3ed1e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Table of Contents
- 1.Incrementally Adopting Auto Layout
- 2.Design and Runtime Constraints
- 3.NSGridView
- 4.Layout Feedback Loop Debugging


## 1. Incrementally Adopting Auto Layout
What does Incrementally Adopting Auto Layout mean? When laying out our views in IB, we don't need to add all constraints at once. We can add constraints step by step, which simplifies the workflow and makes our setup more flexible. 

Before discussing the new feature, let's first introduce the background behind it.  

Consider this scenario: we place a view on its parent view without setting any constraints. When we run the app, it looks like the following image.
![](http://upload-images.jianshu.io/upload_images/1194012-637527eb1a0ca498.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Everything appears normal. But once we rotate the device by 90°, it looks like this:

![](http://upload-images.jianshu.io/upload_images/1194012-d716316a84356bf1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, you can see that the view's height, width, and its top and left margins have not changed. We did not set any constraints, so how is this achieved?

During compilation, the Auto Layout engine automatically and implicitly adds some constraints to the view to ensure that the view's size does not change. In this example, the view is given four constraints: top, left, width, and height.

If we need more dynamic resizing behavior, we need to define constraints ourselves in IB. This raises the question: is there a better way to do this? Ideally, there would be a way to achieve simple resizing behavior without using constraints.

This problem now has a solution. In Xcode 8, we can specify autoresizing masks for a view instead of setting constraints. This means that even without constraints, we can still achieve simple resizing behavior.

Before the Auto Layout era, some people may recognize this UI approach. It is the Springs & Struts UI model. We can define edge constraints (note: the "constraints" here do not refer to Auto Layout constraints, but to the rules in autoresizing masks). No matter how a view's width and height change, these views will resize together with the view for which those rules are configured.


![](http://upload-images.jianshu.io/upload_images/1194012-d66036d42faa95e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the example above, Xcode 8 can preserve the view's margins after screen rotation without adding any constraints. How does it do this? In fact, Xcode 8 first retrieves the autoresizing masks and then converts them into the corresponding constraints. This conversion happens at runtime. The reason the corresponding constraints are generated at runtime rather than compile time is to give developers a more convenient way to add more fine-grained constraints to a view.

On a view, we can set the `translatesAutoresizingMaskIntoConstraints` property.
```objc
translatesAutoresizingMaskIntoConstraints == true
```
Assuming the View already has constraints added in Interface Builder, the “Show the Size inspector” panel will still look the same as before. Click the View and inspect all the constraints added to it. At this point, Autoresizing masks are ignored, and the `translatesAutoresizingMask` property is also set to `false`. As shown below, we can no longer see the AutoresizingMask settings panel in the “Show the Size inspector” panel.

![](http://upload-images.jianshu.io/upload_images/1194012-8fa2f4a12705805d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-a572a36604c85ffd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
The image above shows that before the Auto Layout era, we had always been using autoresizing masks. But after Auto Layout arrived, once Auto Layout was enabled, the previous AutoresizingMask became ineffective.

Back to our original question: Xcode 8 now supports incremental adoption of Auto Layout for Views. This means we can start with AutoresizingMask to handle simple resizing, and then add appropriate constraints when more complex requirements arise. In short, Xcode 8 Auto Layout ≈ AutoresizingMask + Auto Layout.


Next, let’s use a demo to illustrate the new Auto Layout features in Xcode 8.  
Before getting into the example, let’s first look at what new functionality Xcode 8 added to storyboards. As shown below, a new bar has been added at the bottom, where you can switch between different screen sizes. You can see that iPhone has now diverged into 6 screen sizes that we need to adapt to. From largest to smallest, they are: iPad Pro 12.9, iPad 9.7, iPhone 6s Plus/iPhone 6 Plus, iPhone 6s/iPhone 6, iPhone SE/iPhone5s/iPhone5, and iPhone4s/iPhone4. Below that, you can also choose portrait/landscape orientation and adaptive layouts that do not use screen percentages.
![](http://upload-images.jianshu.io/upload_images/1194012-ccd7ee3afb97128c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Back to the example. We will now apply simple AutoresizingMask settings to these views on the page. In the preview on the right, you can see the effect after adding these masks.

First, for the pink parent View, we add the following AutoresizingMask.
![](http://upload-images.jianshu.io/upload_images/1194012-541263982f9d5004.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Add the following AutoresizingMask to the “Rainy” imageView.
![](http://upload-images.jianshu.io/upload_images/1194012-a72576207ebe4447.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Add the following AutoresizingMask to the “Cloudy” imageView.

![](http://upload-images.jianshu.io/upload_images/1194012-c17df0eec79dd816.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Finally, add an AutoresizingMask to the Label in the middle.

![](http://upload-images.jianshu.io/upload_images/1194012-d8df43f7952321be.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, rotate the screen and everything works as expected. The layout of the Views is exactly what we want.

![](http://upload-images.jianshu.io/upload_images/1194012-4df96205a8480096.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Now choose a 3:2 split-screen layout, and something goes wrong: the Label’s Width gets squeezed.

![](http://upload-images.jianshu.io/upload_images/1194012-55bf242088854780.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The reason is that Autoresizing masks, unlike Auto Layout, do not take the View’s content into account, so it gets compressed here.

To fix this Label, we can easily add a constraint. But here, let’s talk about another approach.

Go to the Attributes Inspector panel, find the Autoshrink property, and change “fixed font size” to “minimum font size”.


![](http://upload-images.jianshu.io/upload_images/1194012-79b7038d7df03eb8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This fixes the issue described above.

![](http://upload-images.jianshu.io/upload_images/1194012-d140165f6ca54036.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Even after switching back to landscape in split-screen mode, it now displays correctly.

![](http://upload-images.jianshu.io/upload_images/1194012-02e1709fd25a60e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Next, let’s handle the temperature Label in the middle. This time we have a more complex requirement, so we need to use constraints.

Hold down the Control key, drag to the parent View, and release. A menu will pop up. Then hold down Shift so we can select multiple constraints at once.

![](http://upload-images.jianshu.io/upload_images/1194012-793f4205c747a333.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-95aab84ae9baace3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Select “Center Horizontally in Container” and “Center Vertically in Container” at the same time. Note that the panel on the right is still the AutoresizingMask panel, because the Label does not yet have any constraints. When we click “Add Constraints”, constraints are added to the Label, and the panel on the right also changes to the constraints panel.

Now continue adding 2 constraints to this Label: “Horizontal Spacing” and “Baseline”.


![](http://upload-images.jianshu.io/upload_images/1194012-48e850a152987d86.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Similarly, drag from the Label to the “Sun” imageView, then add the “Horizontal Spacing” and “Baseline” constraints.

Now update the frame. As shown below, select “Update Frames”; at this point, all frames are completed.

![](http://upload-images.jianshu.io/upload_images/1194012-23546d448e5c177d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-04a9232b13c71d6d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Now update the font size of the temperature Label in the middle. The calculated size becomes larger, and because all our constraints are correct, the Views on both sides will also grow as the Label’s font size increases.


![](http://upload-images.jianshu.io/upload_images/1194012-3da0a819491ff184.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, Xcode 8 becomes smarter and immediately updates the frame automatically.


Next, add a background image for sunny Shanghai. Add an imageView, make it fill the entire parent View, and set the mode to “Aspect Fill”.

![](http://upload-images.jianshu.io/upload_images/1194012-7639cec83cd526d3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The usual approach would be to add constraints to this imageView so that this View has the same size as the parent View. But for this kind of simple resizing behavior, Xcode 8 no longer requires adding constraints. Here, we instead use Autoresizing masks to implement it. Add the following masks to the imageView.
![](http://upload-images.jianshu.io/upload_images/1194012-badadb886e9ff91e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Move the imageView to the background. At this point, the layout of our entire interface is complete.


![](http://upload-images.jianshu.io/upload_images/1194012-4917418adeac2aec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Test the landscape effect.
![](http://upload-images.jianshu.io/upload_images/1194012-9c3f8c4a5c4db2b3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Even split-screen works just fine!
![](http://upload-images.jianshu.io/upload_images/1194012-29ed778b3ce5e7aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
 

[Demo GitHub address](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/Xcode8AutolayoutDemo-master). There is nothing difficult in this demo; it is just for seeing the effect.

This is Incrementally Adopting Auto Layout in Xcode 8: Autoresizing masks and Auto Layout Constraint working together!


## II. Design and Runtime Constraints  

During development, we may encounter a situation where a View’s constraints are added based on the data you load. Therefore, before the app runs, we cannot know all of the constraints.

There are 3 approaches for handling the situation above.

### 1. Placeholder Constraints

Suppose we now need to place an image in the vertical and horizontal center of a View, with a leading margin from the left edge. We also need to preserve its aspect ratio. But we do not know what this image will ultimately look like. Only at runtime can we know the actual appearance of this image.

To be able to see our image in Interface Builder, we first estimate the image’s aspect ratio. Suppose we estimate it as 4:3. At this point, add constraints to the image and check “placeholder constraint”; this constraint will be removed at build time.


![](http://upload-images.jianshu.io/upload_images/1194012-ed8c011d75371e39.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After we obtain the image at runtime, we can then add the appropriate constraints and aspect ratio to it.


### 2. Intrinsic Content Size

This is similar to the scenario above. Sometimes we customize UIView or NSView instances, and the content inside these Views is dynamic. Interface Builder does not run our code, so until the app runs, we do not know the size inside. We can set an intrinsic content size for it.

![](http://upload-images.jianshu.io/upload_images/1194012-5f22d602933155e2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

>Setting a design time intrinsic content size only affects a view while editing in Interface Builder.The view will not have this intrinsic content size at runtime.  

Note the explanation above: intrinsic content size is essentially just a placeholder during layout. At runtime, this size no longer exists. So if we truly need to use this intrinsic content size during development, we need to override the content size.
```objc

override var intrinsicContentSize: CGSize
```

### 3.Turn Off Ambiguity Per View

This is a new feature in Xcode 8. When neither of the two approaches above can satisfy our requirements, this is the approach we need. Xcode 8 gives us the ability to dynamically adjust the warning level when constraints are ambiguous.

![](http://upload-images.jianshu.io/upload_images/1194012-4f433ddf72781326.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

In this scenario, we only know that we need to place this imageView horizontally centered, but we do not yet know the imageView’s size or its horizontal position. If we add only this single constraint, Interface Builder will show a red error, because based on the constraints we have provided, IB cannot uniquely determine the current view’s position.

If, later at runtime, after we have obtained the complete image information, we know how to add constraints ourselves, and we know how to lay things out so that the imageView’s position can be uniquely determined, then we can turn off IB’s red warning. Find “Ambiguous”, which controls the warning level, and select “Never Verify”. At that point, the red warnings and error indicators will disappear. However, the prerequisite for choosing this option is that we can guarantee that at runtime we will add enough constraints to fully define the view’s position information.

The three approaches above are the solutions we can use to add constraints to a view at runtime.


## III.NSGridView  

This is a new layout container introduced by macOS.

Sometimes maintaining correct constraints can be fairly tedious. For example, even for a simple group of checkboxes, maintaining the constraints is not always easy. In such cases, we often choose to use a stack view to make development easier.

The following image shows a common group of checkboxes in a macOS app.
![](http://upload-images.jianshu.io/upload_images/1194012-9cc9080a7861603d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, we would choose NS/UIStackView to implement it, because it has the following advantages: it can arrange a group of items, and more importantly, it can handle content size properly and control the spacing between each item.

However, there are still some scenarios that stack view does not handle very naturally. For example, the scenario shown below.

![](http://upload-images.jianshu.io/upload_images/1194012-e7c6eb85adbd76db.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This can still be implemented with a stack view, but it cannot help us align rows and columns based on the content.

This is why the new NSGridView was introduced.

With NSGridView, we can easily align content along both the X and Y axes. All we need to do is place the content into a predefined grid, and NSGridView will manage everything related to alignment for us.

Let’s look at the example below.
![](http://upload-images.jianshu.io/upload_images/1194012-a7194363c60b4d99.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


NSGridView has two child classes, NSGridRow and NSGridColumn. Together, they automatically manage the size of the content. Of course, when needed, we can specify the size, padding, and spacing. We can also dynamically hide certain rows and columns.

The job of NSGridCell is to manage the layout of the content view inside each cell. If the content of a cell exceeds the cell’s bounds, cells will be merged, just like in a typical spreadsheet app.

![](http://upload-images.jianshu.io/upload_images/1194012-0240de67714b42b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Let’s build a simple interface. The design is shown below:
![](http://upload-images.jianshu.io/upload_images/1194012-ef33742918f3879a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


We do not need to worry about the grid sizing; we only need to care about how many pieces of content need to be displayed in each row and each column.
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
The UI produced by running the code above looks like this:

![](http://upload-images.jianshu.io/upload_images/1194012-a561bbdcb0ff07c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Although there is nothing wrong with how we call the constructor, the resulting UI is clearly somewhat different from the design. The most obvious issue is that the UI has been stretched out, leaving a lot of empty space.

The cause of the problem is that the grid has been constrained to the edges of the window. Our intention should be for the window to match the size of our grid, but what is happening now is that the grid is being stretched to match the size of the window.

The way to solve this problem is to change the content hugging priority of the grid view. Even though the constraints on the page already have a high priority, we can still raise the priority further so that the constraints push the content away from the edges of the window. Let’s increase the priority a bit:
```objc
gridView.setContentHuggingPriority(600, for: .horizontal)
gridView.setContentHuggingPriority(600, for: .vertical)
```
![](http://upload-images.jianshu.io/upload_images/1194012-a1dd15524cd1dcf0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

We can see that the content in the window is now more compact, and the large empty space in the middle is gone.

Next, let’s address the empty space in the middle of the window: the label on the left is too far away from the content on the right. According to the design, we should right-align the labels. This is easy to do; we only need to adjust the cell’s placement information. Placement information affects cells, rows, columns, and the grid view.

If the cell’s `placement` attribute value is not specified, the row and column determine it based on the gridview’s `placement` attribute value. This rule allows us to set `placement` in one place and instantly change the layout of many cells.
```objc
//first column needs to be right-justified:
gridView.column(at: 0).xPlacement = .trailing
```
Find the first column of the gridView and change its xPlacement property value. This will make the cells in that column align to the right.


![](http://upload-images.jianshu.io/upload_images/1194012-1225a9d45ea39661.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


After right-aligning, a new problem appears: the baselines are no longer aligned.

![](http://upload-images.jianshu.io/upload_images/1194012-74949bdfced19d16.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Row alignment works the same way as column alignment. Similarly, we only need to configure it in one place, and it will affect the entire grid view.
```objc
// all cells use firstBaseline alignment
gridView.rowAlignment = .firstBaseline
```
![](http://upload-images.jianshu.io/upload_images/1194012-a61900a27d2bd610.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After the setup is complete, the entire grid view is aligned.

Next, let’s adjust the margin of the pop-up button.

![](http://upload-images.jianshu.io/upload_images/1194012-3201fb8701df1ed6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```objc
let row = gridView.cell(for: brailleTranslationPopup)!.row!
row.topPadding = 5
row.bottomPadding = 5
```
The approach of taking the first row here can be the same as the previous approach of taking the first column: simply take the row at index 0. Here, however, we’ll use a better approach. In `gridView`, find the cell that contains the pop-up button, and then find the corresponding row from that cell. This approach is better than directly using an index because if someone later adds another row at index 0, the code will break. With our code, however, it will continue to work, because we guarantee that we are retrieving the cell that contains the pop-up button. So try not to hard-code fixed indices in your code; doing so makes future maintenance more difficult.

Similarly, we also add Padding to the “status cells”.
```objc
ridView.cell(for:statusCellsLabel)!.row!.topPadding = 6
```
Here we need to compare the difference between padding and spacing.

Padding applies to the gaps between each row or each column. We can increase padding to change the spacing between individual pairs.
Spacing applies to the entire GridView. Changing it affects the layout of the entire grid view.

Now let’s look at our design mockup:

![](http://upload-images.jianshu.io/upload_images/1194012-ef33742918f3879a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Without padding, it would look like this:

![](http://upload-images.jianshu.io/upload_images/1194012-a44097139cef38b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Without spacing, it would look like this:

![](http://upload-images.jianshu.io/upload_images/1194012-559a56f9aa2f175e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

If neither spacing nor padding is set, everything gets crowded together:

![](http://upload-images.jianshu.io/upload_images/1194012-13509a34450af8b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Finally, let’s handle the bottom row that contains the checkbox cell.

![](http://upload-images.jianshu.io/upload_images/1194012-73c75d29bd25b172.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here we need to use what we mentioned earlier: merging two cells.
```objc
// Special treatment for centered checkbox:
let cell = gridView.cell(for: showAlertCB)!
cell.row!.topPadding = 4
cell.row!.mergeCells(in: NSMakeRange(0, 2))
```
Here we explicitly specify that the first two cells should be merged.

After the code runs, it will look like this.

![](http://upload-images.jianshu.io/upload_images/1194012-b181efe7718f5ae4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The cell in the last row will span the width of two cells. Although it occupies the space of two cells, it still inherits the right-alignment rule from the first column.

Now our requirement is that we want it to be neither right-aligned nor left-aligned.

A checkbox can in fact be aligned between two columns, but because the widths of these two adjacent columns are not equal, the gridview does not know how to arrange it. At this point, we need to manually adjust the layout.

Some people may be thinking here: why not just
```objc
cell.xPlacement = .none
```
Directly setting the cell's xPlacement to none would immediately disrupt the constraints-based layout of the entire gridview, so we can't do that. We need to keep adding additional constraints to the cell to maintain the balance of constraints across the entire gridview.
```objc
cell.xPlacement = .none
let centering = showAlertCB.centerXAnchor.constraint(equalTo: textStyleCB.leadingAnchor)
cell.customPlacementConstraints = [centering]
```
We only need to specify the checkbox anchors along the x-axis. At that point, the checkboxes will be arranged the way we want.

![](http://upload-images.jianshu.io/upload_images/1194012-6d6d0fdb84291a2d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, we have completed the requirement. To summarize, `NSGridView` is a new control that can help us build grid-like layouts very effectively. It lets us quickly and conveniently align the content we need to display. After that, we only need to adjust values such as padding and spacing.

## 4. Layout Feedback Loop Debugging

Sometimes, after we set up constraints, no errors are reported. However, in some cases, when the app runs, a large number of constraint conflicts appear in the debug console. In severe cases, the app may even crash directly. This kind of crash occurs when you hit a layout feedback loop.

This often happens during a “transition” phase, either at the beginning or at the end. For example, if you click a button, the button responds to your click, but afterward it does not pop back up and instead remains in the pressed state.

![](http://upload-images.jianshu.io/upload_images/1194012-c7f7e77d4a5642a3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

You will then observe that CPU usage maxes out, memory usage grows rapidly, and eventually the app crashes. At the same time, a large amount of layout-related stack trace information is returned.

![](http://upload-images.jianshu.io/upload_images/1194012-614c97ca5d350293.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The reason this happens is that the layout of some view keeps being executed over and over, falling into an infinite loop. The run loop never stops, and CPU usage stays at its peak. All messages are collected into autoreleased objects; as messages continue to be sent, they continue to accumulate. As a result, memory usage also grows rapidly.

One cause of this is the `setNeedsLayout` method.

![](http://upload-images.jianshu.io/upload_images/1194012-775542406d024aca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After one view calls `setNeedsLayout`, the call propagates to its parent view, which continues calling `setNeedsLayout`. The parent view’s `setNeedsLayout` may in turn trigger layout information for other views. If we can identify the caller during these mutual calls—that is, determine which view called this method—then we can analyze where these `setNeedsLayout` calls come from and where they go, and ultimately find the location of the infinite loop.

This information is indeed difficult to collect, which is why Apple specifically developed a tool to help us debug this and identify the root cause.

The switch for enabling this tool is in the “Arguments” section, as shown below.

![](http://upload-images.jianshu.io/upload_images/1194012-a46ee65eca84ff69.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```objc
-UIViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
-NSViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
// Logs to com.apple.UIKit:LayoutLoop or com.apple.AppKit:LayoutLoop
```
UIView is used on iOS, while NSView is used on macOS. Once we enable this switch, the layout feedback loop debugger starts recording every call to setNeedsLayout.

Here I set the threshold to 100.

If, within a single Runloop, layout is invoked on a view more times than the threshold—100 in this case—the infinite loop will continue running for a short while, because the debugger needs some time to record the relevant information. Once recording is complete, it immediately throws an exception. The information is also displayed in the logs. The log is recorded under com.apple.UIKit:LayoutLoop(iOS)/com.apple.AppKit:LayoutLoop(macOS).

We can also set a global exception break point.
In the debug window, we can also use the LLDB command po to print some debugging information.
![](http://upload-images.jianshu.io/upload_images/1194012-a83832771675c027.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Next, let’s look at two practical examples.

### 1.Upstream Geometry Change


![](http://upload-images.jianshu.io/upload_images/1194012-68dca9ff105c7c61.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Here we have multiple views, with the hierarchy shown above.

Now, in a single hierarchy change, the 10 child views on the right subtree are removed.

![](http://upload-images.jianshu.io/upload_images/1194012-4014b85c072a588b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Then the three views circled at the top level will all be affected. ~~As a result, the bounds of these three views change. This implicitly calls setNeedsLayout to obtain the new bounds information.~~**(After experiments by @kuailejim @冬瓜争做全栈瓜 and other experts, setNeedsLayout must be called manually by us developers; the system does not implicitly call setNeedsLayout when bounds changes)**. The current view’s bounds changes, but if the parent view has not completed layout, the parent view will also continue receiving setNeedsLayout messages. This message keeps propagating upward until it reaches the topmost view. After the topmost view finishes layout, it resets the bounds of the related views below and calls layoutSubview(). At this point, an infinite loop is created.

![](http://upload-images.jianshu.io/upload_images/1194012-8a4946f8c09e222c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
~~These three views are the three views above. The lower view needs setNeedsLayout to obtain the latest bounds information, and the blue view in the middle also needs setNeedsLayout, which in turn causes the upper view to call setNeedsLayout(). At this point, the infinite loop is created. There are two loops, one above and one below, and the shared view is the blue view in the middle. The views inside the loop keep requesting setNeedsLayout() from one another, and after completing their own layout, they reset the bounds of the related views. This forms triggers layout.~~

Everyone was very curious about how two loops are produced here, and there was a lively discussion about the situations in which loops can occur. The scenario we can currently imagine is this: among the three subtrees above, under some condition, the right subtree is suddenly deleted. Suppose the user’s screen is currently full-screen. Because a bunch of views are suddenly removed, the original area becomes blank. At this point, the developer wants to tile the other views across the screen. This requires changing the bounds of the parent view above. The bottom view manually calls setNeedsLayout() on the blue view above in code, and sets the blue view’s bounds to full-screen. Because the blue view’s bounds changes, the developer’s code then manually calls the blue view’s parent view to execute setNeedsLayout(). In the top view’s code, bounds = origRect is written again, which triggers layout on the blue view and updates bounds. This creates a loop. Similarly, another loop is formed below. This results in two infinite loops. **Thanks to @kuailejim @冬瓜争做全栈瓜 for their guidance on these conclusions.**


![](http://upload-images.jianshu.io/upload_images/1194012-71863fde64ba8227.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This is the log we collected using the tool. The first line is the top-level view, and the following lines show the recursive process. Looking further down, we see some numbers. These numbers are the number of times the view received layout, and they are ordered. In a single infinite loop, these numbers represent the order of the loop. Of course, in a loop, each view can be either the starting point or the ending point. Here, by default, we set the top view as the starting point. This lets us see how many views are involved in the infinite loop.

From the log, there are 3 views above and 10 views below, but together they do not add up to 23. Why is that? Let’s continue looking down the log and see what is recorded under “Views receiving layout in order”.

![](http://upload-images.jianshu.io/upload_images/1194012-333285494519f9d2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Here we can clearly see the order in which views receive layout, and there are exactly 23 in total. We can also see that in a single loop, a view may receive layout more than once.

![](http://upload-images.jianshu.io/upload_images/1194012-1a2647a8c347ad9e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As marked in the figure above, there are two segments in the loop: after 10 views receive layout, then 2 views, followed immediately by another 10 views, and then 1 view.

Returning to why we used this tool in the first place: initially, we used it to find out where the setNeedsLayout message received by the top-level view came from. Continue searching downward until you find the call stack information.

![](http://upload-images.jianshu.io/upload_images/1194012-b10dc1deecd2a7e5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
Reading from top to bottom, the first few lines are definitely UIViewLayoutFeedbackLoopDebugging information. Looking further down, at line 6, we can see that DropShadowView received the message and is about to setBounds. Looking back at the previous hierarchy information, we find that DropShadowView is a subview of TransitionView.

The only way to trigger setBounds on DropShadowView is for its parent view, TransitionView, to trigger setNeedsLayout(). This is because TransitionView has not laid out yet at this point.

![](http://upload-images.jianshu.io/upload_images/1194012-415e97e9fcf8b94f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
Going back to “geometry change records”, we can now see that the three selected lines are looping repeatedly. Looking at the second and third lines, we can see they come from the layout of TransitionView. This is reasonable. Looking at the first line, we find that a subview of TransitionView called viewLayoutSubviews at this point.

At this point, we have located the root cause of the bug. As long as we find a way to avoid changing the superview’s bounds during layout, we can eliminate this infinite loop.

### 2.Ambiguous Layout From Constraints

When we set constraints, we often create ambiguous constraints. Ambiguous constraints are usually not scary; we only need to make slight adjustments and then update all frame.

However, the following scenario can lead to a loop:

When your view rotates, the constraints also change accordingly, and after rotation, some views’ constraints conflict with one another. As a result, some constraints form a loop.

Without this debugger tool, thinking through this problem is extremely painful and gives you no clear direction. This is also why the log puts the top-level view on the first line: it hints that we should start looking for the cause of the bug from there.

![](http://upload-images.jianshu.io/upload_images/1194012-bd525917ccd858da.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
In the log, we see many “Ambiguous Layout” entries. Note: tAMIC is short for Translates Auto Resizing Mask into Constraints.

Let’s look at the detailed log. Before looking at the log, we should understand that although there may be many constraint conflicts, there may be only one constraint that actually causes the conflicts. In other words, once we correct one of the constraints, all the conflicts may very likely be resolved.
![](http://upload-images.jianshu.io/upload_images/1194012-2cc7f461bc91b5e4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
As shown in the log above, at minX we set two conflicting constraints: one is -60, and the other is -120. We could check the constraints one by one, but this list is very long, making it fairly troublesome to inspect.

So let’s draw a diagram to analyze this problem.

![](http://upload-images.jianshu.io/upload_images/1194012-be202345d46bf519.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As shown in the figure, the label has leading and trailing padding. The label is a subview of container, container is a subview of action, and action is a subview of representation. There is a centering constraint between container and the action view. The action view has autoresizing mask constraints on the representation view.

Then each representation view is aligned with the others. From this, it appears that these views do not have enough constraints to fully determine their positions. For example, on the X-axis, this chain of views can exist at any position, which produces ambiguous constraints.

The solution to the ambiguity above is
```objc
-UIViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
-NSViewLayoutFeedbackLoopDebuggingThreshold 100 // 50...1000
 //Logs to com.apple.UIKit:LayoutLoop or com.apple.AppKit:LayoutLoop
```
Using a debugger can solve the issue described above.


## Summary
Xcode 8’s Auto Layout integrates the previous usage of Autoresizing Masks, allowing the two to be used together. This gives us more options in different scenarios and lets us handle layout issues more flexibly. It also allows us to manually adjust the priority level of constraint warnings.

For layout issues on macOS, it also introduces a new control: NSGridView.

Finally, the new Layout Feedback Loop Debugging tool gives us a way to handle layout debugging problems that are usually quite painful, providing concrete clues so we can quickly locate and investigate issues.

Lastly, I welcome your feedback and suggestions.


> GitHub Repository: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/wwdc2016\_xcode8autolayout\_features/](https://halfrost.com/wwdc2016_xcode8autolayout_features/)