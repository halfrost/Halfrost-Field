+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-21T07:50:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/69_9_.png"
slug = "computing_parameters_analytically"
tags = ["Machine Learning", "AI"]
title = "计算参数分析 —— 正规方程法"

+++


>由于 Ghost 博客对 LateX 的识别语法和标准的 LateX 语法有差异，为了更加通用性，所以以下文章中 LateX 公式可能出现乱码，如果出现乱码，不嫌弃的话可以在笔者的 [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md) 上看这篇无乱码的文章。笔者有空会修复这个乱码问题的。请见谅。
>
> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Computing\_Parameters\_Analytically.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Computing_Parameters_Analytically.ipynb)

## 一. Normal Equation

### 1. 正规方程

正规方程法相对梯度下降法，它可以一步找到最小值。而且它也不需要进行特征值的缩放。

样本集是 $ m * n $ 的矩阵，每行样本表示为 $ \vec{x^{(i)}} $ ,第 i 行第 n 列分别表示为 $ x^{(i)}_{0} , x^{(i)}_{1} , x^{(i)}_{2} , x^{(i)}_{3} \cdots x^{(i)}_{n} $, m 行向量分别表示为 $ \vec{x^{(1)}} , \vec{x^{(2)}} , \vec{x^{(3)}} , \cdots \vec{x^{(m)}} $

令 

$$ \vec{x^{(i)}} = \begin{bmatrix} x^{(i)}_{0}\\ x^{(i)}_{1}\\ \vdots \\ x^{(i)}_{n}\\ \end{bmatrix} $$

$ \vec{x^{(i)}} $ 是这样一个 $(n+1)*1$ 维向量。每行都对应着 i 行 0-n 个变量。

再构造几个矩阵：

$$ X = \begin{bmatrix} (\vec{x^{(1)}})^{T}\\  \vdots \\  (\vec{x^{(m)}})^{T} \end{bmatrix} \;\;\;\;
\Theta = \begin{bmatrix} \theta_{0}\\ \theta_{1}\\ \vdots \\ \theta_{n}\\ \end{bmatrix} \;\;\;\;
Y = \begin{bmatrix} y^{(1)}\\ y^{(2)}\\ \vdots \\ y^{(m)}\\ \end{bmatrix} 
$$

X 是一个 $ m * (n+1)$ 的矩阵，$ \Theta $ 是一个 $ (n+1) * 1$ 的向量，Y 是一个 $ m * 1$的矩阵。

对比之前代价函数中，$$ \rm{CostFunction} = \rm{F}({\theta_{0}},{\theta_{1}}) = \frac{1}{2m}\sum_{i = 1}^{m} (h_{\theta}(x^{(i)})-y^{(i)})^2 $$  

$$
\begin{align*}
X \cdot \Theta - Y = 
\begin{bmatrix}
(\vec{x^{(1)}})^{T}\\ 
\vdots \\ 
(\vec{x^{(m)}})^{T}
\end{bmatrix} \cdot 
\begin{bmatrix} 
\theta_{0}\\ 
\theta_{1}\\ 
\vdots \\ 
\theta_{n}\\ 
\end{bmatrix} - 
\begin{bmatrix} 
y^{(1)}\\ 
y^{(2)}\\ 
\vdots \\ 
y^{(m)}\\ 
\end{bmatrix} = 
\begin{bmatrix} 
h_{\theta}(x^{(1)})-y^{(1)}\\ 
h_{\theta}(x^{(2)})-y^{(2)}\\ 
\vdots \\ 
h_{\theta}(x^{(m)})-y^{(m)}\\ 
\end{bmatrix}
\end{align*}$$


代入到之前代价函数中，
$$ 
\begin{align*}
\rm{CostFunction} = \rm{F}({\theta_{0}},{\theta_{1}}) &= \frac{1}{2m}\sum_{i = 1}^{m} (h_{\theta}(x^{(i)})-y^{(i)})^2\\
& = \frac{1}{2m} (X \cdot \Theta - Y)^{T}(X \cdot \Theta - Y)\\
\end{align*}
$$  


  
----------------------------------------------------------------------------------------------------------------



### 2. 矩阵的微分和矩阵的迹

接下来在进行推导之前，需要引入矩阵迹的概念，因为迹是求解一阶矩阵微分的工具。

矩阵迹的定义是 

$$ \rm{tr} A =  \sum_{i=1}^{n}A_{ii}$$ 

简单的说就是左上角到右下角对角线上元素的和。

接下来有几个性质在下面推导过程中需要用到：

1. $ \rm{tr}\;a = a $ ， a 是标量 ( $ a \in \mathbb{R} $)  

2. $ \rm{tr}\;AB = \rm{tr}\;BA $ 更近一步 $ \rm{tr}\;ABC = \rm{tr}\;CAB = \rm{tr}\;BCA $  
    证明：假设 A 是 $n * m$ 矩阵， B 是 $m * n$ 矩阵，则有
    $$ \rm{tr}\;AB = \sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji} = \sum_{j=1}^{n} \sum_{i=1}^{m}B_{ji}A_{ij}= \rm{tr}\;BA $$
    同理：$$ \rm{tr}\;ABC = \rm{tr}\;(AB)C = \rm{tr}\;C(AB) = \rm{tr}\;CAB$$
    $$ \rm{tr}\;ABC = \rm{tr}\;A(BC) = \rm{tr}\;(BC)A = \rm{tr}\;BCA$$
    连起来，即 $$ \rm{tr}\;ABC = \rm{tr}\;CAB = \rm{tr}\;BCA $$

3. $ \triangledown_{A}\rm{tr}\;AB = \triangledown_{A}\rm{tr}\;BA = B^{T}$  
    证明：按照矩阵梯度的定义：
    $$\triangledown_{X}f(X) = \begin{bmatrix}
\frac{\partial f(X) }{\partial x_{11}} & \cdots & \frac{\partial f(X) }{\partial x_{1n}}\\ 
\vdots & \ddots  & \vdots \\ 
\frac{\partial f(X) }{\partial x_{m1}} & \cdots & \frac{\partial f(X) }{\partial x_{mn}}
\end{bmatrix} = \frac{\partial f(X) }{\partial X}$$
    假设 A 是 $n * m$ 矩阵， B 是 $m * n$ 矩阵，则有
    $$\begin{align*}\triangledown_{A}\rm{tr}\;AB &= \triangledown_{A} \sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji}  = \frac{\partial}{\partial A}(\sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji})\\ & = \begin{bmatrix}
\frac{\partial}{\partial A_{11}}(\sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji}) & \cdots & \frac{\partial}{\partial A_{1m}}(\sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji})\\ 
\vdots & \ddots  & \vdots \\ 
\frac{\partial}{\partial A_{n1}}(\sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji}) & \cdots & \frac{\partial}{\partial A_{nm}}(\sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji})
\end{bmatrix} \\ & = \begin{bmatrix}
B_{11} & \cdots & B_{m1} \\ 
\vdots & \ddots  & \vdots \\ 
B_{1n} & \cdots & B_{mn}
\end{bmatrix} = B^{T}\\ \end{align*}$$
    
    $$\begin{align*}\triangledown_{A}\rm{tr}\;BA &= \triangledown_{A} \sum_{i=1}^{m}\sum_{j=1}^{n}B_{ij}A_{ji}  = \frac{\partial}{\partial A}(\sum_{i=1}^{m}\sum_{j=1}^{n}B_{ij}A_{ji})\\ & = \begin{bmatrix}
\frac{\partial}{\partial A_{11}}(\sum_{i=1}^{m}\sum_{j=1}^{n}B_{ij}A_{ji}) & \cdots & \frac{\partial}{\partial A_{1m}}(\sum_{i=1}^{m}\sum_{j=1}^{n}B_{ij}A_{ji})\\ 
\vdots & \ddots  & \vdots \\ 
\frac{\partial}{\partial A_{n1}}(\sum_{i=1}^{m}\sum_{j=1}^{n}B_{ij}A_{ji}) & \cdots & \frac{\partial}{\partial A_{nm}}(\sum_{i=1}^{m}\sum_{j=1}^{n}B_{ij}A_{ji})
\end{bmatrix} \\ & = \begin{bmatrix}
B_{11} & \cdots & B_{m1} \\ 
\vdots & \ddots  & \vdots \\ 
B_{1n} & \cdots & B_{mn}
\end{bmatrix} = B^{T}\\ \end{align*}$$

    所以有 $ \triangledown_{A}\rm{tr}\;AB = \triangledown_{A}\rm{tr}\;BA = B^{T}$
    
4. $\triangledown_{A^{T}}a = (\triangledown_{A}a)^{T}\;\;\;\; (a \in \mathbb{R})$  
    证明：假设 A 是 $n * m$ 矩阵
    $$\begin{align*}\triangledown_{A^{T}}a & = \begin{bmatrix}
\frac{\partial}{\partial A_{11}}a & \cdots & \frac{\partial}{\partial A_{1n}}a\\ 
\vdots & \ddots  & \vdots \\ 
\frac{\partial}{\partial A_{m1}}a & \cdots & \frac{\partial}{\partial A_{mn}}a
\end{bmatrix}  = (\begin{bmatrix}
\frac{\partial}{\partial A_{11}}a & \cdots & \frac{\partial}{\partial A_{1m}}a\\ 
\vdots & \ddots  & \vdots \\ 
\frac{\partial}{\partial A_{n1}}a & \cdots & \frac{\partial}{\partial A_{nm}}a
\end{bmatrix})^{T} \\ & = (\triangledown_{A}a)^{T}\\ \end{align*}$$

5. $\mathrm{d}(\rm{tr}\;A) = \rm{tr}(\mathrm{d}A)$
    证明：   
    $$\mathrm{d}(\rm{tr}\;A) = \mathrm{d}(\sum_{i=1}^{n}a_{ii}) = \sum_{i=1}^{n}\mathrm{d}a_{ii} = \rm{tr}(\mathrm{d}A)$$
    矩阵的迹的微分等于矩阵的微分的迹。
    
6. $\triangledown_{A}\rm{tr}\;ABA^{T}C = CAB + C^{T}AB^{T}$  
    证明：
    根据实标量函数梯度的乘法法则：
    若 f(A)、g(A)、h(A) 分别是矩阵 A 的实标量函数，则有
    $$\begin{align*}\frac{\partial f(A)g(A)}{\partial A} &= g(A)\frac{\partial f(A)}{\partial A} + f(A)\frac{\partial g(A)}{\partial A}\\ \frac{\partial f(A)g(A)h(A)}{\partial A} &= g(A)h(A)\frac{\partial f(A)}{\partial A} + f(A)h(A)\frac{\partial g(A)}{\partial A}+ f(A)g(A)\frac{\partial h(A)}{\partial A}\\ \end{align*}$$
    令 $f(A) = AB,g(A) = A^{T}C$，由性质5，矩阵的迹的微分等于矩阵的微分的迹，那么则有：
    $$\begin{align*} \triangledown_{A}\rm{tr}\;ABA^{T}C & = \rm{tr}(\triangledown_{A}ABA^{T}C) = \rm{tr}(\triangledown_{A}f(A)g(A)) = \rm{tr}\triangledown_{A_{1}}(A_{1}BA^{T}C) + \rm{tr}\triangledown_{A_{2}}(ABA_{2}^{T}C)  \\ & = (BA^{T}C)^{T} + \rm{tr}\triangledown_{A_{2}}(ABA_{2}^{T}C) = C^{T}AB^{T} + \triangledown_{A_{2}}\rm{tr}(ABA_{2}^{T}C)\\ & = C^{T}AB^{T} + \triangledown_{A_{2}}\rm{tr}(A_{2}^{T}CAB) = C^{T}AB^{T} + (\triangledown_{{A_{2}}^{T}}\;\rm{tr}\;A_{2}^{T}CAB)^{T} \\ & = C^{T}AB^{T} + ((CAB)^{T})^{T}  \\ & = C^{T}AB^{T} + CAB  \\ \end{align*}$$
    
    
------------------------------------------------------------------------------------------------------------



### 3. 推导

回到之前的代价函数中：

$$ 
\rm{CostFunction} = \rm{F}({\theta_{0}},{\theta_{1}}) = \frac{1}{2m} (X \cdot \Theta - Y)^{T}(X \cdot \Theta - Y)
$$ 

求导：

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) & = \frac{1}{2m} \triangledown_{\theta}(X \cdot \Theta - Y)^{T}(X \cdot \Theta - Y) = \frac{1}{2m}\triangledown_{\theta}(\Theta^{T}X^{T}-Y^{T})(X\Theta-Y)\\
& = \frac{1}{2m}\triangledown_{\theta}(\Theta^{T}X^{T}X\Theta-Y^{T}X\Theta-\Theta^{T}X^{T}Y+Y^{T}Y) \\ \end{align*}
$$ 

上式中，对 $\Theta $矩阵求导，$ Y^{T}Y $ 与 $\Theta $ 无关，所以这一项为 0 。 $Y^{T}X\Theta$ 是标量，由性质4可以知道，$Y^{T}X\Theta = (Y^{T}X\Theta)^{T} = \Theta^{T}X^{T}Y$，因为 $\Theta^{T}X^{T}X\Theta , Y^{T}X\Theta $都是标量，所以它们的也等于它们的迹，（处理矩阵微分的问题常常引入矩阵的迹），于是有

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) & = \frac{1}{2m}\triangledown_{\theta}(\Theta^{T}X^{T}X\Theta-2Y^{T}X\Theta) \\ 
& = \frac{1}{2m}\triangledown_{\theta}\rm{tr}\;(\Theta^{T}X^{T}X\Theta-2Y^{T}X\Theta) \\ & = \frac{1}{2m}\triangledown_{\theta}\rm{tr}\;(\Theta\Theta^{T}X^{T}X-2Y^{T}X\Theta) \\ & = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -\triangledown_{\theta}\rm{tr}\;Y^{T}X\Theta) \\ & = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -(Y^{T}X)^{T}) = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -X^{T}Y)\\ \end{align*}
$$ 

上面第三步用的性质2矩阵迹的交换律，第五步用的性质3。

为了能进一步化简矩阵的微分，我们在矩阵的迹上面乘以一个单位矩阵，不影响结果。于是：

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) & = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -X^{T}Y) \\ &= \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta I \Theta^{T}X^{T}X -X^{T}Y) \end{align*}
$$ 

利用性质6 展开上面的式子，令 $ A = \Theta , B = I , C = X^{T}X $。

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) &= \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta I \Theta^{T}X^{T}X -X^{T}Y) \\ & = \frac{1}{m}(\frac{1}{2}(X^{T}X\Theta I + (X^{T}X)^{T}\Theta I^{T}) -X^{T}Y) \\ & = \frac{1}{m}(\frac{1}{2}(X^{T}X\Theta I + (X^{T}X)^{T}\Theta I^{T}) -X^{T}Y) \\ & = \frac{1}{m}(\frac{1}{2}(X^{T}X\Theta + X^{T}X\Theta) -X^{T}Y)  = \frac{1}{m}(X^{T}X\Theta -X^{T}Y) \\ \end{align*}
$$

令 $\triangledown_{\theta}\rm{F}(\theta) = 0$，即 $X^{T}X\Theta -X^{T}Y = 0$, 于是 $ X^{T}X\Theta = X^{T}Y $ ，这里假设 $ X^{T}X$ 这个矩阵是可逆的，等号两边同时左乘$ X^{T}X$的逆矩阵，得到 $\Theta = (X^{T}X)^{-1}X^{T}Y$

最终结果也就推导出来了，$$\Theta = (X^{T}X)^{-1}X^{T}Y$$

但是这里有一个**前提条件是 $X^{T}X$ 是非奇异(非退化)矩阵， 即 $ \left | X^{T}X \right | \neq 0 $**

------------------------------------------------------------------------------------------------------------

### 4. 梯度下降和正规方程法比较：

优点：
梯度下降在超大数据集面前也能运行的很良好。  
正规方程在超大数据集合面前性能会变得很差，因为需要计算 $(x^{T}x)^{-1}$,时间复杂度在 $O(n^{3})$ 这个级别。  

缺点：
梯度下降需要合理的选择学习速率 $\alpha$ , 需要很多次迭代的操作去选择合理的 $\alpha$，寻找最小值的时候也需要迭代很多次才能收敛。  
正规方程的优势相比而言，不需要选择学习速率 $\alpha$，也不需要多次的迭代或者画图检测是否收敛。


------------------------------------------------------------------------------------------------------------

## 二. Normal Equation Noninvertibility

上一章谈到了如何利用正规方程法求解 $\Theta $,但是在线性代数中存在这样一个问题，如果是奇异(退化)矩阵，是不存在逆矩阵的。也就是说用上面正规方程的公式是不一定能求解出正确结果的。

在 Octave 软件中，存在2个求解逆矩阵的函数，一个是 pinv 和 inv。pinv (pseudo-inverse)求解的是**伪逆矩阵**，inv 求解的是逆矩阵，所以用 pinv 求解问题，就算是 $ X^{T}X $ 不存在逆矩阵，也一样可以得到最后的结果。

导致$ X^{T}X $ 不存在逆矩阵有2种情况：

1. 多余的特征。特征之间呈倍数关系，线性依赖。
2. 过多的特征。当 $ m \leqslant n $ 的时候，会导致过多的特征。解决办法是删除一些特征，或者进行正则化。

所以解决$ X^{T}X $ 不存在逆矩阵的办法也就是对应上面2种情况：

1. 删掉多余的特征，线性相关的，倍数关系的。直到没有多余的特征
2. 再删除一些不影响结果的特征，或者进行正则化。

------------------------------------------------------------------------------------------------------------

## 三. Linear Regression with Multiple Variables 测试


### 1. Question 1

Suppose m=4 students have taken some class, and the class had a midterm exam and a final exam. You have collected a dataset of their scores on the two exams, which is as follows:

midterm exam	(midterm exam)2	final exam
89	7921	96
72	5184	74
94	8836	87
69	4761	78
You'd like to use polynomial regression to predict a student's final exam score from their midterm exam score. Concretely, suppose you want to fit a model of the form hθ(x)=θ0+θ1x1+θ2x2, where x1 is the midterm score and x2 is (midterm score)2. Further, you plan to use both feature scaling (dividing by the "max-min", or range, of a feature) and mean normalization.

What is the normalized feature x(2)2? (Hint: midterm = 72, final = 74 is training example 2.) Please round off your answer to two decimal places and enter in the text box below.

解答：
标准化 $$x = \frac{x_{2}^{2}-\frac{(7921+5184+8836+4761)}{4}}{\max - \min } = \frac{5184 - 6675.5}{8836-4761} = -0.37$$

### 2. Question 2

You run gradient descent for 15 iterations

with α=0.3 and compute J(θ) after each

iteration. You find that the value of J(θ) increases over

time. Based on this, which of the following conclusions seems

most plausible?


A. Rather than use the current value of α, it'd be more promising to try a smaller value of α (say α=0.1).

B. α=0.3 is an effective choice of learning rate.

C. Rather than use the current value of α, it'd be more promising to try a larger value of α (say α=1.0).


解答：  A 

下降太快所以a下降速率过大，a越大下降越快，a小下降慢，在本题中，代价函数快速收敛到最小值，代表此时a最合适。


### 3. Question 3

Suppose you have m=28 training examples with n=4 features (excluding the additional all-ones feature for the intercept term, which you should add). The normal equation is θ=(XTX)−1XTy. For the given values of m and n, what are the dimensions of θ, X, and y in this equation?


A. X is 28×4, y is 28×1, θ is 4×4

B. X is 28×5, y is 28×5, θ is 5×5

C. X is 28×5, y is 28×1, θ is 5×1

D. X is 28×4, y is 28×1, θ is4×1

解答：  C 

这里需要注意的是，题目中说了额外添加一列全部为1的，所以列数是5 。

### 4. Question 4

Suppose you have a dataset with m=50 examples and n=15 features for each example. You want to use multivariate linear regression to fit the parameters θ to our data. Should you prefer gradient descent or the normal equation?


A. Gradient descent, since it will always converge to the optimal θ.

B. Gradient descent, since (XTX)−1 will be very slow to compute in the normal equation.

C. The normal equation, since it provides an efficient way to directly find the solution.

D. The normal equation, since gradient descent might be unable to find the optimal θ.

解答：  C 

数据量少，选择正规方程法更加高效

### 5. Question 5

Which of the following are reasons for using feature scaling?


A. It prevents the matrix XTX (used in the normal equation) from being non-invertable (singular/degenerate).

B. It is necessary to prevent the normal equation from getting stuck in local optima.

C. It speeds up gradient descent by making it require fewer iterations to get to a good solution.

D. It speeds up gradient descent by making each iteration of gradient descent less expensive to compute.

解答：  C 

normal equation 不需要 Feature Scaling，排除AB， 特征缩放减少迭代数量，加快梯度下降，然而不能防止梯度下降陷入局部最优。


------------------------------------------------------

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Computing\_Parameters\_Analytically.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Computing_Parameters_Analytically.ipynb)

