+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Stack"]
date = 2019-10-12T08:15:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/139_0.png"
slug = "stack"
tags = ["Algorithm", "Stack"]
title = "Algorithm in LeetCode —— Stack"

+++


![](https://img.halfrost.com/Blog/ArticleImage/139_1.png)

## Stack 的 Tips:

- 括号匹配问题及类似问题。第 20 题，第 921 题，第 1021 题。
- 栈的基本 pop 和 push 操作。第 71 题，第 150 题，第 155 题，第 224 题，第 225 题，第 232 题，第 946 题，第 1047 题。
- 利用栈进行编码问题。第 394 题，第 682 题，第 856 题，第 880 题。
- **单调栈**。**利用栈维护一个单调递增或者递减的下标数组**。第 84 题，第 456 题，第 496 题，第 503 题，第 739 题，第 901 题，第 907 题，第 1019 题。

| Title | Solution | Difficulty | Time | Space |收藏| 
| ----- | :--------: | :----------: | :----: | :-----: | :-----: |
|[20. Valid Parentheses](https://leetcode.com/problems/valid-parentheses)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0020.%20Valid-Parentheses)| Easy | O(log n)| O(1)||
|[42. Trapping Rain Water](https://leetcode.com/problems/trapping-rain-water)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0042.%20Trapping%20Rain%20Water)| Hard | O(n)| O(1)|❤️|
|[71. Simplify Path](https://leetcode.com/problems/simplify-path)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0071.%20Simplify%20Path)| Medium | O(n)| O(n)|❤️|
|[84. Largest Rectangle in Histogram](https://leetcode.com/problems/largest-rectangle-in-histogram)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0084.%20Largest%20Rectangle%20in%20Histogram)| Medium | O(n)| O(n)|❤️|
|[94. Binary Tree Inorder Traversal](https://leetcode.com/problems/binary-tree-inorder-traversal)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0094.%20Binary%20Tree%20Inorder%20Traversal)| Medium | O(n)| O(1)||
|[103. Binary Tree Zigzag Level Order Traversal](https://leetcode.com/problems/binary-tree-zigzag-level-order-traversal)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0103.%20Binary%20Tree%20Zigzag%20Level%20Order%20Traversal)| Medium | O(n)| O(n)||
|[144. Binary Tree Preorder Traversal](https://leetcode.com/problems/binary-tree-preorder-traversal)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0144.%20Binary%20Tree%20Preorder%20Traversal)| Medium | O(n)| O(1)||
|[145. Binary Tree Postorder Traversal](https://leetcode.com/problems/binary-tree-postorder-traversal)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0145.%20Binary%20Tree%20Postorder%20Traversal)| Hard | O(n)| O(1)||
|[150. Evaluate Reverse Polish Notation](https://leetcode.com/problems/evaluate-reverse-polish-notation)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0150.%20Evaluate%20Reverse%20Polish%20Notation)| Medium | O(n)| O(1)||
|[155. Min Stack](https://leetcode.com/problems/min-stack)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0155.%20Min%20Stack)| Easy | O(n)| O(n)||
|[173. Binary Search Tree Iterator](https://leetcode.com/problems/binary-search-tree-iterator)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0173.%20Binary%20Search%20Tree%20Iterator)| Medium | O(n)| O(1)||
|[224. Basic Calculator](https://leetcode.com/problems/basic-calculator)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0224.%20Basic%20Calculator)| Hard | O(n)| O(n)||
|[225. Implement Stack using Queues](https://leetcode.com/problems/implement-stack-using-queues)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0225.%20Implement%20Stack%20using%20Queues)| Easy | O(n)| O(n)||
|[232. Implement Queue using Stacks](https://leetcode.com/problems/implement-queue-using-stacks)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0232.%20Implement%20Queue%20using%20Stacks)| Easy | O(n)| O(n)||
|[331. Verify Preorder Serialization of a Binary Tree](https://leetcode.com/problems/verify-preorder-serialization-of-a-binary-tree)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0331.%20Verify%20Preorder%20Serialization%20of%20a%20Binary%20Tree)| Medium | O(n)| O(1)||
|[394. Decode String](https://leetcode.com/problems/decode-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0394.%20Decode%20String)| Medium | O(n)| O(n)||
|[402. Remove K Digits](https://leetcode.com/problems/remove-k-digits)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0402.%20Remove%20K%20Digits)| Medium | O(n)| O(1)||
|[456. 132 Pattern](https://leetcode.com/problems/132-pattern)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0456.%20132%20Pattern)| Medium | O(n)| O(n)||
|[496. Next Greater Element I](https://leetcode.com/problems/next-greater-element-i)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0496.%20Next%20Greater%20Element%20I)| Easy | O(n)| O(n)||
|[503. Next Greater Element II](https://leetcode.com/problems/next-greater-element-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0503.%20Next%20Greater%20Element%20II)| Medium | O(n)| O(n)||
|[636. Exclusive Time of Functions](https://leetcode.com/problems/exclusive-time-of-functions)| [Go](https://leetcode.com/problems/exclusive-time-of-functions)| Medium | O(n)| O(n)||
|[682. Baseball Game](https://leetcode.com/problems/baseball-game)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0682.%20Baseball%20Game)| Easy | O(n)| O(n)||
|[726. Number of Atoms](https://leetcode.com/problems/number-of-atoms)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0726.%20Number%20of%20Atoms)| Hard | O(n)| O(n) |❤️|
|[735. Asteroid Collision](https://leetcode.com/problems/asteroid-collision)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0735.%20Asteroid%20Collision)| Medium | O(n)| O(n) ||
|[739. Daily Temperatures](https://leetcode.com/problems/daily-temperatures)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0739.%20Daily%20Temperatures)| Medium | O(n)| O(n) ||
|[844. Backspace String Compare](https://leetcode.com/problems/backspace-string-compare)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0844.%20Backspace%20String%20Compare)| Easy | O(n)| O(n) ||
|[856. Score of Parentheses](https://leetcode.com/problems/score-of-parentheses)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0856.%20Score%20of%20Parentheses)| Medium | O(n)| O(n)||
|[880. Decoded String at Index](https://leetcode.com/problems/decoded-string-at-index)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0880.%20Decoded%20String%20at%20Index)| Medium | O(n)| O(n)||
|[895. Maximum Frequency Stack](https://leetcode.com/problems/maximum-frequency-stack)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0895.%20Maximum%20Frequency%20Stack)| Hard | O(n)| O(n)  ||
|[901. Online Stock Span](https://leetcode.com/problems/online-stock-span)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0901.%20Online%20Stock%20Span)| Medium | O(n)| O(n)  ||
|[907. Sum of Subarray Minimums](https://leetcode.com/problems/sum-of-subarray-minimums)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0907.%20Sum%20of%20Subarray%20Minimums)| Medium | O(n)| O(n)|❤️|
|[921. Minimum Add to Make Parentheses Valid](https://leetcode.com/problems/minimum-add-to-make-parentheses-valid)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0921.%20Minimum%20Add%20to%20Make%20Parentheses%20Valid)| Medium | O(n)| O(n)||
|[946. Validate Stack Sequences](https://leetcode.com/problems/validate-stack-sequences)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0946.%20Validate%20Stack%20Sequences)| Medium | O(n)| O(n)||
|[1003. Check If Word Is Valid After Substitutions](https://leetcode.com/problems/check-if-word-is-valid-after-substitutions)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1003.%20Check%20If%20Word%20Is%20Valid%20After%20Substitutions)| Medium | O(n)| O(1)||
|[1019. Next Greater Node In Linked List](https://leetcode.com/problems/next-greater-node-in-linked-list/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1019.%20Next%20Greater%20Node%20In%20Linked%20List)| Medium | O(n)| O(1)||
|[1021. Remove Outermost Parentheses](https://leetcode.com/problems/remove-outermost-parentheses)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1021.%20Remove%20Outermost%20Parentheses)| Medium | O(n)| O(1)||
|[1047. Remove All Adjacent Duplicates In String](https://leetcode.com/problems/remove-all-adjacent-duplicates-in-string)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1047.%20Remove%20All%20Adjacent%20Duplicates%20In%20String)| Medium | O(n)| O(1)||



