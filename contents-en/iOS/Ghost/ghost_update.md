# Ghost Blog Upgrade Guide

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/92_0.png'>
</p>

When I first set up this site, the Ghost version I used was the 0.7.4 Chinese edition. This very early version also allowed quite a few hacky tricks. It wasn’t until recently, when some friends around me also started playing with Ghost, that I realized many new features in the latest version were very appealing: for example, the latest version has long supported inserting tables in Markdown, and it also supports LaTeX. The lack of support for inserting tables in Markdown used to be quite painful. Previously, the workaround for tables was to publish the article on GitHub, take a screenshot, and then upload the image to Ghost.

Since several years have passed, if I’m going to upgrade, I might as well upgrade directly to the latest version. As of the time of writing, the latest version is Ghost 1.24.8. Next, I’ll write up some upgrade guidance. If you, like me, are using the Ghost 0.7.4 Chinese edition and want to upgrade to the latest version, you can take a look at my upgrade journey.

## Preparation

The preparation work is mainly to back up the old version’s configuration and data. Here is a checklist of what needs to be backed up:

- Database file
  Export all post data through the Ghost admin system; this is essentially a JSON file exported from MySQL.
- Theme files ghost/content/themes/
- The server-side Ghost configuration file config.js
- The ghost.conf configuration file under Nginx
- The entire Ghost directory on the server
  Backing up the entire directory is optional. It is meant to allow rollback if something goes wrong, and to recover data if anything is lost.

## Starting the Upgrade

Ghost changed quite a lot after V1.XX, because many convenient scaffolding tools were added, such as Ghost, Ghost-CLI, and so on. Upgrading from 0.7.4 counts as a breaking change, so these Ghost tools all need to be installed fresh.

>Ghost is a fully open source, hackable platform for building and running a modern online publication.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/92_1.jpg'>
</p>

Before installing the latest version of Ghost, please read the official documentation first:  
[getting-started-guide](https://docs.ghost.org/v1.0.0/docs/getting-started-guide)  
[Install & Setup (production)](https://docs.ghost.org/docs/install)

The rest of this article is basically the same set of steps from that English documentation, except that I’ve added some of the issues I encountered myself. I’ll keep the order of the problems consistent with the installation sequence, and I hope this can provide readers with some help during the upgrade.


### Environment Setup

#### 1. Environment Dependencies

- At least 1 GB of memory (or configure a swap partition)
- Systemd (included with CentOS 7)
- Node.js ( v8.9+, v6.9+, v4.5+ )
- MySQL (or sqlite3)
- nginx (if SSL needs to be configured to use https, then nginx >= 1.9.5)
- A non-root user with sudo privileges (the username also cannot be ghost). **This point is very important; this special user will be emphasized below**.

#### 2. Configure a Swap Partition

The purpose of a swap partition is that when physical memory is insufficient, the system will place data into swap, so swap acts as a form of virtual memory. Ghost requires at least 1GB of physical memory; otherwise, it will report an error. This can be resolved by configuring a swap partition (if you have 1GB or more, you do not need to configure it).

Check the host’s physical memory and virtual memory:
```bash
$ free
```

```makefile
total used free shared buff/cache available

Mem: 1016168 100360 293520 356 622288 746024

Swap: 0 0 0

```
Create 1024k empty files of size 1k in /var/swap:
```bash
$ dd if=/dev/zero of=/var/swap bs=1k count=1024k
```

```makefile
1048576+0 records in
1048576+0 records out
1073741824 bytes (1.1 GB) copied, 18.4951 s, 58.1 MB/s
```
Create a swap partition:
```bash
$ mkswap /var/swap
```

```makefile
Setting up swapspace version 1, size = 1048572 KiB
no label, UUID=9a1b4bf2-cc39-4ab7-8dd9-9e0f25d0695d
```
Enable the swap partition:
```bash
$ swapon /var/swap
```
```makefile
swapon: /var/swap: insecure permissions 0644, 0600 suggested.
```
Write partition information:
```bash
$ echo '/var/swap swap swap default 0 0' >> /etc/fstab
```
Check the swap partition size again:
```bash
$ free
```

```makefile
total used free shared buff/cache available
Mem: 1016168 100360 293520 356 622288 746024
Swap: 1048572 0 1048572
```

#### 3. Check Node.js

Check the installed Node.js version:
```bash
$ node -v
```

```makefile
v8.11.3
```
Note: The latest version of Ghost supports Node.js versions v8.9+, v6.9+, and v4.5+.

Check the Node.js installation path:
```bash
$ sudo which node
```

```makefile
/bin/node
```
**Note**: Node.js must be installed in a system path, such as /usr/bin/node or /usr/local/bin/node. Using nvm to manage Node.js is not recommended, because nvm installs Node.js under user paths such as /root or /home, and relying on symlinks will not work. If you must use nvm, you can use it to install Node.js in a system path (see Install system-wide Node.js with NVM: the painless way).

#### 4. Check MySQL

Check the MySQL version:
```bash
$ mysqld -V
```

```makefile
mysqld Ver 5.7.22 for Linux on x86_64 (MySQL Community Server (GPL))
```
Note: We recommend using MySQL 5.7.x, not 8.x; otherwise, Ghost will fail to connect to MySQL.

Check whether the MySQL service is running:
```bash
$ systemctl is-active mysqld
```
```makefile
active
```
Log in to MySQL as the MySQL root user:
```bash
$ mysql -u root -p -h localhost
```
Enter the MySQL root user password:
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
Just ensure that the root user can log in to MySQL normally.

Because we are upgrading Ghost, the original MySQL configuration should already be in place. In this section, you only need to verify that the account is still usable.

#### 5. Check nginx

Check the nginx version:
```bash
$ nginx -v
```

```makefile
nginx version: nginx/1.15.0
```
Note: If you need to configure SSL to use HTTPS, the NGINX version must be 1.9.5 or later.

Check whether the NGINX service is running:
```bash
$ systemctl is-active nginx
```

```makefile
active
```
Use the IP address to confirm that you can access the nginx welcome page, or the welcome page you modified yourself.

### Start the Installation

#### 1. Install Ghost-CLI

Ghost-CLI makes it easy to manage and upgrade Ghost going forward. After installing Ghost-CLI, future version upgrades only require running `ghost update`. So for this breaking update, you only need to go through the pain once.

Install ghost-cli globally with npm:
```bash
$ sudo npm i -g ghost-cli
```
Check the installed ghost-cli version:
```bash
$ ghost -v
```

```makefile
Ghost-CLI version: 1.8.1
```

#### 2. Create a New User

Note: If you already have a non-root user with sudo privileges, skip this step.

Create a new user:
```bash
$ adduser <user>
```
Note: `<user>` is the username of the new user. This name must not be `ghost`, because Ghost creates a user named `ghost`.

Set the user password:
```bash
$ passwd <user>
```
Enter the user password twice.

Grant write permission to the /etc/sudoers file:
```bash
$ chmod -v u+w /etc/sudoers
```
Edit file:
```bash
$ vim /etc/sudoers
```
Found:
```makefile

## Allow root to run any commands anywhere
root    ALL=(ALL)       ALL
```
Add below:
```makefile

# This user does not need to enter a password when using the sudo command
<user>    ALL=(ALL)       NOPASSWD:ALL

# or this user needs to enter a password when using the sudo command
<user>    ALL=(ALL)       ALL
```
Save and exit, then restore the permissions of the `/etc/sudoers` file:
```bash
$ chmod -v u-w /etc/sudoers
```

#### 3. Configure Ghost

Create the directory
Switch to a non-root user that has sudo privileges and whose username is not ghost:
```bash
$ su - <user>
```
Note: ghost-cli creates a system user and group named ghost to run Ghost automatically.

Create the website directory and set permissions:
```bash
$ sudo mkdir -p /var/www/ghost
$ sudo chown <user>:<user> /var/www/ghost
$ sudo chmod 775 /var/www/ghost
```
Note: `<user>` is the username of the currently logged-in non-root user.

Go to the website directory:
```bash
$ cd /var/www/ghost
```

#### 4. Install Ghost

Because we are upgrading directly in the production environment, we are using a MySQL database. In a local environment, sqlite3 is used.

Skip the system checks in the current directory and install Ghost using MySQL as the database.

Although the official documentation lists Ubuntu 16.04 as the recommended OS, Ghost can also be installed on CentOS; you just need to add the `--no-stack` option.
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
Enter your website’s full URL [https://halfrost.com](https://halfrost.com) 

Press Enter:
```makefile
? Enter your blog URL: [https://halfrost.com](https://halfrost.com)
? Enter your MySQL hostname: (localhost)
```
Enter the MySQL login address. For a local login, just enter `localhost` and press Enter:
```makefile
? Enter your MySQL hostname: localhost
? Enter your MySQL username:
```
Input root:
```makefile
? Enter your MySQL username: root
? Enter your MySQL password: [input is hidden]
```
Enter the MySQL `root` user password:
```makefile
? Enter your MySQL password: [hidden]
? Enter your Ghost database name:
```
Enter the name of the database to create, or press Enter to use the default:
```makefile
✔ Configuring Ghost
✔ Setting up instance
Running sudo command: chown -R ghost:ghost /var/www/ghost/content
✔ Setting up "ghost" system user
? Do you wish to set up "ghost" mysql user? (Y/n)
```
Press Enter to confirm automatically creating the MySQL user:
```makefile
? Do you wish to set up "ghost" mysql user? Yes
✔ Setting up "ghost" mysql user
? Do you wish to set up Nginx? (Y/n)
```
Press Enter to confirm automatic nginx setup:
```makefile
? Do you wish to set up Nginx? Yes
Nginx is not installed. Skipping Nginx setup.
ℹ Setting up Nginx [skipped]
Task ssl depends on the 'nginx' stage, which was skipped.
ℹ Setting up SSL [skipped]
? Do you wish to set up Systemd? (Y/n)
```
I found that Ghost-CLI still does not recognize the installed nginx on CentOS, so I will configure it manually later.

Pressing Enter directly does indeed automatically set up the system service:
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
At this point, if you try to start it, it will fail because the nginx configuration is from an older version, and the configuration fields have changed in the new version.

#### 5. Configure nginx

Create a new configuration file:
```bash
$ sudo vim /etc/nginx/conf.d/ghost.conf
```
Write the configuration. The following is my configuration, shown only as an example:
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
Note: Change the `server_name` field to the domain name(s) you have configured for DNS resolution. Separate multiple domain names with spaces.

Save and exit, then restart the nginx service:
```bash
$ sudo systemctl restart nginx
```

#### 6. Other ghost Configuration

Under the /var/www/ghost/ directory, there is a `config.production.json` file, which contains some configuration for ghost. Here is my configuration:
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
The configuration fields above have changed significantly compared with the older version. Although the configuration options are largely the same, their formats have changed.

You can configure email, the database, CDN storage, the log file path, and `contentPath`.

## Testing

Start the current website service:
```bash
$ sudo systemctl start ghost_halfrost-com
```
Check the service status:
```bash
$ sudo systemctl status ghost_halfrost-com
```
```makefile
● ghost_halfrost-com.service - Ghost systemd service for blog: halfrost-com
   Loaded: loaded (/var/www/ghost/system/files/ghost_halfrost-com.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2018-07-15 14:40:07 CST; 8h ago
     Docs: https://docs.ghost.org
 Main PID: 454 (ghost run)
   Memory: 218.7M
   CGroup: /system.slice/ghost_halfrost-com.service
           ├─454 ghost run
           └─829 /usr/local/bin/node current/index.js

```
Note: Do not use `ghost start` to start it. On CentOS 7, this command will fail because the service check returns `unknown`.

Use the bound domain name to access your site, and go to `http://<domain>/ghost` to register the administrator account.

If it can be accessed normally, set the service to start on boot:
```bash
$ sudo systemctl enable ghost_halfrost-com
```

## Issues Encountered

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/92_2.jpg'>
</p>

If you upgraded Ghost by following the steps above and did not run into any issues, congratulations—you can happily leave this article now. If you did encounter problems, please continue reading.

Ghost officially provides an error handbook: [troubleshooting](https://docs.ghost.org/docs/troubleshooting). If you run into an issue, you can check this handbook first.

Next, I’ll share a few issues I encountered during the upgrade process.

### node: command not found

This issue can occur after Ghost is installed. When a non-root user with sudo privileges invokes node-related commands, this error appears.
```bash
$ sudo -u ghost node -v
```
```Makefile
sudo：node：command not found
```
When I ran into this issue, I was a bit confused. I had already created a non-root user with sudo privileges, and Node was installed globally. In theory, this problem shouldn’t have occurred. After searching online for a long time, I finally found the cause.

It turns out that on CentOS, after installing Node globally, the default path is `/usr/local/bin/node`, while Ghost may follow the Linux path convention and only recognize `/usr/bin/node`. So you need to add a symlink to resolve this issue.
```bash
$ sudo ln -s /usr/local/bin/node /usr/bin/node
```
Check
```bash
$ sudo -u ghost node -v
```

```Makefile
v8.11.3
```
Successfully outputting the version number means it worked.

### server limits the upload file size

For example, uploading a 10 MB high-resolution image will result in an error because the server limits the file size. This limit is enforced by nginx. The default is 5 MB; anything larger than that is not allowed.

So we need to increase the nginx limit. First, locate the nginx configuration file. The configuration file is at `/etc/nginx/nginx.conf`. (The original permissions of `nginx.conf` are -rw-r—r—, 0644.)

We need to modify the file permissions first:
```bash
$ cd /etc/nginx
$ chmod 777 nginx.conf
```
In this file, add `client_max_body_size`
```bash
$ vim nginx.conf
```
Add `client_max_body_size 10m;`

Finally, restore the file permissions and restart the nginx service.
```bash
$ chmod 644 nginx.conf
$ service nginx restart
```

### user locked

When importing a JSON database file backed up from an older version of Ghost into the latest version of Ghost, you may run into an issue where the user is locked. This is likely a security consideration in Ghost.

I searched through the Ghost admin UI for quite a while but couldn’t find anywhere to change this status directly. In the end, I had no choice but to look in the database, where I found it. After changing it there, everything worked fine.
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
There is a `status` field in the `users` table; just change this field for the corresponding user to `active`.
```bash
mysql> update users set status = "active";
```

### Emoji Upgrade

In older versions of Ghost, the database used `utf8` encoding by default, so it could not support emoji. The tables created by the latest version of Ghost use `utf8mb4` encoding by default, which supports emoji. 🙄😏

### Permission Issues

After installing the latest version of Ghost, there are still some additional issues, such as permission problems. You just have to resolve them one by one.
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
Judging from the error messages, they are all caused by file permission issues.
```bash
$ sudo find ./ ! -path "./versions/*" -type f -exec chmod 664 {} \;
$ sudo chown -R ghost:ghost ./content
```
After changing the permissions, run `ghost doctor` again; all issues should be resolved.
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