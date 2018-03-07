<p align='center'>
<img src='../images/Machine-Learning_3.png'>
</p>



# What is Machine Learning?

在机器学习的历史上，一共出现了两种定义。

- 1956 年，开发了西洋跳棋 AI 程序的 Arthur Samuel 在标志着人工智能学科诞生的达特茅斯会议上定义了 “机器学习” 这个词，定义为，“在没有明确设置的情况下，使计算机具有学习能力的研究领域”。

- 1997 年，Tom Mitchell 提供了一个更现代的定义：“如果用 P 来测量程序在任务 T 中性能。若一个程序通过利用经验 E 在 T 任务中获得了性能改善，则我们就说关于任务 T 和 性能测量 P ，该程序对经验 E 进行了学习。”


例如：玩跳棋。

E = 玩很多盘跳棋游戏的经验

T = 玩跳棋的任务。

P = 程序将赢得下一场比赛的概率。

一般来说，任何机器学习问题都可以分配到两大类中的一个：

有监督学习 supervised learning 和无监督学习 unsupervised learning。

简单的说，监督学习就是我们教计算机去做某件事情，无监督学习是我们让计算机自己学习。

<p align='center'>
<img src='../images/machine-learning.png'>
</p>


------------------------------------------------------


Question 1
A computer program is said to learn from experience E with respect to some task T and some performance measure P if its performance on T, as measured by P, improves with experience E. Suppose we feed a learning algorithm a lot of historical weather data, and have it learn to predict weather. In this setting, what is E?

Answer
The process of the algorithm examining a large amount of historical weather data.

Explanation
T := The weather prediction task.
P := The probability of it correctly predicting a future date's weather.
E := The process of the algorithm examining a large amount of historical weather data.

Question 2
Suppose you are working on weather prediction, and you would like to predict whether or not it will be raining at 5pm tomorrow. You want to use a learning algorithm for this. Would you treat this as a classification or a regression problem?

Answer
Classification

Explanation
Classification is appropriate when we are trying to predict one of a small number of discrete-valued outputs, such as whether it will rain (which we might designate as class 0), or not (say class 1).

Question 3
Suppose you are working on stock market prediction, and you would like to predict the price of a particular stock tomorrow (measured in dollars). You want to use a learning algorithm for this. Would you treat this as a classification or a regression problem?

Answer
Regression

Explanation
Regression is appropriate when we are trying to predict a continuous-valued output, since as the price of a stock (similar to the housing prices example in the lectures).

Question 4
Some of the problems below are best addressed using a supervised learning algorithm, and the others with an unsupervised learning algorithm. Which of the following would you apply supervised learning to? (Select all that apply.) In each case, assume some appropriate dataset is available for your algorithm to learn from.

Explanation
Take a collection of 1000 essays written on the US Economy, and find a way to automatically group these essays into a small number of groups of essays that are somehow "similar" or "related". :=
        This is an unsupervised learning/clustering problem (similar to the Google News example in the lectures).

Given a large dataset of medical records from patients suffering from heart disease, try to learn whether there might be different clusters of such patients for which we might tailor separate treatements. :=
        This can be addressed using an unsupervised learning, clustering, algorithm, in which we group patients into different clusters.

Given genetic (DNA) data from a person, predict the odds of him/her developing diabetes over the next 10 years. :=
        This can be addressed as a supervised learning, classification, problem, where we can learn from a labeled dataset comprising different people's genetic data, and labels telling us if they had developed diabetes.

Given 50 articles written by male authors, and 50 articles written by female authors, learn to predict the gender of a new manuscript's author (when the identity of this author is unknown). :=
        This can be addressed as a supervised learning, classification, problem, where we learn from the labeled data to predict gender.

In farming, given data on crop yields over the last 50 years, learn to predict next year's crop yields. :=
        This can be addresses as a supervised learning problem, where we learn from historical data (labeled with historical crop yields) to predict future crop yields.

Examine a large collection of emails that are known to be spam email, to discover if there are sub-types of spam mail. :=
        This can addressed using a clustering (unsupervised learning) algorithm, to cluster spam mail into sub-types.

Examine a web page, and classify whether the content on the web page should be considered "child friendly" (e.g., non-pornographic, etc.) or "adult." :=
        This can be addressed as a supervised learning, classification, problem, where we can learn from a dataset of web pages that have been labeled as "child friendly" or "adult."

Examine the statistics of two football teams, and predicting which team will win tomorrow's match (given historical data of teams' wins/losses to learn from). :=
        This can be addressed using supervised learning, in which we learn from historical records to make win/loss predictions.

Question 5
Which of these is a reasonable definition of machine learning?

Answer
Machine learning is the field of study that gives computers the ability to learn without being explicitly programmed.

Explanation
This was the definition given by Arthur Samuel (who had written the famous checkers playing, learning program).


------------------------------------------------------


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine\_Learning/What\_is\_Machine\_Learning.md](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Machine_Learning/What_is_Machine_Learning.md)