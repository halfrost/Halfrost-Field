<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleTitleImage/99_0.png'>
</p>

笔者最近在研究 TLS 1.3 协议，所以想要实践一下，博客必须先部署 TLS 1.3 。另外它的 0-RTT 对博客速度的也是一种提升。需要注意目前 Chrome 68 和 Firefox 支持的是 TLS 1.3 draft 28，暂时不要用在生产环境。

关于 TLS 1.3 的更多细节，会在之后的文章里面分析。

## 一. 安装依赖

先来看看依赖项的一些情况。

Nginx 1.13.0 开始 正式支持 ssl\_protocols 的 TLSv1.3 的选项. 在此之前 TLSv1.2 选项会自动使用 TLSv1.3.

OpenSSL 目前有 draft-18 分支, pre2 版本的 draft-23 以及 pre7+ 的 draft-28 通过 tls1.h (include/openssl/tls1.h 第35行) 可以查看目前的 Draft。

从 Chrome 65 开始会默认开启并使用 TLSv1.3 Draft 23, 从 Chrome 68 开始支持 Draft 28 (Firefox Nightly 应该也支持).


我的 ECS 系统是 centOS 7.0，如果你使用其它发行版，与包管理有关的命令请自行调整。

目前 nginx 最新是 Nginx 1.15.1，OpenSSL 最新是 1.1.1-pre8，笔者这次都安装最新版。

首先安装依赖库和编译要用到的工具：

```bash
$ sudo yum groupinstall -y "Development Tools"
$ sudo yum install -y git wget zlib zlib-devel pcre-devel google-perftools google-perftools-devel lua-devel GeoIP-devel
$ sudo yum install -y git gcc gcc-c clang automake make autoconf libtool zlib-devel libatomic_ops-devel pcre-devel openssl-devel libxml2-devel libxslt-devel gd-devel GeoIP-devel gperftools-devel  perl-devel perl-ExtUtils-Embed
```

### Nginx 1.15.1

```bash
#下载 Nginx 1.15.1
$ wget https://nginx.org/download/nginx-1.15.1.tar.gz
$ tar zxf nginx-1.15.1.tar.gz
```

安装原版的 Nginx 1.15.1，少了一些好用的功能，还好有 patch，笔者在这里打了 5 个 patch，也推荐大家使用。

- 支持 SPDY
- 支持 HTTP/2 HPACK
- 支持 Dynamic TLS Record (这个强烈推荐)
- 支持 PRIORITIZE\_CHACHA (这个强烈推荐)
- Fix Http2 Push Error 补丁 (推荐)

这些补丁不一定适用于最新的 Nginx 已测试通过的版本请查看[https://github.com/kn007/patch](https://github.com/kn007/patch)

```bash
# 打 SPDY, HTTP2 HPACK, Dynamic TLS Record, PRIORITIZE_CHACHA, Fix Http2 Push Error 补丁

$ cd nginx-1.15.1
$ wget https://raw.githubusercontent.com/kn007/patch/45f1417c450fc82cd470cb73a32e23085c4ba3d5/nginx.patch
$ wget https://raw.githubusercontent.com/kn007/patch/c59592bc1269ba666b3bb471243c5212b50fd608/nginx_auto_using_PRIORITIZE_CHACHA.patch
$ wget https://raw.githubusercontent.com/kn007/patch/b70155131a74deafe9c642194b4394edda20ccec/fix_nginx_hpack_push_error.patch
$ patch -p1 < nginx.patch
$ patch -p1 < nginx_auto_using_PRIORITIZE_CHACHA.patch
$ patch -p1 < fix_nginx_hpack_push_error.patch
$ cd ..
```


### OpenSSL 1.1.1-pre8

```bash
# 下载 OpenSSL 1.1.1-pre8
$ wget https://www.openssl.org/source/openssl-1.1.1-pre8.tar.gz
$ tar zxf openssl-1.1.1-pre8.tar.gz
```

由于不同版本的 chrome 支持的 TLS 不同，所以我们最好能支持所有主流版本的 TLS 1.3 。这里再打上同时支持 draft 23,26,28 的补丁。

```bash
# 打 TLS1.3 Draft 23,26,28 补丁
# 根据 OpenSSL 版本决定, 具体见 https://github.com/hakasenyang/openssl-patch
$ cd openssl-1.1.1-pre8
$ wget https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/openssl-equal-pre8.patch
$ patch -p1 < openssl-equal-pre8.patch
$ cd ..
```

### ngx_brotli

本站支持 Google 开发的 Brotli 压缩格式，它通过内置分析大量网页得出的字典，实现了更高的压缩比率，同时几乎不影响压缩 / 解压速度。

```bash
# 安装 ngx_brotli
$ git clone https://github.com/eustas/ngx_brotli.git
pushd ngx_brotli
$ git submodule update --init
$ cd ..
```

## 二. 编译 Nginx

使用 --with\-openssl=..\/openssl\-1.1.1\-pre8 来指定 OpenSSL 路径。

HTTP2 HPACK 需要加入 `--with-http_v2_hpack_enc`

SPDY 需要加入 `--with-http_spdy_module`

TLS 1.3 需要加入 `--with-openssl-opt='enable-tls1_3'`

所有的编译参数合起来如下：

```c
$ auto/configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-openssl=/tmp/openssl-OpenSSL_1_1_1-pre8 --with-openssl-opt='enable-tls1_3' --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' --with-http_spdy_module --with-http_v2_hpack_enc --add-module=/tmp/ngx_brotli
```

如果读者安装了上面笔者推荐的所有补丁，那么再往下编译可能会出现问题。需要把编译参数 `--with-cc-opt` 里面的 `-O2` 去掉即可。

笔者的最终编译参数如下，仅供参考：

```bash
$ auto/configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-openssl=/tmp/openssl-OpenSSL_1_1_1-pre8 --with-openssl-opt='enable-tls1_3' --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' --with-http_spdy_module --with-http_v2_hpack_enc --add-module=/tmp/ngx_brotli
```

修改好编译参数以后就可以开始 make 了：

```bash
$ make
```

如果编译过程中还遇到了 `pthread_atfork` 的错误：

```bash
threads_pthread.c:(.text+0x16): undefined reference to `pthread_atfork'
collect2: error: ld returned 1 exit status
make[1]: *** [objs/nginx] Error 1
```

要修改 nginx 目录下的 objs 内的 Makefile:

```bash
$ vim ./objs/Makefile
```

找到下面这一行：

```bash
-Wl,-z,relro -Wl,-z,now -pie -ldl -lpthread -lpthread -lcrypt -lpcre /tmp/openssl-master/.openssl/lib/libssl.a /tmp/openssl-master/.openssl/lib/libcrypto.a -ldl -lz \
```

修改为：

```bash
-Wl,-z,relro -Wl,-z,now -pie -ldl -lcrypt -lpcre /tmp/openssl-master/.openssl/lib/libssl.a /tmp/openssl-master/.openssl/lib/libcrypto.a -ldl -lz -lpthread \
```

编译完成以后，验证一下：

```bash
$ nginx -V

nginx version: nginx/1.15.1
built by gcc 4.8.5 20150623 (Red Hat 4.8.5-28) (GCC)
built with OpenSSL 1.1.1-pre8 (beta) 20 Jun 2018
TLS SNI support enabled
configure arguments: --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-openssl=/tmp/openssl-OpenSSL_1_1_1-pre8 --with-openssl-opt=enable-tls1_3 --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie' --with-http_spdy_module --with-http_v2_hpack_enc --add-module=/tmp/ngx_brotli
```


## 三. 更换 Nginx

```bash
$ cd /usr/sbin
$ mv nginx nginx.1.13.8_old
$ cp /tmp/nginx-release-1.15.1/objs/nginx ./
```

测试 nginx 是否能正常工作：

```bash
$ nginx -t
```

## 四.配置 Nginx

配置 Brotli (Optional)

```bash
$ sudo vim /etc/nginx/nginx.conf

# 在 http{} 中加入
brotli             on;
brotli_static      on;
brotli_comp_level  6;
brotli_buffers     32 8k;
brotli_types       text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;
```

配置 Web 站点

在 Nginx 的站点配置中，以下两个参数需要修改：

```bash
ssl_protocols              TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # 增加 TLSv1.3
ssl_ciphers                TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
```

包含 TLS13 是 TLS 1.3 新增的 Cipher Suite，加在最前面即可。

最后使用 `nginx -t` 测试一下，确认无问题。

## 五.部署 Nginx

重启 nginx 生效上面所有配置

```bash
$ systemctl restart nginx
```

## 六.验证 TLS 1.3

### chrome 验证

![](https://img.halfrost.com/Blog/ArticleImage/99_4.png)

进入 chrome:\/\/flags 页面，找到 TLS 1.3，选择支持 draft-28。

然后访问博客主页，打开开发者工具，security 选项卡：

![](https://img.halfrost.com/Blog/ArticleImage/99_1.png)

![](https://img.halfrost.com/Blog/ArticleImage/99_2.png)

可以看到链接已经是 TLS 1.3 的了。

### wireshark 抓包验证

如果还不放心，可以通过抓包来验证是否开启了 TLS 1.3 。

![](https://img.halfrost.com/Blog/ArticleImage/99_3.png)

从报文上来看，握手阶段确实用的 TLS 1.3 。


### SSLlabs 检测报告

可以通过[https://www.ssllabs.com/](https://www.ssllabs.com/)检测自己的站点 TLS 支持情况。

### MySSL 检测报告

可以通过[https://myssl.com/](https://myssl.com/)检测自己的站点 TLS 支持情况。

### 使用 testssl 工具

在服务端安装 testssl 工具

```bash
$ git clone --depth 1 https://github.com/drwetter/testssl.sh.git
$ cd testssl.sh
$ ./testssl.sh --help
```

```bash
$ ./testssl.sh -p halfrost.com

 Testing protocols via sockets except NPN+ALPN

 SSLv2      not offered (OK)
 SSLv3      not offered (OK)
 TLS 1      offered
 TLS 1.1    offered
 TLS 1.2    offered (OK)
 TLS 1.3    offered (OK): draft 28, draft 27, draft 26
 NPN/SPDY   h2, spdy/3.1, http/1.1 (advertised)
 ALPN/HTTP2 h2, spdy/3.1, http/1.1 (offered)
```

详细的情况可以用 -P

```bash
$ ./testssl.sh -P halfrost.com

 Testing server preferences

 Has server cipher order?     yes (OK)
 Negotiated protocol          TLSv1.3
 Negotiated cipher            TLS_AES_256_GCM_SHA384, 253 bit ECDH (X25519)
```

更加详细的报告这里就不贴了，感兴趣的同学可以用 

```bash
$ ./testssl.sh halfrost.com
```


自己测试。

关于 TLS 1.3 的更多细节，会在之后的文章里面分析。Enjoy ~

------------------------------------------------------

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/tls1-3\_start/](https://halfrost.com/tls1-3_start/)
