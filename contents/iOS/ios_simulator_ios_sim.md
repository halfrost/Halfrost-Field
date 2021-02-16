# 给 iOS 模拟器“安装” app 文件

![](https://img.halfrost.com//Blog/ArticleTitleImage/3/d7/6f263a9193cd5db1c6ff3a1da43fc.jpg)


#### 前言 
刚刚接触iOS的时候，我就一直很好奇，模拟器上面能不能直接安装app呢？如果可以，我们就直接在模拟器上面聊QQ和微信了。直到昨天和朋友们聊到了这个话题，没有想到还真的可以给模拟器“安装”app！

#### 一.应用场景 

先来谈谈是什么情况下，会有在模拟器上安装app的需求。

在一个大公司里，对源码的管理有严格的制度，非开发人员是没有权限接触到源码的。对苹果的开发证书管理也非常严格，甚至连开发人员也没有发布证书，证书只在持续集成环境或者Appstore产线里面，或者只在最后打包上架的人手上。

那么现在就有这样的需求，开发人员搭建好UI以后，要把开发完成的Alapha版给到UI设计师那边去评审，看看是否完全达到要求，达不到要求就需要打回来重做。

一般做法就是直接拿手机去安装一遍了。直接真机看效果。不过要是设计师和开发不在同一个地方的公司，一个在北京一个在上海，这种就没法安装了。源码又无法导出给设计师，让他运行一下Xcode跑一下模拟器。这个时候就比较麻烦了。(一般也没人遇到这么蛋疼的事情吧)


那么现在就有给模拟器安装app的需求了，那开发人员如何能把开发版的app给打包出来给其他模拟器安装呢？


#### 二.解决办法

解决思路，想要别人的模拟器运行起我们开发的app，最简单的办法就是把我们DerivedData的数据直接拷贝到别人模拟器上面，就可以了。当然还要考虑到设计师也许并不会一些命令行命令，我们的操作越傻瓜越好。

##### 1.拷贝本地的DerivedData里面的debug包

Mac的拷贝命令有cp和ditto，建议用ditto进行拷贝工作。

```vim

Usage: ditto [ <options> ] src [ ... src ] dst

    <options> are any of:
    -h                         print full usage
    -v                         print a line of status for each source copied
    -V                         print a line of status for every file copied
    -X                         do not descend into directories with a different device ID

    -c                         create an archive at dst (by default CPIO format)
    -x                         src(s) are archives
    -z                         gzip compress CPIO archive
    -j                         bzip2 compress CPIO archive
    -k                         archives are PKZip
    --keepParent               parent directory name src is embedded in dst_archive
    --arch archVal             fat files will be thinned to archVal
                               multiple -arch options can be specified
                               archVal should be one of "ppc", "i386", etc
    --bom bomFile              only objects present in bomFile are copied
    --norsrc                   don't preserve resource data
    --noextattr                don't preserve extended attributes
    --noqtn                    don't preserve quarantine information
    --noacl                    don't preserve ACLs
    --sequesterRsrc            copy resources via polite directory (PKZip only)
    --nocache                  don't use filesystem cache for reads/writes
    --hfsCompression           compress files at destination if appropriate
    --nopreserveHFSCompression don't preserve HFS+ compression when copying files
    --zlibCompressionLevel num use compression level 'num' when creating a PKZip archive
    --password                 request password for reading from encrypted PKZip archive
```

Ditto比cp命令更好的地方在于：
1. 它在复制过程中不仅能保留源文件或者文件夹的属性与权限，还能保留源文件的资源分支结构和文件夹的源结构。
2. 此命令能确保文件或者文件夹被如实复制。
3. 如果目标文件或者文件夹不存在，ditto将直接复制过去或创建新的文件和文件夹，相反，对于已经存在的文件，命令将与目标文件（夹）合并。
4. ditto还能提供完整符号链接。

那么我们就拷贝出本地的debug包

```vim
ditto -ck --sequesterRsrc --keepParent `ls -1 -d -t ~/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphonesimulator/*.app | head -n 1` /Users/YDZ/Desktop/app.zip
```

有几点需要说明的：

1. 上面命令最后一个路径(/Users/YDZ/Desktop/app.zip)，这个是自定义的，我这里举的例子是直接放在桌面。除了这里改一下路径，前面的都不需要改，包括 \* 也都不用改。

2. 再来说一下命令里面的 \* 的问题。当我们打开自己本地的~/Library/Developer/Xcode/DerivedData/ ，这个路径下，会发现里面装的都是在我们本地模拟器上运行过的app程序。前面是app的Bundle Identifier，横线后面是一堆字符串。上面的ditto里面带 \* 的那个路径是为了动态匹配一个地址的，\* 在这里也是一个通配符。后面的head说明了匹配的规则。head其实是找出最近一次我们运行模拟器的app的路径。

为了保证我们打包是正确的，建议先运行一下我们要打包的app，一般我们Scheme里面的Run都是debug product(如果这里有更改，那就改成对应debug的Scheme)，确保是我们要给设计师审核的app，之后再运行这个ditto命令。

##### 2.把debug包拷贝到另一个模拟器中

我们运行完上面的ditto命令会产生一个zip文件，解压出来，会得到一个app文件，这个就是debug包了。debug包就是我们要给设计师的app包了。

如何能让设计师傻瓜式的安装这个app呢？

这里介绍一个命令行工具，[ios-sim](https://github.com/appcelerator/ios-sim)命令行工具。

ios-sim 是一个可以在命令控制iOS模拟器的工具。利用这个命令，我们可以启动一个模拟器，安装app，启动app，查询iOS SDK。它可以使我们像自动化测试一样不用打开Xcode。

不过 ios-sim 只支持Xcode 6 以后的版本。

安装ios-sim
```vim 
    $ npm install ios-sim -g
```

说明文档：

```vim 

    Usage: ios-sim <command> <options> [--args ...]
        
    Commands:
      showsdks                        List the available iOS SDK versions
      showdevicetypes                 List the available device types
      launch <application path>       Launch the application at the specified path on the iOS Simulator
      start                           Launch iOS Simulator without an app
      install <application path>      Install the application at the specified path on the iOS Simulator without launching the app

    Options:
      --version                       Print the version of ios-sim
      --help                          Show this help text
      --exit                          Exit after startup
      --log <log file path>           The path where log of the app running in the Simulator will be redirected to
      --devicetypeid <device type>    The id of the device type that should be simulated (Xcode6+). Use 'showdevicetypes' to list devices.
                                      e.g "com.apple.CoreSimulator.SimDeviceType.Resizable-iPhone6, 8.0"
                                  
    Removed in version 4.x:
      --stdout <stdout file path>     The path where stdout of the simulator will be redirected to (defaults to stdout of ios-sim)
      --stderr <stderr file path>     The path where stderr of the simulator will be redirected to (defaults to stderr of ios-sim)
      --sdk <sdkversion>              The iOS SDK version to run the application on (defaults to the latest)
      --family <device family>        The device type that should be simulated (defaults to `iphone')
      --retina                        Start a retina device
      --tall                          In combination with --retina flag, start the tall version of the retina device (e.g. iPhone 5 (4-inch))
      --64bit                         In combination with --retina flag and the --tall flag, start the 64bit version of the tall retina device (e.g. iPhone 5S (4-inch 64bit))
                                    
    Unimplemented in this version:
      --verbose                       Set the output level to verbose
      --timeout <seconds>             The timeout time to wait for a response from the Simulator. Default value: 30 seconds
      --args <...>                    All following arguments will be passed on to the application
      --env <environment file path>   A plist file containing environment key-value pairs that should be set
      --setenv NAME=VALUE             Set an environment variable
                                  
```

用法不难

```vim
ios-sim launch /Users/YDZ/Desktop/app.app --devicetypeid iPhone-6s 
```

其中，/Users/YDZ/Desktop/app.app这个是设计师收到app之后的路径。--devicetypeid参数后面是给定一个模拟器的版本。

只需要把上面的命令发给设计师，无脑粘贴到命令行，装好app的模拟器就会自动启动，打开app了。


#### 三.额外的尝试

好奇的同学肯定不会满足只给模拟器安装debug包吧，既然可以不用代码就可以给模拟器安装app，那我们能安装release包么？我好奇的尝试了一下。

先从Appstore上面下载最新的微信，把ipa后缀改成zip，解压，把Payload文件夹里面的“WeChat”取出来，然后运行ios-sim命令。

结果微信确实是安装到了模拟器了。不过一点击app，看见了月亮界面就退出了。控制台打印了一堆信息。


```vim
An error was encountered processing the command (domain=FBSOpenApplicationErrorDomain, code=1):
The operation couldn’t be completed. (FBSOpenApplicationErrorDomain error 1.)
Aug 18 16:29:17 YDZdeMacBook-Pro nsurlsessiond[19213]: Task 1 for client <CFString 0x7fa810c047d0 [0x1073daa40]>{contents = "com.apple.mobileassetd"} completed with error - code: -999
Aug 18 16:29:17 YDZdeMacBook-Pro com.apple.CoreSimulator.SimDevice.D6BD3967-9BC4-4A8D-9AD0-23176B22B12A.launchd_sim[19096] (UIKitApplication:com.tencent.xin[0xdf6d][19774]): Program specified by service does not contain one of the requested architectures:
Aug 18 16:29:17 YDZdeMacBook-Pro SpringBoard[19181]: Unable to get pid for 'UIKitApplication:com.tencent.xin[0xdf6d]': No such process (err 3)
Aug 18 16:29:17 YDZdeMacBook-Pro SpringBoard[19181]: Bootstrapping failed for <FBApplicationProcess: 0x7fa83cd91840; com.tencent.xin; pid: -1>
Aug 18 16:29:17 YDZdeMacBook-Pro SpringBoard[19181]: Unable to delete job with label UIKitApplication:com.tencent.xin[0xdf6d]. Error: Operation now in progress
Aug 18 16:29:17 YDZdeMacBook-Pro SpringBoard[19181]: Application 'UIKitApplication:com.tencent.xin[0xdf6d]' exited for an unknown reason.
Aug 18 16:29:17 YDZdeMacBook-Pro com.apple.CoreSimulator.SimDevice.D6BD3967-9BC4-4A8D-9AD0-23176B22B12A.launchd_sim[19096] (UIKitApplication:com.tencent.xin[0xdf6d][19774]): Trampoline was terminated before jumping to service: Killed: 9
Aug 18 16:29:18 YDZdeMacBook-Pro fileproviderd[19169]: (Note ) FileProvider: /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/PrivateFrameworks/FileProvider.framework/Support/fileproviderd starting.
Aug 18 16:29:20 YDZdeMacBook-Pro pkd[19238]: assigning plug-in com.apple.ServerDocuments.ServerFileProvider(1.0) to plugin sandbox
Aug 18 16:29:20 YDZdeMacBook-Pro pkd[19238]: enabling pid=19169 for plug-in com.apple.ServerDocuments.ServerFileProvider(1.0) D12B6280-6DF1-434C-9BAA-BD9B0D0FB756 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/Applications/ServerDocuments.app/PlugIns/ServerFileProvider.appex
Aug 18 16:29:22 YDZdeMacBook-Pro SpringBoard[19181]: Weekly asset update check did fire (force=NO)
Aug 18 16:29:22 YDZdeMacBook-Pro SpringBoard[19181]: Beginning check for asset updates (force: 0
Aug 18 16:29:22 YDZdeMacBook-Pro SpringBoard[19181]: Did not complete check for asset updates (force: 0, isVoiceOverRunning: 0
Aug 18 16:29:23 YDZdeMacBook-Pro mstreamd[19171]: (Note ) mstreamd: mstreamd starting up.
Aug 18 16:29:23 YDZdeMacBook-Pro DTServiceHub[19191]: DTServiceHub(19191) [error]: 'mach_msg_send' failed: (ipc/send) invalid destination port (268435459)
Aug 18 16:29:25 YDZdeMacBook-Pro itunesstored[19744]: iTunes Store environment is: MR22
Aug 18 16:29:25 YDZdeMacBook-Pro itunesstored[19744]: Normal message received by listener connection. Ignoring.
Aug 18 16:29:25 --- last message repeated 1 time ---
Aug 18 16:29:25 YDZdeMacBook-Pro mstreamd[19171]: (Note ) PS: The subscription plugin class does not support push notification refreshing.
Aug 18 16:29:25 YDZdeMacBook-Pro itunesstored[19744]: libMobileGestalt MGIOKitSupport.c:387: value for udid-version property of IODeviceTree:/product is invalid ((null))
Aug 18 16:29:25 YDZdeMacBook-Pro itunesstored[19744]: Normal message received by listener connection. Ignoring.
Aug 18 16:29:25 YDZdeMacBook-Pro itunesstored[19744]: libMobileGestalt MGBasebandSupport.c:60: _CTServerConnectionCopyMobileEquipmentInfo: CommCenter error: 1:45 (Operation not supported)
Aug 18 16:29:25 YDZdeMacBook-Pro itunesstored[19744]: libMobileGestalt MGBasebandSupport.c:189: No CT mobile equipment info dictionary while fetching kCTMobileEquipmentInfoIMEI
Aug 18 16:29:26 YDZdeMacBook-Pro mstreamd[19171]: (Note ) PS: Media stream daemon starting...
Aug 18 16:29:27 YDZdeMacBook-Pro itunesstored[19744]: UpdateAssetsOperation: Error downloading manifest from URL https://apps.itunes.com/files/ios-music-app/: Error Domain=SSErrorDomain Code=109 "无法连接到 iTunes Store" UserInfo={NSLocalizedDescription=无法连接到 iTunes Store, SSErrorHTTPStatusCodeKey=503}
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: (Error) MC: MobileContainerManager gave us a path we weren't expecting; file a radar against them
       	Expected: /private/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles
       	Actual: /Users/YDZ/Library/Developer/CoreSimulator/Devices/D6BD3967-9BC4-4A8D-9AD0-23176B22B12A/data/Containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles
       	Overriding MCM with the one true path
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: PairedSync, Debugging at level 0 for console and level 0 for log files
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: Error: Could not create service from plist at path: file:///Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/PairedSyncServices/com.apple.pairedsync.healthd.plist. Returning nil PSYSyncCoordinator for service name com.apple.pairedsync.healthd.  Please check that your plist exists and is in the correct format.
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: Error: failed to load bundle "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Health/Plugins/CompanionHealth.bundle": Error Domain=NSCocoaErrorDomain Code=4 "未能载入软件包“CompanionHealth.bundle”，因为未能找到其可执行文件的位置。" UserInfo={NSLocalizedFailureReason=未能找到该软件包可执行文件的位置。, NSLocalizedRecoverySuggestion=请尝试重新安装软件包。, NSBundlePath=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Health/Plugins/CompanionHealth.bundle, NSLocalizedDescription=未能载入软件包“CompanionHealth.bundle”，因为未能找到其可执行文件的位置。}
Aug 18 16:29:33 YDZdeMacBook-Pro wcd[19180]: libMobileGestalt MobileGestalt.c:2584: Failed to get battery level
Aug 18 16:29:34 --- last message repeated 1 time ---
Aug 18 16:29:34 YDZdeMacBook-Pro assertiond[19185]: assertion failed: 15G31 13E230: assertiond + 15801 [3C808658-78EC-3950-A264-79A64E0E463B]: 0x1
Aug 18 16:29:34 --- last message repeated 1 time ---
Aug 18 16:29:34 YDZdeMacBook-Pro SpringBoard[19181]: [MPUSystemMediaControls] Updating supported commands for now playing application.
Aug 18 16:29:34 YDZdeMacBook-Pro assertiond[19185]: assertion failed: 15G31 13E230: assertiond + 15801 [3C808658-78EC-3950-A264-79A64E0E463B]: 0x1
Aug 18 16:29:34 --- last message repeated 1 time ---
Aug 18 16:29:34 YDZdeMacBook-Pro fileproviderd[19169]: plugin com.apple.ServerDocuments.ServerFileProvider invalidated
Aug 18 16:29:34 YDZdeMacBook-Pro ServerFileProvider[19775]: host connection <NSXPCConnection: 0x7f880160bc30> connection from pid 19169 invalidated
Aug 18 16:30:08 YDZdeMacBook-Pro mstreamd[19171]: (Note ) PS: Media stream daemon stopping.
Aug 18 16:30:09 YDZdeMacBook-Pro mstreamd[19171]: (Note ) AS: <MSIOSAlbumSharingDaemon: 0x7fd139c0a020>: Shared Streams daemon has shut down.
Aug 18 16:30:09 YDZdeMacBook-Pro mstreamd[19171]: (Warn ) mstreamd: mstreamd shutting down.
Aug 18 16:30:09 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans
Aug 18 16:30:09 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: KEYMAP: Failed to determine iOS keyboard layout for language zh-Hans.
Aug 18 16:30:09 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans
Aug 18 16:30:09 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: KEYMAP: Failed to determine iOS keyboard layout for language zh-Hans.
Aug 18 16:30:10 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans
Aug 18 16:30:10 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: KEYMAP: Failed to determine iOS keyboard layout for language zh-Hans.
Aug 18 16:30:10 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans
Aug 18 16:30:10 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: KEYMAP: Failed to determine iOS keyboard layout for language zh-Hans.
Aug 18 16:30:16 YDZdeMacBook-Pro sharingd[19183]: 16:30:16.190 : Failed to send SDURLSessionProxy startup message, error Error Domain=com.apple.identityservices.error Code=23 "Timed out" UserInfo={NSLocalizedDescription=Timed out, NSUnderlyingError=0x7ff088e005a0 {Error Domain=com.apple.ids.idssenderrordomain Code=12 "(null)"}}
Aug 18 16:30:38 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans
Aug 18 16:30:38 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: KEYMAP: Failed to determine iOS keyboard layout for language zh-Hans.
Aug 18 16:30:38 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans
Aug 18 16:30:38 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: KEYMAP: Failed to determine iOS keyboard layout for language zh-Hans.
Aug 18 16:30:41 YDZdeMacBook-Pro CoreSimulatorBridge[19190]: Switching to keyboard: zh-Hans

```


仔细看了一下log，根本原因还是因为

```vim
com.apple.CoreSimulator.SimDevice.D6BD3967-9BC4-4A8D-9AD0-23176B22B12A.launchd_sim[19096] (UIKitApplication:com.tencent.xin[0xdf6d][19774]): Program specified by service does not contain one of the requested architectures:

Unable to get pid for 'UIKitApplication:com.tencent.xin[0xdf6d]': No such process (err 3)
```

因为release包里面architectures打包的时候不包含模拟器的architectures。debug包里面就有。所以release就没法安装到模拟器了。

由于笔者逆向方面的东西没有研究，所以也无法继续下去了。不知道逆向技术能不能把release包破壳之后能不能转成debug包呢？如果能转成debug包，通过ios-sim命令应该也是可以直接安装到模拟器的。


至此，ios-sim给模拟器安装app就尝试到此了。因为只能给模拟器安装debug包，所以在题目上额外给安装加了双引号，并不是所有的app文件都可以安装到模拟器。


请大家多多指教。

