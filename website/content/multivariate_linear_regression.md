+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-20T07:47:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/69_4.png"
slug = "multivariate_linear_regression"
tags = ["Machine Learning", "AI"]
title = "多元线性回归"

+++


>由于 Ghost 博客对 LateX 的识别语法和标准的 LateX 语法有差异，为了更加通用性，所以以下文章中 LateX 公式可能出现乱码，如果出现乱码，不嫌弃的话可以在笔者的 [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md) 上看这篇无乱码的文章。笔者有空会修复这个乱码问题的。请见谅。
>
> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Multivariate\_Linear\_Regression.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Multivariate_Linear_Regression.ipynb)

## 一. Multiple Features

具有多个变量的线性回归也被称为“多元线性回归”。

$x_{j}^{(i)}$: 训练集第 i 个向量中的第 j 个元素(第 i 行第 j 列)  
$x^{(i)}$: 训练集第 i 个向量(第 i 行)  
$ m $: 总共 m 行  
$ n $: 总共 n 列  


适应这些多特征的假设函数的多变量形式如下：

$$ h_{\theta}(x) = \theta_{0} + \theta_{1}x_{1} + \theta_{2}x_{2} + \theta_{3}x_{3} + \cdots + \theta_{n}x_{n} $$

使用矩阵乘法的定义，我们的多变量假设函数可以简洁地表示为：

$$ h_{\theta}(x) = \begin{bmatrix}
\theta_{0} & \theta_{1} & \cdots  & \theta_{n}
\end{bmatrix} \begin{bmatrix}
x_{0}\\ 
x_{1}\\ 
 \vdots \\ 
x_{n}
\end{bmatrix} = \theta^{T}x$$

其中 $ x_{0}^{(i)} = 1 (i\in 1,\cdots,m)$


------------------------------------------------------

## 二. Gradient Descent for Multiple Variables

多个变量的梯度下降，同时更新 n 个变量。

$$ \theta_{j} := \theta_{j} - \alpha \frac{1}{m} \sum_{i=1}^{m}(h_{\theta}(x^{(i)})-y^{(i)})x^{(i)}_{j}$$

其中 $ j \in [0,n]$




------------------------------------------------------


## 三. Gradient Descent in Practice I - Feature Scaling

特征缩放包括将输入值除以输入变量的范围（即最大值减去最小值），导致新的范围仅为1。

均值归一化包括从输入变量的值中减去输入变量的平均值，从而导致输入变量的新平均值为零。

### 1. Feature Scaling

特征缩放让特征值取值范围都比较一致，这样在执行梯度下降的时候，“下山的路线”会更加简单，更快的收敛。通常进行特征缩放都会把特征值缩尽量缩放到 [-1,1] 之间**或者这个区间附近**。

即 $ x_{i} = \frac{x_{i}}{s_{i}}$

### 2. Mean normalization

$ x_{i} = \frac{x_{i} - \mu_{i}}{s_{i}}$

其中，$\mu_{i}$ 是特征值的所有值的平均值，$s_{i}$ 是值的范围（最大 - 最小），或者 $s_{i}$ 是标准偏差

当然 $x_{0} = 1$ 就不需要经过上述的处理了，因为它永远等于1，不能有均值等于0的情况。



------------------------------------------------------

## 四. Gradient Descent in Practice II - Learning Rate

如果学习率 $\alpha $ 太小的话，就会导致收敛速度过慢的问题。
如果学习率 $\alpha $ 太大的话，代价函数可能不会在每次迭代中都下降，甚至可能不收敛，在某种情况下，学习率 $\alpha $ 过大，也有可能出现收敛缓慢。

可以通过绘制代价函数随迭代步数变化的曲线去调试这个问题。

$\alpha $ 的取值可以从 0.001，0.003，0.01，0.03，0.1，0.3，1 这几个值去尝试，选一个最优的。



------------------------------------------------------

## 五. Features and Polynomial Regression


可以通过改造特征值，例如合并2个特征，用 $ x_{3}$ 来表示 $ x_{1} * x_{2} $

在多项式回归中，针对 $ h_{\theta}(x) = \theta_{0} + \theta_{1}x_{1} + \theta_{2}x_{1}^{2} + \theta_{3}x_{1}^{3} $ ，我们可以令 $ x_{2} = x_{1}^{2} , x_{3} = x_{1}^{3} $ 降低次数。

还可以考虑用根号的式子，例如选用  $ h_{\theta}(x) = \theta_{0} + \theta_{1}x_{1} + \theta_{2}\sqrt{x} $

通过上述转换以后，需要记得用**特征值缩放，均值归一化，调整学习速率的方式调整一下**。


------------------------------------------------------

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Multivariate\_Linear\_Regression.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Multivariate_Linear_Regression.ipynb)

