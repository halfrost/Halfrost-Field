# Google S2 中的 priorityQueue 优先队列


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