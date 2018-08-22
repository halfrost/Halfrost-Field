# HTTPS 温故知新（二） —— 加密初步


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



<p align='center'>
<img src='../images/https_guide.png'>
</p>


<p align='center'>
<img src='../images/http_https.png'>
</p>

------------------------------------------------------

Reference：
  
《图解 HTTP》    
《HTTP 权威指南》  
《深入浅出 HTTPS》  


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()