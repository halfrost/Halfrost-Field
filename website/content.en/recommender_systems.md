+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-04-02T18:25:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/80_0.png"
slug = "recommender_systems"
tags = ["Machine Learning", "AI"]
title = "Collaborative Filtering and Low-Rank Matrix Factorization in Recommender Systems"

+++


>Because Ghost's syntax for recognizing LaTeX differs from standard LaTeX syntax, the LaTeX formulas in the following article may appear garbled for broader compatibility. If that happens and you don't mind, you can read the non-garbled version of this article on the author's [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this garbling issue when time permits. Thank you for your understanding.
>
> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Recommender\_Systems.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Recommender_Systems.ipynb)


## I. Predicting Movie Ratings

![](https://img.halfrost.com/Blog/ArticleImage/80_1.png)

Take predicting the rating that user 1 might give movie 3 as an example.

First, we use $x_1$ to represent the romantic movie genre, and $x_2$ to represent the action movie genre. The right side of the table in the image above shows the degree of relevance of each movie to these two categories. We assume $x_0=1$ by default. Then the degree of relevance of the first movie to the two genres can be expressed as: $x^{(3)}=\left[ \begin{array}{ccc}1 \\0.99 \\0 \end{array} \right]$ . Next, use $\theta^{(j)}$ to denote the rating preference of the j-th user for this type of movie. Here we assume that we already know (details below) $\theta^{(1)}=\left[ \begin{array}{ccc}0 \\5 \\0 \end{array} \right]$ , then we can use $(\theta^{(j)})^Tx^{(i)}$ to calculate the rating that user 1 might give movie 3. The computed result here is 4.95.


### 1. Objective Optimization

To make the most accurate prediction of user j's ratings, we need:

$$\min_{(\theta^{(j)})}=\frac{1}{2}\sum_{i:r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{k=1}^{n}{(\theta_k^{(j)})^2}$$

Solving for all $\theta$ gives: 


$$J(\theta^{(1)},\cdots,\theta^{(n_u)})=\min_{(\theta^{(1)},\cdots,\theta^{(n_u)})}=\frac{1}{2}\sum_{j=1}^{n_u}\sum_{i:r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{j=1}^{n_u}\sum_{k=1}^{n}{(\theta_k^{(j)})^2}$$


Consistent with the linear regression approach learned earlier, to compute $J(\theta^{(1)},\cdots,\theta^{(n_u)})$, we use gradient descent to update the parameters:

Update the bias (intercept):

$$\theta^{(j)}_0=\theta^{(j)}_0-\alpha \sum_{i:r(i,j)=1}((\theta^{(j)})^Tx^{(i)}-y^{(i,j)})x^{(i)}_0$$


Update the weights:

$$\theta^{(j)}_k=\theta^{(j)}_k-\alpha \left( \sum_{i:r(i,j)=1}((\theta^{(j)})^Tx^{(i)}-y^{(i,j)})x^{(i)}_k+\lambda \theta^{(j)}_k \right),\;\;\; k \neq 0$$


----------------------------------------------------------------------------------------------------------------

## II. Collaborative Filtering

The premise is that we know $\theta^{(j)}$, that is, each user's preference level for each movie genre. Then we can infer $x^{(i)}$ from each user's ratings for each movie = $(\theta^{(j)})^Tx^{(i)}$ .

### 1. Objective Optimization


When users provide the genres they like, namely $\theta^{(1)},\cdots,\theta^{(n_u)}$ , we can obtain $x^{(i)}$ from the following formula: 

$$\min_{(x^{(i)})}=\frac{1}{2}\sum_{j:r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{k=1}^{n}{(x_k^{(i)})^2}$$

Solving for all x gives:

$$\min_{(x^{(1)},\cdots,x^{(n_m)})}=\frac{1}{2}\sum_{i=1}^{n_m}\sum_{j:r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{i=1}^{n_m}\sum_{k=1}^{n}{(x_k^{(i)})^2}$$

As long as we obtain either $\theta$ or x, we can derive the other from it.


The basic idea of collaborative filtering is that when we obtain one set of data, we infer the other; then, based on the inferred result, we infer back again for optimization. After optimization, we continue inferring and optimizing in this way, collaboratively and iteratively.


### 2. Objective Optimization for Collaborative Filtering


1. Infer user preferences: given $x^{(1)},\cdots,x^{(n_m)}$ , estimate $\theta^{(1)},\cdots,\theta^{(n_\mu)}$ :
$$\min_{(\theta^{(1)},\cdots,\theta^{(n_\mu)})}=\frac{1}{2}\sum_{j=1}^{n_\mu}\sum_{i:r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{j=1}^{n_\mu}\sum_{k=1}^{n}{(\theta_k^{(j)})^2}$$

2. Infer item content: given $\theta^{(1)},\cdots,\theta^{(n_\mu)}$ , estimate $x^{(1)},\cdots,x^{(n_m)}$ :
$$\min_{(x^{(1)},\cdots,x^{(n_m)})}=\frac{1}{2}\sum_{i=1}^{n_m}\sum_{j:r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{i=1}^{n_m}\sum_{k=1}^{n}{(x_k^{(i)})^2}$$

3. Collaborative filtering: optimize $x^{(1)},\cdots,x^{(n_m)}$ while estimating $\theta^{(1)},\cdots,\theta^{(n_\mu)}$:
$$\min \; J(x^{(1)},\cdots,x^{(n_m)};\theta^{(1)},\cdots,\theta^{(n_\mu)})$$


That is:

$$\min_{(x^{(1)},\cdots,x^{(n_m)};\theta^{(1)},\cdots,\theta^{(n_\mu)})}=\frac{1}{2}\sum_{(i,j):r(i,j)=1}^{}{((\theta^{(j)})^T(x^{(i)})-y^{(i,j)})^2}+\frac{\lambda}{2}\sum_{i=1}^{n_m}\sum_{k=1}^{n}{(x_k^{(i)})^2}+\frac{\lambda}{2}\sum_{j=1}^{n_u}\sum_{k=1}^{n}{(\theta_k^{(j)})^2}$$

Because of regularization, the previous $x_0=1$,$\theta_0=0$ are no longer used here.


### 3. The Steps of the Collaborative Filtering Algorithm Are:

1. Randomly initialize $x^{(1)},\cdots,x^{(n_m)},\theta^{(1)},\cdots,\theta^{(n_\mu)} $ to some small values. Similar to parameter initialization in neural networks, do not initialize with 0 values, to avoid the system getting stuck in a dead state.
2. Use gradient descent to compute $J(x^{(1)},\cdots,x^{(n_m)},\theta^{(1)},\cdots,\theta^{(n_\mu)})$. The parameter update formulas are:
$$x^{(i)}_k=x^{(i)}_k-\alpha \left( \sum_{j:r(i,j)=1}((\theta^{(j)})^Tx^{(i)}-y^{(i,j)})\theta^{(j)}_k+\lambda x^{(i)}_k \right)$$
$$\theta^{(j)}_k=\theta^{(j)}_k-\alpha \left( \sum_{i:r(i,j)=1}((\theta^{(j)})^Tx^{(i)}-y^{(i,j)})x^{(i)}_k+\lambda \theta^{(j)}_k \right)$$
3. If the user's preference vector is $\theta$ and the item's feature vector is x, then the user's rating can be predicted as $\theta^Tx$ .

Because $\theta$ and x influence each other in the collaborative filtering algorithm, neither needs to use the bias terms $\theta_0$ and $x_0$; that is, $x \in \mathbb{R}^n$ and $\theta \in \mathbb{R}^n$ .


----------------------------------------------------------------------------------------------------------------

## III. Low Rank Matrix Factorization


### 1. Vectorization


![](https://img.halfrost.com/Blog/ArticleImage/80_2.png)

Again, take movie ratings as an example. First, we write the users' ratings as a matrix Y.


![](https://img.halfrost.com/Blog/ArticleImage/80_3.png)


A more detailed representation is shown in the figure above. Matrix Y can be represented as $\Theta^TX$ . This algorithm is also called Low Rank Matrix Factorization.


### 2. Mean Normalization

![](https://img.halfrost.com/Blog/ArticleImage/80_4.png)


When a user has not watched any movies, the final results computed using $\Theta^TX$ are all the same, so it cannot recommend any particular movie to the user very well.
![](https://img.halfrost.com/Blog/ArticleImage/80_5.png)


What mean normalization does is first compute the average value of each row, then subtract that row’s average from each data point to obtain a new rating matrix. Then it fits $\Theta^TX$ based on this matrix, and finally adds the average back to the resulting prediction, i.e., $\Theta^TX+\mu_i$ . This $\mu_i$ is then used as a weight for making recommendations where there was previously no information.


----------------------------------------------------------------------------------------------------------------

## IV. Recommender Systems Quiz


### 1. Question 1

Suppose you run a bookstore, and have ratings (1 to 5 stars) of books. Your collaborative filtering algorithm has learned a parameter vector θ(j) for user j, and a feature vector x(i) for each book. You would like to compute the "training error", meaning the average squared error of your system's predictions on all the ratings that you have gotten from your users. Which of these are correct ways of doing so (check all that apply)? For this problem, let m be the total number of ratings you have gotten from your users. (Another way of saying this is that $m=\sum^{n_m}_{i=1}\sum^{n_\mu}_{j=1}r(i,j))$. [Hint: Two of the four options below are correct.]


A. $$\frac{1}{m}\sum_{(i,j):r(i,j)=1}((\theta^{(j)})^{T}x_{i}^{(i)}-y^{(i,j)})^2$$

B. $$\frac{1}{m}\sum^{n_\mu}_{i=1}\sum_{j:r(i,j)=1}(\sum_{k=1}^{n}(\theta^{(j)})_{k}x_{k}^{(i)}-y^{(i,j)})^2$$

C. $$\frac{1}{m}\sum^{n_\mu}_{j=1}\sum_{i:r(i,j)=1}(\sum_{k=1}^{n}(\theta^{(k)})_{j}x_{i}^{(k)}-y^{(i,j)})^2$$

D. $$\frac{1}{m}\sum_{(i,j):r(i,j)=1}((\theta^{(j)})^{T}x_{i}^{(i)}-r(i,j))^2$$

Answer: A, B


### 2. Question 2

In which of the following situations will a collaborative filtering system be the most appropriate learning algorithm (compared to linear or logistic regression)?


A. You run an online bookstore and collect the ratings of many users. You want to use this to identify what books are "similar" to each other (i.e., if one user likes a certain book, what are other books that she might also like?)

B. You own a clothing store that sells many styles and brands of jeans. You have collected reviews of the different styles and brands from frequent shoppers, and you want to use these reviews to offer those shoppers discounts on the jeans you think they are most likely to purchase

C. You manage an online bookstore and you have the book ratings from many users. You want to learn to predict the expected sales volume (number of books sold) as a function of the average rating of a book.

D. You're an artist and hand-paint portraits for your clients. Each client gets a different portrait (of themselves) and gives you 1-5 star rating feedback, and each client purchases at most 1 portrait. You'd like to predict what rating your next customer will give you.

Answer: A, B

Collaborative filtering algorithms require a relatively large number of features and data points.

A. You run an online bookstore and collect ratings from many users. You want to use this to determine which books are “similar” to each other (for example, if a user likes a certain book, what other books might she also like?). There are many features, so use collaborative filtering.

B. You own a clothing store that sells jeans in many styles and brands. You have collected reviews of the different styles and brands from frequent shoppers, and you want to use these reviews to offer those shoppers discounts on the jeans you think they are most likely to purchase. There are many features, so use collaborative filtering.

C. You manage an online bookstore and have book ratings from many users. You want to learn to predict the expected sales volume (number of books sold) as a function of a book’s average rating. Linear regression is more appropriate.

D. You are an artist who hand-paints portraits for your clients. Each client receives a different portrait (of themselves) and gives you 1–5 star rating feedback, and each client purchases at most one portrait. You want to predict what rating your next customer will give you. Logistic regression is more appropriate.


### 3. Question 3

You run a movie empire, and want to build a movie recommendation system based on collaborative filtering. There were three popular review websites (which we'll call A, B and C) which users to go to rate movies, and you have just acquired all three companies that run these websites. You'd like to merge the three companies' datasets together to build a single/unified system. On website A, users rank a movie as having 1 through 5 stars. On website B, users rank on a scale of 1 - 10, and decimal values (e.g., 7.5) are allowed. On website C, the ratings are from 1 to 100. You also have enough information to identify users/movies on one website with users/movies on a different website. Which of the following statements is true?


A. It is not possible to combine these websites' data. You must build three separate recommendation systems.

B. You can merge the three datasets into one, but you should first normalize each dataset separately by subtracting the mean and then dividing by (max - min) where the max and min (5-1) or (10-1) or (100-1) for the three websites respectively.

C. You can combine all three training sets into one as long as your perform mean normalization and feature scaling after you merge the data.

D. You can combine all three training sets into one without any modification and expect high performance from a recommendation system.

Answer: B

Apply feature scaling.

### 4. Question 4

Which of the following are true of collaborative filtering systems? Check all that apply.

A. Even if each user has rated only a small fraction of all of your products (so r(i,j)=0 for the vast majority of (i,j) pairs), you can still build a recommender system by using collaborative filtering.

B. For collaborative filtering, it is possible to use one of the advanced optimization algoirthms (L-BFGS/conjugate gradient/etc.) to solve for both the $x^{(i)}$'s and $\theta^{(j)}$'s simultaneously.

C. For collaborative filtering, the optimization algorithm you should use is gradient descent. In particular, you cannot use more advanced optimization algorithms (L-BFGS/conjugate gradient/etc.) for collaborative filtering, since you have to solve for both the $x^{(i)}$'s and $\theta^{(j)}$'s simultaneously.
D. Suppose you are writing a recommender system to predict a user's book preferences. In order to build such a system, you need that user to rate all the other books in your training set.

Answer: A, B


### 5. Question 5

Suppose you have two matrices A and B, where A is 5x3 and B is 3x5. Their product is C=AB, a 5x5 matrix. Furthermore, you have a 5x5 matrix R where every entry is 0 or 1. You want to find the sum of all elements C(i,j) for which the corresponding R(i,j) is 1, and ignore all elements C(i,j) where R(i,j)=0. One way to do so is the following code:

![](https://img.halfrost.com/Blog/ArticleImage/7X_5_0.png)

Which of the following pieces of Octave code will also correctly compute this total? Check all that apply. Assume all options are in code.


A. $total = sum(sum((A * B) .* R))$

B. $C = A * B; total = sum(sum(C(R == 1)))$;

C. $C = (A * B) * R; total = sum(C(:))$;

D. $total = sum(sum(A(R == 1) * B(R == 1))$;


Answer: A, B

----------------------------------------------------------------------------------------------------------------

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Recommender\_Systems.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Recommender_Systems.ipynb)