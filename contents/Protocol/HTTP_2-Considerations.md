<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/128_0.jpg'>
</p>

# HTTP/2 中的注意事项


## 一. HTTP 值得关注的问题

本节概述了 HTTP 协议的属性，这些属性可提高互操作性，减少已知安全漏洞的风险或降低实现方在代码实现的时候出现歧义的可能性。

### 1. 连接管理

HTTP/2 连接是持久的。为了获得最佳性能，建议客户端不要主动关闭连接。除非在确定不需要与服务器进行进一步通信(例如，当用户离开特定网页时)或服务器关闭连接的时候再去关闭连接。

客户端不应该打开与给定主机和端口对的多个 HTTP/2 连接，其中主机包括是从 URI，选定的备用服务 [ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC) 或配置的代理中派生出来的。

客户端可以创建其他连接作为替换，以替换可用的流标识符空间即将用完的连接（[第 5.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6)），刷新 TLS 连接的密钥材料，或替换遇到错误的连接（[第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)）。

客户端可以对一个 IP 打开多个连接，并且 TCP 端口可以使用不同服务器标识 [TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) 或者提供不同的 TLS 客户端证书，但应该避免使用相同的配置创建多个连接。

鼓励服务器尽可能长时间地保持打开的连接，但如果有需要，允许服务器终止空闲连接。当任一端点选择关闭传输层 TCP 连接时，发起终止的端点应首先发送 GOAWAY 帧（[第 6.8 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)），这样做能够使得两个端点可以可靠地确定先前发送的帧是否已被处理并正常完成或者终止任何必要的剩余任务。


### (1). 连接重用


直接或通过使用 CONNECT 方法创建的隧道的方式（[第 8.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%B8%89-the-connect-method)）对原始服务器建立的连接，可以重用于具有多个不同 URI 权限组件的请求。只要原始服务器具有权限，就可以重用连接（[第 10.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90)）。对于没有 TLS 的 TCP 连接，这取决于已解析为相同 IP 地址的主机。

对于 "https" 资源，连接重用还取决于具有对 URI 中的主机的证书是否有效。服务器提供的证书必须要能通过客户端在 URI 中为主机建立新的 TLS 连接时将执行的任何检查。

源服务器可能提供具有多个 "subjectAltName" 属性的证书或带有通配符的名称，其中一个对 URI 中的权限有效。例如，"subjectAltName" 为 "* .example.com" 的证书可能允许对以 "https://a.example.com/" 和 "https://b.example.com/" 开头的 URI 的请求使用相同的连接。


在某些部署中，重用多个源的连接可能导致请求被定向到错误的源服务器。例如，TLS 可能会被网络中间件关闭，因为网络中间件使用了 TLS Server Name Indication (SNI)[TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) 的扩展去选择源服务器。这意味着客户端可以将机密信息发送到可能不是请求的预期目标的服务器，即使服务器具有其他的权限。

不希望客户端重用连接的服务器可以通过发送响应请求的 421 (错误请求)状态代码来指示它对请求不具有权限(参见[第 9.1.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-421-%E7%8A%B6%E6%80%81%E7%A0%81))。

配置了基于 HTTP/2 代理的客户端通过单个连接将请求定向到该代理。也就是说，通过代理发送的所有请求都会重用客户端与代理的连接。



### (2). 421 状态码

421 (错误请求) 状态码表示请求发到了一台无法生成响应的服务器。这个状态码可以由没有配置请求 URI 中的 scheme 和权限组合的响应服务器发送。

从服务器接收 421（错误请求）响应的客户端可以通过不同的连接重试请求，无论请求方法是否是幂等性的。这可能是因为重用了连接([第 9.1.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E8%BF%9E%E6%8E%A5%E9%87%8D%E7%94%A8))或者选择了 [ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC)。代理不得生成此 421 状态码。

默认情况下，421 响应是可缓存的，除非除此之外还有方法定义或者显式缓存控制(参见[[RFC7234]的第 4.2.2 节](https://tools.ietf.org/html/rfc7234#section-4.2.2))。


### 2. 使用 TLS 特性


HTTP/2 的实现必须使用 TLS 版本 1.2 [TLS12](https://tools.ietf.org/html/rfc7540#ref-TLS12) 或 TLS 更高版本来实现 HTTP/2。 应遵循 [TLSBCP](https://tools.ietf.org/html/rfc7540#ref-TLSBCP) 中的规定 TLS 使用指南，以及一些特定于 HTTP/2 的附加限制。

TLS 实现必须支持 TLS 的服务器名称指示 (SNI)[TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) 扩展。协商 TLS 时，HTTP/2 客户端必须指明目标域名。

部署 HTTP/2 的时候，协商 TLS 1.3 或更高版本只需支持和使用 SNI 扩展；TLS 1.2 的部署符合以下各节的要求。鼓励实现方提供符合要求的默认值，但是需要认识到部署最终要对合规性负责。


### (1). TLS 1.2 特性

本节介绍了可与 HTTP/2 一起使用的 TLS 1.2 的一些限制。由于部署的限制，如果不能满足这些限制，则可能无法使 TLS 协商失败。端点可以通过 INADEQUATE\_SECURITY 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))立即终止不满足这些 TLS 要求的 HTTP/2 连接。

在 TLS 1.2 上部署 HTTP/2 **必须**禁用压缩。TLS 压缩可能导致泄露信息，而这些信息如果不压缩就不会泄露 [[RFC3749]](https://tools.ietf.org/html/rfc3749)。通用的压缩是不必要的，因为 HTTP/2 提供了更了解上下文的压缩功能，出于性能，安全性或其他原因考虑，HTTP/2 的压缩可能更适合使用。

在 TLS 1.2 上部署 HTTP/2 **务必**禁用重新协商。端点必须将 TLS 重新协商视为 PROTOCOL\_ERROR 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。请注意，由于基础密码套件可以加密的消息数量受到限制，因此禁用重新协商可能会导致长连接无法使用。


端点可以使用重新协商为握手中提供的客户证书提供机密性保护，但是任何重新协商必须在发送连接序言之前进行。如果服务器在建立连接后立即收到重新协商请求，则应该请求客户端证书。这可以有效地防止因为需要响应对特定受保护资源的请求而使用重新协商。将来的规范可能会提供一种支持这种情况的方法。或者，服务器也可能使用 HTTP\_1\_1\_REQUIRED 类型的错误([第 5.4 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%83-%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))来请求客户端使用支持重新协商的协议。

对于使用临时有限域 Diffie-Hellman(DHE) [[TLS12]](https://tools.ietf.org/html/rfc7540#ref-TLS12) 的密码套件，实现必须支持至少 2048 位的临时密钥交换大小，对于使用临时椭圆曲线 Diffie-Hellman(ECDHE) [[RFC4492]](https://tools.ietf.org/html/rfc4492) 的密码套件，实现方必须支持至少 224 位的密码套件。客户端必须接受最大 4096 位的 DHE 大小。端点可以将小于密钥大小最小下限的协商视为 INADEQUATE\_SECURITY 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### (2). TLS 1.2 加密套件


通过 TLS 1.2 部署 HTTP/2 不应该使用密码套件黑名单([附录 A](https://tools.ietf.org/html/rfc7540#appendix-A))中列出的任何密码套件。

如果协商了黑名单中的一个密码套件，则端点可以选择生成 INADEQUATE\_SECURITY 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。选择使用列入黑名单的密码套件的部署可能会引发连接错误，除非已知一组潜在的对等方接受该密码套件。对于未列入黑名单的密码套件的协商，实现方不得产生此错误。因此，当客户端提供不在黑名单中的密码套件时，他们必须准备将密码套件与 HTTP/2 一起使用。

黑名单包括 TLS 1.2 强制使用的密码套件，这意味着 TLS 1.2 部署可以具有不相交的被允许的密码套件集。为避免此问题导致 TLS 握手失败，使用 TLS 1.2 的 HTTP/2 部署必须支持具有 P-256 椭圆曲线 [[FIPS186]](https://tools.ietf.org/html/rfc7540#ref-FIPS186) 的 TLS\_ECDHE\_RSA\_WITH\_AES\_128\_GCM\_SHA256 [[TLS-ECDHE]](https://tools.ietf.org/html/rfc7540#ref-TLS-ECDHE)。

请注意，客户端可能会广播它对黑名单上的密码套件的支持，以允许连接到不支持 HTTP/2 的服务器。这使得服务器使用 HTTP/1.1 协议和使用 HTTP/2 黑名单上的密码套件。但是，如果选择应用程序协议和密码套件是独立的，则可能导致在协商 HTTP/2 过程中也使用了黑名单密码套件。

## 二. 安全问题

### 1. 服务器权限

HTTP/2 依靠 HTTP/1.1 权限定义来确定服务器在提供给定响应方面是否具有权威性(请参阅[[RFC7230]，第 9.1 节](https://tools.ietf.org/html/rfc7230#section-9.1))。 这依赖于 "http" URI 方案的本地名称解析和 "https" 方案的已认证服务器身份(请参阅[[RFC2818]，第 3 节](https://tools.ietf.org/html/rfc2818#section-3)）。


### 2. 跨协议攻击


在跨协议攻击中，攻击者使客户端以一种协议 A 向了解不同协议 B 的服务器(并不了解协议 A)发起事务。攻击者可能能够使交易在第二协议(协议 B)中显示为有效交易。结合 Web 上下文的功能，可以将其与专用网络中受到保护不高的服务器进行交互。使用 HTTP/2 的 ALPN 标识符完成 TLS 握手可以被认为是对跨协议攻击的充分保护。ALPN 明确表明服务器愿意继续使用 HTTP/2，从而防止了对其他基于 TLS 的协议的攻击。TLS 中的加密使攻击者难以控制可用于跨协议攻击中明文协议中的数据。

HTTP/2 的明文版本对跨协议攻击的保护最低。连接序言([第 3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))包含一个旨在混淆 HTTP/1.1 服务器的字符串，但没有为其他协议提供特殊保护。愿意忽略除客户端连接序言之外还包含 Upgrade 头字段的 HTTP/1.1 请求的一部分的服务器可能会受到跨协议攻击。


### 3. 中间件封装攻击

HTTP/2 头字段编码允许在 HTTP/1.1 使用的 Internet 消息语法中表达不是有效字段名称的名称。包含无效头域名称的请求或响应必须被视为格式错误([第 8.1.2.6 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#2-http-header-fields))。因此，中间件无法将包含无效字段名称的 HTTP/2 请求或响应转换为 HTTP/1.1 消息。

同样，HTTP/2 允许无效的头字段值。虽然大多数可以编码的值都不会更改头字段的解析，但是如果将它们逐字翻译，攻击者还是可能会利用回车符（CR，ASCII 0xd），换行符（LF，ASCII 0xa）和零字符（NUL，ASCII 0x0）。任何包含头部字段值中不允许的字符的请求或响应都必须被视为格式错误([第 8.1.2.6 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#2-http-header-fields))。有效字符由 [[RFC7230] 的 3.2 节](https://tools.ietf.org/html/rfc7230#section-3.2)中的“字段内容”  ABNF 规则定义。



### 4. 推送响应的可缓存性

推送的响应没有一个来自客户端的明确请求；该请求是由服务器在 PUSH\_PROMISE 帧中提供的。

是否推送缓存响应，可以根据原始服务器在 Cache-Control 头字段中提供的值来判定。但是，如果一台服务器托管多个租户，则可能导致问题。例如，服务器可能为多个用户提供其 URI 空间的一小部分。如果多个租户共享同一台服务器上的空间，则该服务器必须确保租户不能推送他们没有权限的资源。如果不强制执行此操作，则租户可以提供在缓存之外使用的表示形式，从而覆盖了租户提供的实际表示形式的权限。

对于原始服务器不具有权威性的推送响应(请参阅[第 10.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90))，不得使用或缓存。



### 5. 关于拒绝服务


与 HTTP/1.1 连接相比，HTTP/2 连接可能需要更多的资源来进行操作。头压缩和流控制的使用取决于用于存储大量状态的资源承诺大小。这些功能的设置可确保严格限制这些功能的内存承诺大小。

PUSH\_PROMISE 帧的数量不受相同方式的限制。接受服务器推送的客户端应该限制允许处于“保留(远程)”状态的流的数量。过多的服务器推送流可被视为类型为 ENHANCE\_YOUR\_CALM 的流错误([第 5.4.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。处理容量不能像状态容量那样有效地受到保护。SETTINGS 帧可能被滥用，导致对等方花费额外的处理时间。例如，无意义地更改 SETTINGS 参数，设置多个未定义的参数或在同一帧中多次更改相同的设置。WINDOW\_UPDATE 或 PRIORITY frame 帧可能会被滥用，从而造成不必要的资源浪费。

大量的小帧或空帧可能会被滥用，从而导致对等方花费更多的时间处理帧头。但是请注意，某些使用是完全合法的，例如在流的末尾发送空的 DATA 或 CONTINUATION 帧。头压缩还提供了一些浪费处理资源的机会；有关潜在滥用的更多详细信息，请参见[[压缩]](https://tools.ietf.org/html/rfc7540#ref-COMPRESSION)的第 7 节。

不能立即降低 SETTINGS 参数中的限制，这会使端点暴露出来自对等方的行为，并可能超出新的限制。特别是，在建立连接后，客户端不知道服务器设置的限制，并且可以在不明显违反协议的情况下超过服务器限制。所有这些功能——即 SETTINGS 更改，小帧，头部压缩——都具有合法用途。这些功能仅在不必要或过度使用时才成为负担。不监视此行为的端点会使自己面临拒绝服务攻击的风险。实现方应跟踪这些功能的使用并设置其使用限制。端点可以将可疑活动视为 ENHANCE\_YOUR\_CALM 类型的连接错误([第 5.4.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86))。


### (1). 限制头块大小

较大的标题块([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))可能导致实现方提交大量的状态。对于路由至关重要的头字段可能会出现在头块的末尾，这会阻止头字段流式传输到其最终目的地。这种排序和其他原因(例如确保高速缓存正确性)意味着端点可能需要缓冲整个头块。由于对头块的大小没有硬性限制，因此某些端点可能被迫为头字段提供大量可用内存。

端点可以使用 SETTINGS\_MAX\_HEADER\_LIST\_SIZE 来通知对等端可能适用于头块大小的限制。该设置仅是建议性的，因此端点可以选择发送超出此限制的报头块，并有可能将请求或响应视为格式错误。此设置特定于连接，因此任何请求或响应都可能遇到具有较低、未知限制的跃点。中间件可以通过传递不同对等方提供的值来尝试避免此问题，但他们没有义务这样做。

服务器如果接收到了比其愿意处理的头块大小更大的头块，可以发送 HTTP 431(请求头字段太大)状态码 [[RFC6585]](https://tools.ietf.org/html/rfc6585)。客户端可以丢弃无法处理的响应。除非关闭连接，否则必须处理头块以确保一致的连接状态。


### (2). 连接问题

CONNECT 方法可用于在代理上创建不成比例的负载，因为与 TCP 连接的创建和维护相比，stream 流创建相对容易。由于传出的 TCP 连接仍处于 TIME\_WAIT 状态，因此代理可能还会为携带 CONNECT 请求的 stream 流关闭之后的 TCP 连接保留一些资源。因此，代理不能仅依靠 SETTINGS\_MAX\_CONCURRENT\_STREAMS 来限制 CONNECT 请求消耗的资源。


### 6. 使用压缩


压缩可以使攻击者在与攻击者控制下的数据相同的上下文中对其进行压缩时恢复秘密数据。HTTP/2 可以压缩头字段([第 4.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression))；以下注意事项也适用于 HTTP 压缩内容编码的使用([[RFC7231]，第 3.1.2.1 节](https://tools.ietf.org/html/rfc7231#section-3.1.2.1))。

研究表明，压缩攻击利用了网络的特征(例如 [[BREACH]](https://tools.ietf.org/html/rfc7540#ref-BREACH))。攻击者会诱使多个请求包含不同的明文，并观察每个明文中得到的密文的长度，当对密文的猜测正确时，会暴露出较短的长度。

在安全通道上进行通信的实现方不得压缩包含加密数据和攻击者控制的数据的内容，除非为每个数据源搭配使用单独的压缩字典。如果不能可靠地确定数据源，则不得使用压缩。通用 stream 流压缩(例如 TLS 提供的压缩)不得与 HTTP/2 一起使用（请参见 [9.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E4%BD%BF%E7%94%A8-tls-%E7%89%B9%E6%80%A7)）。在 [[COMPRESSION]](https://tools.ietf.org/html/rfc7540#ref-COMPRESSION) 中描述了有关头字段压缩的其他注意事项。


### 7. 使用填充

HTTP/2 中的填充不是为了替代通用填充的，例如 TLS [[TLS12]](https://tools.ietf.org/html/rfc7540#ref-TLS12) 提供的填充。多余的填充甚至可能适得其反。正确的应用程序可能需要对要填充的数据有特定的了解。为了减少依赖压缩的攻击，禁用或限制压缩可能比填充更可取。

填充可用于掩盖帧内容的确切大小，并用于减少 HTTP 中的特定攻击，例如，压缩内容同时包含攻击者控制的明文和秘密数据（例如 [[BREACH]](https://tools.ietf.org/html/rfc7540#ref-BREACH)）的攻击。

使用填充可能导致的保护作用少于立即显而易见的保护作用。充其量，填充只会使攻击者更难通过增加攻击者必须观察的帧数来推断长度信息。实现错误的填充方案很容易被击败。特别是，具有可预测分布的随机填充提供的保护能力很小。类似地，将有效载荷填充到固定大小，这种做法会在有效载荷大小越过固定大小边界时泄露信息，这种情况会在攻击者可以控制纯文本的情况下发送。

中间件应该保留对 DATA 帧的填充，但是可以对 HEADERS 和 PUSH\_PROMISE 帧不填充。中间件更改帧填充量的可行理由是为了改善填充提供的保护。


### 8. 关于隐私的注意事项

HTTP/2 的几个特征为观察者提供了一个机会，可以随时间将单个客户端或服务器的操作关联起来。这些包括设置的值，管理流控制窗口的方式，将优先级分配给 streams 流的方式，对刺激的反应时间以及对设置帧控制的任何功能的处理。只要它们在行为上产生了可观察到的差异，就可以用作对特定客户端进行指纹识别的基础，如 [[HTML5]](https://tools.ietf.org/html/rfc7540#ref-HTML5) 的第 1.8 节所定义。

HTTP/2 使用单个 TCP 连接的首选项允许将用户在站点上的活动相关联。重用不同来源的连接可以跟踪这些来源。由于 PING 和 SETTINGS 帧会请求即时响应，因此端点可以使用它们来测量到其对等方的延迟。在某些情况下，这可能会对隐私产生影响。



## 三. IANA 注意事项


在建立 [TLS-ALPN] 中注册的用于标识 HTTP/2 的字符串 "应用程序层协议协商(ALPN)协议 ID"。本文档为 frame 类型，设置和错误代码建立了一个注册表。这些新注册表出现在新的"超文本传输协议版本 2(HTTP/2) 参数"部分中。本文档注册了 HTTP2-Settings 头字段以用于HTTP；它还注册 421(错误请求)状态码。本文档注册了用于 HTTP 的 "PRI" 方法，以避免与连接序言冲突([第 3.5 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface))。

### 1. HTTP/2 标识字符串注册

本文档在 [[TLS-ALPN]](https://tools.ietf.org/html/rfc7540#ref-TLS-ALPN) 建立张中注册了 "Application-Layer Protocol Negotiation (ALPN) Protocol IDs"，并创建了 2 个注册字符串用来标识 HTTP/2 (详情见[第 3.3 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#4-starting-http2-for-https-uris))，

"h2" 字符串用来标识使用 TLS 的 HTTP/2。标识序列：0x68 0x32 ("h2")。"h2c" 字符串用来标识使用明文 TCP 的 HTTP/2。标识序列：0x68 0x32 0x63 ("h2c")。


### 2. 帧类型注册

本文档为 HTTP/2 帧类型代码建立了一个注册表。“HTTP/2 帧类型”注册表管理一个 8 位空间。“HTTP/2 帧类型”注册了 0x00 和 0xef 之间的值，并遵循 “IETF 审查” 或 “IESG 批准” 策略 [[RFC5226]](https://tools.ietf.org/html/rfc5226) 中的规范，其中 0xf0 和 0xff 之间的值保留供实验使用。

想要在此注册表中的注册新条目需要提供以下信息：

帧类型：帧类型的名字或者标签。  
码：一个 8 位的码标识帧类型。  
规范：对规范的引用，其中包括：对 frame 帧布局的描述，以及帧使用的语义和标志(帧类型用到的类型、包括帧用到的任何有条件的地方)  

被本文档注册过的值见下表：

|Frame Type|Code|Section|
|:--------:|:--------:|:----------:|
| DATA |0x0|[Section 6.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7)|  
| HEADERS       | 0x1  | [Section 6.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7)  |  
| PRIORITY      | 0x2  | [Section 6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%89-priority-%E5%B8%A7)  |  
| RST\_STREAM    | 0x3  | [Section 6.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%9B%9B-rst_stream-%E5%B8%A7)  |  
| SETTINGS      | 0x4  | [Section 6.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)  |  
| PUSH\_PROMISE  | 0x5  | [Section 6.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AD-push_promise-%E5%B8%A7)  |  
| PING          | 0x6  | [Section 6.7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%83-ping-%E5%B8%A7)  |  
| GOAWAY        | 0x7  | [Section 6.8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)  |  
| WINDOW\_UPDATE | 0x8  | [Section 6.9](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7)  |  
| CONTINUATION  | 0x9  | [Section 6.10](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81-continuation-%E5%B8%A7) |  
 


### 3. Settings 注册


本文档为 HTTP/2 Settings 建立了一个注册表。“HTTP/2 Settings”注册表管理一个 16 位空间。“HTTP/2 Settings”注册了从 0x0000 到 0xefff 之间的值，并且遵循在 “Expert Review” 策略 [[RFC5226]](https://tools.ietf.org/html/rfc5226) 中的规范，其中 0xf000 和 0xffff 之间的值保留供实验使用。


想要在此注册表中的注册新条目需要提供以下信息：

名称：setting 的名字，指定 setting 名字是可选的。  
码：分配给 setting 用的 16 位的码。  
初始值：setting 的初始值。  
规范：对描述 setting 的使用规范的可选参考。  

被本文档注册过的值见下表：

       
| Name |Code|Initial Value| Specification |  
|:--------:|:--------:|:----------:|:----------:|  
| HEADER\_TABLE\_SIZE      | 0x1  | 4096          | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| ENABLE\_PUSH            | 0x2  | 1             | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| MAX\_CONCURRENT\_STREAMS | 0x3  | (infinite)    | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| INITIAL\_WINDOW\_SIZE    | 0x4  | 65535         | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| MAX\_FRAME\_SIZE         | 0x5  | 16384         | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |
| MAX\_HEADER\_LIST\_SIZE   | 0x6  | (infinite)    | [Section 6.5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters) |



### 4. 错误码注册

本文档为 HTTP/2 错误码建立了一个注册表。“HTTP/2 Error Code”注册表管理一个 32 位空间。“HTTP/2 Error Code”遵循注册在 “Expert Review” 策略 [[RFC5226]](https://tools.ietf.org/html/rfc5226) 中的规范。


注册错误码必须包含错误码的描述。专家会审阅新的错误码，防止新的错误码和老的错误码重复。鼓励尽量使用现有注册过的错误码，但不强制使用。


想要在此注册表中的注册新条目需要提供以下信息：

名称：错误码的名字，指定错误码的名字是可选的。  
码：32 位的错误码。  
描述：错误码语义的简短描述，没有没有更加详细的规范说明，描述可以更长一些。  
规范：对定义错误码使用规范的可选参考。  

被本文档注册过的值见下表：


| Name |Code| Description | Specification |  
|:--------:|:--------:|:----------:|:----------:|  
| NO\_ERROR            | 0x0  | Graceful shutdown    | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| PROTOCOL\_ERROR      | 0x1  | Protocol error       | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | detected             |               |
| INTERNAL\_ERROR      | 0x2  | Implementation fault | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| FLOW\_CONTROL\_ERROR  | 0x3  | Flow-control limits  | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | exceeded             |               |
| SETTINGS\_TIMEOUT    | 0x4  | Settings not         | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | acknowledged         |               |
| STREAM\_CLOSED       | 0x5  | Frame received for   | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | closed stream        |               |
| FRAME\_SIZE\_ERROR    | 0x6  | Frame size incorrect | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| REFUSED\_STREAM      | 0x7  | Stream not processed | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| CANCEL              | 0x8  | Stream cancelled     | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
| COMPRESSION\_ERROR   | 0x9  | Compression state    | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | not updated          |               |
| CONNECT\_ERROR       | 0xa  | TCP connection error | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | for CONNECT method   |               |
| ENHANCE\_YOUR\_CALM   | 0xb  | Processing capacity  | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | exceeded             |               |
| INADEQUATE\_SECURITY | 0xc  | Negotiated TLS       | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | parameters not       |               |
|                     |      | acceptable           |               |
| HTTP\_1\_1\_REQUIRED   | 0xd  | Use HTTP/1.1 for the | [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes)     |
|                     |      | request              |               |


### 5. HTTP2-Settings 头字段注册

这一节在 "Permanent Message Header Field Names" [[BCP90]](https://tools.ietf.org/html/rfc7540#ref-BCP90) 中注册了 HTTP2-Settings 头字段。

头字段名字：HTTP2-Settings  
应用协议：HTTP  
状态：标准  
作者/变更管理者：IETF  
规范文档：[Section 3.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#3-http2-settings-header-field)  
有关信息：这个头字段只会被 HTTP/2 中的客户端使用，用来升级协商的时候使用。  



### 6. PRI 方法注册

这一节在 "HTTP Method Registry" [[RFC7231], Section 8.1](https://tools.ietf.org/html/rfc7231#section-8.1) 中注册了 "PRI" 方法。

方法名：PRI  
安全性：是  
幂等性：是  
规范文档：[Section 3.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface)  
有关信息：这个方法实际上永远都不会被客户端使用。这个方法会出现在当一个 HTTP/1.1 服务器或者一个中间件尝试解析 HTTP/2 的连接序言。  

### 7. 421 HTTP 状态码

这一节在 "HTTP Status Codes" [[RFC7231], Section 8.2](https://tools.ietf.org/html/rfc7231#section-8.2)中注册了 421 (方向错误的请求) HTTP 状态码。

状态码：421  
简短描述：方向错误的请求  
规范：[Section 9.1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-421-%E7%8A%B6%E6%80%81%E7%A0%81)  


### 8. 关于 h2c 升级 token

这一节在 "HTTP Upgrade Tokens" [[RFC7230], Section 8.6](https://tools.ietf.org/html/rfc7230#section-8.6)中注册了 "h2c" 升级 token。  


值：h2c  
描述：Hypertext Transfer Protocol version 2 (HTTP/2)   
预期版本 tokens：无   
引用：[Section 3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#2-starting-http2-for-http-uris)    





------------------------------------------------------

Reference：  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http2-considerations/](https://halfrost.com/http2-considerations/)
> 