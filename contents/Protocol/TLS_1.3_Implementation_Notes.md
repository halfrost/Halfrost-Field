# TLS 1.3 Implementation Notes


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/95_0.png'>
</p>


## 一、Cipher Suites

对称密码套件定义了一对 AEAD 算法和与 HKDF 一起使用的哈希算法。密码套件名称遵循    命名惯例：

```
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

```
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





------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()