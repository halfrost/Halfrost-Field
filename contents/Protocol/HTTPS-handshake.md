# HTTPS 温故知新（三） —— 直观感受 TLS 握手流程


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0.png'>
</p>


## 一、为什么需要 TLS




## 二、TLS 的好处


## 三、TLS 对速度的影响

由于部署了 HTTPS，传输层增加了 TLS，对一个完成的请求耗时又会多增加一些。具体会增加几个 RTT 呢？

先来看看一个请求从零开始，完整的需要多少个 RTT。假设访问一个 HTTPS 网站，用户从 HTTP 开始访问，到收到第一个 HTTPS 的 Response，大概需要经历一下几个步骤(以目前最主流的 TLS 1.2 为例)：


流程 | 消耗时间 | 总计 |
---- | --- | ---
1. DNS 解析网站域名 | 1-RTT | |
2. 访问 HTTP 网页 TCP 握手 |  1-RTT | |
3. HTTPS 重定向 302 |  1-RTT | |
4. 访问 HTTPS 网页 TCP 握手|  1-RTT | |
5. TLS 记录层握手| 1-RTT||
6. 【证书校验】CA 站点的 DNS 解析| 1-RTT||
7. 【证书校验】CA 站点的 TCP 握手| 1-RTT||
8. 【证书校验】请求 OCSP 验证|1-RTT||
9. TLS 加密层握手| 1-RTT||
10. 第一个 HTTPS 请求| 1-RTT||
|||10-RTT|


在上面这些步骤中，1、10 肯定无法省去，6、7、8 如果浏览器本地有缓存，是可选的。将剩下的画在流程图上，见下图：

![](https://img.halfrost.com/Blog/ArticleImage/97_1.png)

针对上面的步骤进行一些说明：

如果网站做了 HSTS (HTTP Strict Transport Security)，那么上面的第 3 步就不存在，因为浏览器会直接替换掉 HTTP 的请求，变成 HTTPS 的，防止重定向的中间人攻击。

如果浏览器有主流 CA 的域名解析缓存，也不需要进行上面的第 6 步，直接访问即可。

如果浏览器关闭掉了 OCSP 或者是有本地缓存，那么也不需要进行上面的第 7 和第 8 步。

上面这 10 步是最最完整的流程，一般有各种缓存不会经历上面每一步。如果有各种缓存，并且有 HSTS 策略，那么用户访问一次的流程如下：

流程 | 消耗时间 | 总计 |
---- | --- | ---
1. DNS 解析网站域名 | 1-RTT | |
2. 访问 HTTPS 网页 TCP 握手 |  1-RTT | |
3. TLS 记录层握手| 1-RTT||
4. TLS 加密层握手| 1-RTT||
5. 第一个 HTTPS 请求| 1-RTT||
|||5-RTT|

除去 1、5 是无论如何都无法省掉的以外，剩下的就是 TCP 和 TLS 握手了。 TCP 想要减至 0-RTT，目前来看有点难。那 TLS 呢？目前 TLS 1.2 完整一次握手需要 2-RTT，能再减少一点么？答案是可以的。



## 三、TLS 1.2 首次握手流程



## 四、TLS 1.2 第二次握手流程


## 五、TLS 1.3 首次握手流程

为何会出现再次握手呢？这个就牵扯到了会话复用机制。

在 TLS 1.3 中，会话复用机制，一种是 session id 复用，一种是 session ticket 复用。session id 复用存在于服务端，session ticket 复用存在于客户端。


## 六、TLS 1.3 第二次握手流程

这里网上很多文章对 TLS 1.3 第二次握手有误解。经过自己实践以后发现了“真理”。

TLS 1.3 在宣传的时候就以 0-RTT 为主，大家都会认为 TLS 1.3 再第二次握手的时候都是 0-RTT 的，包括网上一些分析的文章里面提到的最新的 PSK 密钥协商，PSK 密钥协商并非是 0-RTT 的。

TLS 1.3 再次握手其实是分两种：会话恢复模式、0-RTT 模式

### 1. 会话恢复模式


### 2. 0-RTT 模式

先来看看 0-RTT 在整个草案里面的变更历史。

|    草案    | 变更 |
| ---------- | --- |
| draft-07   |  0-RTT 最早是在 draft-07 中加入了基础的支持 |
| draft-11   |  1. 在 draft-11 中删除了early\_handshake内容类型<br>2. 使用一个 alert 终止 0-RTT 数据 |
| draft-13   |  1. 删除 0-RTT 客户端身份验证<br>2. 删除 (EC)DHE 0-RTT<br>3. 充实 0-RTT PSK 模式并 shrink EarlyDataIndication |
| draft-14   |  1. 移除了 0-RTT EncryptedExtensions<br>2. 降低使用 0-RTT 的门槛<br>3. 阐明 0-RTT 向后兼容性<br>4. 说明 0-RTT 和 PSK 密钥协商的相互关系 |
| draft-15   |  讨论 0-RTT 时间窗口 |
| draft-16   |  1. 禁止使用 0-RTT 和 PSK 的 CertificateRequest<br>2. 放宽要求检查 SNI 的 0-RTT |
| draft-17   |  1. 删除 0-RTT Finished 和 resumption\_context，并替换为 PSK 本身的 psk\_binder 字段<br>2. 协调密码套件匹配的要求：会话恢复只需要匹配 KDF 但是对于 0-RTT 需要匹配整个密码套件。允许 PSK 实际去协商密码套件<br>3. 阐明允许使用 PSK 进行 0-RTT 的条件 |
| draft-21   |  关于 0-RTT 和重放的讨论，建议实现一些反重放机制 |

目前最新草案是 draft-28，从历史来看，人们从功能问题讨论到性能问题，最后讨论到安全问题。

------------------------------------------------------

Reference：
  
《图解 HTTP》    
《HTTP 权威指南》  
《深入浅出 HTTPS》    
[TLS1.3 draft-28](https://tools.ietf.org/html/draft-ietf-tls-tls13-28)  
[Keyless SSL: The Nitty Gritty Technical Details](https://blog.cloudflare.com/keyless-ssl-the-nitty-gritty-technical-details/)  
[大型网站的 HTTPS 实践（二）-- HTTPS 对性能的影响](https://developer.baidu.com/resources/online/doc/security/https-pratice-2.html)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()