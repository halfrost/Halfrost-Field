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
	// 下面这个判断详细解释
	if ci.lsb()&0x1111111111111110 != 0 {
		orientation ^= swapMask
	}
	return
}


```

这个方法就是把 CellID 再分解回原来的 i 和 j。这里具体的过程在笔者这篇[《Google S2 中的 CellID 是如何生成的 ？》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_CellID.md)里面的 cellIDFromFaceIJ 方法里面有详细的叙述，这里就不再赘述了。cellIDFromFaceIJ 方法和 faceIJOrientation 方法是互为逆方法。
cellIDFromFaceIJ 是把 face，i，j 这个当入参传进去，返回值是 CellID，faceIJOrientation 是把 CellID 分解成 face，i，j，orientation。faceIJOrientation 比 cellIDFromFaceIJ 分解出来多一个 orientation。


这里需要重点解释的是 orientation 怎么计算出来的。

我们知道 CellID 的数据结构是 3位 face + 60位 position + 1位标志位。那么对于 Level - n 的非叶子节点，3位 face 之后，一定是有 2 * n 位二进制位，然后紧接着 2*(maxLevel - n) + 1 位以1开头的，末尾都是0的二进制位。maxLevel = 30 。

例如 Level - 16，中间一定是有32位二进制位，然后紧接着 2*(30 - 16) + 1 = 29位。这29位是首位为1，末尾为0组成的。3 + 32 + 29 = 64 位。64位 CellID 就这样组成的。

当 n = 30，3 + 60 + 1 = 64，所以末尾的1并没有起任何作用。当 n = 29，3 + 58 + 3 = 64，于是末尾一定是 100 组成的。10对方向并不起任何作用，最后多的一个0也对方向不起任何作用。关键就是看10和0之间有多少个00 。当 n = 28，3 + 56 + 5 = 64，末尾5位是 10000，在10和0之间有一个“00”。“00”是会对方向产生影响，初始的方向应该再异或 01 才能得到。

关于 “00” 会对原始的方向产生影响，这点其实比较好理解。CellID 从最先开始的方向进行四分，每次四分都将带来一次方向的变换。直到变换到最后一个4个小格子的时候，方向就不会变化了，因为在4个小格子之间就可以唯一确定是哪一个 Cell 被选中。所以这也是上面看到了， Level - 30 和 Level - 29 的方向是不变的，除此以外的 Level 是需要再异或一次 01 ，变换以后得到原始的 orientation。


最后进行转换，具体代码实现如下：

```go

func cellIDFromFaceIJWrap(f, i, j int) CellID {
	// 1.
	i = clamp(i, -1, maxSize)
	j = clamp(j, -1, maxSize)

	// 2.
	const scale = 1.0 / maxSize
	limit := math.Nextafter(1, 2)
	u := math.Max(-limit, math.Min(limit, scale*float64((i<<1)+1-maxSize)))
	v := math.Max(-limit, math.Min(limit, scale*float64((j<<1)+1-maxSize)))
	// 3.
	f, u, v = xyzToFaceUV(faceUVToXYZ(f, u, v))
	return cellIDFromFaceIJ(f, stToIJ(0.5*(u+1)), stToIJ(0.5*(v+1)))
}

```

转换过程总共分为三步。第一步先处理 i，j 边界的问题。第二步，将 i，j 转换成 u，v 。第三步，u，v 转 xyz，再转回 u，v，最后转回 CellID 。


第一步：

```go

func clamp(x, min, max int) int {
	if x < min {
		return min
	}
	if x > max {
		return max
	}
	return x
}

```

clamp 函数就是用来限定 i ， j 的范围的。i，j 的范围始终限定在 [-1，maxSize] 之间。


第二步：

最简单的想法是将（i，j）坐标转换为（x，y，z）（这个点不在边界上），然后调用 xyzToFaceUV 方法投影到对应的 face 上。

我们知道在生成 CellID 的时候，stToUV 的时候，用的是一个二次变换：

```go

func stToUV(s float64) float64 {
	if s >= 0.5 {
		return (1 / 3.) * (4*s*s - 1)
	}
	return (1 / 3.) * (1 - 4*(1-s)*(1-s))
}

```

但是此处，我们用的变换就简单一点，用的是线性变换。

```go

u = 2 * s - 1
v = 2 * t - 1

```

u，v 的取值范围都被限定在 [-1，1] 之间。具体代码实现：


```go

const scale = 1.0 / maxSize
limit := math.Nextafter(1, 2)
u := math.Max(-limit, math.Min(limit, scale*float64((i<<1)+1-maxSize)))
v := math.Max(-limit, math.Min(limit, scale*float64((j<<1)+1-maxSize)))

```

第三步：找到叶子节点，把 u，v 转成 对应 Level 的 CellID。

```go

f, u, v = xyzToFaceUV(faceUVToXYZ(f, u, v))
return cellIDFromFaceIJ(f, stToIJ(0.5*(u+1)), stToIJ(0.5*(v+1)))

```

这样就求得了一个 CellID 。

由于边有4条边，所以边邻居有4个。

```go

	return [4]CellID{
		cellIDFromFaceIJWrap(f, i, j-size).Parent(level),
		cellIDFromFaceIJWrap(f, i+size, j).Parent(level),
		cellIDFromFaceIJWrap(f, i, j+size).Parent(level),
		cellIDFromFaceIJWrap(f, i-size, j).Parent(level),
	}


```


上面数组里面分别会装入当前 CellID 的上边邻居，右边邻居，下边邻居，左边邻居。

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