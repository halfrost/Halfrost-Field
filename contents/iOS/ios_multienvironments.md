# 手把手教你给一个 iOS app 配置多个环境变量


![](https://img.halfrost.com/Blog/ArticleTitleImage/19_0_.jpg)


#### 前言  
谈到多环境，相信现在大多公司都至少有2-3个app环境了，比如Test环境，UAT(User Acceptance Test)用户验收测试环境，Release环境等等。当需要开发打多个包的时候，一般常见做法就是直接代码里面修改环境变量，改完之后Archive一下就打包了。当然这种做法很正确，只不过不是很优雅很高效。如果搭建好了Jenkins([搭建教程](http://www.jianshu.com/p/41ecb06ae95f))，我们利用它来优雅的打包。如果利用Jenkins来打包，我们就需要来给app来配置一下多个环境变量了。之后Jenkins分别再不同环境下自动集成即可。接下来，我们来谈谈常见的2种做法。

####目录
- 1.利用Build Configuration来配置多环境
- 2.利用[xcconfig](https://developer.apple.com/library/ios/recipes/xcode_help-project_editor/Articles/BasingBuildConfigurationsonConfigurationFiles.html)文件来配置多环境
- 3.利用Targets来配置多环境

#### 一.利用Build Configuration来配置多环境
前言里面我们先谈到了需求，由于需要配置多个环境，并且多个环境都需要安装到手机上，那么可以配置Build Configuration来完成这个任务。如果Build Configuration还不熟悉的，可以先温习一下[官方文档](https://developer.apple.com/library/ios/recipes/xcode_help-project_editor/Articles/BasingBuildConfigurationsonConfigurationFiles.html)，[新版文档链接在这里Build settings reference](https://help.apple.com/xcode/mac/8.0/#/itcaec37c2a6)。

##### 1. 新建Build Configuration
先点击Project里面找到Configuration，然后选择添加，这里新加一个Configuration。系统默认是2个，一个Debug，一个Release。这里我们需要选择是复制一个Debug还是Release。Release和Debug的区别是，Release是不能调试程序，因为默认是屏蔽了可调试的一些参数，具体可以看BuildSetting里面的区别，而且Release编译时有做编译优化，会比用Debug打包出来的体积更小一点。

![](https://img.halfrost.com/Blog/ArticleImage/19_2.png)  


这里我们选择一个Duplicate “Debug” Configuration，因为我们新的环境需要debug，添加完了之后就会多了一套Configuration了，这一套其实是包含了一些编译参数的配置集合。如果此时项目里面有cocopods的话，打开Configuration Set就会发现是如下的样子：

![](https://img.halfrost.com/Blog/ArticleImage/19_3.png)  



在我们自己的项目里面用了Pod，打开配置是会看到如下信息  

![](https://img.halfrost.com/Blog/ArticleImage/19_4.png)  


注意：刚刚新建完Build Configuration之后，这时如果有pod，请立即执行一下

```vim  

pod install  
```
pod安装完成之后会自动生成xcconfig文件，如果你手动新建这个xcconfig，然后把原来的debug和release对应的pod xcconfig文件内容复制进来，这样做是无效的，需要pod自己去生成xcconfig文件才能被识别到。

新建完Build Configuration，这个时候需要新建pod里面对应的Build Configuration，要不然一会编译会报错。如果没用pod，可以忽略一下这一段。

如下图新建一个对应之前Porject里面新建的Build Configuration  

![](https://img.halfrost.com/Blog/ArticleImage/19_5.png)  


##### 2. 新建Scheme

接下来我们要为新的Configuration新建一个编译Scheme。

![](https://img.halfrost.com/Blog/ArticleImage/19_6.png) 



新建完成之后，我们就可以编辑刚刚新建的Scheme，这里可以把Run模式和Archive都改成新建Scheme。如下图：

![](https://img.halfrost.com/Blog/ArticleImage/19_7.png) 



注意：如果是使用了Git这些协同工具的同学这里还需要把刚刚新建的Scheme共享出去，否则其他人看不到这个Scheme。选择“Manage Schemes”

![](https://img.halfrost.com/Blog/ArticleImage/19_8.png)  


##### 3. 新建User-defined Build Settings

再次回到Project的Build Settings里面来，Add User-Defined Setting。  

![](https://img.halfrost.com/Blog/ArticleImage/19_9.png) 


我们这里新加入2个参数，CustomAppBundleld是为了之后打包可以分开打成多个包，这里需要3个不同的Id，建议是直接在原来的Bundleld加上Scheme的名字即可。

CustomProductName是为了app安装到手机上之后，手机上显示的名字，这里可以按照对应的环境给予描述，比如测试服，UAT，等等。如下图。

![](https://img.halfrost.com/Blog/ArticleImage/19_10.png)  


这里值得提到的一点是，下面Pods的Build_DIR这些目录其实是Pods自己生成好的，之前执行过**Pod install** 之后，这里默认都是配置好的，不需要再改动了。


![](https://img.halfrost.com/Blog/ArticleImage/19_11.png)  



##### 4. 修改info.plist文件 和 Images.xcassets

先来修改一下info.plist文件。

![](https://img.halfrost.com/Blog/ArticleImage/19_12.png)  



由于我们新添加了2个CustomAppBundleld 和 CustomProductName，这里我们需要把info.plist里面的Bundle display name修改成我们自定义的这个字典。编译过程中，编译器会根据我们设置好的Scheme去自己选择Debug，Release，TestRelease分别对应的ProductName。

![](https://img.halfrost.com/Blog/ArticleImage/19_13.png)  



我们还需要在Images.xcassets里面新添加2个New iOS App Icon，名字最好和scheme的名字相同，这样好区分。


![](https://img.halfrost.com/Blog/ArticleImage/19_14.png)  



新建完AppIcon之后，再在Build Setting里面找到**Asset Catalog Compiler**里面，然后把这几种模式下的App Icon set
 Name分别设置上对应的图标。如上图。


既然我们已经新建了这几个scheme，那接下来怎么把他们都打包成app呢？？这里有一份官方的文档[Troubleshooting Application Archiving in Xcode](https://developer.apple.com/library/ios/technotes/tn2215/_index.html)这里面详细记录了我们平时点击了Archive之后是怎么打包的。

这里分享一下我分好这些环境的心得。一切切记，每个环境都要设置好Debug 和 Release！千万别认为线上的版本只设置Release就好，哪天需要调试线上版本，没有设置Debug就无从下手了。也千万别认为测试环境的版本只要设置Debug就好，万一哪天要发布一个测试环境需要发Release包，那又无从下手了。我的建议就是每个环境都配置Debug 和 Release，即使以后不用，也提前设置好，以防万一。合理的设置应该如下图这样。

```markdown  
| -------------------------- |------------------|
|           Scheme           |   Configurations |  
| -------------------------- |------------------| 
|      XXXXProjectTest       |      Debug       | 
|                            |------------------|
|                            |      Release     | 
| -------------------------- |------------------|
|      XXXXProjectAppStore   |      Debug       | 
|                            |------------------|
|                            |      Release     | 
| -------------------------- |------------------|
|      XXXXProjectUAT        |      Debug       | 
|                            |------------------|
|                            |      Release     | 
| -------------------------- |------------------|

```
注意这里一定要把Scheme的名字和编译方式区分开，选择了一个Scheme，只是相当于选择了一个环境，并不是代表这Debug还是Release。

![](https://img.halfrost.com/Blog/ArticleImage/19_15.png)  



我建议Scheme只配置环境，而进来的Run和Archive来配置Debug和Release，我建议每个Scheme都按照上图来，Run对应的Debug，Archive对应的Release。


配置好上述之后，就可以选择不同环境运行app了。可以在手机上生成不同的环境的app，可以同时安装。如下图。

![](https://img.halfrost.com/Blog/ArticleImage/19_16.png)  



##### 5. 配置和获取环境变量

接下来讲几种动态配置环境变量的方法

###### 1. 使用GCC预编译头参数GCC_PREPROCESSOR_DEFINITIONS  

我们进入到Build Settings里面，可以找到Apple LLVM Preprocessing，这里我们可以找到**Preprocessor Macros**在这里，我们是可以加一些环境变量的宏定义来标识符。Preprocessor Macros可以根据不同的环境预先制定不同定义的宏。

![](https://img.halfrost.com/Blog/ArticleImage/19_17.png)  

如上图，圈出来的地方其实就是一个标识符。

有了这些我们预先设置的标识符之后，我们就可以在代码里面写入如下的代码了。
```objectivec

#ifdef DEVELOP
#define searchURL @"http://www.baidu.com"
#define sociaURL  @"weibo.com"
#elif UAT
#define searchURL @"http://www.bing.com"
#define sociaURL  @"twitter.com"
#else
#define searchURL @"http://www.google.com"
#define sociaURL  @"facebook.com"
#endif

```


###### 2. 使用plist文件动态配置环境变量  

我们先来新建3个名字一样的plist作为3个环境的配置文件。  

![](https://img.halfrost.com/Blog/ArticleImage/19_18.png)  


这里名字一样的好处是写代码方便，因为就只需要去读取“Configuration.plist”就可以了，如果名字不一样，还要分别去把对应环境的plist名字拼接出来才能读取。

众所周知，在一个文件夹里面新建2个相同名字的文件，Mac 系统都会提示我们名字相同，不允许我们新建。那我们怎么新建3个相同名字的文件呢？这其实很简单，分别放在3个不同文件夹下面即可。如下图：

![](https://img.halfrost.com/Blog/ArticleImage/19_19.png)   

我就是这样放置的，大家可以根据自己习惯去放置文件。


接下来我们要做的是在编译的时候，运行app前，动态的copy Configuration.plist到app里面，这里需要设置一个copy脚本。

![](https://img.halfrost.com/Blog/ArticleImage/19_20.png)  


进入到我们的Target里面，找到**Build Phases**，我们新建一个**New Copy Files Phase**，并且重命名为**Copy Configuration Files**。

```vim

echo "CONFIGURATION -> ${CONFIGURATION}"
RESOURCE_PATH=${SRCROOT}/${PRODUCT_NAME}/config/${CONFIGURATION}

BUILD_APP_DIR=${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app

echo "Copying all files under ${RESOURCE_PATH} to ${BUILD_APP_DIR}"
cp -v "${RESOURCE_PATH}/"* "${BUILD_APP_DIR}/"

```
这一段脚本就能保证我们的Configuration.plist 文件可以在编译的时候，选择其中一个打包进我们的app。

再写代码每次读取这个plist里面的信息就可以做到动态化了。

```objectivec

- (NSString *) readValueFromConfigurationFile {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:@"Configuration" ofType:@"plist"];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
    return config[@"serverURL"];
}

```






这里我假设plist文件里面预设置了一个serverURL的字符串，用这种方式就可以读取出来了。当然在plist里面也可以设置数组，字典，相应的把返回值和Key值改一下就可以了。


###### 3. 使用单例来处理环境切换

当然使用一个单例也可以做到环境切换。新建一个单例，然后可以在设置菜单里面加入一个列表，里面列出所有的环境，然后用户选择以后，单例就初始化用户所选的环境。和上面几种方式不同的是，这种方式就是在一个app里面切换多种环境。看大家的需求，任取所需。






 

#### 二.利用文件来配置多环境
说道[xcconfig](https://developer.apple.com/library/ios/recipes/xcode_help-project_editor/Articles/BasingBuildConfigurationsonConfigurationFiles.html)，这个官方文档上面也提到的不是很详细，在网上寻找了一下，倒是找到了另外一份详细非官方文档。[The Unofficial Guide to xcconfig files](http://pewpewthespells.com/blog/xcconfig_guide.html#CondVarSDK)

提到xcconfig，就要先说说几个概念。


##### 1. 区分几个概念 
先来区分一下Xcode Workspace、Xcode Scheme、Xcode Project、Xcode Target、Build Settings 这5者的关系。这5者的关系在苹果官方文档上其实都已经说明的很清楚了。详情见文档[Xcode Concepts](https://developer.apple.com/library/ios/featuredarticles/XcodeConcepts/Concept-Targets.html)。

我来简单来解读一下文档。

**Xcode Workspace**   

> A workspace is an Xcode document that groups projects and other documents so you can work on them together. A workspace can contain any number of Xcode projects, plus any other files you want to include. In addition to organizing all the files in each Xcode project, a workspace provides implicit and explicit relationships among the included projects and their targets.  

workspace这个概念大家应该都很清楚了。它可以包含多个Project和其他文档文件。


**Xcode Project**

>An Xcode project is a repository for all the files, resources, and information required to build one or more software products. A project contains all the elements used to build your products and maintains the relationships between those elements. It contains one or more targets, which specify how to build products. A project defines default build settings for all the targets in the project (each target can also specify its own build settings, which override the project build settings).

project就是一个个的仓库，里面会包含属于这个项目的所有文件，资源，以及生成一个或者多个软件产品的信息。每一个project会包含一个或者多个 targets，而每一个 target 告诉我们如何生产 products。project 会为所有 targets 定义了默认的 build settings，每一个 target 也能自定义自己的 build settings，且 target 的 build settings 会重写 project 的 build settings。

最后这句话比较重要，下面设置xcconfig的时候就会用到这一点。


![](https://img.halfrost.com/Blog/ArticleImage/19_21.png)  

Xcode Project 文件会包含以下信息，对资源文件的引用(源码.h和.m文件，frame，资源文件plist，bundle文件等，图片文件image.xcassets还有Interface Builder(nib)，storyboard文件)、文件结构导航中用来组织源文件的组、Project-level build configurations(Debug\\Release)、Targets、可执行环境，该环境用于调试或者测试程序。

**Xcode Target**

>A target specifies a product to build and contains the instructions for building the product from a set of files in a project or workspace. A target defines a single product; it organizes the inputs into the build system—the source files and instructions for processing those source files—required to build that product. Projects can contain one or more targets, each of which produces one product.

target 会有且唯一生成一个 product, 它将构建该 product 所需的文件和处理这些文件所需的指令集整合进 build system 中。Projects 会包含一个或者多个 targets,每一个 target 将会产出一个 product。


这里值得说明的是，每个target 中的 build setting 参数继承自 project 的 build settings, 一旦你在 target 中修改任意 settings 来重写 project settings，那么最终生效的 settings 参数以在 target 中设置的为准. Project 可以包含多个 target, 但是在同一时刻，只会有一个 target 生效，可用 Xcode 的 scheme 来指定是哪一个 target 生效。



**Build Settings**

>A build setting is a variable that contains information about how a particular aspect of a product’s build process should be performed. For example, the information in a build setting can specify which options Xcode passes to the compiler.

build setting 中包含了 product 生成过程中所需的参数信息。project的build settings会对于整个project 中的所有targets生效，而target的build settings是重写了Project的build settings，重写的配置以target为准。

一个 build configaration 指定了一套 build settings 用于生成某一 target 的 product，例如Debug和Release就属于build configaration。


**Xcode Scheme**

>An Xcode scheme defines a collection of targets to build, a configuration to use when building, and a collection of tests to execute.

一个Scheme就包含了一套targets(这些targets之间可能有依赖关系)，一个configuration，一套待执行的tests。

这5者的关系，举个可能不恰当的例子，
Xcode Workspace就如同工厂，Xcode Project如同车间，每个车间可以独立于工厂来生产产品(project可独立于workspace存在)，但是各个车间组合起来就需要工厂来组织(如果用了cocopods，就需要用workspace)。Xcode Target是一条条的流水线，一条流水线上面只生产一种产品。Build Settings是生产产品的秘方，如果是生产汽水，Build Settings就是其中各个原料的配方。Xcode Scheme是生产方案，包含了流水线生产，秘方，还包含生产完成之后的质检(test)。


##### 2. 创建一个xcconfig文件  

![](https://img.halfrost.com/Blog/ArticleImage/19_22.png)  

然后创建好了这个文件，我们在project里面设置一下。

![](https://img.halfrost.com/Blog/ArticleImage/19_23.png)  


在这些地方把配置文件换成我们刚刚新建的文件。


接下来就要编写我们的xcconfig文件了。这个文件里面可以写的东西挺多的。细心的同学就会发现，其实我们一直使用的cocopods就是用这个文件来配置编译参数的。我们随便看一个简单的cocopods的xcconfig文件，就是下图这样子：

```vim 

GCC_PREPROCESSOR_DEFINITIONS = $(inherited) COCOAPODS=1
HEADER_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/Headers/Public" "${PODS_ROOT}/Headers/Public/Forms"
OTHER_CFLAGS = $(inherited) -isystem "${PODS_ROOT}/Headers/Public" -isystem "${PODS_ROOT}/Headers/Public/Forms"
OTHER_LDFLAGS = $(inherited) -ObjC -l"Forms"
PODS_ROOT = ${SRCROOT}/Pods
```

我们由于需要配置网络环境，那可以这样写

```vim 
//网络请求baseurl
REQUESTBASE_URL = @"http:\\/\\/10.20.100.1"
```

当然也可以写成cocopods那样

```vim
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) WEBSERVICE_URL='$(REQUESTBASE_URL)' MESSAGE_SYSTEM_URL='$(MESSAGE_SYSTEM_URL)'

```

这里利用了一个GCC_PREPROCESSOR_DEFINITIONS编译参数。

>Space-separated list of option specifications. Specifies preprocessor macros in the form foo (for a simple #define) or foo=1 (for a value definition). This list is passed to the compiler through the gcc -D option when compiling precompiled headers and implementation files.

GCC_PREPROCESSOR_DEFINITIONS 是 GCC 预编译头参数，通常我们可以在 Project 文件下的 Build Settings 对预编译宏定义进行默认赋值。


它就是在Build Settings里面的 Apple LLVM 7.X - Preprocessing - Preprocessor Macros 这里。  

![](https://img.halfrost.com/Blog/ArticleImage/19_24.png)  


Preprocessor Macros 其实是按照 Configuration 选项进行默认配置的, 它是可以根据不同的环境预先制定不同定义的宏，或者为不同环境下的相同变量定义不同的值。

xcconfig 我们可以写入不同的 Configuration 选项配置不同的文件。每一个 xcconfig 可以配置 Build Settings 里的属性值, 其实实质就是通过 xcconfig 去修改 GCC_PREPROCESSOR_DEFINITIONS 的值，这样我们就可以做到动态配置环境的需求了。


最后还需要提的一点是，这个配置文件的level的问题。现在本地有这么多配置，到底哪一个最终生效呢？打开Build 里面的level，我们来看一个例子。

![](https://img.halfrost.com/Blog/ArticleImage/19_25.png)  



我们目前可以看到有5个配置，他们是有优先级的。优先级是从左往右，依次降低的。Resolved = target-level > project-level > 自定义配置文件 > iOS 默认配置。左边第一列永远显示的是当前生效的最终配置结果。

知道了这个优先级之后，我们可以更加灵活的配置我们的app了。


最后关于xcconfig配置，基本使用就这些了。但是这里面的学问不仅仅这些。

还能利用xcconfig动态配置Build Settings里面的很多参数。这其实类似于cocopods的做法。但是有一个大神的做法很优雅。值得大家感兴趣的人去学习学习。iOS大神[Justin Spahr-Summers](https://github.com/jspahrsummers)的开源库[xcconfigs](https://github.com/jspahrsummers/xcconfigs)提供了一个类权威的模板, 这是一个很好的学习使用xcconfig的库，强烈推荐。


最后这里有一个Demo，配置了Cocopods，配置了xcconfig文件，还有Build Configuration的，大家可以看看，请多多指教，[Demo](https://github.com/halfrost/Halfrost-Field/tree/master/contents/iOS/MultiEnvironmentsSettingDemo-master)。


#### 三.利用Targets来配置多环境

配置一个多环境其实一个Scheme和xcconfig已经完全够用了，为什么还要有这个第三点呢？虽说仅仅为了配置一个多环境这点“小事”，但是利用多个Targets也能实现需求，只不过有点“兴师动众”了。


关于构建Targets这个技术，我也是在2年前的公司实践过。当时的需求是做一个OEM的产品。自己公司有主要产品，也帮其他公司做OEM。一说到OEM，大家应该就知道Targets用到这里的妙用了。利用Targets可以瞬间大批量产生大量的app。

2013年巧哥也发过关于Targets的文章，[猿题库iOS客户端的技术细节（一）：使用多target来构建大量相似App](http://blog.devtang.com/2013/10/17/the-tech-detail-of-ape-client-1/)，我原来公司在2014年也实现了这种功能。

![](https://img.halfrost.com/Blog/ArticleImage/19_26.png)  

仅仅只用一套代码，就可以生产出7个app。7个app的证书都是不同的，配置也都不同，但是代码只需要维护一套代码，就可以完成维护7个app的目标。

下面我们来看看怎么新建Targets，有2种方法。

![](https://img.halfrost.com/Blog/ArticleImage/19_27.png)  


一种方法是完全新建一个Targets，另外一种方法是复制原有的Targets。

其实第一种方法建立出Targets，之后看你需求是怎么样的。如果也想是做OEM这种，可以把新建出来的project删掉，本地还是维护一套代码，然后在新建的Targets 的Build Phases里面去把本地现有代码加上，参数自己可以随意配置。这样也是一套代码维护多个app。

第二种方法就是复制一个原有的Targets，这种做法只用自己去改参数就可以了。

再来说说Targets的参数。

由于我们新建了Targets，相当于新建了一个app了。所以里面的所有的文件全部都可以更改。包括info.plist，源码引用，Build Settings……所有参数都可以改，这样就不仅仅局限于修改Scheme和xcconfig，所以之前说仅仅配置一个多环境用Targets有点兴师动众，但是它确实能完成目的。根据第二章里面我们也提到了，Targets相当于流水线，仅次于Project的地位，可以想象，有了Targets，我们没有什么不能修改的。


PS.最后关于Targets还有一点想说的，如果大家有多个app，并且这几个app之间有超过80%的代码都是完全一样的，或者说仅仅只是个别界面显示不同，逻辑都完全相同，建议大家用Targets来做，这样只需要维护一套代码就可以了。维护多套相同的代码，实在太没有效率了。一个bug需要在多套代码上面来回改动，费时费力。

这时候可能有人会问了，如果维护一套代码，以后这些app如果需求有不同怎么办？？比如要进入不同界面，跳转不同界面，页面也显示不同怎么办？？这个问题其实很简单。在Targets里面的**Compile Sources**里面是可以给每个不同的Targets添加不同的编译代码的。只需要在每个不同的Targets里面加入不同界面的代码进行编译就可以了，在跳转的那个界面加上宏，来控制不同的app跳转到相应界面。这样本地还是维护的一套代码，只不过每个Targets编译的代码就是这套代码的子集了。这样维护起来还是很方便。也实现了不同app不同界面，不同需求了。


#### 最后
其实这篇文章的需求源自于上篇Jenkins自动化持续集成，有一个需求是能打不同环境的包。之前没有Jenkins的时候就改改URL运行一遍就好，虽说做法不够优雅，但是也不麻烦。现在想持续集成，只好把环境都分好，参数配置正确，这样Jenkins可以一次性多个环境的包一起打。真正做到多环境的持续集成。


![](https://img.halfrost.com/Blog/ArticleImage/19_28.png)   

最后就可以打出不同环境的包了。请大家多多指教。

