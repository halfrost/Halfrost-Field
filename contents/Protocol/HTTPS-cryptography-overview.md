# 密码学概述


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/96_0.png'>
</p>


## 一、为什么需要加密

![](https://img.halfrost.com/Blog/ArticleImage/96_3.png)

每个人都有自己的秘密，如果不加密，在网上传输很容易被监听。如果涉及到金钱相关，密码泄露以后很容易造成损失。所以都会利用**加密** cryptography 技术，保证信息的**机密性** confidentiality。

![](https://img.halfrost.com/Blog/ArticleImage/96_4.png)

信息被加密以后变成了密文在网上传播，接收者拿到密文进行**解密** cryptanalysis，解密以后就可以看到明文。

![](https://img.halfrost.com/Blog/ArticleImage/96_5.png)

进行破译密码的人叫破译者，破译者不一定都是坏人，密码学研究者为了研究密码强度，也会需要对密码进行破译，研究者在这种情况下也是破译者。



## 二、对称加密

**对称密码** (symmetric cryptography)是指在加密和解密时使用同一密钥的方式。对应的加密方式是对称加密。

对称密码有多种别名，**公共密钥密码**(common-key cryptography)，**传统密码**(conventional cryptography)，**私钥密码**(secret-key cryptography)，**共享密钥密码**(shared-key cryptography)等。

![](https://img.halfrost.com/Blog/ArticleImage/96_1.png)

## 三、非对称加密

**公钥密码** (public-key cryptography)则是指在加密和解密时使用不同密钥的方式。对应的加密方式是非对称加密。

![](https://img.halfrost.com/Blog/ArticleImage/96_2.png)

## 四、单向散列函数

网上很多免费的软件，为了防止软件被篡改，有安全意识的软件发布者会在发布软件的同时会发布这个版本软件的散列值 hash。散列值是用单向散列函数(one-way hash function)计算出来的数值。

> **散列值** hash，又被称为**哈希值**，**密码校验和**(cryptographic checksum)，**指纹**(fingerprint)，**消息摘要**(message digest)。

单向散列函数并不是为了保证消息的机密性，而是**完整性**(integrity)。完整性指的是，数据是正确的，而不是伪造的。单向散列函数是保证信息的完整性的密码技术，它会检测数据是否被篡改。

## 五、消息认证码

为了确认消息是否来自期望的通信对象，可以通过使用**消息认证码**(message authentication code)。消息认证码主要是提供了认证(authentication)机制，与此同时它也能保证消息的完整性。

## 六、数字签名

试想有这样一种情况，A 欠 B 100 万美刀，于是 A 向 B 打了一张欠条。一周以后，A 拿到钱以后就不承认那张欠条是自己写的，抵赖借钱了。

这个时候就牵扯到密码学里面的防抵赖的技术 —— **数字签名**。数字签名类似现实世界中的签名和盖章，数字签名是一种能防止用户抵赖，伪装，篡改和否认的密码技术。

如果用户 B 能让 A 在打欠条的时候，签上自己的签名(数字签名)，这样可以防止他日后抵赖。


## 七、伪随机数生成器

**伪随机数生成器**(Pseudo Random Number Generator，PRNG)是一种能够模拟产生随机数列的算法。伪随机数负责承担**密钥生成**的职责。


## 八、隐写术和数字水印

加密技术是为了让消息内容本身无法被读取。而隐写术是为了能够隐藏消息本身。

举个例子，比如在一个音乐里面可以隐藏一张图片，在特定的比特位上面分别插入图片的二进制位，只要记住哪些位是图片，哪些为是音乐，那么就能还原成一首音乐和一张图片。

再比如，iOS 开发中，可以把客户端本地的证书隐藏到图片资源中。这样就算怀有恶意的人拆开 ipa 安装包，咋一看也找不到证书文件，除非先逆向代码，找到隐写术的算法才能获取到证书的真实文件。

数字水印就是利用了隐写术的方法。数字水印是一种将著作权拥有者及购买者的信息嵌入文件中的技术。但是仅仅凭借数字水印技术是没有办法对信息进行保密的，所以需要结合其他的技术一起。


可以将加密和隐写术结合起来使用。类似上面证书隐藏到图片中的例子。证书是加密过的，所以证书隐藏了敏感信息，隐写术又隐藏了证书本身。

## 九、信息安全常识

1. 不要使用保密的密码算法
2. 使用低强度的密码比不进行任何加密更加危险
3. 任何密码总有一天都会被破解
4. 密码只是信息安全的一部分


## 十、历史上的著名密码

历史上著名的密码有，凯撒密码，简单替换密码，Enigma。

凯撒密码是把明文简单的平移 n 位，得到密文。这种密码强度低，可以用暴力破解它，左右移动尝试 0-25 次就可以破译。

简单替换密码是把明文按照映射表，把明文映射成密文。这种密码也可以破译，利用频率分析即可破译。一篇文章的字母出现的频次基本是固定的，通过观察密文的字母出现频次，可以推断出映射表。

Enigma 是二战中德国使用的密码机器。通过转子和接线的方式来产生密钥。过程略复杂。图灵在 1940 年研究出了破译 Enigma 的机器。

------------------------------------------------------

Reference：
  
《图解密码技术》      


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/cryptography\_overview/](https://halfrost.com/cryptography_overview/)