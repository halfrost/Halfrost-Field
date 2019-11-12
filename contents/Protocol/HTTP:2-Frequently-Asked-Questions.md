<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/131_0.png'>
</p>

# HTTP/2 中的常见问题

以下是有关 HTTP/2 的常见问题。

## 一. 一般的问题

### 1. 为什么要修改 HTTP？

HTTP/1.1 在 Web 上已经服务了 15 年以上，但是它的缺点正在开始显现。加载网页比以往任何时候都需要更多资源(请参阅[HTTP Archive’s page size statistics](http://httparchive.org/trends.php#bytesTotal&reqTotal))，并且要高效地加载所有这些资源非常困难，因为事实上，HTTP 只允许每个 TCP 连接有一个未完成的请求。

过去，浏览器使用多个 TCP 连接来发出并行请求。但是，这是有局限性的。如果使用的连接过多，则将适得其反(TCP 拥塞控制将被无效化，导致的用塞事件将会损害性能和网络)，并且从根本上讲是不公平的(因为浏览器会占用许多本不该属于它的资源)。同时，大量请求意味着“在线”上有大量重复数据。

这两个因素都意味着 HTTP/1.1 请求有很多与之相关的开销。如果请求过多，则会影响性能。

这使得业界误解了“最佳实践”，进行诸如 spriting 图片合并，data: inlining 内联数据，Domain Sharding 域名分片和 Concatenation 文件合并之类的事情。这些 hack 行为表明协议本身存在潜在问题，在使用的时候会出现很多问题。


### 2. 谁制定了 HTTP/2？

HTTP/2 是由 [IETF](http://www.ietf.org/) 的 [HTTP 工作组](https://httpwg.github.io/)开发的，该工作组维护 HTTP 协议。它由许多 HTTP 实现者，用户，网络运营商和 HTTP 专家组成。

请注意，虽然我们的[邮件列表](http://lists.w3.org/Archives/Public/ietf-http-wg/)托管在 W3C 网站上，但这并不是 W3C 的努力。但是，Tim Berners-Lee 和 W3C TAG 与 WG 的工作进度保持同步。

大量的人为这项工作做出了贡献，最活跃的参与者包括来自诸如 Firefox，Chrome，Twitter，Microsoft 的 HTTP stack，Curl 和 Akamai 等“大型”项目的工程师，以及许多诸如 Python、Ruby 和 NodeJS 之类的 HTTP 实现者。

要了解有关 IETF 的更多信息，请参见[Tao of the IETF](http://www.ietf.org/tao.html)。您还可以在 Github 的贡献者图中了解谁为规范做出了贡献，以及谁在我们的[实现列表](https://github.com/http2/http2-spec/wiki/Implementations)中参与该项目。


### 3. HTTP/2 与 SPDY 有什么关系？

HTTP/2 第一次出现并被讨论的时候，SPDY 正逐渐受到实现者(例如 Mozilla 和 nginx)的青睐时，并且被当成对 HTTP/1.x 的重大改进。

在征求提案和进行选择过程之后，选择 [SPDY/2](http://tools.ietf.org/html/draft-mbelshe-httpbis-spdy-00) 作为 HTTP/2 的基础。此后，根据工作组的讨论和实现者的反馈，进行了许多更改。在整个过程中，SPDY 的核心开发人员都参与了 HTTP/2 的开发，包括 Mike Belshe 和 Roberto Peon。2015 年 2 月，Google 宣布了其计划删除对 SPDY 的支持，转而支持 HTTP/2。


### 4. 是 HTTP/2.0 还是 HTTP/2？

工作组决定删除次版本（“.0”），因为它在 HTTP/1.x 中引起了很多混乱。换句话说，HTTP 版本仅表示网络兼容性，而不表示功能集或“亮点”。


### 5. HTTP/2 和 HTTP/1.x 的主要区别是什么？

在高版本的 HTTP/2 中：

- 是二进制的，而不是文本的
- 完全多路复用，而不是有序和阻塞
- 因此可以使用一个连接进行并行处理
- 使用头压缩​​来减少开销
- 允许服务器主动将响应"推送"到客户端缓存中


### 6. 为什么 HTTP/2 是二进制的？

与诸如 HTTP/1.x 之类的文本协议相比，二进制协议解析起来更高效，更“紧凑”，并且最重要的是，它们比二进制协议更不容易出错，因为它们对空格处理，大写，行尾，空白行等的处理很有帮助。例如，HTTP/1.1 定义了[四种不同的解析消息的方式](http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4)。在 HTTP/2 中，只有一个代码路径。

HTTP/2 在 telnet 中不可用，但是我们已经有了一些工具支持，例如 [Wireshark 插件](https://bugs.wireshark.org/bugzilla/show_bug.cgi?id=9042)。


### 7. 为什么 HTTP/2 需要多路复用？

HTTP/1.x 存在一个称为“队头阻塞”的问题，指的是一次连接（connection）中，只提交一个请求的效率比较高，多了就会变慢。


HTTP/1.1 试图通过管道修复此问题，但是并不能完全解决问题（较大或较慢的响应仍会阻止其他问题）。此外，由于许多中间件和服务器未正确处理管线化，因此很难部署它。

这迫使客户使用多种试探法（通常是猜测法）来决定通过哪些连接提交哪些请求；由于页面加载的数据量通常是可用连接数的 10 倍（或更多），因此会严重影响性能，通常会导致被阻止的请求“泛滥”。

多路复用通过允许同时发送多个请求和响应消息来解决这些问题。甚至有可能将一条消息的一部分与另一条消息混合在一起。所以在这种情况下，客户端只需要一个连接就能加载一个页面。


### 8. 为什么只有一个 TCP 连接？

使用 HTTP/1，浏览器打开每个站点需要 4 个到 8 个连接。现在很多网站都使用多点传输，因此这可能意味着单个页面加载会打开 30 多个连接。

一个应用程序打开如此多的连接，已经远远超出了当初设计 TCP 时的预想。由于每个连接都会响应大量的数据，这会造成中间网络中的缓冲区溢出的风险，从而导致网络拥塞事件并重新传输。

此外，使用这么多连接还会强占许多网络资源。这些资源都是从那些“遵纪守法”的应用那“偷”的（VoIP  就是个很好的例子）。


### 9. 服务器推送的好处是什么？

当浏览器请求页面时，服务器将在响应中发送 HTML，然后需要等待浏览器解析 HTML 并发出对所有嵌入资源的请求，然后才能开始发送 JavaScript，图像和 CSS。

服务器推送可以通过“推送”它认为客户端需要的响应到其缓存中，来避免服务器的这种往返延迟。

但是，“推送”响应不是“神奇的”——如果使用不正确，可能会损害性能。正确使用 Server Push 是正在进行的实验和研究领域。


### 10. 为什么我们需要头压缩？

Mozilla 的 Patrick McManus 通过计算平均页面加载消息头的效果，生动地展示了这一点。

假设一个页面包含大约 80 个资源需要加载（在当今的 Web 中是保守的），并且每个请求具有 1400 字节的消息头（这并不罕见，这要归功于 Cookie，Referer 等），至少要 7 到 8 个来回去“在线”获得这些消息头。这还不包括响应时间——那只是从客户端那里获取到它们所花的时间而已。

这是因为 TCP 的慢启动机制造成的，根据已确认的数据包数量，从而对新连接上发送数据的进行限制——有效地限制了最初的几次来回可以发送的数据包数量。

相比之下，即使对报头进行轻微的压缩，这些请求也可以在一次往返（甚至一个数据包）内搞定。

这种额外开销是相当大的，尤其是考虑到对移动客户端的影响时，即使在网络状况良好的条件下，移动客户端的往返延迟通常也要几百毫秒。


### 11. 为什么选择 HPACK？

SPDY/2 建议每个方都使用单独的 GZIP 上下文进行消息头压缩，该方法易于实现且效率很高。

从那时起，一个重要的攻击方式 [CRIME](http://en.wikipedia.org/wiki/CRIME) 诞生了，这种方式可以攻击加密文件内部的所使用的压缩流（如 GZIP）。

使用 CRIME，攻击者有能力将数据注入加密流中，并可以“探测”明文并恢复它。由于这是 Web，因此 JavaScript 使这成为可能，而且已经有了通过对受到 TLS 保护的 HTTP 资源的使用CRIME来还原出 cookies 和认证令牌（Toekn）的案例。

结果，我们无法使用 GZIP 压缩。没有找到适合该用例并且可以安全使用的其他算法，我们创建了一种新的，专门针对报头的压缩方案，该方案以粗粒度压缩模式运行；由于 HTTP 标头通常在消息之间不改变，因此仍然可以提供合理的压缩效率，并且更加安全。


### 12. HTTP/2 可以使 Cookie(或其他头字段)变得更好吗？

这一努力被许可在网络协议的一个修订版本上运行 —— 例如，HTTP 消息头、方法等等如何才能在不改变 HTTP 语义的前提下放到“网络上”。

这是因为 HTTP 被广泛使用。如果我们使用此版本的 HTTP 引入一种新的状态机制（例如之前讨论过的例子）或更改了核心方法（值得庆幸的是，尚未提出该方法），则意味着新协议与现有 Web 不兼容。

特别是，我们希望能够在不损失任何信息的情况下从 HTTP/1 转换为 HTTP/2。如果我们开始“清理”报头（并且大多数人会同意，因为 HTTP 报头很乱），将会出现很多与现有 Web 互操作性的问题。

这样做只会对新协议的普及造成麻烦。

综上所述，HTTP 工作组负责所有 HTTP，而不仅仅是 HTTP/2。这样，我们可以研究与版本无关的新机制，只要它们与现有 Web 向后兼容即可。


### 13. 非浏览器的 HTTP 用户呢？

如果非浏览器应用程序已经在使用 HTTP，则它们也应该能够使用 HTTP/2。

先前收到过 HTTP “APIs” 在 HTTP/2 中具有良好性能等特点这样的反馈，那是因为 API 不需要在设计中考虑诸如请求开销之类的问题。

话虽如此，我们正在考虑的改进的主要焦点是典型的浏览用例，因为这是该协议的核心用例。

我们的章程对此表示：


```c
The resulting specification(s) are expected to meet these goals for common existing deployments of HTTP; in particular, Web browsing (desktop and mobile), non-browsers ("HTTP APIs"), Web serving (at a variety of scales), and intermediation (by proxies, corporate firewalls, "reverse" proxies and Content Delivery Networks). Likewise, current and future semantic extensions to HTTP/1.x (e.g., headers, methods, status codes, cache directives) should be supported in the new protocol.

正在制定的规范需要满足现在已经普遍部署了的 HTTP 的功能要求；具体来说主要包括，Web 浏览（桌面端和移动端），非浏览器（“HTTP APIs” 形式的），Web 服务（大范围的），还有各种网络中介（借助代理，企业防火墙，反向代理以及内容分发网络实现的）。同样的，对 HTTP/1.x 当前和未来的语义扩展 (例如，消息头，方法，状态码，缓存指令) 都应该在新的协议中支持。


Note that this does not include uses of HTTP where non-specified behaviours are relied upon (e.g., connection state such as timeouts or client affinity,and "interception" proxies); these uses may or may not be enabled by the final product.

值得注意的是，这里没有包括将 HTTP 用于非特定行为所依赖的场景中（例如超时，连接状态以及拦截代理）。这些可能并不会被最终的产品启用。

```



### 14. HTTP/2 是否需要加密？

否。经过广泛讨论，工作组尚未对新协议必须要使用加密（例如 TLS）达成共识，。

但是，一些实现已声明它们仅在通过加密连接使用 HTTP/2 时才支持 HTTP/2，并且当前没有浏览器支持未加密的 HTTP/2。


### 15. HTTP/2 如何提高安全性？

HTTP/2 定义了必需的 TLS 配置文件；这包括了版本，密码套件黑名单和使用的扩展。

有关详细信息，请参见[规范](http://http2.github.io/http2-spec/#TLSUsage)。

还讨论了其他机制，例如对 HTTP:// URL 使用 TLS（所谓的“机会主义加密”）；参见 [RFC 8164](https://tools.ietf.org/html/rfc8164)。


### 16. 我现在可以使用 HTTP/2 吗？

在浏览器中，Edge，Safari，Firefox 和 Chrome 的最新版本都支持 HTTP/2。其他基于 Blink 的浏览器也将支持 HTTP/2（例如 Opera 和 Yandex Browser）。有关更多详细信息，请参见[这里](http://caniuse.com/#feat=http2)。

还有几种可用的服务器（包括 [Akamai](https://http2.akamai.com/)，[Google](https://google.com/) 和 [Twitter](https://twitter.com/) 的主要站点提供的 beta 支持），以及许多可以部署和测试的开源实现。

有关更多详细信息，请参见[实现列表](https://github.com/http2/http2-spec/wiki/Implementations)。


### 17. HTTP/2 会取代 HTTP/1.x 吗？

工作组的目的是让那些使用 HTTP/1.x 的人也可以使用 HTTP/2，并能获得 HTTP/2 所带来的好处。他们说过，由于人们部署代理和服务器的方式不同，我们不能强迫整个世界进行迁移，所以 HTTP/1.x 仍有可能要使用了一段时间。

### 18. 会有 HTTP/3 吗？

如果通过 HTTP/2 引入的协商机制运行良好，支持新版本的 HTTP 就会比过去更加容易。


## 二. 实现相关的问题

### 1. 为什么规则会围绕 HEADERS frame 的 Continuation？

存在连续性是因为单个值（例如 Set-Cookie）可能超过 16KiB-1，这意味着它无法放入单个帧中。决定处理该问题的最不容易出错的方法是要求所有消息头数据都以一个接一个帧的方式传递，这使得解码和缓冲区管理也变得更加容易。



### 2. HPACK 状态的最小或最大大小是多少？

接收方始终控制 HPACK 中使用的内存量，并且可以将其最小设置为 0，最大值与 SETTINGS 帧中的最大可表示整数（当前为 2^32-1）有关。


### 3. 如何避免保持 HPACK 状态？

发送一个 SETTINGS 帧，将状态尺寸（SETTINGS\_HEADER\_TABLE\_SIZE）设置到 0，然后 RST 所有的流，直到一个带有 ACT 设置位的 SETTINGS 帧被接收。


### 4. 为什么只有一个压缩/流控制上下文？

简单的说一下。

最初的提议里有流分组的概念，它可以共享上下文，流量控制等。虽然这将使代理受益（以及代理用户的体验），但这样做却增加了相当多的复杂性。所以我们就决定先以一个简单的东西开始，看看它会有多糟糕的问题，并且在未来的协议版本中解决这些问题（如果有的话）。


### 5. 为什么 HPACK 中有 EOS 符号？

HPACK 的霍夫曼编码，出于 CPU 效率和安全性的考虑，将霍夫曼编码的字符串填充到下一个字节边界；任何特定的字符串可能需要 0-7 位之间的填充。

如果单独考虑霍夫曼解码，那么任何比所需填充长的符号都可以工作；但是，HPACK 的设计允许按字节比较霍夫曼编码的字符串。通过要求将 EOS 符号的位用于填充，我们确保用户可以对霍夫曼编码的字符串进行字节比较，以确定是否相等。反过来，这意味着许多 headers 可以在不需要霍夫曼解码的情况下被解析。


### 6. 是否可以在不实现 HTTP/1.1 的情况下实现 HTTP/2？

是的，大部分情况都可以。

对于 TLS（h2）上的 HTTP/2 ，如果您未实现 http1.1 ALPN 标识符，则无需支持任何 HTTP/1.1 功能。

对于基于 TCP（h2c）的 HTTP/2 ，您需要实现初始 Upgrade 升级请求。

只支持 h2c 的客户端需要生成一个针对 OPTIONS 的请求，因为 “*” 或者一个针对 “/” 的 HEAD 请求，它们相当安全且易于构造。希望仅实现 HTTP/2 的客户端将需要将没有 101 状态码的 HTTP/1.1 响应视为错误。

只支持 h2c 的服务器可以使用一个固定的 101 响应来接收一个包含升级（Upgrade）消息头字段的请求。没有 h2c 升级令牌的请求可以通过包含 Upgrade 头字段的 505（不支持 HTTP 版本）状态码拒绝。不希望处理 HTTP/1.1 响应的服务器应在发送连接序言后，应该立即用 REFUSED\_STREAM 错误码拒绝 stream 1，以鼓励客户端通过 upgraded 的 HTTP/2 连接重试请求。


### 7. 第 5.3.2 节中的优先级示例不正确吗？

是正确的。流 B 的权重为 4，流 C 的权重为 12。要确定这些流中的每一个接收的可用资源的比例，请将所有权重相加（16），然后将每个流的权重除以总权重。因此，流 B 获得了四分之一的可用资源，流C获得了四分之三。因此，如规范所述：[流 B 理想地接收分配给流 C 的资源的三分之一](http://http2.github.io/http2-spec/#rfc.section.5.3.2)。


### 8. HTTP/2 连接需要 TCP\_NODELAY 么？

有可能需要。即使对于仅使用单个流下载大量数据的客户端实现，仍将有必要向相反方向发送一些数据包以实现最大传输速度。如果未设置 TCP\_NODELAY（仍允许 Nagle 算法），则传出数据包可能会保留一段时间，以允许它们与后续数据包合并。

例如，如果这样一个数据包告诉对等端有更多可用的窗口来发送数据，那么将其发送延迟数毫秒（或更长时间）会对高速连接造成严重影响。

## 三. 部署问题

### 1. 如果 HTTP/2 是加密的，我该如何调试？

有很多方法可以访问应用程序数据，但最简单的方法是 [NSS keylogging](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS/Key_Log_Format) 与 Wireshark 插件（包含在最新开发版本中）结合使用。这个方法对 Firefox 和 Chrome 均可适用。


### 2. 如何使用 HTTP/2 服务器推送


HTTP/2 服务器推送允许服务器无需等待请求即可向客户端提供内容。这可以改善检索资源的时间，特别是对于具有[大带宽延迟产品](https://en.wikipedia.org/wiki/Bandwidth-delay_product)的连接，其中网络往返时间占了在资源上花费的大部分时间。

推送基于请求内容而变化的资源可能是不明智的。目前，浏览器只会推送请求，如果他们不这样做，就会提出匹配的请求（请参阅 [RFC 7234 的第 4 节](https://tools.ietf.org/html/rfc7234#section-4)）。

某些缓存不考虑所有请求头字段中的变化，即使它们在 Vary 头字段中。为了使推送资源被接收的可能性最大化，内容协商是最好的选择。基于 accept-encoding 报头字段的内容协商受到缓存的广泛尊重，但是可能无法很好地支持其他头字段。


------------------------------------------------------

Reference：  

[HTTP/2 Frequently Asked Questions](https://http2.github.io/faq/)    

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
> 
> Source: [https://halfrost.com/http2-frequently-asked-questions/](https://halfrost.com/http2-frequently-asked-questions/)
> 