# Ghost 博客升级指南

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/92_0.png'>
</p>

在笔者一开始建站的时候，用的 Ghost 版本就是 0.7.4 中文版。这个非常早期的版本也有不少 hack 的玩法。直到最近周围有朋友也在玩 Ghost 的时候，我发现最新版很多新功能非常吸引我：比如最新版早就支持了 markdown 插入表格，也能支持 LateX。关于不支持 markdown 插入表格这个比较痛苦，之前表格的替代方法是在 github 上发布完文章以后截图，然后把图片传到 Ghost 上。

既然几年过去了，要升级就直接升级到最新版吧。截止到这篇文章的时间，当前最新版是 Ghost 1.24.8 。接下来写一些升级指南，如果也有和我一样用 Ghost 0.7.4 中文版的想升级到最新版，可以看看笔者的升级之路。

## 准备工作

准备工作当前是备份老版本的配置和数据。这里列一个需要备份的清单：

- 数据库文件
  通过 Ghost 后台管理系统，导出所有博文数据，其实就是从 MySQL 中导出的 JSON 文件。
- 主题文件 ghost/content/themes/
- 服务器端 Ghost 的配置文件 config.js
- Nginx 下的 ghost.conf 配置文件
- 服务器上的 Ghost 整个文件夹
  备份整个文件夹是可选的，是为了防止出错可以回退，丢数据可以找回。

## 开始升级

Ghost 在 V1.XX 以后改动比较大，因为加入了很多方便的脚手架工具，比如 Ghost、Ghost-CLI 等等。从 0.7.4 升级上来算是一次 breaking，所以 Ghost 这些工具都需要新装。

>Ghost is a fully open source, hackable platform for building and running a modern online publication.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/92_1.jpg'>
</p>

安装 Ghost 最新版之前请先阅读官方文档：  
[getting-started-guide](https://docs.ghost.org/v1.0.0/docs/getting-started-guide)  
[Install & Setup (production)](https://docs.ghost.org/docs/install)

接下来的文章基本也就是这份英文文档里面的步骤，只不过加了一些自己遇到的问题，行文会把遇到问题的先后顺序和安装的顺序保持一致，希望能给读者一些升级上的帮助。


### 环境配置

#### 1. 环境依赖

- 至少 1 GB 为内存（或者设置 swap 分区）
- Systemd （CentOS 7 自带）
- Node.js ( v8.9+, v6.9+, v4.5+ )
- MySQL （或者 sqlite3）
- nginx（如果需要配置 SSL 使用 https，则 nginx >= 1.9.5）
- 一个非 root 且拥有 sudo 权限的用户（用户名也不能为 ghost ）**这一点非常重要，下面会强调这个特殊用户**。

#### 2. 设置 Swap 分区

Swap 分区的用处是当物理内存不够用的时候，系统会把数据放到 swap 中，所以 swap 起到了一个虚拟内存的作用。Ghost 需要至少 1GB 物理内存，否则会报错，可以通过设置 swap 分区解决（大于等于 1GB 可不用设置）。

查看主机物理内存和虚拟内存：

```bash
$ free
```

```makefile
total used free shared buff/cache available

Mem: 1016168 100360 293520 356 622288 746024

Swap: 0 0 0

```

在 /var/swap 创建 1024k 个 1k 大小的空文件：

```bash
$ dd if=/dev/zero of=/var/swap bs=1k count=1024k
```

```makefile
1048576+0 records in
1048576+0 records out
1073741824 bytes (1.1 GB) copied, 18.4951 s, 58.1 MB/s
```

创建 swap 分区：

```bash
$ mkswap /var/swap
```

```makefile
Setting up swapspace version 1, size = 1048572 KiB
no label, UUID=9a1b4bf2-cc39-4ab7-8dd9-9e0f25d0695d
```

启用 swap 分区：

```bash
$ swapon /var/swap
```
```makefile
swapon: /var/swap: insecure permissions 0644, 0600 suggested.
```

写入分区信息：

```bash
$ echo '/var/swap swap swap default 0 0' >> /etc/fstab
```

再次查看 swap 分区大小：

```bash
$ free
```

```makefile
total used free shared buff/cache available
Mem: 1016168 100360 293520 356 622288 746024
Swap: 1048572 0 1048572
```

#### 3. 检查 Node.js

查看安装的 node.js 版本号：

```bash
$ node -v
```

```makefile
v8.11.3
```

注意： Ghost 最新版支持的 Node.js 的版本为 v8.9+, v6.9+, v4.5+ 。

查看 node.js 安装路径：

```bash
$ sudo which node
```

```makefile
/bin/node
```

**注意**：Node.js 需要安装在系统路径，比如 /usr/bin/node 或者 /usr/local/bin/node 等。不推荐使用 nvm 来管理 node.js，nvm 会把 node.js 安装在 /root 或者 /home 等用户路径，依靠建立软链的方式是不行的。如果一定要用 nvm，可以使用 nvm 将 node.js 安装在系统路径中（见 Install system-wide Node.js with NVM: the painless way）。

#### 4. 检查 MySQL

查看 MySQL 版本：

```bash
$ mysqld -V
```

```makefile
mysqld Ver 5.7.22 for Linux on x86_64 (MySQL Community Server (GPL))
```

注意： 推荐使用 MySQL 5.7.x 版本，不要使用 8.x 版本，否则 Ghost 将连接 MySQL 出错。

检查 MySQL 服务是否正在运行：

```bash
$ systemctl is-active mysqld
```
```makefile
active
```

使用 MySQL root 用户登陆 MySQL：

```bash
$ mysql -u root -p -h localhost
```

输入 MySQL root 用户密码：

```makefile
Welcome to the MySQL monitor. Commands end with ; or \g.
Your MySQL connection id is 2
Server version: 5.7.22

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>

```

确保可以 root 用户可以正常登陆 MySQL 即可。

由于我们是升级 Ghost，Mysql 这里其实原来配置都有，这一小节只需要检验一下账户是否还可以用就可以了。

#### 5. 检查 nginx

检查 nginx 版本：

```bash
$ nginx -v
```

```makefile
nginx version: nginx/1.15.0
```

注意： 如果需要配置 SSL 使用 https，则 nginx 版本需要大于等于 1.9.5。

检查 nginx 服务是否正在运行：

```bash
$ systemctl is-active nginx
```

```makefile
active
```

使用 IP 地址确认可以访问到 nginx 的欢迎页面，或者自己修改后的欢迎页面。

### 开始安装

#### 1. 安装 Ghost-CLI

Ghost-CLI 可以方便对未来的 Ghost 状态管理，升级。装上 Ghost-CLI 以后，之后的版本升级只需要 `ghost update` 一下就可以了。所以本次 breaking update 只需要痛这一次。

使用 npm 全局安装 ghost-cli ：

```bash
$ sudo npm i -g ghost-cli
```

查看安装的 ghost-cli 版本：

```bash
$ ghost -v
```

```makefile
Ghost-CLI version: 1.8.1
```

#### 2. 创建新用户

注意： 如果已有拥有 sudo 权限的非 root 用户，跳过此步骤。

新建一个用户：

```bash
$ adduser <user>
```

注意：`<user>` 为新建用户的用户名。注意这个名字不能为 ghost，因为 Ghost 会创建一个叫 ghost 的用户。

设置用户密码：

```bash
$ passwd <user>
```

输入两遍用户密码。

赋予 /etc/sudoers 文件写权限：

```bash
$ chmod -v u+w /etc/sudoers
```

编辑文件：

```bash
$ vim /etc/sudoers
```

找到：

```makefile
## Allow root to run any commands anywhere
root    ALL=(ALL)       ALL
```

在下面添加：

```makefile
# 该用户在使用 sudo 命令时不需要输入密码
<user>    ALL=(ALL)       NOPASSWD:ALL
# or 该用户在使用 sudo 命令时需要输入密码
<user>    ALL=(ALL)       ALL
```

保存退出，并恢复 /etc/sudoers 文件权限：

```bash
$ chmod -v u-w /etc/sudoers
```

#### 3. 配置 Ghost

创建目录
切换到一个非 root 且拥有 sudo 权限的用户，且用户名不为 ghost 的其他用户：

```bash
$ su - <user>
```

注意： ghost-cli 会创建一个用户名为 ghost 的系统用户和用户组来自动运行 Ghost。

创建网站目录并设置权限：

```bash
$ sudo mkdir -p /var/www/ghost
$ sudo chown <user>:<user> /var/www/ghost
$ sudo chmod 775 /var/www/ghost
```

注意：`<user>` 为当前登陆的非 root 用的的用户名。

进入到网站目录：

```bash
$ cd /var/www/ghost
```

#### 4. 安装 Ghost

由于我们是直接在生产环境上升级，所以用的是 Mysql 数据库。如果是 local 环境，用的是 sqlite3 数据库。

在当前目录跳过系统检查，使用 MySQL 作为数据库来安装 Ghost。

虽然官方文档上写的推荐 OS 是 Ubuntu 16.04，不过 CentOS 一样可以安装，只要加上 `--no-stack` 参数即可。

```bash
$ ghost install --no-stack
```

```makefile
✔ Checking system Node.js version
✔ Checking logged in user
✔ Checking current folder permissions
ℹ Checking operating system compatibility [skipped]
✔ Checking for a MySQL installation
✔ Checking memory availability
✔ Checking for latest Ghost version
✔ Setting up install directory
✔ Downloading and installing Ghost v1.24.8
✔ Finishing install process
? Enter your blog URL: (http://localhost:2368)
```

输入自己网站完整访问路径 [https://halfrost.com](https://halfrost.com) 

回车：

```makefile
? Enter your blog URL: [https://halfrost.com](https://halfrost.com)
? Enter your MySQL hostname: (localhost)
```

输入 MySQL 的登陆地址，本机登陆就是 localhost 直接回车即可：

```makefile
? Enter your MySQL hostname: localhost
? Enter your MySQL username:
```

输入 root：

```makefile
? Enter your MySQL username: root
? Enter your MySQL password: [input is hidden]
```

输入 MySQL 的 root 用户密码：

```makefile
? Enter your MySQL password: [hidden]
? Enter your Ghost database name:
```

输入要创建的数据库的名称，回车直接使用默认的：

```makefile
✔ Configuring Ghost
✔ Setting up instance
Running sudo command: chown -R ghost:ghost /var/www/ghost/content
✔ Setting up "ghost" system user
? Do you wish to set up "ghost" mysql user? (Y/n)
```

回车确认自动创建 MySQL 用户：

```makefile
? Do you wish to set up "ghost" mysql user? Yes
✔ Setting up "ghost" mysql user
? Do you wish to set up Nginx? (Y/n)
```

直接回车确定自动设置 nginx：

```makefile
? Do you wish to set up Nginx? Yes
Nginx is not installed. Skipping Nginx setup.
ℹ Setting up Nginx [skipped]
Task ssl depends on the 'nginx' stage, which was skipped.
ℹ Setting up SSL [skipped]
? Do you wish to set up Systemd? (Y/n)
```

发现 Ghost-CLI 在 CentOS 上依然不识别已安装的 nginx，后面自己手动设置。

直接回车确实自动设置系统服务：

```makefile
? Do you wish to set up Systemd? Yes
✔ Creating systemd service file at /var/www/ghost/system/files/ghost_halfrost-com.service
Running sudo command: ln -sf /var/www/ghost/system/files/ghost_halfrost-com.service /lib/systemd/system/ghost_halfrost-com.service
Running sudo command: systemctl daemon-reload
✔ Setting up Systemd
Running sudo command: /var/www/ghost/current/node_modules/.bin/knex-migrator-migrate --init --mgpath /var/www/ghost/current
✔ Running database migrations
? Do you want to start Ghost? (Y/n)
```

现在如果启动，是启动不起来的，因为 nginx 的配置是老版本的，新版本的配置字段有变更。

#### 5. 设置 nginx

新建配置文件：

```bash
$ sudo vim /etc/nginx/conf.d/ghost.conf
```

写入配置，下面是我的配置，只是举个例子：

```makefile
server {  
    listen 443 default_server ssl http2;
    server_name halfrost.com www.halfrost.com;
    
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-Xss-Protection 1;

    ssl on;
    ssl_certificate /etc/letsencrypt/live/halfrost.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/halfrost.com/privkey.pem; # managed by Certbot
    ssl_prefer_server_ciphers on;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";

    location / {
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   Host      $http_host;
        proxy_pass         http://127.0.0.1:2368;
    }

}


server {  
        listen 80;
        server_name halfrost.com www.halfrost.com;
	rewrite ^(.*)  https://$server_name$1;

        #if ($http_user_agent !~* baidu.com){ 
        #        return 301 https://$host$request_uri;
	#}

	location /.well-known/acme-challenge/ {
            	alias /var/www/halfrost.com/.well-known/acme-challenge/;
            	try_files $uri =404;
        }

        location / {
                proxy_set_header   X-Real-IP $remote_addr;
                proxy_set_header   Host      $http_host;
                proxy_pass         http://127.0.0.1:2368;
                client_max_body_size 35m;
        }
}

```

注意： 修改 server_name 字段为自己解析的域名，多个域名空格隔开。

保存退出，重启 nginx 服务：

```bash
$ sudo systemctl restart nginx
```

#### 6. ghost 其他配置

在 /var/www/ghost/ 文件夹下面有一个 `config.production.json` 文件，这文件是对 ghost 的一些配置。这里可以列举一下我的配置：

```makefile
{
  "url": "http://halfrost.com",
  "server": {
    "port": 2368,
    "host": "127.0.0.1"
  },
  "mail": {
    "transport": "SMTP",
    "from": "halfrost@halfrost.com",
    "options": {
	 "host": "smtp.qq.com",
     	 "secureConnection": true,
         "port": 465,
         "auth": {
              "user": "707176544@qq.com",
              "pass": "XXXX"
       	  }
     }
  },
  "database": {
    "client": "mysql",
    "connection": {
      "host": "127.0.0.1",
      "user": "ghost",
      "password": "XXXX",
      "database": "XXXX"
    }
  },
  "storage": {
    "active": "qn-store",
    "qn-store": {
      "accessKey": "XXXX",
      "secretKey": "XXXX",
      "bucket": "XXXX",
      "origin": "XXXX",
      "fileKey": {
        "safeString": true,
        "prefix": "[Blog/ArticleTitleImage/]",
	"suffix": "",
	"extname": true
      }
    }
  },
  "logging": {
    "transports": [
      "file",
      "stdout"
    ]
  },
  "process": "systemd",
  "paths": {
    "contentPath": "/var/www/ghost/content"
  }
}

```

上面的配置字段比老版本变化了很多，虽然设置项基本没变，但是格式都有变化。

可以设置邮件，数据库，CDN 存储，日志文件地址，contentPath。

## 测试

启动当前网站服务：

```bash
$ sudo systemctl start ghost_halfrost-com
```

查看服务状态：

```bash
$ sudo systemctl status ghost_halfrost-com
```
```makefile
● ghost_halfrost-com.service - Ghost systemd service for blog: halfrost-com
   Loaded: loaded (/var/www/ghost/system/files/ghost_halfrost-com.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2018-07-15 14:40:07 CST; 8h ago
     Docs: https://docs.ghost.org
 Main PID: 454 (ghost run)
   Memory: 218.7M
   CGroup: /system.slice/ghost_halfrost-com.service
           ├─454 ghost run
           └─829 /usr/local/bin/node current/index.js

```

注意： 不要使用 ghost start 启动，该命令在 CentOS 7 上会因为服务检查返回值为 unknown 而出错。

使用绑定的域名尝试访问自己的网站，访问 `http://<domain>/ghost` 注册管理员账号。

可正常访问，则将该服务设置为开机启动：


```bash
$ sudo systemctl enable ghost_halfrost-com
```


## 遇到的问题

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/92_2.jpg'>
</p>

如果按照上面的步骤升级完 Ghost，没有出现问题，那么恭喜你，可以愉快的离开本文了。如果遇到了问题，请继续往下看。

Ghost 官方提供了一个错误手册 [troubleshooting](https://docs.ghost.org/docs/troubleshooting)，遇到问题可以先来查看这个手册。

接下来分享几个我在升级过程中遇到的问题。

### node：找不到命令

这个问题会出现在 Ghost 安装以后，当非 root 且拥有 sudo 权限的用户调用 node 相关的方法，就会出现这个错误。

```bash
$ sudo -u ghost node -v
```
```Makefile
sudo：node：找不到命令
```

遇到这个问题的时候，笔者比较懵。因为非 root 且拥有 sudo 权限的用户笔者也创建了，node 也是全局安装的。按理来说不应该出现这个问题。在网上查了很久，才发现这个问题的原因。

原来在 CentOS 上，全局安装完 node，默认的路径在 `/usr/local/bin/node`，而 Ghost 可能按照 Linux 的路径，只认 `/usr/bin/node`。所以这里需要添加软链解决这个问题。

```bash
$ sudo ln -s /usr/local/bin/node /usr/bin/node
```

检查

```bash
$ sudo -u ghost node -v
```

```Makefile
v8.11.3
```

成功输出版本号，代表成功了。

### server 限制上传文件大小

比如上传一个 10MB 的高清图片，会报一个错误，server 限制了文件大小。这个限制是 nginx 上限制的。默认是 5MB，超过这个大小都不允许。

那么我们就需要提高 nginx 限制，先找到 nginx 的配置文件。配置文件在 `/etc/nginx/nginx.conf`。(`nginx.conf` 的原始权限是 -rw-r—r—，0644)

我们需要先修改文件的权限：

```bash
$ cd /etc/nginx
$ chmod 777 nginx.conf
```

在这个文件中，添加 `client_max_body_size`
```bash
$ vim nginx.conf
```

添加 `client_max_body_size 10m;`

最后还原文件权限，重启 nginx 服务。

```bash
$ chmod 644 nginx.conf
$ service nginx restart
```

### user locked

如果从老版本的 Ghost 备份的数据库文件 JSON 导入到最新版的 Ghost 的时候，会遇到用户被 locked 的问题。这个可能是 Ghost 出于安全的考虑。

笔者在 Ghost 后台找了很久，也没有发现能直接更改这个状态的地方。无奈，最终在数据库里面找到了，更改过后就好了。

```bash
$ mysql -u ghost -p
```

```Makefile
Enter password:

Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 267
Server version: 5.7.37 MySQL Community Server (GPL)

Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

```bash
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| ghost              |
| newghost           |
+--------------------+
3 rows in set (0.00 sec)

mysql> show tables;
+------------------------+
| Tables_in_newghost     |
+------------------------+
| accesstokens           |
| app_fields             |
| app_settings           |
| apps                   |
| brute                  |
| client_trusted_domains |
| clients                |
| invites                |
| migrations             |
| migrations_lock        |
| permissions            |
| permissions_apps       |
| permissions_roles      |
| permissions_users      |
| posts                  |
| posts_authors          |
| posts_tags             |
| refreshtokens          |
| roles                  |
| roles_users            |
| settings               |
| subscribers            |
| tags                   |
| users                  |
| webhooks               |
+------------------------+
25 rows in set (0.00 sec)

mysql> show create table users;
| users | CREATE TABLE `users` (
  `id` varchar(24) NOT NULL,
  `name` varchar(191) NOT NULL,
  `slug` varchar(191) NOT NULL,
  `ghost_auth_access_token` varchar(32) DEFAULT NULL,
  `ghost_auth_id` varchar(24) DEFAULT NULL,
  `password` varchar(60) NOT NULL,
  `email` varchar(191) NOT NULL,
  `profile_image` varchar(2000) DEFAULT NULL,
  `cover_image` varchar(2000) DEFAULT NULL,
  `bio` text,
  `website` varchar(2000) DEFAULT NULL,
  `location` text,
  `facebook` varchar(2000) DEFAULT NULL,
  `twitter` varchar(2000) DEFAULT NULL,
  `accessibility` text,
  `status` varchar(50) NOT NULL DEFAULT 'active',
  `locale` varchar(6) DEFAULT NULL,
  `visibility` varchar(50) NOT NULL DEFAULT 'public',
  `meta_title` varchar(2000) DEFAULT NULL,
  `meta_description` varchar(2000) DEFAULT NULL,
  `tour` text,
  `last_seen` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `created_by` varchar(24) NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  `updated_by` varchar(24) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_slug_unique` (`slug`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 |
```

在 users 表中有一个 status 字段，把对应的用户这个字段改成 active 即可。

```bash
mysql> update users set status = "active";
```

### emoji 升级

在老版本的 Ghost 中，数据库默认是 utf8 的编码，所以不能支持 emoji 表情。最新版的 Ghost 默认创建的表就是支持 emoji 的 utf8mb4 编码。🙄😏

### 权限问题

在安装完最新版的 Ghost 以后，还是有一些额外的问题，比如权限问题。那只能一一解决咯。

```bash
$ ghost doctor
```

```Makefile
✔ Checking system Node.js version
✔ Checking logged in user
✔ Ensuring user is not logged in as ghost user
✔ Checking if logged in user is directory owner
✔ Checking current folder permissions
System checks failed with message: 'Linux version is not Ubuntu 16'
Some features of Ghost-CLI may not work without additional configuration.
For local installs we recommend using `ghost install local` instead.
? Continue anyway? Yes
ℹ Checking operating system compatibility [skipped]
✔ Checking for a MySQL installation
Running sudo command: systemctl is-active ghost_halfrost-com
✔ Validating config
✔ Checking folder permissions
✖ Checking file permissions
✖ Checking content folder ownership
✔ Checking memory availability
One or more errors occurred.

1) Checking file permissions

Message: Your installation folder contains some directories or files with incorrect permissions:
- ./content/themes/boo-master/assets/fonts/casper-icons.svg
- ./content/themes/boo-master/assets/fonts/casper-icons.woff
- ./content/themes/boo-master/assets/fonts/casper-icons.eot
- ./content/themes/boo-master/assets/fonts/casper-icons.ttf
- ./content/themes/yasuko-----2/author.hbs
- ./content/themes/yasuko-----2/default.hbs
- ./content/themes/yasuko-----2/LICENSE
- ./content/themes/yasuko-----2/gulpfile.js
- ./content/themes/yasuko-----2/page.hbs
- ./content/themes/yasuko-----2/assets/js/dev.min.js
- ./content/themes/yasuko-----2/assets/js/webfont.js
- ./content/themes/yasuko-----2/assets/js/jquery.fitvids.js
- ./content/themes/yasuko-----2/assets/js/prism.js
- ./content/themes/yasuko-----2/assets/js/lazy.js
- ./content/themes/yasuko-----2/assets/js/all.min.js
- ./content/themes/yasuko-----2/assets/js/index.js
- ./content/themes/yasuko-----2/assets/css/uncompressed.css
- ./content/themes/yasuko-----2/assets/css/dev.min.css
- ./content/themes/yasuko-----2/assets/css/all.min.css
- ./content/themes/yasuko-----2/assets/css/screen.css
- ./content/themes/yasuko-----2/assets/css/font_.min.css
- ./content/themes/yasuko-----2/index.hbs
- ./content/themes/yasuko-----2/partials/navigation.hbs
- ./content/themes/yasuko-----2/partials/loop.hbs
- ./content/themes/yasuko-----2/package.json
- ./content/themes/yasuko-----2/post.hbs
- ./content/themes/yasuko-----2/tag.hbs
- ./content/themes/yasuko-----2/README.md
- ./content/themes/odin-master/assets/fonts/casper-icons.svg
- ./content/themes/odin-master/assets/fonts/casper-icons.woff
- ./content/themes/odin-master/assets/fonts/casper-icons.eot
- ./content/themes/odin-master/assets/fonts/casper-icons.ttf
- ./content/themes/odin-master/assets/js/rrssb.min.js
- ./content/themes/odin-master/assets/css/rrssb.css
- ./node_modules/os-name/cli.js
- ./node_modules/mime/src/build.js
- ./node_modules/mime/cli.js
- ./node_modules/semver/bin/semver
- ./node_modules/osx-release/cli.js
- ./node_modules/mkdirp/bin/cmd.js
- ./node_modules/escodegen/bin/escodegen.js
- ./node_modules/escodegen/bin/esgenerate.js
- ./node_modules/esprima/bin/esvalidate.js
- ./node_modules/esprima/bin/esparse.js
Run sudo find ./ ! -path "./versions/*" -type f -exec chmod 664 {} \; and try again.


2) Checking content folder ownership

Message: Your installation folder contains some directories or files with incorrect permissions:
- ./content/adapters
- ./content/adapters/storage
- ./content/adapters/storage/qn-store
- ./content/adapters/storage/qn-store/LICENSE
- ./content/adapters/storage/qn-store/lib
- ./content/adapters/storage/qn-store/lib/getHash.js
- ./content/adapters/storage/qn-store/package.json
- ./content/adapters/storage/qn-store/index.js
- ./content/adapters/storage/qn-store/.npmignore
- ./content/adapters/storage/qn-store/README.md
Run sudo chown -R ghost:ghost ./content and try again.

Debug Information:
    OS: CentOS, v7.3.1611
    Node Version: v8.11.3
    Ghost-CLI Version: 1.8.1
    Environment: production
    Command: 'ghost doctor'

Try running ghost doctor to check your system for known issues.

Please refer to https://docs.ghost.org/v1/docs/troubleshooting#section-cli-errors for troubleshooting.

```

从报错来看，都是因为文件权限的原因。

```bash
$ sudo find ./ ! -path "./versions/*" -type f -exec chmod 664 {} \;
$ sudo chown -R ghost:ghost ./content
```

更改权限以后再次执行 `ghost doctor`，所有问题都解决了。

```bash
$ ghost doctor
```

```Makefile
✔ Checking system Node.js version
✔ Checking logged in user
✔ Ensuring user is not logged in as ghost user
✔ Checking if logged in user is directory owner
✔ Checking current folder permissions
System checks failed with message: 'Linux version is not Ubuntu 16'
Some features of Ghost-CLI may not work without additional configuration.
For local installs we recommend using `ghost install local` instead.
? Continue anyway? Yes
ℹ Checking operating system compatibility [skipped]
✔ Checking for a MySQL installation
Running sudo command: systemctl is-active ghost_halfrost-com
✔ Validating config
✔ Checking folder permissions
✔ Checking file permissions
✔ Checking content folder ownership
✔ Checking memory availability
```

------------------------------------------------------

Reference：  

[getting-started-guide](https://docs.ghost.org/v1.0.0/docs/getting-started-guide)   
[cli-install](https://docs.ghost.org/v1.0.0/docs/cli-install)    
[Install & Setup (production)](https://docs.ghost.org/docs/install)    
[troubleshooting](https://docs.ghost.org/docs/troubleshooting)    
[Unlock Your Locked Ghost Account](https://briankoopman.com/unlock-ghost-account/)  
       

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ghost\_update/](https://halfrost.com/ghost_update/)