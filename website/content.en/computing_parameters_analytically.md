+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-21T07:50:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/69_9_.png"
slug = "computing_parameters_analytically"
tags = ["Machine Learning", "AI"]
title = "Computational Parameter Analysis —— Normal Equation Method"

+++


>Because Ghost blogs recognize LaTeX with syntax that differs from standard LaTeX syntax, and to make the content more generally usable, some LaTeX formulas in the following article may appear garbled. If that happens, and if you do not mind, you can read the non-garbled version of this article on the author's [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this garbling issue when time permits. Thank you for your understanding.
>
> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Computing\_Parameters\_Analytically.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Computing_Parameters_Analytically.ipynb)

## I. Normal Equation

### 1. Normal Equation

Compared with gradient descent, the normal equation can find the minimum in one step. It also does not require feature scaling.

The sample set is an $ m * n $ matrix. Each row sample is represented as $ \vec{x^{(i)}} $; the elements in row i and columns 0 through n are represented as $ x^{(i)}_{0} , x^{(i)}_{1} , x^{(i)}_{2} , x^{(i)}_{3} \cdots x^{(i)}_{n} $, and the m row vectors are represented as $ \vec{x^{(1)}} , \vec{x^{(2)}} , \vec{x^{(3)}} , \cdots \vec{x^{(m)}} $

Let 

$$ \vec{x^{(i)}} = \begin{bmatrix} x^{(i)}_{0}\\ x^{(i)}_{1}\\ \vdots \\ x^{(i)}_{n}\\ \end{bmatrix} $$

$ \vec{x^{(i)}} $ is such an $(n+1)*1$ dimensional vector. Each row corresponds to the 0–n variables in row i.

Now construct several matrices:

$$ X = \begin{bmatrix} (\vec{x^{(1)}})^{T}\\  \vdots \\  (\vec{x^{(m)}})^{T} \end{bmatrix} \;\;\;\;
\Theta = \begin{bmatrix} \theta_{0}\\ \theta_{1}\\ \vdots \\ \theta_{n}\\ \end{bmatrix} \;\;\;\;
Y = \begin{bmatrix} y^{(1)}\\ y^{(2)}\\ \vdots \\ y^{(m)}\\ \end{bmatrix} 
$$

X is an $ m * (n+1)$ matrix, $ \Theta $ is an $ (n+1) * 1$ vector, and Y is an $ m * 1$ matrix.

Comparing this with the previous cost function, $$ \rm{CostFunction} = \rm{F}({\theta_{0}},{\theta_{1}}) = \frac{1}{2m}\sum_{i = 1}^{m} (h_{\theta}(x^{(i)})-y^{(i)})^2 $$  

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


Substituting this into the previous cost function,
$$ 
\begin{align*}
\rm{CostFunction} = \rm{F}({\theta_{0}},{\theta_{1}}) &= \frac{1}{2m}\sum_{i = 1}^{m} (h_{\theta}(x^{(i)})-y^{(i)})^2\\
& = \frac{1}{2m} (X \cdot \Theta - Y)^{T}(X \cdot \Theta - Y)\\
\end{align*}
$$  


  
----------------------------------------------------------------------------------------------------------------


### 2. Matrix Differentiation and the Trace of a Matrix

Before proceeding with the derivation, we need to introduce the concept of the trace of a matrix, because the trace is a tool for computing first-order matrix derivatives.

The trace of a matrix is defined as 

$$ \rm{tr} A =  \sum_{i=1}^{n}A_{ii}$$ 

In simple terms, it is the sum of the elements on the diagonal from the upper-left corner to the lower-right corner.

The following properties will be needed in the derivation below:

1. $ \rm{tr}\;a = a $ , where a is a scalar ( $ a \in \mathbb{R} $)  

2. $ \rm{tr}\;AB = \rm{tr}\;BA $ More generally, $ \rm{tr}\;ABC = \rm{tr}\;CAB = \rm{tr}\;BCA $  
    Proof: suppose A is an $n * m$ matrix and B is an $m * n$ matrix. Then
    $$ \rm{tr}\;AB = \sum_{i=1}^{n}\sum_{j=1}^{m}A_{ij}B_{ji} = \sum_{j=1}^{n} \sum_{i=1}^{m}B_{ji}A_{ij}= \rm{tr}\;BA $$
    Similarly: $$ \rm{tr}\;ABC = \rm{tr}\;(AB)C = \rm{tr}\;C(AB) = \rm{tr}\;CAB$$
    $$ \rm{tr}\;ABC = \rm{tr}\;A(BC) = \rm{tr}\;(BC)A = \rm{tr}\;BCA$$
    Combining them gives $$ \rm{tr}\;ABC = \rm{tr}\;CAB = \rm{tr}\;BCA $$

3. $ \triangledown_{A}\rm{tr}\;AB = \triangledown_{A}\rm{tr}\;BA = B^{T}$  
    Proof: according to the definition of the matrix gradient:
    $$\triangledown_{X}f(X) = \begin{bmatrix}
\frac{\partial f(X) }{\partial x_{11}} & \cdots & \frac{\partial f(X) }{\partial x_{1n}}\\ 
\vdots & \ddots  & \vdots \\ 
\frac{\partial f(X) }{\partial x_{m1}} & \cdots & \frac{\partial f(X) }{\partial x_{mn}}
\end{bmatrix} = \frac{\partial f(X) }{\partial X}$$
    Suppose A is an $n * m$ matrix and B is an $m * n$ matrix. Then
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

    Therefore, $ \triangledown_{A}\rm{tr}\;AB = \triangledown_{A}\rm{tr}\;BA = B^{T}$
    
4. $\triangledown_{A^{T}}a = (\triangledown_{A}a)^{T}\;\;\;\; (a \in \mathbb{R})$  
    Proof: assume A is an $n * m$ matrix.
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
    Proof:   
    $$\mathrm{d}(\rm{tr}\;A) = \mathrm{d}(\sum_{i=1}^{n}a_{ii}) = \sum_{i=1}^{n}\mathrm{d}a_{ii} = \rm{tr}(\mathrm{d}A)$$
    The differential of the trace of a matrix is equal to the trace of the differential of the matrix.
    
6. $\triangledown_{A}\rm{tr}\;ABA^{T}C = CAB + C^{T}AB^{T}$  
    Proof:
    According to the product rule for gradients of real-valued scalar functions:
    If f(A), g(A), and h(A) are real-valued scalar functions of the matrix A, respectively, then:
    $$\begin{align*}\frac{\partial f(A)g(A)}{\partial A} &= g(A)\frac{\partial f(A)}{\partial A} + f(A)\frac{\partial g(A)}{\partial A}\\ \frac{\partial f(A)g(A)h(A)}{\partial A} &= g(A)h(A)\frac{\partial f(A)}{\partial A} + f(A)h(A)\frac{\partial g(A)}{\partial A}+ f(A)g(A)\frac{\partial h(A)}{\partial A}\\ \end{align*}$$
    Let $f(A) = AB,g(A) = A^{T}C$. By Property 5, the differential of the trace of a matrix is equal to the trace of the differential of the matrix, so we have:
    $$\begin{align*} \triangledown_{A}\rm{tr}\;ABA^{T}C & = \rm{tr}(\triangledown_{A}ABA^{T}C) = \rm{tr}(\triangledown_{A}f(A)g(A)) = \rm{tr}\triangledown_{A_{1}}(A_{1}BA^{T}C) + \rm{tr}\triangledown_{A_{2}}(ABA_{2}^{T}C)  \\ & = (BA^{T}C)^{T} + \rm{tr}\triangledown_{A_{2}}(ABA_{2}^{T}C) = C^{T}AB^{T} + \triangledown_{A_{2}}\rm{tr}(ABA_{2}^{T}C)\\ & = C^{T}AB^{T} + \triangledown_{A_{2}}\rm{tr}(A_{2}^{T}CAB) = C^{T}AB^{T} + (\triangledown_{{A_{2}}^{T}}\;\rm{tr}\;A_{2}^{T}CAB)^{T} \\ & = C^{T}AB^{T} + ((CAB)^{T})^{T}  \\ & = C^{T}AB^{T} + CAB  \\ \end{align*}$$
    
    
------------------------------------------------------------------------------------------------------------


### 3. Derivation

Returning to the previous cost function:

$$ 
\rm{CostFunction} = \rm{F}({\theta_{0}},{\theta_{1}}) = \frac{1}{2m} (X \cdot \Theta - Y)^{T}(X \cdot \Theta - Y)
$$ 

Taking the derivative:

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) & = \frac{1}{2m} \triangledown_{\theta}(X \cdot \Theta - Y)^{T}(X \cdot \Theta - Y) = \frac{1}{2m}\triangledown_{\theta}(\Theta^{T}X^{T}-Y^{T})(X\Theta-Y)\\
& = \frac{1}{2m}\triangledown_{\theta}(\Theta^{T}X^{T}X\Theta-Y^{T}X\Theta-\Theta^{T}X^{T}Y+Y^{T}Y) \\ \end{align*}
$$ 

In the expression above, we differentiate with respect to the $\Theta $ matrix. $ Y^{T}Y $ is independent of $\Theta $, so this term is 0. $Y^{T}X\Theta$ is a scalar; from Property 4, we know that $Y^{T}X\Theta = (Y^{T}X\Theta)^{T} = \Theta^{T}X^{T}Y$. Since $\Theta^{T}X^{T}X\Theta , Y^{T}X\Theta $ are both scalars, they are also equal to their traces (when working with matrix differentials, the trace of a matrix is often introduced). Therefore:

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) & = \frac{1}{2m}\triangledown_{\theta}(\Theta^{T}X^{T}X\Theta-2Y^{T}X\Theta) \\ 
& = \frac{1}{2m}\triangledown_{\theta}\rm{tr}\;(\Theta^{T}X^{T}X\Theta-2Y^{T}X\Theta) \\ & = \frac{1}{2m}\triangledown_{\theta}\rm{tr}\;(\Theta\Theta^{T}X^{T}X-2Y^{T}X\Theta) \\ & = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -\triangledown_{\theta}\rm{tr}\;Y^{T}X\Theta) \\ & = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -(Y^{T}X)^{T}) = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -X^{T}Y)\\ \end{align*}
$$ 

The third step above uses Property 2, the commutation property of the matrix trace, and the fifth step uses Property 3.

To further simplify the matrix differential, we multiply by an identity matrix inside the matrix trace, which does not affect the result. Thus:

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) & = \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta\Theta^{T}X^{T}X -X^{T}Y) \\ &= \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta I \Theta^{T}X^{T}X -X^{T}Y) \end{align*}
$$ 

Use Property 6 to expand the expression above, with $ A = \Theta , B = I , C = X^{T}X $.

$$
\begin{align*}
\triangledown_{\theta}\rm{F}(\theta) &= \frac{1}{m}(\frac{1}{2}\triangledown_{\theta}\rm{tr}\;\Theta I \Theta^{T}X^{T}X -X^{T}Y) \\ & = \frac{1}{m}(\frac{1}{2}(X^{T}X\Theta I + (X^{T}X)^{T}\Theta I^{T}) -X^{T}Y) \\ & = \frac{1}{m}(\frac{1}{2}(X^{T}X\Theta I + (X^{T}X)^{T}\Theta I^{T}) -X^{T}Y) \\ & = \frac{1}{m}(\frac{1}{2}(X^{T}X\Theta + X^{T}X\Theta) -X^{T}Y)  = \frac{1}{m}(X^{T}X\Theta -X^{T}Y) \\ \end{align*}
$$

Let $\triangledown_{\theta}\rm{F}(\theta) = 0$, that is, $X^{T}X\Theta -X^{T}Y = 0$. Then $ X^{T}X\Theta = X^{T}Y $. Here we assume that the matrix $ X^{T}X$ is invertible. Left-multiplying both sides of the equation by the inverse of $ X^{T}X$, we obtain $\Theta = (X^{T}X)^{-1}X^{T}Y$

The final result is thus derived: $$\Theta = (X^{T}X)^{-1}X^{T}Y$$

However, there is a **prerequisite here: $X^{T}X$ must be a non-singular (non-degenerate) matrix, i.e., $ \left | X^{T}X \right | \neq 0 $**

------------------------------------------------------------------------------------------------------------

### 4. Comparison Between Gradient Descent and the Normal Equation Method:

Advantages:
Gradient descent can still run very well on extremely large datasets.  
The normal equation performs poorly on extremely large datasets because it needs to compute $(x^{T}x)^{-1}$, whose time complexity is on the order of $O(n^{3})$.  

Disadvantages:
Gradient descent requires choosing an appropriate learning rate $\alpha$ and many iterations to select a reasonable $\alpha$; it also requires many iterations to converge when finding the minimum.  
By comparison, the advantage of the normal equation is that it does not require choosing a learning rate $\alpha$, nor does it require repeated iterations or plotting to check whether it has converged.


------------------------------------------------------------------------------------------------------------

## II. Normal Equation Noninvertibility

The previous chapter discussed how to solve for $\Theta $ using the normal equation method. However, in linear algebra there is an issue: if a matrix is singular (degenerate), it does not have an inverse. In other words, using the normal equation formula above does not necessarily produce a correct result.

In Octave, there are two functions for computing matrix inverses: pinv and inv. pinv (pseudo-inverse) computes the **pseudo-inverse matrix**, while inv computes the inverse matrix. Therefore, if you use pinv to solve the problem, even if $ X^{T}X $ does not have an inverse, you can still obtain the final result.

There are two situations that can cause $ X^{T}X $ to have no inverse:

1. Redundant features. Features have multiplicative relationships with each other and are linearly dependent.
2. Too many features. When $ m \leqslant n $, there will be too many features. The solution is to delete some features or apply regularization.

Therefore, the ways to handle the case where $ X^{T}X $ has no inverse correspond to the two situations above:

1. Remove redundant features—those that are linearly correlated or have multiplicative relationships—until there are no redundant features left.
2. Remove additional features that do not affect the result, or apply regularization.

------------------------------------------------------------------------------------------------------------

## III. Linear Regression with Multiple Variables Test


### 1. Question 1

Suppose m=4 students have taken some class, and the class had a midterm exam and a final exam. You have collected a dataset of their scores on the two exams, which is as follows:

midterm exam	(midterm exam)2	final exam
89	7921	96
72	5184	74
94	8836	87
69	4761	78
You'd like to use polynomial regression to predict a student's final exam score from their midterm exam score. Concretely, suppose you want to fit a model of the form hθ(x)=θ0+θ1x1+θ2x2, where x1 is the midterm score and x2 is (midterm score)2. Further, you plan to use both feature scaling (dividing by the "max-min", or range, of a feature) and mean normalization.

What is the normalized feature x(2)2? (Hint: midterm = 72, final = 74 is training example 2.) Please round off your answer to two decimal places and enter in the text box below.

Solution:
Normalization: $$x = \frac{x_{2}^{2}-\frac{(7921+5184+8836+4761)}{4}}{\max - \min } = \frac{5184 - 6675.5}{8836-4761} = -0.37$$

### 2. Question 2

You run gradient descent for 15 iterations

with α=0.3 and compute J(θ) after each

iteration. You find that the value of J(θ) increases over

time. Based on this, which of the following conclusions seems

most plausible?


A. Rather than use the current value of α, it'd be more promising to try a smaller value of α (say α=0.1).

B. α=0.3 is an effective choice of learning rate.

C. Rather than use the current value of α, it'd be more promising to try a larger value of α (say α=1.0).


Solution:  A 

The descent is too fast, so the descent rate a is too large. The larger a is, the faster the descent; the smaller a is, the slower the descent. In this question, the cost function quickly converges to the minimum, indicating that a is the most appropriate value at this point.


### 3. Question 3

Suppose you have m=28 training examples with n=4 features (excluding the additional all-ones feature for the intercept term, which you should add). The normal equation is θ=(XTX)−1XTy. For the given values of m and n, what are the dimensions of θ, X, and y in this equation?


A. X is 28×4, y is 28×1, θ is 4×4

B. X is 28×5, y is 28×5, θ is 5×5

C. X is 28×5, y is 28×1, θ is 5×1

D. X is 28×4, y is 28×1, θ is4×1

Solution:  C 

Note that the problem states that an extra column of all 1s is added, so the number of columns is 5.

### 4. Question 4

Suppose you have a dataset with m=50 examples and n=15 features for each example. You want to use multivariate linear regression to fit the parameters θ to our data. Should you prefer gradient descent or the normal equation?


A. Gradient descent, since it will always converge to the optimal θ.

B. Gradient descent, since (XTX)−1 will be very slow to compute in the normal equation.

C. The normal equation, since it provides an efficient way to directly find the solution.

D. The normal equation, since gradient descent might be unable to find the optimal θ.

Solution:  C 

With a small amount of data, the normal equation method is more efficient.

### 5. Question 5

Which of the following are reasons for using feature scaling?


A. It prevents the matrix XTX (used in the normal equation) from being non-invertable (singular/degenerate).

B. It is necessary to prevent the normal equation from getting stuck in local optima.

C. It speeds up gradient descent by making it require fewer iterations to get to a good solution.

D. It speeds up gradient descent by making each iteration of gradient descent less expensive to compute.

Solution:  C 

The normal equation does not require feature scaling, so A and B are excluded. Feature scaling reduces the number of iterations and speeds up gradient descent; however, it cannot prevent gradient descent from getting stuck in a local optimum.


------------------------------------------------------

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Computing\_Parameters\_Analytically.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Computing_Parameters_Analytically.ipynb)