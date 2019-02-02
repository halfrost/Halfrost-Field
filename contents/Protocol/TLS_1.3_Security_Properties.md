# TLS 1.3 Overview of Security Properties


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/116_0.png'>
</p>


对 TLS 的完整安全性分析超出了本文的讨论范围。在本附录中，我们提供了对所需属性的非正式描述，以及对更加正式定义的研究文献中提出更详细工作的参考。

我们将握手的属性与记录层的属性分开。


## 一. Handshake

TLS 握手是经过身份验证的密钥交换(AKE，Authenticated Key Exchange)协议，旨在提供单向身份验证(仅 Server)和相互身份验证(Client 和 Server)功能。在握手完成时，每一侧都输出其以下值：


- 一组 "会话密钥"(从主密钥导出的各种密钥)，可以从中导出一组工作密钥。

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

外部 PSK 和恢复 PSK 使长期共享密钥转换为每个连接唯一的短期会话密钥集。这个密钥可能是在之前的握手中建立的。如果是使用由 (EC)DHE 密钥建立的 PSK，则这些会话密钥也将是前向保密的。已经设计了恢复 PSK，使得由 N 个连接计算出来的并且形成 N + 1 个连接所需的恢复主密钥与 N 个连接使用的流量密钥分开，从而在连接之间提供前向保密性。 此外，如果在同一连接上建立了多个 ticket，则它们与不同的密钥相关联，因此与一个 ticket 相关联的 PSK 的泄密不会导致与其他 ticket 相关联的 PSK 建立的连接也泄密。如果 ticket 存储在数据库中(因此可以删除)而不是它们是自加密的，则此属性最有趣。

PSK 绑定器的值使得 PSK 与当前握手之间构成绑定关系，以及在建立 PSK 的会话与当前会话之间构成绑定关系。这种绑定传递性地包含了原始握手记录，因为该记录被用来产生恢复主密钥的值。这要求用于产生恢复主密钥的 KDF 和用于计算 binder 的 MAC 都是防碰撞的。有关详细信息，请参阅[附录 E.1.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#1-key-derivation-and-hkdf)。注意：binder 不包括其他 PSK 的 binder 的值，但它们包含在 Finished 的 MAC 中。


TLS 当前不允许 Server 在不是基于证书的握手(例如，PSK)中发送 certificate\_request 消息。如果未来放宽此限制，Client 的签名将不会直接覆盖 Server 的证书。但是，如果 PSK 是通过 NewSessionTicket 建立的，则 Client 的签名将通过 PSK binder 传递并覆盖 Server 的证书。[PSK-FINISHED](https://tools.ietf.org/html/rfc8446#ref-PSK-FINISHED) 描述了对未绑定到 Server 证书的结构的具体攻击（另请参阅 [Kraw16](https://tools.ietf.org/html/rfc8446#ref-Kraw16)）。当 Client 与两个不同的端点共享相同的 PSK / 密钥ID对时，在这种情况下，使用基于证书的 Client 身份验证是不安全的。实现方绝不能将外部 PSK 与 Client 或 Server 的基于证书的身份验证方式相结合，除非通过某些扩展协商。


如果使用 exporter，则它会生成唯一且保密的值(因为它们是从唯一的会话密钥生成的)。使用不同标签和不同上下文进行计算的 exporter 在计算上是独立的，因此根据 exporter 反推算会话密钥是不可行的，根据一个 exporter 计算另外一个 exporter 也是不可行的。注意：exporter 可以生成任意长度的值; 如果要将 exporter 被用作通道绑定，则导出的值必须足够大以提供防碰撞性。TLS 1.3 中提供的 exporter 分别来自与早期流量密钥和应用程序流量密钥相同的握手上下文，因此具有类似的安全属性。请注意，它们不包括 Client 的证书;未来希望绑定到 Client 的证书的应用程序可能需要定义包含完整握手记录的新的 exporter。


对于所有握手模式，Finished 的 MAC(以及存在的签名)可防止降级攻击。此外，如 [第4.1.3节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-server-hello) 所述，在随机 nonce 中使用某些字节可以检测出降级到 TLS 以前版本的情况。有关 TLS 1.3 和降级的更多详细信息，请参阅 [BBFGKZ16](https://tools.ietf.org/html/rfc8446#ref-BBFGKZ16)。

一旦 Client 和 Server 交换了足够的信息建立了共享密钥，握手的剩余部分就会被加密，从而提供针对被动攻击者的防护，即使计算的共享密钥未经过身份验证也能提供加密保护。由于 Server 在 Client 之前进行身份验证，因此 Client 可以确保如果 Client  对 Server 进行身份验证，则只会向已经经过身份验证的 Server 显示其身份。请注意，实现方必须在握手期间使用提供的记录填充机制，(记录填充机制可以混淆长度信息)以避免由于长度而泄露有关身份的信息。Client 提议的 PSK 标识如果未加密，那么也不是 Server 选择的标识。


### 1. Key Derivation and HKDF

TLS 1.3 中的密钥派生使用 [[RFC5869]](https://tools.ietf.org/html/rfc5869) 中定义的 HKDF 及其两个组件 HKDF-Extract 和 HKDF-Expand。HKDF 数据结构可以在 [[Kraw10]](https://tools.ietf.org/html/rfc8446#ref-Kraw10) 中找到，以及在 [[KW16]](https://tools.ietf.org/html/rfc8446#ref-KW16) 中说明了如何在 TLS 1.3 中合理使用的方式。在整个文档中，HKDF-Extract 的每个应用都会进行一次或多次 HKDF-Expand 的调用。应始终遵循此顺序(包括在本文档的未来修订版本中); 特别是，我们不应使用 HKDF-Extract 的输出直接作为 HKDF-Extract 的另一个应用程序的输入，而没有在中间进行一次 HKDF-Expand 调用。只要能通过密钥或标签区分这些输入，就允许多个 HKDF-Expand 应用使用相同的输入。

请注意，HKDF-Expand 实现了具有可变长度的输入和输出的伪随机函数(PRF)。在本文中，HKDF 的一些用途(例如，用于生成 exporters 和 resumption\_master\_secret)，HKDF-Expand 的应用必须具有抗冲突性; 也就是说，两个不同的输入值，是不可能出现输出相同值的 HKDF-Expand。这要求底层散列函数具有抗冲突性，并且 HKDF-Expand 的输出长度至少为 256 位(或者其他为了防止发现冲突的哈希函数所需要的长度)。

### 2. Client Authentication

在握手期间或握手后身份验证期间，已将身份验证数据发送到 Server 的 Client 无法确定 Server 之后是否认为 Client 已经过身份验证。如果 Client 需要确定 Server 是否认为连接是单方面认证的或双方相互认证的，则必须由应用层进行配置。有关详细信息，请参见 [[CHHSV17]](https://tools.ietf.org/html/rfc8446#ref-CHHSV17)。 另外，来自 [[Kraw16]](https://tools.ietf.org/html/rfc8446#ref-Kraw16) 的握手后认证分析表明，在握手后阶段中发送的证书所识别的 Client 拥有流量密钥。因此，该方要么是参与原始握手的 Client ，要么是为原始 Client 代理流量密钥的 Client(假设流量密钥未被泄露)。


### 3. 0-RTT

0-RTT 操作模式通常提供类似于 1-RTT 数据的安全属性，但有两个例外，即 0-RTT 加密密钥不提供完全前向保密性，并且 Server 在不保留过多的状态的条件下，无法保证握手的唯一性(不可重复性)。有关限制重放风险的机制，请参阅 [第8节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay)。


### 4. Exporter Independence

exporter\_master\_secret 和 early\_exporter\_master\_secret 的派生独立于流量密钥，因此不会对使用这些密钥加密的流量的安全性构成威胁。但是，因为这些密钥可以用来计算任何 exporter 的值，所以它们应该尽快删除。如果已知 exporter 标签的总集合，则实现方应该在计算 exporter 的期间，为所有这些标签预先计算内部的 Derive-Secret，然后只要知道删掉不再需要它，就可以立即删除紧跟在每个内部值后面的 [early\_] exporter\_master\_secret。


### 5. Post-Compromise Security

TLS 不提供在对等方的长期密钥(签名密钥或外部 PSK)泄露之后发生的握手的安全性。因此，它不提供泄露后的安全性 [[CCG16]](https://tools.ietf.org/html/rfc8446#ref-CCG16)，有时也称为后向或未来保密性。这与抗 KCI 性相反，抗 KCI 性描述的是通信的一方在其自身的长期密钥泄露之后所拥有的安全保障。


### 6. External References

读者应参考以下参考文献来分析 TLS 握手：[[DFGS15]](https://tools.ietf.org/html/rfc8446#ref-DFGS15)，[[CHSV16]](https://tools.ietf.org/html/rfc8446#ref-CHSV16)，[[DFGS16]](https://tools.ietf.org/html/rfc8446#ref-DFGS16)，[[KW16]](https://tools.ietf.org/html/rfc8446#ref-KW16)，[[Kraw16]](https://tools.ietf.org/html/rfc8446#ref-Kraw16)，[[FGSW16]](https://tools.ietf.org/html/rfc8446#ref-FGSW16)，[[LXZFH16]](https://tools.ietf.org/html/rfc8446#ref-LXZFH16)，[[FG17]](https://tools.ietf.org/html/rfc8446#ref-FG17) 和 [[BBK17]](https://tools.ietf.org/html/rfc8446#ref-BBK17)。



## 二. Record Layer


记录层依赖于握手产生强大的流量密钥，流量密钥可用于导出双向加密密钥和随机数。假设这是真的，并且密钥不再用于 [第5.5节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%BA%94-limits-on-key-usage) 中所示的数据，那么记录层应该提供以下保证:


- 保密性：攻击者不应该能够推测出给定记录的明文内容。

- 完整性：攻击者不应该能够创建，可以被接收者接收的新消息，这条新消息是与现有记录不同的新记录。

- 顺序保护/不可重放性：攻击者不应该使接收者接受已经接受的记录(不可重放性)，或者使接收者接受记录 N + 1 而不必先处理记录 N(顺序性)。

- 长度隐藏：针对一条具有给定外部长度的记录，攻击者不应该能够确定内容与填充的记录量。

- 密钥更改后的前向保密：如果使用了 [第4.6.3节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update) 中描述的流量密钥更新机制并删除了上一代密钥，则打算破坏端点的攻击者不应该能够解密使用旧密钥加密的密文。


非正式地，TLS 1.3 通过 AEAD 提供安全属性 - 用强密钥保护明文。AEAD 加密 [[RFC5116]](https://tools.ietf.org/html/rfc5116) 为数据提供机密性和完整性。通过对每个记录使用单独的随机数来提供不可重放性，其中随机数来自记录序列号([第5.3节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%89-per-record-nonce))，序列号在两侧独立维护; 因此，无序传送的记录导致 AEAD 脱保护失败。不同用户在同一密钥下重复加密相同的明文时(通常是HTTP的情况)，为了在这种情况下防止大量的密码分析，通过将序列号与随着流量密钥一起导出的每个连接初始化向量的密钥相互混合来形成随机数。有关此结构的分析，请参见 [[BT16]](https://tools.ietf.org/html/rfc8446#ref-BT16)。


TLS 1.3 中的密钥更新技术(参见 [第7.2节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%BA%8C-updating-traffic-secrets))遵循 [[REKEY]](https://tools.ietf.org/html/rfc8446#ref-REKEY) 中讨论的串行生成器的构造，它表明密钥更新可以允许密钥用于大量加密而不需要重新加密。这依赖于作为伪随机函数(PRF) —— HKDF-Expand-Label 函数的安全性。此外，只要这个函数是真正的一种方式，就不可能在密钥更改之前计算流量密钥(前向保密性)。

在该连接的流量密钥被泄露之后，TLS 不为在连接上传送的数据提供安全性。也就是说，TLS 不提供泄露后关于流量密钥的安全性/未来保密性/后向保密性。实际上，了解流量密钥的攻击者可以计算该连接上的所有未来的流量密钥。需要防御此类攻击的系统需要进行新的握手并用 (EC)DHE 交换建立新连接。



### 1. External References

读者应参考以下参考文献分析TLS记录层：[[BMMRT15]](https://tools.ietf.org/html/rfc8446#ref-BMMRT15)，[[BT16]](https://tools.ietf.org/html/rfc8446#ref-BT16)，[[BDFKPPRSZZ16]](https://tools.ietf.org/html/rfc8446#ref-BDFKPPRSZZ16)，[[BBK17]](https://tools.ietf.org/html/rfc8446#ref-BBK17) 和 [[PS18]](https://tools.ietf.org/html/rfc8446#ref-PS18)

## 三. Traffic Analysis

基于观察加密数据包的长度和时间，TLS 易受各种流量分析攻击 [[CLINIC]](https://tools.ietf.org/html/rfc8446#ref-CLINIC) [[HCJC16]](https://tools.ietf.org/html/rfc8446#ref-HCJC16)。当存在一小组可能的消息要区分时，特别容易做到。例如托管固定内容集的视频服务器，甚至在更复杂的场景中仍然提供可用信息。

TLS 不提供针对此类攻击的任何特定防御，但提供了一个供应用程序使用的填充机制：受 AEAD 功能保护的明文，由内容和可变长度填充组成，允许应用程序生成任意长度的加密记录，也允许仅仅只填充，目的是为了覆盖流量以隐藏传输周期和静默期之间的差异。由于填充是与实际内容一起加密的，所以攻击者无法直接确定填充的长度，但可以通过使用在记录处理期间暴露的定时通道间接测量填充(即，查看处理记录所需的时间长度或者在记录中 trickling，看看哪些引起 Server 的响应)。通常，不知道如何删除所有的这些通道，因为即使是恒定时间填充删除功能也可能将内容提供给依赖于数据的功能。至少，完全恒定时间的 Server 或 Client 需要与应用层协议实现密切合作，包括使创造更高级别的协议保持恒定时间。

注意：由于传输数据包的延迟和流量增加，强大的流量分析防御体系可能会导致性能下降。

## 四. Side-Channel Attacks

通常，TLS 没有针对侧信道攻击的特定防御手段(即那些通过辅助信道，例如校时，攻击通信)，而是将这些攻击留给相关加密原语的实现方。但是，TLS 的某些功能是为了使编写防御侧信道攻击的代码更加容易：


- 与先前 TLS 版本中使用复合 MAC-then-encrypt 结构的不同，TLS 1.3 仅使用 AEAD 算法，允许实现方使用这些原语自包含的常量时间去实现。

- TLS 对所有解密错误使用统一的 "bad\_record\_mac" alert 消息，目的是为了防止攻击者获得对消息部分的分段的监听。通过用这种错误来终止连接来提高攻击者的门槛;新连接将具有不同的加密材料，从而防止通过多次试验对加密基元进行的攻击。


通过侧信道的信息泄漏可能发生在 TLS 以上的层，例如应用协议和使用它们的应用中。对侧信道攻击的防御取决于应用和应用协议，它们两者要分别确保机密信息不会无意间的泄露。






## 五. Replay Attacks on 0-RTT


可重复使用的 0-RTT 数据对使用 TLS 的应用程序提出了许多安全威胁，除非这些应用程序经过专门设计，即使在重放的时候也能保证安全(最低限度，这意味着幂等，但在许多情况下可能还需要其他更强的条件，例如常数时间的响应)。潜在的攻击包括：

- 导致副作用（例如，购买物品或转移金钱）的动作被重复复制，从而损害站点或用户。

- 攻击者可以存储和重放 0-RTT 消息，为了使用其他消息来对它们进行重新排序(例如，原本是先删除再创建，改变为先创建再删除)。

- 利用缓存定时行为通过将 0-RTT 消息重放到不同的缓存节点然后使用单独的连接来测量请求延迟来发现 0-RTT 消息的内容，通过这种方式也可以查看这两个请求是否寻址相同的资源。

如果数据可以被重放很多次，则可能发生额外的攻击，例如重复测量加密操作的速度。此外，他们可能会导致有速度限制的系统超负荷。有关这些攻击的进一步说明，请参阅 [[Mac17]](https://tools.ietf.org/html/rfc8446#ref-Mac17)



最终，Server 有责任保护自己免受使用 0-RTT 数据复制的攻击。[第8节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay) 中描述的机制旨在防止在 TLS 层重放，但不提供对防止接收到 Client 数据的多个副本这种情况的完全保护。当 Server 没有关于 Client 的任何信息时，TLS 1.3 会回退到 1-RTT 握手，例如，如[第8.1节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets)所述，因为 Client 位于不共享状态的不同集群中，或者因为 ticket 已被删除。如果应用层协议在此设置中重新传输数据，则攻击者可能通过将 ClientHello 发送到原始群集(这个集群会立即处理数据)和另一个将回退到 1-RTT 的群集来引发消息重复，造成了应用层重放时需要处理数据。此攻击的规模受到 Client 重试事务意愿的限制，因此只允许有限量的重复，Server 会把每个重复的副本视为一个新的连接。

如果实现方实现的正确的话，[第 8.1 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets) 和 [第 8.2 节](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording)中描述的机制会阻止 ClientHello 重放及其关联的 0-RTT 数据被具有一致状态的任何群集接受多次;对于将 0-RTT 的使用范围限制为一个集群一个 ticket 的 Server，那么给定的 ClientHello 及其关联的 0-RTT 数据将仅被接受一次。但是，如果状态不完全一致，则攻击者可能能够在复制窗口期间接受多个数据副本。由于 Client 不知道 Server 行为的具体细节，因此它们不得在 early data 中发送不安全的重放消息，并且他们也不愿意在多个 1-RTT 连接中重试这些消息。


如果没有定义其用途的配置文件，应用程序协议绝不能使用 0-RTT 数据。该配置文件需要确定哪些消息或哪些交互可以安全地与 0-RTT 一起使用，以及在 Server 拒绝 0-RTT 并回退到 1-RTT 时如何处理这种情况。


此外，为避免无意间的误用，除非应用程序特别要求，否则 TLS 实现方不得启用 0-RTT (发送方或者接受方)。除非应用程序做出了相关指示，否则如果 Server 拒绝了 0-RTT，就不得自动重新发送 0-RTT 数据。Server 端应用程序可能希望对某些类型的应用程序流量实现 0-RTT 数据的特殊处理(例如，中止连接，请求在应用程序层重新发送数据，或延迟处理直到握手完成)。为了允许应用程序实现这种处理，TLS 实现方必须为应用程序提供一种方法来确定握手是否已完成。



### 1. Replay and Exporters

ClientHello 的重放产生了相同的早期 exporter，因此需要对使用这些 exporter 的应用程序进行额外的关注。特别地，如果这些 exporter 被用作认证通道绑定(例如，对 exporter 的输出进行签名)，则破解了 PSK 的攻击者可以在不破解认证密钥的条件下，在连接之间移植认证。

此外，早期的 exporter 不应该用于生成 Server 到 Client 的加密密钥，因为这意味着重用这些密钥。这与仅在 Client 到 Server 方向上使用早期应用程序流量密钥相似。


## 六. PSK Identity Exposure

由于实现方通过中止握手来响应无效的 PSK 绑定器，因此攻击者可能会去验证给定的 PSK 身份是否有效。具体来说，如果 Server 同时接受外部 PSK 握手和基于证书的握手，则有效的 PSK 身份将导致握手失败，而只是被跳过的无效身份却可以证书握手成功。单独支持 PSK 握手的 Server 可以通过处理没有有效 PSK 身份的情况，和存在身份但却具有相同无效 binder 的这两种情况来抵抗这种形式的攻击。

## 七. Sharing PSKs

TLS 1.3 对 PSK 采取了保守的方法，具体做法是将 PSK 绑定到具体的 KDF。相比之下，TLS 1.2 允许 PSK 与任何散列函数和 TLS 1.2 PRF 一起使用。 因此，想在 TLS 1.2 和 TLS 1.3 中一起使用的任何 PSK 必须在 TLS 1.3 中仅使用一个散列，如果用户想要提供单个 PSK，则这不是最佳的方法。TLS 1.2 和 TLS 1.3 中的结构是不同的，尽管它们都基于 HMAC 的。虽然没有已知的方法可以在两个版本中使用相同的 PSK 产生相关输出，但只是进行了有限的分析。通过不在 TLS 1.3 和 TLS 1.2 之间重用 PSK，实现方可以确保跨协议相关输出的安全性。

## 八. Attacks on Static RSA

尽管 TLS 1.3 不使用 RSA 密钥传输，因此不会直接受到 Bleichenbacher 类型攻击 [[Blei98]](https://tools.ietf.org/html/rfc8446#ref-Blei98) 的影响，如果 TLS 1.3 Server 在早期版本的 TLS 环境中也支持静态 RSA，那么对于TLS 1.3连接可能会出现冒充的 Server [[JSS15]](https://tools.ietf.org/html/rfc8446#ref-JSS15)。TLS 1.3 实现方可以通过在所有版本的 TLS 上禁用对静态 RSA 的支持来防止此类攻击。原则上，实现方也可能能够将具有不同 keyUsage 位的证书分开用于静态 RSA 解密和 RSA 签名，但是该技术依赖于 Client 拒绝使用没有设置 digitalSignature 位的证书中的密钥来接受签名，并且许多 Client 不强制执行此限制。


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_Security\_Properties/](https://halfrost.com/tls_1-3_security_properties/)