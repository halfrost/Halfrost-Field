![](https://img.halfrost.com/Blog/ArticleImage/147_0.jpg)

# 深入研究 Go interface 底层实现

接口是高级语言中的一个规约，是一组方法签名的集合。Go 的 interface 是非侵入式的，具体类型实现 interface 不需要在语法上显式的声明，只需要具体类型的方法集合是 interface 方法集合的超集，就表示该类实现了这一 interface。编译器在编译时会进行 interface 校验。interface 和具体类型不同，它不能实现具体逻辑，也不能定义字段。

在 Go 语言中，interface 和函数一样，都是“第一公民”。interface 可以用在任何使用变量的地方。可以作为结构体内的字段，可以作为函数的形参和返回值，可以作为其他 interface 定义的内嵌字段。interface 在大型项目中常常用来解耦。在层与层之间用 interface 进行抽象和解耦。由于 Go interface 非侵入的设计，使得抽象出来的代码特别简洁，这也符合 Go 语言设计之初的哲学。除了解耦以外，还有一个非常重要的应用，就是利用 interface 实现伪泛型。利用空的 interface 作为函数或者方法参数能够用在需要泛型的场景里。

interface 作为 Go 语言类型系统的灵魂，Go 语言实现多态和反射的基础。新手对其理解不深刻的话，常常会犯下面这个错误：

```go
func main() {
	var x interface{} = nil
	var y *int = nil
	interfaceIsNil(x)
	interfaceIsNil(y)
}

func interfaceIsNil(x interface{}) {
	if x == nil {
		fmt.Println("empty interface")
		return
	}
	fmt.Println("non-empty interface")
}
```

笔者第一次接触到这个问题是强转了 gRPC 里面的一个 interface，然后在外面判断它是否为 nil。结果出 bug 了。当初如果了解对象强制转换成 interface 的时候，不仅仅含有原来的对象，还会包含对象的类型信息，也就不会出 bug 了。

本文将会详细分解 interface 所有底层实现。

> 以下代码基于 Go 1.16 


## 一. 数据结构

### 1. 非空 interface 数据结构
非空的 interface 初始化的底层数据结构是 iface，稍后在汇编代码中能验证这一点。

```go
type iface struct {
	tab  *itab
	data unsafe.Pointer
}
```

tab 中存放的是类型、方法等信息。data 指针指向的 iface 绑定对象的原始数据的副本。这里同样遵循 Go 的统一规则，值传递。tab 是 itab 类型的指针。

```go
// layout of Itab known to compilers
// allocated in non-garbage-collected memory
// Needs to be in sync with
// ../cmd/compile/internal/gc/reflect.go:/^func.WriteTabs.
type itab struct {
	inter *interfacetype
	_type *_type
	hash  uint32 // copy of _type.hash. Used for type switches.
	_     [4]byte
	fun   [1]uintptr // variable sized. fun[0]==0 means _type does not implement inter.
}
```

itab 中包含 5 个字段。inner 存的是 interface 自己的静态类型。\_type 存的是 interface 对应具体对象的类型。itab 中的 \_type 和 iface 中的 data 能简要描述一个变量。\_type 是这个变量对应的类型，data 是这个变量的值。这里的 hash 字段和 \_type 中存的 hash 字段是完全一致的，这么做的目的是为了类型断言(下文会提到)。fun 是一个函数指针，它指向的是具体类型的函数方法。虽然这里只有一个函数指针，但是它可以调用很多方法。在这个指针对应内存地址的后面依次存储了多个方法，利用指针偏移便可以找到它们。  

由于 Go 语言是强类型语言，编译时对每个变量的类型信息做强校验，所以每个类型的元信息要用一个结构体描述。再者 Go 的反射也是基于类型的元信息实现的。\_type 就是所有类型最原始的元信息。

```go
// Needs to be in sync with ../cmd/link/internal/ld/decodesym.go:/^func.commonsize,
// ../cmd/compile/internal/gc/reflect.go:/^func.dcommontype and
// ../reflect/type.go:/^type.rtype.
// ../internal/reflectlite/type.go:/^type.rtype.
type _type struct {
	size       uintptr // 类型占用内存大小
	ptrdata    uintptr // 包含所有指针的内存前缀大小
	hash       uint32  // 类型 hash
	tflag      tflag   // 标记位，主要用于反射
	align      uint8   // 对齐字节信息
	fieldAlign uint8   // 当前结构字段的对齐字节数
	kind       uint8   // 基础类型枚举值
	equal func(unsafe.Pointer, unsafe.Pointer) bool // 比较两个形参对应对象的类型是否相等
	gcdata    *byte    // GC 类型的数据
	str       nameOff  // 类型名称字符串在二进制文件段中的偏移量
	ptrToThis typeOff  // 类型元信息指针在二进制文件段中的偏移量
}
```

有 3 个字段需要解释一下：

- kind，这个字段描述的是如何解析基础类型。在 Go 语言中，基础类型是一个枚举常量，有 26 个基础类型，如下。枚举值通过 kindMask 取出特殊标记位。

```go
const (
	kindBool = 1 + iota
	kindInt
	kindInt8
	kindInt16
	kindInt32
	kindInt64
	kindUint
	kindUint8
	kindUint16
	kindUint32
	kindUint64
	kindUintptr
	kindFloat32
	kindFloat64
	kindComplex64
	kindComplex128
	kindArray
	kindChan
	kindFunc
	kindInterface
	kindMap
	kindPtr
	kindSlice
	kindString
	kindStruct
	kindUnsafePointer

	kindDirectIface = 1 << 5
	kindGCProg      = 1 << 6
	kindMask        = (1 << 5) - 1
)
```

- str 和 ptrToThis，对应的类型是 nameoff 和 typeOff。这两个字段的值是在链接器段合并和符号重定向的时候赋值的。
![](https://img.halfrost.com/Blog/ArticleImage/147_1.png)
链接器将各个 .o 文件中的段合并到输出文件，会进行段合并，有的放入 .text 段，有的放入 .data 段，有的放入 .bss 段。name 和 type 针对最终输出文件所在段内的偏移量 offset 是由 resolveNameOff 和 resolveTypeOff 函数计算出来的，然后链接器把结果保存在 str 和 ptrToThis 中。具体逻辑可以见源码中下面 2 个函数:

```go
func resolveNameOff(ptrInModule unsafe.Pointer, off nameOff) name {}  
func resolveTypeOff(ptrInModule unsafe.Pointer, off typeOff) *_type {}
```

回到 \_type 类型。上文谈到 \_type 是所有类型原始信息的元信息。例如：

```go
type arraytype struct {
	typ   _type
	elem  *_type
	slice *_type
	len   uintptr
}

type chantype struct {
	typ  _type
	elem *_type
	dir  uintptr
}
```

在 arraytype 和 chantype 中保存类型的元信息就是靠 \_type。同样 interface 也有类似的类型定义：

```go
type imethod struct {
	name nameOff
	ityp typeOff
}

type interfacetype struct {
	typ     _type     // 类型元信息
	pkgpath name      // 包路径和描述信息等等
	mhdr    []imethod // 方法
}
```

因为 Go 语言中函数方法是以包为单位隔离的。所以 interfacetype 除了保存 \_type 还需要保存包路径等描述信息。mhdr 存的是各个 interface 函数方法在段内的偏移值 offset，知道偏移值以后才方便调用。 


### 2. 空 interface 数据结构

空的 inferface{} 是没有方法集的接口。所以不需要 itab 数据结构。它只需要存类型和类型对应的值即可。对应的数据结构如下：

```go
type eface struct {
	_type *_type
	data  unsafe.Pointer
}
```

从这个数据结构可以看出，只有当 2 个字段都为 nil，空接口才为 nil。空接口的主要目的有 2 个，一是实现“泛型”，二是使用反射。

## 执行过程

https://qcrao91.gitbook.io/go/interface/jie-kou-de-gou-zao-guo-cheng-shi-zen-yang-de




## 二. 类型转换

举个具体的例子来说明 interface 是如何进行类型转换的。先来看指针类型转换。


### 1. 指针类型

```go
package main

import "fmt"

func main() {
	var s Person = &Student{name: "halfrost"}
	s.sayHello("everyone")
}

type Person interface {
	sayHello(name string) string
	sayGoodbye(name string) string
}

type Student struct {
	name string
}

func (s *Student) sayHello(name string) string {
	return fmt.Sprintf("%v: Hello %v, nice to meet you.\n", s.name, name)
}

func (s *Student) sayGoodbye(name string) string {
	return fmt.Sprintf("%v: Hi %v, see you next time.\n", s.name, name)
}

```

利用 go build 和 go tool 命令将上述代码变成汇编代码：

```go
$ go tool compile -S -N -l main.go >main.s1 2>&1
```

main 方法中有 3 个操作，重点关注后 2 个涉及到 interface 的操作：

1. 初始化 Student 对象  
2. 将 Student 对象转换成 interface  
3. 调用 interface 的方法  

> Plan9 汇编常见寄存器含义：  
> BP: 栈基，栈帧（函数的栈叫栈帧）的开始位置。  
> SP: 栈顶，栈帧的结束位置。  
> PC: 就是IP寄存器，存放CPU下一个执行指令的位置地址。  
> TLS: 虚拟寄存器。表示的是 thread-local storage，Golang 中存放了当前正在执行的g的结构体。  


先来看 Student 初始化的汇编代码：

```go
0x0021 00033 (main.go:6)	LEAQ	type."".Student(SB), AX      // 将 type."".Student 地址放入 AX 中
0x0028 00040 (main.go:6)	MOVQ	AX, (SP)                     // 将 AX 中的值存储在 SP 中
0x002c 00044 (main.go:6)	PCDATA	$1, $0
0x002c 00044 (main.go:6)	CALL	runtime.newobject(SB)        // 调用 runtime.newobject() 方法，生成 Student 对象存入 SB 中
0x0031 00049 (main.go:6)	MOVQ	8(SP), DI                    // 将生成的 Student 对象放入 DI 中
0x0036 00054 (main.go:6)	MOVQ	DI, ""..autotmp_2+40(SP)     // 编译器认为 Student 是临时变量，所以将 DI 放在栈上
0x003b 00059 (main.go:6)	MOVQ	$8, 8(DI)                    // (DI.Name).Len = 8
0x0043 00067 (main.go:6)	PCDATA	$0, $-2
0x0043 00067 (main.go:6)	CMPL	runtime.writeBarrier(SB), $0
0x004a 00074 (main.go:6)	JEQ	78
0x004c 00076 (main.go:6)	JMP	172
0x004e 00078 (main.go:6)	LEAQ	go.string."halfrost"(SB), AX  // 将 "halfrost" 字符串的地址放入 AX 中
0x0055 00085 (main.go:6)	MOVQ	AX, (DI)                      // (DI.Name).Data = &"halfrost"
0x0058 00088 (main.go:6)	JMP	90
0x005a 00090 (main.go:6)	PCDATA	$0, $-1
```

先将 *\_type 放在 (0)SP 栈顶。然后调用 runtime.newobject() 生成 Student 对象。(0)SP 栈顶的值即是 newobject() 方法的入参。

```go
func newobject(typ *_type) unsafe.Pointer {
	return mallocgc(typ.size, typ, true)
}
```

PCDATA 用于生成 PC 表格，PCDATA 的指令用法为：PCDATA tableid, tableoffset。PCDATA有个两个参数，第一个参数为表格的类型，第二个是表格的地址。runtime.writeBarrier() 是 GC 相关的方法，感兴趣的可以研究它的源码。以下是 Student 对象临时对象 GC 的一些汇编代码逻辑，由于有 JMP 命令，代码是分开的，笔者在这里将它们汇集在一起。

```go
0x0043 00067 (main.go:6)    PCDATA  $0, $-2
0x0043 00067 (main.go:6)    CMPL    runtime.writeBarrier(SB), $0
0x004a 00074 (main.go:6)    JEQ 78
0x004c 00076 (main.go:6)    JMP 172
......
0x00ac 00172 (main.go:6)	PCDATA	$0, $-2
0x00ac 00172 (main.go:6)	LEAQ	go.string."halfrost"(SB), AX
0x00b3 00179 (main.go:6)	CALL	runtime.gcWriteBarrier(SB)
0x00b8 00184 (main.go:6)	JMP	90
0x00ba 00186 (main.go:6)	NOP
```

78 对应的十六进制是 0x004e，172 对应的十六进制是 0x00ac。先对比 runtime.writeBarrier(SB) 和 \$0 存的是否一致，如果相同则 JMP 到 0x004e 行，如果不同则 JMP 到 0x00ac 行。0x004e 行和 0x00ac 行代码完全相同，都是将字符串 "halfrost" 的地址放入 AX 中，不过 0x00ac 行执行完会紧接着调用 runtime.gcWriteBarrier(SB)。执行完成以后再回到 0x005a 行。

第一步结束以后，内存中存了 3 个值。临时变量 .autotmp\_2 放在 +40(SP) 的地址处，它也就是临时 Student 对象。

![](https://img.halfrost.com/Blog/ArticleImage/147_2_.png)


接下来是第二步，将 Student 对象转换成 interface。

```go
0x005a 00090 (main.go:6)	MOVQ	""..autotmp_2+40(SP), AX
0x005f 00095 (main.go:6)	MOVQ	AX, ""..autotmp_1+48(SP)
0x0064 00100 (main.go:6)	LEAQ	go.itab.*"".Student,"".Person(SB), CX
0x006b 00107 (main.go:6)	MOVQ	CX, "".s+56(SP)
0x0070 00112 (main.go:6)	MOVQ	AX, "".s+64(SP)
```

经过上面几行汇编代码，成功的构造出了 itab 结构体。在汇编代码中可以找到 itab 的内存布局：

```go
go.itab.*"".Student,"".Person SRODATA dupok size=40
	0x0000 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
	0x0010 0c 31 79 12 00 00 00 00 00 00 00 00 00 00 00 00  .1y.............
	0x0020 00 00 00 00 00 00 00 00                          ........
	rel 0+8 t=1 type."".Person+0
	rel 8+8 t=1 type.*"".Student+0
	rel 24+8 t=1 "".(*Student).sayGoodbye+0
	rel 32+8 t=1 "".(*Student).sayHello+0
```

itab 结构体的首字节里面存的是 inter *interfacetype，此处即 Person interface。第二个字节中存的是 \*\_type，这里是第一步生成的，放在 (0)SP 地址处的地址。第四个字节中存的是 fun [1]uintptr，对应 sayGoodbye 方法的首地址。第五个字节中存的也是 fun [1]uintptr，对应 sayHello 方法的首地址。回顾上一章节里面的 itab 数据结构：

```go
type itab struct {
    inter *interfacetype // 8 字节
    _type *_type         // 8 字节
    hash  uint32 		 // 4 字节，填充使得内存对齐
    _     [4]byte        // 4 字节
    fun   [1]uintptr     // 8 字节
}
```
现在就很明确了为什么 fun 只需要存一个函数指针。每个函数指针都是 8 个字节，如果 interface 里面包含多个函数，只需要 fun 往后顺序偏移多个字节即可。第二步结束以后，内存中存储了以下这些值：


![](https://img.halfrost.com/Blog/ArticleImage/147_3_0.png)

在第二步中新建了一个临时变量 .autotmp\_1 放在 +48(SP) 地址处。并且利用第一步中生成的 Student 临时变量构造出了 itab 数据结构。值得说明的是，虽然汇编代码并没有显示调用函数生成 iface，但是此时已经生成了 iface。

```go
type iface struct {
    tab  *itab
    data unsafe.Pointer
}
```

如上图，+(56)SP 处存的是 *itab，+(64)SP 处存的是 unsafe.Pointer，这里的指针和 +(8)SP 的指针是完全一致的。接下来就是最后一步，调用 interface 的方法。

```go
0x0075 00117 (main.go:7)	MOVQ	"".s+56(SP), AX
0x007a 00122 (main.go:7)	TESTB	AL, (AX)
0x007c 00124 (main.go:7)	MOVQ	32(AX), AX
0x0080 00128 (main.go:7)	MOVQ	"".s+64(SP), CX
0x0085 00133 (main.go:7)	MOVQ	CX, (SP)
0x0089 00137 (main.go:7)	LEAQ	go.string."everyone"(SB), CX
0x0090 00144 (main.go:7)	MOVQ	CX, 8(SP)
0x0095 00149 (main.go:7)	MOVQ	$8, 16(SP)
0x009e 00158 (main.go:7)	NOP
0x00a0 00160 (main.go:7)	CALL	AX
```

先取出调用方法的真正对象，放入 (0)SP 中，再依次将方法中的入参按照顺序放在 (8)SP 之后。然后调用函数指针对应的方法。从汇编代码中可以看到，AX 直接从取出了 *itab 指针存的内存地址，然后偏移到了 +32 的位置，这里是要调用的方法 sayHello 的内存地址。最后从栈顶依次取出需要的参数，即算完成 iterface 方法调用。方法调用前一刻，内存中的状态如下，主要关注 AX 的地址以及栈顶的所有参数信息。

![](https://img.halfrost.com/Blog/ArticleImage/147_4_.png)

栈顶依次存放的是方法的调用者，参数。调用格式可以表示为 func(reciver, param1)。


### 2. 指针类型




要注意隐藏类型转换，自定义的 error 类型会因为隐藏的类型转换变为非 nil。

例如

```go
package main

import "fmt"

type MyError struct {}

func (i MyError) Error() string {
    return "MyError"
}

func main() {
    err := Process()
    fmt.Println(err)

    fmt.Println(err == nil)
}

func Process() error {
    var err *MyError = nil
    return err
}
```

```go
<nil>
false
```

## 二. 类型断言 Type Assertion

https://qcrao91.gitbook.io/go/interface/lei-xing-zhuan-huan-he-duan-yan-de-qu-bie


## 三. 类型查询 Type Switches


## 四. 动态派发 

派发方法，实现类似多态。fun 数组里保存的是实体类型实现的函数，所以当函数传入不同的实体类型时，调用的实际上是不同的函数实现，从而实现多态。


https://qcrao91.gitbook.io/go/interface/jie-kou-zhuan-huan-de-yuan-li