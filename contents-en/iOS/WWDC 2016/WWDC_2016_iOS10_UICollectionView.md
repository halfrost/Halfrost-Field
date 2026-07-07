# WWDC2016 Session Notes - New UICollectionView Features in iOS 10

<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-520084e0dda3ed1e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


## Preface 
The new UICollectionView features in iOS 10 are mainly reflected in the following three areas:
1. A smooth scrolling experience
Today, essentially everyone depends on their phone, and people use mobile apps every day. The quality of an app is determined by its user experience. In scrollable views, scrolling must be even smoother and more fluid to win users over. These new UICollectionView features can make your apps smoother than before, and you only need to add a small amount of code to achieve that.  
2. Improvements for self-sizing
The self-sizing API was introduced in iOS 8. iOS 10 adds more capabilities that make cells easier to adapt.  
3. Interactive reordering
This feature was introduced in iOS 9, and Apple significantly enhanced it in the iOS 10 API.


## Table of Contents
- 1. Smooth scrolling experience for UICollectionViewCell
- 2. Pre-Fetching for UICollectionViewCell
- 3. Pre-Fetching for UITableViewCell
- 4. Improvements for self-sizing
- 5. Interactive Reordering
- 6. UIRefreshControl

## I. Smooth Scrolling Experience for UICollectionViewCell 
As everyone knows, iOS devices have won a large user base with their excellent user experience. iOS responds immediately when the user taps the screen. A large portion of interactions also come from the user’s scrolling gestures. So smooth scrolling is a prerequisite for keeping users immersed in and enjoying an app. Next, let’s discuss what new features were added in iOS 10.

First, let’s look at the previous UICollectionView experience. Suppose each of our cells is simply blue; in real app development, cells are much more complex than this. First we generate 100 cells. When the user scrolls slowly, you may not notice any stutter, but when the user scrolls a long distance quickly, the stuttering of the entire UICollectionView becomes very obvious. If the DataSource for the cells is loaded from the network, the stutter becomes even worse. The effect is shown below.


![](http://upload-images.jianshu.io/upload_images/1194012-2357f133fd5961cf.gif?imageMogr2/auto-orient/strip)


If this kind of app were released on the App Store, users might very likely give it a one-star rating after using it. But why does this problem occur? Let’s analyze it. We’ll simulate how the system handles the reuse mechanism, as shown below.


![](http://upload-images.jianshu.io/upload_images/1194012-f3aebac8fa099ff6.gif?imageMogr2/auto-orient/strip)


In the image above, we can see that when a cell is about to be loaded onto the screen, the entire cell has already finished loading and is waiting outside the screen. More importantly, the cells waiting outside the screen are an entire row! All the cells in that row have already finished loading their data. This is the root cause of UICollectionView stuttering when the user scrolls a long distance quickly. In professional terms, this is called dropped frames.

Next, let’s discuss dropped frames in detail.  

Today’s users are very demanding. They expect a very smooth experience. Even a little bit of stutter can make them uninstall the app immediately. If we want users not to perceive any stutter, our app must reach a frame rate of 60 frames per second. In mathematical terms, that means each frame must be refreshed every 16 milliseconds.

Let’s use diagrams to analyze the dropped-frame problem. Below are two different frame scenarios.  

In the first case, the figure below shows the user scrolling slightly up and down. At this point, the loading pressure for each cell is not high. iOS has already done a good job optimizing for this situation, so the user does not perceive any stutter. In this case, no frames are dropped, and this is exactly the kind of smooth app experience users want.  
![](http://upload-images.jianshu.io/upload_images/1194012-61e63f9cf0819c8b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the second case, when the user scrolls a long distance quickly, the loading pressure for each cell is high. It may require a network request, or it may require reading from a database. Since an entire row of cells is loaded each time, the loading time for each cell increases, and the total time needed to load a row increases significantly as well, as shown below. As a result, not only is the current frame loading cells, but the total time also spills over into the time budget for the next frame. In this situation, the user perceives stutter.

![](http://upload-images.jianshu.io/upload_images/1194012-c1c21562f28f212a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Let’s explain the dropped-frame behavior in these two scenarios another way. We use the criteria in the figure below to evaluate the two cases above. The figure below is divided into two parts. The red area at the top represents the dropped-frame region, because it is above 16 ms. The boundary between the red and green regions is at 16 ms. The y-axis represents the time the CPU spends on the main thread. The x-axis represents refresh events that occur while the user is scrolling.  

![](http://upload-images.jianshu.io/upload_images/1194012-5b3c7220a9742932.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)  

For the dropped-frame situation described above, we can plot the experimental data as shown below. What deserves our attention is that the curve is very jagged and not smooth at all. When the user scrolls a long distance quickly, the peak exceeds 16 ms. When the user scrolls slowly, the frame rate can stay in the relatively smooth region. Cells loaded within the green region have very low loading pressure. This is the scenario where frames are sometimes dropped and scrolling is sometimes smooth. In this scenario, the user experience is very poor.
![](http://upload-images.jianshu.io/upload_images/1194012-742100ebb16ca993.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

So how do we solve this problem? Let’s look at the figure below:


![](http://upload-images.jianshu.io/upload_images/1194012-66aee8c339f703c7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
The curve in the figure above looks much smoother, and in this situation, dropped frames no longer occur. Every interval during scrolling can reach 60 FPS. How is this achieved? Because the loading work for each cell is evenly distributed. Individual cells no longer fall into the two extremes of being very busy or very idle. This eliminates the previous peaks and valleys, making the curve nearly a horizontal straight line. 


How do we distribute the loading pressure across cells? This brings us to the new cell lifecycle.  

First, let’s look at the old UICollectionViewCell lifecycle. When the user scrolls the screen, a cell outside the screen is about to be loaded and displayed.

![](http://upload-images.jianshu.io/upload_images/1194012-1e6f8e72fba43498.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, we take the cell out of the reuse queue and then call prepareForReuse. This method gives the cell time to reset itself, reset its state, refresh the cell, and load new data.


![](http://upload-images.jianshu.io/upload_images/1194012-c26df5728427d953.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As scrolling continues, cellForItemAtIndexPath is called. This method is where we developers define how to configure the cell. Here we populate the data model, assign it to the cell, and then return the cell to the iOS system.


![](http://upload-images.jianshu.io/upload_images/1194012-91a745c8edf6f8e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
When the cell is about to enter the screen, willDisplayCell is called. This method gives our app one last opportunity to perform final preparation before the cell enters the screen. After willDisplayCell finishes executing, the cell enters the screen.


![](http://upload-images.jianshu.io/upload_images/1194012-1339cb009c3810bf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
After the cell has completely left the screen, didEndDisplayingCell is called. The above is the entire UICollectionViewCell lifecycle before iOS 10.


Next, let’s look at what the UICollectionViewCell lifecycle looks like in iOS 10.


![](http://upload-images.jianshu.io/upload_images/1194012-67440aea27bca091.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This is still the same as iOS 9. When the user scrolls the UICollectionView and a cell is needed, we take a cell from the reuse queue and call prepareForReuse. Pay attention to when this method is called: it is called ahead of time, before the cell enters the screen. Notice the difference from iOS 9. In iOS 9, the method was called only when the upper edge of the cell was about to enter the screen. Here, the entire cell lifecycle has been moved earlier, to the point where the cell is still outside the device’s visible area.


![](http://upload-images.jianshu.io/upload_images/1194012-a17f0da0f0c23533.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

This is still the same as before: in cellForItemAtIndexPath, the cell is created, data is populated, state is refreshed, and so on. Note that this part of the lifecycle is also earlier than in iOS 9.


The user continues scrolling, and now things are different!  


At this point, we do not call willDisplayCell yet! The principle followed here is: call willDisplayCell only when the cell is actually going to be displayed.


![](http://upload-images.jianshu.io/upload_images/1194012-84563cde3084c866.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
When the cell is about to be displayed, we then call willDisplayCell.  


![](http://upload-images.jianshu.io/upload_images/1194012-0f7c0d6a0c5ad1fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
When the entire cell is about to disappear from the visible region of the UICollectionView, didEndDisplayingCell is called. What happens next is the same as in iOS 9: the cell enters the reuse queue.  


If the user wants to display a particular cell in iOS 9, the cell can only be taken from the reuse queue, go through the lifecycle again, and call cellForItemAtIndexPath to create or generate a cell.  

In iOS 10, the system keeps the cell around for a period of time. In iOS, if the user scrolls a cell off the screen and then suddenly wants to come back, the cell does not need to go through the lifecycle again. It only needs to call willDisplayCell directly. The cell will then appear on the screen again. This is the entire UICollectionView lifecycle in iOS 10.


![](http://upload-images.jianshu.io/upload_images/1194012-38285868d022c65d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-e76c5772fe94b6de.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-d98623c78588707f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-aec86f77678e3d84.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-0d966174af80472f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The iOS 10 scenario described above also applies to multi-column layouts. In this case, we load only one cell at a time instead of loading an entire row of cells each time. After the first cell is ready, we then ask the second cell to prepare. After both cells are ready, we then call willDisplayCell for each cell. Once this message has been sent, the cells appear on the screen.

Although this looks like a very small change, this tiny change greatly improves the user experience!

Let’s look at the impact of the changes above on scrolling.


![](http://upload-images.jianshu.io/upload_images/1194012-c832a32902927e60.gif?imageMogr2/auto-orient/strip)


Scrolling is much smoother than with the iOS 9 flow. Here you can see that the entire process is very smooth, without stuttering.


Still as with iOS 9, let’s simulate how the system loads cells.


![](http://upload-images.jianshu.io/upload_images/1194012-561985a86edbd74a.gif?imageMogr2/auto-orient/strip)

We can clearly see that the iOS system loads cells one by one. After one cell finishes loading, it goes on to load the next cell. This is very different from iOS 9, where an entire row of cells was loaded.  

This is because we are using the new UICollectionViewCell lifecycle. The entire app does not need a single additional line of code. The smooth scrolling experience in iOS 10 is really fantastic!


## II. Pre-Fetching for UICollectionViewCell

When we compile an iOS 10 app, this Pre-Fetching feature is enabled by default. Of course, if for some reason you must use the old lifecycle from before iOS 10, you only need to add the new isPrefetchingEnabled property to the collectionView. If you do not want to use Pre-Fetching, set this property to false.
```

@property (nonatomic, getter=isPrefetchingEnabled) BOOL prefetchingEnabled NS_AVAILABLE_IOS(10_0);

[collectionView setPrefetchingEnabled:NO];

```
To best practice this new feature, let’s first change the way we load cells. We’ll move the heavyweight data-reading operations and all content creation into the `cellForItemAtIndexPath` method. Make sure that we basically do nothing else in `willDisplayCell` and `didEndDisplayCell`. Finally, note that some cells generated by `cellForItemAtIndexPath` may never be displayed on screen. One such case is when a cell is about to be displayed, but the user suddenly scrolls away from the view.

If you compile your app with iOS 10 at this point, a very smooth user experience will be optimized automatically.

Now that smooth scrolling in `UICollectionView` has been addressed, how do we solve the time spent loading `UICollectionViewCell`?

The loading time of a `UICollectionViewCell` depends on the `DataModel`. The `DataModel` may load images from the network or from a local database. Most of these operations are asynchronous. To make data loading faster, iOS 10 introduced new APIs to solve this problem.

`UICollectionView` has two “partners”: the data source and the delegate. In iOS 10, it gets a third “partner”. This “partner” is called `prefetchDataSource`.
```
protocol UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView,
                        prefetchItemsAt indexPaths: [NSIndexPath])
    optional func collectionView(_ collectionView: UICollectionView,
                                 cancelPrefetchingForItemsAt indexPaths: [NSIndexPath])
}
class UICollectionView : UIScrollView {
    weak var prefetchDataSource: UICollectionViewDataSourcePrefetching?
    var isPrefetchingEnabled: Bool
}
```
There is only one required method in this protocol—ColletionView prefetchItemsAt indexPaths. This method is called inside prefetchDataSource and is used to let you asynchronously preload data. The indexPaths array is ordered; it represents the order in which the upcoming items will receive data, making it more convenient for our model to process data asynchronously.  

There is also a second method in this protocol, CollectionView cancelPrefetcingForItemsAt indexPaths, but this method is optional. We can use this method to handle canceling data preloading, or lowering its priority, during scrolling.


It is worth noting that the newly added “helper” prefetchDataSource cannot replace the original data loading method. This preloading is only an auxiliary way to load data, and we cannot
remove the original method we use to read data.

At this point, let’s look at how much UICollectionView performance has improved since the beginning of the article. We will still use dropped frames to evaluate UICollectionView performance.

![](http://upload-images.jianshu.io/upload_images/1194012-5b6b9e2c3350a172.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The image above shows UICollectionView performance on iOS 9. It is obvious that the peaks and valleys are very pronounced, and 8 frames were dropped, resulting in noticeable stuttering.

![](http://upload-images.jianshu.io/upload_images/1194012-0f8356b077664bae.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows UICollectionView performance on iOS 10. We can clearly see that, after the optimizations in iOS 10, the entire curve has become noticeably smoother, with no extreme peak-related frame drops. However, there are still a small number of peaks approaching the 16 ms threshold.


![](http://upload-images.jianshu.io/upload_images/1194012-24bf2be2c051eb80.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows the performance after using iOS 10 + the Pre-Fetching API. The optimization effect is already very obvious! The entire curve is basically flat—almost perfect. However, we can still see that a few peaks are particularly high. Those particularly high peaks occur where the cell has a heavy loading workload and takes relatively longer. Next, we will continue optimizing!

First, let’s summarize the things to keep in mind when using the Pre-Fetching API.
1. When using the Pre-Fetching API, we must ensure that the entire preloading process runs on a background thread. Use GCD and NSOperationQueue appropriately to handle multithreading well.  

2. Keep in mind that the Pre-Fetching API is an adaptive technology. What is adaptive technology? When we scroll slowly, during this “quiet” period, the Pre-Fetching API will silently preload data for us in the background. However, once we scroll quickly and need frequent refreshes, we will not execute the Pre-Fetching API.  

3. Finally, use cancelPrefetchingAPI to respond to changes in the user’s scrolling behavior. For example, if the user is scrolling quickly and suddenly notices something interesting, then stops scrolling, or even quickly scrolls in the opposite direction, or taps an event and goes into the detail view, we should enable cancelPrefetchingAPI at those moments. 

In summary, the Pre-Fetching API is very helpful for improving UICollectionView performance, and it does not require adding much code. With just a small amount of code, you can achieve a huge performance improvement!  


## 3. UITableViewCell Pre-Fetching

In iOS 10, UITableViewCell also received performance improvements alongside UICollectionView, and it likewise gained the Pre-Fetching API.
```
protocol UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [NSIndexPath])
    optional func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths:
                            [NSIndexPath])
}
class UITableView : UIScrollView {
    weak var prefetchDataSource: UITableViewDataSourcePrefetching?
}
```
As with `UICollectionView` above, the TableView `prefetchRowsAt indexPaths` method will be called. `indexPaths` is still an ordered sequence of numbers, and the order corresponds to the visible order in the list. The second optional API is still TableView `cancelPrefetchingForRowsAt indexPaths`; as mentioned earlier, it is also used to cancel preloading. The performance improvement is the same as with `UICollectionView`, and it greatly improves `UITableView` performance!


## 4. Improvements for self-sizing

The self-sizing API was first introduced in iOS 8, and it has now received some improvements in iOS 10.

In `UICollectionView`, there is a fixed class called `UICollectionViewFlowLayout`. iOS already fully supports self-sizing in this class. To enable this feature, developers need to set an estimated item size for cells whose `CGSize` cannot be 0.
```

layout.estimatedItemSize = CGSize(width:50,height:50)
```  
This tells `UICollectionView` that we want to enable a layout that dynamically calculates its content.

So far, we have three ways to lay out content dynamically.

1. The first approach is to use Auto Layout.  
When we add the constraints correctly, the cell lays itself out dynamically based on its content as it loads.

2. The second approach, if you don’t want to use Auto Layout and prefer more manual control, is to override the `sizeThatFits()` method.

3. The third and most advanced approach is to override the `preferredLayoutAttributesFittingAttributes()` method. In this method, you can provide not only size information, but also information such as `alpha` and `transform`.

So if you want to specify the cell size, you can use one of the three methods above.

In practice, however, we may find that setting an appropriate estimated item size is sometimes difficult. It would be great if the flow layout could calculate the layout dynamically using math, rather than laying things out based on the size we provide.

iOS 10 introduced new APIs to solve the problems described above.
```
layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
```
For developers, all we need to do is set up the flow layout, assign a new constant to `estimatedItemSize`, and then `UICollectionViewFlowLayout` will automatically calculate the height.

The system will automatically compute the entire layout, including cells whose size has already been determined, and it will also dynamically predict the sizes of upcoming cells.

Next, let’s look at two examples that clearly show the self-sizing improvements in iOS 10.


![](http://upload-images.jianshu.io/upload_images/1194012-8c9bad76b1cf453c.gif?imageMogr2/auto-orient/strip)

As shown above, the iOS 9 layout is calculated on a per-cell basis. When a single cell changes, the other cells remain unchanged and still need to be recalculated.


![](http://upload-images.jianshu.io/upload_images/1194012-38a291c2d0daacc0.gif?imageMogr2/auto-orient/strip)

This example makes the difference very clear. After we change the size of the first cell, the system automatically calculates the sizes of all cells, and the size of each row and each section is computed dynamically and the UI is refreshed.

That’s the self-sizing improvement in iOS 10.


## V. Interactive Reordering  

When it comes to reordering, we can compare it to `UITableView`: reordering in `UICollectionView` is like moving cells up and down in `UITableView`, except that `UITableView` reordering is limited to the vertical direction.

In iOS 9, `UICollectionView` introduced Interactive Reordering. In this year’s iOS 10, several new APIs were added.

![](http://upload-images.jianshu.io/upload_images/1194012-fedd66fb206d0beb.gif?imageMogr2/auto-orient/strip)

In the image above, we can see that even if we drag cells arbitrarily, the entire interface is reordered. And after we change the cell sizes, the entire `UICollectionView` is dynamically laid out again.  


Let’s first look at the APIs in iOS 9.
```

class UICollectionView : UIScrollView {
    func beginInteractiveMovementForItem(at indexPath: NSIndexPath) -> Bool
    func updateInteractiveMovementTargetPosition(_ targetPosition: CGPoint)
    func endInteractiveMovement()
    func cancelInteractiveMovement()
}
```
To enable interactive movement, we need to call the beginInteractiveMovementForItem() method, where indexPath represents the cell we are about to move. Then, on each gesture update, we need to update the cell’s position to respond to the movement of the user’s finger. At this point, we need to call the updateInteractiveMovementTargetPosition() method. We pass the coordinate changes through the gesture. When the movement ends, endInteractiveMovement() is called. UICollectionView will drop the cell and complete the entire layout process. At this point, you can also refresh the model or process the data model. If the gesture is suddenly cancelled midway, you should call cancelInteractiveMovement(). If we move the cell around and then put it back in its original position, that is effectively a cancelled move, so in cancelInteractiveMovement() you should not refresh the data source.

In iOS 10, if you use UICollectionViewController, this reordering becomes even simpler for you.
```

class UICollectionViewController : UIViewController {
    var installsStandardGestureForInteractiveMovement: Bool
}
```  
You only need to set the `installsStandardGestureForInteractiveMovement` property to `True`. `CollectionViewController` will automatically add the gesture for you and automatically call the method above.


That covers the APIs Apple added for us in iOS 9 last year.

The new API added in iOS 10 this year builds on iOS 9 by adding page-turning functionality.  
`UICollectionView` inherits from `UIScrollView`, so all you need to do is set the `isPagingEnabled` property to `True` to enable paging.
```

collectionView.isPagingEnabled = true
```  
Before enabling paging:

![](http://upload-images.jianshu.io/upload_images/1194012-843decaf48445ce9.gif?imageMogr2/auto-orient/strip)


After enabling paging, it looks like this:


![](http://upload-images.jianshu.io/upload_images/1194012-7d2a6304b914cc59.gif?imageMogr2/auto-orient/strip)

Each movement flips by one page.  


## 6. UIRefreshControl  

UIRefreshControl can now be used directly inside a CollectionView. Likewise, it can also be used directly inside a UITableView, without depending on UITableViewController. This is because RefreshControl has now become a property of ScrollView.

Using UIRefreshControl is very simple—just three steps:
```

let refreshControl = UIRefreshControl()
refreshControl.addTarget(self, action: #selector(refreshControlDidFire(_:)),
                         for: .valueChanged)
collectionView.refreshControl = refreshControl
```
First create a refreshControl, then associate an action event with it, and finally assign this new refreshControl to the corresponding property of the control you want.


## Summary

From the above, we covered the following:
1. UICollectionView cell pre-fetching mechanism
2. The new UICollectionView and UITableView prefetchDataSource APIs 
3. Improvements for self-sizing cells
4. Interactive reordering


Finally, let me share my thoughts after looking at the UICollectionView optimizations in iOS 10. In the past, AsyncDisplayKit was used in some places to optimize UICollectionView performance; now you can consider avoiding third-party libraries for optimization. The system-provided approaches can solve common stuttering issues. I feel that UICollectionView in iOS 10 is finally a more complete version; the optimizations in previous systems were not sufficient. I’m still very optimistic about UICollectionView in iOS 10.

Feedback and suggestions are welcome.


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/wwdc2016\_ios10\_uicollectionview\_new\_features/](https://halfrost.com/wwdc2016_ios10_uicollectionview_new_features/)