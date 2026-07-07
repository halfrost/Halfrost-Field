# "Installing" an app File on the iOS Simulator

![](https://img.halfrost.com//Blog/ArticleTitleImage/3/d7/6f263a9193cd5db1c6ff3a1da43fc.jpg)


#### Preface 
When I first started working with iOS, I was always curious: can you install an app directly on the simulator? If so, we could just use QQ and WeChat on the simulator. It wasn't until I discussed this topic with some friends yesterday that I realized you actually can "install" an app on the simulator!

#### 1. Use Cases 

Let's first talk about the situations where you might need to install an app on the simulator.

In a large company, source code management is governed by strict policies, and non-developers do not have access to the source code. Apple's development certificates are also managed very strictly. In some cases, even developers do not have distribution certificates; the certificates exist only in the continuous integration environment, on the App Store production line, or in the hands of the person responsible for the final packaging and submission.

Now suppose there is such a requirement: after developers finish building the UI, they need to deliver the completed Alpha version to the UI designers for review, so the designers can check whether it fully meets the requirements. If it does not, it has to be sent back for rework.

The usual approach is to install it directly on a physical device and check the result there. But if the designer and developer are not in the same location—for example, one is in Beijing and the other is in Shanghai—then this kind of installation is not possible. The source code also cannot be exported to the designer so that they can run it in Xcode and launch it on the simulator. At that point, things become rather troublesome. (Though most people probably do not run into such a painful scenario.)


So now there is a need to install an app on the simulator. How can developers package a development build of the app so that it can be installed on someone else's simulator?


#### 2. Solution

The idea is simple: if we want someone else's simulator to run the app we developed, the easiest way is to copy the data from our DerivedData directly onto their simulator. Of course, we also need to consider that designers may not know how to use command-line commands, so the process should be as foolproof as possible.

##### 1. Copy the debug package from local DerivedData

On macOS, the copy commands include cp and ditto. It is recommended to use ditto for copying.
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
Ditto is better than the cp command in that:
1. During copying, it can preserve not only the attributes and permissions of the source file or folder, but also the source file’s resource fork structure and the folder’s original structure.
2. This command ensures that files or folders are copied faithfully.
3. If the target file or folder does not exist, ditto will copy it over directly or create new files and folders. Conversely, for files that already exist, the command will merge with the target file or folder.
4. ditto can also provide complete symbolic links.

So let’s copy out the local debug package.
```vim
ditto -ck --sequesterRsrc --keepParent `ls -1 -d -t ~/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphonesimulator/*.app | head -n 1` /Users/YDZ/Desktop/app.zip
```
A few points need to be clarified:

1. The final path in the command above (`/Users/YDZ/Desktop/app.zip`) is customizable. In my example, I put it directly on the desktop. Other than changing this path, nothing before it needs to be changed, including the \*.

2. Next, let’s talk about the \* in the command. When we open `~/Library/Developer/Xcode/DerivedData/` locally, we’ll find that it contains all the app programs that have been run on our local simulator. The prefix is the app’s Bundle Identifier, followed by a hyphen and a string of characters. The path containing \* in the `ditto` command above is used to dynamically match an address; \* is also a wildcard here. The `head` command that follows defines the matching rule. In fact, `head` is used to find the path of the app most recently run in the simulator.

To ensure that the package we build is correct, it’s recommended to first run the app we want to package. In general, the Run action in our Scheme uses the debug product (if this has been changed, switch it to the corresponding debug Scheme), and make sure it is the app we want to give to the designer for review. Then run this `ditto` command.

##### 2. Copy the debug package to another simulator

After running the `ditto` command above, a zip file will be generated. After extracting it, you’ll get an app file, which is the debug package. The debug package is the app package we will give to the designer.

How can we let the designer install this app in the simplest possible way?

Here we’ll introduce a command-line tool, [ios-sim](https://github.com/appcelerator/ios-sim).

ios-sim is a tool that can control the iOS Simulator from the command line. With this command, we can launch a simulator, install an app, launch an app, and query the iOS SDK. It allows us to avoid opening Xcode, similar to automated testing.

However, ios-sim only supports versions after Xcode 6.

Install ios-sim
```vim 
    $ npm install ios-sim -g
```
Documentation:
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
It's not hard to use.
```vim
ios-sim launch /Users/YDZ/Desktop/app.app --devicetypeid iPhone-6s 
```
Here, `/Users/YDZ/Desktop/app.app` is the path where the designer has the app. The `--devicetypeid` parameter is followed by a specified simulator version.

You only need to send the command above to the designer. They can blindly paste it into the command line, and the simulator with the app installed will start automatically and open the app.


#### III. Additional Experiments

Curious folks definitely won’t be satisfied with only installing debug builds on the simulator. Since we can install an app on the simulator without using code, can we install a release build as well? I tried it out of curiosity.

First, I downloaded the latest WeChat from the App Store, changed the `ipa` suffix to `zip`, extracted it, took out “WeChat” from the `Payload` folder, and then ran the `ios-sim` command.

As a result, WeChat was indeed installed on the simulator. However, as soon as I tapped the app, it showed the moon screen and then exited. The console printed a bunch of information.
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
Aug 18 16:29:27 YDZdeMacBook-Pro itunesstored[19744]: UpdateAssetsOperation: Error downloading manifest from URL https://apps.itunes.com/files/ios-music-app/: Error Domain=SSErrorDomain Code=109 "Cannot connect to iTunes Store" UserInfo={NSLocalizedDescription=Cannot connect to iTunes Store, SSErrorHTTPStatusCodeKey=503}
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: (Error) MC: MobileContainerManager gave us a path we weren't expecting; file a radar against them
       	Expected: /private/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles
       	Actual: /Users/YDZ/Library/Developer/CoreSimulator/Devices/D6BD3967-9BC4-4A8D-9AD0-23176B22B12A/data/Containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles
       	Overriding MCM with the one true path
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: PairedSync, Debugging at level 0 for console and level 0 for log files
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: Error: Could not create service from plist at path: file:///Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/PairedSyncServices/com.apple.pairedsync.healthd.plist. Returning nil PSYSyncCoordinator for service name com.apple.pairedsync.healthd.  Please check that your plist exists and is in the correct format.
Aug 18 16:29:31 YDZdeMacBook-Pro healthd[19174]: Error: failed to load bundle "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Health/Plugins/CompanionHealth.bundle": Error Domain=NSCocoaErrorDomain Code=4 "Could not load bundle “CompanionHealth.bundle” because the location of its executable could not be found." UserInfo={NSLocalizedFailureReason=Could not find the location of this bundle's executable., NSLocalizedRecoverySuggestion=Please try reinstalling the bundle., NSBundlePath=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Health/Plugins/CompanionHealth.bundle, NSLocalizedDescription=Could not load bundle “CompanionHealth.bundle” because the location of its executable could not be found.}
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
After taking a closer look at the log, the root cause is still because
```vim
com.apple.CoreSimulator.SimDevice.D6BD3967-9BC4-4A8D-9AD0-23176B22B12A.launchd_sim[19096] (UIKitApplication:com.tencent.xin[0xdf6d][19774]): Program specified by service does not contain one of the requested architectures:

Unable to get pid for 'UIKitApplication:com.tencent.xin[0xdf6d]': No such process (err 3)
```
Because the architectures packaged in the release build do not include simulator architectures, whereas the debug build does. Therefore, the release build cannot be installed on the simulator.

Since I haven’t studied reverse engineering, I can’t go any further. I’m not sure whether reverse-engineering techniques can strip the release package and convert it into a debug package. If it can be converted into a debug package, then it should also be possible to install it directly on the simulator via the `ios-sim` command.

That concludes this attempt to use `ios-sim` to install an app on the simulator. Because it can only install debug builds on the simulator, I added quotation marks around “install” in the title; not every app file can be installed on the simulator.

Feedback and suggestions are welcome.