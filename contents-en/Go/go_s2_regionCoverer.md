# How Does Google S2 Solve the Optimal Spatial Covering Problem?


![](http://upload-images.jianshu.io/upload_images/1194012-94c4e3b05a487f59.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## Preface

Barring anything unexpected, this will be the final article in the entire Google S2 series. In this article, I will explain the regionCoverer algorithm in full. As for the many other small algorithms in the Google S2 library, their code is also very much worth reading and learning from, but I will not go through them one by one here. Interested readers can read through the entire library.

While writing this article, I noticed some new commits from the library’s author, such as commit f9610db2b871b54b17d36d4da6a4d6a2aab6018d from December 4, 2017. This commit modified the README. Although it only changed the documentation, there is actually a lot of content in it.
```go

 -For an analogous library in C++, see
 -https://code.google.com/archive/p/s2-geometry-library/, and in Java, see
 -https://github.com/google/s2-geometry-library-java
------------------------------------------------------------------------------------
 +For an analogous library in C++, see https://github.com/google/s2geometry, in
 +Java, see https://github.com/google/s2-geometry-library-java, and Python, see
 +https://github.com/google/s2geometry/tree/master/src/python

```
You can see that they’ve moved the code that used to live in Google’s official private code repository to GitHub. Previously, the C++ code could only be viewed in the code archive; now it can be viewed directly on GitHub. Much more convenient.
```go

+More details about S2 in general are available on the S2 Geometry Website
 +[s2geometry.io](https://s2geometry.io/).

```
This commit also mentioned a new website, which I found was only recently released. I have been following every S2 commit continuously for almost half a year. I keep an eye on every S2-related resource online, and this website is very new. I will mention this website at the end of the article, so I will not go into detail here.

Starting from this commit, I believe Google S2 may be receiving more attention, and it may even be preparing for a major push.

Alright, let’s get to the main topic.


## 1. Spatial Types

In Google S2, the following types can be used for RegionCovering. Basically, they all must satisfy the Region interface.

### 1. Cap

Cap represents a disk-shaped region defined by a center and a radius. Technically, this shape is called a “spherical cap” rather than a disk, because it is not planar. A cap represents a portion of a sphere cut off by a plane. The boundary of a cap is the circle defined by the intersection of the sphere and the plane. A cap is a closed set, meaning it includes its boundary. In most cases, wherever a disk would be used in planar geometry, a spherical cap can be used instead. The radius of a cap is measured along the surface of the sphere, rather than as a straight-line distance through the interior. Therefore, a cap with radius π/2 is a hemisphere, and a cap with radius π covers the entire sphere. The center is a point on the unit sphere. (Therefore, it must have unit length.) A cap can also be defined by its center point and height. The height is the distance from the center point to the cutting plane. “Empty” and “full” caps are also supported, containing no points and all points respectively. Below are some useful relationships among the cap height (h), cap radius (r), maximum chord length from the cap center (d), and base radius of the cap (a).
```
h = 1 - cos(r)
	= 2 * sin^2(r/2)
d^2 = 2 * h
	= a^2 + h^2

```

### 2. Loop

A Loop represents a simple spherical polygon. It consists of a sequence of vertices, where the first vertex is implicitly considered connected to the last vertex. All loops are defined to have a CCW orientation; that is, the interior of the loop is on the left side of its edges. This means that a clockwise loop enclosing a small region is interpreted as a CCW loop enclosing a very large region. A loop is not allowed to have any duplicate vertices, whether adjacent or not. Adjacent edges are not allowed to intersect, and edges of length 180 degrees are not allowed; that is, adjacent vertices cannot be antipodal. A loop must have at least 3 vertices, except for the “empty” and “full” loops discussed below. There are two special loops: EmptyLoop contains no points, and FullLoop contains all points. These loops have no edges, but in order to preserve the invariant that every loop can be represented as a vertex chain, they are defined as having exactly one vertex each.


### 3. Polygon
A polygon represents a sequence of zero or more loops; similarly, the left-hand side of a loop’s direction is defined as its interior. When a polygon is initialized, the given loops are automatically converted into a canonical form consisting of holes. The loops are reordered to match a predefined traversal order of the nesting hierarchy. A polygon can represent any region of the sphere with a polygonal boundary, including the entire sphere, which is called a “full” polygon. A full polygon consists of one full loop, while an empty polygon has no loops at all. Use FullPolygon() to construct a full polygon. The zero value of Polygon is treated as an empty polygon.

For multiple loops to form a Polygon, the following four conditions must be satisfied:

1. Loops must not cross; that is, the boundary of a loop may not intersect both the interior and exterior of any other loop.   
2. Loops must not share edges; that is, if a loop contains edge AB, no other loop may contain AB or BA.   
3. Loops may share vertices, but no vertex may appear twice within a single loop (see S2Loop).   
4. There must be no empty loops. A full loop may appear only in a complete full polygon.  


### 4. Rect
Rect represents a closed latitude-longitude rectangle. It is also a Region type. It can represent empty and full rectangles as well as a single point. It has an AddPoint method, which makes it convenient to construct a bounding rectangle for a set of points, including point sets that span the 180-degree meridian.

### 5. Region
A region represents a two-dimensional region on the unit sphere. The purpose of this interface is to allow complex regions to be approximated by simpler regions. The interface is limited to methods that compute approximations.

An S2 region represents a two-dimensional region on the unit sphere. It is an abstract interface with various concrete subtypes, such as disks, rectangles, polylines, polygons, geometry collections, buffered shapes, and so on. The main purpose of this interface is to allow complex regions to be approximated by simpler regions. Therefore, the interface can only be used for methods that compute approximations, rather than for a wide variety of virtual methods implemented by all subtypes.


### 6. Shape

Shape can be regarded as the “base class” for all graphics or shapes. It represents polygonal geometry in the most flexible way. It is composed of a collection of edges and may optionally define an interior. All geometries represented by a given Shape must have the same dimension, which means a Shape can represent a set of points, a set of polylines, or a set of polygons. Shape is defined as an interface so that clients can more conveniently control the underlying data representation. Sometimes a Shape does not own its own data, but instead wraps data of other types. Shape operations are typically defined on ShapeIndex rather than on individual shapes. ShapeIndex is simply a collection of Shapes, possibly with different dimensions (for example, 10 points and 3 polygons), organized into a data structure for efficient access. The edges of a Shape are indexed by a contiguous range of edge IDs starting from 0. Edges are further subdivided into chains, where each chain consists of a sequence of edges connected end to end (a polyline). For example, a shape representing two polylines AB and CDE would have three edges (AB, CD, DE) split into two chains (AB) and (CD, DE). Similarly, a shape representing 5 points would have 5 chains, each consisting of one edge. Shape has methods that allow edges to be accessed either by global numbering (edge ID) or within a specific chain. Global numbering is sufficient for most cases, but the chain representation is very useful for certain algorithms, such as intersection (see BooleanOperation).

S2 defines a total of two extensible interfaces for representing geometry: S2Shape and S2Region.

The difference between the two is: 
The purpose of S2Shape is to flexibly represent polygonal geometry. (This includes not only polygons, but also points and polylines.) Most core S2 operations work with any class that implements the S2Shape interface. 

The purpose of S2Region is to compute approximations of geometry. For example, there are methods for computing bounding rectangles and caps, and S2RegionCoverer can be used to approximate a region as a collection of cells to any desired precision. Unlike S2Shape, S2Region can represent non-polygonal geometries, such as spherical caps (S2Cap).


In addition to the common types described above, the following intermediate or lower-level types are also available for developers to use.


- S2LatLngRect - A rectangle in the latitude-longitude coordinate system.
- S2Polyline - A polyline.
- S2CellUnion - A region approximated as a set of S2CellIds. This is the type produced after conversion by RegionCoverer.
- S2ShapeIndexRegion - An arbitrary collection of points, polylines, and polygons.
- S2ShapeIndexBufferedRegion - Defined the same way as S2ShapeIndexRegion, except expanded by a given radius.
- S2RegionUnion - A collection of arbitrary regions.
- S2RegionIntersection - The intersection of arbitrary other regions.


Finally, as an additional note, the S2RegionTermIndexer type supports indexing and querying any type of S2Region, which means all the types mentioned above. You can use S2RegionTermIndexer to index a set of polylines and then query which polylines intersect a given polygon.


## 2. RegionCoverer Example

RegionCoverer is mainly intended to find an approximately optimal solution that covers the current region (why not the optimal solution?).

There are mainly three conversion parameters: MaxLevel, MaxCells, and MinLevel. MaxCells determines the maximum number of cells, but getting too close to the maximum value can cause the covered area to be too large and imprecise. Therefore, the maximum count is only a constraint on the number of cells that must not be exceeded while satisfying the maximum precision requirement. Because of this, the result is not necessarily the optimal solution satisfying MaxCells.

Here are a few examples:

The following is a cap with a radius of 10 kilometers, located at the corner where 3 faces meet. Suppose we need at most 10 cells to cover it. The result is as follows:

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-06147cab0700189c.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


With the same settings, we change the count to 20, as follows:

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-9986012502eab78b.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>

Still using the same configuration, we change the count to 50:

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-0bd56144b9a22a11.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>

So far, the precision is only passable. The edge portions still cover more than the original cap. Let’s continue improving the precision by adjusting the count to 200.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-74a80a89d27c0f09.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


200 cells looks relatively precise. Let’s increase it again to 1000 and see what happens.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-39a5bd16c9e688cf.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


Although the code configuration sets the count to 1000, there are actually only 706 cells. The reason is that although the code computes based on 1000 cells, the actual algorithm also merges cells after pruning. Therefore, the final count is less than 1000.

Here is another example. The rectangle below represents a latitude/longitude rectangle extending from 60 degrees north to 80 degrees north, and from -170 degrees longitude to +170 degrees longitude. The covering is limited to 8 cells. Note that the hole in the middle is completely covered. This clearly does not match our intent.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-b400bf236651eeaa.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


We increase the number of cells to 20. The hole in the middle is still filled in.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-c0f6fe597231fee0.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


We adjust the parameter to 100, with all other configurations exactly the same. Now the hole in the middle has begun to take shape. However, the empty area near the date line still has not appeared.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-9a99f328cffd1bd7.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>

Finally, we adjust the parameter to 500. Now the hole in the middle is displayed relatively completely.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-5ae24704889d70f0.gif?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


Here are a few more examples from our actual project. The following is the boundary of a grid in Shanghai. We first use
```go

defaultCoverer := &s2.RegionCoverer{MaxLevel: 16, MaxCells: 100, MinLevel: 13}

```
Perform the conversion, and the result is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-97b0cb74e9505b83.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```go

defaultCoverer := &s2.RegionCoverer{MaxLevel: 30, MaxCells: 1000, MinLevel: 1}

```
When the precision is increased to 1000, the result is as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-39da9d80faadb81f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


There are also cases with larger regions, such as a province—Hubei Province:


![](http://upload-images.jianshu.io/upload_images/1194012-68b697c17ab0ea94.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Or a lake—Taihu Lake:

![](http://upload-images.jianshu.io/upload_images/1194012-f29b4ed9cb846ca6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Finally, let’s look at another polygon example. We know that a polygon consists of multiple loops:
```go

	loops := []*s2.Loop{}
	loops = append(loops, loop1)
	loops = append(loops, loop2)

	polygon := s2.PolygonFromLoops(loops)

	defaultCoverer := &s2.RegionCoverer{MaxLevel: 16, MaxCells: 100, MinLevel: 8}
	fmt.Println("----  polygon-----")

	cvr = defaultCoverer.Covering(polygon)

	for i := 0; i < len(cvr); i++ {
		fmt.Printf("%d,\n", cvr[i])
	}
	fmt.Printf("------------\n")


```
Below is what the two loops look like on the map.

![](http://upload-images.jianshu.io/upload_images/1194012-09a758bab8beb8b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-7591f2062cb4af4f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Finally, the polygon, which contains the two loops above.

![](http://upload-images.jianshu.io/upload_images/1194012-4c8c2fa4ec88dd9e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## III. Implementation of RegionCoverer's Core Covering Algorithm


This section analyzes in detail how Covering is implemented.

The most common usage is just the following lines:
```go

	rc := &s2.RegionCoverer{MaxLevel: 30, MaxCells: 5}
	r := s2.Region(CapFromCenterArea(center, area))
	covering := rc.Covering(r)


```
The example above shows that after the max conversion, the `CellUnion` contains 5 `CellID`s. The area covered by the three rows above is a Cap.
```go

type RegionCoverer struct {
	MinLevel int // the minimum cell level to be used.
	MaxLevel int // the maximum cell level to be used.
	LevelMod int // the LevelMod to be used.
	MaxCells int // the maximum desired number of cells in the approximation.
}


```
RegionCoverer is a struct; in practice, it contains four fields: MinLevel, MaxLevel, MaxCells, and LevelMod. The first three should not need much explanation; they are used frequently. The key point to explain is LevelMod.

Once LevelMod is set, during the RegionCover conversion, the selected Cell Level can only satisfy `(level - MinLevel) % LevelMod = 0`; that is, `(level - MinLevel)` must be a multiple of LevelMod. Only Cell Levels that meet this condition will be selected. This effectively allows the branching factor of the S2 CellID hierarchy to increase. The currently supported values are only 0, 1, 2, and 3, corresponding to branching factors of 0, 4, 16, and 64.

Now let’s discuss the core idea of the algorithm.

RegionCover can be abstracted as the following problem: given a region, cover it with Cells as accurately as possible, but do not exceed MaxCells in total. How do we find those Cells?

This is essentially a locally optimal approximation problem. If we want maximum accuracy, the obvious approach is to cover all boundary areas with MaxLevel Cells—the larger the Level, the smaller the cell—which gives the most precise result. However, this causes the number of Cells to grow dramatically, far exceeding MaxCells, so it no longer satisfies the requirement. So how can we still cover the given region as accurately as possible while keeping the number of Cells <= MaxCells?

A few points need to be clarified first:

- 1. MinLevel has higher priority than MaxCells (note that this is not MaxLevel). In other words, Cells below the given Level will never be used, even if using one such Cell could replace many smaller-area Cells with larger Levels.
- 2. Regarding the minimum valid range for MaxCells: in cases where the required output is the minimum number of necessary cells—for example, if the region intersects all six face cells—the result may contain up to 6 cells. If the region happens to lie at the intersection of three cube faces, then even a very small convex region may return up to 3 cells.
- 3. If MinLevel is already too large for the approximate region, then MaxCells loses its constraining effect, and any number of cells may be returned.
- 4. If MaxCells is less than 4, then even if the region is convex, such as a cap or rect, the final covered area will be larger than the original region. Developers should be aware of this case.

Alright, next let’s start from the source code. The core function for RegionCoverer conversion is this one.
```go

func (rc *RegionCoverer) Covering(region Region) CellUnion {
	covering := rc.CellUnion(region)
	covering.Denormalize(maxInt(0, minInt(maxLevel, rc.MinLevel)), maxInt(1, minInt(3, rc.LevelMod)))
	return covering
}

```
From this function implementation, we can see that the conversion is effectively divided into two steps: Normalize Cell + conversion, and Denormalize Cell.

### (1). CellUnion

The concrete implementation of the CellUnion method:
```go

func (rc *RegionCoverer) CellUnion(region Region) CellUnion {
	c := rc.newCoverer()
	c.coveringInternal(region)
	cu := c.result
	cu.Normalize()
	return cu
}


```
This method can mainly be broken down into three parts: creating `newCoverer`, `coveringInternal`, and `Normalize`.


#### 1. newCoverer()
```go

func (rc *RegionCoverer) newCoverer() *coverer {
	return &coverer{
		minLevel: maxInt(0, minInt(maxLevel, rc.MinLevel)),
		maxLevel: maxInt(0, minInt(maxLevel, rc.MaxLevel)),
		levelMod: maxInt(1, minInt(3, rc.LevelMod)),
		maxCells: rc.MaxCells,
	}
}


```
The `newCoverer()` method initializes a `coverer` struct. `maxLevel` is a previously defined constant: `maxLevel = 30`. All initialization parameters for `coverer` come from the parameters of `RegionCoverer`. We initialize a `RegionCoverer` externally, and its four main parameters—`MinLevel`, `MaxLevel`, `LevelMod`, and `MaxCells`—are all passed in here. The `maxInt` and `minInt` used in the initialization function above are mainly for handling invalid values.

In fact, the `coverer` struct contains eight fields.
```go

type coverer struct {
	minLevel         int // the minimum cell level to be used.
	maxLevel         int // the maximum cell level to be used.
	levelMod         int // the LevelMod to be used.
	maxCells         int // the maximum desired number of cells in the approximation.
	region           Region
	result           CellUnion
	pq               priorityQueue
	interiorCovering bool
}


```
Excluding the four items initialized above, it actually contains four other important items, which will be used below. `region` is the area to cover. `result` is the final converted result, which is an array of `CellUnion`. `pq` is the priority queue `priorityQueue`, and `interiorCovering` is a `bool` variable indicating whether the current conversion is an interior conversion.


#### 2. coveringInternal()

Next, let's look at the `coveringInternal` method.
```go

func (c *coverer) coveringInternal(region Region) {
	c.region = region

	c.initialCandidates()
	for c.pq.Len() > 0 && (!c.interiorCovering || len(c.result) < c.maxCells) {
		cand := heap.Pop(&c.pq).(*candidate)

		if c.interiorCovering || int(cand.cell.level) < c.minLevel || cand.numChildren == 1 || len(c.result)+c.pq.Len()+cand.numChildren <= c.maxCells {
			for _, child := range cand.children {
				if !c.interiorCovering || len(c.result) < c.maxCells {
					c.addCandidate(child)
				}
			}
		} else {
			cand.terminal = true
			c.addCandidate(cand)
		}
	}
	c.pq.Reset()
	c.region = nil
}


```
The coveringInternal method generates a covering strategy and stores the result in result. The general strategy for the covering transformation is:

**Start with the 6 faces of the cube. Discard any shapes that do not intersect the region. Then repeatedly select the largest cell that intersects the shape and subdivide it**.

Of the 8 fields in the coverer struct, the first 4 are initialized from external inputs, and the last 4 are used here. First,
```go

c.region = region

```
Initialize the coverer’s region. The other three elements—result, pq, and interiorCovering—are all used below.

result contains only the qualifying Cells that will become part of the final output, while the pq priority queue contains Cells that may still need further subdivision.

If a Cell is 100% fully contained in the covering region, it is added to the output immediately; a Cell that has no intersection with the region at all is discarded immediately. Therefore, the pq priority queue contains only Cells that partially intersect the region.

The dequeue strategy for the pq priority queue is:

**1. First, prioritize candidates by Cell size (starting with larger Cells)  
2. Then by the number of intersecting children (fewer children have higher priority and are dequeued first)  
3. Finally by the number of fully contained children (fewer children have higher priority and are dequeued first)**

After filtering through the pq priority queue, the Cells that ultimately remain must have the lowest priority: their Cell area is relatively small, and they have a larger portion intersecting the region and the greatest number of fully contained children. In other words, the Cells closest to the region boundary (the Cells whose covered area has the least excess beyond the region to be covered/converted) are the ones that ultimately remain.
```go

if c.interiorCovering || int(cand.cell.level) < c.minLevel || cand.numChildren == 1 || len(c.result)+c.pq.Len()+cand.numChildren <= c.maxCells {

}


```
The intent of this condition in the `coveringInternal` function implementation is:

For an interior covering, regardless of how many children a candidate has, we keep subdividing it further. If we reach `MaxCells` before expanding all of its children, we simply use some of them. For an exterior covering, we cannot do this, because the result must cover the entire region, so all children must be used.
```go

candidate.numChildren == 1

```
In the case described above, when we already have more than MaxCells results (because minLevel is too high), this situation is accounted for. In this case, having a child candidate continue to be subdivided has little impact on the final result.

#### 3. initialCandidates()

Next, let’s look at how candidates are initialized:
```go

func (c *coverer) initialCandidates() {
	// Optimization: start with a small (usually 4 cell) covering of the region's bounding cap.
	temp := &RegionCoverer{MaxLevel: c.maxLevel, LevelMod: 1, MaxCells: min(4, c.maxCells)}

	cells := temp.FastCovering(c.region)
	c.adjustCellLevels(&cells)
	for _, ci := range cells {
		c.addCandidate(c.newCandidate(CellFromCellID(ci)))
	}
}


```
This function includes a small optimization: it converts the initial covering of the region into four Cells that cover the Cap along the region’s boundary. The two important methods in the implementation of initialCandidates are FastCovering and adjustCellLevels.


#### 4. FastCovering()
```go

func (rc *RegionCoverer) FastCovering(region Region) CellUnion {
	c := rc.newCoverer()
	cu := CellUnion(region.CellUnionBound())
	c.normalizeCovering(&cu)
	return cu
}


```
The `FastCovering` function returns a `CellUnion`, whose cells cover the given region. What makes this method different is that it is very fast, and the result it produces is relatively coarse. Of course, the resulting `CellUnion` also satisfies the `MaxCells`, `MinLevel`, `MaxLevel`, and `LevelMod` constraints. However, the result does not try to make full use of a large `MaxCells` value. It usually returns only a small number of cells, so the result is fairly coarse.

Therefore, using the `FastCovering` function as the starting point for recursively subdividing cells is very effective.

In this method, `region.CellUnionBound()` is called. How this works depends on how each `region` implements this interface.

Taking `loop` as an example, its implementation of `CellUnionBound()` is as follows:
```go

func (l *Loop) CellUnionBound() []CellID {
	return l.CapBound().CellUnionBound()
}


```
The above method is the concrete implementation for quickly computing boundary conversions. It is also the core part of implementing spatial coverage.

CellUnionBound returns an array of CellIDs that cover the region. The Cells are not sorted, may contain redundancy (for example, a Cell that contains other Cells), and may cover more area than necessary.

For this reason as well, this method is not suitable for direct use by client code. Clients should generally use the Region.Covering method, which can be used to control the size and accuracy of the covering. In addition, if you want a fast covering and do not care about accuracy, consider calling FastCovering (it returns a cleaned-up version of the covering computed by this method).

The CellUnionBound implementation should try to return a small covering of the region (ideally 4 cells or fewer) and be fast to compute. Therefore, the CellUnionBound method is used by RegionCoverer as a starting point for further refinement.
```go

func (l *Loop) CapBound() Cap {
	return l.bound.CapBound()
}

```
CapBound returns an upper bound on the boundary, which may include more padding than the corresponding RectBound. Its bounds are conservative: if the loop contains point P, then the bound is guaranteed to contain that point as well.
```go


func (c Cap) CellUnionBound() []CellID {

	level := MinWidthMetric.MaxLevel(c.Radius().Radians()) - 1

	// If level < 0, more than three face cells are required.
	if level < 0 {
		cellIDs := make([]CellID, 6)
		for face := 0; face < 6; face++ {
			cellIDs[face] = CellIDFromFace(face)
		}
		return cellIDs
	}

	return cellIDFromPoint(c.center).VertexNeighbors(level)
}


```
The code above is the core algorithm of the roughest version of the conversion. The key step in this algorithm is calculating the `level` to look for.
```go

level := MinWidthMetric.MaxLevel(c.Radius().Radians()) - 1

```
The Level found here is the largest Cell that this Cap can contain.
```go

return cellIDFromPoint(c.center).VertexNeighbors(level)

```
The line above returns 4 Cells—the ones closest to the center point of the Cap. Of course, if the Cap is very large, it may return 6 Cells. The returned Cells are not sorted in any way.


#### 5. normalizeCovering()

The final step of FastCovering is normalizeCovering.
```go

func (c *coverer) normalizeCovering(covering *CellUnion) {
	// 1
	// 
	if c.maxLevel < maxLevel || c.levelMod > 1 {
		for i, ci := range *covering {
			level := ci.Level()
			newLevel := c.adjustLevel(minInt(level, c.maxLevel))
			if newLevel != level {
				(*covering)[i] = ci.Parent(newLevel)
			}
		}
	}
	// 2
	// 
	covering.Normalize()

	// 3
	// 
	for len(*covering) > c.maxCells {
		bestIndex := -1
		bestLevel := -1
		for i := 0; i+1 < len(*covering); i++ {
			level, ok := (*covering)[i].CommonAncestorLevel((*covering)[i+1])
			if !ok {
				continue
			}
			level = c.adjustLevel(level)
			if level > bestLevel {
				bestLevel = level
				bestIndex = i
			}
		}

		if bestLevel < c.minLevel {
			break
		}
		(*covering)[bestIndex] = (*covering)[bestIndex].Parent(bestLevel)
		covering.Normalize()
	}
	// 4
	// 
	if c.minLevel > 0 || c.levelMod > 1 {
		covering.Denormalize(c.minLevel, c.levelMod)
	}
}


```
normalizeCovering further normalizes the coverage-conversion result from the previous step so that it complies with the current covering parameters (`MaxCells`, `minLevel`, `maxLevel`, and `levelMod`). This method does not attempt to produce an optimal result. In particular, if `minLevel > 0` or `levelMod > 1`, it may return more `Cell` values than desired even when that is not necessary.

The code implementation above marks four points that need attention.

First, it checks whether a `Cell` is too small or does not satisfy the `levelMod` constraint; if so, it replaces those cells with their ancestors.

Second, it sorts the result from the previous step and further simplifies it.

Third, if the number of cells is still too large, meaning there are still too many `Cell` values, it uses a `for` loop to find the lowest common ancestor (LCA) of two adjacent cells and replaces both of them with that ancestor. The `for` loop iterates in `CellID` order.

The concrete implementation of the LCA used here was explained in detail in the previous article, [article link](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md), so it will not be repeated here.

Fourth, it finally ensures that the result satisfies `minLevel` and `levelMod`, and preferably also satisfies `MaxCells`.

Next, the two functions that still need further analysis are `Normalize()` and `Denormalize()`.

#### 6. Normalize()

First, let’s look at `Normalize()`.
```go


func (cu *CellUnion) Normalize() {
	sortCellIDs(*cu)

	output := make([]CellID, 0, len(*cu)) // the list of accepted cells
	
	for _, ci := range *cu {
	
		// 1
		if len(output) > 0 && output[len(output)-1].Contains(ci) {
			continue
		}
		
		// 2
		j := len(output) - 1 // last index to keep
		for j >= 0 {
			if !ci.Contains(output[j]) {
				break
			}
			j--
		}
		output = output[:j+1]

		// 3
		for len(output) >= 3 && areSiblings(output[len(output)-3], output[len(output)-2], output[len(output)-1], ci) {
			output = output[:len(output)-3]
			ci = ci.immediateParent() // checked !ci.isFace above
		}
		output = append(output, ci)
	}
	*cu = output
}


```
The main purpose of the `Normalize` method is to organize the individual `CellID`s in a `CellUnion`, sort them, and output a `CellUnion` with no redundancy.

Sorting is the first step.

The next step is removing redundant `Cell`s. This is the second step, and it is the key part of this function’s implementation. There are two types of redundancy: one where a `Cell` is completely contained by another, and another where four smaller `Cell`s can be merged into one larger `Cell`.

First, it handles the case where one `Cell` completely contains another `Cell`. In this case, the contained `Cell` is redundant and should be discarded. This corresponds to the location marked 1 in the code above.

In the implementation, we only need to check the last accepted cell. After the `Cell`s have been sorted, if the current candidate `Cell` is not contained by the last accepted `Cell`, then it cannot be contained by any previously accepted `Cell`.

Similarly, if the current candidate `Cell` contains `Cell`s that have already been accepted, then the `Cell`s already in `output` must also be discarded. This is because `output` maintains a contiguous suffix sequence. As mentioned earlier, S2 `Cell`s are sorted, so this contiguity cannot be broken. This corresponds to the location marked 2 in the code above.

Finally, the location marked 3 in the code checks whether the last three cells plus the current one can be merged. If three consecutive `Cell`s together with the current `Cell` can be coalesced into their nearest parent, we replace those three cells with the larger `Cell`.

After this “formatting” step performed by `Normalize`, the output `Cell`s are ordered and free of redundancy.

#### 7. Denormalize()
```go

func (cu *CellUnion) Denormalize(minLevel, levelMod int) {
	var denorm CellUnion
	for _, id := range *cu {
		level := id.Level()
		newLevel := level
		if newLevel < minLevel {
			newLevel = minLevel
		}
		if levelMod > 1 {
			newLevel += (maxLevel - (newLevel - minLevel)) % levelMod
			if newLevel > maxLevel {
				newLevel = maxLevel
			}
		}
		if newLevel == level {
			denorm = append(denorm, id)
		} else {
			end := id.ChildEndAtLevel(newLevel)
			for ci := id.ChildBeginAtLevel(newLevel); ci != end; ci = ci.Next() {
				denorm = append(denorm, ci)
			}
		}
	}
	*cu = denorm
}


```
`Denormalize` is straightforward to implement. It is the flip side of `normalize` (despite the names being antonyms). This function is used to “normalize” whether a `Cell` satisfies several predefined conditions before the covering conversion: `MinLevel`, `MaxLevel`, `LevelMOD`, and `MaxCell`.

Any `Cell` whose level is less than `minLevel`, or whose `(level - minLevel)` is not a multiple of `levelMod`, will be replaced by its child nodes until these two conditions are satisfied or `maxLevel` is reached.

The intent of the `Denormalize` function is to ensure that the resulting output satisfies `minLevel` and `levelMod`, and ideally also satisfies `MaxCells`.

At this point, readers should also understand why the function is called `Denormalize`: to satisfy the conditions, it replaces a large `Cell` with its smaller child `Cell`s. `Normalize` does exactly the opposite: it replaces four smaller child `Cell`s with their direct parent node.

With that, the analysis of the `FastCovering()` function is complete.


#### 8. adjustCellLevels()

Returning to the `initialCandidates()` function, after `FastCovering()` there is one more step: `adjustCellLevels`.
```go

c.adjustCellLevels(&cells)

```
Next, let's look at the specific implementation of `adjustCellLevels`.
```go

func (c *coverer) adjustCellLevels(cells *CellUnion) {
	if c.levelMod == 1 {
		return
	}

	var out int
	for _, ci := range *cells {
		level := ci.Level()
		newLevel := c.adjustLevel(level)
		if newLevel != level {
			ci = ci.Parent(newLevel)
		}
		if out > 0 && (*cells)[out-1].Contains(ci) {
			continue
		}
		for out > 0 && ci.Contains((*cells)[out-1]) {
			out--
		}
		(*cells)[out] = ci
		out++
	}
	*cells = (*cells)[:out]
}


```
`adjustCellLevels` is used to ensure that all `Cell`s with `level > minLevel` also satisfy `levelMod`, replacing them with ancestors when necessary. `Cell`s with levels below `minLevel` will not have their levels modified (see level adjustment). The final result is a normalized `CellUnion` that ensures there are no redundant cells.

`adjustCellLevels` is somewhat similar to `Denormalize`: both adjust a `CellUnion` to satisfy certain conditions. However, they adjust in different directions. `Denormalize` replaces a `Cell` with its children, while `adjustCellLevels` replaces a `Cell` with its parent node.
```go

func (c *coverer) adjustLevel(level int) int {
	if c.levelMod > 1 && level > c.minLevel {
		level -= (level - c.minLevel) % c.levelMod
	}
	return level
}


```
`adjustLevel` is intended to return the next smaller `Level` so that it satisfies the `levelMod` condition. Levels smaller than `minLevel` are unaffected, because the cells at those levels will eventually be handled by the `Denormalize` function.


### (2). Denormalize

The implementation of `Denormalize` has already been analyzed above, so it will not be covered again here.


### (3). Summary

The following diagram shows the full flow of Google S2’s implementation of the covering algorithm for an entire spatial region:


![](http://upload-images.jianshu.io/upload_images/1194012-14ebab5dcd205250.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Every key implementation point in the diagram above has been analyzed. If any node is still unclear, you can go back and review the earlier sections.

This approximation algorithm is not optimal, but it works reasonably well in practice. The output does not always use the maximum number of cells allowed by the constraints, because doing so does not always produce a better approximation. For example, as mentioned above, if the region to be covered happens to lie exactly at the intersection of three faces, the resulting covering may be much larger than the original region. In addition, `MaxCells` acts as a limit both on the amount of search work and on the number of cells in the final output.


Because this is an approximation algorithm, you should not rely on the stability of its output. In particular, the output of the covering algorithm may differ across versions of different libraries.

This algorithm can also produce interior covering cells. An interior covering cell is a cell that is completely contained within the region. If no cells satisfy the constraints, the set of interior covering cells may be empty, even for a non-empty region.

Note that, for performance reasons, it is wise to specify `MaxLevel` when computing interior covering cells. Otherwise, for small or zero-area regions, the algorithm may spend a large amount of time subdividing cells down to the leaf level in an attempt to find interior covering cells that satisfy the constraints.

## 4. Closing

![](http://upload-images.jianshu.io/upload_images/1194012-677511a5aa65e1c8.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This concludes the series of articles on spatial search. As usual, I will end with a few thoughts and takeaways.

While learning and practicing this area of spatial search, I consulted materials from physics, mathematics, and algorithms. From the perspectives of both physics and mathematics, this improved my understanding of space and time as a whole. Although my personal understanding in this area may still be rather shallow, it has improved substantially compared with before. The goal has been achieved.

Finally, I would like to recommend two websites. These are also the topics I have been asked about most often on Weibo.

The first question is: how were the S2 Cells in this series of articles drawn?

This is actually done with an open-source website maintained by an individual: [http://s2map.com/](http://s2map.com/). I entered the `CellID`s computed by my program there and displayed them. It is essentially a visualization and research tool for S2.

The second question is: why can’t some of the code be found in the Go version?

The answer is that the Go implementation is not yet 100% complete. For some parts, you still need to refer to the complete C++ and Java implementations. As for the C++ and Java source code, Google moved it from a private code repository to GitHub a few days ago, making it much easier to study and inspect. The official team has also organized some documentation on [https://s2geometry.io/](https://s2geometry.io/). Beginners are advised to read the official API documentation first. After reading the documentation, if you still have questions about the underlying principles, you can come back and read this spatial search series. I hope it will be helpful to readers.


------------------------------------------------------

Spatial Search series:

[Understanding n-dimensional space and n-dimensional spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient multidimensional spatial point indexing algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How is CellID generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA (Lowest Common Ancestor) in a quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The magical De Bruijn sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to find Hilbert curve neighbors in a quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)  
[How does Google S2 solve the optimal spatial covering problem?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_regionCoverer.md)


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_regionCoverer/](https://halfrost.com/go_s2_regionCoverer/)