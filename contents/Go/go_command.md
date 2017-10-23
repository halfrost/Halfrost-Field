<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-0b9a654a1c10804e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



## 引言

![](http://upload-images.jianshu.io/upload_images/1194012-49d72af68625a441.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Go 语言这两年在语言排行榜上的上升势头非常猛，Go 语言虽然是静态编译型语言，但是它却拥有脚本化的语法，支持多种编程范式(函数式和面向对象)。Go 语言最最吸引人的地方可能是其原生支持并发编程(语言层面原生支持和通过第三方库支持是有很大区别的)。Go 语言的对网络通信、并发和并行编程的支持度极高，从而可以更好地利用大量的分布式和多核的计算机。开发者可以通过 goroutine 这种轻量级线程的概念来实现这个目标，然后通过 channel 来实现各个 goroutine 之间的通信。他们实现了分段栈增长和 goroutine 在线程基础上多路复用技术的自动化。



![](http://upload-images.jianshu.io/upload_images/1194012-551cb2b164e7737b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2017年7月 TIOBE 语言排行榜 Go 首次进入前十。今天就让我们来探究探究 Go 的编译命令执行过程。


## 一. 理解 Go 的环境变量


### 1. GOROOT

该环境变量的值为 Go 语言的当前安装目录。

### 2. GOPATH

该环境变量的值为 Go 语言的工作区的**集合（意味着可以有很多个）**。工作区类似于工作目录。每个不同的目录之间用`：`分隔。（**不同操作系统，$GOPATH 列表分隔符不同，UNIX-like 使用 `:`冒号，Windows 使用`;`分号**）


>正因为搜索优先级和默认下载位置等原因，社区对于是否为每个项目单独设置环境变量，还是将所有项目组织到同一个工作空间内存在争议，有一个推荐的做法是写一个脚本工具，作用类似 Python Virtual Environment，在激活某个项目的时候，自动设置相关的环境变量。


工作区是放置 Go 源码文件的目录。一般情况下，Go 源码文件都需要存放到工作区中。

工作区一般会包含3个子文件夹，自己手动新建以下三个目录：src 目录，pkg 目录，bin 目录。


```go

/home/halfrost/gorepo
├── bin
├── pkg
└── src
```

这里需要额外说的一点：关于 IDE 新建 Go 项目。IDE 在新建完 Go 的项目以后，会自动的执行 go get 命令去把相应的基础包拉过来，
在这个过程中会新建 bin、pkg、src 三个目录。不用 IDE 的同学，需要自己手动创建这三个目录。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-95343de87d0bb0c2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


上图是 Atom 的 go-plus 插件在一个新的项目打开的时候，自动 go get 的一些基础包。

bin 目录里面存放的都是通过 go install 命令安装后，由 Go 命令源码文件生成的可执行文件（ 在 Mac 平台下是 Unix executable 文件，在 Windows 平台下是 exe 文件）。

>**注意**：有两种情况下，bin 目录会变得没有意义。
>1. 当设置了有效的 GOBIN 环境变量以后，bin 目录就变得没有意义。
>2. 如果 GOPATH 里面包含多个工作区路径的时候，必须设置 GOBIN 环境变量，否则就无法安装 Go 程序的可执行文件。
>

pkg 目录是用来存放通过 go install 命令安装后的代码包的归档文件(.a 文件)。归档文件的名字就是代码包的名字。所有归档文件都会被存放到该目录下的平台相关目录中，即在 $GOPATH\/pkg\/$GOOS\_$GOARCH 中，同样以代码包为组织形式。

这里有两个隐藏的环境变量，GOOS 和 GOARCH。这两个环境变量是不用我们设置的，系统就默认的。GOOS 是 Go 所在的操作系统类型，GOARCH 是 Go 所在的计算架构。平台相关目录是以
 $GOOS\_$GOARCH 命名的，Mac 平台上这个目录名就是 darwin\_amd64。


src 目录是以代码包的形式组织并保存 Go 源码文件的。每个代码包都和 src 目录下的文件夹一一对应。每个子目录都是一个代码包。



>代码包包名和文件目录名，不要求一致。比如文件目录叫 myPackage，但是代码包包名可以声明为 “package service”，但是同一个目录下的源码文件第一行声明的所属包，必须一致！


这里有一个**特例**，命令源码文件并不一定必须放在 src 文件夹中的。

**这里需要纠正一个错误的观点：“所有的 Go 的代码都要放在 GOPATH 目录下”（这个观点是错误的）**

说到这里需要谈到 Go 的源码文件分类：




![](http://upload-images.jianshu.io/upload_images/1194012-d3e3d56e460b424e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



如上图，分为三类：

（1）命令源码文件：

声明自己属于 main 代码包、包含无参数声明和结果声明的 main 函数。

命令源码文件被安装以后，GOPATH 如果只有一个工作区，那么相应的可执行文件会被存放当前工作区的 bin 文件夹下；如果有多个工作区，就会安装到 GOBIN 指向的目录下。


命令源码文件是 Go 程序的入口。

同一个代码包中最好也不要放多个命令源码文件。多个命令源码文件虽然可以分开单独 go run 运行起来，但是无法通过 go build 和 go install。

```vim

YDZ ~/LeetCode_Go/helloworld/src/me $  ls
helloworld.go  helloworldd.go

```

先说明一下，在上述文件夹中放了两个命令源码文件，同时都声明自己属于 main 代码包。helloworld.go 文件输出 hello world，helloworldd.go 文件输出 worldd hello。接下来执行 go build 和 go install ，看看会发生什么。

```vim

YDZ ~/LeetCode_Go/helloworld/src/me $  go build
# _/Users/YDZ/LeetCode_Go/helloworld/src/me
./helloworldd.go:7: main redeclared in this block
	previous declaration at ./helloworld.go:50

YDZ ~/LeetCode_Go/helloworld/src/me $  go install
# _/Users/YDZ/LeetCode_Go/helloworld/src/me
./helloworldd.go:7: main redeclared in this block
	previous declaration at ./helloworld.go:50

```

这也就证明了多个命令源码文件虽然可以分开单独 go run 运行起来，但是无法通过 go build 和 go install。

同理，如果命令源码文件和库源码文件也会出现这样的问题，库源码文件不能通过 go build 和 go install 这种常规的方法编译和安装。具体例子和上述类似，这里就不再贴代码了。

所以命令源码文件应该是被单独放在一个代码包中。

（2）库源码文件

库源码文件就是不具备命令源码文件上述两个特征的源码文件。存在于某个代码包中的普通的源码文件。

库源码文件被安装后，相应的归档文件（.a 文件）会被存放到当前工作区的 pkg 的平台相关目录下。

（3）测试源码文件

名称以 \_test.go 为后缀的代码文件，并且必须包含 Test 或者 Benchmark 名称前缀的函数。

```go

func TestXXX( t *testing.T) {

}

```

名称以 Test 为名称前缀的函数，只能接受 *testing.T 的参数，这种测试函数是功能测试函数。

```go

func BenchmarkXXX( b *testing.B) {

}

```

名称以 Benchmark 为名称前缀的函数，只能接受 *testing.B 的参数，这种测试函数是性能测试函数。

现在答案就很明显了：

命令源码文件是可以单独运行的。可以使用 go run 命令直接运行，也可以通过 go build 或 go install 命令得到相应的可执行文件。所以命令源码文件是可以在机器的任何目录下运行的。

举个例子：

比如平时我们在 LeetCode 上刷算法题，这时候写的就是一个程序，这就是命令源码文件，可以在电脑的任意一个文件夹新建一个 go 文件就可以开始刷题了，写完就可以运行，对比执行结果，答案对了就可以提交代码。


但是公司项目里面的代码就不能这样了，只能存放在 GOPATH 目录下。因为公司项目不可能只有命令源码文件的，肯定是包含库源码文件，甚至包含测试源码文件的。

### 3.GOBIN

该环境变量的值为 Go 程序的可执行文件的目录。

### 4.PATH
为了方便使用 Go 语言命令和 Go 程序的可执行文件，需要添加其值。追加的操作还是用`：`分隔。

```go

export PATH=$PATH:$GOBIN

```

以上就是关于 Go 的4个重要环境变量的理解。还有一些其他的环境变量，用 go env 命令就可以查看。

```vim

YDZ ~ $  go env
GOARCH="amd64"
GOBIN="/Users/YDZ/Ele_Project/clairstormeye/bin"
GOEXE=""
GOHOSTARCH="amd64"
GOHOSTOS="darwin"
GOOS="darwin"
GOPATH="/Users/YDZ/Ele_Project/clairstormeye"
GORACE=""
GOROOT="/usr/local/Cellar/go/1.8.3/libexec"
GOTOOLDIR="/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64"
GCCGO="gccgo"
CC="clang"
GOGCCFLAGS="-fPIC -m64 -pthread -fno-caret-diagnostics -Qunused-arguments -fmessage-length=0 -fdebug-prefix-map=/var/folders/66/dcf61ty92rgd_xftrsxgx5yr0000gn/T/go-build977187889=/tmp/go-build -gno-record-gcc-switches -fno-common"
CXX="clang++"
CGO_ENABLED="1"
PKG_CONFIG="pkg-config"
CGO_CFLAGS="-g -O2"
CGO_CPPFLAGS=""
CGO_CXXFLAGS="-g -O2"
CGO_FFLAGS="-g -O2"
CGO_LDFLAGS="-g -O2"

```

名称    | 说明
--------- | ------- 
CGO_ENABLED        | 指明 cgo 工具是否可用的标识
GOARCH        | 程序构建环境的目标计算架构
GOBIN      | 存放可执行文件的目录的绝对路径
GOCHAR | 程序构建环境的目标计算架构的单字符标识
GOEXE      | 可执行文件的后缀
GOHOSTARCH       | 程序运行环境的目标计算架构
GOOS       | 程序构建环境的目标操作系统
GOHOSTOS       | 程序运行环境的目标操作系统
GOPATH       | 工作区目录的绝对路径
GORACE       | 用于数据竞争检测的相关选项
GOROOT       |  Go 语言的安装目录的绝对路径
GOTOOLDIR       | Go 工具目录的绝对路径



在探索 Go 的编译命令之前，需要说明的一点是：

Go 程序是通过 package 来组织的。

package <pkgName>（假设我们的例子中是 package main）这一行告诉我们当前文件属于哪个包，而包名 main 则告诉我们它是一个可独立运行的包，它在编译后会产生可执行文件。除了 main 包之外，其它的包最后都会生成 *.a 文件（也就是包文件）并放置在 $GOPATH/pkg/$GOOS\_$GOARCH中（以 Mac 为例就是
 $GOPATH/pkg/darwin\_amd64 ）。


Go 使用 package（和 Python 的模块类似）来组织代码。main.main() 函数(这个函数位于主包）是每一个独立的可运行程序的入口点。

>每一个可独立运行的 Go 程序，必定包含一个 package main，在这个 main 包中必定包含一个入口函数 main，而这个函数既没有参数，也没有返回值。


## 二. 初探 Go 的编译过程

目前 Go 最新版1.8.3里面基本命令只有以下的16个。

```go

	build       compile packages and dependencies
	clean       remove object files
	doc         show documentation for package or symbol
	env         print Go environment information
	bug         start a bug report
	fix         run go tool fix on packages
	fmt         run gofmt on package sources
	generate    generate Go files by processing source
	get         download and install packages and dependencies
	install     compile and install packages and dependencies
	list        list packages
	run         compile and run Go program
	test        test packages
	tool        run specified go tool
	version     print Go version
	vet         run go tool vet on packages



```

其中和编译相关的有 build、get、install、run 这4个。接下来就依次看看这四个的作用。

在详细分析这4个命令之前，先罗列一下通用的命令标记，以下这些命令都可适用的：

名称    | 说明
--------- | ------- 
-a        | 用于强制重新编译所有涉及的 Go 语言代码包（包括 Go 语言标准库中的代码包），即使它们已经是最新的了。该标记可以让我们有机会通过改动底层的代码包做一些实验。
-n        | 使命令仅打印其执行过程中用到的所有命令，而不去真正执行它们。如果不只想查看或者验证命令的执行过程，而不想改变任何东西，使用它正好合适。
-race      | 用于检测并报告指定 Go 语言程序中存在的数据竞争问题。当用 Go 语言编写并发程序的时候，这是很重要的检测手段之一。
-v | 用于打印命令执行过程中涉及的代码包。这一定包括我们指定的目标代码包，并且有时还会包括该代码包直接或间接依赖的那些代码包。这会让你知道哪些代码包被执行过了。
-work      | 用于打印命令执行时生成和使用的临时工作目录的名字，且命令执行完成后不删除它。这个目录下的文件可能会对你有用，也可以从侧面了解命令的执行过程。如果不添加此标记，那么临时工作目录会在命令执行完毕前删除。
-x       | 使命令打印其执行过程中用到的所有命令，并同时执行它们。


### 1. go run

专门用来运行命令源码文件的命令，**注意，这个命令不是用来运行所有 Go 的源码文件的！**


go run 命令只能接受一个命令源码文件以及若干个库源码文件（必须同属于 main 包）作为文件参数，且**不能接受测试源码文件**。它在执行时会检查源码文件的类型。如果参数中有多个或者没有命令源码文件，那么 go run 命令就只会打印错误提示信息并退出，而不会继续执行。


这个命令具体干了些什么事情呢？来分析分析：

```vim

YDZ ~/LeetCode_Go/helloworld/src/me $  go run -n helloworld.go

#
# command-line-arguments
#

mkdir -p $WORK/command-line-arguments/_obj/
mkdir -p $WORK/command-line-arguments/_obj/exe/
cd /Users/YDZ/LeetCode_Go/helloworld/src/me
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/compile -o $WORK/command-line-arguments.a -trimpath $WORK -p main -complete -buildid 2841ae50ca62b7a3671974e64d76e198a2155ee7 -D _/Users/YDZ/LeetCode_Go/helloworld/src/me -I $WORK -pack ./helloworld.go
cd .
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/link -o $WORK/command-line-arguments/_obj/exe/helloworld -L $WORK -w -extld=clang -buildmode=exe -buildid=2841ae50ca62b7a3671974e64d76e198a2155ee7 $WORK/command-line-arguments.a
$WORK/command-line-arguments/_obj/exe/helloworld



```

这里可以看到创建了两个临时文件夹 \_obj 和 exe，先执行了 compile 命令，然后 link，生成了归档文件.a 和 最终可执行文件，最终的可执行文件放在 exe 文件夹里面。命令的最后一步就是执行了可执行文件。

总结一下如下图：

![](http://upload-images.jianshu.io/upload_images/1194012-a03bf806d1cd810a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)




举个例子，生成的临时文件可以用`go run -work`看到，比如当前生成的临时文件夹是如下的路径：

```vim

/var/folders/66/dcf61ty92rgd_xftrsxgx5yr0000gn/T/go-build876472071

```

打印目录结构：

```vim

├── command-line-arguments
│   └── _obj
│       └── exe
│           └── helloworld
└── command-line-arguments.a

```

可以看到，最终`go run`命令是生成了2个文件，一个是归档文件，一个是可执行文件。command-line-arguments 这个归档文件是 Go 语言为命令源码文件临时指定的一个代码包。在接下来的几个命令中，生成的临时代码包都叫这个名字。


go run 命令在第二次执行的时候，如果发现导入的代码包没有发生变化，那么 go run 不会再次编译这个导入的代码包。直接静态链接进来。

```vim

go run -a

```

加上`-a`的标记可以强制编译所有的代码，即使归档文件.a存在，也会重新编译。

如果嫌弃编译速度慢，可以加上`-p n`，这个是并行编译，n是并行的数量。n一般为逻辑 CPU 的个数。


### 2. go build

当代码包中有且仅有一个命令源码文件的时候，在文件夹所在目录中执行 go build 命令，会在该目录下生成一个与目录同名的可执行文件。

```vim

// 假设当前文件夹名叫 myGoRepo

YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go
YDZ：~/helloworld/src/myGoRepo $ go build
YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go  myGoRepo

```

于是在当前目录直接生成了以当前文件夹为名的可执行文件（ 在 Mac 平台下是 Unix executable 文件，在 Windows 平台下是 exe 文件）

我们先记录一下这个可执行文件的 md5 值

```vim

YDZ ~/helloworld/src/myGoRepo $  md5 /Users/YDZ/helloworld/src/myGoRepo/myGoRepo
MD5 (/Users/YDZ/helloworld/src/myGoRepo/myGoRepo) = 1f23f6efec752ed34b9bd22b5fa1ddce

```


但是这种情况下，如果使用 go install 命令，如果 GOPATH 里面只有一个工作区，就会在当前工作区的 bin 目录下生成相应的可执行文件。如果 GOPATH 下有多个工作区，则是在 GOBIN 下生成对应的可执行文件。

咱们先接着刚刚 go build 继续操作。

```vim

YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go myGoRepo
YDZ：~/helloworld/src/myGoRepo $ go install
YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go 

```

执行完 go install 会发现可执行文件不见了！去哪里了呢？其实是被移动到了 bin 目录下了（如果 GOPATH 下有多个工作区，就会放在
 GOBIN 目录下）。

```vim

YDZ：~/helloworld/bin $ ls
myGoRepo

```

再来比对一下这个文件的 md5 值：

```vim

YDZ ~/helloworld/bin $  md5 /Users/YDZ/helloworld/bin/myGoRepo
MD5 (/Users/YDZ/helloworld/bin/myGoRepo) = 1f23f6efec752ed34b9bd22b5fa1ddce

```

和 go build 命令执行出来的可执行文件完全一致。我们可以大胆猜想，是把刚刚 go build 命令执行出来的可执行文件移动到了 bin 目录下（如果 GOPATH 下有多个工作区，就会放在 GOBIN 目录下）。

那 go build 和 go install 究竟干了些什么呢？

这个问题一会再来解释，先来说说 go build。

go build 用于编译我们指定的源码文件或代码包以及它们的依赖包。，但是**注意如果用来编译非命令源码文件，即库源码文件，go build 执行完是不会产生任何结果的。这种情况下，go build 命令只是检查库源码文件的有效性，只会做检查性的编译，而不会输出任何结果文件。**

go build 编译命令源码文件，则会在该命令的执行目录中生成一个可执行文件，上面的例子也印证了这个过程。

go build 后面不追加目录路径的话，它就把当前目录作为代码包并进行编译。go build 命令后面如果跟了代码包导入路径作为参数，那么该代码包及其依赖都会被编译。

go run 的`-a`标记在 go build 这里同样奏效，go build 加了`-a`强制编译所有涉及到的代码包，不加`-a`只会编译归档文件不是最新的代码包。

go build 使用`-o`标记可以指定输出文件（在这个示例中指的是可执行文件）的名称。它是最常用的一个 go build 命令标记。但需要注意的是，当使用标记`-o`的时候，不能同时对多个代码包进行编译。

标记`-i`会使 go build 命令安装那些编译目标依赖的且还未被安装的代码包。这里的安装意味着产生与代码包对应的归档文件，并将其放置到当前工作区目录的 pkg 子目录的相应子目录中。在默认情况下，这些代码包是不会被安装的。

go build 常用的一些标记如下：

标记名称      | 标记描述
|:-------|:-------:|
-a           | 强行对所有涉及到的代码包（包含标准库中的代码包）进行重新构建，即使它们已经是最新的了。
-n           | 打印编译期间所用到的其它命令，但是并不真正执行它们。
-p n         | 指定编译过程中执行各任务的并行数量（确切地说应该是并发数量）。在默认情况下，该数量等于CPU的逻辑核数。但是在`darwin/arm`平台（即iPhone和iPad所用的平台）下，该数量默认是`1`。
-race        | 开启竞态条件的检测。不过此标记目前仅在`linux/amd64`、`freebsd/amd64`、`darwin/amd64`和`windows/amd64`平台下受到支持。
-v           | 打印出那些被编译的代码包的名字。
-work        | 打印出编译时生成的临时工作目录的路径，并在编译结束时保留它。在默认情况下，编译结束时会删除该目录。
-x           | 打印编译期间所用到的其它命令。注意它与`-n`标记的区别。


go build 命令究竟做了些什么呢？我们来打印一下每一步的执行过程。先看看命令源码文件执行了 go build 干了什么事情。

```vim

#
# command-line-arguments
#

mkdir -p $WORK/command-line-arguments/_obj/
mkdir -p $WORK/command-line-arguments/_obj/exe/
cd /Users/YDZ/MyGitHub/LeetCode_Go/helloworld/src/me
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/compile -o $WORK/command-line-arguments.a -trimpath $WORK -p main -complete -buildid 2841ae50ca62b7a3671974e64d76e198a2155ee7 -D _/Users/YDZ/MyGitHub/LeetCode_Go/helloworld/src/me -I $WORK -pack ./helloworld.go
cd .
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/link -o $WORK/command-line-arguments/_obj/exe/a.out -L $WORK -extld=clang -buildmode=exe -buildid=2841ae50ca62b7a3671974e64d76e198a2155ee7 $WORK/command-line-arguments.a
mv $WORK/command-line-arguments/_obj/exe/a.out helloworld

```

可以看到，执行过程和 go run 大体相同，唯一不同的就是在最后一步，go run 是执行了可执行文件，但是 go build 命令是把可执行文件移动到了当前目录的文件夹中。

打印看看生成的临时文件夹的树形结构

```vim

.
├── command-line-arguments
│   └── _obj
│       └── exe
└── command-line-arguments.a

```

和 go run 命令的结构基本一致，唯一的不同可执行文件不在 exe 文件夹中了，被移动到了当前执行 go build 的文件夹中了。

在来看看库源码文件执行了 go build 以后干了什么事情：

```vim

#
# _/Users/YDZ/Downloads/goc2p-master/src/pkgtool
#

mkdir -p $WORK/_/Users/YDZ/Downloads/goc2p-master/src/pkgtool/_obj/
mkdir -p $WORK/_/Users/YDZ/Downloads/goc2p-master/src/
cd /Users/YDZ/Downloads/goc2p-master/src/pkgtool
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/compile -o $WORK/_/Users/YDZ/Downloads/goc2p-master/src/pkgtool.a -trimpath $WORK -p _/Users/YDZ/Downloads/goc2p-master/src/pkgtool -complete -buildid cef542c3da6d3126cdae561b5f6e1470aff363ba -D _/Users/YDZ/Downloads/goc2p-master/src/pkgtool -I $WORK -pack ./envir.go ./fpath.go ./ipath.go ./pnode.go ./util.go

```

这里可以看到 go build 命令只是把库源码文件编译了一遍，其他什么事情都没有干。

再看看生成的临时文件夹的树形结构

```vim

.
└── _
    └── Users
        └── YDZ
            └── Downloads
                └── goc2p-master
                    └── src
                        ├── pkgtool
                        │   └── _obj
                        └── pkgtool.a

```

可以看到它的目录结构层级前段部分是该代码包所在本机的路径的相对路径。然后生成了归档文件 .a 文件。


总结一下如下图：

![](http://upload-images.jianshu.io/upload_images/1194012-c1b0dd9175c4f04a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



关于 go build 和 go install 的不同，接下来分析完 go install 就会明白了，接下来继续看 go install。


### 3. go install

go install 命令是用来编译并安装代码包或者源码文件的。

go install 用于编译并安装指定的代码包及它们的依赖包。当指定的代码包的依赖包还没有被编译和安装时，该命令会先去处理依赖包。与 go build 命令一样，传给 go install 命令的代码包参数应该以导入路径的形式提供。并且，go build 命令的绝大多数标记也都可以用于
 go install 命令。实际上，go install 命令只比 go build 命令多做了一件事，即：安装编译后的结果文件到指定目录。

安装代码包会在当前工作区的 pkg 的平台相关目录下生成归档文件（即 .a 文件）。
安装命令源码文件会在当前工作区的 bin 目录（如果 GOPATH 下有多个工作区，就会放在 GOBIN 目录下）生成可执行文件。

同样，go install 命令如果后面不追加任何参数，它会把当前目录作为代码包并安装。这和 go build 命令是完全一样的。

go install 命令后面如果跟了代码包导入路径作为参数，那么该代码包及其依赖都会被安装。

go install 命令后面如果跟了命令源码文件以及相关库源码文件作为参数的话，只有这些文件会被编译并安装。

go install 命令究竟做了些什么呢？我们来打印一下每一步的执行过程。

```vim

#
# command-line-arguments
#

mkdir -p $WORK/command-line-arguments/_obj/
mkdir -p $WORK/command-line-arguments/_obj/exe/
cd /Users/YDZ/MyGitHub/LeetCode_Go/helloworld/src/me
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/compile -o $WORK/command-line-arguments.a -trimpath $WORK -p main -complete -buildid 2841ae50ca62b7a3671974e64d76e198a2155ee7 -D _/Users/YDZ/MyGitHub/LeetCode_Go/helloworld/src/me -I $WORK -pack ./helloworld.go
cd .
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/link -o $WORK/command-line-arguments/_obj/exe/a.out -L $WORK -extld=clang -buildmode=exe -buildid=2841ae50ca62b7a3671974e64d76e198a2155ee7 $WORK/command-line-arguments.a
mkdir -p /Users/YDZ/Ele_Project/clairstormeye/bin/
mv $WORK/command-line-arguments/_obj/exe/a.out /Users/YDZ/Ele_Project/clairstormeye/bin/helloworld

```

前面几步依旧和 go run 、go build 完全一致，只是最后一步的差别，go install 会把命令源码文件安装到当前工作区的 bin 目录（如果 GOPATH 下有多个工作区，就会放在 GOBIN 目录下）。如果是库源码文件，就会被安装到当前工作区的 pkg 的平台相关目录下。


还是来看看 go install 生成的临时文件夹的结构：

```vim

.
├── command-line-arguments
│   └── _obj
│       └── exe
└── command-line-arguments.a

```

结构和运行了 go build 命令一样，最终生成的文件也都被移动到了相对应的目标目录中。


总结一下如下图：

![](http://upload-images.jianshu.io/upload_images/1194012-1a75a9e2080aecd8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在安装多个库源码文件时有可能遇到如下的问题：

```go
hc@ubt:~/golang/goc2p/src/pkgtool$ go install envir.go fpath.go ipath.go pnode.go util.go
go install: no install location for .go files listed on command line (GOBIN not set)
```

而且，在我们为环境变量 GOBIN 设置了正确的值之后，这个错误提示信息仍然会出现。这是因为，只有在安装命令源码文件的时候，命令程序才会将环境变量 GOBIN 的值作为结果文件的存放目录。而在安装库源码文件时，在命令程序内部的代表结果文件存放目录路径的那个变量不会被赋值。最后，命令程序会发现它依然是个无效的空值。所以，命令程序会同样返回一个关于“无安装位置”的错误。这就引出一个结论，我们只能使用安装代码包的方式来安装库源码文件，而不能在 go install 命令罗列并安装它们。另外，go install 命令目前无法接受标记`-o`以自定义结果文件的存放位置。这也从侧面说明了
 go install 命令不支持针对库源码文件的安装操作。



### 4. go get

go get 命令用于从远程代码仓库（比如 Github ）上下载并安装代码包。**注意，go get 命令会把当前的代码包下载到 $GOPATH 中的第一个工作区的 src 目录中，并安装。**


>使用 go get 下载第三方包的时候，依旧会下载到 $GOPATH 的第一个工作空间，而非 vendor 目录。当前工作链中并没有真正意义上的包依赖管理，不过好在有不少第三方工具可选。


如果在 go get 下载过程中加入`-d` 标记，那么下载操作只会执行下载动作，而不执行安装动作。比如有些非常特殊的代码包在安装过程中需要有特殊的处理，所以我们需要先下载下来，所以就会用到`-d` 标记。


还有一个很有用的标记是`-u`标记，加上它可以利用网络来更新已有的代码包及其依赖包。如果已经下载过一个代码包，但是这个代码包又有更新了，那么这时候可以直接用`-u`标记来更新本地的对应的代码包。如果不加这个`-u`标记，执行 go get 一个已有的代码包，会发现命令什么都不执行。只有加了`-u`标记，命令会去执行 git pull 命令拉取最新的代码包的最新版本，下载并安装。

命令 go get 还有一个很值得称道的功能——智能下载。在使用它检出或更新代码包之后，它会寻找与本地已安装 Go 语言的版本号相对应的标签（tag）或分支（branch）。比如，本机安装 Go 语言的版本是1.x，那么 go get 命令会在该代码包的远程仓库中寻找名为 “go1” 的标签或者分支。如果找到指定的标签或者分支，则将本地代码包的版本切换到此标签或者分支。如果没有找到指定的标签或者分支，则将本地代码包的版本切换到主干的最新版本。

go get 常用的一些标记如下：

标记名称    | 标记描述 
--------- | ------- 
-d        | 让命令程序只执行下载动作，而不执行安装动作。
-f        | 仅在使用`-u`标记时才有效。该标记会让命令程序忽略掉对已下载代码包的导入路径的检查。如果下载并安装的代码包所属的项目是你从别人那里 Fork 过来的，那么这样做就尤为重要了。
-fix      | 让命令程序在下载代码包后先执行修正动作，而后再进行编译和安装。
-insecure | 允许命令程序使用非安全的 scheme（如 HTTP ）去下载指定的代码包。如果你用的代码仓库（如公司内部的 Gitlab ）没有HTTPS 支持，可以添加此标记。请在确定安全的情况下使用它。
-t        | 让命令程序同时下载并安装指定的代码包中的测试源码文件中依赖的代码包。
-u        | 让命令利用网络来更新已有代码包及其依赖包。默认情况下，该命令只会从网络上下载本地不存在的代码包，而不会更新已有的代码包。

go get 命令究竟做了些什么呢？我们还是来打印一下每一步的执行过程。

```vim


cd .
git clone https://github.com/go-errors/errors /Users/YDZ/Ele_Project/clairstormeye/src/github.com/go-errors/errors
cd /Users/YDZ/Ele_Project/clairstormeye/src/github.com/go-errors/errors
git submodule update --init --recursive
cd /Users/YDZ/Ele_Project/clairstormeye/src/github.com/go-errors/errors
git show-ref
cd /Users/YDZ/Ele_Project/clairstormeye/src/github.com/go-errors/errors
git submodule update --init --recursive
WORK=/var/folders/66/dcf61ty92rgd_xftrsxgx5yr0000gn/T/go-build124856678
mkdir -p $WORK/github.com/go-errors/errors/_obj/
mkdir -p $WORK/github.com/go-errors/
cd /Users/YDZ/Ele_Project/clairstormeye/src/github.com/go-errors/errors
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/compile -o $WORK/github.com/go-errors/errors.a -trimpath $WORK -p github.com/go-errors/errors -complete -buildid bb3526a8c1c21853f852838637d531b9fcd57d30 -D _/Users/YDZ/Ele_Project/clairstormeye/src/github.com/go-errors/errors -I $WORK -pack ./error.go ./parse_panic.go ./stackframe.go
mkdir -p /Users/YDZ/Ele_Project/clairstormeye/pkg/darwin_amd64/github.com/go-errors/
mv $WORK/github.com/go-errors/errors.a /Users/YDZ/Ele_Project/clairstormeye/pkg/darwin_amd64/github.com/go-errors/errors.a

```

这里可以很明显的看到，执行完 go get 命令以后，会调用 git clone 方法下载源码，并编译，最终会把库源码文件编译成归档文件安装到 pkg 对应的相关平台目录下。


总结一下如下图：


![](http://upload-images.jianshu.io/upload_images/1194012-332a021cc97af1c0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


关于工作区的问题，这里额外提一下：

一般情况下，为了分离自己与第三方的代码，我们会设置两个或更多的工作区。我们现在有一个目录路径为 /home/hc/golang/lib 的工作区，并且它是环境变量 GOPATH 值中的第一个目录路径。注意，环境变量 GOPATH 中包含的路径不能与环境变量GOROOT的值重复。好了，如果我们使用 go get 命令下载和安装代码包，那么这些代码包都会被安装在上面这个工作区中。我们暂且把这个工作区叫做
 Lib 工作区。


> 如果使用 vendor 管理依赖的话，常用命令是：  
> 1. go get -u -x -a github.com/golang/geo/s2  
> 2. rm -rf Godeps vendor && make dep



## 三. 静态链接 or 动态链接 ？

Go 在最初刚刚发布的时候，静态链接被当做优点宣传，只须编译后的一个可执行文件，无须附加任何东西就能部署。将运行时、依赖库直接打包到可执行文件内部，简化了部署和发布的操作，无须事先安装运行环境和下载诸多第三方库。不过最新版本却又加入了动态链接的内容了。

普通的 go build 、go install 用的都是静态链接。可以验证一下：



![](http://upload-images.jianshu.io/upload_images/1194012-6d22852191014329.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上图是笔者用 MachOView 打开的 gofmt 文件，可以看到 fmt.Println 的地址是确定的，所以可以确定是静态链接的。

目前最新版的 Go 是如何支持动态链接的呢？

在 go build 、go install 的时候加上 -buildmode 参数。 

这些是以下 buildmode 的选项：

archive: 将非 main 包构建为 .a 文件 . main 包将被忽略。
c-archive: 将 main 软件包及其导入的所有软件包构建到 C 归档文件中
c-shared: 将列出的主要软件包，以及它们导入的所有软件包构建到
 C 动态库中。
shared: 将所有列出的非 main 软件包合并到一个动态库中。
exe: 构建列出的 main 包及其导入到可执行文件中的一切。 将忽略未命名为 main 的包。
默认情况下，列出的 main 软件包内置到可执行文件中，列出的非
 main 软件包内置到 .a 文件中。


关于动态库，笔者还没有实践过，这里就不继续深入了，以后充分实践后，再开一篇单独的文章谈谈 Go 的动态链接。这里只是想说明一点，Go 目前不仅仅只有静态链接，动态链接也支持了！


------------------------------------------------------

Reference：  
[《GO 命令教程》](https://github.com/hyper0x/go_command_tutorial)  
《Go 并发编程实战》


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_command/](https://halfrost.com/go_command/)