# 博客跑分优化

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_0_.png'>
</p>

本篇文章会持续更新，因为优化无止境。

本文会罗列目前已经优化过的点。从开始页面略卡顿，到最后跑满分，笔者在这里都会一一展现出来。

## 起点

博客页面优化从 Chrome 的 Performance 开始。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_1_.png'>
</p>

从上图中可以看到页面前 550ms 都是空白，时间耗在了加载 JS 的过程上了。这段是 Disqus 的脚本和 Google 统计脚本。

笔者优化的原则是：**必须要加载的 pre-load，不必须加载的并且未出现在屏幕里面的 lazy-load**。

优化的思路很简单，在 DOM 渲染之前，去掉上图中大长条的黄色的矩形，这段时间是加载 JS 的时间，阻塞页面渲染了。笔者在页面渲染的时候不会加载 Disqus 脚本，只在博文页面用的时候，点击按钮的时候才会 lazy-load 加载脚本。

至于 Google 统计脚本，需要用最新的 gtag 的异步版本，并且加上 async 标志就可以解决。当然如果想彻底异步这段统计的代码，需要服务端做一些改造。

这里可以参考这两篇文章[《优化 Google Analytics 异步加载来提高你的网站速度》](https://imiku.me/2017/07/14/916.html)、[《服务端使用 Google Analytics》](https://blog.alphatr.com/google-analytics-on-server.html)。

如果还有百度统计的脚本的话，将 baidu 统计生成的代码移入网站，将 type 设置为 test 等非 mime/type 类型，这样浏览器便不会解析这段 script，baidu 统计却也能校验通过：

```javascript
<script type="text/test">
    var _hmt = _hmt || [];
    (function() {
      var hm = document.createElement("script");
      hm.src = "https://hm.baidu.com/hm.js?XXXX";
      var s = document.getElementsByTagName("script")[0];
      s.parentNode.insertBefore(hm, s);
    })();
    </script>
```

百度统计可以参考这篇文章[《Analytics代码延迟异步加载》](http://blog.angular.in/analyticsdai-ma-yan-chi-yi-bu-jia-zai/)。


把上面这两块弄好，会得到下面这张图：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_14_.png'>
</p>

效果就很明显了，首页首次有效渲染时间（FMP，是指主要内容出现在页面上所需的时间）小于 100 ms 了。

## 跑分

接下来是 Chrome 的 Audits。笔者第一次跑分的结果比较难看。分数比较低的是 Performance 和 Accessibility。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_2_.png'>
</p>

Performance 上，有以下几个衡量的指标：

- 首次有效渲染（FMP，是指主要内容出现在页面上所需的时间），
- 重要渲染时间（页面最重要部分渲染完成所需的时间），
- 可交互时间（TTI，是指页面布局已经稳定，关键的页面字体已经可见，主进程可以足够的处理用户的输入 —— 基本的时间标记是，用户可以在 UI 上进行点击和交互），
- 输入响应，接口响应用户操作所需的时间，
- Speed Index，测量填充页面内容的速度。 分数越低越好，

一般对流畅的定义是 ：

控制响应时间在 100ms 内，控制帧速在 60 帧/秒。速度指标(SpeedIndex) < 1250，3G 上交互时间 < 5s，关键文件大小 < 170Kb（SpeedIndex < 1250, TTI < 5s on 3G, Critical file size budget < 170Kb）

HTML 的前 14~15kb 加载是是最关键的有效载荷块 —— 也是第一次往返（这是在400 ms 往返延时下 1 秒内所得到的）预算中唯一可以交付的部分。一般来说，为了实现上述目标，我们必须在关键的文件大小内进行操作。最高预算压缩之后 170 Kb（0.8-1MB解压缩），它已经占用多达 1s （取决于资源类型）来解析和编译。稍微高于这个值是可以的，但是要尽可能地降低这些值。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_3_.png'>
</p>

由于本博客首页大量使用图片，所以图片优化是大头。上图中可以看到 Chrome 对图片指出 3 点优化建议：

- 图片格式尽量使用 JPEG 2000，JPEG XR 或者 WebP 替代 PNG 和 JPEG，这样图片大小更小。
- 从服务器上拿到的图片尺寸最好是缩放后的尺寸，不要下载过大尺寸的图片。
- 离屏渲染。屏幕以外的图片进行 lazy-load。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_4_.png'>
</p>

在性能方面还有几处需要重点优化的：

- 减少阻塞渲染的 stylesheets
- 减少不使用的 CSS 样式
- 减少阻塞渲染的 JS 脚本

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_5_.png'>
</p>

Accessibility 上，有以下容易漏掉的指标：

- 元素使用正确的 Attributes，例如 `<image>` 加上 `[alt]` 的 Attributes。
- 元素加上 Discernible name。例如 `<a>` 加上 Discernible name。
- 表单元素缺失 associated 标签。
- 背景颜色和前景颜色要有足够的颜色区分度。sufficient contrast ratio。

关于最后一点，推荐在 Chrome 上装上 aXe extension 插件，调试的时候选择它进行颜色区分度的调试。


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_6_.png'>
</p>

在默认页面上，还有一些要求：

- `<html>` 标签必须要加上 `[lang]` 属性
- `<meta name="viewport">` 标签里面不要加入 `[user-scalable="no"]`，并且 `[maximum-scale]` 属性要大于 5

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_7_.png'>
</p>

最后 SEO 方面，文字有限制，那就是文字大小要求 75% 以上的文字 >= 16 px。

## 优化

优化的重点当然是图片方面的。主要是 3 方面，图片格式用 WebP，图片缩放到合适大小，图片用 lazy-load。

关于 lazy-load 的原理简单说明一下，在 viewport 中可以获取到当前视窗里面元素的百分比，根据这个比例，我们会知道接下来哪个元素即将要被加载。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_15_.png'>
</p>

可以在图片的标签里面加上 `data-url` 属性来存储图片的真实地址。

```html
<img class="lazy" data-url="{{img_url feature_image}}" alt="">
```

当滚动到图片需要被展示的时候，再进行一些处理，把最后真实要获取图片的地址赋值到 src 属性上，这样浏览器会加载指定的图片。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_16_.png'>
</p>

更加详细的说明可以看谷歌的这篇官方文档[《IntersectionObserver’s Coming into View》](https://developers.google.com/web/updates/2016/04/intersectionobserver)

图片换成 WebP 格式，这个要用到七牛提供的 API。如果读者用的是其他 CDN ，也可以去找找他们有没有提供相关可用的 API，如果也有，那么就方便了。

七牛提供了图片基本处理的一些 API，见这篇官方文档[《七牛图片基本处理 API》](https://developer.qiniu.com/dora/manual/1279/basic-processing-images-imageview2)

在上面基本处理的 API 中也有对图片进行缩放的 API，所以我们在从 CDN 获取图片的时候，图片缩放到合适尺寸并且转换成 WebP 格式，可以一起做。这样最终获得图片的 URL 直接赋值给 src 即可。

不过这里需要注意的一点是，Safari 和 iOS 这些苹果平台上的浏览器是都不支持 WebP 格式的，如果强行加载，图片有损非常严重，分辨率很差，实际展现出来会很模糊。所以加载 WebP 之前需要判断一下是否支持，如果不支持还需要换到 JPEG 2000 或者 JPEG XR。

其他优化就是 JS 和 CSS 文件的优化，发布到生产上之前一定要记得压缩这些资源文件。压缩完可以让它们的体积变得很小，网络传输消耗时间变少。JS 文件如果能变成 chunks，按需加载，效果会更好。

检查每个 JavaScript 依赖性的关键，像 webpack-bundle-analyzer、Source Map Explorer 和 Bundle Buddy 这样的工具可以帮助你完成这些。度量 JavaScript 解析和编译时间。Etsy 的 DeviceTiming，一个小工具可以让你的 JavaScript 测量任何设备或浏览器上的解析和执行时间。重要的是，虽然文件的大小重要，但它不是最重要的。解析和编译时间并不是随着脚本大小增加而线性增加。

关于 JS 文件的优化，首先推荐用 Webpack。

Code-splitting 是 Webpack 的一个特性，可将你的代码分解为按需加载的“块”。并不是所有的 JavaScript 都是必须下载、解析和编译的。一旦你在代码中确定了分割点，Webpack 会处理这些依赖关系和输出文件。在应用发送请求的时候，这样基本上确保初始的下载足够小并且实现按需加载。另外，考虑使用 preload-webpack-plugin 获取代码拆分的路径，然后使用 `<link rel="preload">` or `<link rel="prefetch">` 提示浏览器预加载它们。

如果用不了 Webpack，那么相比于 Browserify 的输出结果， Rollup 的输出更好一些。当使用 Rollup 时，推荐你了解下 Rollupify，它可以将 ECMAScript 2015 modules 转化为一个大的 CommonJS module —— 因为小的模块会有令人惊讶的高性能开销（取决于打包工具和模块加载系统的选择）。


为确保浏览器尽快开始渲染页面，通常会收集开始渲染页面的第一个可见部分所需的所有 CSS（称为 “关键CSS” 或 “首屏 CSS”）并将其内联添加到页面的 `<head>` 中，从而减少往返。 由于在慢启动阶段交换包的大小有限，所以关键 CSS 的预算大约是 14 KB。

## 其他优化

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_13_.png'>
</p>


### 1. PWA

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_17_.png'>
</p>


没有什么网络性能优化能快过用户机器上的本地缓存。如果你的网站运行在 HTTPS 上，那么可以考虑做一下 PWA。使用 service worker 中缓存静态资源并存储离线资源（甚至离线页面）的目的，而且还会教你如何从用户的设备里面拿数据，也就是说，你现在是不需要通过网络的方式去请求之前的数据。

PWA 在第二次进入页面的时候，提升特别大，应为资源都是从本地加载的。

笔者在 PWA 上花了一些功夫，推荐看一下官方的这篇文章[《PWA 网络应用清单》](https://developers.google.com/web/fundamentals/web-app-manifest/#_5)。

由于博客的特殊性，页面变化不大，所以很多资源都可以缓存下来。笔者的 PWA 缓存策略是，缓存 JS 和 CSS 框架类文件，缓存字体，缓存 Disqus 框架，缓存图片，缓存百度和 google 统计框架。这样用户在第二次加载的时候，99% 都是走的缓存。极大的提高的加载速度。

关于 Service Workers 有一篇写的比较好的文章，推荐一下[《使用 Service Workers》](https://developer.mozilla.org/zh-CN/docs/Web/API/Service_Worker_API/Using_Service_Workers) 

### 2. HTTP/2

这个也需要 Nginx 的支持。

```nginx
server {
    listen 443 ssl http2;
}
```

关于 HTTP/2 的提升是很大的，这块笔者接下来会在系列文章里面分析，在这篇优化的文章里面就不分析了。

如果按照上面的设置以后，还没有开启 HTTP/2 的话，可以参考这篇文章[《解决Nginx配置http2不生效，谷歌浏览器仍然采用http1.1协议问题》](https://zhangge.net/5114.html)

### 3. Nginx 开启 gZip

gZip 能有效减少网络传输消耗，开启以后会占用一点服务器的 CPU，对前端网页性能提升有一些帮助。笔者贴一下自己服务器上 Nginx 的配置：

```nginx
http {
    include            mime.types;
    default_type       application/octet-stream;

    charset            UTF-8;

    sendfile           on;
    tcp_nopush         on;
    tcp_nodelay        on;

    keepalive_timeout  60;

    #... ...#

    gzip               on;
    gzip_vary          on;

    gzip_comp_level    6;
    gzip_buffers       16 8k;

    gzip_min_length    1000;
    gzip_proxied       any;
    gzip_disable       "msie6";

    gzip_http_version  1.0;

    gzip_types         text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;

    #... ...#

    include            /home/jerry/www/nginx_conf/*.conf;
}
```

### 4. 支持 TLS 1.3

这块网上的教程比较多，具体地址笔者就不贴了。

主要步骤需要先现在最新的 OpenSSL 和 Nginx，然后先编译 OpenSSL，再编译 Nginx。在编译 Nginx 的时候要带上刚刚编译的 OpenSSL 和 TLS1.3 的编译参数即可。

开启 TLS 1.3 可以参考这两篇文章[《本站开始支持TLS1.3》](https://www.cainwang.cn/tls1_3support/)、[《本博客开始支持 TLS 1.3》](https://imququ.com/post/enable-tls-1-3.html#comment-4000795428)。

### 5. 启用 OCSP Stapling


```nginx
server {
    ssl_session_cache        shared:SSL:10m;
    ssl_session_timeout      60m;

    ssl_session_tickets      on;

    ssl_stapling             on;
    ssl_stapling_verify      on;
    ssl_trusted_certificate  /xxx/full_chain.crt;

    resolver                 8.8.4.4 8.8.8.8  valid=300s;
    resolver_timeout         10s;
    ... ...
}
```

TLS 会话恢复的目的是为了简化 TLS 握手，有两种方案：Session Cache 和 Session Ticket。他们都是将之前握手的 Session 存起来供后续连接使用，所不同是 Cache 存在服务端，占用服务端资源；Ticket 存在客户端，不占用服务端资源。另外目前主流浏览器都支持 Session Cache，而 Session Ticket 的支持度一般。

`ssl_stapling` 开始的几行用来配置 OCSP stapling 策略。浏览器可能会在建立 TLS 连接时在线验证证书有效性，从而阻塞 TLS 握手，拖慢整体速度。OCSP stapling 是一种优化措施，服务端通过它可以在证书链中封装证书颁发机构的 OCSP（Online Certificate Status Protocol）响应，从而让浏览器跳过在线查询。服务端获取 OCSP 一方面更快（因为服务端一般有更好的网络环境），另一方面可以更好地缓存。


Let's Encrypt 目前支持 ECC 证书，申请完以后顺带记得开启 OCSP Stapling。具体的步骤可以参考这篇文章[《Let's Encrypt，免费好用的 HTTPS 证书》](https://imququ.com/post/letsencrypt-certificate.html)

配置完需要验证 OCSP Stapling 是否开启，可以用以下的命令：

```nginx
$ cd /var/www/ghost/ssl/

$ openssl ocsp -CAfile full_chained.pem -issuer intermediate.pem -cert chained.pem -no_nonce -text -url http://ocsp.int-x3.letsencrypt.org -header "HOST" "ocsp.int-x3.letsencrypt.org"

```

### 6. 支持 QUIC

本博客目前支持了 QUIC，但是性能上没有感觉有多少提升。而且目前只有 Chrome 支持 QUIC，开启几率也极低，基本上还都是走 HTTP/2。

想支持 QUIC 需要在服务器部署 caddy 这个 Go 的项目。由于我们已经有了 Nginx 占用了 443 端口，所以需要做一次端口映射，可以借助 Docker 来实现。另外 Nginx 配置里面也需要加一个头参数：

```nginx
add_header alt-svc 'quic=":443"; ma=2592000; v="39"';
```

### 7. 开启 HSTS

开启 HSTS 首先需要满足以下条件：

- 拥有合法的证书（如果使用 SHA-1 证书，过期时间必须早于 2016 年）；
- 将所有 HTTP 流量重定向到 HTTPS；
- 确保所有子域名都启用了 HTTPS；
- 输出 HSTS 响应头：  
  max-age 不能低于 18 周（10886400 秒）；  
  必须指定 includeSubdomains 参数；  
  必须指定 preload 参数；  

然后 Nginx 要加入相关的安全策略

```nginx

add_header  Strict-Transport-Security  "max-age=31536000";
add_header  X-Frame-Options  deny;
add_header  X-Content-Type-Options  nosniff;
add_header  Content-Security-Policy  "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://a.disquscdn.com; img-src 'self' data: https://www.google-analytics.com; style-src 'self' 'unsafe-inline'; frame-src https://disqus.com";

ssl_certificate      /home/ssl/server.crt;
ssl_certificate_key  /home/ssl/server.key;
ssl_dhparam          /home/ssl/dhparams.pem;

ssl_ciphers          ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:DES-CBC3-SHA;

ssl_prefer_server_ciphers  on;

ssl_protocols        TLSv1 TLSv1.1 TLSv1.2;
```

最后可以在 [ssllabs](https://www.ssllabs.com/ssltest/index.html)上进行测试。笔者拿到了 A+ 的成绩：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_19.png'>
</p>

## 最后

最后上述优化点都优化完，用 Chrome 版本 67.0.3396.99（正式版本）（64 位）匿名模式下跑分(选择在匿名模式下跑分是为了减少其他插件的影响)，在网络环境很好的条件下，得到的最好成绩如下：

没有缓存的情况下，FMP 160ms，FI 300ms

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_11_0.png'>
</p>

有缓存的情况下，FMP 和 FI 都是 110ms，这得益于 PWA 的缓存效果。

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/94_12_0.png'>
</p>

但是优化还远远没有终点。本文会持续更新。


------------------------------------------------------

Reference：  


[优化 Google Analytics 异步加载来提高你的网站速度](https://imiku.me/2017/07/14/916.html)  
[服务端使用 Google Analytics](https://blog.alphatr.com/google-analytics-on-server.html)
[Analytics代码延迟异步加载](http://blog.angular.in/analyticsdai-ma-yan-chi-yi-bu-jia-zai/)  
[IntersectionObserver’s Coming into View](https://developers.google.com/web/updates/2016/04/intersectionobserver)    
[七牛图片基本处理 API](https://developer.qiniu.com/dora/manual/1279/basic-processing-images-imageview2)  
[PWA 网络应用清单](https://developers.google.com/web/fundamentals/web-app-manifest/#_5)  
[2018 前端性能优化清单](http://cherryblog.site/front-end-performance-checklist-2018.html)    
[Nginx 配置之安全篇](https://imququ.com/post/my-nginx-conf-for-security.html)    
[Nginx 配置之完整篇](https://imququ.com/post/my-nginx-conf.html)  
[解决Nginx配置http2不生效，谷歌浏览器仍然采用http1.1协议问题](https://zhangge.net/5114.html)  
[使用 Service Workers](https://developer.mozilla.org/zh-CN/docs/Web/API/Service_Worker_API/Using_Service_Workers)  
[让你的Ghost博客支持Progressive Web Apps (PWA)](https://blog.wangkaibo.com/node-express-ghost-progressive-web-apps-pwa/)  
[本站开启支持-quic-的方法与配置](https://liudanking.com/beautiful-life/%E6%9C%AC%E7%AB%99%E5%BC%80%E5%90%AF%E6%94%AF%E6%8C%81-quic-%E7%9A%84%E6%96%B9%E6%B3%95%E4%B8%8E%E9%85%8D%E7%BD%AE/)  
[Let's Encrypt，免费好用的 HTTPS 证书](https://imququ.com/post/letsencrypt-certificate.html)  
[本站开始支持TLS1.3](https://www.cainwang.cn/tls1_3support/)  
[本博客开始支持 TLS 1.3](https://imququ.com/post/enable-tls-1-3.html#comment-4000795428)      
[从无法开启 OCSP Stapling 说起](https://imququ.com/post/why-can-not-turn-on-ocsp-stapling.html)  

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ghost\_fast/](https://halfrost.com/ghost_fast/)


