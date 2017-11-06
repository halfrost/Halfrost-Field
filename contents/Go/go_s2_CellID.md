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

选定主轴以后就要把另外2个轴上的坐标点投影到这个面上，具体做法就是投影。


## 三. g(face,u,v) -> h(face,s,t)



## 四. h(face,s,t) -> H(face,i,j)


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