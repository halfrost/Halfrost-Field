<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/128_0.png'>
</p>

# HTTP/2 中的值得关注的问题


## 一. HTTP 值得关注的问题

本节概述了 HTTP 协议的属性，这些属性可提高互操作性，减少已知安全漏洞的风险或降低实现方在代码实现的时候出现歧义的可能性。

### 1. 连接管理

HTTP/2 连接是持久的。为了获得最佳性能，建议客户端不要主动关闭连接。除非在确定不需要与服务器进行进一步通信(例如，当用户离开特定网页时)或服务器关闭连接的时候再去关闭连接。

客户端不应该打开与给定主机和端口对的多个 HTTP/2 连接，其中主机包括是从 URI，选定的备用服务 [ALT-SVC](https://tools.ietf.org/html/rfc7540#ref-ALT-SVC) 或配置的代理中派生出来的。

客户端可以创建其他连接作为替换，以替换可用的流标识符空间即将用完的连接（[第 5.1.1 节](https://tools.ietf.org/html/rfc7540#section-5.1.1)），刷新 TLS 连接的密钥材料，或替换遇到错误的连接（[第 5.4.1 节](https://tools.ietf.org/html/rfc7540#section-5.4.1)）。

客户端可以对一个 IP 打开多个连接，并且 TCP 端口可以使用不同服务器标识 [TLS-EXT](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) 或者提供不同的 TLS 客户端证书，但应该避免使用相同的配置创建多个连接。

鼓励服务器尽可能长时间地保持打开的连接，但如果有需要，允许服务器终止空闲连接。当任一端点选择关闭传输层 TCP 连接时，发起终止的端点应首先发送 GOAWAY 帧（[第 6.8 节](https://tools.ietf.org/html/rfc7540#section-6.8)），这样做能够使得两个端点可以可靠地确定先前发送的帧是否已被处理并正常完成或者终止任何必要的剩余任务。


### (1). 连接重用


直接或通过使用 CONNECT 方法创建的隧道的方式（[第 8.3 节](https://tools.ietf.org/html/rfc7540#section-8.3)）对原始服务器建立的连接，可以重用于具有多个不同 URI 权限组件的请求。只要原始服务器具有权限，就可以重用连接（[第 10.1 节](https://tools.ietf.org/html/rfc7540#section-10.1)）。对于没有 TLS 的 TCP 连接，这取决于已解析为相同 IP 地址的主机。

对于 "https" 资源，连接重用还取决于具有对 URI 中的主机的证书是否有效。服务器提供的证书必须要能通过客户端在 URI 中为主机建立新的 TLS 连接时将执行的任何检查。

源服务器可能提供具有多个 "subjectAltName" 属性的证书或带有通配符的名称，其中一个对 URI 中的权限有效。例如，"subjectAltName" 为 "* .example.com" 的证书可能允许对以 "https://a.example.com/" 和 "https://b.example.com/" 开头的 URI 的请求使用相同的连接。


在某些部署中，重用多个源的连接可能导致请求被定向到错误的源服务器。例如，TLS 可能被网络中间件关闭，

终止可能是由于使用了 TLS 服务器名称指示(SNI)[[TLS-EXT]](https://tools.ietf.org/html/rfc7540#ref-TLS-EXT) 扩展名来选择源服务器的中间件执行。 这意味着客户端可以将机密信息发送到可能不是请求的预期目标的服务器，即使服务器具有其他权威性。

不希望客户端重用连接的服务器可以通过发送响应请求的421（错误请求）状态代码来指示它对请求不具有权威性（参见第9.1.2节）。

配置为通过HTTP / 2使用代理的客户端通过单个连接将请求定向到该代理。 也就是说，通过代理发送的所有请求都重用与代理的连接。




### (2). 421 状态码

### 2. 使用 TLS 特性

### (1). TLS 1.2 特性

### (2). TLS 1.2 加密套件


## 二. 安全问题

### 1. 服务器权限

### 2. 跨协议攻击


### 3. 中介封装攻击


### 4. 推送响应的可缓存性


### 5. 关于拒绝服务

### (1). 限制头块大小

### (2). 连接问题

### 6. 使用压缩

### 7. 使用填充


### 8. 关于隐私的注意事项


## 三. IANA 注意事项


### 1. HTTP/2 标识字符串注册



### 2. 帧类型注册


### 3. Settings 注册


### 4. 错误码注册


### 5. HTTP2-Settings 头字段注册


### 6. PRI 方法注册



### 7. 421 HTTP 状态码


### 8. 关于 h2c 升级 token





------------------------------------------------------

Reference：  

[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()