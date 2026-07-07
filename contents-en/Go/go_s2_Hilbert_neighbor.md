# How Do You Find Hilbert Curve Neighbors on a Quadtree?


![](http://upload-images.jianshu.io/upload_images/1194012-6d8555b537b3809c.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As for the definition of a neighbor: if two cells are adjacent, they are neighbors. Neighbors can therefore be divided into two types: edge-adjacent and vertex-adjacent. There are four edge-adjacent directions: up, down, left, and right. There are also four vertex-adjacent directions, corresponding to adjacency at the four corners.


![](http://upload-images.jianshu.io/upload_images/1194012-a0c74a7e02fa551b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As shown above, the green region is the area represented by a quadtree. There is a point on the quadtree: the point indicated by the yellow region in the figure. We now want to find the Hilbert curve neighbors of the yellow point on the quadtree. The black line in the figure is a Hilbert curve passing through the quadtree. The Hilbert curve starts at 0 in the upper-left cell and ends at 63 in the upper-right cell.

The four red cells are the edge-adjacent neighbors of the yellow cell, and the four blue cells are the vertex-adjacent neighbors of the yellow cell. Therefore, the yellow cell has 8 neighboring cells, corresponding to the points 8, 9, 54, 11, 53, 30, 31, and 32. As you can see, these neighbors are not adjacent in terms of their represented points on the Hilbert curve.

So how do we find the Hilbert curve neighbors of any point on a quadtree?


## 1. Edge Neighbors

The most straightforward idea for edge neighbors is to first obtain the coordinates `(i, j)` of the center point, and then, using the coordinate system, derive the coordinates of the edge-adjacent Cells: `(i + 1, j)`, `(i - 1, j)`, `(i, j - 1)`, and `(i, j + 1)`.

The actual implementation follows this approach as well. However, there is one conversion involved here: the point on the Hilbert curve must first be converted into coordinates before we can compute its edge neighbors using the method above.

For the generation and data structure of `CellID`, see my article [How Is `CellID` Generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)

Following the idea above, the implemented code is as follows:
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
The edges are numbered 0, 1, 2, 3 in counterclockwise order: bottom, right, top, left.


Next, let’s take a closer look at the implementation.
```go

func sizeIJ(level int) int {
	return 1 << uint(maxLevel-level)
}

```
`sizeIJ` stores the **side length** of a cell at the current Level. This size is relative to Level 30. For example, if `level = 29`, its `sizeIJ` is 2, meaning the side length of a Level 29 cell consists of 2 Level 30 cells, so it contains 2^2^ = 4 smaller cells. If `level = 28`, the side length is 4, consisting of 16 smaller cells. The same pattern applies to the other levels.
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
	// Detailed explanation of this check
	if ci.lsb()&0x1111111111111110 != 0 {
		orientation ^= swapMask
	}
	return
}


```
This method decomposes a CellID back into the original i and j. The detailed process is described in the cellIDFromFaceIJ method in my article [“How Is CellID Generated in Google S2?”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md), so I won’t repeat it here. The cellIDFromFaceIJ method and the faceIJOrientation method are inverses of each other.
cellIDFromFaceIJ takes face, i, and j as input parameters and returns a CellID. faceIJOrientation decomposes a CellID into face, i, j, and orientation. Compared with cellIDFromFaceIJ, faceIJOrientation decomposes one additional value: orientation.


What needs to be explained in detail here is how orientation is computed.

We know that the data structure of a CellID is 3 bits of face + 60 bits of position + 1 flag bit. Therefore, for a non-leaf node at Level - n, after the 3-bit face, there must be 2 * n binary bits, immediately followed by 2*(maxLevel - n) + 1 binary bits that start with 1 and end with all 0s. maxLevel = 30.

For example, at Level - 16, there must be 32 binary bits in the middle, immediately followed by 2*(30 - 16) + 1 = 29 bits. These 29 bits consist of a leading 1 followed by 0s. 3 + 32 + 29 = 64 bits. This is how the 64-bit CellID is composed.

When n = 30, 3 + 60 + 1 = 64, so the trailing 1 does not have any effect. When n = 29, 3 + 58 + 3 = 64, so the trailing bits must be 100. The 10 direction pair has no effect, and the extra final 0 also has no effect on the direction. The key is how many 00 pairs appear between 10 and 0. When n = 28, 3 + 56 + 5 = 64, and the trailing 5 bits are 10000. There is one “00” between 10 and 0. “00” affects the direction, so the initial direction should be XORed with 01 to obtain the result.

The fact that “00” affects the original direction is actually fairly easy to understand. Starting from the initial direction, CellID is subdivided into four parts each time, and each subdivision introduces a direction transformation. Once the subdivision reaches the final four small cells, the direction no longer changes, because among those four small cells it is already possible to uniquely determine which Cell was selected. This is why, as shown above, the directions for Level - 30 and Level - 29 remain unchanged. For all other Levels, one more XOR with 01 is required, and after that transformation we obtain the original orientation.


Finally, perform the conversion. The concrete code implementation is as follows:
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
The conversion process consists of three steps in total. The first step handles the boundary cases for i and j. The second step converts i and j to u and v. The third step converts u and v to xyz, then converts back to u and v, and finally converts back to CellID.


Step 1:
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
The `clamp` function is used to constrain the ranges of `i` and `j`. The ranges of `i` and `j` are always constrained to `[-1, maxSize]`.


Second step:

The simplest idea is to convert the `(i, j)` coordinates to `(x, y, z)` (this point is not on the boundary), and then call the `xyzToFaceUV` method to project it onto the corresponding face.

We know that when generating a `CellID`, `stToUV` uses a quadratic transform:
```go

func stToUV(s float64) float64 {
	if s >= 0.5 {
		return (1 / 3.) * (4*s*s - 1)
	}
	return (1 / 3.) * (1 - 4*(1-s)*(1-s))
}

```
Here, however, the transformation we use is a bit simpler: a linear transformation.
```go

u = 2 * s - 1
v = 2 * t - 1

```
The values of u and v are both constrained to the range [-1, 1]. The concrete code implementation is:
```go

const scale = 1.0 / maxSize
limit := math.Nextafter(1, 2)
u := math.Max(-limit, math.Min(limit, scale*float64((i<<1)+1-maxSize)))
v := math.Max(-limit, math.Min(limit, scale*float64((j<<1)+1-maxSize)))

```
Step 3: Find the leaf nodes and convert `u` and `v` into the CellID of the corresponding Level.
```go

f, u, v = xyzToFaceUV(faceUVToXYZ(f, u, v))
return cellIDFromFaceIJ(f, stToIJ(0.5*(u+1)), stToIJ(0.5*(v+1)))

```
This gives us a CellID.

Since a cell has four edges, it has four edge neighbors.
```go

	return [4]CellID{
		cellIDFromFaceIJWrap(f, i, j-size).Parent(level),
		cellIDFromFaceIJWrap(f, i+size, j).Parent(level),
		cellIDFromFaceIJWrap(f, i, j+size).Parent(level),
		cellIDFromFaceIJWrap(f, i-size, j).Parent(level),
	}


```
The array above will be populated with the current CellID’s bottom neighbor, right neighbor, top neighbor, and left neighbor, respectively.

If displayed on a map, it would look like the figure below.

The CellID of the center cell is 3958610196388904960, at Level 10. Using the method above, the edge neighbors obtained are:
```go


3958603599319138304 // Bottom neighbor
3958607997365649408 // Right neighbor
3958612395412160512 // Top neighbor
3958599201272627200 // Left neighbor


```
Shown on the map:

![](http://upload-images.jianshu.io/upload_images/1194012-4ef6c57835e72159.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## II. Vertex-Sharing Neighbors


The vertex-sharing neighbors discussed here are slightly different from the vertex neighbors mentioned at the beginning of the article. There will also be some seemingly odd examples below; these are pitfalls the author ran into in actual coding, so I’m sharing them here.

First, let’s cover a special case: when a Cell lies exactly on one of the 8 vertices of the cube circumscribing the Earth. In that case, this point has only 3 vertex neighbors, not 4. Since each of these 8 vertices is connected to only 3 faces, on each face there is exactly one Cell that is its vertex neighbor. Except for Cells at these 8 points, all other Cells have 4 vertex neighbors!
```go

j
|
|  (0,1)  (1,1)
|  (0,0)  (1,0)
|
---------------> i

```
In the coordinate axes above, if the direction along the i-axis is 1, it falls in the right column of the four quadrants. If the direction along the j-axis is 1, it falls in the top row of the four quadrants.


>**Assume Cell Level is not equal to 30, meaning there are still 0s after the trailing marker bit 1. In that case, after this Cell is converted into i and j, the trailing bits of both i and j will be 1.**
>
>
>The conclusion above can be proven. When the faceIJOrientation function splits the Cell, if it encounters an all-zero case—for example, orientation = 11 and the trailing bits of the Cell are all 0—then it takes the last 8 bits plus orientation, 00000000 11, and after conversion through lookupIJ obtains 1111111111. Therefore i = 1111 and j = 1111, and the orientation is still 11. The trailing 00s in the Cell continue through the same process, so the trailing bits of i and j all become 1111.


Therefore, we only need to determine, from i and j, which quadrant the input Level falls in to find all vertex-sharing neighbors.


Assume the input Level is small, meaning the Cell has a large area. Then we need to determine which of the four vertices of the input Cell the shared vertex of the current Cell (the function caller) lies on. A Cell is a rectangle and has four vertices. Whichever vertex the current Cell (the function caller) is closest to is selected as the shared vertex. Then compute, in order, the four Cells around that shared vertex.

Assume the input Level is large, meaning the Cell has a small area. Then we also need to determine which of the four vertices of the current Cell (the function caller) the shared vertex of the input Cell lies on. A Cell is a rectangle and has four vertices. Whichever vertex the input Cell is closest to is selected as the shared vertex. Then compute, in order, the four Cells around that shared vertex.


Because we need to determine which quarter of a Cell it lies in, we need to examine the positions of its four children. In other words, determine the relative positions of the children at Level - 1.
```go

	halfSize := sizeIJ(level + 1)
	size := halfSize << 1
	f, i, j, _ := ci.faceIJOrientation()

	var isame, jsame bool
	var ioffset, joffset int

```
Here we need to obtain `halfSize`; `halfSize` is essentially the size of the child cells of the input `Cell`.
```go

	if i&halfSize != 0 {
		// In the rear column, so add one cell to the offset
		ioffset = size
		isame = (i + size) < maxSize
	} else {
		// In the left column, so subtract one cell from the offset
		ioffset = -size
		isame = (i - size) >= 0
	}


```
Here, we determine which of the rectangle’s four vertices is closest based on whether the `halfSize` bit is 1. Note that `i + size` must not exceed `maxSize`; if it does, it is no longer on the same face. Similarly, `i - size` must not be less than 0; if it is, it is no longer on the same face.

The logic for the `j` axis is exactly the same as for `i`.
```go

	if j&halfSize != 0 {
		// Located on the upper row, so add one cell to the offset
		joffset = size
		jsame = (j + size) < maxSize
	} else {
		// Located on the lower row, so subtract one cell from the offset
		joffset = -size
		jsame = (j - size) >= 0
	}


```
For the final result, first compute the input `Cell`, then compute the `Cell`s around it along the two axes.
```go


	results := []CellID{
		ci.Parent(level),
		cellIDFromFaceIJSame(f, i+ioffset, j, isame).Parent(level),
		cellIDFromFaceIJSame(f, i, j+joffset, jsame).Parent(level),
	}

```
If both i and j lie on the same face, then the shared vertex is definitely not one of the 8 vertices of the circumscribed cube. We can then compute the Cell of the fourth shared vertex.
```go

	if isame || jsame {
		results = append(results, cellIDFromFaceIJSame(f, i+ioffset, j+joffset, isame && jsame).Parent(level))
	}

```
In summary, the complete code implementation for computing common-vertex neighbors is as follows:
```go

func (ci CellID) VertexNeighbors(level int) []CellID {
	halfSize := sizeIJ(level + 1)
	size := halfSize << 1
	f, i, j, _ := ci.faceIJOrientation()

	fmt.Printf("halfsize original value = %v-%b\n", halfSize, halfSize)
	var isame, jsame bool
	var ioffset, joffset int

	if i&halfSize != 0 {
		// Located in the right column, so add one cell to the offset
		ioffset = size
		isame = (i + size) < maxSize
	} else {
		// Located in the left column, so subtract one cell from the offset
		ioffset = -size
		isame = (i - size) >= 0
	}
	if j&halfSize != 0 {
		// Located in the top row, so add one cell to the offset
		joffset = size
		jsame = (j + size) < maxSize
	} else {
		// Located in the bottom row, so subtract one cell from the offset
		joffset = -size
		jsame = (j - size) >= 0
	}

	results := []CellID{
		ci.Parent(level),
		cellIDFromFaceIJSame(f, i+ioffset, j, isame).Parent(level),
		cellIDFromFaceIJSame(f, i, j+joffset, jsame).Parent(level),
	}

	if isame || jsame {
		results = append(results, cellIDFromFaceIJSame(f, i+ioffset, j+joffset, isame && jsame).Parent(level))
	}

	return results
}


```
Let's look at a few examples.

The first example uses Cells of the same size. Both the input parameter and the caller Cell are at the same level—10.


![](http://upload-images.jianshu.io/upload_images/1194012-e9b551a5674b7ebf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```go

VertexNeighbors := cellID.Parent(10).VertexNeighbors(10)

// 11011011101111110011110000000000000000000000000000000000000000
3958610196388904960 // upper right corner 
3958599201272627200 // upper left corner
3958603599319138304 // lower right corner
3958601400295882752 // lower left corner

```
In the second example, is it a Cell of a different size? The caller Cell uses the default Level - 30.


![](http://upload-images.jianshu.io/upload_images/1194012-a4b3c0f0d516017f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```go

VertexNeighbors := cellID.VertexNeighbors(10)

// 11011011101111110011110000000000000000000000000000000000000000
3958610196388904960 // bottom right
3958599201272627200 // bottom left
3958612395412160512 // top right
3958623390528438272 // top left

```
The two examples above illustrate a point: although the Cells returned by the same call to `VertexNeighbors(10)` are all at Level 10, their directions and positions differ. Fundamentally, the vertices they share are different, so the four generated Cells are generated in different directions.

In the C++ version, there is a limitation when looking up vertex neighbors:
```c

DCHECK_LT(level, this->level());


```
The input Level must be strictly lower than the Level of the Cell being searched for. In other words, the grid area of the input Cell must be smaller than the grid size of the Cell. However, the Go implementation does not have this requirement; the input can be either larger or smaller.


In the following example, the input Level is lower than the Cell’s Level. (You can see that Chengdu has already been reduced to a point.)

![](http://upload-images.jianshu.io/upload_images/1194012-12642816fd82c439.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```go

VertexNeighbors := cellID.Parent(10).VertexNeighbors(5)

3957538172551823360 // bottom right
3955286372738138112 // bottom left
3959789972365508608 // top right
3962041772179193856 // top left


```
In the example below, the input parameter is greater than the Cell's Level. (You can see that the area at Level 15 is already very small.)

![](http://upload-images.jianshu.io/upload_images/1194012-f0207c8399eb2c0d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
```go

VertexNeighbors := cellID.Parent(10).VertexNeighbors(15)


3958610197462646784 // lower-left corner
3958610195315163136 // lower-right corner
3958610929754570752 // upper-left corner
3958609463023239168 // upper-right corner


```

## III. All Neighbors

Finally, let’s return to the question raised at the beginning of the article: how do we find the neighbors of a Hilbert curve on a quadtree? With the groundwork laid above, the answer may already be clear to the reader.

Finding all neighbors has one requirement: the area represented by the input Level must be smaller than or equal to that of the caller Cell. In other words, the input Level value must not be smaller than the caller’s Level. If it were smaller, the neighboring Cell would cover a much larger area, and a single neighboring Cell could very likely contain all of the original Cell’s neighbors. Such a lookup would be meaningless.

For example, if the input Level is smaller than the Level of the caller Cell, then when finding all of its neighbors, the result would look like this:
```go

AllNeighbors := cellID.Parent(10).AllNeighbors(5)

```
![](http://upload-images.jianshu.io/upload_images/1194012-69f1278ae3aa5115.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

At this point, all neighbors can be found, but overlapping Cells may occur. Why this happens will be analyzed below.


If the input parameter has the same Level as the caller Cell, then the set of all neighbors found is the issue mentioned at the beginning of the article. The ideal case is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-ee02a45bd6acd3e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The concrete implementation is as follows:
```go

func (ci CellID) AllNeighbors(level int) []CellID {
	var neighbors []CellID

	face, i, j, _ := ci.faceIJOrientation()

	// Find the coordinates of the lower-leftmost leaf node. We need to normalize the i, j coordinates, because the input Level may be greater than the caller Cell's Level.
	size := sizeIJ(ci.Level())
	i &= -size
	j &= -size

	nbrSize := sizeIJ(level)

	for k := -nbrSize; ; k += nbrSize {
		var sameFace bool
		if k < 0 {
			sameFace = (j+k >= 0)
		} else if k >= size {
			sameFace = (j+k < maxSize)
		} else {
			sameFace = true
			// Top and bottom neighbors
			neighbors = append(neighbors, cellIDFromFaceIJSame(face, i+k, j-nbrSize,
				j-size >= 0).Parent(level))
			neighbors = append(neighbors, cellIDFromFaceIJSame(face, i+k, j+size,
				j+size < maxSize).Parent(level))
		}

		// Left and right neighbors, plus the 2 diagonal vertex neighbors
		neighbors = append(neighbors, cellIDFromFaceIJSame(face, i-nbrSize, j+k,
			sameFace && i-size >= 0).Parent(level))
		neighbors = append(neighbors, cellIDFromFaceIJSame(face, i+size, j+k,
			sameFace && i+size < maxSize).Parent(level))

		// This condition serves 2 purposes: preventing 32-bit overflow and serving as the loop exit condition; once it exceeds size, there is no need to keep looking.
		if k >= size {
			break
		}
	}

	return neighbors
}

```
The simple idea behind the code above has already been written in the comments. The parts that need explanation are covered below.

The first thing to understand is the relationship between nbrSize and size. Why do we need nbrSize? Because the input Level may be different from the Level of the caller Cell. The Cell represented by the input Level may be larger, smaller, or the same size. The final result is expressed in grid units of nbrSize, so the loop needs to use nbrSize to control the grid size. size, on the other hand, is only the original grid size of the caller Cell.

In the loop, k changes as follows. When k = -nbrSize, the loop only computes the left and right neighbors. Vertex neighbors on the diagonals are actually special cases of the left and right neighbors. Next, when k = 0, it starts computing the upper and lower neighbors. k keeps increasing until finally k >= size. In the last iteration, the loop first computes the left and right neighbors once, then exits with break.

The caller Cell is in the middle, so if you want to skip over this Cell and reach the other side (up/down or left/right), you need to skip by size. In the code, this is implemented as i + size and j + size.

First, look at the scanning pattern for the left and right neighbors.

The left neighbor is i - nbrSize, j + k, with k changing in the loop. This is how the left neighbors are generated. It generates one column of left neighbors, starting from the lower-left corner and continuing upward to the upper-left corner.

The right neighbor is i + size, j + k, with k changing in the loop. This is how the right neighbors are generated. It generates one column of right neighbors, starting from the lower-right corner and continuing upward to the upper-right corner.

Now look at the scanning pattern for the upper and lower neighbors.


The lower neighbor is i + k, j - nbrSize, with k changing in the loop. This is how the lower neighbors are generated. It generates one row of lower neighbors, starting from the leftmost lower neighbor and continuing to the rightmost lower neighbor.

The upper neighbor is i + k, j + size, with k changing in the loop. This is how the upper neighbors are generated. It generates one row of upper neighbors, starting from the leftmost upper neighbor and continuing to the rightmost upper neighbor.

Example:


![](http://upload-images.jianshu.io/upload_images/1194012-9e6cd1a918e09fd7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The full set of neighbors around the middle Cell consists of the 8 Cells at the same Level shown in the image above.

The generation order has been marked. 1, 2, 5, 6, 7, and 8 are generated as left and right neighbors. 3 and 4 are generated as upper and lower neighbors.

In the example above, all Cells are generated at Level 10. The full neighbor set contains exactly 8 Cells.
```go

AllNeighbors := cellID.Parent(10).AllNeighbors(10)

3958601400295882752,
3958605798342393856,
3958603599319138304,
3958612395412160512,
3958599201272627200,
3958607997365649408,
3958623390528438272,
3958614594435416064

```
Here’s another example where the Level is greater than the caller Cell’s Level.
```go

AllNeighbors := cellID.Parent(10).AllNeighbors(11)

3958600575662161920,
3958606622976114688,
3958603324441231360,
3958611570778439680,
3958600025906348032,
3958607172731928576,
3958603874197045248,
3958613220045881344,
3958599476150534144,
3958608821999370240,
3958623115650531328,
3958613769801695232

```
Its full-neighbor generation order is as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-45598db44a6c6064.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1, 2, 5, 6, 9, 10, 11, and 12 are left/right neighbors; 3, 4, 7, and 8 are top/bottom neighbors. As we can see, the left/right neighbors are generated from bottom to top. The top/bottom neighbors are generated from left to right.

If the Level is larger, for example Level - 15, more neighbors will be generated:

![](http://upload-images.jianshu.io/upload_images/1194012-5d83cca16bac5db2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Now let’s explain the case where the input Level is smaller than the Level of the caller Cell.

For example, input Level = 9.
```go

AllNeighbors := cellID.Parent(10).AllNeighbors(9)

3958589305667977216,
3958580509574955008,
3958580509574955008,
3958615693947043840,
3958598101760999424,
3958606897854021632,
3958624490040066048,
3958615693947043840


```
The generated full neighbors are as follows:


![](http://upload-images.jianshu.io/upload_images/1194012-8592d2f0bd88d0a8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


You can see that what originally had 8 neighbors now has only 6. In fact, 8 are still generated; it is just that 2 of them are duplicates. The duplicates are the two dark-red Cells shown in the figure.

Why do they overlap?

First draw the caller’s Level - 10 Cell in the middle.

![](http://upload-images.jianshu.io/upload_images/1194012-65cc842aae629105.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Because it is Level - 9, it is one quarter of the Cell in the middle.

Now draw the two upper neighbors of the Level - 10 Cell as well.

![](http://upload-images.jianshu.io/upload_images/1194012-71bfabd68c79f29e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-6d94c763140d7e50.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

You can see that the upper neighbor Up and the vertex neighbor up-right are both located within the same Level - 9 Cell. Therefore, the upper neighbor and the top-right vertex neighbor are both the same Level - 9 Cell. That is why they overlap. Similarly, the lower neighbor and the bottom-right vertex neighbor also overlap. As a result, two Cells overlap.

Also, the caller Cell’s position is not left empty in the middle. This is because after i + size, the range is still within the same Level - 9 Cell.

If the Level is smaller, the overlap pattern changes again. For example, Level - 5.
```go

AllNeighbors := cellID.Parent(10).AllNeighbors(5)

3953034572924452864,
3946279173483397120,
3946279173483397120,
3957538172551823360,
3955286372738138112,
3957538172551823360,
3962041772179193856,
3959789972365508608


```
Drawn on a map, it looks like this:


![](http://upload-images.jianshu.io/upload_images/1194012-40bde6af3a924589.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The overlapping positions have changed as well.


At this point, we have covered all the algorithms related to finding neighbors.


------------------------------------------------------

Articles in the spatial search series:

[How to Understand n-Dimensional Space and n-Dimensional Spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How Is CellID Generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA (Lowest Common Ancestor) in a Quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The Magical De Bruijn Sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to Find Neighbors on a Hilbert Curve in a Quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_Hilbert\_neighbor/](https://halfrost.com/go_s2_Hilbert_neighbor/)