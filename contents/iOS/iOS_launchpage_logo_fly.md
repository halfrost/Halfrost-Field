# iOS app旧貌换新颜(一)—Launch Page让Logo"飞"出屏幕


![](http://upload-images.jianshu.io/upload_images/1194012-cf3e37d486bf7c51.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



####前言
当今是个看脸的世界，一个app的颜值可能会决定用户的使用次数，icon的颜值更可能决定了用户是否回去下载，如果太丑，放在手机桌面都难看，那用户很可能就直接卸载了。所以漂亮的界面UI + 合理的用户体验UX/UE也会很大程度决定用户的黏性。最近由于公司的app准备美化一下界面，提升性能，所以我就想把美化过程中可以和大家分享的东西都整理整理，拿出来也和大家一起分享学习。这个“旧貌换新颜”我就写成一个系列吧，相信美化的道路是永无止境的！(场外音:自己又给自己开了一个巨坑)


####一.灵感的来源
也许有些人看了文章的标题并不一定完全懂是啥意思，其实设计这个的来源源自于我在微博上看到的一个动图，很生动，形象。
![](http://upload-images.jianshu.io/upload_images/1194012-2c82a315c04b2a63.gif?imageMogr2/auto-orient/strip)

一个呆萌的大叔点开Twitter客户端，启动界面有一个动效，就是他们的logo直接“飞”出屏幕，打在了他的脸上。这个效果我当时看了就觉得很有趣。很多应用每次启动之后都是直接进去，或者先展示一个几秒的广告页。其实要是加一个这种启动特性，感觉也挺不错。

####二.动画原理
接下来说一下上面那个启动特效的原理，其实原理很简单:app在启动之后，先加载一个View，上面放了我们的logo，然后在做一个放大的UIView的动画就好了。接下来看看我的做法吧。

####三.准备工具
PS + AI 或者 Sketch + PaintCode
这个可能有人问了，怎么突然还需要这些作图的工具。其实大家也可以加载一个logo图片放在view上，一样可以实现。不过老板觉得加载一张图片如果太高清会占app大小，能尽量程序画出来的，就让程序画出来。对于不规则复杂的图形，就只好用上面这一套组合工具了。

![](http://upload-images.jianshu.io/upload_images/1194012-4ce2d7bca595f60e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)PS主要是把logo抠出来



![](http://upload-images.jianshu.io/upload_images/1194012-1a7156da405557e4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![](http://upload-images.jianshu.io/upload_images/1194012-f570354c4b17de1c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)AI和Sketch是为了把抠出来的logo用钢笔工具，进行描点，导出路径。



![](http://upload-images.jianshu.io/upload_images/1194012-5a872f4388f8c95c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)最后PaintCode就是把路径转换成UIBezierPath(PaintCode这个软件很厉害，可以直接把SVG里面的路径直接转换成对应的Swift或者Objective-C代码)(后来我发现其实只要用PaintCode一个软件就可以完成上面所有功能了，它也可以直接用钢笔工具画路径)


####四.开始制作
1.首先用PS把Logo图抠出来，保存成图片。
2.然后打开Sketch，导入刚刚的Logo图片。

![](http://upload-images.jianshu.io/upload_images/1194012-93cc2ee749ecde12.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.选择左上角的“Insert”-“Vector”钢笔工具，依次连接Logo图标的各个顶点
![](http://upload-images.jianshu.io/upload_images/1194012-4504387610269f31.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
4.然后在每段顶点之间，加新的锚点，钢笔工具会出现+号。在软件的右侧，会出现下面这个面板

![](http://upload-images.jianshu.io/upload_images/1194012-b4faccaa7e9955c4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
通过拖拉这些你加出来的点，可以使路径完全吻合Logo复杂的外形。拖过一番拖拽之后，就应该成下面这个图的样子了。
![](http://upload-images.jianshu.io/upload_images/1194012-a10c6a94f30c1d49.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

5.接下来我们就选择左边面板上面有一个Page面板
![](http://upload-images.jianshu.io/upload_images/1194012-195b264d904142c8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
选一下刚刚描出来的Path，右下角会出现一个Export面板

![](http://upload-images.jianshu.io/upload_images/1194012-692ee827e904a2a4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




![](http://upload-images.jianshu.io/upload_images/1194012-f90a1583f99ecc95.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-2c9e94dcdd68baba.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这个时候我们选择导出SVG文件

>SVG[![svg logo](http://upload-images.jianshu.io/upload_images/1194012-50421760e6be23df.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)](http://baike.baidu.com/pic/SVG/63178/0/4e83cb62211a2be5e7113acd?fr=lemma&ct=single)可缩放矢量图形（Scalable Vector Graphics）是基于
可扩展标记语言（XML），用于描述二维矢量图形的一种图形格式。SVG是W3C("World Wide Web ConSortium" 即 " 国际互联网标准组织")在2000年8月制定的一种新的二维矢量图形格式，也是规范中的网络矢量图形标准。SVG严格遵从XML语法，并用文本格式的描述性语言来描述图像内容，因此是一种和图像分辨率无关的矢量图形格式

其实这里有一个小插曲，绘制路径的时候，其实我用的是AI描点的，之后导出SVG给PaintCode，居然不识别我的路径。后来网上问了问，大神要我换Sketch试试，然后就行了。后来我比较了一下Sketch和AI导出的SVG有什么不同，才发现，我之前AI导出的，加了几个图层，把路径盖住了。用AI绘制路径的方法和Sketch的差不多，如下图。
![](http://upload-images.jianshu.io/upload_images/1194012-c41cf3802e3c5b9f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-37b8ee89ce46e689.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

6.把之前导出的SVG文件导入到PaintCode中，下面会自动生成Objective-C代码
![](http://upload-images.jianshu.io/upload_images/1194012-e13e918ec6ce6c5b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

把生成的这些代码复制出来。
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
小插曲:当我全部忙活完这些以后，我才发现PaintCode也有钢笔工具

![](http://upload-images.jianshu.io/upload_images/1194012-8f2308c103a3639d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
也就是说只用一个PaintCode就可以完成所有想做的事情了，不需要Sketch或者AI去画路径了。PaintCode自己就可以画路径，导出OC或者Swift代码了。

7.现在我们回到Xcode工程中。添加一个UIView用来显示Logo。并且把Layer加到View的Layer中
```
-(void)addLayerToLaunchView
{
    //self.launchView是我添加的一个显示Logo的UIVIew
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
    //  这里面加入的就是刚刚PaintCode粘贴出来的代码
}
```
![](http://upload-images.jianshu.io/upload_images/1194012-7a0cc3fd94a481c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

8.给这个View添加动画。仔细观察我文章开头的那个呆萌大叔打开Twitter的Gif图，动画效果是先把鸟缩小，然后再变大
```

- (void)startLaunch
{
    [UIView animateWithDuration:0.2 animations:^{
        // 这里先把View缩小
        self.launchView.frame = CGRectMake(0, 0, 50, 50);
        self.launchView.center = self.view.center;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 animations:^{
            // 这里要把View放大
            self.launchView.frame = CGRectMake(0, 0, 5000, 5000);
            self.launchView.center = self.view.center;
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [self.launchView removeFromSuperview];
        }];;
    }];
}
```
接下来运行工程就可以实现应用启动的时候，让Logo"飞"起来的效果啦。


这是我把这个效果做到app中的效果：


![](http://upload-images.jianshu.io/upload_images/1194012-16c1f62fea34ed00.gif?imageMogr2/auto-orient/strip)



#### 结尾
这个效果其实适用很多app，如果公司也没有强制要加入广告页，等等其他页面，
可以考虑在启动之后加上这些动画来增加app的用户体验。优秀的过场动画能让app更加鲜活，充满活力！


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_coredata\_migration/](https://halfrost.com/ios_coredata_migration/)