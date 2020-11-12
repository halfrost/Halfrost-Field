+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Union Find"]
date = 2019-11-16T08:31:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/142_0.png"
slug = "union_find"
tags = ["Algorithm", "Union Find"]
title = "Algorithm in LeetCode —— Union Find"

+++


![](https://img.halfrost.com/Blog/ArticleImage/142_1.png)



## Union Find 的 Tips:


- 灵活使用并查集的思想，熟练掌握并查集的[模板](https://github.com/halfrost/LeetCode-Go/blob/master/template/UnionFind.go)，模板中有两种并查集的实现方式，一种是路径压缩 + 秩优化的版本，另外一种是计算每个集合中元素的个数 + 最大集合元素个数的版本，这两种版本都有各自使用的地方。能使用第一类并查集模板的题目有：第 128 题，第 130 题，第 547 题，第 684 题，第 721 题，第 765 题，第 778 题，第 839 题，第 924 题，第 928 题，第 947 题，第 952 题，第 959 题，第 990 题。能使用第二类并查集模板的题目有：第 803 题，第 952 题。第 803 题秩优化和统计集合个数这些地方会卡时间，如果不优化，会 TLE。
- 并查集是一种思想，有些题需要灵活使用这种思想，而不是死套模板，如第 399 题，这一题是 stringUnionFind，利用并查集思想实现的。这里每个节点是基于字符串和 map 的，而不是单纯的用 int 节点编号实现的。
- 有些题死套模板反而做不出来，比如第 685 题，这一题不能路径压缩和秩优化，因为题目中涉及到有向图，需要知道节点的前驱节点，如果路径压缩了，这一题就没法做了。这一题不需要路径压缩和秩优化。
- 灵活的抽象题目给的信息，将给定的信息合理的编号，使用并查集解题，并用 map 降低时间复杂度，如第 721 题，第 959 题。
- 关于地图，砖块，网格的题目，可以新建一个特殊节点，将四周边缘的砖块或者网格都 union() 到这个特殊节点上。第 130 题，第 803 题。
- 能用并查集的题目，一般也可以用 DFS 和 BFS 解答，只不过时间复杂度会高一点。


| Title | Solution | Difficulty | Time | Space | 收藏 |
| ----- | :--------: | :----------: | :----: | :-----: |:-----: |
|[128. Longest Consecutive Sequence](https://leetcode.com/problems/longest-consecutive-sequence)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0128.%20Longest%20Consecutive%20Sequence)| Hard | O(n)| O(n)|❤️|
|[130. Surrounded Regions](https://leetcode.com/problems/surrounded-regions)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0130.%20Surrounded%20Regions)| Medium | O(m\*n)| O(m\*n)||
|[200. Number of Islands](https://leetcode.com/problems/number-of-islands)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0200.%20Number%20of%20Islands)| Medium | O(m\*n)| O(m\*n)||
|[399. Evaluate Division](https://leetcode.com/problems/evaluate-division)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0399.%20Evaluate%20Division)| Medium | O(n)| O(n)||
|[547. Friend Circles](https://leetcode.com/problems/friend-circles)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0547.%20Friend%20Circles)| Medium | O(n^2)| O(n)||
|[684. Redundant Connection](https://leetcode.com/problems/redundant-connections)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0684.%20Redundant%20Connection)| Medium | O(n)| O(n)||
|[685. Redundant Connection II](https://leetcode.com/problems/redundant-connection-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0685.%20Redundant%20Connection%20II)| Hard | O(n)| O(n)||
|[721. Accounts Merge](https://leetcode.com/problems/accounts-merge)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0721.%20Accounts%20Merge)| Medium | O(n)| O(n)|❤️|
|[765. Couples Holding Hands](https://leetcode.com/problems/couples-holding-hands)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0765.%20Couples%20Holding%20Hands)| Hard | O(n)| O(n)|❤️|
|[778. Swim in Rising Water](https://leetcode.com/problems/swim-in-rising-water)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0778.%20Swim%20in%20Rising%20Water)| Hard | O(n^2)| O(n)|❤️|
|[803. Bricks Falling When Hit](https://leetcode.com/problems/bricks-falling-when-hit)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0803.%20Bricks%20Falling%20When%20Hit)| Hard | O(n^2)| O(n)|❤️|
|[839. Similar String Groups](https://leetcode.com/problems/similar-string-groups)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0839.%20Similar%20String%20Groups)| Hard | O(n^2)| O(n)||
|[924. Minimize Malware Spread](https://leetcode.com/problems/minimize-malware-spread)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0924.%20Minimize%20Malware%20Spread)| Hard | O(m\*n)| O(n)||
|[928. Minimize Malware Spread II](https://leetcode.com/problems/minimize-malware-spread-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0928.%20Minimize%20Malware%20Spread%20II)| Hard | O(m\*n)| O(n)|❤️|
|[947. Most Stones Removed with Same Row or Column](https://leetcode.com/problems/most-stones-removed-with-same-row-or-column)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0947.%20Most%20Stones%20Removed%20with%20Same%20Row%20or%20Column)| Medium | O(n)| O(n)||
|[952. Largest Component Size by Common Factor](https://leetcode.com/problems/largest-component-size-by-common-factor)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0952.%20Largest%20Component%20Size%20by%20Common%20Factor)| Hard | O(n)| O(n)|❤️|
|[959. Regions Cut By Slashes](https://leetcode.com/problems/regions-cut-by-slashes)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0959.%20Regions%20Cut%20By%20Slashes)| Medium | O(n^2)| O(n^2)|❤️|
|[990. Satisfiability of Equality Equations](https://leetcode.com/problems/satisfiability-of-equality-equations)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0990.%20Satisfiability%20of%20Equality%20Equations)| Medium | O(n)| O(n)||



