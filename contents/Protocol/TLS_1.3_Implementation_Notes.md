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





------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()