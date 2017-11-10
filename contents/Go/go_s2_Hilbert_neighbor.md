# 四叉树上如何求希尔伯特曲线的邻居 ？


![](http://upload-images.jianshu.io/upload_images/1194012-6d8555b537b3809c.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)






关于邻居的定义，相邻即为邻居，那么邻居分为2种，边相邻和点相邻。边相邻的有4个方向，上下左右。点相邻的也有4个方向，即4个顶点相邻的。



![](http://upload-images.jianshu.io/upload_images/1194012-a0c74a7e02fa551b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如上图，绿色的区域是一颗四叉树表示的范围，四叉树上面有一个点，图中黄色区域标明的点。现在想求四叉树上黄色的点的希尔伯特曲线邻居。图中黑色的线就是一颗穿过四叉树的希尔伯特曲线。希尔伯特曲线的起点0在左上角的方格中，终点63在右上角的方格中。

红色的四个格子是黄色格子边相邻邻居，蓝色的四个格子是黄色格子的顶点相邻的邻居，所以黄色格子的邻居为8个格子，分别表示的点是8，9，54，11，53，30，31，32 。可以看出来这些邻居在表示的点上面并不是相邻的。

那么怎么求四叉树上任意一点的希尔伯特曲线邻居呢？

------------------------------------------------------

空间搜索系列文章：

[如何理解 n 维空间和 n 维时空](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[高效的多维空间点索引算法 — Geohash 和 Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)  
[Google S2 中的 CellID 是如何生成的 ？](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_CellID.md)     
[Google S2 中的四叉树求 LCA 最近公共祖先](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_lowest_common_ancestor.md)  
[神奇的德布鲁因序列](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_De_Bruijn.md)



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_cellID/](https://halfrost.com/go_s2_cellID/)