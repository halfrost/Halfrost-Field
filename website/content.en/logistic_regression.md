+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-22T08:00:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/69_6_.png"
slug = "logistic_regression"
tags = ["Machine Learning", "AI"]
title = "Logistic Regression"

+++


> Because Ghost’s syntax for recognizing LaTeX differs from standard LaTeX syntax, the LaTeX formulas in the article below may appear garbled for better general compatibility. If that happens, and if you don’t mind, you can read the clean version of this article on the author’s [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this rendering issue when time permits. Thank you for your understanding.
>
> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Logistic_Regression.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Logistic_Regression.ipynb)


## I. Classification and Representation

To perform classification, one approach is to use linear regression and map all predicted values greater than 0.5 to 1, and all predicted values less than 0.5 to 0. However, this approach does not work well, because classification is not actually a linear function. A classification problem is like a regression problem, except that the values we want to predict are now only a small number of discrete values.

**Using linear regression to solve classification problems is usually not a good idea**.

When solving a classification problem, we could ignore the fact that y is discrete and use our old linear regression algorithm to try to predict a given x. However, it is easy to construct examples where this approach performs poorly. Intuitively, when we know that $y\in \begin{Bmatrix}
0,1
\end{Bmatrix}$, it also does not make sense for $h_{\theta}(x)$ to take values greater than 1 or less than 0. To address this issue, let’s change the form of our hypothesis $h_{\theta}(x)$ so that it satisfies $0\leqslant h_{\theta}(x)\leqslant 1$. This is done by plugging $\theta^{T}x$ into the Logistic function:

$$g(x) = \frac{1}{1+e^{-x}}$$

The expression above is called the Sigmoid Function or the Logistic Function.

Let $h_{\theta}(x) = g(\theta^{T}x)$,$z = \theta^{T}x$, then:

$$g(x) = \frac{1}{1+e^{-\theta^{T}x}}$$


![](https://img.halfrost.com/Blog/ArticleImage/69_8.png)


The function $g(x)$ shown here maps any real number to the interval (0,1), making it useful for converting an arbitrary-valued function into one better suited for classification.


**The decision boundary is not a property of the training set, but a property of the hypothesis itself and its parameters**.


------------------------------------------------------

## II. Logistic Regression Model


### 1. Cost Function


The cost function defined earlier:

$$ \rm{CostFunction} = \rm{F}({\theta}) = \frac{1}{m}\sum_{i = 1}^{m} (h_{\theta}(x^{(i)})-y^{(i)})^2 $$


If we substitute $$h_{\theta}(x) = \frac{1}{1+e^{-\theta^{T}x}} $$ into the expression above, the graph of the $\rm{CostFunction}$ will be a non-convex function with many local extrema.


So we look for a new cost function:

$$\rm{CostFunction} = \rm{F}({\theta}) = \frac{1}{m}\sum_{i = 1}^{m} \rm{Cost}(h_{\theta}(x^{(i)}),y^{(i)})$$


$$\rm{Cost}(h_{\theta}(x^{(i)}),y^{(i)}) = \left\{\begin{matrix}
-log(h_{\theta}(x)) &if \; y = 1 \\ 
-log(1-h_{\theta}(x)) & if\; y = 0
\end{matrix}\right.$$


One thing to note is that in our training set, and even for samples not in the training set, the value of y is always either 0 or 1.


### 2. Simplified Cost Function and Gradient Descent


We can further write the cost function as a single expression:

$$\rm{Cost}(h_{\theta}(x),y) = - ylog(h_{\theta}(x)) - (1-y)log(1-h_{\theta}(x))$$


So the final form of the cost function is:

$$
\begin{align*}
\rm{CostFunction} = \rm{F}({\theta}) &= \frac{1}{m}\sum_{i = 1}^{m} \rm{Cost}(h_{\theta}(x^{(i)}),y^{(i)})\\
&= -\frac{1}{m}\left [ \sum_{i=1}^{m} y^{(i)}logh_{\theta}(x^{(i)}) + (1-y^{(i)})log(1-h_{\theta}(x^{(i)})) \right ] \\
\left( h_{\theta}(x) = \frac{1}{1+e^{-\theta^{T}x}} \right ) 
\end{align*}
$$

Vectorized form:

$$
\begin{align*}
h &= g(X\theta)\\ 
\rm{CostFunction} = \rm{F}({\theta}) &= \frac{1}{m} \left ( -\overrightarrow{y}^{T}log(h) - (1-\overrightarrow{y})^{T}log(1-h) \right ) \\ 
\end{align*}
$$


Writing the expression in the form above comes from maximum likelihood estimation in statistics, which is a method for quickly finding parameters for different models. One of its properties is that it is convex.

Using gradient descent, we obtain the minimum of the cost function:

$$ \theta_{j} := \theta_{j} - \alpha \frac{1}{m} \sum_{i=1}^{m}(h_{\theta}(x^{(i)})-y^{(i)})x^{(i)}_{j}$$

Vectorized, that is:

$$ \theta := \theta - \alpha \frac{1}{m} X^{T}(g(X\Theta)-\vec{y})$$


**One thing to note here is that**,


**In linear regression, $h_{\theta}(x) = \theta^{T}x $**,

**whereas in Logistic regression, $h_{\theta}(x) = \frac{1}{1+e^{-\theta^{T}x}}$**.

Finally, feature scaling also applies to Logistic regression and helps gradient descent converge faster.

------------------------------------------------------

### 3. Derivation Process

Logistic function

First, let’s look at how to differentiate the logistic function (Sigmoid function):

$$
\begin{align*}
\sigma(x)'&=\left(\frac{1}{1+e^{-x}}\right)'=\frac{-(1+e^{-x})'}{(1+e^{-x})^2}=\frac{-1'-(e^{-x})'}{(1+e^{-x})^2}=\frac{0-(-x)'(e^{-x})}{(1+e^{-x})^2}=\frac{-(-1)(e^{-x})}{(1+e^{-x})^2}=\frac{e^{-x}}{(1+e^{-x})^2} \newline &=\left(\frac{1}{1+e^{-x}}\right)\left(\frac{e^{-x}}{1+e^{-x}}\right)=\sigma(x)\left(\frac{+1-1 + e^{-x}}{1+e^{-x}}\right)=\sigma(x)\left(\frac{1 + e^{-x}}{1+e^{-x}} - \frac{1}{1+e^{-x}}\right)\\
&=\sigma(x)(1 - \sigma(x))\\
\end{align*}
$$

Cost function

Using the result above, together with the chain rule for composite functions, we get:

$$
\begin{align*}
\frac{\partial}{\partial \theta_j} J(\theta) &= \frac{\partial}{\partial \theta_j} \frac{-1}{m}\sum_{i=1}^m \left [ y^{(i)} log (h_\theta(x^{(i)})) + (1-y^{(i)}) log (1 - h_\theta(x^{(i)})) \right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     y^{(i)} \frac{\partial}{\partial \theta_j} log (h_\theta(x^{(i)}))   + (1-y^{(i)}) \frac{\partial}{\partial \theta_j} log (1 - h_\theta(x^{(i)}))\right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     \frac{y^{(i)} \frac{\partial}{\partial \theta_j} h_\theta(x^{(i)})}{h_\theta(x^{(i)})}   + \frac{(1-y^{(i)})\frac{\partial}{\partial \theta_j} (1 - h_\theta(x^{(i)}))}{1 - h_\theta(x^{(i)})}\right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     \frac{y^{(i)} \frac{\partial}{\partial \theta_j} \sigma(\theta^T x^{(i)})}{h_\theta(x^{(i)})}   + \frac{(1-y^{(i)})\frac{\partial}{\partial \theta_j} (1 - \sigma(\theta^T x^{(i)}))}{1 - h_\theta(x^{(i)})}\right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     \frac{y^{(i)} \sigma(\theta^T x^{(i)}) (1 - \sigma(\theta^T x^{(i)})) \frac{\partial}{\partial \theta_j} \theta^T x^{(i)}}{h_\theta(x^{(i)})}   + \frac{- (1-y^{(i)}) \sigma(\theta^T x^{(i)}) (1 - \sigma(\theta^T x^{(i)})) \frac{\partial}{\partial \theta_j} \theta^T x^{(i)}}{1 - h_\theta(x^{(i)})}\right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     \frac{y^{(i)} h_\theta(x^{(i)}) (1 - h_\theta(x^{(i)})) \frac{\partial}{\partial \theta_j} \theta^T x^{(i)}}{h_\theta(x^{(i)})}   - \frac{(1-y^{(i)}) h_\theta(x^{(i)}) (1 - h_\theta(x^{(i)})) \frac{\partial}{\partial \theta_j} \theta^T x^{(i)}}{1 - h_\theta(x^{(i)})}\right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     y^{(i)} (1 - h_\theta(x^{(i)})) x^{(i)}_j - (1-y^{(i)}) h_\theta(x^{(i)}) x^{(i)}_j\right ] \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     y^{(i)} (1 - h_\theta(x^{(i)})) - (1-y^{(i)}) h_\theta(x^{(i)}) \right ] x^{(i)}_j \newline&= - \frac{1}{m}\sum_{i=1}^m \left [     y^{(i)} - y^{(i)} h_\theta(x^{(i)}) - h_\theta(x^{(i)}) + y^{(i)} h_\theta(x^{(i)}) \right ] x^{(i)}_j \newline&= - \frac{1}{m}\sum_{i=1}^m \left [ y^{(i)} - h_\theta(x^{(i)}) \right ] x^{(i)}_j  \newline&= \frac{1}{m}\sum_{i=1}^m \left [ h_\theta(x^{(i)}) - y^{(i)} \right ] x^{(i)}_j
\end{align*}
$$
Vectorized form:

$$\nabla J(\theta) = \frac{1}{m} \cdot  X^T \cdot \left(g\left(X\cdot\theta\right) - \vec{y}\right)$$


------------------------------------------------------

### 4. Advanced Optimization

Besides gradient descent, there are other optimization methods:

conjugate gradient,  
BFGS,  
L_BFGS,  


The three algorithms above are used in advanced numerical computing. Compared with gradient descent, they have the following advantages:

1. There is no need to manually choose the learning rate $\alpha$ . You can think of them as having an intelligent inner loop (a line search algorithm) that automatically tries different learning rates $\alpha$ and automatically selects the best learning rate $\alpha$ . It can even choose a different learning rate for each iteration, so you do not need to choose one yourself.
2. They converge much faster than gradient descent.

The downside is that, compared with gradient descent, they are more complex.


For example:
```c

function [jVal, gradient] = costFunction(theta)

jVal = (theta(1)-5)^2 + (theta(2)-5)^2;

gradient = zeros(2,1);
gradient(1) = 2*(theta(1)-5);
gradient(2) = 2*(theta(2)-5);

```
Call the high-level function fminunc:
```c

options = optimset('GrabObj','on','MaxIter','100');
initialTheta = zeros(2,1);
[optTheta, functionVal, exitFlag] = fminunc(@costFunction, initialTheta, options);


```
Final result:
```c

optTheta = 
    
    5.0000
    5.0000
    
functionVal = 1.5777e-030
exitFlag = 1

```
`optTheta` represents the final computed result, and `functionVal` represents the minimum value of the cost function. Here it is `0`, which is what we expect. `exitFlag` indicates whether the optimization ultimately converged; `1` means it converged.

Here, `fminunc` attempts to find the minimum of a multivariable function, starting from an initial estimate. This is typically considered an unconstrained nonlinear optimization problem.

Some other examples:
```c

x =fminunc(fun,x0)                                   %Attempts to find a local minimum of the function starting near x0; x0 can be a scalar, vector, or matrix
x =fminunc(fun,x0,options)                           %Finds the minimum according to the settings in the options structure; use optimset to set options
x =fminunc(problem)                                  %Finds the minimum for problem, a structure defined in Input Arguments

[x,fval]= fminunc(...)                               %Returns the value of the objective function fun at the solution x
[x,fval,exitflag]= fminunc(...)                      %Returns exitflag, a value that describes the exit condition
[x,fval,exitflag,output]= fminunc(...)               %Returns a structure called output that contains optimization information
[x,fval,exitflag,output,grad]= fminunc(...)          %Returns the value of the gradient of the function at the solution x, stored in grad
[x,fval,exitflag,output,grad,hessian]= fminunc(...)  %Returns the value of the Hessian matrix of the function at the solution x, stored in hessian


```
------------------------------------------------------

## III. Multiclass Classification

In this section, we discuss how to use logistic regression to solve multiclass classification problems, introducing a one-vs-all classification algorithm.

![](https://img.halfrost.com/Blog/ArticleImage/69_7.png)

Now, when we have more than two classes, we will be classifying data among multiple categories. We extend our definition so that y = {0,1 ... n}, instead of y = {0,1}. Since y = {0,1 ... n}, we split the problem into n + 1 (+1 because indexing starts at 0) binary classification problems; in each one, we predict the probability that 'y' belongs to one of our classes.


Finally, feed x into each of the n + 1 classifiers, then take the maximum probability among the n + 1 classifiers; this is the probability value corresponding to $y=i$.


------------------------------------------------------

## IV. Logistic Regression Quiz


### 1. Question 1

Suppose that you have trained a logistic regression classifier, and it outputs on a new example x a prediction hθ(x) = 0.7. This means (check all that apply):


A. Our estimate for P(y=1|x;θ) is 0.7.  
B. Our estimate for P(y=0|x;θ) is 0.3.  
C. Our estimate for P(y=1|x;θ) is 0.3.  
D. Our estimate for P(y=0|x;θ) is 0.7.  


Answer: A, B  


### 2. Question 2

Suppose you have the following training set, and fit a logistic regression classifier hθ(x)=g(θ0+θ1x1+θ2x2).


Which of the following are true? Check all that apply.

A. Adding polynomial features (e.g., instead using hθ(x)=g(θ0+θ1x1+θ2x2+θ3x21+θ4x1x2+θ5x22) ) could increase how well we can fit the training data.  

B. At the optimal value of θ (e.g., found by fminunc), we will have J(θ)≥0.  

C. Adding polynomial features (e.g., instead using hθ(x)=g(θ0+θ1x1+θ2x2+θ3x21+θ4x1x2+θ5x22) ) would increase J(θ) because we are now summing over more terms.  

D. If we train gradient descent for enough iterations, for some examples x(i) in the training set it is possible to obtain hθ(x(i))>1.  


Answer: A, B


### 3. Question 3

For logistic regression, the gradient is given by ∂∂θjJ(θ)=1m∑mi=1(hθ(x(i))−y(i))x(i)j. Which of these is a correct gradient descent update for logistic regression with a learning rate of α? Check all that apply.


A. θj:=θj−α1m∑mi=1(hθ(x(i))−y(i))x(i) (simultaneously update for all j).  

B. θj:=θj−α1m∑mi=1(hθ(x(i))−y(i))x(i)j (simultaneously update for all j).  

C. θj:=θj−α1m∑mi=1(11+e−θTx(i)−y(i))x(i)j (simultaneously update for all j).  

D. θ:=θ−α1m∑mi=1(θTx−y(i))x(i).  


Answer: A, D

The difference between linear regression and logistic regression


### 4. Question 4

Which of the following statements are true? Check all that apply.

A. The cost function J(θ) for logistic regression trained with m≥1 examples is always greater than or equal to zero.  

B. Linear regression always works well for classification if you classify by using a threshold on the prediction made by linear regression.  

C. The one-vs-all technique allows you to use logistic regression for problems in which each y(i) comes from a fixed, discrete set of values.   

D. For logistic regression, sometimes gradient descent will converge to a local minimum (and fail to find the global minimum). This is the reason we prefer more advanced optimization algorithms such as fminunc (conjugate gradient/BFGS/L-BFGS/etc).  

Answer: A, C

For D, because the cost function used is the linear regression cost function, there will be many local optima.


### 5. Question 5
Suppose you train a logistic classifier hθ(x)=g(θ0+θ1x1+θ2x2). Suppose θ0=6,θ1=0,θ2=−1. Which of the following figures represents the decision boundary found by your classifier?

Answer: C

6-x2>=0, so when X2<6, the classification is 1.


------------------------------------------------------


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Logistic_Regression.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Logistic_Regression.ipynb)