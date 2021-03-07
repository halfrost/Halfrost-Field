![](https://img.halfrost.com/Blog/ArticleImage/148_0.png)

# Go reflection 三定律与最佳实践

在计算机学中，反射式编程 reflective programming 或反射 reflection，是指计算机程序在运行时 runtime 可以访问、检测和修改它本身状态或行为的一种能力。用比喻来说，反射就是程序在运行的时候能够“观察”并且修改自己的行为。

> Wikipedia: In computer science, reflective programming or reflection is the ability of a process to examine, introspect, and modify its own structure and behavior.


“反射”和“内省”（type introspection）在概念上有区别。内省（或称“自省”）机制仅指程序在运行时对自身信息（称为元数据）的检测；反射机制不仅包括要能在运行时对程序自身信息进行检测，还要求程序能进一步根据这些信息改变程序状态或结构。所以反射的概念范畴要大于内省。


在类型检测严格的面向对象的编程语言如 Java 中，一般需要在编译期间对程序中需要调用的对象的具体类型、接口（interface）、字段（fields）和方法的合法性进行检查。反射技术则允许将对需要调用的对象的消息检查工作从编译期间推迟到运行期间再现场执行。这样一来，可以在编译期间先不明确目标对象的接口（interface）名称、字段（fields），即对象的成员变量、可用方法，然后在运行根据目标对象自身的消息决定如何处理。它还允许根据判断结果进行实例化新对象和相关方法的调用。

反射主要用途就是使给定的程序，动态地适应不同的运行情况。利用面向对象建模中的多态（多态性）也可以简化编写分别适用于多种不同情形的功能代码，但是反射可以解决多态（多态性）并不适用的更普遍情形，从而更大程度地避免硬编码（即把代码的细节“写死”，缺乏灵活性）的代码风格。

**反射也是元编程的一个关键策略**。

最常见的代码如下：

```go
import "reflect"

func main() {
	// Without reflection
	f := Foo{}
	f.Hello()

	// With reflection
	fT := reflect.TypeOf(Foo{})
	fV := reflect.New(fT)

	m := fV.MethodByName("Hello")
	if m.IsValid() {
		m.Call(nil)
	}
}
```

反射看似代码更加复杂，但是能实现的功能更加灵活了。究竟什么时候用反射？最佳实践是什么？这篇文章好好讨论一下。


## 一. 基本数据结构

在上一篇 Go interface 中，可以了解到普通对象在内存中的存在形式，一个变量值得我们关注的无非是两部分，一个是类型，一个是它存的值。变量的类型决定了底层 tpye 是什么，支持哪些方法集。值无非就是读和写。去内存里面哪里读，把 0101 写到内存的哪里，都是由类型决定的。这一点在解析不同 Json 数据结构的时候深有体会，如果数据类型用错了，解析出来得到的变量的值是乱码。Go 提供反射的功能，是为了支持在运行时动态访问变量的类型和值。

在运行时想要动态访问类型的值，必然应用程序存储了所有用到的类型信息。"reflect" 库提供了一套供开发者使用的访问接口。Go 中反射的基础是接口和类型，Go 很巧妙的借助了对象到接口的转换时使用的数据结构，先将对象传递给内部的空接口，即将类型转换成空接口 eface。然后反射再基于这个 eface 来访问和操作实例对象的值和类型。

那么笔者就从数据结构开始梳理 Go 是如何实现反射的。在 reflect 包中，有一个描述类型公共信息的通用数据结构 rtype。从源码的注释上看，它和 interface 里面的 \_type 是同一个数据结构。它们俩只是因为包隔离，加上为了避免循环引用，所以在这边又复制了一遍。


```go
// rtype is the common implementation of most values.
// It is embedded in other struct types.
//
// rtype must be kept in sync with ../runtime/type.go:/^type._type.
type rtype struct {
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

相同的，所有类型的元信息也都复制了一遍：

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

所有基础类型都不再赘述，详情可见上一篇《深入研究 Go interface 底层实现》。在 reflect 包中有一个重要的方法 TypeOf()，利用这个方法可以获得一个 Type 的 interface。通过 Type interface 可以获取对象的类型信息。

```go
// TypeOf returns the reflection Type that represents the dynamic type of i.
// If i is a nil interface value, TypeOf returns nil.
func TypeOf(i interface{}) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}

// toType converts from a *rtype to a Type that can be returned
// to the client of package reflect. In gc, the only concern is that
// a nil *rtype must be replaced by a nil Type, but in gccgo this
// function takes care of ensuring that multiple *rtype for the same
// type are coalesced into a single Type.
func toType(t *rtype) Type {
	if t == nil {
		return nil
	}
	return t
}
```

上述方法实现非常简单，就是将形参转换成 Type interface。这里设计成返回 interface 而不是返回 rtype 类型的数据结构是有讲究的。一是设计者不希望调用者拿到 rtype 滥用。毕竟类型信息这些都是只读的，在运行时被任意篡改太不安全了。二是设计者将调用者的需求的所有需求用 interface 这一层屏蔽了，Type interface 下层可以对应很多种类型，利用这个接口统一抽象成一层。

值得说明的一点是 TypeOf() 入参，入参类型是 i interface{}，可以是 2 种类型，一种是 interface 变量，另外一种是具体的类型变量。如果 i 是具体的类型变量，TypeOf() 返回的具体类型信息；如果 i 是 interface 变量，并且绑定了具体类型对象实例，返回的是 i 绑定具体类型的动态类型信息；如果 i 没有绑定任何具体的类型对象实例，返回的是接口自身的静态类型信息。


下面来看看 Type interface 究竟涵盖了哪些有用的方法：


### 1. 通用方法

以下这些方法是通用方法，可以适用于任何类型。

```go
// Type 是 Go 类型的表示。
//
// 并非所有方法都适用于所有类型。
// 在调用 kind 具体方法之前，先使用 Kind 方法找出类型的种类。因为调用一个方法如果类型不匹配会导致 panic
//
// Type 类型值是可以比较的，比如用 == 操作符。所以它可以用做 map 的 key
// 如果两个 Type 值代表相同的类型，那么它们一定是相等的。
type Type interface {
	
	// Align 返回该类型在内存中分配时，以字节数为单位的字节数
	Align() int
	
	// FieldAlign 返回该类型在结构中作为字段使用时，以字节数为单位的字节数
	FieldAlign() int
	
	// Method 这个方法返回类型方法集中的第 i 个方法。
	// 如果 i 不在[0, NumMethod()]范围内，就会 panic。
	// 对于一个非接口类型 T 或 *T，返回的 Method 的 Type 和 Func。
	// fields 字段描述一个函数，它的第一个参数是接收方，而且只有导出的方法可以访问。
	// 对于一个接口类型，返回的 Method 的 Type 字段给出的是方法签名，没有接收者，Func字段为nil。
	// 方法是按字典序顺序排列的。
	Method(int) Method
	
	// MethodByName 返回类型中带有该名称的方法。
	// 方法集和一个表示是否找到该方法的布尔值。
	// 对于一个非接口类型 T 或 *T，返回的 Method 的 Type 和 Func。
	// fields 字段描述一个函数，其第一个参数是接收方。
	// 对于一个接口类型，返回的 Method 的 Type 字段给出的是方法签名，没有接收者，Func字段为nil。
	MethodByName(string) (Method, bool)

	// NumMethod 返回使用 Method 可以访问的方法数量。
	// 请注意，NumMethod 只在接口类型的调用的时候，会对未导出方法进行计数。
	NumMethod() int

	// 对于定义的类型，Name 返回其包中的类型名称。
	// 对于其他(非定义的)类型，它返回空字符串。
	Name() string

	// PkgPath 返回一个定义类型的包的路径，也就是导入路径，导入路径是唯一标识包的类型，如 "encoding/base64"。
	// 如果类型是预先声明的(string, error)或者没有定义(*T, struct{}, []int，或 A，其中 A 是一个非定义类型的别名），包的路径将是空字符串。
	PkgPath() string

	// Size 返回存储给定类型的值所需的字节数。它类似于 unsafe.Sizeof.
	Size() uintptr

	// String 返回该类型的字符串表示。
	// 字符串表示法可以使用缩短的包名。
	// (例如，使用 base64 而不是 "encoding/base64")并且它并不能保证类型之间是唯一的。如果是为了测试类型标识，应该直接比较类型 Type。
	String() string

	// Kind 返回该类型的具体种类。
	Kind() Kind

	// Implements 表示该类型是否实现了接口类型 u。
	Implements(u Type) bool

	// AssignableTo 表示该类型的值是否可以分配给类型 u。
	AssignableTo(u Type) bool

	// ConvertibleTo 表示该类型的值是否可转换为 u 类型。
	ConvertibleTo(u Type) bool

	// Comparable 表示该类型的值是否具有可比性。
	Comparable() bool
}
```

### 2. 专有方法

以下这些方法是某些类型专有的方法，如果类型不匹配会发生 panic。在不确定类型之前最好先调用 Kind() 方法确定具体类型再调用类型的专有方法。


|Kind|Methods applicable|
|:------|:-----------|
|Int\*| Bits |
|Uint\* | Bits |
|Float\*| Bits |
|Complex\*| Bits |
|Array|Elem, Len|
|Chan|ChanDir, Elem|
|Func|In, NumIn, Out, NumOut, IsVariadic|
|Map| Key, Elem|
|Ptr| Elem|
|Slice| Elem|
|Struct| Field, FieldByIndex, FieldByName,FieldByNameFunc, NumField|


对专有方法的说明如下：


```go
type Type interface {

	// Bits 以 bits 为单位返回类型的大小。
	// 如果类型的 Kind 不属于：sized 或者 unsized Int, Uint, Float, 或者 Complex，会 panic。
	//大小不一的Int、Uint、Float或Complex类型。
	Bits() int

	// ChanDir 返回一个通道类型的方向。
	// 如果类型的 Kind 不是 Chan，会 panic。
	ChanDir() ChanDir


	// IsVariadic 表示一个函数类型的最终输入参数是否为一个 "..." 可变参数。如果是，t.In(t.NumIn() - 1) 返回参数的隐式实际类型 []T.
	// 更具体的，如果 t 代表 func(x int, y ... float64)，那么：
	// t.NumIn() == 2
	// t.In(0)是 "int" 的 reflect.Type 反射类型。
	// t.In(1)是 "[]float64" 的 reflect.Type 反射类型。
	// t.IsVariadic() == true
	// 如果类型的 Kind 不是 Func.IsVariadic，IsVariadic 会 panic
	IsVariadic() bool

	// Elem 返回一个 type 的元素类型。
	// 如果类型的 Kind 不是 Array、Chan、Map、Ptr 或 Slice，就会 panic
	Elem() Type

	// Field 返回一个结构类型的第 i 个字段。
	// 如果类型的 Kind 不是 Struct，就会 panic。
	// 如果 i 不在 [0, NumField()] 范围内，也会 panic。
	Field(i int) StructField

	// FieldByIndex 返回索引序列对应的嵌套字段。它相当于对每一个 index 调用 Field。
	// 如果类型的 Kind 不是 Struct，就会 panic。
	FieldByIndex(index []int) StructField

	// FieldByName 返回给定名称的结构字段和一个表示是否找到该字段的布尔值。
	FieldByName(name string) (StructField, bool)

	// FieldByNameFunc 返回一个能满足 match 函数的带有名称的 field 字段。布尔值表示是否找到。
	// FieldByNameFunc 先在自己的结构体的字段里面查找，然后在任何嵌入结构中的字段中查找，按广度第一顺序搜索。最终停止在含有一个或多个能满足 match 函数的结构体中。如果在该深度上满足条件的有多个字段，这些字段相互取消，并且 FieldByNameFunc 返回没有匹配。
	// 这种行为反映了 Go 在包含嵌入式字段的结构的情况下对名称查找的处理方式
	FieldByNameFunc(match func(string) bool) (StructField, bool)

	// In 返回函数类型的第 i 个输入参数的类型。
	// 如果类型的 Kind 不是 Func 类型会 panic。
	// 如果 i 不在 [0, NumIn()) 的范围内，会 panic。
	In(i int) Type

	// Key 返回一个 map 类型的 key 类型。
	// 如果类型的 Kind 不是 Map，会 panic。
	Key() Type

	// Len 返回一个数组类型的长度。
	// 如果类型的 Kind 不是 Array，会 panic。
	Len() int

	// NumField 返回一个结构类型的字段数目。
	// 如果类型的 Kind 不是 Struct，会 panic。
	NumField() int

	// NumIn 返回一个函数类型的输入参数数。
	// 如果类型的 Kind 不是Func.NumIn()，会 panic。
	NumIn() int

	// NumOut 返回一个函数类型的输出参数数。
	// 如果类型的 Kind 不是 Func.NumOut()，会 panic。
	NumOut() int

	// Out 返回一个函数类型的第 i 个输出参数的类型。
	// 如果类型的类型不是 Func.Out，会 panic。
	// 如果 i 不在 [0, NumOut()) 的范围内，会 panic。
	Out(i int) Type

	common() *rtype
	uncommon() *uncommonType
}
```




```go
// Value is the reflection interface to a Go value.
//
// Not all methods apply to all kinds of values. Restrictions,
// if any, are noted in the documentation for each method.
// Use the Kind method to find out the kind of value before
// calling kind-specific methods. Calling a method
// inappropriate to the kind of type causes a run time panic.
//
// The zero Value represents no value.
// Its IsValid method returns false, its Kind method returns Invalid,
// its String method returns "<invalid Value>", and all other methods panic.
// Most functions and methods never return an invalid value.
// If one does, its documentation states the conditions explicitly.
//
// A Value can be used concurrently by multiple goroutines provided that
// the underlying Go value can be used concurrently for the equivalent
// direct operations.
//
// To compare two Values, compare the results of the Interface method.
// Using == on two Values does not compare the underlying values
// they represent.
type Value struct {
	// typ holds the type of the value represented by a Value.
	typ *rtype

	// Pointer-valued data or, if flagIndir is set, pointer to data.
	// Valid when either flagIndir is set or typ.pointers() is true.
	ptr unsafe.Pointer

	// flag holds metadata about the value.
	// The lowest bits are flag bits:
	//	- flagStickyRO: obtained via unexported not embedded field, so read-only
	//	- flagEmbedRO: obtained via unexported embedded field, so read-only
	//	- flagIndir: val holds a pointer to the data
	//	- flagAddr: v.CanAddr is true (implies flagIndir)
	//	- flagMethod: v is a method value.
	// The next five bits give the Kind of the value.
	// This repeats typ.Kind() except for method values.
	// The remaining 23+ bits give a method number for method values.
	// If flag.kind() != Func, code can assume that flagMethod is unset.
	// If ifaceIndir(typ), code can assume that flagIndir is set.
	flag

	// A method value represents a curried method invocation
	// like r.Read for some receiver r. The typ+val+flag bits describe
	// the receiver r, but the flag's Kind bits say Func (methods are
	// functions), and the top bits of the flag give the method number
	// in r's type's method table.
}
```

## 二. 反射的内部实现



## 三. 反射三定律






## 四. 优缺点与最佳实践

优点：  
支持反射的语言提供了一些在早期高级语言中难以实现的运行时特性。

- 可以在一定程度上避免硬编码，提供灵活性和通用性。
- 可以作为一个第一类对象发现并修改源代码的结构（如代码块、类、方法、协议等）。
- 可以在运行时像对待源代码语句一样动态解析字符串中可执行的代码（类似JavaScript的eval()函数），进而可将跟class或function匹配的字符串转换成class或function的调用或引用。
- 可以创建一个新的语言字节码解释器来给编程结构一个新的意义或用途。

劣势：

- 此技术的学习成本高。面向反射的编程需要较多的高级知识，包括框架、关系映射和对象交互，以实现更通用的代码执行。  
- 同样因为反射的概念和语法都比较抽象，过多地滥用反射技术会使得代码难以被其他人读懂，不利于合作与交流。
- 由于将部分信息检查工作从编译期推迟到了运行期，此举在提高了代码灵活性的同时，牺牲了一点点运行效率。

通过深入学习反射的特性和技巧，它的劣势可以尽量避免，但这需要许多时间和经验的积累。
