# TLS 1.3 Implementation Notes


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/114_0.png'>
</p>


## 一、Cipher Suites

对称密码套件定义了一对 AEAD 算法和与 HKDF 一起使用的哈希算法。密码套件名称遵循    命名惯例：

```c
      CipherSuite TLS_AEAD_HASH = VALUE;

      +-----------+------------------------------------------------+
      | Component | Contents                                       |
      +-----------+------------------------------------------------+
      | TLS       | The string "TLS"                               |
      |           |                                                |
      | AEAD      | The AEAD algorithm used for record protection  |
      |           |                                                |
      | HASH      | The hash algorithm used with HKDF              |
      |           |                                                |
      | VALUE     | The two-byte ID assigned for this cipher suite |
      +-----------+------------------------------------------------+
```

此规范定义了以下用于 TLS 1.3 的密码套件：

```c
              +------------------------------+-------------+
              | Description                  | Value       |
              +------------------------------+-------------+
              | TLS_AES_128_GCM_SHA256       | {0x13,0x01} |
              |                              |             |
              | TLS_AES_256_GCM_SHA384       | {0x13,0x02} |
              |                              |             |
              | TLS_CHACHA20_POLY1305_SHA256 | {0x13,0x03} |
              |                              |             |
              | TLS_AES_128_CCM_SHA256       | {0x13,0x04} |
              |                              |             |
              | TLS_AES_128_CCM_8_SHA256     | {0x13,0x05} |
              +------------------------------+-------------+

```


相应的 AEAD 算法 AEAD\_AES\_128\_GCM，AEAD\_AES\_256\_GCM，    AEAD\_AES\_128\_CCM 在 [[RFC5116]](https://tools.ietf.org/html/rfc5116) 中定义。AEAD\_CHACHA20\_POLY1305 在 [[RFC8439]](https://tools.ietf.org/html/rfc8439) 中定义。AEAD\_AES\_128\_CCM\_8 在[[RFC6655]](https://tools.ietf.org/html/rfc6655) 中定义。相应的哈希算法是在 [[SHS]](https://tools.ietf.org/html/rfc8446#ref-SHS) 中定义的。

虽然 TLS 1.3 与之前 TLS 版本使用相同的密码套件空间，但是 TLS 1.3 密码套件的定义不同，TLS 1.3 只有指定对称密码套件，并且不能用于 TLS 1.2。同样，TLS 1.2 及更低版本的密码套件也不能使用 TLS 1.3。

新的密码套件值由 IANA 分配。

## 二. Random Number Generation and Seeding

TLS 需要加密安全的伪随机数生成器(CSPRNG)。在大多数情况下，操作系统提供适当的工具，例如 /dev/urandom，应该在没有其他(例如性能)问题的情况下使用。建议使用现有的 CSPRNG 实现，而不是开发新的 CSPRNG 实现。许多合适的加密库已经在有利的许可条款下可用。如果还是不能令人满意，[[RFC4086]](https://tools.ietf.org/html/rfc4086) 提供了随机值生成的指导。

TLS 在公共协议字段中使用随机值(1)，例如 ClientHello 和 ServerHello 中的公共随机值，以及(2)生成密钥材料。正确使用 CSPRNG，这不会带来安全问题，因为想从输出中确定 CSPRNG 的状态是不可行的。但是，如果 CSPRNG 损坏，攻击者可能会使用公共输出来确定 CSPRNG 内部状态，从而预测密钥材料，如 [[CHECKOWAY]](https://tools.ietf.org/html/rfc8446#ref-CHECKOWAY) 中所述。实现方可以针对通过使用单独的 CSPRNG 生成公共和私有值的这类攻击，提供额外的安全性。

## 三. Certificates and Authentication

实现方负责验证证书的完整性，并且通常应支持证书废除消息。如果没有来自应用程序配置文件的特定指示，则应始终验证证书以确保受信任的证书颁发机构(CA)正确签名。应非常谨慎地选择和添加信任锚。用户应该能够查看有关证书和信任锚的信息。 

应用程序还应该强制限制最小和最大密钥大小。例如，证书路径中包含弱于 2048 位 RSA 或 224 位 ECDSA 的密钥或者签名，则它不适用于安全性比较高的应用程序。


## 四. Implementation Pitfalls

经验表明，早期 TLS 规范的某些部分不易理解，并且是互操作性和安全性问题的根源。 本文件中澄清了其中许多方面，但本附录包含了一些需要实现者特别注意的重要事项的简短列表。

TLS 协议问题：

- 您是否正确处理了分散在多个 TLS 记录中的握手消息(参见第5.1节)？你是否正确处理了像 ClientHello 这样被分成几个小片段的边缘案例？您是否将超过最大片段大小的握手消息分段？特别是，Certificate 和 CertificateRequest 握手消息可能足够大，需要分段。

- 您是否忽略了所有未加密的 TLS 记录中的 TLS 记录层版本号(参见附录D)？

- 您是否确保了，为了支持 TLS 1.3 或更高版本的所有可能配置中已经完全删除了对 SSL，RC4，EXPORT 密码和 MD5(通过"signature\_algorithms"扩展)的所有支持，并且尝试使用这些过时功能的操作都会失败(请参阅附录D)？

- 您是否正确处理 ClientHellos 中的 TLS 扩展，包括未知扩展？

- 当 Server 请求了 Client 证书但没有合适的证书可用时，您是否正确发送了一个空的证书消息，而不是省略整个消息(参见第4.4.2节)？

- 当处理由 AEAD-Decrypt 生成的纯文本片段并且从末尾开始扫描 ContentType 的时候，如果对端发送了全部为零的格式错误明文，您是否会避免扫描明文的开头？

- 您是否正确忽略了 ClientHello 中无法识别的密码套件([第 4.1.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello))，hello 扩展([第 4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%BA%8C-extensions))，命名组([第 4.2.7 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups))，密钥共享([第 4.2.8 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share))，支持的版本([第 4.2.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions))和签名算法([第 4.2.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms))？

- 作为 Server，您是否向支持兼容 (EC)DHE 组但是不能预测它在 "key\_share" 扩展中的 Client 发送 HelloRetryRequest？作为 Client，您是否正确地处理从 Server 发过来的 HelloRetryRequest？

加密细节：

- 您使用什么对策来防止定时攻击 [[TIMING]](https://tools.ietf.org/html/rfc8446#ref-TIMING)？

- 使用 Diffie-Hellman 密钥交换时，是否正确保留了协商密钥中的前导零字节(参见第7.4.1节)？

- 您的 TLS Client 是否检查过 Server 发送过来的 Diffie-Hellman 参数是否可接受(参见第4.2.8.1节)？

- 在生成 Diffie-Hellman 私有值，ECDSA"k" 参数和其他安全关键值时，您是否使用了强大且最重要的正确选择种子随机数生成器(参见 [附录C.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E4%BA%8C-random-number-generation-and-seeding))？建议实现方实现 [[RFC6979]](https://tools.ietf.org/html/rfc6979)中规定的 "确定性ECDSA"。

- 您是否将 Diffie-Hellman 公钥值和共享密钥，用 0 填充到到组的大小(参见[第 4.2.8.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-diffie-hellman-parameters)和[第 7.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#1-finite-field-diffie-hellman))？

- 您是否在制作签名后验证签名，以防止 RSA-CRT 密钥泄漏[FW15](https://tools.ietf.org/html/rfc8446#ref-FW15)？


## 五. Client Tracking Prevention

Client 不应该为多个连接重用一个 ticket。重用一个 ticket 会允许被动观察者关联不同的连接。发布 ticket 的 Server 至少应该提供与 Client 可能使用的连接数量一样多的 ticket;例如，使用 HTTP/1.1 [RFC7230](https://tools.ietf.org/html/rfc7230) 的 Web 浏览器可能会与 Server 建立六个连接。Server 应该为每个连接都发出新 ticket。这样可以确保 Client 始终能够在创建新连接时使用新的 ticket。


## 六. Unauthenticated Operation

TLS 之前的版本中提供了基于匿名 Diffie-Hellman 算法的明显未经过验证的密码套件。这些模式已在 TLS 1.3 中弃用。但是，仍然可以通过多种方法协商不提供可验证 Server 身份验证的参数，包括：

- 原始公钥 [[RFC7250]](https://tools.ietf.org/html/rfc7250)。

- 使用证书中包含的公钥，但不验证证书链或其任何内容。

单独使用这两种技术都容易受到中间人攻击，因此上述做法不安全。但是，也可以通过 Server 公钥的带外验证，首次使用时信任或通道绑定（尽管 [RFC5929](https://tools.ietf.org/html/rfc5929) 中描述了通道绑定，没有为TLS 1.3 定义)等机制将这些连接绑定到外部认证机制上。如果没有使用这种机制，则该连接无法防止主动的中间人攻击；应用程序禁止以没有显式配置或特定应用程序配置文件的这种方式使用 TLS。


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Implementation\_Notes/](https://halfrost.com/tls_1-3_implementation_notes/)