# TLS 1.3 Cryptographic Computations


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/111_0.png'>
</p>

TLS 握手建立一个或多个输入的 secrets，如下文所述，将这些 secrets 组合起来以创建实际工作密钥材料。密钥派生过程包含输入 secrets 和握手记录。请注意，由于握手记录包含来自 Hello 消息的随机值，因此即使使用相同的输入 secrets，任何给定的握手都将具有不同的流量 secrets，就像将相同的 PSK 用于多个连接的情况一样。

## 一. Key Schedule

密钥派生过程使用 HKDF [[RFC5869]](https://tools.ietf.org/html/rfc5869) 定义的 HKDF-Extract 和 HKDF-Expand 函数，以及下面定义的函数:  

```c
       HKDF-Expand-Label(Secret, Label, Context, Length) =
            HKDF-Expand(Secret, HkdfLabel, Length)

       Where HkdfLabel is specified as:

       struct {
           uint16 length = Length;
           opaque label<7..255> = "tls13 " + Label;
           opaque context<0..255> = Context;
       } HkdfLabel;

       Derive-Secret(Secret, Label, Messages) =
            HKDF-Expand-Label(Secret, Label,
                              Transcript-Hash(Messages), Hash.length)
```

Transcript-Hash 和 HKDF 使用的 Hash 函数是密码套件哈希算法。Hash.length 是其输出长度(以字节为单位)。消息是表示的握手消息的串联，包括握手消息类型和长度字段，但不包括记录层头。请注意，在某些情况下，零长度 context（由 "" 表示）传递给 HKDF-Expand-Label。本文档中指定的 labels 都是 ASCII 字符串，不包括尾随 NUL 字节。

注意：对于常见的哈希函数，任何超过 12 个字符的 label 都需要额外迭代哈希函数才能计算。所有标准都已选择符合此限制。

密钥是从使用 HKDF-Extract 和 Derive-Secret 函数的两个输入 secrets 中派生出来的。添加新 secret 的一般模式是使用 HKDF-Extract，其中 Salt 是当前的 secret 状态，输入密钥材料(IKM)是要添加的新 secret 。在此版本的 TLS 1.3 中，两个输入 secrets 是:  

- PSK(外部建立的预共享密钥，或从先前连接的 resumption\_master\_secret 值派生的)

- (EC)DHE 共享 secret ([Section 7.4](https://tools.ietf.org/html/rfc8446#section-7.4))


这将生成一个完整的密钥推导计划，如下图所示。在此图中，约定以下的格式：

- HKDF-Extract 画在图上，它为从顶部获取 Salt 参数，从左侧获取 IKM 参数，它的输出是底部，和右侧输出的名称。

- Derive-Secret 的 Secret 参数由传入的箭头指示。例如，Early Secret 是生成 client\_early\_traffic\_secret 的 Secret。

- "0" 表示将 Hash.length 字节的字符串设置为零。


```c
             0
             |
             v
   PSK ->  HKDF-Extract = Early Secret
             |
             +-----> Derive-Secret(., "ext binder" | "res binder", "")
             |                     = binder_key
             |
             +-----> Derive-Secret(., "c e traffic", ClientHello)
             |                     = client_early_traffic_secret
             |
             +-----> Derive-Secret(., "e exp master", ClientHello)
             |                     = early_exporter_master_secret
             v
       Derive-Secret(., "derived", "")
             |
             v
   (EC)DHE -> HKDF-Extract = Handshake Secret
             |
             +-----> Derive-Secret(., "c hs traffic",
             |                     ClientHello...ServerHello)
             |                     = client_handshake_traffic_secret
             |
             +-----> Derive-Secret(., "s hs traffic",
             |                     ClientHello...ServerHello)
             |                     = server_handshake_traffic_secret
             v
       Derive-Secret(., "derived", "")
             |
             v
   0 -> HKDF-Extract = Master Secret
             |
             +-----> Derive-Secret(., "c ap traffic",
             |                     ClientHello...server Finished)
             |                     = client_application_traffic_secret_0
             |
             +-----> Derive-Secret(., "s ap traffic",
             |                     ClientHello...server Finished)
             |                     = server_application_traffic_secret_0
             |
             +-----> Derive-Secret(., "exp master",
             |                     ClientHello...server Finished)
             |                     = exporter_master_secret
             |
             +-----> Derive-Secret(., "res master",
                                   ClientHello...client Finished)
                                   = resumption_master_secret
```


这里的一般模式指的是，图左侧显示的 secrets 是没有上下文的原始熵，而右侧的 secrets 包括握手上下文，因此可以用来派生工作密钥而无需额外的上下文。请注意，对 Derive-Secret 的不同调用可能会使用不同的 Messages 参数，即使是具有相同的 secret。在 0-RTT 交换中，Derive-Secret 和四个不同的副本一起被调用;在 1-RTT-only 交换中，它和三个不同的副本一起被调用。

如果给定的 secret 不可用，则使用由设置为零的 Hash.length 字节串组成的 0 值。请注意，这并不意味着要跳过轮次，因此如果 PSK 未被使用，Early Secret 仍将是 HKDF-Extract(0,0)。对于 binder\_key 的计算，label 是外部 PSK(在 TLS 之外提供的那些)的 "ext binder" 和用于恢复 PSK 的 "res binder"(提供为先前握手的恢复主密钥的那些)。不同的 labels 阻止了一种 PSK 替代另一种 PSK。


这存在有多个潜在的 Early Secret 值，具体取决于 Server 最终选择的 PSK。Client 需要为每个潜在的 PSK 都计算一个值;如果没有选择 PSK，则需要计算对应于零 PSK 的 Early Secret。

一旦计算出了从给定 secret 派生出的所有值，就应该删除该 secret。



## 二. Updating Traffic Secrets

一旦握手完成后，任何一方都可以使用[第 4.6.3 节](https://tools.ietf.org/html/rfc8446#section-4.6.3)中定义的 KeyUpdate 握手消息更新其发送流量密钥。 下一代流量密钥的计算方法是，如本节所述，从 client\_ / server\_application\_traffic\_secret\_N 生成出 client\_ / server\_application\_traffic\_secret\_N + 1，然后按 [7.3 节](https://tools.ietf.org/html/rfc8446#section-7.3)所述方法重新导出流量密钥。

下一代 application\_traffic\_secret 计算方法如下：

```c
       application_traffic_secret_N+1 =
           HKDF-Expand-Label(application_traffic_secret_N,
                             "traffic upd", "", Hash.length)
```

一旦计算了 client\_ / server\_application\_traffic\_secret\_N + 1 及其关联的流量密钥，实现方应该删除 client\_ / server\_application\_traffic\_secret\_N 及其关联的流量密钥。




## 三. Traffic Key Calculation


流量密钥材料由以下输入值生成:

- secret 的值

- 表示正在生成的特定值的目的值

- 生成密钥的长度


使用输入流量 secret 的值生成流量密钥材料:

```c
  [sender]_write_key = HKDF-Expand-Label(Secret, "key", "", key_length)
   [sender]_write_iv  = HKDF-Expand-Label(Secret, "iv", "", iv_length)
```

[sender] 表示发送方。每种记录类型的 Secret 值显示在下表中:

```c
       +-------------------+---------------------------------------+
       | Record Type       | Secret                                |
       +-------------------+---------------------------------------+
       | 0-RTT Application | client_early_traffic_secret           |
       |                   |                                       |
       | Handshake         | [sender]_handshake_traffic_secret     |
       |                   |                                       |
       | Application Data  | [sender]_application_traffic_secret_N |
       +-------------------+---------------------------------------+
```


每当底层 Secret 更改时(例如，从握手更改为应用程序数据密钥或密钥更新时)，将重新计算所有流量密钥材料。

## 四. (EC)DHE Shared Secret Calculation

### 1. Finite Field Diffie-Hellman

对于有限的字段组合，执行传统的 Diffie-Hellman [[DH76]](https://tools.ietf.org/html/rfc8446#ref-DH76) 计算。协商密钥(Z)被转换成一个字节字符串，字符串以 big-endian 形式编码，并用零往左边填充到初始的大小。此字节字符串用作上面指定的密钥计划中的共享密钥。

请注意，此结构与先前版本的 TLS 不同，TLS 之前的版本删除了前导零。



### 2. Elliptic Curve Diffie-Hellman

对于 secp256r1，secp384r1 和 secp521r1，ECDH 计算(包括参数和密钥生成以及共享密钥计算)根据 [[IEEE1363]]() 使用 ECKAS-DH1 方案执行，身份映射作为密钥导出函数（KDF）， 因此，共享秘密是表示为八位字节串的ECDH共享秘密椭圆曲线点的x坐标。
 
注意，FE2OSP（字段元素到八位字符串转换基元）输出的该八位字节串（IEEE 1363术语中的“Z”）对于任何给定字段具有恒定长度; 在此八位字符串中找到的前导零不得截断。

（请注意，使用身份KDF是一种技术性。完整的图片是ECDH与非平凡的KDF一起使用，因为TLS不直接将此秘密用于计算其他秘密以外的任何其他内容。）



## 五. Exporters











------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()