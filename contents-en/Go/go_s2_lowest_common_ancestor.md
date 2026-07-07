# Finding the LCA (Lowest Common Ancestor) in the Quadtree in Google S2

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-11d251652f23c659.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


## I. Finding Parent Nodes and Child Nodes

First, we need to review how the Hilbert curve is generated. For the specific code, see the [analysis in my previous article](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#5-坐标轴点与希尔伯特曲线-cell-id-相互转换). In that analysis, four directions are especially important for what follows, so I’ll reproduce the diagrams for those four directions here.


![](http://upload-images.jianshu.io/upload_images/1194012-6855d1cebab16c91.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Before giving an example, one more point needs to be clarified. Some websites that provide binary conversion do not specify whether the conversion is signed or unsigned, which can easily lead to misunderstandings. I did not notice this at first and fell into this trap; it took me quite a while to realize what was going on. I looked up many online conversion calculator tools and found this issue in all of them. For example, on the common [online base converter http://tool.oschina.net/hexconvert](http://tool.oschina.net/hexconvert), pick any two 64-bit binary numbers, convert the signed and unsigned versions to decimal, or convert them the other way around, and you will be surprised to find that the two results are actually the same! For instance, if you enter 3932700003016900608 and 3932700003016900600, you will find that after conversion to binary, both results are 11011010010011110000011101000100000000000000000000000000000000. But clearly, these two numbers are different.

Assuming 3932700003016900608 is unsigned and 3932700003016900600 is signed, the correct result should be as follows:
```go

// 3932700003016900608
11011010010011110000011101000100000000000000000000000000000000

// 3932700003016900600
11011010010011110000011101000011111111111111111111111111111000

```
The difference is clearly very large. There are actually many more examples like this; here are a few more sets: unsigned 3932700011606835200 and signed 3932700011606835000; unsigned 3932700020196769792 and signed 3932700020196770000; unsigned 3932700028786704384 and signed 3932700028786704400... There are many examples that could be listed, so I will not enumerate them further here.

When using that online tool, decimal-to-binary conversion is unsigned, while binary-to-decimal conversion becomes signed. However, **Google S2 uses unsigned CellID by default**, so using signed CellID values will cause errors. You need to pay attention to this during conversion. I ran into some issues before I noticed this; once I suddenly realized it, everything became clear.

All right, let’s get to the main topic. Next, let’s look directly at an example. I will use it to explain the relationship between Cells and how to find the parent node.


![](http://upload-images.jianshu.io/upload_images/1194012-8cba180aedc07d89.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Assume there are these four connected Cells in the figure above. First, calculate the CellID from the latitude and longitude.


![](http://upload-images.jianshu.io/upload_images/1194012-d3b9e286a13e56d2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The corresponding four CellIDs are:
```go

Since the first two bits are both 0, they can actually be omitted, but for clarity, the author still pads it to 64 bits and keeps the two leading 0s

// 3932700003016900608 upper right
0011011010010011110000011101000100000000000000000000000000000000      

// 3932700011606835200 upper left
0011011010010011110000011101001100000000000000000000000000000000 

// 3932700020196769792 lower left
0011011010010011110000011101010100000000000000000000000000000000

// 3932700028786704384 lower right
0011011010010011110000011101011100000000000000000000000000000000


```
In the previous article, we also analyzed the 64-bit structure of a Cell. Here we have four Level 14 Cells, so there are 64 - 3 - 1 - 14 * 2 = 32 trailing 0s. Counting backward from the end, the 33rd bit is a 1, and the 34th and 35th bits are what we need to focus on. As you can see, they are 00, 01, 10, and 11 respectively—exactly four consecutive binary values.


![](http://upload-images.jianshu.io/upload_images/1194012-546afde3c28252af.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Following this order, we can determine that the order of these four Level 14 Cells corresponds to diagram 0 in the figure above. The only difference is that the current orientation is rotated by about 45°.


![](http://upload-images.jianshu.io/upload_images/1194012-dd7e93f0a025cc2e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The CellID of the upper-right Cell is 3932700003016900608. The 34th and 35th bits from the right are 00. Starting from this upper-right Cell, if we want to find the next Cell on the Hilbert curve, since its current orientation matches diagram 0, the next Cell after the upper-right one is the upper-left Cell. Therefore, the 34th and 35th bits should become 01. After changing them to 01, we get 3932700011606835200, which is the corresponding CellID. The 34th bit from the right has increased by 1, which in decimal corresponds to an increase of 2^33^ = 8589934592. If you compute the decimal difference between the two CellIDs, it is exactly this value. So far, everything is correct.


By the same reasoning, the next Cell after the upper-left Cell is the lower-left Cell. Again, the 34th and 35th bits change to 10, corresponding to another decimal increase of 2^33^ = 8589934592, yielding the CellID of the lower-left Cell: 3932700020196769792. Continuing in the same way, we obtain the final CellID, the lower-right CellID: 3932700028786704384.


At this point, the method for finding sibling nodes at the same Level should be very clear. Some readers may wonder: what does finding parent and child nodes have to do with siblings? The connection lies in the four orientation diagrams mentioned at the beginning of this section.

Let’s review how the Hilbert curve is generated. During the recursive generation of the Hilbert curve, a `posToIJ` array is maintained, and this array records the four orientations. The way the Hilbert curve is generated is closely related to these four orientations. If you have forgotten this part, please refer back to the previous [article analysis](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md#5-坐标轴点与希尔伯特曲线-cell-id-相互转换).

Therefore, when looking for child nodes from a Cell at a given Level, we first need to determine the current Cell’s position within that Level, as well as which of the four orientations the current Cell is in. This orientation determines the position of the child to look for at the next Level, or several Levels down. Conceptually, the Hilbert curve is a quadtree: each root node has four children. Although it is easy to traverse by Level to reach the child’s Level, each root node has four children, and deciding which one to choose requires judging the orientation of each parent node level by level.

Here is an example to illustrate this problem:
```go

func testS2() {

	latlng := s2.LatLngFromDegrees(29.323773, 107.727194)
	cellID := s2.CellIDFromLatLng(latlng)
	cell := s2.CellFromCellID(cellID) //9279882742634381312

	// cell.Level()
	fmt.Println("latlng = ", latlng)
	fmt.Println("cell level = ", cellID.Level())
	fmt.Printf("cell = %d %b\n", cellID, cellID)
	smallCell := s2.CellFromCellID(cellID.Parent(13))
	fmt.Printf("smallCell level = %d\n", smallCell.Level())
	fmt.Printf("smallCell id = %d / cellID = %d /smallCell(14).Parent = %d (level = %d)/smallCell(15).Parent = %d (level = %d)/cellID(13).Parent = %d (level = %d)/cellID(14).Parent = %d (level = %d)/cellID(15).Parent = %d (level = %d)/ %b \n", smallCell.ID(), cellID, smallCell.ID().Parent(14), (smallCell.ID().Parent(14).Level()), smallCell.ID().Parent(15), (smallCell.ID().Parent(15).Level()), cellID.Parent(13), (cellID.Parent(13)).Level(), cellID.Parent(14), (cellID.Parent(14)).Level(), cellID.Parent(15), (cellID.Parent(15)).Level(), smallCell.ID())

}


```
What do you think the program above will output? Or put another way: for the same node, if we first find its Level 13 parent node, and then from that Level 13 node find its Level 15 parent node, will the resulting Level 15 node be the same as directly finding the original node’s Level 15 parent node?

Of course, finding Level 13 first and then Level 15 does not produce Level 28. This is not an additive relationship; the result is still the Level 15 parent node. So both approaches produce a Level 15 node. But are the results from the two approaches the same? Take a guess first.


The actual result is as follows:
```go


latlng =  [29.3237730, 107.7271940]
cell level =  30
cell = 3932700032807325499 11011010010011110000011101011111101111101001011100111100111011
smallCell level = 13
smallCell id = 3932700015901802496 / cellID = 3932700032807325499 /smallCell(14).Parent = 3932700020196769792 (level = 14)/smallCell(15).Parent = 3932700016975544320 (level = 15)/cellID(13).Parent = 3932700015901802496 (level = 13)/cellID(14).Parent = 3932700028786704384 (level = 14)/cellID(15).Parent = 3932700032007929856 (level = 15)/ 11011010010011110000011101010000000000000000000000000000000000

```
As you can see, the results produced by the two approaches are different. But where exactly do they differ? Looking directly at the CellID is not very intuitive, so let’s plot both of them and take a look.

![](http://upload-images.jianshu.io/upload_images/1194012-873abcbbed748eeb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

As you can see, although the two have the same Level, their positions are different. Why does this happen? The reason is what we mentioned earlier: for the four children of a quadtree node, which one gets selected is determined by the direction in which the parent node lies.

### 1. Finding child nodes

Continuing with the example from the program above, let’s look at how to find child nodes.

We print out all nodes from Level 13 to Level 17.
```go

smallCell id = 3932700015901802496 (level = 13)/
smallCell(14).Parent = 3932700020196769792 (level = 14)/ 
smallCell(15).Parent = 3932700016975544320 (level = 15)/
smallCell(16).Parent = 3932700016170237952 (level = 16)/
smallCell(17).Parent = 3932700015968911360 (level = 17)/

```
Drawn on the diagram,


![](http://upload-images.jianshu.io/upload_images/1194012-a4d9d26447450c90.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

How does Level 13 transform into Level 14? We know the currently selected orientation is that of diagram 0. Therefore, the current Level 14 corresponds to position 2 in diagram 0.

![](http://upload-images.jianshu.io/upload_images/1194012-dd7e93f0a025cc2e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


So, counting from right to left, bits 64 - 3 - 1 - 13 * 2 = 34 and 35 should be filled with 01 respectively. Read from front to back, that is 10, which corresponds to position 2 in the diagram above. Also, the trailing flag bit 1 is moved back by another 2 bits.
```go

11011010010011110000011101010000000000000000000000000000000000   13
11011010010011110000011101010100000000000000000000000000000000   14  

```
This transforms Level 13 into Level 14. This is the transformation method from a parent node to a child node.


Similarly, let’s look at the transformation methods for Level 15, Level 16, and Level 17.


![](http://upload-images.jianshu.io/upload_images/1194012-1742eac58a199a3f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As mentioned earlier, when inspecting a child node, you need to know the directions of the current node’s other three sibling nodes.

According to the figure below, Level 14 corresponds to Figure 0, and position 2 is currently selected. From the figure below, you can see that the next-level figure for position 2 in Figure 0 is “U”-shaped, which means it still has the same shape as Figure 0.

![](http://upload-images.jianshu.io/upload_images/1194012-546afde3c28252af.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Therefore, we know that the orientation of the current Level 14 is still Figure 0. Mark the directions on the figure as shown below.


![](http://upload-images.jianshu.io/upload_images/1194012-c9dd16b2ccc81188.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

So if position 0 in the figure above is still selected, then for Level 15, fill `00` into bit positions 64 - 3 - 1 - 14 * 2 = 32 and 33, counting from right to left.
```go

11011010010011110000011101010100000000000000000000000000000000   14 
11011010010011110000011101010001000000000000000000000000000000   15

```
Since position 0 in Figure 0 was selected, the direction for the next level corresponds to Figure 1. (Note that the entire diagram has been rotated 90° to the left.)

![](http://upload-images.jianshu.io/upload_images/1194012-88afd710e9b98ba3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

In Figure 1, position 0 is selected again, so in Level 16, counting from right to left, bits 64 - 3 - 1 - 15 * 2 = 30 and 31 are filled with 00. Thus, Level 16 can be obtained.
```go


11011010010011110000011101010001000000000000000000000000000000   15
11011010010011110000011101010000010000000000000000000000000000   16

```
Since position 0 in Figure 1 is selected, the direction for the next level still corresponds to Figure 0.


![](http://upload-images.jianshu.io/upload_images/1194012-f822c6806ce461be.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Continue selecting position 0 in Figure 0, so for Level 17, counting from right to left, fill the 64 - 3 - 1 - 16 * 2 = 28th bit and the 29th bit with 00. This gives Level 17.
```go

11011010010011110000011101010000010000000000000000000000000000   16
11011010010011110000011101010000000100000000000000000000000000   17

```
Similarly, the other child nodes can all be derived using this method.


![](http://upload-images.jianshu.io/upload_images/1194012-427bbdef9e664438.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Starting from Level 13, since the direction corresponding to Level 13 is Figure 0, selecting position 3 gives Level 14. Therefore, the two bits before the trailing flag bit 1 in Level 14 are 11. Thus, we can transform from Level 13 to Level 14.
```go

11011010010011110000011101010000000000000000000000000000000000   13 3932700015901802496
11011010010011110000011101011100000000000000000000000000000000   14 3932700028786704384

```
Since Figure 0 selected position 3, the direction for Level 14 is Figure 3.

The direction corresponding to Level 14 is Figure 3. Since position 3 is currently selected, Level 15 can be obtained. Therefore, the two bits before the trailing marker bit `1` in Level 15 are `11`. Thus, Level 14 can be transformed into Level 15.
```go

11011010010011110000011101011100000000000000000000000000000000   14 3932700028786704384
11011010010011110000011101011111000000000000000000000000000000   15 3932700032007929856


```
![](http://upload-images.jianshu.io/upload_images/1194012-c5f3c9ed57334d55.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Since Figure 3 selects position 3, the direction for Level 15 is Figure 0.

The direction corresponding to Level 15 is Figure 0. With position 0 currently selected, we can obtain Level 16, so the two bits before the trailing flag bit 1 of Level 16 are 00. Thus, we can transform from Level 15 to Level 16.
```go

11011010010011110000011101011111000000000000000000000000000000   15 3932700032007929856
11011010010011110000011101011110010000000000000000000000000000   16 3932700031202623488

```
![](http://upload-images.jianshu.io/upload_images/1194012-6d4e7e04891227fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Since Figure 0 selects position 0, the direction for Level 16 is Figure 1.

The direction corresponding to Level 16 is Figure 1. Selecting position 1 in the current state yields Level 17, so the two bits before the trailing marker bit 1 in Level 17 are 01. Thus, Level 16 can be transformed into Level 17.
```go

11011010010011110000011101011110010000000000000000000000000000   16 3932700031202623488
11011010010011110000011101011110001100000000000000000000000000   17 3932700031135514624

```
![](http://upload-images.jianshu.io/upload_images/1194012-2db753c88581d3fe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Because position 1 is selected in Figure 1, the orientation at Level 18 is still that of Figure 1.


At this point, readers should have a clear understanding of the process for finding a `CellID`'s child nodes. In Google S2, the concrete implementation for finding child nodes is as follows.
```go

func (ci CellID) Children() [4]CellID {
	var ch [4]CellID
	lsb := CellID(ci.lsb())
	ch[0] = ci - lsb + lsb>>2
	lsb >>= 1
	ch[1] = ch[0] + lsb
	ch[2] = ch[1] + lsb
	ch[3] = ch[2] + lsb
	return ch
}

```
Now this code should be completely straightforward to read.

The key bitwise operation here is `lsb`. Its name basically tells you what it does.
```go

// lsb returns the least significant bit
func (ci CellID) lsb() uint64 { return uint64(ci) & -uint64(ci) }

```
One thing to note here is that negative numbers are stored as the two’s complement of their sign-magnitude representation: the sign bit remains unchanged, each bit is inverted, and then 1 is added.

For example, a CellID at Level 16 is as follows:
```go

11011010010011110000011101011110010000000000000000000000000000   16 3932700031202623488

```
Perform an LSB calculation on it:

![](http://upload-images.jianshu.io/upload_images/1194012-5a6443f5f221db1c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The result is that the least significant bit is 1, and every other bit is 0.
```go

ch[0] = ci - lsb + lsb>>2

```
This line actually moves the end marker bit `1` of the next lower Level corresponding to the current Level into position—that is, it shifts it 2 bits to the right. Also, the 2 bits before the marker bit are both `0`, so after this operation is complete, the result is child 0.

![](http://upload-images.jianshu.io/upload_images/1194012-8594e129ccfab375.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Once child 0 is found, the rest is straightforward. After shifting `lsb` one bit to the right, continuously add this value to get the remaining 4 children, as shown below:


![](http://upload-images.jianshu.io/upload_images/1194012-69131b0636dfed0d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This gives us the 4 children. The small snippet above is quite simple—simpler than the earlier explanation based on the map. The reason is that it does not visualize the relative positions of the 4 children; that relationship needs to be determined from the current orientation. The earlier map repeatedly emphasized the directional relationship at each level in order to visualize, on the map, relative positions that conform to the Hilbert curve.

### 2. Determine Whether It Is a Leaf Node

If you understand the `CellID` data structure well, this check is very simple.
```go

func (ci CellID) IsLeaf() bool { return uint64(ci)&1 != 0 }

```
Because `CellID` is 64-bit and has a trailing flag bit of `1`, if this flag bit reaches the last bit, it must be a leaf node, i.e., a Level 30 Cell.


### 3. Determine the current child's positional relationship

As explained earlier when looking up child nodes, because this is a quadtree, each parent has 4 corresponding children: `00`, `01`, `10`, and `11`. Therefore, to determine the relative positions among the 4 children, you only need to inspect these two binary bits.
```go

func (ci CellID) ChildPosition(level int) int {
	return int(uint64(ci)>>uint64(2*(maxLevel-level)+1)) & 3
}

```
The function above takes the `Level` of a parent node as input and returns the position information of the child node under that parent node. That is, one of `00`, `01`, `10`, or `11`.

### 4. Finding the Parent Node

In Google S2, because the generated `Cell` is Level 30 by default—that is, the lowest `Level`, a leaf node at the bottom of the tree—generating a `Cell` with a lower `Level` can only be done by looking up its parent node.

Since we covered how to find child nodes earlier, finding a parent node is simply the reverse process.
```go

func lsbForLevel(level int) uint64 { return 1 << uint64(2*(maxLevel-level)) }

```
The first step is to locate the rightmost flag bit, which determines the value of Level.
```go

(uint64(ci) & -lsb)

```
The second step is to preserve the values of all binary bits before the flag bit. This can be done by performing a bitwise AND with the negation of `lsb` from the first step. The negation of `lsb` is effectively a mask where all higher bits to the left of the low bit of `lsb` are `1`.

![](http://upload-images.jianshu.io/upload_images/1194012-69cc45f144f84cb0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The final step is simply to place the flag bit `1` in the correct position.
```go

func (ci CellID) Parent(level int) CellID {
	lsb := lsbForLevel(level)
	return CellID((uint64(ci) & -lsb) | lsb)
}


```
That is the concrete implementation for finding the parent node.

## II. LCA: Finding the Lowest Common Ancestor

A critical part of computing a CellID is finding the lowest common ancestor. Problem statement: given the CellIDs of any two Levels in a quadtree, how do we find their lowest common ancestor?

From the data structure of CellID, we know that finding the lowest common ancestor of two Levels can be transformed into finding the longest common prefix of two binary strings from left to right. The longest one is the farthest common ancestor from the root node, which is the lowest common ancestor.

So the problem now becomes finding the first differing bit from left to right, or finding the last differing bit from right to left.

There is a special case during the search: the two nodes whose common ancestor we want to find may already lie on the same branch. In other words, one CellID is already an ancestor of the other CellID. In that case, their common ancestor is simply the larger CellID.

At this point, we can determine the search process that follows.

First, XOR the two CellIDs to find the positions of the differing bits.
```go

	bits := uint64(ci ^ other)

```
Second, determine whether there is a special case: the two are in an ancestor-descendant relationship.
```go

	if bits < ci.lsb() {
		bits = ci.lsb()
	}
	if bits < other.lsb() {
		bits = other.lsb()
	}


```
Step 3: find the position of the leftmost (most significant) differing bit.
```go


func findMSBSetNonZero64(bits uint64) int {
	val := []uint64{0x2, 0xC, 0xF0, 0xFF00, 0xFFFF0000, 0xFFFFFFFF00000000}
	shift := []uint64{1, 2, 4, 8, 16, 32}
	var msbPos uint64
	for i := 5; i >= 0; i-- {
		if bits&val[i] != 0 {
			bits >>= shift[i]
			msbPos |= shift[i]
		}
	}
	return int(msbPos)
}

```
Since CellID is 64 bits, the possible range for the number of differing bits between the two values is [0, 63]. Prepare six masks, corresponding to 0x2, 0xC, 0xF0, 0xFF00, 0xFFFF0000, and 0xFFFFFFFF00000000, respectively, as shown below.

![](http://upload-images.jianshu.io/upload_images/1194012-defc30b929b9fe94.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The lookup process uses the idea of binary search. For the 64-bit value, first check the upper 32 bits. If the result of applying the mask to the upper 32 bits with a bitwise AND is nonzero, that means there are differing bits in the upper 32 bits. In that case, add 32 to the final result `msbPos` and shift the number right by 32 bits. Because the upper 32 bits contain differing bits, and we need the leftmost one, the lower 32 bits can be discarded directly by shifting them out.

By the same logic, continue bisecting: 16 bits, 8 bits, 4 bits, 2 bits, and 1 bit. After this loop completes, the leftmost differing bit is guaranteed to have been found, and the resulting position is `msbPos`.

Step 4: validate `msbPos` and output the final result.

If `msbPos` is greater than 60, it is an invalid value, so simply return `false`.
```go

	msbPos := findMSBSetNonZero64(bits)
	if msbPos > 60 {
		return 0, false
	}
	return (60 - msbPos) >> 1, true

```
The final output is the Level value of the lowest common ancestor, so after 60 - msbPos, you still need to divide by 2.

The complete algorithm implementation is as follows:
```go

func (ci CellID) CommonAncestorLevel(other CellID) (level int, ok bool) {
	bits := uint64(ci ^ other)
	if bits < ci.lsb() {
		bits = ci.lsb()
	}
	if bits < other.lsb() {
		bits = other.lsb()
	}

	msbPos := findMSBSetNonZero64(bits)
	if msbPos > 60 {
		return 0, false
	}
	return (60 - msbPos) >> 1, true
}

```
For example:

In the example above, we selected two CellIDs at different levels that do not have an ancestor relationship.
```go

11011010010011110000011101010000000100000000000000000000000000   17
11011010010011110000011101011111000000000000000000000000000000   15

```
If we look for the lowest common ancestor directly in this binary sequence, we can see that the longest common binary prefix from left to right is:
```go

1101101001001111000001110101

```
Then their lowest common ancestor is:
```go

11011010010011110000011101010000000000000000000000000000000000

```
The corresponding Level is 13, and the CellID is 3932700015901802496.


------------------------------------------------------

Spatial search series:

[Understanding n-dimensional space and n-dimensional spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient multidimensional spatial point indexing algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How is a CellID generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA (Lowest Common Ancestor) in a quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The magical De Bruijn sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to find Hilbert curve neighbors on a quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_lowest\_common\_ancestor/](https://halfrost.com/go_s2_lowest_common_ancestor/)