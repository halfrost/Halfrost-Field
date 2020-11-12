+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Bit Manipulation"]
date = 2019-11-09T08:27:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/141_0.png"
slug = "bit_manipulation"
tags = ["Algorithm", "Bit Manipulation"]
title = "Algorithm in LeetCode —— Bit Manipulation"

+++


![](https://img.halfrost.com/Blog/ArticleImage/141_1.png)


## Bit Manipulation 的 Tips:

- 异或的特性。第 136 题，第 268 题，第 389 题，第 421 题，

```go
x ^ 0 = x
x ^ 11111……1111 = ~x
x ^ (~x) = 11111……1111
x ^ x = 0
a ^ b = c  => a ^ c = b  => b ^ c = a (交换律)
a ^ b ^ c = a ^ (b ^ c) = (a ^ b）^ c (结合律)
```

- 构造特殊 Mask，将特殊位置放 0 或 1。

```go
1. 将 x 最右边的 n 位清零， x & ( ~0 << n )
2. 获取 x 的第 n 位值(0 或者 1)，(x >> n) & 1
3. 获取 x 的第 n 位的幂值，x & (1 << (n - 1))
4. 仅将第 n 位置为 1，x | (1 << n)
5. 仅将第 n 位置为 0，x & (~(1 << n))
6. 将 x 最高位至第 n 位(含)清零，x & ((1 << n) - 1)
7. 将第 n 位至第 0 位(含)清零，x & (~((1 << (n + 1)) - 1)）
```

- 有特殊意义的 & 位操作运算。第 260 题，第 201 题，第 318 题，第 371 题，第 397 题，第 461 题，第 693 题，

```go
X & 1 == 1 判断是否是奇数(偶数)
X & = (X - 1) 将最低位(LSB)的 1 清零
X & -X 得到最低位(LSB)的 1
X & ~X = 0
```


| Title | Solution | Difficulty | Time | Space | 收藏 |
| ----- | :--------: | :----------: | :----: | :-----: |:-----: |
|[78. Subsets](https://leetcode.com/problems/subsets)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0078.%20Subsets)| Medium | O(n^2)| O(n)|❤️|
|[136. Single Number](https://leetcode.com/problems/single-number)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0136.%20Single%20Number)| Easy | O(n)| O(1)||
|[137. Single Number II](https://leetcode.com/problems/single-number-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0137.%20Single%20Number%20II)| Medium | O(n)| O(1)||
|[169. Majority Element](https://leetcode.com/problems/majority-element)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0169.%20Majority%20Element)| Easy | O(n)| O(1)|❤️|
|[187. Repeated DNA Sequences](https://leetcode.com/problems/repeated-dna-sequences)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0187.%20Repeated%20DNA%20Sequences)| Medium | O(n)| O(1)||
|[190. Reverse Bits](https://leetcode.com/problems/reverse-bits/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0190.%20Reverse%20Bits)| Easy | O(n)| O(1)||
|[191. Number of 1 Bits](https://leetcode.com/problems/number-of-1-bits/)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0191.%20Number%20of%201%20Bits)| Easy | O(n)| O(1)||
|[201. Bitwise AND of Numbers Range](https://leetcode.com/problems/bitwise-and-of-numbers-range)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0201.%20Bitwise%20AND%20of%20Numbers%20Range)| Medium | O(n)| O(1)|❤️|
|[231. Power of Two](https://leetcode.com/problems/power-of-twor)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0231.%20Power%20of%20Two)| Easy | O(1)| O(1)||
|[260. Single Number III](https://leetcode.com/problems/single-number-iii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0260.%20Single%20Number%20III)| Medium | O(n)| O(1)||
|[268. Missing Number](https://leetcode.com/problems/missing-number)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0268.%20Missing%20Number)| Easy | O(n)| O(1)||
|[318. Maximum Product of Word Lengths](https://leetcode.com/problems/maximum-product-of-word-lengths)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0318.%20Maximum%20Product%20of%20Word%20Lengths)| Medium | O(n)| O(1)||
|[338. Counting Bits](https://leetcode.com/problems/counting-bits)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0338.%20Counting%20Bits)| Medium | O(n)| O(n)||
|[342. Power of Four](https://leetcode.com/problems/power-of-four)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0342.%20Power%20of%20Four)| Easy | O(n)| O(1)||
|[371. Sum of Two Integers](https://leetcode.com/problems/sum-of-two-integers)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0371.%20Sum%20of%20Two%20Integers)| Easy | O(n)| O(1)||
|[389. Find the Difference](https://leetcode.com/problems/find-the-difference)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0389.%20Find%20the%20Difference)| Easy | O(n)| O(1)||
|[393. UTF-8 Validation](https://leetcode.com/problems/utf-8-validation)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0393.%20UTF-8%20Validation)| Medium | O(n)| O(1)||
|[397. Integer Replacement](https://leetcode.com/problems/integer-replacement)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0397.%20Integer%20Replacement)| Medium | O(n)| O(1)||
|[401. Binary Watch](https://leetcode.com/problems/binary-watch)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0401.%20Binary%20Watch)| Easy | O(1)| O(1)||
|[405. Convert a Number to Hexadecimal](https://leetcode.com/problems/convert-a-number-to-hexadecimal)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0405.%20Convert%20a%20Number%20to%20Hexadecimal)| Easy | O(n)| O(1)||
|[421. Maximum XOR of Two Numbers in an Array](https://leetcode.com/problems/maximum-xor-of-two-numbers-in-an-array)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0421.%20Maximum%20XOR%20of%20Two%20Numbers%20in%20an%20Array)| Medium | O(n)| O(1)|❤️|
|[461. Hamming Distance](https://leetcode.com/problems/hamming-distance)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0461.%20Hamming%20Distance)| Easy | O(n)| O(1)||
|[476. Number Complement](https://leetcode.com/problems/number-complement)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0476.%20Number%20Complement)| Easy | O(n)| O(1)||
|[477. Total Hamming Distance](https://leetcode.com/problems/total-hamming-distance)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0477.%20Total%20Hamming%20Distance)| Medium | O(n)| O(1)||
|[693. Binary Number with Alternating Bits](https://leetcode.com/problems/binary-number-with-alternating-bits)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0693.%20Binary%20Number%20with%20Alternating%20Bits)| Easy | O(n)| O(1)|❤️|
|[756. Pyramid Transition Matrix](https://leetcode.com/problems/pyramid-transition-matrix)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0756.%20Pyramid%20Transition%20Matrix)| Medium | O(n log n)| O(n)||
|[762. Prime Number of Set Bits in Binary Representation](https://leetcode.com/problems/prime-number-of-set-bits-in-binary-representation)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0762.%20Prime%20Number%20of%20Set%20Bits%20in%20Binary%20Representation)| Easy | O(n)| O(1)||
|[784. Letter Case Permutation](https://leetcode.com/problems/letter-case-permutation)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0784.%20Letter%20Case%20Permutation)| Easy | O(n)| O(1)||
|[898. Bitwise ORs of Subarrays](https://leetcode.com/problems/letter-case-permutation)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0784.%20Letter%20Case%20Permutation)| Easy | O(n)| O(1)||



