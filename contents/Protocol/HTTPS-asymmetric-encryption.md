# 翱游公钥密码算法


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_0.png'>
</p>


## 一、引子

在对称加密中，例如一次性密码本，就存在密钥配送的问题。在 DES、AES 中也存在这个问题。由于加密和解密的密钥是相同的，所以必须向接收者配送密钥。如果使用公钥密钥，则无需向接收者配送用于解密的密钥，这样就解决了密钥配送的问题，可以说公钥密码是密码学历史上最伟大的发明。


## 二、配送密钥问题

为了防止中间人截获密钥，安全的把密钥传递给通信对方。有以下 4 种方式：

### 1. 事先共享密钥

这种方法虽然有效，但是具有局限性。在一次性密码本中，我们说过，大国之间的热线是用这种方式加密的，但是密钥是靠特工押送过去的。如果通讯对方在附近，提前共享密钥还比较方便。如果通讯对方在世界各地，这种方式也就存在局限性了。

另外通讯量增大以后，密钥个数也会陡增。n 个人两两通讯，需要 n * (n-1) /2 个密钥。这点来看，也不现实。

### 2. 密钥分配中心

为了解决事先共享密钥的密钥增多的问题。于是有人想出了密钥分配中心(Key Distribution Center, KDC)的办法。每次加密的密钥由密钥中心进行分配，每个人只要和密钥中心事先共享密钥就可以了。

虽然这个方法解决了密钥增多的问题，但是又带来了新的问题。

密钥中心存储和记录了所有的密钥，一旦它出现故障或者被攻击破坏，那么所有的加密都会瘫痪。这也是集中式管理的缺点。


### 3. Diffie-Hellman 密钥交换

为了解决集中式管理的缺点，那么应该密钥的配送还是不能用集中式。于是有人想出了 Diffie-Hellman 密钥交换的方法。

在 Diffie-Hellman 密钥交换中，加密通信双方需要交换一些信息，而这些信息即便被窃听者窃听，也不会有任何问题。

根据交换的信息，双方各自生成相同的密钥。而窃听者无法生成相同的密钥。这种方式可行。不过这种方式不算是非对称加密，在本文中不详细讨论。

### 4. 公钥密码

非对称加密有一个公钥和一个私钥。公钥可以在网上传播，被窃听者拿到也没有关系，由于没有私钥，他也无法解开密文。私钥只要掌握在接收者手上就不会导致密文被窃听。

举个例子：超市里面的存包处，所有顾客有硬币就可以存包。硬币就是“公钥”，顾客把包放进箱子里，（明文加密），箱子锁上以后就没人能打开。这个时候窃听者也拿不走存进去的包。这个明文（包），只有私钥才能打开。客户存完包以后会生成一个私钥，只要这个钥匙在手，就可以随时开箱拿包。


## 三、非对称加密

非对称加密一般指的是具有公钥密钥(public-key cryptography)的加密算法。密钥分为加密密钥和解密密钥两种。发送者用加密密钥对信息进行加密，接收者用解密密钥对密文进行解密。可以公开出去的叫公钥(public key)，保存在自己手上不公开的叫私钥(private key)。

公钥和私钥是一一对应的。一对公钥和私钥统称为密钥对(key pair)。在数学的关系上，这两者不能单独生成。


## 四、非对称加密存在的问题

公钥密码虽然解决了密钥配送的问题，但是并不意味着它解决了所有问题。公钥密码存在以下几个问题：

- 公钥认证
- 处理速度不到对称加密的十分之一

## 五、RSA 算法流程

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_3.png'>
</p>


RSA 是一种公钥密码算法，它的名字是由它的三位开发者，即 Ron Rivest、Adi Shamir 和 Leonard Adleman 的姓氏的首字母组成的 (Rivest-Shamir-Adleman)。1983 年，RSA 公司为 RSA 算法在美国取得了权利，但是现在该专利已经过期了。

RSA 可以被用于公钥密码和数字签名。

### 1. RSA 加密

在 RSA 中，明文、密钥和密文都是数字。加密过程可以用下面的公式来表示：

```c
密文 = 明文^E mod N
```

RSA 的密文是对代表明文的数字 E 次方求 mod N 的结果。E 和 N 是 RSA 加密的密钥，**E 和 N 的组合就是公钥**。E 是加密 Encryption 的首字母，N 是数字 Number 的首字母。


### 2. RSA 解密

RSA 解密过程可以用下面的公式来表示：

```c
明文 = 密文^D mod N
```

解密的过程是对密文的数字的 D 次方求 mod N 就可以得到明文。**D 和 N 的组合就是私钥**。D 是解密 Decryption 的首字母，N 是数字 Number 的首字母。

RSA 奇妙的是加密和解密过程是一致的。加密是求明文的 E 次方对 N 的 mod 余数。解密是求密文的 D 次方对 N 的 mod 余数。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_2.png'>
</p>


### 3. 生成密钥对

E 和 N 是公钥，D 和 N 是私钥，因此求 E、D 和 N 的这三个数是**生成密钥对**。具体流程主要分为 4 步：

- 求 N
- 求 L(L 是仅在生成密钥对的过程中使用的数)
- 求 E
- 求 D

主要步骤如下图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_5.png'>
</p>

先计算 N。

计算 N 需要准备 2 个很大的质数。质数太小容易被破译，太大导致计算时间很长。p 和 q 都是由伪随机数生成器生成的，且 p != q。N = p * q。

再计算 L。

L 这个数只在生成密钥对的过程中会用到，加密和解密过程中都不出现。
L 是 p - 1 和 q - 1 的最小公倍数 (least common multiple, lcm)。

再求数 E。

数 E 需要满足两个条件：

```c
1 < E < L

gcd(E,L) = 1 ， E 和 L 的最大公约数为 1 (E 和 L 互质)
```

条件 1 用伪随机生成树生成。条件 2 是为了保证一定存在解密时需要使用的数 D。求最大公约数可以使用欧几里得的辗转相除法。

至次，我们已经生成了密钥对中的公钥{E,M}

再求 D。

数 D 是由数 E 计算得到的。D、E、L 之间具有以下的关系：

```c
1 < D < L

E * D mod L = 1
```

只要 D 满足上面的条件，就可以通过 E 和 N 进行加密的密文，可以通过 D 和 N 进行解密。要保证一定存在满足条件的 D，需要先保证 E 和 L 的最大公约数为 1 。`E * D mod L = 1` 这个条件保证了密文解密以后可以得到明文。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_6_.png'>
</p>

总结一下推导流程：

```c
明文 = 密文^D mod N
	 = (明文^E)^D mod N
	 = 明文^(E * D) mod N

E * D mod L = 1 保证了最终的转换可以还原成明文。这里详细推导可以见文章末尾 Reference 阮老师的两篇 RSA 分析的文章。
```


## 六、直接攻击 RSA

要想直接攻击 RSA，也就是拿到密文算出明文。我们知道：

```c
密文 = 明文^E mod N
```

攻击者可以拿到密文和公钥{E,N}。那么现在问题转变成求离散对数的问题。目前还没有针对这个问题的高效算法。所以这条路走不通。

换一个思路，算出私钥，通过解密的方式顺序计算出明文。现在公钥里面有 N，私钥还需要知道 D，那么能暴力计算出 D 么？

一般 p 和 q 的长度都在 1024 位以上，N 的长度在 2048 以上。D 的长度 和 N 差不多，那么需要进行 2048 位以上的破解，在现实的时间内破解也是极其困难的。(除非以后量子计算机出现，当然量子计算机出现，当前现有加密体系也会被全部颠覆)

既然暴力破解 D 是不可能的，那么通过 E 和 N 计算 D 可行么？整理一下可以推暴力计算 D 的现有条件：

```c
E * D mod L = 1

N = p * q

L = lcm( p-1 , q-1)

```

目前我们知道 E 和 N，想算出 D 需要先算出 L，而 L 和 p、q 有关系。 p * q 又恰恰等于 N。那么我们第一步需要先破译 p 和 q。

目前对大数 N 进行质因数分解，比较难。**一旦发现了能对大整数进行质因数分解的高效算法，RSA 也就能够被破译**。目前还没有有效的算法。想通过猜测来推出 p、q 也不可能。p、q 的位数一般会比较长。

**p、q 两者在 RSA 中的地位和私钥的地位是一样的，一旦 p、q 被泄露，也就相当于私钥被泄露了**。



## 七、间接攻击 RSA

间接攻击 RSA 指的是利用中间人攻击。

举个例子，如下图：


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_7.png'>
</p>

主动攻击者 Mallory 在通信双方之间拦截各自的公钥。并且分别向两者发送自己的公钥。这样攻击者就可以在中间截获两边的密文，并且用自己的私钥进行解密。解密得到明文以后就可以任意篡改原文。最终达到攻击的目的。


这种攻击仅仅靠 RSA 本身是无法防御的。要想防御中间人攻击需要用到认证相关的算法。认证相关的算法在下一篇文章里面再详细说明。


## 八、椭圆曲线加密算法

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_16.webp'>
</p>

椭圆曲线密码(Elliptic Curve Cryptography, ECC)是近期备受关注的公钥密码算法。它的特点是比 RSA 所需的密钥长度短。**椭圆曲线密码密钥短但强度高**。密钥长度 224 - 255 比特的椭圆曲线密码，与密钥长度为 2048 比特的 RSA 具备相同的长度。

对应关系如下：

|RSA Key Length (bit)	| ECC Key Length (bit)| AES Key Length (bit)|
|:-----:|:-----:|:-----:|
|1024	 |160|80 |
|2048	|224| 112|
|3072	|256| 128 |
|7680	|384| 192 |
|15360|	521| 256|

|密码学算法 | 推荐的密钥安全长度|
|:----:|:-----:|
|AES 对称加密算法 | 128 比特|
|RSA 加密和签名算法 | 2048 比特|
|DSA 数字签名算法 | 2048 比特|
|ECC 椭圆曲线算法 | 256 比特|

由于 ECC 密钥具有很短的长度，所以运算速度比较快。到目前为止，对于 ECC 进行逆操作还是很难的，数学上证明不可破解，ECC 算法的优势就是性能和安全性高。实际应用可以结合其他的公开密钥算法形成更快、更安全的公开密钥算法，比如结合 DH 密钥形成 ECDH 密钥协商算法，结合数字签名 DSA 算法组成 ECDSA 数字签名算法。

|算法	| 加密/解密| 数字签名|密钥交换 |
|:-----:|:-----:|:-----:|:-----:|
|RSA	 |✅| ✅| ✅|
|Diffie-Hellman	|❌| ❌| ✅|
|DSS	|❌| ✅ |❌ |
|椭圆曲线 ECC|	✅|✅| ✅|

如上表，椭圆曲线可以用于 3 个方面：

- 基于椭圆曲线的公钥密码
- 基于椭圆曲线的数字签名
- 基于椭圆曲线的密钥交换

>椭圆曲线 (Elliptic Curve，EC) 这个名字很容易让人联想到“椭圆形”。但实际上椭圆曲线的图像并不是椭圆形的，之所以叫椭圆曲线，是有历史原因的，因为椭圆曲线源自于求椭圆弧长的椭圆积分反函数。



椭圆曲线源自于求椭圆弧长的椭圆积分的反函数。一般情况下，椭圆曲线可以用下面的方程式来表示，其中 a,b,c,d 为系数：

```c
E: y^2 = ax^3 + bx^2 + cx+ d
```

举个例子，

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_8.png'>
</p>

上面是一条椭圆曲线，但是它的样子也并不是一个椭圆。

### 1. 椭圆曲线上的运算

加法运算：椭圆曲线上的两点 A 和 B，构成的直线与椭圆曲线的交点，与 X 轴的对称点，定义为 A+B。如下图： 

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_9.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_17.gif'>
</p>

当然也存在两个点重合的情况，这种情况下，就相当于寻找 2 倍点的问题。在椭圆曲线上的一点 A，做一条切线，与椭圆曲线的另外一交点，相对于 X 轴的对称点成为 2 倍点。这种运算成为 2 倍计算，如下图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_10_.png'>
</p>

点 A 相对于 X 轴的对称位置的点成为 -A。这个运算成为椭圆曲线的正负取反运算。如下图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_11.png'>
</p>


### 2. 椭圆曲线加密实质

椭圆曲线加密的实质是利用椭圆曲线上离散对数问题(Elliptic Curve Discrete Logarithm Problem, ECDLP)，实质是**已知点 xG 求数 x 的问题**。

>已知：  
>椭圆曲线 E  
>椭圆曲线 E 上的一点 G (基点)  
>椭圆曲线 E 上的一点 xG (G 的 x 倍)  
>
>求：    
>数 x  
>

椭圆曲线在实数域上是连续的，曲线也是一条光滑的曲线。假设椭圆曲线为 E2：y^2 = x^3 + x + 1，如下图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_12.png'>
</p>

如果位于有限域 F23 上，那么 E2：y^2 ≡ x^3 + x + 1 (mod 23)。此时椭圆曲线就不是一个连续的曲线了，而是一堆离散的点。如下图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_13.png'>
</p>

上图中每个点的 y 坐标对 23 求余，都等于 x^3 + x + 1 对 23 求余。如果我们把 E2 上的点 G=(0,1) 作为基点，那么按照椭圆曲线的计算规则计算 2G、3G、4G、5G、……。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_14.png'>
</p>

这就是“已知 G 和 xG 求 x 的问题”。这个问题在 p 相当大的时候，很难求解。**椭圆曲线无法被破解的原因是：求解椭圆曲线上的离散对数问题是非常困难的**。

但是椭圆曲线加密算法并非在实数域 R 上，而是在**有限域 F(P) 上**。有限域 F(P) 指的是对于某个给定的质数 p，由 0，1，2，……，p-1 共 p 个元素所组成的整数集合中定义的加减乘除运算。

>椭圆曲线加密算法除了可以使用特征数为质数 p 的素域 GF(P)，椭圆曲线还可以使用特征数为 2^m 的扩张域 GF(2^m)。


### 3. 椭圆曲线 Diffie-Hellman 密钥交换 (ECDH)

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_18.png'>
</p>

>Diffie-Hellman 发明出来的非常早：  
>1976 年，Diffie 和 Hellman 提出了不对称加密  
>1977 年，Rivest，Shamir 和 Adleman 提出了 RSA 公钥算法  
>1977 年，DES 算法出现  
>80 年代，出现 IDEA 和 CAST 等算法
>90 年代，对称密钥进一步成熟，Rijndael，RC6 的出现，以及椭圆曲线等其他公钥算法  
>2000 年，Rijndael 算法成为 AES 标准


非椭圆曲线的 Diffie-Hellman 密钥交换利用的是：

**以 p 为模，已知 G 和 G^x mod p 求 x 的复杂度(有限域上的离散对数问题)**

椭圆曲线的 Diffie-Hellman 密钥交换利用的是：

**在椭圆曲线上，已知 G 和 xG 求 x 的复杂度(椭圆曲线上的离散对数问题)**

DH 算法和 RSA 算法最大的不同在于：

- DH 算法在进行**密钥协商**的过程中，通信双方的任何一方无法独自计算出一个会话密钥，通信双方各自保留一部分关键信息，再将另外一部分信息告诉对方，双方有了全部信息才能共同计算出全部的会话密钥。
- RSA 算法在传输会话密钥的时候，会话密钥完全由客户端生成和控制，并没有服务端的参与，准确的来说应该叫 **RSA 密钥传输**。


举个例子来说明 ECDH 算法是如何生成共享密钥的。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_15.png'>
</p>

- Alice 向 Bob 发送点 G，点 G 被窃听了也没有关系。
- Alice 生成随机数 a。这个数**只有 Alice 自己一个人知道**。也没有必要告诉 Bob。更加不能让第三者知道，这个 a 称为 Alice 的私钥。
- Bob 生成随机数 b。这个数**只有 Bob 自己一个人知道**。也没有必要告诉 Alice。更加不能让第三者知道，这个 b 称为 Bob 的私钥。
- Alice 向 Bob 发送点 aG。点 aG 被窃听了也没有关系。它是 Alice 的公钥。
- Bob 向 Alice 发送点 bG。点 bG 被窃听了也没有关系。它是 Bob 的公钥。
- Alice 拿到 Bob 发过来的 bG，开始计算其在椭圆曲线上 a 倍的点，即 a(bG) = abG，它就是 Alice 和 Bob 的共享密钥。
- Bob 拿到 Alice 发过来的点 aG 开始计算其在椭圆曲线上 b 倍的点，即 b(aG) = baG = abG，它就是 Alice 和 Bob 的共享密钥。

窃听者一共可以拿到 3 个有效信息：G、aG、bG。但是由于“已知 G 和 xG 求 x 非常难”，导致已知 G 和 aG 无法求解出 a，已知 G 和 bG 无法求解出 b。所以最终也就无法求解出私钥 abG。

>严格的来说，椭圆曲线上的离散对数问题的复杂度只能证明 “已知 G，aG，bG 难以求出 a，b”，但无法证明“已知 G，aG，bG 难以求出 abG”，后者需要另外证明。具体证明这里省略。

如果采用静态的 DH 算法和 ECC 结合就是 ECDH 算法。这种方式每次都使用的相同的 G 基点，它的优点在于可以避免每次在初始化连接时服务器频繁生成 G。这个过程比较消耗 CPU。但是它带来的缺点是，一旦随机数 a、b 被泄露了，那么在这之前的所有会话都将会被解密。

为了解决这个问题，于是出现了 DHE 算法(Diffie-Hellman Ephemeral ，短暂临时的 DH 算法)，结合 ECC 后形成了 ECDHE 算法。它可以保证每次通信使用的共享密钥都是不同的，DH 密钥对仅仅保存在内存中，不像 RSA 的私钥保存在磁盘上，攻击者即使从内存中破解了私钥，也仅仅影响本次通信，所以无需担心在此之前的通信内容会被解密，这样的特征成为前向安全性(Forward Secrecy，FS)或者完全前向安全性(Perfect Forward Secrecy，PFS)。更安全的是，协商出会话密钥后，a 和 b 两个私钥可以丢弃，进一步提升了安全性，在有限的时间、有效的空间生成了密钥对。在 TLS 握手中使用的 ECDHE\_ECDSA 和 ECDHE\_RSA 密钥交换算法。




### 4. 椭圆曲线 DSA (ECDSA)

使用椭圆曲线密码还可以实现数字签名。

假设 Alice 要对消息 m 加上数字签名，而 Bob 需要验证该签名。下面所有的“计算”，都是代表以 p 为模的时钟运算。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_19.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_20.png'>
</p>

### 5. 椭圆曲线 EIGamal 密码

假设 Alice 要想 Bob 发送一条消息，Alice 可以将自己要发送的消息用椭圆曲线上的一个点 M 来表示(实际上是用该点的 x 坐标)

加密：

- Alice 用自己的私钥 a 以及 Bob 的公钥 bG，对消息 M 计算点 M + abG。此点 M + abG 就是密文。
- Alice 将密文 M + abG 发送给 Bob。

解密：

- Bob 接收到密文 M + abG。
- Bob 用 Alice 的公钥 aG 以及自己的私钥 b 计算出共享密钥 abG。将收到的密文减去 abG 就可以得到原文 M 了。

这里用到的还是窃听者无法出 abG 的特点，所以保证了密文的安全。


## 九、其他公钥加密算法

EIGamal 方式是由 Taher EIGamal 设计的公钥算法。RSA 利用了质因数分解的困难度，而 EIGamal 利用了 mod N 下求离散对数的困难度。


EIGamal 方式有一个缺点，就是经过加密的密文长度会变成明文的 2 倍。密码软件 GnuPG 中就支持这种方式。

Rabin 方式是由 M.O.Rabin 设计的公钥算法。Rabin 利用了 mod N 下求平方根的困难度。破译 Rabin 公钥密码的困难度与 RSA 质因数分解 N 是相当的。


## 十、混合加密系统

通过使用对称加密可以解决信息安全的问题，但是使用对称加密，必须要解决密钥配送的问题。

使用公钥密码可以解决密钥配送的问题，但是公钥密码又暴露了 2 个新的问题。

- 公钥密码的处理速度远远低于对称密码
- 公钥密码难以抵御中间人攻击

第一点缺点可以用这一章节讲的混合加密系统来解决。第二点缺点需要用到下一篇文章中的认证相关的算法来解决。

混合密码系统 (hybrid crytosystem) 是将对称密码和公钥密码的优势相结合的方法。用快速的对称密码对明文进行加密，用公钥密码对对称密码的密钥进行加密。由于对称密钥一般都比消息本身要短，这样公钥密码速度慢的问题也可以忽略。

- 用对称密码对消息明文进行加密
- 用伪随机生成器生成对称密码加密中使用的会话密钥
- 用公钥密码加密会话密钥
- 从混合密码系统外部赋予公钥密码加密时使用的密钥

会话密钥 (session key) 是指为本次通信而生成的临时密钥。它一般都是通过伪随机数生成器产生的。伪随机生成器所产生的会话密钥同时也会作为对称密码的密钥使用。**会话密钥是对称密码的密钥，同时也是公钥密码的明文**。

下图是混合密码系统中的加密流程：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_22.png'>
</p>

值得说明的是，公钥密码的强度应该高于对称密码。因为对称密码会话密钥被破译只影响本地通信内容，但是公钥密钥被破译就会影响到过去所有通信内容，以及未来所有通信内容。

下图是混合密码系统中的解密流程：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/101_21.png'>
</p>


## 十一、OpenSSL 中的 RSA

使用 genrsa 子命令生成密钥对，密钥对是一个文件。

```c
// 生成密钥长度为 2048 比特
$ openssl genrsa -out mykey.pem 2048
```

输出

```c
Generating RSA private key, 2048 bit long modulus (2 primes)
..................................................+++
...............................................................+++
e is 65537 (0x010001)


-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAvQuZaPWI47tMLufxTxlFUmVkvl3HCjo7WtxD7znK5TvbOtQN
N0QsbhdzLc+gVy8asYE95f06ujELtsrhLX2g8HcklgAM13k6ML47Vj1mEgl8M1Gh
ye/ZcWeOFYxDn3JbhVZbofzAwowkEbc9KXMxYI+J2Bp1wCq7dh1IHVkV1OQy2qo6
poR0pMjV1qd+AzrBFyVtV6DqNkInFrPMCL9iu+j1PliNG4I00+66JcVBlMCsYxX6
orhhwDV85NVitAvEX2GwRd3v65/93ZtOOTJgyofrFr/nYxp/ytfhwIsDTIfuGNES
9xJ0x4ENbEL8POTHrpEgpf9VQ/9mdVxkCtWsPwIDAQABAoIBACe/zJ35IrNfqoEi
W+bZ1W2hzDEK3tMTs29DaTVf3X2dvFb+R1kbiIwNejZjtb8fNGmmVzGIsVR9A42H
0xkRlUl6g8LWd9zGrKmbFjbn6hJY1DimLXKccAgcUg/N0lowXXYH1nSVBKLjfKIM
+VtB0VwQUleSGLgzQ/9t4L/q/2AnztXe/LLyMxjsW1XNSlMREPjBoykygw6dk41/
Wou96UvUElJc9YiU+WwIL46yWfwf68C9qmlrkY32pj7q/q7FHLsgGeiSXpxRYSeo
bl99xHzBN/Kf3wHcw803JFSolZKb63VDt0p9P58Dg34M9NxqHKfnXW/+Ot4ryIaT
LNUe1IECgYEA3UiEUANv10WSmXQXuNOcCsTezwvNGrxERD6q7sGs4gEMDkjOy4eG
ENbT3OqISOpMjli9+m0XjG0Jdc6+WaAKbddAwwfHfq+e9qWHg88q1yHJFYLRMMgV
f5kV5sq2/b+eOLpPeOI4dRiU1J5dorab0SxpSMvLcu1krPpss3BoBDECgYEA2rRM
EH/gtT3uTGVfsF9WtFr+/AYExsLg8GK38HdwopVPhgNMhrIIvHSRBpGgPNZC7Q6z
pDreFZM5U0zCcLVpYdKSh0ag0uckOVwDoKcvOFEG+hE5N22LseiU2FXSDFPjk5wz
C5ZKZDh826n+28P7XN74HGDvF/usXEA8ibu5y28CgYAbidbNjl/wznu8FTKOkect
f+qqobFYzm1AgPwM0pWNWswBSxZRRgBtQA8FwzpKuL3mSSz7aXAwzbELtDsENGKX
4N3yZ5lwLrL9xwPiZ3nRZCb+QlV+WKg0RPzwx/GWCq7KKIWTabPU/sYm376PbWJe
2cQQhyw+lUSeMlwsyKRpQQKBgH1hyAndhjHh43Ag3g77WXXkhTJvMOXSa6rkrZdK
omRTPVgTJBhEkQWZvlsJudem7o+BUjPhG9k6oi7DXuXG2zedxSuQrjq7EOVhfyLn
NgcPTPSoUykXwHKqaEruSJGQtnO1pP4Ll3KFf+9fMiFD5iOEILIEUI5rVpE8sng0
C3w5AoGBAIRZ7BVKof069wdJRbCYWNcQ9wLpfbsDfJ1nB25aDlYsbiX+04dg30oY
63IQIuE1+uU+ucQhOn1ct8zQN8+neqRsfyAKfDr9pble8L2PeLdTlJiSnChXmctX
fR6ZxFL/ScnE2JiJ9EJeAvKVVRBWe4loSiz1LOjRXnNqTQK5VUdT
-----END RSA PRIVATE KEY-----
```
用 3DES 加密口令

```c
// 口令结合 3DES 算法保护密钥对
$ openssl genrsa -des3 -out mykey2.pem 2048
```
输出

```c
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,4F3848C3AF836C73

+TL2YDfcSZh3oCPUcUaKLHZBnnzSKSspZV5NwlDHbyokkigEeVaEn19nBEDdH5ph
Mv2afNfs5TNHe/uxun0OP99Z/QrWgkz75JRDQYjUEBilte0MHLS+W7bzJlYcYYhs
IK/8/x6X3A0T3lm13PV389RnuEJKl/x4JhhS7+AHUt/ceYxYAbW35dPVzBaVX8KL
1t67joBEasOxqFblDcVniOWLHhdn4aF+k4P4a3qs5ayzVNxB7+cQOK7ZFyRN7OOP
O/iu6Ha7kCqUi4NP8yJohfBoiLqmWAgl5nbyRs/ymjrI1Qu9Gne551cXY57SFJB1
YdtXanXcQodL9S9EZ9dSNrQLzDbQ2bpJNO7QdmxTxxUWn0Nw2SBeRcju+5HU//XV
FB90xc3abskjE/Dq8KCWY+TogEJmB8fLGBGnF3RDUkgOtQ93omGREcRgI3QSDt2O
KryYSwO/f0Rh+dbLs6OhenPgUEHFXteS0ETq5Q7lPAgH6xLGQdrdVHm2gkQ72IMt
JE4w68bC8x4qM7XSK9RublEjFWY7UKd93JWsaxbokozD7cYSi2SZO6eDiKZMUhOH
bV+7uSt6IT6KdvNTtO4hQFcttqjxApdwDf1GA8qRUmQ57PS6pbpGq07zGYtoGZ2o
Za1MUZtH/omi41smVPJWlB5YEQhVPclpw4BpGkVqYoI56QrmEuZWK8x8A8Fota0C
ZZvvbEFGO+wKlp3mmaKC0g3P0xXblKUVzpXhiEGEPxyxzMYu7vhS4gSEA8TvWyH3
YJBDDF2dSPYoJq0HQcnmeVKNG544ZSuJz/+Jfn6WcD6qx5zZ9NXsm6xaji5hHGoW
aJzWGZbk74WXpc+y/NFyJLhKpozr+Gsu8r40A+BCQXhkYUu58QAbtuWP48gfyn0+
fP0oLlBq3UGMga46JJgdMNbnNcbo5Qxzo0srHdwiYts4oBXEfED/NRQeecsKqrvk
qNxK9AR0MP3sKMshuBiS0nSgGovnAG5TwEzbwPgoiU09CWGWLQQOnRxZt4FNmVqz
kQg8t+U0JW8rKSH9FihRXpOeSDlVrk4L8It98v8KyczNWZjKxBszbO/AJeK8gPeY
hXZ6bU8/FljI+NMeA7gUgcNjXNSoNdHiJFMh5XbVN3AaUiUV9oOr5d/v1kWTYz+A
xaGw5rYKMe32Fs8ohMHnTydmO4iHGziKt5gchJwzAmY4k05tyyRF/VjJCb4bV0XA
VwGLUlhuNWzuvh2FGBXceEOf6eOzE1FDriTVQX2gFSBaE3olWtBvB7lzAEm+nyMJ
zL+aiSBDgBSKFkGRXe5i2Lq7/3600z4HWON3Ccc8gwuVVOsv927CDXdi33Ew+XqN
yKxG2PFHf2MoymRcp+YnyZqa2yGCQWXEOvzUgRRIlgH9BVbXxPKPigDwWqho5X+F
3ymDjsGp87x8RoE14GWImVpYjWx500fs/FweLoKzi+RRWvFFcc4izW7YvGY9yby7
zWKng2Wrqkc0NBExqkIxpcGsLay+1joa++lX/6V0/Rdq8DWrI2zalpw3LYsN1jCW
1iOD6CoOsAKsj3QpqFU4gh5RRXgPYQK1nq0ctonVsQ7Cv1929+TmMw==
-----END RSA PRIVATE KEY-----
```

从密钥对中分离出公钥

```c
$ openssl rsa -in mykey.pem -pubout -out mypubkey.pem

// 需要输入口令才能分离公钥
$ openssl rsa -in mykey2.pem -pubout -out mypubkey2.pem
```

无口令的分离出公钥

```c
writing RSA key

-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvQuZaPWI47tMLufxTxlF
UmVkvl3HCjo7WtxD7znK5TvbOtQNN0QsbhdzLc+gVy8asYE95f06ujELtsrhLX2g
8HcklgAM13k6ML47Vj1mEgl8M1Ghye/ZcWeOFYxDn3JbhVZbofzAwowkEbc9KXMx
YI+J2Bp1wCq7dh1IHVkV1OQy2qo6poR0pMjV1qd+AzrBFyVtV6DqNkInFrPMCL9i
u+j1PliNG4I00+66JcVBlMCsYxX6orhhwDV85NVitAvEX2GwRd3v65/93ZtOOTJg
yofrFr/nYxp/ytfhwIsDTIfuGNES9xJ0x4ENbEL8POTHrpEgpf9VQ/9mdVxkCtWs
PwIDAQAB
-----END PUBLIC KEY-----
```

有口令的分离出公钥

```c
writing RSA key

-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn2AlBE0SzDjS4ITtV0KU
i7ZfpVaI7SaxhkVqgZNqTX8WsLQefXJipzcCR3aFNOyfRr/YtsUKKozD3qtQRckH
TkZdil80RB9im8IINIgUXWtOm1j6/ztptKtPoBlv556+cLY+zEJQWnSzB3N8g2py
26oewc6AeZiYtqpLEbuGBsBxGa8xNIp2/fnBKonA4stAI6b+3yCsDeEwgw3O7omt
AMTtYBJqd2Be9Np8CukXD4fBLdVRcRoTiIGxSp8GRJ+F5JBIr5THMAerVhNjdAeU
y15gc7B5OTJUfLmBXWo6gmq4hLcp4S5dCv7kapK7Zebyt1LkXAsrRCWGMVavy84y
fwIDAQAB
-----END PUBLIC KEY-----
```
校验密码对文件是否正确

```c
// -noout 参数表示不打印密钥对信息，如果校验成功，说明密钥对文件无误
$ openssl rsa -in mykey.pem -check -noout
```
输出

```c
RSA key ok
```
显示公钥信息

```c
$ openssl rsa -pubin -in mypubkey.pem -text
```
输出

```c
RSA Public-Key: (2048 bit)
Modulus:
    00:bd:0b:99:68:f5:88:e3:bb:4c:2e:e7:f1:4f:19:
    45:52:65:64:be:5d:c7:0a:3a:3b:5a:dc:43:ef:39:
    ca:e5:3b:db:3a:d4:0d:37:44:2c:6e:17:73:2d:cf:
    a0:57:2f:1a:b1:81:3d:e5:fd:3a:ba:31:0b:b6:ca:
    e1:2d:7d:a0:f0:77:24:96:00:0c:d7:79:3a:30:be:
    3b:56:3d:66:12:09:7c:33:51:a1:c9:ef:d9:71:67:
    8e:15:8c:43:9f:72:5b:85:56:5b:a1:fc:c0:c2:8c:
    24:11:b7:3d:29:73:31:60:8f:89:d8:1a:75:c0:2a:
    bb:76:1d:48:1d:59:15:d4:e4:32:da:aa:3a:a6:84:
    74:a4:c8:d5:d6:a7:7e:03:3a:c1:17:25:6d:57:a0:
    ea:36:42:27:16:b3:cc:08:bf:62:bb:e8:f5:3e:58:
    8d:1b:82:34:d3:ee:ba:25:c5:41:94:c0:ac:63:15:
    fa:a2:b8:61:c0:35:7c:e4:d5:62:b4:0b:c4:5f:61:
    b0:45:dd:ef:eb:9f:fd:dd:9b:4e:39:32:60:ca:87:
    eb:16:bf:e7:63:1a:7f:ca:d7:e1:c0:8b:03:4c:87:
    ee:18:d1:12:f7:12:74:c7:81:0d:6c:42:fc:3c:e4:
    c7:ae:91:20:a5:ff:55:43:ff:66:75:5c:64:0a:d5:
    ac:3f
Exponent: 65537 (0x10001)
writing RSA key
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvQuZaPWI47tMLufxTxlF
UmVkvl3HCjo7WtxD7znK5TvbOtQNN0QsbhdzLc+gVy8asYE95f06ujELtsrhLX2g
8HcklgAM13k6ML47Vj1mEgl8M1Ghye/ZcWeOFYxDn3JbhVZbofzAwowkEbc9KXMx
YI+J2Bp1wCq7dh1IHVkV1OQy2qo6poR0pMjV1qd+AzrBFyVtV6DqNkInFrPMCL9i
u+j1PliNG4I00+66JcVBlMCsYxX6orhhwDV85NVitAvEX2GwRd3v65/93ZtOOTJg
yofrFr/nYxp/ytfhwIsDTIfuGNES9xJ0x4ENbEL8POTHrpEgpf9VQ/9mdVxkCtWs
PwIDAQAB
-----END PUBLIC KEY-----
```
Modulus 是 RSA 加密结构中的 N。Exponent 是公钥中的 E。-----BEGIN PUBLIC KEY----- 和 -----END PUBLIC KEY----- 之间是公钥具体的值。

使用密钥对加密

```c
// rsautl 命令默认填充机制是 PKCS#1 v1.5
$ openssl rsautl -encrypt -inkey mykey.pem -in plain.txt -out cipher.txt

// 指定 rsautl 填充机制为 PKCS#1 OAEP
$ openssl rsautl -encrypt -inkey mykey.pem -in plain.txt -out cipher.txt -oaep
```
假设我们加密的文件里面的明文是 "hello world"。加密以后密文变成了：

```c
�1Au�&.�rzC��7��6:
+��٠P�?��|��~İ���}'x�������X�IkBx��V2��~�/��$�N�(5m�s�#�m�0����s�ɜ+jėއ(!E�t��??�{���Y�W�a��tȈp���uUlzk�I9W����[���/�l!J��ө��-v�O_h����b~ ��Y
```

使用公钥加密，务必有 -pubin 参数表明 -inkey 参数输入的是公钥文件

```c
$ openssl rsautl -encrypt -pubin -inkey mypubkey.pem -in plain.txt -out cipher2.txt
```
同样加密的明文是 "hello world"，加密以后密文变成了：

```c
�
�P�C��)���>e{�}�QK���N2At�T�XSF�P�cFO2āFbj��G0�c���Kg�G+�Q�qߊ�'
       ~;�`DF{�ϭa&i����?�3l��!	�w��&q���Q���z�f��Κ�!�u�ʩ��j�U�Y
```
解密

```c
$ openssl rsautl -decrypt -inkey mykey.pem -in cipher.txt
```
输出

```c
hello world
```


## 十二、OpenSSL 中的 ECC

### 1. DH 密钥协商

与 RSA 密钥对生成方式不一样，DH 密钥对生成方式分为 2 步，第一步先生成参数文件，第二步再根据参数文件生成密钥对，**同一个参数文件可以生成无数多且不重复的密钥对**。

第一步，生成 DH 密钥对

```c
// 生成 2048 比特的参数文件
$ openssl dhparam -out dhparam.pem -2 2048

$ openssl dhparam -in dhparam.pem -noout -C
```
输出

```c
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
......................+..........................................................................+..............................................................................................................................................................................................+.......................................................+

#ifndef HEADER_DH_H
# include <openssl/dh.h>
#endif

DH *get_dh2048()
{
    static unsigned char dhp_2048[] = {
	0xBD, 0x70, 0xDB, 0x2E, 0xF9, 0x0B, 0x89, 0x37, 0xC4, 0x31,
	0x93, 0x48, 0x47, 0xEF, 0xD5, 0xEA, 0x7E, 0xBC, 0xDA, 0xC8,
	0x14, 0x0E, 0x82, 0xDD, 0xF6, 0xC6, 0x07, 0x2A, 0xD4, 0x97,
	0xC3, 0x02, 0xA1, 0x9B, 0x02, 0xCB, 0xE4, 0xC0, 0xB9, 0x33,
	0xD1, 0xBB, 0x69, 0xF0, 0xBA, 0x8C, 0x7A, 0x57, 0x1F, 0xDF,
	0xD3, 0xB5, 0x2F, 0x87, 0x1E, 0xA8, 0x35, 0xE4, 0xC0, 0x94,
	0xED, 0x20, 0x04, 0x26, 0x58, 0x50, 0x27, 0xFC, 0xF6, 0xE1,
	0xBE, 0xC7, 0xB8, 0x7A, 0x14, 0xC1, 0x08, 0x16, 0x06, 0xC6,
	0xB8, 0x09, 0xDC, 0x34, 0xEA, 0xA0, 0xD1, 0x3E, 0x88, 0xBD,
	0xB3, 0xBB, 0x05, 0xFE, 0x4D, 0xCB, 0x62, 0x05, 0x9A, 0xC7,
	0x00, 0xA2, 0x0B, 0x73, 0xAD, 0xDD, 0x39, 0x18, 0x9A, 0xD8,
	0x2A, 0x95, 0xCE, 0xF4, 0x10, 0x6A, 0xB2, 0x5C, 0x0F, 0x9E,
	0x99, 0xE5, 0xE6, 0x0D, 0x6C, 0x19, 0xF5, 0xF5, 0xDC, 0x07,
	0x2D, 0xF0, 0xDE, 0xB5, 0x58, 0xEC, 0x35, 0x33, 0xEF, 0x65,
	0x70, 0xC3, 0x8C, 0xBF, 0x14, 0x40, 0x4C, 0xC3, 0x47, 0x77,
	0xE0, 0x5F, 0xF6, 0x61, 0x5F, 0x49, 0x35, 0xCC, 0x39, 0x75,
	0x8E, 0x31, 0xA3, 0x99, 0x43, 0x61, 0xD7, 0xE3, 0xB7, 0xB8,
	0x0F, 0x79, 0xF3, 0x66, 0x50, 0x95, 0x0D, 0x95, 0xB2, 0x5F,
	0x1B, 0x2C, 0x9D, 0x64, 0xE0, 0x54, 0xCB, 0x27, 0xE9, 0x4A,
	0x23, 0x96, 0xA0, 0x7E, 0x55, 0xD4, 0xA9, 0x93, 0x43, 0xB0,
	0x69, 0xB2, 0xF5, 0xB4, 0x9D, 0x41, 0x5B, 0xD3, 0x5D, 0x4B,
	0x91, 0x48, 0x9F, 0xAA, 0x54, 0xA4, 0xA1, 0x81, 0xF1, 0x59,
	0xF6, 0xB3, 0x44, 0x8C, 0xE7, 0x83, 0x8F, 0x57, 0x63, 0x52,
	0x58, 0x70, 0x2F, 0x0A, 0xC1, 0xC0, 0xE5, 0xDD, 0x6F, 0x4D,
	0xFD, 0xC1, 0x5D, 0x61, 0x6E, 0xD0, 0xA4, 0xBD, 0x15, 0xA1,
	0xA6, 0xDE, 0x61, 0xC9, 0xF4, 0x4B
    };
    static unsigned char dhg_2048[] = {
	0x02
    };
    DH *dh = DH_new();
    BIGNUM *dhp_bn, *dhg_bn;

    if (dh == NULL)
        return NULL;
    dhp_bn = BN_bin2bn(dhp_2048, sizeof(dhp_2048), NULL);
    dhg_bn = BN_bin2bn(dhg_2048, sizeof(dhg_2048), NULL);
    if (dhp_bn == NULL || dhg_bn == NULL
            || !DH_set0_pqg(dh, dhp_bn, NULL, dhg_bn)) {
        DH_free(dh);
        BN_free(dhp_bn);
        BN_free(dhg_bn);
        return NULL;
    }
    return dh;
}
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAvXDbLvkLiTfEMZNIR+/V6n682sgUDoLd9sYHKtSXwwKhmwLL5MC5
M9G7afC6jHpXH9/TtS+HHqg15MCU7SAEJlhQJ/z24b7HuHoUwQgWBsa4Cdw06qDR
Poi9s7sF/k3LYgWaxwCiC3Ot3TkYmtgqlc70EGqyXA+emeXmDWwZ9fXcBy3w3rVY
7DUz72Vww4y/FEBMw0d34F/2YV9JNcw5dY4xo5lDYdfjt7gPefNmUJUNlbJfGyyd
ZOBUyyfpSiOWoH5V1KmTQ7BpsvW0nUFb011LkUifqlSkoYHxWfazRIzng49XY1JY
cC8KwcDl3W9N/cFdYW7QpL0VoabeYcn0SwIBAg==
-----END DH PARAMETERS-----
```

第二步，基于参数文件生成密钥对

```c
$ openssl genpkey -paramfile dhparam.pem -out dhkey.pem

// 查看密钥对文件内容
$ openssl pkey -in dhkey.pem -text -noout
```
输出

```c
DH Private-Key: (2048 bit)
    private-key:
        53:7c:d5:88:80:13:49:b0:c0:00:79:62:fd:4b:8d:
        54:c6:b2:f3:49:45:fa:3c:f7:d8:49:cf:b2:b2:cd:
        b6:45:be:b8:de:54:9b:07:7e:dc:e5:f1:92:0c:7c:
        7d:b9:6e:aa:db:3e:a0:b0:e1:e8:aa:b6:6e:71:c8:
        59:30:b7:75:cb:79:c8:44:25:18:36:2f:22:c2:6b:
        fb:19:f6:31:7e:c8:6d:df:5f:46:cf:b9:df:41:53:
        1c:5e:42:9f:46:77:29:c0:09:a0:a2:4d:e8:f7:44:
        43:1a:f8:43:18:d1:2d:7f:56:75:dc:62:4f:84:93:
        26:c6:fc:ca:a6:5f:50:73:d8:bc:ee:2b:1c:65:22:
        4c:ab:0b:a3:a0:ce:d3:cd:1d:d9:21:3f:b3:32:f0:
        74:fd:3d:98:1d:43:3b:a4:ed:e0:d2:7e:eb:27:64:
        c7:64:54:e7:12:19:5d:f8:f0:a5:fc:15:50:ee:20:
        8f:81:84:b5:e6:ba:64:9a:e0:36:bc:61:09:b3:b3:
        ea:24:63:92:66:13:50:2d:5b:f5:db:2f:15:3d:6b:
        e3:63:99:61:70:8e:b1:12:a1:c1:bb:c0:fa:57:90:
        ae:47:7a:78:35:ce:dc:47:2a:63:b4:30:4a:9d:49:
        4f:2b:ac:a0:8e:47:44:dc:a5:29:68:cd:c6:e0:74:
        50
    public-key:
        00:81:0a:3e:3b:29:8a:e9:1e:26:47:e0:cc:a0:40:
        e9:2d:03:c4:55:64:b0:73:2c:6e:39:6f:5a:95:de:
        a3:44:6a:d1:20:f4:69:68:3c:58:8f:f5:86:94:39:
        13:bf:c7:66:1f:af:7b:1e:0e:15:cd:0e:f9:65:d4:
        d4:70:37:63:50:f7:7b:93:6c:bf:e2:9a:de:fa:41:
        13:20:8b:23:0c:f7:b3:94:00:19:6d:65:f2:30:6a:
        50:88:8f:5e:7e:40:79:fa:14:0f:73:3b:51:ed:24:
        06:5d:29:f9:6e:34:7a:21:6e:b0:cf:6a:7e:c3:26:
        31:3f:f5:42:47:f6:2f:45:c4:89:67:90:b4:69:0e:
        73:92:57:90:32:63:be:77:9f:f1:a8:c5:e3:cd:4d:
        b8:2f:13:4f:88:78:9a:09:1b:04:fa:ab:6d:0c:a7:
        b8:b4:6e:76:05:42:d2:50:b7:a3:6b:0c:94:53:9f:
        fa:eb:9e:20:df:e7:91:a3:08:fa:a8:be:85:6d:75:
        41:89:e9:ae:1d:e4:e1:65:bc:17:f3:b3:a2:ab:45:
        31:eb:9e:21:dc:45:66:0d:8b:2c:70:ea:c2:1d:ac:
        27:9d:0d:d4:06:9c:b0:3d:0b:34:9e:05:2d:9c:55:
        28:f4:63:7f:61:96:da:e7:09:0b:40:b4:d6:0a:5c:
        aa:df
    prime:
        00:bd:70:db:2e:f9:0b:89:37:c4:31:93:48:47:ef:
        d5:ea:7e:bc:da:c8:14:0e:82:dd:f6:c6:07:2a:d4:
        97:c3:02:a1:9b:02:cb:e4:c0:b9:33:d1:bb:69:f0:
        ba:8c:7a:57:1f:df:d3:b5:2f:87:1e:a8:35:e4:c0:
        94:ed:20:04:26:58:50:27:fc:f6:e1:be:c7:b8:7a:
        14:c1:08:16:06:c6:b8:09:dc:34:ea:a0:d1:3e:88:
        bd:b3:bb:05:fe:4d:cb:62:05:9a:c7:00:a2:0b:73:
        ad:dd:39:18:9a:d8:2a:95:ce:f4:10:6a:b2:5c:0f:
        9e:99:e5:e6:0d:6c:19:f5:f5:dc:07:2d:f0:de:b5:
        58:ec:35:33:ef:65:70:c3:8c:bf:14:40:4c:c3:47:
        77:e0:5f:f6:61:5f:49:35:cc:39:75:8e:31:a3:99:
        43:61:d7:e3:b7:b8:0f:79:f3:66:50:95:0d:95:b2:
        5f:1b:2c:9d:64:e0:54:cb:27:e9:4a:23:96:a0:7e:
        55:d4:a9:93:43:b0:69:b2:f5:b4:9d:41:5b:d3:5d:
        4b:91:48:9f:aa:54:a4:a1:81:f1:59:f6:b3:44:8c:
        e7:83:8f:57:63:52:58:70:2f:0a:c1:c0:e5:dd:6f:
        4d:fd:c1:5d:61:6e:d0:a4:bd:15:a1:a6:de:61:c9:
        f4:4b
    generator: 2 (0x2)
```

prime 是一个大质数，generator 是生成元。

接下来举一个 DH 密钥协商的完整例子。

```c
// 通讯一方生成 DH 参数文件，可以对外公开
$ openssl genpkey -genparam -algorithm DH -out dhp.pem

// 查看参数文件内容，包括 p 和 g 参数
$ openssl pkeyparam -in dhp.pem -text
```

输出

```c
-----BEGIN DH PARAMETERS-----
MIGHAoGBAO6kIxno65uejqlc0Q+SwnpIQjc9A8DMr1r1xNk9d/qTGczGi52olR96
XfKHZMKCRih4mvFglAfisykwLGdVViiqOQrLmG0uI2WviyPKG4eHqu7gID/6+pil
RBHo6m9McsnlrcGLgV2d3a3IczNcH/g2NnVoKN6Q9+tGiZKhowZDAgEC
-----END DH PARAMETERS-----
DH Parameters: (1024 bit)
    prime:
        00:ee:a4:23:19:e8:eb:9b:9e:8e:a9:5c:d1:0f:92:
        c2:7a:48:42:37:3d:03:c0:cc:af:5a:f5:c4:d9:3d:
        77:fa:93:19:cc:c6:8b:9d:a8:95:1f:7a:5d:f2:87:
        64:c2:82:46:28:78:9a:f1:60:94:07:e2:b3:29:30:
        2c:67:55:56:28:aa:39:0a:cb:98:6d:2e:23:65:af:
        8b:23:ca:1b:87:87:aa:ee:e0:20:3f:fa:fa:98:a5:
        44:11:e8:ea:6f:4c:72:c9:e5:ad:c1:8b:81:5d:9d:
        dd:ad:c8:73:33:5c:1f:f8:36:36:75:68:28:de:90:
        f7:eb:46:89:92:a1:a3:06:43
    generator: 2 (0x2)
```

发送方 Alice 基于参数文件生成一个密钥对

```c
$ openssl genpkey -paramfile dhp.pem -out akey.pem

// 查看密钥对内容
$ openssl pkey -in akey.pem -text -noout
```
输出

```c
DH Private-Key: (1024 bit)
    private-key:
        79:1f:07:19:83:8d:34:db:4a:ea:d6:7b:16:4f:7e:
        11:cd:39:78:75:ea:4f:c3:f7:09:48:91:3c:96:cf:
        6b:8d:85:56:48:9e:1a:83:fb:13:0a:28:c5:f6:eb:
        74:13:ff:a4:2e:ae:29:df:b5:92:2a:af:25:11:cf:
        02:b6:09:d5:c8:a1:71:78:86:dd:26:6a:d1:55:52:
        33:ce:65:57:22:3f:f4:df:a6:df:80:c2:cc:c6:98:
        de:67:09:05:e2:68:09:d1:43:7f:42:03:37:99:88:
        cc:5f:78:e6:22:b0:fa:5c:c9:5f:0f:2d:de:b6:33:
        42:05:f4:45:58:b8:fb:93
    public-key:
        4d:90:d3:5f:df:13:fb:17:32:55:6c:3b:17:67:cb:
        51:8f:42:1c:88:10:ef:7b:90:69:2c:e6:97:92:10:
        92:4f:16:8d:d5:9b:4f:d5:97:fa:71:3b:28:12:99:
        1f:86:0d:ee:b2:ca:7e:4f:96:ae:46:73:1d:14:b5:
        0e:1a:0c:e6:41:fa:97:d4:0c:50:a2:17:5d:a9:e8:
        7e:c0:33:fd:dc:59:ca:13:90:f7:1b:79:ee:88:5e:
        39:70:4f:c0:a8:a7:0b:0e:6e:e8:27:29:43:1b:af:
        56:72:0a:aa:a1:06:1d:0d:78:f8:6d:1a:1e:bd:b5:
        3b:20:55:76:bc:9c:1a:d3
    prime:
        00:ee:a4:23:19:e8:eb:9b:9e:8e:a9:5c:d1:0f:92:
        c2:7a:48:42:37:3d:03:c0:cc:af:5a:f5:c4:d9:3d:
        77:fa:93:19:cc:c6:8b:9d:a8:95:1f:7a:5d:f2:87:
        64:c2:82:46:28:78:9a:f1:60:94:07:e2:b3:29:30:
        2c:67:55:56:28:aa:39:0a:cb:98:6d:2e:23:65:af:
        8b:23:ca:1b:87:87:aa:ee:e0:20:3f:fa:fa:98:a5:
        44:11:e8:ea:6f:4c:72:c9:e5:ad:c1:8b:81:5d:9d:
        dd:ad:c8:73:33:5c:1f:f8:36:36:75:68:28:de:90:
        f7:eb:46:89:92:a1:a3:06:43
    generator: 2 (0x2)
```

接收方 Bob 也基于参数文件生成一个密钥对

```c
$ openssl genpkey -paramfile dhp.pem -out bkey.pem

// 查看密钥对内容
$ openssl pkey -in bkey.pem -text -noout
```

输出

```c
PKCS#3 DH Private-Key: (1024 bit)
    private-key:
        7b:00:1e:c9:12:62:3a:82:69:58:03:5c:f5:23:ef:
        c2:20:10:27:f5:a7:e3:c9:14:57:76:ea:94:4c:68:
        e5:17:c2:38:36:e1:82:9d:fb:d2:97:04:44:4a:0c:
        9f:81:d3:4a:33:c8:8f:64:50:79:6c:cd:a6:3a:26:
        d0:2b:55:7d:78:b0:e7:1e:12:d8:a3:89:da:61:53:
        1e:d0:9a:9f:f6:c0:ce:7d:c9:25:50:01:cf:c2:cb:
        0d:e2:74:78:3c:58:28:71:38:f0:d3:d2:91:f4:28:
        ec:da:f2:f9:75:e6:c4:13:8c:97:2a:f9:a3:fd:c0:
        0e:cb:d0:17:7d:62:01:c4
    public-key:
        00:8c:ad:e1:2f:42:85:4f:f8:07:7e:15:d0:f9:c5:
        84:b4:a3:be:9d:b2:fb:57:86:b8:c7:0c:d3:d5:92:
        c1:7b:db:e6:e6:b2:7e:ff:db:95:d9:8b:10:1a:10:
        4d:59:ac:b2:00:43:6f:23:f6:aa:13:b6:e4:f4:04:
        92:f1:23:88:13:21:c9:f7:d2:f3:dc:0e:a6:75:20:
        ed:4c:61:29:55:a2:36:55:d3:04:9f:7d:c3:96:7d:
        be:62:44:83:bf:9e:b3:f8:e7:ac:88:c5:3e:9b:b7:
        01:52:63:1a:30:5f:5d:90:46:5b:06:06:f3:b4:f8:
        c4:4b:16:45:43:da:d5:6d:1e
    prime:
        00:ee:a4:23:19:e8:eb:9b:9e:8e:a9:5c:d1:0f:92:
        c2:7a:48:42:37:3d:03:c0:cc:af:5a:f5:c4:d9:3d:
        77:fa:93:19:cc:c6:8b:9d:a8:95:1f:7a:5d:f2:87:
        64:c2:82:46:28:78:9a:f1:60:94:07:e2:b3:29:30:
        2c:67:55:56:28:aa:39:0a:cb:98:6d:2e:23:65:af:
        8b:23:ca:1b:87:87:aa:ee:e0:20:3f:fa:fa:98:a5:
        44:11:e8:ea:6f:4c:72:c9:e5:ad:c1:8b:81:5d:9d:
        dd:ad:c8:73:33:5c:1f:f8:36:36:75:68:28:de:90:
        f7:eb:46:89:92:a1:a3:06:43
    generator: 2 (0x2)
```
Alice 拆出公钥文件 akey\_pub.pem，私钥自己保存

```c
$ openssl pkey -in akey.pem -pubout -out akey_pub.pem
```

输出

```c
-----BEGIN PUBLIC KEY-----
MIIBHzCBlQYJKoZIhvcNAQMBMIGHAoGBAO6kIxno65uejqlc0Q+SwnpIQjc9A8DM
r1r1xNk9d/qTGczGi52olR96XfKHZMKCRih4mvFglAfisykwLGdVViiqOQrLmG0u
I2WviyPKG4eHqu7gID/6+pilRBHo6m9McsnlrcGLgV2d3a3IczNcH/g2NnVoKN6Q
9+tGiZKhowZDAgECA4GEAAKBgE2Q01/fE/sXMlVsOxdny1GPQhyIEO97kGks5peS
EJJPFo3Vm0/Vl/pxOygSmR+GDe6yyn5Plq5Gcx0UtQ4aDOZB+pfUDFCiF12p6H7A
M/3cWcoTkPcbee6IXjlwT8CopwsObugnKUMbr1ZyCqqhBh0NePhtGh69tTsgVXa8
nBrT
-----END PUBLIC KEY-----
```

Bob 拆出公钥文件 bkey\_pub.pem，私钥自己保存

```c
$ openssl pkey -in bkey.pem -pubout -out bkey_pub.pem
```

输出

```c
-----BEGIN PUBLIC KEY-----
MIIBIDCBlQYJKoZIhvcNAQMBMIGHAoGBAO6kIxno65uejqlc0Q+SwnpIQjc9A8DM
r1r1xNk9d/qTGczGi52olR96XfKHZMKCRih4mvFglAfisykwLGdVViiqOQrLmG0u
I2WviyPKG4eHqu7gID/6+pilRBHo6m9McsnlrcGLgV2d3a3IczNcH/g2NnVoKN6Q
9+tGiZKhowZDAgECA4GFAAKBgQCMreEvQoVP+Ad+FdD5xYS0o76dsvtXhrjHDNPV
ksF72+bmsn7/25XZixAaEE1ZrLIAQ28j9qoTtuT0BJLxI4gTIcn30vPcDqZ1IO1M
YSlVojZV0wSffcOWfb5iRIO/nrP456yIxT6btwFSYxowX12QRlsGBvO0+MRLFkVD
2tVtHg==
-----END PUBLIC KEY-----
```

Alice 收到 Bob 他的公钥，并将协商出来的密钥保存到 data\_a.txt 中

```c
$ openssl pkeyutl -derive -inkey akey.pem -peerkey bkey_pub.pem -out data_a.txt
```

输出

```c

b;[nQ?�!zX^m��4���Է�M<{|1X?�M3�NT�Łm�Ϧ\��X+<����(L�(�F��l5Yl��N���/o���v�#7���J`>�?R�,���!>G������
                                                                                                   ��>B�����$�-��Y
                                                                                                   
```

对应二进制
     
```c   
$ od -d data_a.txt
                                                                                          0000000     25098   23355   20846   16134    8602   32634   24152   59757
0000020     59416   57652   52209   47060   19942   31548   12668   16216
0000040     19901   56883   21582   50641   28033   53186   23718   55494
0000060     11096   35644   61385   10435   33612   54568   51014   27841
0000100     22837   44908    5587   49486   61576   12198   57967   64511
0000120     60534   56867   14088   38019   19100   15968   16283   57938
0000140     60972   57071   15905     583   49404   47506   61861   47628
0000160      5292   16958   38029   62234   57799   39460   43821   38391
0000200
```

Bob 收到 Alice 他的公钥，并将协商出来的密钥保存到 data\_b.txt 中


```c
$ openssl pkeyutl -derive -inkey bkey.pem -peerkey akey_pub.pem -out data_b.txt
```

输出

```c

b;[nQ?�!zX^m��4���Է�M<{|1X?�M3�NT�Łm�Ϧ\��X+<����(L�(�F��l5Yl��N���/o���v�#7���J`>�?R�,���!>G������
                                                                                                   ��>B�����$�-��Y
```

对应二进制

```c
$ od -d data_b.txt

0000000     25098   23355   20846   16134    8602   32634   24152   59757
0000020     59416   57652   52209   47060   19942   31548   12668   16216
0000040     19901   56883   21582   50641   28033   53186   23718   55494
0000060     11096   35644   61385   10435   33612   54568   51014   27841
0000100     22837   44908    5587   49486   61576   12198   57967   64511
0000120     60534   56867   14088   38019   19100   15968   16283   57938
0000140     60972   57071   15905     583   49404   47506   61861   47628
0000160      5292   16958   38029   62234   57799   39460   43821   38391
0000200
```

可以发现两者最后协商出来的密钥是完全一致的。

### 2. ECC 加密

OpenSSL 中支持很多命名的曲线，先来看看支持的曲线有哪些。

```c
$ openssl ecparam -list_curves
```

输出

```c
  secp112r1 : SECG/WTLS curve over a 112 bit prime field
  secp112r2 : SECG curve over a 112 bit prime field
  secp128r1 : SECG curve over a 128 bit prime field
  secp128r2 : SECG curve over a 128 bit prime field
  secp160k1 : SECG curve over a 160 bit prime field
  secp160r1 : SECG curve over a 160 bit prime field
  secp160r2 : SECG/WTLS curve over a 160 bit prime field
  secp192k1 : SECG curve over a 192 bit prime field
  secp224k1 : SECG curve over a 224 bit prime field
  secp224r1 : NIST/SECG curve over a 224 bit prime field
  secp256k1 : SECG curve over a 256 bit prime field
  secp384r1 : NIST/SECG curve over a 384 bit prime field
  secp521r1 : NIST/SECG curve over a 521 bit prime field
  prime192v1: NIST/X9.62/SECG curve over a 192 bit prime field
  prime192v2: X9.62 curve over a 192 bit prime field
  prime192v3: X9.62 curve over a 192 bit prime field
  prime239v1: X9.62 curve over a 239 bit prime field
  prime239v2: X9.62 curve over a 239 bit prime field
  prime239v3: X9.62 curve over a 239 bit prime field
  prime256v1: X9.62/SECG curve over a 256 bit prime field
  sect113r1 : SECG curve over a 113 bit binary field
  sect113r2 : SECG curve over a 113 bit binary field
  sect131r1 : SECG/WTLS curve over a 131 bit binary field
  sect131r2 : SECG curve over a 131 bit binary field
  sect163k1 : NIST/SECG/WTLS curve over a 163 bit binary field
  sect163r1 : SECG curve over a 163 bit binary field
  sect163r2 : NIST/SECG curve over a 163 bit binary field
  sect193r1 : SECG curve over a 193 bit binary field
  sect193r2 : SECG curve over a 193 bit binary field
  sect233k1 : NIST/SECG/WTLS curve over a 233 bit binary field
  sect233r1 : NIST/SECG/WTLS curve over a 233 bit binary field
  sect239k1 : SECG curve over a 239 bit binary field
  sect283k1 : NIST/SECG curve over a 283 bit binary field
  sect283r1 : NIST/SECG curve over a 283 bit binary field
  sect409k1 : NIST/SECG curve over a 409 bit binary field
  sect409r1 : NIST/SECG curve over a 409 bit binary field
  sect571k1 : NIST/SECG curve over a 571 bit binary field
  sect571r1 : NIST/SECG curve over a 571 bit binary field
  c2pnb163v1: X9.62 curve over a 163 bit binary field
  c2pnb163v2: X9.62 curve over a 163 bit binary field
  c2pnb163v3: X9.62 curve over a 163 bit binary field
  c2pnb176v1: X9.62 curve over a 176 bit binary field
  c2tnb191v1: X9.62 curve over a 191 bit binary field
  c2tnb191v2: X9.62 curve over a 191 bit binary field
  c2tnb191v3: X9.62 curve over a 191 bit binary field
  c2pnb208w1: X9.62 curve over a 208 bit binary field
  c2tnb239v1: X9.62 curve over a 239 bit binary field
  c2tnb239v2: X9.62 curve over a 239 bit binary field
  c2tnb239v3: X9.62 curve over a 239 bit binary field
  c2pnb272w1: X9.62 curve over a 272 bit binary field
  c2pnb304w1: X9.62 curve over a 304 bit binary field
  c2tnb359v1: X9.62 curve over a 359 bit binary field
  c2pnb368w1: X9.62 curve over a 368 bit binary field
  c2tnb431r1: X9.62 curve over a 431 bit binary field
  wap-wsg-idm-ecid-wtls1: WTLS curve over a 113 bit binary field
  wap-wsg-idm-ecid-wtls3: NIST/SECG/WTLS curve over a 163 bit binary field
  wap-wsg-idm-ecid-wtls4: SECG curve over a 113 bit binary field
  wap-wsg-idm-ecid-wtls5: X9.62 curve over a 163 bit binary field
  wap-wsg-idm-ecid-wtls6: SECG/WTLS curve over a 112 bit prime field
  wap-wsg-idm-ecid-wtls7: SECG/WTLS curve over a 160 bit prime field
  wap-wsg-idm-ecid-wtls8: WTLS curve over a 112 bit prime field
  wap-wsg-idm-ecid-wtls9: WTLS curve over a 160 bit prime field
  wap-wsg-idm-ecid-wtls10: NIST/SECG/WTLS curve over a 233 bit binary field
  wap-wsg-idm-ecid-wtls11: NIST/SECG/WTLS curve over a 233 bit binary field
  wap-wsg-idm-ecid-wtls12: WTLS curve over a 224 bit prime field
  Oakley-EC2N-3:
	IPSec/IKE/Oakley curve #3 over a 155 bit binary field.
	Not suitable for ECDSA.
	Questionable extension field!
  Oakley-EC2N-4:
	IPSec/IKE/Oakley curve #4 over a 185 bit binary field.
	Not suitable for ECDSA.
	Questionable extension field!
  brainpoolP160r1: RFC 5639 curve over a 160 bit prime field
  brainpoolP160t1: RFC 5639 curve over a 160 bit prime field
  brainpoolP192r1: RFC 5639 curve over a 192 bit prime field
  brainpoolP192t1: RFC 5639 curve over a 192 bit prime field
  brainpoolP224r1: RFC 5639 curve over a 224 bit prime field
  brainpoolP224t1: RFC 5639 curve over a 224 bit prime field
  brainpoolP256r1: RFC 5639 curve over a 256 bit prime field
  brainpoolP256t1: RFC 5639 curve over a 256 bit prime field
  brainpoolP320r1: RFC 5639 curve over a 320 bit prime field
  brainpoolP320t1: RFC 5639 curve over a 320 bit prime field
  brainpoolP384r1: RFC 5639 curve over a 384 bit prime field
  brainpoolP384t1: RFC 5639 curve over a 384 bit prime field
  brainpoolP512r1: RFC 5639 curve over a 512 bit prime field
  brainpoolP512t1: RFC 5639 curve over a 512 bit prime field
  SM2       : SM2 curve over a 256 bit prime field
```

生成一个参数文件，通过 -name 指定命名曲线

```c
$ openssl ecparam -name secp256k1 -out secp256k1.pem

// 查看参数文件，下面这句话默认只打印曲线名字
$ openssl ecparam -in secp256k1.pem -text -noout
```

输出

```c
ASN1 OID: secp256k1

-----BEGIN EC PARAMETERS-----
BgUrgQQACg==
-----END EC PARAMETERS-----
```

显示参数文件内具体参数

```c
// 显示参数文件内具体参数
$ openssl ecparam -in secp256k1.pem -text -param_enc explicit -noout
```

输出

```c
Field Type: prime-field
Prime:
    00:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:
    ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:fe:ff:
    ff:fc:2f
A:    0
B:    7 (0x7)
Generator (uncompressed):
    04:79:be:66:7e:f9:dc:bb:ac:55:a0:62:95:ce:87:
    0b:07:02:9b:fc:db:2d:ce:28:d9:59:f2:81:5b:16:
    f8:17:98:48:3a:da:77:26:a3:c4:65:5d:a4:fb:fc:
    0e:11:08:a8:fd:17:b4:48:a6:85:54:19:9c:47:d0:
    8f:fb:10:d4:b8
Order:
    00:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:
    ff:fe:ba:ae:dc:e6:af:48:a0:3b:bf:d2:5e:8c:d0:
    36:41:41
Cofactor:  1 (0x1)
```

参数解释：

- A 和 B 是椭圆曲线公式参数
- P 大质数，它把 ECC 所有点的大小都控制在有限域中。几乎所有的 ECC 操作都会对 P 进行取模运算
- Generator 就是基点 G。由 (gx,gy) 组合
- Order 相当于基点的 n。也就是基点的打点次数。大部分的 ECC 操作都不需要这个值，除了 ECDSA 在计算签名的时候会对 Order 取模，而不是对 P 取模
- Cofactor 该值等于椭圆曲线上所有点总数除以 n。

>在 ECC 中，k 就是私钥，g 就是基点，kg 基于公式运算最终得到公钥，通过公钥很难计算出私钥 k，其背后有复杂的数学理论，即离散对数问题。

接下来举一个 ECDH 密钥协商的完整例子。

```c
// 生成参数文件
$ openssl ecparam -name secp256k1 -out secp256k1.pem
```

输出

```c
-----BEGIN EC PARAMETERS-----
BgUrgQQACg==
-----END EC PARAMETERS-----
```

Alice 生成 EDCH 私钥对文件

```c
$ openssl genpkey -paramfile secp256k1.pem -out akey.pem
```

输出

```c
-----BEGIN PRIVATE KEY-----
MIGEAgEAMBAGByqGSM49AgEGBSuBBAAKBG0wawIBAQQgXVTzOp6aEkAeC2ICiPTi
bmAZkr1RYtzprh3Larg4n/yhRANCAATbDBxnW/pTc6fS1Rk/bJEZZLp0fBGfn+H8
hYJILjrQu7ZORRlQqe+o2le1+OV2t/l3bEGOYAI8nvHOhT6weN/e
-----END PRIVATE KEY-----
```

Bob 生成 EDCH 私钥对文件

```c
$ openssl genpkey -paramfile secp256k1.pem -out bkey.pem
```

输出

```c
-----BEGIN PRIVATE KEY-----
MIGEAgEAMBAGByqGSM49AgEGBSuBBAAKBG0wawIBAQQgjhUWgm7C3tcXTUcqX9RG
aHCJQ5BqF0OzCBYntGnhJwahRANCAARPI4E54N3VfbHTfcvoUXNGJrIcMHAEhj6t
TkKrpEYMCbPkM0g57C2DWcOIqvb9ImD8OYQ+N27LlVNhYt6ncD/v
-----END PRIVATE KEY-----
```

Alice 分解出公钥，将公钥发送给 Bob

```c
$ openssl pkey -in akey.pem -pubout -out akey_pub.pem
```

输出

```c
-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE2wwcZ1v6U3On0tUZP2yRGWS6dHwRn5/h
/IWCSC460Lu2TkUZUKnvqNpXtfjldrf5d2xBjmACPJ7xzoU+sHjf3g==
-----END PUBLIC KEY-----
```

Bob 分解出公钥，将公钥发送给 Alice

```c
$ openssl pkey -in bkey.pem -pubout -out bkey_pub.pem
```

输出

```c
-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAETyOBOeDd1X2x033L6FFzRiayHDBwBIY+
rU5Cq6RGDAmz5DNIOewtg1nDiKr2/SJg/DmEPjduy5VTYWLep3A/7w==
-----END PUBLIC KEY-----
```

Alice 收到 Bob 他的公钥，并将协商出来的密钥保存到 data\_a.txt 中 

```c
$ openssl pkeyutl -derive -inkey akey.pem -peerkey bkey_pub.pem -out data_a.txt
```

输出

```c
��tR�"��g����_������]�Vn�Uɺ
```

对应二进制

```c
$ od -d data_a.txt

0000000     38303   21108    8888   49924   26595   54407   63697   57439
0000020     61643   63942   37357   63837   28246    3817    5973   47817
0000040
```

Bob 收到 Alice 他的公钥，并将协商出来的密钥保存到 data\_b.txt 中

```c
$ openssl pkeyutl -derive -inkey bkey.pem -peerkey akey_pub.pem -out data_b.txt
```

输出

```c
��tR�"��g����_������]�Vn�Uɺ
```

对应二进制

```c
$ od -d data_a.txt

0000000     38303   21108    8888   49924   26595   54407   63697   57439
0000020     61643   63942   37357   63837   28246    3817    5973   47817
0000040
```

可以发现两者最后协商出来的密钥是完全一致的



------------------------------------------------------

Reference：
  
《图解密码技术》   
[《RSA算法原理（一）》](http://www.ruanyifeng.com/blog/2013/06/rsa_algorithm_part_one.html)  
[《RSA算法原理（二）》](http://www.ruanyifeng.com/blog/2013/07/rsa_algorithm_part_two.html)       


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/asymmetric\_encryption/](https://halfrost.com/asymmetric_encryption/)