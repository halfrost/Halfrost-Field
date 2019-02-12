# TLS 1.3 0-RTT and Anti-Replay


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/112_0_.png'>
</p>

如 [第2.3节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3.md#3-0-rtt-%E6%95%B0%E6%8D%AE) 和 [附录 E.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%BA%94-replay-attacks-on-0-rtt) 所述，TLS不为 0-RTT 数据提供固有的重放保护。有两个潜在的威胁值得关注:

- 通过简单地复制 0-RTT 数据并发送来进行重放攻击的网络攻击者

- 网络攻击者利用 Client 重试行为使 Server 接收多个应用程序消息的副本。这种威胁在某种程度上已经存在，因为重视健壮性的 Client 通过尝试重试请求来响应网络错误。但是，0-RTT 为任何不维护全局一致服务器状态的 Server 系统添加了额外的维度。具体来说，如果服务器系统有多个 zone，zone B 中不接受来自 zone A 的 ticket，则攻击者可以将 A 中的 ClientHello 和 early data 复制到 A 和 B。对于 A，数据将在 0-RTT 内被接收，但对于 B，Server 将拒绝 0-RTT 数据，而是强制进行完全握手。如果攻击者 block 了 A 的 ServerHello，那么 Client 将会与 B 完成握手并且很可能重试一次请求，从而导致整个服务器系统上出现重复。


通过共享状态可以防止第一类攻击，以保证最多接受一次 0-RTT 数据。Server 应该通过实现本文中描述的方法之一或通过等效方法提供一定级别的重放安全性。但是，据了解，由于操作问题，并非所有部署都将维持该级别的状态。因此，在正常操作中，Client 并不知道这些 Server 实际实现了哪些机制(如果有的话)，因此必须只发送他们认为可以安全重放的 early data。

除了重放的直接影响之外，还存在一类攻击，即使通常被认为是幂等的操作也会被大量重放(定时攻击，资源限制耗尽等，如 附录 E.5 中所述)所利用。可以通过确保每个 0-RTT 有效载荷只能重播有限次数的方法来减轻这些问题。Server 必须确保它的任何实例(无论是机器，线程或相关服务基础设施内的任何其他实体)都可以接受 0-RTT，并且最多只能进行一次 0-RTT 握手;这样会将重放次数限制为部署中的 Server 实例数。可以通过本地记录最近收到的 ClientHellos 数据并拒绝重复的做法来实现，或者通过提供相同或更强保证的任何其他方法来完成。“一个 0-RTT，每个 Server 实例最多响应一次”，这个保证是最低要求;Server 应该在可行的情况下限制 0-RTT 进一步重放。

在 TLS 层无法阻止第二类攻击，必须由任何应用程序处理。请注意，任何具有 Client 实现了任何类型的重试行为的应用程序都需要实现某种反重放防御。


## 一. Single-Use Tickets


最简单的防重放防御形式是 Server 只允许使用一次会话 ticket。例如，Server 可以维护所有未完成的有效 ticket 的数据库，在使用时从数据库中删除每个 ticket。如果提供了未知 ticket，则 Server 将握手回退到完全握手。


如果 ticket 不是自包含的而是数据库密钥，并且在使用时删除相应的 PSK，则使用 PSK 建立的连接享有前向保密。当在没有 (EC)DHE 的情况下使用 PSK 时，这提高了所有 0-RTT 数据和 PSK 使用的安全性。

由于此机制要求在具有多个分布式服务器的环境中的 Server 节点之间共享会话数据库，因此与自加密 ticket 相比，可能难以保证在成功的 PSK 0-RTT 连接下的高速率。与会话数据库不同，即使没有一致性的存储，会话 ticket 也可以成功地进行基于 PSK 的会话建立，但是当允许 0-RTT 时，它们仍然需要一致性的存储来反重放 0-RTT 数据，如下节所述。



## 二. Client Hello Recording



另一种反重放形式是记录从 ClientHello 派生的唯一值(通常是随机值或 PSK binder)并拒绝重复。记录所有 ClientHello 会导致状态无限制地增长，但 Server 可以在给定时间窗口内记录 ClientHellos 并使用 "obfuscated\_ticket\_age" 来确保不在该窗口外重用 ticket。

为了实现这一点，当收到 ClientHello 时，Server 首先验证 PSK binder，如[4.2.11节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension) 所述。然后它会计算 expected\_arrival\_time，如下一节所述，如果它在记录窗口之外，则拒绝 0-RTT，然后回到 1-RTT 握手。



如果 expected\_arrival\_time 在窗口中，则 Server 检查它是否记录了匹配的 ClientHello。如果找到一个，它将使用 "illegal\_parameter" alert 消息中止握手或接受 PSK 但拒绝 0-RTT。如果找不到匹配的 ClientHello，则它接受 0-RTT，然后只要 expected\_arrival\_time 在窗口内，就存储 ClientHello。Server 也可以实现具有误报的数据存储，例如布隆过滤器，在这种情况下，它们必须通过拒绝 0-RTT 来响应明显的重放，但绝不能中止握手。

Server 必须仅从 ClientHello 的有效部分派生存储密钥。如果 ClientHello 包含多个 PSK 标识，则攻击者可以创建多个具有不同 binder 值的 ClientHellos，用于不太优选的标识，前提是 Server 不会对其进行验证(如 [第4.2.11节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension) 所述)。即，如果 Client 发送PSK A 和 B 但 Server 选择了 A，那么攻击者可以更改 B 的 binder 而不影响 A 的 binder。如果 B 的 binder 是存储密钥的一部分，则此 ClientHello 将不会重复出现，这将导致该 ClientHello 被接受，并且可能导致副作用，例如重放缓存污染，尽管任何 0-RTT 数据都不会被解密，因为它使用的不同的密钥。如果使用经过验证的 binder 或 ClientHello.random 作为存储密钥，则无法进行此攻击。


因为这种机制不需要存储所有未完成的 ticket，所以可能更容易在具有高恢复率和 0-RTT 的分布式系统中实现，代价可能是较弱的反重放防御，因为难以可靠地存储和检索收到 ClientHello 消息。在许多这样的系统中，对所有接收的 ClientHellos 进行全局一致的存储是不切实际的。在这种情况下，最好的反重放攻击的方法是，单个存储 zone 具有一个权威性的 ticket，并且不接受来自其他 zone 的 0-RTT 的 ticket。此方法可防止攻击者进行简单重放，因为只有一个 zone 可接受 0-RTT 数据。较弱的设计是为每个 zone 实现单独存储，但允许在任何 zone 中使用 0-RTT。此方法将每个 zone 的重放次数限制为一次。当然，上述的设计仍然可能导致应用程序消息重复。

当实现方刚刚启动的时候，只要其记录窗口的任何部分与启动时间重叠，它们就应该拒绝 0-RTT。否则，接收最初在这段时间内发送的重放是会有风险的。


注意：如果 Client 的时钟运行速度比 Server 快，那么将来在窗口外可能会收到一个 ClientHello，在这种情况下，它可能被 1-RTT 接受，导致 Client 重试，然后再接受  0-RTT。这是 [第 8 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay) 中描述的第二种攻击形式的另一种变体。


## 三. Freshness Checks


因为 ClientHello 中包含了 Client 发送它的时间，所以可以有效地确定 ClientHello 是否是最近合理地发送，是否仅接受这样的 ClientHello 的 0-RTT，如果不符合规则，就回退到 1-RTT 握手。这对于 [8.2节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording) 中描述的 ClientHello 存储机制是必要的，否则 Server 需要存储无限数量的 ClientHellos，并且这个存储机制对于自包含的一次性 ticket 是非常有用的优化，因为它可以有效拒绝不能用于 0-RTT 的 ClientHellos。

为了实现这种机制，Server 需要存储 Server 生成 session ticket 的时间，并通过估计 Client 和 Server 之间的往返时间来抵消。例如:

```c
adjusted_creation_time = creation_time + estimated_RTT
```

该值可以在 ticket 中编码，从而避免还要为每个未完成的 ticket 保持状态。Server 可以通过从客户端的 "pre\_shared\_key" 扩展名中的 "obfuscated\_ticket\_age" 参数中减去 ticket 的 "ticket\_age\_add" 值来确定 Client 的 ticket 有效时间。Server 可以将 ClientHello 的 expected\_arrival\_time 确定为:

```c
expected_arrival_time = adjusted_creation_time + clients_ticket_age
```

当收到新的 ClientHello 时，然后用 expect\_arrival\_time 与当前 Server 时间进行比较，如果它们相差超过一定数量，则拒绝 0-RTT，尽管 1-RTT 握手也能完成。


有几个潜在的错误来源可能会导致 expected\_arrival\_time 和测量时间不匹配。Client 和 Server 时钟速率的变化可能性是最小的，但可能会出现绝对时间可能很大的情况，最终导致关闭。网络传播延迟是导致时间不匹配的最可能的原因。NewSessionTicket 和 ClientHello 消息都可能被重传并因此被延迟，这可能被 TCP 隐藏。对于互联网上的 Client，这意味着大约有 10 秒的窗口可以解决时钟错误和测量变化的问题;其他部署方案可能有不同的需求。时钟偏差分布不是对称的，因此最佳方法应该是在允许有一定误差值的非对称范围内去权衡。


请注意，单独的有效时间检查不足以防止重放，因为在错误窗口期间检测不到它们，这取决于带宽和系统容量，可能包括实际环境中的数十亿次重放。此外，此有效时间的检查仅在收到 ClientHello 时完成，而不是在收到后续 early Application Data 记录的时候完成。在 early data 被接受了之后，记录可以继续在更长的时间内流式传输到 Server。






------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_0-RTT/](https://halfrost.com/tls_1-3_0-rtt/)