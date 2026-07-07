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


## Tips for Segment Tree:

- The classic array-based implementation of a segment tree. The `pushUp` logic for merging two nodes is abstracted out, so arbitrary operations can be implemented (common operations include addition, taking `max`, `min`, etc.). Problems 218, 303, 307, and 699.
- The classic implementation of a counting segment tree. Problems 315, 327, and 493.
- The tree-based implementation of a segment tree. Problems 715 and 732.
- Lazy range updates. Problems 218 and 699.
- Discretization. Pay attention to one special case in discretization: suppose the three intervals are [1,10], [1,4], and [6,10]. After discretization, x[1]=1,x[2]=4,x[3]=6,x[4]=10. The first interval becomes [1,4], the second becomes [1,2], and the third becomes [3,4]. As a result, interval one = interval two + interval three, which does not match the model before discretization. Before discretization, it is obvious that interval one > interval two + interval three. The correct approach is to add a number between values whose difference is greater than 1. For example, add 5 between 4 and 6 in 1 4 6 10 above, yielding x[1]=1,x[2]=4,x[3]=5,x[4]=6,x[5]=10. After this processing, interval one is 1-5, interval two is 1-2, and interval three is 4-5.
- Build segment trees flexibly. A segment tree node can store multiple pieces of information, and the `pushUp` operation that merges two nodes can also take many forms. Problems 850 and 1157.


Segment tree [problem types](https://blog.csdn.net/xuechelingxiao/article/details/38313105), from easy to hard:

1. Point updates:  
	[HDU 1166 Enemy Troops](http://acm.hdu.edu.cn/showproblem.php?pid=1166) update: point increment/decrement query: range sum  
	[HDU 1754 I Hate It](http://acm.hdu.edu.cn/showproblem.php?pid=1754) update: point replacement query: range extremum  
	[HDU 1394 Minimum Inversion Number](http://acm.hdu.edu.cn/showproblem.php?pid=1394) update: point increment/decrement query: range sum  
	[HDU 2795 Billboard](http://acm.hdu.edu.cn/showproblem.php?pid=2795) query: find the position of the maximum value in a range (the update operation is performed directly inside query)
2. Range updates:  
	[HDU 1698 Just a Hook](http://acm.hdu.edu.cn/showproblem.php?pid=1698) update: range replacement (because only the full range is queried once, you can directly output the information of node 1)  
	[POJ 3468 A Simple Problem with Integers](http://poj.org/problem?id=3468) update: range increment/decrement query: range sum  
	[POJ 2528 Mayor’s posters](http://poj.org/problem?id=2528) discretization + update: range replacement query: simple hashing  
	[POJ 3225 Help with Intervals](http://poj.org/problem?id=3225) update: range replacement, interval XOR query: simple hashing
3. Range merging (these problems ask for the longest contiguous interval within a range that satisfies certain conditions, so during PushUp, the intervals of the left and right children need to be merged):  
	[POJ 3667 Hotel](http://poj.org/problem?id=3667) update: range replacement query: ask for the leftmost endpoint that satisfies the condition
4. Sweep line (these problems require sorting a set of operations, then sweeping from left to right with a sweep line. The most typical examples are union area of rectangles, union perimeter, and similar problems):  
	[HDU 1542 Atlantis](http://acm.hdu.edu.cn/showproblem.php?pid=1542) update: range increment/decrement query: directly take the value of the root node  
	[HDU 1828 Picture](http://acm.hdu.edu.cn/showproblem.php?pid=1828) update: range increment/decrement query: directly take the value of the root node

| Title | Solution | Difficulty | Time | Space | Favorite |
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