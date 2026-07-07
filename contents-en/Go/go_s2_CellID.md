# How Is the CellID in Google S2 Generated?


![](http://upload-images.jianshu.io/upload_images/1194012-64ce626aba0ed519.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In [“Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md), I analyzed the algorithmic ideas behind Google S2 in detail. After the article was published, some readers became curious about its implementation. This article is a supplement to the previous one and looks at the concrete implementation of the Google S2 algorithm from a code perspective. I recommend reading the algorithmic concepts in the previous article first; the code implementation in this article will then be easier to understand.


## 1. What Is a Cell?


Google S2 defines a framework for decomposing the unit sphere into a hierarchical structure of cells. Each Cell is a quadrilateral bounded by four geodesics. The top level of the hierarchy is obtained by projecting the six faces of a cube onto the unit sphere, and lower levels are obtained by recursively subdividing each cell into four children. For example, the image below shows two Cells on one of the six faces, one of which has been subdivided several times:


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-59278816e3f3761f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


Note that the Cell edges appear curved because they are spherical geodesics—that is, straight lines on the sphere (similar to the routes flown by aircraft).


Each cell in the hierarchy has a level, defined as the number of times the cell has been subdivided (starting from a face cell). Cell levels range from 0 to 30. The smallest cells at level 30 are called leaf cells; there are 6 * 4^30^ of them in total, and each is roughly 1 cm across on the Earth’s surface. (Details about cell sizes at each level can be found in [the S2 Cell ID data structure](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#6-s2-cell-id-%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84).)


S2 Levels are very useful for spatial indexing and for approximating regions as sets of cells. A Cell can be used to represent both points and regions: points are typically represented as leaf nodes, while regions are represented as sets of Cells at any Level. For example, the following is a set of 22 cells approximating Hawaii:


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-402b7c697ac2fed5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


## 2. S(lat,lng) -> f(x,y,z) 


**Latitude ranges from [-90°,90°].**  
**Longitude ranges from [-180°,180°].**

The first conversion step converts spherical coordinates into three-dimensional Cartesian coordinates.
```go

func makeCell() {
	latlng := s2.LatLngFromDegrees(30.64964508, 104.12343895)
	cellID := s2.CellIDFromLatLng(latlng)
}

```
The two short lines above construct a 64-bit CellID.
```go

func LatLngFromDegrees(lat, lng float64) LatLng {
	return LatLng{s1.Angle(lat) * s1.Degree, s1.Angle(lng) * s1.Degree}
}

```
The step above converts latitude and longitude into radians. Since latitude and longitude are angles, converting degrees to radians simply requires multiplying by π / 180°.
```go


const (
	Radian Angle = 1
	Degree       = (math.Pi / 180) * Radian
}

```
`LatLngFromDegrees` converts longitude and latitude into a `LatLng` struct. The `LatLng` struct is defined as follows:
```go

type LatLng struct {
	Lat, Lng s1.Angle
}

```
Once you have the `LatLng` struct, you can use the `CellIDFromLatLng` method to convert the latitude/longitude radians into a 64-bit `CellID`.
```go

func CellIDFromLatLng(ll LatLng) CellID {
	return cellIDFromPoint(PointFromLatLng(ll))
}

```
The above method is also completed in two steps: first convert the latitude and longitude into a point in the coordinate system, then convert that point in the coordinate system into a CellID.

For how latitude and longitude are converted into a point in the coordinate system, see the general analysis in [this article](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#四-s-算法) by the author. That article explains, from the perspective of code implementation, how to convert a point in the spherical coordinate system into the corresponding Hilbert curve point on a quadtree.
```go


func PointFromLatLng(ll LatLng) Point {
	phi := ll.Lat.Radians()
	theta := ll.Lng.Radians()
	cosphi := math.Cos(phi)
	return Point{r3.Vector{math.Cos(theta) * cosphi, math.Sin(theta) * cosphi, math.Sin(phi)}}
}


```
The function above converts longitude and latitude into a vector point in a 3D coordinate system. The vector starts at the origin of the 3D coordinates and ends at the point converted onto the sphere. The conversion relationship is shown below:

![](http://upload-images.jianshu.io/upload_images/1194012-c8e13ebbc98e6ac9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

θ is the latitude in the longitude/latitude pair, which is `phi` in the code above; φ is the longitude, which is `theta` in the code above. Based on the trigonometric functions, we can obtain the 3D coordinates of this vector:
```go

x = r * cos θ * cos φ
y = r * cos θ * sin φ 
z = r * sin θ

```
The radius of the sphere in the figure is r = 1. Therefore, the final constructed vector is:
```go

r3.Vector{math.Cos(theta) * cosphi, math.Sin(theta) * cosphi, math.Sin(phi)}

```
**(x, y, z) is a direction vector; it is not required to be a unit vector. The range of values for (x, y, z) lies within the 3D cubic space [-1,+1] x [-1,+1] x [-1,+1]. It can be normalized to obtain the corresponding point on the unit sphere.**


At this point, the conversion from a point on the sphere S(lat,lng) -> f(x,y,z) has been completed.


## III. f(x,y,z) -> g(face,u,v)

Next, perform the conversion from f(x,y,z) -> g(face,u,v).
```go

func xyzToFaceUV(r r3.Vector) (f int, u, v float64) {
	f = face(r)
	u, v = validFaceXYZToUV(f, r)
	return f, u, v
}


```
The idea here is to perform projection.

First, choose the longest axis among the x, y, and z axes as the principal axis.
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
By default, the x-axis is defined as 0, the y-axis as 1, and the z-axis as 2.
```go

const (
	XAxis Axis = iota
	YAxis
	ZAxis
)

```
Finally, the value of `face` is the longest of the three axes. Note that all three are constrained to the range [0,5], so if it is a negative axis, you need to add 3 to adjust it. The implementation is as follows.
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
Thus, the values for the six faces are determined. If the principal axis is the positive x-axis, `face = 0`; if it is the positive y-axis, `face = 1`; if it is the positive z-axis, `face = 2`; if it is the negative x-axis, `face = 3`; if it is the negative y-axis, `face = 4`; if it is the negative z-axis, `face = 5`.

After selecting the principal axis, the coordinate points on the other two axes need to be projected onto this face. The specific approach is projection or coordinate-system transformation.
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
The above describes the coordinate system transforms on the six faces. If you map them intuitively to the six faces of a circumscribed cube, then face = 0 corresponds to the front face, face = 1 to the right face, face = 2 to the top face, face = 3 to the back face, face = 4 to the left face, and face = 5 to the bottom face.

Note that the 3D coordinate axes here follow a right-handed coordinate system. That is, if the four fingers of your right hand curl in the direction from the x-axis to the y-axis, the direction your thumb points is the positive direction of the other axis.

For example, on the front face of the cube, rotating your right hand from the positive direction of the y-axis to the positive direction of the z-axis makes your thumb point in the positive direction of the x-axis, so this corresponds to the front face. As another example, for the bottom face of the cube 👇, rotating your right hand from the negative direction of the y-axis to the negative direction of the x-axis makes your thumb point in the negative direction of the z-axis, so this corresponds to the bottom face 👇.

**(face,u,v) represents a cubic spatial coordinate system, where the value range of all three axes is [-1,1]. To make every cell the same size, a transformation is required; the specific transformation rule is in the next conversion step.**

## IV. g(face,u,v) -> h(face,s,t)

Converting from u and v to s and t uses a quadratic transform. In the C++ version there are three types of transforms; for why this quadratic transform was ultimately chosen, see [here](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#3-球面矩形投影修正).
```go


// Linear transform
u = 0.5 * ( u + 1)

// tan() transform
u = 2 / pi * (atan(u) + pi / 4) = 2 * atan(u) / pi + 0.5

// Quadratic transform
u >= 0，u = 0.5 * sqrt(1 + 3*u)
u < 0,    u = 1 - 0.5 * sqrt(1 - 3*u)

```
In Go, the conversion only includes the quadratic transformation; the other two transformations simply have no corresponding code in the Go implementation.
```go

func uvToST(u float64) float64 {
	if u >= 0 {
		return 0.5 * math.Sqrt(1+3*u)
	}
	return 1 - 0.5*math.Sqrt(1-3*u)
}


```
**(face, s, t) denotes a cell-space coordinate system, where both s and t range over [0,1]. They represent a point on a face. For example, the point (s,t) = (0.5,0.5) represents the center point on this face. This point is also the vertex of the 4 smaller cells obtained by subdividing the current face.**


## 5. h(face,s,t) -> H(face,i,j)

This section covers coordinate-system conversion. For the specific idea, see [here](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#4-converting-between-points-and-coordinate-axis-points).

Convert the point in s and t to a point in the i and j coordinate system.
```go


func stToIJ(s float64) int {
	return clamp(int(math.Floor(maxSize*s)), 0, maxSize-1)
}

```
The range of s and t is [0,1], and now the range needs to be expanded to [0,2^30^-1]. This is only one of the faces.


## VI. H(face,i,j) -> CellID 


Before performing the final conversion, let’s first review the conversion process so far.
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
S(lat,lng) -> f(x,y,z) -> g(face,u,v) -> h(face,s,t) -> H(face,i,j) -> CellID involves a total of 5 conversion steps.


After the 5 conversion steps above, this is equivalent to mapping every latitude/longitude point on Earth to a point on the Hilbert curve.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-dee23e3aa755dafc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


Before explaining the final conversion step to CellID, let’s first clarify the issue of orientation.


There are 2 arrays that store constants:
```go


	ijToPos = [4][4]int{
		{0, 1, 3, 2}, // canonical order
		{0, 3, 1, 2}, // axes swapped
		{2, 3, 1, 0}, // bits inverted
		{2, 1, 3, 0}, // swapped & inverted
	}
	posToIJ = [4][4]int{
		{0, 1, 3, 2}, // canonical order:    (0,0), (0,1), (1,1), (1,0)
		{0, 2, 3, 1}, // axes swapped:       (0,0), (1,0), (1,1), (0,1)
		{3, 2, 0, 1}, // bits inverted:      (1,1), (1,0), (0,0), (0,1)
		{3, 1, 0, 2}, // swapped & inverted: (1,1), (0,1), (0,0), (1,0)
	}

```
The values in these two two-dimensional arrays can be represented by the following two diagrams:


![](http://upload-images.jianshu.io/upload_images/1194012-cd6a5af8e42d89a0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The diagram above is `posToIJ`. Note that the `i` and `j` here refer to coordinate values, as shown above. Since this is a first-order Hilbert curve, `i` and `j` are equal to the values on the coordinate axes. `posToIJ[0] = {0, 1, 3, 2}` represents the shape shown in Figure 0 above. Similarly, `posToIJ[1]` represents Figure 1, `posToIJ[2]` represents Figure 2, and `posToIJ[3]` represents Figure 3.

From the four diagrams above, we can see that:
**The four diagrams of `posToIJ` are actually obtained by rotating a “U” shape counterclockwise by 90° each time. Here we can only see the relationships among the four diagrams themselves—that is, the relationships between siblings—but we cannot see the parent-child relationships between diagrams.**

The values stored in `posToIJ[0] = {0, 1, 3, 2}` are the combined values of `ij`. `posToIJ[0][0] = 0` refers to the cell where `i = 0` and `j = 0`; combined, `ij` is `00`, which is `0`. `posToIJ[0][1] = 1` refers to the cell where `i = 0` and `j = 1`; combined, `ij` is `01`, which is `1`. `posToIJ[0][2] = 1` refers to the cell where `i = 1` and `j = 1`; combined, `ij` is `11`, which is `3`. `posToIJ[0][3] = 2` refers to the cell where `i = 1` and `j = 0`; combined, `ij` is `10`, which is `2`. The order in the array is the drawing order of the “U” shape. Therefore, `posToIJ[0] = {0, 1, 3, 2}` represents the shape in Figure 0. The other figures work the same way.


![](http://upload-images.jianshu.io/upload_images/1194012-cbfcef53b1758394.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The four diagrams above are for the `ijToPos` array. This array is not used anywhere in the entire library either, so we do not need to worry about its corresponding mapping here.


The `lookupPos` array and `lookupIJ` array are initialized by the following code.
```go

func init() {
	initLookupCell(0, 0, 0, 0, 0, 0)
	initLookupCell(0, 0, 0, swapMask, 0, swapMask)
	initLookupCell(0, 0, 0, invertMask, 0, invertMask)
	initLookupCell(0, 0, 0, swapMask|invertMask, 0, swapMask|invertMask)
}


```
If we substitute all the variable values in, the code becomes:
```go

func init() {
	initLookupCell(0, 0, 0, 0, 0, 0)
	initLookupCell(0, 0, 0, 1, 0, 1)
	initLookupCell(0, 0, 0, 2, 0, 2)
	initLookupCell(0, 0, 0, 3, 0, 3)
}

```
`initLookupCell` takes 6 parameters; 4 of them are `0`. We need to focus on the fourth and sixth parameters. The fourth parameter is `origOrientation`, and the sixth parameter is `orientation`.

Inside the `initLookupCell` method, there are the following 4 lines:
```go

initLookupCell(level, i+(r[0]>>1), j+(r[0]&1), origOrientation, pos, orientation^posToOrientation[0])
initLookupCell(level, i+(r[1]>>1), j+(r[1]&1), origOrientation, pos+1, orientation^posToOrientation[1])
initLookupCell(level, i+(r[2]>>1), j+(r[2]&1), origOrientation, pos+2, orientation^posToOrientation[2])
initLookupCell(level, i+(r[3]>>1), j+(r[3]&1), origOrientation, pos+3, orientation^posToOrientation[3])

```
As an aside, let’s explain what r[0]>>1 and r[0]&1 are actually doing.
```go

	r := posToIJ[orientation]

```
The `r` array comes from the `posToIJ` array. As mentioned above, the `posToIJ` array actually contains four “U” shapes in different directions. In effect, it represents the relative directions among the current four small sibling cells. What `r[0]`, `r[1]`, `r[2]`, and `r[3]` retrieve are the four values `00`, `01`, `10`, and `11`. So the `r[0]>>1` operation extracts the first bit of the two-bit binary value, i.e. the `i` bit. The `r[0]&1` operation extracts the second bit of the two-bit binary value, i.e. the `j` bit. The same applies to `r[1]`, `r[2]`, and `r[3]`.

Now let’s return to the question of direction. First, we need to explain what the following four lines do.
```go

orientation^posToOrientation[0]
orientation^posToOrientation[1]
orientation^posToOrientation[2]
orientation^posToOrientation[3]

```
Before we explain further, let's first take a look at the posToOrientation array:
```go

posToOrientation = [4]int{swapMask, 0, 0, invertMask | swapMask}

```
Substitute the values into the array above:
```go

posToOrientation = [4]int{1, 0, 0, 3}

```
The original values stored in the `posToOrientation` array are [01, 00, 00, 11]. These four values are not initialized arbitrarily.

![](http://upload-images.jianshu.io/upload_images/1194012-73a4a7c9135a26a7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


They actually correspond to the directions in which the four small squares in Figure 0 will be subdivided next. For position 0 in Figure 0, the direction of the next figure should be Figure 1, i.e. 01; for position 1 in Figure 0, the direction of the next figure should be Figure 0, i.e. 00; for position 2 in Figure 0, the direction of the next figure should be Figure 0, i.e. 00; and for position 3 in Figure 0, the direction of the next figure should be Figure 3, i.e. 11. This is the rationale behind initializing the `posToOrientation` array.


**From the four `posToIJ` diagrams, we can only see the relationships among siblings; the four `posToOrientation` diagrams show us the relationships between parent and child.**

Returning to the code mentioned above:
```go

orientation^posToOrientation[0]
orientation^posToOrientation[1]
orientation^posToOrientation[2]
orientation^posToOrientation[3]

```
Each `orientation` is XORed with the `posToOrientation` array. This ensures that, each time, the current direction of `pos` can be derived from the previous original direction. In other words, it computes the parent-child relationship.

![](http://upload-images.jianshu.io/upload_images/1194012-73a4a7c9135a26a7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Let’s return to this figure. The relationship between siblings is a 90° counterclockwise rotation. So, if these four siblings each act as a parent, what is the relationship between each of them and their four children? The conclusion is: **the parent-child relationships are 01, 00, 00, and 11.** We can also see this from the figure. In Figure 1, although the “U” shape has been rotated 90° counterclockwise, its children have also been rotated 90° (relative to Figure 0). The same applies to Figures 2 and 3.

In code, this relationship is represented by the following four lines:
```go

orientation^posToOrientation[0]
orientation^posToOrientation[1]
orientation^posToOrientation[2]
orientation^posToOrientation[3]

```
For example, suppose orientation = 0, i.e., Figure 0, then:
```go

00 ^ 01 = 01
00 ^ 00 = 00
00 ^ 00 = 00
00 ^ 11 = 11

```
The directions of the four children in Figure 0 are then computed as 01, 00, 00, 11, 1003. This is consistent with what Figure 0 in the image above shows.

The same applies to orientation = 1, orientation = 2, and orientation = 3:
```go

01 ^ 01 = 00
01 ^ 00 = 01
01 ^ 00 = 01
01 ^ 11 = 10


10 ^ 01 = 11
10 ^ 00 = 10
10 ^ 00 = 10
10 ^ 11 = 01

11 ^ 01 = 10
11 ^ 00 = 11
11 ^ 00 = 11
11 ^ 11 = 00


```
In Figure 1, the children’s orientations are 0, 1, 1, 2. In Figure 2, the children’s orientations are 3, 2, 2, 1. In Figure 3, the children’s orientations are 2, 3, 3, 0. These are exactly consistent with what is shown in the diagrams.

So the transformation above is critical. It is specifically used to convert between parent and child orientations in the Hilbert curve.

Finally, some readers may wonder: what is the relationship between `origOrientation` and `orientation`?
```go

lookupPos[(ij<<2)+origOrientation] = (pos << 2) + orientation
lookupIJ[(pos<<2)+origOrientation] = (ij << 2) + orientation

```
The array indices store `origOrientation`, and the values stored at those indices are `orientation`.

![](http://upload-images.jianshu.io/upload_images/1194012-4903cd17303c485b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


After explaining the issue of Hilbert curve orientation, we can next take a closer look at the coordinate conversion issue for 55. The previous article, [“Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md), discussed this topic. Some readers were still unclear about a few points, so here is one final explanation.

In Google S2, when initializing `initLookupCell`, two arrays are initialized: the `lookupPos` array and the `lookupIJ` array. Four key variables are also used along the way: `i`, `j`, `pos`, and `orientation`. We have already discussed `orientation`, so we will not repeat it here. What needs a detailed explanation is the relationship between `i`, `j`, and `pos`.

`pos` refers to the position on the Hilbert curve. This position is counted from the starting point of the Hilbert curve: starting at the beginning, how many blocks away is the current block? Note that this block is a large block composed of 4 smaller blocks, because `orientation` selects one of the 4 blocks.

In the example of 55, `pos` is actually equal to 13. This means the current large block composed of 4 smaller blocks is the 13th large block from the starting point. Since each large block consists of 4 smaller blocks, the first number in the current large block is `13 * 4 = 52`. In code, this is implemented by shifting left by 2 bits, which is equivalent to multiplying by 4. Then add the offset `orientation = 11` for 55, which is 3, so `52 + 3 = 55`.

Now let’s talk about `i` and `j`. In the example of 55, `i = 14`, `1110`, and `j = 13`, `1101`. If we look at the coordinate system intuitively, 55 is actually at coordinate `(5, 2)`. So why are `i = 14` and `j = 13`? The confusing part here is the relationship between `i`, `j`, and `pos`.

**Note:**
**`i` and `j` do not directly correspond to coordinates in the Hilbert curve coordinate system, because initialization needs to generate a fifth-order Hilbert curve. In the first-order Hilbert curve represented by the `posToIJ` array, `i` and `j` directly correspond to coordinates in the Hilbert curve coordinate system.**

At this point, readers may ask: then which parameter corresponds to the coordinates in the Hilbert curve coordinate system?


The `pos` parameter corresponds to the coordinates in the Hilbert curve coordinate system. Once the starting point and order of a Hilbert curve are determined, and once the `pos` position of a large block composed of four smaller blocks is determined, its coordinate is effectively determined as well. Coordinates on the Hilbert curve do not depend on `i` or `j`; they are completely determined by the properties of the curve and the `pos` position.

**We do not care about the coordinates of small blocks on the Hilbert curve; what we care about is the conversion relationship between `pos` and `i`, `j`!**

Another question arises: then which coordinate system do `i` and `j` correspond to?

**`i` and `j` correspond to coordinates in a coordinate system after coordinate transformation.**

We know that when performing the `( u, v ) -> ( i, j )` transformation, the range of `u` and `v` is `[0, 1]`, and after transformation it must be mapped to `[ 0, 2^30^-1 ]`. `i` and `j` are the coordinate values in the transformed coordinate system, and the range of `i` and `j` becomes `[ 0, 2^30^-1 ]`.


So what is the purpose of initializing and computing the `lookupPos` and `lookupIJ` arrays? These two arrays are used to connect `i`, `j`, and `pos`. Once you know `pos`, you can immediately find the corresponding `i` and `j`. Once you know `i` and `j`, you can immediately find the corresponding `pos`.


**The bridge for converting between `i`, `j`, and `pos` is the method used to generate the Hilbert curve. This method can be compared to the way a Z-index curve is generated.**

The Z-index curve is generated by bisecting the longitude and latitude coordinate intervals separately: values in the left interval are recorded as 0, and values in the right interval are recorded as 1. In the resulting two binary strings, even-numbered bits store longitude and odd-numbered bits store latitude. These are then combined into a new binary string, and after this string is base-32 encoded, the final geohash is generated.

So how is the Hilbert curve generated? It first converts longitude and latitude coordinates into coordinates in a three-dimensional Cartesian coordinate system, then projects them onto the 6 faces of the circumscribed cube. Thus the three-dimensional Cartesian coordinate `(x, y, z)` is converted into `(face, u, v)`. `(face, u, v)` is transformed by a quadratic transform into `(face, s, t)`, and `(face, s, t)` is transformed by a coordinate-system transform into `(face, i, j)`. Then `i` and `j` are each extracted 4 bits at a time: the 4 binary bits of `i` are placed first, and the 4 binary bits of `j` are placed after them. Finally, the 2 orientation bits `orientation` of the Hilbert curve are appended. This forms a 10-bit binary value like `iiii jjjj oo`. Through the bridge of the `lookupPos` array, the corresponding `pos` value is found. The `pos` value is the corresponding position on the Hilbert curve. The same process continues: extract another 4 bits from `i` and another 4 bits from `j`, perform the same conversion, and continue until all binary bits of `i` and `j` have been consumed. Finally, these generated `pos` values are concatenated into the final CellID, with earlier-generated values placed in higher-order bits and later-generated values placed in lower-order bits.


> Some readers may wonder why the design is `iiii jjjj oo`, and why it uses 4 bits at a time. Google developers wrote the following in the comments: “We considered combining 16 bits at a time, with 14 bits for `position` + 2 bits for `orientation`, but in practice the code runs faster with smaller arrays. 2 KB is more suitable for storage in the primary cache.”


In Google S2, `i` and `j` are converted 4 bits at a time, so the valid values of `i` and `j` are 0–15. Therefore, `iiii jjjj oo` is a decimal number whose representable range is `2^10^ = 1024`. So the initial values of `pos` also need to be computed up to 1024. Since `pos` is a large block composed of 4 smaller blocks, it is itself a first-order Hilbert curve. Therefore, initialization needs to generate a fifth-order Hilbert curve.


![](http://upload-images.jianshu.io/upload_images/1194012-9feb6afa0ffbb81b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above is a first-order Hilbert curve. It consists of 4 small cells.

![](http://upload-images.jianshu.io/upload_images/1194012-9ac5960d43dcfbaa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above is a second-order Hilbert curve, composed of 4 `pos` cells.

![](http://upload-images.jianshu.io/upload_images/1194012-0f4790f1ac760d63.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above is a third-order Hilbert curve.

![](http://upload-images.jianshu.io/upload_images/1194012-cc038a117b63438f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The figure above is a fourth-order Hilbert curve.

![](http://upload-images.jianshu.io/upload_images/1194012-65eedea2a62b6caf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The figure above is a fifth-order Hilbert curve. There are 1024 `pos` cells in total.


At this point, we have clarified the orientation of the Hilbert curve and the order of the Hilbert curve generated in Google S2: a fifth-order Hilbert curve.

From this, we can also see that **the Hilbert curve is composed of “U” shapes, specifically 4 “U” shapes in different orientations. The initial orientation is a “U” whose opening faces upward.**


For an animation of Hilbert curve generation, see the section [“Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2” — How the Hilbert Curve Is Constructed](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#2-希尔伯特曲线的构造方法) in the previous article.

Now it is much easier to derive 55. Starting from the fifth-order Hilbert curve, the derivation process is shown below.

![](http://upload-images.jianshu.io/upload_images/1194012-418f28aa82592e42.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


First, 55 is located at the green point in each subfigure above. We repeatedly determine the orientation. In the first subfigure, the green point is at position `00`. In the second subfigure, the green point is at position `00`. In the third subfigure, the green point is at position `11`. In the fourth subfigure, the green point is at position `01`. In the fifth subfigure, the green point is at position `11`. In fact, by the fourth step, the value obtained is the value of `pos`, namely `00001101 = 13`. The last 2 bits specify the position of the concrete point inside the `pos` cell, which is `11`, so `13 * 4 + 3 = 55`.

Of course, if you directly derive all the way based on orientation, you can also get `0000110111 = 55`, which is also 55.

## VII. Example


Finally, here is a complete concrete example:

|  | Latitude| | Longitude|
|:-------:|:-------:|:------:|:------:|
|Cartesian coordinate system|-0.209923466239598816018841|0.834295703289209877873134|0.509787031803590306999752|
|(face,u,v)|1|0.25161758044776666|0.6110387837235114|
|(face,s,t)|1|0.6623542747924445|0.8415931842598497|
|(face,i,j)|1|711197487|903653800|

The first 4 steps of conversion have been completed above.

The final step is to convert to CellID. The concrete implementation code is as follows. Since CellID is 64 bits, after excluding the 3 bits occupied by `face` and the position occupied by the final sentinel bit `1`, 60 bits remain.
```go

func cellIDFromFaceIJ(f, i, j int) CellID {
  // 1.
	n := uint64(f) << (posBits - 1)
  // 2.
	bits := f & swapMask
  // 3.
	for k := 7; k >= 0; k-- {
		mask := (1 << lookupBits) - 1
		bits += int((i>>uint(k*lookupBits))&mask) << (lookupBits + 2)
		bits += int((j>>uint(k*lookupBits))&mask) << 2
		bits = lookupPos[bits]
    // 4.
		n |= uint64(bits>>2) << (uint(k) * 2 * lookupBits)
    // 5.
		bits &= (swapMask | invertMask)
	}
  // 6.
	return CellID(n*2 + 1)
}

```
The specific steps are as follows:

1. Shift face left by 60 bits.
2. Compute the initial origOrientation. The initial origOrientation is derived from face; the result after face & 01 is used to ensure that each face has a right-handed coordinate system.
3. Loop from the beginning, taking the 4-bit binary values of i and j in sequence, compute ij<<2 + origOrientation, then look up the corresponding pos<<2 + orientation in the lookupPos array.
4. Concatenate the CellID. Shift pos<<2 + orientation right by 2 bits, leaving only pos, then continue appending pos to the CellID from the previous iteration.
5. Compute the origOrientation for the next iteration. &= (swapMask | invertMask) means &= 11, i.e., take the last 2 binary bits.
6. Finally, append the final marker bit 1.


Here, let’s talk about step 2: the conversion of origOrientation.

We know that face has 6 faces, numbered 000, 001, 010, 011, 100, 101. To make all 6 faces have the properties of a right-handed coordinate system, a conversion is required. The conversion rule can actually be implemented with a single bit operation:
```go

000 & 001 = 00
001 & 001 = 01
010 & 001 = 00
011 & 001 = 01
100 & 001 = 00
101 & 001 = 01

```
After the conversion, the value of face & 01 is the initial origOrientation.

The following table shows each step (the table is fairly wide; scroll right):

|  | i| j| orientation |ij<<2 + origOrientation |pos<<2 + orientation|CellID|
|:-------:|:-------:|:------:|:------:|:------:|:------:|:------:|
||711197487| 903653800 |1||||
|Binary representation|101010011001000000001100101111|110101110111001010100110101000|01||||
||||||||
|Conversion|Shift i left by 6 bits, leaving room for 4 bits of j and 2 orientation bits|Shift j left by 2 bits, leaving room for orientation|The initial value of orientation is the value of face|[iiii jjjj oo]: four bits of i, four bits of j, and two bits of o are concatenated in order to form a 10-bit binary value|Converted from the previous column by looking it up in the lookupPos array|Initial value: face shifted left by 60 bits. In each subsequent loop, pos is concatenated. Note that orientation is not included, so the previous column needs to be shifted right by 2 bits to drop the trailing orientation|
||||||||
|Take the first two bits of i and j|10 000000|11 00|01|(00)10001101|101110 |1101100000000000000000000000000000000000000000000000000000000|
|Then take bits 3, 4, 5, and 6 of i and j|1010 000000|0101 00|10|1010010110|111011110|1101101110111000000000000000000000000000000000000000000000000|
|Then take bits 7, 8, 9, and 10 of i and j|0110 000000|1101 00|10|(0)110110110|1110011110|1101101110111111001110000000000000000000000000000000000000000|
|Then take bits 11, 12, 13, and 14 of i and j|0100 000000|1100 00|10|(0)100110010|1110000001|1101101110111111001111110000000000000000000000000000000000000|
|Then take bits 15, 16, 17, and 18 of i and j|0000 000000|1010 00|01|(0000)101001|1110110000|1101101110111111001111110000011101100000000000000000000000000|
|Then take bits 19, 20, 21, and 22 of i and j|0011 000000|1001 00|00|(00)11100100|100011001|1101101110111111001111110000011101100010001100000000000000000|
|Then take bits 23, 24, 25, and 26 of i and j|0010 000000|1010 00|01|(00)10101001|1110001011|1101101110111111001111110000011101100010001101110001000000000|
|Then take bits 27, 28, 29, and 30 of i and j|1111 000000|1000 00|11|1111100011|1010110|1101101110111111001111110000011101100010001101110001000010101|
|Final result||||||11011011101111110011111100000111011000100011011100010000101011<br>(concatenate the trailing sentinel bit 1)|

Taking any one iteration from the loop, it can be illustrated as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-8f5f935722da1837.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Note: Because CellID is 64 bits, the first three bits are face and the last bit is the sentinel bit, so there are 60 bits in the middle. i and j are each converted into 30-bit binary values: seven 4-bit binary chunks and one 2-bit binary chunk. 4*7 + 2 = 30. iijjoo, namely the first 2 binary bits of i plus the first 2 binary bits of j plus origOrientation, forms a 6-bit binary value. It can represent at most 2^6^ = 32 possible values, and the converted pos + orientation also has at most 32 possible values. In other words, the converted result is at most a 6-bit binary value. After removing the trailing 2 bits of orientation, pos is at most 4 bits in this case. iiiijjjjpppp, namely the 4 binary bits of i plus the 4 binary bits of j plus origOrientation, forms a 10-bit binary value. It can represent at most 2^10^ = 1024 possible values, and the converted pos + orientation also has at most 1024 possible values. In other words, the converted result is at most a 10-bit binary value. After removing the trailing 2 bits of orientation, pos is at most 8 bits in this case.

Because the final CellID concatenates only pos, the middle portion has 4 + 7 * 8 = 60 bits. After concatenation, all 60 middle bits are made up of pos. Finally, concatenate the first 3 bits and the trailing 1-bit sentinel, and the 64-bit CellID is generated.

At this point, the entire CellID generation process is complete.

------------------------------------------------------

Spatial search article series:

[How to Understand n-Dimensional Space and n-Dimensional Spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How Is CellID Generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA (Lowest Common Ancestor) in a Quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The Magical De Bruijn Sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to Find Hilbert Curve Neighbors in a Quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_cellID/](https://halfrost.com/go_s2_cellID/)