# Ghost 博客搭建日记

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/26_0_.jpg'>
</p>

#### 前言

今年7月阴错阳差的给自己买了一台阿里云服务器，当时是想着自己折腾折腾后台，看能否打通前端和后端之间的任督二脉。直到我发现我原来放在GitPage上的博客访问速度慢的实在不能忍，痛下决心之后，就把原来Jekyll搭建的博客站点一口气都迁移到了现在自己阿里云的主机上了。原来的Jekyll博客还在，还在GitPage上。换到了国内自己的阿里云主机上，我就用了优雅的Ghost搭建我的新家了。

今年8月的时候，博客上线了，网友们看见我这个博客还不错，让我出一下搭建教程。虽然博客上线，还没有通过网络管理中心的审核，还不知道之后会发生什么。当时的我也对Ghost不是很熟，也不知道后期如何维护，所以想着先让Ghost在服务器上面跑一个月看看，有了心得体会之后在写篇文章记录一下搭建过程。

现在博客也跑了一个多月了，日常维护都玩的转了，于是就有了这一篇文章了。



#### 目录
- 1.Ghost 简介
- 2.搭建前准备清单
- 3.开始搭建
- 4.全站 Https
- 5.管局备案 / 公安备案
- 6.CDN 优化访问速度
- 7.后期维护


#### 一.Ghost简介


![](https://img.halfrost.com/Blog/ArticleImage/26_1.png)




Ghost 是一套基于 Node.js 构建的开源博客平台（Open source blogging platform），具有易用的书写界面和体验，博客内容默认采用 Markdown 语法书写，不过原生的不支持Markdown的表格和[LaTeX](http://www.baidu.com/link?url=K_4JBAR3uS6xnec99adJX0IzXiUT0ANv52nbth0WUNaf3Z52ob2qSLRPX0KjGNEBBBXE5d8hEvOhKdgBR77EDa)，如果需要使用，需要在服务器端安装插件。

Ghost目标是取代臃肿的 Wordpress，界面简洁，专注写作，支持在线预览和在线写作。

Ghost属于动态博客，页面并不是像[Hexo](http://hexo.io/),[Jekyll](http://jekyllrb.com/)这类静态博客，在编译的时候会生成所有页面。Ghost有前台和后台。后台负责写作，发布文章，系统配置，等等。

##### 1. Ghost的优势和劣势
这里有篇[文章](https://segmentfault.com/a/1190000002947497)是这样评论Ghost的优缺点的

- 优势
技术上,采用[NodeJs](https://nodejs.org/en)，在可预见的未来里，无疑比[PHP](http://php.net/)有更多优势，并发能力远超Wordpress，虽然NodeJs后期维护成本高，但是我们只是借它做博客而已。
易用性上，专注写作，评论，超炫皮肤，完美支持 MarkDown,没有Wordpress那么臃肿，回归到博客最原始的状态,传递文字最原始的力量。
使用上，便捷，随时随地编辑，比[Hexo](http://hexo.io/),[Jekyll](http://jekyllrb.com/)这类静态博客要书写方便，特别是在不同电脑上写作时。

- 劣势
需要配套支持Node环境的虚拟机，一般免费的很少支持，这时必须得掏腰包了。
后台简陋,许多功能还未完善，不过写作这一块没啥大问题。


关于劣势，我再说一点，Ghost没有Hexo上面那么丰富的插件。


##### 2. Ghost的亮点：

- 采用Mysql作为数据库,通用快速上手，这里也可以用其他数据库比如Sqlite。
- Nginx作为反向代理,配置多个Ghost博客,同时也能增加了网站的负载。
- 非常简易化的Ubuntu的Node.js安装方法，不用编译打包。
- 安装系统服务,开机重启Ghost服务，免去日后以后操作。
- 采用[Font Awesome](http://fontawesome.io/icons/)作为社交按钮，也可以自定义图标。
- [highlight.js](http://highlightjs.org/) 作为主题的代码高亮引擎
- 整合[Disqus](https://disqus.com/)评论系统,建立属于自己的Discuss圈
- 国外优秀免费[Ghost主题](http://themeforest.net/category/blogging/ghost-themes)资源分享
- 整合[百度统计](http://tongji.baidu.com/web/welcome/login)以及[百度分享](http://share.baidu.com/)



#### 二. 搭建前准备清单

- 一个可用的域名
- 一台服务器 ( 我买的[阿里云ECS](https://www.aliyun.com/product/ecs?spm=5176.8048432.416540.25.gO4w50) ，服务器系统安装的是 CentOS 7.0 64位)
- Node v0.10.40（官方建议版本，**注意，安装Ghost中文版，只能安装这个版本的Node，安装高版本的会不识别，安装其他版本的Ghost也一定要注意对准版本号**）
- Nginx 1.80
- Mysql
- Ghost v0.7.4 full (zh)（**中文汉化**、支持**七牛**、**又拍云**、**阿里云OSS**存储) 目前Ghost最新版是v**0.11.1** (3.8mb zip)，中文版最新版本号只到v0.7.4。

Ghost官网 https://ghost.org/  
Ghost中文官网 http://www.ghostchina.com/  
Ghost中文文档 http://docs.ghostchina.com/zh/  


#### 三. 开始搭建


![](https://img.halfrost.com/Blog/ArticleImage/26_2.png)



##### 1. 安装Node
Ghost是基于Node.js构建的开源博客平台，所以我们首先搭建Node环境。


![](https://img.halfrost.com/Blog/ArticleImage/26_3.png)



```vim

$ wget http://nodejs.org/dist/v0.10.40/node-v0.10.40.tar.gz 

$ tar zxvf node-v0.10.40.tar.gz 

$ cd node-v0.10.40 

$ ./configure 

$ make && make install 

```

命令执行完毕之后，检测一下环境是否配置成功。

```vim

$ node -v 

v0.10.40

```

显示node的版本号，即为安装成功。

**一定要注意node的版本号和Ghost的版本是否对应**，如果不对应，会报下面的错误

![](https://img.halfrost.com/Blog/ArticleImage/26_26.png)

解决办法就是更改node的版本。




##### 2. 安装Nginx


![](https://img.halfrost.com/Blog/ArticleImage/26_4.png)


Nginx是一款轻量级的Web服务器/反向代理服务器及电子邮件（IMAP/POP3）代理服务器，并在一个BSD-like 协议下发行。

首先在/etc/yum.repos.d/目录下创建一个源配置文件nginx.repo

```vim

$ vi /etc/yum.repos.d/nginx.repo

```

写入以下内容：

```vim

[nginx] 
name=nginx repo 
baseurl= http://nginx.org/packages/centos/$releasever/$basearch/ 
gpgcheck=0 
enabled=1

```
保存。

按i编辑，按Esc结束编辑，:x保存修改并退出，:q!强制退出，放弃修改，:wq也是保存并退出。

初始化好Nginx之后，继续执行以下指令：

```vim

$ yum install nginx -y # 安装
$ Nginx service nginx start # 启动
$ Nginx chkconfig nginx on # 设置开机启动Nginx 

```

这样Nginx就安装成功了，在浏览器中输入你的服务器的IP地址就可以看到提示：“Welcome to Nginx!”


##### 3. 配置Nginx
安装好了nginx后，我们需要设置一个代理服务器让我们的博客可以使用域名访问。 

```vim

$ cd /etc/nginx/conf.d

```

在这个目录下创建一个配置文件ghost.conf

```vim

$ vi /etc/nginx/conf.d/ghost.conf

```

粘贴以下内容：

```vim

server {
    listen 443;
    server_name halfrost.com www.halfrost.com; #这里写你的域名或者ip地址

    ssl on;
    ssl_certificate /etc/letsencrypt/live/halfrost.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/halfrost.com/privkey.pem;

    location / {
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   Host      $http_host;
        proxy_pass         http://127.0.0.1:2368;
    }
}

```

中间有3行SSL的，是为了后面全站配置Https的，如果不需要Https，中间3行不需要加。


保存退出，重启nginx：


```vim

$ service nginx restart

```

Nginx 就配置完成了。


##### 4. 安装Mysql

![](https://img.halfrost.com/Blog/ArticleImage/26_5.png)




Ghost 默认使用 sqlite3 数据库，对于一般使用足够了，但是内容多的话，就会拖慢整个系统，也就影响页面打开速度了，不想使用Mysql的朋友可以跳过这步。 

CentOS7的yum源中默认好像是没有mysql的。为了解决这个问题，我们要先下载mysql的repo源。

1.下载mysql的repo源

```vim

$ wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm

```

2.安装mysql-community-release-el7-5.noarch.rpm包

```vim

$ sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm

```

安装这个包后，会获得两个mysql的yum repo源：  
/etc/yum.repos.d/mysql-community.repo，
/etc/yum.repos.d/mysql-community-source.repo。
  
3.安装mysql

```vim

$ sudo yum install mysql-server

```
根据步骤安装就可以了，不过安装完成后，没有密码，需要重置密码。

4.重置密码

重置密码前，首先要登录

```vim

$ mysql -u root

```

登录时有可能报这样的错：ERROR 2002 (HY000): Can‘t connect to local MySQL server through socket ‘/var/lib/mysql/mysql.sock‘ (2)，原因是/var/lib/mysql的访问权限问题。下面的命令把/var/lib/mysql的拥有者改为当前用户：

```vim

$ sudo chown -R openscanner:openscanner /var/lib/mysql

```
然后，重启服务：

```vim

$ service mysqld restart
$ chkconfig mysqld on # 设置开机启动Mysql 

```


##### 5. 配置Mysql


输入mysql_secure_installation配置Mysql：

```vim

$ Set root password? [Y/n] # 设置root密码 
$ anonymous users? [Y/n] # 删除匿名用户 
$ Disallow root login remotely? [Y/n] # 禁止root用户远程登录 
$ Remove test database and access to it? [Y/n] # 删除默认的 test 数据库 
$ Reload privilege tables now? [Y/n] # 刷新授权表使修改生效 

```

为了避免数据库存放的中文是乱码，我们还需要设置Mysql的编码：

```vim

$ vi /etc/my.cnf

```

粘贴以下内容：

```vim

[client]
default-character-set=utf8 
[mysql]
default-character-set=utf8
[mysqld]
character-set-server=utf8 
collation-server=utf8_general_ci

```

保存退出，重启Mysql：


```vim

$ service mysqld restart

```

最后我们需要新建一个数据库，用来存放博客的数据：


```vim

$ mysql -u root -p # 输入设置好的密码 
$ create database ghost; # 创建ghost数据库 
$ grant all privileges on ghost.* to 'ghost'@'%' identified by '123456'; # 新建一个用户ghost，密码为123456，这里自己设置 
$ flush privileges # 重新读取权限表中的数据到内存，不用重启mysql就可以让权限生效 

```

Mysql数据库就安装配置完成了。

##### 6. 安装Ghost


![](https://img.halfrost.com/Blog/ArticleImage/26_6.jpg)



首先下载Ghost：

```vim

$ cd /var/www 
$ wget http://dl.ghostchina.com/Ghost-0.7.4-zh-full.zip 
$ unzip Ghost-0.7.4-zh-full.zip -d ghost 
$ cd ghost

```

接着修改默认配置：


```vim

$ cp config.example.js config.js 
$ vi config.js

```

Ghost有产品模式、开发模式和测试模式等多种运行模式，这里我们需要在配置文件中找到production模式：


```vim

config = {
    // ### Production
    // When running Ghost in the wild, use the production environment.
    // Configure your URL and mail settings here
    production: {
        url: 'http://www.halfrost.com',
        mail: {},
        database: {
            client: 'mysql',
            connection: {
               // filename: path.join(__dirname, '/content/data/ghost.db')
               host:'127.0.0.1',
               user:'ghost',  #数据库连接的用户
               password:'iloveghost', #之前数据库创建的密码
               database:'ghost',  #之前创建的数据库名字
               charset:'utf8'
            },
            debug: false
        },
 // 配置MySQL 数据库
        /*database: {
            client: 'mysql',
            connection: {
                host     : 'host',
                user     : 'user',
                password : 'password',
                database : 'database',
                charset  : 'utf8'
            },
            debug: false
        },*/

        server: {
            host: '127.0.0.1',
            port: '2368'
        },

       //Storage.Now,we can support `qiniu`,`upyun`, `aliyun oss`, `aliyun ace-storage` and `local-file-store`
       // storage: {
           // provider: 'local-file-store'
       // }

        // or
        // 参考文档： http://www.ghostchina.com/qiniu-cdn-for-ghost/
        storage: {
            provider: 'qiniu',
            bucketname: 'Mybucketname',
            ACCESS_KEY: 'TZmRdasfdasfps5NDJEK4d*JsdgYGFFgWOsy5k_k0Zu',
            SECRET_KEY: '7IsGSDDf1ef4HEsafsagLPDfs3gCkr$FERFe6ivfT',
            root: '/Blog/',
            prefix: 'https://odd2zeri30g.qnssl.com/'
        }

```

storage这一项是配置云存储的，支持七牛，又拍云，阿里云等等，具体设置需要查看相应文档。如果只需要本地存储，改成下面的样子：

```vim

   storage: { 
     provider: 'local-file-store' 
}

```

保存并退出，Ghost就配置完成了。

运行

```vim

$ npm start --production

```

启动浏览器，输入之前配置的域名或者IP，我们就可以看到建立好的Ghost博客啦。 （Ctrl+C 中断掉开发者模式）

##### 7.部署Ghost


前面提到的启动 Ghost 使用 npm start --production 命令。这是一个在开发模式下启动和测试的不错的选择，但是通过这种命令行启动的方式有个缺点，即当你关闭终端窗口或者从 SSH 断开连接时，Ghost 就停止了。为了防止 Ghost 停止工作，我们得解决这个问题。

以下有几种解决方案：  
PM2([https://github.com/Unitech/pm2](https://github.com/Unitech/pm2))   
Forever ([https://npmjs.org/package/forever](https://npmjs.org/package/forever))   
Supervisor ([http://supervisord.org/](http://supervisord.org/))  

这里我们使用PM2让Ghost保持运行：

```vim

$ cd /var/www/ghost 
$ npm install pm2 -g # 安装PM2 
$ NODE_ENV=production 
$ pm2 start index.js --name "ghost" 
$ pm2 startup centos pm2 save

```

如果npm安装依赖的时候无法安装，需要把镜像换成淘宝的，再试试。

```vim

$ npm install -g cnpm --registry= https://registry.npm.taobao.org
$ cnpm install pm2 -g 
$ NODE_ENV=production pm2 start index.js --name "ghost" 
$ pm2 startup centos 
$ pm2 save

```

这样一来，我们的Ghost博客就可以保持运行啦，你可以使用以下指令来控制Ghost博客：

```vim

pm2 start/stop/restart ghost

```

##### 8. 初始化Ghost

现在所有准备工作都做好了，打开你的浏览器，在浏览器中输入 域名地址/ghost/，开始初始化用户名，密码，就可以开始愉快的Ghost之旅了。


#### 四. 全站Https

![](https://img.halfrost.com/Blog/ArticleImage/26_7.png)


Let's Encrypt是国外一个公共的免费SSL项目，由 Linux 基金会托管，它的来头不小，由Mozilla、思科、Akamai、IdenTrust和EFF等组织发起，目的就是向网站自动签发和管理免费证书，以便加速互联网由HTTP过渡到HTTPS，目前Facebook等大公司开始加入赞助行列。

Let's Encrypt已经得了 IdenTrust 的交叉签名，这意味着其证书现在已经可以被Mozilla、Google、Microsoft和Apple等主流的浏览器所信任，你只需要在Web 服务器证书链中配置交叉签名，浏览器客户端会自动处理好其它的一切，Let's Encrypt安装简单，未来大规模采用可能性非常大。

Let's Encrypt官网：  
1、官方网站：https://letsencrypt.org/  
2、项目主页：https://github.com/letsencrypt/letsencrypt  

##### 1、 安装Let's Encrypt免费SSL准备
安装Let's Encrypt脚本依赖环境：（这一部分可以跳过，因为官方提供的Let's Encrypt脚本会自动检测并安装）

```vim

# Debian
$ apt-get install git

# CentOS 6
$ yum install centos-release-SCL && yum update
$ yum install python27
$ scl enable python27 bash
$ yum install python27-python-devel python27-python-setuptools python27-python-tools python27-python-virtualenv
$ yum install augeas-libs dialog gcc libffi-devel openssl-devel python-devel
$ yum install python-argparse

# CentOS 7
$ yum install -y git python27
$ yum install -y augeas-libs dialog gcc libffi-devel openssl-devel python-devel
$ yum install python-argparse


```

查看自己的VPS主机到底是安装了哪个操作系统版本，可以执行命令：cat /etc/issue 或者 cat /etc/redhat-release。



![](https://img.halfrost.com/Blog/ArticleImage/26_8.png)





##### 2. 获取Let's Encrypt免费SSL证书

获取Let's Encrypt免费SSL证书很简单，你只需要执行以下命令，就会自动在你的VPS上生成SSL证书和私钥。

```vim

$ git clone https://github.com/letsencrypt/letsencrypt
$ cd letsencrypt
$ ./letsencrypt-auto

```

经过测试，上述代码对于Debian系统支持最好，可以完成自动检测并安装相应的软件。如果你是使用其它的Linux系统，Redhat或CentOS 6可能需要配置EPEL软件源，Python需要2.7版本以上。



![](https://img.halfrost.com/Blog/ArticleImage/26_9.png)





执行上述命令后，会弹出对话框，同意用户协议。


![](https://img.halfrost.com/Blog/ArticleImage/26_10.png)



接着会提示让你关闭Nginx或者Apache。


![](https://img.halfrost.com/Blog/ArticleImage/26_11.png)




Let's Encrypt需要用到80和443端口，所以你需要关闭那些占用这两个端口的应用。


![](https://img.halfrost.com/Blog/ArticleImage/26_12.png)



当你看以下内容时，就表明你的Let's Encrypt免费SSL证书获取成功了。



```vim

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at
   /etc/letsencrypt/live/freehao123.org/fullchain.pem. Your cert will
   expire on 2016-03-09. To obtain a new version of the certificate in
   the future, simply run Let's Encrypt again.
 - If like Let's Encrypt, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

```


见下图：


![](https://img.halfrost.com/Blog/ArticleImage/26_13.png)





到此，证书就申请结束了。


##### 3. 配置SSL证书

接下来要配置一下本地的Nginx，在Nginx的config文件里面加入ssl的配置，配置在上面配置Nginx的时候已经写过了。

##### 4.脚本自动获取SSL证书

免费申请的SSL证书是每3个月就会过期，如果每次都要手动去申请证书，有点麻烦，而且一旦忘记了，SSL证书就过期了。


利用脚本快速获取Let's Encrypt SSL证书，调用 acme_tiny.py 认证、获取、更新证书，不需要额外的依赖。

项目主页：https://github.com/xdtianyu/scripts/tree/master/lets-encrypt


下载项目到本地

```vim

$ wget https://raw.githubusercontent.com/xdtianyu/scripts/master/lets-encrypt/letsencrypt.conf
$ wget https://raw.githubusercontent.com/xdtianyu/scripts/master/lets-encrypt/letsencrypt.sh
$ chmod +x letsencrypt.sh

```

![](https://img.halfrost.com/Blog/ArticleImage/26_14.png)




配置文件。只需要修改 DOMAIN\_KEY DOMAIN\_DIR DOMAINS 为你自己的信息


```vim

ACCOUNT_KEY="letsencrypt-account.key"
DOMAIN_KEY="freehao123.com.key"
DOMAIN_DIR="/var/www/freehao123.com"
DOMAINS="DNS:freehao123.com,DNS:www.freehao123.com"

```

执行过程中会自动生成需要的 key 文件。运行：

```vim

./letsencrypt.sh letsencrypt.conf

```


注意需要已经绑定域名到 /var/www/www.freehao123.com 目录，即通过 http://freehao123.com https://www.freehao123.com 可以访问到 /var/www/freehao123.com目录，用于域名的验证。



正常按照上面的操作即可成功获取到Let's Encrypt SSL证书，不过经过测试最大的问题就是“DNS query timed out”，由于域名DNS解析的问题导致无法验证域名从而获取SSL证书不成功。

```vim

Traceback (most recent call last):
  File "/tmp/acme_tiny.py", line 198, in 
    main(sys.argv[1:])
  File "/tmp/acme_tiny.py", line 194, in main
    signed_crt = get_crt(args.account_key, args.csr, args.acme_dir, log=LOGGER, CA=args.ca)
  File "/tmp/acme_tiny.py", line 149, in get_crt
    domain, challenge_status))
ValueError: hkh.freehao123.info challenge did not pass: {u'status': u'invalid', u'validationRecord': [{u'url': u'http://hkh.freehao123.info/.well-known/acme-challenge/sikHlqvbN4MrWkScgr1oZ9RX-lR1l__Z7FWVLhlYR0Q', u'hostname': u'hkh.freehao123.info', u'addressUsed': u'', u'port': u'80', u'addressesResolved': None}],  u'https://acme-v01.api.letsencrypt.org/acme/challenge/5m1su6O5MmJYlGzCJnEUAnvhweAJwECBhEcvsQi5B2Q/1408863', u'token': u'sikHlqvbN4MrWkScgr1oZ9RX-lR1l__Z7FWVLhlYR0Q', u'error': {u'type': u'urn:acme:error:connection', u'detail': u'DNS query timed out'}, u'type': u'http-01'}

```

如果遇到这种情况，请加上VPN再试一次了。

配置好了自动获取SSL证书的脚本以后，就不用担心自己的SSL证书会过期啦。

到这里，访问你博客网站对应的443端口就是https了。

![](https://img.halfrost.com/Blog/ArticleImage/26_23.png)

#### 五. 管局备案 / 公安备案

进行到这一步，其实网站已经“上线”，并且可以成功访问了。不过正常访问80端口会出现以下的界面。

![](https://img.halfrost.com/Blog/ArticleImage/26_15.png)


但是如果配置好了Https，正常访问443端口是没问题的。

我猜想这里应该可以把80端口的所有请求都转发到443，那不就可以避开80端口的请求了？不过我没有这么尝试。

想让我们辛辛苦苦搭建的博客能以正常的方式访问到，那么需要申请管局的备案。我在阿里云买的服务器，申请备案有直达链接，很方便。

![](https://img.halfrost.com/Blog/ArticleImage/26_16.png)


申请过程需要先填写个人信息，申请地要写身份证所在地。个别地方有特殊规定，比如上海和北京，如果有居住证，可以写居住证的所在地。然后还要上传手持身份证图片，和一些需要亲手签字的扫描件。

这些提交好了之后，会给你邮寄一块幕布，需要你拍照再次上传备案。



![](https://img.halfrost.com/Blog/ArticleImage/26_17.png)



之后就是等待了，一般备案从提交到审核通过大概10个工作日左右。如果觉得慢，还可以电话咨询审核进度。


![](https://img.halfrost.com/Blog/ArticleImage/26_18.png)




当管局备案通过之后，会给你发邮件，里面还有一个公安备案。我看很多教程没有说要公安备案。也许是新出的。点邮件里面的链接，继续进行公安备案。

公安备案也是需要填写个人信息。这里全部提交完全之后提交就好了，没有管局的备案麻烦，只需要等待审核通过即可。


![](https://img.halfrost.com/Blog/ArticleImage/26_19.png)



当这两个备案都完美通过之后，就可以算是备案通过，网站可以正常上线了。上线前，记得需要在网站页脚处加上备案号。这些说明在备案通过的邮件里面有详细的说明，把邮件里面说到的事情都做一遍，就OK了。



#### 六. CDN优化访问速度

![](https://img.halfrost.com/Blog/ArticleImage/26_20.png)


网站上线以后，访问速度会比服务器在国外的GitPage访问快一点。但是如果网站图片很多，或者文章图片质量很高，很多，访问速度还是会随之下降。

这是我们需要加入CDN来加速。

这里我用的七牛的CDN云服务。申请一个正好，建立好自己的仓库，就可以把需要缓存到CDN的资源都上传进去。图片，视频，音乐都可以放进去。博客里面引用的就是七牛上面这些资源的外链。

这里需要提醒注意的一点是，七牛记得设置好防盗链和流量提醒，否则别人会偷偷的从你这里盗走好多流量，到月底，我们就白白花掉了好多冤枉钱了。

由于之前全站设置了Https，所以七牛这里的图片也需要用https的，https的流量比http的免费流量少很多。


设置好了以后，我跑了一个分，对比之前放在GitPage上的博客访问速度。


![](https://img.halfrost.com/Blog/ArticleImage/26_21.png)




#### 七. 后期维护

这里的维护基本上指的是博客更新和发布以及Ghost配置的更改。

在自己的github上把所有的Ghost的配置都放在仓库里面，并把自己服务器的SSH Key加入到Github的key里面去。

git clone 一份到本地，每次在本地更改了，调试好之后，就先push一份到远端。然后登陆到服务器上，把最新的代码pull下来，应用就好了。pull完之后只要执行

```vim

$ service nginx restart
$ pm2 restart ghost

```

执行这两句就可以了。


平时还可能会出现一些https的问题，遇到了就Google查找错误代码就可以了。


这里说一个https不兼容百度分享的问题。


这里有一份修改好的分享代码Github地址[https://github.com/hrwhisper/baiduShare](https://github.com/hrwhisper/baiduShare)


static 解压后丢到站点根目录下即可。

然后对应的百度分享代码中，把http://bdimg.share.baidu.com/改为 /

```vim

.src='http://bdimg.share.baidu.com/static/api/js/share.js?v=89860593.js?cdnversion='+~(-new Date()/36e5)];</script>
改为
.src='/static/api/js/share.js?v=89860593.js?cdnversion='+~(-new Date()/36e5)];</script>

```

这样就可以了。如果想知道具体是怎么实现了，就看看作者[这篇文章](https://www.hrwhisper.me/baidu-share-not-support-https-solution/)


解决百度分享不支持https的还有一个办法是利用七牛的镜像存储

看了下从百度分享获取的代码，里面主要加载了这个：http://bdimg.share.baidu.com/static/api/js/share.js， 访问了一下确实不支持 HTTPS。利用七牛的镜像存储，或者自己利用服务器的Nginx反向代理一下就可以支持https了。

具体实现可以看[这篇文章](https://iyaozhen.com/use-qiniu-image-storage-allow-baidu-share-support-https.html)

#### 最后



![](https://img.halfrost.com/Blog/ArticleImage/26_22.png)


经过我们自己辛辛苦苦一路踩坑过来，搭建出来的博客，一定会好好珍惜。这是我们程序员自己的家，让我们用一篇篇的用心的博客来装饰我们的新家吧。



------------------------------------------------------

Reference：  

[安装Ghost & 开始尝试](http://docs.ghostchina.com/zh/installation/)    
[「搭建Ghost博客」经典教程](https://segmentfault.com/a/1190000002947497)    
[如何搭建一个Ghost平台的博客](http://www.zhihu.com/question/22755373)    
[How To Create a Blog with Ghost and Nginx on Ubuntu 14.04](https://www.digitalocean.com/community/tutorials/how-to-create-a-blog-with-ghost-and-nginx-on-ubuntu-14-04)    
[免费SSL证书Let’s Encrypt安装使用教程:Apache和Nginx配置SSL](https://www.freehao123.com/lets-encrypt/)    
[手把手教你搭建一个属于自己的Ghost博客](https://snowz.me/how-to-install-ghost/)    
 
       

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ghost\_build/](https://halfrost.com/ghost_build/)