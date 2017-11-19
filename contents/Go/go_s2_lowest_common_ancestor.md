# Google S2 中的四叉树求 LCA 最近公共祖先

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-11d251652f23c659.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



## 一. 寻找父亲节点和孩子节点

首先需要回顾一下希尔伯特曲线的生成方式，具体代码见笔者[上篇文章的分析](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md#5-坐标轴点与希尔伯特曲线-cell-id-相互转换)，在这个分析中，有4个方向比较重要，接下来的分析需要，所以把这4个方向的图搬过来。




![](http://upload-images.jianshu.io/upload_images/1194012-6855d1cebab16c91.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在举例之前还需要说明一点，有些网站提供的二进制转换，并没有标明有符号还是无符号的转换，这样就会导致使用者的一些误解。笔者开始并没有发现这个问题，导致掉入了这个坑，好一会才转过弯来。笔者在网上查询了很多在线转换计算器的工具，都发现了这个问题。比如常见的[在线进制转换http://tool.oschina.net/hexconvert](http://tool.oschina.net/hexconvert)，随便找两个64位的二进制数，有符号的和无符号的分别转换成十进制，或者反过来转换，你会惊喜的发现，两次结果居然相同！例如你输入 3932700003016900608 和 3932700003016900600，你会发现转换成二进制以后结果都是 11011010010011110000011101000100000000000000000000000000000000。但是很明显这两个数不同。

假如 3932700003016900608 是无符号的，3932700003016900600 是有符号的，正确的结果应该如下：

```go

// 3932700003016900608
11011010010011110000011101000100000000000000000000000000000000

// 3932700003016900600
11011010010011110000011101000011111111111111111111111111111000

```

差距明显很大。这种例子其实还有很多，随便再举出几组：无符号的 3932700011606835200 和有符号的 3932700011606835000；无符号的 3932700020196769792 和有符号的 3932700020196770000；无符号的 3932700028786704384 和有符号的 3932700028786704400……可以举的例子很多，这里就不再举了。

利用网上的这个工具，十进制转二进制是无符号的转换，二进制转十进制就会变成有符号的转换了。而 **Google S2 默认是无符号的 CellID**，所以用有符号的 CellID 会出现错误。所以转换中需要注意一下。笔者之前没有发现这一点的时候出现了一些问题，后来突然发现了这一点，茅塞顿开。

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


![](http://upload-images.jianshu.io/upload_images/1194012-546afde3c28252af.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


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


前面说过，查看孩子节点的时候需要知道当前节点的其他3个兄弟节点的方向。

根据下图，Level 14 对应的是图0，并且当前选择了2号位置，从下图中可以看到图0中的2号位置的下一级的图是“U”形的，说明还是图0的样子。

![](http://upload-images.jianshu.io/upload_images/1194012-546afde3c28252af.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

所以可以知道当前 Level 14 所处的方向依旧是图0 。按照方向标识在图上，如下图。


![](http://upload-images.jianshu.io/upload_images/1194012-c9dd16b2ccc81188.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

所以如果还是选择上图中0号的位置，那么 Level 15 的从右往左数 64 - 3 - 1 - 14 * 2 = 32位和第33位上填入00 。

```go

11011010010011110000011101010100000000000000000000000000000000   14 
11011010010011110000011101010001000000000000000000000000000000   15

```




由于选择了图0的0号位置，所以下一级的方向对应的是图1 。(注意整个图的方向是向左旋转了90°) 。


![](http://upload-images.jianshu.io/upload_images/1194012-88afd710e9b98ba3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


图1中继续选择0号的位置，所以 Level 16 的从右往左数 64 - 3 - 1 - 15 * 2 = 30位和31位填上00 。那么就可以得到 Level 16 。

```go


11011010010011110000011101010001000000000000000000000000000000   15
11011010010011110000011101010000010000000000000000000000000000   16

```

由于选择了图1的0号位置，所以下一级的方向对应的是还是图0。



![](http://upload-images.jianshu.io/upload_images/1194012-f822c6806ce461be.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

图0中继续选择0号的位置，所以 Level 17 的从右往左数 64 - 3 - 1 - 16 * 2 = 28位和第29位填上00 。那么就可以得到 Level 17 。



```go

11011010010011110000011101010000010000000000000000000000000000   16
11011010010011110000011101010000000100000000000000000000000000   17

```

同理，其他的孩子节点都可以按照这个方法推算得到。


![](http://upload-images.jianshu.io/upload_images/1194012-427bbdef9e664438.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


从 Level 13 开始，由于 Level 13 对应的方向是图0，当前选择3号位置，就可以得到 Level 14，所以 Level 14 的末尾标志位1前面的两位是 11 。于是就可以从 Level 13 变换到 Level 14 。

```go

11011010010011110000011101010000000000000000000000000000000000   13 3932700015901802496
11011010010011110000011101011100000000000000000000000000000000   14 3932700028786704384

```

由于图0选择了3号位置，那么 Level 14 的方向就是图3 。

Level 14 对应的方向是图3，当前选择3号位置，就可以得到 Level 15，所以 Level 15 的末尾标志位1前面的两位是 11 。于是就可以从 Level 14 变换到 Level 15 。



```go

11011010010011110000011101011100000000000000000000000000000000   14 3932700028786704384
11011010010011110000011101011111000000000000000000000000000000   15 3932700032007929856


```


![](http://upload-images.jianshu.io/upload_images/1194012-c5f3c9ed57334d55.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



由于图3选择了3号位置，那么 Level 15 的方向就是图0。

Level 15 对应的方向是图0，当前选择0号位置，就可以得到 Level 16，所以 Level 16 的末尾标志位1前面的两位是 00 。于是就可以从 Level 15 变换到 Level 16 。

```go

11011010010011110000011101011111000000000000000000000000000000   15 3932700032007929856
11011010010011110000011101011110010000000000000000000000000000   16 3932700031202623488

```


![](http://upload-images.jianshu.io/upload_images/1194012-6d4e7e04891227fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



由于图0选择了0号位置，那么 Level 16 的方向就是图1。

Level 16 对应的方向是图1，当前选择1号位置，就可以得到 Level 17，所以 Level 17 的末尾标志位1前面的两位是 01 。于是就可以从 Level 16 变换到 Level 17 。


```go

11011010010011110000011101011110010000000000000000000000000000   16 3932700031202623488
11011010010011110000011101011110001100000000000000000000000000   17 3932700031135514624

```



![](http://upload-images.jianshu.io/upload_images/1194012-2db753c88581d3fe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



由于图1选择了1号位置，那么 Level 18 的方向还是图1。


到此读者应该对查找 CellID 孩子节点的流程了然于心了。在 Google S2 中，查找孩子节点的具体实现代码如下。

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

现在在来看这段代码应该毫无压力了吧。

这里比较重要的位运算的操作就是 lsb 了。从名字上其实也可以知道它是做什么的。

```go

// lsb 返回最低有效位
func (ci CellID) lsb() uint64 { return uint64(ci) & -uint64(ci) }

```

这里需要注意的一点就是负数的存储方式是以原码的补码，即符号位不变，每位取反再加1 。

举个例子，Level 16 的某个 CellID 如下：

```go

11011010010011110000011101011110010000000000000000000000000000   16 3932700031202623488

```

对它进行 lsb 计算：

![](http://upload-images.jianshu.io/upload_images/1194012-5a6443f5f221db1c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


得到的结果就是最低有效位为1，其他每位都为0 。


```go

ch[0] = ci - lsb + lsb>>2

```

这一行实际是把 Level 对应的下一级 Level 的末尾标志位1移动到位。即往后挪2位。并且标志位前面2位都为0，所以这步操作完成以后就是0号的孩子。

![](http://upload-images.jianshu.io/upload_images/1194012-8594e129ccfab375.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


0号孩子找到以后接下来就很好办了。lsb 往右移动一位以后，不断的加上这个值，就可以得到剩下的4个孩子了。如下图：


![](http://upload-images.jianshu.io/upload_images/1194012-69131b0636dfed0d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


这样就可以得到4个孩子，上面这一小段程序挺简单的，比前面从地图上解释的更简单，原因是因为没有可视化的4个孩子的相互位置关系，这个关系需要从当前所在的方向来决定。前面地图上也一再强调每一级的方向位置关系也是为了可视化展现在地图上是符合希尔伯特曲线的相对位置。

### 2. 判断是否是叶子节点

如果对 CellID 的数据结构很了解，这个判断就很简单了。

```go

func (ci CellID) IsLeaf() bool { return uint64(ci)&1 != 0 }

```

由于 CellID 是64位的，末尾有一个1的标志位，如果这个标志位到了最后一位，那么就肯定是叶子节点了，也就是 Level 30 的 Cell。


### 3. 查找当前孩子位置关系

在前面讲解查找孩子节点的时候，由于是四叉树，每个父亲下面对应4个孩子，00，01，10，11，所以判断4个孩子之间相对的位置关系只需要判断这两个二进制位就可以了。

```go

func (ci CellID) ChildPosition(level int) int {
	return int(uint64(ci)>>uint64(2*(maxLevel-level)+1)) & 3
}

```

上面这个函数入参是一个父亲节点的 Level 等级，返回的是这个父亲节点下面孩子节点的位置信息。即是 00，01，10，11 中的一个。

### 4. 查找父亲节点

在 Google S2 中，由于默认生成出来的 Cell 就是 Level 30 的，也就是 Level 最低的，位于树的最下层的叶子节点。所以生成 Level 比较低的 Cell 必须只能查找父亲节点。

由于前面讲解了如何查找孩子节点，查找父亲节点就是逆向的过程。

```go

func lsbForLevel(level int) uint64 { return 1 << uint64(2*(maxLevel-level)) }

```

第一步就是先找到最右边的标志位，它决定了 Level 的值。

```go

(uint64(ci) & -lsb)

```

第二步是保留住标志位前面所有的二进制位上的值。这里对第一步的 lsb 的相反数进行按位与操作就可以实现。lsb 的相反数其实就是 lsb 低位往左的高位都为1 ，相当于一个掩码。

![](http://upload-images.jianshu.io/upload_images/1194012-69cc45f144f84cb0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

最后一步将标志位1放好就可以了。

```go

func (ci CellID) Parent(level int) CellID {
	lsb := lsbForLevel(level)
	return CellID((uint64(ci) & -lsb) | lsb)
}


```

以上就是查找父亲节点的具体实现。

## 二. LCA 查找最近公共祖先

关于 CellID 的计算，还有很关键的一部分就是查找最近公共祖先的问题。问题背景：给定一棵四叉树中任意两个 Level 的 CellID ，如何查询两者的最近公共祖先。


由 CellID 的数据结构我们知道，想查找两个 Level 的最近公共祖先的问题可以转化为从左往右查找两个二进制串最长公共序列，最长的即是从根节点开始最远的公共祖先，也就是最近公共祖先。


那么现在问题就转换成从左往右找到第一个不相同的二进制位，或者从右往左找到最后一个不相同的二进制位。

查找过程中存在一个特殊情况，那就是要查找公共祖先的两个节点本身就在一个分支上，即其中一个 CellID 本来就是另外一个 CellID 的祖先，那么他们俩的公共祖先就直接是 CellID 大的那个。

那么到此就可以确定出接下来查找的流程。

第一步，先对两个 CellID 进行异或，找到不同的二进制位分别在那些位置上。

```go

	bits := uint64(ci ^ other)

```


第二步，判断是否存在特殊情况：两个存在祖先关系。

```go

	if bits < ci.lsb() {
		bits = ci.lsb()
	}
	if bits < other.lsb() {
		bits = other.lsb()
	}


```


第三步，查找左边最高位不同的位置。


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

由于 CellID 是 64 位的，所以两者不同的位数可能的范围是 [0，63]。分别准备6种掩码，对应的分别是0x2, 0xC, 0xF0, 0xFF00, 0xFFFF0000, 0xFFFFFFFF00000000。如下图。

![](http://upload-images.jianshu.io/upload_images/1194012-defc30b929b9fe94.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


查找的过程就是利用的二分的思想。64位先查找高位32位，如果对高32位的掩码进行按位与运算以后结果不为0，那么就说明高32位是存在不相同的位数的，那么最终结果 msbPos 加上32位，并把数字右移32位。因为高32位存在不同的数，由于我们需要求最左边的，所以低32位就可以直接舍去了，直接右移去掉。

同理，继续二分，16位，8位，4位，2位，1位，这样循环完，就一定能把最左边的不同的位数找到，并且结果位即为 msbPos。

第四步，判断 msbPos 的合法性，并输出最终结果。

如果 msbPos 比60还要大，那么就是非法值，直接返回 false 即可。

```go

	msbPos := findMSBSetNonZero64(bits)
	if msbPos > 60 {
		return 0, false
	}
	return (60 - msbPos) >> 1, true

```


最终输出的为最近公共祖先的 Level 值，所以 60 - msbPos 以后还需要再除以2 。

完整的算法实现如下：

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


举个例子：

在上面的例子中，我们挑选不存在祖先关系的两个 Level 的 CellID。

```go

11011010010011110000011101010000000100000000000000000000000000   17
11011010010011110000011101011111000000000000000000000000000000   15

```

如果从这串二进制里面直接找最近公共祖先，一定可以发现，从左往右最长的公共二进制串是：

```go

1101101001001111000001110101

```

那么他们俩的最近公共祖先就是：

```go

11011010010011110000011101010000000000000000000000000000000000

```

对应的 Level 是13，CellID 是 3932700015901802496。


------------------------------------------------------

空间搜索系列文章：

[如何理解 n 维空间和 n 维时空](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[高效的多维空间点索引算法 — Geohash 和 Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)  
[Google S2 中的 CellID 是如何生成的 ？](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_CellID.md)     
[Google S2 中的四叉树求 LCA 最近公共祖先](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_lowest_common_ancestor.md)  
[神奇的德布鲁因序列](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_De_Bruijn.md)  
[四叉树上如何求希尔伯特曲线的邻居 ？](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_Hilbert_neighbor.md)



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_lowest\_common\_ancestor/](https://halfrost.com/go_s2_lowest_common_ancestor/)
