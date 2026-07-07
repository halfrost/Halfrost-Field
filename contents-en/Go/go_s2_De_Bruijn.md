# The Magical De Bruijn Sequence


![](http://upload-images.jianshu.io/upload_images/1194012-d857e84412a8925b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In mathematics, there exists a sequence that feels almost magical, and it also has some practical engineering applications. Today I want to share this sequence: how it is used in Google S2, and how it is applied in graph theory and other domains. This sequence is the De Bruijn sequence.

## I. Starting with a Magic Trick


![](http://upload-images.jianshu.io/upload_images/1194012-7b559f218c56f210.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


There is a playing-card magic trick like this. The magician holds a deck of cards and asks 5 people to inspect the cards separately. They check whether the suits and ranks of the cards are all different—that is, whether there are no duplicate cards.

After the cards have been checked and confirmed to contain no duplicates, the 5 people are allowed to “shuffle” them. Each person can take an arbitrary stack from the top and move it to the bottom; in other words, cut the deck. After all 5 people have taken turns cutting the deck, the order of the cards has completely changed.

Then the drawing begins. The magician asks the last person who cut the deck to take the top card, and then each person in turn takes the top card. At this point, 5 cards have been drawn. The magician says, “I can see through your minds; I know all the cards in your hands.” Then the magician asks the people holding black cards to stand up (this step is crucial!). The magician then names every person’s card one by one. Finally, everyone reveals their card, and every guess is correct. The audience erupts in applause.


## II. Revealing the Principle Behind the Trick


![](http://upload-images.jianshu.io/upload_images/1194012-6ce8d13eb66da18b.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


There are three key points in the whole trick. The first is that the number of participants must be no more than 32. A full deck contains 54 cards, but after removing the 2 jokers (because they only have two colors), there are 52 cards in total.


In the trick above, all cards are encoded in binary. To be able to identify any arbitrary sequence of 5 consecutive cards, the deck must have the property of a complete permutation. That is, it must enumerate all combinations, and each combination must uniquely represent a particular arrangement.

If the window size is 5—that is, 5 consecutive playing cards—then binary encoding gives 2^5^ = 32, so 32 cards are needed. If the window size is 6—that is, 6 consecutive playing cards—then binary encoding gives 2^6^ = 64, requiring 64 playing cards. Since there are only 52 cards in total, reaching 64 is impossible. Therefore, 32 people is the upper limit.

The second key point is that the magician can determine exactly which 5 consecutive cards these 5 people are holding only after asking either the people holding black cards or the people holding red cards to stand up. In fact, when the magician says, “I already know what cards all of you are holding,” he does not actually know each person’s card yet.

Besides rank, playing cards also have 4 suits. Here we need 32 cards: cards numbered 1 through 8, with 4 suits for each rank. The suit is encoded using 2 binary bits, and the values 1 through 8 are encoded using 3 binary bits. Thus, 5 binary bits are exactly enough to represent all information for one playing card.


![](http://upload-images.jianshu.io/upload_images/1194012-9010d14fa1d95c6a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown above, 00110 represents the 6 of clubs. 11000 represents the 8 of hearts (because there is no card numbered 0, so 000 represents 8).

After the first step of encoding the cards, the second step is to find a sequence that must satisfy the following condition: for a sequence or circular arrangement consisting of 2^n-1^ ones and 2^n-1^ zeros, can it ensure that the 0/1 sequences at any n positions are all pairwise distinct? A sequence satisfying this condition is also called a complete binary circular arrangement of order n.

In this trick, what we need to find is a complete binary circular arrangement of order 5. The answer is that such a sequence does exist. This sequence is the protagonist of this article: the De Bruijn sequence.


![](http://upload-images.jianshu.io/upload_images/1194012-23cfb3272af42fc1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The sequence above is a De Bruijn sequence with a window size of 5. Any 5 consecutive binary digits are pairwise distinct from any other such window. Therefore, no matter how the audience “shuffles” the cards, as long as the final cards drawn are 5 consecutive cards, that 5-card combination is included in the final set of results.

Convert every 5 binary bits in the De Bruijn sequence with window size 5 into the encoding of a playing card, as follows:

![](http://upload-images.jianshu.io/upload_images/1194012-fdb9c413d07ed051.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

So the initial order of the 32 cards is as follows:

8 of clubs, Ace of clubs, 2 of clubs, 4 of clubs, Ace of spades, 2 of diamonds, 5 of clubs, 3 of spades, 6 of diamonds, 4 of spades, Ace of hearts, 3 of diamonds, 7 of clubs, 7 of spades, 7 of hearts, 6 of hearts, 4 of hearts, 8 of hearts, Ace of diamonds, 3 of clubs, 6 of clubs, 5 of spades, 3 of hearts, 7 of diamonds, 6 of spades, 5 of hearts, 2 of hearts, 5 of diamonds, 2 of spades, 4 of diamonds, 8 of spades, 8 of diamonds.


**The magician has to memorize the initial order of these 32 cards.**

![](http://upload-images.jianshu.io/upload_images/1194012-8475eab472a824e9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


List all the permutations and combinations, as shown above. When the magician asks the people holding black or red cards to step forward, he can determine exactly which combination it is. From there, he can directly name the suit and rank of each person’s card.

The De Bruijn sequence chosen for this trick is also very special: it can be generated through a partial recurrence.


For this special sequence, take any window from it—that is, 5 consecutive binary digits. Add the first and third bits of those 5 bits, or equivalently the third-from-last and fifth-from-last bits. The addition follows binary rules, and the result gives the next bit immediately following this window.


![](http://upload-images.jianshu.io/upload_images/1194012-9e8be8aeea30d538.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In the example above, suppose the five bits in the current window are 00001. Adding the first bit from the left and the third bit from the left—or the third bit from the right and the fifth bit from the right—gives 0, so the next bit immediately following this window is 0, yielding 000010. As another example, if the current window is 11000, adding the first bit from the left and the third bit from the left gives 1, so the next bit is 1, yielding 110001.

The final key point lies in the way the deck is cut. Because a De Bruijn sequence is a cyclic sequence, in order to preserve that sequence, cutting the deck can only move cards from the top to the bottom; it cannot be cut arbitrarily. Only moving the top cards to the bottom preserves the De Bruijn sequence because of its cyclic nature.


For the trick to work, the necessary condition is that the magician first memorize the initial positions of the 32 cards. Then, when cutting the deck, the magician subtly suggests to the audience that the cards have been shuffled. Finally, based on which audience members holding black-suit cards (clubs and spades) raise their hands, the magician quickly locates which window of the 32-card cycle contains the 5 consecutive cards, and then names the suit and rank of each of the 5 cards.


## III. Definition and Properties of De Bruijn Sequences

### 1. Definition

A De Bruijn sequence, denoted B(k, n), is a cyclic sequence over an alphabet of k elements. Every length-n sequence over those k elements appears as a subsequence of it (in circular form), appearing exactly once.

For example, the sequence 00010111 belongs to B(2,3). All length-3 subsequences of 00010111 are 000,001,010,101,011,111,110,100, which exactly form all combinations in {0,1} ^3^.

### 2. Length

The length of a De Bruijn sequence is k^n^.

Notice that the total number of length-n sequences over k elements is k^n^. And for each element in a De Bruijn sequence, there is exactly one length-n subsequence starting at that element. Therefore, the length of a De Bruijn sequence is k^n^.

### 3. Count

The number of De Bruijn sequences B(k,n) is (k!) ^ (k^n-1^) / k^n^.

We can prove the conclusion above by mathematical induction.

First, assume the De Bruijn sequence is binary, i.e. k = 2. To calculate how many such sequences there are in total, we can look at the maximum decimal value obtained by converting each subsequence of the sequence into base 10; that value determines the count.

Because adjacent subsequences depend on each other—for example, the next subsequence is obtained by shifting the previous subsequence left by one bit and then appending 0 or 1, thereby generating the next subsequence. Of course, we finally need to take mod 2^n^ so that the length of every subsequence stays within n bits. Thus, we can obtain the following expression:
```go

s[i+1]=(2s[i]+(0|1))mod(2^n)

```
Using the method of subtracting shifted equations, we can obtain the general term formula:


|B(2,n)|= 2 ^ 2^(n−1)^ / 2^n^

Finally, using mathematical induction, we can derive a general formula:


The number of |B(k,n)| is  (k!) ^ (k^n-1^) / k^n^


The most commonly used De Bruijn sequence is when k = 2. Computing the number of |B(2,n)| gives the following:


![](http://upload-images.jianshu.io/upload_images/1194012-c7680945bca66476.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


### 4. Generation Method

Since De Bruijn sequences are not unique, code can generate any one of them.
```python

def de_bruijn(k, n):
    """
    de Bruijn sequence for alphabet k
    and subsequences of length n.
    """
    try:
        # let's see if k can be cast to an integer;
        # if so, make our alphabet a list
        _ = int(k)
        alphabet = list(map(str, range(k)))

    except (ValueError, TypeError):
        alphabet = k
        k = len(k)

    a = [0] * k * n
    sequence = []

    def db(t, p):
        if t > n:
            if n % p == 0:
                sequence.extend(a[1:p + 1])
        else:
            a[t] = a[t - p]
            db(t + 1, p)
            for j in range(a[t - p] + 1, k):
                a[t] = j
                db(t + 1, t)
    db(1, 1)
    return "".join(alphabet[i] for i in sequence)


```
Binary de Bruijn sequences are used quite often; next, let’s look at the sequences they generate.

For B(2, 1), there is only one possible case.
```go

i  01  s[i]
0  0    0
1   1   1

```
B(2，2) consists of 4 binary bits. It is also the only such case.
```go

i  0011|0  s[i]
0  00 . . . 0
1   01      1
2  . 11 . . 3
3     1|0   2

```
B(2，3) consists of 8 bits. There are 2 de Bruijn sequences.
```go

i  00010111|00 s[i]    i  00011101|00 s[i]
0  000 . . . .  0      0  000 . . . .  0
1   001         1      1   001         1
2  . 010 . . .  2      2  . 011 . . .  3
3     101       5      3     111       7
4  . . 011 . .  3      4  . . 110 . .  6
5       111     7      5       101     5
6  . . . 11|0   6      6  . . . 01|0   2
7         1|00  4      7         1|00  4

```
B(2, 4) consists of 16 binary bits. There are 16 corresponding de Bruijn sequences.
```go

0x09af  0000100110101111
0x09eb  0000100111101011
0x0a6f  0000101001101111
0x0a7b  0000101001111011
0x0b3d  0000101100111101
0x0b4f  0000101101001111
0x0bcd  0000101111001101
0x0bd3  0000101111010011
0x0cbd  0000110010111101
0x0d2f  0000110100101111
0x0d79  0000110101111001
0x0de5  0000110111100101
0x0f2d  0000111100101101
0x0f4b  0000111101001011
0x0f59  0000111101011001
0x0f65  0000111101100101

```
Extract `0x0d2f` from it:
```go

 i  0000110100101111|000 s[i]
 0  0000 . . . . . . . .  0
 1   0001                 1
 2  . 0011 . . . . . . .  3
 3     0110               6
 4  . . 1101 . . . . . . 13
 5       1010            10
 6  . . . 0100 . . . . .  4
 7         1001           9
 8  . . . . 0010 . . . .  2
 9           0101         5
10  . . . . . 1011 . . . 11
11             0111       7
12  . . . . . . 1111 . . 15
13               111|0   14
14  . . . . . . . 11|00  12
15                 1|000  8


```
B(2，5) consists of 32 binary bits. There are 2048 corresponding de Bruijn sequences. Since there are too many to list here one by one, here is an arbitrary one as an example:
```go

 i  00000111011010111110011000101001|0000 s[i]
 0  00000 . . . . . . . . . . . . . . . .  0
 1   00001                                 1
 2  . 00011 . . . . . . . . . . . . . . .  3
 3     00111                               7
 4  . . 01110 . . . . . . . . . . . . . . 14
 5       11101                            29
 6  . . . 11011 . . . . . . . . . . . . . 27
 7         10110                          22
 8  . . . . 01101 . . . . . . . . . . . . 13
 9           11010                        26
10  . . . . . 10101 . . . . . . . . . . . 21
11             01011                      11
12  . . . . . . 10111 . . . . . . . . . . 23
13               01111                    15
14  . . . . . . . 11111 . . . . . . . . . 31
15                 11110                  30
16  . . . . . . . . 11100 . . . . . . . . 28
17                   11001                25
18  . . . . . . . . . 10011 . . . . . . . 19
19                     00110               6
20  . . . . . . . . . . 01100 . . . . . . 12
21                       11000            24
22  . . . . . . . . . . . 10001 . . . . . 17
23                         00010           2
24  . . . . . . . . . . . . 00101 . . . .  5
25                           01010        10
26  . . . . . . . . . . . . . 10100 . . . 20
27                             01001       9
28  . . . . . . . . . . . . . . 1001|0. . 18
29                               001|00    4
30  . . . . . . . . . . . . . . . 01|000   8
31                                 1|0000 16

```
B(2, 6) consists of 64 binary bits. There are 67,108,864 corresponding de Bruijn sequences. Since there are too many, they cannot all be listed here; here is an arbitrary one as an example:
```go

 i  0000001000101111110111010110001111001100100101010011100001101101|00000 s[i]
 0  000000 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  0
 1   000001                                                                 1
 2  . 000010 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  2
 3     000100                                                               4
 4  . . 001000 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .  8
 5       010001                                                            17
 6  . . . 100010 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 34
 7         000101                                                           5
 8  . . . . 001011 . . . . . . . . . . . . . . . . . . . . . . . . . . . . 11
 9           010111                                                        23
10  . . . . . 101111 . . . . . . . . . . . . . . . . . . . . . . . . . . . 47
11             011111                                                      31
12  . . . . . . 111111 . . . . . . . . . . . . . . . . . . . . . . . . . . 63
13               111110                                                    62
14  . . . . . . . 111101 . . . . . . . . . . . . . . . . . . . . . . . . . 61
15                 111011                                                  59
16  . . . . . . . . 110111 . . . . . . . . . . . . . . . . . . . . . . . . 55
17                   101110                                                46
18  . . . . . . . . . 011101 . . . . . . . . . . . . . . . . . . . . . . . 29
19                     111010                                              58
20  . . . . . . . . . . 110101 . . . . . . . . . . . . . . . . . . . . . . 53
21                       101011                                            43
22  . . . . . . . . . . . 010110 . . . . . . . . . . . . . . . . . . . . . 22
23                         101100                                          44
24  . . . . . . . . . . . . 011000 . . . . . . . . . . . . . . . . . . . . 24
25                           110001                                        49
26  . . . . . . . . . . . . . 100011 . . . . . . . . . . . . . . . . . . . 35
27                             000111                                       7
28  . . . . . . . . . . . . . . 001111 . . . . . . . . . . . . . . . . . . 15
29                               011110                                    30
30  . . . . . . . . . . . . . . . 111100 . . . . . . . . . . . . . . . . . 60
31                                 111001                                  57
32  . . . . . . . . . . . . . . . . 110011 . . . . . . . . . . . . . . . . 51
33                                   100110                                38
34  . . . . . . . . . . . . . . . . . 001100 . . . . . . . . . . . . . . . 12
35                                     011001                              25
36  . . . . . . . . . . . . . . . . . . 110010 . . . . . . . . . . . . . . 50
37                                       100100                            36
38  . . . . . . . . . . . . . . . . . . . 001001 . . . . . . . . . . . . .  9
39                                         010010                          18
40  . . . . . . . . . . . . . . . . . . . . 100101 . . . . . . . . . . . . 37
41                                           001010                        10
42  . . . . . . . . . . . . . . . . . . . . . 010101 . . . . . . . . . . . 21
43                                             101010                      42
44  . . . . . . . . . . . . . . . . . . . . . . 010100 . . . . . . . . . . 20
45                                               101001                    41
46  . . . . . . . . . . . . . . . . . . . . . . . 010011 . . . . . . . . . 19
47                                                 100111                  39
48  . . . . . . . . . . . . . . . . . . . . . . . . 001110 . . . . . . . . 14
49                                                   011100                28
50  . . . . . . . . . . . . . . . . . . . . . . . . . 111000 . . . . . . . 56
51                                                     110000              48
52  . . . . . . . . . . . . . . . . . . . . . . . . . . 100001 . . . . . . 33
53                                                       000011             3
54  . . . . . . . . . . . . . . . . . . . . . . . . . . . 000110 . . . . .  6
55                                                         001101          13
56  . . . . . . . . . . . . . . . . . . . . . . . . . . . . 011011 . . . . 27
57                                                           110110        54
58  . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 101101 . . . 45
59                                                             01101|0     26
60  . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 1101|00  . 52
61                                                               101|000   40
62  . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 01|0000  16
63                                                                 1|00000 32

```
B(2, 5) and B(2, 6) are both widely used in real-world production.


## IV. Applications in Graph Theory: Eulerian Circuits and Hamiltonian Circuits


![](http://upload-images.jianshu.io/upload_images/1194012-49870623b01f2955.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In graph theory, there is a type of undirected connected graph in which there exists a path that traverses every edge of the graph once and only once; such a path is called an Eulerian circuit. This is also the well-known Seven Bridges of Königsberg problem: can one walk across all seven bridges exactly once? In essence, it asks whether an Eulerian circuit exists.


![](http://upload-images.jianshu.io/upload_images/1194012-ac58d92607a4f638.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Closely related to the Eulerian problem is the Hamiltonian circuit problem. This problem originated from a mathematical game about a regular dodecahedron, invented in 1857 by the British mathematician William Hamilton. Each vertex of the dodecahedron was labeled with the name of a famous city of the time. The goal of the game was to travel “around the world”: that is, to find a tour that visits each city once and exactly once.


![](http://upload-images.jianshu.io/upload_images/1194012-21f09760f3fe504e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


If we treat the 20 vertices of the regular dodecahedron as vertices in a graph, and draw the dodecahedron as the planar graph shown above, the problem becomes: can we find a circuit in the graph that visits each vertex once and only once? The figure above shows one such circuit.

There are generally two ways to solve the Eulerian circuit problem: DFS and Fleury’s algorithm. However, there is no efficient decision procedure for Hamiltonian graphs; only some sufficient conditions or necessary conditions are known, not necessary and sufficient conditions.


De Bruijn sequences are closely related to Eulerian circuits and Hamiltonian circuits.


If the list of all sequences of length n over an alphabet of k symbols is used as the set of vertices of a directed graph, then the graph has k^n^ vertices. If removing the first symbol from vertex m and appending one symbol to the end yields vertex n, then there is a directed edge from m to n. This graph is a De Bruijn graph. As shown below, in the graph where k = 2 and n = 3, vertex 010 has two outgoing edges, pointing to 101 and 100 respectively.

Let’s use B(2,3) as an example.

A Hamiltonian circuit in a De Bruijn graph is a De Bruijn sequence. In the figure below, the red Hamiltonian circuit in the left diagram corresponds to the De Bruijn sequence 00010111. This Hamiltonian circuit is equivalent to an Eulerian circuit in the De Bruijn graph with window length 2; see the sequence numbers corresponding to the marked Eulerian circuit in the lower-right diagram.


<p align='center'>
<img src='../images/De_Bruijn_B(2,3)0.png'>
</p>


Therefore, **a Hamiltonian circuit in a De Bruijn graph with window size n can be equivalently transformed into an Eulerian circuit in a De Bruijn graph with window size n - 1.**

<p align='center'>
<img src='../images/De_Bruijn_B(2,3)1.png'>
</p>


Of course, a Hamiltonian circuit in a De Bruijn graph is not necessarily unique. As shown in the left diagram above, in the same De Bruijn graph with k = 2 and n = 3, we can find another Hamiltonian circuit. The order of the corresponding Eulerian circuit also changes accordingly, as shown in the right diagram.

This also shows that when k = 2 and n = 3, multiple De Bruijn sequences exist; they are not unique.

Taking this a step further: since a Hamiltonian circuit in a higher-order De Bruijn graph can be transformed into an Eulerian circuit in a lower-order one, can we use an Eulerian circuit in the De Bruijn graph with k = 2 and n = 3 to construct a higher-order Hamiltonian graph? The answer is, of course, yes.


<p align='center'>
<img src='../images/De_Bruijn_B(2,4).png'>
</p>


As shown above, using an Eulerian circuit in the De Bruijn graph with k = 2 and n = 3, we construct a De Bruijn sequence with k = 2 and n = 4.


Similarly, when k = 3 and n = 2, a Hamiltonian circuit can still be found in the De Bruijn graph, and the corresponding Eulerian circuit for a window of n = 1 also exists, as shown below.

<p align='center'>
<img src='../images/De_Bruijn_B(3,2).png'>
</p>

## V. Bit Scanner

One widely used application of De Bruijn sequences is bit scanning. This is also how they are used in Google S2.

Let’s start with a fairly common problem.

Given a nonzero positive number represented in binary, how can we quickly find the position of the last 1 bit in its binary representation? For example, in 0101010010010100, the last 1 is at the second position when counting from right to left (starting from 0).

There are several ways to solve this problem. Let’s analyze them in order, from the roughest to the optimal approach.

The most direct idea is to convert the binary number into a form where only one bit is set to 1. If the problem above were converted into the case where exactly one bit is 1, it would be easy to solve.

So the problem becomes how to isolate the trailing 1. This can be done directly with bitwise operations.
```go

x &= (~x+1)

// or

x &= -x

```
The steps above let us isolate the least significant `1` bit.

Once it has been isolated, there are many possible ways to proceed.

For example:

Suppose a 64-bit binary number is as follows:
```go

3932700031202623488

11011010010011110000011101011110010000000000000000000000000000

```
![](http://upload-images.jianshu.io/upload_images/1194012-bae98242e8ce0235.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

After applying the `x & -x` operation, you can isolate the trailing `1`. This works because negative numbers are stored as the two's complement of their original representation: the sign bit remains unchanged, each bit is inverted, and then `1` is added. The consecutive trailing `0`s become `1`s after inversion, so adding `1` keeps carrying forward until it reaches the bit that was originally `1`. Since that bit becomes `0` after inversion, the carry stops there.


### 1. Loop

You can use a `for` loop to continuously right-shift the target number and find the position of the trailing `1`.
```go

for ( index = -1; x > 0; x >>= 1, ++index ) ;

```
This approach is simple and brute-force, with a time complexity of O(n).

### 2. Binary Search

Replace the loop above with binary search, and the time complexity becomes O(lgn).

### 3. Construct Special Numbers for Bitwise Operations

This approach looks clever, but in practice it still uses the idea of binary search.
```go

index = 0;
index += (!!(x & 0xAAAAAAAA)) * 1;
index += (!!(x & 0xCCCCCCCC)) * 2;
index += (!!(x & 0xF0F0F0F0)) * 4;
index += (!!(x & 0xFF00FF00)) * 8;
index += (!!(x & 0xFFFF0000)) * 16;

```
The time complexity of this approach is also O(lgn), but in practice it is much faster than binary search because it does not require comparisons; bitwise operations are sufficient.

### 5. Hashing

This approach is more efficient than all the previous ones.

Assume x has 32 bits, so there are only 32 possible positions where the trailing 1 can appear. If x is 64 bits, then there are 64 possibilities, one for each bit position. Using a hash-based approach, the result can be looked up in O(1) time.

### 6. De Bruijn Sequence


The principle behind this approach is also hashing, but it is faster than plain hashing because it avoids the modulo operation.

If x is 32 bits, the hash function can be constructed as follows:
```go

(x * 0x077CB531) >> 27 


```
0x077CB531 is one of the 32-bit De Bruijn sequences.

Constructing a hash function like this has two advantages:

1. Because this binary number is a special binary value we selected, the trailing `1` in the original binary number has been isolated. It is itself effectively a power of two, so multiplying any number by this special binary value is equivalent to a left shift. The number of bits shifted left is the position of the trailing `1` in the original binary number.
2. A De Bruijn sequence is essentially a complete permutation: it enumerates all possible cases. Therefore, any two of its subsequences are guaranteed to be different, which makes it a perfect hash.

Finally, it is shifted by another 27 bits to ensure that the leading 5 bits can be extracted.

In Go’s native code package, there is a `nat.go` file that contains the following code:
```go


const deBruijn32 = 0x077CB531

var deBruijn32Lookup = []byte{
	0, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15, 25, 17, 4, 8,
	31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9,
}

const deBruijn64 = 0x03f79d71b4ca8b09

var deBruijn64Lookup = []byte{
	0, 1, 56, 2, 57, 49, 28, 3, 61, 58, 42, 50, 38, 29, 17, 4,
	62, 47, 59, 36, 45, 43, 51, 22, 53, 39, 33, 30, 24, 18, 12, 5,
	63, 55, 48, 27, 60, 41, 37, 16, 46, 35, 44, 21, 52, 32, 23, 11,
	54, 26, 40, 15, 34, 20, 31, 10, 25, 14, 19, 9, 13, 8, 7, 6,
}

```
In this file, there is also a function that solves the problem described above, but from a different angle.

Finding the position of the trailing 1 in a binary number can actually be transformed into finding how many consecutive 0s appear at the end of that binary number.

This classic problem appears in Turing Award winner Donald Ervin Knuth’s *The Art of Computer Programming*, Volume 4, Section 7.3.1. Interested readers may want to take a look.
```go

// trailingZeroBits returns the number of consecutive zero bits on the right
// side of the given Word.
// See Knuth, volume 4, section 7.3.1
func trailingZeroBits(x Word) int {
	// x & -x leaves only the right-most bit set in the word. Let k be the
	// index of that bit. Since only a single bit is set, the value is two
	// to the power of k. Multiplying by a power of two is equivalent to
	// left shifting, in this case by k bits.  The de Bruijn constant is
	// such that all six bit, consecutive substrings are distinct.
	// Therefore, if we have a left shifted version of this constant we can
	// find by how many bits it was shifted by looking at which six bit
	// substring ended up at the top of the word.
	switch _W {
	case 32:
		return int(deBruijn32Lookup[((x&-x)*deBruijn32)>>27])
	case 64:
		return int(deBruijn64Lookup[((x&-x)*(deBruijn64&_M))>>58])
	default:
		panic("Unknown word size")
	}

	return 0
}

```
We also need to explain what the numbers initially loaded into the `deBruijn32Lookup` and `deBruijn64Lookup` arrays actually represent.

`deBruijn32` and `deBruijn64` are de Bruijn sequences, respectively. Their subsequences are pairwise distinct, and all of the subsequences together form a complete permutation.
```go

const deBruijn32 = 0x077CB531
// 0000 0111 0111 1100 1011 0101 0011 0001

const deBruijn64 = 0x03f79d71b4ca8b09
// 0000 0011 1111 0111 1001 1101 0111 0001 1011 0100 1100 1010 1000 1011 0000 1001

```
We use the following hash function to construct a “perfect” hash function.
```go

h(x) = (x * deBruijn) >> (n - lg n)

```
n is the number of bits in the binary representation. So it should now be clear what ((x&-x)*deBruijn32)>>27 and ((x&-x)*(deBruijn64&\_M))>>58 mean: they are computing the corresponding hash value.

The values stored in the array are our final results: the position of the trailing 1, or equivalently, the number of consecutive trailing 0s.

In fact, the numbers stored in the array are computed like this:
```go

void setup( void )
{	
	int i;
	for(i=0; i<32; i++)
		index32[ (debruijn32 << i) >> 27 ] = i;
}

```
That is, use the computed hash value as the index, and the value stored at that index is the number of bits to shift left. This shift count is the result we want. So we first compute the hash value, then retrieve the value stored at that hash value’s index in the array, which gives us the result.

For example, suppose the original binary number is 64 bits.
```go

0011011011101100110011001001001111110011000000000000000000000000

```
The result of x & -x
```go

1000000000000000000000000

```
After this step, the trailing `1` in the binary representation has been isolated. The remaining problem is to find which bit position this `1` is at when counting from right to left.

Use a 64-bit De Bruijn sequence to compute it:
```go

0000001111110111100111010111000110110100110010101000101100001001

```
Multiplying the result computed above with `x & -x` by this 64-bit De Bruijn sequence is equivalent to shifting left by a certain number of bits. By directly counting the number of zeros, we can see that it is shifted left by 24 bits:
```go

0111000110110100110010101000101100001001000000000000000000000000

```
Finally, take the first 6 bits of this number to get the result we need. Since lg 64 = 6, we take the first 6 bits: 011100.
```go

// findLSBSetNonZero64 returns the index (between 0 and 63) of the least
// significant set bit. Passing zero to this function has undefined behavior.
//
// This code comes from trailingZeroBits in https://golang.org/src/math/big/nat.go
// which references (Knuth, volume 4, section 7.3.1).
func findLSBSetNonZero64(bits uint64) int {
	return int(deBruijn64Lookup[((bits&-bits)*(deBruijn64&digitMask))>>58])
}


```
The program above is exactly the same as the previous implementation, except that the function name here indicates finding the position of the trailing 1, which is exactly the same as finding how many trailing 0s there are!

The code above is also source code from Google S2. It also directly uses a De Bruijn sequence to find the bit position of the trailing 1.

To summarize: the array index corresponds to the value of the hash function we constructed. The value of the hash function is essentially the leading bits of the corresponding De Bruijn sequence. We have transformed the position of the trailing 1 into a special binary number, where the position of the 1 in this number is exactly the position of the trailing 1 in the original binary number. In this special binary number, all bits after the trailing 1 are 0, so multiplying any number by it is equivalent to shifting left by the number of trailing 0s. Therefore, the position of the trailing 1 is converted into the problem of how many bits to left-shift the De Bruijn sequence. After shifting the De Bruijn sequence left by that amount, we take the leading bits, and the resulting number is the value of the hash function, which is in turn associated with the array index. Finally, the value stored at the corresponding hash-value position in the array is the result we want.


## 6. Industrial Applications

The magic of De Bruijn sequences is not limited to tricks. We can also use them as landmarks for robot localization: arrange small blocks of two different colors into a long line along the robot’s path. As long as the robot can identify the colors of a few blocks in front of and behind it, it can determine how many meters it has traveled—without GPS or high-precision sensors.


Researchers have used De Bruijn sequences to design a simple electronic component called a “feedback shift register,” which can generate a different random number for encryption each time. Between one random number and the next, only one digit needs to change and a shift needs to be performed, making the circuit structure very simple.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-4dfebc6cd83539a7.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


In measurement engineering, De Bruijn sequences can also be used in research on fast 3D shape measurement systems based on grating projection patterns.


![](http://upload-images.jianshu.io/upload_images/1194012-56ca782ec8b769ad.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


In genetic engineering, De Bruijn sequences can be used for assembling repetitive regions of genomes.

In medical research, De Bruijn sequences are commonly used in neuroscience and psychological experiments to detect the effects of stimulus sequences on the nervous system, and they can be applied specifically to functional magnetic resonance imaging.

In artificial intelligence algorithms, De Bruijn sequences also appear in neural-network time-series prediction.


------------------------------------------------------

Reference：

[Wiki  De Bruijn sequence](http://en.wikipedia.org/wiki/De_Bruijn_sequence)  
[Wolfram Mathworld de Bruijn Sequence](http://mathworld.wolfram.com/deBruijnSequence.html)    
[http://chessprogramming.wikispaces.com/De+Bruijn+sequence](http://chessprogramming.wikispaces.com/De+Bruijn+sequence)    
[The On-Line Encyclopedia of Integer Sequences](http://oeis.org/A166315)  
[De Bruijn cycle generator](https://cfn.upenn.edu/aguirre/wiki/public:de_bruijn_software)  
[On line Sequence Generator](http://jgeisler0303.github.io/deBruijnDecode/#decoderTest)  
[de Bruijn cycles for neural decoding](http://www.ncbi.nlm.nih.gov/pubmed/21315160)  
[De Bruijn sequence](https://zhouer.org/DeBruijn/)   
[《Using de Bruijn Sequences to Index a 1 in a Computer Word》](http://supertech.csail.mit.edu/papers/debruijn.pdf)

------------------------------------------------------

Spatial Search Series:

[How to Understand n-Dimensional Space and n-Dimensional Spacetime](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/n-dimensional_space_and_n-dimensional_space-time.md)  
[Efficient Multidimensional Spatial Point Indexing Algorithms — Geohash and Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_spatial_search.md)  
[How Is CellID Generated in Google S2?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_CellID.md)     
[Finding the LCA, the Lowest Common Ancestor, in a Quadtree in Google S2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_lowest_common_ancestor.md)  
[The Magical De Bruijn Sequence](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_De_Bruijn.md)  
[How to Find Hilbert Curve Neighbors on a Quadtree?](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Go/go_s2_Hilbert_neighbor.md)


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_s2\_De\_Bruijn/](https://halfrost.com/go_s2_De_Bruijn/)