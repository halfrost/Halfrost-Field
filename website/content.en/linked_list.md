+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Linked List"]
date = 2019-08-18T07:47:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/136_0.png"
slug = "linked_list"
tags = ["Algorithm", "Linked List"]
title = "Algorithm in LeetCode —— Linked List"

+++


![](https://img.halfrost.com/Blog/ArticleImage/136_1.png)


## Tips for Linked Lists:

- Cleverly introduce a dummy head node. This can make traversal and processing logic more uniform.
- Use recursion flexibly. By defining the right recursive conditions, recursion can solve certain problems elegantly. However, note that some problems should not be solved recursively, because excessive recursion depth can lead to timeouts and stack overflows.
- Reverse a range within a linked list. Problem 92.
- Find the middle node of a linked list. Problem 876. Find the nth node from the end of a linked list. Problem 19. The answer can be obtained with just one traversal.
- Merge K sorted linked lists. Problems 21 and 23.
- Classify linked list nodes. Problems 86 and 328.
- Sort a linked list with required time complexity O(n * log n) and space complexity O(1). There is only one approach: merge sort, using top-down merging. Problem 148.
- Determine whether a linked list has a cycle; if it does, output the index of the intersection point of the cycle. Determine whether two linked lists intersect; if they do, output the intersection point. Problems 141, 142, and 160.

  
    
    

| Title | Solution | Difficulty | Time | Space | Favorites | 
| ----- | -------- | ---------- | ---- | ----- | ----- |
[2. Add Two Numbers](https://leetcode.com/problems/add-two-numbers)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0002.%20Add-Two-Number)| Medium | O(n)| O(1)||
[19. Remove Nth Node From End of List](https://leetcode.com/problems/remove-nth-node-from-end-of-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0019.%20Remove%20Nth%20Node%20From%20End%20of%20List)| Medium | O(n)| O(1)||
[21. Merge Two Sorted Lists](https://leetcode.com/problems/merge-two-sorted-lists)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0021.%20Merge%20Two%20Sorted%20Lists)| Easy | O(log n)| O(1)||
[23. Merge k Sorted Lists](https://leetcode.com/problems/merge-k-sorted-lists/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0023.%20Merge%20k%20Sorted%20Lists)| Hard | O(log n)| O(1)|❤️|
[24. Swap Nodes in Pairs](https://leetcode.com/problems/swap-nodes-in-pairs/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0024.%20Swap%20Nodes%20in%20Pairs)| Medium | O(n)| O(1)||
[25. Reverse Nodes in k-Group](https://leetcode.com/problems/reverse-nodes-in-k-group/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0025.%20Reverse%20Nodes%20in%20k%20Group)| Hard | O(log n)| O(1)|❤️|
[61. Rotate List](https://leetcode.com/problems/rotate-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0061.%20Rotate%20List)| Medium | O(n)| O(1)||
[82. Remove Duplicates from Sorted List II](https://leetcode.com/problems/remove-duplicates-from-sorted-list-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0082.%20Remove%20Duplicates%20from%20Sorted%20List%20II)| Medium | O(n)| O(1)||
[83. Remove Duplicates from Sorted List](https://leetcode.com/problems/remove-duplicates-from-sorted-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0083.%20Remove%20Duplicates%20from%20Sorted%20List)| Easy | O(n)| O(1)||
[86. Partition List](https://leetcode.com/problems/partition-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0086.%20Partition%20List)| Medium | O(n)| O(1)|❤️|
[92. Reverse Linked List II](https://leetcode.com/problems/reverse-linked-list-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0092.%20Reverse%20Linked%20List%20II)| Medium | O(n)| O(1)|❤️|
[109. Convert Sorted List to Binary Search Tree](https://leetcode.com/problems/convert-sorted-list-to-binary-search-tree/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0109.%20Convert%20Sorted%20List%20to%20Binary%20Search%20Tree)| Medium | O(log n)| O(n)||
[141. Linked List Cycle](https://leetcode.com/problems/linked-list-cycle/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0141.%20Linked%20List%20Cycle)| Easy | O(n)| O(1)|❤️|
[142. Linked List Cycle II](https://leetcode.com/problems/linked-list-cycle-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0142.%20Linked%20List%20Cycle%20II)| Medium | O(n)| O(1)|❤️|
[143. Reorder List](https://leetcode.com/problems/reorder-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0143.%20Reorder%20List)| Medium | O(n)| O(1)|❤️|
[147. Insertion Sort List](https://leetcode.com/problems/insertion-sort-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0147.%20Insertion%20Sort%20List)| Medium | O(n)| O(1)||
[148. Sort List](https://leetcode.com/problems/sort-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0148.%20Sort%20List)| Medium | O(log n)| O(n)|❤️|
[160. Intersection of Two Linked Lists](https://leetcode.com/problems/intersection-of-two-linked-lists/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0160.%20Intersection%20of%20Two%20Linked%20Lists)| Easy | O(n)| O(1)|❤️|
[203. Remove Linked List Elements](https://leetcode.com/problems/remove-linked-list-elements/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0203.%20Remove%20Linked%20List%20Elements)| Easy | O(n)| O(1)||
[206. Reverse Linked List](https://leetcode.com/problems/reverse-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0206.%20Reverse-Linked-List)| Easy | O(n)| O(1)||
[234. Palindrome Linked List](https://leetcode.com/problems/palindrome-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0234.%20Palindrome%20Linked%20List)| Easy | O(n)| O(1)||
[237. Delete Node in a Linked List](https://leetcode.com/problems/delete-node-in-a-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0237.%20Delete%20Node%20in%20a%20Linked%20List)| Easy | O(n)| O(1)||
[328. Odd Even Linked List](https://leetcode.com/problems/odd-even-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0328.%20Odd%20Even%20Linked%20List)| Medium | O(n)| O(1)||
[445. Add Two Numbers II](https://leetcode.com/problems/add-two-numbers-ii/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0445.%20Add%20Two%20Numbers%20II)| Medium | O(n)| O(n)||
[725. Split Linked List in Parts](https://leetcode.com/problems/split-linked-list-in-parts/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0725.%20Split%20Linked%20List%20in%20Parts)| Medium | O(n)| O(1)||
[817. Linked List Components](https://leetcode.com/problems/linked-list-components/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0817.%20Linked%20List%20Components)| Medium | O(n)| O(1)||
[707. Design Linked List](https://leetcode.com/problems/design-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0707.%20Design%20Linked%20List)| Easy | O(n)| O(1)||
[876. Middle of the Linked List](https://leetcode.com/problems/middle-of-the-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0876.%20Middle%20of%20the%20Linked%20List)| Easy | O(n)| O(1)|❤️|
[1019. Next Greater Node In Linked List](https://leetcode.com/problems/next-greater-node-in-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1019.%20Next%20Greater%20Node%20In%20Linked%20List)| Medium | O(n)| O(1)||


