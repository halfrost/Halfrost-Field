# Google S2 是如何快速索引数据的?

S2 is designed to have good performance on large geographic datasets. Most operations are accelerated using an in-memory edge index data structure (S2ShapeIndex). For example if you have a million polygons, finding the polygon(s) that contain a given point typically takes a few hundred nanoseconds. Similarly it is fast to find objects that are near each other, such as finding all the places of business near a given road, or all the roads near a given location.

S2被设计为在大型地理数据集上具有良好的性能。大多数操作使用内存中边缘索引数据结构（S2ShapeIndex）进行加速。例如，如果您有一百万个多边形，找到包含给定点的多边形通常需要几百纳秒。类似地，找到彼此靠近的对象也是快速的，例如查找给定道路附近的所有营业场所或者给定位置附近的所有道路。




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
