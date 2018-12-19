# TLS 1.3 Overview of Security Properties


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/109_0.png'>
</p>


对 TLS 的完整安全性分析超出了本文的讨论范围。在本附录中，我们提供了对所需属性的非正式描述，以及对更加正式定义的研究文献中提出更详细工作的参考。

我们将握手的属性与记录层的属性分开。


## 一. Handshake

TLS 握手是经过身份验证的密钥交换(AKE，Authenticated Key Exchange)协议，旨在提供单向身份验证(仅 Server)和相互身份验证(Client 和 Server)功能。在握手完成时，每一侧都输出其以下值：


- 一组 "会话密钥"(从主密钥导出的各种秘密)，可以从中导出一组工作密钥。

- 一组加密参数（算法等）。

- 沟通各方的身份标识

我们假设攻击者是一个活跃的网络攻击者，这意味着它可以完全控制双方通信的网络 [[RFC3552]](https://tools.ietf.org/html/rfc3552)。即使在这些条件下，握手也应提供下面列出的属性。请注意，这些属性不一定是独立的，而是反映了协议消费者的需求的。

建立相同的会话密钥：握手需要在握手的两边输出相同的会话密钥集，前提是它在每个端点上成功完成（参见 [[CK01]](https://tools.ietf.org/html/rfc8446#ref-CK01)，定义1，第1部分）


会话密钥的保密性：共享会话密钥只能由通信方而不是攻击者所知（参见 [[CK01]](https://tools.ietf.org/html/rfc8446#ref-CK01)，定义 1，第 2 部分）。请注意，在单方面验证的连接中，攻击者可以与 Server 建立自己的会话密钥，但这些会话密钥与 Client 建立的会话密钥不同。

对等身份验证：Client 对等身份的视图应该反映 Server 的身份标识。如果 Client 已通过身份验证，则 Server 的对等标识视图应与 Client 的标识匹配。

会话密钥的唯一性：任何两个不同的握手都应该产生不同的，不相关的会话密钥。握手产生的各个会话密钥也应该是不同且独立的。

降级保护：双方的加密参数应该相同，并且应该与在没有攻击的情况下双方进行通信的情况相同（参见 [[BBFGKZ16]](https://tools.ietf.org/html/rfc8446#ref-BBFGKZ16)，定义 8 和 9）

关于长期密钥的前向保密：如果长期密钥材料（在这种情况下，是基于证书的认证模式中的签名密钥或具有 (EC)DHE 模式的 PSK 中的外部/恢复 PSK）在握手后完成后泄露了，只要会话密钥本身已被删除，这不会影响会话密钥的安全性（参见 [[DOW92]](https://tools.ietf.org/html/rfc8446#ref-DOW92)）。当在 "psk\_ke" PskKeyExchangeMode 中使用 PSK 时，不能满足前向保密属性。

密钥泄露模拟 (KCI，Key Compromise Impersonation) 抵抗性：在通过证书进行相互认证的连接中，泄露一个参与者的长期密钥不应该破坏该参与者在这个给定连接中对通信对端的认证（参见 [[HGFS15]](https://tools.ietf.org/html/rfc8446#ref-HGFS15)）。例如，如果 Client 的签名密钥被泄露，则不应该在随后的握手中模拟任意的 Server 和 Client 进行通信。

端点身份的保护：应该保护 Server 的身份(证书)免受被动攻击者的攻击。应该保护 Client 的身份免受被动和主动攻击者的攻击。

非正式地，TLS 1.3 的基于签名的模式，提供了由 (EC)DHE 密钥交换建立的唯一的，保密的共享密钥，并且在握手的基础上，通过 Server 的签名进行认证，一个 Mac 与 Server 的身份相关联。如果 Client 通过证书进行身份验证，它还会根据握手记录进行签名并提供与这两个身份标识相关联的 MAC。[[SIGMA]](https://tools.ietf.org/html/rfc8446#ref-SIGMA) 描述了这种密钥交换协议的设计和分析。如果每个连接使用新的 (EC)DHE 密钥，则输出密钥是前向保密的。

外部 PSK 和恢复 PSK 让长期共享秘密转换为每个连接唯一的短期会话密钥集。这个密钥可能是在之前的握手中建立的。如果使用具有 (EC)DHE 密钥建立的 PSK，则这些会话密钥也将是前向保密的。已经设计了恢复 PSK，使得由连接 N 计算并且形成连接 N + 1 所需的恢复主秘密与连接 N 使用的业务密钥分开，从而在连接之间提供前向保密。 此外，如果在同一连接上建立了多个票证，则它们与不同的密钥相关联，因此与一个票证相关联的PSK的泄密不会导致与与其他票证相关联的PSK建立的连接的危害。 如果票证存储在数据库中（因此可以删除）而不是它们是自加密的，则此属性最有趣


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()