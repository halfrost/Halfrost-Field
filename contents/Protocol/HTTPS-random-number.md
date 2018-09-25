# 无法预测的根源——随机数


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_0.png'>
</p>


## 一、为什么需要随机数？

在之前文章说提到了好多密码学技术，在这些技术中，都会看见随机数的身影。

- 生成密钥      
用于对称密码和消息认证码
- 生成公钥密码    
用于生成公钥密码和数字签名
- 生成初始化向量 IV    
用于分组密码中的 CBC、CFB、OFB 模式
- 生成 nonce    
用于防御重放攻击和分组密码中的 CTR 模式
- 生成盐  
用于基于口令密码的 PBE 等


用随机数的目的是为了**提高密文的不可预测性，让攻击者无法一眼看穿**。



## 二、什么是随机数？

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_1.png'>
</p>

给随机数下一个严密的定义很难。只能从性质去区分一些随机数的种类。

- 随机性 —— 不存在统计学偏差，是完全杂乱的数列
- 不可预测性 —— 不能从过去的数列推测出下一个出现的数
- 不可重现性 —— 除非将数列本身保存下来，否则不能重现相同的数列

||随机性|不可预测性|不可重现性||备注|生成器|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|弱伪随机数|✅|❌|❌|只具备随机性|不可用于密码技术❌|伪随机数生成器 PRNG (Preudo Random Number Generator)|
|强伪随机数|✅|✅|❌|具备不可预测性|可用于密码技术✅|密码学伪随机数生成器 CPRNG (Cryptography secure Preudo Random Number Generator)|
|真随机数|✅|✅|✅|具备不可重现性|可用于密码技术✅|真随机数生成器 TRNG (True Random Number Generator)|


密码技术上使用到的随机数至少要达到不可预测性这一等级，即至少是强伪随机数，最好是真随机数。

>日常生活中的掷骰子的行为，产生的数列是**真随机数**，因为它产生的数列是不可重现的，具备随机性、不可预测性、不可重现性全部三种性质。

### 1. 随机性

随机性虽然看似杂乱无章，但是却会被攻击者看穿。所以被称为弱伪随机数。

用线性同余生成的伪随机数列，看起来杂乱无章，但是实际上是能被预测的。


### 2. 不可预测性

所谓不可预测性，即攻击者在知道过去生成的伪随机数列的前提下，依然无法预测出下一个生成出来的伪随机数。不可预测性是通过使用其他的密码技术来实现的，例如单向散列函数的单向性和机密性，来保证伪随机数的不可预测性。

### 3. 不可重现性

利用热噪声这一自然现象，英特尔开发出了能够生成不可重现的随机数列的硬件设备。在 CPU 中内置了**数字随机数生成数** (Digital Random Number Generator，DRNG)，并提供了生成不可重现的随机数 RDSEED 指令，以及生成不可预测的随机数的 RDRAND 指令。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_5.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_3.png'>
</p>


## 三、伪随机数生成器



伪随机数生成器是由外部输入的种子和内部状态两者生成的伪随机数列。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_6.png'>
</p>

由于内部状态决定了下一个生成的伪随机数，所以内部状态不能被攻击者知道。外部输入的种子是对伪随机数生成器的内部状态进行初始化的。所以种子也不能被攻击者知道。因为种子也不能使用容易被预测的值，例如不能使用当前时间作为种子。


密码的密钥与随机数种子之间的对比如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_7.png'>
</p>

生成伪随机数有以下几种算法：

- 杂乱的方法
- 线性同余法
- 单向散列函数法
- 密码法
- ANSI X9.17

### 1. 线性同余法

线性同余法就是**将当前的伪随机数值乘以 A 再加上 C，然后将除以 M 得到的余数作为下一个伪随机数**。如下。

```c
R0 = (A * 种子 + C) mod M
R1 = (A * R0 + C) mod M
R2 = (A * R1 + C) mod M
R3 = (A * R2 + C) mod M
R4 = (A * R3 + C) mod M

Rn = (A * R(n-1) + C) mod M
```

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_8.png'>
</p>

线性同余具有周期性，根据周期即可预测未来的状态。所以它不具备不可预测性，即不能将它用于密码技术。

很多伪随机数生成器的库函数(library function)都是采用线性同余法编写。例如 C 语言的库函数 rand，以及 Java 的 java.util.Random 类等，都采用了线性同余法。因此这些函数都不能用于密码技术。


### 2. 单向散列函数法

单向散列函数也可以生成不可预测的伪随机数，且为强伪随机数(因为它的单向性，具备不可预测性)。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_9.png'>
</p>

1. 用伪随机数的种子初始化内部状态，即计数器的值
2. 用单向散列函数计算计数器的散列值
3. 将散列值作为伪随机数输出
4. 计数器的值加1
5. 根据需要的伪随机数数量，重复 第 2 步 ~ 第 4 步

**单向散列函数的单向性是支撑伪随机数生成器不可预测性的基础**。

### 3. 密码法

使用密码法也能生成强伪随机数，既可以使用 AES 对称加密，也可以使用 RSA 公钥加密。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_10.png'>
</p>

1. 初始化内部状态(计数器)
2. 用密钥加密计数器的值
3. 将密文作为伪随机数输出
4. 计数器的值加1
5. 根据需要的伪随机数数量，重复 第 2 步 ~ 第 4 步

**密码的机密性是支撑伪随机数生成器不可预测性的基础**。

### 4. ANSI X9.17

用 ANSI X9.17 方法也可以生成强伪随机数。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_11.png'>
</p>

1. 初始化内部状态
2. 将当前时间加密生成密钥
3. 对内部状态与掩码求 XOR
4. 将步骤 3 的结果进行加密
5. 将步骤 4 的结果作为伪随机数输出
6. 将步骤 4 的结果与掩码求 XOR
7. 将步骤 6 的结果加密
8. 将步骤 7 的结果作为新的内部状态
9. 根据需要的伪随机数数量，重复 第 2 步 ~ 第 8 步



## 四、其他算法

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_4.png'>
</p>

有一个伪随机数生成算法叫梅森旋转算法(Mersenne twister)，它并不能用于安全相关的用途，因为它和线性同余算法一样，观察周期，即可对之后生成的随时数列进行预测。

Java 中的 java.util.Random 类也不能用于安全相关用途，如果要用于安全相关的用途，可以使用另外一个叫 java.security.SecureRandom 类。

同理 Ruby 中也有这样对应的两个类，Random 类和 SecureRandom 类，用于安全用途的也只能使用 SecureRandom 类。


## 五、对伪随机数生成器的攻击

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/107_2.png'>
</p>

- 对种子进行攻击  
伪随机数的种子和密码的密钥同等重要，要避免种子被攻击者知道，需要使用具备不可重现性的真随机数作为种子。

- 对随机数池进行攻击  
一般不会在使用的时候才生成真随机数，会事先在**随机数池**的文件中累计随机比特序列。当需要用的时候，直接从池子中取出所需长度的随机比特序列使用即可。(随机数池本身并不存储任何意义的信息，但是我们却需要保护没有任何意义的比特序列。虽然有点矛盾，但是又是必须的)



------------------------------------------------------

Reference：
  
《图解密码技术》        

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/random\_number/](https://halfrost.com/random_number/)