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




## 类型转换

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