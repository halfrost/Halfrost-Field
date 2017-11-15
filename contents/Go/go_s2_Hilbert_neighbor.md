# 四叉树上如何求希尔伯特曲线的邻居 ？


![](http://upload-images.jianshu.io/upload_images/1194012-6d8555b537b3809c.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)






关于邻居的定义，相邻即为邻居，那么邻居分为2种，边相邻和点相邻。边相邻的有4个方向，上下左右。点相邻的也有4个方向，即4个顶点相邻的。



![](http://upload-images.jianshu.io/upload_images/1194012-a0c74a7e02fa551b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如上图，绿色的区域是一颗四叉树表示的范围，四叉树上面有一个点，图中黄色区域标明的点。现在想求四叉树上黄色的点的希尔伯特曲线邻居。图中黑色的线就是一颗穿过四叉树的希尔伯特曲线。希尔伯特曲线的起点0在左上角的方格中，终点63在右上角的方格中。

红色的四个格子是黄色格子边相邻邻居，蓝色的四个格子是黄色格子的顶点相邻的邻居，所以黄色格子的邻居为8个格子，分别表示的点是8，9，54，11，53，30，31，32 。可以看出来这些邻居在表示的点上面并不是相邻的。

那么怎么求四叉树上任意一点的希尔伯特曲线邻居呢？




## 一. 边邻居

边邻居最直接的想法就是 先拿到中心点的坐标 (i，j) ，然后通过坐标系的关系，拿到与它边相邻的 Cell 的坐标  (i + 1，j) ， (i - 1，j) ， (i，j - 1) ， (i，j + 1) 。

实际做法也是如此。不过这里涉及到需要转换的地方。这里需要把希尔伯特曲线上的点转换成坐标以后才能按照上面的思路来计算边邻居。

关于 CellID 的生成与数据结构，见笔者这篇[《Google S2 中的 CellID 是如何生成的 ？》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_CellID.md)

按照上述的思路，实现出来的代码如下：

```go


func (ci CellID) EdgeNeighbors() [4]CellID {
	level := ci.Level()
	size := sizeIJ(level)
	f, i, j, _ := ci.faceIJOrientation()
	return [4]CellID{
		cellIDFromFaceIJWrap(f, i, j-size).Parent(level),
		cellIDFromFaceIJWrap(f, i+size, j).Parent(level),
		cellIDFromFaceIJWrap(f, i, j+size).Parent(level),
		cellIDFromFaceIJWrap(f, i-size, j).Parent(level),
	}
}



```

边按照，下边，右边，上边，左边，逆时针的方向依次编号0，1，2，3 。


接下来具体分析一下里面的实现。

```go

func sizeIJ(level int) int {
	return 1 << uint(maxLevel-level)
}

```

sizeIJ 保存的是当前 Level 的格子**边长**大小。这个大小是相对于 Level 30 来说的。比如 level = 29，那么它的 sizeIJ 就是2，代表 Level 29 的一个格子边长是由2个 Level 30 的格子组成的，那么也就是2^2^=4个小格子组成的。如果是 level = 28，那么边长就是4，由16个小格子组成。其他都以此类推。

```go

func (ci CellID) faceIJOrientation() (f, i, j, orientation int) {

	f = ci.Face()
	orientation = f & swapMask
	nbits := maxLevel - 7*lookupBits // first iteration

	for k := 7; k >= 0; k-- {
		orientation += (int(uint64(ci)>>uint64(k*2*lookupBits+1)) & ((1 << uint((2 * nbits))) - 1)) << 2
		orientation = lookupIJ[orientation]
		i += (orientation >> (lookupBits + 2)) << uint(k*lookupBits)
		j += ((orientation >> 2) & ((1 << lookupBits) - 1)) << uint(k*lookupBits)
		orientation &= (swapMask | invertMask)
		nbits = lookupBits // following iterations
	}
	// 下面这个判断还没有看懂
	if ci.lsb()&0x1111111111111110 != 0 {
		orientation ^= swapMask
	}
	return
}


```

这个方法就是把 CellID 再分解回原来的 i 和 j。这里具体的过程在笔者这篇[《Google S2 中的 CellID 是如何生成的 ？》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_CellID.md)里面的 cellIDFromFaceIJ 方法里面有详细的叙述，这里就不再赘述了。cellIDFromFaceIJ 方法和 faceIJOrientation 方法是互为逆方法。
cellIDFromFaceIJ 是把 face，i，j 这个当入参传进去，返回值是 CellID，faceIJOrientation 是把 CellID 分解成 face，i，j，orientation。faceIJOrientation 比 cellIDFromFaceIJ 分解出来多一个 orientation。（由于下面也没有用到这个 orientation ，暂时请读者先不管，这个判断 orientation 的代码，笔者也有点疑惑，暂时先不解释）。

最后进行转换，具体代码实现如下：

```go

func cellIDFromFaceIJWrap(f, i, j int) CellID {
	// Convert i and j to the coordinates of a leaf cell just beyond the
	// boundary of this face.  This prevents 32-bit overflow in the case
	// of finding the neighbors of a face cell.
	fmt.Printf("#########################\n")
	fmt.Printf("i,j 原始的值 = %v-%b | %v-%b\n", i, i, j, j)
	i = clamp(i, -1, maxSize)
	j = clamp(j, -1, maxSize)
	fmt.Printf("i,j 变换后的值 = %v-%b | %v-%b\n", i, i, j, j)

	// We want to wrap these coordinates onto the appropriate adjacent face.
	// The easiest way to do this is to convert the (i,j) coordinates to (x,y,z)
	// (which yields a point outside the normal face boundary), and then call
	// xyzToFaceUV to project back onto the correct face.
	//
	// The code below converts (i,j) to (si,ti), and then (si,ti) to (u,v) using
	// the linear projection (u=2*s-1 and v=2*t-1).  (The code further below
	// converts back using the inverse projection, s=0.5*(u+1) and t=0.5*(v+1).
	// Any projection would work here, so we use the simplest.)  We also clamp
	// the (u,v) coordinates so that the point is barely outside the
	// [-1,1]x[-1,1] face rectangle, since otherwise the reprojection step
	// (which divides by the new z coordinate) might change the other
	// coordinates enough so that we end up in the wrong leaf cell.
	const scale = 1.0 / maxSize
	limit := math.Nextafter(1, 2)
	fmt.Printf("limit 的值 = %v-%b \n", limit, limit)
	u := math.Max(-limit, math.Min(limit, scale*float64((i<<1)+1-maxSize)))
	v := math.Max(-limit, math.Min(limit, scale*float64((j<<1)+1-maxSize)))

	fmt.Printf("u，v 的值 = %v-%b | %v-%b\n", u, u, v, v)

	// Find the leaf cell coordinates on the adjacent face, and convert
	// them to a cell id at the appropriate level.

	fmt.Printf("f，u，v 的原始值 = %v-%b | %v-%b | %v-%b\n", f, f, u, u, v, v)

	f, u, v = xyzToFaceUV(faceUVToXYZ(f, u, v))

	fmt.Printf("f，u，v 的变换以后的值 = %v-%b | %v-%b | %v-%b\n", f, f, u, u, v, v)

	fmt.Printf("#########################\n")
	return cellIDFromFaceIJ(f, stToIJ(0.5*(u+1)), stToIJ(0.5*(v+1)))
}

```



## 二. 顶点邻居


## 三. 全邻居





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