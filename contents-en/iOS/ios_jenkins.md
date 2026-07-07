# Step-by-Step Guide to Continuous Integration for iOS Projects with Jenkins

![](https://img.halfrost.com/Blog/ArticleTitleImage/19__0__.png)


#### Preface
As everyone knows, competition among apps has reached a white-hot stage where user experience is king and quality comes first. Users are very picky. If a company's growth team spends a large amount of money promoting an app and finally acquires some users, but then an online bug causes a batch of users to experience crashes during use, the lighter consequence is that the earlier marketing spend may be wasted; the heavier consequence is poor word of mouth, making it difficult to grow the user base in the future. If we calmly analyze the root cause, it usually comes down to shipping before quality has passed the bar. Setting aside some subjective factors, I believe a large portion of the objective factors can be prevented. According to a set of development-practice recommendations proposed by experts, CI + FDD can help us solve objective issues to a great extent. This article will mainly discuss [Continuous Integration](http://martinfowler.com/articles/continuousIntegration.html), abbreviated as CI.

####Table of Contents
- 1.Why we need continuous integration
- 2.Continuous integration tool — Jenkins
- 3.iOS automated packaging commands — xcodebuild + xcrun and fastlane - gym
- 4.Automatically uploading to third-party platforms such as fir / Pgyer after packaging
- 5.A complete continuous integration workflow
- 6.Jenkins + Docker

#### 1. Why We Need Continuous Integration
When discussing why we need it, we first need to talk about what it is. So what is continuous integration?

> Continuous integration is a software development practice: many teams integrate their work frequently. Each member usually integrates daily, which means there may be multiple integrations every day. Each integration is verified by an automated build, including tests, to detect errors as quickly as possible. Many teams find that this approach can significantly reduce integration problems and make team development faster.

CI is a development practice. The practice should include three basic modules: an automated build process that can automatically compile code, distribute it, deploy it, and run tests; a code repository, such as SVN or Git; and finally, a continuous integration server. Through continuous integration, we can use automation and other means to obtain product feedback at high frequency and respond to it.

So what benefits can continuous integration bring us? Here I recommend an [article](http://apiumtech.com/blog/top-benefits-of-continuous-integration-2/), which divides [Continuous integration](http://apiumtech.com/blog/top-benefits-of-continuous-integration-2/) (CI) and [test-driven development](http://apiumtech.com/blog/20-benefits-of-test-driven-development/) (TDD) into 12 steps. The resulting benefits multiply, yielding 24 advantages.

![](https://img.halfrost.com/Blog/ArticleImage/18_2.png) 


Let me talk about some of the advantages I have deeply experienced after using CI.

##### 1. Shorten the development cycle and iterate versions quickly
At the beginning of each version, the development cycle is estimated, but it is always delayed by various things. Some of these are objective factors. As product lines increase and iteration speed becomes faster and faster, the pressure on testing also becomes greater. If testing only begins after development is completely finished, it will affect the schedule for a long period of time. At that point, late integration will seriously slow down the project pace. If continuous integration can be started as early as possible, and the iteration loop of the 12 steps in the image above can be entered as soon as possible, problems can be exposed earlier, resolved earlier, and the tasks can be completed within the scheduled time as much as possible.

##### 2. Efficiency brought by automated pipeline operations
Packaging is actually a very time-consuming task for developers, and it does not require much technical depth. The more developers there are, the higher the chance of code conflicts caused by mutual changes. In addition, without a production-line management mechanism, it is difficult to guarantee the quality of the code in the repository. The team will spend time resolving conflicts, and after resolving them, developers still need to package manually. If the certificates are also incorrect at this point, a lot more time will be wasted. This time can actually be saved through continuous integration. One or two days may not look like much, but measured over a year, it can save a lot of time!

##### 3. Deployable at any time
With continuous integration, we can package on a daily basis. The biggest advantage brought by this high-frequency integration is that we can deploy and go online at any time. This avoids the situation where, right before release, there are vulnerabilities and bugs everywhere, everything is rushed, and deployment still cannot happen after the chaos, seriously affecting the release schedule.

##### 4. Greatly avoid low-level mistakes
We can make mistakes, but making low-level mistakes is really unacceptable. The low-level mistakes referred to here include the following: compilation errors, installation issues, API issues, and performance issues.
Daily continuous integration can quickly detect compilation issues because automated packaging will fail directly. After the package is built, if testers cannot install it by scanning the QR code, this kind of issue will also be exposed immediately. API issues and performance issues can be found by automated test scripts. These low-level issues are exposed and displayed by continuous integration, reminding us to avoid them.


#### 2. Continuous Integration Tool — Jenkins

Jenkins is an open-source project that provides an easy-to-use continuous integration system, freeing developers from tedious integration work so they can focus on implementing more important business logic. At the same time, Jenkins can monitor errors that occur during integration, provide detailed log files and notifications, and visually display trends and stability of project builds in chart form.


According to the official definition, Jenkins has the following uses:  
1. Build projects
2. Run test cases to detect bugs
3. Perform static code analysis
4. Deploy

Regarding these four points, Jenkins is quite convenient in actual use:
1.Automating project builds and packaging can save developers a lot of time. More importantly, Jenkins maintains a high-quality, usable set of code for us and guarantees a clean environment. We often encounter packaging failures caused by incorrect local configuration. Now Jenkins acts as an impartial judge: if it cannot correctly compile an ipa, then there is either a compilation error or a configuration issue. Developers do not need to argue that it runs locally, or that it stopped running after pulling someone else's code. Everyone jointly maintains Jenkins's ability to compile successfully, because Jenkins's build environment is much simpler than our local environment. It is the cleanest, least polluted build environment. Developers only need to focus on coding. This is the convenience it brings to developers.

2.This can be used for automated testing. Generate large batches of test cases locally, then use the server to keep running these cases every day. Run every API once each day. It may seem unnecessary, but in reality, a system that runs normally today may very well have problems tomorrow due to today's code changes. With Jenkins, regression testing can be performed on a daily basis. As long as the code changes, Jenkins runs all regression test cases. When project schedules are tight, regression testing is often not taken seriously in many cases; after all, it is quite possible that running through it once turns out to be “useless work.” However, because regression testing is not performed in time, the system may become unusable by the final release. At that point, tracing the root cause becomes time-consuming. Looking through commit history and seeing hundreds of commits is also painful to investigate. Daily regression testing can discover problems immediately. Testers can focus on unit tests every day and manually perform regression testing once a week. This is the convenience it brings to testers.

3.This is static code analysis, which can detect many code issues, such as potential memory leaks. Because the environment where Jenkins runs is clean, it can also discover issues that our complex local environments may not reveal, further improving code quality. This is the convenience it brings to quality assurance.

4.Deploy at any time. After Jenkins finishes packaging, subsequent actions can be configured. At this point, it usually submits the app to a system that runs test cases, or deploys it to an internal testing platform and generates a QR code. Low-level issues such as inability to install during deployment are immediately exposed. Testers only need to scan a QR code to install it, which is very convenient. This also counts as convenience brought to testers.

![](https://img.halfrost.com/Blog/ArticleImage/18_3.png) 


The following example uses the Weekly Release 2.15 version from 2016-07-24 22:35.


Now let's start installing Jenkins. Download the latest pkg installer from the official website https://jenkins.io/.

![](https://img.halfrost.com/Blog/ArticleImage/18_4.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_5.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_6.png)   

![](https://img.halfrost.com/Blog/ArticleImage/18_7.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_8.png)   


![](https://img.halfrost.com/Blog/ArticleImage/18_9.png)   


You can also download jenkins.war, then run Java -jar jenkins.war to install it.


After installation is complete, Safari may open automatically. If it does not, open your browser and enter http://localhost:8080

![](https://img.halfrost.com/Blog/ArticleImage/18_10.png)  


At this point, an error may be reported. If the issue shown here occurs, the reason is that there is a problem with the Java environment. Reinstall the Java environment.

At this point, if you restart the computer, you will find that Jenkins has added a new user for you named Jenkins, but you do not know the password. You may try passwords, but they will definitely be wrong, because the initial password is very complex. The correct approach is to open http://localhost:8080, and the initial password reset page shown below will appear.

![](https://img.halfrost.com/Blog/ArticleImage/18_11.png)  


Follow the prompt and locate the /Users/Shared/Jenkins/Home/ directory. Although this directory is shared, it has permissions. Non-Jenkins users do not have read/write permissions for the /secrets/ directory.
          

![](https://img.halfrost.com/Blog/ArticleImage/18_12.png)   

![](https://img.halfrost.com/Blog/ArticleImage/18_13.png)  

Open the initialAdminPassword file, copy the password, and you can fill it into the web page to reset the password, as shown below.

![](https://img.halfrost.com/Blog/ArticleImage/18_14.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_15.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_16.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_17.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_18.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_19.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_20.png)  


Install all the way through, enter the username, password, email, and so on, and the installation is complete.

Continue logging in to localhost:8080, choose “System Management” — “Manage Plugins”. We need to install some supporting plugins first.

**Install the GitLab plugin**
Because we use GitLab to manage source code, Jenkins itself does not come with a GitLab plugin, so we need to choose **System Management**->**Manage Plugins**, select “**GitLab Plugin**” and “**Gitlab Hook Plugin**” under “**Available Plugins**”, and then install them.

**Install the Xcode plugin**
Same as the steps for installing the GitLab plugin, choose **System Management**->**Manage Plugins**, select “**Xcode integration**” under “**Available Plugins**”, and install it.


After installing this, we can configure a build project.

![](https://img.halfrost.com/Blog/ArticleImage/18_21.png)  


![](https://img.halfrost.com/Blog/ArticleImage/18_22.png)  


Click the newly created project and configure the **General** parameters. 

![](https://img.halfrost.com/Blog/ArticleImage/18_23.png)  


Here you can set the package retention days and the number of builds.

Next, configure **Source Code Management**.

Since I am currently using GitLab, first configure the SSH Key and add SSH in Jenkins credential management. On the Jenkins management page, choose “**Credentials**”, then choose “**Global credentials (unrestricted)**”, and click “**Add Credentials**”. As shown below, fill in your SSH information, then click “**Save**”. This adds SSH to Jenkins's global domain.

![](https://img.halfrost.com/Blog/ArticleImage/18_24.png)  


If the configuration is correct, the red warning shown in the image below will not appear. If you see the prompt below, it means Jenkins has not yet connected to GitLab or SVN. Please check again whether the SSH Key is configured correctly.

![](https://img.halfrost.com/Blog/ArticleImage/18_25.png)  


**Build Trigger Settings** is where automated testing is configured. There is a lot involved here, and I have not studied it in depth yet, so we will not configure it for now. If you have automated testing requirements, you can study these settings carefully.

However, there are two configurations here that still need to be configured.

**Poll SCM**  (poll source code management)  Poll source code management  
You need to set the source code path for polling to take effect. A typical setting looks like: 0/5 * * * * poll once every 5 minutes  
**Build periodically**  (scheduled build)  
A typical setting looks like: 00 20 * * *   execute a scheduled build every day at 20:00. Of course, the settings for both are the same format and can be used interchangeably.

The format is as follows:

Minute (0-59) Hour (0-23) Date (1-31) Month (1-12) Day of week (0-7, both 0 and 7 mean Sunday) [See here for more detailed settings](http://www.scmgalaxy.com/scm/setting-up-the-cron-jobs-in-jenkins-using-build-periodically-scheduling-the-jenins-job.html)


![](https://img.halfrost.com/Blog/ArticleImage/18_26.png)  


**Build Environment Settings**  
iOS packaging requires signing files and certificates, so in this section we check “**Keychains and Code Signing Identities**” and “**Mobile Provisioning Profiles**”.
Here we need to use a Jenkins plugin again. On the system management page, choose “**Keychains and Provisioning Profiles Management**”.

![](https://img.halfrost.com/Blog/ArticleImage/18_27.png)  


Enter the **Keychains and Provisioning Profiles Management** page, click the “**Browse**” button, and upload your keychain and certificate respectively. After the upload succeeds, specify the signing file name for the keychain. Click “**Add Code Signing Identity**”. After it is successfully added, it looks like the following image:

![](https://img.halfrost.com/Blog/ArticleImage/18_28.png)  

Note: The first time I imported the certificate and Provisioning Profiles file, I ran into a small “pitfall”. At the time, I thought a certificate was needed, but what is needed here is the Keychain, not the cer certificate file. This Keychain is actually located at /Users/admin username/Library/keychains/login.keychain. After this Keychain is configured, Jenkins copies it to /Users/Shared/Jenkins/Library/keychains, where Library is a hidden file. The Provisioning Profiles file is also copied directly to the /Users/Shared/Jenkins/Library/MobileDevice directory.

This configures the Adhoc certificate and signing file in Jenkins. Next, we only need to specify the related files in the item settings.
Return to the item we created, find **Build Environment**, and select your related certificate and signing file as shown below.

![](https://img.halfrost.com/Blog/ArticleImage/18_29.jpg)  


Next, configure **Build**.  

![](https://img.halfrost.com/Blog/ArticleImage/18_30.png)  


Here we choose to execute a packaging script. The script will be explained in detail in the next section.

**Post-build Actions**

![](https://img.halfrost.com/Blog/ArticleImage/18_31.png)  


Here we choose **Execute a set of scripts**. This is also a script, used to upload the automatically packaged ipa file. The script is explained in detail in Chapter 4.

At this point, all of our Jenkins settings are complete. Click **Build**, and the project will start building.

After one build, the meaning of each color is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/18_32.png)  


The weather indicator represents the quality of the project, which is also one of Jenkins's distinctive features.  
  
![](https://img.halfrost.com/Blog/ArticleImage/18_33.jpg)  


If the build fails, you can check **Console Output** to view the log.

![](https://img.halfrost.com/Blog/ArticleImage/18_34.png)

#### III. iOS Automated Packaging Commands — `xcodebuild` + `xcrun` and `fastlane gym`

In day-to-day development, packaging is an indispensable final step before release. If you need to package a project into an IPA file, the usual approach is to click “Product -> Archive” in Xcode. After the entire project has been archived, you then make selections in the automatically displayed “Organizer” and export an Ad Hoc or Enterprise IPA package as needed. Although Xcode already does an excellent job of packaging, it still requires us to click five or six times manually. In addition, since we now need continuous integration, automating the process with packaging commands naturally becomes necessary.

##### 1. `xcodebuild` + `xcrun` Commands

Xcode provides developers with a set of commands for building and packaging: `xcodebuild` and `xcrun`. `xcodebuild` packages the specified project into an `.app` file, and `xcrun` converts the specified `.app` file into the corresponding `.ipa` file.

The detailed documentation is as follows: [Official xcodebuild Documentation](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcodebuild.1.html), [Official xcrun Documentation](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcrun.1.html)
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
The first three of the 10 commands above are the most important.

Next, let’s explain the parameters:  
-project -workspace: These two correspond to the project name. If there are multiple projects and none is specified here, the first project is used by default.  
-target: The targets to build. If not specified, the first one is used by default.  
-configuration: If this configuration has not been modified, the defaults are the Debug and Release versions. If not specified, Release is used by default.  
-buildsetting=value ...: Use this command to modify the project’s configuration.  
-scheme: Specifies the scheme to build.

The above are the most basic commands.

For the parameters in the first and second of the 10 commands above, the -target
 and -configuration parameters can be obtained using xcodebuild -list
, the -sdk parameter can be obtained using xcodebuild -showsdks
, and [buildsetting=value ...] is used to override existing configurations in the project. For the overridable parameters, refer to the official documentation [Xcode Build Setting Reference](https://developer.apple.com/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/).
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
The third command above is specifically for building projects that use CocoaPods, because at that point the project file is no longer an `xcodeproj`; it has become an `xcworkspace`.

Now let’s talk about the `xcrun` command.
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
There aren’t many parameters, and usage is straightforward: xcrun -sdk iphoneos -v PackageApplication + the parameters mentioned above.


Once we understand the parameters, let’s look at how to use them. The following is an automated packaging script written using the xcodebuild + xcrun commands.
```vim  

# Project name
APP_NAME="YourProjectName"

# Certificate
CODE_SIGN_DISTRIBUTION="iPhone Distribution: Shanghai ******* Co., Ltd."

# info.plist path
project_infoplist_path="./${APP_NAME}/Info.plist"

# Get version number
bundleShortVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" "${project_infoplist_path}")

# Get build value
bundleVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleVersion" "${project_infoplist_path}")

DATE="$(date +%Y%m%d)"
IPANAME="${APP_NAME}_V${bundleShortVersion}_${DATE}.ipa"

# IPA file path to upload
IPA_PATH="$HOME/${IPANAME}"
echo ${IPA_PATH}
echo "${IPA_PATH}">> text.txt

//The following 2 lines are for use without Cocopods
echo "=================clean================="
xcodebuild -target "${APP_NAME}"  -configuration 'Release' clean

echo "+++++++++++++++++build+++++++++++++++++"
xcodebuild -target "${APP_NAME}" -sdk iphoneos -configuration 'Release' CODE_SIGN_IDENTITY="${CODE_SIGN_DISTRIBUTION}" SYMROOT='$(PWD)'

//The following 2 lines are for use with Cocopods integrated
echo "=================clean================="
xcodebuild -workspace "${APP_NAME}.xcworkspace" -scheme "${APP_NAME}"  -configuration 'Release' clean

echo "+++++++++++++++++build+++++++++++++++++"
xcodebuild -workspace "${APP_NAME}.xcworkspace" -scheme "${APP_NAME}" -sdk iphoneos -configuration 'Release' CODE_SIGN_IDENTITY="${CODE_SIGN_DISTRIBUTION}" SYMROOT='$(PWD)'

xcrun -sdk iphoneos PackageApplication "./Release-iphoneos/${APP_NAME}.app" -o ~/"${IPANAME}"
```

##### 2. The gym Command
When talking about gym, we should first talk about fastlane.
fastlane is a suite of automated build tools written in Ruby, used for automating build, packaging, and release workflows for iOS and Android. gym is its build command.

See the fastlane official website [here](https://fastlane.tools/), and the fastlane GitHub repository [here](https://github.com/fastlane/fastlane)

To use gym, you first need to install fastlane.
```vim  
sudo gem install fastlane --verbose
```
fastlane includes all the commands we run after day-to-day coding when preparing to go live.
```vim   
deliver：Upload screenshots, binary data, and apps to AppStore
snapshot：Automatically capture screenshots of your app on every device
frameit：Add device frames around app screenshots
pem：Can automatically generate and update app push notification profiles
sigh：Generate and download development/App Store provisioning profiles
produce：Create a new iOS app in iTunes Connect from the command line
cert：Automatically create iOS certificates
pilot：The best way to manage TestFlight builds from the terminal
boarding：An easy way to invite beta testers
gym：Build and package a new release version
match：Use git to sync developer certificates and provisioning profiles among your team
scan：Run test cases on iOS and Mac apps
```
The entire release process can be described with fastlane as follows.
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
PS: You may also have heard of a command called [xctool](https://github.com/facebook/xctool).

xctool is an enhanced implementation of the official `xcodebuild` command, and its output is much more intuitive and readable than `xcodebuild`’s. It can be installed via `brew`.
```vim  
brew install xctool
```
Use gym to automate packaging. The [script](https://github.com/xilin/ios-build-script/blob/master/build_using_gym.sh) is as follows.
```vim  

# Timer

SECONDS=0

# Assume the script is placed in the same path as the project

project_path=$(pwd)

# Get the current time string and append it to the file name

now=$(date +"%Y_%m_%d_%H_%M_%S")

# Specify the project's scheme name

scheme="DemoScheme"

# Specify the configuration name for packaging

configuration="Adhoc"

# Specify the export method used for packaging; currently supports app-store, package, ad-hoc, enterprise, development, and developer-id, i.e. xcodebuild's method parameter

export_method='ad-hoc'

# Specify the project path

workspace_path="$project_path/Demo.xcworkspace"

# Specify the output path

output_path="/Users/your_username/Documents/"

# Specify the output archive file path

archive_path="$output_path/Demo_${now}.xcarchive"

# Specify the output ipa path

ipa_path="$output_path/Demo_${now}.ipa"

# Specify the output ipa name

ipa_name="Demo_${now}.ipa"

# Get the commit message when executing the command

commit_msg="$1"

# Output the configured variable values

echo "===workspace path: ${workspace_path}==="

echo "===archive path: ${archive_path}==="

echo "===ipa path: ${ipa_path}==="

echo "===export method: ${export_method}==="

echo "===commit msg: $1==="

# Clean the previous build first

gym --workspace ${workspace_path} --scheme ${scheme} --clean --configuration ${configuration} --archive_path ${archive_path} --export_method ${export_method} --output_directory ${output_path} --output_name ${ipa_name}

# Output the total time

echo "===Finished. Total time: ${SECONDS}s==="
```

#### IV. Automatically Upload to Third-Party Platforms such as fir / Pgyer After Packaging

To upload to third-party platforms such as fir / Pgyer, you need to register an account and obtain a token before you can perform scripted operations.

##### 1. Automatically Upload to fir
Install the fir-clifir command-line tool  
You need to install ruby first, then run
```vim  
gem install fir-cli
```

```vim  

#Upload to fir
fir publish ${ipa_path} -T fir_token -c "${commit_msg}"
```

##### 2. Automated Upload to Pgyer
```vim  

#User Key on Pgyer
uKey="7381f97070*****c01fae439fb8b24e"

#API Key on Pgyer
apiKey="0b27b5c145*****718508f2ad0409ef4"

#Path of the ipa file to upload
IPA_PATH=$(cat text.txt)

rm -rf text.txt

#Command to upload to Pgyer
echo "++++++++++++++upload+++++++++++++"
curl -F "file=@${IPA_PATH}" -F "uKey=${uKey}" -F "_api_key=${apiKey}" http://www.pgyer.com/apiv1/app/upload
```

#### V. Complete Continuous Integration Workflow

After the continuous integration setup described above, we now have the following complete continuous integration workflow:

![](https://img.halfrost.com/Blog/ArticleImage/18_35.png)  


#### VI. Jenkins + Docker

There are actually two deployment models for Jenkins:
Single-node (Master) deployment
This deployment model applies to most projects. The build tasks are relatively lightweight and few in number, so a single node is sufficient for day-to-day development needs.
Multi-node (Master-Slave) deployment
This deployment structure is typically adopted by larger-scale projects with frequent code commits (which means frequent builds) and heavy automated testing workloads. In this deployment structure, the Master usually acts only as the manager, responsible for task scheduling, managing slave nodes, collecting task status, and so on, while the actual build tasks are assigned to slave nodes. In theory, there is no upper limit to the number of slave nodes a Master node can manage, but as the number increases, its performance and stability usually degrade to varying degrees. The exact impact depends on the hardware performance of the Master.

However, multi-node deployment also has some drawbacks. When the number of test cases becomes massive, it can cause issues, so some people have designed the following deployment structure: Jenkins + Docker.

![](https://img.halfrost.com/Blog/ArticleImage/18_36.png)  


Since my current project is still using a single-node (Master) deployment, I do not have practical experience with multi-node (Master-Slave) deployment, let alone the improved Docker-based version. However, if you have requirements involving a massive number of test cases and high-pressure, large-scale, complex regression testing, I recommend reading this [article](http://www.zjbonline.com/2016/03/05/Jenkins-Docker%E6%90%AD%E5%BB%BA%E6%8C%81%E7%BB%AD%E9%9B%86%E6%88%90%E6%B5%8B%E8%AF%95%E7%8E%AF%E5%A2%83/).


#### Finally

That’s my practical experience with Jenkins continuous integration. I’m sharing it with everyone, and if there are any mistakes, I welcome your feedback and guidance.