+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-04-03T18:28:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/81_0.png"
slug = "large_scale_machine_learning"
tags = ["Machine Learning", "AI"]
title = "How to Optimize Algorithms in Large-Scale Machine Learning?"

+++


>Because Ghost blogs recognize LaTeX with syntax that differs from standard LaTeX syntax, for better portability, the LaTeX formulas in the following article may appear garbled. If that happens and you do not mind, you can read the non-garbled version of this article on the author's [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this garbling issue when time permits. Thank you for your understanding.   
>
> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Large\_Scale\_Machine\_Learning.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Large_Scale_Machine_Learning.ipynb)

## I. Gradient Descent with Large Datasets

If we have a low-variance model, increasing the size of the dataset can help you obtain better results. How should we handle a training set with 1 million records?

Take a linear regression model as an example. In each gradient descent iteration, we need to compute the sum of squared errors over the training set. If our learning algorithm requires 20 iterations, this already represents a very large computational cost.

The first thing we should do is check whether a training set at such a large scale is truly necessary. Perhaps we can obtain good results using only 1,000 training examples. We can plot learning curves to help make this judgment.


![](https://img.halfrost.com/Blog/ArticleImage/81_1.png)


----------------------------------------------------------------------------------------------------------------


## II. Advanced Topics


### 1. Batch gradient descent


Having big data means that our algorithmic model must deal with a very large value of m. Recall our batch gradient descent method:

Repeat until convergence:

$$\theta_j=\theta_j-\alpha \frac{1}{m} \sum_{i=1}^{m}(h_{\theta}(x^{(i)})-y^{(i)})x^{(i)}_j,\\;\\;\\;\\;for\\;\\;j=0,\cdots,n$$
 
As you can see, every time we update a parameter $\theta_j$ , we have to traverse the entire sample set. When m is very large, this algorithm becomes relatively inefficient. However, batch gradient descent can find the global optimum:


![](https://img.halfrost.com/Blog/ArticleImage/81_2.png)


### 2. Stochastic gradient descent


For large datasets, stochastic gradient descent is introduced. The execution process of this algorithm is:

Repeat until convergence:

$$
\begin{align*}
for\\;\\;\\;i&=1,\cdots,m:\\
\theta_j&=\theta_j-\alpha(h_\theta(x^{(i)})-y^{(i)})x^{(i)}_j,\\;\\;\\;\\;for\\;\\;j=0,\cdots,n\\
\end{align*}
$$
 
Compared with batch gradient descent, stochastic gradient descent updates $\theta_j$ using only the current sample being traversed. Although the outer loop still needs to traverse all samples, in practice we can often converge before all samples have been traversed. Therefore, when facing large datasets, stochastic gradient descent performs exceptionally well.


![](https://img.halfrost.com/Blog/ArticleImage/81_3.png)


The figure above reflects the process by which stochastic gradient descent searches for the optimal solution. Compared with batch gradient descent, the curve for stochastic gradient descent is not as smooth; it is much more jagged, and it also tends to find a local optimum rather than a global optimum. Therefore, we usually need to plot debugging curves to monitor whether stochastic gradient descent is working correctly. For example, suppose the error is defined as $cost(\theta,(x^{(i)},y^{(i)}))=\frac{1}{2}(h_\theta(x^{(i)})-y^{(i)})^2$. Then, after every 1,000 iterations—that is, after traversing 1,000 samples—we compute the average error and plot it, obtaining a curve of error versus the number of iterations:


![](https://img.halfrost.com/Blog/ArticleImage/81_4.png)

In addition, there is no need to worry if you encounter the following curve. It does not mean that there is a problem with our learning rate; it may be that our averaging interval is too small:

![](https://img.halfrost.com/Blog/ArticleImage/81_5.png)


If we plot only every 5,000 iterations, the curve will be smoother:

![](https://img.halfrost.com/Blog/ArticleImage/81_6.png)


If we are facing a curve with an obvious upward trend, we should consider reducing the learning rate $\alpha$ :


![](https://img.halfrost.com/Blog/ArticleImage/81_7.png)


The learning rate $\alpha$ can also be optimized as the number of iterations increases:

$$\alpha=\frac{constant1}{iterationNumber+constant2}$$


As the number of iterations increases, our descent step size will slow down, avoiding oscillation:

![](https://img.halfrost.com/Blog/ArticleImage/81_8.png)


>Before stochastic gradient descent starts working, the dataset needs to be randomly shuffled so that the process of traversing samples is more dispersed.


### 3. Mini-batch gradient descent


Mini-batch gradient descent is a compromise between batch gradient descent and stochastic gradient descent. The parameter b specifies the number of samples used to update $\theta$ in each iteration. Assuming b=10,m=1000 , the workflow of mini-batch gradient descent is as follows:

Repeat until convergence:

$$
\begin{align*}
for\;\;\;i&=1,11,21,\cdots,991:\\
\theta_j&=\theta_j-\alpha \frac{1}{10}\sum_{k=i}^{i+9}(h_\theta(x^{(i)})-y^{(i)})x^{(i)}_j,\;\;\;\;for\;\;j=0,\cdots,n\\
\end{align*}
$$


----------------------------------------------------------------------------------------------------------------


### 4. Online learning

A user logs in to a website that provides freight shipping services and enters the sender and recipient addresses for the shipment. The website provides a shipping quote, and the user decides whether to purchase the service ( y=1 ) or not purchase the service ( y=0 ).

The feature vector x includes the sender/recipient addresses and quote information. We want to learn $p(y=1|x;\theta)$ to optimize the quote:

Repeat until convergence:

Obtain the sample (x,y) for this user and use this sample to update $\theta$:

$$\theta_j=\theta_j-\alpha(h_\theta(x)-y)x_j,\;\;\;for\;\;j=0,\cdots,n$$
 
This is **online learning**. Unlike the machine learning process mentioned in previous sections, online learning does not require a fixed sample set for training. Instead, it continuously receives samples and continuously learns from the received samples. Therefore, the prerequisite for online learning is that we are dealing with streaming data.


### 5. MapReduce

Earlier, we mentioned mini-batch gradient descent. Assuming  b=400,m=400,000,000 , our optimization of $\theta$ is:

$$\theta_j=\theta_j-\alpha \frac{1}{400} \sum i=1^{400}(h_\theta(x^i)-y^{(i)})x^{(i)}_j$$
 
Assume we have 4 machines. We first use the Map process to compute the summation terms in the expression in parallel. Each machine is assigned 100 samples for computation:

$$
\begin{align*}
temp^{(1)}_j&=\sum_{i=1}^{100}(h_\theta(x^{(i)}-y^{(i)})x^{(i)}_j\\
temp^{(2)}_j&=\sum_{i=101}^{200}(h_\theta(x^{(i)}-y^{(i)})x^{(i)}_j\\
temp^{(3)}_j&=\sum_{i=201}^{300}(h_\theta(x^{(i)}-y^{(i)})x^{(i)}_j\\
temp^{(4)}_j&=\sum_{i=301}^{400}(h_\theta(x^{(i)}-y^{(i)})x^{(i)}_j\\
\end{align*}
$$
Finally, the summation is performed through the Reduce operation:

$$\theta_j=\theta_j-\alpha \frac{1}{400}(temp_j^{(1)}+temp_j^{(2)}+temp_j^{(3)}+temp_j^{(4)})$$

We can use multiple machines for MapReduce. In this case, Map tasks are assigned to multiple machines:


![](https://img.halfrost.com/Blog/ArticleImage/81_9.png)


We can also use multiple cores on a single machine for MapReduce. In this case, Map tasks are assigned to multiple CPU cores:


![](https://img.halfrost.com/Blog/ArticleImage/81_10.png)


----------------------------------------------------------------------------------------------------------------


## III. Large Scale Machine Learning Quiz

### 1. Question 1

Suppose you are training a logistic regression classifier using stochastic gradient descent. You find that the cost (say, $cost(\theta,(x^{(i)},y^{(i)})$), averaged over the last 500 examples), plotted as a function of the number of iterations, is slowly increasing over time. Which of the following changes are likely to help?


A. Use fewer examples from your training set.

B. Try averaging the cost over a smaller number of examples (say 250 examples instead of 500) in the plot.
C. This is not possible with stochastic gradient descent, as it is guaranteed to converge to the optimal parameters $\theta$.

D. Try halving (decreasing) the learning rate $\alpha$, and see if that causes the cost to now consistently go down; and if not, keep halving it until it does.

Answer: D


### 2. Question 2

Which of the following statements about stochastic gradient descent are true? Check all that apply.

A. Stochastic gradient descent is particularly well suited to problems with small training set sizes; in these problems, stochastic gradient descent is often preferred to batch gradient descent.

B. In each iteration of stochastic gradient descent, the algorithm needs to examine/use only one training example.

C. Suppose you are using stochastic gradient descent to train a linear regression classifier. The cost function $J(\theta)=\frac{1}{2m}\sum^m_{i=1}(h_\theta(x^{(i)})-y^{(i)})^2$ is guaranteed to decrease after every iteration of the stochastic gradient descent algorithm.

D. One of the advantages of stochastic gradient descent is that it can start progress in improving the parameters $\theta$ after looking at just a single training example; in contrast, batch gradient descent needs to take a pass over the entire training set before it starts to make progress in improving the parameters' values.

E. n order to make sure stochastic gradient descent is converging, we typically compute $J_{train}(\theta)$ after each iteration (and plot it) in order to make sure that the cost function is generally decreasing.


F. If you have a huge training set, then stochastic gradient descent may be much faster than batch gradient descent.

G. In order to make sure stochastic gradient descent is converging, we typically compute $J_{train}(\theta)$ after each iteration (and plot it) in order to make sure that the cost function is generally decreasing.

H. Before running stochastic gradient descent, you should randomly shuffle (reorder) the training set.

Answer: F, H

C is incorrect  
G does not require the cost function to always decrease; it may decrease, so it is incorrect  

### 3. Question 3

Which of the following statements about online learning are true? Check all that apply.

A. Online learning algorithms are most appropriate when we have a fixed training set of size m that we want to train on.

B. Online learning algorithms are usually best suited to problems were we have a continuous/non-stop stream of data that we want to learn from.

C. When using online learning, you must save every new training example you get, as you will need to reuse past examples to re-train the model even after you get new training examples in the future.

D. One of the advantages of online learning is that if the function we're modeling changes over time (such as if we are modeling the probability of users clicking on different URLs, and user tastes/preferences are changing over time), the online learning algorithm will automatically adapt to these changes.


Answer: B, D


### 4. Question 4

Assuming that you have a very large training set, which of the following algorithms do you think can be parallelized using map-reduce and splitting the training set across different machines? Check all that apply.

A. Logistic regression trained using batch gradient descent.

B. Linear regression trained using stochastic gradient descent.

C. Logistic regression trained using stochastic gradient descent.

D. Computing the average of all the features in your training set $\mu=\frac{1}{m}\sum^m_{i=1}x^{(i)}$ (say in order to perform mean normalization).

Answer: A, D

The algorithms that can use map-reduce include logistic regression with batch gradient descent. Any algorithm that needs to compute a large number of values can use it; stochastic gradient descent does not need to compute a large number of values, so choose A and D.

B. Linear regression trained using batch gradient descent. So B is incorrect.

C. Incorrect

### 5. Question 5

Which of the following statements about map-reduce are true? Check all that apply.

A. When using map-reduce with gradient descent, we usually use a single machine that accumulates the gradients from each of the map-reduce machines, in order to compute the parameter update for that iteration.

B. Linear regression and logistic regression can be parallelized using map-reduce, but not neural network training.

C. Because of network latency and other overhead associated with map-reduce, if we run map-reduce using N computers, we might get less than an N-fold speedup compared to using 1 computer.

D. If you have only 1 computer with 1 computing core, then map-reduce is unlikely to help.

E. If you have just 1 computer, but your computer has multiple CPUs or multiple cores, then map-reduce might be a viable way to parallelize your learning algorithm.

F. In order to parallelize a learning algorithm using map-reduce, the first step is to figure out how to express the main work done by the algorithm as computing sums of functions of training examples.

G. Running map-reduce over N computers requires that we split the training set into $N^2$ pieces.

Answer: A, C, D

Using N computers is less than N times faster than using one. Use one computer to aggregate the data computed by the others. Neural networks also need to compute the cost function and involve a large amount of computation, so neural networks can also be parallelized.
B is incorrect  
C is correct  
E is incorrect    
F is incorrect    
G might be correct?  

----------------------------------------------------------------------------------------------------------------

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Large\_Scale\_Machine\_Learning.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Large_Scale_Machine_Learning.ipynb)

