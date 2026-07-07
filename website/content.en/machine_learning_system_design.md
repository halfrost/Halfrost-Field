+++
author = "一缕殇流化隐半边冰霜"
categories = ["Machine Learning", "AI"]
date = 2018-03-28T17:38:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/75_0_.png"
slug = "machine_learning_system_design"
tags = ["Machine Learning", "AI"]
title = "What Should You Consider When Designing a Machine Learning System?"

+++


>Because Ghost blogs recognize LaTeX syntax differently from standard LaTeX syntax, the LaTeX formulas in the following article may appear garbled for better generality. If they do, and if you do not mind, you can read the non-garbled version of this article on the author's [Github](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/contents.md). The author will fix this garbling issue when time permits. Thank you for your understanding.
>
> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)  
> Follow: [halfrost · GitHub](https://github.com/halfrost)  
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Machine\_Learning\_System\_Design.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Machine_Learning_System_Design.ipynb)


## I. Building a Spam Classifier

Spam classification is a 0/1 classification problem and can be solved with logistic regression. We will not repeat the logistic regression process here; instead, we will consider how to reduce the classification error rate:

- Expand the data sample as much as possible: a Honeypot does exactly this. It disguises itself as a machine that is highly attractive to hackers in order to lure them into attacking it, just as a honey pot attracts bees, thereby recording attack behaviors and techniques.
- Add more features: for example, we can add the email sender's address as a feature, or add punctuation marks as features (spam emails are often filled with eye-catching punctuation such as ? and !).
- Preprocess samples: as we can see in spam, attackers constantly evolve their techniques. Spam creators also upgrade their attack methods, such as tampering with word spellings to prevent problematic email content from being detected—for example, spelling medicine as med1cinie. Therefore, we need methods to recognize these misspellings and thereby improve the samples we feed into logistic regression.


If we want to solve a problem using machine learning, the best practice is:

1.Build a simple machine learning system and implement it quickly with a simple algorithm.

2.By plotting learning curves and examining errors, determine whether our algorithm suffers from high bias or high variance. Then improve the algorithm by adding more training data, features, and so on.

3.Perform error analysis. For example, when building a spam classifier, we examine which types of emails or which feature values consistently cause emails to be misclassified, and then correct them. Of course, the error metric is also very important; for instance, we can report the error rate to judge the quality of the algorithm.


----------------------------------------------------------------------------------------------------------------

## II. Handling Skewed Data


To evaluate whether a model is good or bad, we usually use visualized error analysis, that is, displaying the prediction accuracy. In fact, this has shortcomings. This kind of error metric is also known as the Skewed Classes problem.


![](https://img.halfrost.com/Blog/ArticleImage/75_1.png)

For example, suppose we are performing cancer analysis and finally obtain an algorithm with only a 1% error rate, meaning its accuracy reaches 99%. At first glance, 99% seems very high. However, we find that only 0.5% of patients in the training set have cancer, so this 1% error rate is no longer that reliable. Consider an even more extreme example: regardless of the input, all predicted outputs are 0 (that is, non-cancer). In this case, the accuracy is 99.5%, but this evaluation criterion clearly cannot reflect the classifier's performance.

This is because the data sizes of the two classes differ greatly. Here, because there are very few cancer samples, the prediction results tend toward one extreme. We call this type of situation the Skewed Classes problem.

Therefore, we need another evaluation method. One such evaluation metric is Precision and Recall.

![](https://img.halfrost.com/Blog/ArticleImage/75_2.png)


Create a 2 x 2 table, with the horizontal axis representing the actual values and the vertical axis representing the predicted values. Table cells 1-4 represent: correctly predicted positive samples (True positive), incorrectly predicted positive samples (False positive), incorrectly predicted negative samples (False negative), and correctly predicted negative samples (True negative), respectively.

![](https://img.halfrost.com/Blog/ArticleImage/75_3.png)


Precision = correctly predicted positive samples (True positive) / predicted positive samples (predicted positive), where predicted positive samples naturally include correctly predicted positive samples + incorrectly predicted positive samples.

$$Precision=\frac{True\;positive}{Predicated\;as\;positive }=\frac{True\;positive}{True\;positive+False\;positive}$$

Recall = correctly predicted positive samples (True positive) / actual positive samples (actual positive), where actual positive samples naturally include correctly predicted positive samples + incorrectly predicted negative samples.

$$Recall=\frac{True\;positive}{Actual\;positive}=\frac{True\;positive}{True\;positive+False\;negative}$$


If, as before, y is always 0, then although its accuracy is 99%, its recall is 0%. Therefore, this is very helpful for evaluating the correctness of an algorithm.


So how should Precision and Recall be evaluated?

Suppose we choose the average of the two. This seems feasible, but it still does not work for the previous extreme example. If the y we predict is always 1, then recall becomes 100%, while precision is very low; however, the average may still look relatively good. Therefore, we use the following evaluation method, called the F-score:

$$F_1\;Score = 2\frac{PR}{P+R}$$

P refers to Precision, and R refers to Recall.

----------------------------------------------------------------------------------------------------------------

## III. Using Large Data Sets


![](https://img.halfrost.com/Blog/ArticleImage/75_4.png)

In the field of machine learning, there is a well-known saying:

>It's not who has the best algorithm that wins. It's who has the most data.

The people who succeed are not those with the best algorithm, but those with the most data.


Why is this the case?

First, because we have a large number of features to train on the data, the training set error becomes very small; that is, $J_{train}(\theta)$ is very small. Then, because we provide a large amount of training data, this helps prevent overfitting and can make $J_{train}(\theta)\approx J_{test}(\theta)$ . In this way, our hypothesis function has neither high bias nor high variance, so comparatively speaking, training with big data will be more accurate.

Note that this requires not only a large amount of training data, but also more features. If there are only a few features—for example, only the size of a house is used to predict its price—then even the world's best salesperson cannot tell you the price of a house based only on its size.

When should we use a large-scale dataset? We must ensure that the model has enough parameters (clues). For linear regression/logistic regression, this means having sufficiently many features; for neural networks, it means having more hidden-layer units. In this way, sufficiently many features avoid the high-bias (underfitting) problem, while a sufficiently large dataset avoids the high-variance (overfitting) problem that can easily be caused by many features.


----------------------------------------------------------------------------------------------------------------

## IV. Machine Learning System Design Quiz


### 1. Question 1

You are working on a spam classification system using regularized logistic regression. "Spam" is a positive class (y = 1) and "not spam" is the negative class (y = 0). You have trained your classifier and there are m = 1000 examples in the cross-validation set. The chart of predicted class vs. actual class is:

Actual Class: 1	Actual Class: 0
Predicted Class: 1	85	890
Predicted Class: 0	15	10

For reference:

- Accuracy = (true positives + true negatives) / (total examples)
- Precision = (true positives) / (true positives + false positives)
- Recall = (true positives) / (true positives + false negatives)
- F1 score = (2 * precision * recall) / (precision + recall)

What is the classifier's F1 score (as a value from 0 to 1)?

Enter your answer in the box below. If necessary, provide at least two values after the decimal point.

Answer: 0.158

Simply substitute into the formula $2\frac{PR}{P+R}$ and calculate.

### 2. Question 2

Suppose a massive dataset is available for training a learning algorithm. Training on a lot of data is likely to give good performance when two of the following conditions hold true.

Which are the two?


A. When we are willing to include high order polynomial features of x (such as $x_{1}^{2}$, $x_{2}^{2}$,$x_{1}$,$x_{2}$, etc.).

B. The features x contain sufficient information to predict y accurately. (For example, one way to verify this is if a human expert on the domain can confidently predict y when given only x).
C. We train a learning algorithm with a small number of parameters (that is thus unlikely to overfit).

D. We train a learning algorithm with a large number of parameters (that is able to learn/represent fairly complex functions).

Answer: B, D

A. What is needed is a sufficient number of features, not high-order features.  
B. The features contain enough information to make accurate predictions.  
C. A small number of features is obviously not enough.  
D. There need to be enough variables (features).  


### 3. Question 3

Suppose you have trained a logistic regression classifier which is outputing hθ(x).

Currently, you predict 1 if $h_{\theta}(x)\geqslant threshold$, and predict 0 if $h_{\theta}(x)<threshold$, where currently the threshold is set to 0.5.

Suppose you decrease the threshold to 0.3. Which of the following are true? Check all that apply.


A. The classifier is likely to have unchanged precision and recall, but higher accuracy.

B. The classifier is likely to now have higher precision.

C. The classifier is likely to now have higher recall.

D. The classifier is likely to have unchanged precision and recall, but lower accuracy.

Answer: C

Lowering the threshold will only increase recall and decrease precision.


### 4. Question 4

Suppose you are working on a spam classifier, where spam emails are positive examples (y=1) and non-spam emails are negative examples (y=0). You have a training set of emails in which 99% of the emails are non-spam and the other 1% is spam. Which of the following statements are true? Check all that apply.


A. If you always predict non-spam (output y=0), your classifier will have 99% accuracy on the training set, but it will do much worse on the cross validation set because it has overfit the training data.

B. If you always predict non-spam (output y=0), your classifier will have 99% accuracy on the training set, and it will likely perform similarly on the cross validation set.

C. A good classifier should have both a high precision and high recall on the cross validation set.

D. If you always predict non-spam (output y=0), your classifier will have an accuracy of 99%.

Answer: B, C, D

A. The accuracy dropping on the cross validation set due to overfitting is not the issue here; this is a problem of skewed classes.  
B. If the training set has 99% accuracy, then the cross validation set is also very likely to have 99% accuracy. This is correct, because the data is randomly distributed, and the data distribution of the training set is similar to that of the cross validation set.  
C. A good classifier should have relatively high precision and recall. Correct.  
D. If we always predict every result as non-spam, then the accuracy will reach 99%. Correct.  

### 5. Question 5

Which of the following statements are true? Check all that apply.


A. On skewed datasets (e.g., when there are more positive examples than negative examples), accuracy is not a good measure of performance and you should instead use F1 score based on the precision and recall.


B. If your model is underfitting the training set, then obtaining more data is likely to help.


C. After training a logistic regression classifier, you must use 0.5 as your threshold for predicting whether an example is positive or negative.


D. It is a good idea to spend a lot of time collecting a large amount of data before building your first version of a learning algorithm.


E. Using a very large training set makes it unlikely for model to overfit the training data.

Answer: A, E

A. Using F1 score to measure accuracy is correct.  
B. The model does not fit the training set well; this is underfitting. Increasing the amount of data is useless for underfitting.  
C. The threshold does not necessarily have to be 0.5.  
D. Spending a lot of time collecting a large amount of data before building the first learning algorithm can obviously lead down a path of wasted time.  
E. Using more data samples can address overfitting. Correct.  


----------------------------------------------------------------------------------------------------------------

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/Machine\_Learning\_System\_Design.ipynb](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/Machine_Learning_System_Design.ipynb)