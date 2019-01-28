# HTTPS 温故知新（三） —— 直观感受 TLS 握手流程


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0_.png'>
</p>


在 HTTPS 开篇的文章中，笔者分析了 HTTPS 之所以安全的原因是因为 TLS 协议的存在。TLS 能保证信息安全和完整性的协议是记录层协议。(记录层协议在上一篇文章中详细分析了)。看完上篇文章的读者可能会感到疑惑，TLS 协议层加密的密钥是哪里来的呢？客户端和服务端究竟是如何协商 Security Parameters 加密参数的？这篇文章就来详细的分析一下 TLS 1.2 和 TLS 1.3 在 TLS 握手层上的异同点。

TLS 1.3 在 TLS 1.2 的基础上，针对 TLS 握手协议最大的改进在于提升速度和安全性。本篇文章会重点分析这两块。

## 一、TLS 对网络请求速度的影响

由于部署了 HTTPS，传输层增加了 TLS，对一个完成的请求耗时又会多增加一些。具体会增加几个 RTT 呢？

先来看看一个请求从零开始，完整的需要多少个 RTT。假设访问一个 HTTPS 网站，用户从 HTTP 开始访问，到收到第一个 HTTPS 的 Response，大概需要经历一下几个步骤(以目前最主流的 TLS 1.2 为例)：


|流程 | 消耗时间 | 总计 |
| --- | :---: | :---:|
|1. DNS 解析网站域名 | 1-RTT | |
|2. 访问 HTTP 网页 TCP 握手 |  1-RTT | |
|3. HTTPS 重定向 302 |  1-RTT | |
|4. 访问 HTTPS 网页 TCP 握手|  1-RTT | |
|5. TLS 握手第一阶段 Say Hello| 1-RTT||
|6. 【证书校验】CA 站点的 DNS 解析| 1-RTT||
|7. 【证书校验】CA 站点的 TCP 握手| 1-RTT||
|8. 【证书校验】请求 OCSP 验证|1-RTT||
|9. TLS 握手第二阶段 加密| 1-RTT||
|10. 第一个 HTTPS 请求| 1-RTT||
|||10-RTT|


在上面这些步骤中，1、10 肯定无法省去，6、7、8 如果浏览器本地有缓存，是可选的。将剩下的画在流程图上，见下图：

![](https://img.halfrost.com/Blog/ArticleImage/97_1.png)

针对上面的步骤进行一些说明：

用户第一次访问网页需要解析 DNS，DNS 解析以后会被浏览器缓存下来，只要是 TTL 没有过期，期间的所有访问都不需要再耗 DNS 的解析时间了。另外如果有 HTTPDNS，也会缓存解析之后的结果。所以第一步并非每次都要花费 1-RTT。

如果网站做了 HSTS (HTTP Strict Transport Security)，那么上面的第 3 步就不存在，因为浏览器会直接替换掉 HTTP 的请求，变成 HTTPS 的，防止重定向的中间人攻击。

如果浏览器有主流 CA 的域名解析缓存，也不需要进行上面的第 6 步，直接访问即可。

如果浏览器关闭掉了 OCSP 或者是有本地缓存，那么也不需要进行上面的第 7 和第 8 步。 

上面这 10 步是最最完整的流程，一般有各种缓存不会经历上面每一步。如果有各种缓存，并且有 HSTS 策略，所以用户每次访问网页都必须要经历的流程如下：

|流程 | 消耗时间 | 总计 |
|--- | :---: | :---: |
|1. 访问 HTTPS 网页 TCP 握手 |  1-RTT | |
|2. TLS 握手第一阶段 Say Hello| 1-RTT||
|3. TLS 握手第二阶段 加密| 1-RTT||
|4. 第一个 HTTPS 请求| 1-RTT||
|||4-RTT|

除去 4 是无论如何都无法省掉的以外，剩下的就是 TCP 和 TLS 握手了。 TCP 想要减至 0-RTT，目前来看有点难。那 TLS 呢？目前 TLS 1.2 完整一次握手需要 2-RTT，能再减少一点么？答案是可以的。


## 二、TLS/SSL 协议概述

TLS 握手协议运行在 TLS 记录层之上，目的是为了让服务端和客户端就协议版本达成一致, 选择加密算法, 选择性的彼此相互验证对方, 使用公钥加密技术生成共享密钥——即协商出 TLS 记录层加密和完整性保护需要用到的 Security Parameters 加密参数。协商的过程中还必须要保证网络中传输的信息不能被篡改，伪造。由于协商需要在网络上来来回回花费几个来回，所以 TLS 的网络耗时基本上很大一部分花费在网络 RTT 上了。

和加密参数关系最大的是密码套件。客户端和服务端在协商过程中需要匹配双方的密码套件。然后双方握手成功以后，基于密码套件协商出所有的加密参数，加密参数中最重要的就是主密钥(master secret)。

握手协议主要负责协商一个会话，这个会话由以下元素组成:

- session identifier:    
  由服务端选取的一个任意字节的序列用于辨识一个活动的或可恢复的连接状态。

- peer certificate:    
  对端的 X509v3 [[PKIX]](https://tools.ietf.org/html/rfc5246#ref-PKIX)证书。这个字段可以为空。

- compression method:    
  加密之前的压缩算法。这个字段在 TLS 1.2 中用的不多。在 TLS 1.3 中这个字段被删除。

- cipher spec:    
  指定用于产生密钥数据的伪随机函数(PRF)，块加密算法(如：空，AES 等)，和 MAC 算法(如：HMAC-SHA1)。它也定义了密码学属性如 mac\_length。这个字段在 TLS 1.3 标准规范中已经删除，但是为了兼容老的 TLS 1.2 之前的协议，实际使用中还可能存在。在 TLS 1.3 中，密钥导出用的是 HKDF 算法。具体 PRF 和 HKDF 的区别会在之后的一篇文章中详细分析。

- master secret:    
  client 和 server 之间共享的 48 字节密钥。
  
- is resumable:    
   一个用于标识会话是否能被用于初始化新连接的标签。

上面这些字段随后会被用于产生安全参数并由记录层在保护应用数据时使用。利用TLS握手协议的恢复特性，使用相同的会话可以实例化许多连接。

TLS 握手协议包含如下几步:

- 交换 Hello 消息, 交换随机数和支持的密码套件列表, 以协商出密码套件和对应的算法。检查会话是否可恢复
- 交换必要的密码参数以允许 client 和 server 协商预备主密钥 premaster secret
- 交换证书和密码信息以允许 client 和 server 进行身份认证
- 从预备主密钥 premaster secret 和交换的随机数中生成主密钥 master secret
- 为 TLS 记录层提供安全参数(主要是密码块)
- 允许 client 和 server 验证它们的对端已经计算出了相同的安全参数, 而且握手过程不被攻击者篡改


下面行文思路会按照 TLS 首次握手，会话恢复的顺序，依次对比 TLS 1.2 和 TLS 1.3 在握手上的不同，并且结合 Wireshark 抓取实际的网络包进行分析讲解。最后分析一下 TLS 1.3 新出的 0-RTT 是怎么回事。


## 三、TLS 1.2 首次握手流程

TLS 1.2 握手协议主要流程如下：

Client 发送一个 ClientHello 消息, Server 必须回应一个 ServerHello 消息或产生一个验证的错误并且使连接失败。ClientHello 和 ServerHello 用于在 Client 和 Server 之间建立安全性增强的能力。ClientHello 和 ServerHello 建立了如下的属性: 协议版本, 会话 ID, 密码套件, 压缩算法。此外, 产生并交换两个随机数: ClientHello.random 和 ServerHello.random。

密钥交换中使用的最多4个消息: Server Certificate, ServerKeyExchange, Client Certificate 和 ClientKeyExchange。新的密钥交换方法可以通过这些方法产生:为这些消息指定一个格式, 并定义这些消息的用法以允许 Client 和 Server 就一个共享密钥达成一致。这个密钥必须很长；当前定义的密钥交换方法交换的密钥大于 46 字节。

在 hello 消息之后, Server 会在 Certificate 消息中发送它自己的证书，如果它即将被认证。此外，如果需要的话，一个 ServerKeyExchange 消息会被发送(例如, 如果 Server 没有证书, 或者它的证书只用于签名，RSA 密码套件就不会出现 ServerKeyExchange 消息)。如果 Server 被认证过了，如果对于已选择的密码套件来说是合适的话，它可能会要求 Client 发送证书。接下来，Server 会发送 ServerHelloDone 消息，至此意味着握手的 hello 消息阶段完成。Server 将会等待 Client 的响应。如果 Server 发送了一个 CertificateRequest 消息，Client 必须发送 Certificate 消息。现在 ClientKeyExchange 消息需要发送, 这个消息的内容取决于 ClientHello 和 ServerHello 之间选择的公钥算法。如果 Client 发送了一个带签名能力的证书, 则需要发送以一个数字签名的 CertificateVerify 消息，以显式验证证书中私钥的所有权。

这时，Client 发送一个 ChangeCipherSpec 消息，并且复制 pending 的 Cipher Spec 到当前的 Cipher Spec 中. 然后 Client 在新算法, 密钥确定后立即发送 Finished 消息。作为回应，Server 会发送它自己的 ChangeCipherSpec 消息, 将 pending 的 Cipher Spec 转换为当前的 Cipher Spec，在新的 Cipher Spec 下发送 Finished 消息。这时，握手完成，Client 和 Server 可以开始交换应用层数据。应用数据一定不能在第一个握手完成前(在一个非TLS\_NULL\_WITH\_NULL\_NULL 类型的密码套件建立之前)发送。

用经典的图表示一次完成的握手就是下图：

```c
      Client                                               Server

      ClientHello                  -------->
                                                      ServerHello
                                                     Certificate*
                                               ServerKeyExchange*
                                              CertificateRequest*
                                   <--------      ServerHelloDone
      Certificate*
      ClientKeyExchange
      CertificateVerify*
      [ChangeCipherSpec]
      Finished                     -------->
                                               [ChangeCipherSpec]
                                   <--------             Finished
      Application Data             <------->     Application Data
```

\* 号意味着可选择的或者并不会一直被发送的条件依赖形消息。

**为了防止 pipeline stalls，ChangeCipherSpec 是一种独立的 TLS 协议内容类型，并且事实上它不是一种 TLS 消息**。所以图上 "[]" 代表的是，ChangeCipherSpec 并不是 TLS 的消息的意思。

TLS 握手协议是 TLS 记录协议的一个已定义的高层客户端。这个协议用于协商一个会话的安全属性。握手消息封装传递给 TLS 记录层，这里它们会被封装在一个或多个 TLSPlaintext 结构中，这些结构按照当前活动会话状态所指定的方式被处理和传输。

```c
      enum {
          hello_request(0), 
          client_hello(1), 
          server_hello(2),
          certificate(11), 
          server_key_exchange (12),
          certificate_request(13), 
          server_hello_done(14),
          certificate_verify(15), 
          client_key_exchange(16),
          finished(20), 
          (255)
      } HandshakeType;

      struct {
          HandshakeType msg_type;    /* handshake type */
          uint24 length;             /* bytes in message */
          select (HandshakeType) {
              case hello_request:       HelloRequest;
              case client_hello:        ClientHello;
              case server_hello:        ServerHello;
              case certificate:         Certificate;
              case server_key_exchange: ServerKeyExchange;
              case certificate_request: CertificateRequest;
              case server_hello_done:   ServerHelloDone;
              case certificate_verify:  CertificateVerify;
              case client_key_exchange: ClientKeyExchange;
              case finished:            Finished;
          } body;
      } Handshake;
```

握手协议消息在下文中会以发送的顺序展现；没有按照期望的顺序发送握手消息会导致一个致命错误，握手失败。然而，不需要的握手消息会被忽略。需要注意的是例外的顺序是：证书消息在握手（从 Server 到 Client，然后从 Client到 Server）过程中会使用两次。不被这些顺序所约束的一个消息是 HelloRequest 消息，它可以在任何时间发送，但如果在握手中间收到这条消息，则应该被 Client 忽略。

### 1. Hello 子消息

Hello 阶段的消息用于在 Client 和 Server 之间交换安全增强能力。当一个新的会话开始时，记录层连接状态加密，hash，和压缩算法被初始化为空。当前连接状态被用于重协商消息。


### (1) Hello Request

HelloRequest 消息可以在任何时间由 Server 发送。

这个消息的含义: HelloRequest 是一个简单的通知，告诉 Client 应该开始重协商流程。在响应过程中，Client 应该在方便的时候发送一个 ClientHello 消息。这个消息并不是意图确定哪端是 Client 或 Server，而仅仅是发起一个新的协商。Server 不应该在 Client 发起连接后立即发送一个 HelloRequest。

如果 Client当前正在协商一个会话时，HelloRequest 这个消息会被 Client忽略。如果 Client 不想重新协商一个会话，或 Client 希望响应一个 no\_renegotiation alert 消息，那么也可能忽略 HelloRequest 消息。因为握手消息意图先于应用数据被传送，它希望协商会在少量记录消息被 Client 接收之前开始。如果 Server 发送了一个 HelloRequest 但没有收到一个 ClientHello 响应，它应该用一个致命错误 alert 消息关闭连接。在发送一个 HelloRequest 之后，Server 不应该重复这个请求直到随后的握手协商完成。

HelloRequest 消息的结构:

```c
              struct { } HelloRequest;
```

这个消息不能被包含在握手消息中维护的消息 hash 中, 也不能用于结束的消息和证书验证消息。

### (2) Client Hello

当一个 Client 第一次连接一个 Server 时，发送的第一条消息必须是 ClientHello。Client 也能发送一个 ClientHello 作为对 HelloRequest 的响应，或用于自身的初始化以便在一个已有连接中重新协商安全参数。

```c
         struct {
             uint32 gmt_unix_time;
             opaque random_bytes[28];
         } Random;
         
      struct {
          ProtocolVersion client_version;
          Random random;
          SessionID session_id;
          CipherSuite cipher_suites<2..2^16-2>;
          CompressionMethod compression_methods<1..2^8-1>;
          select (extensions_present) {
              case false:
                  struct {};
              case true:
                  Extension extensions<0..2^16-1>;
          };
      } ClientHello;         
```

- gmt\_unix\_time  
  依据发送者内部时钟以标准 UNIX 32 位格式表示的当前时间和日期(从1970年1月1日UTC午夜开始的秒数, 忽略闰秒)。基本 TLS 协议不要求时钟被正确设置；更高层或应用层协议可以定义额外的需求. 需要注意的是，出于历史原因，该字段使用格林尼治时间命名，而不是 UTC 时间。

- random\_bytes  
  由一个安全的随机数生成器产生的 28 个字节数据。

- client\_version  
  Client 愿意在本次会话中使用的 TLS 协议的版本. 这个应当是 Client 所能支持的最新版本(值最大)，TLS 1.2 是 3.3，TLS 1.3 是 3.4。

- random  
  一个 Client 所产生的随机数结构 Random。随机数的结构体 Random 在上面展示出来了。**客户端的随机数，这个值非常有用，生成预备主密钥的时候，在使用 PRF 算法计算导出主密钥和密钥块的时候，校验完整的消息都会用到，随机数主要是避免重放攻击**。

- session\_id  
  Client 希望在本次连接中所使用的会话 ID。如果没有 session\_id 或 Client 想生成新的安全参数，则这个字段为空。**这个字段主要用在会话恢复中**。

- cipher\_suites  
  Client 所支持的密码套件列表，Client最倾向使用的排在最在最前面。如果 session\_id 字段不空(意味着是一个会话恢复请求)，这个向量必须至少包含那条会话中的 cipher\_suite。cipher\_suites 字段可以取的值如下：

```c
      CipherSuite TLS_NULL_WITH_NULL_NULL               = { 0x00,0x00 };
      CipherSuite TLS_RSA_WITH_NULL_MD5                 = { 0x00,0x01 };
      CipherSuite TLS_RSA_WITH_NULL_SHA                 = { 0x00,0x02 };
      CipherSuite TLS_RSA_WITH_NULL_SHA256              = { 0x00,0x3B };
      CipherSuite TLS_RSA_WITH_RC4_128_MD5              = { 0x00,0x04 };
      CipherSuite TLS_RSA_WITH_RC4_128_SHA              = { 0x00,0x05 };
      CipherSuite TLS_RSA_WITH_3DES_EDE_CBC_SHA         = { 0x00,0x0A };
      CipherSuite TLS_RSA_WITH_AES_128_CBC_SHA          = { 0x00,0x2F };
      CipherSuite TLS_RSA_WITH_AES_256_CBC_SHA          = { 0x00,0x35 };
      CipherSuite TLS_RSA_WITH_AES_128_CBC_SHA256       = { 0x00,0x3C };
      CipherSuite TLS_RSA_WITH_AES_256_CBC_SHA256       = { 0x00,0x3D };
      CipherSuite TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA      = { 0x00,0x0D };
      CipherSuite TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA      = { 0x00,0x10 };
      CipherSuite TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA     = { 0x00,0x13 };
      CipherSuite TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA     = { 0x00,0x16 };
      CipherSuite TLS_DH_DSS_WITH_AES_128_CBC_SHA       = { 0x00,0x30 };
      CipherSuite TLS_DH_RSA_WITH_AES_128_CBC_SHA       = { 0x00,0x31 };
      CipherSuite TLS_DHE_DSS_WITH_AES_128_CBC_SHA      = { 0x00,0x32 };
      CipherSuite TLS_DHE_RSA_WITH_AES_128_CBC_SHA      = { 0x00,0x33 };
      CipherSuite TLS_DH_DSS_WITH_AES_256_CBC_SHA       = { 0x00,0x36 };
      CipherSuite TLS_DH_RSA_WITH_AES_256_CBC_SHA       = { 0x00,0x37 };
      CipherSuite TLS_DHE_DSS_WITH_AES_256_CBC_SHA      = { 0x00,0x38 };
      CipherSuite TLS_DHE_RSA_WITH_AES_256_CBC_SHA      = { 0x00,0x39 };
      CipherSuite TLS_DH_DSS_WITH_AES_128_CBC_SHA256    = { 0x00,0x3E };
      CipherSuite TLS_DH_RSA_WITH_AES_128_CBC_SHA256    = { 0x00,0x3F };
      CipherSuite TLS_DHE_DSS_WITH_AES_128_CBC_SHA256   = { 0x00,0x40 };
      CipherSuite TLS_DHE_RSA_WITH_AES_128_CBC_SHA256   = { 0x00,0x67 };
      CipherSuite TLS_DH_DSS_WITH_AES_256_CBC_SHA256    = { 0x00,0x68 };
      CipherSuite TLS_DH_RSA_WITH_AES_256_CBC_SHA256    = { 0x00,0x69 };
      CipherSuite TLS_DHE_DSS_WITH_AES_256_CBC_SHA256   = { 0x00,0x6A };
      CipherSuite TLS_DHE_RSA_WITH_AES_256_CBC_SHA256   = { 0x00,0x6B };
```  

- compression\_methods  
  这是 Client 所支持的压缩算法的列表，按照 Client所倾向的顺序排列。如果 session\_id 字段不空(意味着是一个会话恢复请求)，它必须包含那条会话中的 compression\_method。这个向量中必须包含, 所有的实现也必须支持 CompressionMethod.null。因此，一个 Client 和 Server 将能就压缩算法协商打成一致。

- extensions  
  Clients 可以通过在扩展域中发送数据来请求 Server 的扩展功能。**和证书中的扩展一样，TLS/SSL 协议中也支持扩展，可以在不用修改协议的基础上提供更多的可扩展性**。

如果一个 Client 使用扩展来请求额外的功能, 并且这个功能 Server 并不支持, 则 Client可以中止握手。一个 Server 必须接受带有或不带扩展域的 ClientHello 消息，并且(对于其它所有消息也是一样)它必须检查消息中数据的数量是否精确匹配一种格式；如果不是，它必须发送一个致命"decode\_error" alert 消息。

发送 ClientHello 消息之后，Client 会等待 ServerHello 消息。Server 返回的任何握手消息，除 HelloRequest 外, 均被作为一个致命的错误。

TLS 允许在 compression\_methods 字段之后的 extensions 块中添加扩展。通过查看在 ClientHello 结尾处，compression\_methods 后面是否有多余的字节就能检测到扩展是否存在。需要注意的是这种检测可选数据的方法与正常的 TLS 变长域不一样，但它可以用于与扩展还没有定义之前的 TLS 相互兼容。


ClientHello 消息包含一个变长的 Session ID 会话标识符。如果非空，这个值标识了同一对 Client 和 Server 之间的会话，Client 希望重新使用这个会话中 Server 的安全参数。

Session ID 会话标识符可能来自于一个早期的连接，本次连接，或来自另一个当前活动的连接。第二个选择是有用的，如果 Client 只是希望更新随机数据结构并且从一个连接中导出数值；第三个选择使得在无需重复全部握手协议的情况下就能够建立若干独立的安全连接。这些独立的连接可能先后顺序建立或同时建立。一个 Session ID 在双方交换 Finished 消息，握手协商完成是开始有效，并持续到由于过期或在一个与会话相关联的连接上遭遇致命错误导致它被删除为止。Session ID 的实际内容由 Server 定义。

```c
       opaque SessionID<0..32>;
```

由于 Session ID 在传输时没有加密或直接的 MAC 保护，Server 一定不能将机密信息放在 Session ID 会话标识符中或使用伪造的会话标识符的内容，都是违背安全原则。(需要注意的是握手的内容作为一个整体, 包括 SessionID, 是由在握手结束时交换的 Finished 消息再进行保护的)。

密码族列表, 在 ClientHello 消息中从 Client 传递到 Server，以 Client 所倾向的顺序(最推荐的在最先)包含了 Client 所支持的密码算法。每个密码族定义了一个密钥交互算法，一个块加密算法(包括密钥长度)，一个 MAC 算法，和一个随机数生成函数 PRF。Server 将选择一个密码套件，如果没有可以接受的选择，在返回一个握手失败 alert 消息然后关闭连接。如果列表包含了 Server 不能识别，支持或希望使用的密码套件，Server 必须忽略它们，并正常处理其余的部分。

```c
      uint8 CipherSuite[2];    /* Cryptographic suite selector */
```

ClientHello 保护了 Client 所支持的压缩算法列表，按照 Client 的倾向进行排序。


### (3) Server Hello


当 Server 能够找到一个可接受的算法集时，Server 发送这个消息作为对 ClientHello 消息的响应。如果不能找到这样的算法集, 它会发送一个握手失败 alert 消息作为响应。

Server Hello 消息的结构是:

```c
      struct {
          ProtocolVersion server_version;
          Random random;
          SessionID session_id;
          CipherSuite cipher_suite;
          CompressionMethod compression_method;
          select (extensions_present) {
              case false:
                  struct {};
              case true:
                  Extension extensions<0..2^16-1>;
          };
      } ServerHello;
```

通过查看 compression\_methods 后面是否有多余的字节在 ServerHello 结尾处就能探测到扩展是否存在。

- server\_version  
  这个字段将包含 Client 在 Client hello 消息中建议的较低版本和 Server 所能支持的最高版本。TLS 1.2 版本是 3.3，TLS 1.3 是 3.4 。


- random    
  这个结构由 Server 产生并且必须独立于 ClientHello.random 。**这个随机数值和 Client 的随机数一样，这个值非常有用，生成预备主密钥的时候，在使用 PRF 算法计算导出主密钥和密钥块的时候，校验完整的消息都会用到，随机数主要是避免重放攻击**。

- session\_id    
  这是与本次连接相对应的会话的标识。如果 ClientHello.session\_id 非空，Server 将在它的会话缓存中进行匹配查询。如果匹配项被找到，且 Server 愿意使用指定的会话状态建立新的连接，Server 会将与 Client 所提供的相同的值返回回去。这意味着恢复了一个会话并且规定双方必须在 Finished 消息之后继续进行通信。否则这个字段会包含一个不同的值以标识新会话。Server 会返回一个空的 session\_id 以标识会话将不再被缓存从而不会被恢复。如果一个会话被恢复了，它必须使用原来所协商的密码套件。需要注意的是没有要求 Server 有义务恢复任何会话，即使它之前提供了一个 session\_id。Client 必须准备好在任意一次握手中进行一次完整的协商，包括协商新的密码套件。
  
- cipher\_suite  
  由 Server 在 ClientHello.cipher\_suites 中所选择的单个密码套件。对于被恢复的会话, 这个字段的值来自于被恢复的会话状态。**从安全性考虑，应该以服务器配置为准**。

- compression\_method  
  由 Server 在 ClientHello.compression\_methods 所选择的单个压缩算法。对于被恢复的会话，这个字段的值来自于被恢复的会话状态。

- extensions  
  扩展的列表. 需要注意的是只有由 Client 给出的扩展才能出现在 Server 的列表中。


### 2. Server Certificate

无论何时经过协商一致以后的密钥交换算法需要使用证书进行认证的，Server 就必须发送一个 Certificate。**Server Certificate 消息紧跟着 ServerHello 之后，通常他们俩者在同一个网络包中，即同一个 TLS 记录层消息中**。

如果协商出的密码套件是 DH\_anon 或者 ECDH\_annon，则 Server 不应该发送该消息，因为可能会遇到中间人攻击。其他的情况，只要不是需要证书进行认证的，Server 都可以选择不发送此条子消息。

这个消息的作用是：  

这个消息把 Server 的证书链传给 Client。

证书必须适用于已协商的密码套件的密钥交互算法和任何已协商的扩展。

这个消息的结构是：  

```c
      opaque ASN.1Cert<1..2^24-1>;

      struct {
          ASN.1Cert certificate_list<0..2^24-1>;
      } Certificate;
```

- certificate\_list:  
  这是一个证书序列(链)。**每张证书都必须是 ASN.1Cert 结构**。发送者的证书必须在列表的第一个位置。每个随后的证书必须直接证明它前面的证书。假设远端必须已经拥有它以便在任何情况下验证它，在这个假设下，因为证书验证要求根密钥是独立分发的，所以可以从链中省略指定根证书颁发机构的自签名证书。**根证书集成到了 Client 的根证书列表中，没有必要包含在 Server 证书消息中**。

相同的消息类型和结果将用于 Client 端对一个证书请求消息的响应。需要注意的是一个 Client 可能不发送证书, 如果它没有合适的证书来发送以响应 Server 的认证请求。


如下的规则会被应用于 Server 发送的证书:

-  证书类型必须是 X.509v3, 除非显式协商了其它的类型(如 [[TLSPGP]](https://tools.ietf.org/html/rfc5246#ref-TLSPGP))。
-  终端实体证书的公钥(和相关的限制)必须与选择的密钥交互算法兼容。
-  "server\_name"和"trusted\_ca\_keys"扩展 [[TLSEXT]](https://tools.ietf.org/html/rfc5246#ref-TLSEXT) 被用于指导证书选择。

|密钥交换算法|证书类型|
|:------:|:-------:|
|RSA <br> RSA\_PSK |   证书中包含 RSA 公钥，该公钥可以进行密码协商，也就是使用 RSA 密码协商算法；证书必须允许密钥用于加密(如果 key usage 扩展存在的话，则 keyEncipherment 位必须被设置，表示允许服务器公钥用于密码协商) <br>注:RSA\_PSK 定义于 [[TLSPSK]](https://tools.ietf.org/html/rfc5246#ref-TLSPSK)|
|DHE\_RSA<br>ECDHE\_RSA   | 证书中包含 RSA 公钥，可以使用 ECDHE 或者 DHE 进行密钥协商；证书必须允许密钥使用 Server 密钥交互消息中的签名机制和 hash 算法进行签名 (如果 key usage 扩展存在的话，digitalSignature 位必须设置，RSA 公钥就可以进行数字签名)<br>注: ECDHE\_RSA定义于 [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC)|
|DHE\_DSS    |  证书包含 DSA 公钥; 证书必须允许密钥用于使用将在 Server 密钥交换消息中使用的散列算法进行签名|
|DH\_DSS<br> DH\_RSA   | 证书中包含 DSS 或 RSA 公钥，使用 Diffie-Hellman 进行密钥协商; 如果 key usage 扩展存在的话，keyAgreement 位必须设置，**目前这种套件已经很少见了**。|
|ECDH\_ECDSA <br>ECDH\_RSA |    证书包含 ECDSA 或 RSA 公钥，使用 ECDH-capable 进行密钥协商。由于是静态密钥协商算法，ECDH 的参数和公钥包含在证书中; 公钥必须使用一个能够被 Client 支持的曲线和点格式, 正如 [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC) 中描述的那样。**目前这种套件已经很少见了，因为 ECDH 不支持前向安全性**|
|ECDHE\_ECDSA  | 证书包含 ECDSA-capable 公钥，使用 ECDHE 算法协商预备主密钥; 证书必须允许密钥用于使用将在 Server 密钥交换消息中使用的散列算法进行签名;公钥必须使用一个能够被 Client 支持的曲线和点格式，Client 通过 Client Hello 消息中的 ec\_point\_formats 扩展指定支持的命名曲线，正如 [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC) 中描述的那样。**这是 TLS 1.2 中最安全，性能最高的密码套件**。|


如果 Client 提供了一个 "signature\_algorithms" 扩展，则 Server 提供的所有证书必须由出现在这个扩展中的一个 hash/签名算法对进行签名。需要注意的是这意味着一个包含了一个签名算法密钥的证书应该被一个不同的签名算法签名(例如，RSA 密钥被 DSA 密钥签名)。这个与 TLS 1.1 不同，TLS 1.1 中要求算法是相同的。**更进一步也说明了 DH\_DSS，DH\_RSA，ECDH\_ECDSA，和 ECDH\_RSA 套件的后半部分对应的公钥不会用来加密或者数字签名，没有存在的必要性，并且后半部分也不限制 CA 机构签发证书所选用的数字签名算法**。固定的 DH 证书可以被出现在扩展中的任意 hash/签名算法对签名。DH\_DSS，DH\_RSA，ECDH\_ECDSA，和 ECDH\_RSA 是历史上的名称。



如果 Server 有多个证书, 它基于上述标准(此外其它的标准有:传输层端点，本地配置和偏好等)选择其中一个。如果 Server 只有一个证书，它应该尝试使这个证书符合这些标准。

需要注意的是有很多证书使用无法与 TLS 兼容的算法或算法组合。例如，一个使用 RSASSA-PSS 签名密钥的证书(在 SubjectPublicKeyInfo 中是 id-RSASSA-PSS OID)不能被使用因为 TLS 没有定义相应的签名算法。

正如密钥套件指定了用于 TLS 协议的新的密钥交换方法，它们也同样指定了证书格式和要求的编码的按键信息。

至此已经涉及到了 Client 签名算法、证书签名算法、密码套件、Server 公钥，这 4 者相互有关联，也有没有关系的。

- Client 签名算法需要和证书签名算法相互匹配，如果 Client Hello 中的 signature\_algorithms 扩展与证书链中的证书签名算法不匹配的话，结果是握手失败。

- Server 公钥与证书签名算法无任何关系。证书中包含 Server 证书，证书签名算法对 Server 公钥进行签名，但是 Server 公钥的加密算法可以是 RSA 也可以是 ECDSA。

- 密码套件和 Server 公钥存在相互匹配的关系，因为密码套件中的身份验证算法指的就是 Server 公钥类型。

例如 TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 这个密码套件：

密钥协商算法是 ECDHE，身份验证算法是 ECDSA，加密模式是 AES\_256\_GCM，由于 GCM 是属于 AEAD 加密模式，所以整个密码套件无须另外的 HMAC，SHA384 指的是 PRF 算法。

**这里的身份验证并不是指的证书由哪种数字签名算法签名的，而是指的证书中包含的 Server 公钥是什么类型的公钥**。

所以 Client Hello 中的 signature\_algorithms 扩展需要和证书链中的签名算法匹配，如果不匹配，就无法验证证书中的 Server 公钥，也需要和双方协商出来的密码套件匹配，如果不匹配，就无法使用 Server 公钥。



### 3. Server Key Exchange Message

这个消息会紧随在 Server 证书消息之后发送(如果是一个匿名协商的话，会紧随在 Server Hello消息之后发送)；

ServerKeyExchange 消息由 Server 发送，但仅在 Server 证书消息(如果发送了)没有包含足够的数据以允许 Client 交换一个预密钥时。这个限制对于如下的密钥交换算法是成立的:

```c
         DHE_DSS
         DHE_RSA
         ECDHE_ECDSA
         ECDHE_RSA
         DH_anon
         ECDH_anon
```

对于上面前 4 个密码套件，由于使用的临时的 DH/ECDH 密钥协商算法，证书中是不包含这些动态的 DH 信息(DH 参数和 DH 公钥)，所以需要使用 Server Key Exchange 消息传递这些信息。传递的动态 DH 信息需要使用 Server 私钥进行签名加密。

对于上面后 2 个密码套件，是匿名协商，使用的静态的 DH/ECDH 密钥协商算法，而且它们也没有证书消息(Server Certificate 消息)，所以同样需要使用 Server Key Exchange 消息传递这些信息。传递的静态 DH 信息需要使用 Server 私钥进行签名加密。

对于如下密钥交换算法发送 ServerKeyExchange 是非法的:

```c
         RSA
         DH_DSS
         DH_RSA
```

对于 RSA 加密套件，Client 不需要额外参数就可以计算出预备主密钥，然后使用 Server 的公钥加密发送给 Server 端，所以不需要 Server Key Exchange 可以完成协商。

对于 DH\_DSS 和 DH\_RSA，在证书中就会包含静态的 DH 信息，也不需要发送 Server Key Exchange，Client 和 Server 双方可以各自协商出预备主密钥的一半密钥，合起来就是预备主密钥了。这两种密码套件目前很少用，一般 CA 不会在证书中包含静态的 DH 信息，也不太安全。

其它的密钥交换算法，如在 [[TLSECC]](https://tools.ietf.org/html/rfc5246#ref-TLSECC) 中所定义的那些，必须指定是否发送 ServerKeyExchange；如果消息发送了，则必须指定发送内容。


ServerKeyExchange 这个消息的目的就是传递了必要的密码信息，使得 Client 可以完成预备主密钥的通信：获得一个 Client 可用于完成一个密钥交换的 Diffie-Hellman 公钥(结果就是生成预备主密钥)或一个其它算法的公钥。



DH 参数的结构是:
    
```c
      enum { dhe_dss, dhe_rsa, dh_anon, rsa, dh_dss, dh_rsa,ec_diffie_hellman
            /* 可以被扩展, 例如, 对于 ECDH -- 见 [TLSECC] */
           } KeyExchangeAlgorithm;

      struct {
          opaque dh_p<1..2^16-1>;
          opaque dh_g<1..2^16-1>;
          opaque dh_Ys<1..2^16-1>;
      } ServerDHParams;     /* 动态的 DH 参数 */
```

- dh\_p
  用于 Diffie-Hellman 操作的素模数，即大质数。

- dh\_g
  用于 Diffie-Hellman 操作的生成器

- dh\_Ys
  Server 的 Diffie-Hellman 公钥 (g^X mod p)

Server 需要传递额外参数的密码套件主要 6 种，之前提到过，DHE\_DSS、DHE\_RSA、ECDHE\_ECDSA、ECDHE\_RSA、DH\_anon、ECDH\_anon，其他的密码套件不可用于 ServerKeyExchange 这个消息中。**一般 HTTPS 都会部署这 4 种密码套件：ECDHE\_RSA、DHE\_RSA、ECDHE\_ECDSA、RSA**。

>关于 TLS 中 ECC 相关描述在 [RFC4492](https://tools.ietf.org/html/rfc4492) 这篇文档中 

|密钥交换算法 |  描述  |
|:------|:-----|
|ECDH\_ECDSA | 静态的 ECDH + ECDSA 签名证书|
|ECDHE\_ECDSA  |   动态的 ECDH + ECDSA 签名证书|
|ECDH\_RSA     |   静态的 ECDH + RSA 签名证书|
|ECDHE\_RSA    |   动态的 ECDH + RSA 签名证书 |
|ECDH\_anon    |   匿名的 ECDH + 无签名证书 |


ECDHE 参数的结构是:

```c
        struct {
            ECParameters    curve_params;
            ECPoint         public;
        } ServerECDHParams;
```

ECC public 公钥的数据结构如下：

```c
        struct {
            opaque point <1..2^8-1>;
        } ECPoint;
```

ECC 椭圆曲线的类型:

```c
        enum { 
            explicit_prime (1), 
            explicit_char2 (2),
            named_curve (3), 
            reserved(248..255) 
        } ECCurveType;
         
        struct {
            opaque a <1..2^8-1>;
            opaque b <1..2^8-1>;
        } ECCurve;  
        
        enum { ec_basis_trinomial, ec_basis_pentanomial } ECBasisType;     
```

支持的所有命名曲线:

```c
        enum {
            sect163k1 (1), sect163r1 (2), sect163r2 (3),
            sect193r1 (4), sect193r2 (5), sect233k1 (6),
            sect233r1 (7), sect239k1 (8), sect283k1 (9),
            sect283r1 (10), sect409k1 (11), sect409r1 (12),
            sect571k1 (13), sect571r1 (14), secp160k1 (15),
            secp160r1 (16), secp160r2 (17), secp192k1 (18),
            secp192r1 (19), secp224k1 (20), secp224r1 (21),
            secp256k1 (22), secp256r1 (23), secp384r1 (24),
            secp521r1 (25),
            reserved (0xFE00..0xFEFF),
            arbitrary_explicit_prime_curves(0xFF01),
            arbitrary_explicit_char2_curves(0xFF02),
            (0xFFFF)
        } NamedCurve;
```

ECDH 参数的数据结构：

```c
        struct {
            ECCurveType    curve_type;
            select (curve_type) {
                case explicit_prime:
                    opaque      prime_p <1..2^8-1>;
                    ECCurve     curve;
                    ECPoint     base;
                    opaque      order <1..2^8-1>;
                    opaque      cofactor <1..2^8-1>;
                case explicit_char2:
                    uint16      m;
                    ECBasisType basis;
                    select (basis) {
                        case ec_trinomial:
                            opaque  k <1..2^8-1>;
                        case ec_pentanomial:
                            opaque  k1 <1..2^8-1>;
                            opaque  k2 <1..2^8-1>;
                            opaque  k3 <1..2^8-1>;
                    };
                    ECCurve     curve;
                    ECPoint     base;
                    opaque      order <1..2^8-1>;
                    opaque      cofactor <1..2^8-1>;
                case named_curve:
                    NamedCurve namedcurve;
            };
        } ECParameters;
```

ECCurveType 表示 ECC 类型每个人可以自行指定椭圆曲线的公式，基点等参数，但是在 TLS/SSL 协议中一般都是使用已经命名好的命名曲线 NamedCurve，这样也更加安全。

ServerECDHParams 中包含了 ECParameters 参数和 ECPoint 公钥。

最后来看看 ServerKeyExchange 消息的数据结构：

```c
      struct {
          select (KeyExchangeAlgorithm) {
              case dh_anon:
                  ServerDHParams params;
              case dhe_dss:
              case dhe_rsa:
                  ServerDHParams params;
                  digitally-signed struct {
                      opaque client_random[32];
                      opaque server_random[32];
                      ServerDHParams params;
                  } signed_params;
              case rsa:
              case dh_dss:
              case dh_rsa:
                  struct {} ;
                 /* 消息忽略 rsa, dh_dss, 和dh_rsa */
              case ec_diffie_hellman:
                  ServerECDHParams    params;
                  Signature           signed_params;
          };
      } ServerKeyExchange;
```

- params
  Server 密钥协商需要的参数

- signed\_params
  对于非匿名密钥交换, 这是一个对 Server 密钥协商参数的签名

ServerKeyExchange 根据 KeyExchangeAlgorithm 类型的不同，加入了不同的参数。对于匿名协商，不需要证书，所以也不需要身份验证，没有证书。DHE 开头的协商算法，Server 需要发给 Client 动态的 DH 参数 ServerDHParams 和 数字签名。这里的数字签名会包含 Client 端传过来的随机数，Server 端生成的随机数和 ServerDHParams。

RSA、DH\_DSS、DH\_RSA 这 3 个不需要 ServerKeyExchange 消息。

如果是动态的 ECDH 协商算法，Server 需要把 ServerECDHParams 参数和签名发给 Client。签名的数据结构如下：

```c
          enum { ecdsa } SignatureAlgorithm;

          select (SignatureAlgorithm) {
              case ecdsa:
                  digitally-signed struct {
                      opaque sha_hash[sha_size];
                  };
          } Signature;
          
        ServerKeyExchange.signed_params.sha_hash
            SHA(ClientHello.random + ServerHello.random +
                                              ServerKeyExchange.params);
```

这里的签名里面包含的是 Client 随机数、Server 随机数 和 ServerKeyExchange.params 三者求 SHA。


如果 Client已经提供了 "signature\_algorithms" 扩展，签名算法和 hash 算法必须成对出现在扩展中。需要注意的是这里可能会有不一致的可能，例如，Client 可能提供 DHE\_DSS 密钥交换算法，但却在 "signature\_algorithms" 扩展中忽略任何与 DSA 配对的组合。为了达成正确的密码协商，Server 必须在选择密码套件之前检查与 "signature\_algorithms" 扩展可能冲突的密码套件。这并不算是一个优雅的方案，只能算是一个折中的方案，对原来密码套件的设计改动最小。

此外，hash 和签名算法必须与位于 Server 的终端实体证书中的密钥相兼容。RSA 密钥可以与任何允许的 hash 算法配合使用, 并满足任何证书的约束(如果有的话)。


### 4. Certificate Request

一个非匿名的 Server 可以选择性地请求一个 Client 发送的证书，如果相互选定的密码套件合适的话。如果 ServerKeyExchange 消息发送了的话，就紧跟在 ServerKeyExchange 消息的后面。如果 ServerKeyExchange 消息没有发送的话，就跟在 Server Certificate 消息后面。

这个消息的结构是:

```c
        enum {
          rsa_sign(1), 
          dss_sign(2), 
          rsa_fixed_dh(3), 
          dss_fixed_dh(4),
          rsa_ephemeral_dh_RESERVED(5), 
          dss_ephemeral_dh_RESERVED(6),
          fortezza_dms_RESERVED(20), 
          ecdsa_sign(64), 
          rsa_fixed_ecdh(65),
          ecdsa_fixed_ecdh(66),
          (255)
      } ClientCertificateType;
      
      opaque DistinguishedName<1..2^16-1>;

      struct {
          ClientCertificateType certificate_types<1..2^8-1>;
          SignatureAndHashAlgorithm
            supported_signature_algorithms<2^16-1>;
          DistinguishedName certificate_authorities<0..2^16-1>;
      } CertificateRequest;
```

- certificate\_types
  client 可以提供的证书类型的列表.
  rsa\_sign:一个包含 RSA 密钥的证书
  dss\_sign:一个包含 DSA 密钥的证书
  rsa\_fixed\_dh:一个包含静态 DH 密钥的证书
  dss\_fixed\_dh:一个包含静态 DH 密钥的证书

- supported\_signature\_algorithms
  一个 hash/签名算法对列表供 Server选择，按照偏好降序排列

- certificate\_authorities
  可接受的 certificate\_authorities [[X501]](https://tools.ietf.org/html/rfc5246#ref-X501) 的名称列表，以 DER 编码的格式体现。这些名称可以为一个根 CA 或一个次级 CA 指定一个期望的名称；因此，这个消息可以被用于描已知的根和期望的认证空间。如果 certificate\_authorities 列表为空，则 Client 可以发送 ClientCertificateType 中的任意证书，除非存在有一些属于相反情况的外部设定。

certificate\_types 和 supported\_signature\_algorithms 域的交互关系某种程度上有些复杂，certificate\_type 自从 SSLv3 开始就在 TLS 中存在，但某种程度上并不规范。它的很多功能被 supported\_signature\_algorithms 所取代。应遵循下述 3 条规则:

- Client 提供的任何证书必须使用在 supported\_signature\_algorithms 中存在的 hash/签名算法对来签名

- Clinet 提供的终端实体的证书必须包含一个与 certificate\_types 兼容的密钥。如果这个密钥是一个签名密钥，它必须能与 supported\_signature\_algorithms 中的一些 hash/签名算法对一起使用

- 出于历史原因，一些 Client 证书类型的名称包含了签名证书的算法。例如，在早期版本的 TLS 中，rsa\_fixed\_dh 意味着一个用 RSA 签名并且还包含一个静态 DH 密钥的证书。在 TLS 1.2 中，这个功能被 supported\_signature\_algorithms 废除，证书类型不再限制签名证书的算法。例如，如果 Server 发送了 dss\_fixed\_dh 证书类型和 {{sha1, dsa}, {sha1, rsa}} 签名类型，Client 可以回复一个包含一个静态 DH 密钥的证书，用 RSA-SHA1 签名。

>注: 一个匿名 Server 请求认证 Client 会产生一个致命的 handshake\_failure 警告错误。




### 5. Server Hello Done

ServerHelloDone 消息已经被 Server 发送以表明 ServerHello 及其相关消息的结束。发送这个消息之后, Server 将会等待 Client 发过来的响应。

这个消息意味着 Server 发送完了所有支持密钥交换的消息，Client 能继续它的密钥协商，证书校验等步骤。

在收到 ServerHelloDone 消息之后，Client 应当验证 Server 提供的是否是有效的证书，如果有要求的话, 还需要进一步检查 Server hello 参数是否可以接受。

这个消息的结构:

```c
        struct { } ServerHelloDone;
```    
  


### 6. Client Certificate



### 7. Client Key Exchange Message

```c
        enum { implicit, explicit } PublicValueEncoding;
        
        struct {
            select (PublicValueEncoding) {
                case implicit: struct { };
                case explicit: ECPoint ecdh_Yc;
            } ecdh_public;
        } ClientECDiffieHellmanPublic;
        
        struct {
            select (KeyExchangeAlgorithm) {
                case ec_diffie_hellman: ClientECDiffieHellmanPublic;
            } exchange_keys;
        } ClientKeyExchange;                
```

### 8. Certificate Verify



### 9. Finished



![](https://img.halfrost.com/Blog/ArticleImage/97_2.png)


![](https://img.halfrost.com/Blog/ArticleImage/97_3.png)


![](https://img.halfrost.com/Blog/ArticleImage/97_6.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_8.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_10.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_11.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_12.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_13.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_14.png)



## 四、TLS 1.2 第二次握手流程

为何会出现再次握手呢？这个就牵扯到了会话复用机制。


当 Client 和 Server 决定继续一个以前的会话或复制一个现存的会话(取代协商新的安全参数)时，消息流如下:

Client 使用需要恢复的当前会话的 ID 发送一个 ClientHello。Server 检查它的会话缓存以进行匹配。如果匹配成功，并且 Server 愿意在指定的会话状态下重建连接，它将会发送一个带有相同会话 ID 值的 ServerHello 消息。这时，Client 和 Server 必须都发送 ChangeCipherSpec 消息并且直接发送 Finished 消息。一旦重建立完成，Client 和 Server 可以开始交换应用层数据(见下面的流程图)。如果一个会话 ID 不匹配，Server 会产生一个新的会话 ID，然后 TLS Client 和 Server 需要进行一次完整的握手。
        
```c
      Client                                                Server

      ClientHello                   -------->
                                                       ServerHello
                                                [ChangeCipherSpec]
                                    <--------             Finished
      [ChangeCipherSpec]
      Finished                      -------->
      Application Data              <------->     Application Data
      
```


在 TLS 1.2 中，会话复用机制，一种是 session id 复用，一种是 session ticket 复用。session id 复用存在于服务端，session ticket 复用存在于客户端。

![](https://img.halfrost.com/Blog/ArticleImage/97_4.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_5.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_23.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_24.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_25.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_26.png)

## 五、TLS 1.3 首次握手流程


![](https://img.halfrost.com/Blog/ArticleImage/97_15.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_16.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_17.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_18.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_19.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_20.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_21.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_22.png)



## 六、TLS 1.3 第二次握手流程

这里网上很多文章对 TLS 1.3 第二次握手有误解。经过自己实践以后发现了“真理”。

TLS 1.3 在宣传的时候就以 0-RTT 为主，大家都会认为 TLS 1.3 再第二次握手的时候都是 0-RTT 的，包括网上一些分析的文章里面提到的最新的 PSK 密钥协商，PSK 密钥协商并非是 0-RTT 的。

TLS 1.3 再次握手其实是分两种：会话恢复模式、0-RTT 模式

### 1. 会话恢复模式

![](https://img.halfrost.com/Blog/ArticleImage/97_27.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_28.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_29.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_30.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_31.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_32.png)

### 2. 0-RTT 模式

先来看看 0-RTT 在整个草案里面的变更历史。

|    草案    | 变更 |
| ---------- | --- |
| draft-07   |  0-RTT 最早是在 draft-07 中加入了基础的支持 |
| draft-11   |  1. 在 draft-11 中删除了early\_handshake内容类型<br>2. 使用一个 alert 终止 0-RTT 数据 |
| draft-13   |  1. 删除 0-RTT 客户端身份验证<br>2. 删除 (EC)DHE 0-RTT<br>3. 充实 0-RTT PSK 模式并 shrink EarlyDataIndication |
| draft-14   |  1. 移除了 0-RTT EncryptedExtensions<br>2. 降低使用 0-RTT 的门槛<br>3. 阐明 0-RTT 向后兼容性<br>4. 说明 0-RTT 和 PSK 密钥协商的相互关系 |
| draft-15   |  讨论 0-RTT 时间窗口 |
| draft-16   |  1. 禁止使用 0-RTT 和 PSK 的 CertificateRequest<br>2. 放宽要求检查 SNI 的 0-RTT |
| draft-17   |  1. 删除 0-RTT Finished 和 resumption\_context，并替换为 PSK 本身的 psk\_binder 字段<br>2. 协调密码套件匹配的要求：会话恢复只需要匹配 KDF 但是对于 0-RTT 需要匹配整个密码套件。允许 PSK 实际去协商密码套件<br>3. 阐明允许使用 PSK 进行 0-RTT 的条件 |
| draft-21   |  关于 0-RTT 和重放的讨论，建议实现一些反重放机制 |

目前最新草案是 draft-28，从历史来看，人们从功能问题讨论到性能问题，最后讨论到安全问题。


------------------------------------------------------

Reference：
   
《深入浅出 HTTPS》      
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)  
[Keyless SSL: The Nitty Gritty Technical Details](https://blog.cloudflare.com/keyless-ssl-the-nitty-gritty-technical-details/)  
[大型网站的 HTTPS 实践（二）-- HTTPS 对性能的影响](https://developer.baidu.com/resources/online/doc/security/https-pratice-2.html)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()