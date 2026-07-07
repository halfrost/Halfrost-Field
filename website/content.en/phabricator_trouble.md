+++
author = "一缕殇流化隐半边冰霜"
categories = ["Code review", "Phabricator"]
date = 2016-04-25T01:54:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/2_0_.png"
slug = "phabricator_trouble"
tags = ["Code review", "Phabricator"]
title = "Pitfalls I Encountered Setting Up Phabricator"

+++


#### I. Commands You May Need
1. Restart the phd daemon
First go to the Fabricator folder, then $./bin/phd/ log

2. Delete a code repository  $ ./bin/remove destroy rMOBILE(repository prefix name)

3. Restart the MySQL database
```vim    
sudo launchctl unload -F /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
sudo launchctl load -F /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
```
4. Command to restart the Apache server
```vim    
sudo /usr/sbin/apachectl restart
sudo apachectl -k restart
```

#### II. Some Pitfalls You May Encounter

##### 1. How to fix the “sudo: /etc/sudoers is owned by uid 501, should be 0” issue on Mac
- First enable the root account    
- Enable and use the “root” user in OS X    

**OS X Lion (10.7) and later**    

- Choose “System Preferences” from the Apple menu.    
- Choose “Users & Groups” from the “View” menu.    
- Click the lock icon and authenticate with an administrator account.    
- Click “Login Options”.    
- Click the “Edit” or “Join” button in the lower-right corner.    
- Click the “Open Directory Utility” button.  
- Click the lock icon in the “Directory Utility” window.  
- Enter the administrator account name and password, then click “OK”.  
- Choose “Enable Root User” from the “Edit” menu.  
- Enter the root password you want to use in the “Password” and “Verify” fields, then click “OK”.  

**Mac OS X Snow Leopard (10.6.x)**  

- Choose “System Preferences” from the Apple menu.  
- Choose “Accounts” from the “View” menu.  
- Click the lock icon and authenticate with an administrator account.  
- Click “Login Options”.  
- Click the “Edit” or “Join” button in the lower-right corner.  
- Click the “Open Directory Utility” button.  
- Click the lock icon in the “Directory Utility” window.  
- Enter the administrator account name and password, then click “OK”.  
- Choose “Enable Root User” from the “Edit” menu.  
- Enter the root password you want to use in the “Password” and “Verify” fields, then click “OK”.  

##### 2. If the sudo command cannot be used on Mac, log in with the root account and change the permissions of the sudoers file as follows:
```vim 
$cd  /etc
$ls -al （view all files and their group permissions）
$chgrp wheel sudoers
$chown root /etc/sudoers
```
Then you can exit the root account, log in again with another account, and use the sudo command.

##### 3. How to access MySQL on Mac. The following uses the command line; for a graphical method, use MySQL Workbench.
```vim   
$ cd /usr/local/mysql/bin
$ ls -l
$ mysql -h localhost -u root -p
Enter password:
```
After you log in, the following screen will appear.
```sql  
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 225
Server version: 5.7.10 MySQL Community Server (GPL)

Copyright (c) 2000, 2015, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show databases;   (Note that the commands here must all include semicolons!)
```

##### 4. phpize Command Failed
Go to the php-protobuf page and run phpize as follows
```php  
grep: /usr/include/php/main/php.h: No such file or directorygrep: /usr/include/php/Zend/zend_modules.h: No such file or directorygrep: /usr/include/php/Zend/zend_extensions.h: No such file or directoryConfiguring for:PHP Api Version: Zend Module Api No: Zend Extension Api No:
```
Google it

Solution:
```vim  
sudo ln -s/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/usr/include/ /usr/include
```
Execute it
```vim  
ln: /usr/iclude: Operation not permitted

```
This error occurs  
because there is no `include` directory under `/usr/`.  
Also, running `mkdir include` cannot create the directory either; it reports `Operation not permitted` as well.

The real solution is:
```vim  
sudo ln -s/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/usr/include/ /usr/include
``` 
Linking fails because Mac OS X 10.11 strengthened system protection, and /usr no longer has write permission.

How to temporarily disable system protection:
Immediately after pressing the power button, hold down command R (the “R” key). Release the keys after the Apple logo and progress bar appear, then wait for the recovery installation screen and the “OS X Utilities” window to appear. Click “Utilities” in the top menu bar, choose “Terminal” from the drop-down menu, enter “csrutil disable” directly at the terminal prompt, press Enter, and restart the computer.

Of course, you can also directly use the phpize included with XAMPP.

#### III. Ongoing Maintenance
Main steps:  
1. Stop the server and stop the daemon process.
2. Use git to update the three dependency components; all three must be upgraded to the same latest version.
3. Update the SQL database. Errors are very likely at this point, because the table schema may have changed due to data structure changes and may need to be repaired.
4. Start the daemon thread. After the upgrade is complete, make sure to restart once!

The specific commands are as follows:
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

