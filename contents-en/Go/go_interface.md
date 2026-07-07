![](https://img.halfrost.com/Blog/ArticleImage/147_0.jpg)

# An In-Depth Look at the Underlying Implementation of Go Interfaces

An interface is a contract in high-level languages: a set of method signatures. Go interfaces are non-intrusive. A concrete type does not need to explicitly declare, syntactically, that it implements an interface. As long as the method set of the concrete type is a superset of the interface’s method set, the type is considered to implement that interface. The compiler performs interface checks at compile time. Unlike concrete types, an interface cannot implement concrete logic or define fields.

In Go, interfaces, like functions, are “first-class citizens.” An interface can be used anywhere a variable can be used. It can be a field in a struct, a function parameter or return value, or an embedded field in the definition of another interface. In large projects, interfaces are often used for decoupling. Interfaces provide abstraction and decoupling between layers. Because Go interfaces are designed to be non-intrusive, the resulting abstractions are particularly concise, which aligns with the philosophy behind Go’s original design. In addition to decoupling, interfaces have another very important use: implementing pseudo-generics. Using an empty interface as a function or method parameter can be applied in scenarios that require generics.

As the soul of Go’s type system, interfaces are the foundation of polymorphism and reflection in Go. Beginners who do not understand them deeply often make the following mistake:
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
The first time I ran into this issue was when I type-asserted an interface in gRPC and then checked outside whether it was nil. It resulted in a bug. If I had understood back then that when an object is coerced into an interface, it contains not only the original object but also the object's type information, the bug would not have happened.

This article will break down all of the underlying implementation details of interface.

> The following code is based on Go 1.16


## 1. Data Structures

### 1. Data Structure of a Non-Empty interface
The underlying data structure initialized for a non-empty interface is iface. We will verify this later in the assembly code.
```go
type iface struct {
	tab  *itab
	data unsafe.Pointer
}
```
tab stores information such as types and methods. The data pointer points to a copy of the original data of the object bound to iface. This likewise follows Go’s uniform rule: pass by value. tab is a pointer to the itab type.
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
`itab` contains five fields. `inner` stores the static type of the interface itself. `_type` stores the type of the concrete object corresponding to the interface. The `_type` in `itab` together with the `data` in `iface` can briefly describe a variable: `_type` is the type corresponding to the variable, and `data` is the value of the variable. The `hash` field here is exactly the same as the `hash` field stored in `_type`; this is done for type assertions (discussed later). `fun` is a function pointer that points to the method of the concrete type. Although there is only one function pointer here, it can call many methods. Multiple methods are stored sequentially after the memory address corresponding to this pointer, and they can be located via pointer offsets.  

Because Go is a strongly typed language, it strictly validates the type information of every variable at compile time, so the metadata of each type must be described by a struct. Furthermore, Go’s reflection is also implemented based on type metadata. `_type` is the most fundamental metadata for all types.
```go
// Needs to be in sync with ../cmd/link/internal/ld/decodesym.go:/^func.commonsize,
// ../cmd/compile/internal/gc/reflect.go:/^func.dcommontype and
// ../reflect/type.go:/^type.rtype.
// ../internal/reflectlite/type.go:/^type.rtype.
type _type struct {
	size       uintptr // memory size occupied by the type
	ptrdata    uintptr // size of the memory prefix containing all pointers
	hash       uint32  // type hash
	tflag      tflag   // flag bits, mainly used for reflection
	align      uint8   // alignment in bytes
	fieldAlign uint8   // alignment in bytes for fields of the current struct
	kind       uint8   // base type enum value
	equal func(unsafe.Pointer, unsafe.Pointer) bool // compares whether the types of the objects corresponding to the two parameters are equal
	gcdata    *byte    // GC type data
	str       nameOff  // offset of the type name string in the binary file segment
	ptrToThis typeOff  // offset of the type metadata pointer in the binary file segment
}
```
There are three fields that need some explanation:

- `kind`: this field describes how to parse the basic type. In Go, a basic type is an enum constant; there are 26 basic types, as shown below. The enum value uses `kindMask` to extract the special flag bits.
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
- `str` and `ptrToThis` correspond to the types `nameoff` and `typeOff`. The values of these two fields are assigned when the linker merges sections and redirects symbols.
![](https://img.halfrost.com/Blog/ArticleImage/147_1.png)
When the linker merges the sections from each `.o` file into the output file, it performs section merging: some sections go into the `.text` section, some into the `.data` section, and some into the `.bss` section. The offsets of `name` and `type` within the sections of the final output file are computed by the `resolveNameOff` and `resolveTypeOff` functions, and the linker then stores the results in `str` and `ptrToThis`. For the specific logic, see the following two functions in the source code:
```go
func resolveNameOff(ptrInModule unsafe.Pointer, off nameOff) name {}  
func resolveTypeOff(ptrInModule unsafe.Pointer, off typeOff) *_type {}
```
Back to the \_type type. As mentioned above, \_type is the metadata for the raw information of all types. For example:
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
In `arraytype` and `chantype`, type metadata is stored via \_type. Similarly, `interface` has analogous type definitions:
```go
type imethod struct {
	name nameOff
	ityp typeOff
}

type interfacetype struct {
	typ     _type     // type metadata
	pkgpath name      // package path, description info, etc.
	mhdr    []imethod // methods
}
```
Because in Go, methods are isolated at the package level. Therefore, in addition to storing \_type, interfacetype also needs to store descriptive information such as the package path. mhdr stores the offset of each interface method within the segment; once the offset is known, the method can be called conveniently. 


### 2. Empty interface data structure

An empty interface{} is an interface with no method set. Therefore, it does not need the itab data structure. It only needs to store the type and the value corresponding to that type. The corresponding data structure is as follows:
```go
type eface struct {
	_type *_type
	data  unsafe.Pointer
}
```
From this data structure, we can see that an empty interface is `nil` only when both fields are `nil`. The empty interface has two main purposes: first, to implement “generics”; second, to use reflection.


## II. Type Conversion

Let’s use a concrete example to illustrate how an interface performs type conversion. First, let’s look at pointer type conversion.


### 1. Pointer Types
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

//go:noinline
func (s *Student) sayHello(name string) string {
	return fmt.Sprintf("%v: Hello %v, nice to meet you.\n", s.name, name)
}

//go:noinline
func (s *Student) sayGoodbye(name string) string {
	return fmt.Sprintf("%v: Hi %v, see you next time.\n", s.name, name)
}

```
Use the `go build` and `go tool` commands to turn the above code into assembly code:
```go
$ go tool compile -S -N -l main.go >main.s1 2>&1
```
There are 3 operations in the `main` method. Focus on the latter 2 operations involving `interface`:

1. Initialize a pointer to a Student object  
2. Convert the pointer to the Student object into an interface  
3. Call the interface method  

> Common meanings of registers in Plan 9 assembly:  
> BP: Stack base, the start position of the stack frame (a function’s stack is called a stack frame).  
> SP: Stack top, the end position of the stack frame.  
> PC: The IP register; stores the address of the next instruction to be executed by the CPU.  
> TLS: A virtual register. It represents thread-local storage; in Golang, it stores the struct of the currently executing g.  


First, let’s look at the assembly code for Student initialization:
```go
0x0021 00033 (main.go:6)	LEAQ	type."".Student(SB), AX      // Put the address of type."".Student into AX
0x0028 00040 (main.go:6)	MOVQ	AX, (SP)                     // Store the value in AX in SP
0x002c 00044 (main.go:6)	PCDATA	$1, $0
0x002c 00044 (main.go:6)	CALL	runtime.newobject(SB)        // Call the runtime.newobject() method to create a Student object and store it in SB
0x0031 00049 (main.go:6)	MOVQ	8(SP), DI                    // Put the created Student object into DI
0x0036 00054 (main.go:6)	MOVQ	DI, ""..autotmp_2+40(SP)     // The compiler treats Student as a temporary variable, so it puts DI on the stack
0x003b 00059 (main.go:6)	MOVQ	$8, 8(DI)                    // (DI.Name).Len = 8
0x0043 00067 (main.go:6)	PCDATA	$0, $-2
0x0043 00067 (main.go:6)	CMPL	runtime.writeBarrier(SB), $0
0x004a 00074 (main.go:6)	JEQ	78
0x004c 00076 (main.go:6)	JMP	172
0x004e 00078 (main.go:6)	LEAQ	go.string."halfrost"(SB), AX  // Put the address of the "halfrost" string into AX
0x0055 00085 (main.go:6)	MOVQ	AX, (DI)                      // (DI.Name).Data = &"halfrost"
0x0058 00088 (main.go:6)	JMP	90
0x005a 00090 (main.go:6)	PCDATA	$0, $-1
```
First place \*\_type at the top of the (SP) stack. Then call runtime.newobject() to create a Student object. The value at the top of the (SP) stack is the argument to newobject().
```go
func newobject(typ *_type) unsafe.Pointer {
	return mallocgc(typ.size, typ, true)
}
```
`PCDATA` is used to generate PC tables. The instruction syntax for `PCDATA` is: `PCDATA tableid, tableoffset`. `PCDATA` takes two parameters: the first is the table type, and the second is the table address. `runtime.writeBarrier()` is a GC-related method; those interested can study its source code. The following is part of the assembly logic related to GC for a temporary `Student` object. Because there are `JMP` instructions, the code is split across different sections; the author has collected them together here.
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
The hexadecimal representation of 78 is 0x004e, and the hexadecimal representation of 172 is 0x00ac. First, compare whether the value stored in runtime.writeBarrier(SB) is the same as \$0. If they are the same, JMP to line 0x004e; if they are different, JMP to line 0x00ac. The code at line 0x004e and line 0x00ac is exactly the same: both put the address of the string "halfrost" into AX. However, after line 0x00ac finishes executing, it immediately calls runtime.gcWriteBarrier(SB). After execution completes, control returns to line 0x005a.

After the first step completes, three values are stored in memory. The temporary variable .autotmp\_2 is placed at the address +40(SP); it is the temporary Student object.

![](https://img.halfrost.com/Blog/ArticleImage/147_2_1.png)


Next is the second step: converting the Student object into an interface.
```go
0x005a 00090 (main.go:6)	MOVQ	""..autotmp_2+40(SP), AX
0x005f 00095 (main.go:6)	MOVQ	AX, ""..autotmp_1+48(SP)
0x0064 00100 (main.go:6)	LEAQ	go.itab.*"".Student,"".Person(SB), CX
0x006b 00107 (main.go:6)	MOVQ	CX, "".s+56(SP)
0x0070 00112 (main.go:6)	MOVQ	AX, "".s+64(SP)
```
After the few lines of assembly code above, the `itab` struct has been successfully constructed. The memory layout of `itab` can be found in the assembly code:
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
The first byte of the itab struct stores inter \*interfacetype, which here is the Person interface. The second byte stores \*\_type, which is the value generated in the first step and placed at the address of (SP). The fourth byte stores fun [1]uintptr, corresponding to the entry address of the sayGoodbye method. The fifth byte also stores fun [1]uintptr, corresponding to the entry address of the sayHello method. Recall the itab data structure from the previous section:
```go
type itab struct {
    inter *interfacetype // 8 bytes
    _type *_type         // 8 bytes
    hash  uint32 		 // 4 bytes, padding for memory alignment
    _     [4]byte        // 4 bytes
    fun   [1]uintptr     // 8 bytes
}
```
Now it is clear why `fun` only needs to store a function pointer. Each function pointer is 8 bytes. If the interface contains multiple functions, `fun` only needs to advance sequentially by multiple bytes. After the second step completes, the following values are stored in memory:

![](https://img.halfrost.com/Blog/ArticleImage/147_3_2.png)

In the second step, a new temporary variable `.autotmp_1` is created at the address `+48(SP)`. The `Student` temporary variable generated in the first step is then used to construct `*itab`. It is worth noting that although the assembly code does not show a function call that creates `iface`, the `iface` has already been created at this point.
```go
type iface struct {
    tab  *itab
    data unsafe.Pointer
}
```
As shown above, +56(SP) stores \*itab, and +64(SP) stores unsafe.Pointer. The pointer here is exactly the same as the pointer at +8(SP). Next comes the final step: calling the interface method.
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
First, retrieve the actual object on which the method is called and place it in `(SP)`. Then place the method’s input parameters in order starting at `+8(SP)`. After that, call the method corresponding to the function pointer. From the assembly code, you can see that `AX` directly loads the memory address stored in the `*itab` pointer, then applies an offset to `+32`; this is the memory address of the `sayHello` method to be called. Finally, the required arguments are popped from the top of the stack in sequence, completing the interface method call. Immediately before the method call, the state in memory is as follows. Pay particular attention to the address in `AX` and all argument information at the top of the stack.

![](https://img.halfrost.com/Blog/ArticleImage/147_4_1.png)

At the top of the stack, the method receiver and the arguments are stored in order. The call format can be represented as func(reciver, param1).


### 2. Struct Type

What are the differences between pointer types and struct types during type conversion? This section analyzes and compares them in detail. The test code is largely the same as for the pointer type; the only changes are that the type conversion is changed to use a struct, and the method implementation is also changed to a struct. Everything else remains unchanged.
```go
package main

import "fmt"

func main() {
	var s Person = Student{name: "halfrost"}
	s.sayHello("everyone")
}

type Person interface {
	sayHello(name string) string
	sayGoodbye(name string) string
}

type Student struct {
	name string
}

//go:noinline
func (s Student) sayHello(name string) string {
	return fmt.Sprintf("%v: Hello %v, nice to meet you.\n", s.name, name)
}

//go:noinline
func (s Student) sayGoodbye(name string) string {
	return fmt.Sprintf("%v: Hi %v, see you next time.\n", s.name, name)
}
```
Use the same command to generate the corresponding assembly code:
```go
$ go tool compile -S -N -l main.go >main.s2 2>&1
```
Compare the same three steps:

1. Initialize the Student object
2. Convert the Student object to an interface
3. Call the interface method
```go
0x0021 00033 (main.go:6)	XORPS	X0, X0                       // Set X0 to 0
0x0024 00036 (main.go:6)	MOVUPS	X0, ""..autotmp_1+64(SP)     // Clear +64(SP)
0x0029 00041 (main.go:6)	LEAQ	go.string."halfrost"(SB), AX
0x0030 00048 (main.go:6)	MOVQ	AX, ""..autotmp_1+64(SP)
0x0035 00053 (main.go:6)	MOVQ	$8, ""..autotmp_1+72(SP)
0x003e 00062 (main.go:6)	MOVQ	AX, (SP)
0x0042 00066 (main.go:6)	MOVQ	$8, 8(SP)
0x004b 00075 (main.go:6)	PCDATA	$1, $0
```
This code places `"halfrost"` at the corresponding location in memory. Lines 1–8 of the code above copy the address of the string `"halfrost"` and its length, 8, into `+0(SP)`, `+8(SP)`, `+64(SP)`, and `+72(SP)`. From this, we can understand how ordinary temporary variables are laid out in memory. As shown in the assembly code above, the compiler determined that this variable is only a temporary variable, so it did not even call `runtime.newobject()`; it simply generated each of its primitive-typed fields and placed them in memory.


![](https://img.halfrost.com/Blog/ArticleImage/147_6_.png)
```go
0x004b 00075 (main.go:6)	CALL	runtime.convTstring(SB)
0x0050 00080 (main.go:6)	MOVQ	16(SP), AX
0x0055 00085 (main.go:6)	MOVQ	AX, ""..autotmp_2+40(SP)
0x005a 00090 (main.go:6)	LEAQ	go.itab."".Student,"".Person(SB), CX
0x0061 00097 (main.go:6)	MOVQ	CX, "".s+48(SP)
0x0066 00102 (main.go:6)	MOVQ	AX, "".s+56(SP)
```
The above code generates an interface. Line 1 calls `runtime.convTstring()`.
```go
func convTstring(val string) (x unsafe.Pointer) {
	if val == "" {
		x = unsafe.Pointer(&zeroVal[0])
	} else {
		x = mallocgc(unsafe.Sizeof(val), stringType, true)
		*(*string)(x) = val
	}
	return
}
```
`runtime.convTstring()` takes the input argument `"halfrost"` and length `8` from the top of the stack at `+0(SP)`. It creates a string variable on the stack, returns its pointer into `+16(SP)`, and copies it to `+40(SP)`. Line 4 generates the `itab` pointer; this is the same as in the previous chapter, so we will not go into it again. At this point, the `iface` has been created, with `\*itab` and `unsafe.Pointer` stored at `+48(SP)` and `+56(SP)`, respectively.


![](https://img.halfrost.com/Blog/ArticleImage/147_5_1.png)
```go
0x006b 00107 (main.go:7)	MOVQ	"".s+48(SP), AX
0x0070 00112 (main.go:7)	TESTB	AL, (AX)
0x0072 00114 (main.go:7)	MOVQ	32(AX), AX
0x0076 00118 (main.go:7)	MOVQ	"".s+56(SP), CX
0x007b 00123 (main.go:7)	MOVQ	CX, (SP)
0x007f 00127 (main.go:7)	LEAQ	go.string."everyone"(SB), CX
0x0086 00134 (main.go:7)	MOVQ	CX, 8(SP)
0x008b 00139 (main.go:7)	MOVQ	$8, 16(SP)
0x0094 00148 (main.go:7)	CALL	AX
```
The final step is to call the interface method. This step is basically the same as the process in the previous section. First, find the function pointer through the itab pointer. Then place all the input arguments for the method to be called at the top of the stack. Finally, make the call. At this point, the memory layout is shown below:

![](https://img.halfrost.com/Blog/ArticleImage/147_7_0.png)


At this point, some readers may be wondering why there is no call to `runtime.convT2I()` in the struct type conversion either. I believe this is due to certain compiler optimizations.
```go
func convT2I(tab *itab, elem unsafe.Pointer) (i iface) {
	t := tab._type
	if raceenabled {
		raceReadObjectPC(t, elem, getcallerpc(), funcPC(convT2I))
	}
	if msanenabled {
		msanread(elem, t.size)
	}
	x := mallocgc(t.size, t, true)
	typedmemmove(t, x, elem)
	i.tab = tab
	i.data = x
	return
}
```
`runtime.convT2I()` generates an `iface`, allocates `iface.data` on the heap, and calls `typedmemmove()`. I found two related PRs; take a look if you’re interested: [optimize convT2I as a two-word copy when T is pointer-shaped](https://go-review.googlesource.com/c/go/+/20901/9), [cmd/compile: optimize remaining convT2I calls](https://go-review.googlesource.com/c/go/+/20902). Since this only involves a type conversion, constructing `\*itab` and `unsafe.Pointer` in memory is sufficient. The compiler considers it unnecessary—and redundant—to call `runtime.convT2I()` just to construct an `iface`.

### 3. Implicit Type Conversion

In day-to-day development, be careful with implicit type conversions, as they can easily introduce bugs. For example, a custom `error` type can become non-`nil` because of a hidden type conversion. The code is as follows:
```go
package main

import "fmt"

type GrpcError struct{}

func (e GrpcError) Error() string {
	return "GrpcError"
}

func main() {
	err := cal()
	fmt.Println(err)            // Prints: <nil>
	fmt.Println(err == nil)     // Prints: false
}

func cal() error {
	var err *GrpcError = nil
	return err
}
```
A project may wrap errors thrown by the gRPC framework in another layer to make the returned error messages more readable. What is often overlooked is that this can inadvertently introduce bugs. In the code above, `main` checks whether `err` is `nil`, and the answer is `false`. `error` is a non-empty interface; its underlying data structure is `iface`. Although `data` is `nil`, `*itab` is not, so `err == nil` evaluates to `false`.

At this point, some readers may wonder what this implicit conversion is useful for. This conversion is, in fact, an ingenious design. From the first two sections of this chapter, we know that when an object is passed to a value of type `interface{}`, the compiler automatically converts it into the corresponding type data structure. Without this design, the Go language designers would have needed to create a separate set of type data structures specifically to support reflection. The Go designers recognized the characteristics of interfaces and implemented reflection based on their dynamic type conversion, achieving more with less effort.


## III. Type Assertion

Another important use of interfaces is type assertion. For non-empty interfaces and empty interfaces, let’s examine how the underlying assembly code handles them respectively.

### 1. Non-Empty Interface

The test code is as follows:
```go
func main() {
	var s Person = &Student{name: "halfrost"}
	v, ok := s.(Person)
	if !ok {
		fmt.Printf("%v\n", v)
	}
}
```
Use the same command to convert the above code into assembly code.
```go
go tool compile -S -N -l main.go >main.s3 2>&1
```
The first line of the `main` function creates a pointer to a `Student` object and assigns it to the `Person` interface. This code appeared multiple times in the previous chapter, and the corresponding assembly code has not changed:
```go
0x002f 00047 (main.go:8)	LEAQ	type."".Student(SB), AX
0x0036 00054 (main.go:8)	MOVQ	AX, (SP)
0x003a 00058 (main.go:8)	PCDATA	$1, $0
0x003a 00058 (main.go:8)	CALL	runtime.newobject(SB)
0x003f 00063 (main.go:8)	MOVQ	8(SP), DI
0x0044 00068 (main.go:8)	MOVQ	DI, ""..autotmp_7+80(SP)
0x0049 00073 (main.go:8)	MOVQ	$8, 8(DI)
0x0051 00081 (main.go:8)	PCDATA	$0, $-2
0x0051 00081 (main.go:8)	CMPL	runtime.writeBarrier(SB), $0
0x0058 00088 (main.go:8)	JEQ	95
0x005a 00090 (main.go:8)	JMP	529
0x005f 00095 (main.go:8)	LEAQ	go.string."halfrost"(SB), AX
0x0066 00102 (main.go:8)	MOVQ	AX, (DI)
0x0069 00105 (main.go:8)	JMP	107
0x006b 00107 (main.go:8)	PCDATA	$0, $-1
0x006b 00107 (main.go:8)	MOVQ	""..autotmp_7+80(SP), AX
0x0070 00112 (main.go:8)	MOVQ	AX, ""..autotmp_3+88(SP)
0x0075 00117 (main.go:8)	LEAQ	go.itab.*"".Student,"".Person(SB), CX
0x007c 00124 (main.go:8)	MOVQ	CX, "".s+120(SP)
0x0081 00129 (main.go:8)	MOVQ	AX, "".s+128(SP)
```
We will not analyze the code above again here; see the previous chapter for details. The `iface` struct has also been generated, at +120(SP) ~ +128(SP). At this point, the memory layout is as shown below:

![](https://img.halfrost.com/Blog/ArticleImage/147_8_0.png)

The following code is the key part of type inference. Since the assembly code is quite long, I have split it into two parts. The first part is the key section for the type assertion.
```go
0x0089 00137 (main.go:9)	XORPS	X0, X0
0x008c 00140 (main.go:9)	MOVUPS	X0, ""..autotmp_4+152(SP)
0x0094 00148 (main.go:9)	MOVQ	"".s+120(SP), AX
0x0099 00153 (main.go:9)	MOVQ	"".s+128(SP), CX
0x00a1 00161 (main.go:9)	LEAQ	type."".Person(SB), DX
0x00a8 00168 (main.go:9)	MOVQ	DX, (SP)
0x00ac 00172 (main.go:9)	MOVQ	AX, 8(SP)
0x00b1 00177 (main.go:9)	MOVQ	CX, 16(SP)
0x00b6 00182 (main.go:9)	CALL	runtime.assertI2I2(SB)
```
In the code above, you can see that to call the `runtime.assertI2I2()` method, three arguments are pushed onto the top of the stack consecutively: \*interfacetype, \*itab, and unsafe.Pointer. This corresponds to the source code of `runtime.assertI2I2()`:
```go
func assertI2I2(inter *interfacetype, i iface) (r iface, b bool) {
	tab := i.tab
	if tab == nil {
		return
	}
	if tab.inter != inter {
		tab = getitab(inter, tab._type, true)
		if tab == nil {
			return
		}
	}
	r.tab = tab
	r.data = i.data
	b = true
	return
}
```
Although the code above has two input parameters, `iface` can be split into two parts: `*itab` and `unsafe.Pointer`. Therefore, the contiguous `+0(SP)`, `+8(SP)`, and `+16(SP)` at the top of the stack satisfy the function’s parameter requirements. The logic of the code above is very simple: if `itab.inter` in `iface` is the same as the first parameter, `*interfacetype`, it means the types are identical, so it directly returns the input `iface` with the same type, and the boolean value is `true`. If `itab.inter` in `iface` is different from the first parameter, `*interfacetype`, it reconstructs `tab` based on `*interfacetype` and `iface.tab`. The construction process looks up `itabTable`. If the types do not match, or they do not belong to the same interface type, it fails. The third parameter of the `getitab()` method is `canfail`; here `true` is passed, indicating that constructing `*itab` is allowed to fail, and `nil` is returned after failure. Back in the `runtime.assertI2I2()` method, if `tab` construction fails, it is `nil`, so the method returns directly. As a result, the externally received `iface` is `nil`, and `bool` is also `false`.

The second part is merely the assignment part and is straightforward.
```go
0x00bb 00187 (main.go:9)	MOVQ	24(SP), AX
0x00c0 00192 (main.go:9)	MOVQ	32(SP), CX
0x00c5 00197 (main.go:9)	MOVBLZX	40(SP), DX
0x00ca 00202 (main.go:9)	MOVQ	AX, ""..autotmp_4+152(SP)
0x00d2 00210 (main.go:9)	MOVQ	CX, ""..autotmp_4+160(SP)
0x00da 00218 (main.go:9)	MOVB	DL, ""..autotmp_5+71(SP)
0x00de 00222 (main.go:9)	MOVQ	""..autotmp_4+152(SP), AX
0x00e6 00230 (main.go:9)	MOVQ	""..autotmp_4+160(SP), CX
0x00ee 00238 (main.go:9)	MOVQ	AX, "".v+104(SP)
0x00f3 00243 (main.go:9)	MOVQ	CX, "".v+112(SP)
0x00f8 00248 (main.go:9)	MOVBLZX	""..autotmp_5+71(SP), AX
0x00fd 00253 (main.go:9)	MOVB	AL, "".ok+70(SP)
```
The return values of `runtime.assertI2I2()` are placed in `+24(SP)`, `+32(SP)`, and `+40(SP)`. There are three return values because `iface` is split into two values. Note that `+40(SP)` uses the `MOVBLZX` instruction, because `bool` is `uint8`. During the subsequent moves, only the low 8 bits are used, so `DL` is used instead of `DX`. After being transferred through temporary variables, the final return values are placed in the variables `v` and `ok`. `v` is at `+104(SP)` ~ `+112(SP)` in memory, and `ok` is at `+70(SP)`.

One more point here: if the type assertion is to a concrete type, the compiler constructs the `iface` directly instead of calling `runtime.assertI2I2()` to construct it. For example, in the following code, the type assertion specifies a concrete type:
```go
func main() {
	var s Person = &Student{name: "halfrost"}
	v, ok := s.(*Student)
	if !ok {
		fmt.Printf("%v\n", v)
	}
}
```
When the compiler lowers the conversion to assembly, it performs an optimization and no longer calls `runtime.assertI2I2()` to look up `itabTable`. The specific handling logic is shown in the assembly code below.
```go
0x0075 00117 (main.go:8)	LEAQ	go.itab.*"".Student,"".Person(SB), CX
0x007c 00124 (main.go:8)	MOVQ	CX, "".s+104(SP)
0x0081 00129 (main.go:8)	MOVQ	AX, "".s+112(SP)
0x0086 00134 (main.go:9)	MOVQ	$0, ""..autotmp_3+96(SP)
0x008f 00143 (main.go:9)	MOVQ	"".s+112(SP), AX
0x0094 00148 (main.go:9)	LEAQ	go.itab.*"".Student,"".Person(SB), CX
0x009b 00155 (main.go:9)	NOP
0x00a0 00160 (main.go:9)	CMPQ	"".s+104(SP), CX
```
In the code above, `iface` is constructed first: the `*itab` is stored at `+104(SP)` in memory, and the `unsafe.Pointer` is stored at `+112(SP)`. Then, during the type assertion, `*itab` is constructed again, and the new `*itab` is compared with the previous `*itab` at `+104(SP)`.

Summary: **The essence of type assertions on non-empty interfaces is comparing the `*itab` in `iface`**. If the `*itab` matches successfully, the return value is assembled in memory. If the match fails, the registers are cleared directly and the zero value is returned.


### 2. Empty Interface


Next, let’s look at what type assertions on empty interfaces look like under the hood. The test code is as follows:
```go
func main() {
	var s interface{} = &Student{name: "halfrost"}
	v, ok := s.(int)
	if !ok {
		fmt.Printf("%v\n", v)
	}
}
```
Use the same command to convert the above code into assembly code.
```go
go tool compile -S -N -l main.go >main.s4 2>&1
```
The first line of the `main` function creates a pointer to a `Student` object and assigns it to an empty interface. This code appeared multiple times in the previous chapter, and the corresponding assembly code has not changed:
```go
0x002f 00047 (main.go:8)	XORPS	X0, X0
0x0032 00050 (main.go:8)	MOVUPS	X0, ""..autotmp_8+136(SP)
0x003a 00058 (main.go:8)	LEAQ	""..autotmp_8+136(SP), AX
0x0042 00066 (main.go:8)	MOVQ	AX, ""..autotmp_7+88(SP)
0x0047 00071 (main.go:8)	TESTB	AL, (AX)
0x0049 00073 (main.go:8)	MOVQ	$8, ""..autotmp_8+144(SP)
0x0055 00085 (main.go:8)	LEAQ	go.string."halfrost"(SB), CX
0x005c 00092 (main.go:8)	MOVQ	CX, ""..autotmp_8+136(SP)
0x0064 00100 (main.go:8)	MOVQ	AX, ""..autotmp_3+96(SP)
0x0069 00105 (main.go:8)	LEAQ	type.*"".Student(SB), CX
0x0070 00112 (main.go:8)	MOVQ	CX, "".s+120(SP)
0x0075 00117 (main.go:8)	MOVQ	AX, "".s+128(SP)
```
Assigning to an empty interface does not create a new temporary variable; the data all resides on the stack. After the code above finishes executing, it has assembled an `eface` in memory, whose memory layout is as follows:

![](https://img.halfrost.com/Blog/ArticleImage/147_9_0.png)

In Chapter 2, we learned that `eface` is the data structure for an empty interface. It contains two fields:
```go
type eface struct {
    _type *_type
    data  unsafe.Pointer
}
```
From memory, we can see that the eface’s \*\_type is stored at +120(SP), and the unsafe.Pointer is stored at +128(SP). Note that in the figure above, several values are the same: the values at +88(SP), +96(SP), and +128(SP) are identical to the value stored in the AX register; all of them hold the address value of +136(SP). Now let’s look at the assembly implementation of type assertion for an empty interface:
```go
0x007d 00125 (main.go:9)	MOVQ	"".s+120(SP), AX
0x0082 00130 (main.go:9)	MOVQ	"".s+128(SP), CX
0x008a 00138 (main.go:9)	LEAQ	type.int(SB), DX
0x0091 00145 (main.go:9)	CMPQ	DX, AX
0x0094 00148 (main.go:9)	JEQ	155
0x0096 00150 (main.go:9)	JMP	423
```
From the code above, we can see that a type assertion on an empty interface is very simple: it compares the first field of `eface`, \*\_type, with the \*\_type of the type being checked, and if they are the same, it prepares the subsequent return value.
```go
0x009b 00155 (main.go:9)	MOVQ	(CX), AX
0x009e 00158 (main.go:9)	MOVL	$1, CX
0x00a3 00163 (main.go:9)	JMP	165
0x00a5 00165 (main.go:9)	MOVQ	AX, ""..autotmp_4+80(SP)
0x00aa 00170 (main.go:9)	MOVB	CL, ""..autotmp_5+71(SP)
0x00ae 00174 (main.go:9)	MOVQ	""..autotmp_4+80(SP), AX
0x00b3 00179 (main.go:9)	MOVQ	AX, "".v+72(SP)
0x00b8 00184 (main.go:9)	MOVBLZX	""..autotmp_5+71(SP), AX
0x00bd 00189 (main.go:9)	MOVB	AL, "".ok+70(SP)
```
If the type assertion succeeds, the return values are prepared. After being passed through several intermediate temporary variables, `v` is ultimately stored in memory at `+72(SP)`, and `ok` is stored in memory at `+70(SP)`. The final state in memory is shown below:


![](https://img.halfrost.com/Blog/ArticleImage/147_10_.png)
```go
0x01a7 00423 (main.go:11)	XORL	AX, AX
0x01a9 00425 (main.go:11)	XORL	CX, CX
0x01ab 00427 (main.go:9)	JMP	165
0x01b0 00432 (main.go:9)	NOP
```
If the assertion fails, the AX and CX registers are cleared. AX and CX hold the two fields in the `eface` struct.

Summary: **The essence of empty-interface type inference is comparing the `*_type` in `eface`**. If `*_type` matches successfully, the return value is assembled in memory. If the match fails, the registers are cleared directly and the default value is returned.

## IV. Type Queries Type Switches

A type query is also a kind of interface operation. This section analyzes the underlying principles of type queries in detail. The first point to clarify is that the target of a type query must be an interface type. Since a concrete type is fixed and does not change after declaration, variables of concrete types do not have type-query operations.

First, establish a convention: the first line of the `main` function has no impact on this section, whether it creates a `Student` or a `*Student`.
```go
	var s Person = &Student{name: "halfrost"}
	var s Person = Student{name: "halfrost"}
```
The two lines above both produce an interface type like `Person`. The differences in the generation process were explained in detail in Chapter 2, Type Conversion, so they will not be repeated here. This chapter focuses on the `switch-case` content below.


### 1. Non-Empty Interface

This section will use the following code for an in-depth study.
```go
func main() {
	var s Person = &Student{name: "halfrost"}
	switch s.(type) {
	case Person:
		person := s.(Person)
		person.sayHello("everyone")
	case *Student:
		student := s.(*Student)
		student.sayHello("everyone")
	case Student:
		student := s.(Student)
		student.sayHello("everyone")
	}
}
```
There is one more point to clarify about Type Switches. The type name after `case` can be either a non-interface type name or an interface type name. As in the code above, `case` can be followed by the interface name `Person`, or by a non-interface type name such as `Student`. The type that an interface variable matches first is the type it will be treated as. For example, if it matches `Person` first, then `s` is of type `Person`, and matching will not continue further. **The `fallthrough` statement cannot be used in Type Switches**. If you force its use, the compiler will report an error: `fallthrough statement out of placecompiler`. This is also reasonable: no single type can satisfy all types. Converting the code above into assembly:
```go
$ go tool compile -S -N -l main.go >main.s5 2>&1
```
We will not go into the generated assembly code for creating the `Person` type here; instead, we will start the analysis directly from the `switch`. There are three `case` branches here, so we will analyze them in three separate parts. First is the first part: matching the `Person` type. The figure below shows the state of memory at this point:

![](https://img.halfrost.com/Blog/ArticleImage/147_11_1.png)
```go
0x0086 00134 (main.go:9)	MOVQ	"".s+96(SP), AX
0x008b 00139 (main.go:9)	MOVQ	"".s+104(SP), CX
0x0090 00144 (main.go:9)	MOVQ	AX, ""..autotmp_8+128(SP)
0x0098 00152 (main.go:9)	MOVQ	CX, ""..autotmp_8+136(SP)
0x00a0 00160 (main.go:9)	TESTQ	AX, AX
0x00a3 00163 (main.go:9)	JNE	170
0x00a5 00165 (main.go:9)	JMP	750
0x00aa 00170 (main.go:9)	MOVL	16(AX), AX
0x00ad 00173 (main.go:9)	MOVL	AX, ""..autotmp_10+52(SP)
```
The `iface` generated for `Person` is located in memory at `+128(SP)` to `+136(SP)`. `(16)AX` retrieves the hash value from `*itab`, which is then stored at `+52(SP)`. Next comes the code for matching `case Person`.
```go
0x00b1 00177 (main.go:10)	MOVQ	""..autotmp_8+128(SP), AX
0x00b9 00185 (main.go:10)	MOVQ	""..autotmp_8+136(SP), CX
0x00c1 00193 (main.go:10)	LEAQ	type."".Person(SB), DX
0x00c8 00200 (main.go:10)	MOVQ	DX, (SP)
0x00cc 00204 (main.go:10)	MOVQ	AX, 8(SP)
0x00d1 00209 (main.go:10)	MOVQ	CX, 16(SP)
0x00d6 00214 (main.go:10)	PCDATA	$1, $1
0x00d6 00214 (main.go:10)	CALL	runtime.assertI2I2(SB)
0x00db 00219 (main.go:10)	MOVBLZX	40(SP), AX
0x00e0 00224 (main.go:10)	MOVB	AL, ""..autotmp_9+51(SP)
0x00e4 00228 (main.go:10)	TESTB	AL, AL
0x00e6 00230 (main.go:10)	JNE	237
0x00e8 00232 (main.go:10)	JMP	383
0x00ed 00237 (main.go:10)	PCDATA	$1, $-1
0x00ed 00237 (main.go:10)	JMP	239
```
The code above mainly calls runtime.assertI2I2(). The source code for this method was analyzed in Chapter 3, Type Inference, so we will not repeat it here. This method takes two parameters: \*interfacetype and iface. DX holds the address of type(Person), i.e. \*interfacetype, while AX and CX hold the iface.\*itab and iface.unsafe.Pointer of \*Student, respectively. If the match succeeds, the returned bool is placed in AX. If it is true, TESTB is not equal, so JNE 237 is executed. If it is false, it means the match with Person failed; TESTB is equal, so JMP 383 is executed. First, let’s look at the successful match case, where TESTB is not equal:
```go
0x00ed 00237 (main.go:10)	PCDATA	$1, $-1
0x00ed 00237 (main.go:10)	JMP	239
0x00ef 00239 (main.go:11)	XORPS	X0, X0
0x00f2 00242 (main.go:11)	MOVUPS	X0, ""..autotmp_5+160(SP)
0x00fa 00250 (main.go:11)	MOVQ	"".s+96(SP), AX
0x00ff 00255 (main.go:11)	MOVQ	"".s+104(SP), CX
0x0104 00260 (main.go:11)	LEAQ	type."".Person(SB), DX
0x010b 00267 (main.go:11)	MOVQ	DX, (SP)
0x010f 00271 (main.go:11)	MOVQ	AX, 8(SP)
0x0114 00276 (main.go:11)	MOVQ	CX, 16(SP)
0x0119 00281 (main.go:11)	PCDATA	$1, $0
0x0119 00281 (main.go:11)	CALL	runtime.assertI2I(SB)
0x011e 00286 (main.go:11)	MOVQ	24(SP), AX
0x0123 00291 (main.go:11)	MOVQ	32(SP), CX
0x0128 00296 (main.go:11)	MOVQ	AX, ""..autotmp_5+160(SP)
0x0130 00304 (main.go:11)	MOVQ	CX, ""..autotmp_5+168(SP)
0x0138 00312 (main.go:11)	MOVQ	AX, "".person+112(SP)
0x013d 00317 (main.go:11)	MOVQ	CX, "".person+120(SP)
```
Before invoking Type Switches, the memory diagram shows that +96(SP) stores \*itab, and +104(SP) stores unsafe.Pointer. Before calling runtime.assertI2I(), the three arguments are first placed at the top of the stack. (SP), +8(SP), and +16(SP) hold \*interfacetype, \*itab, and unsafe.Pointer, respectively. The source code of runtime.assertI2I() is as follows:
```go
func assertI2I(inter *interfacetype, i iface) (r iface) {
	tab := i.tab
	if tab == nil {
		// explicit conversions require non-nil interface value.
		panic(&TypeAssertionError{nil, nil, &inter.typ, ""})
	}
	if tab.inter == inter {
		r.tab = tab
		r.data = i.data
		return
	}
	r.tab = getitab(inter, tab._type, false)
	r.data = i.data
	return
}
```
The `assertI2I()` method returns one fewer `bool` variable than the `assertI2I2()` method. Therefore, the function name also has one fewer `2`. The `assertI2I()` method is more dangerous than `assertI2I2()`, because it may panic. If the match succeeds, it returns an `iface`; the value inside this `iface` is the same as the value inside the input `iface`, meaning it has been copied. The returned `iface.*itab` is placed in `+112(SP)`. Next is the code that invokes the method.
```go
0x0142 00322 (main.go:12)	MOVQ	"".person+112(SP), AX
0x0147 00327 (main.go:12)	TESTB	AL, (AX)
0x0149 00329 (main.go:12)	MOVQ	32(AX), AX
0x014d 00333 (main.go:12)	MOVQ	"".person+120(SP), CX
0x0152 00338 (main.go:12)	MOVQ	CX, (SP)
0x0156 00342 (main.go:12)	LEAQ	go.string."everyone"(SB), CX
0x015d 00349 (main.go:12)	MOVQ	CX, 8(SP)
0x0162 00354 (main.go:12)	MOVQ	$8, 16(SP)
0x016b 00363 (main.go:12)	CALL	AX
```
The code above appeared several times in Chapter 2 on type conversions, so we won’t repeat it here. The gist is to find the function pointer, place the arguments required by the function on top of the stack, and then invoke the method. Returning to the point after the `runtime.assertI2I2()` call: if the `bool` is `false`, it means matching against `Person` failed, so `TESTB` evaluates as equal and `JMP 383` is executed.
```go
0x017f 00383 (main.go:9)	CMPL	""..autotmp_10+52(SP), $309932300
0x0187 00391 (main.go:10)	JEQ	398
0x0189 00393 (main.go:10)	JMP	546
```
Compare +52(SP) with 309932300; +52(SP) is the previously stored hash value. If they are equal, jump to 398. The hexadecimal representation of 309932300 is 0x1279310c. Searching for this value in memory shows that it is the hash value inside the \*itab for the \*Student type.
```go
go.itab.*"".Student,"".Person SRODATA dupok size=40
	0x0000 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
	0x0010 0c 31 79 12 00 00 00 00 00 00 00 00 00 00 00 00  .1y.............
	0x0020 00 00 00 00 00 00 00 00                          ........
```
As shown above, the first 16 bytes in memory are , respectively. Starting from the lower 4 bytes of byte 24 is the hash value; the upper 4 bytes are padding bits for memory alignment, and they are all filled with 0 here. If the hash values are the same, it means a match, then JEQ 398. If there is no match, then JMP	546. First, look at the matched case:
```go
0x018e 00398 (main.go:13)	LEAQ	go.itab.*"".Student,"".Person(SB), AX
0x0195 00405 (main.go:13)	CMPQ	""..autotmp_8+128(SP), AX
0x019d 00413 (main.go:13)	JEQ	418
```
A hash match is only the first step; it also needs to match whether `*itab` is the same. Only when both the hash and `*itab` match is it considered to have reached the corresponding `case`. Next comes the type assertion process:
```go
0x01b5 00437 (main.go:14)	MOVQ	"".s+104(SP), AX
0x01ba 00442 (main.go:14)	MOVQ	"".s+96(SP), CX
0x01bf 00447 (main.go:14)	LEAQ	go.itab.*"".Student,"".Person(SB), DX
0x01c6 00454 (main.go:14)	CMPQ	CX, DX
0x01c9 00457 (main.go:14)	JEQ	464
0x01cb 00459 (main.go:14)	JMP	806
0x01d0 00464 (main.go:14)	MOVQ	AX, "".student+56(SP)
```
The above code corresponds to line 7 in the main function.
```go
student := s.(*Student)
```
Here, the type assertion also performs one comparison against `*itab`. If it matches, the next step is to prepare the arguments before the method call, placing all arguments at the top of the stack.
```go
0x01d5 00469 (main.go:15)	TESTB	AL, (AX)
0x01d7 00471 (main.go:15)	MOVQ	(AX), CX
0x01da 00474 (main.go:15)	MOVQ	8(AX), AX
0x01de 00478 (main.go:15)	MOVQ	CX, ""..autotmp_11+176(SP)
0x01e6 00486 (main.go:15)	MOVQ	AX, ""..autotmp_11+184(SP)
0x01ee 00494 (main.go:15)	MOVQ	CX, (SP)
0x01f2 00498 (main.go:15)	MOVQ	AX, 8(SP)
0x01f7 00503 (main.go:15)	LEAQ	go.string."everyone"(SB), AX
0x01fe 00510 (main.go:15)	MOVQ	AX, 16(SP)
0x0203 00515 (main.go:15)	MOVQ	$8, 24(SP)
0x020c 00524 (main.go:15)	PCDATA	$1, $0
0x020c 00524 (main.go:15)	CALL	"".Student.sayHello(SB)
```
Calling the `sayHello()` method with a \*Student pointer requires 4 parameters in total, placed at memory locations (SP), +8(SP), +16(SP), and +24(SP), respectively. The contents placed there, in order, are \*("halfrost"), 8, \*(everyone), and 8. When the method is finally called, these 4 input parameters are taken from the top of the stack to complete the call.

Back to the case judgment: if there is no match, it will JMP 546:
```go
0x0222 00546 (main.go:9)	CMPL	""..autotmp_10+52(SP), $-736059430
0x022a 00554 (main.go:10)	JEQ	561
```
This code is again checking the hash value. This indicates that if the second `case` does not match, it starts matching the third `case`. Note that what is printed here is a signed decimal number; when calculating the hash, it needs to be converted to hexadecimal. Decimal `-736059430` converted to binary is `10101011110111110110000000100110`. For a negative number, the one's complement keeps the sign bit unchanged and inverts every other bit, so after inversion it becomes `11010100001000001001111111011001`. The two's complement of a negative number is the one's complement + 1, so the two's complement is `11010100001000001001111111011010`, which converted to hexadecimal is `0xd4209fda`. Searching for `0xd4209fda` in memory gives the following memory layout:
```go
go.itab."".Student,"".Person SRODATA dupok size=40
	0x0000 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
	0x0010 da 9f 20 d4 00 00 00 00 00 00 00 00 00 00 00 00  .. .............
	0x0020 00 00 00 00 00 00 00 00                          ........
```
You can see that 0xd4209fda is exactly the hash value of the \*itab corresponding to the Student type. The following assembly code is completely identical in logic to the code for the second case, so the full assembly is not shown here again. After the hash value matches, the \*itab is matched as well. If both matches succeed, execution enters the case and performs the type assertion. The type assertion performs one more \*itab comparison; if they are the same, it prepares the arguments before the method call. All input arguments are placed at the top of the stack, and finally the method is called.

If every case above fails to match, it will JMP 367 and exit the Type Switches.
```go
0x016f 00367 (main.go:9)	PCDATA	$1, $-1
0x016f 00367 (main.go:9)	MOVQ	192(SP), BP
0x0177 00375 (main.go:9)	ADDQ	$200, SP
0x017e 00382 (main.go:9)	RET
```
The assembly code for exiting does not contain much processing logic; it just cleans up the frame and returns. Summary:

- If a Type Switches case is followed by the type name of a non-empty interface, it calls runtime.assertI2I2() to determine whether the case matches. If the match succeeds, the type assertion inside the case calls runtime.assertI2I() again to obtain the iface.
- If a Type Switches case is followed by the type name of a non-interface, it first matches the type based on the hash value. If the hash matches, it then matches \*itab. Only when both match successfully can execution enter the case body. After entering, the type assertion will check once more whether \*itab is consistent.


### 2. Empty Interface

Now let’s look at the empty interface. In this section, we will use the following code for an in-depth investigation.
```go
func main() {
	var s interface{} = &Student{name: "halfrost"}
	switch s.(type) {
	case Person:
		person := s.(Person)
		person.sayHello("everyone")
	case *Student:
		student := s.(*Student)
		student.sayHello("everyone")
	case Student:
		student := s.(Student)
		student.sayHello("everyone")
	}
}
```
Use the same command to convert the above code into assembly code:
```go
$ go tool compile -S -N -l main.go >main.s6 2>&1
```
Because much of the logic is the same as for non-empty interfaces, we will focus here on the differences. The first line of the `main` function creates a pointer to `Student` and converts its type to `interface{}`. This code appeared in Chapter 2, so we will not go into it again here. First, let’s look at the second line of the `main` function:
```go
0x00b1 00177 (main.go:10)	MOVQ	""..autotmp_8+128(SP), AX
0x00b9 00185 (main.go:10)	MOVQ	""..autotmp_8+136(SP), CX
0x00c1 00193 (main.go:10)	LEAQ	type."".Person(SB), DX
0x00c8 00200 (main.go:10)	MOVQ	DX, (SP)
0x00cc 00204 (main.go:10)	MOVQ	AX, 8(SP)
0x00d1 00209 (main.go:10)	MOVQ	CX, 16(SP)
0x00d6 00214 (main.go:10)	PCDATA	$1, $1
0x00d6 00214 (main.go:10)	CALL	runtime.assertE2I2(SB)
```
As you can see, the assembly logic above is basically the same as the logic for a non-empty interface; only the method being called differs. The non-empty interface calls `runtime.assertI2I2()`, whereas here `runtime.assertE2I2()` is called. Its source code is as follows:
```go
func assertE2I2(inter *interfacetype, e eface) (r iface, b bool) {
	t := e._type
	if t == nil {
		return
	}
	tab := getitab(inter, t, true)
	if tab == nil {
		return
	}
	r.tab = tab
	r.data = e.data
	b = true
	return
}
```
The logic of this code is largely the same as `assertI2I2()`, except that here it converts an `eface` into an `iface`. By calling `getitab()`, the \_type in the `eface` is assembled into an \*itab, and then combined with the `eface`’s `data`, forming an `iface`. After a successful match enters the `case`, type inference is performed:
```go
0x00fa 00250 (main.go:11)	MOVQ	"".s+96(SP), AX
0x00ff 00255 (main.go:11)	MOVQ	"".s+104(SP), CX
0x0104 00260 (main.go:11)	LEAQ	type."".Person(SB), DX
0x010b 00267 (main.go:11)	MOVQ	DX, (SP)
0x010f 00271 (main.go:11)	MOVQ	AX, 8(SP)
0x0114 00276 (main.go:11)	MOVQ	CX, 16(SP)
0x0119 00281 (main.go:11)	PCDATA	$1, $0
0x0119 00281 (main.go:11)	CALL	runtime.assertE2I(SB)
```
The code logic here is also the same as for non-empty interfaces; only the method being called differs. Here, the runtime.assertE2I() method is called:
```go
func assertE2I(inter *interfacetype, e eface) (r iface) {
	t := e._type
	if t == nil {
		// explicit conversions require non-nil interface value.
		panic(&TypeAssertionError{nil, nil, &inter.typ, ""})
	}
	r.tab = getitab(inter, t, false)
	r.data = e.data
	return
}
```
runtime.assertE2I(), like runtime.assertI2I(), is a “dangerous” method and may panic. The method returns an iface. Next, the sayHello() method is called; the logic is exactly the same as for a non-empty interface. The matching process for the remaining two cases is also exactly the same as for a non-empty interface, so we won’t analyze it here.

It is worth noting that when matching the hash value of a non-interface type, the hash value is related only to the fields and methods, not to the concrete values stored in the fields. In other words, in the two matches against \*Student and Student for the non-empty interface and the empty interface, the type hash values are the same: 0x1279310c and 0xd4209fda. This is reasonable: different field values stored in an object do not change the object’s type. As long as the type is exactly the same, the hash value is the same. Summary:

- If a Type Switches case is followed by the type name of an empty interface, runtime.assertE2I2() will be called to determine whether the case matches. If the match succeeds, the type assertion inside the case will call runtime.assertE2I() again to obtain the iface.

## V. Dynamic Dispatch 

Although Go is not an object-oriented language in the strict sense, interfaces in Go can dynamically dispatch methods, enabling polymorphism-like behavior similar to that in object-oriented languages.

Polymorphism is a runtime behavior with the following characteristics:  
- A single type has the capability to take on multiple forms  
- It allows different objects to respond flexibly to the same message  
- It treats the objects being used in a generic way  
- Non-dynamic languages must implement it through inheritance and interfaces  

The test code in this section has already appeared in previous chapters; it is extracted here only to introduce the concept of dynamic dispatch separately.
```go
func main() {
	var s Person = &Student{name: "halfrost"}
	s.sayHello("everyone")
}
```
After converting the above code into assembly, draw the memory layout diagram based on the assembly code, as shown below:

![](https://img.halfrost.com/Blog/ArticleImage/147_4_1.png)

Find the assembly code for the method call:
```go
0x0075 00117 (main.go:7)    MOVQ    "".s+56(SP), AX
0x007a 00122 (main.go:7)    TESTB   AL, (AX)
0x007c 00124 (main.go:7)    MOVQ    32(AX), AX
0x0080 00128 (main.go:7)    MOVQ    "".s+64(SP), CX
0x0085 00133 (main.go:7)    MOVQ    CX, (SP)
0x0089 00137 (main.go:7)    LEAQ    go.string."everyone"(SB), CX
0x0090 00144 (main.go:7)    MOVQ    CX, 8(SP)
0x0095 00149 (main.go:7)    MOVQ    $8, 16(SP)
0x00a0 00160 (main.go:7)    CALL    AX
```
As you can see in the code above, in order to call a dynamically dispatched method, the AX register performs an address lookup based on the func pointer stored in \*itab; `32(AX)` locates the address of the method to be dispatched. It then places all the method’s required input arguments at the top of the stack. If dynamic dispatch were not performed here, how would the assembly code differ in its handling logic? Change the code to the following:
```go
func main() {
	var s *Student = &Student{name: "halfrost"}
	s.sayHello("everyone")
}
```
After converting it to assembly code, the extracted line containing the method call is as follows:
```go
0x004b 00075 (main.go:20)	MOVQ	AX, (SP)
0x004f 00079 (main.go:20)	LEAQ	go.string."everyone"(SB), AX
0x0056 00086 (main.go:20)	MOVQ	AX, 8(SP)
0x005b 00091 (main.go:20)	MOVQ	$8, 16(SP)
0x0064 00100 (main.go:20)	PCDATA	$1, $0
0x0064 00100 (main.go:20)	CALL	"".(*Student).sayHello(SB)
```
As you can see, the code no longer includes the method-addressing process. Here, it directly places the input arguments at the top of the stack and calls the method.

Summary: the `fun` pointer stores the starting address of the function list implemented by the concrete type. The method to be called can be found through address lookup. When different concrete types are passed into the function, what actually gets called are different function implementations, thereby achieving polymorphism.

Regarding the dynamic dispatch process, there are actually two sources of performance overhead. One is the dynamic method call mentioned above. This is an indirect call through a function pointer, and it also requires a jump after dynamically computing the address offset. The other is the process of constructing the `iface`. In the first dynamic-dispatch code path, a complete `iface` is constructed in memory. In the second code path, which directly calls the method, no `iface` is constructed; instead, the input arguments are placed directly at the top of the stack, and that method is called directly. Given these two sources of overhead, some readers may worry that the cost is significant. Quite a few people on GitHub have published benchmark code for this. I won’t include the full benchmark code here; I’ll state the conclusions directly:

- The performance overhead caused by dynamic dispatch implemented with pointers is very small. Compared with handler functions that contain more complex logic, this overhead is almost negligible.
- The performance overhead of dynamic dispatch implemented with structs is relatively large. When a struct method is called, the value must be passed and the arguments copied, which leads to relatively significant overhead.

Therefore, in development, all dynamically dispatched code should be implemented with pointers.

At this point, we have covered all the underlying principles of `interface`. The applications of `interface` will be discussed in the article on reflection.