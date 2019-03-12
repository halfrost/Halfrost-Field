# HTTPS 温故知新（六） —— TLS 中的 Extensions

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_0.png'>
</p>

扩展是 TLS 比较重要的一个知识点。它的存在能让 Client 和 Server 在不更新 TLS 的基础上，获得新的能力。扩展的官方文档在 [[RFC 6066]](https://tools.ietf.org/html/rfc6066) 中定义。**Extension 像 TLS 中的一系列可水平扩展的插件**。

Client 在 ClientHello 中申明多个自己可以支持的 Extension，以向 Server 表示自己有以下这些能力，或者向 Server 协商某些协议。Server 收到 ClientHello 以后，依次解析 Extension，有些如果需要立即回应，就在 ServerHello 中作出回应，有些不需要回应，或者 Server 不支持的 Extension 就不用响应，忽略不处理。

TLS 握手中的 Extension 有以下几个特点:

- Extension 不影响 TLS 握手的成功与否。Server 对 ClientHello 中的 Extension 有些不支持，忽略不处理即可，不影响握手的流程。

- ServerHello 中回应 Client 的 Extension 一定要是 ClientHello 中的 Extension 的子集(小于等于)。ServerHello 中禁止出现 ClientHello 中没有出现的 Extension。如果一个 Client 在 ServerHello 中收到一个扩展类型但在相关的 ClientHello 中并没有请求，它必须用一个 unsupported\_extension 致命 alert 消息来丢弃握手。

- 当 ClientHello 或 ServerHello 中有多个不同类型的扩展存在时，这些扩展可能会以任意顺序出现。一个类型不能拥有超过一个扩展。

- 所有的 Extension 都必须考虑会话恢复的情况，保证安全性。

> "面向 Server"的扩展将来可以在 TLS 中提供。这样的一个扩展(比如, 类型 X 的扩展)可能要求 Client 首先发送一个类型 X 的扩展在 ClientHello 中，并且 extension\_data 为空以表示它支持扩展类型。在这个例子中，Client 提供了理解扩展类型的能力，Server 基于 Client 提供的内容与其进行通信。


本篇文章，笔者打算对比一下 TLS 1.2 和 TLS 1.3 握手中的 extension。

## 一. TLS 1.2 握手中的 extension

在 [[RFC 6066]](https://tools.ietf.org/html/rfc6066) 中定义了很多 Extension，这些  Extension 在 TLS 1.2 中基本都在使用。

|扩展类型名称 | 扩展类型编号 | TLS 1.3 中使用情况 | 是否推荐 | RFC 文档出处 |
| :----: | :----: | :----: |  :----: |  :----: |
| server_name |  0 |CH, EE	 | ✅ | RFC 6066 |
| max\_fragment\_length | 1 | CH, EE	 | ❌ | RFC 6066 |
| client\_certificate\_url | 2 |  | ✅ | RFC 6066 |
| trusted\_ca\_keys | 3 | | ✅ | RFC 6066 |
| truncated\_hmac | 4  | | ❌ | RFC 6066 | 
| status\_request | 5 | CH, CR, CT | ✅ | RFC 6066 |
| user\_mapping | 6 |  | ✅ | RFC 4681 |
| client\_authz | 7 |  | ❌ | RFC 5878 |
| server\_authz | 8 |  | ❌ | RFC 5878 |
| cert\_type | 9 |  | ❌ | RFC 6091 |
| supported\_groups(renamed from "elliptic_curves") | 10 | CH, EE | ✅ |  RFC 7919 |
| ec\_point\_formats | 11 | | ✅ | RFC 8422 |
| srp | 12 | | ❌ | RFC 5054 |
| signature\_algorithms | 13 | CH, CR | ✅ | RFC 5246 |
| use\_srtp | 14 | CH, EE | ✅ | RFC 5764 |
| heartbeat | 15 | CH, EE | ✅ | RFC 6520 |
| application\_layer\_protocol\_negotiation | 16 | CH, EE | ✅ | RFC 7301 |
| status\_request\_v2	 | 17 |  | ✅ | RFC 6961 |
| signed\_certificate\_timestamp | 18 |CH, CR, CT|❌|  RFC 6962 |
| client\_certificate\_type | 19 | CH, EE | ✅ | RFC7250 |
| server\_certificate\_type | 20 | CH, EE | ✅ | RFC7250 |
| padding | 21 |	CH	| ✅ |  RFC7685 |
| encrypt\_then\_mac | 22 | |✅ | RFC7366 |
| extended\_master\_secret | 23 | | ✅ | RFC 7627 |
| token\_binding	| 24 | |✅ | RFC8472 |
| cached\_info | 25 | 	| ✅	 | RFC7924 |
| tls\_lts | 26 |  | ❌	|  draft-gutmann-tls-lts |
| compress\_certificate (TEMPORARY - registered 2018-05-23, expires 2019-05-23) | 27 | CH, CR | ✅ | draft-ietf-tls-certificate-compression|
| record\_size\_limit | 28 |  CH, EE | ✅ | RFC8449|
| pwd\_protect | 29 |	CH	 | ❌	| RFC-harkins-tls-dragonfly-03 |
| pwd\_clear | 30 |	CH	| ❌|RFC-harkins-tls-dragonfly-03|
| password\_salt | 31 |	CH, SH, HRR|❌|RFC-harkins-tls-dragonfly-03|
| Unassigned	| 32 | | ❌ | |
| Unassigned	| 33 | | ❌ | | 
| Unassigned	| 34 | | ❌ |	 |	
| session\_ticket (renamed from "SessionTicket TLS") | 35 | | ✅ | RFC 4507 |
| Unassigned	| 36 | | ❌ |	 |	
| Unassigned	| 37 | | ❌ |	 |	
| Unassigned	| 38 | | ❌ |	 |	
| Unassigned	| 39 | | ❌ |	 |	
| Unassigned	| 40 | | ❌ |	 |	
| Unassigned	| 52-65279 | | ❌ |	 |		
| renegotiation\_info | 65281 | |✅ |  RFC 5746 |

> 缩写注解: CH: ClientHello，SH: ServerHello，CR: CertificateRequest，EE:EncryptedExtensions，HRR: HelloRetryRequest，CT: Certificate

上面这些 Extension 也有对应的 ExtensionType，这里只列举一些常用的 ExtensionType，并非所有:  

```c
      enum {
          server_name(0), 
          max_fragment_length(1),
          client_certificate_url(2), 
          trusted_ca_keys(3),
          truncated_hmac(4), 
          status_request(5), 
          supported_groups(10),
          ec_point_formats(11),
          signature_algorithms(13),
          application_layer_protocol_negotiation(16),
          signed_certificate_timestamp(18),
          extended_master_secret(23),
          SessionTicket TLS(35),
          renegotiation_info(65281)
          (65535)
      } ExtensionType;
```

每个 Extension 的数据结构如下:  

```c
      struct {
          ExtensionType extension_type;
          opaque extension_data<0..2^16-1>;
      } Extension;
```

Extension 是由 `extension_type` 和 `extension_data` 共同构成的。有些 Extension 是没有 `extension_data` 的。所以 `extension_type` 占 2 个字节，后面 `extension_data` 是 <0..2^16-1> 可变长度。


通常, 每个扩展类型的规范需要描述扩展对全部握手流程和会话恢复的影响。大多数当前的 TLS 扩展仅当一个会话被初始化时才是相关联的: 当一个旧的会话被恢复时，Server 不会处理 Client Hello 中的扩展，也不会将其包含在 Server Hello 中。然而, 一些扩展可以在会话恢复时指定不同的行为.

在这个协议的新特性与现存特性之间会有一些敏感(以及不很敏感)的交互产生, 这可能会导致整体安全性的显著降低。当设计新的扩展时应考虑下列事项:

-  一些情况 Server 没有就一个扩展协商一致是错误情况，一些情况下则简单地拒绝支持特定特性。通常，错误警报应该用于前者，Server 扩展中的一个域用于响应后者。

-  扩展应该尽可能在设计上阻止任何通过操纵握手消息来强制使用(或不使用)一个特殊特性进行的攻击。无论这个特性是否被确认会导致安全问题，这个原则都应该被遵循。通常扩展域扩展域都会被包含在 Finished 消息的 hash 输入中，但需要给予极大关注的是在握手阶段扩展改变了发送消息的含义。设计者和实现者应该注意的事实是，握手被认证后，活动的攻击者才能修改消息并插入，移动或替换扩展。

-  使用扩展来改变 TLS 设计的主要方面在技术上是可能的；例如密码套件协商的设计。这种做法并不被推荐；更合适的做法是定义一个新版本的 TLS -- 尤其是 TLS 握手算法有特定的保护方法以防御基于版本号的版本回退攻击，版本回退攻击的可能性应该在任何主要的修改设计中都是一个有意义的考量。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_1_.png'>
</p>

我们知道在 ClientHello 中，Compression Methods 字段之后就是 Extension 了，所以我们从 Compression Methods 字段之后逐一看起。


### 1. server\_name


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_2_.png'>
</p>

server\_name 扩展比较简单，存储的就是 Server 的名字。

TLS 没有为 Client 提供一种机制来告诉 Server 它正在建立链接的 Server 的名称。Client 可能希望提供此信息以促进与在单个底层网络地址处托管多个“虚拟”服务的 Server 的安全连接。

当 Client 连接 HTTPS 网站的时候，解析出 IP 地址以后，就能创建 TLS 连接，在握手完成之前，Server 接收到的消息中并没有 host HTTP 的头部。如果这个 Server 有多个虚拟的服务，每个服务都有一张证书，那么此时 Server 不知道该用哪一张证书。

于是为了解决这个问题，增加了 SNI 扩展。用这个扩展就能区别出各个服务对应的证书了。


```c
      struct {
          NameType name_type;
          select (name_type) {
              case host_name: HostName;
          } name;
      } ServerName;

      enum {
          host_name(0), (255)
      } NameType;

      opaque HostName<1..2^16-1>;

      struct {
          ServerName server_name_list<1..2^16-1>
      } ServerNameList;
```

支持 TLS 1.2 的 Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_14.png'>
</p>

TLS 1.3 中也同样在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_30.png'>
</p>


返回的是一个空的扩展即可。

### 2. extended\_master\_secret

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_3_.png'>
</p>

这个 Extension 标识 Client 和 Server 使用增强型主密钥计算方式。   

Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_19.png'>
</p>

Server 返回了一个空的 extended\_master\_secret 扩展，表明会使用增强型主密钥计算方式。关于增强型主密钥计算方式，见 [《HTTPS 温故知新（五） —— TLS 中的密钥计算》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTPS-key-cipher.md) 这篇文章。
   
### 3. renegotiation\_info 重协商

在安全性要求比较高的场景中，如果 Server 发现当前加密算法不够安全，或者需要校验 Client 证书的时候，需要建立一个新的链接，这个时候就需要用到重协商。重协商的协议设计初衷是好的，但是由于 2009 年出现了一个针对重协商的漏洞 CVE-2009-3555，导致 Server 和 Client 发起的重协商都是不安全的。出现漏洞的原因是没有校验 Client 和 Server 的身份，因为双方没法判断重协商的链接是不是原有链接的对端。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_4_.png'>
</p>

为了解决这个问题，所以在 RFC 5746 中增加了这个 Extension，增加了这个 Extension 以后，重协商就安全了。

这个扩展的数据结构非常简单：  

```c
      struct {
          opaque renegotiated_connection<0...255>;
      }
```

Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_13.png'>
</p>

### 4. supported\_groups

这个扩展原名叫 "elliptic\_curves"，后来更名成 "supported\_groups"。从原名的意思就能看出来这个扩展的意义。它标识了 Client 支持的椭圆曲线的种类。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_5.png'>
</p>

这个例子中，Client 支持 4 种椭圆曲线，x25519、secp256r1、secp384r1、secp521r1。

Server 接收到这个扩展会根据这些信息进行选择合适的椭圆曲线。

TLS 1.3 中支持的所有曲线如下：

```c
      enum {
          unallocated_RESERVED(0x0000),

          /* Elliptic Curve Groups (ECDHE) */
          obsolete_RESERVED(0x0001..0x0016),
          secp256r1(0x0017), secp384r1(0x0018), secp521r1(0x0019),
          obsolete_RESERVED(0x001A..0x001C),
          x25519(0x001D), x448(0x001E),

          /* Finite Field Groups (DHE) */
          ffdhe2048(0x0100), ffdhe3072(0x0101), ffdhe4096(0x0102),
          ffdhe6144(0x0103), ffdhe8192(0x0104),

          /* Reserved Code Points */
          ffdhe_private_use(0x01FC..0x01FF),
          ecdhe_private_use(0xFE00..0xFEFF),
          obsolete_RESERVED(0xFF01..0xFF02),
          (0xFFFF)
      } NamedGroup;

      struct {
          NamedGroup named_group_list<2..2^16-1>;
      } NamedGroupList;
```

标记了 "obsolete\_RESERVED" 的曲线是在以前版本的 TLS 中使用过的，不得由 TLS 1.3 实现提供或协商。因为这些过时的曲线具有各种已知/理论上的弱点或者使用的非常少，它们不再被认为适合一般用途，应该被认为可能不安全。此处指定的曲线集足以与所有当前部署和正确配置的 TLS 实现进行互操作。

### 5. ec\_point\_formats 

这个扩展标识了是否能对椭圆曲线参数进行压缩。一般不启用压缩(uncompressed)。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_6.png'>
</p>

Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_15.png'>
</p>


### 6. SessionTicket TLS

这个扩展表明了 Client 端是否有上次会话保存的 SessionTicket，如果有，则表明 Client 希望基于 SessionTicket 的方式进行会话恢复。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_7.png'>
</p>

Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_16.png'>
</p>

Server 在 SessionTicket TLS 中返回一个空的扩展，在 NewSessionTicket 中发给 Client 新的 session ticket。


### 7. application\_layer\_protocol\_negotiation

Application Layer Protocol Negotiation，ALPN 应用层协议扩展。由于应用层协议存在多个版本，Client 在 TLS 握手的时候想知道应用层用的什么协议。基于这个目的，ALPN 协议就出现了。ALPN 希望能协商出双方都支持的应用层协议，应用层底层还是基于 TLS/SSL 协议的。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_8.png'>
</p>

上图中显示 Client 希望协商 HTTP/2 协议。如果不能达成一致，那么接着协商 HTTP/1.1。

除了 HTTP 这些协议以外，还有一些其他的应用层协议，见下表。

| 应用层协议 | 标识 | RFC 文档出处|
| :-----: | :-----: | :-----: | 
|HTTP/0.9	 | 0x68 0x74 0x74 0x70 0x2f 0x30 0x2e 0x39 ("http/0.9") | RFC1945|
|HTTP/1.0	| 0x68 0x74 0x74 0x70 0x2f 0x31 0x2e 0x30 ("http/1.0") |RFC1945|
|HTTP/1.1	| 0x68 0x74 0x74 0x70 0x2f 0x31 0x2e 0x31 ("http/1.1") | RFC7230 |
| SPDY/1	|0x73 0x70 0x64 0x79 0x2f 0x31 ("spdy/1")|http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft1|
| SPDY/2	|0x73 0x70 0x64 0x79 0x2f 0x32 ("spdy/2")|http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2|
|SPDY/3	|0x73 0x70 0x64 0x79 0x2f 0x33 ("spdy/3")|http://dev.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3|
|Traversal Using Relays around NAT (TURN)|0x73 0x74 0x75 0x6E 0x2E 0x74 0x75 0x72 0x6E ("stun.turn")	|RFC7443|
|NAT discovery using Session Traversal Utilities for NAT (STUN)|0x73 0x74 0x75 0x6E 0x2E 0x6e 0x61 0x74 0x2d 0x64 0x69 0x73 0x63 0x6f 0x76 0x65 0x72 0x79 ("stun.nat-discovery") |RFC7443|
|HTTP/2 over TLS	|0x68 0x32 ("h2")|RFC7540|
|HTTP/2 over TCP	|0x68 0x32 0x63 ("h2c")	|RFC7540|
|WebRTC Media and Data	|0x77 0x65 0x62 0x72 0x74 0x63 ("webrtc")|RFC-ietf-rtcweb-alpn-04|
|Confidential WebRTC Media and Data	|0x63 0x2d 0x77 0x65 0x62 0x72 0x74 0x63 ("c-webrtc")|RFC-ietf-rtcweb-alpn-04|
|FTP	|0x66 0x74 0x70 ("ftp")	|RFC959、RFC4217|
|IMAP	|0x69 0x6d 0x61 0x70 ("imap")	|RFC2595|
|POP3	|0x70 0x6f 0x70 0x33 ("pop3")	|RFC2595|
|ManageSieve	|0x6d 0x61 0x6e 0x61 0x67 0x65 0x73 0x69 0x65 0x76 0x65 ("managesieve")	|RFC5804|
|CoAP	|0x63 0x6f 0x61 0x70 ("coap")	|RFC8323|
|XMPP jabber:client namespace	|0x78 0x6d 0x70 0x70 0x2d 0x63 0x6c 0x69 0x65 0x6e 0x74 ("xmpp-client")	|https://xmpp.org/extensions/xep-0368.html|
|XMPP jabber:server namespace	|0x78 0x6d 0x70 0x70 0x2d 0x73 0x65 0x72 0x76 0x65 0x72 ("xmpp-server")	|https://xmpp.org/extensions/xep-0368.html|

支持 TLS 1.2 的 Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_18.png'>
</p>


TLS 1.3 的情况一样，也在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_31.png'>
</p>


从这里例子中看到协商 HTTP/2 成功。

### 8. status\_request

当 Client 收到 Server 发来的证书以后，除了校验证书身份以外，还需要校验证书是否有效。有可能证书已经被 CA 刚刚吊销了。所以 Client 必须通过 CRL 和 OCSP 机制校验证书是否还在有效期之内。不管是 CRL 还是 OCSP 机制都会发送一个额外的请求去验证有效期，这个请求可能会阻塞握手下面的流程，为了避免阻塞，一般采用 Server 向 CA 发送 OCSP 请求。

为了使用 OCSP 封套技术，在 ClientHello 中增加 status\_request 扩展，这个扩展内包含了证书状态的请求。

该扩展的 `extension_data` 中就包含了 CertificateStatusRequest 信息。对应的数据结构如下：

```c
      struct {
          CertificateStatusType status_type;
          select (status_type) {
              case ocsp: OCSPStatusRequest;
          } request;
      } CertificateStatusRequest;

      enum { ocsp(1), (255) } CertificateStatusType;

      struct {
          ResponderID responder_id_list<0..2^16-1>;
          Extensions  request_extensions;
      } OCSPStatusRequest;

      opaque ResponderID<1..2^16-1>;
      opaque Extensions<0..2^16-1>;
```

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_9.png'>
</p>

Sever 收到此扩展以后，会发送 CertificateStatus 子消息，这条新增的子消息就是专门针对此扩展的。

```c
      struct {
          CertificateStatusType status_type;
          select (status_type) {
              case ocsp: OCSPResponse;
          } response;
      } CertificateStatus;

      opaque OCSPResponse<1..2^24-1>;
```

OCSPResponse 中包含了一个完整经过 DER 编码的 OCSP 封套响应。**CertificateStatus 子消息也只能返回 Server 自己证书的 OCSP 信息**。

Server 在 ServerHello 中响应该扩展，返回如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_17.png'>
</p>

Server 返回了一个空的 status\_request 扩展。

支持 TLS 1.2 的 Server 返回的 CertificateStatus 子消息内容如下： 

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_20.png'>
</p>

而在支持 TLS 1.3 的 Server 是在 Certificate 子消息中响应该扩展:  

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_33.png'>
</p>


### 9. signature\_algorithms

Client 使用 "signature\_algorithms" 扩展来向 Server 表明哪个签名/ hash 算法对会被用于数字签名。这个扩展的 "extension\_data" 域包含了一个 "supported\_signature\_algorithms" 值。

```c
      enum {
          none(0), md5(1), sha1(2), sha224(3), sha256(4), sha384(5),
          sha512(6), (255)
      } HashAlgorithm;

      enum { anonymous(0), rsa(1), dsa(2), ecdsa(3), (255) }
        SignatureAlgorithm;

      struct {
            HashAlgorithm hash;
            SignatureAlgorithm signature;
      } SignatureAndHashAlgorithm;

      SignatureAndHashAlgorithm
        supported_signature_algorithms<2..2^16-2>;
```

每个 SignatureAndHashAlgorithm 值都列出了一个 Client 愿意使用的 hash/签名对。这些值根据倾向使用的程度按降序排列。

注: 由于并不是所有的签名算法和 hash 算法都会被一个实现方所接受(例如: DSA 接受 SHA-1, 不接受 SHA-256), 所有算法是成对列出。

- hash:    
  这个字段表明可能使用的 hash 算法。这些值分别表明支持无 hash, MD5, SHA-1, SHA-224, SHA-256, SHA-384, 和 SHA-512。"none" 值用于将来的可扩展性, 以防止一个签名算法在签名之前不需要 hash。

- signature:    
  这个字段表明使用哪个签名算法。这些值分别表示匿名签名, RSASSA-PKCS1-v1\_5, DSA 和ECDSA。"anonymous" 值在这个上下文中是无意义的，它不能出现在这个扩展之中。

这个扩展的语义某种程度上有些复杂, 因为密码套件表明允许的签名算法而不是 hash 算法。

如果 Client 只支持默认的 hash 和签名算法(本节中所列出的)，它可以忽略 signature\_algorithms 扩展。如果 Client 不支持默认的算法，或支持其它的 hash 和签名算法(并且它愿意使用他们来验证 Server 发送的消息，如: server certificates 和 server key exchange)，它必须发送 signature\_algorithms 扩展，列出它愿意接受的算法。

如果 Client 不发送 signature\_algorithms 扩展，Server 必须执行如下动作:  

-  如果协商后的密钥交换算法是(RSA、DHE\_RSA、DH\_RSA、RSA\_PSK、ECDH\_RSA、ECDHE\_RSA)中的一个，处理行为同 Client 发送了 {sha1,rsa}；

-  如果协商后的密钥交换算法是(DHE\_DSS、DH\_DSS)中的一个, 处理行为同 Client 发送了{sha1,dsa}。

-  如果协商后的密钥交换算法是(ECDH\_ECDSA,ECDHE\_ECDSA)中的一个, 处理行为同 Client 发送了{sha1,ecdsa}。

注: 这个对于 TLS 1.1 是一个变更，且没有显式的规则，但在实现上可以假定对端支持 MD5 和 SHA-1。

注: 这个扩展对早于 1.2 版本的 TLS 是没有意义的，对于之前的版本 Client 不能这个扩展。然而，即使 Client 提供了这个扩展，[TLSEXT] 中明确的规则要求 Server 如果不能理解扩展则忽略之。

Server 不能发送此扩展，TLS Server 必须支持接收此扩展。

当进行会话恢复时，这个扩展不能被包含在 Server Hello 中, 且 Server 会忽略 Client Hello 中的这个扩展(如果有)。
  
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_10.png'>
</p>



  

## 二. TLS 1.3 握手中的 extension

在 TLS 1.3 [[RFC 8446]](https://tools.ietf.org/html/rfc8447) 规范中定义了很多 Extension，以下这些 Extension 在 TLS 1.3 中基本都在使用。加上上一章节表格中的 Extension，就是当前最全的 Extension 了。

|扩展类型名称 | 扩展类型编号 | TLS 1.3 中使用情况 | 是否推荐 | RFC 文档出处 |
| :----: | :----: | :----: |  :----: |  :----: |
| pre\_shared\_key | 41 | CH, SH	| ✅ | RFC8446 |
| early\_data	| 42 | CH, EE, NST	|✅	 | RFC8446 |
| supported\_versions | 43 |	CH, SH, HRR | ✅|RFC8446|
| cookie| 44 | CH, HRR|	✅|RFC8446|
| psk\_key\_exchange\_modes |45| CH|	✅|	RFC8446|
| Unassigned |46| | ❌| |			
| certificate\_authorities | 47|	CH, CR |✅ | RFC8446|
| oid\_filters | 48 | CR| ✅|RFC8446|
| post\_handshake\_auth | 49 |CH |✅	| RFC8446|
| signature\_algorithms\_cert | 50 |CH, CR|✅|RFC8446|
| key\_share | 51 | CH, SH, HRR | ✅	| RFC8446|
| Unassigned	| 52-65279 | | ❌ |	 |		
| Reserved for Private Use	 | 65280 | | | RFC8446 |
| Reserved for Private Use	 | 65282-65535 | | | RFC8446 |

> 缩写注解: CH: ClientHello，SH: ServerHello，CR: CertificateRequest，EE:EncryptedExtensions，HRR: HelloRetryRequest，CT: Certificate，NST: NewSessionTicket


CH (ClientHello), SH (ServerHello), EE (EncryptedExtensions), CT (Certificate), CR (CertificateRequest), NST (NewSessionTicket), 和 HRR (HelloRetryRequest) 


```c
    enum {
        server_name(0),                             /* RFC 6066 */
        max_fragment_length(1),                     /* RFC 6066 */
        status_request(5),                          /* RFC 6066 */
        supported_groups(10),                       /* RFC 8422, 7919 */
        signature_algorithms(13),                   /* RFC 8446 */
        use_srtp(14),                               /* RFC 5764 */
        heartbeat(15),                              /* RFC 6520 */
        application_layer_protocol_negotiation(16), /* RFC 7301 */
        signed_certificate_timestamp(18),           /* RFC 6962 */
        client_certificate_type(19),                /* RFC 7250 */
        server_certificate_type(20),                /* RFC 7250 */
        padding(21),                                /* RFC 7685 */
        RESERVED(40),                               /* Used but never
                                                       assigned */
        pre_shared_key(41),                         /* RFC 8446 */
        early_data(42),                             /* RFC 8446 */
        supported_versions(43),                     /* RFC 8446 */
        cookie(44),                                 /* RFC 8446 */
        psk_key_exchange_modes(45),                 /* RFC 8446 */
        RESERVED(46),                               /* Used but never
                                                       assigned */
        certificate_authorities(47),                /* RFC 8446 */
        oid_filters(48),                            /* RFC 8446 */
        post_handshake_auth(49),                    /* RFC 8446 */
        signature_algorithms_cert(50),              /* RFC 8446 */
        key_share(51),                              /* RFC 8446 */
        (65535)
    } ExtensionType;
```

在 TLS 1.3 中，相比 TLS 1.2 增加了大量的扩展，当然上一章提到的 TLS 1.2 的扩展也会继续使用。

```c
   +--------------------------------------------------+-------------+
   | Extension                                        |     TLS 1.3 |
   +--------------------------------------------------+-------------+
   | server_name [RFC6066]                            |      CH, EE |
   |                                                  |             |
   | max_fragment_length [RFC6066]                    |      CH, EE |
   |                                                  |             |
   | status_request [RFC6066]                         |  CH, CR, CT |
   |                                                  |             |
   | supported_groups [RFC7919]                       |      CH, EE |
   |                                                  |             |
   | signature_algorithms (RFC 8446)                  |      CH, CR |
   |                                                  |             |
   | use_srtp [RFC5764]                               |      CH, EE |
   |                                                  |             |
   | heartbeat [RFC6520]                              |      CH, EE |
   |                                                  |             |
   | application_layer_protocol_negotiation [RFC7301] |      CH, EE |
   |                                                  |             |
   | signed_certificate_timestamp [RFC6962]           |  CH, CR, CT |
   |                                                  |             |
   | client_certificate_type [RFC7250]                |      CH, EE |
   |                                                  |             |
   | server_certificate_type [RFC7250]                |      CH, EE |
   |                                                  |             |
   | padding [RFC7685]                                |          CH |
   |                                                  |             |
   | key_share (RFC 8446)                             | CH, SH, HRR |
   |                                                  |             |
   | pre_shared_key (RFC 8446)                        |      CH, SH |
   |                                                  |             |
   | psk_key_exchange_modes (RFC 8446)                |          CH |
   |                                                  |             |
   | early_data (RFC 8446)                            | CH, EE, NST |
   |                                                  |             |
   | cookie (RFC 8446)                                |     CH, HRR |
   |                                                  |             |
   | supported_versions (RFC 8446)                    | CH, SH, HRR |
   |                                                  |             |
   | certificate_authorities (RFC 8446)               |      CH, CR |
   |                                                  |             |
   | oid_filters (RFC 8446)                           |          CR |
   |                                                  |             |
   | post_handshake_auth (RFC 8446)                   |          CH |
   |                                                  |             |
   | signature_algorithms_cert (RFC 8446)             |      CH, CR |
   +--------------------------------------------------+-------------+
```


在 TLS 1.3 中，扩展通常以请求/响应方式构建，虽然有些扩展只是一些标识，并不会有任何响应。Client 只能在 ClientHello 中发送其扩展请求，Server 只能在 ServerHello, EncryptedExtensions, HelloRetryRequest,和 Certificate 消息中发送对应的扩展响应。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_21.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_22.png'>
</p>

上面 2 张图是 TLS 1.3 中 ClientHello 中的所有扩展。到 signature\_algorithms 为止，上面的扩展都在 TLS 1.2 扩展中讲解了。这里就不再赘述了，只是放一下 Wireshake 的截图展示一下。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_23.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_24.png'>
</p>

### 1. signed\_certificate\_timestamp 

这个扩展在 TLS 1.2 中就有了，之所以放在这里，只是因为在 TLS 1.3 的抓包中出现了，在 TLS 1.2 的抓包中没有出现。

这个扩展与证书透明度有关系，每一张 Server 实体证书都可以由 CA 机构或者 Server 实体提交给 CT 日志服务器从而获得证书的 SCT 信息。

HTTPS 网站的安全性很大一部分取决于 PKI 设施的可信赖性。CA 如果因为失误导致错误签发了证书，这些错误的证书都能通过证书链的校验，所以这些证书很难被发现，即使被发现，也很难快速消除影响。

Certificate Transparency 证书透明度就是为了解决这些问题的，由 Google 主导，并由 IETF 标准化为 RFC 6962。Certificate Transparency 的目标是提供一个开放的审计和监控系统，可以让任何域名所有者或者 CA 确定证书是否被错误签发或者被恶意使用，从而提高 HTTPS 网站的安全性。


Certificate Transparency 整套系统由三部分组成：1）Certificate Logs；2）Certificate Monitors；3）Certificate Auditors。完整的工作原理可以看官方文档：[How Certificate Transparency Works](https://www.certificate-transparency.org/how-ct-works)

简单说来，证书所有者或者 CA 都可以主动向 Certificate Logs 服务器提交证书，所有证书记录都会接受审计和监控。支持 CT 的浏览器（目前只有 Chrome）会根据 Certificate Logs 中证书状态，作出不同的反应。CT 不是要替换现有的 CA 设施，而是做为补充，使之更透明、更实时。

Certificate Logs 服务器由 Google 或 CA 部署，[这个页面](https://www.certificate-transparency.org/known-logs)列举了目前已知的服务器。合法的证书提交到 CT Logs 服务器之后，服务器会返回 signed certificate timestamp（SCT），要启用 CT 就必须用到 SCT 信息。

开启证书透明度有 3 种方法：

- 1. 通过 X.509v3 扩展
- 2. 通过 TLS 的 `signed_certificate_timestamp` 扩展
- 3. 通过 OCSP Stapling

这里的方法 2 就是这里所说的扩展。SCT 信息可以通过 X.509v3 扩展嵌入在证书里，方法 1 是以后的趋势。

Letsencrypt 已经默认在证书中嵌入了 CT 信息。笔者的博客证书就是由 Letsencrypt 签发的，所以证书中也嵌入了 CT 信息了。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_24_0.png'>
</p>


### 2. key\_share

在 TLS 1.3 中，之所以能比 TLS 1.2 快的原因，原因之一就在 key\_share 这个扩展上。key\_share 扩展内包含了 (EC)DHE groups 需要协商密钥参数，这样不需要再次花费 1-RTT 进行协商了。


"supported\_groups" 的扩展 和 "key\_share" 扩展配合使用。“supported\_groups” 这个扩展表明了 Client 支持的 (EC)DHE groups，"key\_share" 扩展表明了 Client 是否包含了一些或者全部的（EC）DHE共享参数。

KeyShareEntry 数据结构如下:  

```c
    struct {
        NamedGroup group;
        opaque key_exchange<1..2^16-1>;
    } KeyShareEntry;

    struct {
        KeyShareEntry client_shares<0..2^16-1>;
    } KeyShareClientHello;
```

如果 Server 选择了 (EC)DHE 组，并且 Client 在 ClientHello 中没有提供合适的 "key\_share" 扩展， Server 必须用 HelloRetryRequest 消息作为回应。

```c
    struct {
        NamedGroup selected_group;
    } KeyShareHelloRetryRequest;
```

如果 ClientHello 提供了合适的 "key\_share" 扩展，那么在 Serverhello 中回应 Server 的参数。

```c
    struct {
        KeyShareEntry server_share;
    } KeyShareServerHello;
```

整个流程见下图:  

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_25.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_29.png'>
</p>


上面 2 张图就展示了 Server 和 Client 是如何协商各自的密钥参数的。

> 这个扩展在 TLS 1.3 中非常关键，TLS 1.3 官方也对它进行了大篇幅的说明，见[这篇文章](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share)


### 3. psk\_key\_exchange\_modes

为了使用 PSK，Client 还必须发送一个 "psk\_key\_exchange\_modes" 扩展。这个扩展语意是 Client 仅支持使用具有这些模式的 PSK。这就限制了在这个 ClientHello 中提供的 PSK 的使用，也限制了 Server 通过 NewSessionTicket 提供的 PSK 的使用。

如果 Client 提供了 "pre\_shared\_key" 扩展，那么它必须也要提供 "psk\_key\_exchange\_modes" 扩展。如果 Client 发送不带 "psk\_key\_exchange\_modes" 扩展名的 "pre\_shared\_key"，Server 必须立即中止握手。Server 不能选择一个 Client 没有列出的密钥交换模式。此扩展还限制了与 PSK 恢复使用的模式。Server 也不能发送与建议的 modes 不兼容的 NewSessionTicket。不过如果 Server 一定要这样做，影响的只是 Client 在尝试恢复会话的时候会失败。


Server 不能发送 "psk\_key\_exchange\_modes" 扩展:

```c
      enum { psk_ke(0), psk_dhe_ke(1), (255) } PskKeyExchangeMode;

      struct {
          PskKeyExchangeMode ke_modes<1..255>;
      } PskKeyExchangeModes;
```

- psk\_ke:  
	仅 PSK 密钥建立。在这种模式下，Server 不能提供 "key\_share" 值。

- psk\_dhe\_ke:  
	PSK 和 (EC)DHE 建立。在这种模式下，Client 和 Server 必须提供 "key\_share" 值。

未来分配的任何值都必须要能保证传输的协议消息可以明确的标识 Server 选择的模式。目前 Server 选择的值由 ServerHello 中存在的 "key\_share" 表示。

ClientHello 中包含此扩展的消息如下：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_26.png'>
</p>

### 4. supported\_versions

在 TLS 1.3 中，ClientHello 中的 supported\_versions 扩展非常重要。因为 TLS 1.3 是根据这个字段的值来协商是否支持 TLS 1.3 。在 TLS 1.3 规范中规定，ClientHello 中的  legacy\_version 必须设置为 0x0303，这个值代表的是 TLS 1.2 。这样规定是为了对网络中间件做的一些兼容。如果此时 ClientHello 中不携带 supported\_versions 这个扩展，那么注定只能协商 TLS 1.2 了。

```c
      struct {
          select (Handshake.msg_type) {
              case client_hello:
                   ProtocolVersion versions<2..254>;

              case server_hello: /* and HelloRetryRequest */
                   ProtocolVersion selected_version;
          };
      } SupportedVersions;
```

Client 在 ClientHello 的 supported\_versions 扩展中发送自己所能支持的 TLS 版本。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_27.png'>
</p>

Server 收到以后，在 ServerHello 中的 supported\_versions 扩展响应 Client，告诉 Client 接下来进行哪个 TLS 版本的握手。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_28_.png'>
</p>

上面这个例子说明了接下来会进行 TLS 1.3 的握手。哪怕 ClientHello 和 ServerHello 中 version 都是 TLS 1.2 。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_28_0.png'>
</p>



### 5. early\_data


当使用 PSK 并且 PSK 允许使用 early\_data 的时候，Client 可以在其第一个消息中发送应用数据。如果 Client 选择这么做，则必须发送 "pre\_shared\_key" 和 "early\_data" 扩展。


Early Data Indication 扩展中的 "extension\_data" 字段包含了一个 EarlyDataIndication 值。

```c
      struct {} Empty;

      struct {
          select (Handshake.msg_type) {
              case new_session_ticket:   uint32 max_early_data_size;
              case client_hello:         Empty;
              case encrypted_extensions: Empty;
          };
      } EarlyDataIndication;
```

有关 max\_early\_data\_size 字段的使用请看 [New Session Ticket Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-new-session-ticket-message) 章节。


0-RTT 数据(版本，对称加密套件，应用层协议协商协议[[RFC7301]](https://tools.ietf.org/html/rfc7301)，等等)的参数与使用中的 PSK 参数相关。对于外部配置的 PSK，关联值是由密钥提供的。对于通过 NewSessionTicket 消息建立的 PSK，关联值是在建立 PSK 连接时协商的值。PSK 用来加密 early data 必须是 Client 在 "pre\_shared\_key" 扩展中列出的第一个 PSK。


对于通过 NewSessionTicket 提供的 PSK，Server 必须验证所选 PSK 标识中的 ticket age(从 PskIdentity.obfuscated\_ticket\_age 取 2^32 模中减去 ticket\_age\_add)距离 ticket 发出的时间是否有一个很小的公差。如果相差的时间很多，那么 Server 应该继续握手，但是要拒绝 0-RTT，并且还要假定这条 ClientHello 是新的，也不能采取任何其他措施。


在第一次 flight 中发送的 0-RTT 消息与其他 flight (握手和应用数据)中发送的相同类型的消息具有相同(加密)的内容类型，但受到不同密钥的保护。如果 Server 已经接收了 early data，Client 在收到 Server 的 Finished 消息以后，Client 则会发送 EndOfEarlyData 消息表示密钥更改。这条消息将会使用 0-RTT 的 traffic 密钥进行加密。

Server 接收 "early\_data" 扩展必须以下面三种方式之一操作：

- 忽略 "early\_data" 扩展，并返回常规的 1-RTT 响应。Server 尝试通过用握手中的流量密钥(traffic key)解密收到的记录，并忽略掉 early data。丢弃解密失败的记录(取决于配置的 max\_early\_data\_size)。一旦一个记录被解密成功，它将会被 Server 看做 Client 第二次 flight 的开始并且 Server 会把它当做普通的 1-RTT 来处理。


- 通过回应 HelloRetryRequest 来请求 Client 发送另外一个 ClientHello。Client 不能在这个 ClientHello 中包含 "early\_data" 扩展。Server 通过跳过具有外部内容类型的 "application\_data"(说明他们被加密了) 的所有记录来忽略 early data(同样取决于配置的 max\_early\_data\_size)。

- 在 EncryptedExtensions 中返回自己的 "early\_data" 扩展，表明它准备处理 early data。Server 不可能只接受 early data 消息中的一部分。即使 Server 发送了一条接收 early data 的消息，但是实际上 early data 可能在 Server 生成这条消息的时候已经在 flight 了。

为了接受 early data，Server 必须已经接受了 PSK 密码套件并且选择了 Client 的 "pre\_shared\_key" 扩展中提供的第一个密钥。此外，Server 还需要验证以下的值和选择的 PSK 关联值一样：

- TLS 版本号
- 选择的密码套件
- 选择的 ALPN 协议，如果选择了的话

这些要求是使用相关 PSK 执行 1-RTT 握手所需的超集。对于外部建立的 PSK，关联值是与密钥一起提供的值。对于通过 NewSessionTicket 消息建立的 PSK，关联值是在连接中协商的值，在这期间 ticket 被建立了。

如果任何检查失败了，Server 不得在响应中附带扩展，并且必须使用上面列出的前两种机制中的一个，丢弃所有 first-flight 数据(因此回落到 1-RTT 或者 2-RTT)。如果 Client 尝试 0-RTT 握手但 Server 拒绝了它，则 Server 通常不会有 0-RTT 记录保护密钥，而必须使用试用解密（使用 1-RTT 握手密钥或者通过在有 HelloRetryRequest 消息的情况下查找明文 ClientHello）找到第一个非 0-RTT 消息。

如果 Server 选择接受 early\_data 扩展，那么在处理 early data 记录的时候，Server 必须遵守用相同的标准(指定的相同错误处理要求)来处理所有记录。具体来说，如果 Server 无法解密已经接受的 "early\_data" 扩展中的记录，则它必须发送 "bad\_record\_mac" alert 消息中止握手。

如果 Server 拒绝 "early\_data" 扩展，则 Client 应用程序可以选择在握手完成后重新发送先前在 early data 中发送的应用数据。请注意，early data 的自动重传可能会导致关于连接状态的误判。例如，当协商连接从用于 early data 的协议中选择不同的 ALPN 协议时，应用程序可能需要构造不同的消息。同样，如果 early data 假定包含有关连接状态的任何内容，则在握手完成后可能会错误地发送这些内容。


TLS 的实现不应该自动重新发送 early data；应用程序可以很好的决定何时重传。除非协商连接选择相同的 ALPN 协议，否则 TLS 实现绝不能自动重新发送 early data。

下图是 NewSessionTicket 中的 early\_data，表明了 Server 可以接受 0-RTT。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_32.png'>
</p>


### 6. pre\_shared\_key

"pre\_shared\_key" 预共享密钥和 "psk\_key\_exchange\_modes" 扩展配合使用。预共享密钥扩展包含了 Client 可以识别的对称密钥标识。"psk\_key\_exchange\_modes" 扩展表明了可能可以和 psk 一起使用的密钥交换模式。

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

实现者请注意：会话恢复是 PSK 最主要的用途，实现 PSK/密钥套件 匹配要求的最直接的方法是先协商密码套件，然后再排除任何不兼容的 PSK。任何未知的 PSK (例如：不在 PSK 数据库中，或者用未知的 key 进行编码的)都必须忽略。如果找不到可接受的 PSK，如果可能，Server 应该执行 non-PSK 握手。如果向后兼容性很重要，Client 提供的，外部建立的 PSK 应该影响密码套件的选择。


在接受PSK密钥建立之前，Server 必须先验证相应的 binder 值。如果这个值不存在或者未验证，则 Server 必须立即中止握手。Server 不应该尝试去验证多个 binder，而应该选择单个 PSK 并且仅验证对应于该 PSK 的 binder。为了接受 PSK 密钥建立连接，Server 发送 "pre\_shared\_key" 扩展，标明它所选择的 identity。


Client 必须验证 Server 的 selected\_identity 是否在 Client 提供的范围之内。Server 选择的加密套件标明了与 PSK 关联的哈希算法，如果 ClientHello "psk\_key\_exchange\_modes" 有需要，Server 还应该发送 "key\_share" 扩展。如果这些值不一致，Client 必须立即用 "illegal\_parameter" alert 消息中止握手。


如果 Server 提供了 "early\_data" 扩展，Client 必须验证 Server 的 selected\_identity 是否为 0。如果返回任何其他值，Client 必须使用 "illegal\_parameter" alert 消息中止握手。


"pre\_shared\_key" 扩展必须是 ClientHello 中的最后一个扩展(这有利于下面的描述的实现)。Server 必须检查它是最后一个扩展，否则用 "illegal\_parameter" alert 消息中止握手。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_38.png'>
</p>

上图是 ClientHello 中的 pre\_shared\_key 扩展。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/122_41.png'>
</p>

上图是 Server 选择后，返回给 Client 的 pre\_shared\_key 扩展。它标识了 Server 选择的哪一组密钥参数。

### 7. signature\_algorithms\_cert

"signature\_algorithms" 签名算法和 "signature\_algorithms\_cert" 签名证书算法的扩展配合使用。"signature\_algorithms" 这个扩展展示了 Client 可以支持了签名算法有哪些。"signature\_algorithms\_cert" 这个扩展展示了具体证书的签名算法。



### 8. cookie

```c
      struct {
          opaque cookie<1..2^16-1>;
      } Cookie;
```

Cookies 有 2 大主要目的：

- 允许 Server 强制 Client 展示网络地址的可达性(因此提供了一个保护 Dos 的度量方法)，这主要是面向无连接的传输(参考 [RFC 6347](https://tools.ietf.org/html/rfc6347) 中的例子)


- 允许 Server 卸载状态。从而允许 Server 在向 Client 发送 HelloRetryRequest 消息的时候，不存储任何状态。为了实现这一点，可以通过 Server 把 ClientHello 的哈希存储在 HelloRetryRequest 的 cookie 中(用一些合适的完整性算法保护)。


当发送 HelloRetryRequest 消息时，Server 可以向 Client 提供 “cookie” 扩展(这是常规中的一个例外，常规约定是：只能是可能被发送的扩展才可以出现在 ClientHello 中)。当发送新的 ClientHello 消息时，Client 必须将 HelloRetryRequest 中收到的扩展的内容复制到新 ClientHello 中的 “cookie” 扩展中。Client 不得在后续连接中使用首次 ClientHello 中的 Cookie。


当 Server 在无状态运行的时候，在第一个和第二个 ClientHello 之间可能会收到不受保护的 change\_cipher\_spec 消息。由于 Server 没有存储任何状态，它会表现出像到达的第一条消息一样。无状态的 Server 必须忽略这些记录。

### 9. certificate\_authorities
	
"certificate\_authorities" 扩展用于表示终端支持的 CA, 并且接收的端点应该使用它来指导证书的选择。
	
"certificate\_authorities" 扩展的主体包含了一个 CertificateAuthoritiesExtension 结构：

```c
      opaque DistinguishedName<1..2^16-1>;

      struct {
          DistinguishedName authorities<3..2^16-1>;
      } CertificateAuthoritiesExtension;
```
	
- authorities:  
	可接受证书颁发机构的一个可分辨名字 [X501](https://tools.ietf.org/html/rfc8446#ref-X501) 的列表	，这个列表是以 DER [X690](https://tools.ietf.org/html/rfc8446#ref-X690) 编码格式表示的。这些可分辨的名称为，信任锚或从属的 CA 指定所需的可分辨的名称。因此，可以使用此消息描述已知的信任锚以及所需的授权空间。
	
Client 可能会在 ClientHello 消息中发送 "certificate\_authorities" 扩展，Server 可能会在 CertificateRequest 消息中发送 "certificate\_authorities" 扩展。


"trusted\_ca\_keys" 扩展和 "certificate\_authorities" 扩展有相同的目的，但是更加复杂。"trusted\_ca\_keys" 扩展不能在 TLS 1.3 中使用，但是它在 TLS 1.3 之前的版本中，可能出现在 Client 的 ClientHello 消息中。


### 10. oid\_filters

"oid\_filters" 扩展允许 Server 提供一组 OID/value 对，用来匹配 Client 的证书。如果 Server 想要发送这个扩展，有且仅有在 CertificateRequest 消息中才能发送。

```c
      struct {
          opaque certificate_extension_oid<1..2^8-1>;
          opaque certificate_extension_values<0..2^16-1>;
      } OIDFilter;

      struct {
          OIDFilter filters<0..2^16-1>;
      } OIDFilterExtension;
```

- filters:  
	一个有允许值的证书扩展 OID [RFC 5280](https://tools.ietf.org/html/rfc5280) 列表，以 DER 编码 [X690](https://tools.ietf.org/html/rfc8446#ref-X690) 格式表示。一些证书扩展 OID 允许多个值(例如，Extended Key Usage)。如果 Server 包含非空的 filters 列表，则响应中包含的 Client 证书必须包含 Client 识别的所有指定的扩展 OID。对于 Client 识别的每个扩展 OID，所有指定的值必须存在于 Client 证书中（但是证书也可以具有其他值）。然而，Client 必须忽略并跳过任何无法识别的证书扩展 OID。如果 Client 忽略了一些所需的证书扩展 OID 并提供了不满足请求的证书。Server 可以自行决定是继续与没有身份认证的 Client 保持连接，还是用 "unsupported\_certificate" alert 消息中止握手。任何给定的 OID 都不能在 filters 列表中出现多次。


PKIX RFC 定义了各种证书扩展 OID 及其对应的值类型。根据类型，匹配的证书扩展值不一定是按位相等的。期望 TLS 实现将依靠它们的 PKI 库，使用证书扩展 OID 来做证书的选择。

TLS 1.3 规范中定义了 [RFC5280](https://tools.ietf.org/html/rfc5280) 中定义的两个标准证书扩展的匹配规则：


- 当请求中声明的所有 Key Usage 位也同样在 Key Usage 证书扩展声明了，那么证书中的 Key Usage 扩展匹配了请求。

- 当请求中所有的密钥 OIDs 在 Extended Key Usage 证书扩展中也存在，那么证书中的 Extended Key Usage 匹配了请求。特殊的 anyExtendedKeyUsage OID 一定不能在请求中使用。


单独的规范可以为其他证书扩展的规则定义匹配规则。



### 11. post\_handshake\_auth


"post\_handshake\_auth" 扩展用于表明 Client 愿意握手后再认证。Server 不能向没有提供此扩展的 Client 发送握手后再认证的 CertificateRequest 消息。Server 不能发送此扩展。

```c
      struct {} PostHandshakeAuth;
```

"post\_handshake\_auth" 扩展名中的 "extension\_data" 字段为零长度。

当 Client 发送了 "post\_handshake\_auth" 扩展时，Server 可以在握手完成后随时通过发送 CertificateRequest 消息来请求客户端身份验证。Client 必须使用适当的验证消息进行响应。如果 Client 选择进行身份验证，则必须发送 Certificate，CertificateVerify，Finished 消息。如果 Client 拒绝身份验证，它必须发送一个 Certificate 证书消息，其中不包含证书，然后是 Finished 消息。响应 Server 的所有 Client 消息必须连续出现在线路上，中间不能有其他类型的消息。


在没有发送 "post\_handshake\_auth" 扩展的情况下接收 CertificateRequest 消息的 Client 必须发送 "unexpected\_message" alert 消息。


注意：由于 Client 身份验证可能涉及提示用户，因此 Server 必须做好一些延迟的准备，包括在发送 CertificateRequest 和接收响应之间接收任意数量的其他消息。此外，Client 如果连续接收到了多个 CertificateRequests 消息，Client 可能会以不同于它们的顺序响应它们(certificate\_request\_context 值允许服务器消除响应的歧义)

### 12. signature\_algorithms

这个扩展在 TLS 1.2 中就存在，只不过在 TLS 1.3 中数据结构发生了变化，所以这个扩展还是需要提一下。

```c
      struct {
          SignatureScheme supported_signature_algorithms<2..2^16-2>;
      } SignatureSchemeList;
```

SignatureScheme 有以下一些枚举值：

```c
      enum {
          /* RSASSA-PKCS1-v1_5 algorithms */
          rsa_pkcs1_sha256(0x0401),
          rsa_pkcs1_sha384(0x0501),
          rsa_pkcs1_sha512(0x0601),

          /* ECDSA algorithms */
          ecdsa_secp256r1_sha256(0x0403),
          ecdsa_secp384r1_sha384(0x0503),
          ecdsa_secp521r1_sha512(0x0603),

          /* RSASSA-PSS algorithms with public key OID rsaEncryption */
          rsa_pss_rsae_sha256(0x0804),
          rsa_pss_rsae_sha384(0x0805),
          rsa_pss_rsae_sha512(0x0806),

          /* EdDSA algorithms */
          ed25519(0x0807),
          ed448(0x0808),

          /* RSASSA-PSS algorithms with public key OID RSASSA-PSS */
          rsa_pss_pss_sha256(0x0809),
          rsa_pss_pss_sha384(0x080a),
          rsa_pss_pss_sha512(0x080b),

          /* Legacy algorithms */
          rsa_pkcs1_sha1(0x0201),
          ecdsa_sha1(0x0203),

          /* Reserved Code Points */
          obsolete_RESERVED(0x0000..0x0200),
          dsa_sha1_RESERVED(0x0202),
          obsolete_RESERVED(0x0204..0x0400),
          dsa_sha256_RESERVED(0x0402),
          obsolete_RESERVED(0x0404..0x0500),
          dsa_sha384_RESERVED(0x0502),
          obsolete_RESERVED(0x0504..0x0600),
          dsa_sha512_RESERVED(0x0602),
          obsolete_RESERVED(0x0604..0x06FF),
          private_use(0xFE00..0xFFFF),
          (0xFFFF)
      } SignatureScheme;
```


------------------------------------------------------

Reference：

[RFC 6066](https://tools.ietf.org/html/rfc6066)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTPS-extensions/](https://halfrost.com/https-extensions/)