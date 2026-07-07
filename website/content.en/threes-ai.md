+++
author = "一缕殇流化隐半边冰霜"
categories = ["AI"]
date = 2018-02-14T15:35:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/67_0.png"
slug = "threes-ai"
tags = ["AI"]
title = "Threes-AI Plays Threes (Part 1)"

+++


AI for the Threes! game.

# Inspiration

A month ago, I took part in an AI competition with two friends. Although the result was not ideal, I at least enjoyed the fun of programming. That competition made me realize that, in addition to writing server-side systems, Go is also very good at building game simulators and AI. Recently, the assistants for WeChat Jump Jump and Chongding Conference were basically written in Go as well. So I couldn't sit still anymore and decided to write one too, as a commemoration of that competition.


Since I also come from a client-side background, this AI must be able to grind scores on a phone as well. So I needed to find a mobile game—one that three people can play, or whose name contains the word “three”. Hence:


> Three people join one AI competition  ---> Threes-AI

# “Showing Off” the Scores

So far, this Go version of the AI has been run in 3 places, with 200 games in each. The ratio of high-score runs is only about 20%. So I also hope that in the second phase of the project—the machine learning phase—I can raise the high-score rate to 100%.

## 1. Official play threes game Website

This site is the web version of the official game.


![](https://img.halfrost.com/Blog/ArticleImage/67_1.png)

![](https://img.halfrost.com/Blog/ArticleImage/67_2.png)

![](https://img.halfrost.com/Blog/ArticleImage/67_3.png)

The high-score video is here: [Tencent Video link](https://v.qq.com/x/page/w0559rco3qz.html)


<embed src="https://imgcache.qq.com/tencentvideo_v1/playerv3/TPout.swf?max_age=86400&v=20161117&vid=w0559rco3qz&auto=0" allowFullScreen="true" quality="high" width="900" height="720" align="middle" allowScriptAccess="always" type="application/x-shockwave-flash"></embed>

## 2. threes Android Client

The reason there are no screenshots from the iOS client here is that the iOS client requires jailbreak to run. The devices I have are all on iOS 11.2+, so once a jailbreak becomes available in the future, I can run the scores again.

![](https://img.halfrost.com/Blog/ArticleImage/67_4.png)

![](https://img.halfrost.com/Blog/ArticleImage/67_5.png)


## 3. Self-Hosted threes game Website

To train a model through machine learning myself, and also to publicly demonstrate the strength of this AI, I faithfully recreated a web version according to the official game rules.

![](https://img.halfrost.com/Blog/ArticleImage/67_6.png)

![](https://img.halfrost.com/Blog/ArticleImage/67_7.png)


The high-score video is here: [Tencent Video link](https://v.qq.com/x/page/e0559nle7dh.html)


<embed src="https://imgcache.qq.com/tencentvideo_v1/playerv3/TPout.swf?max_age=86400&v=20161117&vid=e0559nle7dh&auto=0" allowFullScreen="true" quality="high" width="900" height="720" align="middle" allowScriptAccess="always" type="application/x-shockwave-flash"></embed>

(Some people asked why the video above feels sped up. It actually isn't; you can tell from the timer next to it that it is running at normal speed. So why does it look so fast? The current online version adds a 400 ms movement animation. During local training, I removed that 400 ms animation delay because the animation time is unnecessary. That is why the video above appears very fast; the AI itself is the same.)

There is a “rumor” circulating online: when a 12288 tile is created—that is, when two 6144 tiles merge—the game ends and starts playing the game creators’ credits. This rule does not exist on this website; you can create tiles as large as possible. There is no upper limit on the score, which also makes it possible to fully test the AI’s intelligence.

Of course, for the first two official game URLs, I have never actually created a 12288 tile even once, so I cannot verify whether the “rumor” is true. Creating a 12288 tile with 100% certainty is also a goal of this AI. **That goal has not been reached yet**.


# How to Run


## 1. Self-Hosted threes game Website

### Docker
```go

// First start the Go server; port is 9000
docker container run --rm -p 9000:9000 -it halfrost/threes-ai:go-0.0.1

// Then start the web frontend; http://127.0.0.1:9888
docker container run --rm -p 9888:9888 -it halfrost/threes-ai:web-0.0.1

```

### Local

Building locally is a bit more involved and is also done in two steps: first build the Go server, then build the web frontend.

First, build the Go server:
```go

// Return to the project root directory
cd threes-ai
go run main.go

```
The above command builds the Go server, which listens for incoming messages on port 9000.

Next, build the web app:

Because the project is based on Meteor, please first set up the local Meteor environment. Install Meteor: [Installation guide](https://www.meteor.com/install)
```go

// Enter the threes! web root directory
cd threes-ai/threes!
meteor 

```
The above command will run the web app at http://localhost:3000.

At this point, it is already running locally.

Next, let’s talk about how to build a Docker image locally.

First, build the Go server. Since Docker runs Linux internally, you need to pay attention to cross-compilation when building; otherwise, the resulting Docker image will not be executable. For the specific build steps, see the instructions in the Dockerfile\_go file.
```go

docker image build -t threes_go:0.0.1 .
docker container run --rm -p 9000:9000 -it threes_go:0.0.1

```
Repackage the web:
```go

cd threes-ai/threes!
meteor build ./dist

```
After the preceding command finishes, a dist folder will be generated in the current directory, and it will contain the `threes!.tar.gz` archive. Extracting this archive will produce a bundle file, which is the file we need to deploy.

At this point, you can also run this production web build locally. Use the following command:
```go

cd dist/bundle
ROOT_URL=http://127.0.0.1 PORT=9888 node main.js

```
At this point, the web service will also be running at http://127.0.0.1:9888. Note that the Node version here must be 8.9.4. The Node version requirement comes from the Meteor version requirement: Meteor 1.6 corresponds to Node 8.9.4. The author has also pinned the Node version in the .nvmrc file. Back to the main point: packaging the web Docker image.

For the subsequent steps to package it into a Docker image, please refer to the steps in the Dockerfile\_web file.
```go

docker image build -t threes_web:0.0.1 .
docker container run --rm -p 9888:9888 -it threes_web:0.0.1

```
First run the Docker image for the Go server, then start the Docker image for the web app.

## 2. play threes game official website

First, package the Go program as a dynamic library so it can be called from Python.
```go

go build -buildmode=c-shared -o threes.so main.go

```
The command above packages the Go code into the `threes.so` dynamic library.

Next, we need to use Chrome’s remote debugging mode to establish a WebSocket connection. What `threes_ai_web.py` does is pass the board’s numeric information from the web page to Go. After the Go function finishes processing, it returns the direction for the next move. Finally, that direction is sent back to the web page via WebSocket to simulate the move.
```go

sudo /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9162

python threes_ai_web.py -b chrome -p 9162

```
Sometimes, if the `sudo` command is not used, certain errors may occur, such as GPU allocation failures.
```go

A new window has been created in the existing browser session.
[29819:45571:0225/225036.004108:ERROR:browser_gpu_channel_host_factory.cc(121)] Failed to launch GPU process.

```
If you encounter the error above, quit Chrome completely, then run it again with `--remote-debugging-port=9162`. A new websocket connection is typically established, for example:
```go

DevTools listening on ws://127.0.0.1:9162/devtools/browser/86c6deb3-3fc1-4833-98ab-0177ec50f1fa

```
`threes_ai_web.py` still has some issues; sometimes an error can cause the ws connection to drop. I’ll release it after fixing this later.


## 3. FAQ

### 1. The `halfrost/threes-ai:web-0.0.1` image has a 0.0.2 version. Why do the commands above use version 0.0.1?

This has to do with the deployment server. In the current source code, line 367 of `threes-ai/threes!/client/js/game.js` uses port 9000 in version 0.0.1, while version 0.0.2 uses port 8999 there.

Why is the port number the only difference between the two versions? Because of SSL. When deployed to a server, the site runs over HTTPS, so ws becomes a wss connection. When running locally, it does not matter because it is either localhost or 127.0.0.1, both over HTTP. Since SSL is required on the server side, nginx needs to add a reverse proxy layer to support wss. nginx listens on the web server’s port 8999, adds SSL, and forwards traffic to the Go server’s port 9000. This enables wss interaction between the web app and Go. When running locally, you do not need this extra setup: everything can use port 9000 directly. The web server connects directly to the Go server on port 9000 for ws communication.
 

### 2. During server deployment, the error `WebSocket connection to 'wss://XXXX' failed: Error in connection establishment: net::ERR_CONNECTION_REFUSED` occurs. How can it be fixed?

In general, the CONNECTION_REFUSED error above may have the following three causes:

- 1. The server’s iptables may be blocking the port
- 2. The IP address or port may be wrong, or the protocol may not be supported
- 3. The server-side service is not running

I ran into this issue during deployment. I first checked with iptables and found no problem. The second possibility was that wss was not supported, so I checked the port with the openssl command:
```go

openssl s_client [-connect host:port>] [-verify depth] [-cert filename] [-key filename] 
 [-CApath directory] [-CAfile filename][-reconnect] [-pause] [-showcerts] [-debug] [-msg] 
 [-nbio_test] [-state] [-nbio] [-crlf] [-ign_eof] [-quiet]

```
Testing showed that the port did not support SSL, so adding an SSL layer via an nginx proxy resolved the issue above.


# Game Analysis

The hard part about Threes is that it is a **game you are guaranteed to lose**. Once the game reaches the later stages and a 6144 tile has been created, for much of the remaining time the position occupied by that tile can no longer be moved. It is effectively as if, out of the 4 * 4 = 16 cells, one has to be taken away for it. In the late game, the tiles on the board also cannot be merged all at once, so there is very little free space left. You often get “squeezed to death” because there is no room to maneuver, or because several 1s or several 2s arrive in a row and you cannot make a 3.

During the design of the web version, I did not implement the same “level-skipping” mode as the client, where generated tiles can be multiples of 3, such as 3, 6, 12, 24, 96, 192, 384, and so on. Therefore, the web version may be slightly easier than the client version.

Why is it easier? Because although large tiles will not appear (large tiles have high scores), and the game lasts longer, the survival rate is also slightly higher. If 96, 384, and 768 each arrive as single tiles in succession, many tiles that cannot be merged will suddenly appear on the board. Although the score will surge, those tiles cannot be merged, which prevents movement and quickly ends the game.

The client does have the “level-skipping” setting, so these tiles may appear after some time. I also discovered this issue while testing the AI. The probability of being forced to death by a run of single 1s or single 2s is not very high; instead, there are many cases where high-scoring large tiles force the game to end. This results in shorter survival times and scores that are not as high as in the web version.

There are indeed techniques when it comes to board layout.

The optimal layout is based on monotonicity, as shown in the two images below:

![](https://img.halfrost.com/Blog/ArticleImage/67_8.png)

![](https://img.halfrost.com/Blog/ArticleImage/67_9.png)


As you can see, the layouts in these two images are the best, because adjacent tiles can continue to merge into the next higher level after being combined. This also gives the fastest merge speed and clears tiles from the board as quickly as possible. If you do not arrange the board with this kind of monotonicity, the final outcome is often that your own chaotic layout leaves some tiles impossible to merge, and you ultimately “force yourself to death.”

# Algorithmic Ideas

This repo uses Expectimax Search. Of course, there are other ways to solve this problem. I will briefly mention those algorithmic ideas as well; they correspond to Algorithm 2 and Algorithm 3, but I will not implement them in code.

## 1. Expectimax Search Trees

In daily life, there are situations where, even after careful thought, we still cannot determine what kind of outcome a decision will lead to. Will it be good or bad?

- 1. When drawing poker cards, you never know what the next card will be, or how that unknown card will affect the game.
- 2. In Minesweeper, each time you click a square, it may be a mine or it may be a number. The random placement of mines directly determines whether the game ends immediately in that round.
- 3. In Pac-Man, the ghosts appear at random positions, which directly affects the route planning that follows.
- 4. In Threes!, 1 and 2 tiles appear randomly, which affects how we should move the tiles.

All of the above situations can be handled using Expectimax Search Trees. These problems all aim to find a maximum value (score). The main idea is as follows:

Max nodes are the same as in minimax search and serve as the root of the entire tree. “Chance” nodes are inserted in between. They are similar to min nodes, but account for nodes whose outcomes are uncertain. Finally, a weighted average is used to compute the maximum expected value, which is the final result.

**This type of problem can also be reduced to a Markov Decision Process: determining the next action based on the current board state.**

### 1. Some Properties of Expectimax

The other nodes are not adversarial nodes, nor are they under our control. The reason is their uncertainty. We do not know what these nodes will cause to happen.

Each state likewise has an expected maximum value. However, we cannot blindly choose the expectimax value, because it is not 100% safe; it may cause the entire tree to become “unstable.”

Chance nodes are managed by weighted-average probabilities, rather than by always choosing the minimum value.


### 2. About Pruning

**There is no concept of pruning in expectimax**.

First, there is no notion of an opponent playing an “optimal game,” because the opponent’s behavior is random and unknown. Therefore, no matter what the current expected value is, random situations that appear in the future may overturn the current state. For this reason as well, searching for expectimax is slow (though there are acceleration strategies).


### 3. Probability Function

In Expectimax Search, we have a probability model for the opponent’s behavior in any state. This model may be a simple uniform distribution (for example, rolling dice), or it may be complex and require extensive computation to obtain a probability.


The most uncertain factor is the opponent’s behavior or random environmental changes. Suppose that for these states, we have a “magical” function that can produce the corresponding probability. The probability affects the final expected value. The expected value of a function is its average, weighted by the probability distribution of the inputs.

For example: calculating the time needed to get to the airport. The weight of the luggage affects the driving time.
```go

L（none）= 20，L（light）= 30，L（heavy）= 60

```
In the three cases, the probability distributions are:
```go

P（T）= {none：0.25，light：0.5，heavy：0.25}

```
Then the estimated driving time is denoted as
```go

E [L（T）] =  L（none）* P（none）+ L（light）* P（light）+ L（heavy）* P (heavy)
E [L（T）] =  20 * 0.25）+（30 * 0.5）+（60 * 0.25）= 35

```

### 4. Mathematical Theory

In probability theory and statistics, the mathematical expectation (or mean, often simply called the expected value) is the sum of each possible outcome of an experiment multiplied by the probability of that outcome. It is one of the most fundamental mathematical characteristics. It reflects the average value of a random variable.

It is worth noting that the expected value is not necessarily the same as “expectation” in the everyday sense—the “expected value” may not be equal to any individual outcome. The expected value is the average of the values output by the variable. It does not necessarily belong to the set of possible output values of the variable.

The law of large numbers states that as the number of repetitions approaches infinity, the arithmetic mean of the observed values almost surely converges to the expected value.


### 5. Details

Let’s talk about the concrete approach.

![](https://img.halfrost.com/Blog/ArticleImage/67_10.png)

![](https://img.halfrost.com/Blog/ArticleImage/67_11.png)


As the two figures above show, for each situation, there can be 4 possible operations. Each operation will produce a new tile, and the position where the new tile appears follows a stable probability distribution. We compute the expected value for every possible situation. This yields the tree-like structure shown above.

Here is a more detailed example. As shown below, suppose the current board state is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/67_12.png)


The next tile is 2. Where will it appear? There are 16 possible cases in total.

![](https://img.halfrost.com/Blog/ArticleImage/67_13.png)

If we perform the UP move, there are 4 possible positions where the 2 tile can appear.
If we perform the DOWN move, there are 4 possible positions where the 2 tile can appear.
If we perform the LEFT move, there are 4 possible positions where the 2 tile can appear.
If we perform the RIGHT move, there are 4 possible positions where the 2 tile can appear.

After obtaining these 16 cases, we continue recursively. The recurrence formula is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/67_14.png)

The formula above is essentially repeated expected-value computation.


However, recursion cannot continue indefinitely; it needs a termination condition. The convergence condition I set here is that recursion ends when the probability falls below a certain value. The specific threshold can be chosen appropriately based on the recursion depth.

After the recursion converges, we start computing the expected value for this round. This expected value is obtained by multiplying the weight matrix by the board matrix. The values in the weight matrix also need to be tuned manually. Poor tuning can lead to very deep recursion and hurt efficiency; too shallow a recursion depth, however, affects the accuracy of the expected-value calculation. Perhaps the “tuning” of this weight matrix could be handed over to unsupervised learning in machine learning.

![](https://img.halfrost.com/Blog/ArticleImage/67_15.png)


The formula above is the expected-value calculation formula under the recursion convergence condition.

After the recursive expected-value computation described above, we can return to the initial state. So how do we decide which direction to move?

Just like the airport route example above, we compute the expected value of each route. Here, after computing the maximum expected value, we simply take an average; the direction with the largest value is the direction to move next.

![](https://img.halfrost.com/Blog/ArticleImage/67_16.png)


However, in the actual recursive process, the following situation may occur:

![](https://img.halfrost.com/Blog/ArticleImage/67_17.png)


There is a large empty area, so many recursive steps are needed, which indirectly makes the amount of computation very large and increases the time the AI takes to think once. The way to solve this problem is to limit the recursion depth.

Use the sample variance to evaluate the mean:

![](https://img.halfrost.com/Blog/ArticleImage/67_18.png)


The larger S is, the greater the difference between the samples and the mean, and the more dispersed they are. We can indirectly use it to constrain the recursion depth.


> Reference:
> 
> \[1\]:[ExpectimaxSearch](https://web.uvic.ca/~maryam/AISpring94/Slides/06_ExpectimaxSearch.pdf)
>
> \[2\]:[What is the optimal algorithm for the game 2048?](https://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048/22498940#22498940)
> 
> \[3\]:[2048 AI – The Intelligent Bot](https://codemyroad.wordpress.com/2014/05/14/2048-ai-the-intelligent-bot/)


## II. Minimax Search

The minimax theory proposed by von Neumann in 1928 paved the way for later adversarial tree search methods, which became the foundation of decision theory when computer science and artificial intelligence were just emerging.

See the following repo for details:

[https://github.com/rianhunter/threes-solver](https://github.com/rianhunter/threes-solver)

## III. Monte Carlo Tree Search

Monte Carlo methods solve problems through random sampling. Later, in the 1940s, they were used as an approach for solving vaguely defined problems that were not suitable for direct tree search. In 2006, Rémi Coulomb combined these two methods to provide a new approach for move planning in Go, now known as Monte Carlo Tree Search (MCTS). In theory, MCTS can be applied to any domain that can be described in terms of {state, action} and whose outcomes can be predicted through simulation.


Monte Carlo is a method for solving reinforcement learning problems based on average sample returns. AlphaGo uses Monte Carlo Tree Search to quickly evaluate the value of board positions. We can likewise use this method to evaluate the probability that the current move in Threes will achieve the highest score.

A Go board has 19 lines in each direction, for a total of 361 intersections where stones can be placed. The two players take turns placing stones, which means there are up to 10^171 (1 followed by 171 zeros) possible game states in Go. This exceeds the total number of atoms in the universe, which is 10^80 (1 followed by 80 zeros)!

Traditional AI generally uses brute-force search methods (Deep Blue did exactly this), constructing a tree of all possible moves. Because the state space is enormous, it is impossible to enumerate all states through brute force.

![](https://img.halfrost.com/Blog/ArticleImage/67_19.gif)


Monte Carlo Tree Search can roughly be divided into four steps: Selection, Expansion, Simulation, and Backpropagation.

At the beginning, the search tree has only one node, namely the position for which we need to make a decision. Each node in the search tree contains three basic pieces of information: the represented position, the number of visits, and the accumulated score.


Selection: Start from the root R and select successive child nodes until reaching a leaf node L. The following section describes more about how child nodes are selected, allowing the game tree to expand toward the most promising moves. This is the essence of Monte Carlo Tree Search. 

Expansion: Unless L ends the game with a win for either side, create one or more child nodes and select one node C from them. 

Simulation: Play randomly from node C. This step is sometimes also called a playout or rollout. 

Backpropagation: Use the result of the playout to update the information in the nodes along the path from C to R.

![](https://img.halfrost.com/Blog/ArticleImage/67_20.png)


This figure shows the steps involved in a decision. Each node shows, from the perspective of the player represented at that point, the number of wins / number of simulations for that player. So in the selection diagram, black is about to move. 11/21 is the total number of white wins from playouts so far starting from this position. It reflects the total of 10/21 black wins shown by the three black nodes beneath it, where each black win represents a possible black move.

When a white simulation fails, all selected nodes have their simulation counts incremented (the denominator), but only the black nodes among them are credited with a win (the numerator). If white wins instead, all selected nodes still have their simulation counts incremented, but only the white nodes among them are credited with a win. This ensures that during selection, each player’s choices expand toward the most promising moves for that player, reflecting each player’s goal of maximizing the value of their actions.

As long as the time allocated to the move remains unchanged, the search is repeated. The move with the most simulations (that is, the highest denominator) is then chosen as the final answer.


From this we can see that Monte Carlo Tree Search is a heuristic search strategy. It uses frequency to estimate probability; when enough samples have been collected, frequency approximates probability. It is like randomly tossing a coin: as long as the number of tosses is large enough, the frequency of heads will approach 0.5 indefinitely.

> Reference:
>
> \[1\]:Browne C B, Powley E, Whitehouse D, et al. A Survey of Monte Carlo Tree Search Methods[J]. IEEE Transactions on Computational Intelligence & Ai in Games, 2012, 4:1(1):1-43.
>
> \[2\]:P. Auer, N. Cesa-Bianchi, and P. Fischer, “Finite-time Analysis  of the Multiarmed Bandit Problem,” Mach. Learn., vol. 47, no. 2,  pp. 235–256, 2002.


# To-Do

I originally thought this project would end here. But after Alibaba released the “Yellow Book” in the past few days, I suddenly felt that there was a new direction, so I decided to continue using reinforcement learning to complete a second version. I hope a more intelligent AI can achieve the highest achievement, 12288, with 100% consistency. After the training is complete, I will come back and continue writing the remaining articles.


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://github.com/halfrost/threes-ai](https://github.com/halfrost/threes-ai)