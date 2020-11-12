+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Jenkins", "Continuous Integration", "CI", "Docker", "fastlane", "gym", "xcodebuild", "xcrun", "fir"]
date = 2016-07-30T23:04:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/19__0__.png"
slug = "ios_jenkins"
tags = ["iOS", "Jenkins", "Continuous Integration", "CI", "Docker", "fastlane", "gym", "xcodebuild", "xcrun", "fir"]
title = "手把手教你利用 Jenkins 持续集成 iOS 项目"

+++


#### 前言
众所周知，现在App的竞争已经到了用户体验为王，质量为上的白热化阶段。用户们都是很挑剔的。如果一个公司的推广团队好不容易砸了重金推广了一个APP，好不容易有了一些用户，由于一次线上的bug导致一批的用户在使用中纷纷出现闪退bug，轻则，很可能前期推广砸的钱都白费了，重则，口碑不好，未来也提升不起用户量来了。静下心来分析一下问题的原因，无外乎就是质量没有过关就上线了。除去主观的一些因素，很大部分的客观因素我觉得可以被我们防范的。根据大神们提出的一套开发规范建议，CI + FDD，就可以帮助我们极大程度的解决客观因素。本文接下来主要讨论 [Continuous Integration](http://martinfowler.com/articles/continuousIntegration.html) 持续集成（简称CI）

####目录
- 1.为什么我们需要持续集成
- 2.持续化集成工具——Jenkins
- 3.iOS自动化打包命令——xcodebuild + xcrun 和 fastlane - gym 命令
- 4.打包完成自动化上传 fir / 蒲公英 第三方平台
- 5.完整的持续集成流程
- 6.Jenkins + Docker

#### 一. 为什么我们需要持续集成
谈到为什么需要的问题，我们就需要从什么是来说起。那什么是持续集成呢。

> 持续集成是一种软件开发实践：许多团队频繁地集成他们的工作，每位成员通常进行日常集成，进而每天会有多种集成。每个集成会由自动的构建（包括测试）来尽可能快地检测错误。许多团队发现这种方法可以显著的减少集成问题并且可以使团队开发更加快捷。

CI是一种开发实践。实践应该包含3个基本模块，一个可以自动构建的过程，自动编译代码，可以自动分发，部署和测试。一个代码仓库，SVN或者Git。最后一个是一个持续集成的服务器。通过持续集成，可以让我们通过自动化等手段高频率地去获取产品反馈并响应反馈的过程。

那么持续集成能给我们带来些什么好处呢？这里推荐一篇[文章](http://apiumtech.com/blog/top-benefits-of-continuous-integration-2/)，文章中把[Continuous integration](http://apiumtech.com/blog/top-benefits-of-continuous-integration-2/) (CI) and [test-driven development](http://apiumtech.com/blog/20-benefits-of-test-driven-development/) (TDD)分成了12个步骤。然而带来的好处成倍增加，有24点好处。

![](https://img.halfrost.com/Blog/ArticleImage/18_2.png) 


我来说说用了CI以后带来的一些深有体会的优点。

##### 1. 缩减开发周期，快速迭代版本
每个版本开始都会估算好开发周期，但是总会因为各种事情而延期。这其中包括了一些客观因素。由于产品线增多，迭代速度越来越快，给测试带来的压力也越来越大。如果测试都在开发完全开发完成之后再来测试，那就会影响很长一段时间。这时候由于集成晚就会严重拖慢项目节奏。如果能尽早的持续集成，尽快进入上图的12步骤的迭代环中，就可以尽早的暴露出问题，提早解决，尽量在规定时间内完成任务。

##### 2. 自动化流水线操作带来的高效
其实打包对于开发人员来说是一件很耗时，而且没有很大技术含量的工作。如果开发人员一多，相互改的代码冲突的几率就越大，加上没有产线管理机制，代码仓库的代码质量很难保证。团队里面会花一些时间来解决冲突，解决完了冲突还需要自己手动打包。这个时候如果证书又不对，又要耽误好长时间。这些时间其实可以用持续集成来节约起来的。一天两天看着不多，但是按照年的单位来计算，可以节约很多时间！

##### 3. 随时可部署
有了持续集成以后，我们可以以天为单位来打包，这种高频率的集成带来的最大的优点就是可以随时部署上线。这样就不会导致快要上线，到处是漏洞，到处是bug，手忙脚乱弄完以后还不能部署，严重影响上线时间。

##### 4. 极大程度避免低级错误
我们可以犯错误，但是犯低级错误就很不应该。这里指的低级错误包括以下几点：编译错误，安装问题，接口问题，性能问题。
以天为单位的持续集成，可以很快发现编译问题，自动打包直接无法通过。打完包以后，测试扫码无法安装，这种问题也会立即被暴露出来。接口问题和性能问题就有自动化测试脚本来发现。这些低级问题由持续集成来暴露展现出来，提醒我们避免低级错误。




#### 二. 持续化集成工具——Jenkins

Jenkins 是一个开源项目，提供了一种易于使用的持续集成系统，使开发者从繁杂的集成中解脱出来，专注于更为重要的业务逻辑实现上。同时 Jenkins 能实施监控集成中存在的错误，提供详细的日志文件和提醒功能，还能用图表的形式形象地展示项目构建的趋势和稳定性。


根据官方定义，Jenkins有以下的用途：  
1. 构建项目
2. 跑测试用例检测bug
3. 静态代码检测
4. 部署

关于这4点，实际使用中还是比较方便的：
1.构建项目自动化打包可以省去开发人员好多时间，重要的是，Jenkins为我们维护了一套高质量可用的代码，而且保证了一个纯净的环境。我们经常会出现由于本地配置出错而导致打包失败的情况。现在Jenkins就是一个公平的评判者，它无法正确的编译出ipa，那就是有编译错误或者配置问题。开发人员没必要去争论本地是可以运行的，拉取了谁谁谁的代码以后就不能运行了。共同维护Jenkins的正常编译，因为Jenkins的编译环境比我们本地简单的多，它是最纯净无污染的编译环境。开发者就只用专注于编码。这是给开发者带来的便利。

2.这个可以用来自动化测试。在本地生成大批的测试用例。每天利用服务器不断的跑这些用例。每天每个接口都跑一遍。看上去没必要，但是实际上今天运行正常的系统，很可能由于今天的代码改动，明天就出现问题了。有了Jenkins可以以天为单位的进行回归测试，代码只要有改动，Jenkins就把所有的回归测试的用例全部都跑一遍。在项目工期紧张的情况下，很多情况测试都不是很重视回归测试，毕竟很可能测一遍之后是徒劳的“无用功”。然而由于回归测试不及时，就导致到最后发版的时候系统不可用了，这时候回头查找原因是比较耗时的，查看提交记录，看到上百条提交记录，排查起来也是头疼的事情。以天为单位的回归测试能立即发现问题。测试人员每天可以专注按单元测试，一周手动一次回归测试。这是给测试者带来的便利。

3.这个是静态代码分析，可以检测出很多代码的问题，比如潜在的内存泄露的问题。由于Jenkins所在环境的纯净，还是可以发现一些我们本地复杂环境无法发现的问题，进一步的提高代码质量。这是给质检带来的便利。

4.随时部署。Jenkins在打包完成之后可以设定之后的操作，这个时候往往就是提交app到跑测试用例的系统，或者部署到内测平台生成二维码。部署中不能安装等一些低级问题随之立即暴露。测试人员也只需要扫一下二维码即可安装，很方便。这也算是给测试带来的便利。

![](https://img.halfrost.com/Blog/ArticleImage/18_3.png) 



以下的例子以2016-07-24 22:35的Weekly Release 2.15的版本为例。


我们来开始安装Jenkins。从官网https://jenkins.io/ 上下载最新的pkg安装包。

![](https://img.halfrost.com/Blog/ArticleImage/18_4.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_5.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_6.png)   

![](https://img.halfrost.com/Blog/ArticleImage/18_7.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_8.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_9.png)   


也可以下载jenkins.war, 然后运行Java -jar jenkins.war，进行安装。


安装完成之后，Safari可能会自动打开，如果没有自动打开，打开浏览器，输入http://localhost:8080

![](https://img.halfrost.com/Blog/ArticleImage/18_10.png)  


这个时候可能会报一个错误。如果出现了这面的问题。出现这个问题的原因就是Java环境有问题，重新Java环境即可。

这个时候如果你重启电脑会发现Jenkins给你新增了一个用户，名字就叫Jenkins，不过这个时候你不知道密码。你可能会去试密码，肯定是是不对的，因为初始密码很复杂。这个时候正确做法是打开http://localhost:8080 会出现下图的重设初始密码的界面。

![](https://img.halfrost.com/Blog/ArticleImage/18_11.png)  


按照提示，找到/Users/Shared/Jenkins/Home/ 这个目录下，这个目录虽然是共享目录，但是有权限的，非Jenkins用户/secrets/目录是没有读写权限的。
          

![](https://img.halfrost.com/Blog/ArticleImage/18_12.png)   

![](https://img.halfrost.com/Blog/ArticleImage/18_13.png)  

打开initialAdminPassword文件，复制出密码，就可以填到网页上去重置密码了。如下图

![](https://img.halfrost.com/Blog/ArticleImage/18_14.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_15.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_16.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_17.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_18.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_19.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_20.png)  


一路安装过来，输入用户名，密码，邮件这些，就算安装完成了。

还是继续登录localhost:8080  ，选择“系统管理”——“管理插件”，我们要先安装一些辅助插件。

**安装GitLab插件**
因为我们用的是GitLab来管理源代码，Jenkins本身并没有自带GitLab插件，所以我们需要依次选择 **系统管理**->**管理插件**，在“**可选插件**”中选中“**GitLab Plugin**”和“**Gitlab Hook Plugin**”这两项，然后安装。

**安装Xcode插件**
同安装GitLab插件的步骤一样，我们依次选择**系统管理**->**管理插件**，在“**可选插件**”中选中“**Xcode integration**”安装。


安装完了这个，我们就可以配置一个构建项目了。

![](https://img.halfrost.com/Blog/ArticleImage/18_21.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_22.png)  


点击新建好的项目，进来配置一下**General**参数。 

![](https://img.halfrost.com/Blog/ArticleImage/18_23.png)  


这里可以设置包的保留天数还有天数。

接着设置**源码管理**。

由于现在我用到的是GitLab，先配置SSH Key，在Jenkins的证书管理中添加SSH。在Jenkins管理页面，选择“**Credentials**”，然后选择“**Global credentials (unrestricted)**”，点击“**Add Credentials**”，如下图所示，我们填写自己的SSH信息，然后点击“**Save**”，这样就把SSH添加到Jenkins的全局域中去了。

![](https://img.halfrost.com/Blog/ArticleImage/18_24.png)  



如果正常的配置正确的话，是不会出现下图中的那段红色的警告。如果有下图的提示，就说明Jenkins还没有连通GitLab或者SVN，那就请再检查SSH Key是否配置正确。

![](https://img.halfrost.com/Blog/ArticleImage/18_25.png)  



**构建触发器设置**这里是设置自动化测试的地方。这里涉及的内容很多，暂时我也没有深入研究，这里暂时先不设置。有自动化测试需求的可以好好研究研究这里的设置。

不过这里有两个配置还是需要是配置的

**Poll SCM**  (poll source code management)  轮询源码管理  
需要设置源码的路径才能起到轮询的效果。一般设置为类似结果： 0/5 * * * * 每5分钟轮询一次  
**Build periodically**  (定时build)  
一般设置为类似： 00 20 * * *   每天 20点执行定时build 。当然两者的设置都是一样可以通用的。

格式是这样的

分钟(0-59) 小时(0-23) 日期(1-31) 月(1-12) 周几(0-7,0和7都是周日) [更加详细的设置看这里](http://www.scmgalaxy.com/scm/setting-up-the-cron-jobs-in-jenkins-using-build-periodically-scheduling-the-jenins-job.html)


![](https://img.halfrost.com/Blog/ArticleImage/18_26.png)  



**构建环境设置**  
iOS打包需要签名文件和证书，所以这部分我们勾选“**Keychains and Code Signing Identities**”和“**Mobile Provisioning Profiles**”。
这里我们又需要用到Jenkins的插件，在系统管理页面，选择“**Keychains and Provisioning Profiles Management**”。

![](https://img.halfrost.com/Blog/ArticleImage/18_27.png)  



进入**Keychains and Provisioning Profiles Management**页面，点击“**浏览**”按钮，分别上传自己的keychain和证书。上传成功后，我们再为keychain指明签名文件的名称。点击“**Add Code Signing Identity**”，最后添加成功后如下图所示：

![](https://img.halfrost.com/Blog/ArticleImage/18_28.png)  

注意：我第一次导入证书和Provisioning Profiles文件，就遇到了一点小“坑”，我当时以为是需要证书，但是这里需要的Keychain，并不是cer证书文件。这个Keychain其实在/Users/管理员用户名/Library/keychains/login.keychain,当把这个Keychain设置好了之后，Jenkins会把这个Keychain拷贝到/Users/Shared/Jenkins/Library/keychains这里，(Library是隐藏文件)。Provisioning Profiles文件也直接拷贝到/Users/Shared/Jenkins/Library/MobileDevice文件目录下。

这样Adhoc证书和签名文件就在Jenkins中配置好了，接下来我们只需要在item设置中指定相关文件即可。
回到我们新建的item，找到**构建环境**，按下图选好自己的相关证书和签名文件。

![](https://img.halfrost.com/Blog/ArticleImage/18_29.jpg)  




接下来在进行**构建**的设置  

![](https://img.halfrost.com/Blog/ArticleImage/18_30.png)  


我们这里选择执行一段打包脚本。脚本在下一章节详细的讲解。

**构建后操作**

![](https://img.halfrost.com/Blog/ArticleImage/18_31.png)  


这里我们选择**Execute a set of scripts**，这里也是一个脚本，这个脚本用来上传自动打包好的ipa文件。脚本在第四章节有详细的讲解。

至此，我们的Jenkins设置就全部完成了。点击**构建**，就会开始构建项目了。

构建一次，各个颜色代表的意义如下：

![](https://img.halfrost.com/Blog/ArticleImage/18_32.png)  


天气的晴雨表代表了项目的质量，这也是Jenkins的一个特色。  
  
![](https://img.halfrost.com/Blog/ArticleImage/18_33.jpg)  



如果构建失败了，可以去查看**Console Output**可以查看log日志。

![](https://img.halfrost.com/Blog/ArticleImage/18_34.png)  


#### 三. iOS自动化打包命令——xcodebuild + xcrun 和 fastlane - gym 命令

在日常开发中，打包是最后上线不可缺少的环节，如果需要把工程打包成 ipa 文件，通常的做法就是在 Xcode 里点击 「Product -> Archive」，当整个工程 archive 后，然后在自动弹出的 「Organizer」 中进行选择，根据需要导出 ad hoc，enterprise 类型的 ipa 包。虽然Xcode已经可以很完美的做到打包的事情，但是还是需要我们手动点击5，6下。加上我们现在需要持续集成，用打包命令自动化执行就顺其自然的需要了。

##### 1. xcodebuild + xcrun命令

Xcode为我们开发者提供了一套构建打包的命令，就是xcodebuild
和xcrun命令。xcodebuild把我们指定的项目打包成.app文件，xcrun将指定的.app文件转换为对应的.ipa文件。

具体的文档如下， [xcodebuild官方文档](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcodebuild.1.html)、[xcrun官方文档](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcrun.1.html) 

```vim  
NAME
xcodebuild – build Xcode projects and workspaces

SYNOPSIS
1. xcodebuild [-project name.xcodeproj] [[-target targetname] … | -alltargets] [-configuration configurationname] [-sdk [sdkfullpath | sdkname]] [action …] [buildsetting=value …] [-userdefault=value …]

2. xcodebuild [-project name.xcodeproj] -scheme schemename [[-destination destinationspecifier] …] [-destination-timeout value] [-configuration configurationname] [-sdk [sdkfullpath | sdkname]] [action …] [buildsetting=value …] [-userdefault=value …]

3. xcodebuild -workspace name.xcworkspace -scheme schemename [[-destination destinationspecifier] …] [-destination-timeout value] [-configuration configurationname] [-sdk [sdkfullpath | sdkname]] [action …] [buildsetting=value …] [-userdefault=value …]

4. xcodebuild -version [-sdk [sdkfullpath | sdkname]] [infoitem]

5. xcodebuild -showsdks

6. xcodebuild -showBuildSettings [-project name.xcodeproj | [-workspace name.xcworkspace -scheme schemename]]

7. xcodebuild -list [-project name.xcodeproj | -workspace name.xcworkspace]

8. xcodebuild -exportArchive -archivePath xcarchivepath -exportPath destinationpath -exportOptionsPlist path

9. xcodebuild -exportLocalizations -project name.xcodeproj -localizationPath path [[-exportLanguage language] …]

10. xcodebuild -importLocalizations -project name.xcodeproj -localizationPath path
```

上面10个命令最主要的还是前3个。

接下来来说明一下参数：  
-project -workspace：这两个对应的就是项目的名字。如果有多个工程，这里又没有指定，则默认为第一个工程。  
-target：打包对应的targets，如果没有指定这默认第一个。  
-configuration：如果没有修改这个配置，默认就是Debug和Release这两个版本，没有指定默认为Release版本。  
-buildsetting=value ...：使用此命令去修改工程的配置。  
-scheme：指定打包的scheme。

上面这些是最最基本的命令。

上面10个命令的第一个和第二个里面的参数，其中 -target
 和 -configuration 参数可以使用 xcodebuild -list
获得，-sdk 参数可由 xcodebuild -showsdks
 获得，[buildsetting=value ...] 用来覆盖工程中已有的配置。可覆盖的参数参考官方文档 [Xcode Build Setting Reference](https://developer.apple.com/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/)。
```vim  
build
Build the target in the build root (SYMROOT). This is the default action, and is used if no action is given.

analyze
Build and analyze a target or scheme from the build root (SYMROOT). This requires specifying a scheme.

archive
Archive a scheme from the build root (SYMROOT). This requires specifying a scheme.

test
Test a scheme from the build root (SYMROOT). This requires specifying a scheme and optionally a destination.

installsrc
Copy the source of the project to the source root (SRCROOT).

install
Build the target and install it into the target’s installation directory in the distribution root (DSTROOT).

clean
Remove build products and intermediate files from the build root (SYMROOT).
```

上面第3个命令就是专门用来打带有Cocopods的项目，因为这个时候项目工程文件不再是xcodeproj了，而是变成了xcworkspace了。


再来说说xcrun命令。
```vim  
Usage:
PackageApplication [-s signature] application [-o output_directory] [-verbose] [-plugin plugin] || -man || -help

Options:

[-s signature]: certificate name to resign application before packaging
[-o output_directory]: specify output filename
[-plugin plugin]: specify an optional plugin
-help: brief help message
-man: full documentation
-v[erbose]: provide details during operation
``` 
参数不多，使用方法也很简单，xcrun -sdk iphoneos -v PackageApplication  + 上述一些参数。


参数都了解之后，我们就来看看该如何用了。下面这个是使用了xcodebuild + xcrun命令写的自动化打包脚本
```vim  
# 工程名
APP_NAME="YourProjectName"
# 证书
CODE_SIGN_DISTRIBUTION="iPhone Distribution: Shanghai ******* Co., Ltd."
# info.plist路径
project_infoplist_path="./${APP_NAME}/Info.plist"

#取版本号
bundleShortVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" "${project_infoplist_path}")

#取build值
bundleVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleVersion" "${project_infoplist_path}")

DATE="$(date +%Y%m%d)"
IPANAME="${APP_NAME}_V${bundleShortVersion}_${DATE}.ipa"

#要上传的ipa文件路径
IPA_PATH="$HOME/${IPANAME}"
echo ${IPA_PATH}
echo "${IPA_PATH}">> text.txt

//下面2行是没有Cocopods的用法
echo "=================clean================="
xcodebuild -target "${APP_NAME}"  -configuration 'Release' clean

echo "+++++++++++++++++build+++++++++++++++++"
xcodebuild -target "${APP_NAME}" -sdk iphoneos -configuration 'Release' CODE_SIGN_IDENTITY="${CODE_SIGN_DISTRIBUTION}" SYMROOT='$(PWD)'

//下面2行是集成有Cocopods的用法
echo "=================clean================="
xcodebuild -workspace "${APP_NAME}.xcworkspace" -scheme "${APP_NAME}"  -configuration 'Release' clean

echo "+++++++++++++++++build+++++++++++++++++"
xcodebuild -workspace "${APP_NAME}.xcworkspace" -scheme "${APP_NAME}" -sdk iphoneos -configuration 'Release' CODE_SIGN_IDENTITY="${CODE_SIGN_DISTRIBUTION}" SYMROOT='$(PWD)'

xcrun -sdk iphoneos PackageApplication "./Release-iphoneos/${APP_NAME}.app" -o ~/"${IPANAME}"
```


##### 2. gym 命令
说到gym，就要先说一下fastlane。
fastlane是一套自动化打包的工具集，用 Ruby 写的，用于 iOS 和 Android 的自动化打包和发布等工作。gym是其中的打包命令。

fastlane 的官网看[这里](https://fastlane.tools/), fastlane 的 github 看[这里](https://github.com/fastlane/fastlane)

要想使用gym，先要安装fastlane。
```vim  
sudo gem install fastlane --verbose
```

fastlane包含了我们日常编码之后要上线时候进行操作的所有命令。
```vim   
deliver：上传屏幕截图、二进制程序数据和应用程序到AppStore
snapshot：自动截取你的程序在每个设备上的图片
frameit：应用截屏外添加设备框架
pem：可以自动化地生成和更新应用推送通知描述文件
sigh：生成下载开发商店的配置文件
produce：利用命令行在iTunes Connect创建一个新的iOS app
cert：自动创建iOS证书
pilot：最好的在终端管理测试和建立的文件
boarding：很容易的方式邀请beta测试
gym：建立新的发布的版本，打包
match：使用git同步你成员间的开发者证书和文件配置
scan：在iOS和Mac app上执行测试用例
```
整个发布过程可以用fastlane描述成下面这样

```vim  
lane :appstore do
  increment_build_number
  cocoapods
  xctool
  snapshot
  sigh
  deliver
  frameit
  sh "./customScript.sh"

  slack
end

```

PS：这里可能大家还会听过一个命令叫 [xctool](https://github.com/facebook/xctool)
xctool是官方xcodebuild命令的一个增强实现，输出的内容比xcodebuild直观可读得多。通过brew即可安装。  
```vim  
brew install xctool
```

使用gym自动化打包，[脚本](https://github.com/xilin/ios-build-script/blob/master/build_using_gym.sh)如下

```vim  
#计时

SECONDS=0

#假设脚本放置在与项目相同的路径下

project_path=$(pwd)

#取当前时间字符串添加到文件结尾

now=$(date +"%Y_%m_%d_%H_%M_%S")

#指定项目的scheme名称

scheme="DemoScheme"

#指定要打包的配置名

configuration="Adhoc"

#指定打包所使用的输出方式，目前支持app-store, package, ad-hoc, enterprise, development, 和developer-id，即xcodebuild的method参数

export_method='ad-hoc'

#指定项目地址

workspace_path="$project_path/Demo.xcworkspace"

#指定输出路径

output_path="/Users/your_username/Documents/"

#指定输出归档文件地址

archive_path="$output_path/Demo_${now}.xcarchive"

#指定输出ipa地址

ipa_path="$output_path/Demo_${now}.ipa"

#指定输出ipa名称

ipa_name="Demo_${now}.ipa"

#获取执行命令时的commit message

commit_msg="$1"

#输出设定的变量值

echo "===workspace path: ${workspace_path}==="

echo "===archive path: ${archive_path}==="

echo "===ipa path: ${ipa_path}==="

echo "===export method: ${export_method}==="

echo "===commit msg: $1==="

#先清空前一次build

gym --workspace ${workspace_path} --scheme ${scheme} --clean --configuration ${configuration} --archive_path ${archive_path} --export_method ${export_method} --output_directory ${output_path} --output_name ${ipa_name}

#输出总用时

echo "===Finished. Total time: ${SECONDS}s==="
```




#### 四. 打包完成自动化上传 fir / 蒲公英 第三方平台

要上传到 fir / 蒲公英 第三方平台，都需要注册一个账号，获得token，之后才能进行脚本化操作。

##### 1. 自动化上传fir
安装fir-clifir的命令行工具  
需要先装好ruby再执行
```vim  
gem install fir-cli
```

```vim  
#上传到fir
fir publish ${ipa_path} -T fir_token -c "${commit_msg}"
```

##### 2.自动化上传蒲公英
```vim  
#蒲公英上的User Key
uKey="7381f97070*****c01fae439fb8b24e"
#蒲公英上的API Key
apiKey="0b27b5c145*****718508f2ad0409ef4"
#要上传的ipa文件路径
IPA_PATH=$(cat text.txt)

rm -rf text.txt

#执行上传至蒲公英的命令
echo "++++++++++++++upload+++++++++++++"
curl -F "file=@${IPA_PATH}" -F "uKey=${uKey}" -F "_api_key=${apiKey}" http://www.pgyer.com/apiv1/app/upload
```

#### 五. 完整的持续集成流程

经过上面的持续化集成，现在我们就拥有了如下完整持续集成的流程

![](https://img.halfrost.com/Blog/ArticleImage/18_35.png)  



#### 六. Jenkins + Docker

关于Jenkins的部署，其实是分以下两种：
单节点（Master）部署
这种部署适用于大多数项目，其构建任务较轻，数量较少，单个节点就足以满足日常开发所需。
多节点(Master-Slave)部署
通常规模较大，代码提交频繁（意味着构建频繁），自动化测试压力较大的项目都会采取这种部署结构。在这种部署结构下，Master通常只充当管理者的角色，负责任务的调度，slave节点的管理，任务状态的收集等工作，而具体的构建任务则会分配给slave节点。一个Master节点理论上可以管理的slave节点数是没有上限的，但通常随着数量的增加，其性能以及稳定性就会有不同程度的下降，具体的影响则因Master硬件性能的高低而不同。

但是多节点部署又会有一些缺陷，当测试用例变得海量以后，会造成一些问题，于是有人设计出了下面这种部署结构，Jenkins + Docker

![](https://img.halfrost.com/Blog/ArticleImage/18_36.png)  


由于笔者现在的项目还处于单节点（Master）部署，关于多节点(Master-Slave)部署也没有实践经验，改进版本的Docker更是没有接触过，但是如果有这种海量测试用例，高压力的大量复杂的回归测试的需求的，那推荐大家看这篇[文章](http://www.zjbonline.com/2016/03/05/Jenkins-Docker%E6%90%AD%E5%BB%BA%E6%8C%81%E7%BB%AD%E9%9B%86%E6%88%90%E6%B5%8B%E8%AF%95%E7%8E%AF%E5%A2%83/)。


#### 最后

以上就是我关于Jenkins持续集成的一次实践经验。分享给大家，如果里面有什么错误，欢迎大家多多指教。

