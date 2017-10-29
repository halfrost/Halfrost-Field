# 神奇的德布鲁因序列



![](http://upload-images.jianshu.io/upload_images/1194012-d857e84412a8925b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


数学中存在这样一个序列，它充满魔力，在实际工程中也有一部分的应用。今天就打算分享一下这个序列，它在 Google S2 中是如何使用的以及它在图论中，其他领域中的应用。这个序列就是德布鲁因序列 De Bruijn。

## 从一个魔术开始说起


![](http://upload-images.jianshu.io/upload_images/1194012-7b559f218c56f210.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



有这样一个扑克牌魔术。魔术师手上拿着一叠牌，给5个人(这里的人数只能少于等于32，原因稍后会解释)分别检查扑克牌，查看扑克牌的花色和点数是否都是不同的，即没有相同的牌。

检查完扑克牌，没有重复的牌以后，就可以给这5个人洗牌了。让这5个人任意的抽一叠牌从上面放到下面，即切牌。5个人轮流切完牌，牌的顺序已经全部变化了。

接着开始抽牌。魔术师让最后一个切牌的人抽走这叠牌最上面的一张，依次给每个人抽走最上面的一张。这时候抽走了5张牌。魔术师会说，“我已经看透了你们的心思，你们手上的牌我都知道了”。然后魔术师会让拿黑色牌的人站起来(这一步很关键！)。然后魔术师会依次说出所有人手上的牌。最后每个人翻出自己的牌，全部命中。全场欢呼。


## 魔术原理揭秘



![](http://upload-images.jianshu.io/upload_images/1194012-6ce8d13eb66da18b.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



在整个魔术中，有两个地方比较关键。第一个是参与的人数只能少于等于32 。一副完整的扑克牌中，总共有54张牌，但是除去2张鬼牌(因为他们花色只有2种)，总共就52张牌。


在上述魔术中，所有的牌都用二进制进行编码，要想任意说出任意连续的5张牌，那么必须这副牌具有全排列的特性。即枚举所有种组合，并且每个组合都唯一代表了一组排列。

如果窗口大小为5，5张连续的扑克牌。二进制编码 2^5^ = 32 ，所以需要32张牌。如果窗口大小为6，6张连续的扑克牌，二进制编码 2^6^ = 64，需要64张扑克牌。总共牌只有52张，所以不可能到64张。所以32个人是上限了 。

第二个关键的地方是，只有让拿黑色的牌的人或者拿红色的牌的人站出来，魔术师才能知道这5个人拿到的连续5张扑克牌究竟是什么。其实魔术师说“我已经知道你们所有人拿到的是什么牌”的时候，他并不知道每个人拿到的是什么牌。

扑克牌除了点数以外，还有4种花色。现在需要32张牌，就是1-8号牌，每号牌都有4种花色。花色用2位二进制编码，1-8用3位二进制编码。于是5位二进制正好可以表示一张扑克牌所有信息。



![](http://upload-images.jianshu.io/upload_images/1194012-4ee59f6d184c0b3a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


如上图，00110 表示的就是梅花6 。11000 表示的是红桃8（因为没有 0 号牌，所以000就表示8）

第一步将扑克牌编码完成以后，第二步就需要找到一个序列，它必须满足以下的条件：由 2^n-1^个1和2^n-1^个0构成的序列或者圆排列，是否能存在在任意 n 个位置上0，1序列两两都不同。满足这个条件的序列也称为 n 阶完备二进圆排列。

这个魔术中我们需要找的是 5 阶完备二进圆排列。答案是存在这样一个满足条件的序列。这个序列也就是文章的主角，德布鲁因序列。


![](http://upload-images.jianshu.io/upload_images/1194012-cda420023544461e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上述序列就是一个窗口大小为5的德布鲁因序列。任意连续的5个二进制相互之间都是两两不同的。所以给观众任意洗牌，不管怎么洗牌，只要最终挑出来是连续的5张，这5张的组合都在最终的结果之中。

将窗口大小为5的德布鲁因序列每5个二进制位都转换成扑克牌的编码，如下：

![](http://upload-images.jianshu.io/upload_images/1194012-fdb9c413d07ed051.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

所以32张牌的初始顺序如下：

梅花8，梅花A，梅花2，梅花4，黑桃A，方片2，梅花5，黑桃3，方片6，黑桃4，红桃A，方片3，梅花7，黑桃7，红桃7，红桃6，红桃4，红桃8，方片A，梅花3，梅花6，黑桃5，红桃3，方片7，黑桃6，红桃5，红桃2，方片5，黑桃2，方片4，黑桃8，方片8。



![](http://upload-images.jianshu.io/upload_images/1194012-8475eab472a824e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


将所有的排列组合列举出来，如上图。当魔术师让黑色或者红色的牌的人出列的时候，就能确定到具体是哪一种组合了。于是也就可以直接说出每个人手上拿的是什么牌了。



## 德布鲁因序列的性质


## 在图论中的应用：欧拉环 和 汉密尔顿回路



## 位运算




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
> Source: [https://halfrost.com/go\_s2\_De\_Bruijn/](https://halfrost.com/go_s2_De_Bruijn/)