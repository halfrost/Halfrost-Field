# TLS 1.3 Backward Compatibility


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/115_0.png'>
</p>


TLS 协议为端点之间的版本协商提供了一个内置机制，让支持不同版本的 TLS 成为了可能。

TLS 1.x 和 SSL 3.0 使用兼容的 ClientHello 消息。只要 ClientHello 消息格式保持兼容并且 Client 和 Server 都至少共同能支持一个协议版本，Server 就可以尝试使用未来版本 TLS 来回应 Client。

TLS 的早期版本使用记录层版本号(TLSPlaintext.legacy\_record\_version 和 TLSCiphertext.legacy\_record\_version)用于各种目的。从 TLS 1.3 开始，此字段被废弃了。所有实现都必须忽略 TLSPlaintext.legacy\_record\_version 的值。TLSCiphertext.legacy\_record\_version 的值包含在不被保护的附加数据中，但可以忽略或者可以验证，以此匹配固定的常量值。只能使用握手版本执行版本协商(ClientHello.legacy\_version 和 ServerHello.legacy\_version 以及ClientHello，HelloRetryRequest 和 ServerHello 中的 "supported\_versions" 扩展名)。为了最大限度地提高与旧的端点的互操作性，协商使用 TLS 1.0-1.2 的实现方应该将记录层版本号设置为协商版本，这样做是为了 ServerHello 和以后的所有记录。


为了最大限度地兼容以前的非标准行为和配置错误的部署，所有实现方都应该支持基于本文档中的期望验证认证的方法，即使在处理先前的 TLS 版本的握手时也是如此(参见 [第4.4.2.2节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-server-certificate-selection))。

TLS 1.2 和之前版本支持 "Extended Master Secret" [RFC7627](https://tools.ietf.org/html/rfc7627) 扩展，它将握手记录的大部分内容消化为主密钥。因为 TLS 1.3 总是从转录开始到 Server Finish 都在计算哈希，所以同时支持 TLS 1.3 和早期版本的实现方，无论是否使用了 TLS 1.3，都应该表明在其 API 中使用了Extended Master Secret extension。

## 一、Negotiating with an Older Server

一个 TLS 1.3 的 Client 希望与不支持 TLS 1.3 的 Server 协商，Client 将在ClientHello.legacy\_version 中发送包含 0x0303(TLS 1.2) 的普通 TLS 1.3 ClientHello，但在 "supported\_versions" 扩展中使用正确的版本。如果 Server 不支持 TLS 1.3，它将使用包含旧版本号的 ServerHello 进行响应。如果 Client 同意使用此版本，则协商将根据协商协议进行。使用 ticket 恢复会话的 Client 应该使用先前协商的版本发起连接。

请注意，0-RTT 数据与旧的 Server 不兼容，并且在不知道 Server 支持TLS 1.3的情况下就不应该发送 0-RTT。见 [附录D.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%B8%89-0-rtt-backward-compatibility)。

如果 Client 不支持 Server 选择的版本(或者不可接受)，Client 必须通过 "protocol\_version" alert 消息中止握手。

已知一些传统 Server 实现不能正确实现 TLS 规范，并且可能在遇到他们不知道的版本或 TLS 扩展时中止连接。与错误 Server 的互操作性是一个超出本文档范围的复杂主题。可能需要多次连接尝试才能协商向后兼容的连接;但是，这种做法很容易受到降级攻击，并且不推荐。

## 二. Negotiating with an Older Client

TLS Server 可以接收 ClientHello，说明版本号小于其支持的最高版本。如果存在 "supported\_versions"扩展，则 Server 必须使用该扩展进行协商，如 [第4.2.1节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions) 所述。 如果  "supported\_versions" 扩展名不存在，则 Server 必须协商 ClientHello.legacy\_version 和 TLS 1.2 的最小值。例如，如果 Server 支持 TLS 1.0,1.1 和 1.2，并且 legacy\_version 是 TLS 1.0，则 Server 将使用 TLS 1.0 进行 ServerHello。如果 "supported\_versions" 扩展名不存在且 Server 仅支持大于 ClientHello.legacy\_version 的版本，则 Server 必须使用 "protocol\_version" alert 消息中止握手。


请注意，早期版本的 TLS 并未在所有情况下明确指定记录层版本号值(TLSPlaintext.legacy\_record\_version)。Server 将在此字段中接收到各种 TLS 1.x 版本，但必须始终忽略它的值。


## 三. 0-RTT Backward Compatibility

0-RTT 数据与旧 Server 不兼容。较旧的 Server 将使用较旧的 ServerHello 响应 ClientHello，但它不会正确跳过 0-RTT 数据，并且无法完成握手。当 Client 尝试使用 0-RTT 时，这可能会导致问题，尤其是针对多 Server 部署的情况。例如，部署可以逐步部署 TLS 1.3，其中一些 Server 实现 TLS 1.3，一些 Server 实现 TLS 1.2，或者 TLS 1.3 部署可以降级为 TLS 1.2。

尝试发送 0-RTT 数据的 Client 如果收到 TLS 1.2 或更早版本的 ServerHello，则必须使导致连接失败。然后，它可以在禁用 0-RTT 的情况下重试连接。为了避免降级攻击，Client 不应该禁用 TLS 1.3，而是只禁用 0-RTT。

为了避免这种错误情况，多 Server 部署应该在启用 0-RTT 之前，确保在没有 0-RTT 的情况下统一和稳定地部署 TLS 1.3。

## 四. Middlebox Compatibility Mode

现场测试 [Ben17a](https://tools.ietf.org/html/rfc8446#ref-Ben17a) [Ben17b](https://tools.ietf.org/html/rfc8446#ref-Ben17b) [Res17a](https://tools.ietf.org/html/rfc8446#ref-Res17a) [Res17b](https://tools.ietf.org/html/rfc8446#ref-Res17b) 发现当 TLS 客户端/服务器对协商 TLS 1.3 时，大量中间件行为表现不正确。实现方通过使 TLS 1.3 握手看起来更像是 TLS 1.2 握手，来增加通过这些中间件建立连接的机会。


- Client 始终在 ClientHello 中提供非空的 session ID，如 [第4.1.2节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello) 的 legacy\_session\_id 部分所述。

- 如果不提供 early data，Client 会在第二次发送数据之前立即发送虚拟的 change\_cipher\_spec 记录(参见第5节第3段)。这可能在其第二个 ClientHello 之前或在其加密的发送握手数据之前。如果提供 early data，则 record 会立即放在第一个 ClientHello 之后。

- Server 在第一次握手消息之后立即发送虚拟 change\_cipher\_spec 记录。这可能是在 ServerHello 或 HelloRetryRequest 之后。

放在一起时，这些更改使 TLS 1.3 握手类似于 TLS 1.2 会话恢复，这提高了通过中间件成功建立连接的机会。这种 "兼容模式" 是部分协商的：Client
 可以选择是否提供会话 ID，Server 必须回应它。任何一方都可以在握手期间随时发送 change\_cipher\_spec，因为它们必须被对等方忽略，但是如果 Client 一旦发送了非空的会话 ID，Server 必须按照本附录中的描述发送 change\_cipher\_spec。



## 五. Security Restrictions Related to Backward Compatibility


协商使用旧版 TLS 的实现方应该更倾向于使用前向密钥和AEAD密码套件(如果可用的话)。

由于 [RFC7465](https://tools.ietf.org/html/rfc7465) 中引用的原因，RC4 密码套件的安全性已经被认为是不安全的了。实现方绝不能出于任何原因为任何版本的 TLS 提供或协商 RC4 密码套件。

旧版本的 TLS 允许使用非常低强度的密码。现在不管是任何原因，任何版本的 TLS 都不能提供或协商强度低于 112 位的密码。

由于 [RFC7568](https://tools.ietf.org/html/rfc7568) 中列举的原因，SSL 3.0 [RFC6101](https://tools.ietf.org/html/rfc6101) 的安全性已经被认为是不安全的了，所以现在不能以任何理由再进行协商了。

由于 [RFC6176](https://tools.ietf.org/html/rfc6176) 中列举的原因，SSL 2.0 [SSL2](https://tools.ietf.org/html/rfc8446#ref-SSL2) 的安全性已经被认为是不安全的了，所以现在不能以任何理由再进行协商了。

实现方现在绝不能再发送兼容 SSL 2.0 的 CLIENT-HELLO。实现方不得使用兼容 SSL 2.0 的 CLIENT-HELLO 协商 TLS 1.3 或更高版本。不推荐实现方接受兼容 SSL 版本 2.0 的 CLIENT-HELLO 以协商旧版本的 TLS。

实现方绝不能将 ClientHello.legacy\_version 或 ServerHello.legacy\_version 设置为 0x0300 或更低。任何接收到ClientHello.legacy\_version 或 ServerHello.legacy\_version 设置为 0x0300 的 Hello 消息的端点必须使用 "protocol\_version" alert 消息中止握手。

实现方绝不能发送版本低于 0x0300 的任何记录。实现方不应该接受版本低于 0x0300 的任何记录(但如果完全忽略记录版本号，可能会无意中这样做)。

实现方绝不能使用 [RFC6066 第7节](https://tools.ietf.org/html/rfc6066#section-7) 中定义的 Truncated HMAC 扩展，因为它不适用于 AEAD 算法，并且在某些情况下已被证明是不安全的



------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Backward\_Compatibility/](https://halfrost.com/tls_1-3_backward_compatibility/)