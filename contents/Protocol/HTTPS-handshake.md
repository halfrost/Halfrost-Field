# HTTPS 温故知新（三） —— 握手流程


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/97_0.png'>
</p>


## 一、为什么需要握手




## 二、



## 三、TLS 1.2 首次握手流程



## 四、TLS 1.3 首次握手流程


## 五、TLS 1.2 第二次握手流程

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

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()