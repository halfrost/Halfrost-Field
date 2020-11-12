+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Sort"]
date = 2019-09-14T10:00:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/137_0.png"
slug = "sort"
tags = ["Algorithm", "Sort"]
title = "Algorithm in LeetCode —— Sort"

+++


![](https://img.halfrost.com/Blog/ArticleImage/137_1.png)


## Sort 的 Tips:

- 深刻的理解多路快排。第 75 题。
- 链表的排序，插入排序(第 147 题)和归并排序(第 148 题)
- 桶排序和基数排序。第 164 题。
- "摆动排序"。第 324 题。
- 两两不相邻的排序。第 767 题，第 1054 题。
- "饼子排序"。第 969 题。

| Title | Solution | Difficulty | Time | Space | 收藏 |
| ----- | -------- | ---------- | ---- | ----- |----- |
[56. Merge Intervals](https://leetcode.com/problems/merge-intervals/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0056.%20Merge%20Intervals)| Medium | O(n log n)| O(log n)||
[57. Insert Interval](https://leetcode.com/problems/insert-interval/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0057.%20Insert%20Interval)| Hard | O(n)| O(1)||
[75. Sort Colors](https://leetcode.com/problems/sort-colors/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0075.%20Sort%20Colors)| Medium| O(n)| O(1)|❤️|
[147. Insertion Sort List](https://leetcode.com/problems/insertion-sort-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0147.%20Insertion%20Sort%20List)| Medium | O(n)| O(1) |❤️|
[148. Sort List](https://leetcode.com/problems/sort-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0148.%20Sort%20List)| Medium |O(n log n)| O(log n)|❤️|
[164. Maximum Gap](https://leetcode.com/problems/maximum-gap/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0164.%20Maximum%20Gap)| Hard | O(n log n)| O(log n) |❤️|
[179. Largest Number](https://leetcode.com/problems/largest-number/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0179.%20Largest%20Number)| Medium | O(n log n)| O(log n) |❤️|
[220. Contains Duplicate III](https://leetcode.com/problems/contains-duplicate-iii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0220.%20Contains%20Duplicate%20III)| Medium | O(n^2)| O(1) ||
[242. Valid Anagram](https://leetcode.com/problems/valid-anagram/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0242.%20Valid%20Anagram)| Easy | O(n)| O(n) ||
[274. H-Index](https://leetcode.com/problems/h-index/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0274.%20H-Index)| Medium |  O(n)| O(n) ||
[324. Wiggle Sort II](https://leetcode.com/problems/wiggle-sort-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0324.%20Wiggle%20Sort%20II)| Medium| O(n)| O(n)|❤️|
[349. Intersection of Two Arrays](https://leetcode.com/problems/intersection-of-two-arrays/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0349.%20Intersection%20of%20Two%20Arrays)| Easy | O(n)| O(n) ||
[350. Intersection of Two Arrays II](https://leetcode.com/problems/intersection-of-two-arrays-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0350.%20Intersection%20of%20Two%20Arrays%20II)| Easy | O(n)| O(n) ||
[524. Longest Word in Dictionary through Deleting](https://leetcode.com/problems/longest-word-in-dictionary-through-deleting/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0524.%20Longest%20Word%20in%20Dictionary%20through%20Deleting)| Medium | O(n)| O(1) ||
[767. Reorganize String](https://leetcode.com/problems/reorganize-string/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0767.%20Reorganize%20String)| Medium | O(n log n)| O(log n)  |❤️|
[853. Car Fleet](https://leetcode.com/problems/car-fleet/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0853.%20Car%20Fleet)| Medium | O(n log n)| O(log n)  ||
[710. Random Pick with Blacklist](https://leetcode.com/problems/random-pick-with-blacklist/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0710.%20Random%20Pick%20with%20Blacklist)| Hard | O(n)| O(n)  ||
[922. Sort Array By Parity II](https://leetcode.com/problems/sort-array-by-parity-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0922.%20Sort%20Array%20By%20Parity%20II)| Easy | O(n)| O(1) ||
[969. Pancake Sorting](https://leetcode.com/problems/pancake-sorting/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0969.%20Pancake%20Sorting)| Medium | O(n log n)| O(log n) |❤️|
[973. K Closest Points to Origin](https://leetcode.com/problems/k-closest-points-to-origin/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0973.%20K%20Closest%20Points%20to%20Origin)| Medium | O(n log n)| O(log n) ||
[976. Largest Perimeter Triangle](https://leetcode.com/problems/largest-perimeter-triangle/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0976.%20Largest%20Perimeter%20Triangle)| Easy | O(n log n)| O(log n) ||
[1030. Matrix Cells in Distance Order](https://leetcode.com/problems/matrix-cells-in-distance-order/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1030.%20Matrix%20Cells%20in%20Distance%20Order)| Easy | O(n^2)| O(1) ||
[1054. Distant Barcodes](https://leetcode.com/problems/distant-barcodes/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1054.%20Distant%20Barcodes)| Medium | O(n log n)| O(log n) ||



