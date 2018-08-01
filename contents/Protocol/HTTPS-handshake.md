# HTTPS 温故知新（三） —— 握手流程


<p align='center'>
<img src='https://ob6mci30g.qnssl.com/Blog/ArticleImage/97_0.png'>
</p>


## 一、为什么需要握手




## 二、



## 三、TLS 1.2 首次握手流程



## 四、TLS 1.3 首次握手流程


## 五、TLS 1.2 第二次握手流程

为何会出现再次握手呢？这个就牵扯到了会话复用机制。

在 TLS 1.3 中，会话复用机制，一种是 session id 复用，一种是 session ticket 复用。session id 复用存在于服务端，session ticket 复用存在于客户端。


## 六、TLS 1.3 第二次握手流程


------------------------------------------------------

Reference：
  
《图解 HTTP》    
《HTTP 权威指南》  
《深入浅出 HTTPS》  


> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: []()