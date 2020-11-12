+++
author = "一缕殇流化隐半边冰霜"
categories = ["Algorithm", "Backtracking"]
date = 2019-10-19T08:20:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/140_0.png"
slug = "backtracking"
tags = ["Algorithm", "Backtracking"]
title = "Algorithm in LeetCode —— Backtracking"

+++


![](https://img.halfrost.com/Blog/ArticleImage/140_1.png)

## Backtracking 的 Tips:

- 排列问题 Permutations。第 46 题，第 47 题。第 60 题，第 526 题，第 996 题。
- 组合问题 Combination。第 39 题，第 40 题，第 77 题，第 216 题。
- 排列和组合杂交问题。第 1079 题。
- N 皇后终极解法(二进制解法)。第 51 题，第 52 题。
- 数独问题。第 37 题。
- 四个方向搜索。第 79 题，第 212 题，第 980 题。
- 子集合问题。第 78 题，第 90 题。
- Trie。第 208 题，第 211 题。
- BFS 优化。第 126 题，第 127 题。
- DFS 模板。(只是一个例子，不对应任何题)

```go
func combinationSum2(candidates []int, target int) [][]int {
	if len(candidates) == 0 {
		return [][]int{}
	}
	c, res := []int{}, [][]int{}
	sort.Ints(candidates)
	findcombinationSum2(candidates, target, 0, c, &res)
	return res
}

func findcombinationSum2(nums []int, target, index int, c []int, res *[][]int) {
	if target == 0 {
		b := make([]int, len(c))
		copy(b, c)
		*res = append(*res, b)
		return
	}
	for i := index; i < len(nums); i++ {
		if i > index && nums[i] == nums[i-1] { // 这里是去重的关键逻辑
			continue
		}
		if target >= nums[i] {
			c = append(c, nums[i])
			findcombinationSum2(nums, target-nums[i], i+1, c, res)
			c = c[:len(c)-1]
		}
	}
}
```
- BFS 模板。(只是一个例子，不对应任何题)

```go
func updateMatrix_BFS(matrix [][]int) [][]int {
	res := make([][]int, len(matrix))
	if len(matrix) == 0 || len(matrix[0]) == 0 {
		return res
	}
	queue := make([][]int, 0)
	for i, _ := range matrix {
		res[i] = make([]int, len(matrix[0]))
		for j, _ := range res[i] {
			if matrix[i][j] == 0 {
				res[i][j] = -1
				queue = append(queue, []int{i, j})
			}
		}
	}
	level := 1
	for len(queue) > 0 {
		size := len(queue)
		for size > 0 {
			size -= 1
			node := queue[0]
			queue = queue[1:]
			i, j := node[0], node[1]
			for _, direction := range [][]int{{-1, 0}, {1, 0}, {0, 1}, {0, -1}} {
				x := i + direction[0]
				y := j + direction[1]
				if x < 0 || x >= len(matrix) || y < 0 || y >= len(matrix[0]) || res[x][y] < 0 || res[x][y] > 0 {
					continue
				}
				res[x][y] = level
				queue = append(queue, []int{x, y})
			}
		}
		level++
	}
	for i, row := range res {
		for j, cell := range row {
			if cell == -1 {
				res[i][j] = 0
			}
		}
	}
	return res
}
```

| Title | Solution | Difficulty | Time | Space |收藏| 
| ----- | :--------: | :----------: | :----: | :-----: | :-----: |
|[17. Letter Combinations of a Phone Number](https://leetcode.com/problems/letter-combinations-of-a-phone-number)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0017.%20Letter%20Combinations%20of%20a%20Phone%20Number)| Medium | O(log n)| O(1)||
|[22. Generate Parentheses](https://leetcode.com/problems/generate-parentheses)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0022.%20Generate%20Parentheses)| Medium | O(log n)| O(1)||
|[37. Sudoku Solver](https://leetcode.com/problems/sudoku-solver)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0037.%20Sudoku%20Solver)| Hard | O(n^2)| O(n^2)|❤️|
|[39. Combination Sum](https://leetcode.com/problems/combination-sum)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0039.%20Combination%20Sum)| Medium | O(n log n)| O(n)||
|[40. Combination Sum II](https://leetcode.com/problems/combination-sum-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0040.%20Combination%20Sum%20II)| Medium | O(n log n)| O(n)||
|[46. Permutations](https://leetcode.com/problems/permutations)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0046.%20Permutations)| Medium | O(n)| O(n)|❤️|
|[47. Permutations II](https://leetcode.com/problems/permutations-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0047.%20Permutations%20II)| Medium | O(n^2)| O(n)|❤️|
|[51. N-Queens](https://leetcode.com/problems/n-queens)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0051.%20N-Queens)| Hard | O(n^2)| O(n)|❤️|
|[52. N-Queens II](https://leetcode.com/problems/n-queens-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0052.%20N-Queens%20II)| Hard | O(n^2)| O(n)|❤️|
|[60. Permutation Sequence](https://leetcode.com/problems/permutation-sequence)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0060.%20Permutation%20Sequence)| Medium | O(n log n)| O(1)||
|[77. Combinations](https://leetcode.com/problems/combinations)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0077.%20Combinations)| Medium | O(n)| O(n)|❤️|
|[78. Subsets](https://leetcode.com/problems/subsets)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0078.%20Subsets)| Medium | O(n^2)| O(n)|❤️|
|[79. Word Search](https://leetcode.com/problems/word-search)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0079.%20Word%20Search)| Medium | O(n^2)| O(n^2)|❤️|
|[89. Gray Codes](https://leetcode.com/problems/gray-code)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0089.%20Gray%20Code)| Medium | O(n)| O(1)||
|[90. Subsets II](https://leetcode.com/problems/subsets-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0090.%20Subsets%20II)| Medium | O(n^2)| O(n)|❤️|
|[93. Restore IP Addresses](https://leetcode.com/problems/restore-ip-addresses)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0093.%20Restore%20IP%20Addresses)| Medium | O(n)| O(n)|❤️|
|[126. Word Ladder II](https://leetcode.com/problems/word-ladder-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0126.%20Word%20Ladder%20II)| Hard | O(n)| O(n^2)|❤️|
|[131. Palindrome Partitioning](https://leetcode.com/problems/palindrome-partitioning)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0131.%20Palindrome%20Partitioning)| Medium | O(n)| O(n^2)|❤️|
|[211. Add and Search Word - Data structure design](https://leetcode.com/problems/add-and-search-word-data-structure-design)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0211.%20Add%20and%20Search%20Word%20-%20Data%20structure%20design)| Medium | O(n)| O(n)|❤️|
|[212. Word Search II](https://leetcode.com/problems/word-search-ii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0212.%20Word%20Search%20II)| Hard | O(n^2)| O(n^2)|❤️|
|[216. Combination Sum III](https://leetcode.com/problems/combination-sum-iii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0216.%20Combination%20Sum%20III)| Medium | O(n)| O(1)|❤️|
|[306. Additive Number](https://leetcode.com/problems/additive-number)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0306.%20Additive%20Number)| Medium | O(n^2)| O(1)|❤️|
|[357. Count Numbers with Unique Digits](https://leetcode.com/problems/count-numbers-with-unique-digits)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0357.%20Count%20Numbers%20with%20Unique%20Digits)| Medium | O(1)| O(1)||
|[401. Binary Watch](https://leetcode.com/problems/binary-watch)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0401.%20Binary%20Watch)| Easy | O(1)| O(1)||
|[526. Beautiful Arrangement](https://leetcode.com/problems/beautiful-arrangement)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0526.%20Beautiful%20Arrangement)| Medium | O(n^2)| O(1)|❤️|
|[784. Letter Case Permutation](https://leetcode.com/problems/letter-case-permutation)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0784.%20Letter%20Case%20Permutation)| Easy | O(n)| O(n)||
|[842. Split Array into Fibonacci Sequence](https://leetcode.com/problems/split-array-into-fibonacci-sequence)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0842.%20Split%20Array%20into%20Fibonacci%20Sequence)| Medium | O(n^2)| O(1)|❤️|
|[980. Unique Paths III](https://leetcode.com/problems/unique-paths-iii)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0980.%20Unique%20Paths%20III)| Hard | O(n log n)| O(n)||
|[996. Number of Squareful Arrays](https://leetcode.com/problems/number-of-squareful-arrays)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/0996.%20Number%20of%20Squareful%20Arrays)| Hard | O(n log n)| O(n) ||
|[1079. Letter Tile Possibilities](https://leetcode.com/problems/letter-tile-possibilities)| [Go](https://github.com/halfrost/LeetCode-Go/tree/master/Algorithms/1079.%20Letter%20Tile%20Possibilities)| Medium | O(n^2)| O(1)|❤️|



