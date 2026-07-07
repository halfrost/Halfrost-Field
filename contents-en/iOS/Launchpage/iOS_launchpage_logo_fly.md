# Giving an iOS App a Makeover (Part 1)—Making the Logo “Fly” off the Launch Page


![](http://upload-images.jianshu.io/upload_images/1194012-cf3e37d486bf7c51.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


####Preface
Today’s world is very much driven by appearances. The visual quality of an app may determine how often users open it, and the look of its icon may even determine whether users choose to download it at all. If it is too ugly—even sitting on the phone’s home screen looks bad—users may simply uninstall it. So an attractive UI plus a reasonable UX/UE can, to a large extent, determine user stickiness. Recently, because our company’s app is being prepared for a UI refresh and performance improvements, I wanted to organize the things worth sharing from the makeover process and share them with everyone for learning and discussion. I’ll turn this “makeover” topic into a series. I believe the road to beautification is endless! (Voice from offstage: I’ve just dug myself another huge pit.)


####I. Where the Inspiration Came From
Some people may not fully understand what the title of this article means. The idea actually came from an animated GIF I saw on Weibo. It was vivid and very expressive.
![](http://upload-images.jianshu.io/upload_images/1194012-2c82a315c04b2a63.gif?imageMogr2/auto-orient/strip)

A goofy-looking uncle taps open the Twitter client, and the launch screen has an animation where their logo “flies” straight out of the screen and hits him in the face. I thought the effect was very interesting when I saw it. Many apps either go directly into the app after launch or first show an ad page for a few seconds. In fact, adding a launch effect like this feels pretty nice.

####II. Animation Principle
Next, let’s talk about the principle behind the launch effect above. It’s actually very simple: after the app launches, first load a View, place our logo on it, and then run a scaling UIView animation. Now let’s look at how I implemented it.

####III. Tools Required
PS + AI or Sketch + PaintCode
Some people may ask why these graphics tools are suddenly needed. Actually, you can also load a logo image and place it on the view; that works too. But my boss felt that loading a high-resolution image would increase the app size, and whatever can be drawn programmatically should be drawn programmatically. For irregular and complex shapes, we have to use the toolchain above.

![](http://upload-images.jianshu.io/upload_images/1194012-4ce2d7bca595f60e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)PS is mainly used to cut out the logo.


![](http://upload-images.jianshu.io/upload_images/1194012-1a7156da405557e4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![](http://upload-images.jianshu.io/upload_images/1194012-f570354c4b17de1c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)AI and Sketch are used to trace the cut-out logo with the Pen tool and export the path.


![](http://upload-images.jianshu.io/upload_images/1194012-5a872f4388f8c95c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)Finally, PaintCode converts the path into a UIBezierPath. PaintCode is very powerful: it can directly convert paths inside an SVG into the corresponding Swift or Objective-C code. Later, I discovered that PaintCode alone can actually complete all the steps above, because it also lets you draw paths directly with the Pen tool.


####IV. Start Building
1. First, use PS to cut out the logo image and save it as an image.
2. Then open Sketch and import the logo image you just created.

![](http://upload-images.jianshu.io/upload_images/1194012-93cc2ee749ecde12.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3. Select “Insert” - “Vector” in the upper-left corner to use the Pen tool, then connect each vertex of the logo icon in sequence.
![](http://upload-images.jianshu.io/upload_images/1194012-4504387610269f31.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
4. Then add new anchor points between each pair of vertices. A plus sign will appear on the Pen tool. On the right side of the app, you will see the panel below.

![](http://upload-images.jianshu.io/upload_images/1194012-b4faccaa7e9955c4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
By dragging the points you added, you can make the path perfectly match the complex outline of the logo. After a fair amount of dragging, it should look like the image below.
![](http://upload-images.jianshu.io/upload_images/1194012-a10c6a94f30c1d49.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

5. Next, select the Page panel on the left panel.
![](http://upload-images.jianshu.io/upload_images/1194012-195b264d904142c8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
Select the Path you just traced, and an Export panel will appear in the lower-right corner.

![](http://upload-images.jianshu.io/upload_images/1194012-692ee827e904a2a4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-f90a1583f99ecc95.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-2c9e94dcdd68baba.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, choose to export an SVG file.

>SVG[![svg logo](http://upload-images.jianshu.io/upload_images/1194012-50421760e6be23df.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)](http://baike.baidu.com/pic/SVG/63178/0/4e83cb62211a2be5e7113acd?fr=lemma&ct=single), or Scalable Vector Graphics, is a graphics format based on
Extensible Markup Language (XML) used to describe two-dimensional vector graphics. SVG is a new two-dimensional vector graphics format defined by the W3C (“World Wide Web Consortium,” i.e., the international web standards organization) in August 2000, and it is also the standard for web vector graphics in the specification. SVG strictly follows XML syntax and describes image content using a descriptive language in text format, so it is a vector graphics format independent of image resolution.

There was actually a small detour here. When drawing the path, I originally used AI to trace the points, then exported the SVG to PaintCode, but PaintCode unexpectedly failed to recognize my path. Later, I asked around online, and an expert suggested that I try Sketch instead. Then it worked. Afterward, I compared the SVGs exported by Sketch and AI and found the difference: the SVG I exported from AI had added several layers that covered the path. The method for drawing paths in AI is similar to Sketch, as shown below.
![](http://upload-images.jianshu.io/upload_images/1194012-c41cf3802e3c5b9f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-37b8ee89ce46e689.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

6. Import the previously exported SVG file into PaintCode, and the Objective-C code will be generated automatically below.
![](http://upload-images.jianshu.io/upload_images/1194012-e13e918ec6ce6c5b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Copy out the generated code.
```
//// Color Declarations
UIColor* color1 = [UIColor colorWithRed: 0.521 green: 0.521 blue: 0.521 alpha: 1];

//// Bezier Drawing


//// Page-1
{
    //// Bezier 2 Drawing
    UIBezierPath* bezier2Path = UIBezierPath.bezierPath;
    [bezier2Path moveToPoint: CGPointMake(552.37, 9.09)];
    [bezier2Path addCurveToPoint: CGPointMake(519.07, 26.69) controlPoint1: CGPointMake(552.37, 9.09) controlPoint2: CGPointMake(538.05, 18.98)];
    [bezier2Path addCurveToPoint: CGPointMake(480.56, 38.26) controlPoint1: CGPointMake(500.1, 34.4) controlPoint2: CGPointMake(480.56, 38.26)];
    [bezier2Path addCurveToPoint: CGPointMake(439.19, 9.09) controlPoint1: CGPointMake(480.56, 38.26) controlPoint2: CGPointMake(467.44, 22.55)];
    [bezier2Path addCurveToPoint: CGPointMake(368.15, 2.85) controlPoint1: CGPointMake(410.93, -4.38) controlPoint2: CGPointMake(368.15, 2.85)];
    [bezier2Path addCurveToPoint: CGPointMake(316.47, 30.92) controlPoint1: CGPointMake(368.15, 2.85) controlPoint2: CGPointMake(340.52, 7.85)];
    [bezier2Path addCurveToPoint: CGPointMake(281.09, 86.36) controlPoint1: CGPointMake(292.42, 53.99) controlPoint2: CGPointMake(290.08, 59.09)];
    [bezier2Path addCurveToPoint: CGPointMake(279.09, 144.27) controlPoint1: CGPointMake(272.1, 113.63) controlPoint2: CGPointMake(279.09, 144.27)];
    [bezier2Path addCurveToPoint: CGPointMake(181.55, 124.87) controlPoint1: CGPointMake(279.09, 144.27) controlPoint2: CGPointMake(224.85, 139.76)];
    [bezier2Path addCurveToPoint: CGPointMake(101.23, 83.11) controlPoint1: CGPointMake(138.25, 109.98) controlPoint2: CGPointMake(101.23, 83.11)];
    [bezier2Path addLineToPoint: CGPointMake(38.19, 22.55)];
    [bezier2Path addCurveToPoint: CGPointMake(21.56, 66.97) controlPoint1: CGPointMake(38.19, 22.55) controlPoint2: CGPointMake(24, 45.21)];
    [bezier2Path addCurveToPoint: CGPointMake(28.04, 113.2) controlPoint1: CGPointMake(19.12, 88.74) controlPoint2: CGPointMake(28.04, 113.2)];
    [bezier2Path addCurveToPoint: CGPointMake(45.34, 151.3) controlPoint1: CGPointMake(28.04, 113.2) controlPoint2: CGPointMake(34.12, 134.96)];
    [bezier2Path addCurveToPoint: CGPointMake(72.71, 178.32) controlPoint1: CGPointMake(56.55, 167.65) controlPoint2: CGPointMake(72.71, 178.32)];
    [bezier2Path addCurveToPoint: CGPointMake(45.34, 173.23) controlPoint1: CGPointMake(72.71, 178.32) controlPoint2: CGPointMake(57.6, 176.78)];
    [bezier2Path addCurveToPoint: CGPointMake(21.56, 163.51) controlPoint1: CGPointMake(33.08, 169.68) controlPoint2: CGPointMake(21.56, 163.51)];
    [bezier2Path addCurveToPoint: CGPointMake(28.04, 210.73) controlPoint1: CGPointMake(21.56, 163.51) controlPoint2: CGPointMake(20.58, 191.27)];
    [bezier2Path addCurveToPoint: CGPointMake(53.47, 246.86) controlPoint1: CGPointMake(35.49, 230.2) controlPoint2: CGPointMake(53.47, 246.86)];
    [bezier2Path addCurveToPoint: CGPointMake(80.14, 268.29) controlPoint1: CGPointMake(53.47, 246.86) controlPoint2: CGPointMake(65.25, 259.74)];
    [bezier2Path addCurveToPoint: CGPointMake(113.46, 281.28) controlPoint1: CGPointMake(95.04, 276.83) controlPoint2: CGPointMake(113.46, 281.28)];
    [bezier2Path addCurveToPoint: CGPointMake(86.11, 286.04) controlPoint1: CGPointMake(113.46, 281.28) controlPoint2: CGPointMake(98.18, 285.95)];
    [bezier2Path addCurveToPoint: CGPointMake(62.93, 281.67) controlPoint1: CGPointMake(74.03, 286.13) controlPoint2: CGPointMake(62.93, 281.67)];
    [bezier2Path addCurveToPoint: CGPointMake(80.14, 317.03) controlPoint1: CGPointMake(62.93, 281.67) controlPoint2: CGPointMake(71.12, 304.22)];
    [bezier2Path addCurveToPoint: CGPointMake(103.91, 339.84) controlPoint1: CGPointMake(89.17, 329.83) controlPoint2: CGPointMake(103.91, 339.84)];
    [bezier2Path addCurveToPoint: CGPointMake(135.88, 359.44) controlPoint1: CGPointMake(103.91, 339.84) controlPoint2: CGPointMake(119.59, 353.53)];
    [bezier2Path addCurveToPoint: CGPointMake(170.93, 364.15) controlPoint1: CGPointMake(152.16, 365.34) controlPoint2: CGPointMake(170.93, 364.15)];
    [bezier2Path addCurveToPoint: CGPointMake(135.88, 386.44) controlPoint1: CGPointMake(170.93, 364.15) controlPoint2: CGPointMake(153.54, 376.98)];
    [bezier2Path addCurveToPoint: CGPointMake(101.13, 401.54) controlPoint1: CGPointMake(118.21, 395.9) controlPoint2: CGPointMake(101.13, 401.54)];
    [bezier2Path addCurveToPoint: CGPointMake(53.47, 412.64) controlPoint1: CGPointMake(101.13, 401.54) controlPoint2: CGPointMake(81.16, 409.59)];
    [bezier2Path addCurveToPoint: CGPointMake(0.29, 412.64) controlPoint1: CGPointMake(25.78, 415.7) controlPoint2: CGPointMake(0.29, 412.64)];
    [bezier2Path addCurveToPoint: CGPointMake(72.71, 447.67) controlPoint1: CGPointMake(0.29, 412.64) controlPoint2: CGPointMake(36.62, 435.16)];
    [bezier2Path addCurveToPoint: CGPointMake(149.39, 464.31) controlPoint1: CGPointMake(108.8, 460.17) controlPoint2: CGPointMake(149.39, 464.31)];
    [bezier2Path addCurveToPoint: CGPointMake(249.01, 457.71) controlPoint1: CGPointMake(149.39, 464.31) controlPoint2: CGPointMake(196.6, 469.56)];
    [bezier2Path addCurveToPoint: CGPointMake(352.07, 418.46) controlPoint1: CGPointMake(301.42, 445.86) controlPoint2: CGPointMake(352.07, 418.46)];
    [bezier2Path addCurveToPoint: CGPointMake(414.45, 370.11) controlPoint1: CGPointMake(352.07, 418.46) controlPoint2: CGPointMake(388.26, 396.31)];
    [bezier2Path addCurveToPoint: CGPointMake(458.34, 312.2) controlPoint1: CGPointMake(440.64, 343.92) controlPoint2: CGPointMake(458.34, 312.2)];
    [bezier2Path addCurveToPoint: CGPointMake(489.68, 246.86) controlPoint1: CGPointMake(458.34, 312.2) controlPoint2: CGPointMake(476.64, 284.33)];
    [bezier2Path addCurveToPoint: CGPointMake(509.39, 165.55) controlPoint1: CGPointMake(502.73, 209.38) controlPoint2: CGPointMake(509.39, 165.55)];
    [bezier2Path addLineToPoint: CGPointMake(510.48, 117.41)];
    [bezier2Path addCurveToPoint: CGPointMake(542.8, 90.45) controlPoint1: CGPointMake(510.48, 117.41) controlPoint2: CGPointMake(526.7, 107.34)];
    [bezier2Path addCurveToPoint: CGPointMake(569.12, 56.54) controlPoint1: CGPointMake(558.9, 73.55) controlPoint2: CGPointMake(569.12, 56.54)];
    [bezier2Path addLineToPoint: CGPointMake(537.79, 66.97)];
    [bezier2Path addLineToPoint: CGPointMake(503.61, 73.55)];
    [bezier2Path addCurveToPoint: CGPointMake(537.79, 43.14) controlPoint1: CGPointMake(503.61, 73.55) controlPoint2: CGPointMake(528.94, 56.27)];
    [bezier2Path addCurveToPoint: CGPointMake(552.37, 9.09) controlPoint1: CGPointMake(546.63, 30.01) controlPoint2: CGPointMake(552.37, 9.09)];
    [bezier2Path closePath];
    bezier2Path.miterLimit = 4;

    bezier2Path.usesEvenOddFillRule = YES;

    [color1 setStroke];
    bezier2Path.lineWidth = 1;
    [bezier2Path stroke];
}

```
A quick aside: after I had finished all of this, I realized that PaintCode also has a Pen tool.

![](http://upload-images.jianshu.io/upload_images/1194012-8f2308c103a3639d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
In other words, PaintCode alone can do everything we need; there’s no need to use Sketch or AI to draw the paths. PaintCode itself can draw the paths and export Objective-C or Swift code.

7. Now let’s go back to the Xcode project. Add a UIView to display the logo, and add the Layer to the View’s Layer.
```
-(void)addLayerToLaunchView
{
    //self.launchView is a UIVIew I added to display the Logo
    CAShapeLayer *layer = [[CAShapeLayer alloc]init];
    layer.path = [self setBezierPath].CGPath;
    layer.bounds = CGPathGetBoundingBox(layer.path);
    
    self.launchView.backgroundColor = [UIColor blueColor];
    layer.position = CGPointMake(self.view.layer.bounds.size.width / 2, self.view.layer.bounds.size.height/ 2);
    layer.fillColor = [UIColor whiteColor].CGColor;
    [self.launchView.layer addSublayer:layer];
}
```

```

-(UIBezierPath *)setBezierPath
{
    //  Add the code just pasted from PaintCode here
}
```
![](http://upload-images.jianshu.io/upload_images/1194012-7a0cc3fd94a481c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

8. Add an animation to this View. Take a close look at the GIF at the beginning of my article, where that goofy-looking guy opens Twitter: the animation first shrinks the bird, then enlarges it.
```

- (void)startLaunch
{
    [UIView animateWithDuration:0.2 animations:^{
        // First shrink the View here
        self.launchView.frame = CGRectMake(0, 0, 50, 50);
        self.launchView.center = self.view.center;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 animations:^{
            // Enlarge the View here
            self.launchView.frame = CGRectMake(0, 0, 5000, 5000);
            self.launchView.center = self.view.center;
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [self.launchView removeFromSuperview];
        }];;
    }];
}
```
Next, run the project and you’ll get the effect of making the Logo “fly” when the app launches.

Here’s what it looks like after I integrated this effect into the app:

![](http://upload-images.jianshu.io/upload_images/1194012-16c1f62fea34ed00.gif?imageMogr2/auto-orient/strip)


#### Conclusion
This effect is actually suitable for many apps. If your company doesn’t require an ad page or other mandatory screens,
you can consider adding these animations after launch to improve the app’s user experience. A great transition animation can make an app feel more vivid and full of energy!


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_coredata\_migration/](https://halfrost.com/ios_coredata_migration/)