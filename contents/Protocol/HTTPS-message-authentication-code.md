# 消息认证码是怎么一回事？


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_0.png'>
</p>


## 一、为什么需要消息认证码？

还是举一个银行汇钱的例子：A 向 B 汇钱 100 万元。如果攻击者从中攻击，篡改这条消息，就可能变成 A 向攻击者汇钱 1000 万元。这里针对汇款消息，需要注意两个问题：消息的 “完整性” 和 “认证” 。

消息的完整性，就叫消息的一致性，这个可以用上一篇文章中讲的消息指纹来判断，通过对比单向散列函数的 hash 值来判断这条消息的完整性，有没有被篡改。

消息的认证，指的是，消息是否来自正确的发送者。如果确认汇款请求确实来自 A，就相当于对消息进行了认证，代表消息没有被伪装。

**如果同时需要识别出篡改和伪装，即要确认消息的完整性，又要对消息进行认证，这种情况下就需要消息认证码**。

## 二、什么是消息认证码？

**消息认证码**(Message Authentication Code) 是一种确认完整性并进行认证的技术，简称 MAC。

使用消息认证码可以确认自己收到的消息是否就是发送者的本意，也就是说可以判断消息是否被篡改，是否有人伪装成发送者发送了这条消息。

>消息认证码也是密码学家工具箱中的 6 大工具之一：对称密码、公钥密码、单向散列函数、消息认证码、数字签名和伪随机数生成器。

消息认证码的输入包括任意长度的**消息**和一个发送者与接收者之间的**共享密钥**。输出固定长度的数据，输出的数据就是 MAC 值。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_1.png'>
</p>


消息认证码和单向散列函数的区别就在有没有这个**共享密钥**上了。所以消息认证码就是利用共享密钥进行认证的。消息认证码和单向散列函数的散列值一样，如果消息发生了 1 比特的变化，MAC 值也会发生变化。所以消息认证码正是用这个性质来进行完整性的。

所以消息认证码可以理解为**消息认证码是一种与密钥相关联的单向散列函数**。



## 三、消息认证码的使用步骤

如果银行之间汇款采用消息认证码，流程会如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_2_.png'>
</p>

大体流程和验证单向散列函数基本一致，只不过消息认证码需要共享密钥来解出 MAC 值。

不过消息认证码的共享密钥存在密钥配送问题。密钥在配送中不能被窃听者窃取。解决密钥配送问题需要用到上上篇文章中讲的公钥密码、Diffie-Hellman 密钥交换等其他安全的方式配送密钥。

## 四、消息认证码使用现状

- SWIFT（Society for Worldwide Interbank Financial Telecommunications---环球同业银行金融电讯协会) 是一个目的为国际银行间的交易保驾护航的协会。银行和银行间通过 SWIFT 来传递交易消息，SWIFT 会利用消息认证码校验消息的完整性和对消息的验证。消息认证码的共享密钥是由人进行配送的。

- IPsec 是对 IP 协议增加安全性的一种方式，在 IPsec 中，对消息的认证和完整性校验也是用消息认证码的方式。

- SSL/TLS 对通信内容的认证和完整性校验也用了消息认证码。

## 五、消息认证码的实现方式

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_6.png'>
</p>

- 使用 SHA-2 之类的单向散列函数可以实现消息认证码，例如 HMAC。  

- 使用 AES 之类的分组密码可以实现消息认证码。分组密码的密钥作为共享密钥，利用 CBC 模式将消息全部加密。由于消息认证码中不需要解密，所以可以只留下最后一个分组，其他分组全部丢弃。CBC 模式的最后一个分组会受到整个消息以及密钥的双重影响，所以它可以作为 MAC 值。AES-CMAC (RFC4493) 就是一种基于 AES 来实现的消息认证码。

- 流密码

- 公钥密码

2000 年以后，人们基于认证的研究更加进一步，产生了**认证加密** (AE：Authenticated Encryption，AEAD：Authenticated Encryption with Associated Data)。认证加密是一种将对称密码和消息认证相结合的技术，同时满足加密性，完整性和认证性三大功能。

认证加密有几种，这里举例：例如 Encrypt-then-MAC，先用对称密码将明文加密，然后计算密文的 MAC 值。Encrypt-and-MAC，将明文用对称密码加密，并对明文计算 MAC 值。MAC-then-Encrypt，先计算明文的 MAC 值，然后将明文和 MAC 值同时用对称密码加密。**在 HTTPS 中，一般使用 MAC-then-Encrypt 这种模式进行处理**。

GCM(Galois/Counter Mode)是一种认证加密方式。GCM 中使用 AES 等 128 位比特分组密码的 CTR 模式，并使用一个反复进行加法和乘法运算的散列函数来计算 MAC 值。CTR 模式加密与 MAC 值的计算使用的是相同密钥，所以密钥管理很方便。专门用于消息认证码的 GCM 成为 GMAC。**GCM 和 CCM (CBC Counter Mode) 都是被推荐的认证加密方式**。

>ChaCha20-Poly1305 是谷歌发明的一种算法，使用 ChaCha20 流密码进行加密运算，使用 Poly1305 算法进行 MAC 运算。

## 六、HMAC 算法

HMAC 是一种使用单向散列函数来构造消息认证码的方法，HMAC 中的 H 是 Hash 的意思。官方文档见 [RFC 2104](https://tools.ietf.org/html/rfc2104)

任何高强度的单向散列函数都可以被用于 HMAC 中，例如 SHA-1、SHA-224、SHA-256、SHA-384、SHA-512 所构造的 HMAC，分别称为 HMAC-SHA1、HMAC-SHA-224、HMAC-SHA-256、HMAC-SHA-384、HMAC-SHA-512。

HMAC 计算 MAC 值步骤如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_3__.png'>
</p>


### 1. 密钥填充

如果密钥比单向散列函数的分组长度要短，就需要在末尾填充 0，使最终长度和单向散列函数分组长度一样。

如果密钥比分组长度要长，则要用单向散列函数求出密钥的散列值，然后把这个散列值作为 HMAC 的密钥。


### 2. 密钥变换 I

将填充后的密钥和 ipad 的比特序列进行 XOR 计算。ipad 是 00110110 (16进制的 36)不断循环直到长度和分组长度一样长的比特序列。ipad 的 i 是 inner 内部的意思。

XOR 得到的最终结果是一个**和单向散列函数的分组长度相同，且和密钥相关的比特序列**。这个序列称为 ipadkey。

### 3. 与消息组合

把 ipadkey 附加在消息的开头。


### 4. 计算散列值

把第 3 步的结果输入单向散列函数，计算出散列值。

### 5. 密钥变换 II


将填充后的密钥和 opad 的比特序列进行 XOR 计算。opad 是 01011100 (16进制的 5C)不断循环直到长度和分组长度一样长的比特序列。opad 的 o 是 outer 外部的意思。

XOR 得到的最终结果是一个**和单向散列函数的分组长度相同，且和密钥相关的比特序列**。这个序列称为 opadkey。

### 6. 与散列值组合

把 opadkey 附加在散列值的开头。

### 7. 计算散列值

把第 6 步的结果输入单向散列函数，计算出散列值。这个散列值即为最终 MAC 值。


最终的 MAC 值一定是一个和输入消息以及密钥都相关的长度固定的比特序列。

HMAC 如果用伪代码表示：

```c
HMAC = hash(opadkey || hash(ipadkey || message))
	 = hash( (key ⊕ opad) || hash( (key ⊕ ipad) || message) )

opadkey = key ⊕ opad
ipadkey = key ⊕ ipad

key 为密钥，message 为消息，hash 计算为 hash()，A || B 代表 A 放在 B 的前面
```

具体举一个 HMAC\_MD5 的例子：

```c
/*
** Function: hmac_md5
*/

void hmac_md5(text, text_len, key, key_len, digest)
unsigned char*  text;                /* pointer to data stream */
int             text_len;            /* length of data stream */
unsigned char*  key;                 /* pointer to authentication key */
int             key_len;             /* length of authentication key */
caddr_t         digest;              /* caller digest to be filled in */

{
        MD5_CTX context;
        unsigned char k_ipad[65];    /* inner padding -
                                      * key XORd with ipad
                                      */
        unsigned char k_opad[65];    /* outer padding -
                                      * key XORd with opad
                                      */
        unsigned char tk[16];
        int i;
        /* if key is longer than 64 bytes reset it to key=MD5(key) */
        if (key_len > 64) {

                MD5_CTX      tctx;

                MD5Init(&tctx);
                MD5Update(&tctx, key, key_len);
                MD5Final(tk, &tctx);

                key = tk;
                key_len = 16;
        }

        /*
         * the HMAC_MD5 transform looks like:
         *
         * MD5(K XOR opad, MD5(K XOR ipad, text))
         *
         * where K is an n byte key
         * ipad is the byte 0x36 repeated 64 times
         * opad is the byte 0x5c repeated 64 times
         * and text is the data being protected
         */

        /* start out by storing key in pads */
        bzero( k_ipad, sizeof k_ipad);
        bzero( k_opad, sizeof k_opad);
        bcopy( key, k_ipad, key_len);
        bcopy( key, k_opad, key_len);

        /* XOR key with ipad and opad values */
        for (i=0; i<64; i++) {
                k_ipad[i] ^= 0x36;
                k_opad[i] ^= 0x5c;
        }
        /*
         * perform inner MD5
         */
        MD5Init(&context);                   /* init context for 1st
                                              * pass */
        MD5Update(&context, k_ipad, 64)      /* start with inner pad */
        MD5Update(&context, text, text_len); /* then text of datagram */
        MD5Final(digest, &context);          /* finish up 1st pass */
        /*
         * perform outer MD5
         */
        MD5Init(&context);                   /* init context for 2nd
                                              * pass */
        MD5Update(&context, k_opad, 64);     /* start with outer pad */
        MD5Update(&context, digest, 16);     /* then results of 1st
                                              * hash */
        MD5Final(digest, &context);          /* finish up 2nd pass */
}

```

输出

```c
  key =         0x0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b
  key_len =     16 bytes
  data =        "Hi There"
  data_len =    8  bytes
  digest =      0x9294727a3638bb1c13f48ef8158bfc9d
  
  
  key =         "Jefe"
  data =        "what do ya want for nothing?"
  data_len =    28 bytes
  digest =      0x750c783e6ab0b503eaa86e310a5db738
  
  
  key =         0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  key_len       16 bytes
  data =        0xDDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD...
                ..DDDDDDDDDDDDDDDDDDDD
  data_len =    50 bytes
  digest =      0x56be34521d144c88dbb8c733f0e8b3f6

```


## 七、对消息认证码的攻击

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_5.png'>
</p>

### 1. 重放攻击

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/103_4_.png'>
</p>

窃听者不直接破解消息认证码，而是把它保存起来，反复利用，这种攻击就叫做**重放攻击(replay attack)**。

防止重放攻击可以有 3 种方法：

- 序号  
每条消息都增加一个递增的序号，并且在计算 MAC 值的时候把序号也包含在消息中。这样攻击者如果不破解消息认证码就无法计算出正确的 MAC 值。这个方法的弊端是每条消息都需要多记录最后一个消息的序号。

- 时间戳  
发送消息的时候包含当前时间，如果收到的时间与当前的不符，即便 MAC 值正确也认为是错误消息直接丢弃。这样也可以防御重放攻击。这个方法的弊端是，发送方和接收方的时钟必须一致，考虑到消息的延迟，所以需要在时间上留下一定的缓冲余地。这个缓冲之间还是会造成重放攻击的可趁之机。

- nonce  
在通信之前，接收者先向发送者发送一个一次性的随机数 nonce。发送者在消息中包含这个 nonce 并计算 MAC 值。由于每次 nonce 都会变化，因此无法进行重放攻击。这个方法的缺点会导致通信的数据量增加。

### 2. 密钥推测攻击

消息认证码同样可以暴力破解以及生日攻击。消息认证码必须要保证不能通过 MAC 值推测出通信双方所使用的密钥。这一点可以通过单向散列函数的单向性和抗碰撞性来保证无法推测出密钥。

## 八、消息认证码无法解决的问题

消息认证码虽然可以证明双方发送的消息是一致的，没有篡改，也不存在中间人伪装。但是它无法 “对第三方证明” 和 “防止抵赖”。

无法 “对第三方证明” 原因是因为消息认证码中用到的密钥是共享密钥，通信双方都有这个密钥，所以对第三方无法证明消息到底出自双方中的哪一方。  
解决 “第三方证明” 的问题需要用到数字签名。

无法 “防止抵赖” 原因是也是因为消息认证码的共享密钥双方都有，无法判断消息是发自于哪一方。所以消息认证码无法防止否认(nonrepudiation)。  
解决 “防止抵赖” 的问题需要用到数字签名。

## 九、总结


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/102_2.png'>
</p>

单向散列函数保证消息的一致性，完整性，没有被篡改。  
消息认证码保证消息的一致性，完整性，没有被篡改，并且不存在中间人伪装。  
数字签名保证消息的一致性，完整性，没有被篡改，并且不存在中间人伪装，并且能防止抵赖。  

------------------------------------------------------

Reference：
  
《图解密码技术》        

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/message\_authentication\_code/](https://halfrost.com/message_authentication_code/)