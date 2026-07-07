+++
author = "一缕殇流化隐半边冰霜"
categories = ["Go"]
date = 2017-08-11T21:52:32Z
description = ""
draft = false
image = "https://img.halfrost.com//Blog/ArticleTitleImage/a/0c/ca94ad89b1a7d682f85adf957c600.jpeg"
slug = "go_spatial_search"
tags = ["Go"]
title = "Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2"

+++


## Introduction

Every day when we work late and head home at night, we may use Didi or a shared bike. When we open the app, we see an interface like this:  


![](https://img.halfrost.com/Blog/ArticleImage/56_1.png)


The app displays available taxis or shared bikes within a certain radius around us. Suppose the map shows vehicles within a 5-kilometer radius centered on the user. How would we implement this? The most intuitive idea is to query a table in the database, compute which vehicles are within 5 kilometers of the user, filter them out, and return the data to the client.

This approach is rather clumsy, and in practice it is generally not used. Why? Because it requires computing the relative distance for every row in the entire table. That is far too time-consuming. Since the dataset is too large, we need to divide and conquer. This leads naturally to partitioning the map into blocks. Then, even if we compute the relative distance for every record in each block, it is still much faster than scanning the entire table.

We also know that commonly used databases such as MySQL and PostgreSQL natively support B+ trees. This data structure enables efficient queries. The process of partitioning a map is essentially a process of adding an index. If we can find a way to assign a suitable index to points on the map and make those indexes sortable, then we can use methods similar to binary search for fast queries.

Here comes the problem: points on a map are two-dimensional, with longitude and latitude. How should they be indexed? If we search on only one dimension, either longitude or latitude, we still need to perform a second search after the first pass. What if the data is in even higher dimensions? Three dimensions, for example. Some people might say we can set priorities among dimensions, such as concatenating them into a composite key. But in three-dimensional space, which of x, y, and z should have higher priority? Setting priorities does not seem very reasonable.


This article introduces two relatively general-purpose indexing algorithms for spatial points.
    
------------------------------------------------------

## 1. The GeoHash Algorithm

### 1. Introduction to the Geohash Algorithm
Geohash is a geocoding system invented by [Gustavo Niemeyer](https://en.wikipedia.org/w/index.php?title=Gustavo_Niemeyer&action=edit&redlink=1). It is a hierarchical data structure that partitions space into grids. Geohash is a practical application of the Z-order curve ([Z-order curve](https://en.wikipedia.org/wiki/Z-order_curve)) among space-filling curves.


What is a Z-order curve?

![](https://img.halfrost.com/Blog/ArticleImage/56_2.png)


The figure above shows a Z-order curve. This curve is relatively simple, and it is also easy to generate: you only need to connect the end of each Z to the beginning of the next.

![](https://img.halfrost.com/Blog/ArticleImage/56_3.png)


A Z-order curve can also be extended to three-dimensional space. As long as the Z shapes are small enough and dense enough, they can fill the entire three-dimensional space.

At this point, readers may still be confused and wonder what relationship Geohash has with the Z-order curve. In fact, the theoretical foundation of the Geohash algorithm is based on the generation principle of the Z-order curve. Let’s return to Geohash.

Geohash can provide hierarchical levels of arbitrary precision. In general, levels range from 1 to 12.

![](https://img.halfrost.com/Blog/ArticleImage/56_3_0.png)


Remember the problem mentioned in the introduction? Here we can use Geohash to solve it.

We can use the length of the Geohash string to determine the size of the region to partition. The corresponding relationship can be found in the cell width and height in the table above. Once the cell width and height are chosen, the length of the Geohash string is determined. In this way, we divide the map into rectangular regions.


Although the map has been partitioned into regions, one problem remains: how can we quickly find neighboring points and regions around a given point?

Geohash has a property related to the Z-order curve: locations near a point (though not absolutely always) tend to have hash strings with a common prefix, and the longer the common prefix, the closer the two points are.

Because of this property, Geohash is often used as a unique identifier. In a database, Geohash can be used to represent a point. This common-prefix property of Geohash can be used to quickly search for neighboring points. Points that are closer to the target point usually have a longer common prefix with the target point’s Geohash string. (However, this is not guaranteed; there are special cases, which will be illustrated below.)

Geohash also has several encoding formats. The two common ones are base 32 and base 36.

![](https://img.halfrost.com/Blog/ArticleImage/56_3_1.png)


The base 36 version is case-sensitive and uses 36 characters: “23456789bBCdDFgGhHjJKlLMnNPqQrRtTVWX”.

![](https://img.halfrost.com/Blog/ArticleImage/56_3_2.png)


### 2. A Practical Example of Geohash

The following example uses base-32. Let’s take a concrete example.

![](https://img.halfrost.com/Blog/ArticleImage/56_4.png)


The image above is a map. Metro City is in the middle of the map. Suppose we need to query for the restaurants closest to Metro City. How should we do it?

First, we need to grid the map using geohash. By looking up the table, we choose rectangles with a string length of 6 to grid this map.

After querying, the latitude and longitude of Metro City are [31.1932993, 121.43960190000007].

Process the latitude first. The latitude range of the Earth is [-90,90]. Split this range into two parts: [-90,0) and [0,90]. 31.1932993 falls in the (0,90] interval, that is, the right interval, so mark it as 1. Then continue bisecting the (0,90] interval into [0,45) and [45,90]. 31.1932993 falls in the [0,45) interval, that is, the left interval, so mark it as 0. Continue subdividing in this way.

![](https://img.halfrost.com/Blog/ArticleImage/56_4_0.png)


Then process the longitude in the same way. The longitude range of the Earth is [-180,180].

![](https://img.halfrost.com/Blog/ArticleImage/56_4_1.png)


The binary string produced by the latitude is 101011000101110, and the binary string produced by the longitude is 110101100101101. According to the rule **“put longitude in even-numbered positions and latitude in odd-numbered positions”**, we recombine the binary strings for longitude and latitude to generate a new one: 111001100111100000110011110110. The final step is to convert this resulting string into characters, which requires looking up the base-32 table. 11100 11001 11100 00011 00111 10110 convert to decimal as 28 25 28 3 7 22; after table lookup and encoding, the final result is wtw37q.


We can also compute the 8 surrounding grids.

![](https://img.halfrost.com/Blog/ArticleImage/56_5.png)


From the map, we can see that these 9 adjacent cells have exactly the same prefix: wtw37.

What happens if we add one more character to the string? Increase the Geohash length to 7.

![](https://img.halfrost.com/Blog/ArticleImage/56_6.png)


When the Geohash length increases to 7, the grid becomes smaller, and the Geohash of Metro City becomes wtw37qt.

At this point, readers should already understand the principles of the Geohash algorithm. Let’s combine the 6-character and 7-character versions into one figure.


![](https://img.halfrost.com/Blog/ArticleImage/56_7.png)


We can see that the Geohash value of the large cell in the middle is wtw37q, so all the smaller cells inside it have the prefix wtw37q. It is easy to imagine that when the Geohash string length is 5, the Geohash would certainly be wtw37.


Next, let’s explain the relationship between Geohash and the Z-order curve mentioned earlier. Recall the rule used in the final step when merging the longitude and latitude strings: **“put longitude in even-numbered positions and latitude in odd-numbered positions”**. Readers may wonder where this rule comes from. Was it just made up out of thin air? In fact, it was not. This rule comes from the Z-order curve. See the figure below:

![](https://img.halfrost.com/Blog/ArticleImage/56_8.png)


The x-axis is latitude, and the y-axis is longitude. This is where the rule of putting longitude in even-numbered positions and latitude in odd-numbered positions comes from.

Finally, there is the question of precision. Part of the data in the following table comes from Wikipedia.

![](https://img.halfrost.com/Blog/ArticleImage/56_8_0.png)


### 3. Concrete Implementation of Geohash

By now, readers should have a clear understanding of the Geohash algorithm. Next, let’s implement the Geohash algorithm in Go.
```go

package geohash

import (
	"bytes"
)

const (
	BASE32                = "0123456789bcdefghjkmnpqrstuvwxyz"
	MAX_LATITUDE  float64 = 90
	MIN_LATITUDE  float64 = -90
	MAX_LONGITUDE float64 = 180
	MIN_LONGITUDE float64 = -180
)

var (
	bits   = []int{16, 8, 4, 2, 1}
	base32 = []byte(BASE32)
)

type Box struct {
	MinLat, MaxLat float64 // latitude
	MinLng, MaxLng float64 // longitude
}

func (this *Box) Width() float64 {
	return this.MaxLng - this.MinLng
}

func (this *Box) Height() float64 {
	return this.MaxLat - this.MinLat
}

// Input values: latitude, longitude, precision (geohash length)
// Return geohash and the region containing the point
func Encode(latitude, longitude float64, precision int) (string, *Box) {
	var geohash bytes.Buffer
	var minLat, maxLat float64 = MIN_LATITUDE, MAX_LATITUDE
	var minLng, maxLng float64 = MIN_LONGITUDE, MAX_LONGITUDE
	var mid float64 = 0

	bit, ch, length, isEven := 0, 0, 0, true
	for length < precision {
		if isEven {
			if mid = (minLng + maxLng) / 2; mid < longitude {
				ch |= bits[bit]
				minLng = mid
			} else {
				maxLng = mid
			}
		} else {
			if mid = (minLat + maxLat) / 2; mid < latitude {
				ch |= bits[bit]
				minLat = mid
			} else {
				maxLat = mid
			}
		}

		isEven = !isEven
		if bit < 4 {
			bit++
		} else {
			geohash.WriteByte(base32[ch])
			length, bit, ch = length+1, 0, 0
		}
	}

	b := &Box{
		MinLat: minLat,
		MaxLat: maxLat,
		MinLng: minLng,
		MaxLng: maxLng,
	}

	return geohash.String(), b
}

```

### 4. Pros and Cons of Geohash

The advantages of Geohash are obvious: it uses the Z-order curve for encoding. A Z-order curve can transform all points in a two-dimensional or multidimensional space into a one-dimensional curve. In mathematics, this is known as a fractal dimension. The Z-order curve also has a locality-preserving property.

A Z-order curve simply computes the z-value of a point in multiple dimensions by interleaving the binary representations of the point’s coordinate values. Once the data is added to this ordering, any one-dimensional data structure—such as a binary search tree, B-tree, skip list, or hash table (with the least significant bits truncated)—can be used to process the data. The ordering produced by the Z-order curve can equivalently be described as the order obtained from a depth-first traversal of a quadtree.

This is another advantage of Geohash: searching for nearby points is relatively fast.


One of Geohash’s disadvantages also comes from the Z-order curve.

The Z-order curve has a fairly serious issue: although it has locality preservation, it also has discontinuities. At every corner of the Z shape, the order may change abruptly.

![](https://img.halfrost.com/Blog/ArticleImage/56_9.png)


Look at the blue points marked in the figure above. Although each pair of points is adjacent in the ordering, they are far apart in distance. In the lower-right diagram, the two red points with adjacent numeric values are almost a full side length of the square apart. The two green points with adjacent numeric values are also about half the side length of the square apart.

Another disadvantage of Geohash is that if an appropriate grid size is not chosen, determining nearby points can become cumbersome.

![](https://img.halfrost.com/Blog/ArticleImage/56_10.png)


As shown above, if the Geohash string length is 6, the grid is the large blue cells. The red star is Metro City, and the purple dots are the target points returned by the search. If we query using the Geohash algorithm, the nearby cells may be wtw37p, wtw37r, wtw37w, and wtw37m. But the actual nearest point is in wtw37q. If a grid this large is chosen, you need to search the 8 surrounding cells as well.

If the Geohash string length is 7, the grid becomes the smaller yellow cells. In that case, there is only one point closest to the red star: wtw37qw.

If the grid size and precision are not chosen well, finding the nearest point still requires querying the 8 surrounding cells again.


## II. Space-Filling Curves and Fractals

Before introducing the second algorithm for indexing points in multidimensional space, we first need to discuss space-filling curves and fractals.

Solving multidimensional point indexing requires solving two problems. First, how do we reduce multiple dimensions to a lower dimension, or to one dimension? Second, how does a one-dimensional curve become fractal?

### 1. Space-Filling Curves

In mathematical analysis, there is a difficult question: can an infinitely long line pass through every point in a space of arbitrary dimension?

![](https://img.halfrost.com/Blog/ArticleImage/56_11.png)


In 1890, Giuseppe Peano discovered a continuous curve, now called the Peano curve, that can pass through every point in the unit square. His goal was to construct a continuous mapping from the unit interval to the unit square. Peano was inspired by Georg Cantor’s earlier counterintuitive result: the infinite number of points in the unit interval has the same cardinality as the infinite number of points in any finite-dimensional [manifold](https://en.wikipedia.org/wiki/Manifold). The problem Peano solved was essentially whether such a continuous mapping exists—a curve that can fill an entire plane. The figure above is one such curve he found.

In general, a one-dimensional object cannot fill a two-dimensional square. But the Peano curve provides a counterexample. The Peano curve is continuous but nowhere differentiable.

The Peano curve is constructed as follows: take a square and divide it into nine equal smaller squares. Starting from the lower-left square and ending at the upper-right square, connect the centers of the smaller squares in sequence with line segments. In the next step, divide each smaller square into nine equal squares, and again connect their centers in the same manner… Repeat this procedure indefinitely. The limiting curve obtained in the end is called the Peano curve.

Peano gave a detailed mathematical description of the mapping between points in the interval [0, 1] and points in the square. In fact, for these points in the square, for ![](https://wikimedia.org/api/rest_v1/media/math/render/svg/31a5c18739ff04858eecc8fec2f53912c348e0e5), two continuous functions x = f(t) and y = g(t) can be found such that x and y take every value belonging to the unit square.

One year later, in 1891, [Hilbert](https://zh.wikipedia.org/wiki/%E5%B8%8C%E5%B0%94%E4%BC%AF%E7%89%B9) constructed such a curve, called the Hilbert curve.


![](https://img.halfrost.com/Blog/ArticleImage/56_12.png)


The figure above shows Hilbert curves of order 1 through 6. The specific construction method will be discussed in the next section.

![](https://img.halfrost.com/Blog/ArticleImage/56_13.gif)


The figure above shows a Hilbert curve filling a three-dimensional space.


Many variants of space-filling curves appeared later, including the Dragon curve, Gosper curve, Koch curve, Moore curve, Sierpiński curve, and Osgood curve. These curves are not related to this article, so they will not be covered in detail.

![](https://img.halfrost.com/Blog/ArticleImage/56_14.gif)

![](https://img.halfrost.com/Blog/ArticleImage/56_15.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_16.gif)

![](https://img.halfrost.com/Blog/ArticleImage/56_17.png)


![](https://img.halfrost.com/Blog/ArticleImage/56_18.png)


In mathematical analysis, a space-filling curve is a parameterized injective function that maps the unit interval to a continuous curve in the unit square, cube, or more generally an n-dimensional hypercube. As the parameter increases, it can get arbitrarily close to any given point in the unit cube. Beyond their mathematical significance, space-filling curves are also used in dimensionality reduction, mathematical programming, sparse multidimensional database indexing, electronics, and biology. Today, space-filling curves are used in web maps.

### 2. Fractals

The emergence of the Peano curve showed that our understanding of dimension was flawed, and that the definition of dimension needed to be re-examined. This is what [fractal geometry](https://zh.wikipedia.org/wiki/%E5%88%86%E5%BD%A2%E5%87%A0%E4%BD%95) studies. In fractal geometry, a dimension can be fractional; this is called a fractal dimension.

After reducing the dimensionality of a multidimensional space, how to make it fractal is another problem. There are many ways to construct fractals. Here is a [list](https://en.wikipedia.org/wiki/List_of_fractals_by_Hausdorff_dimension) where you can see how different fractals are constructed and the fractal dimension of each one, namely the Hausdorff fractal dimension, as well as the topological dimension. We will not go into the details of fractals here; interested readers can read the linked material carefully.

Next, let’s continue with algorithms for indexing points in multidimensional space. The next algorithm is based on the Hilbert curve, so let’s first take a closer look at it.

## III. Hilbert Curve

### 1. Definition of the Hilbert Curve


![](https://img.halfrost.com/Blog/ArticleImage/56_19Hilbert curve fills the plane.gif)


The **Hilbert curve** is a fractal curve ([space-filling curve](https://zh.wikipedia.org/w/index.php?title=%E7%A9%BA%E9%96%93%E5%A1%AB%E5%85%85%E6%9B%B2%E7%B7%9A&action=edit&redlink=1)) that can fill a square in the plane. It was proposed by [David Hilbert](https://zh.wikipedia.org/wiki/%E5%A4%A7%E8%A1%9B%C2%B7%E5%B8%8C%E7%88%BE%E4%BC%AF%E7%89%B9) in 1891.

Because it can fill the plane, its [Hausdorff dimension](https://zh.wikipedia.org/wiki/%E8%B1%AA%E6%96%AF%E5%A4%9A%E5%A4%AB%E7%B6%AD) is 2. If the side length of the square it fills is 1, the length of the Hilbert curve at step n is 2^n - 2^(-n).

### 2. How to Construct a Hilbert Curve

For a first-order Hilbert curve, the construction method is to divide the square into four equal parts, start from the center of one subsquare, and connect through the centers of the other three squares in sequence.

![](https://img.halfrost.com/Blog/ArticleImage/56_20_1st-order Hilbert curve.gif)


For a second-order Hilbert curve, continue dividing each previous subsquare into four equal parts. First generate a first-order Hilbert curve for each group of four small squares. Then connect the four first-order Hilbert curves end to end.

![](https://img.halfrost.com/Blog/ArticleImage/56_21_2nd-order Hilbert curve.gif)


For a third-order Hilbert curve, the construction is similar to the second order: first generate second-order Hilbert curves, then connect the four second-order Hilbert curves end to end.

![](https://img.halfrost.com/Blog/ArticleImage/56_22_3rd-order Hilbert curve.gif)


The construction of an n-th order Hilbert curve is also recursive: first generate an (n-1)-th order Hilbert curve, then connect four (n-1)-th order Hilbert curves end to end.

![](https://img.halfrost.com/Blog/ArticleImage/56_23_5n-th order Hilbert curve.gif)


### 3. Why Choose the Hilbert Curve

At this point, some readers may wonder: among so many space-filling curves, why choose the Hilbert curve?

Because the Hilbert curve has excellent properties.

#### (1) Dimensionality Reduction

First, as a space-filling curve, the Hilbert curve can effectively reduce the dimensionality of a multidimensional space.

![](https://img.halfrost.com/Blog/ArticleImage/56_24_6Hilbert curve unfolds into a line.gif)


The figure above shows that after the Hilbert curve fills a plane, all points on the plane are unfolded into a one-dimensional line.

Some may wonder: the Hilbert curve in the figure above only passes through 16 points—how can that represent a plane?


![](https://img.halfrost.com/Blog/ArticleImage/56_25_7Hilbert curve subdivides indefinitely.gif)


Of course, when n approaches infinity, the n-th order Hilbert curve can approximately fill the entire plane.

#### (2) Stability

For an n-th order Hilbert curve, as n approaches infinity, the positions of points on the curve essentially become stable. For example:

![](https://img.halfrost.com/Blog/ArticleImage/56_26_8Which is better, the Hilbert curve or the serpentine curve.gif)


The left side of the figure above is the Hilbert curve, and the right side is a snake-like curve. As n approaches infinity, both can theoretically fill the plane. But why is the Hilbert curve better?

Given a point on the snake-like curve, as n approaches infinity, the position of that point on the snake-like curve keeps changing.

![](https://img.halfrost.com/Blog/ArticleImage/56_27_9Serpentine curve oscillates back and forth.gif)


This means the relative position of the point is never stable.

Now look at the Hilbert curve. For the same point, as n approaches infinity:

![](https://img.halfrost.com/Blog/ArticleImage/56_28_10Hilbert curve approaches stability.gif)
As you can see from the image above, the positions of the points have barely changed. Therefore, the Hilbert curve is superior.


#### (3) Continuity


![](https://img.halfrost.com/Blog/ArticleImage/56_29.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_30.png)


The Hilbert curve is continuous, so it can guarantee that the space can be completely filled. Continuity requires a mathematical proof. The specific proof method will not be discussed in detail here. If you are interested, you can click the paper on Hilbert curves at the end of the article; it contains a proof of continuity.


The Google S2 algorithm to be introduced next is based on the Hilbert curve. By now, readers should understand why the Hilbert curve was chosen.

## IV. [S²](https://godoc.org/github.com/golang/geo/s2)  Algorithm


>[Google’s S2 library](https://code.google.com/p/s2-geometry-library/) is a real treasure, not only due to its capabilities for spatial indexing but also because it is a library that was released more than 4 years ago and it didn’t get the attention it deserved

The passage above comes from a 2015 blog post by a Google engineer. He sincerely lamented that the S2 algorithm had not received the appreciation it deserved in the four years since its release. Today, however, S2 is already used by many major companies.

Before introducing this heavyweight algorithm, let’s first explain where its name comes from. S2 actually comes from a mathematical notation in geometry, S², which denotes the unit sphere. The S2 library was designed to solve various geometric problems on the surface of a sphere. One point worth mentioning is that, apart from geo/s2 in the official golang repo, which is currently only 40% complete, the S2 implementations in other languages—Java, C++, and Python—are all 100% complete. This article focuses on the Go version.

Next, let’s look at how S2 solves the problem of indexing points in multidimensional space.

### 1. Spherical Coordinate Conversion

Following our earlier approach to handling multidimensional space, we first consider how to reduce dimensionality, and then how to apply a fractal.

As everyone knows, the Earth is approximately a sphere. A sphere is three-dimensional, so how can we reduce three dimensions to one?

A point on the sphere can be represented in a Cartesian coordinate system as follows:


![](https://img.halfrost.com/Blog/ArticleImage/56_31.png)
```vim

x = r * sin θ * cos φ
y = r * sin θ * sin φ 
z = r * cos θ

```
Typically, we represent points on Earth using latitude and longitude.

![](https://img.halfrost.com/Blog/ArticleImage/56_32.png)


Taking this one step further, we can relate them to latitude and longitude on a sphere. One thing to note here is that the latitude angle α plus the spherical-coordinate angle θ in a Cartesian coordinate system equals 90°. So be careful with the trigonometric conversion.

Thus, any point on Earth specified by latitude and longitude can be converted into f(x,y,z).

In S2, the Earth’s radius is treated as the unit value 1. So the radius does not need to be considered. The ranges of x, y, and z are all constrained to [-1,1] x [-1,1] x [-1,1].

### 2. Flattening the Sphere into a Plane

The next step in S2 is to flatten the sphere into a plane. How is this done?

First, an externally tangent cube is placed around the Earth, as shown below.

![](https://img.halfrost.com/Blog/ArticleImage/56_33.png)


Then each point is projected from the center of the sphere onto the six faces of the tangent cube. S2 projects all points on the sphere onto the six faces of this tangent cube.

![](https://img.halfrost.com/Blog/ArticleImage/56_34.png)


Here is a simple projection diagram. The left side of the figure above illustrates the projection onto one face of the cube; the actual affected region on the sphere is shown on the right.


![](https://img.halfrost.com/Blog/ArticleImage/56_35.png)


Viewed from the side, when one part of the sphere is projected onto one face of the cube, the angle between the lines from the edge to the center of the sphere is 90°, but the angle relative to the x, y, and z axes is 45°. We can draw 45° auxiliary circles in the six directions of the sphere, as shown on the left below.

![](https://img.halfrost.com/Blog/ArticleImage/56_36.png)


The figure on the left above shows six auxiliary lines. The blue lines are the front/back pair, the red lines are the left/right pair, and the green lines are the top/bottom pair. Each represents the locus of points where the line from the center of the sphere intersects the sphere at a 45° position. This lets us draw the regions of the sphere that are projected onto the six faces of the tangent cube, as shown on the right above.

After projecting onto the cube, we can unfold the cube.

![](https://img.halfrost.com/Blog/ArticleImage/56_37.png)


There are many ways to unfold a cube. Regardless of how it is unfolded, the smallest unit is a square.

That is the projection scheme used by S2. Next, let’s look at some other projection schemes.

First, there is the following approach, which combines triangles and squares.

![](https://img.halfrost.com/Blog/ArticleImage/56_38.png)


The unfolded net for this approach is shown below.

![](https://img.halfrost.com/Blog/ArticleImage/56_39.png)


This approach is actually quite complex, because its sub-shapes consist of two different types of shapes. Coordinate conversion is slightly more complicated.

Another approach is to use only triangles. With this method, the more triangles there are, the closer the approximation is to a sphere.

![](https://img.halfrost.com/Blog/ArticleImage/56_40.png)


The leftmost figure above consists of 20 triangles. As you can see, it has many sharp corners and differs significantly from a sphere. As the number of triangles increases, it becomes increasingly close to a sphere.

![](https://img.halfrost.com/Blog/ArticleImage/56_41.png)


After unfolding, 20 triangles might look like this.

The last approach may currently be the best one, but it may also be the most complex: projection based on hexagons.

![](https://img.halfrost.com/Blog/ArticleImage/56_42.png)


Hexagons have relatively few sharp corners, and each of their six edges can connect to other hexagons. From the rightmost figure above, you can see that with enough hexagons, the shape approximates a sphere very closely.

![](https://img.halfrost.com/Blog/ArticleImage/56_43.png)


After unfolding, the hexagons look like the figure above. Of course, there are only 12 hexagons here. The more hexagons there are, the better; the finer the granularity, the closer the approximation is to a sphere.

In a public talk, Uber mentioned that they use a hexagonal grid to divide a city into many hexagons. This part was likely developed in-house. Perhaps Didi also divides areas into hexagons, or perhaps Didi has an even better partitioning scheme.


In Google S2, the Earth is unfolded as follows:

![](https://img.halfrost.com/Blog/ArticleImage/56_43_0.png)

If the six unfolded faces above were all represented using a 5th-order Hilbert curve, the six faces would look like this:

![](https://img.halfrost.com/Blog/ArticleImage/56_43_1.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_43_2.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_43_3.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_43_4.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_43_5.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_43_6.png)


Returning to S2, S2 uses squares. So the spherical coordinates from the first step are further converted as f(x,y,z) -> g(face,u,v), where face is one of the six square faces, and u and v correspond to the x and y coordinates on one of those six faces.

### 3. Correcting the Projection of Spherical Rectangles

![](https://img.halfrost.com/Blog/ArticleImage/56_44_0.png)


In the previous step, we projected spherical rectangles on the sphere onto a face of the cube. The resulting shape is similar to a rectangle, but because the angles on the sphere differ, even when projected onto the same face, the areas of these rectangles are not necessarily the same.

![](https://img.halfrost.com/Blog/ArticleImage/56_44.png)


The figure above shows a spherical rectangle on the sphere projected onto one face of the cube.

![](https://img.halfrost.com/Blog/ArticleImage/56_45.png)


Actual calculations show that the largest area differs from the smallest area by a factor of 5.2, as shown on the left above. The same angular interval projects to different areas on the square at different latitudes.

So we need to correct the areas of the projected shapes. Choosing an appropriate mapping correction function becomes the key. The goal is to achieve something like the right side of the figure above, making the areas of the rectangles as equal as possible.

The code for this conversion is explained in detail only in the C++ version; in the Go version, it is mentioned only briefly. This left me confused for quite a while.

![](https://img.halfrost.com/Blog/ArticleImage/56_45_0.png)


A linear transform is the fastest transform, but it produces the least correction. The tan() transform can make the areas of the projected rectangles much more consistent; the ratio between the largest and smallest rectangles differs by only 0.414. This can be considered very close. However, calling tan() is very expensive. If all points were computed this way, performance would drop by a factor of 3.

In the end, Google chose a quadratic transform. This is a projection curve that approximates the tangent curve. Its computation speed is much faster than tan(), roughly 3 times as fast. The sizes of the projected rectangles it produces are also similar. However, the ratio between the largest rectangle and the smallest rectangle is still 2.082.


In the table above, ToPoint and FromPoint are respectively the number of milliseconds required to convert a unit vector to a Cell ID and to convert a Cell ID back to a unit vector. (A Cell ID is the ID of a rectangle on one of the six cube faces after projection; the rectangle is called a Cell, and its corresponding ID is called a Cell ID.) ToPointRaw is the number of milliseconds required, for certain purposes, to convert a Cell ID into a non-unit vector.


In S2, the default conversion is the quadratic transform.
```c

#define S2_PROJECTION S2_QUADRATIC_PROJECTION

```
Let's take a closer look at how these three conversions are actually performed.
```c

#if S2_PROJECTION == S2_LINEAR_PROJECTION

inline double S2::STtoUV(double s) {
  return 2 * s - 1;
}

inline double S2::UVtoST(double u) {
  return 0.5 * (u + 1);
}

#elif S2_PROJECTION == S2_TAN_PROJECTION

inline double S2::STtoUV(double s) {
  // Unfortunately, tan(M_PI_4) is slightly less than 1.0.  This isn't due to
  // a flaw in the implementation of tan(), it's because the derivative of
  // tan(x) at x=pi/4 is 2, and it happens that the two adjacent floating
  // point numbers on either side of the infinite-precision value of pi/4 have
  // tangents that are slightly below and slightly above 1.0 when rounded to
  // the nearest double-precision result.

  s = tan(M_PI_2 * s - M_PI_4);
  return s + (1.0 / (GG_LONGLONG(1) << 53)) * s;
}

inline double S2::UVtoST(double u) {
  volatile double a = atan(u);
  return (2 * M_1_PI) * (a + M_PI_4);
}

#elif S2_PROJECTION == S2_QUADRATIC_PROJECTION

inline double S2::STtoUV(double s) {
  if (s >= 0.5) return (1/3.) * (4*s*s - 1);
  else          return (1/3.) * (1 - 4*(1-s)*(1-s));
}

inline double S2::UVtoST(double u) {
  if (u >= 0) return 0.5 * sqrt(1 + 3*u);
  else        return 1 - 0.5 * sqrt(1 - 3*u);
}

#else

#error Unknown value for S2_PROJECTION

#endif

```
The handling of `tan(M_PI_4)` above is due to precision issues, which make it slightly less than 1.0.

Therefore, after projection, the three transformations in the correction function should be as follows:
```c

// Linear transform
u = 0.5 * ( u + 1)

// tan() transform
u = 2 / pi * (atan(u) + pi / 4) = 2 * atan(u) / pi + 0.5

// Quadratic transform
u >= 0，u = 0.5 * sqrt(1 + 3*u)
u < 0， u = 1 - 0.5 * sqrt(1 - 3*u)

```
Note that although the transformation formula above only shows `u`, that does not mean only `u` is transformed. In actual use, both `u` and `v` are passed in separately and both are transformed.

For this correction function, the Go version directly implements only the quadratic transformation. The other two transformation methods are not mentioned anywhere in the entire library.
```go

// stToUV converts an s or t value to the corresponding u or v value.
// This is a non-linear transformation from [-1,1] to [-1,1] that
// attempts to make the cell sizes more uniform.
// This uses what the C++ version calls 'the quadratic transform'.
func stToUV(s float64) float64 {
	if s >= 0.5 {
		return (1 / 3.) * (4*s*s - 1)
	}
	return (1 / 3.) * (1 - 4*(1-s)*(1-s))
}

// uvToST is the inverse of the stToUV transformation. Note that it
// is not always true that uvToST(stToUV(x)) == x due to numerical
// errors.
func uvToST(u float64) float64 {
	if u >= 0 {
		return 0.5 * math.Sqrt(1+3*u)
	}
	return 1 - 0.5*math.Sqrt(1-3*u)
}

```
After the correction transform, both u and v are transformed into s and t. The value range also changes. The range of u and v is [-1,1]; after the transform, the range of s and t is [0,1].

At this point, to summarize: a point on the sphere S(lat,lng) -> f(x,y,z) -> g(face,u,v) -> h(face,s,t). So far, there have been four conversion steps in total: converting spherical latitude/longitude coordinates into spherical xyz coordinates, then converting them into coordinates on the projection face of the circumscribed cube, and finally transforming them into the corrected coordinates.

Up to now, there are two places where S2 can be optimized: first, can the projection shape be changed to a hexagon? Second, can we find a transform function with an effect similar to tan(), but with a computation speed much higher than tan(), so that it does not affect computational performance?

### 4. Converting Between Points and Coordinate-Axis Points

In the S2 algorithm, the default Cell subdivision level is 30, which means dividing a square into 2^30 * 2^30 small squares.

So how should the s and t from the previous step be mapped onto this square and converted accordingly?

![](https://img.halfrost.com/Blog/ArticleImage/56_46.png)

The value range of s and t is [0,1]; now the range needs to be expanded to [0,2^30^-1].
```go

// stToIJ converts value in ST coordinates to a value in IJ coordinates.
func stToIJ(s float64) int {
	return clamp(int(math.Floor(maxSize*s)), 0, maxSize-1)
}

```
The C++ implementation is the same.
```c

inline int S2CellId::STtoIJ(double s) {
  // Converting from floating-point to integers via static_cast is very slow
  // on Intel processors because it requires changing the rounding mode.
  // Rounding to the nearest integer using FastIntRound() is much faster.
  // Subtract 0.5 here to round to the nearest integer
  return max(0, min(kMaxSize - 1, MathUtil::FastIntRound(kMaxSize * s - 0.5)));
}

```
At this step, it is h(face,s,t) -> H(face,i,j).

### 5. Converting Between Coordinate-Axis Points and Hilbert Curve Cell IDs

The final step: how do we associate i, j with a point on the Hilbert curve?
```go

const (
	lookupBits = 4
	swapMask   = 0x01
	invertMask = 0x02
)

var (
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
	posToOrientation = [4]int{swapMask, 0, 0, invertMask | swapMask}
	lookupIJ         [1 << (2*lookupBits + 2)]int
	lookupPos        [1 << (2*lookupBits + 2)]int
)

```
Before the transformation, let’s first explain some of the variables that are defined.

posToIJ represents a matrix that records positional information for some unit Hilbert curve cells.

If we visualize the information in the posToIJ array, it looks like this:

![](https://img.halfrost.com/Blog/ArticleImage/56_47.png)


Similarly, if we visualize the information in the ijToPos array, it looks like this:


![](https://img.halfrost.com/Blog/ArticleImage/56_48.png)


The posToOrientation array contains four numbers: 1, 0, 0, and 3.
lookupIJ and lookupPos are two arrays with a capacity of 1024. They correspond respectively to the lookup table for converting a Hilbert curve ID to IJ coordinates, and the lookup table for converting IJ coordinates to a Hilbert curve ID.
```go


func init() {
	initLookupCell(0, 0, 0, 0, 0, 0)
	initLookupCell(0, 0, 0, swapMask, 0, swapMask)
	initLookupCell(0, 0, 0, invertMask, 0, invertMask)
	initLookupCell(0, 0, 0, swapMask|invertMask, 0, swapMask|invertMask)
}

```
This is the recursive function for initialization. In the standard order of the Hilbert curve, you can see that there are 4 cells, and each cell has its own order, so initialization needs to traverse all orders. The fourth input parameter ranges from 0 to 3.
```go

// initLookupCell initializes the lookupIJ table at init time.
func initLookupCell(level, i, j, origOrientation, pos, orientation int) {

	if level == lookupBits {
		ij := (i << lookupBits) + j
		lookupPos[(ij<<2)+origOrientation] = (pos << 2) + orientation
		lookupIJ[(pos<<2)+origOrientation] = (ij << 2) + orientation
	
		return
	}

	level++
	i <<= 1
	j <<= 1
	pos <<= 2
	
	r := posToIJ[orientation]
	
	initLookupCell(level, i+(r[0]>>1), j+(r[0]&1), origOrientation, pos, orientation^posToOrientation[0])
	initLookupCell(level, i+(r[1]>>1), j+(r[1]&1), origOrientation, pos+1, orientation^posToOrientation[1])
	initLookupCell(level, i+(r[2]>>1), j+(r[2]&1), origOrientation, pos+2, orientation^posToOrientation[2])
	initLookupCell(level, i+(r[3]>>1), j+(r[3]&1), origOrientation, pos+3, orientation^posToOrientation[3])
}

```
The function above generates a Hilbert curve. We can see an operation on ` pos << 2 `; this maps the position into the first four small cells, so the position is multiplied by 4.

Because the initial setting is `lookupBits = 4`, the ranges of i and j are [0,15], for a total of 16\*16=256 combinations. The i and j coordinates represent 4 cells, which are then further subdivided. When `lookupBits = 4`, the number of points that can be represented is 256\*4=1024. This is exactly the total capacity of lookupIJ and lookupPos.


Here is a local diagram where i and j range from 0 to 7.

![](https://img.halfrost.com/Blog/ArticleImage/56_49__.png)


The diagram above is a 4th-order Hilbert curve. The actual initialization process initializes the mapping table between the coordinates of the 1024 points on the 4th-order Hilbert curve and the x and y axes of the coordinate system.

For example, the table below shows the intermediate values generated during the recursion for i and j. The table below shows the computation process for the
 lookupPos table.

![](https://img.halfrost.com/Blog/ArticleImage/56_49_0_.png)


Let’s take one row and analyze the computation process in detail.

Assume the current (i,j)=(0,2). The computation of ij shifts i left by 4 bits and then adds j, and then shifts the overall result left by 2 bits. The purpose is to leave 2 bits for the orientation position. The first 4 bits of ij are i, the next 4 bits are j, and the last 2 bits are the orientation. The resulting value of ij is 8.

Next, compute the value of lookupPos[i j]. From the diagram above, we can see that the four numbers in the cell represented by (0,2) are 16, 17, 18, and 19. At this step, the value of pos is 4 (pos specifically records which generated cell we are at; in total, pos cycles from 0 to 255). pos represents the index of the current cell (made up of 4 small cells). The current cell is the 4th one, and each cell contains 4 small cells. So 4\*4 offsets us to the first number in the current cell, which is 16. The posToIJ array records the shape of the current cell. From it, we extract the orientation.

Looking at the diagram above, 16, 17, 18, and 19 correspond to the axis-rotated case in the posToIJ array, so 17 is located in the cell represented by the number 1 in the axis-rotation diagram. At this point, orientation = 1.

Thus the number represented by lookupPos[i j] is computed as 4\*4+1=17. This completes the mapping between i, j and the number on the Hilbert curve.

So how do we map a number on the Hilbert curve back to actual coordinates?

The lookupIJ array records the reverse information. The information stored in the lookupIJ array and the lookupPos array is exactly inverse. The value stored at an index in the lookupIJ array is the index in the lookupPos array. If we look up the lookupIJ array, the value of lookupIJ[17] is 8, which corresponds to the computed (i,j)=(0,2). At this point, i and j are still large-cell coordinates. We still need to use the shape information described in the posToIJ array. The current shape is axis-rotated, and we already know orientation = 1. Since each coordinate contains 4 small cells, one i, j represents 2 small cells, so we need to multiply by 2 and then add the orientation from the shape information. This gives the actual coordinate (0 \* 2 + 1 , 2 \* 2 + 0) = ( 1，4) .

At this point, the entire coordinate mapping for spherical coordinates is complete.

A point S(lat,lng) on the sphere -> f(x,y,z) -> g(face,u,v) -> h(face,s,t)  -> H(face,i,j) -> CellID. There are currently 6 conversion steps in total: convert spherical latitude/longitude coordinates to spherical xyz coordinates, then convert them to coordinates on the circumscribed cube’s projection face, then transform them into corrected coordinates, then transform the coordinate system and map them to the [0,2^30^-1] interval, and finally map all points in the coordinate system onto the Hilbert curve.

### 6. S2 Cell ID Data Structure


Finally, we need to discuss the S2 Cell ID data structure, which is directly related to the precision corresponding to different Levels.

![](https://img.halfrost.com/Blog/ArticleImage/56_50_.png)


In the diagram above, the left side corresponds to Level 30, and the right side corresponds to Level 24. (The exponent of 2 corresponds to the Level value.)

In S2, each CellID consists of 64 bits and can be stored in a uint64. The first 3 bits indicate one of the 6 faces of the cube, with a value range of [0,5]. Three bits can represent 0-7, but 6 and 7 are invalid values.

The last bit of the 64 bits is 1; this bit is deliberately reserved. It is used to quickly determine how many bits are in the middle. Starting from the last bit at the end and searching forward, find the first position that is not 0, i.e., the first 1. From the bit immediately before that one up to the 4th bit from the beginning (because the first 3 bits are occupied) are the usable digits.

The number of green cells determines how many grid cells can be represented. In the left diagram above, there are 60 green cells, so it can represent [0,2^30^ -1] * [0,2^30^ -1] cells. In the right diagram above, there are only 48 green cells, so it can represent only [0,2^24^ -1]*[0,2^24^ -1] cells.

So how large is the grid area represented by different levels?

From the previous chapter, we know that due to projection, the projected areas still differ in size.

The formula derived here is fairly complex, so I will not prove it. See the documentation for details.
```c

MinAreaMetric = Metric{2, 8 * math.Sqrt2 / 9} 
AvgAreaMetric = Metric{2, 4 * math.Pi / 6} 
MaxAreaMetric = Metric{2, 2.635799256963161491}

```
This is the multiplicative relationship between the maximum/minimum areas and the average area.

(The units in the figure below are km^2^, square kilometers.)

![](https://img.halfrost.com/Blog/ArticleImage/56_51.png)

![](https://img.halfrost.com/Blog/ArticleImage/56_51_0.png)

Level 0 is one of the six faces of the cube. The Earth’s surface area is approximately 510,100,000 km^2^. The area of level 0 is one-sixth of the Earth’s surface area. The smallest area representable at level 30 is 0.48 cm^2^, and the largest is only 0.93 cm^2^.

### 7. Comparing S2 and Geohash

Geohash has 12 levels, ranging from 5000 km down to 3.7 cm. The change between adjacent levels can be quite large. Sometimes choosing the next coarser level is much too large, while choosing the next finer level is a bit too small. For example, if you choose a string length of 4, the corresponding cell width is 39.1 km. If the requirement is 50 km, then choosing a string length of 5 makes the corresponding cell width 156 km—suddenly more than 3 times larger. In such cases, it is difficult to decide what length of Geohash string to use. If the choice is poor, each check may also require fetching the eight neighboring cells and checking them again. Geohash requires 12 bytes of storage.

S2 has 30 levels, ranging from 0.7 cm² to 85,000,000 km². The change between adjacent levels is much smoother, close to a quartic curve. Therefore, choosing the precision does not suffer from the same difficulty as with Geohash. S2 storage only requires a single `uint64`.

The S2 library provides not only geocoding, but also many other geometry-related libraries. Geocoding is only a small part of it. There are many, many S2 implementations that this article has not covered: various vector computations, area calculations, polygon covering, distance problems, and problems on the sphere and spherical surfaces—it implements all of them.

S2 can also solve polygon covering problems. For example, given a city, compute a polygon that just covers the city.

![](https://img.halfrost.com/Blog/ArticleImage/56_52.png)

As shown above, the generated polygon just covers the blue area underneath. The generated polygons here can be large or small. In any case, the final result just covers the target object.

![](https://img.halfrost.com/Blog/ArticleImage/56_53.png)

The same goal can also be achieved with identical Cells. The figure above covers the entire city of São Paulo using Cells of the same Level.

These are things Geohash cannot do.

Polygon covering uses an approximate algorithm. Although it is not strictly an optimal solution, it works particularly well in practice.

One additional point worth mentioning is that Google’s documentation emphasizes that although this polygon-covering algorithm is very useful for search and preprocessing operations, it is “not dependable.” The reason is also that it is an approximate algorithm rather than a unique optimal algorithm, so the solution obtained may change depending on the library version.

### 8. S2 Cell Examples

First, let’s look at conversions between latitude/longitude and CellID, as well as rectangular area calculation.
```go

	latlng := s2.LatLngFromDegrees(31.232135, 121.41321700000003)
	cellID := s2.CellIDFromLatLng(latlng)
	cell := s2.CellFromCellID(cellID) //9279882742634381312

	// cell.Level()
	fmt.Println("latlng = ", latlng)
	fmt.Println("cell level = ", cellID.Level())
	fmt.Printf("cell = %d\n", cellID)
	smallCell := s2.CellFromCellID(cellID.Parent(10))
	fmt.Printf("smallCell level = %d\n", smallCell.Level())
	fmt.Printf("smallCell id = %b\n", smallCell.ID())
	fmt.Printf("smallCell ApproxArea = %v\n", smallCell.ApproxArea())
	fmt.Printf("smallCell AverageArea = %v\n", smallCell.AverageArea())
	fmt.Printf("smallCell ExactArea = %v\n", smallCell.ExactArea())


```
Here, the `Parent` method parameter can directly specify the `CellID` at the corresponding level for that point.

The output printed by the methods above is as follows:
```go

latlng =  [31.2321350, 121.4132170]
cell level =  30
cell = 3869277663051577529

****Parent **** 10000000000000000000000000000000000000000
smallCell level = 10
smallCell id = 11010110110010011011110000000000000000000000000000000000000000
smallCell ApproxArea = 1.9611002454714756e-06
smallCell AverageArea = 1.997370817559429e-06
smallCell ExactArea = 1.9611009480261058e-06


```
Here’s another example involving polygon coverage. First, let’s create an arbitrary region.
```go

	rect = s2.RectFromLatLng(s2.LatLngFromDegrees(48.99, 1.852))
	rect = rect.AddPoint(s2.LatLngFromDegrees(48.68, 2.75))

	rc := &s2.RegionCoverer{MaxLevel: 20, MaxCells: 10, MinLevel: 2}
	r := s2.Region(rect.CapBound())
	covering := rc.Covering(r)


```
Set the coverage parameters to level 2 - 20, with a maximum of 10 Cells.

![](https://img.halfrost.com/Blog/ArticleImage/56_54.png)


Next, we change the maximum number of Cells to 20.

![](https://img.halfrost.com/Blog/ArticleImage/56_55.png)


Finally, change it to 30.


![](https://img.halfrost.com/Blog/ArticleImage/56_56.png)


As you can see, for the same level range, the more Cells there are, the more accurately the target range is covered.

This is matching a rectangular region; matching a circular region works the same way.

![](https://img.halfrost.com/Blog/ArticleImage/56_57.png)


![](https://img.halfrost.com/Blog/ArticleImage/56_58.png)


I won’t include the code here; it is similar to the rectangular case. Geohash cannot provide this kind of capability, so you need to implement it manually.

Finally, here is an example of polygon matching.
```go


func testLoop() {

	ll1 := s2.LatLngFromDegrees(31.803269, 113.421145)
	ll2 := s2.LatLngFromDegrees(31.461846, 113.695803)
	ll3 := s2.LatLngFromDegrees(31.250756, 113.756228)
	ll4 := s2.LatLngFromDegrees(30.902604, 113.997927)
	ll5 := s2.LatLngFromDegrees(30.817726, 114.464846)
	ll6 := s2.LatLngFromDegrees(30.850743, 114.76697)
	ll7 := s2.LatLngFromDegrees(30.713884, 114.997683)
	ll8 := s2.LatLngFromDegrees(30.430111, 115.42615)
	ll9 := s2.LatLngFromDegrees(30.088491, 115.640384)
	ll10 := s2.LatLngFromDegrees(29.907713, 115.656863)
	ll11 := s2.LatLngFromDegrees(29.783833, 115.135012)
	ll12 := s2.LatLngFromDegrees(29.712295, 114.728518)
	ll13 := s2.LatLngFromDegrees(29.55473, 114.24512)
	ll14 := s2.LatLngFromDegrees(29.530835, 113.717776)
	ll15 := s2.LatLngFromDegrees(29.55473, 113.3772)
	ll16 := s2.LatLngFromDegrees(29.678892, 112.998172)
	ll17 := s2.LatLngFromDegrees(29.941039, 112.349978)
	ll18 := s2.LatLngFromDegrees(30.040949, 112.025882)
	ll19 := s2.LatLngFromDegrees(31.803269, 113.421145)

	point1 := s2.PointFromLatLng(ll1)
	point2 := s2.PointFromLatLng(ll2)
	point3 := s2.PointFromLatLng(ll3)
	point4 := s2.PointFromLatLng(ll4)
	point5 := s2.PointFromLatLng(ll5)
	point6 := s2.PointFromLatLng(ll6)
	point7 := s2.PointFromLatLng(ll7)
	point8 := s2.PointFromLatLng(ll8)
	point9 := s2.PointFromLatLng(ll9)
	point10 := s2.PointFromLatLng(ll10)
	point11 := s2.PointFromLatLng(ll11)
	point12 := s2.PointFromLatLng(ll12)
	point13 := s2.PointFromLatLng(ll13)
	point14 := s2.PointFromLatLng(ll14)
	point15 := s2.PointFromLatLng(ll15)
	point16 := s2.PointFromLatLng(ll16)
	point17 := s2.PointFromLatLng(ll17)
	point18 := s2.PointFromLatLng(ll18)
	point19 := s2.PointFromLatLng(ll19)

	points := []s2.Point{}
	points = append(points, point19)
	points = append(points, point18)
	points = append(points, point17)
	points = append(points, point16)
	points = append(points, point15)
	points = append(points, point14)
	points = append(points, point13)
	points = append(points, point12)
	points = append(points, point11)
	points = append(points, point10)
	points = append(points, point9)
	points = append(points, point8)
	points = append(points, point7)
	points = append(points, point6)
	points = append(points, point5)
	points = append(points, point4)
	points = append(points, point3)
	points = append(points, point2)
	points = append(points, point1)

	loop := s2.LoopFromPoints(points)

	fmt.Println("----  loop search (gets too much) -----")
	// fmt.Printf("Some loop status items: empty:%t   full:%t \n", loop.IsEmpty(), loop.IsFull())

	// ref: https://github.com/golang/geo/issues/14#issuecomment-257064823
	defaultCoverer := &s2.RegionCoverer{MaxLevel: 20, MaxCells: 1000, MinLevel: 1}
	// rg := s2.Region(loop.CapBound())
	// cvr := defaultCoverer.Covering(rg)
	cvr := defaultCoverer.Covering(loop)

	// fmt.Println(poly.CapBound())
	for _, c3 := range cvr {
		fmt.Printf("%d,\n", c3)
	}
}


```
This uses the Loop class. The smallest unit for initializing this class is a Point, and a Point is generated from latitude and longitude. **The most important thing to note is that a polygon is determined by the counterclockwise direction and the region on the left-hand side.**

If the points are accidentally arranged clockwise, then the polygon being defined is the larger outer surface. This means that everything on the sphere except the polygon you drew is the polygon you actually selected.


For a concrete example, suppose the polygon we want to draw looks like this:


![](https://img.halfrost.com/Blog/ArticleImage/56_63.png)


If we store the Points in clockwise order and use this clockwise array to initialize a Loop, then a “strange” phenomenon occurs, as shown below:


![](https://img.halfrost.com/Blog/ArticleImage/56_62.png)


The vertex in the upper-left corner and the vertex in the lower-right corner of this image coincide on the Earth. If this map were restored back onto the sphere, it would be equivalent to hollowing out a polygon from the middle of the entire sphere.

Zooming in on the image above gives the following:


![](https://img.halfrost.com/Blog/ArticleImage/56_61.png)


Now it is very clear that a polygon has been hollowed out in the middle. The reason for this phenomenon is that each point was stored in clockwise order, so when initializing a Loop, the larger polygon outside the intended polygon is selected.

When using Loop, always keep this in mind: **clockwise represents the outer polygon, while counterclockwise represents the inner polygon.**

The polygon covering issue is the same as in the earlier examples:

With the same MaxLevel = 20 and MinLevel = 1, different MaxCells values produce different covering precision. The following image shows the case where MaxCells = 100:

![](https://img.halfrost.com/Blog/ArticleImage/56_64.png)


The following image shows the case where MaxCells = 1000:

![](https://img.halfrost.com/Blog/ArticleImage/56_65.png)


This example also shows that, for the same Level range, the larger MaxCells is, the higher the covering precision.


### 9. Applications of S2


![](https://img.halfrost.com/Blog/ArticleImage/56_59.png)

S2 is mainly useful in the following 8 areas:

1. Representing angles, intervals, latitude/longitude points, unit vectors, and so on, as well as performing various operations on these types.  
2. Geometric shapes on the unit sphere, such as spherical caps (“disks”), latitude-longitude rectangles, polylines, and polygons.  
3. Powerful construction operations, such as union, and Boolean predicates, such as containment, for arbitrary collections of points, polylines, and polygons.  
4. Fast in-memory indexing of collections of points, polylines, and polygons.  
5. Algorithms for measuring distances and finding nearby objects.  
6. Robust algorithms for snapping and simplifying geometry, with guarantees on precision and topology.  
7. A collection of efficient and exact mathematical predicates for testing relationships between geometric objects.  
8. Support for spatial indexing, including approximating regions as discrete collections of “S2 cells”. This makes it easy to build large-scale distributed spatial indexes.  

The last point, spatial indexing, is undoubtedly used very widely in industrial production.


S2 is currently used quite extensively, especially in map-related businesses. Google Maps uses S2 heavily; readers can experience for themselves how fast it is. Uber also uses the S2 algorithm to search for the nearest taxi. The scenario is the one mentioned in the introduction of this article. Didi should also have related applications, and perhaps even better solutions. The currently popular shared-bike services also use these spatial indexing algorithms.

Finally, the food delivery industry is also closely tied to maps. Meituan and Ele.me are likely to have many applications in this area as well. As for exactly where they are used, I will leave that to the reader’s imagination.

Of course, S2 also has scenarios where it is not suitable:

1. Planar geometry problems, for which there are many mature existing planar geometry libraries to choose from. 
2. Converting to/from common GIS formats. To read such formats, use external libraries such as [OGR](http://gdal.org/1.11/ogr/). 


## V. Conclusion

![](https://img.halfrost.com/Blog/ArticleImage/56_60.jpg)


This article focused on the basic implementation of Google’s S2 algorithm. Although Geohash is also a spatial point indexing algorithm, its performance is slightly inferior to Google’s S2. In addition, databases at major companies have largely started adopting Google’s S2 algorithm for indexing.

There is actually another large class of problems in spatial search: how do we search multidimensional spatial lines, multidimensional spatial surfaces, and multidimensional spatial polygons? They are all composed of countless spatial points. Real-world examples include streets, high-rise buildings, railways, and rivers. To search these objects, how should the database tables be designed? How can efficient search be achieved? Can a B+ tree still be used?

The answer is, of course, that efficient search can also be implemented, but that requires an R-tree, or an R-tree together with a B+ tree.

That part is beyond the scope of this article. When I have time, I may share another article on “Multidimensional Spatial Polygon Indexing Algorithms”.

Finally, feedback and suggestions are very welcome.

------------------------------------------------------

References:  
[Z-order curve](https://en.wikipedia.org/wiki/Z-order_curve)  
[Geohash wikipedia](https://en.wikipedia.org/wiki/Geohash)  
[Geohash-36](https://en.wikipedia.org/wiki/Geohash-36)  
[Geohash Online Demo](http://geohash.gofreerange.com/)  
[Geohash Query](http://www.movable-type.co.uk/scripts/geohash.html)  
[Geohash Converter](http://geohash.co/)   
[Space-filling curve](https://en.wikipedia.org/wiki/Space-filling_curve)  
[List of fractals by Hausdorff dimension](https://en.wikipedia.org/wiki/List_of_fractals_by_Hausdorff_dimension)  
[YouTube video introducing Hilbert curves](https://www.youtube.com/watch?v=3s7h2MHQtxc)  
[Hilbert curve online demo](http://bit-player.org/extras/hilbert/hilbert-mapping.html)  
[Hilbert curve paper](http://www4.ncsu.edu/~njrose/pdfFiles/HilbertCurve.pdf)  
[Mapping the Hilbert curve](http://bit-player.org/2013/mapping-the-hilbert-curve)  
[Official Google S2 PPT](https://docs.google.com/presentation/d/1Hl4KapfAENAOf4gv-pSngKwvS_jwNVHRPZTTDzXXn6Q/view#slide=id.i22)  
[Go S2 source code github.com/golang/geo](https://github.com/golang/geo)  
[Java S2 source code github.com/google/s2-geometry-library-java](https://github.com/google/s2-geometry-library-java)  
[L’Huilier’s Theorem](http://numerical.recipes/whp/HuiliersTheorem.pdf) 


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_spatial_search/](https://halfrost.com/go_spatial_search/)