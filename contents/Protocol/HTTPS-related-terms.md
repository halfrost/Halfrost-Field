# HTTPS 相关术语


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0.png'>
</p>


## EV
EV证书(Extended Validation Certificate)是一种根据一系列特定标准颁发的X.509电子证书，根据要求，在颁发证书之前，证书颁发机构(CA)必须验证申请者的身份。不同机构根据证书标准发行的扩展验证证书并无太大差异，但是有时候根据一些具体的要求，特定机构发行的证书可以被特定的软件识别

## OV
OV证书(Organization Validation SSL)，指需要验证网站所有单位的真实身份的标准型SSL证书，此类证书不仅能够起到网站信息加密的作用，而且能向用户证明网站的真实身份。

## DV
DV证书(Domain Validation SSL)，指需要验证域名的有效性。该类证书只提供基本的加密保障，不能提供域名所有者的信息。

## HPKP
公钥固定，这是一种https网站防止攻击者使用CA错误颁发的证书进行中间人攻击的一种安全机制，用于预防诸如攻击者入侵CA偷发证书、浏览器信任CA签发伪造证书等情况，采用该机制后服务器会提供一个公钥哈希列表，客户端在后续的通信中只接受该列表上的一个或多个公钥。HPKP是一个响应头

> Public-Key-Pins:max-age=xxx;pin-sha256=xxxx;includeSubDomains;

其中可以使用多个pin-sha256，pin-sha256的值是对证书公钥sha256的值，includeSubDomains决定是否包含所有子域名，在max-age所指定的时间内(秒)，证书链中的证书至少一个公钥须和固定公钥相符，这样客户端才认为该证书链是有效的。

还有一种响应头：

> Public-Key-Pins-Report-Only:max-age=xxx;pin-sha256=xxxx;includeSubDomains;report-uri=xxx

Public-Key-Pins-Report-Only中的report-uri，决定是否回报违反HTTP公钥固定策略的事件。客户端进行HTTP公钥固定验证失败后，将把此次错误详情以JSON格式回报个report-uri参数中指定的服务器。

## CAA
CAA : DNS Certification Authority Authorization，使用DNS来指定该域名可以由哪些CA机构签发证书，这不是为TLS层的安全提供保证，而是作为CA签发证书程序中的一部分。使用CAA可以避免一些CA签发错误证书的情况。

## SNI
SNI(服务器名称指示)，这个是一个扩展的TLS协议，在该协议中，在TLS握手过程中客户端可以指定服务器的主机名称，这允许服务器在相同的IP和端口上部署多个证书，并允许在相同的IP地址上提供多个HTTPS网站或者基于TLS的服务。

## ALPN
ALPN(应用层协议协商 Application-Layer Protocol Negotiation) 是一个进行应用层协议协商的传输层安全协议(TLS)扩展，ALPN允许应用层协商应该在安全连接上实行哪个协议，以避免额外且独立于应用层协议的往返协商通信。它已被HTTP/2使用。

## NPN
NPN(Next Protocol Negotiation) 下一协议协商，在TLS上允许应用层协商使用哪个协议，在2014年7月11日的RFC 7301中使用ALPN代替NPN

## h2
HTTP/2 的协议名称，口语叫法HTTP2和http/1.1 是一个概念，通过ALPN协商。
HTTP/2 中只能使用 TLSv1.2+协议。

## CSR
CSR(Certificate Signing Request)，在PKI系统中，CSR文件必须在申请和购买SSL证书之前创建，也就是证书申请者在申请数字证书时由CSP(加密服务提供者)在生成私钥的同时也生成证书请求文件，证书申请者只要把CSR文件提交给证书颁发机构后，证书颁发机构使用其根证书私钥签名就生成了证书公钥文件

## CT
CT (Certificate Transparency) 证书透明，Certificate Transparency的目标是提供一个开放的审计和监控系统，可以让任何域名所有者或者CA确定证书是否被错误签发或者被恶意使用，从而提高HTTPS网站的安全性。

## RSA
RSA加密算法是一种非对称加密算法。在公开密钥加密和电子商业中RSA被广泛使用。对极大整数做因数分解的难度决定了RSA算法的可靠性，支持签名和加密。

## ECC
ECDSA（椭圆曲线签名算法）的常见叫法，和RSA同时具有签名和加密不同，它只能做签名，它的优势是具有很好的性能、大小和安全性更高。

## DH/DHE
Diffie-Hellman(DH)密钥交换是一种密钥交换的协议，DH的诀窍是使用了一种正向计算简单、逆向计算困难的数学函数，即使交换中某些因子已被知晓，情况也是一样。DH密钥交换需要6个参数，其中两个(dh_p和dh_g)称为域参数，由服务器选取，协商过程中，客户端和服务器各自生成另外两个参数，相互发送其中一个参数(dh_Ys和dh_Yc)到对端，在经过计算，最终得到共享密钥。

临时Diffie-Hellman(ephemeral Diffie-Hellman,DHE)密钥交换中没有任何参数被重复利用。与之相对，在一些DH密钥交换方式中，某些参数是静态的，并被嵌入到服务器和客户端的证书中，这样的话密钥交换的结果是一直不变的共享密钥，就无法具备前向保密的能力。

## ECDH/ECHDE
椭圆曲线Diffie-Hellman(elliptic curve Diffie-Hellman，ECDH)密钥交换原理与DH相似，但是它的核心使用了不同的数学基础，ECHD基于椭圆曲线加密，ECDH密钥交换发生在一条由服务器定义的椭圆曲线上，这条曲线代替了DH中域参数的角色，理论上，ECDH支持静态的密钥交换。

临时椭圆曲线Diffie-Hellman密钥交换，和DHE类似，使用临时的参数，具有前向保密的能力。

## SRI
HTTPS 可以防止数据在传输中被篡改，合法的证书也可以起到验证服务器身份的作用，但是如果 CDN 服务器被入侵，导致静态文件在服务器上被篡改，HTTPS 也无能为力。

W3C 的 SRI（Subresource Integrity）规范可以用来解决这个问题。SRI 通过在页面引用资源时指定资源的摘要签名，来实现让浏览器验证资源是否被篡改的目的。只要页面不被篡改，SRI 策略就是可靠的。

有关 SRI 的更多说明请看Jerry Qu写的《Subresource Integrity 介绍》。SRI 并不是 HTTPS 专用，但如果主页面被劫持，攻击者可以轻松去掉资源摘要，从而失去浏览器的 SRI 校验机制。

## CSP
CSP，全称是 Content Security Policy，它有非常多的指令，用来实现各种各样与页面内容安全相关的功能。这里只介绍两个与 HTTPS 相关的指令，更多内容可以看我之前写的《Content Security Policy Level 2 介绍》。

## block-all-mixed-content
前面说过，对于 HTTPS 中的图片等 Optionally-blockable 类 HTTP 资源，现代浏览器默认会加载。图片类资源被劫持，通常不会有太大的问题，但也有一些风险，例如很多网页按钮是用图片实现的，中间人把这些图片改掉，也会干扰用户使用。

通过 CSP 的 block-all-mixed-content 指令，可以让页面进入对混合内容的严格检测（Strict Mixed Content Checking）模式。在这种模式下，所有非 HTTPS 资源都不允许加载。跟其它所有 CSP 规则一样，可以通过以下两种方式启用这个指令：

HTTP 响应头方式：

> Content-Security-Policy: block-all-mixed-content

标签方式：
upgrade-insecure-requests
历史悠久的大站在往 HTTPS 迁移的过程中，工作量往往非常巨大，尤其是将所有资源都替换为 HTTPS 这一步，很容易产生疏漏。即使所有代码都确认没有问题，很可能某些从数据库读取的字段中还存在 HTTP 链接。

而通过 `upgrade-insecure-requests` 这个 CSP 指令，可以让浏览器帮忙做这个转换。启用这个策略后，有两个变化：

- 页面所有 HTTP 资源，会被替换为 HTTPS 地址再发起请求；
- 页面所有站内链接，点击后会被替换为 HTTPS 地址再跳转；
跟其它所有 CSP 规则一样，这个指令也有两种方式来启用，具体格式请参考上一节。需要注意的是 `upgrade-insecure-requests` 只替换协议部分，所以只适用于 HTTP/HTTPS 域名和路径完全一致的场景。

## HSTS
在网站全站 HTTPS 后，如果用户手动敲入网站的 HTTP 地址，或者从其它地方点击了网站的 HTTP 链接，依赖于服务端 301/302 跳转才能使用 HTTPS 服务。而第一次的 HTTP 请求就有可能被劫持，导致请求无法到达服务器，从而构成 HTTPS 降级劫持。

这个问题可以通过 HSTS（HTTP Strict Transport Security，RFC6797）来解决。HSTS 是一个响应头，格式如下：

> Strict-Transport-Security: max-age=expireTime [; includeSubDomains] [; preload]

max-age，单位是秒，用来告诉浏览器在指定时间内，这个网站必须通过 HTTPS 协议来访问。也就是对于这个网站的 HTTP 地址，浏览器需要先在本地替换为 HTTPS 之后再发送请求。

includeSubDomains，可选参数，如果指定这个参数，表明这个网站所有子域名也必须通过 HTTPS 协议来访问。

preload，可选参数，后面再介绍它的作用。

HSTS 这个响应头只能用于 HTTPS 响应；网站必须使用默认的 443 端口；必须使用域名，不能是 IP。而且启用 HSTS 之后，一旦网站证书错误，用户无法选择忽略。

## HSTS Preload List
可以看到 HSTS 可以很好的解决 HTTPS 降级攻击，但是对于 HSTS 生效前的首次 HTTP 请求，依然无法避免被劫持。浏览器厂商们为了解决这个问题，提出了 HSTS Preload List 方案：内置一份可以定期更新的列表，对于列表中的域名，即使用户之前没有访问过，也会使用 HTTPS 协议。

目前这个 Preload List 由 Google Chrome 维护，Chrome、Firefox、Safari、IE 11 和 Microsoft Edge 都在使用。如果要想把自己的域名加进这个列表，首先需要满足以下条件：

- 拥有合法的证书（如果使用 SHA-1 证书，过期时间必须早于 2016 年）；
- 将所有 HTTP 流量重定向到 HTTPS；
- 确保所有子域名都启用了 HTTPS；
- 输出 HSTS 响应头：
max-age 不能低于 18 周（10886400 秒）；
必须指定 includeSubdomains 参数；
必须指定 preload 参数；

即便满足了上述所有条件，也不一定能进入 HSTS Preload List，更多信息可以看这里。通过 Chrome 的 chrome://net-internals/#hsts 工具，可以查询某个网站是否在 Preload List 之中，还可以手动把某个域名加到本机 Preload List。

## PFS
PFS(perfect forward secrecy)正向保密 ，在密码学中也可以被称为FS(forward secrecy)，是安全通信协议的特性，要求一个密钥只能访问由它所保护的数据，用来产生密钥的元素一次一换，不能再产生其他的密钥，一个密钥被破解，并不影响其他密钥的安全性。

## OCSP
OCSP(Online Certificate Status Protocol)是一个用于获取X.509数字证书撤销状态的网际协议，在RCF 6960中定义，作为证书吊销列表的替代品解决公开密钥基础建设(PKI)中使用证书吊销列表而带来的多个问题。协议数据传输过程中使用ASN.1编码，并通常创建在HTTP协议上

## OCSP Stapling
OCSP装订，是TLS证书状态查询扩展，作为在线证书状态协议的替代方法对X.509证书状态进行查询，服务器在TLS握手时发送事先缓存的OCSP响应，用户只要验证该响应的时效性而不用再向数字证书认证机构(CA)发送请求，可以加快握手速度。

## CRL
CRL(Certificate revocation list 证书吊销列表)是一个已经被吊销的数字证书的名单，这些在证书吊销列表中的证书不再会受到信任，但目前OCSP(在线证书状态协议)可以代替CRL实现证书状态检查。

## Session ID
Session ID 完成SSL握手后会获得一个编号（Session ID）。如果对话中断，下次重连的时候，只要客户端给出这个编号，且服务器有这个编号的缓存，双方就可以重新使用已有的"对话密钥"，而不必重新生成一把（握手的主要开销）。 因为要缓存每个连接的握手参数，服务端存储开销会比较大。

## Session Ticket
Session ticket获得方式和SessionID类似，但是使用时是在每次握手时由服务器进行解密，获得加密参数。服务端无需维持握手参数，可以减少内存开销。

## POODLE
POODLE(贵宾犬漏洞 CVE-2014-3566)，贵宾犬漏洞的根本原因是CBC模式在设计上的缺陷，具体来说就是CBC只对明文进行了身份验证，但是没有对填充字节进行完整性校验。这使得攻击者可以对填充字节修改并且利用填充预示来恢复加密内容，让POODLE攻击成为可能的原因是SSL3中过于松散的填充结构和校验规则。

## TLS POODLE
TLS POODLE(TLS 贵宾犬漏洞 CVE-2014-8730) 该漏洞的原理和POODLE漏洞的原理一致，但不是SSL3协议，而是在TLS协议上，TLS协议本身没有问题，但是在其实现上。一些开发人员在进行SSL3到TLS的转换的时候，没有遵守协议规定的填充要求，使得他们的实现容易受到POODLE攻击的威胁

## DROWN
一句话概括：“使用SSLv2对TLS进行交叉协议攻击”

DROWN(CVE-2016-0800)  DROWN表示仅支持SSL2是对现代服务器和客户端的威胁，它允许攻击者通过讲探测发送到支持SSLv2的服务器并使用相同的私钥来解密最新客户端和服务器之间的TLS连接，如果如果服务器容易受到DROWN的影响，有两种原因：

- 服务器允许SSL2连接
- 私钥用于允许SSL2连接的其他服务器，即使是另一个支持SSL/TLS的协议，例如，Web服务器和邮件服务器上使用相同的私钥和证书，如果邮件服务器支持SSL2，即使web服务器不支持SSL2，攻击者可以利用
邮件服务器来破坏与web服务器的TLS连接。
使用40bit的出口限制RSA加密套件，单台PC能在一分钟内完成工具，对于攻击的一般变体（对任何SSL2服务起作用）也可以在8个小时内完成。

## Logjam
Logjam(CVE-2015-4000) 使用 Diffie-Hellman 密钥交换协议的 TLS 连接很容易受到攻击，尤其是DH密钥中的公钥强度小于1024bits。中间人攻击者可将有漏洞的 TLS 连接降级至使用 512 字节导出级加密。这种攻击会影响支持 DHE_EXPORT 密码的所有服务器。这个攻击可通过为两组弱 Diffie-Hellman 参数预先计算 512 字节质数完成，特别是 Apache 的 httpd 版本 2.1.5 到 2.4.7，以及 OpenSSL 的所有版本。

## BEAST
BEAST(CVE-2011-3389)  BEAST攻击针对TLS1.0和更早版本的协议中的对称加密算法CBC模式，初始化向量IV可以预测，这就使得攻击者可以有效的讲CBC模式削弱为ECB模式，ECB模式是不安全的

## Downgrade
Downgrade attack(降级攻击 ) 降级攻击是一种对计算机系统或者通信协议的攻击，在降级攻击中，攻击者故意使系统放弃新式、安全性高的工作方式，反而使用为向下兼容而准备的老式、安全性差的工作方式，降级攻击常被用于中间人攻击，讲加密的通信协议安全性大幅削弱，得以进行原本不可能做到的攻击。 在现代的回退防御中，使用单独的信号套件来指示自愿降级行为，需要理解该信号并支持更高协议版本的服务器来终止协商，该套件是TLS_FALLBACK_SCSV(0x5600)

## MITM
MITM(Man-in-the-middle) ，是指攻击者与通讯的两端分别创建独立的联系，并交换其所有收到的数据，使通讯的两端认为他们正在通过一个私密的连接与对方直接对话，但事实上整个对话都被攻击者完全控制，在中间人攻击中，攻击者可以拦截通讯双方的通话并插入新的内容。一个中间人攻击能成功的前提条件是攻击者能够将自己伪装成每个参与会话的终端，并且不被其他终端识破。

## Openssl Padding Oracle
Openssl Padding Oracle(CVE-2016-2107) openssl 1.0.1t到openssl 1.0.2h之前没有考虑某些填充检查期间的内存分配，这允许远程攻击者通过针对AES CBC会话的padding-oracle攻击来获取敏感的明文信息。

## CCS
CCS(openssl MITM CCS injection attack CVE-2014-0224) 0.9.8za之前的Openssl，1.0.0m之前的以及1.0.1h之前的openssl没有适当的限制ChangeCipherSpec信息的处理，这允许中间人攻击者在通信之间使用0长度的主密钥

## FREAK
FREAK(CVE-2015-0204) 客户端会在一个全安全强度的RSA握手过程中接受使用弱安全强度的出口RSA密钥，其中关键在于客户端并没有允许协商任何出口级别的RSA密码套件

## Export-cipher
在1998年9月之前，美国曾经限制出口高强度的加密算法。具体来说，限制对称加密强度为最大40位，限制密钥交换强度为最大512位。

## CRIME
CRIME(Compression Ratio Info-leak Made Easy CVE-2012-4929)，这是一种可攻击安全隐患，通过它可窃取启用数据压缩特性的HTTPS或SPDY协议传输的私密Web Cookie。在成功读取身份验证Cookie后，攻击者可以实行会话劫持和发动进一步攻击。

## Heartbleed
Heartbleed(心血漏洞 CVE-2014-0160) 是Openssl的程序漏洞，如果使用带缺陷的Openssl版本，无论是服务器还是客户端，都可能因此受到攻击。此问题的原因是在实现TLS的心跳扩展时没有对输入进行适当的验证（缺少边界检查），该程序错误属于缓冲区过读，即可以读取的数据比应该允许读取的还多。

## RC4
是一种流加密算法，对称加密，密钥长度可变。由于RC4算法存在弱点，2015年2月所发布的 RFC 7465 规定禁止在TLS中使用RC4加密算法。
Chrome 48版本开始会拒绝与「以 RC4 做为对称加密算法的 CipherSuite」建立 TLS 连接 。

## 3DES
在加密套件中很多的密码使用的是3DES_EDE_CBC这种类型的，在维基上3DES提供的bits数是192bits(168+24)，但由于Meet-in-the-middle attack攻击的影响，只能提供112bits的安全。因此在等级评定上使用192bits，在套件的安全性上使用112bits

## PSK
PSK 是“Pre-Shared Key”的缩写。就是 预先让通讯双方共享一些密钥（通常是对称加密密钥）。
这种算法用的不多，它的好处是：

1. 不需要依赖公钥体系，不需要部属 CA 证书。
2. 不需要涉及非对称加密，TLS 协议握手（初始化）时的性能好于 RSA 和 DH。
密钥交换时通讯双方已经预先部署了若干个共享的密钥为了标识多个密钥，给每一个密钥定义一个唯一的 ID客户端通过ID 和服务端进行通讯。

## SRP
TLS-SRP（ Secure Remote Password）密码套件有两类：第一类密码套件仅使用SRP认证。第二类使用SRP认证和公共密钥证书来增加安全性。

## TLS GREASE
为了保持可扩展性，服务器必须忽略未知值，
是Chrome 推出的一种探测机制。

1. GREASE for TLS
2. https://tools.ietf.org/html/draft-davidben-tls-grease-01

## AEAD
全称是使用关联数据的已验证加密，Authenticated Encryption with Associated Data (AEAD) algorithms。
AEAD是用一个算法在内部同时实现cipher+MAC，是TLS1.2、TLS1.3上采用的现代加密算法。

相关密码套件：

```
TLS_RSA_WITH_AES_128_CCM = {0xC0,0x9C}
TLS_RSA_WITH_AES_256_CCM = {0xC0,0x9D)
TLS_DHE_RSA_WITH_AES_128_CCM = {0xC0,0x9E}
TLS_DHE_RSA_WITH_AES_256_CCM = {0xC0,0x9F}
TLS_RSA_WITH_AES_128_CCM_8 = {0xC0,0xA0}
TLS_RSA_WITH_AES_256_CCM_8 = {0xC0,0xA1)
TLS_DHE_RSA_WITH_AES_128_CCM_8 = {0xC0,0xA2}
TLS_DHE_RSA_WITH_AES_256_CCM_8 = {0xC0,0xA3}
```

https://tools.ietf.org/html/rfc6655

## AES-GCM
AES-GCM是一种AEAD，是目前TLS的主力算法，互联网上https流量的大部分依赖使用AES-GCM。

## ChaCha20-poly1305
ChaCha20-poly1305是一种AEAD，提出者是Daniel J. Bernstein教授，针对移动互联网优化，目前Google对移动客户端的所有流量都使用ChaCha20-Poly1305

## AES-CBC
关于AES-CBC，在AES-GCM流行之前，TLS主要依赖AES-CBC，而由于历史原因，TLS在设计之初固定选择了MAC-then-Encrypt结构，AES-CBC和MAC-then-encrypt结合，为选择密文攻击(CCA)创造了便利条件，TLS历史上有多个漏洞都和CBC模式有关。

## STARTTLS
STARTTLS 是对纯文本通信协议(SMTP/POP3/IMAP)的扩展。它提供一种方式将纯文本连接升级为加密连接（TLS或SSL），而不是另外使用一个端口作加密通信。
RFC 2595定义了IMAP和POP3的STARTTLS；RFC 3207定义了SMTP的；


------------------------------------------------------

Reference：
  
《图解 HTTP》    
《HTTP 权威指南》  
《深入浅出 HTTPS》   
[MySSL 相关术语](https://blog.myssl.com/myssl-term/)


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()