


#### 一.可能会用到的命令
1.重启phd守护线程
先进入到Fabricator文件夹下面，然后 $./bin/phd/ log

2.删除一个代码仓库  $ ./bin/remove destroy rMOBILE(代码库的前缀名字)

3.重启mysql数据库

```vim    
sudo launchctl unload -F /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
sudo launchctl load -F /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
```

4.重启apache服务器命令

```vim    
sudo /usr/sbin/apachectl restart
sudo apachectl -k restart
```

#### 二.可能会用到的一些坑
##### 1.Mac如果出现“sudo: /etc/sudoers is owned by uid 501, should be 0 ”问题解决办法
- 先启用root账户    
- 在 OS X 中启用和使用“root”用户    

**OS X Lion (10.7) 和更高版本**    

- 从 Apple 菜单中选取“系统偏好设置”。    
- 从“显示”菜单中选取“用户与群组”。    
- 点按锁图标并使用管理员帐户进行鉴定。    
- 点按“登录选项”。    
- 点按右下方的“编辑”或“加入”按钮。    
- 点按“打开目录实用工具”按钮。  
- 点按“目录实用工具”窗口中的锁图标。  
- 输入管理员帐户名称和密码，然后点按“好”。  
- 从“编辑”菜单中选取“启用 Root 用户”。  
- 在“密码”和“验证”栏中输入您想要使用的 root 密码，然后点按“好”。  

**Mac OS X Snow Leopard (10.6.x)**  

- 从 Apple 菜单中选取“系统偏好设置”。  
- 从“显示”菜单中选取“帐户”。  
- 点按锁图标并使用管理员帐户进行鉴定。  
- 点按“登录选项”。  
- 点按右下方的“编辑”或“加入”按钮。  
- 点按“打开目录实用工具”按钮。  
- 点按“目录实用工具”窗口中的锁图标。  
- 输入管理员帐户名称和密码，然后点按“好”。  
- 从“编辑”菜单中选取“启用 Root 用户”。  
- 在“密码”和“验证”栏中输入您想要使用的 root 密码，然后点按“好”。  

##### 2.Mac如果出现sudo命令无法使用，然后root账户登录进去，更改sudoers文件的权限，步骤如下：

```vim 
$cd  /etc
$ls -al （查看所有文件以及所属组权限）
$chgrp wheel sudoers
$chown root /etc/sudoers
```

再就可以退出root账户重新登录其他账户，并且可以使用sudo命令了。

##### 3.Mac如何进入Mysql ，以下是命令行方式，图形化方式就是用MySQLWorkBench软件

```vim   
$ cd /usr/local/mysql/bin
$ ls -l
$ mysql -h localhost -u root -p
Enter password:
```

然后登陆进去了，就会出现下面这个界面

```sql  
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 225
Server version: 5.7.10 MySQL Community Server (GPL)

Copyright (c) 2000, 2015, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show databases;   (注意这里的命令一定都要带分号！)
```

##### 4.phpize命令失败
进入php-protobuf 页面 phpize 如下

```php  
grep: /usr/include/php/main/php.h: No such file or directorygrep: /usr/include/php/Zend/zend_modules.h: No such file or directorygrep: /usr/include/php/Zend/zend_extensions.h: No such file or directoryConfiguring for:PHP Api Version: Zend Module Api No: Zend Extension Api No:
```

google之
解决方法：

```vim  
sudo ln -s/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/usr/include/ /usr/include
```

执行之

```vim  
ln: /usr/iclude: Operation not permitted

```

报这个错误  
是因为 /usr/ 下是没有include 这个文件夹的  
还有mkdir include 创建不了文件夹 一样报Operation not permitted

真正的解决办法是：  

```vim  
sudo ln -s/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/usr/include/ /usr/include
``` 

链接失败原因 Mac OS X10.11加强了系统保护 /usr 木有操作权限

暂时停用系统保护的方法：
按下开机键时即刻按住 command R（“R”字母键），中间的苹果标志及进度条出现后放开按键，等待恢复安装界面和 “OS X 实用工具”窗口出现后，点击顶部菜单栏的 “实用工具”，在其下拉菜单点选运行 “终端”，在终端闪动字符的位置直接输入“csrutil disable”并回车，重新启动电脑。

当然也可以直接用XAMPP 中的phpize

#### 三.后期维护
主要步骤：  
1. 停止服务器，停止守护进程 
2. git更新3个依赖组件 ,3个必须升级到相同的最新版
3. 更新sql数据库 ，此时很有可能出错，因为表有可能变了数据结构导致表结构变化，需要修复 
4. 开启守护线程，升级完成一定要重启一次！

具体命令如下： 

```vim  
Stop the webserver (including php-fpm, if you use it).

Stop the daemons, with phabricator/bin/phd stop.

Run git pull in libphutil/, arcanist/ and phabricator/.

Run phabricator/bin/storage upgrade.

Start the daemons, with phabricator/bin/phd start.

Restart the webserver (and php-fpm, if you stopped it earlier).
```


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/phabricator\_trouble/](https://halfrost.com/phabricator_trouble/)

