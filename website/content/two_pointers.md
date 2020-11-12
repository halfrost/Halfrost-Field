+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Two Pointers"]
date = 2019-09-21T10:07:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/138_0.png"
slug = "two_pointers"
tags = ["Algorithm", "Two Pointers"]
title = "Algorithm in LeetCode —— Two Pointers"

+++


![](https://img.halfrost.com/Blog/ArticleImage/138_1.png)

## Two Pointers 的 Tips:

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

- 快慢指针可以查找重复数字，时间复杂度 O(n)，第 287 题。
- 替换字母以后，相同字母能出现连续最长的长度。第 424 题。
- SUM 问题集。第 1 题，第 15 题，第 16 题，第 18 题，第 167 题，第 923 题，第 1074 题。

| Title | Solution | Difficulty | Time | Space |收藏| 
| ----- | :--------: | :----------: | :----: | :-----: | :-----: |
|[3. Longest Substring Without Repeating Characters](https://leetcode.com/problems/longest-substring-without-repeating-characters)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0003.%20Longest%20Substring%20Without%20Repeating%20Characters)| Medium | O(n)| O(1)|❤️|
|[11. Container With Most Water](https://leetcode.com/problems/container-with-most-water)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0011.%20Container%20With%20Most%20Water)| Medium | O(n)| O(1)||
|[15. 3Sum](https://leetcode.com/problems/3sum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0015.%203Sum)| Medium | O(n^2)| O(n)|❤️|
|[16. 3Sum Closest](https://leetcode.com/problems/3sum-closest)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0016.%203Sum%20Closest)| Medium | O(n^2)| O(1)|❤️|
|[18. 4Sum](https://leetcode.com/problems/4sum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0018.%204Sum)| Medium | O(n^3)| O(n^2)|❤️|
|[19. Remove Nth Node From End of List](https://leetcode.com/problems/remove-nth-node-from-end-of-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0019.%20Remove%20Nth%20Node%20From%20End%20of%20List)| Medium | O(n)| O(1)||
|[26. Remove Duplicates from Sorted Array](https://leetcode.com/problems/remove-duplicates-from-sorted-array)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0026.%20Remove%20Duplicates%20from%20Sorted%20Array)| Easy | O(n)| O(1)||
|[27. Remove Element](https://leetcode.com/problems/remove-element)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0027.%20Remove%20Element)| Easy | O(n)| O(1)||
|[28. Implement strStr()](https://leetcode.com/problems/implement-strstr)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0028.%20Implement%20strStr())| Easy | O(n)| O(1)||
|[30. Substring with Concatenation of All Words](https://leetcode.com/problems/substring-with-concatenation-of-all-words)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0030.%20Substring%20with%20Concatenation%20of%20All%20Words)| Hard | O(n)| O(n)|❤️|
|[42. Trapping Rain Water](https://leetcode.com/problems/trapping-rain-water)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0042.%20Trapping%20Rain%20Water)| Hard | O(n)| O(1)|❤️|
|[61. Rotate List](https://leetcode.com/problems/rotate-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0061.%20Rotate%20List)| Medium | O(n)| O(1)||
|[75. Sort Colors](https://leetcode.com/problems/sort-colors/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0075.%20Sort%20Colors)| Medium| O(n)| O(1)|❤️|
|[76. Minimum Window Substring](https://leetcode.com/problems/minimum-window-substring)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0076.%20Minimum%20Window%20Substring)| Hard | O(n)| O(n)|❤️|
|[80. Remove Duplicates from Sorted Array II](https://leetcode.com/problems/remove-duplicates-from-sorted-array-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0080.%20Remove%20Duplicates%20from%20Sorted%20Array%20II)| Medium | O(n)| O(1||
|[86. Partition List](https://leetcode.com/problems/partition-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0086.%20Partition%20List)| Medium | O(n)| O(1)|❤️|
|[88. Merge Sorted Array](https://leetcode.com/problems/merge-sorted-array)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0088.%20Merge-Sorted-Array)| Easy | O(n)| O(1)|❤️|
|[125. Valid Palindrome](https://leetcode.com/problems/valid-palindrome)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0125.%20Valid-Palindrome)| Easy | O(n)| O(1)||
|[141. Linked List Cycle](https://leetcode.com/problems/linked-list-cycle/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0141.%20Linked%20List%20Cycle)| Easy | O(n)| O(1)|❤️|
|[142. Linked List Cycle II](https://leetcode.com/problems/linked-list-cycle-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0142.%20Linked%20List%20Cycle%20II)| Medium | O(n)| O(1)|❤️|
|[167. Two Sum II - Input array is sorted](https://leetcode.com/problems/two-sum-ii-input-array-is-sorted)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0167.%20Two%20Sum%20II%20-%20Input%20array%20is%20sorted)| Easy | O(n)| O(1)||
|[209. Minimum Size Subarray Sum](https://leetcode.com/problems/minimum-size-subarray-sum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0209.%20Minimum%20Size%20Subarray%20Sum)| Medium | O(n)| O(1)||
|[234. Palindrome Linked List](https://leetcode.com/problems/palindrome-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0234.%20Palindrome%20Linked%20List)| Easy | O(n)| O(1)||
|[283. Move Zeroes](https://leetcode.com/problems/move-zeroes)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0283.%20Move%20Zeroes)| Easy | O(n)| O(1)||
|[287. Find the Duplicate Number](https://leetcode.com/problems/find-the-duplicate-number)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0287.%20Find%20the%20Duplicate%20Number)| Easy | O(n)| O(1)|❤️|
|[344. Reverse String](https://leetcode.com/problems/reverse-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0344.%20Reverse%20String)| Easy | O(n)| O(1)||
|[345. Reverse Vowels of a String](https://leetcode.com/problems/reverse-vowels-of-a-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0345.%20Reverse%20Vowels%20of%20a%20String)| Easy | O(n)| O(1)||
|[349. Intersection of Two Arrays](https://leetcode.com/problems/intersection-of-two-arrays/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0349.%20Intersection%20of%20Two%20Arrays)| Easy | O(n)| O(n) ||
|[350. Intersection of Two Arrays II](https://leetcode.com/problems/intersection-of-two-arrays-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0350.%20Intersection%20of%20Two%20Arrays%20II)| Easy | O(n)| O(n) ||
|[424. Longest Repeating Character Replacement](https://leetcode.com/problems/longest-repeating-character-replacement)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0424.%20Longest%20Repeating%20Character%20Replacement)| Medium | O(n)| O(1) ||
|[524. Longest Word in Dictionary through Deleting](https://leetcode.com/problems/longest-word-in-dictionary-through-deleting/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0524.%20Longest%20Word%20in%20Dictionary%20through%20Deleting)| Medium | O(n)| O(1) ||
|[532. K-diff Pairs in an Array](https://leetcode.com/problems/k-diff-pairs-in-an-array)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0532.%20K-diff%20Pairs%20in%20an%20Array)| Easy | O(n)| O(n)||
|[567. Permutation in String](https://leetcode.com/problems/permutation-in-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0567.%20Permutation%20in%20String)| Medium | O(n)| O(1)|❤️|
|[713. Subarray Product Less Than K](https://leetcode.com/problems/subarray-product-less-than-k)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0713.%20Subarray%20Product%20Less%20Than%20K)| Medium | O(n)| O(1)||
|[763. Partition Labels](https://leetcode.com/problems/partition-labels)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0763.%20Partition%20Labels)| Medium | O(n)| O(1)|❤️|
|[826. Most Profit Assigning Work](https://leetcode.com/problems/most-profit-assigning-work)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0826.%20Most%20Profit%20Assigning%20Work)| Medium | O(n log n)| O(n)||
|[828. Unique Letter String](https://leetcode.com/problems/unique-letter-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0828.%20Unique%20Letter%20String)| Hard | O(n)| O(1)|❤️|
|[838. Push Dominoes](https://leetcode.com/problems/push-dominoes)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0838.%20Push%20Dominoes)| Medium | O(n)| O(n)||
|[844. Backspace String Compare](https://leetcode.com/problems/backspace-string-compare)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0844.%20Backspace%20String%20Compare)| Easy | O(n)| O(n) ||
|[845. Longest Mountain in Array](https://leetcode.com/problems/longest-mountain-in-array)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0845.%20Longest%20Mountain%20in%20Array)| Medium | O(n)| O(1) ||
|[881. Boats to Save People](https://leetcode.com/problems/boats-to-save-people)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0881.%20Boats%20to%20Save%20People)| Medium | O(n log n)| O(1) ||
|[904. Fruit Into Baskets](https://leetcode.com/problems/fruit-into-baskets)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0904.%20Fruit%20Into%20Baskets)| Medium | O(n log n)| O(1) ||
|[923. 3Sum With Multiplicity](https://leetcode.com/problems/3sum-with-multiplicity)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0923.%203Sum%20With%20Multiplicity)| Medium | O(n^2)| O(n) ||
|[925. Long Pressed Name](https://leetcode.com/problems/long-pressed-name)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0925.%20Long%20Pressed%20Name)| Easy | O(n)| O(1)||
|[930. Binary Subarrays With Sum](https://leetcode.com/problems/binary-subarrays-with-sum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0930.%20Binary%20Subarrays%20With%20Sum)| Medium | O(n)| O(n)  |❤️|
|[977. Squares of a Sorted Array](https://leetcode.com/problems/squares-of-a-sorted-array)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0977.%20Squares%20of%20a%20Sorted%20Array)| Easy | O(n)| O(1)||
|[986. Interval List Intersections](https://leetcode.com/problems/interval-list-intersections)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0986.%20Interval%20List%20Intersections)| Medium | O(n)| O(1)||
|[992. Subarrays with K Different Integers](https://leetcode.com/problems/subarrays-with-k-different-integers)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0992.%20Subarrays%20with%20K%20Different%20Integers)| Hard | O(n)| O(n)|❤️|
|[1004. Max Consecutive Ones III](https://leetcode.com/problems/max-consecutive-ones-iii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1004.%20Max%20Consecutive%20Ones%20III)| Medium | O(n)| O(1) ||
|[1093. Statistics from a Large Sample](https://leetcode.com/problems/statistics-from-a-large-sample)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1093.%20Statistics%20from%20a%20Large%20Sample)| Medium | O(n)| O(1) ||



