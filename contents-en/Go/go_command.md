<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-0b9a654a1c10804e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


## Introduction

![](http://upload-images.jianshu.io/upload_images/1194012-49d72af68625a441.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Go has been rising very rapidly in programming language rankings over the past two years. Although Go is a statically compiled language, it has a scripting-like syntax and supports multiple programming paradigms (functional and object-oriented). What may be most attractive about Go is its native support for concurrent programming (there is a big difference between native language-level support and support via third-party libraries). Go provides extremely strong support for network communication, concurrency, and parallel programming, making it better able to leverage large numbers of distributed and multi-core computers. Developers can achieve this through the concept of goroutine, a lightweight thread, and then use channel to enable communication between goroutines. Go automates segmented stack growth and the multiplexing of goroutines on top of threads.


![](http://upload-images.jianshu.io/upload_images/1194012-551cb2b164e7737b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

In July 2017, Go entered the top ten of the TIOBE programming language ranking for the first time. Today, let’s take a look at how Go’s compile commands are executed.


## I. Understanding Go Environment Variables


### 1. GOROOT

The value of this environment variable is the current installation directory of the Go language.

### 2. GOPATH

The value of this environment variable is the **set (meaning there can be many)** of Go workspaces. A workspace is similar to a working directory. Different directories are separated by `：`. (**The $GOPATH list separator differs by operating system: UNIX-like systems use `:` colon, while Windows uses `;` semicolon.**)


>It is precisely because of factors such as search priority and the default download location that the community has debated whether to set environment variables separately for each project or to organize all projects within the same workspace. One recommended approach is to write a scripting tool similar in purpose to Python Virtual Environment, which automatically sets the relevant environment variables when a given project is activated.


A workspace is a directory that contains Go source files. In general, Go source files need to be stored in a workspace.

A workspace typically contains three subdirectories. Manually create the following three directories: the src directory, the pkg directory, and the bin directory.
```go

/home/halfrost/gorepo
├── bin
├── pkg
└── src
```
One additional point needs to be mentioned here: creating a new Go project in an IDE. After an IDE creates a new Go project, it automatically runs the go get command to fetch the corresponding base packages. During this process, it creates three directories: bin, pkg, and src. If you are not using an IDE, you need to create these three directories manually.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-95343de87d0bb0c2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The image above shows some base packages that Atom’s go-plus plugin automatically fetches via go get when a new project is opened.

The bin directory stores executable files generated from Go command source files after installation via the go install command. On macOS, these are Unix executable files; on Windows, they are exe files.

>**Note**: In two cases, the bin directory becomes meaningless.
>1. Once a valid GOBIN environment variable is set, the bin directory becomes meaningless.
>2. If GOPATH contains multiple workspace paths, the GOBIN environment variable must be set; otherwise, executable files for Go programs cannot be installed.
>

The pkg directory is used to store archive files (.a files) for code packages after they are installed via the go install command. The name of an archive file is the name of the code package. All archive files are stored under the platform-specific directory in this directory, namely $GOPATH\/pkg\/$GOOS\_$GOARCH, and are likewise organized by code package.

There are two hidden environment variables here: GOOS and GOARCH. We do not need to set these two environment variables; they are provided by the system by default. GOOS is the operating system type where Go is running, and GOARCH is the processor architecture where Go is running. The platform-specific directory is named after
 $GOOS\_$GOARCH. On macOS, this directory name is darwin\_amd64.


The src directory organizes and stores Go source files in the form of code packages. Each code package corresponds one-to-one with a folder under the src directory. Each subdirectory is a code package.


>The code package name and the directory name do not have to be the same. For example, the directory may be named myPackage, while the code package name can be declared as “package service”. However, the package declaration on the first line of source files in the same directory must be consistent!


There is a **special case** here: command source files do not necessarily have to be placed in the src directory.

**A misconception needs to be corrected here: “All Go code must be placed under the GOPATH directory” (this view is incorrect).**

At this point, we need to talk about the classification of Go source files:


![](http://upload-images.jianshu.io/upload_images/1194012-d3e3d56e460b424e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As shown above, they are divided into three categories:

(1) Command source files:

These declare that they belong to the main code package and contain a main function with no parameter declarations and no result declarations.

After command source files are installed, if GOPATH has only one workspace, the corresponding executable file is stored in the bin directory of the current workspace; if there are multiple workspaces, it is installed into the directory pointed to by GOBIN.


Command source files are the entry point of a Go program.

It is also best not to place multiple command source files in the same code package. Although multiple command source files can be run separately with go run, they cannot be processed via go build and go install.
```vim

YDZ ~/LeetCode_Go/helloworld/src/me $  ls
helloworld.go  helloworldd.go

```
First, note that the above directory contains two command source files, and both declare themselves as belonging to the `main` package. The `helloworld.go` file outputs `hello world`, while the `helloworldd.go` file outputs `worldd hello`. Next, run `go build` and `go install` and see what happens.
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
This also proves that although multiple command source files can be run separately with `go run`, they cannot be processed with `go build` or `go install`.

Similarly, command source files and library source files can also run into this issue. Library source files cannot be compiled and installed using conventional methods such as `go build` and `go install`. The concrete examples are similar to the above, so the code is not shown here.

Therefore, command source files should be placed in a separate code package.

(2) Library source files

Library source files are source files that do not have the two characteristics of command source files described above. They are ordinary source files that exist in a code package.

After a library source file is installed, the corresponding archive file (`.a` file) is stored under the platform-specific directory of `pkg` in the current workspace.

(3) Test source files

A code file whose name has the suffix `_test.go`, and which must contain functions whose names have the prefix `Test` or `Benchmark`.
```go

func TestXXX( t *testing.T) {

}

```
Functions whose names are prefixed with `Test` can only accept a `*testing.T` parameter; this kind of test function is a functional test function.
```go

func BenchmarkXXX( b *testing.B) {

}

```
Functions whose names are prefixed with Benchmark can only accept a parameter of type *testing.B. This kind of test function is a benchmark function.

Now the answer is obvious:

Command source files can be run independently. You can run them directly with the go run command, or use go build or go install to generate the corresponding executable file. Therefore, command source files can be run from any directory on the machine.

For example:

When we practice algorithm problems on LeetCode, the code we write is a program, which is a command source file. We can create a new Go file in any folder on the computer and start solving problems. After writing it, we can run it, compare the execution result, and submit the code if the answer is correct.


However, code in company projects cannot be handled this way; it can only be stored under the GOPATH directory. This is because company projects cannot consist only of command source files; they will certainly include library source files, and may even include test source files.

### 3.GOBIN

The value of this environment variable is the directory for executable files of Go programs.

### 4.PATH
To make it convenient to use Go language commands and executable files of Go programs, its value needs to be added. The append operation still uses `:` as the separator.
```go

export PATH=$PATH:$GOBIN

```
That’s the explanation of four important Go environment variables. There are also some other environment variables, which you can view with the `go env` command.
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
Name    | Description
--------- | ------- 
CGO_ENABLED        | Flag indicating whether the cgo tool is available
GOARCH        | Target compute architecture for the program build environment
GOBIN      | Absolute path to the directory where executable files are stored
GOCHAR | Single-character identifier for the target compute architecture of the program build environment
GOEXE      | Executable file suffix
GOHOSTARCH       | Target compute architecture for the program runtime environment
GOOS       | Target operating system for the program build environment
GOHOSTOS       | Target operating system for the program runtime environment
GOPATH       | Absolute path to the workspace directory
GORACE       | Options related to data race detection
GOROOT       | Absolute path to the Go installation directory
GOTOOLDIR       | Absolute path to the Go tools directory


Before exploring Go's compile commands, one point needs to be clarified:

Go programs are organized by package.

The line package <pkgName> (assume it is package main in our example) tells us which package the current file belongs to, and the package name main tells us that it is an independently runnable package, which will produce an executable after compilation. Except for the main package, all other packages eventually generate *.a files (that is, package files) and are placed in $GOPATH/pkg/$GOOS\_$GOARCH (on Mac, for example, this is
 $GOPATH/pkg/darwin\_amd64 ).


Go uses packages (similar to Python modules) to organize code. The main.main() function (this function is in the main package) is the entry point for every standalone runnable program.

>Every independently runnable Go program must contain a package main, and this main package must contain an entry function main. This function has neither parameters nor return values.


## II. First Look at Go's Compilation Process

As of the current latest Go version, 1.8.3, there are only the following 16 basic commands.
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
Among these, the ones related to compilation are `build`, `get`, `install`, and `run`. Next, let’s look at what each of these four does.

Before analyzing these four commands in detail, let’s first list some common command flags that apply to all of the following commands:

Name    | Description
--------- | ------- 
-a        | Forces recompilation of all involved Go packages (including packages in the Go standard library), even if they are already up to date. This flag gives us a chance to run experiments by modifying lower-level packages.
-n        | Makes the command only print all commands it would use during execution, without actually running them. If you only want to inspect or verify the execution process without changing anything, this is exactly the right option.
-race      | Detects and reports data races in the specified Go program. When writing concurrent programs in Go, this is one of the important detection mechanisms.
-v | Prints the packages involved during command execution. This will definitely include the target package we specify, and sometimes also includes packages that the target package directly or indirectly depends on. This lets you know which packages have been processed.
-work      | Prints the name of the temporary work directory generated and used during command execution, and does not delete it after the command completes. The files in this directory may be useful to you, and they can also help you understand the command’s execution process indirectly. If this flag is not added, the temporary work directory will be deleted before the command finishes.
-x       | Makes the command print all commands used during execution and execute them at the same time.


### 1. go run

A command specifically used to run command source files. **Note that this command is not used to run all Go source files!**


The `go run` command can only accept one command source file and several library source files (which must all belong to the `main` package) as file arguments, and it **cannot accept test source files**. During execution, it checks the types of the source files. If there are multiple command source files among the arguments, or none at all, the `go run` command will only print an error message and exit; it will not continue execution.


What exactly does this command do? Let’s analyze it:
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
Here you can see that two temporary directories, \_obj and exe, are created. The compile command is run first, followed by link, producing an archive file .a and the final executable. The final executable is placed in the exe directory. The last step of the command is to run the executable.

Summarized as shown below:

![](http://upload-images.jianshu.io/upload_images/1194012-a03bf806d1cd810a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


For example, you can view the generated temporary files with `go run -work`; for instance, the temporary directory currently generated is at the following path:
```vim

/var/folders/66/dcf61ty92rgd_xftrsxgx5yr0000gn/T/go-build876472071

```
Print the directory structure:
```vim

├── command-line-arguments
│   └── _obj
│       └── exe
│           └── helloworld
└── command-line-arguments.a

```
As you can see, the final `go run` command generates two files: an archive file and an executable file. The archive file command-line-arguments is a package name that Go temporarily assigns to command source files. In the next few commands, the generated temporary package will use this same name.

When the `go run` command is executed a second time, if it finds that the imported packages have not changed, `go run` will not compile those imported packages again. It simply statically links them in.
```vim

go run -a

```
Adding the `-a` flag forces all code to be compiled; even if the archive file `.a` already exists, it will be recompiled.

If you find compilation too slow, you can add `-p n`. This enables parallel compilation, where `n` is the degree of parallelism. In general, `n` should be the number of logical CPUs.


### 2. go build

When a code package contains exactly one command source file, running the go build command in the directory containing that file will generate an executable file in that directory with the same name as the directory.
```vim

// Suppose the current folder is named myGoRepo

YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go
YDZ：~/helloworld/src/myGoRepo $ go build
YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go  myGoRepo

```
As a result, an executable named after the current folder is generated directly in the current directory (on macOS, a Unix executable file; on Windows, an exe file).

Let’s first record the MD5 value of this executable.
```vim

YDZ ~/helloworld/src/myGoRepo $  md5 /Users/YDZ/helloworld/src/myGoRepo/myGoRepo
MD5 (/Users/YDZ/helloworld/src/myGoRepo/myGoRepo) = 1f23f6efec752ed34b9bd22b5fa1ddce

```
However, in this case, if you use the `go install` command and there is only one workspace in `GOPATH`, the corresponding executable will be generated in the `bin` directory of the current workspace. If there are multiple workspaces under `GOPATH`, the corresponding executable will be generated under `GOBIN`.

Let’s continue from the `go build` operation we just performed.
```vim

YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go myGoRepo
YDZ：~/helloworld/src/myGoRepo $ go install
YDZ：~/helloworld/src/myGoRepo $ ls
helloworld.go 

```
After running `go install`, you may find that the executable has disappeared. Where did it go? It was actually moved into the `bin` directory. If there are multiple workspaces under `GOPATH`, it will be placed in the `GOBIN` directory.
```vim

YDZ：~/helloworld/bin $ ls
myGoRepo

```
Now compare the MD5 checksum of this file:
```vim

YDZ ~/helloworld/bin $  md5 /Users/YDZ/helloworld/bin/myGoRepo
MD5 (/Users/YDZ/helloworld/bin/myGoRepo) = 1f23f6efec752ed34b9bd22b5fa1ddce

```
It is exactly the same as the executable produced by the `go build` command. We can reasonably speculate that the executable just produced by `go build` was moved into the `bin` directory (if there are multiple workspaces under `GOPATH`, it will be placed under the `GOBIN` directory).

So what exactly do `go build` and `go install` do?

We will explain that shortly. First, let’s talk about `go build`.

`go build` is used to compile the source files or packages we specify, along with their dependent packages. However, **note that if it is used to compile non-command source files, that is, library source files, `go build` will not produce any output after it finishes. In this case, the `go build` command only validates the library source files; it performs a compilation for checking purposes only and does not output any result files.**

When `go build` compiles command source files, it generates an executable file in the directory where the command is executed. The example above also confirms this process.

If no directory path is appended after `go build`, it treats the current directory as a package and compiles it. If an import path of a package is provided as an argument after the `go build` command, that package and all of its dependencies will be compiled.

The `-a` flag of `go run` also works with `go build`. Adding `-a` to `go build` forces all involved packages to be compiled. Without `-a`, only packages whose archive files are not up to date will be compiled.

`go build` can use the `-o` flag to specify the name of the output file (in this example, the executable file). It is one of the most commonly used `go build` flags. However, note that when using the `-o` flag, you cannot compile multiple packages at the same time.

The `-i` flag causes the `go build` command to install packages that the build target depends on and that have not yet been installed. Here, installation means producing archive files corresponding to the packages and placing them in the appropriate subdirectory under the `pkg` subdirectory of the current workspace directory. By default, these packages are not installed.

Some commonly used `go build` flags are as follows:

Flag name      | Flag description
|:-------|:-------:|
-a           | Force all involved packages (including packages in the standard library) to be rebuilt, even if they are already up to date.
-n           | Print the other commands used during compilation, but do not actually execute them.
-p n         | Specify the parallelism of tasks executed during compilation (more precisely, the concurrency). By default, this number is equal to the number of logical CPU cores. However, on the `darwin/arm` platform (the platform used by iPhones and iPads), the default is `1`.
-race        | Enable race condition detection. However, this flag is currently supported only on the `linux/amd64`, `freebsd/amd64`, `darwin/amd64`, and `windows/amd64` platforms.
-v           | Print the names of the packages being compiled.
-work        | Print the path of the temporary work directory generated during compilation, and keep it after compilation finishes. By default, this directory is deleted when compilation finishes.
-x           | Print the other commands used during compilation. Note how it differs from the `-n` flag.


What exactly does the `go build` command do? Let’s print the execution process step by step. First, let’s see what happens when `go build` is executed on a command source file.
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
As you can see, the execution process is largely the same as `go run`. The only difference is in the final step: `go run` executes the binary, whereas `go build` moves the binary into the current directory.

Print the tree structure of the generated temporary directory.
```vim

.
├── command-line-arguments
│   └── _obj
│       └── exe
└── command-line-arguments.a

```
The structure is basically the same as that of the `go run` command. The only difference is that the executable is no longer in the `exe` folder; it has been moved to the folder where `go build` is currently being executed.

Next, let’s look at what happens after running `go build` on library source files:
```vim

#

# _/Users/YDZ/Downloads/goc2p-master/src/pkgtool

#

mkdir -p $WORK/_/Users/YDZ/Downloads/goc2p-master/src/pkgtool/_obj/
mkdir -p $WORK/_/Users/YDZ/Downloads/goc2p-master/src/
cd /Users/YDZ/Downloads/goc2p-master/src/pkgtool
/usr/local/Cellar/go/1.8.3/libexec/pkg/tool/darwin_amd64/compile -o $WORK/_/Users/YDZ/Downloads/goc2p-master/src/pkgtool.a -trimpath $WORK -p _/Users/YDZ/Downloads/goc2p-master/src/pkgtool -complete -buildid cef542c3da6d3126cdae561b5f6e1470aff363ba -D _/Users/YDZ/Downloads/goc2p-master/src/pkgtool -I $WORK -pack ./envir.go ./fpath.go ./ipath.go ./pnode.go ./util.go

```
Here we can see that the `go build` command simply compiled the library source files once and did nothing else.

Now take a look at the tree structure of the generated temporary directory.
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
You can see that the leading part of its directory hierarchy is the relative path of the local path where the code package resides. Then an archive `.a` file is generated.

To summarize, as shown below:

![](http://upload-images.jianshu.io/upload_images/1194012-c1b0dd9175c4f04a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


As for the difference between `go build` and `go install`, it will become clear after we finish analyzing `go install`. Next, let’s continue with `go install`.


### 3. go install

The `go install` command is used to compile and install code packages or source files.

`go install` compiles and installs the specified code packages and their dependencies. If the dependencies of the specified code packages have not yet been compiled and installed, the command processes those dependencies first. As with the `go build` command, package arguments passed to `go install` should be provided in the form of import paths. In addition, most of the flags supported by `go build` can also be used with
 `go install`. In fact, `go install` does only one thing more than `go build`: it installs the compiled result files into the specified directory.

Installing a code package generates an archive file (that is, a `.a` file) under the platform-specific directory of `pkg` in the current workspace.
Installing command source files generates an executable file in the `bin` directory of the current workspace (if there are multiple workspaces under `GOPATH`, it will be placed in the `GOBIN` directory).

Similarly, if no arguments are appended to the `go install` command, it treats the current directory as a code package and installs it. This is exactly the same as the `go build` command.

If the `go install` command is followed by a package import path as an argument, that package and all of its dependencies will be installed.

If the `go install` command is followed by command source files and related library source files as arguments, only those files will be compiled and installed.

So what exactly does the `go install` command do? Let’s print the execution process for each step.
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
The first few steps are still exactly the same as `go run` and `go build`; the only difference is the final step. `go install` installs command source files into the `bin` directory of the current workspace (if there are multiple workspaces under `GOPATH`, they are placed in the `GOBIN` directory). If they are library source files, they are installed under the platform-specific directory in `pkg` of the current workspace.

Now let’s take a look at the structure of the temporary directory generated by `go install`:
```vim

.
├── command-line-arguments
│   └── _obj
│       └── exe
└── command-line-arguments.a

```
The structure is the same as when running the `go build` command, and the generated files are ultimately moved into the corresponding target directories.

To summarize, as shown below:

![](http://upload-images.jianshu.io/upload_images/1194012-1a75a9e2080aecd8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

When installing source files for multiple libraries, you may encounter the following issue:
```go
hc@ubt:~/golang/goc2p/src/pkgtool$ go install envir.go fpath.go ipath.go pnode.go util.go
go install: no install location for .go files listed on command line (GOBIN not set)
```
Moreover, even after we set the environment variable GOBIN to the correct value, this error message will still appear. This is because only when installing command source files will the command use the value of the GOBIN environment variable as the directory for the resulting file. When installing library source files, however, the variable inside the command that represents the result file’s storage directory path is never assigned. In the end, the command will find that it is still an invalid empty value. Therefore, the command will likewise return an error about “no install location.” This leads to a conclusion: we can only install library source files by installing code packages, and cannot list and install them directly with the go install command. In addition, the go install command currently cannot accept the `-o` flag to customize the location where the result file is stored. This also indirectly shows that
 the go install command does not support installation operations for library source files.


### 4. go get

The go get command is used to download and install code packages from remote code repositories (such as GitHub). **Note that the go get command downloads the current code package into the src directory of the first workspace in $GOPATH, and installs it.**


>When using go get to download third-party packages, they are still downloaded into the first workspace under $GOPATH, not into the vendor directory. The current toolchain does not provide true package dependency management, but fortunately there are many third-party tools available.


If the `-d` flag is added during the go get download process, the operation will only download and will not install. For example, some very special code packages require special handling during installation, so we need to download them first; this is where the `-d` flag is used.


Another very useful flag is `-u`. With it, existing code packages and their dependencies can be updated over the network. If you have already downloaded a code package, but that package has since been updated, you can directly use the `-u` flag to update the corresponding local code package. If you do not add the `-u` flag, running go get on an existing code package will result in the command doing nothing. Only when the `-u` flag is added will the command execute git pull to fetch the latest version of the code package, then download and install it.

The go get command also has a highly commendable feature: smart downloading. After it checks out or updates a code package, it looks for a tag or branch that corresponds to the version number of the locally installed Go language. For example, if the installed Go version on the machine is 1.x, the go get command will look in that package’s remote repository for a tag or branch named “go1”. If the specified tag or branch is found, the local code package version is switched to that tag or branch. If the specified tag or branch is not found, the local code package version is switched to the latest version on the mainline.

Some commonly used flags for go get are as follows:

Flag name | Flag description 
--------- | ------- 
-d        | Makes the command only perform the download action, without performing installation.
-f        | Only effective when used with the `-u` flag. This flag makes the command ignore checks on the import paths of already downloaded code packages. This is especially important if the project to which the downloaded and installed code package belongs is one you forked from someone else.
-fix      | Makes the command run the fix action after downloading the code package, and only then compile and install it.
-insecure | Allows the command to use an insecure scheme (such as HTTP) to download the specified code package. If the code repository you use (such as an internal company Gitlab) does not support HTTPS, you can add this flag. Use it only when you are certain it is safe.
-t        | Makes the command also download and install the code packages depended on by the test source files in the specified code package.
-u        | Makes the command use the network to update existing code packages and their dependencies. By default, this command only downloads code packages that do not exist locally; it does not update existing code packages.

What exactly does the go get command do? Let’s print the execution process of each step.
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
Here you can clearly see that after the `go get` command is executed, it calls `git clone` to download the source code, then compiles it. Ultimately, the library source files are compiled into archive files and installed under the platform-specific directory in `pkg`.


A summary is shown in the diagram below:


![](http://upload-images.jianshu.io/upload_images/1194012-332a021cc97af1c0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


One additional note about workspaces:

In general, to separate our own code from third-party code, we configure two or more workspaces. Suppose we now have a workspace whose directory path is /home/hc/golang/lib, and it is the first directory path in the `GOPATH` environment variable. Note that the paths contained in the `GOPATH` environment variable must not duplicate the value of the `GOROOT` environment variable. Now, if we use the `go get` command to download and install code packages, those packages will all be installed in the workspace mentioned above. For now, let’s call this workspace the
 Lib workspace.


> If you use `vendor` to manage dependencies, the commonly used commands are:  
> 1. go get -u -x -a github.com/golang/geo/s2  
> 2. rm -rf Godeps vendor && make dep


## III. Static Linking or Dynamic Linking?

When Go was first released, static linking was promoted as an advantage: deployment required only a single compiled executable, with nothing else attached. By packaging the runtime and dependent libraries directly into the executable, deployment and release operations were simplified, with no need to install a runtime environment in advance or download many third-party libraries. However, newer versions have added support for dynamic linking as well.

Ordinary `go build` and `go install` use static linking. We can verify this:


![](http://upload-images.jianshu.io/upload_images/1194012-6d22852191014329.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

The image above shows the `gofmt` file opened by the author using MachOView. You can see that the address of `fmt.Println` is fixed, so we can determine that it is statically linked.

How does the latest version of Go support dynamic linking?

Add the `-buildmode` parameter when running `go build` or `go install`. 

The following are the available `buildmode` options:

archive: Build non-`main` packages into `.a` files. `main` packages are ignored.
c-archive: Build the `main` package and all packages it imports into a C archive file.
c-shared: Build the listed main packages, along with all packages they import, into
 a C dynamic library.
shared: Combine all listed non-`main` packages into a single dynamic library.
exe: Build the listed `main` packages and everything they import into an executable. Packages not named `main` are ignored.
By default, listed `main` packages are built into executables, and listed non-
 `main` packages are built into `.a` files.


The author has not yet practiced using dynamic libraries, so we will not go further into them here. After gaining sufficient hands-on experience, I will write a separate article about Go’s dynamic linking. The only point I want to make here is that Go no longer supports only static linking; it now supports dynamic linking as well!


------------------------------------------------------

Reference:  
[GO Command Tutorial](https://github.com/hyper0x/go_command_tutorial)  
《Go Concurrency Programming in Practice》


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/go\_command/](https://halfrost.com/go_command/)