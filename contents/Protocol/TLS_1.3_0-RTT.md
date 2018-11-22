# TLS 1.3 0-RTT and Anti-Replay


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/112_0.png'>
</p>

如 [第2.3节](https://tools.ietf.org/html/rfc8446#section-2.3) 和 [附录 E.5](https://tools.ietf.org/html/rfc8446#appendix-E.5) 所述，TLS不为 0-RTT 数据提供固有的重放保护。有两个潜在的威胁值得关注:

- 通过简单地复制 0-RTT 数据并发送来进行重放攻击的网络攻击者

- 网络攻击者利用 Client 重试行为使 Server 接收多个应用程序消息的副本。这种威胁在某种程度上已经存在，因为重视健壮性的 Client 通过尝试重试请求来响应网络错误。但是，0-RTT 为任何不维护全局一致服务器状态的 Server 系统添加了额外的维度。具体来说，如果服务器系统有多个 zone，zone B 中不接受来自 zone A 的 ticket，则攻击者可以将 A 中的 ClientHello 和 early data 复制到 A 和 B。对于 A，数据将在 0-RTT 内被接收，但对于 B，Server 将拒绝 0-RTT 数据，而是强制进行完全握手。如果攻击者 block 了 A 的 ServerHello，那么 Client 将会与 B 完成握手并且很可能重试一次请求，从而导致整个服务器系统上出现重复。


通过共享状态可以防止第一类攻击，以保证最多接受一次 0-RTT 数据。Server 应该通过实现本文中描述的方法之一或通过等效方法提供一定级别的重放安全性。但是，据了解，由于操作问题，并非所有部署都将维持该级别的状态。因此，在正常操作中，Client 并不知道这些 Server 实际实现了哪些机制(如果有的话)，因此必须只发送他们认为可以安全重放的 early data。

除了重放的直接影响之外，还存在一类攻击，即使通常被认为是幂等的操作也会被大量重放(定时攻击，资源限制耗尽等，如 附录E.5 中所述)所利用。可以通过确保每个 0-RTT 有效载荷只能重播有限次数的方法来减轻这些问题。Server 必须确保它的任何实例(无论是机器，线程或相关服务基础设施内的任何其他实体)都可以接受 0-RTT，并且最多只能进行一次 0-RTT 握手;这样会将重放次数限制为部署中的 Server 实例数。可以通过本地记录最近收到的 ClientHellos 数据并拒绝重复的做法来实现，或者通过提供相同或更强保证的任何其他方法来完成。“一个 0-RTT，每个 Server 实例最多响应一次”，这个保证是最低要求;Server 应该在可行的情况下限制 0-RTT 进一步重放。

在 TLS 层无法阻止第二类攻击，必须由任何应用程序处理。请注意，任何具有 Client 实现了任何类型的重试行为的应用程序都需要实现某种反重放防御。


## 一. Single-Use Tickets


最简单的防重放防御形式是 Server 只允许使用一次会话 ticket。例如，Server 可以维护所有未完成的有效 ticket 的数据库，在使用时从数据库中删除每个 ticket。如果提供了未知 ticket，则 Server 将握手回退到完全握手。


如果 ticket 不是自包含的而是数据库密钥，并且在使用时删除相应的 PSK，则使用 PSK 建立的连接享有前向保密。当在没有 (EC)DHE 的情况下使用 PSK 时，这提高了所有 0-RTT 数据和 PSK 使用的安全性。

由于此机制要求在具有多个分布式服务器的环境中的 Server 节点之间共享会话数据库，因此与自加密 ticket 相比，可能难以保证在成功的 PSK 0-RTT 连接下的高速率。与会话数据库不同，即使没有一致性的存储，会话 ticket 也可以成功地进行基于 PSK 的会话建立，但是当允许 0-RTT 时，它们仍然需要一致性的存储来反重放 0-RTT 数据，如下节所述。



## 二. Client Hello Recording



另一种反重放形式是记录从 ClientHello 派生的唯一值(通常是随机值或 PSK binder)并拒绝重复。记录所有 ClientHello 会导致状态无限制地增长，但 Server 可以在给定时间窗口内记录 ClientHellos 并使用 "obfuscated\_ticket\_age" 来确保不在该窗口外重用 ticket。

为了实现这一点，当收到 ClientHello 时，Server 首先验证 PSK binder，如[4.2.11节](https://tools.ietf.org/html/rfc8446#section-4.2.11) 所述。然后它会计算 expected\_arrival\_time，如下一节所述，如果它在记录窗口之外，则拒绝 0-RTT，然后回到 1-RTT 握手。



如果 expected\_arrival\_time 在窗口中，则 Server 检查它是否记录了匹配的ClientHello。如果找到一个，它将使用 "illegal\_parameter" alert 消息中止握手或接受 PSK 但拒绝 0-RTT。如果找不到匹配的 ClientHello，则它接受 0-RTT，然后只要 expected\_arrival\_time 在窗口内，就存储 ClientHello。Server 也可以实现具有误报的数据存储，例如布隆过滤器，在这种情况下，它们必须通过拒绝 0-RTT 来响应明显的重放，但绝不能中止握手。

Server 必须仅从 ClientHello 的有效部分派生存储密钥。如果 ClientHello 包含多个 PSK 标识，则攻击者可以创建多个具有不同 binder 值的 ClientHellos，用于不太优选的标识，前提是服务器不会对其进行验证(如 [第4.2.11节](https://tools.ietf.org/html/rfc8446#section-4.2.11) 所述)。即，如果客户端发送PSK A和B但服务器更喜欢A，那么攻击者可以更改B的绑定程序而不影响A的绑定程序。如果B的绑定程序是存储密钥的一部分，则此ClientHello将不会出现作为重复，这将导致ClientHello被接受，并且可能导致副作用，例如重放缓存污染，尽管任何0-RTT数据都不会被解密，因为它将使用不同的密钥。如果使用经过验证的绑定程序或ClientHello.random作为存储密钥，则无法进行此攻击























------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()