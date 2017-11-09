# Google S2 中的 CellID 是如何生成的 ？


笔者在[《高效的多维空间点索引算法 — Geohash 和 Google S2》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)文章中详细的分析了 Google S2 的算法实现思想。文章发出来以后，一部分读者对它的实现产生了好奇。本文算是对上篇文章的补充，将从代码实现的角度来看看 Google S2 的算法具体实现。建议先读完上篇文章里面的算法思想，再看本篇的代码实现会更好理解一些。


## 一. S(lat,lng) -> f(x,y,z) 

第一步转换，将球面坐标转换成三维直角坐标


```go

func makeCell() {
	latlng := s2.LatLngFromDegrees(30.64964508, 104.12343895)
	cellID := s2.CellIDFromLatLng(latlng)
}

```

上面短短两句话就构造了一个 64 位的CellID。

```go

func LatLngFromDegrees(lat, lng float64) LatLng {
	return LatLng{s1.Angle(lat) * s1.Degree, s1.Angle(lng) * s1.Degree}
}

```

上面这一步是把经纬度转换成弧度。由于经纬度是角度，弧度转角度乘以 π / 180° 即可。


```go


const (
	Radian Angle = 1
	Degree       = (math.Pi / 180) * Radian
}

```


LatLngFromDegrees 就是把经纬度转换成 LatLng 结构体。LatLng 结构体定义如下：

```go

type LatLng struct {
	Lat, Lng s1.Angle
}

```


得到了 LatLng 结构体以后，就可以通过 CellIDFromLatLng 方法把经纬度弧度转成 64 位的 CellID 了。

```go

func CellIDFromLatLng(ll LatLng) CellID {
	return cellIDFromPoint(PointFromLatLng(ll))
}

```

上述方法也分了2步完成，先把经纬度转换成坐标系上的一个点，再把坐标系上的这个点转换成 CellID。


关于经纬度如何转换成坐标系上的一个点，这部分的大体思路分析见笔者的[这篇文章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md#四-s-算法)，这篇文章告诉你从代码实现的角度如何把球面坐标系上的一个点转换到四叉树上对应的希尔伯特曲线点。

```go


func PointFromLatLng(ll LatLng) Point {
	phi := ll.Lat.Radians()
	theta := ll.Lng.Radians()
	cosphi := math.Cos(phi)
	return Point{r3.Vector{math.Cos(theta) * cosphi, math.Sin(theta) * cosphi, math.Sin(phi)}}
}


```

上面这个函数就是把经纬度转换成三维坐标系中的一个向量点，向量的起点是三维坐标的原点，终点为球面上转换过来的点。转换的关系如下图：


![](http://upload-images.jianshu.io/upload_images/1194012-c8e13ebbc98e6ac9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

θ 即为经纬度的纬度，也就是上面代码中的 phi ，φ 即为经纬度的经度，也就是上面代码的 theta 。根据三角函数就可以得到这个向量的三维坐标：

```go

x = r * cos θ * cos φ
y = r * cos θ * sin φ 
z = r * sin θ

```

图中球面的半径 r = 1 。所以最终构造出来的向量即为：

```go

r3.Vector{math.Cos(theta) * cosphi, math.Sin(theta) * cosphi, math.Sin(phi)}

```

至此，已经完成了球面上的点S(lat,lng) -> f(x,y,z) 的转换。


## 二. f(x,y,z) -> g(face,u,v)

接下来进行 f(x,y,z) -> g(face,u,v) 的转换

```go

func xyzToFaceUV(r r3.Vector) (f int, u, v float64) {
	f = face(r)
	u, v = validFaceXYZToUV(f, r)
	return f, u, v
}


```


这里的思路是进行投影。

先从 x，y，z 三个轴上选择一个最长的轴，作为主轴。

```go

func (v Vector) LargestComponent() Axis {
	t := v.Abs()

	if t.X > t.Y {
		if t.X > t.Z {
			return XAxis
		}
		return ZAxis
	}
	if t.Y > t.Z {
		return YAxis
	}
	return ZAxis
}

```

默认定义 x 轴为0，y轴为1，z轴为2 。

```go

const (
	XAxis Axis = iota
	YAxis
	ZAxis
)

```


最后 face 的值就是三个轴里面最长的轴，注意这里限定了他们三者都在 [0,5] 之间，所以如果是负轴就需要 + 3 进行修正。实现代码如下。

```go


func face(r r3.Vector) int {
	f := r.LargestComponent()
	switch {
	case f == r3.XAxis && r.X < 0:
		f += 3
	case f == r3.YAxis && r.Y < 0:
		f += 3
	case f == r3.ZAxis && r.Z < 0:
		f += 3
	}
	return int(f)
}

```

所以 face 的6个面上的值就确定下来了。主轴为 x 正半轴，face = 0；主轴为 y 正半轴，face = 1；主轴为 z 正半轴，face = 2；主轴为 x 负半轴，face = 3；主轴为 y 负半轴，face = 4；主轴为 z 负半轴，face = 5 。

选定主轴以后就要把另外2个轴上的坐标点投影到这个面上，具体做法就是投影或者坐标系转换。

```go

func validFaceXYZToUV(face int, r r3.Vector) (float64, float64) {
	switch face {
	case 0:
		return r.Y / r.X, r.Z / r.X
	case 1:
		return -r.X / r.Y, r.Z / r.Y
	case 2:
		return -r.X / r.Z, -r.Y / r.Z
	case 3:
		return r.Z / r.X, r.Y / r.X
	case 4:
		return r.Z / r.Y, -r.X / r.Y
	}
	return -r.Y / r.Z, -r.X / r.Z
}

```

上述就是 face 6个面上的坐标系转换。如果直观的对应一个外切立方体的哪6个面，那就是 face = 0 对应的是前面，face = 1 对应的是右面，face = 2 对应的是上面，face = 3 对应的是后面，face = 4 对应的是左面，face = 5 对应的是下面。


注意这里的三维坐标轴是符合右手坐标系的。即 右手4个手指沿着从 x 轴旋转到 y 轴的方向，大拇指的指向就是另外一个面的正方向。

比如立方体的前面，右手从 y 轴的正方向旋转到 z 轴的正方向，大拇指指向的是 x 轴的正方向，所以对应的就是前面。再举个例子，立方体的下面👇，右手从 y 轴的负方向旋转到 x 轴的负方向，大拇指指向的是 z 轴负方向，所以对应的是下面👇。


## 三. g(face,u,v) -> h(face,s,t)


从 u、v 转换到 s、t 用的是二次变换。在 C ++ 的版本中有三种变换，至于为何最后选了这种二次变换，原因见[这里](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md#3-球面矩形投影修正)。

```go


// 线性转换
u = 0.5 * ( u + 1)

// tan() 变换
u = 2 / pi * (atan(u) + pi / 4) = 2 * atan(u) / pi + 0.5

// 二次变换
u >= 0，u = 0.5 * sqrt(1 + 3*u)
u < 0,    u = 1 - 0.5 * sqrt(1 - 3*u)

```
在 Go 中，转换直接就只有二次变换了，其他两种变换在 Go 的实现版本中就直接没有相应的代码。

```go

func uvToST(u float64) float64 {
	if u >= 0 {
		return 0.5 * math.Sqrt(1+3*u)
	}
	return 1 - 0.5*math.Sqrt(1-3*u)
}


```

## 四. h(face,s,t) -> H(face,i,j)

这一部分是坐标系的转换，具体思想见[这里](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md#4-点与坐标轴点相互转换)。

将 s、t 上的点转换成坐标系 i、j 上的点。

```go


func stToIJ(s float64) int {
	return clamp(int(math.Floor(maxSize*s)), 0, maxSize-1)
}

```

s，t的值域是[0,1]，现在值域要扩大到[0,2^30^-1]。这里只是其中一个面。


## 五. H(face,i,j) -> CellID 


在进行最后的转换之前，先回顾一下到目前为止的转换流程。


```go


func CellIDFromLatLng(ll LatLng) CellID {
    return cellIDFromPoint(PointFromLatLng(ll))
}

func cellIDFromPoint(p Point) CellID {
	f, u, v := xyzToFaceUV(r3.Vector{p.X, p.Y, p.Z})
	i := stToIJ(uvToST(u))
	j := stToIJ(uvToST(v))
	return cellIDFromFaceIJ(f, i, j)
}

```



S(lat,lng) -> f(x,y,z) -> g(face,u,v) -> h(face,s,t) -> H(face,i,j) -> CellID 总共有5步转换。

```go

func cellIDFromFaceIJ(f, i, j int) CellID {
	n := uint64(f) << (posBits - 1)
	bits := f & swapMask
	for k := 7; k >= 0; k-- {
		mask := (1 << lookupBits) - 1
		bits += int((i>>uint(k*lookupBits))&mask) << (lookupBits + 2)
		bits += int((j>>uint(k*lookupBits))&mask) << 2
		bits = lookupPos[bits]
		n |= uint64(bits>>2) << (uint(k) * 2 * lookupBits)
		bits &= (swapMask | invertMask)
	}
	return CellID(n*2 + 1)
}

```


![](http://upload-images.jianshu.io/upload_images/1194012-73a4a7c9135a26a7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



![](http://upload-images.jianshu.io/upload_images/1194012-4903cd17303c485b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




解释完希尔伯特曲线方向的问题之后，接下来可以再仔细说说 55 的坐标转换的问题。前一篇文章[《高效的多维空间点索引算法 — Geohash 和 Google S2》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)里面有谈到这个问题，读者有些疑惑点，这里再最终解释一遍。

在 Google S2 中，初始化 initLookupCell 的时候，会初始化2个数组，一个是 lookupPos 数组，一个是 lookupIJ 数组。中间还会用到 i ， j ， pos 和 orientation 四个关键的变量。orientation 这个之前说过了，这里就不再赘述了。需要详细说明的 i ，j 和 pos 的关系。

pos 指的是在 希尔伯特曲线上的位置。这个位置是从 希尔伯特 曲线的起点开始算的。从起点开始数，到当前是第几块方块。注意这个方块是由 4 个小方块组成的大方块。因为 orientation 是选择4个方块中的哪一个。

在 55 的这个例子里，pos 其实是等于 13 的。代表当前4块小方块组成的大方块是距离起点的第13块大方块。由于每个大方块是由4个小方块组成的。所以当前这个大方块的第一个数字是 13 * 4 = 52 。代码实现就是左移2位，等价于乘以 4 。再加上 55 的偏移的 orientation = 11，再加 3 ，所以 52 + 3 = 55 。 

再说说 i 和 j 的问题，在 55 的这个例子里面 i = 14，1110，j = 13，1101 。如果直观的看坐标系，其实 55 是在 (5，2) 的坐标上。但是现在为何 i = 14，j = 13 呢 ？这里容易弄混的就是 i ，j 和 pos 的关系。**i，j 并不是直接对应的 希尔伯特曲线 坐标系上的坐标。**

读者到这里就会疑问了，那是什么参数对应的是希尔伯特曲线坐标系上的坐标呢？


pos 参数对应的就是希尔伯特曲线坐标系上的坐标。一旦一个希尔伯特曲线的起始点和阶数确定以后，四个小方块组成的一个大方块的 pos 位置确定以后，那么它的坐标其实就已经确定了。希尔伯特曲线上的坐标并不依赖 i，j，完全是由曲线的性质和 pos 位置决定的。

疑问又来了，那 i，j 对应的是什么坐标系上的坐标呢？

**i，j 对应的是一个经过坐标变换以后的坐标系坐标。**

我们知道，在进行 ( u，v ) -> ( i，j ) 变换的时候，u，v 的值域是 [0，1] 之间，然后经过变换要变到 [ 0, 2^30^-1 ] 之间。i，j 就是变换以后坐标系上的坐标值，i，j 的值域变成了 [ 0, 2^30^-1 ] 。


那初始化计算 lookupPos 数组和 lookupIJ 数组有什么用呢？这两个数组就是把 i，j 和 pos 联系起来的数组。知道 pos 以后可以立即找到对应的 i，j。知道 i，j 以后可以立即找到对应的 pos。


i，j 和 pos 互相转换之间的桥梁

![](http://upload-images.jianshu.io/upload_images/1194012-418f28aa82592e42.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




------------------------------------------------------

空间搜索系列文章：

[如何理解 n 维空间和 n 维时空](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[高效的多维空间点索引算法 — Geohash 和 Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)  
[Google S2 中的四叉树求 LCA 最近公共祖先](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_lowest_common_ancestor.md)  
[神奇的德布鲁因序列](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_De_Bruijn.md)



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_cellID/](https://halfrost.com/go_s2_cellID/)