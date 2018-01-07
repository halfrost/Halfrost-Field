# Google S2 是如何解决空间覆盖最优解问题的?




![](http://upload-images.jianshu.io/upload_images/1194012-c71d0b0615179e9e.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 前言

这篇不出意外就是 Google S2 整个系列的最终篇了。这篇里面会把 regionCoverer 算法都讲解清楚。至于 Google S2 库里面还有很多其他的小算法，代码同样也很值得阅读和学习，这里也就不一一展开了，有兴趣的读者可以把整个库都读一遍。

在写这篇文章的同时，发现了库的作者的一些新的 commit ，比如 2017年12月4号的 commit f9610db2b871b54b17d36d4da6a4d6a2aab6018d，这次提交的改动更改了 README，别看只改了文档，其实里面内容很多。

```go

 -For an analogous library in C++, see
 -https://code.google.com/archive/p/s2-geometry-library/, and in Java, see
 -https://github.com/google/s2-geometry-library-java
------------------------------------------------------------------------------------
 +For an analogous library in C++, see https://github.com/google/s2geometry, in
 +Java, see https://github.com/google/s2-geometry-library-java, and Python, see
 +https://github.com/google/s2geometry/tree/master/src/python

```

可以看到他们把原来存在 Google 官方私有代码仓库里面的代码放到了 github。之前都只能在代码归档里面查看 C++ 代码，现在直接可以在 github 上查看了。方便了很多。

```go

+More details about S2 in general are available on the S2 Geometry Website
 +[s2geometry.io](https://s2geometry.io/).

```

在这次 commit 里面还提到了一个新的网站，这个网站我发现也是最近才发布出来的。因为笔者我连续关注 S2 每个 commit 了快半年了。网上每个关于 S2 的资源都有关注，这个网站非常新。关于这个网站文章最后会提到，这里就不详细说了。

从这个提交开始，笔者认为 Google S2 可能被重视起来了，也有可能打算大力推广了。

好了，正式进入正题。


## 一. 空间类型

在 Google S2 中能进行 RegionCovering 的有以下几种类型。基本上都是必须满足 Region interface 的。

### 1. Cap 球帽

Cap 代表由中心和半径限定的盘形区域。从技术上讲，这种形状被称为“球形帽”（而不是圆盘），因为它不是平面的。帽子代表被飞机切断的球体的一部分。帽的边界是由球面与平面的交点所定义的圆。帽子是一个封闭的组合，即它包含了它的边界。 大多数情况下，无论在平面几何中使用光盘，都可以使用球冠。帽的半径是沿着球体表面测量的（而不是通过内部的直线距离）。因此，一个半径为 π/ 2 的帽是一个半球，半径为 π 的帽覆盖整个球。 中心是单位球面上的一个点。（因此需要它是单位长度）帽子也可以由其中心点和高度来定义。高度是从中心点到截断平面的距离。还有支持“空”和“全”的上限，分别不包含任何点数和所有点数。 下面是帽高（h），帽半径（r），帽中心的最大弦长（d）和帽底部半径（a）之间的一些有用关系。

```
h = 1 - cos(r)
	= 2 * sin^2(r/2)
d^2 = 2 * h
	= a^2 + h^2

```

### 2. Loop 循环

Loop 代表一个简单的球面多边形。它由一系列顶点组成，其中第一个顶点隐含地被认为是连接到最后一个顶点的。所有的 loop 被定义为具有 CCW 方向，即 loop 的内部在边的左侧。这意味着包围一个小区域的顺时针 loop 被解释为包围非常大的区域的 CCW 的 loop。 loop 不允许有任何重复的顶点（不管是否相邻）。不允许相邻的边相交，而且不允许长度为180度的边（即，相邻的顶点不能是相反的）。loop 必须至少有3个顶点（下面讨论的“空”和“全” loop 除外）。 有两个特殊的 loop：EmptyLoop 不包含点，FullLoop 包含所有点。这些 loop 没有任何边，但为了保持每一个 loop 都可以表示为顶点链的不变量，它们被定义为每个只有一个顶点。


### 3. Polygon 多边形
多边形表示一个零或多个 loop 的序列;同样，一个 loop 的左手边方向定义为它的内部。 当多边形初始化时，给定的 loop 自动转换为“孔”的组成的规范形式。loop 被重新排序以对应于嵌套层次的预定义遍历方式。 多边形可以表示具有多边形边界的球体的任何区域，包括整个球体（称为“完整”多边形）。完整的多边形由一个完整的 loop 组成，而空的多边形完全没有 loop。 使用 FullPolygon() 来构造一个完整的多边形。 Polygon 的零值被视为空的多边形。

想要 多个 loop 构成一个 Polygon 多边形，必须满足以下4个条件：

1. loop 不能交叉，即 loop 的边界可能不与任何其他 loop 的内部和外部相交。   
2. loop 不共享边缘，即如果 loop 包含边缘 AB，则其他 loop 可能不包含 AB 或 BA。   
3. loop 可以共享顶点，但是在单个 loop 中不会出现两次顶点（参见S2Loop）。   
4. 不能有空的 loop。full loop 可能只出现在完整的 full polygon 中。  



### 4. Rect 矩形
Rect 代表一个封闭的经纬度矩形。它也是 Region 类型。它能够表示空的和完整的矩形以及单个点。它有一个 AddPoint 方法，可以方便地为一组点构造边界矩形，包括跨越180度子午线的点集。

### 5. Region 区域
区域表示单位球体上的二维区域。 这个接口的目的是让复杂的区域近似为更简单的区域。该接口仅限于计算近似值的方法。

S2 区域表示单位球体上的二维区域。它是一个具有各种具体子类型的抽象接口，如盘形，矩形，多段线，多边形，几何集合，缓冲形状等。 这个接口的主要目的是使复杂区域近似为更简单的区域。因此，接口只能用于计算近似值的方法，而不是具有各种各样的由所有子类型实现的虚拟方法。


### 6. Shape 形状

Shape 算是一切图形或者形状的“基类”了。它可以最灵活的方式表示几何多边形。它是由边缘的集合构成的，可选地定义内部。由给定 Shape 表示的所有几何图形必须具有相同的尺寸，这意味着 Shape 可以表示一组点，一组多边形或一组多边形。 Shape 被定义为一个接口，以便让客户端更加方便的控制底层的数据表示。有时一个 Shape 没有自己的数据，而是包装其他类型的数据。 Shape 操作通常在 ShapeIndex 上定义，而不是单独的形状。 ShapeIndex 只是一个 Shapes 集合，可能有不同的维度（例如10个点和3个多边形），组织成一个数据结构，以便高效的访问。 Shape 的边缘由从 0 开始的连续范围的边缘 ID 索引。边缘被进一步细分为链，其中每个链由端到端连接的一系列边（多段线）组成。例如，表示两条折线 AB 和 CDE 的形状将具有分成两条链（AB）和（CD，DE）的三条边（AB，CD，DE）。类似地，代表5个点的形状将具有由一个边缘组成的5个链。 Shape具有允许使用全局编号（边缘ID）或在特定链中访问边的方法。全局编号对于大多数情况来说是足够的，但链表示对于某些算法（如交集（请参阅BooleanOperation））非常有用。

S2 中总共定义了两个用于表示几何的可扩展接口：S2Shape 和 S2Region。

它们两者不同点是： 
S2Shape 的目的是灵活地表示多边形几何。 （这不仅包括多边形，还包括点和折线）。大部分的核心 S2 操作将与任何实现 S2Shape 接口的类一起工作。 

S2Region 的目的是计算几何的近似值。例如，有计算边界矩形和圆盘的方法，S2RegionCoverer 可以用来逼近一个区域，以任意期望的精度作为单元的集合。与S2Shape 不同，S2Region 可以表示非多边形几何形状，例如球帽（S2Cap）。


除去上面说的这几种常用的类型以外，还有以下这些中间类型或者更加底层的类型可以供开发者使用。


- S2LatLngRect - 经纬度坐标系中的矩形。
- S2Polyline - 折线。
- S2CellUnion - 一个近似为S2CellIds集合的区域。RegionCoverer 转换以后都是这种类型。
- S2ShapeIndexRegion - 点，多义线和多边形的任意集合。
- S2ShapeIndexBufferedRegion - 定义和 S2ShapeIndexRegion 一样，只是扩大了给定的半径。
- S2RegionUnion - 任意区域的集合。
- S2RegionIntersection - 任意其他区域的交集部分。


最后，额外说一句，S2RegionTermIndexer 这个类型是支持索引和查询任何类型的S2Region，也就是上述说的所有的类型。可以使用 S2RegionTermIndexer 来索引一组多段线，然后查询哪些多段线与给定的多边形相交。



## 二. RegionCoverer 举例

RegionCoverer 主要是要找到一个能覆盖当前区域的近似最优解(为何不是最优解？)

转换条件主要有3个，MaxLevel, MaxCells, MinLevel。MaxCells 决定了最大 cell 的个数，但是太接近最大值以后又会导致覆盖面积太大，不精确。所以最大个数仅仅是限制在满足最大精度的条件下最多不能超过这个个数。由于这一点导致并不是满足 MaxCells 的最优解。

举几个例子：

下面是一个半径为 10 公里的 cap，并且这个 cap 位于 3 个 face 夹角处，我们假设需要最大个数为 10 的 cell 去覆盖它。结果如下：

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-06147cab0700189c.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


相同的设置，我们把个数改到 20，如下：

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-9986012502eab78b.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>

还是相同的配置，把个数改到 50 个：

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-0bd56144b9a22a11.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>

到目前，精确度马马虎虎，边缘部门覆盖的还是多于原始的 cap 了，我们继续提高精度，把个数调整到 200 。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-74a80a89d27c0f09.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


200 个看似比较精确了，我们再提高一下，提高到 1000，看看会出现什么结果。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-39a5bd16c9e688cf.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


代码配置上虽然设置的 1000 个，实际只有 706 个 cell。原因是代码上虽然是按照 1000 个计算的，但是实际算法处理上还会进行 cell 剪枝后的合并。所以最终个数会小于 1000 个。

再看一个例子，下面这个矩形是表示一个纬度/经度矩形从北纬 60 度延伸到北纬 80 度，从 -170 度经度延伸到 +170 度。覆盖范围限于 8 个单元。请注意，中间的洞被完全覆盖。这明显是不符合我们的意图的。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-b400bf236651eeaa.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


我们把 cell 的个数提高到 20 个。中间的孔依旧被填补上了。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-c0f6fe597231fee0.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


我们把参数调节到 100 个，其他配置都完全一样。现在中间的孔有一定样子了。但是日期线附近的空白还是没有出来。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-9a99f328cffd1bd7.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>

最后把参数调整到 500 个。现在中间的孔就比较完整的显示出来了。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-5ae24704889d70f0.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


在举几个我们实际项目中用到的例子。下面是上海的一个网格的边缘。我们先用

```go

defaultCoverer := &s2.RegionCoverer{MaxLevel: 16, MaxCells: 100, MinLevel: 13}

```

去转换，得到的结果如下:

![](http://upload-images.jianshu.io/upload_images/1194012-97b0cb74e9505b83.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

```go

defaultCoverer := &s2.RegionCoverer{MaxLevel: 30, MaxCells: 1000, MinLevel: 1}

```

精确度提高到1000，结果就会如下：


![](http://upload-images.jianshu.io/upload_images/1194012-39da9d80faadb81f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


还有一些区域更大的情况，比如一个省，湖北省：


![](http://upload-images.jianshu.io/upload_images/1194012-68b697c17ab0ea94.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


或者一个湖，太湖：

![](http://upload-images.jianshu.io/upload_images/1194012-f29b4ed9cb846ca6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

最后在举一个 polygon 的例子。我们知道 polygon 是由多个 loop 组成的：

```go

	loops := []*s2.Loop{}
	loops = append(loops, loop1)
	loops = append(loops, loop2)

	polygon := s2.PolygonFromLoops(loops)

	defaultCoverer := &s2.RegionCoverer{MaxLevel: 16, MaxCells: 100, MinLevel: 8}
	fmt.Println("----  polygon-----")

	cvr = defaultCoverer.Covering(polygon)

	for i := 0; i < len(cvr); i++ {
		fmt.Printf("%d,\n", cvr[i])
	}
	fmt.Printf("------------\n")


```

下面一次是两个 loop 在地图上的样子。

![](http://upload-images.jianshu.io/upload_images/1194012-09a758bab8beb8b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-7591f2062cb4af4f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


最后是 polygon,它包含了以上2个 loop。

![](http://upload-images.jianshu.io/upload_images/1194012-4c8c2fa4ec88dd9e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



## 三. RegionCoverer 核心算法 Covering 的实现

覆盖的区域是球面上的盘子区域

低等级的 level 的 cell 会优先使用。即大格子会优先使用。

关于 MaxCells 的设置，如果是所需的最小的单元数，就返回最小的单元数。如果待覆盖的区域正好位于三个立方体的交点处，那么就要返回3个 cell，即使覆盖的面会比要求的大一些。

如果设置的单元格的最小 cell 的 level 太高了，即格子太小了，那么就会返回任意数量的单元格数量。

如果 MaxCells 小于4，即使该区域是凸的，比如 cap 或者 rect ，最终覆盖的面积也要比原生区域大。

这个近似算法并不是最优算法，但是在实践中效果还不错。输出的结果并不总是使用的满足条件的最多的单元数，因为这样也不是总能产生更好的近似结果(比如上面举例的，区域整好位于三个面的交点处，得到的结果比原区域要大很多) 并且 MaxCells 对搜索的工作量和最终输出的 cell 的数量是一种限制。


由于这是一个近似算法，所以不能依赖它输出的稳定性。特别的，覆盖算法的输出结果会在不同的库的版本上有所不同。

这个算法还可以产生内部覆盖的 cell，内部覆盖的 cell 指的是完全被包含在区域内的 cell。

如果没有满足条件的 cell ，即使对于非空区域，内部覆盖 cell 也可能是空的。

请注意，处于性能考虑，在计算内部覆盖 cell 的时候，指定 MaxLevel 是明智的做法。否则，对于小的或者零面积的区域，算法可能会花费大量时间将单元格细分到叶子 level ，以尝试找到满足条件的内部覆盖单元格 cell。

## 四. 最后

![](http://upload-images.jianshu.io/upload_images/1194012-677511a5aa65e1c8.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


关于空间搜索系列文章到这里也告一段落了，最后当然说一些心得体会了。

在学习和实践空间搜索这块知识的时候，笔者我查看了物理，数学，算法这三方面的资料，从物理和数学2个层次提升了整个空间和时间的认知。虽然目前个人在这方面的认知也许还很浅显，不过对比之前实在是进步了很多。目的也达到了。

最后的最后就是推荐2个网站，这也是微博上提问问到最多的。

第一个问题是：系列文章里面的 S2 Cell 都是怎么画出来的？

这其实是一个人的开源网站，[http://s2map.com/](http://s2map.com/)，笔者是在这里填入程序算好的 CellID，然后显示出来的。这就相当于是 S2 的可视化研究展示工具了。

第二个问题是：为什么有些代码在 Go 的版本里面没有找到相关实现？

答案是 Go 的版本实现完成度还没有到 100%，个别的还需要去参考 C++ 和 Java 完整版的代码。关于 C++ 和 Java 的源码，Google 已经在几天前把代码从私有代码仓库移到了 Github 上了。更加方便学习与查看了。官方也把一些文档整理到了 [https://s2geometry.io/](https://s2geometry.io/) 这个网站上。初学者建议还是先看官方 API 说明文档。在看完文档以后，原理性的问题还有些疑惑，可以来翻翻笔者这个空间搜索系列文章，希望能对读者有帮助。



------------------------------------------------------

空间搜索系列文章：

[如何理解 n 维空间和 n 维时空](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[高效的多维空间点索引算法 — Geohash 和 Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)  
[Google S2 中的 CellID 是如何生成的 ？](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_CellID.md)     
[Google S2 中的四叉树求 LCA 最近公共祖先](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_lowest_common_ancestor.md)  
[神奇的德布鲁因序列](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_De_Bruijn.md)  
[四叉树上如何求希尔伯特曲线的邻居 ？](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_Hilbert_neighbor.md)  
[如何解决空间覆盖最优解问题？](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_regionCoverer.md)



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_regionCoverer/](https://halfrost.com/go_s2_Hilbert_regionCoverer/)
