<p align='center'>
<img src='../images/tcp-ip.png'>
</p>


## 一. OSI 模型

OSI 参考模型终究只是一个“模型”，它也只是对各层的作用做了一系列粗略的界定，并没有对协议和接口进行详细的定义。它对学习和设计协议只能起到一个引导的作用。因此，若想要了解协议的更多细节，还是有必要参考每个协议本身的具体规范。



<p align='center'>
<img src='../images/OSI.png'>
</p>

上图是 《图解 TCP/IP》书上对七层模型的定义。

| 层 | 层级 |说明 |  备注|
| :---: | :---: | :---: | :---: |
| 应用层 | 7 | 为应用程序提供服务并规定应用程序中通信相关的细节| | 
| 表示层 | 6 | 将应用处理的信息转换为适合网络传输的格式，具体来说，将设备固有的数据格式转换为网络标准传输格式，不同设备对同一比特流解释的结果可能会不同| 主要负责数据格式的转换|
| 会话层 | 5 | 负责建立和断开通信连接（数据流动的逻辑通路），以及数据的分割等数据传输相关的管理||
| 传输层 | 4 | 起着可靠传输的作用。只在通信双方节点上进行处理，而无需在路由器上处理。||
| 网络层 | 3 | 将数据传输到目标地址。||
| 数据链路层 | 2 | 负责物理层面上互连的、节点之间的通信传输||
| 物理层 | 1 |负责 0、1 比特流（0、1 序列）与电压的高低、光的闪灭之间的互换||


<p align='center'>
<img src='../images/OSI_Layer.png'>
</p>

上图是一些协议在 OSI 模型中的位置。值得注意的是 DNS 是应用层协议，SSL 分别位于第五层会话层和第六层表示层。TLS 位于第五层会话层。（DNS、SSL、TLS 这些协议会在后面详细分析与说明）


<p align='center'>
<img src='../images/OSI-TCP-Model-v1.png'>
</p>

上图是 TCP/IP 模型和 OSI 模型的对比图。


接下来放2张网络上的图，笔者对图上的内容持有争议，至于下面2张图哪里对哪里错，欢迎开 issue 讨论。

<p align='center'>
<img src='../images/network-protocol-map-2017-min.png'>
</p>

上面这种图说 DNS 是网络层协议，笔者周围很多朋友都一致认为是应用层协议。还有一个错误是 SSL 是跨第六层和第七层的，这里画的还是不对。

<p align='center'>
<img src='../images/Protocol_Layer.png'>
</p>

上面这种图中 DNS 位于应用层，这点赞同，并且也画出了 DNS 是基于 UDP 和 TCP 的。这点也非常不错！（至于有些人不知道 DNS 为何也是基于 TCP 的，这点在 DNS 那里详细分析）。但是上图中没有画出 SSL/TLS 是位于第几层的。

笔者认为上面2张图，虽然看上去非常复杂，内容详尽，但是仔细推敲，还是都有不足和不对的地方。

## 二. OSI 参考模型通信举例

<p align='center'>
<img src='../images/TCP-IP-package.png'>
</p>

上图是 5 层 TCP/IP 模型中通信时候的数据图。值得说明的一点，在数据链路层的以太网帧里面，除去以太网首部 14 字节，FCS 尾部 4 字节，中间的数据长度在 46-1500 字节之间。


<p align='center'>
<img src='../images/how-data-is-processed-in-OSI-and-TCPIP-models.png'>
</p>



<p align='center'>
<img src='../images/package_struc.png'>
</p>



上图是 OSI 7 层模型中通信时候的数据图。从上图的 7 层模型中，物理层传输的是字节流，数据链路层中包的单位叫，帧。IP、TCP、UDP 网络层的包的单位叫，数据报。TCP、UDP 数据流中的信息叫，段。最后，应用层协议中数据的单位叫，消息。

从第七层应用层一层层的往下，不断的包裹一些协议头，这些协议的头就相当于协议的脸。

<p align='center'>
<img src='../images/Internet_package.png'>
</p>

上图是《网络是怎样连接的》这本书附录里面的一张图。

从上面三种图里面我们可以清楚的看到，一个应用和另一个应用或者和服务器通信，数据是如何流转的。


## 三. TCP/IP 的标准化流程

TCP/IP 协议的标准化流程大致分为以下几个阶段：首先是互联网草案阶段；其次，如果认为可以进行标准化，就记入 RFC 进入提议标准阶段；第三，是草案标准阶段；最后，才进入真正的标准阶段。


<p align='center'>
<img src='../images/Protocol_ standardization.png'>
</p>


## 四. 以太网帧结构


在以太网帧前面有一段前导码（Preamble）的部分，用来对端网卡能够确保与其同步的标志。前导码的末尾有一个叫 SFD（Start Frame Delimiter）的域，以太网的 SFD 是末尾的2位 11，IEEE802.3 的 SFD 是末尾的8位，10101011 。

<p align='center'>
<img src='../images/behind_frame.png'>
</p>

以太网帧和 IEEE802.3 帧的结构也有所不同，见下图。

<p align='center'>
<img src='../images/frame.png'>
</p>

帧尾都有一个 4 字节的 FCS（Frame Check Sequence）。FCS 表示帧校验序列(Frame Check Sequence)，用于判断帧是否在传输过程中有损坏(比如电子噪声干扰)。FCS 保存着发送帧除以某个多项式的余数，接收到的帧也做相同计算，如果得到的值与 FCS 相同则表示没有出错。

以太网帧比较常见，所以详细说说以太网帧结构。除去目标 Mac 地址，源 Mac 地址，再就是一个类型码。

| 类型编号（16进制） | 协议| |
| :---: | :---: | :---: |
|0000-05DC| IEEE802.3 Length Field (01500)||
|0101-01FF|实验用||
|0800| Internet IP (IPv4)|❤|
|0806| Address Resolution Protocol (ARP)|❤|
|8035| Reverse Address Resolution Protocol (RARP)|❤|
|8037| IPX (Novell NetWare)||
|805B| VMTP (Versatile Message Transaction Protocol) ||
|809B| AppleTalk (EtherTalk)||
|80F3| AppleTalk Address Resolution Protocol (AARP)||
|8100| IEEE802.1Q Customer VLAN| |
|814C| SNMP over Ethernet| |
|8191| NetBIOS/NetBEUI||
|817D| XTP||
|86DD| IP version (IPv6)|❤|
|8847-8848| MPLS (Multi-protocol Label Switching)||
|8863| PPPoE Discovery Stage||
|8864| PPPoE Session Stage||
|9000| Loopback (Configuration Test Protocol)||



<p align='center'>
<img src='../images/thernet_frame.png'>
</p>

再来看看 IEEE802.3 帧结构。IEEE802.3 帧结构比以太网帧多了几个部分：帧长度、LLC、SNAP。

数据链路层可以细分成2层：介质访问控制层(Media Access Control,MAC) 和 逻辑链路控制层(Longical Link Control,LLC)。介质访问控制层根据以太网或 FDDI 等不同数据链路所特有的首部信息进行控制。逻辑链路控制层则根据以太网或 FDDI 等不同数据链路所共有的帧头信息进行控制。


<p align='center'>
<img src='../images/LLC_SNAP.png'>
</p>

SNAP 总共5个字节，除去前3个字节代表厂商以外，后面2个字节和以太网帧的类型字段含义一样。

在 VLAN 交换机中，帧的结构还会被追加4个字节，成为下面这样子：


<p align='center'>
<img src='../images/VLAN_Frame.png'>
</p>


## 五. IP 协议

网络层主要由 IP (Internet Protocol) 和 ICMP (Internet Control Message Protocol) 组成。

IP 属于面向无连接类型，原因有两点：一是为了简化，二是为了提速。为了把数据包发送到最终目标地址，尽最大努力。简单，高速。而可靠性就交给了 TCP 去完成。


每种数据链路的最大传输单元 (Maximum Transmission Unit，MTU)都不同。

以太网一个帧最大可传输 1500 个字节，FDDI 可以最大传输 4352 字节，ATM 最大传输 9180 字节。

|数据链路| MTU (字节) | 总长度 (单位为字节，包含 FCS) |  |
| :---: | :--: | :--: | :--: |
| IP 的最大 MTU | 65535 | - ||
| Hyperchannel | 65535 | - ||
| IP over HIPPI | 65280 | 65320 ||
| 16Mbps IBM Token Ring | 17914| 17958||
| IP over ATM | 9180 | - |❤|
| IEEE802.4 Token Bus | 8166 | 8191 ||
| IEEE802.5 Token Bus | 4464 | 4508 ||
| FDDI | 4352 | 4500 |❤|
| 以太网 | 1500 | 1518 |❤|
| PPP (Default) | 1500| -|❤|
| IEEE802.3 Ethernet | 1492 | 1518 |❤|
| PPPoE | 1492 | - ||
| X.25 | 576 | -||
| IP 的最小 MTU | 68 | - ||

由于 MTU 的不同，所以导致了 IP 的分片和重组。路由器只进行分片，终点 (目标主机) 进行重组。

在路由器进行分片处理的过程中，如果出现了某个分片丢失，那么就会造成整个 IP 数据报作废，为了应对这种问题，产生了 路径 MTU 发现的技术。

主机会首先获取整个路径中所有数据链路的最小MTU，并按照整个大小将数据分片。因此传输过程中的任何一个路由器都不用进行分片工作。

为了找到路径MTU，主机首先发送整个数据包，并将IP首部的禁止分片标志设为1.这样路由器在遇到需要分片才能处理的包时不会分片，而是直接丢弃数据并通过ICMP协议将整个不可达的消息发回给主机。

主机将ICMP通知中的MTU设置为当前MTU，根据整个MTU对数据进行分片处理。如此反复下去，直到不再收到ICMP通知，此时的MTU就是路径MTU。

以UDP协议发送数据为例：

<p align='center'>
<img src='../images/MTU_Path.png'>
</p>





## 常用端口

|应用| 应用层协议 | 端口号 | 运输层协议 | 备注 |
| :---: | :--: | :--: | :--: | :--:|
| 域名解析 | DNS | 53 | UDP/TCP | 长度超过 512 字节时使用 TCP |
| 动态主机配置协议 | DHCP | 67/68 | UDP | |
| 简单网络管理协议 | SNMP | 161/162 | UDP | |
| 文件传送协议 | FTP | 20/21 | TCP | 控制连接 21，数据连接 20
| 远程终端协议 | TELNET | 23 | TCP | |
|超文本传送协议 | HTTP | 80 | TCP | |
| 简单邮件传送协议 | SMTP | 25 | TCP | |
| 邮件读取协议 | POP3 | 110 | TCP | |
| 网际报文存取协议 | IMAP | 143 | TCP | |



------------------------------------------------------

Reference：  
《图解 TCP/IP》  
《TCP/IP 详解 卷1:协议》  
《网络是怎样连接的》

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()