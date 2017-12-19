# 如何解决空间覆盖最优解的问题?




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


## 二. RegionCoverer 核心算法 Covering 的实现

## 三. 


## 四. 最后

![](http://upload-images.jianshu.io/upload_images/1194012-677511a5aa65e1c8.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


关于空间搜索系列文章到这里也告一段落了，最后当然说一些心得体会了。

在学习和实践空间搜索这块知识的时候，笔者我查看了物理，数学，算法这三方面的资料，从物理和数学2个层次提升了整个空间和时间的认知。虽然目前个人在这方面的认知也许还很浅显，不过对比之前实在是进步了很多。目的也达到了。

最后的最后就是推荐2个网站，这也是微博上提问问到最多的。

第一个问题是：系列文章里面的 S2 Cell 都是怎么画出来的？

这其实是一个人的开源网站，[http://s2map.com/](http://s2map.com/)，笔者是在这里填入程序算好的 CellID，然后显示出来的。这就相当于是 S2 的可视化研究展示工具了。

第二个问题是：为什么有些代码在 Go 的版本里面没有找到相关实现？

答案是 Go 的版本实现完成度还没有到 100%，个别的还需要去参考 C++ 和 Java 完整版的代码。关于 C++ 和 Java 的源码，Google 已经在几天前把代码从私有代码仓库移到了 Github 上了。更加方便学习与查看了。官方也把一些文档整理到了 [https://s2geometry.io/](https://s2geometry.io/) 这个网站上。初学者建议还是先看官方 API 说明文档。在看完文档以后，原理性的问题还有些疑惑，可以来翻翻笔者这个空间搜索系列文章，希望能对读者有帮助。

------------------------------------------------



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
