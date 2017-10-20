# Google S2 中的四叉树求 LCA 最近公共祖先


## 寻找父亲节点和孩子节点

首先需要回顾一下希尔伯特曲线的生成方式，具体代码见笔者[上篇文章的分析](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md#5-坐标轴点与希尔伯特曲线-cell-id-相互转换)，在这个分析中，有4个方向比较重要，接下来的分析需要，所以把这4个方向的图搬过来。






![](http://upload-images.jianshu.io/upload_images/1194012-d7b41ae8d2a8cffd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在举例之前还需要说明一点，有些网站提供的二进制转换，并没有标明有符号还是无符号的转换，这样就会导致使用者的一些误解。笔者开始并没有发现这个问题，导致掉入了这个坑，好一会才转过弯来。笔者在网上查询了很多在线转换计算器的工具，都发现了这个问题。比如常见的[在线进制转换http://tool.oschina.net/hexconvert](http://tool.oschina.net/hexconvert)，随便找两个64位的二进制数，有符号的和无符号的分别转换成十进制，或者反过来转换，你会惊喜的发现，两次结果居然相同！例如你输入 3932700003016900608 和 3932700003016900600，你会发现转换成二进制以后结果都是 11011010010011110000011101000100000000000000000000000000000000。但是很明显这两个数不同。

假如 3932700003016900608 是无符号的，3932700003016900600 是有符号的，正确的结果应该如下：

```go

// 3932700003016900608
11011010010011110000011101000100000000000000000000000000000000

// 3932700003016900600
11011010010011110000011101000011111111111111111111111111111000

```

差距明显很大。这种例子其实还有很多，随便再举出几组：无符号的 3932700011606835200 和有符号的 3932700011606835000；无符号的 3932700020196769792 和有符号的 3932700020196770000；无符号的 3932700028786704384 和有符号的 3932700028786704400……可以举的例子很多，这里就不再举了。总之这些工具都是按照无符号去转换的。

好了，进入正题。接下来直接看一个例子，笔者用例子来说明每个 Cell 之间的关系，以及如何查找父亲节点的。


![](http://upload-images.jianshu.io/upload_images/1194012-8cba180aedc07d89.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

假设有上图这4个连在一起的 Cell。先根据经纬度把 CellID 计算出来。


![](http://upload-images.jianshu.io/upload_images/1194012-d3b9e286a13e56d2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

对应的4个 CellID 分别是：

```go

由于前两位都是0，所以其实可以省略，但是为了读者看的更清晰，笔者还是补全了64位，前面2个0还是补上

// 3932700003016900608 右上
0011011010010011110000011101000100000000000000000000000000000000      

// 3932700011606835200 左上
0011011010010011110000011101001100000000000000000000000000000000 

// 3932700020196769792 左下
0011011010010011110000011101010100000000000000000000000000000000

// 3932700028786704384 右下
0011011010010011110000011101011100000000000000000000000000000000


```


在前篇文章里面我们也分析了 Cell 64位的结构，这里是4个 Level 14的 Cell，所以末尾有 64 - 3 - 1 - 14 * 2 = 32 个 0 。从末尾往前的第33位是一个1，第34位，第35位是我们重点需要关注的。可以看到分别是00，01，10，11 。正好是连续的4个二进制。



![](http://upload-images.jianshu.io/upload_images/1194012-f685e23aca0e0c1f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


根据这个顺序，我们可以匹配到当前这4个 Level 14 的 Cell 对应的顺序是上图图中的图0 。只不过当前方向旋转了45°左右。



![](http://upload-images.jianshu.io/upload_images/1194012-dd7e93f0a025cc2e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


右上的 CellID 是 3932700003016900608 ，从右往左的第34位和第35位是00，从右上这个 Cell 想找到希尔伯特曲线的下一个 Cell，由于它目前方向是图0的方向，所以右上的 Cell 的下一个 Cell 是左上那个 Cell，那么第34位和第35位就应该是01，变换成01以后，就3932700011606835200，这也就是对应的 CellID。右数第34位增加了一个1，对应十进制就增加了 2^33^ = 8589934592，算一下两个 CellID 对应十进制的差值，也正好是这个数。目前一切都是正确的。


同理可得，左上的 Cell 的下一个 Cell 就是左下的 Cell，也是相同的第34位和第35位上变成10，对应十进制增加 2^33^ = 8589934592，得到左下的 CellID 为 3932700020196769792。继续同理可以得到最后一个 CellID，右下的 CellID，为 3932700028786704384。


看到这里，读者应该对查找同 Level 的兄弟节点的方法清清楚楚了。可能有人有疑问了，要查找父亲节点和孩子节点和兄弟有啥关系？他们之间的联系就在这一章节开头说的4个方向图上面。

回顾一下希尔伯特曲线的生成方式，在递归生成希尔伯特曲线的时候，保存了一个 posToIJ 数组，这个数组里面记录着4个方向。希尔伯特曲线生成的形式和这4个方向是密切相关的。如果忘记了这部分，还请回看之前笔者的[文章分析](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md#5-坐标轴点与希尔伯特曲线-cell-id-相互转换)。

所以同一级的 Level 想查找孩子节点，首先要找到在这一级中，当前 Cell 所处的位置以及当前 Cell 所在的4个方向中的哪一个方向。这个方向决定了要查找孩子位于下一级或者下几级的哪个位置。因为希尔伯特曲线相当于是一个颗四叉树，每个根节点有4个孩子，虽然按层可以很轻松的遍历到孩子所在的层级，但是同一个根节点的孩子有4个，究竟要选哪一个就需要父亲节点的方向一级级的来判断了。

举个例子来说明这个问题：

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


读者考虑一下上述的程序会输出什么呢？或者这样问，同一个节点，先找它的 Level 13 的父亲节点，再通过 Level 13 的这个节点再找它的 Level 15 的父亲节点得到的 Level 15 的节点，和，直接找它的 Level 15 的父亲节点，最终结果一样么？

当然，这里先找 Level 13，再找 Level 15，得到的结果不是 Level 28，这里不是相加的关系，结果还是 Level 15 的父亲节点。所以上面两种方式得到的结果都是 Level 15的。那么两种做法得到的结果是一样的么？读者可以先猜一猜。


实际得到的结果如下：

```go


latlng =  [29.3237730, 107.7271940]
cell level =  30
cell = 3932700032807325499 11011010010011110000011101011111101111101001011100111100111011
smallCell level = 13
smallCell id = 3932700015901802496 / cellID = 3932700032807325499 /smallCell(14).Parent = 3932700020196769792 (level = 14)/smallCell(15).Parent = 3932700016975544320 (level = 15)/cellID(13).Parent = 3932700015901802496 (level = 13)/cellID(14).Parent = 3932700028786704384 (level = 14)/cellID(15).Parent = 3932700032007929856 (level = 15)/ 11011010010011110000011101010000000000000000000000000000000000

```

可以看到，两种做法得到的结果是不同的。但是究竟哪里不同呢？直接看 CellID 不够直观，那把它们俩画出来看看。


![](http://upload-images.jianshu.io/upload_images/1194012-873abcbbed748eeb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以看到两者虽然 Level 是相同的，但是位置是不同的，为何会这样呢？原因就是之前说的，四叉树4个孩子，究竟选择哪一个，是由于父亲节点所在方向决定的。

### 1. 查找孩子节点

还是继续按照上面程序举的例子，看看如何查找孩子节点的。

我们把 Level 13 - Level 17 的节点都打印出来。

```go

smallCell id = 3932700015901802496 (level = 13)/
smallCell(14).Parent = 3932700020196769792 (level = 14)/ 
smallCell(15).Parent = 3932700016975544320 (level = 15)/
smallCell(16).Parent = 3932700016170237952 (level = 16)/
smallCell(17).Parent = 3932700015968911360 (level = 17)/

```

画在图上，


![](http://upload-images.jianshu.io/upload_images/1194012-a4d9d26447450c90.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

从 Level 13 是如何变换到 Level 14 的呢？我们知道当前选择的是图0的方向。那么当前 Level 14是图0 中的2号的位置。

![](http://upload-images.jianshu.io/upload_images/1194012-dd7e93f0a025cc2e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


所以从右往左数 64 - 3 - 1 - 13 * 2 = 34位和35位，应该分别填上01，从前往后就是10，对应的就是上图中的2的位置，并且末尾的那个标志位1往后再挪2位。



```go

11011010010011110000011101010000000000000000000000000000000000   13
11011010010011110000011101010100000000000000000000000000000000   14  

```


即可从 Level 13 变换到 Level 14 。这就是从父亲节点到孩子节点的变换方法。



同理在看看 Level 15，Level 16，Level 17 的变换方法。


![](http://upload-images.jianshu.io/upload_images/1194012-1742eac58a199a3f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


```go


11011010010011110000011101010001000000000000000000000000000000   15
11011010010011110000011101010000010000000000000000000000000000   16
11011010010011110000011101010000000100000000000000000000000000   17

```




### 2. 查找父亲节点

## LCA 查找最近公共祖先

