+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-20T07:47:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/69_4.png"
slug = "multivariate_linear_regression"
tags = ["Machine Learning", "AI"]
title = "Multiple Linear Regression"

+++


>Because Ghost blogs recognize LaTeX with syntax that differs from standard LaTeX syntax, and to make the content more generally usable, the LaTeX formulas in the following article may appear garbled. If that happens and you do not mind, you can read the non-garbled version of this article on the author's [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this garbling issue when time permits. Thank you for your understanding.
>
> GitHub Repository: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Multivariate\_Linear\_Regression.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Multivariate_Linear_Regression.ipynb)

## I. Multiple Features

Linear regression with multiple variables is also called “multivariate linear regression.”

$x_{j}^{(i)}$: the j-th element in the i-th vector of the training set (row i, column j)  
$x^{(i)}$: the i-th vector of the training set (row i)  
$ m $: m rows in total  
$ n $: n columns in total  


The multivariate form of the hypothesis function that accommodates these multiple features is as follows:

$$ h_{\theta}(x) = \theta_{0} + \theta_{1}x_{1} + \theta_{2}x_{2} + \theta_{3}x_{3} + \cdots + \theta_{n}x_{n} $$

Using the definition of matrix multiplication, our multivariate hypothesis function can be expressed concisely as:

$$ h_{\theta}(x) = \begin{bmatrix}
\theta_{0} & \theta_{1} & \cdots  & \theta_{n}
\end{bmatrix} \begin{bmatrix}
x_{0}\\ 
x_{1}\\ 
 \vdots \\ 
x_{n}
\end{bmatrix} = \theta^{T}x$$

where $ x_{0}^{(i)} = 1 (i\in 1,\cdots,m)$


------------------------------------------------------

## II. Gradient Descent for Multiple Variables

Gradient descent with multiple variables updates n variables simultaneously.

$$ \theta_{j} := \theta_{j} - \alpha \frac{1}{m} \sum_{i=1}^{m}(h_{\theta}(x^{(i)})-y^{(i)})x^{(i)}_{j}$$

where $ j \in [0,n]$


------------------------------------------------------


## III. Gradient Descent in Practice I - Feature Scaling

Feature scaling involves dividing input values by the range of the input variable (that is, the maximum value minus the minimum value), resulting in a new range of only 1.

Mean normalization involves subtracting the average value of the input variable from the input variable’s values, resulting in a new average value of zero for the input variable.

### 1. Feature Scaling

Feature scaling makes the ranges of feature values relatively consistent, so when gradient descent is performed, the “route downhill” is simpler and convergence is faster. Typically, feature scaling scales feature values as much as possible into the interval [-1,1] **or close to this interval**.

That is, $ x_{i} = \frac{x_{i}}{s_{i}}$

### 2. Mean normalization

$ x_{i} = \frac{x_{i} - \mu_{i}}{s_{i}}$

Here, $\mu_{i}$ is the average of all values of the feature, and $s_{i}$ is the range of the values (maximum - minimum), or $s_{i}$ is the standard deviation.

Of course, $x_{0} = 1$ does not need to go through the above processing, because it is always equal to 1 and cannot have a mean of 0.


------------------------------------------------------

## IV. Gradient Descent in Practice II - Learning Rate

If the learning rate $\alpha $ is too small, convergence will be too slow.
If the learning rate $\alpha $ is too large, the cost function may not decrease on every iteration and may even fail to converge. In some cases, when the learning rate $\alpha $ is too large, convergence may also be slow.

You can debug this issue by plotting the curve of the cost function against the number of iterations.

For $\alpha $, you can try values such as 0.001, 0.003, 0.01, 0.03, 0.1, 0.3, and 1, and choose the best one.


------------------------------------------------------

## V. Features and Polynomial Regression


You can transform features, for example by combining two features and using $ x_{3}$ to represent $ x_{1} * x_{2} $.

In polynomial regression, for $ h_{\theta}(x) = \theta_{0} + \theta_{1}x_{1} + \theta_{2}x_{1}^{2} + \theta_{3}x_{1}^{3} $, we can set $ x_{2} = x_{1}^{2} , x_{3} = x_{1}^{3} $ to reduce the degree.

You can also consider expressions with square roots, for example using  $ h_{\theta}(x) = \theta_{0} + \theta_{1}x_{1} + \theta_{2}\sqrt{x} $

After applying the transformations above, remember to make adjustments using **feature scaling, mean normalization, and learning-rate tuning**.


------------------------------------------------------

> GitHub Repository: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Multivariate\_Linear\_Regression.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Multivariate_Linear_Regression.ipynb)