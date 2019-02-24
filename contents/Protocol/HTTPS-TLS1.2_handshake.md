# HTTPS 温故知新（三） —— 直观感受 TLS 握手流程(上)


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0_.png'>
</p>


在 HTTPS 开篇的文章中，笔者分析了 HTTPS 之所以安全的原因是因为 TLS 协议的存在。TLS 能保证信息安全和完整性的协议是记录层协议。(记录层协议在上一篇文章中详细分析了)。看完上篇文章的读者可能会感到疑惑，TLS 协议层加密的密钥是哪里来的呢？客户端和服务端究竟是如何协商 Security Parameters 加密参数的？这篇文章就来详细的分析一下 TLS 1.2 和 TLS 1.3 在 TLS 握手层上的异同点。

TLS 1.3 在 TLS 1.2 的基础上，针对 TLS 握手协议最大的改进在于提升速度和安全性。本篇文章会重点分析这两块。

## 一. TLS 对网络请求速度的影响

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


## 二. TLS/SSL 协议概述

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


## 三. TLS 1.2 首次握手流程

TLS 1.2 握手协议主要流程如下：

Client 发送一个 ClientHello 消息，Server 必须回应一个 ServerHello 消息或产生一个验证的错误并且使连接失败。ClientHello 和 ServerHello 用于在 Client 和 Server 之间建立安全性增强的能力。ClientHello 和 ServerHello 建立了如下的属性: 协议版本，会话 ID，密码套件，压缩算法。此外，产生并交换两个随机数: ClientHello.random 和 ServerHello.random。

密钥交换中使用的最多 4 个消息: Server Certificate, ServerKeyExchange, Client Certificate 和 ClientKeyExchange。新的密钥交换方法可以通过这些方法产生:为这些消息指定一个格式, 并定义这些消息的用法以允许 Client 和 Server 就一个共享密钥达成一致。这个密钥必须很长；当前定义的密钥交换方法交换的密钥大于 46 字节。

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

- gmt\_unix\_time:    
  依据发送者内部时钟以标准 UNIX 32 位格式表示的当前时间和日期(从1970年1月1日UTC午夜开始的秒数, 忽略闰秒)。基本 TLS 协议不要求时钟被正确设置；更高层或应用层协议可以定义额外的需求. 需要注意的是，出于历史原因，该字段使用格林尼治时间命名，而不是 UTC 时间。

- random\_bytes:    
  由一个安全的随机数生成器产生的 28 个字节数据。

- client\_version:    
  Client 愿意在本次会话中使用的 TLS 协议的版本. 这个应当是 Client 所能支持的最新版本(值最大)，TLS 1.2 是 3.3，TLS 1.3 是 3.4。

- random:    
  一个 Client 所产生的随机数结构 Random。随机数的结构体 Random 在上面展示出来了。**客户端的随机数，这个值非常有用，生成预备主密钥的时候，在使用 PRF 算法计算导出主密钥和密钥块的时候，校验完整的消息都会用到，随机数主要是避免重放攻击**。

- session\_id:    
  Client 希望在本次连接中所使用的会话 ID。如果没有 session\_id 或 Client 想生成新的安全参数，则这个字段为空。**这个字段主要用在会话恢复中**。

- cipher\_suites:    
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

- compression\_methods:    
  这是 Client 所支持的压缩算法的列表，按照 Client所倾向的顺序排列。如果 session\_id 字段不空(意味着是一个会话恢复请求)，它必须包含那条会话中的 compression\_method。这个向量中必须包含, 所有的实现也必须支持 CompressionMethod.null。因此，一个 Client 和 Server 将能就压缩算法协商打成一致。

- extensions:    
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

- server\_version:    
  这个字段将包含 Client 在 Client hello 消息中建议的较低版本和 Server 所能支持的最高版本。TLS 1.2 版本是 3.3，TLS 1.3 是 3.4 。


- random:      
  这个结构由 Server 产生并且必须独立于 ClientHello.random 。**这个随机数值和 Client 的随机数一样，这个值非常有用，生成预备主密钥的时候，在使用 PRF 算法计算导出主密钥和密钥块的时候，校验完整的消息都会用到，随机数主要是避免重放攻击**。

- session\_id:      
  这是与本次连接相对应的会话的标识。如果 ClientHello.session\_id 非空，Server 将在它的会话缓存中进行匹配查询。如果匹配项被找到，且 Server 愿意使用指定的会话状态建立新的连接，Server 会将与 Client 所提供的相同的值返回回去。这意味着恢复了一个会话并且规定双方必须在 Finished 消息之后继续进行通信。否则这个字段会包含一个不同的值以标识新会话。Server 会返回一个空的 session\_id 以标识会话将不再被缓存从而不会被恢复。如果一个会话被恢复了，它必须使用原来所协商的密码套件。需要注意的是没有要求 Server 有义务恢复任何会话，即使它之前提供了一个 session\_id。Client 必须准备好在任意一次握手中进行一次完整的协商，包括协商新的密码套件。
  
- cipher\_suite:    
  由 Server 在 ClientHello.cipher\_suites 中所选择的单个密码套件。对于被恢复的会话, 这个字段的值来自于被恢复的会话状态。**从安全性考虑，应该以服务器配置为准**。

- compression\_method:    
  由 Server 在 ClientHello.compression\_methods 所选择的单个压缩算法。对于被恢复的会话，这个字段的值来自于被恢复的会话状态。

- extensions:    
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

- dh\_p:  
  用于 Diffie-Hellman 操作的素模数，即大质数。

- dh\_g:  
  用于 Diffie-Hellman 操作的生成器

- dh\_Ys:  
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

- params:  
  Server 密钥协商需要的参数。

- signed\_params:  
  对于非匿名密钥交换, 这是一个对 Server 密钥协商参数的签名。

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

- certificate\_types:      
  client 可以提供的证书类型的列表。  
  rsa\_sign: 一个包含 RSA 密钥的证书  
  dss\_sign: 一个包含 DSA 密钥的证书  
  rsa\_fixed\_dh: 一个包含静态 DH 密钥的证书  
  dss\_fixed\_dh: 一个包含静态 DH 密钥的证书  

- supported\_signature\_algorithms:  
  一个 hash/签名算法对列表供 Server选择，按照偏好降序排列

- certificate\_authorities:    
  可接受的 certificate\_authorities [[X501]](https://tools.ietf.org/html/rfc5246#ref-X501) 的名称列表，以 DER 编码的格式体现。这些名称可以为一个根 CA 或一个次级 CA 指定一个期望的名称；因此，这个消息可以被用于描已知的根和期望的认证空间。如果 certificate\_authorities 列表为空，则 Client 可以发送 ClientCertificateType 中的任意证书，除非存在有一些属于相反情况的外部设定。

certificate\_types 和 supported\_signature\_algorithms 域的交互关系某种程度上有些复杂，certificate\_type 自从 SSLv3 开始就在 TLS 中存在，但某种程度上并不规范。它的很多功能被 supported\_signature\_algorithms 所取代。应遵循下述 3 条规则:

- Client 提供的任何证书必须使用在 supported\_signature\_algorithms 中存在的 hash/签名算法对来签名。

- Clinet 提供的终端实体的证书必须包含一个与 certificate\_types 兼容的密钥。如果这个密钥是一个签名密钥，它必须能与 supported\_signature\_algorithms 中的一些 hash/签名算法对一起使用。

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

这是 Client 在收到一个 ServerHelloDone 消息后发送的第一个消息。这个消息只能在 Server 请求一个证书时发送。如果没有合适的证书，Client 必须发送一个不带证书的证书消息。即, certificate\_list 结构体的长度是 0。如果 Client 不发送任何证书，Server 可以自行决定是否可以在不验证 Client 的情况下继续握手，或者回复一个致命 handshake\_failure 警报 alert 信息。而且, 如果证书链某些方面不能接受(例如, 它没有被一个知名的可信 CA 签名)，Server 可以自行决定是否继续握手(考虑到 Client 无认证)或发送一个致命的警报 alert 信息。

Client 证书的数据结构和 Server Certificate 是相同的。

Client Certificate 消息的目的是传递 Client 的证书链给 Server；当验证 CertificateVerify 消息时(当 Client 的验证基于签名时)Server 会用它来验证或计算预备主密钥(对于静态的 Diffie-Hellman)。证书必须适用于已协商的密码套件的密钥交换算法, 和任何已协商的扩展.

尤其是:

- 证书类型必须是 X.509v3, 除非显示协商其它类型(例如, [[TLSPGP]](https://tools.ietf.org/html/rfc5246#ref-TLSPGP))。  

- 终端实体证书的公钥(和相关的限制)应该与列在 CertificateRequest 中的证书类型兼容:  

|Client 证书类型 | 证书密钥类型 |
|:-----:|:-----:|
|rsa\_sign   |  证书包含 RSA公钥；证书必须允许这个密钥被用于签名, 并与签名方案和 hash 算法一起被用于证书验证消息。|
|dss\_sign    | 证书 DSA公钥；证书必须允许这个密钥被用于签名, 并与 hash 算法一起被用于证书验证消息。|
|ecdsa\_sign   | 证书包含 ECDSA 的公钥；证书必须允许这个密钥被用于签名, 并与 hash 算法一起被用于证书验证消息；这个公钥必须使用一个曲线和 Server 支持的点的格式。|
|rsa\_fixed\_dh <br>dss\_fixed\_dh  |    证书包含 Diffie-Hellman 公钥；必须使用与 Server 的密钥相同的参数|
| rsa\_fixed\_ecdh <br> ecdsa\_fixed\_ecdh | 证书包含 ECDH 公钥；必须使用与 Server 密钥相同的曲线，并且必须使用 Server 支持的点格式|

- 如果列出在证书请求中的 certificate\_authorities 非空，证书链中的一个证书应该被一个列出来的 CA 签发。  

- 证书必须被一个可接受的 hash/签名算法对签名，正如 [Certificate Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#4-certificate-request) 那部分描述的那样。需要注意的是这放宽了在以前的 TLS 版本中对证书签名算法的限制。  

需要注意的是, 与 Server 证书一样，有一些证书使用了当前不能用于当前 TLS 的算法/算法组合。

### 7. Client Key Exchange Message

这个消息始终由 Client 发送。如果有 Client Certificate 消息的话，Client Key Exchange 紧跟在 Client Certificate 消息之后发送。如果不存在Client Certificate 消息的话，它必须是在 Client 收到 ServerHelloDone 后发送的第一个消息。

这个消息的含义是，在这个消息中设置了预备主密钥，或者通过 RSA 加密后直接传输，或者通过传输 Diffie-Hellman 参数来允许双方协商出一致的预备主密钥。

当 Client 使用一个动态的 Diffie-Hellman 指数时，这个消息就会包含 Client 的 Diffie-Hellman 公钥。如果 Client 正在发送一个包含一个静态 DH 指数(例如，它正在进行 fixed_dh Client 认证)的证书时，这个消息必须被发送但必须为空。

这个消息的结构:

这个消息的选项依赖于选择了哪种密钥交互方法。关于 KeyExchangeAlgorithm 的定义，见  [Server Key Exchange Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#3-server-key-exchange-message) 这一节。


ClientKeyExchange 消息的数据结构如下：

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
              case rsa:
                  EncryptedPreMasterSecret;
              case dhe_dss:
              case dhe_rsa:
              case dh_dss:
              case dh_rsa:
              case dh_anon:
                  ClientDiffieHellmanPublic;
              case ec_diffie_hellman: 
                  ClientECDiffieHellmanPublic;
          } exchange_keys;
      } ClientKeyExchange;
```

从 exchange\_keys 的 case 中可以看到主要分为 3 种处理方式：EncryptedPreMasterSecret、ClientDiffieHellmanPublic、ClientECDiffieHellmanPublic。那么接下来就依次分析这 3 种处理方式的不同。

### (1) RSA/ECDSA 加密预备主密钥

如果 RSA 被用于密钥协商和身份认证(RSA 密码套件)，Client 会生成一个 48 字节的预备主密钥，使用 Server 证书中的公钥加密，然后以一个加密的预备主密钥消息发送。这个结构体是 ClientKeyExchange 消息的一个变量，它本身并非一个消息。

这个消息的结构是:

```c
   struct {
       ProtocolVersion client_version;
       opaque random[46];
   } PreMasterSecret;
```

- client\_version:  
  client\_version 是 Client 支持的最高 TLS 协议版本。这个版本号是为了防止回退攻击。
  
- random:    
  紧跟着是一个 46 字节的随机数。
  
Client 将这 48 字节的预备主密钥用 Server 的 RSA 公钥加密以后生成 EncryptedPreMasterSecret，再发回 Server。

EncryptedPreMasterSecret 的数据结构如下：

```c
   struct {
       public-key-encrypted PreMasterSecret pre_master_secret;
   } EncryptedPreMasterSecret;
```

- PreMasterSecret 中的 client\_version 字段不是协商出来的 TLS 版本号，而是 ClientHello 中传递的版本号，这样做是为了防止回退攻击。不幸的是，一些旧的 TLS 实现使用了协商的版本，因此检查版本号会导致与这些不正确的 Client 实现之间的互操作失败。  
- Client 生成的 EncryptedPreMasterSecret，仅仅是加密之后的结果，并没有完整性保护，消息可能会被篡改。有两种加密方式，一种是 RSAES-PKCS1-v1\_5，另外一个种 RSAES-OAEP 加密方式。后者更加安全，但是在 TLS 1.2 中普遍用的是前者。  


Server 拿到 EncryptedPreMasterSecret 以后，用自己的 RSA 私钥解密。解密以后还需要再次校验 PreMasterSecret 中的 ProtocolVersion 和 ClientHello 中传递的 ProtocolVersion 是否一致。如果不相等，校验失败，Server 会根据下面说的规则重新生成 PreMasterSecret，并继续进行握手。

如果 ClientHello.client\_version 是 TLS 1.1 或更高，Server 实现必须按照以下的描述检查版本号。如果版本号是 TLS 1.0 或更早，Server 实现应该检查版本号，但可以有一个可配置的选项来禁止这个检查。需要注意的是如果检查失败，PreMasterSecret 应该按照以下的描述将PreMasterSecret 重新随机化生成。


由 Bleichenbacher [[BLEI]](https://tools.ietf.org/html/rfc5246#ref-BLEI) 和 Klima et al.[[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) 发现的攻击能被用于攻击 TLS Server，这种攻击表明一个特定的消息在解密时，已经被格式化为 PKCS#1，包含一个有效的 PreMasterSecret 结构，或着表明了有正确的版本号。

正如 Klima [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) 所描述的, 这些弱点能够被避免，通过处理不正确的格式消息块，或者在正确格式的 RSA 块中不区分错误的版本号。换句话说:

- 1. 生成一个 46 字节随机字符串 R；  
- 2. 解密这消息来恢复明文 M；  
- 3. 如果 PKCS#1 填充不正确，或消息 M 的长度不是精确的 48 字节:`pre_master_secret = ClientHello.client_version || R`，再如果 `ClientHello.client_version <= TLS 1.0`，且版本号检查被显示禁用：`pre_master_secret = M`。如果以上 2 种情况都不符合，那么就`pre_master_secret = ClientHello.client_version || M[2..47]`。  


需要注意的是,如果 Client 在原始的 pre\_master\_secret 中发生了错误的版本的话，那么使用 ClientHello.client\_version 显式构造产生出来的 pre\_master\_secret 是一个无效的 master\_secret。

另外一个可供选择的方法是将版本号不匹配作为一个 PKCS-1 格式错误来处理，并将预备主密钥完全随机化：

- 1. 生成一个 46 字节随机字符串 R；  
- 2. 解密这消息来恢复明文 M；  
- 3. 如果 PKCS#1 填充不正确，或消息 M 的长度不是精确的 48 字节:`pre_master_secret = R`，再如果`ClientHello.client_version <= TLS 1.0`，且版本号检查被显示禁用:`pre_master_secret = M`。再如果 M 的前两个字节 M[0..1] 不等于`ClientHello.client_version`:`premaster secret = R`，如果以上 3 种情况都不满足，就`pre_master_secret = M`。  

虽然没有已知的针对这个结构体的攻击，Klima et al. [[KPR03]](https://tools.ietf.org/html/rfc5246#ref-KPR03) 描述了一些理论上的攻击， 因此推荐第一种结构描述来处理。


在任何情况下，如果处理一个 RSA 加密的预备主密钥消息失败的时候，或版本号不是期望的时候，一个 TLS Server 一定不能产生一个警报。作为替代，它必须以一个随机生成的预备主密钥继续握手流程。出于定位问题的意图将失败的真正原因记录在日志中可能是有帮助的。但必须注意避免泄露信息给攻击者（例如，计时，日志文件或其它渠道）

在 [[PKCS1]](https://tools.ietf.org/html/rfc5246#ref-PKCS1) 中定义的 RSAES-OAEP 加密方案对于 Bleichenbacher 攻击是更安全的。然而，为了最大程度上兼容早期的 TLS 版本，TLS 1.2 规范使用 RSAES-PKCS1-v1\_5 方案。如果上述建议被采纳的话，不会有多少已知的Bleichenbacher 能够奏效。

公钥加密数据被表现为一个非透明向量 <0..2^16-1>。因此，一个 ClientKeyExchange 消息中的 RSA 加密的预备主密钥以两个长度字节为先导。这些字节对于 RSA 是冗余的因为 EncryptedPreMasterSecret 是 ClientKeyExchange 中仅有的数据，它的长度会明确地确定。SSLv3 规范对公钥加密数据的编码没有明确指定，因此很多 SSLv3 实现没有包含长度字节，它们将 RSA 加密数据直接编码进 ClientKeyExchange 消息中。

TLS 1.2 要求 EncryptedPreMasterSecret 和长度字节一起正确地编码。结果 PDU 会与很多 SSLv3 实现不兼容。实现者从 SSLv3 升级时必须修改他们的实现以生成和接受正确的编码。希望兼容 SSLv3 和 TLS 的实现者必须使他们的实现的行为依赖于版本号。

现在得知对 TLS 进行基于计时的攻击是可能的，至少当 Client 和 Server 在相同局域网中时是可行的。相应地，使用静态 RSA 密钥的实现必须使用 RSA 混淆或其它抗计时攻击技术，如 [[TIMING]](https://tools.ietf.org/html/rfc5246#ref-TIMING) 所述。


### (2) 静态 DH 公钥算出预备主密钥

如果这个值没有被包含在 Clietn 的证书中，这个结构体传递了 Client 的 Diffie-Hellman 公钥(Yc)。Yc 所用的编码由 PublicValueEncoding 罗列。这个结构是 Client 密钥交换消息的一个变量，它本身并非一个消息。

这个消息的结构是：

```c
        enum { implicit, explicit } PublicValueEncoding;
```

- implicit:  
  如果 Client 发送了一个证书其中包含了一个合适的 Diffie-Hellman 密钥(用于 fixed\_dh 类型的 Client认证)，则 Yc 是隐式的且不需要再次发送。这种情况下，Client 密钥交换消息会被发送，单必须是空。

- explicit:  
  Yc 需要被发送。
  
```c
        struct {
          select (PublicValueEncoding) {
              case implicit: struct {};
              case explicit: opaque dh_Yc<1..2^16-1>;
          } dh_public;
      } ClientDiffieHellmanPublic;
```

- dh\_Yc:   
  Client 的 Diffie-Hellman 公钥(Yc)。**DH 公钥是明文传递的**。就是算明文传递，被中间人窃听了，也无法得到最终的主密钥。具体原因可以看笔者之前密码学[这篇文章](https://halfrost.com/cipherkey/#diffiehellman)的分析。


### (3) 动态 DH 公钥算出预备主密钥

如果协商出来的密码套件密钥协商算法是 ECDHE，Client 需要发送 ECDH 公钥，结构体如下:

```c

        struct {
            opaque point <1..2^8-1>;
        } ECPoint;
        
        struct {
            select (PublicValueEncoding) {
                case implicit: struct {};
                case explicit: ECPoint ecdh_Yc;
            } ecdh_public;
        } ClientECDiffieHellmanPublic;                  
```

- ecdh\_Yc：  
  Client 的 ECDH 公钥(Yc)。**ECDH 公钥也是明文传递的**。就是算明文传递，被中间人窃听了，也无法得到最终的主密钥。具体原因可以看笔者之前密码学[这篇文章](https://halfrost.com/asymmetric_encryption/#3diffiehellmanecdh)的分析。
  
所有涉及 ECC 操作的，Server 和 Client 必须选用双方都支持的命名曲线，Client Hello 消息中 ecc\_curve 扩展指定了 Client 支持的 ECC 命名曲线。

### 8. Certificate Verify


这个消息用于对一个 Client 的证书进行显式验证。这个消息只能在一个 Client 证书具有签名能力时才能发送(例如，所有除了包含固定 Diffie-Hellman 参数的证书)。当发送时，它必须紧随着 client key exchange 消息。

这条消息的结构是：

```c
   struct {
        digitally-signed struct {
            opaque handshake_messages[handshake_messages_length];
        }
   } CertificateVerify;
```


这里 handshake\_messages 是指发送或接收到的所有握手消息，从 client hello 开始到但不包括本消息，包含握手消息的类型和长度域。这是到目前为止所有握手结构（在[这一节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#%E4%B8%89-tls-12-%E9%A6%96%E6%AC%A1%E6%8F%A1%E6%89%8B%E6%B5%81%E7%A8%8B)定义的）的级联。需要注意的是这要求两端要么缓存消息，要么计算用所有可用的 hash 算法计算运行时的 hash 值直到计算 CertificateVerify 的 hash 值为止。Server 可以通过在 CertificateRequest 消息中提高一个受限的摘要算法及来最小化这种计算代价。

在签名中使用的 hash 和签名算法必须是 CertificateRequest 消息中 supported\_signature\_algorithms 字段所列出的算法中的一种。此外，hash 和签名算法必须与 Client 的终端实体证书相兼容。RSA 密钥可以与任何允许的 hash 算法一起使用，但需要服从证书中的限制(如果有的话)。

由于 DSA 签名不包含任何安全的 hash 算法的方法，如果任意密钥使用多个 hash 的话会产生一个 hash 替代风险。目前 DSA [[DSS]](https://tools.ietf.org/html/rfc5246#ref-DSS) 可以与 SHA-1 一起使用。将来版本的 DSS [[DSS-3]](https://tools.ietf.org/html/rfc5246#ref-DSS-3) 被希望允许与 DSA 一起使用其它的摘要算法。以及指导哪些摘要算法应与每个密钥大小一起使用。此外，将来版本的 [[PKIX]](https://tools.ietf.org/html/rfc5246#ref-PKIX) 可以指定机制以允许证书表明哪些摘要算法能与 DSA 一起使用。


### 9. Finished

一个 Finished 消息一直会在一个 change cipher spec 消息后立即发送，以证明密钥交换和认证过程是成功的。一个 change cipher spec 消息必须在其它握手消息和结束消息之间被接收。

Finished 消息是第一个被刚刚协商的算法，密钥和机密保护的消息。Finished 消息的接收者必须验证内容是正确的。一旦一方已经发送了 Finished 消息且接收并验证了对端发送的 Finished 消息，就可以在连接上开始发送和接收应用数据。

Finished 消息的结构：

```c
      struct {
          opaque verify_data[verify_data_length];
      } Finished;

      verify_data = 
         PRF(master_secret, finished_label, Hash(handshake_messages))
            [0..verify_data_length-1];
```

- finished\_label:  
  对于由 Client 发送的结束消息，字符串是 "client finished"。 对于由 Server 发送的结束消息，字符串是"server finished"。

Hash 指出了握手消息的一个 hash。hash 必须用作 PRF 的基础。任何定义了一个不同 PRF 的密码套件必须定义 Hash 用于 Finished 消息的计算。

在 TLS 1.2 之前的版本中，verify\_data 一直是 12 字节长。在 TLS 1.2 版本中，verify\_data 的长度取决于密码套件。任何没有显式指定 verify\_data\_length 的密码套件都默认 verify\_data\_length 等于 12。需要注意的是这种表示的编码与之前的版本相同。将来密码套件可能会指定其它长度但这个长度必须至少是 12 字节。

- handshake\_messages:    
  所有在本次握手过程（不包括任何 HelloRequest 消息）到但不包括本消息的消息中的数据。这是只能在握手层中看见的数据且不包含记录层头。这是到目前为止所有在[这一节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#%E4%B8%89-tls-12-%E9%A6%96%E6%AC%A1%E6%8F%A1%E6%89%8B%E6%B5%81%E7%A8%8B)中定义的握手结构体的关联。

如果一个 Finished 消息在握手的合适环节上没有一个 ChangeCipherSpec 在其之前则是致命错误。

handshake\_messages 的值包括了从 ClientHello 开始一直到（但不包括）Finished 消息的所有握手消息。[这一节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.2_handshake.md#8-certificate-verify)中的 handshake\_messages 不同，因为它包含 CertificateVerify 消息（如果发送了）。同样，client 发送的 Finished 消息的 handshake\_messages 与 Server 发送的 Finished 消息不同，因为第二个被发送的要包含前一个。Server 的 Finished 消息会包含 Client 的 Finished 子消息。

注意：ChangeCipherSpec 消息，alert 警报，和任何其它记录类型不是握手消息，不会被包含在 hash 计算中。同样，HelloRequest 消息也被握手 hash 忽略。


Finished 子消息是 TLS 记录层加密保护的第一条消息。Finished 子消息的存在的意义是什么呢？

在所有的握手协议中，所有的子消息都没有加密和完整性保护，消息很容易篡改，改掉以后如果不检验，就会出现不安全的攻击。为了避免握手期间存在消息被篡改的情况，所以 Client 和 Server 都需要校验一下对方的 Finished 子消息。

如果中间人在握手期间把 ClientHello 的 TLS 最高支持版本修改为 TLS 1.0，企图回退攻击，利用 TLS 旧版本中的漏洞。Server 收到中间人的 ClientHello 并不知道是否存在篡改，于是也按照 TLS 1.0 去协商。握手进行到最后一步，校验 Finished 子消息的时候，校验不通过，因为 Client 原本发的 ClientHello 中 TLS 最高支持版本是 TLS 1.2，那么产生的 Finished 子消息的 verify\_data 与 Server 拿到篡改后的 ClientHello 计算出来的 verify\_data 肯定不同。至此也就发现了中间存在篡改，握手失败。


## 四. 直观感受 TLS 1.2 首次握手流程

至此，TLS 1.2 首次握手的所有细节都已经分析完了。这一节让我们小结一下上面的流程，并用 Wireshark 直观感受一下 TLS 1.2 协议。

首先是基于 RSA 密钥协商算法的首次握手：

![](https://img.halfrost.com/Blog/ArticleImage/97_2_3.png)

握手开始，Client 先发送 ClientHello ，在这条消息中，Client 会上报它支持的所有“能力”。client\_version 中标识了 Client 能支持的最高 TLS 版本号；random 中标识了 Client 生成的随机数，用于预备主密钥和主密钥以及密钥块的生成，总长度是 32 字节，其中前 4 个字节是时间戳，后 28 个字节是随机数；cipher\_suites 标识了 Client 能够支持的密码套件。extensions 中标识了 Client 能够支持的所有扩展。

> 关于 extensions 本篇文章涉及的少，因为笔者打算把 TLS 1.2 和 TLS 1.3 中涉及到的 extensions 都整理到一篇文章中，在这篇握手的流程中没有详细分析。extensions 更加详细的分析请见 [《HTTPS 温故知新（六） —— TLS 中的 Extensions》]()

Server 在收到 ClientHello 之后，如果能够继续协商，就会发送 ServerHello，否则发送 Hello Request 重新协商。在 ServerHello 中，Server 会结合 Client 的能力，选择出双方都支持的协议版本以及密码套件进行下一步的握手流程。server\_version 中标识了经过协商以后，Server 选出了双方都支持的协议版本。random 中标识了 Server 生成的随机数，用于预备主密钥和主密钥以及密钥块的生成，总长度是 32 字节，其中前 4 个字节是时间戳，后 28 个字节是随机数；cipher\_suites 标识了经过协商以后，Server 选出了双方都支持的密码套件。extensions 中标识了 Server 处理 Client 的 extensions 之后的结果。

当协商出了双方都能满足的密钥套件，根据需要 Server 会发送 Certificate 消息。Certificate 消息会带上 Server 的证书链。Certificate 消息的目的一是为了验证 Server 身份，二是为了让 Client 根据协商出来的密码套件从证书中获取 Server 的公钥。Client 拿到 Server 的公钥和 server 的 random 会生成预备主密钥。

由于密钥协商算法是 RSA，需要 Server 在发送完 Certificate 消息以后就直接发送 ServerHelloDone 消息了。

Client 收到 ServerHelloDone 消息以后，会开始计算预备主密钥，计算出来的预备主密钥会经过 RSA/ECDSA 算法加密，并通过 ClientKeyExchange 消息发送给 Server。RSA 密码套件的预备主密钥是 48 字节。前 2 个字节是 client\_version，后 46 字节是随机数。Server 收到 ClientKeyExchange 消息以后就会开始计算主密钥和密钥块了。同时 Client 也会在自己本地算好主密钥和密钥块。
 
> 有些人会说“主密钥和会话密钥”，这里的会话密钥和密钥块是相同的意思。主密钥是由预主密钥、客户端随机数和服务器随机数通过 PRF 函数来生成；会话密钥是由主密钥、客户端随机数和服务器随机数通过 PRF 函数来生成。
>
>会话密钥 = key_block = 密钥块，这三者的意思是一样的，只是翻译不同罢了。

Client 发送完 ClientKeyExchange 消息紧接着还会继续发送 ChangeCipherSpec 消息和 Finished 消息。Server 也会回应 ChangeCipherSpec 消息和 Finished 消息。如果 Finished 消息校验完成以后，代表握手最终成功。

再来看看基于 DH 密钥协商算法的首次握手：

![](https://img.halfrost.com/Blog/ArticleImage/97_3_0_.png)

基于 DH 密钥协商算法和基于 RSA 密码协商的区别在 Server 和 Client 协商 DH 参数上面。这里只说明一下 DH 密钥协商过程比 RSA 多的几步，其他的流程和 RSA 的流程基本一致。

在 Server 发送完 Certificate 消息以后，还会继续发送 ServerKeyExchange 消息，在这条消息里面传递 DH 参数。

另外一个不同点在于 ClientKeyExchange 消息中传递给 Server 预备主密钥长度不是 48 字节。基于 DH/ECDH 算法的协商密钥长度取决于 DH/ECDH 算法的公钥。

为了让读者能更加直观的理解 TLS 1.2 的流程，笔者用 Wireshark 抓取了 Chrome 和笔者博客 TLS 握手中的网络包。结合 Wireshark 的抓包分析，让我们更加深入的理解 TLS 1.2 握手吧。下面的例子以 TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 密码套件为例：

![](https://img.halfrost.com/Blog/ArticleImage/97_6.png)

上面这是一次从 TLS 握手开始到 TCP 4 次挥手完整的过程。这里我们重要关注 protocol = TLS 1.2 的所有消息。整体流程和上面分析的基于 DH 密钥交换算法的是一致的。在 TCP 4 次挥手之前，TLS 层会先收到 Close Notify 的 Alert 消息。

> 读到这里能有读者有疑问，为什么经过 TLS 加密以后的上层数据会以明文展示在抓包中？HTTPS 不安全？这里需要解释一下，因为笔者利用 `export SSLKEYLOGFILE=/Users/XXXX/sslkeylog.log` 把 ECDHE 协商的密钥保存成 log 文件了，解析上层 HTTP/2 的加密包的时候就可以利用 log 中的 TLS key 进行解密。上图中绿色的部分，就是通过解密出来得到的 HTTP/2 的解密内容。具体这块内容笔者会在 HTTP/2 相关的文章里面会提一提，这里读者就认为是笔者利用某些手段解析出了 HTTPS 加密的内容即可。

接下来一条条的看看网络是如何传输数据包的。从 ClientHello 开始。

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

从 TLS 1.2 Record Layer 的 Length 字段中我们可以看到 TLS 记录层的这条 TLS 握手消息长度是 512 字节，其中 ClientHello 消息中占 508 字节。ClientHello 中标识了 Client 最高支持的 TLS 版本是 TLS 1.2 (0x0303)。Client 支持的密码套件有 17 种，优先支持的是 TLS\_AES\_128\_GCM\_SHA256 。Session ID 的长度是 32 字节，这里不为空。压缩算法是 null。signature\_algorithms 中标识了 Client 支持 9 对数字签名算法。

>默认情况下 TLS 压缩都是关闭的，因为 CRIME 攻击会利用 TLS 压缩恢复加密认证 cookie，实现会话劫持，而且一般配置 gzip 等内容压缩后再压缩 TLS 分片效益不大又额外占用资源，所以一般都关闭 TLS 压缩。

![](https://img.halfrost.com/Blog/ArticleImage/97_8.png)

ClientHello 中发送了 status\_request 扩展，查询 OCSP 封套消信息。发送了 signed\_certificate\_timestamp 扩展，查询 SCT 信息。发送了 application\_layer\_protocol\_negotiation (ALPN)扩展，询问服务端是否支持 HTTP/2 协议。supported\_group 扩展里面标识了 Client 中支持的椭圆曲线。SessionTicket TLS 扩展表明了 Client 支持基于 Session Ticket 的会话恢复。

再看看 ServerHello 消息。

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

从 TLS 1.2 Record Layer 的 Length 字段中我们可以看到 TLS 记录层的这条 TLS  握手协议消息长度是 82 字节，其中 ServerHello 消息中占 78 字节。Server 选择用 TLS 1.2 版本与 Client 进行接下来的握手流程。Server 与 Client 协商出来的密码套件是 TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384。

Server 支持 HTTP/2，在 ALPN 扩展中进行了回复。

![](https://img.halfrost.com/Blog/ArticleImage/97_10.png)

从 TLS 1.2 Record Layer 的 Length 字段中我们可以看到 TLS 记录层的这条 TLS 握手消息长度是 2544 字节，其中 Certificate 消息中占 2540 字节，Certificates 证书链包含 2 张证书，Server 实体证书 1357 字节，中间证书 1174 字节。中间证书是 Let's Encrypt 签发的。两张证书都是用 sha256WithRSAEncryption 签名算法进行签名的。

![](https://img.halfrost.com/Blog/ArticleImage/97_11.png)

从 TLS 1.2 Record Layer 的 Length 字段中我们可以看到 TLS 记录层的这条 TLS  握手协议消息长度是 535 字节，其中 Certificate Status 消息中占 531 字节。Server 将 OCSP 的 response 发送给 Client。

从 TLS 1.2 Record Layer 的 Length 字段中我们可以看到 TLS 记录层的这条 TLS  握手协议消息长度是 116 字节，其中 ServerKeyExchange 消息中占 112 字节。由于协商出来的是 ECDHE 密钥协商算法，所以 Server 需要把 ECDH 的参数和公钥通过 ServerKeyExchange 消息发给 Client。这里 ECDHE 使用的 ECC 命名曲线是 x25519 。Server 的公钥是 (62761b5……)，签名算法是 ECDSA\_secp256r1\_SHA256 。签名值是 (3046022……)。

ServerHelloDone 消息结构很简单，见上图。

![](https://img.halfrost.com/Blog/ArticleImage/97_12.png)

由于是 ECDHE 协商算法，所以 Client 需要发送 ECC DH 公钥，对应的公钥值是 (1e58cf……)。公钥长度 32 字节。

ChangeCipherSpec 消息结构很简单，发送这条消息是为了告诉 Server ，Client 可以使用 TLS 记录层协议进行密码学保护了。第一条进行密码学保护的消息是 Finished 消息。

Finished 消息结构很简单，见上图。

![](https://img.halfrost.com/Blog/ArticleImage/97_13.png)

Server 如果只是 SessionTicket，那么会生成新的 NewSessionTicket 返给 Client，然后同样返回 ChangeCipherSpec 消息和 Finished 消息。

![](https://img.halfrost.com/Blog/ArticleImage/97_14.png)

当页面关闭的时候，Server 会给 Client 发送 TLS Alert 消息，这条消息里面的描述就是 Close Notify。同时 Server 会发送 FIN 包开始 4 次挥手。


## 五. TLS 1.2 会话恢复


Client 和 Server 只要一关闭连接，短时间内再次访问 HTTPS 网站的时候又需要重新连接。新的连接会造成网络延迟，并消耗双方的计算能力。有没有办法能复用之前的 TLS 连接呢？办法是有的，这就涉及到了 TLS 会话复用机制。

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


Session ID 由服务器端支持，协议中的标准字段，因此基本所有服务器都支持，服务器端保存会话 ID 以及协商的通信信息，占用服务器资源较多。

### 1. 基于 Session ID 的会话恢复

当 Client 通过一次完整的握手，与 Server 建立了一次完整的 Session，Server 会记录这次 Session 的信息，以备恢复会话的时候使用:

- 会话标识符(session identifier):      
  每个会话的唯一标识符
- 对端的证书(peer certificate):   
  对端的证书，一般为空
- 压缩算法(compression method):   
  一般不启用
- 密码套件(cipher spec):  
  Client 和 Server 协商共同协商出来的密码套件
- 主密钥(master secret):    
  每个会话都会保存一份主密钥，**注意不是预备主密钥**。(读者可以想想为什么，如果还是想不通，见 [《HTTPS 温故知新（五） —— TLS 中的密钥计算》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-key-cipher.md))
- 会话可恢复标识(is resumable): 
  标识会话是否可恢复
  
当 Server 保存了以上的信息，可以再次计算出 TLS 记录层需要的 security parameters 加密参数，从而加密应用数据。

基于 Session ID 会话恢复的流程如下：  

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

![](https://img.halfrost.com/Blog/ArticleImage/97_4_.png)

Client 发现请求的网站是之前请求过的，即内存中存在 Session ID，那么再次建立连接的时候会在 ClientHello 中附带与网站对应的 Session ID。Server 的内存中会保存一份 Session Cache 的字典，key 是 Session ID，value 是会话信息。Server 收到 ClientHello 以后，根据传过来的 Session ID 查看是否有相关的会话信息，如果有，就会允许 Client 进行会话恢复，直接发送 ChangeCipherSpec 和 Finished 消息。如果没有相关的会话信息，就会开始一次完整的握手，并在 ServerHello 中生成新的 Session ID 返回给 Client。Client 收到 Server 发来的 ChangeCipherSpec 和 Finished 消息，代表会话恢复成功，也发送 ChangeCipherSpec 和 Finished 消息作为回应。

Session ID 的来源：  

- 上次完全握手生成的 Session ID  
- 使用另外一条连接的 Session ID  
- 直接使用本次连接的 Session ID  

会话恢复中 ClientHello 各个参数的必要性：

- Server 通过 ClientHello 中协商出来的密钥套件必须和会话中的密钥套件是一致的，否则会话恢复失败，进行完整的握手。
- ClientHello 中的随机数和恢复之前会话所用的随机数是不同的，所以即使会话恢复了，由于 ClientHello 中随机数的不同，再次通过 PRF 生成的密钥块(会话密钥)也是不同的。增加了安全性。
- ClientHello 中的 Session ID 是明文传输，所以不应该在 Session ID 中包含敏感信息。并且握手最后一步的  Finished 校验非常有必要，防止 Session ID 被篡改。

最后需要注意的是，会话恢复取决于 Server 端，即使 Session ID 正确，并且 Server 内存中也存在相关的会话信息，Server 依旧可以要求 Client 进行完整的握手。即会话恢复不是强制的。

基于 Session ID 的会话恢复的**优点**是:  

- 减少网络延迟，握手耗时从 2-RTT -> 1-RTT
- 减少了 Client 和 Server 端的负载，减少了加密运算的 CPU 资源消耗

基于 Session ID 的会话恢复的**缺点**是:  

- Server 存储会话信息，限制了 Server 的扩展能力。
- 分布式系统中，如果只是简单的在 Server 的内存中存储 Session Cache，那么多台机器的数据同步也是一个问题。

Nginx 官方并没有提供支持分布式服务器的 Session Cache 的实现。可以使用第三方补丁，但是安全和维护成本也会增加。

由于上面 2 个缺点，也就引出了基于 Session Ticket 的会话恢复方案。


### 2. 基于 Session Ticket 的会话恢复

用来替代 Session ID 会话恢复的方案是使用会话票证（Session ticket）。使用这种方式，除了所有的状态都保存在客户端（与 HTTP Cookie 的原理类似）之外，其消息流与服务器会话缓存是一样的。

其思想是服务器取出它的所有会话数据（状态）并进行加密 (密钥只有服务器知道)，再以票证的方式发回客户端。在接下来的连接中，客户端恢复会话时在 ClientHello 的扩展字段 session\_ticket 中携带加密信息将票证提交回服务器，由服务器检查票证的完整性，解密其内容，再使用其中的信息恢复会话。

**对于 Server 来说，解密 ticket 就可以得到主密钥**，(注意这里和 SessionID 不同，有 Session ID 可以得到主密钥的信息)。对于 Client 来说，完整握手的时候收到 Server 下发的 NewSessionTicket 子消息的时候，Client 会将 Ticket 和对应的预备主密钥存在 Client，简短握手的时候，一旦 Server 验证通过，可以进行简单握手的时候，Client 通过本地存储的预备主密钥生成主密钥，最终再生成会话密钥(密钥块)。

这种方法有可能使扩展服务器集群更为简单，因为如果不使用这种方式，就需要在服务集群的各个节点之间同步 Session Cache。Session ticket 需要服务器和客户端都支持，属于一个扩展字段，占用服务器资源很少。

Session Ticket 的优点也就决定了它特别适合在以下场景中使用：

- 大型 HTTPS 网站，访问量非常大，在 Server 中存储 Session 信息需要消耗大量内存
- HTTPS 网站所有者希望会话信息的生命周期能足够长，让 Client 尽量都使用简短握手的方式
- HTTPS 网站所有者希望用户能跨地域跨主机访问


基于 Session Ticket 会话恢复的流程如下： 


### (1). 获取 SessionTicket

Client 在进行一次完整握手以后才能获取到 SessionTicket。

```c
      Client                                               Server

      ClientHello
      (empty SessionTicket extension)-------->
                                                      ServerHello
                                   (empty SessionTicket extension)
                                                     Certificate*
                                               ServerKeyExchange*
                                              CertificateRequest*
                                   <--------      ServerHelloDone
      Certificate*
      ClientKeyExchange
      CertificateVerify*
      [ChangeCipherSpec]
      Finished                     -------->
      											         NewSessionTicket
                                               [ChangeCipherSpec]
                                   <--------             Finished
      Application Data             <------->     Application Data
```

Client 在 ClientHello 的扩展中包含空的 SessionTicket 扩展，如果 Server 支持 SessionTicket 会话恢复，则会在 ServerHello 中回复一个空的 SessionTicket 扩展。Server 将会话信息进行加密保护，生成一个 ticket，通过 NewSessionTicket 子消息发给 Client 。**注意，虽然 NewSessionTicket 子消息在 ChangeCipherSpec 消息之前，但是它也是一条加密消息**。

Server 将会话信息加密以后以 ticket 的方式发送给 Client，Server 就不再存储任何信息了。Client 将接收到的 ticket 存储在内存中，什么时候想会话恢复了，发给 Server，如果解密以后确认无误，即可进行简短握手了。

### (2). 基于 SessionTicket 的会话恢复

当 Client 本地获取了 SessionTicket 以后，下次想要进行简短握手，就可以使用这个 SessionTicket 了。

```c
      Client                                                Server

      ClientHello
      (SessionTicket extension)     -------->
                                                       ServerHello
                                    (empty SessionTicket extension)
                                                  NewSessionTicket
                                                [ChangeCipherSpec]
                                    <--------             Finished
      [ChangeCipherSpec]
      Finished                      -------->
      Application Data              <------->     Application Data
      
```

Client 在 ClientHello 的扩展中包含非空的 SessionTicket 扩展，如果 Server 支持 SessionTicket 会话恢复，则会在 ServerHello 中回复一个空的 SessionTicket 扩展。Server 将会话信息进行加密保护，生成一个新的 ticket，通过 NewSessionTicket 子消息发给 Client。发送完 NewSessionTicket 消息以后，紧跟着发送 ChangeCipherSpec 和 Finished 消息。Client 收到上述消息以后，回应 ChangeCipherSpec 和 Finished 消息，会话恢复成功。

### (3). Server 不支持 SessionTicket

有读者可能会问了，既然 Client 发送了非空的 SessionTicket extension，为什么 Server 必须在 ServerHello 中回复一个空的 SessionTicket 扩展呢？因为当 Server 不支持 SessionTicket 的时候，ServerHello 中是不包含 SessionTicket extension 的，所以是否包含 SessionTicket extension，区分出了 Server 是否支持 SessionTicket。

```c
         Client                                               Server

         ClientHello
         (SessionTicket extension)    -------->
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

Server 如果不支持 SessionTicket，那么在 ServerHello 不响应 SessionTicket TLS 扩展，并且也不发送 NewSessionTicket 子消息。


### (4). Server 校验 SessionTicket 失败

如果 Server 校验 SessionTicket 失败，那么握手会回退到完整握手。

```c
         Client                                               Server

         ClientHello
         (SessionTicket extension) -------->
                                                         ServerHello
                                     (empty SessionTicket extension)
                                                        Certificate*
                                                  ServerKeyExchange*
                                                 CertificateRequest*
                                  <--------          ServerHelloDone
         Certificate*
         ClientKeyExchange
         CertificateVerify*
         [ChangeCipherSpec]
         Finished                 -------->
                                                    NewSessionTicket
                                                  [ChangeCipherSpec]
                                  <--------                 Finished
         Application Data         <------->         Application Data
```

如果 Server 接受了票证但最终握手失败，则 Client 应该删除 ticket。

正常的基于 SessionTicket 的会话恢复流程如下图：

![](https://img.halfrost.com/Blog/ArticleImage/97_5_.png)


### (5). NewSessionTicket 子消息

这一节内容主要都来自 [[RFC5077]](https://tools.ietf.org/html/rfc5077)。

如果 ServerHello 消息中包含了 Session Ticket TLS 扩展，那么必须在 ChangeCipherSpec 之前发送**加密过的 NewSessionTicket 子消息**。如果 ServerHello 消息中不包含了 Session Ticket TLS 扩展，表示 Server 或 Client 不想使用 SessionTicket 会话恢复机制。

由于 NewSessionTicket 子消息也算是握手的一部分，所以 Finished 子消息中也需要校验它。**如果 Server 成功校验了 Client 发送的 ticket，那么也必须重新生成一个全新的 ticket，通过 NewSessionTicket 子消息发送给 Client，Client 下次会使用这个新的 SessionTicket**。

在握手协议中，由于扩展的加入，也加入了几条新的握手消息:  

```c
      struct {
          HandshakeType msg_type;
          uint24 length;
          select (HandshakeType) {
              case hello_request:       HelloRequest;
              case client_hello:        ClientHello;
              case server_hello:        ServerHello;
              case certificate:         Certificate;
              case certificate_url:     CertificateURL;    /* NEW */
              case certificate_status:  CertificateStatus; /* NEW */
              case server_key_exchange: ServerKeyExchange;
              case certificate_request: CertificateRequest;
              case server_hello_done:   ServerHelloDone;
              case certificate_verify:  CertificateVerify;
              case client_key_exchange: ClientKeyExchange;
              case finished:            Finished;
              case session_ticket:      NewSessionTicket; /* NEW */
          } body;
      } Handshake;
```

CertificateURL、CertificateStatus、NewSessionTicket 这 3 条握手子消息都算是扩展带来的新的子消息。

NewSessionTicket 消息的数据结构如下：

```c

      struct {
          uint32 ticket_lifetime_hint;
          opaque ticket<0..2^16-1>;
      } NewSessionTicket;
```

NewSessionTicket 最重要的一个字段就是 `ticket_lifetime_hint`。它标识了 ticket 是否过期，Server 会校验这个字段，如果过期就不能进行会话恢复。ticket 的生成和校验全部都由 Server 进行，Client 仅仅只是接收和存储。

Server 生成 ticket 没有固定的规范，每个 Server 生成的方式也可以不同，需要注意的一点就是前向安全性，防止被破解。在 RFC5077 中建议按照如下方式生成:

```c
      struct {
          opaque key_name[16];
          opaque iv[16];
          opaque encrypted_state<0..2^16-1>;
          opaque mac[32];
      } ticket;
```

- key\_name:  
  ticket 加密使用的密钥文件
  
- iv:  
  初始化向量，AES 加密算法需要使用
  
- encrypted\_state:  
  ticket 详细信息，存储的就是会话信息
  
- mac:  
  ticket 需要的完整和安全性保护
  
  
会话信息的数据结构如下：

```c
      struct {
          ProtocolVersion protocol_version;
          CipherSuite cipher_suite;
          CompressionMethod compression_method;
          opaque master_secret[48];
          ClientIdentity client_identity;
          uint32 timestamp;
      } StatePlaintext;
```

StatePlaintext 中的 `client_identity` 是 Client 标识符，`timestamp` 是 ticket 过期时间。ClientIdentity 的数据结构如下：

```c
      enum {
         anonymous(0),
         certificate_based(1),
         psk(2)
     } ClientAuthenticationType;

      struct {
          ClientAuthenticationType client_authentication_type;
          select (ClientAuthenticationType) {
              case anonymous: struct {};
              case certificate_based:
                  ASN.1Cert certificate_list<0..2^24-1>;
              case psk:
                  opaque psk_identity<0..2^16-1>;   /* from [RFC4279] */
          };
       } ClientIdentity;
```

ClientIdentity 有 2 种认证方式，一种是基于 `certificate_based` 证书的方式，另外一种是基于 `psk` PSK 的方式。

使用给定 IV，在 CBC 模式下使用 128 位 AES 加密 encrypted\_state 中的实际状态信息。使用 HMAC-SHA-256 通过 key\_name（16个字节）和 IV（16个字节）计算消息验证代码（MAC），然后是 encrypted\_state 字段的长度（2个字节）及其内容（可变长度），这样就生成了 ticket。

## 六. 直观感受 TLS 1.2 会话恢复


这一节，笔者用 Wireshark 展示一下 TLS 1.2 的会话恢复，让读者加深理解。

![](https://img.halfrost.com/Blog/ArticleImage/97_7.png)

![](https://img.halfrost.com/Blog/ArticleImage/97_9.png)

ServerHello 中 SessionID 为空，并且 SessionTicket TLS 扩展也会空。这个时候表明了 Server 会在接下来的子消息中发送 NewSessionTicket 子消息。

这里用的例子比较特殊，Client 在上次握手的时候，ClientHello 中带有 SessionID 和空的 SessionTicket TLS 扩展，Server 收到这个扩展以后，在内存的 Session Cache 中找到了这个 Session ID 对应的会话信息，在 ServerHello 中以相同的 SessionID 响应了 Client，并且也回应了空的 SessionTicket TLS 扩展。以此为背景，进行会话恢复，结果会是怎么样的呢？

最终结果抓包截图如下:

![](https://img.halfrost.com/Blog/ArticleImage/97_23.png)

看上面的截图没有看到 NewSessionTicket 子消息，是否说明会话恢复不是基于 SessionTicket 的呢？我们继续看细节。

![](https://img.halfrost.com/Blog/ArticleImage/97_24.png)

在 ClientHello 中，可以看到 Client 同时带了 Session ID 和非空的 SessionTicker TLS 扩展。

![](https://img.halfrost.com/Blog/ArticleImage/97_25.png)

Server 在 ServerHello 中回应了相同的 Session ID，说明了可以在 Session Cache 中找到相应的会话信息。在 ClientHello 中也发送了 SessionTicket，这里 Server 为什么什么扩展消息都没有回应呢？难道是因为 Server 不支持 SessionTicket TLS 扩展？Server 在前一次握手中发送了 NewSessionTicket 子消息说明了 Server 支持 SessionTicket TLS 扩展，那为什么这里什么关于 SessionTicket 的信息都没有回复呢？原因就是因为 ClientHello 包含了可以用来会话恢复的 SessionID。[[RFC 5077 3.4.  Interaction with TLS Session ID]](https://tools.ietf.org/html/rfc5077) 中**规定**：如果 Client 在 ClientHello 中同时发送了 Session ID 和 SessionTicket TLS 扩展，Server 必须是用 ClientHello 中相同的 Session ID 进行相应。但是在校验 SessionTicket 时，Sever 不能依赖这个特定的 Session ID，即不能用 ClientHello 中的 Session ID 进行会话恢复。Server 优先使用 SessionTicket 进行会话恢复(SessionTicket 优先级高于 Session ID)，如果 Session 校验通过，就继续发送 ChangeCipherSpec 和 Finished 消息。不发送 NewSessionTicket 消息。


![](https://img.halfrost.com/Blog/ArticleImage/97_26.png)

Client 收到 Server 发过来的 ChangeCipherSpec 和 Finished 消息，作为回应，也会发送 ChangeCipherSpec 和 Finished 消息。

![](https://img.halfrost.com/Blog/ArticleImage/97_33_.png)

把会话恢复过程中 Client 同时带有 Session ID 和 SessionTicket TLS 扩展的情况总结成一张图，如上图。


至此，直观感受 TLS 握手流程的上篇就结束了，上篇将 TLS 1.2 中所有的握手流程都详细分析完成了。[《HTTPS 温故知新（四） —— 直观感受 TLS 握手流程(下)》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-TLS1.3_handshake.md) 下篇会着重分析 TLS 1.3 的握手流程，与 TLS 1.2 握手流程进行对比。另外还会讲解 TLS 1.3 新增的 0-RTT 是怎么一回事。

当然在 TLS 1.2 和 TLS 1.3 握手流程中所有涉及到密钥计算的内容，都放在 [《HTTPS 温故知新（五） —— TLS 中的密钥计算》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-key-cipher.md) 这篇文章里面了，TLS 1.2 和 TLS 1.3 握手流程中所有涉及到扩展的内容，都放在 [《HTTPS 温故知新（六） —— TLS 中的 Extensions》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-extensions.md) 这篇文章里面了。

------------------------------------------------------

Reference：

[RFC 5247](https://tools.ietf.org/html/rfc5077)  
[RFC 5077](https://tools.ietf.org/html/rfc5077)    
[RFC 8466](https://tools.ietf.org/html/rfc8466)   
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)        
[大型网站的 HTTPS 实践（二）-- HTTPS 对性能的影响](https://developer.baidu.com/resources/online/doc/security/https-pratice-2.html)  

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS-TLS1.2\_handshake/](https://halfrost.com/https_tls1-2_handshake/)