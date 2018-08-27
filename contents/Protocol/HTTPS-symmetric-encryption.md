# HTTPS 温故知新（二） —— 对称加密


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_0.png'>
</p>


## 一、引子

在引出对称加密之前，有必要先介绍一种位运算，XOR。XOR 的全称是 exclusive or，中文翻译是异或。

```c
0 XOR 0 = 0
0 XOR 1 = 1
1 XOR 0 = 1
1 XOR 1 = 0
```

XOR 可以看成是“两个数相同，异或为 0 ，不同则异或为 1”。

异或也叫半加运算，其运算法则相当于不带进位的二进制加法：二进制下用1表示真，0表示假，则异或的运算法则为：

```c
0 ⊕ 0 = 0
1 ⊕ 0 = 1
0 ⊕ 1 = 1
1 ⊕ 1 = 0
```
这些法则与加法是相同的，只是不带进位，所以异或常被认作不进位加法。由异或的这种特点，也就引出了它的一个常用特性，**两个相同的数进行 XOR 运算的结果一定为 0**。

对应的，我们也可以得到如下的运算法则：

```c
1. a ⊕ a = 0
2. a ⊕ b = b ⊕ a 交换率
3. a ⊕ b ⊕ c = a ⊕ (b ⊕ c) = (a ⊕ b) ⊕ c  结合律
4. d = a ⊕ b ⊕ c 可以推出 a = d ⊕ b ⊕ c
5. a ⊕ b ⊕ a = b
```
上述这几条法则推导过程就不赘述了，相信读者都能明白。

异或的结合律可以用来做简单的对称加密。

试想，如果把异或数设置成一个完全随机的二进制序列，那么被异或数和它进行一次异或运算以后，结果如同“密文”一样。如果窃听者不知道异或数是什么，很难短时间内解出原消息来。

```c
a ⊕ b ⊕ b = a ⊕ (b ⊕ b) = a ⊕ 0 = a
```
消息接收者拿到密文以后，把密文再和异或数进行一起异或运算，就能拿到原文了。这个性质就是异或的结合律。



## 二、一次性加密本

只要通过暴力破解，对密钥空间进行遍历，密文总有一天一定能被破译。只不过看密钥空间有多大，需要花费的时间有多长。但是有一种加密方法却是被证明永远都无法被破解的，即便是暴力遍历了所有密钥空间，依旧无法被破解。

笔者第一次见到这个加密方法的时候，觉得非常神奇，还有这么强大的加密方法，那加密过程应该非常复杂，数学证明也应该非常完备吧。结果看到它的原理以后，发现并非如此。一次性密码本的加密方法非常简单，只用了上一章提到的 XOR 异或运算。


### (一) 加密

一次性密码本加密，举个例子，假设要加密的原文是 midnight。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_1_.png'>
</p>

密钥为一个随机的二进制流。一次性密码本加密的过程，是把明文和密钥进行一次异或计算。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_2.png'>
</p>


### (二) 解密

一次性密码本的解密过程是把密文和密钥进行一次异或计算，得到原文明文。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_3.png'>
</p>

看完这个加密解密过程，读者肯定质疑这种方式很容易被破解啊，64 位随机的二进制流暴力遍历它的密钥空间，一定能试出原文是什么。

那么现在就可以解开谜底了。确实用暴力破解能遍历所有密钥空间，假设有一个超级量子计算机可以一秒遍历完 2^64^ 这么大的密钥空间，但是依旧没法破译一次性密码本。它的“神奇”之处在于，你在不断尝试的过程中，会尝试出很多种情况，比如可能得到 abcdefg、aaaaa、plus、mine 这些原文，但是你无法判断此时你是否破译正确了。这也就是一次性密码本无法破译的原因，和密钥空间大小无关。

一次性密码本无法破译这一特性是由香农(C.E.Shannon)于 1949 年通过数学方法加以证明的。一次性密码本是**无条件安全的(unconditionally secure)，理论上是无法破译的(theoretically unbreakable)**。

### (三) 缺点

一次性密码本虽然这么强大，但是现实中没有人用一次性密码本进行加密。原因有一下几点：

#### 1. 密钥如何发送给对方？

在一次性密码本中，密钥和原文是一样长度的，试想如果有办法能把密文安全的送达到对方，那么是否可以用这种方法把明文送达到对方呢？所以这是一个矛盾的问题。

#### 2. 密钥保存是一个问题

一次性密码本的密钥长度和原文一样长，密钥不能删除也不能丢弃。丢弃了密钥相当于丢弃了明文。所以“加密保护明文”的问题被转换成了“如何安全的保护和明文一样长度的密钥”的问题，实际上问题还是没有解决。


#### 3. 密钥无法重用

如果加密的原文很长，那么密钥也要相同长度，并且密钥每次还要不同，因为如果是相同的，密钥一旦泄露7以后，过去所有用这个密钥进行加密的原文全部都会被破译。


#### 4. 密钥同步难

如果密钥每次都变化，那么密钥如何同步也是一个问题。密钥在传递过程中不能有任何错位，如果错位，从错位的那一位开始之后的每一位都无法解密。

#### 5. 密钥生成难

一次性密码本想要真正的永远无法破解，就需要生成大量的真正的随机数，不能是计算机生成的伪随机数。


据说国家之间的热线电话用的就是一次性密码本，但是是如何避免上述 5 点缺点的呢？国家会派专门的特工，用人肉的方式进行押送密钥的任务，直接把密钥交到对方的手中。

可见一次性密码本虽然无法破译，但是想要用它进行加密，“成本”非常高。如此可见一次性密码本在日常使用中基本没有任何使用价值。不过一次性密码本的思路孕育了 **流密码(stream cipher)**。流密码使用的不是真正的随机比特序列，而是伪随机数生成器产生的二进制比特序列。流密码虽然不是无法破译的，但只要使用高性能的伪随机数生成器就能够构建出强度较高的密码系统。流密码在下面章节会详细分析。

## 三、对称加密算法 DES

DES (Data Encryption Standard) 是 1977 年美国联邦信息处理标准(FIPS)中所采用的一种对称密码(FIPS 46-3)。DES 一直以来被美国以及其他国家的政府和银行所使用。

1997 年 DES Challenge I 比赛中用了 96 天破解了 DES 密钥，1998 年的 DES Challenge II-1 比赛中用了 41 天就破解了密钥。1998 年的 DES Challenge II-2 比赛中用了 56 个小时，1999 年的 DES Challenge III 比赛中只用了 22 小时 15 分钟。目前来说，DES 已经不再安全了。除了用来解密以前老的 DES 密文以外，不再使用 DES 进行加密了。


### (一) 加密

DES 是一种把 64 位明文加密成 64 位密文的对称加密算法。它的密钥长度为 64 比特，但是除去每 7 个二进制位会设置一个用于错误检测的位以外，实际上密钥为 56 比特。DES 会以 64 个二进制为一个**分组**进行加密。以分组为单位进行处理的密码算法成为**分组密码**，DES 为分组密码的一种。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_4_.png'>
</p>

DES 只能一次性加密 64 位明文，如果明文超过了 64 位，就要进行分组加密。反复迭代，迭代的方式成为**模式**。关于模式更加具体的讨论见下一章节。

DES 加密的基本结构是 **Feistel 网络、Feistel 结构、Feistel 密码**，这个结构不仅仅用在 DES 中，还用在其他的加密算法中。

在 Feistel 网络中，加密的各个步骤称为**轮(round)**，整个加密过程就是若干次轮的循环。DES 是一种 16 轮循环的 Feistel 网络。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_6.png'>
</p>

上图展示的是一次加密 64 位明文的过程。每次加密所用的密钥都不同，由于它只在本轮使用，是一个局部密钥，所以也被称为子密钥。

每轮的操作步骤如下：

- 将输入的 64 位分为左右两个 32 位。
- 将输入右侧的 32 位直接向下落到输出的右侧 32 位。
- 将输入右侧作为轮函数的入参输入。
- 轮函数根据输入右侧的 32 位和 子密钥两个入参，生成一串看上去随机的比特序列输出。
- 将轮函数的输出和输入左侧 32 位进行异或运算，结果向下落到输出的左侧 32 位。

这样经过一轮以后，只加密了输入的一半的数据，上例中右侧就没有被加密。我们可以用另外一个子密钥加密右侧的数据。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_7.png'>
</p>

上图是一个 3 轮的 Feistel 网络。3 轮网络有 3 个子密钥和 3 个轮函数，中间有 2 次左右对调的过程。**注意：n 轮 Feistel 网络只交换 n-1 次，最后一次不用交换**。

### (二) 解密

DES 的解密过程和加密过程是相反的。解密也是 64 位分组解密。解密密钥实质也是 56 位。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_5.png'>
</p>

再来聊聊 Feistel 网络的解密过程。

由于 XOR 具有交换律的特性，只要再次做一次异或运算，就能还原明文。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_8.png'>
</p>

从上面这个图中，可以看出 **Feistel 网络的加密和解密步骤完全相同**。

同样也以 3 轮 Feistel 网络的解密过程来举例。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_9.png'>
</p>

解密步骤也和加密步骤完全相同的，只不过子密钥的顺序是逆序的。因为要和之前加密的顺序配合在一起。假设是 n 轮网络，子密钥 1 - n，要想还原成明文，异或的顺序要逆序反过来，这样才能利用 `a ⊕ a = 0`，异或的结合律，还原明文。


### (三) 优点

Feistel 网络的特点

- 加密的时候无论使用任何函数作为轮函数都可以正确的解密，无须担心无法解密。就算轮函数输出的结果无法逆向计算出输入的值也无须担心。Feistel 网络把加密算法中核心的加密本质封装成了这个轮函数，设计算法的人把所有的心思放在把轮函数设计的尽量负责即可。
- 加密和解密可以用完全相同的结构来实现。虽然每一轮只加密了一半的明文，放弃了加密效率，但是获得了可以用相同结构来实现，对于加密硬件设备设计也变得更加容易。

由于 Feistel 网络的这些优点，所以很多分组密码选择了它。比如 AES 候选算法中的 MARS、RC6、Twofish。不过最终 AES 定下的 Rijndael 算法并没有选择它，而是选择的 SPN 网络。


## 四、对称加密算法 3DES


三重 DES (triple-DES) 是为了增加 DES 强度，所以将 DES 重复 3 次得到的一种算法。也称为 TDEA (Triple Data Encryption Algorithm)，通常缩写为 3DES。

### (一) 加密

3DES 加密就是进行 3 次 DES 加密。DES 密钥长度为 56 位，所以 3DES 密钥长度为 56 * 3 = 168 位。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_10.png'>
</p>

不过 3DES 有一个“奇怪”的地方，并不是用 DES 加密 3 次，而是加密-解密-加密，中间有一次解密的过程。IBM 公司之所以这么设计，目的是为了让三重 DES 能兼容普通的 DES。如果三重加密中密钥都完全相同，那么就退化成了普通的 DES 了。(加密一次解密一次就抵消了)所以也就具备了向下兼容性。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_11.png'>
</p>

- 如果 3 次都用相同的密钥，则退化成了 DES。
- 如果第一次和第三次用相同的密钥，第二次用不同的密钥，这种三重 DES 称为 DES-EDE2 。EDE 是加密(Encryption) -> 解密(Decryption) -> 加密(Encryption) 的缩写。
- 如果 3 次都用不同的密钥，则称 DES-EDE3。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_12.png'>
</p>

### (二) 解密

3DES 解密的过程和加密的过程正好相反，按照密钥的逆序解密。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_13.png'>
</p>

### (三) 缺点

3DES 由于处理速度不高，除了兼容之前的 DES 以外，目前基本不再使用它了。

## 五、对称加密算法 AES 和 Rijndael

AES (Advanced Encrytion Standard) 是取代前任标准 DES 而成为新标准的一种对称密码算法。在全世界的范围内征集 AES 加密算法，最终于 2000 年从候选中选出了 Rijndael 算法，确定它为新的 AES。

1997 年开始征集 AES，1998 年满足条件并最终进入评审的有 15 个算法：CAST-256、Crypton、DEAL、DFC、E2、Frog、HPC、LOK197、Magenta、MARS、RC6、Rijndael、SAFER+、Serpent、Twofish。2000 年 10 月 2 日，Rijndael 并定位 AES 标准。AES 可以免费的使用。

Rijndael 的分组长度和密钥长度可以分别以 32 位比特为单位在 128 比特到 256 比特的范围内进行选择。不过在 AES 的规范中，分组长度被固定在 128 比特，密钥长度只有 128、192 和 256 比特三种。

### (一) 加密

AES 的加密也是由多个轮组成的，分为 4 轮，SubBytes、ShiftRows、MixColumns、AddRoundKey 这 4 步，即 SPN 网络。

#### 1. SubBytes 字节变换

Rijndael 的输入分组默认为 128 比特，也就是 16 字节。第一步需要对每个字节进行 SubBytes 处理。以每个字节的值(0-255之间的任意值)为索引，从一张拥有 256 个值的替换表 S-Box 中查找出对应的值进行处理。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_14.png'>
</p>

经过 SubBytes 变换以后，左边 16 个字节(128 个比特)都变换成右边的 16 个字节。

#### 2. ShiftRows 移行操作

这一步以 4 字节为单位的行 row 进行左移操作，且每一行平移的字节数不同。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_15.png'>
</p>

移动以后，每一行都“错位”了。

#### 3. MixColumns 混行操作

这一步以 4 字节为单位的列 column 进行矩阵运算。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_16.png'>
</p>

经过这一步变换以后，每一列和之前的列都不同了。

#### 4. AddRoundKey 异或运算

将上一步的输出与轮密钥进行 XOR，即进行 AddRoundKey 处理。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_17.png'>
</p>

如上图，左边 16 字节每个字节一次与轮密钥对应位置上的字节进行异或运算，计算完成以后得到最终的密文。

到这里为止，是一轮 Rijndael 结束。

完成的一轮解密如下图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_21.png'>
</p>


一般整个算法要进行 10-14 轮计算。

### (二) 解密

Rijndael 的解密过程为加密的逆过程。

在 Rijndael 加密过程中，每一轮处理的顺序为：

SubBytes -> ShiftRows -> MixColumns -> AddRoundKey

在 Rijndael 解密过程中，每一轮处理的顺序为：

AddRoundKey -> InvMixColumns -> InvShiftRows -> InvSubBytes 

解密过程中除了第一步和加密完全一样，其他三步都为加密的逆过程。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_17.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_18.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_19.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/98_20.png'>
</p>

### (三) 优点

SPN 网络和 Feistel 网络相比，加密效率更高，因为 SPN 一轮会加密所有位。所以加密所需轮数会更少。

还有一个优势在于加密用的 4 步可以并行运算。

目前还没有针对 AES 有效的攻击破译方式。

## 六、分组模式

由于 DES 和 AES 一次加密都只能加密固定长度的明文，如果需要加密任意长度的明文，就需要对分组密码进行迭代，而分组密码的迭代方式就称为分组密码的“模式”。

分组密码有很多模式，如果模式选择的不恰当就无法充分保障机密性。

------------------------------------------------------

Reference：
  
《图解密码技术》      


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()