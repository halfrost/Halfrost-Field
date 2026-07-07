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


## Tips for Union Find:


- Apply the Union Find idea flexibly, and be familiar with the Union Find [template](https://github.com/halfrost/LeetCode-Go/blob/master/template/UnionFind.go). The template includes two implementations: one with path compression + union by rank, and another that tracks the number of elements in each set + the size of the largest set. Each version has its own applicable scenarios. Problems that can use the first Union Find template include: Problem 128, Problem 130, Problem 547, Problem 684, Problem 721, Problem 765, Problem 778, Problem 839, Problem 924, Problem 928, Problem 947, Problem 952, Problem 959, and Problem 990. Problems that can use the second Union Find template include: Problem 803 and Problem 952. In Problem 803, union by rank and set-size accounting are critical for performance; without these optimizations, it will TLE.
- Union Find is a way of thinking. Some problems require applying this idea flexibly rather than mechanically using a template. For example, Problem 399 is a stringUnionFind implemented with the Union Find idea. Here, each node is based on strings and a map, rather than simply being represented by int node IDs.
- For some problems, blindly applying the template will not work. For example, in Problem 685, you cannot use path compression or union by rank, because the problem involves a directed graph and you need to know each node’s predecessor. If paths are compressed, this problem can no longer be solved. This problem does not require path compression or union by rank.
- Flexibly abstract the information given by the problem, assign reasonable IDs to that information, solve the problem with Union Find, and use a map to reduce time complexity, as in Problem 721 and Problem 959.
- For problems involving maps, bricks, or grids, you can create a special node and union() all bricks or grid cells on the boundary into this special node. See Problem 130 and Problem 803.
- Problems that can be solved with Union Find can generally also be solved with DFS or BFS, but the time complexity will usually be higher.


| Title | Solution | Difficulty | Time | Space | Favorite |
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