# 神奇的德布鲁因序列


数学中存在这样一个序列，它充满魔力，在实际工程中也有一部分的应用。今天就打算分享一下这个序列，它在 Google S2 中是如何使用的以及它在图论中，其他领域中的应用。这个序列就是德布鲁因序列 De Bruijn。

## 从一个魔术开始说起

有这样一个扑克牌魔术

你有没有看过这样一个扑克牌魔术：魔术师在五六个人好奇的注视下，拿来一叠扑克牌，说：“首先大家检查一下这叠牌是不是不同的花色和点数。”然后对一位观众说：“您可以从这叠牌的上方拿任意数量的牌放到这叠牌的下方（专业一点可以称作切一下牌）。”第一位观众照做之后，把这叠牌递给旁边的人，旁边人同样切一下牌之后，再递给下一个人，轮到最后一个人切完牌的时候，这副牌的顺序已经被完全打乱了。

接下来魔术师会让最后一个人拿走此时这叠牌最上面的一张，再把这叠牌给旁边的人，同样拿走最上面的一张，最后每个人手中都有一张牌。然后魔术师会说：“我看不到你们任何一个人的牌，但现在用意念已经知道你们每个人手中的牌是什么了。”很多人心里一定会想：这也太神奇了吧？魔术师又说：“首先请手中是黑色牌的童鞋站起来。”紧接着他就开始一一说出每个人手中的牌是什么：“你的是黑桃5，你的是梅花8……对于剩下手中是红色牌的童鞋，你的是红桃3，你的是方片……”最后把每个人的牌翻开一看，全部命中，无一错误。




## 德布鲁因序列的性质


## 在图论中的应用：欧拉环 和 汉密尔顿回路



## 位运算




------------------------------------------------------

空间搜索系列文章：

[如何理解 n 维空间和 n 维时空](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[高效的多维空间点索引算法 — Geohash 和 Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_spatial_search.md)  
[Google S2 中的四叉树求 LCA 最近公共祖先](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_lowest_common_ancestor.md)  
[神奇的德布鲁因序列](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Go/go_s2_De_Bruijn.md)


最后，多多练习，多多实践 Go，只要功夫深，铁杵磨成针！


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_De\_Bruijn/](https://halfrost.com/go_s2_De_Bruijn/)