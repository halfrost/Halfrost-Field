# 如何部署 QUIC ？

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleTitleImage/100_0.png'>
</p>

## 一. QUIC 是什么

QUIC 是 Quick UDP Internet Connections 的缩写，谷歌发明的新传输协议。与 TCP 相比，QUIC 可以减少延迟。从表面上看，QUIC 非常类似于在 UDP 上实现的 TCP + TLS + HTTP/2。由于 TCP 是在操作系统内核和中间件固件中实现的，因此对 TCP 进行重大更改几乎是不可能的。但是，由于 QUIC 建立在 UDP 之上，因此没有这种限制。QUIC 可以实现可靠传输，而且相比于 TCP，它的流控功能在用户空间而不在内核空间，那么使用者就 不受限于 CUBIC 或是 BBR，而是可以自由选择，甚至根据应用场景自由调整优化。


QUIC 与现有 TCP + TLS + HTTP/2 方案相比，有以下几点主要特征：

- 利用缓存，显著减少连接建立时间 
- 改善拥塞控制，拥塞控制从内核空间到用户空间
- 没有 head of line 阻塞的多路复用
- 前向纠错，减少重传
- 连接平滑迁移，网络状态的变更不会影响连接断线。

![](https://img.halfrost.com/Blog/ArticleImage/100_1.png)

QUIC 在 UDP 之上，如果想要和 TCP/IP 体系类比，那么就是上图。QUIC 可以类比 TCP/IP 中的 TLS 一层。但是功能又不完全是 TLS ，还有一部分 HTTP/2 ，下面还包括一部分 TCP 的功能，比如 拥塞控制、丢包恢复、流量控制等特性。

## 二. 为什么要部署 QUIC

![](https://img.halfrost.com/Blog/ArticleImage/100_5.png)

本站笔者已经部署了 TLS 1.3，再次握手可以达到 0-RTT 了，速度已经比较快了，但是为何笔者还要再部署一套 QUIC 呢？

1. HTTP + TLS 的首次握手还是需要花费多次 RTT，仍有优化空间
2. 手机在弱网环境下，TCP head of line 阻塞和 TLS record HOF 加剧了网络恶化
3. HTTPS 一套方案过于单一，如果部署多套链路，系统可用性更高

其实最重要的一点还是速度快。如果经常用 Google 服务的用户就会观察到，Google 目前主要业务都已经部署了 QUIC，并且支持了 4 个大版本，quic-44、quic-43、quic-39、quic-35（同时支持多个版本主要是为了兼容多个版本 chrome 浏览器，目前最新的 chrome 浏览器 68 - 70 都只有 quic-44，而低版本的 62 - 66 都只有 quic-39，为了各个版本的用户，也只能支持这么多版本了）。

另外还有一点，如果是 HTTP/2 的开发者，一定会知道，HTTP/2 and SPDY indicator 这个谷歌官方插件。如果只是普通的 HTTP/2 + TLS，这个插件会显示蓝色，并显示“ HTTP/2-enabled(h2) ”；但是如果开启了 QUIC，那么它会显示成炫酷的绿色，并显示“SPDY-enabled(http/2+quic/39)”，绿色表示网络通道更加畅通。


好了，说了这么多理由了，那接下来看看如何部署吧。

## 三. 实现 QUIC 前置条件

![](https://img.halfrost.com/Blog/ArticleImage/100_3.png)

要想在浏览器上实现 QUIC ，有一些前置条件。由于现在好像只有 chrome 浏览器支持 QUIC 协议，所以下面的条件是针对 chrome 浏览器的。

### 1. 首次连接

当 Chrome 向之前从未发过请求的服务端发出请求时，它不知道对方是否支持 QUIC，因此先通过 TCP 发送第一个请求。服务器响应该请求以后，要发送 Alt-Svc HTTP 响应头告诉 chrome 它支持 QUIC。 （例如，响应头中 "alt-svc: quic=":443"; ma=2592000; v="44,43,39,35" 告诉 Chrome 服务端支持端口443上的QUIC，且支持的版本号是 44，43，39，35，max-age 为 2592000 秒）。 现在 Chrome 知道服务端支持 QUIC，于是尝试使用 QUIC 来进行下一个请求。发出请求后，Chrome 将采取 QUIC 和 TCP 竞争的方式与服务端建立连接。（建立这些连接，但是不发送请求）如果第一个请求通过 TCP 发出，TCP 赢得竞争，第二个请求将通过 TCP 发出。 在随后的某个时刻，QUIC 如果一旦连接成功，将来所有请求都将通过 QUIC 连接发送。


**所以 QUIC 的协议发现过程是通过识别响应头中的特殊字段实现的**。

### 2. 后续连接

Chrome 始终原生支持 QUIC，并且启用 QUIC 的服务器会一直支持 0-RTT 握手。当 Chrome 向之前使用过 QUIC 的服务器发出请求时，它还会与 TCP 进行竞争。 由于 Chrome 将能够进行 0-RTT 握手，因此 QUIC 还会立即获胜，并且继续在 QUIC 连接上发出请求。

### 3. 连接失败

如果 QUIC 握手失败（例如，如果UDP被阻止，或者服务器与 chrome 的 QUIC 版本不兼容），则 Chrome 会将 QUIC 标记为该主机已损坏 broken。任何正在进行的请求都将通过 TCP 重新发送。 虽然 QUIC 被标记为主机已损坏，所以不会立即尝试 QUIC 连接了。5分钟后，损坏的连接将过期的 QUIC 标记为“最近破坏”。当向服务器发出下一个请求时，Chrome 又将继续让 TCP 和 QUIC 进行竞争。由于QUIC“最近被破坏”，因此将禁用 0-RTT 握手。如果握手再次失败，则 QUIC 将在此次再次标记为该连接已损坏 10 分钟，将 QUIC 标记为已损坏的前一周期的 2 倍，如此往后都会不断的标记为 2 倍。如果握手成功，请求将通过 QUIC 发送，QUIC 将不再标记为“最近损坏”。

另外还有一点需要注意的是 QUIC 必须要同时部署在 TCP / UDP 443 端口上。没有理由，这算是规定。具体可以看这个帖子[Why MUST a server use the same port for HTTP/QUIC?](https://github.com/quicwg/base-drafts/issues/929)

知道这些以后，QUIC 的部署方案也就出来了。

## 四. 部署 QUIC 方案

![](https://img.halfrost.com/Blog/ArticleImage/100_2.png)

由于 nginx 的生态比较完善，因为部署 QUIC 完全抛弃 nginx ，这有点本末倒置了。但是当前 nginx 还没有支持 QUIC，那我们怎么能提前体验 QUIC 呢？分两步来部署。

### (一). nginx 配置响应头

```nginx
add_header alt-svc 'quic=":443"; ma=2592000; v="39"';
```

这一步比较简单，目的是为了告诉 chrome 浏览器当前服务器支持 QUIC。

### (二). 实现 QUIC 协议

整个 QUIC 协议比较复杂，想自己完全实现一套对笔者来说还比较困难。所以先看看开源实现有哪些：

#### 1. Chromium
   这个是官方支持的。优点自然很多，Google 官方维护基本没有坑，随时可以跟随 chrome 更新到最新版本。不过编译 Chromium 比较麻烦，它有单独的一套编译工具。暂时不考虑这个方案。

#### 2. proto-quic
   从 chromium 剥离的一个 QUIC 协议部分，但是其 github 主页已宣布不再支持，仅作实验使用。不考虑这个方案。

#### 3. goquic
   goquic 封装了 libquic 的 go 语言封装，而 libquic 也是从 chromium 剥离的，好几年不维护了，仅支持到 quic-36， goquic 提供一个反向代理，测试发现由于 QUIC 版本太低，最新 chrome 浏览器已无法支持。不考虑这个方案。

#### 4. quic-go
   quic-go 是完全用 go 写的 QUIC 协议栈，开发很活跃，已在  Caddy 中使用，MIT 许可，目前看是比较好的方案。

于是可以确定方案是最后一个，采用 caddy 来部署实现 QUIC。

部署方案如下：

![](https://img.halfrost.com/Blog/ArticleImage/100_7.png)

nginx 还是继续使用，不过 nginx 只用来响应 TCP/443 端口，UDP/443 交给 caddy 来响应。nginx 返回响应头告诉 chrome 浏览器支持 QUIC，然后 caddy 作为反向代理 proxy 来转发。

## 五. 部署

caddy 这个项目本意并不是专门用来实现 QUIC 的，它是用来实现一个免签的 HTTPS web 服务器的。caddy 会自动续签证书。QUIC 只是它的一个附属功能(不过好像用它来实现 QUIC 的人更多🤣)。

如果直接在服务器上面运行 caddy ，会报一个错误：

```c
Activating privacy features... done.
2018/07/22 14:03:15 listen tcp :443: bind: address already in use
```

原来 caddy 也会监听 TCP/443 ，所以要首先解决这个问题，我们只需要 caddy 监听 UDP/443，把 caddy 的 TCP/443 功能“屏蔽”掉。这里比较好的方法就是用 docker 来实现。因为 docker 容器的网段和宿主机的网段默认是隔离的。

那我们就新建一个 docker 吧。

```makefile
FROM ubuntu:latest
LABEL maintainer="ydz@627@gmail.com"

RUN apt-get update

RUN set -x  \
	&& apt-get install curl -y \
	&& curl https://getcaddy.com | bash -s personal && which caddy

```

如果不想再做了，可以直接 pull 一下笔者 docker pub 里面的这个镜像，REPOSITORY：halfrost/blog，TAG：caddy-0.0.1。

然后要新建一个 caddy 的配置文件

```makefile
https://halfrost.com
gzip
tls /conf/chained.pem /conf/domain.key

proxy / http://127.0.0.1:2368 {
  header_upstream Host {host}
  header_upstream X-Real-IP {remote}
  header_upstream X-Forwarded-For {remote}
  header_upstream X-Forwarded-Proto {scheme}
}

log /caddy-conf/caddy_blog.log
errors /caddy-conf/caddy_errors.log
```

上面文件中具体的 HTTPS 的证书路径，还有 log 和 error 的路径根据个人喜好配置。

接下来就可以启动 docker 啦。

```bash
$ docker container run -d -p 443:443/udp --name halfrost-blog -v /www/ssl:/conf -v /www/caddy:/caddy-conf halfrost/blog:caddy-0.0.1 caddy -quic -conf /caddy-conf/caddy.conf
```

上面这个命令解释一下：

-p 就是映射的端口，把宿主机的 443/udp ，映射到 docker 的 443 端口

-name 就是给这个 docker 起一个名字，如果不设置，会随机生成一个名字。

```c
CONTAINER ID        IMAGE                             COMMAND                  CREATED             STATUS              PORTS                    NAMES
366d4b392ed0        halfrost/blog:caddy-0.0.1         "caddy -quic -conf..."   10 hours ago        Up 10 hours         0.0.0.0:443->443/udp     halfrost-blog
```

-v 是挂载一些目录，冒号前面是宿主机的目录，冒号后面是 docker 里面的目录。

最后的 -conf 加载宿主机的 conf 文件。

如果 docker 启动失败了，查看一下 docker 的 log，看一下启动失败的原因：

```bash
$ docker logs -f -t --tail 10 366d4b392ed0
```

至此，服务端的操作全部完成了。

## 六. 验证 QUIC

### 1. 验证端口

先验证一下 caddy 是否在监听 UDP/443：

```bash
netstat -anp | grep "443"

tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      9748/nginx: master
tcp        0      0 172.16.9.240:443        101.86.117.100:54518    TIME_WAIT   -
tcp        0      0 172.16.9.240:443        124.90.178.236:33162    FIN_WAIT2   -
tcp        0      0 172.16.9.240:64854      140.205.230.3:443       TIME_WAIT   -
udp6       0      0 :::443                  :::*                                5629/./caddy
```

可以看到确实在监听 UDP/443

### 2. chrome 开启 QUIC 特性

再开启 chrome 的 QUIC 特性

在 chrome:\/\/flags\/ 中找到 Experimental 中 QUIC protocol, 设置为Enabled. 重启浏览器生效。

### 3. 安装 HTTP/2 and SPDY indicator 插件

![](https://img.halfrost.com/Blog/ArticleImage/100_8.png)

在 chrome store 里面安装 HTTP/2 and SPDY indicator 插件。这个插件在前面提到过了，如果开启了 QUIC，这个插件会很明显的显示为绿色。如上图右上角，可以看见绿色的闪电⚡️，即代表已经开启了 QUIC。

### 4. chrome developer tools

![](https://img.halfrost.com/Blog/ArticleImage/100_9.png)

在 chrome 的 develop tools 工具里面，打开 security 选项卡，在 connection 项里面会看到 QUIC，如果显示的是 QUIC，代表开启 QUIC。


### 5. chrome net\-internals

打开 chrome:\/\/net\-internals\/#quic 页面

![](https://img.halfrost.com/Blog/ArticleImage/100_10.png)

如果你看到了 QUIC sessins，则开启成功。

左侧 Alt-svc 里面会记录所有支持 QUIC 的相应头。

![](https://img.halfrost.com/Blog/ArticleImage/100_11.png)

在上面的字典里，还会记录下次尝试的时间。如果之前出现了 broken，可以在这个页面清空这里的所有记录。清空方法是在这个页面点击右上角的小三角，里面有一项“Clear cache”，清空以后 chrome 在下次请求的时候就会立即尝试 QUIC 了。


**更新：**

新版的 Chrome 68 以上版本，net\-internals 中没有笔者上面截图的页面了，这些工具都转到了 chrome:\/\/net\-export\/ 这个页面了。笔者写这篇文章的时候 Chrome 还是 67 的版本。

chrome:\/\/net\-export\/ 这个页面需要先把请求记录下来，存成 json 文件。

![](https://img.halfrost.com/Blog/ArticleImage/100_15.png)

记录完成以后会出现下面这个页面：

![](https://img.halfrost.com/Blog/ArticleImage/100_16.png)


然后在 https:\/\/netlog\-viewer.appspot.com\/ 这里解析 json 文件。解析出来以后就能看到左边的那些工具了。


![](https://img.halfrost.com/Blog/ArticleImage/100_18.png)


![](https://img.halfrost.com/Blog/ArticleImage/100_17.png)

至于如何清除 Alt-svc 的 cache，这个笔者还没有找到实时清除的方法，笔者现在都是在 dev-tool 里面点击清理 Network 中的 Disable cache 和 Application 中的 Clear storage。可能清除 Alt-svc 的 cache 目前还没有实现出来，如果以后笔者发现方法了，还会再回来更新这段话，如果读者看到这里知道如何清除 Alt-svc 中的 Alternate Service Mappings，也麻烦留言评论分享一下。不过不清除 Alt-svc 中的 cache 对开启 QUIC 影响不大，只是在 broken 以后需要多等待 5 分钟的过期时间(如果能立即清除 cache 就不用等这个 5 分钟了)。

### 6. wireshark 抓包

![](https://img.halfrost.com/Blog/ArticleImage/100_12.png)

最后的办法就是可以用 wireshark 进行抓包，观察发送的包是不是都是 GQUIC 的，如果是，就代表开启成功。

## 七. 一些“踩坑”实践

看到这里读者可能觉得本文就结束了。确实，进行到这里 QUIC 已经开启成功，并且验证完毕了。但是为何还有这一节呢？笔者最后的方案其实不是上述描述的，因为中间出现了一些蛋疼的情景，导致最终没有选用 docker 的方案。当然笔者的情况比较特殊，这里分享一下，仅仅是记录一下解决问题的过程。

![](https://img.halfrost.com/Blog/ArticleImage/100_4.png)

笔者的浏览器版本是最新的 68，并且也安装了金丝雀，版本是 70 。在部署完 QUIC 以后，疯狂刷新，死活见不到绿色的小闪电⚡️。无奈最终只能采取抓包的方式查问题。抓包发现，chrome 68 的版本默认带的是 quic-43 的实现，在握手的时候会失败。于是就不会开启 QUIC 了。

![](https://img.halfrost.com/Blog/ArticleImage/100_14.png)

上图可以看见握手失败了。

于是笔者为了验证 QUIC 开启成功，下载了一个老的版本 65。但是却出现了另外一个问题，打开页面出现 “502 Bad Gateway”。并且在 
chrome:\/\/net\-internals\/#alt-svc 页面看见了 broken。

![](https://img.halfrost.com/Blog/ArticleImage/100_13.png)

出现 broken 就说明了 UDP 通道不通。

UDP 通道不通可能是几个原因：阿里云或者运营商某个环节屏蔽了 UDP 包；服务端 QUIC 服务挂了，或者博客端口挂了。

先验证一下服务端 caddy 有没有挂，打印了一下 docker log，没有发现 caddy 崩溃。查看了 ghost ，也没有发现崩溃。

再检验一下 UDP 包是否没有发送过来。

笔者服务器是 centOS 的，用 netcat 来检测 UDP 通道。

```bash
$ yum install nc
$ nc --udp --listen 6111
```

在本地连接服务器：

```bash
$ nc -u <server ip> 6111
```

本地发送一串字符串，如果服务端也显示了相同的字符串，代表中间没有防火墙。经过验证，整个 UDP 通道是通的。

>注意这里，如果对方没有收到包，不一定能说明 UDP 通道是不通的。因为如果对端开启了防火墙，防火墙把包 DROP 了，那么是收不到 ICMP 端口不可达消息的，那么使用 nc 命令就会发现实际不通的端口是通的。仔细想想 UDP 的原理就清楚了，UDP 不像 TCP 一样需要 ACK，所以过一段时间没收到端口不可达，UDP 就认为端口是通的，但是实际上 UDP 数据被防火墙 DROP 了。

这个时候笔者有点懵。静下心来再仔细分析一下 caddy 的日志：

```bash
11/Aug/2018:13:12:24 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:24 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:24 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:24 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:24 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:25 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:26 +0000 [ERROR 502 /serviceworker-v1.js] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:26 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:12:27 +0000 [ERROR 502 /serviceworker-v1.js] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:12 +0000 [ERROR 502 /serviceworker-v1.js.map] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:12 +0000 [ERROR 502 /assets/dist/sw-toolbox.js.map] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:14 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:16 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:17 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:27 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:29 +0000 [ERROR 502 /rss/] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:30 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
11/Aug/2018:13:14:31 +0000 [ERROR 502 /] dial tcp 127.0.0.1:2368: connect: connection refused
```

从日志上也看不出具体是什么错误。一直报 502，连接拒绝。

登录到服务器，模拟一下请求试试：

```bash
$ curl -X GET 127.0.0.1:2368
```

输出了博客首页 index.html ，说明 ghost 的 node 服务也没有挂啊，一切正常。那究竟是什么问题导致 502 错误呢？

我们是把宿主机的 UDP/443 端口转发到 docker 内的 443 端口，然后反向代理请求到 127.0.0.1：2368 端口，目前还需要排查的一点就是在 docker 内部是否能代理成功呢？

```bash
$ sudo docker exec -it 775c7c9ee1e1 /bin/bash

进入到 docker 内部了。

/# curl -X GET http://127.0.0.1:2368

curl: (7) Failed to connect to 127.0.0.1 port 2368: Connection refused
```

这里报错了，看到这里，就可以定位到问题的原因了。之所以 caddy 会报 502 错误，原因是因为 caddy 在 docker 内部无法访问到宿主机的 127.0.0.1：2368 端口。

在 docker 内部再验证一下, /etc/hosts/ 文件里面的内容

```bash
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
192.168.0.4	366d4b392ed0
```

可以看到 docker 内部也有一个 127.0.0.1，所以之前代理写的 127.0.0.1 并没有转发到宿主机上，而是被这里的 hosts 文件拦截在本地了。那如何从 docker 内部访问到宿主机呢？宿主机的 IP 是什么呢？

继续在 docker 内部执行 ：

```bash
/# apt-get install iproute2
/# apt-get install net-tools
/# netstat -nr | grep '^0\.0\.0\.0' | awk '{print $2}'

192.168.0.1
```

输出 192.168.0.1 代表在 docker 这个网段的网关是 192.168.0.1。那么我们可以通过这个 IP 访问到外面宿主机的服务么？答案是可以的。

那难道每次我们都需要进入到 docker 里面执行这样一句话查看宿主机的 IP 么？答案当然是否定的。有两种方法可以解决这个 IP 问题。

### 1. --add-host 命令

```bash
$ HOST_IP=`ip -4 addr show scope global dev docker0 | grep inet | awk '{print \$2}' | cut -d / -f 1`

$ docker run --add-host outside:$HOST_IP --name busybox -it busybox /bin/sh

/ # cat /etc/hosts
127.0.0.1    localhost  
::1    localhost ip6-localhost ip6-loopback
fe00::0    ip6-localnet  
ff00::0    ip6-mcastprefix  
ff02::1    ip6-allnodes  
ff02::2    ip6-allrouters  
172.17.0.1    outside <---- THIS ONE!  
172.17.0.3    a8300156a695
```

### 2. 修改 dockerfile

在 dockerfile 最后加入一行：

```bash
RUN ip -4 route list match 0/0 | awk '{print $3 "host.docker.internal"}' >> /etc/hosts
```

一般 docker 生成有 3 种网络类型：

```bash
$ docker network ls

NETWORK ID          NAME                DRIVER              SCOPE
a6211ef82668        bridge              bridge              local
bb6cb9901ca2        host                host                local
c25d8f9f4ae3        none                null                local

```

默认是 bridge 的，所以可以通过 docker 所在网段的网关访问到宿主机。

```bash
$ docker network inspect bridge

[
    {
        "Name": "bridge",
        "Id": "a6211ef82668f63c117d63fdc666a79dea8f3868bdc80434b9f00a05c9ae9d9b",
        "Created": "2018-07-26T22:24:42.881531018+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "192.168.0.0/20",
                    "Gateway": "192.168.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "Containers": {
            "0592382ce0319a58be1eaa07a612ee75092b192337871632b9b2af9baa8f2233": {
                "Name": "serene_brahmagupta",
                "EndpointID": "97349fed924efb4d49173943e0daff0459f0d8df373c639710c81f9efa0f7965",
                "MacAddress": "02:42:c0:a8:00:02",
                "IPv4Address": "192.168.0.2/20",
                "IPv6Address": ""
            },
            "366d4b392ed071186c6442228442a929b20656242b75021beab6eaa7afbc352b": {
                "Name": "halfrost-blog",
                "EndpointID": "13c186ae9c460a87280593c3083f644bdbcd718e993b4ba3ee5a8efc66ae82c8",
                "MacAddress": "02:42:c0:a8:00:04",
                "IPv4Address": "192.168.0.4/20",
                "IPv6Address": ""
            },
            "66b36b776c6f390dfb81f055e38e276cbab9e97fe1aa7736e50b08c04e4d9635": {
                "Name": "infallible_saha",
                "EndpointID": "18ea99dc8e5add8867d6933717b682701f01452439e699274a8b71a053c673df",
                "MacAddress": "02:42:c0:a8:00:03",
                "IPv4Address": "192.168.0.3/20",
                "IPv6Address": ""
            }
        },
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]

```

笔者把代理改成了 192.168.0.1：2368，依旧连接拒绝。代表还是访问方式不对。通过查询 ghost 文档，发现 2368 端口没有对外暴露，默认只能在宿主机上访问。所以不同网段之间不能访问到 2368 这个 node 服务的。

排查到这里，有 2 种选择，选择一，更改 ghost 的服务端口，改到 0.0.0.0：2368，不过这样改，ghost 里面很多配置都要更改。选择二，让 caddy docker 和宿主机在同一个网段。

笔者选择了第二种方案。

让 docker 和 宿主机在同一个网段可以通过启动的时候指定 `--network=host`，这样 docker 和宿主机就在同一个网段了。不过这样又会出现新的问题。之前映射关系就不对了。因为这样 caddy 也会监听宿主机的 TCP/443 端口，如此一来我们之前用 docker 摆脱监听同一个端口的目的就没有意义了。

到这里，笔者还是决定放弃 docker 的方案。那只有改 caddy 源码的方案了。

下载 caddy 源码，在 caddy/caddyhttp/httpserver/server.go 文件中，找到 Listen 这个函数里面，把其中一行注释掉，换成：

```go
// ln, err := net.Listen("tcp", s.Server.Addr)
ln, err := net.Listen("tcp", "127.0.0.1:61234")
// 随便写一个大一点的没有被占用的端口就可以
```

就是把原本的 443 地址换成一个没用的地址，然后重新编译，

```go
$ cd $GOPATH/src/github.com/mholt/caddy/caddy
$ go run build.go --goos=linux --goarch=amd64
```

顺利编译完成以后，就能在已经开了 nginx 的情况下正常启动 Caddy 了。为了能让Caddy变成一个守护进程运行在后台，可以使用 nohup 命令：

```bash
$ nohup sudo ./caddy -quic -conf ./conf  >/dev/null 2>&1 &
```

至此，笔者的 QUIC “完美”的部署好了。

## 八. 答疑 Q & A

Q: 我刷新了好几次，怎么还是没有你博客上绿色的小闪电⚡️？
A: 首先要看你的 chrome 版本是不是 62-65 之间，如果高于这个版本或者低于这个版本，都会导致 QUIC 握手失败，进而无法进行 QUIC 通讯。因为 62-65 版本之间支持了是 quic-39，而目前 caddy 最新只支持到了 quic-39。

其次还需要看看你本地是否开启了类似 surge 全局翻墙软件，如果开启了类似这些软件，一般都会系统代理你本机的所有请求，那么所有的请求都是来自 127.0.0.1:XXXX，这样也不会触发 UDP 的请求了。所以要关闭 Surge “设置为系统代理” 这个设置。

最后，可以看看 chrome:\/\/net\-internals\/#alt\-svc 页面里面有 broken 的情况，如果有，可以清除了以后立即刷新再看看。

Q: caddy 为何不支持最新版的 quic 协议？
A: 这个问题可以看它的 issue，作者在今天 1-4 月，每个月都会更新一个新版本，并且持续的更近 quic 协议的更新。直到 5 月以后，就再也没有发布新版了。作者说要先重构 2 个引入的库的方式，不然以后越开发越乱。一直等到现在 quic-44 了，caddy 还没有更新上来。只能再等等了。

Q: QUIC 如何调试？
A: 这个问题问的好，笔者也考虑查看 QUIC 里面加密包的内容。不过目前还没有方式可以查看。TLS 可以通过保存协商密钥来查看加密内容，但是 QUIC 目前好像还不行(至少笔者还没有在网上搜到相关的内容)


![](https://img.halfrost.com/Blog/ArticleImage/100_12.png)

wireshark 抓包目前只能看到前期握手的明文，握手以后的包都是加密内容。所以调试 QUIC 的问题还有待进一步研究。

## 九. 最后


~~当前 caddy 最新只能支持到 quic-39，并且也不能同时兼容多个版本。最新的 chrome 已经支持到最新的 quic-44 了，只能静静等待 caddy 更新了。~~

经过一次更新，笔者的博客已经支持 quic-44、quic-43、quic-39 三个主流版本了。欢迎大家体验。

另外，在移动互联网时代，如果客户端也想享受到 QUIC 带来的优势的话，光依靠 Chrome 浏览器可不行，谷歌提供了 cronet 这个库，它是 chromium 网络协议栈的封装，可以用于 Android 和 iOS 平台，可以很方便集成到手机 APP 中。利用这个库，可以和服务端进行 QUIC 的通讯。

最后可以推荐大家看新浪微博今年 2018 Qcon 上分享的[在 QUIC 上的一些实践心得](https://pic.huodongjia.com/ganhuodocs/2018-04-28/1524906080.9.pdf)。

关于 QUIC 协议的更详尽的分析，笔者会在接下来的文章中细致讲解。

------------------------------------------------------

Reference：  


[QUIC 官方介绍](https://www.chromium.org/quic)    
[Web服务器快速启用QUIC协议](https://my.oschina.net/u/347901/blog/1647385)  
[reading-and-annotate-quic](https://github.com/y123456yz/reading-and-annotate-quic)    
[怎么把网站升级到QUIC以及QUIC特性分析](https://www.yinchengli.com/2018/06/10/quic/)  
[本站开启支持 QUIC 的方法与配置
](https://liudanking.com/beautiful-life/%E6%9C%AC%E7%AB%99%E5%BC%80%E5%90%AF%E6%94%AF%E6%8C%81-quic-%E7%9A%84%E6%96%B9%E6%B3%95%E4%B8%8E%E9%85%8D%E7%BD%AE/)    

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/quic\_start/](https://halfrost.com/quic_start/)
