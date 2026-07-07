+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-30T18:05:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/77_0_.png"
slug = "unsupervised_learning"
tags = ["Machine Learning", "AI"]
title = "Unsupervised Learning"

+++


>Because Ghost blogs recognize LaTeX with syntax that differs from standard LaTeX, the LaTeX formulas in the article below may appear garbled for the sake of broader compatibility. If that happens and you don’t mind, you can read the clean version of this article on the author’s [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this garbling issue when time permits. Thank you for your understanding.
>
> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Unsupervised\_Learning.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Unsupervised_Learning.ipynb)

## I. Clustering


### 1. Definition

Starting from this section, we officially enter the topic of unsupervised learning. As the name suggests, unsupervised learning is learning without supervision—a free-form way of learning. This learning paradigm does not require prior knowledge as guidance; instead, it continuously builds self-awareness, reinforces itself, and ultimately performs self-induction. In machine learning, unsupervised learning can be simply understood as not providing corresponding category labels for the training set. Its contrast with supervised learning is as follows:

A training set under supervised learning:

$$\left\{ (x^{(1)},y^{(1)}),(x^{(2)},y^{(2)}),\cdots,(x^{(m)},y^{(m)}) \right\}$$

A training set under unsupervised learning:

$$\left\{ (x^{(1)}),(x^{(2)}),(x^{(3)}),\cdots,(x^{(m)}) \right\}$$


![](https://img.halfrost.com/Blog/ArticleImage/77_1.png)


In supervised learning, we call the process of assigning samples to classes classification. In unsupervised learning, we call the process of partitioning objects into different sets clustering. The verb “cluster” is very precise: it vividly describes the process by which objects autonomously move closer to the set they belong to.

In clustering, we call the set an object belongs to a cluster.


### 2. K-Means 

In clustering problems, we need to automatically divide unlabeled data into closely related subsets using an algorithm. K-means clustering is currently the most widely used clustering method.

![](https://img.halfrost.com/Blog/ArticleImage/77_2.png)


We run the K-means clustering algorithm as follows. First, randomly choose two points. These two points are called cluster centroids, namely the red and blue crosses in the figure. K-means clustering is an iterative method. It does two things: cluster assignment and moving the cluster centroids.

In each iteration of the K-means clustering algorithm, the first step is cluster assignment. First, iterate over all samples, that is, every green point in the figure above. Then, based on whether each point is closer to the red centroid or the blue centroid, assign each data point to one of the two different cluster centroids.

For example, the two centroids we randomly selected the first time and their cluster assignments are shown below:

![](https://img.halfrost.com/Blog/ArticleImage/77_3.png)

The second step, naturally, is to move the cluster centroids. We need to move the two centroids to the mean of the data assigned to each of the two classes. What we need to do is find all the red points, compute their mean, and move the red cross to that mean; the same applies to the blue cross.


![](https://img.halfrost.com/Blog/ArticleImage/77_4.png)


Then, by repeatedly performing the two steps above and iterating until the cluster centroids no longer change, K-means clustering has converged. At that point, we can find the two most relevant clusters in the data. The process is roughly shown below:


![](https://img.halfrost.com/Blog/ArticleImage/77_5.png)


![](https://img.halfrost.com/Blog/ArticleImage/77_6.png)


![](https://img.halfrost.com/Blog/ArticleImage/77_7.png)


The K-means clustering algorithm has two inputs: one is the parameter K, which is the number of clusters you want to extract from the data. The other is a training set that has x values but no y values.


The following is the K-means clustering algorithm.

The first step is to randomly initialize K cluster centroids, denoted as:  $\mu_1, \mu_2,\cdots,\mu_k$ .

The second major part is iteration. The first loop is: for each training example, we use the variable $c^{(i)}$ to denote the index of the centroid among the K cluster centroids that is closest to $x^{(i)}$ . We can compute this using $min_k||x^{(i)}-\mu_k||$ . The second loop is: move the cluster centroids. Set  $\mu_k$ , that is, the value of the centroid, to the mean of the cluster we just assigned.

For example:  $\mu_2$ is assigned several sample values: $x^{(1)},x^{(5)},x^{(6)},x^{(10)}$ . This means: $c^{(1)}=2,c^{(5)}=2,c^{(6)}=2,c^{(10)}=2$ . Then the new value of  $\mu_2$ should be: $\frac{1}{4}[ x^{(1)}+x^{(5)}+x^{(6)}+x^{(10)}]$ .


### 3. Optimization


Like other machine learning algorithms, K-Means also needs to evaluate and minimize the clustering cost. Before introducing the K-Means cost function, let’s first introduce the following definition:

$\mu^{(i)}_c$=the cluster centroid to which sample $x^{(i)}$ is assigned
 
Introduce the cost function:

$$J(c^{(1)},c^{(2)},\cdots,c^{(m)};\mu_1,\mu_2,\cdots,\mu_k)=\frac{1}{m}\sum_{i=1}^m\left \| x^{(i)}-\mu_c(i) \right \|^2$$
 
J is also called the distortion cost function. When debugging K-means clustering, you can check whether it converges to determine whether the algorithm is working correctly.

In fact, the two steps of K-Means already complete the process of minimizing the cost function:

1. During sample assignment:

We fix  $(\mu_1,\mu_2,\cdots,\mu_k)$ , and minimize J with respect to  $(c^{(1)},c^{(2)},\cdots,c^{(m)})$ .

2. During centroid movement:

We then minimize J with respect to $(\mu_1,\mu_2,\cdots,\mu_k)$ .

Because each iteration of K-Means minimizes J, the following cost-function curve will not occur:

![](https://img.halfrost.com/Blog/ArticleImage/77_8.png)


### 4. How to Initialize Cluster Centroids


When we run the K-means algorithm, the value of K, the number of cluster centroids, should be less than the total number of samples m.

Then we randomly choose K training examples as the cluster centroids. For example, when K=2, as shown in the figure on the right, randomly choose those two training examples as two different cluster centroids.

However, choosing them randomly in this way can cause K-means to fall into a poor local optimum.

![](https://img.halfrost.com/Blog/ArticleImage/77_9.png)


For example, given the data in the left figure, it is easy to see that it can be divided into 3 clusters. However, when the random initialization is poor, the algorithm may fall into a local optimum rather than the global optimum, as in the two cases shown in the lower-right figures.

Therefore, our random initialization procedure is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/77_10.png)

Usually, we randomly choose K samples as the K cluster centroids ( K<m ). However, as shown in the figure below, different initializations may lead to different clustering results. Reaching the global optimum is certainly good, but what we often get is a local optimum.

![](https://img.halfrost.com/Blog/ArticleImage/77_12.png)

![](https://img.halfrost.com/Blog/ArticleImage/77_13.png)


At present, it is still difficult to avoid poor clustering results in advance. We can only try different initializations:

for  i=1  to  100 ：

1. Randomly initialize, run K-Means, and obtain the cluster $c^{(i)}$ to which each example belongs, as well as the centroid positions $\mu$ for each cluster:
$$c^{(1)},c^{(2)},\cdots,c^{(m)};\mu_1,\mu_2,\cdots,\mu_k$$
2. Compute the distortion function J 

Choose the result with the smallest J among these 100 runs as the final clustering result.


Randomly choose K values, but repeat the process 100 times without duplication, and take the result with the lowest $J(c^{(1)},c^{(2)},\cdots,c^{(m)};\mu_1,\mu_2,\cdots,\mu_k)$ .


### 5. How to Determine the Number of Clusters


Elbow Method:

![](https://img.halfrost.com/Blog/ArticleImage/77_11.png)

We observe how the cost function changes as the number of cluster centroids increases. Sometimes we get a plot like the one on the left, where we can see an elbow at K=3. Because the cost function drops rapidly from 1 to 3 and then decreases more slowly, K=3—that is, dividing the data into 3 classes—is a good choice.

However, reality is often harsh. We may also get the cost function on the right, where there is no elbow at all, making the choice difficult.


----------------------------------------------------------------------------------------------------------------


## II. Unsupervised Learning Quiz


### 1. Question 1

For which of the following tasks might K-means clustering be a suitable algorithm? Select all that apply.

A. Given a database of information about your users, automatically group them into different market segments.

B. Given sales data from a large number of products in a supermarket, figure out which products tend to form coherent groups (say are frequently purchased together) and thus should be put on the same shelf.

C. Given historical weather records, predict the amount of rainfall tomorrow (this would be a real-valued output)
D. Given sales data from a large number of products in a supermarket, estimate future sales for each of these products.


Answer: A, B

A. The market segmentation example above.  
B. An instance of market segmentation.  
C. Given historical weather records, that means the true values are explicitly known. This is supervised learning.  
D. Same as C.  


### 2. Question 2

Suppose we have three cluster centroids $\mu_{1}  = \begin{bmatrix}
1\\ 
2
\end{bmatrix}$, $\mu_{2}  = \begin{bmatrix}
-3\\ 
0
\end{bmatrix}$ and $\mu_{3}  = \begin{bmatrix}
4\\ 
2
\end{bmatrix}$. Furthermore, we have a training example $x^{(i)}  = \begin{bmatrix}
3\\ 
1
\end{bmatrix}$. After a cluster assignment step, what will $c^{(i)}$ be?


A. $c^{(i)} = 1$  

B. $c^{(i)} = 3$  

C. $c^{(i)} = 2$  

D. $c^{(i)} $ is not assigned  

Answer: B

Compute the minimum value of $\frac{1}{m}\sum^{m}_{i=1}\left \| x^{(i)} - \mu_{c}^{(i)} \right \|^{2}$ by substituting the values; option B gives the minimum.


### 3. Question 3

K-means is an iterative algorithm, and two of the following steps are repeatedly carried out in its inner-loop. Which two?


A. Using the elbow method to choose K.

B. The cluster assignment step, where the parameters $c^{(i)} $ are updated.

C. Feature scaling, to ensure each feature is on a comparable scale to the others.

D. Move the cluster centroids, where the centroids $\mu_{k}$ are updated.

Answer: B, D


### 4. Question 4

Suppose you have an unlabeled dataset $\begin{Bmatrix}
x^{(1)},\cdots,x^{(m)}
\end{Bmatrix}$. You run K-means with 50 different random initializations, and obtain 50 different clusterings of the data. What is the recommended way for choosing which one of these 50 clusterings to use?


A. The only way to do so is if we also have labels y(i) for our data.

B. For each of the clusterings, compute $\frac{1}{m}\sum^{m}_{i=1}\left \| x^{(i)} - \mu_{c}^{(i)} \right \|^{2}$, and pick the one that minimizes this.

C. Always pick the final (50th) clustering found, since by that time it is more likely to have converged to a good solution.

D. The answer is ambiguous, and there is no good way of choosing.


Answer: C


Choose the initialization with the smallest cost function.


### 5. Question 5

Which of the following statements are true? Select all that apply.


A. If we are worried about K-means getting stuck in bad local optima, one way to ameliorate (reduce) this problem is if we try using multiple random initializations.

B. Since K-Means is an unsupervised learning algorithm, it cannot overfit the data, and thus it is always better to have as large a number of clusters as is computationally feasible.

C. The standard way of initializing K-means is setting $\mu_{1},\cdots,\mu_{k}$ to be equal to a vector of zeros.

D. For some datasets, the "right" or "correct" value of K (the number of clusters) can be ambiguous, and hard even for a human expert looking carefully at the data to decide.

Answer: A, D

A. To reduce the chance of getting stuck in a local optimum, we can choose random initial parameters multiple times.    
B. The claim that, because unsupervised learning does not overfit, we can choose more clusters is obviously incorrect. More clusters are not necessarily better; it depends on our requirements.    
C. The cluster centroids should be initialized by randomly setting them equal to values from the training examples.    
D. The value of K is difficult to determine; this is correct.  

----------------------------------------------------------------------------------------------------------------


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Unsupervised\_Learning.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Unsupervised_Learning.ipynb)