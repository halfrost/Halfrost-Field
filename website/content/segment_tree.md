+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Segment Tree"]
date = 2019-12-21T11:54:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/144_0.png"
slug = "segment_tree"
tags = ["Algorithm", "Segment Tree"]
title = "Algorithm in LeetCode —— Segment Tree"

+++


![](https://img.halfrost.com/Blog/ArticleImage/144_1.png)



## Segment Tree 的 Tips:

- 线段数的经典数组实现写法。将合并两个节点 pushUp 逻辑抽象出来了，可以实现任意操作(常见的操作有：加法，取 max，min 等等)。第 218 题，第 303 题，第 307 题，第 699 题。
- 计数线段树的经典写法。第 315 题，第 327 题，第 493 题。
- 线段树的树的实现写法。第 715 题，第 732 题。
- 区间懒惰更新。第 218 题，第 699 题。
- 离散化。离散化需要注意一个特殊情况：假如三个区间为 [1,10] [1,4] [6,10]，离散化后 x[1]=1,x[2]=4,x[3]=6,x[4]=10。第一个区间为 [1,4]，第二个区间为 [1,2]，第三个区间为 [3,4]，这样一来，区间一 = 区间二 + 区间三，这和离散前的模型不符，离散前，很明显，区间一 > 区间二 + 区间三。正确的做法是：在相差大于 1 的数间加一个数，例如在上面 1 4 6 10 中间加 5，即可 x[1]=1,x[2]=4,x[3]=5,x[4]=6,x[5]=10。这样处理之后，区间一是 1-5 ，区间二是 1-2 ，区间三是 4-5 。
- 灵活构建线段树。线段树节点可以存储多条信息，合并两个节点的 pushUp 操作也可以是多样的。第 850 题，第 1157 题。


线段树[题型](https://blog.csdn.net/xuechelingxiao/article/details/38313105)从简单到困难:

1. 单点更新:  
	[HDU 1166 敌兵布阵](http://acm.hdu.edu.cn/showproblem.php?pid=1166) update:单点增减 query:区间求和  
	[HDU 1754 I Hate It](http://acm.hdu.edu.cn/showproblem.php?pid=1754) update:单点替换 query:区间最值  
	[HDU 1394 Minimum Inversion Number](http://acm.hdu.edu.cn/showproblem.php?pid=1394) update:单点增减 query:区间求和  
	[HDU 2795 Billboard](http://acm.hdu.edu.cn/showproblem.php?pid=2795) query:区间求最大值的位子(直接把update的操作在query里做了)
2. 区间更新:  
	[HDU 1698 Just a Hook](http://acm.hdu.edu.cn/showproblem.php?pid=1698) update:成段替换 (由于只query一次总区间,所以可以直接输出 1 结点的信息)  
	[POJ 3468 A Simple Problem with Integers](http://poj.org/problem?id=3468) update:成段增减 query:区间求和  
	[POJ 2528 Mayor’s posters](http://poj.org/problem?id=2528) 离散化 + update:成段替换 query:简单hash  
	[POJ 3225 Help with Intervals](http://poj.org/problem?id=3225) update:成段替换,区间异或 query:简单hash
3. 区间合并(这类题目会询问区间中满足条件的连续最长区间,所以PushUp的时候需要对左右儿子的区间进行合并):  
	[POJ 3667 Hotel](http://poj.org/problem?id=3667) update:区间替换 query:询问满足条件的最左端点
4. 扫描线(这类题目需要将一些操作排序,然后从左到右用一根扫描线扫过去最典型的就是矩形面积并,周长并等题):  
	[HDU 1542 Atlantis](http://acm.hdu.edu.cn/showproblem.php?pid=1542) update:区间增减 query:直接取根节点的值  
	[HDU 1828 Picture](http://acm.hdu.edu.cn/showproblem.php?pid=1828) update:区间增减 query:直接取根节点的值

| Title | Solution | Difficulty | Time | Space | 收藏 |
| ----- | :--------: | :----------: | :----: | :-----: |:-----: |
|[218. The Skyline Problem](https://leetcode.com/problems/the-skyline-problem)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0218.%20The%20Skyline%20Problem)| Hard | O(n log n)| O(n)|❤️|
|[307. Range Sum Query - Mutable](https://leetcode.com/problems/range-sum-query-mutable)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0307.%20Range%20Sum%20Query%20-%20Mutable)| Hard | O(1)| O(n)||
|[315. Count of Smaller Numbers After Self](https://leetcode.com/problems/count-of-smaller-numbers-after-self)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0315.%20Count%20of%20Smaller%20Numbers%20After%20Self)| Hard | O(n log n)| O(n)||
|[327. Count of Range Sum](https://leetcode.com/problems/count-of-range-sum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0327.%20Count%20of%20Range%20Sum)| Hard | O(n log n)| O(n)|❤️|
|[493. Reverse Pairs](https://leetcode.com/problems/reverse-pairs)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0493.%20Reverse%20Pairs)| Hard | O(n log n)| O(n)||
|[699. Falling Squares](https://leetcode.com/problems/falling-squares)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0699.%20Falling%20Squares)| Hard | O(n log n)| O(n)|❤️|
|[715. Range Module](https://leetcode.com/problems/range-module)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0715.%20Range%20Module)| Hard | O(log n)| O(n)|❤️|
|[732. My Calendar III](https://leetcode.com/problems/my-calendar-iii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0732.%20My%20Calendar%20III)| Hard | O(log n)| O(n)|❤️|
|[850. Rectangle Area II](https://leetcode.com/problems/rectangle-area-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0850.%20Rectangle%20Area%20II)| Hard | O(n log n)| O(n)|❤️|
|[1157. Online Majority Element In Subarray](https://leetcode.com/problems/online-majority-element-in-subarray)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1157.%20Online%20Majority%20Element%20In%20Subarray)| Hard | O(log n)| O(n)|❤️|



