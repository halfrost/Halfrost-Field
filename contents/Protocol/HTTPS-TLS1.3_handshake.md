# HTTPS 温故知新（四） —— 直观感受 TLS 握手流程(下)


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/120_0.png'>
</p>


在 HTTPS 开篇的文章中，笔者分析了 HTTPS 之所以安全的原因是因为 TLS 协议的存在。TLS 能保证信息安全和完整性的协议是记录层协议。(记录层协议在上一篇文章中详细分析了)。看完上篇文章的读者可能会感到疑惑，TLS 协议层加密的密钥是哪里来的呢？客户端和服务端究竟是如何协商 Security Parameters 加密参数的？这篇文章就来详细的分析一下 TLS 1.2 和 TLS 1.3 在 TLS 握手层上的异同点。

TLS 1.3 在 TLS 1.2 的基础上，针对 TLS 握手协议最大的改进在于提升速度和安全性。本篇文章会重点分析这两块。

先简述一下 TLS 1.3 的一些优化和改进:

1. 减少握手等待时间，将握手时间从 2-RTT 降低到 1-RTT，并且增加 0-RTT 模式。

2. 删除 RSA 密钥协商方式，静态的 Diffie-Hellman 密码套件也被删除了。因为 RSA 不支持前向加密性。TLS 1.3 只支持 (EC)DHE 的密钥协商算法。删除了 RSA 的方式以后，能有效预防[心脏出血](https://en.wikipedia.org/wiki/Heartbleed)的攻击。**所有基于公钥的密钥交换算法现在都能提供前向安全**。TLS 1.3 规范中只支持 5 种密钥套件，TLS13-AES-256-GCM-SHA384、TLS13-CHACHA20-POLY1305-SHA256、TLS13-AES-128-GCM-SHA256、TLS13-AES-128-CCM-8-SHA256、TLS13-AES-128-CCM-SHA256，隐藏了非对称加密密钥协商算法，因为默认都是椭圆曲线密钥协商。


3. 删除对称加密中，分组加密和 MAC 导致的一些隐患。在 TLS1.3 之前的版本中，选择的是 MAC-then-Encrypt 方式。但是这种方式带来了一些漏洞，例如 [BEAST](https://www.youtube.com/watch?v=-_8-2pDFvmg)，一系列填充 oracle 漏洞([Lucky 13](http://www.isg.rhul.ac.uk/tls/Lucky13.html) 和 [Lucky Microseconds](https://eprint.iacr.org/2015/1129))。CBC 模式和填充之间的交互也是 SSLv3 和一些 TLS 实现中广泛宣传的 [POODLE](https://blog.cloudflare.com/sslv3-support-disabled-by-default-due-to-vulnerability/) 漏洞原因。在 TLS 1.3 中，已移除所有有安全隐患的密码和密码模式。你不能再使用 CBC 模式密码或不安全的流式密码，如 RC4 。TLS 1.3 中允许的唯一类型的对称加密是一种称为 AEAD（authenticated encryption with additional data）的新结构，它将加密性和完整性整合到一个无缝操作中。

4. 在 TLS 1.3中，删除了 PKCS＃1 v1.5 的支持，而选择更新的设计 RSA-PSS，提高了安全性。认证方面通过非对称算法，例如，RSA, 椭圆曲线数字签名算法(ECDSA)，或 Edwards 曲线数字签名算法(EdDSA)完成，或通过一个对称的预共享密钥（PSK)。

5. 在 TLS 1.2 的握手流程中，只有 ChangeCipherSpec 之后的消息会被加密，如 Finished 消息和 NewSessionTicket，其他的握手子消息不会加密。TLS 1.3 针对这个问题，对握手中大部分子消息全部进行加密处理。这样可以有效的预防 FREAK，LogJam 和 CurveSwap 这些降级攻击(降级攻击是中间人利用协商，强制使通信双方使用能被支持的最低强度的加密算法，从而暴力攻击计算出密钥，允许攻击者在握手时伪造 MAC)。在TLS 1.3中，这种类型的降级攻击是不可能的，因为服务器现在签署了整个握手，包括密码协商。
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/120_1.png'>
</p>
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/120_2.png'>
</p>

6. TLS 1.3 完全禁止重协商。
7. 密钥导出函数被重新设计，由 TLS 1.2 的 PRF 算法改为更加安全的 HKDF 算法。
8. 废除 Session ID 和 Session Ticket 会话恢复方式，统一通过 PSK 的方式进行会话恢复，并在 NewSessionTicket 消息中添加过期时间和用于混淆时间的偏移值。

更多重要的变更，见笔者之前的文章 [《TLS 1.3 Introduction》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#%E4%B8%89tls-13-%E5%92%8C-tls-12-%E4%B8%BB%E8%A6%81%E7%9A%84%E4%B8%8D%E5%90%8C)

## 七. TLS 1.3 首次握手流程


>由于笔者在之前的某篇文章中已经将 TLS 1.3 握手流程的细节分析过了，所以这篇文章中不会像上篇分析 TLS 1.2 中那么详细，如果想了解 TLS 1.3 中细节，请阅读这篇文章[《TLS 1.3 Handshake Protocol》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md)。本篇文章主要从 wireshark 角度带读者直观感受 TLS 1.3 的握手流程。

在 TLS 1.3 中，存在 4 种密钥协商的方法:

-  Client 支持的加密套件列表。密码套件里面中能体现出 Client 支持的 AEAD 算法或者 HKDF 哈希对。
- “supported\_groups” 的扩展 和 "key\_share" 扩展。“supported\_groups” 这个扩展表明了 Client 支持的 (EC)DHE groups，"key\_share" 扩展表明了 Client 是否包含了一些或者全部的（EC）DHE共享。
- "signature\_algorithms" 签名算法和 "signature\_algorithms\_cert" 签名证书算法的扩展。"signature\_algorithms" 这个扩展展示了 Client 可以支持了签名算法有哪些。"signature\_algorithms\_cert" 这个扩展展示了具体证书的签名算法。
- "pre\_shared\_key" 预共享密钥和 "psk\_key\_exchange\_modes" 扩展。预共享密钥扩展包含了 Client 可以识别的对称密钥标识。"psk\_key\_exchange\_modes" 扩展表明了可能可以和 psk 一起使用的密钥交换模式。

第一种方法是 TLS 1.2 中已经存在的，通过 ClientHello 中的 Cipher Suites 进行协商。第二种方法是 TLS 1.3 新增的，在 TLS 1.3 中完整握手就是通过这种方法实现的。第三种方法也是 TLS 1.3 新增的。这种方法没有第二种方法用的多。第四种方法也是 TLS 1.3 新增的，它将 TLS 1.2 中 Session ID 和 Session Ticket 废除以后，统一通过 PSK 的方式进行会话恢复。TLS 1.3 中的 0-RTT 模式也是通过 PSK 进行的。

TLS 1.3 完整握手的流程如下：

```c
          Client                                               Server

          ClientHello
          + key_share               -------->
                                                          ServerHello
                                                          + key_share
                                                {EncryptedExtensions}
                                                {CertificateRequest*}
                                                       {Certificate*}
                                                 {CertificateVerify*}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Certificate*}
          {CertificateVerify*}
          {Finished}                -------->
                                    <--------      [NewSessionTicket]
          [Application Data]        <------->      [Application Data]
```

在 TLS 1.3 握手中，主要能分为 3 个阶段:

- 密钥交换：建立共享密钥数据并选择密码参数。在这个阶段之后所有的数据都会被加密。
- Server 参数：建立其它的握手参数（Client 是否被认证，应用层协议支持等）。
- 认证：认证 Server（并且选择性认证 Client），提供密钥确认和握手完整性。

密钥交换是 ClientHello 和 ServerHello，Server 参数是 EncryptedExtensions 和 CertificateRequest 消息。认证是 Certificate、CertificateVerify、Finished。


Client 发起完整握手流程从 ClientHello 开始：

```c
      uint16 ProtocolVersion;
      opaque Random[32];

      uint8 CipherSuite[2];    /* Cryptographic suite selector */

      struct {
          ProtocolVersion legacy_version = 0x0303;    /* TLS v1.2 */
          Random random;
          opaque legacy_session_id<0..32>;
          CipherSuite cipher_suites<2..2^16-2>;
          opaque legacy_compression_methods<1..2^8-1>;
          Extension extensions<8..2^16-1>;
      } ClientHello;
```

在 ClientHello 结构体重，legacy\_version = 0x0303，0x0303 是 TLS 1.2 的版本号，这个字段规定必须设置成这个值。其他字段和 TLS 1.2 含义相同，不再赘述了。

在 TLS 1.3 的 ClientHello 的 Extension 中，一定会有 supported\_versions 这个字段，如果这个字段，ClientHello 会被解读成 TLS 1.2 的 ClientHello 消息。在 TLS 1.3 中 Server 根据 supported\_versions 这个字段来决定是否协商 TLS 1.3 。

TLS 1.3 之所以能比 TLS 1.2 完整握手减少 1-RTT 的原因就在 ClientHello 中就已经包含了 (EC)DHE 所需要的密钥参数，不需要像 TLS 1.2 中额外用第二次 RTT 来进行 DH 协商参数。在 TLS 1.3 的 ClientHello 的 Extension 中，带有 key\_share 扩展，这个扩展中包含了 Client 所能支持的 (EC)DHE 算法的密钥参数。并且 Extension 中还会有 supported\_groups 扩展，这个扩展表明了 Client 支持的用于密钥交换的命名组。按照优先级从高到低。

Server 收到 ClientHello 以后，回应一条 ServerHello 消息：

```c
      struct {
          ProtocolVersion legacy_version = 0x0303;    /* TLS v1.2 */
          Random random;
          opaque legacy_session_id_echo<0..32>;
          CipherSuite cipher_suite;
          uint8 legacy_compression_method = 0;
          Extension extensions<6..2^16-1>;
      } ServerHello;
```

在 ServerHello 消息中，legacy\_version = 0x0303，这个也是 TLS 1.3 规范的规定，这个值必须固定填 0x0303(TLS 1.2)。Server 会读取 ClientHello 扩展中 "supported\_versions" 扩展字段，如果 Client 能支持 TLS 1.3，那么 Server 在 ServerHello 扩展中的 "supported\_versions" 扩展字段标识可以进行 TLS 1.3 的握手。

Server 在协商 TLS 1.3 之前的版本，必须要设置 ServerHello.version，不能发送 "supported\_versions" 扩展。Server 在协商 TLS 1.3 版本时候，必须发送 "supported\_versions" 扩展作为响应，并且扩展中要包含选择的 TLS 1.3 版本号(0x0304)。还要设置 ServerHello.legacy\_version 为 0x0303(TLS 1.2)。Client 必须在处理 ServerHello 之前检查此扩展(尽管需要先解析 ServerHello 以便读取扩展名)。如果 "supported\_versions" 扩展存在，Client 必须忽略 ServerHello.legacy\_version 的值，只使用 "supported\_versions" 中的值确定选择的版本。如果 ServerHello 中的 "supported\_versions" 扩展包含了 Client 没有提供的版本，或者是包含了 TLS 1.3 之前的版本(本来是协商 TLS 1.3 的，却又包含了 TLS 1.3 之前的版本)，Client 必须立即发送 "illegal\_parameter" alert 消息中止握手。


在 ServerHello 的 Extension 中必须要有的这 2 个扩展，supported\_versions、key\_share(如果是 PSK 会话恢复方式，还必须包含 pre\_shared\_key)。key\_share 扩展标识了 Server 选择了 Client 支持的哪一个椭圆曲线，以及它对应的密钥协商所需参数。这里有两种情况，一种是协商 Diffie-Hellman 参数，具体分析见[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-diffie-hellman-parameters)，另外一种协商是 ECDHE 参数，具体分析见[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-ecdhe-parameters)。

key\_share 传输过程中并没有使用私钥加密，整个过程的不可抵赖和防篡改是通过 CertificateVerify 验证 Server 持有私钥，以及 Finished 消息使用 HMAC 验证历史消息来确定的。

发完 ServerHello 消息以后，Server 会继续发送 EncryptedExtensions 和 CertificateRequest 消息，如果对 Client 不进行认证，就不需要发送 CertificateRequest 消息。上面这 2 条消息都是加密的，通过 server\_handshake\_traffic\_secret 中派生的密钥加密的。

early secret 和 ecdhe secret 导出 server\_handshake\_traffic\_secret。再从 server\_handshake\_traffic\_secret中导出 key 和 iv，使用该 key 和 iv 对 Server hello 之后的握手消息加密。同样的计算 client\_handshake\_traffic\_secret，使用对应的 key 和 iv 进行解密后续的握手消息。

```c
       Early Secret = HKDF-Extract(salt, IKM) = HKDF-Extract(0, PSK) = HKDF-Extract(0, 0)
       Handshake Secret = HKDF-Extract(salt, IKM) = HKDF-Extract(Derive-Secret(Early Secret, "derived", ""), (EC)DHE)

       client_handshake_traffic_secret = Derive-Secret(Handshake Secret, "c hs traffic", ClientHello...ServerHello)
       server_handshake_traffic_secret = Derive-Secret(Handshake Secret, "s hs traffic", ClientHello...ServerHello)

       client_write_key = HKDF-Expand-Label(client_handshake_traffic_secret, "key", "", key_length)
       client_write_iv  = HKDF-Expand-Label(client_handshake_traffic_secret, "iv", "", iv_length)

       server_write_key = HKDF-Expand-Label(server_handshake_traffic_secret, "key", "", key_length)
       server_write_iv  = HKDF-Expand-Label(server_handshake_traffic_secret, "iv", "", iv_length)
```

EncryptedExtensions 消息包含应该被保护的扩展。即，任何不需要建立加密上下文但不与各个证书相互关联的扩展。比如 ALPN 扩展。Client 必须检查 EncryptedExtensions 消息中是否存在任何禁止的扩展，如果有发现禁止的扩展，必须立即用 "illegal\_parameter" alert 消息中止握手。


```c
   Structure of this message:

      struct {
          Extension extensions<0..2^16-1>;
      } EncryptedExtensions;
```

- extensions:      
	扩展列表。
	

CertificateRequest 消息细节，见[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-certificate-request)


接下来 Server 还要继续发送 Certificate、CertificateVerify、Finished 消息。这 3 条消息是握手消息的最后 3 条消息。这 3 条消息使用从 sender\_handshake\_traffic\_secret 派生出来的密钥进行加密。

Server 发送自己的 Certificate 给 Client，在 Certificate 消息中，有 4 种情况，第一种包含了 OCSP Status and SCT Extensions，细节请看[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-ocsp-status-and-sct-extensions)，第二种包含了 Server Certificate Selection，细节请看[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-server-certificate-selection)，第三种包含了 Client Certificate Selection，细节请看[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-client-certificate-selection)，最后一种包含了 Receiving a Certificate Message，细节请看[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#4-receiving-a-certificate-message)。

Server 发送完 Certificate 消息以后，紧接着是 CertificateVerify 消息。Server 将当前所有的握手消息进行签名，具体验证过程见[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-certificate-verify)。


最后一条消息是 Finished 消息。它对提供握手和计算密钥的身份验证起了至关重要的作用。

用于计算 Finished 消息的密钥是使用 HKDF，特别的:

```c
   finished_key =
       HKDF-Expand-Label(BaseKey, "finished", "", Hash.length)
```

BaseKey 是 handshake\_traffic\_secret。

这条消息的数据结构是:

```c
      struct {
          opaque verify_data[Hash.length];
      } Finished;
```

verify\_data 按照如下方法计算:

```c
      verify_data =
          HMAC(finished_key,
               Transcript-Hash(Handshake Context,
                               Certificate*, CertificateVerify*))

      * Only included if present.
```


HMAC [[RFC2104]](https://tools.ietf.org/html/rfc2104) 使用哈希算法进行握手。如上所述，HMAC 输入通常是通过动态的哈希实现的，即，此时仅是握手的哈希。

在以前版本的 TLS 中，verify\_data 的长度总是 12 个八位字节。在 TLS 1.3 中，它是用来表示握手的哈希的 HMAC 输出的大小。


**注意：警报和任何其他非握手记录类型不是握手消息，并且不包含在哈希计算中**。

Finished 消息之后的任何记录都必须在适当的应用程序流量密钥下加密。特别是，这包括 Server 为了响应 Client 的 Certificate 消息和 CertificateVerify 消息而发送的任何 alert。

Finish 消息发送完后，再导出最终对称加密的密钥。从 Handshake Secret 中导出 master secret，再从 master secret 导出两个方向的对称密钥 key 和 iv。

```c
       Master Secret = HKDF-Extract(salt, IKM) = HKDF-Extract(Derive-Secret(Handshake Secret, "derived", ""), 0)
       client_application_traffic_secret_0 = Derive-Secret(Master Secret, "c ap traffic", ClientHello...server Finished)
       server_application_traffic_secret_0 = Derive-Secret(Master Secret, "s ap traffic", ClientHello...server Finished)
```


Finished 消息发送以后，在完整握手的流程中，Server 收到 Client 的 Finished 消息后，验证完后，还需要发送 NewSessionTicket 消息。通过 master secret 和整个握手的摘要，计算最后的 resumption secret。

NewSessionTicket 使用 server\_application\_traffic\_secret 加密。在加密的 ticket过程中，TLS 1.3 相比 TLS 1.2，还包含了当前的创建时间，因此可以方便的配置和验证 ticket 的过期时间。

注意：虽然恢复主密钥取决于 Client 的第二次 flight，但是不请求 Client 身份验证的 Server 可以独立计算转录哈希的剩余部分，然后在发送 Finished 消息后立即发送 NewSessionTicket 而不是等待 Client 的 Finished 消息。这可能适用于 Client 需要并行打开多个 TLS 连接并且可以从减少恢复握手的开销中受益的情况。

```c
      struct {
          uint32 ticket_lifetime;
          uint32 ticket_age_add;
          opaque ticket_nonce<0..255>;
          opaque ticket<1..2^16-1>;
          Extension extensions<0..2^16-2>;
      } NewSessionTicket;
```


- ticket\_lifetime：  
	这个字段表示 ticket 的生存时间，这个时间是以 ticket 发布时间为网络字节顺序的 32 位无符号整数表示以秒为单位的时间。Server 禁止使用任何大于 604800 秒(7 天)的值。值为零表示应立即丢弃 ticket。无论 ticket\_lifetime 如何，Client 都不得缓存超过 7 天的 ticket，并且可以根据本地策略提前删除 ticket。Server 可以将 ticket 视为有效的时间段短于 ticket\_lifetime 中所述的时间段。**这是 TLS 1.2 和 TLS 1.3 的区别，TLS 1.2 中并不包含 ticket 有效时间段(即生存时间)**。

- ticket\_age\_add:  
	安全的生成的随机 32 位值，用于模糊 Client 在 "pre\_shared\_key" 扩展中包含的 ticket 的时间。Client 的 ticket age 以模 2 ^ 32 的形式添加此值，以计算出 Client 要传输的值。Server 必须为它发出的每个 ticket 生成一个新值。

- ticket\_nonce:  
	每一个 ticket 的值，在本次连接中发出的所有的 ticket 中是唯一的。

- ticket:  
	这个值是被用作 PSK 标识的值。ticket 本身是一个不透明的标签。它可以是数据库查找键，也可以是自加密和自我验证的值。

- extensions：  
	ticket 的一组扩展值。Client 必须忽略无法识别的扩展。
	
当前为 NewSessionTicket 定义的唯一扩展名是 "early\_data"，表示该 ticket 可用于发送 0-RTT 数据。 它包含以下值：

- max\_early\_data\_size:  
	这个字段表示使用 ticket 时允许 Client 发送的最大 0-RTT 数据量(以字节为单位)。数据量仅计算应用数据有效载荷(即，明文但不填充或内部内容类型字节)。Server 如果接收的数据大小超过了 max\_early\_data\_size 字节的 0-RTT 数据，应该立即使用 "unexpected\_message" alert 消息终止连接。请注意，由于缺少加密材料而拒绝 early data 的 Server 将无法区分内容中的填充部分，因此 Client 不应该依赖于能够在 early data 记录中发送大量填充内容。


PSK 关联的 ticket 计算方法如下：

```c
       HKDF-Expand-Label(resumption_master_secret,
                        "resumption", ticket_nonce, Hash.length)
```

因为 ticket\_nonce 值对于每个 NewSessionTicket 消息都是不同的，所以每个 ticket 会派生出不同的 PSK。

请注意，原则上可以继续发布新 ticket，该 ticket 无限期地延长生命周期，这个生命周期是最初从初始非 PSK 握手中(最可能与对等证书相关联)派生得到的密钥材料的生命周期。
 

建议实现方对密钥材料这些加上总寿命时间的限制。这些限制应考虑到对等方证书的生命周期，干预撤销的可能性以及自从对等方在线 CertificateVerify 签名到当前时间的这段时间。

完整握手的流程图如下：

![](https://img.halfrost.com/Blog/ArticleImage/122_54.png)

握手完成以后，还可能受到 KeyUpdate 的子消息。这个子消息是负责更新密钥以保证 AEAD 安全性的 Key Update(KU) 消息。

TLS 协议的最终目的是协商出会话过程使用的对称密钥和加密算法，双方最终使用该密钥和对称加密算法对消息进行加密。AEAD（Authenticated\_Encrypted\_with\_associated\_data）是 TLS 1.3 中唯一保留和支持的加密方式。AEAD 将完整性校验和数据加密两种功能集成在同一算法中完成。TLS 1.2 还支持流加密和 CBC 分组模式的块加密方法，使用 MAC 来进行完整性校验数据，这两种方式均被证明有一定的安全缺陷。

但是即使是 AEAD 仍然有[研究表明](http://link.zhihu.com/?target=http%3A//www.isg.rhul.ac.uk/~kp/TLS-AEbounds.pdf)它有一定局限性：使用同一密钥加密的明文达到一定长度后，就不能再保证密文的安全性。因此，TLS 1.3 中引入了密钥更新机制，一方可以（通常是服务器）向另一方发送 Key Update（KU）消息，对方收到消息后对当前会话密钥再使用一次 HKDF，计算出新的会话密钥，使用该密钥完成后续的通信。

>如果想了解更多关于 Key Update 消息的，可以看笔者之前的这篇文章 [《Key and Initialization Vector Update》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update)

## 八. 直观感受 TLS 1.3 首次握手流程

这一章，笔者用 wireshark 抓取 TLS 1.3 握手流程中的数据包，让读者直观感受一下 TLS 1.3 握手流程。

![](https://img.halfrost.com/Blog/ArticleImage/122_21.png)

上图是 TLS 1.3 中的 ClientHello 消息。在这个消息的结构中，与 TLS 1.2 差别主要在扩展上。TLS 1.2 中有的扩展，TLS 1.3 也有，但是 TLS 1.3 中多了一些重要的扩展。

![](https://img.halfrost.com/Blog/ArticleImage/122_22.png)

上图是 TLS 1.3 中 ClientHello 首次完整握手中所有的扩展。

![](https://img.halfrost.com/Blog/ArticleImage/122_23.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_24.png)

展开这些扩展，可以看到，TLS 1.2 中有的扩展，TLS 1.3 都包含。并且数据结构也都没有发生变化。

![](https://img.halfrost.com/Blog/ArticleImage/122_25.png)

这是 TLS 1.3 新增的 key\_share 扩展。在这个扩展中，包含了 Client 所能支持的椭圆曲线类型和对应的 (EC)DHE 密钥协商参数。

![](https://img.halfrost.com/Blog/ArticleImage/122_26.png)

psk\_key\_exchange\_modes 也是 TLS 1.3 中新增的扩展，这个扩展语意是 Client 仅支持使用具有这些模式的 PSK。这就限制了在这个 ClientHello 中提供的 PSK 的使用，也限制了 Server 通过 NewSessionTicket 提供的 PSK 的使用。

psk\_ke: 代表仅 PSK 密钥建立。在这种模式下，Server 不能提供 "key\_share" 值。

psk\_dhe\_ke: PSK 和 (EC)DHE 建立。在这种模式下，Client 和 Server 必须提供 "key\_share" 值。

![](https://img.halfrost.com/Blog/ArticleImage/122_27.png)

supported\_versions 是 TLS 1.3 中必带的扩展，如果没有这个扩展，Server 会认为 Client 只能支持 TLS 1.2，于是接下来的握手会进行 TLS 1.2 的握手流程。

![](https://img.halfrost.com/Blog/ArticleImage/122_28.png)

在 ServerHello 中回应 Client，supported\_versions 扩展中包含了协商以后的协议版本。

![](https://img.halfrost.com/Blog/ArticleImage/122_29.png)

在 ServerHello 中也会带上 Server 的密钥协商参数，放在 key\_share 扩展中。

![](https://img.halfrost.com/Blog/ArticleImage/122_30.png)


![](https://img.halfrost.com/Blog/ArticleImage/122_31.png)

EncryptedExtensions 子消息中会带和任何不需要建立加密上下文但不与各个证书相互关联的扩展，比如这里的 server\_name 和 ALPN 扩展。

![](https://img.halfrost.com/Blog/ArticleImage/122_33.png)

Certificate 消息中会带上 OCSP Response 扩展。

![](https://img.halfrost.com/Blog/ArticleImage/97_20.png)

ChangeCipherSpec 和 Finished 消息与 TLS 1.2 中没有区别。

![](https://img.halfrost.com/Blog/ArticleImage/122_32.png)

首次完整握手完成以后，还会发送 NewSessionTicket 消息。在这个消息中会带 early\_data 的扩展。如果有这个扩展，就表明 Server 可以支持 0-RTT。如果没有带这个扩展，如下图:  

![](https://img.halfrost.com/Blog/ArticleImage/97_21.png)

如果没有带这个扩展，表明 Server 不支持 0-RTT，Client 在下次会话恢复的时候不要发送 early\_data 扩展。

## 九. TLS 1.3 会话恢复


这里网上很多文章对 TLS 1.3 第二次握手有误解。经过自己实践以后发现了“真理”。

TLS 1.3 在宣传的时候就以 0-RTT 为主，大家都会认为 TLS 1.3 再第二次握手的时候都是 0-RTT 的，包括网上一些分析的文章里面提到的最新的 PSK 密钥协商，PSK 密钥协商并非是 0-RTT 的。

TLS 1.3 再次握手其实是分两种：会话恢复模式、0-RTT 模式。非 0-RTT 的会话恢复模式和 TLS 1.2 在耗时上没有提升，都是 1-RTT，只不过比 TLS 1.2 更加安全了。只有在 0-RTT 的会话恢复模式下，TLS 1.3 才比 TLS 1.2 有提升。具体提升对比见下表:  


||HTTP/2 + TLS 1.2 首次连接|HTTP/2 + TLS 1.2 会话恢复|HTTP/2 + TLS 1.3 首次连接|HTTP/2 + TLS 1.3 会话恢复|HTTP/2 + TLS 1.3 0-RTT|
|:---:|:---:|:---:|:---:|:---:|:---:|
|DNS 解析| 1-RTT | 0-RTT | 1-RTT | 0-RTT | 0-RTT |
|TCP 握手| 1-RTT | 1-RTT | 1-RTT | 1-RTT | 1-RTT |
|TLS 握手| 2-RTT | 1-RTT | 1-RTT | 1-RTT | 0-RTT |
|HTTP 请求| 1-RTT | 1-RTT | 1-RTT | 1-RTT | 1-RTT |
|总计| 5-RTT | 3-RTT | 4-RTT | 3-RTT | 2-RTT |

如果开启 TCP 的 TFO，收到第一个 HTTPS 响应包的时间，可以在上表的基础上再减少一个 RTT。

在完整握手中，Client 在收到 Finished 消息以后，还会收到 NewSessionTicket 消息。

```c
      struct {
          uint32 ticket_lifetime;
          uint32 ticket_age_add;
          opaque ticket_nonce<0..255>;
          opaque ticket<1..2^16-1>;
          Extension extensions<0..2^16-2>;
      } NewSessionTicket;
```

Server 将 ticket\_nonce 和发送 Finished 子消息后计算的 resumption\_master\_secret 一起作为 HKDF-Expand-Label 的入参，计算 NewSessionTicket 中的 ticket 字段：

```c
     PskIdentity.identity = ticket 
     					  = HKDF-Expand-Label(resumption_master_secret, "resumption", ticket_nonce, Hash.length)
```

**TLS 1.2 和 TLS 1.3 的区别，TLS 1.2 中 NewSessionTicket 是主密钥，而 TLS 1.3 中 ticket 只是一个 PSK**。Client 收到 NewSessionTicket 以后就可以生成 PskIdentity 了，如果有多个 PskIdentity，就都放在 identities 数组中。binders 数组中是与 identities 顺序一一对应的 HMAC 值 PskBinderEntry。

```c
      struct {
          opaque identity<1..2^16-1>;
          uint32 obfuscated_ticket_age;
      } PskIdentity;

      opaque PskBinderEntry<32..255>;

      struct {
          PskIdentity identities<7..2^16-1>;
          PskBinderEntry binders<33..2^16-1>;
      } OfferedPsks;

      struct {
          select (Handshake.msg_type) {
              case client_hello: OfferedPsks;
              case server_hello: uint16 selected_identity;
          };
      } PreSharedKeyExtension;
```

PskBinderEntry 的计算方法：

```c
	PskBinderEntry = HMAC(binder_key, Transcript-Hash(Truncate(ClientHello1)))
				   = HMAC(Derive-Secret(HKDF-Extract(0, PSK), "ext binder" | "res binder", ""), Transcript-Hash(Truncate(ClientHello1)))
				   
其中     binder_key = Derive-Secret(HKDF-Extract(0, PSK), "ext binder" | "res binder", "")				   
```

HMAC 会包含 PreSharedKeyExtension.identities 字段。也就是说，HMAC 包含所有的 ClientHello，但是不包含 binder list(否则就出现鸡生蛋，蛋生鸡的死循环问题了)。Truncate() 函数的作用是把 ClientHello 中的 binders list 移除。

Client 可以把 PSK 保存到本地 cache 中，serverName 作为 cache 的 key。

### 1. 会话恢复模式

TLS 1.3 中更改了会话恢复机制，废除了原有的 Session ID 和 Session TIcket 的方式，使用 PSK 的机制，同时 New Session Ticket 中添加了过期时间。TLS 1.2 中 的 ticket 不包含过期时间，可以通过 ticket key 的更新让之前所有发送的 ticket 都失效，或者在生成 ticket 的时候加入自定义可以判断过期时间的策略。

在经历了一次完整握手以后，生成了 PSK，下次握手就会进入会话恢复模式，在 Client hello 中，先在本地 cache 中查找 servername 对应的 PSK，找到后在 Client hello 的 pre\_shared\_key 扩展中带上两部分

- Identity: NewSessionTicket 中加密的 ticket
- Binder: 由 PSK 导出 binder\_key，使用 binder\_key 对不包含 binder list 部分的 ClientHello 作 HMAC 计算。

```c
       Early Secret = HKDF-Extract(0, PSK)
       binder_key = Derive-Secret(Early Secret, "ext binder" | "res binder", "")
       client_early_traffic_secret = Derive-Secret(Early Secret, "c e traffic", ClientHello)
       early_exporter_master_secret = Derive-Secret(Early Secret, "e exp master", ClientHello)
```

注意：当存在多种不同类型的扩展的时候，除了 "pre\_shared\_key" 必须是 ClientHello 的最后一个扩展，其他的扩展间的顺序可以是任意的。("pre\_shared\_key" 可以出现在 ServerHello 中扩展块中的任何位置)。不能存在多个同一个类型的扩展。


通过 resumption secret 导出 PSK。PSK 会最终导出 earlyData 的加密密钥，以及 pre\_shared\_key 扩展中 binder 的 HMAC 密钥。发送 ClientHello 后，使用 resumption secret 导出的 PskIdentity.identity 生成 PSK，进而导出 client\_early\_traffic\_secret 密钥，再生成 Key 和 IV，对 early data 加密后发送。


Server 收到带有 PSK 的 ClientHello 以后，生成协商之后的 keyshare，并检查 Client hello 中的 pre\_shared\_key 扩展，解密 PskIdentity.identity(即 ticket)，查看该 ticket 是否过期，各项检查通过以后，由 PSK 导出 binder\_key 并计算 client hello 的 HMAC，检查 binder 是否正确。验证完 ticket 和 binder 之后，在 ServerHello 扩展中带上 pre\_shared\_key 扩展，标识使用哪个 PSK 进行会话恢复。和 Client 一样，从 resumtion secret 开始导出 PSK，最终导出 earlyData 使用的密钥。后续的密钥导出规则和完整握手是一样的，唯一的区别就是会话恢复多了 PSK，它是作为 early secret 的输入密钥材料 IKM。

TLS 1.3 和 TLS 1.2 在会话恢复的密钥导出上有很大不同，TLS 1.2 会话恢复会直接使用之前的 master secret，然后生成会话密钥(密钥块)。TLS 1.3 只会利用 resumption secret 导出 early data 密钥的输入密钥材料 IKM —— PSK，之后的密钥导出规则和 TLS 1.3 完整握手是一样的。


发送完 ServerHello 以后，还需要继续发送 EncryptedExtensions 和 Finished 消息。不过会话恢复模式就不需要再发送 Certificate 和 CerficateVerify 消息了。只要证明了双方都持有相同的 PSK，就不再需要证书认证来证明双方的身份，这样看来，PSK 也算是一种身份认证机制。


流程图如下：

```c
          Client                                               Server

   Initial Handshake:
          ClientHello
          + key_share               -------->
                                                          ServerHello
                                                          + key_share
                                                {EncryptedExtensions}
                                                {CertificateRequest*}
                                                       {Certificate*}
                                                 {CertificateVerify*}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Certificate*}
          {CertificateVerify*}
          {Finished}                -------->
                                    <--------      [NewSessionTicket]
          [Application Data]        <------->      [Application Data]


   Subsequent Handshake:
          ClientHello
          + key_share*
          + pre_shared_key          -------->
                                                          ServerHello
                                                     + pre_shared_key
                                                         + key_share*
                                                {EncryptedExtensions}
                                                           {Finished}
                                    <--------     [Application Data*]
          {Finished}                -------->
          [Application Data]        <------->      [Application Data]
```

笔者之前写过一篇关于 PSK 细节分析的文章，如果读者感兴趣，可以看[《Pre-Shared Key Extension》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension)。这里简单描述一下 PSK 扩展。

"pre\_shared\_key" 扩展用来协商标识的，这个标识是与 PSK 密钥相关联的给定握手所使用的预共享密钥的标识。


这个扩展中的 "extension\_data" 字段包含一个 PreSharedKeyExtension 值:

```c
      struct {
          opaque identity<1..2^16-1>;
          uint32 obfuscated_ticket_age;
      } PskIdentity;

      opaque PskBinderEntry<32..255>;

      struct {
          PskIdentity identities<7..2^16-1>;
          PskBinderEntry binders<33..2^16-1>;
      } OfferedPsks;

      struct {
          select (Handshake.msg_type) {
              case client_hello: OfferedPsks;
              case server_hello: uint16 selected_identity;
          };
      } PreSharedKeyExtension;
```

- identity:  
	key 的标签。例如，一个 ticket 或者是一个外部建立的预共享密钥的标签。
	
- obfuscated\_ticket\_age:  
	age of the key 的混淆版本。[这一章节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-ticket-age)描述了通过 NewSessionTicket 消息建立，如何为标识(identities)生成这个值。对于外部建立的标识(identities)，应该使用 0 的 obfuscated\_ticket\_age，并且 Server 也必须忽略这个值。


- identities:  
	Client 愿意和 Server 协商的 identities 列表。如果和 "early\_data" 一起发送，第一个标识被用来标识 0-RTT 的。
	

- binders:  
	一系列的 HMAC 值。和 identities 列表中的每一个值都一一对应，并且顺序一致。

- selected\_identity:  
	Server 选择的标识，这个标识是以 Client 列表中标识表示为基于 0 的索引。

每一个 PSK 都和单个哈希算法相关联。对于通过 ticket 建立的 PSK，当 ticket 在连接中被建立，这时候用的哈希算法是 KDF 哈希算法。对于外部建立的 PSK，当 PSK 建立的时候，哈希算法必须设置，如果没有设置，默认算法是 SHA-256。Server 必须确保它选择的是兼容的 PSK (如果有的话) 和密钥套件。


在接受PSK密钥建立之前，Server 必须先验证相应的 binder 值。如果这个值不存在或者未验证，则 Server 必须立即中止握手。Server 不应该尝试去验证多个 binder，而应该选择单个 PSK 并且仅验证对应于该 PSK 的 binder。为了接受 PSK 密钥建立连接，Server 发送 "pre\_shared\_key" 扩展，标明它所选择的 identity。


Client 必须验证 Server 的 selected\_identity 是否在 Client 提供的范围之内。Server 选择的加密套件标明了与 PSK 关联的哈希算法，如果 ClientHello "psk\_key\_exchange\_modes" 有需要，Server 还应该发送 "key\_share" 扩展。如果这些值不一致，Client 必须立即用 "illegal\_parameter" alert 消息中止握手。


如果 Server 提供了 "early\_data" 扩展，Client 必须验证 Server 的 selected\_identity 是否为 0。如果返回任何其他值，Client 必须使用 "illegal\_parameter" alert 消息中止握手。


"pre\_shared\_key" 扩展必须是 ClientHello 中的最后一个扩展(这有利于下面的描述的实现)。Server 必须检查它是最后一个扩展，否则用 "illegal\_parameter" alert 消息中止握手。


#### (1) Ticket Age


从 Client 的角度来看，ticket 的时间指的是，收到 NewSessionTicket 消息开始到当前时刻的这段时间。Client 决不能使用时间大于 ticket 自己标明的 "ticket\_lifetime" 这个时间的 ticket。每个 PskIdentity 中的 "obfuscated\_ticket\_age" 字段都必须包含 ticket 时间的混淆版本，混淆方法是用 ticket 时间(毫秒为单位)加上 "ticket\_age\_add" 字段，最后对 2^32 取模。除非这个 ticket 被重用了，否则这个混淆就可以防止一些相关联连接的被动观察者。注意，NewSessionTicket 消息中的 "ticket\_lifetime"  字段是秒为单位，但是 "obfuscated\_ticket\_age" 是毫秒为单位。因为 ticke lifetime 限制为一周，32 位就足够去表示任何合理的时间，即使是以毫秒为单位也可以表示。


#### (2) PSK Binder

PSK binder 的值形成了 2 种绑定关系，一种是 PSK 和当前握手的绑定，另外一种是 PSK 产生以后(如果是通过 NewSessionTicket 消息)的握手和当前握手的绑定。每一个在 binder 列表中的条目都会根据有一部分 ClientHello 的哈希副本计算 HMAC，最终 HMAC 会包含 PreSharedKeyExtension.identities 字段。也就是说，HMAC 包含所有的 ClientHello，但是不包含 binder list 。如果存在正确长度的 binders，消息的长度字段（包括总长度，扩展块的长度和 "pre\_shared\_key" 扩展的长度）都被设置。


PskBinderEntry 的计算方法和 Finished 消息一样。但是 BaseKey 是派生的 binder\_key，派生方式是通过提供的相应的 PSK 的密钥派生出来的。

如果握手包括 HelloRetryRequest 消息，则初始的 ClientHello 和 HelloRetryRequest 随着新的 ClientHello 一起被包含在副本中。例如，如果 Client 发送 ClientHello，则其 binder 将通过以下方式计算：

```c
      Transcript-Hash(Truncate(ClientHello1))
```

Truncate() 函数的作用是把 ClientHello 中的 binders list 移除。

如果 Server 响应了 HelloRetryRequest，那么 Client 会发送 ClientHello2，它的 binder 会通过以下方式计算：

```c
      Transcript-Hash(ClientHello1,
                      HelloRetryRequest,
                      Truncate(ClientHello2))
```

完整的 ClientHello1/ClientHello2 都会包含在其他的握手哈希计算中。请注意，在第一次发送中，`Truncate(ClientHello1)` 是直接计算哈希的，但是在第二次发送中，ClientHello1 计算哈希，并且还会再注入一条 "message\_hash" 消息。

关于会话恢复密钥的一些计算流程表示出来如下：

```c
             0
             |
             v
   PSK ->  HKDF-Extract = Early Secret
             |
             +-----> Derive-Secret(., "ext binder" | "res binder", "")
             |                     = binder_key
             |
             +-----> Derive-Secret(., "c e traffic", ClientHello)
             |                     = client_early_traffic_secret
             |
             +-----> Derive-Secret(., "e exp master", ClientHello)
             |                     = early_exporter_master_secret
             v
       Derive-Secret(., "derived", "")
             |
             v
```

PSK 会话恢复的流程图如下：

![](https://img.halfrost.com/Blog/ArticleImage/122_55_.png)

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

从历史来看，人们从功能问题讨论到性能问题，最后讨论到安全问题。


据 Google 统计，全网有 60% 的网站访问流量是来自于新访问的网站和过去曾经访问过但是隔了一段时间再次访问。这部分流量在 TLS 1.3 的优化下，已经从 2-RTT 降低到 1-RTT 了。剩下 40% 的网站访问流量是来自于会话恢复，TLS 1.3 废除了之前的 Session ID 和 Session Ticket 的会话恢复的方式，统一成了 PSK 方式，使得原有会话恢复变的更加安全。但是 TLS 1.3 的会话恢复并没有降低 RTT，依旧停留在了 1-RTT。为了进一步降低延迟，于是提出了 0-RTT 的概念。0-RTT 能让用户有更快更顺滑更好的用户体验，在移动网络上更加明显。


TLS 1.3 的里程碑标志就是添加了 0-RTT 会话恢复模式。也就是说，当 client 和 server 共享一个 PSK（从外部获得或通过一个以前的握手获得）时，TLS 1.3 允许 client 在第一个发送出去的消息中携带数据（"early data"）。Client 使用这个 PSK 生成 client\_early\_traffic\_secret 并用它加密 early data。Server 收到这个 ClientHello 之后，用 ClientHello 扩展中的 PSK 导出 client\_early\_traffic\_secret 并用它解密 early data。

0-RTT 会话恢复模式如下：

```c
         Client                                               Server

         ClientHello
         + early_data
         + key_share*
         + psk_key_exchange_modes
         + pre_shared_key
         (Application Data*)     -------->
                                                         ServerHello
                                                    + pre_shared_key
                                                        + key_share*
                                               {EncryptedExtensions}
                                                       + early_data*
                                                          {Finished}
                                 <--------       [Application Data*]
         (EndOfEarlyData)
         {Finished}              -------->
         [Application Data]      <------->        [Application Data]
```

想实现 0-RTT 也是有一些条件的，条件比较苛刻，如果条件有一条不满足，会话恢复都只能是 1-RTT 的 PSK 会话恢复模式。

0-RTT 的**开启条件**是：

- 1. Server 在前一次完整握手中，发送了 NewSessionTicket，并且 Session ticket 中存在max\_early\_data\_size 扩展表示愿意接受 early data。如果没有这个扩展，0-RTT 无法开启。
- 2. 在 PSK 会话恢复的过程中，ClientHello 的扩展中配置了 early data 扩展，表示 Client 想要开启 0-RTT 模式。
- 3. Server 在 Encrypted Extensions 消息中携带了 early data 扩展表示同意读取 early data。0-RTT 模式开启成功。

只有同时满足了上面 3 个条件，才能开启 0-RTT 会话恢复模式。否则握手会是 1-RTT 的会话恢复模式。

>目前不少浏览器虽然支持 TLS 1.3 协议，但是还不支持发送 early data，所以它们也没法启用 0-RTT 模式的会话恢复。


从 0-RTT 的开启条件中就能看出它和上面 1-RTT 会话恢复的区别。ClientHello 中需要带 early\_data 的扩展，Server 要在 Encrypted Extensions 消息中携带了 early\_data 扩展，Client 发送完 early\_data 数据以后，还需要回一个 EndOfEarlyData 的子消息。

```c
      struct {} EndOfEarlyData;
```

Client 在发送 early\_data 之后，可以一直发 early\_data 数据。如果 Server 在 EncryptedExtensions 中发送了 "early\_data" 扩展，则 Client 必须在收到 Server 的 Finished 消息后发送 EndOfEarlyData 消息。 如果 Server 没有在 EncryptedExtensions中发送 "early\_data" 扩展，那么 Client 禁止发送 EndOfEarlyData 子消息。此消息表示已传输完了所有 0-RTT application\_data消息(如果有)，并且接下来的记录受到握手流量密钥的保护。Server 不能发送此消息，Client 如果收到了这条消息，那么必须使用 "unexpected\_message" alert 消息终止连接。这条消息使用从 client\_early\_traffic\_secret 中派生出来的密钥进行加密保护。

**注意**: early data 并不参与最后的 Finished 校验计算，其次，EndOfEarlyData 子消息也不参与最后 application traffic secret 的计算。

Server 在接收到 ClientHello 以后，应立即发送 ServerHello、ChangeCipherSpec、EncryptedExtensions、Finished 子消息。


Server 想拒绝 Client 的 0-RTT 会话恢复，只要打破 3 个开启条件即可：

- 拒绝 PSK。Server 在 ServerHello 中不加入 pre\_shared\_key 扩展，那么握手就会回退到完整握手，自然拒绝了 0-RTT。
- 只拒绝 early\_data，接受 PSK。在 ServerHello 中，加入 pre\_shared\_key 扩展，但是EncryptedExtension 子消息中不加入 early\_data 扩展。

Client 即使发送握手消息还是带有 early\_data 扩展，但是 Server 导出的密钥已经是 server/client\_handshake\_traffic\_secret 而不是 client\_early\_traffic\_secret 了，也无法解密 early\_data 内容。解密失败出现错误就丢弃这个扩展，忽略它。于是 0-RTT 就会降级到 1-RTT。

0-RTT 握手的流程图如下：

![](https://img.halfrost.com/Blog/ArticleImage/122_56_.png)


虽然 TLS 1.3 革命性的提出了 0-RTT 会话恢复模式，但是 0-RTT 存在安全性风险。0-RTT 数据安全性比其他类型的 TLS 数据要弱一些，特别是：

1. 0-RTT 的数据是没有前向安全性的，它使用的是被提供的 PSK 中导出的密钥进行加密的。
2. 在多个连接之间不能保证不存在重放攻击。普通的 TLS 1.3 1-RTT 数据为了防止重放攻击的保护方法是使用 server 下发的随机数，现在 0-RTT 不依赖于 ServerHello 消息，因此保护措施更差。如果数据与 TLS client 认证或与应用协议里一起验证，这一点安全性的考虑尤其重要。这个警告适用于任何使用 early\_exporter\_master\_secret 的情况。


TLS 1.3 0-RTT 中要预防重放攻击。预防 0-RTT 有 4 种措施：

- 第一个措施检查 PSK 中的过期时间，如果过期了，就不处理 early\_data 中的请求，并且将握手降级到 1-RTT。

- 第二个措施是不允许非幂等性的请求出现在 0-RTT 中，如果出现了非幂等性的请求，Server 将会忽略不处理，GET 请求是幂等性的，但是也不能允许后面带参数，不带参数的 GET 请求才能允许。

- 第三个措施是，在请求头中记录 PSK binder 的值或者一个随机值，这个值能保证 0-RTT 的 early\_data 全局唯一，这样就可以防止重放攻击。当收到 ClientHello 时，Server 首先验证 PSK binder。然后它会计算 expected\_arrival\_time，如果它在记录窗口之外，则拒绝 0-RTT，然后回到 1-RTT 握手。如果 expected\_arrival\_time 在窗口中，则 Server 检查它是否记录了匹配的 ClientHello。如果找到一个，它将使用 "illegal\_parameter" alert 消息中止握手或接受 PSK 但拒绝 0-RTT。如果找不到匹配的 ClientHello，则它接受 0-RTT，然后只要 expected\_arrival\_time 在窗口内，就存储 ClientHello。Server 也可以实现具有误报的数据存储，例如布隆过滤器，在这种情况下，它们必须通过拒绝 0-RTT 来响应明显的重放，但绝不能中止握手。关于这一个措施，还可能存在多个 binder 的情况，如果是分布式系统，还会存在多个 zone 的问题，具体分析见笔者这篇文章 [《TLS 1.3 0-RTT and Anti-Replay》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md)。

- 第四个措施是，在数据库里面记录所有未完成有效的 ticket，使用一次就删除掉，如果产生重放攻击，那么这个 ticket 必然是数据库里面查不到的，那么就回退到完整握手。


> 关于 0-RTT 安全性的问题，笔者专门写了一篇文章探讨这个问题，见[《TLS 1.3 0-RTT and Anti-Replay》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md)


## 十. 直观感受 TLS 1.3 会话恢复

这一章，笔者用 wireshark 抓取 TLS 1.3 会话恢复中的数据包，让读者直观感受一下 TLS 1.3 会话恢复流程。


### 1. PSK 会话恢复


![](https://img.halfrost.com/Blog/ArticleImage/122_34.png)

这是 TLS 1.3 会话恢复的完整流程。

![](https://img.halfrost.com/Blog/ArticleImage/122_35.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_36.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_37.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_38.png)

上面这 4 个扩展是 TLS 1.3 PSK 会话恢复中 ClientHello 必须配置的。psk\_key\_exchange\_modes、pre\_shared\_key、key\_share、supported\_versions。

![](https://img.halfrost.com/Blog/ArticleImage/122_39.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_40.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_41.png)

上面这 3 个扩展是 TLS 1.3 PSK 会话恢复中 ServerHello 必须配置的。pre\_shared\_key、key\_share、supported\_versions。

![](https://img.halfrost.com/Blog/ArticleImage/122_42.png)

一旦 PSK 校验完成，Server 就不需要再次发送证书了，直接回应 ChangeCipherSpec、Encrypted Extensions、Finished 即可完成会话恢复。

### 2. 0-RTT

截止到笔者写这篇文章为止，当前主流浏览器对 TLS 1.3 的支持度如下图。

![](https://img.halfrost.com/Blog/ArticleImage/122_53.png)

Google Chrome Canary 最新 74.0.3702.0 还不能支持 0-RTT 模式，Firefox Nightly 最新 67.0a1 可以支持 0-RTT 模式(在 about:config 中 security.tls.enable\_0rtt\_data 设置为 true)，Safari 最新的 12.0.3 (14606.4.5) 还不能支持 0-RTT 模式。所以笔者只能用 Firefox Nightly 抓取 0-RTT 的包。

当然 OpenSSL 最新版 1.1.1a 的 Client 是支持发送 early\_data 的，也就是支持 0-RTT 的，用它来调试 TLS 1.3 0-RTT 也更加方便。

先来看看支持 0-RTT 的 Firefox Nightly 抓到的包是怎么样的。


![](https://img.halfrost.com/Blog/ArticleImage/122_43_.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_44.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_45.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_46.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_47.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_48.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_49.png)

![](https://img.halfrost.com/Blog/ArticleImage/122_50.png)

可以发现整个会话恢复过程满足了 0-RTT 的条件，所以 0-RTT 开启成功。

在用 OpenSSL 的 Client 来测试测试 0-RTT。

先将必要参数导出来，比如协商的密钥和 session 信息。

```c
$ openssl s_client -connect halfrost.com:443 -tls1_3 -keylogfile=/Users/ydz/Documents/sslkeylog.log -sess_out=/Users/ydz/Documents/tls13.sess
```

输出如下:

```c
CONNECTED(00000006)
depth=1 C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
verify error:num=20:unable to get local issuer certificate
---
Certificate chain
 0 s:CN = halfrost.com
   i:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
 1 s:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
   i:O = Digital Signature Trust Co., CN = DST Root CA X3
 2 s:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
   i:O = Digital Signature Trust Co., CN = DST Root CA X3
---
Server certificate
-----BEGIN CERTIFICATE-----
MIIEljCCA36gAwIBAgISA9VdA6rPN6mIzBxEPL/3iAICMA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xOTAyMTAwMTQxMjJaFw0x
OTA1MTEwMTQxMjJaMBcxFTATBgNVBAMTDGhhbGZyb3N0LmNvbTBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABA7sYzIwq29BkT1mQ2TSZRPe34BlnuqN65xoLY+A87M8
PpblV0IvNyj4ZdcgiSmSZffocVF6wzck6TmsQ/j2/sujggJyMIICbjAOBgNVHQ8B
Af8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB
/wQCMAAwHQYDVR0OBBYEFOD4YIpf+PkD1Jvy+eayPn0csEi/MB8GA1UdIwQYMBaA
FKhKamMEfd265tE5t6ZFZe/zqOyhMG8GCCsGAQUFBwEBBGMwYTAuBggrBgEFBQcw
AYYiaHR0cDovL29jc3AuaW50LXgzLmxldHNlbmNyeXB0Lm9yZzAvBggrBgEFBQcw
AoYjaHR0cDovL2NlcnQuaW50LXgzLmxldHNlbmNyeXB0Lm9yZy8wKQYDVR0RBCIw
IIIMaGFsZnJv\ghfhjghjjbmd3cuaGFsZnJvc3QuY29tMEwGA1UdIARFMEMwCAYG
Z4EMAQIBMDcGCysGAQQBgt8TAQEBMCgwJgYIKwYBBQUHAgEWGmh0dHA6Ly9jcHMu
bGV0c2VuY3J5cHQub3JnMIIBAwYKKwYBBAHWeQIEAgSB9ASB8QDvAHUA4mlLribo
6UAJ6IYbtjuD1D7n/nSI+6SPKJMBnd3x2/4AAAFo1UfZTgAABAMARjBEAiAsXJLC
A5uO2R926Dba3fZpV/zvzG9tCPVtTKAeso5bAwIgMXoLRtLqhG5bEcXIpGXJcrd0
6S8tbUdS9YRAIWpMX1oAdgApPFGWVMg5ZbqqUPxYB9S3b79Yeily3KTDDPTlRUf0
eAAAAWjVR9lQAAAEAwBHMEUCIHv6NJ9MWMiL+AHxU8ilL3APMmPkUcc03SjBiDaW
Vm6JAiEA5YF/XHKuYH0S0+mqfB+YdT0FIey9wFQObkR4/Qvzla4wDQYJKoZIhvcN
AQELBQADggEBAHU7a+EgzdhrsyD+2ch7AGD1n1TjDfdxkEjmoitN0Tjh4q3jP/IK
7FPs0LBsDRusmtJVK3gZQc9cTEy/om86VQtcnV0LhK83GnFUIuLTEzeTZmnz6Qbs
3KznprZH0DRUbfpmZsDNIfBEOUOXiBR4DpLd3tPVfRkQowmO6o39vM4UOGlB0zIA
g977q97IT6wS9BCEiGmuF0HSjpLfiPhTy9bpl2VGcJVpIy2TS+d4+JWRI7K5BFSz
ncGDzHJ+zGsx4wS+dxuiwaS9hw4c0FG2V4kMFnA+orAa/oTnfwFlRIehTbDBO+rN
TNtjm4yh63M9gInoQEI1REl2EkGcWug6Ijs=
-----END CERTIFICATE-----
subject=CN = halfrost.com

issuer=C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3

---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: ECDSA
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 3912 bytes and written 316 bytes
Verification error: unable to get local issuer certificate
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 256 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 20 (unable to get local issuer certificate)
---
---
Post-Handshake New Session Ticket arrived:
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
    Session-ID: DECE5063ABC2D1162A5E767C55083FDFFA6A86B64082FE3AD990A213AE
    Session-ID-ctx:
    Resumption PSK: EACCC93ACB3DC420DF5027BEC576EE130D11BF546463034C1BB92B54806057E0C9F5C3DB557AD10D425E
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket lifetime hint: 86400 (seconds)
    TLS session ticket:
    0000 - 0b 8d e5 44 b2 62 71 9d-f9 0a ec da f0 d0 6a 0b   ...D.bq.......j.
    0010 - 97 5d 63 21 ea 1e 8a 69-01 52 a9 0a 19 bf 5c a3   .]c!...i.R....\.
    0020 - 67 45 a3 a0 28 65 ea 9c-c8 d4 cf df 5d c5 5a be   gE..(e......].Z.
    0030 - 32 45 0d 1e af f7 32 67-4a d8 66 cb b6 cb c8 0e   2E....QgJ.f.....
    0040 - 6b b8 53 a8 d2 d4 4b 7b-cc a6 cb 52 39 61 20 6d   k.S...K{...R9a m
    0050 - 75 f8 cb 43 11 1d 58 a2-de 2b 74 b0 ca 70 a2 9c   u..C..X..+t..p..
    0060 - 85 6b 1a 00 9a f1 bd 9b-8c b4 5a 41 aa 4b 64 5d   .k........ZA.Kd]
    0070 - 5a 48 23 a6 10 49 4f 61-c9 57 74 f4 56 50 83 1a   ZH#..IOa.Wt.VP..
    0080 - 1b 74 6c ea 09 99 42 f5-d6 3c 6d 4f 5b 98 ca b3   .tl...B..<mO....
    0090 - c7 72 56 5c 6c 67 71 77-8d 68 f7 54 e5 e3 7b d3   .rV\lgqw.h.T..{.
    00a0 - 24 ff 42 0c 3f 12 27 42-7f 9e 0a 4c c2 79 60 45   $.B.?.'B...L.y`E
    00b0 - 2d 77 a2 c8 2f f5 85 34-fa ce 79 ee 0b ea 00 c1   -w../..4..y.....
    00c0 - 74 33 f0 6c af 7a 1a 55-f8 35 bd 5e 49 66 6f 06   t3.l.z.U.5.^Ifo.
    00d0 - c6 38 ed a6 82 e2 c8 77-99 b7 34 9a 4a 9a 31 40   .8.....w..4.J.1@
    00e0 - f1 93 a0 94 7f 1e 8d e0-54 29 dc e3 6f 5c 93 21   ........T)..o\.!

    Start Time: 1549886406
    Timeout   : 7200 (sec)
    Verify return code: 20 (unable to get local issuer certificate)
    Extended master secret: no
    Max Early Data: 16384
---
read R BLOCK
---
Post-Handshake New Session Ticket arrived:
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
    Session-ID: B7E28DE5DF2C95F2E3DE43732E4F9A45A8943ED3856B73CAB5E7260E7
    Session-ID-ctx:
    Resumption PSK: BF2BA2304BEB2B948F7BF6617D0KDRNFB9CD5466DEC1EB9697D2543B7BB913BC7854359D7F5DF7559D67
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket lifetime hint: 86400 (seconds)
    TLS session ticket:
    0000 - 0b 8d e5 44 b2 62 71 9d-f9 0a ec da f0 d0 6a 0b   ...D.bq.......j.
    0010 - b4 9f cc 17 63 9a 70 c8-63 f8 2e c4 9f d4 a1 f8   ....c.p.c.......
    0020 - 22 34 22 03 d0 f9 78 66-a0 d4 2f 62 53 d3 d8 e3   "4"...xf../bS...
    0030 - 55 2c a5 7c 0b 19 b3 fc-77 55 8c de 0b 2d 00 bd   U,.|....wUL..-..
    0040 - b8 fa 2e 00 30 78 c8 dc-35 14 d3 61 f0 69 38 59   ...%0x..5..a.i8Y
    0050 - ee 2a 75 7e 50 34 3f e3-25 04 71 1c 6e c9 c8 20   .*u~P4?.%.q.n..
    0060 - d7 4e 44 b3 69 56 50 23-38 c2 f1 1e ac 10 a7 ff   .ND.iVP#8.......
    0070 - 96 cf fe ff 4d 07 7e 08-2d 37 49 78 ab 1d 78 6e   ....M.~.-7Ix..xn
    0080 - 62 4b 99 e7 37 03 3e a2-89 de 61 48 a1 c5 77 18   bK..7.>...aH..w.
    0090 - 6f 1c 95 8a 0d 1d 17 68-88 8a 01 5b f0 dc ea 06   o......h...[....
    00a0 - 98 dc 7e 94 f8 ef 4a 72-ff ba e5 03 07 c7 3d d0   ..~...Jr......=.
    00b0 - c8 91 a6 ae 9a df 92 25-05 63 77 03 b0 bc b4 ab   .......%.c......
    00c0 - 36 cb 0f 8c 5d ec 58 65-7c 97 2a 30 57 4a 96 b9   6...].Xe|.*0WJ..
    00d0 - 60 21 12 76 77 4c 6d 0d-12 0c 50 cc f5 da 54 4e   `!.vwLm...P...TN
    00e0 - 4b 27 5f 1b dd 11 b1 8d-7f e0 37 43 34 a3 88 34   K'_.......7C4..4

    Start Time: 1549886406
    Timeout   : 7200 (sec)
    Verify return code: 20 (unable to get local issuer certificate)
    Extended master secret: no
    Max Early Data: 16384
---
read R BLOCK
```

接下来在复用刚刚的连接，命令如下:

```c
$ openssl s_client -connect halfrost.com:443 -tls1_3 -keylogfile=/Users/ydz/Documents/sslkeylog.log -sess_in=/Users/ydz/Documents/tls13.sess -early_data=/Users/ydz/Documents/req.txt
```

req.txt 里面只是简单的写一个 GET 请求:

```c
GET / HTTP/1.1
HOST: halfrost.com
Early-Data: 657567765
```


执行 s\_client 以后，输出如下:


```c
CONNECTED(00000006)
---
Server certificate
-----BEGIN CERTIFICATE-----
MIIElzCCA3+gAwIBAgISA604VEs+7Wwch5cNQDshC4t+MA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xODEyMDgxMzQzMzhaFw0x
OTAzMDgxMzQzMzhaMBcxFTATBgNVBAMTDGhhbGZyb3N0LmNvbTBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABA7sYzIwq29BkT1mQ2TSZRPe34BlnuqN65xoLY+A87M8
PpblV0IvNyj4ZdcgiSmSZffocVF6wzck6TmsQ/j2/sujggJzMIICbzAOBgNVHQ8B
Af8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB
/wQCMAAwHQYDVR0OBBYEFOD4YIpf+PkD1Jvy+eayPn0csEi/MB8GA1UdIwQYMBaA
FKhKamMEfd265tE5t6ZFZe/zqOyhMG8GCCsGAQUFBwEBBGMwYTAuBggrBgEFBQcw
AYYiaHR0cDovL29jc3AuaW50LXgzLmxldHNlbmNyeXB0Lm9yZzAvBggrBgEFBQcw
AoYjaHR0cDovL2NlcnQuaW50LXgzLmxldHNlbmNyeXB0Lm9yZy8wKQYDVR0RBCIw
IIIMaGFsZnJvc3QuY29tghB3d3cuaGFsZnJvc3QuY29tMEwGA1UdIARFMEMwCAYG
Z4EMAQIBMDcGCysGAQQBgt8TAQEBMCgwJgYIKwYBBQUHAgEWGmh0dHA6Ly9jcHMu
bGV0c2VuY3J5cHQub3JnMIIBBAYKKwYBBAHWeQIEAgSB9QSB8gDwAHUA4mlLribo
73qkwe6lN9vZWu1dJV8+Q41cFLGYMJhDD56x7QIgL+V6g1CQst9UDXobdkAEnjah
KiJWihr/Qn3plzgzjiIAdwApPFGWVMg5ZbqqUPxYB9S3b79Yeily3KTDDPTlRUf0
eAAAAWeORhq2AAAEAwBIMEYCIQD1Mf1GtmegyTqIu0S3Q4afNDt0srIFyrtROtn0
jQAV1gIhAJwXIGyMj87kjHtRc/mHJOOCZRSUvoasvWrytCv2dPwXMA0GCSqGSIb3
DQEBCwUAA4IBAQB3sC7jKVGHR8MnAOWnECO/V5Z4oBqbahogwyhOSrbxuutijhyk
8kb3A73Q++Ey150Y+hlNUQStmG9JBGg9pyLG2Yug9p5L13a6VrNaL1VQ1Dq6YgS5
5J8ElsalUgr+9jvTJesdYzfXPdsc8IK67tBXhukqc0/cT3I1QHNwAVru/AKWrkne
H4AcadSeLGe5he2X9OV3JJg+gb/vE90UaVmqwUuSGMzluyBXPMuznTa/+7+31vWV
Q8aWE32X+E5qHSyeLU808mZHYjvKHvuDnNNu6I0KlNcVJf1s0jOQOjgo7hIP/OR4
OlW6ywk07IupV4w07xykP1/tWBsSCviXECcZ
-----END CERTIFICATE-----
subject=CN = halfrost.com

issuer=C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3

---
No client certificate CA names sent
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 245 bytes and written 649 bytes
Verification error: unable to get local issuer certificate
---
Reused, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 256 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was accepted
Verify return code: 20 (unable to get local issuer certificate)
---
```

从输出中可以看到 `Early data was accepted`。这个时候转到 wireshark，看抓到的包是怎么样的。

![](https://img.halfrost.com/Blog/ArticleImage/122_52.png)

可以看到 Client 在 ClientHello 之后，就立即发送了 Application Data。

在 wireshark 中首选项，把下图中的勾去掉。

![](https://img.halfrost.com/Blog/ArticleImage/122_57.png)

配置生效以后，可以看到 Application Data 里面的请求了。

![](https://img.halfrost.com/Blog/ArticleImage/122_51.png)

普通的 GET 请求中 header 中带了 Early-Data 的值。这个值就会传给 Server 处理了。




## 十一. TLS 1.3 的状态机

TLS 1.3 相对 TLS 1.2 握手流程发生了巨大的变化，所以状态机也发生了巨大的变化。下面放 2 张状态流转图，最为总结，对应的也是本篇文章的精华。


```c
                              START <----+
               Send ClientHello |        | Recv HelloRetryRequest
          [K_send = early data] |        |
                                v        |
           /                 WAIT_SH ----+
           |                    | Recv ServerHello
           |                    | K_recv = handshake
       Can |                    V
      send |                 WAIT_EE
     early |                    | Recv EncryptedExtensions
      data |           +--------+--------+
           |     Using |                 | Using certificate
           |       PSK |                 v
           |           |            WAIT_CERT_CR
           |           |        Recv |       | Recv CertificateRequest
           |           | Certificate |       v
           |           |             |    WAIT_CERT
           |           |             |       | Recv Certificate
           |           |             v       v
           |           |              WAIT_CV
           |           |                 | Recv CertificateVerify
           |           +> WAIT_FINISHED <+
           |                  | Recv Finished
           \                  | [Send EndOfEarlyData]
                              | K_send = handshake
                              | [Send Certificate [+ CertificateVerify]]
    Can send                  | Send Finished
    app data   -->            | K_send = K_recv = application
    after here                v
                          CONNECTED
```

这图是 Client 在握手流程上的状态机。如果读者还不清楚中间的某个步骤，可以对照上文中的内容查缺补漏。

```c
                              START <-----+
               Recv ClientHello |         | Send HelloRetryRequest
                                v         |
                             RECVD_CH ----+
                                | Select parameters
                                v
                             NEGOTIATED
                                | Send ServerHello
                                | K_send = handshake
                                | Send EncryptedExtensions
                                | [Send CertificateRequest]
 Can send                       | [Send Certificate + CertificateVerify]
 app data                       | Send Finished
 after   -->                    | K_send = application
 here                  +--------+--------+
              No 0-RTT |                 | 0-RTT
                       |                 |
   K_recv = handshake  |                 | K_recv = early data
 [Skip decrypt errors] |    +------> WAIT_EOED -+
                       |    |       Recv |      | Recv EndOfEarlyData
                       |    | early data |      | K_recv = handshake
                       |    +------------+      |
                       |                        |
                       +> WAIT_FLIGHT2 <--------+
                                |
                       +--------+--------+
               No auth |                 | Client auth
                       |                 |
                       |                 v
                       |             WAIT_CERT
                       |        Recv |       | Recv Certificate
                       |       empty |       v
                       | Certificate |    WAIT_CV
                       |             |       | Recv
                       |             v       | CertificateVerify
                       +-> WAIT_FINISHED <---+
                                | Recv Finished
                                | K_recv = application
                                v
                            CONNECTED

```

这图是 Server 在握手流程上的状态机。如果读者还不清楚中间的某个步骤，可以对照上文中的内容查缺补漏。读者能理解透上面这 2 张状态机，TLS 1.3 也就掌握透彻了。

全文完。

------------------------------------------------------

Reference：
   
[RFC 8466](https://tools.ietf.org/html/rfc8446)     
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)    

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS\_handshake/](https://halfrost.com/https_tls1-3_handshake/)