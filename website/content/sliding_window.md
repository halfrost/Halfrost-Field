+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Sliding Window"]
date = 2019-12-14T11:46:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/143_0.png"
slug = "sliding_window"
tags = ["Algorithm", "Sliding Window"]
title = "Algorithm in LeetCode —— Sliding Window"

+++


![](https://img.halfrost.com/Blog/ArticleImage/143_1.png)




## Sliding Window 的 Tips:

- 双指针滑动窗口的经典写法。右指针不断往右移，移动到不能往右移动为止(具体条件根据题目而定)。当右指针到最右边以后，开始挪动左指针，释放窗口左边界。第 3 题，第 76 题，第 209 题，第 424 题，第 438 题，第 567 题，第 713 题，第 763 题，第 845 题，第 881 题，第 904 题，第 978 题，第 992 题，第 1004 题，第 1040 题，第 1052 题。

```c
	left, right := 0, -1

	for left < len(s) {
		if right+1 < len(s) && freq[s[right+1]-'a'] == 0 {
			freq[s[right+1]-'a']++
			right++
		} else {
			freq[s[left]-'a']--
			left++
		}
		result = max(result, right-left+1)
	}
```
- 滑动窗口经典题。第 239 题，第 480 题。

| Title | Solution | Difficulty | Time | Space | 收藏 |
| ----- | :--------: | :----------: | :----: | :-----: |:-----: |
|[3. Longest Substring Without Repeating Characters](https://leetcode.com/problems/longest-substring-without-repeating-characters)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0003.%20Longest%20Substring%20Without%20Repeating%20Characters)| Medium | O(n)| O(1)|❤️|
|[76. Minimum Window Substring](https://leetcode.com/problems/minimum-window-substring)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0076.%20Minimum%20Window%20Substring)| Hard | O(n)| O(n)|❤️|
|[239. Sliding Window Maximum](https://leetcode.com/problems/sliding-window-maximum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0239.%20Sliding%20Window%20Maximum)| Hard | O(n * k)| O(n)|❤️|
|[424. Longest Repeating Character Replacement](https://leetcode.com/problems/longest-repeating-character-replacement)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0424.%20Longest%20Repeating%20Character%20Replacement)| Medium | O(n)| O(1) ||
|[480. Sliding Window Median](https://leetcode.com/problems/sliding-window-median)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0480.%20Sliding%20Window%20Median)| Hard | O(n * log k)| O(k)|❤️|
|[567. Permutation in String](https://leetcode.com/problems/permutation-in-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0567.%20Permutation%20in%20String)| Medium | O(n)| O(1)|❤️|
|[978. Longest Turbulent Subarray](https://leetcode.com/problems/longest-turbulent-subarray)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0978.%20Longest%20Turbulent%20Subarray)| Medium | O(n)| O(1)|❤️|
|[992. Subarrays with K Different Integers](https://leetcode.com/problems/subarrays-with-k-different-integers)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0992.%20Subarrays%20with%20K%20Different%20Integers)| Hard | O(n)| O(n)|❤️|
|[995. Minimum Number of K Consecutive Bit Flips](https://leetcode.com/problems/minimum-number-of-k-consecutive-bit-flips)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0995.%20Minimum%20Number%20of%20K%20Consecutive%20Bit%20Flips)| Hard | O(n)| O(1)|❤️|
|[1004. Max Consecutive Ones III](https://leetcode.com/problems/max-consecutive-ones-iii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1004.%20Max%20Consecutive%20Ones%20III)| Medium | O(n)| O(1) ||
|[1040. Moving Stones Until Consecutive II](https://leetcode.com/problems/moving-stones-until-consecutive-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1040.%20Moving%20Stones%20Until%20Consecutive%20II)| Medium | O(n log n)| O(1) |❤️|
|[1052. Grumpy Bookstore Owner](https://leetcode.com/problems/grumpy-bookstore-owner)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1052.%20Grumpy%20Bookstore%20Owner)| Medium | O(n log n)| O(1) ||
|[1074. Number of Submatrices That Sum to Target](https://leetcode.com/problems/number-of-submatrices-that-sum-to-target)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1074.%20Number%20of%20Submatrices%20That%20Sum%20to%20Target)| Hard | O(n^3)| O(n) |❤️|



