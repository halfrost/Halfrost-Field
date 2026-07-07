![](https://img.halfrost.com/Blog/ArticleImage/148_0_.png)

# The Three Laws of Go Reflection and Best Practices

In computer science, reflective programming, or reflection, refers to the ability of a computer program to access, inspect, and modify its own state or behavior at runtime. Metaphorically speaking, reflection means that a program can “observe” and modify its own behavior while it is running.

> Wikipedia: In computer science, reflective programming or reflection is the ability of a process to examine, introspect, and modify its own structure and behavior.


There is a conceptual distinction between “reflection” and “introspection” (type introspection). Introspection (or “self-inspection”) refers only to a program inspecting its own information (known as metadata) at runtime. Reflection not only includes the ability to inspect a program’s own information at runtime, but also requires that the program be able to further change its state or structure based on that information. Therefore, reflection is a broader concept than introspection.


In strictly type-checked object-oriented programming languages such as Java, the concrete types, interfaces, fields, and methods of objects that a program needs to call are generally checked for validity during compilation. Reflection allows this message-checking work for objects being called to be deferred from compile time to runtime. As a result, the target object’s interface names and fields—that is, the object’s member variables and available methods—do not need to be known at compile time; instead, the program can decide how to handle them at runtime based on the target object’s own information. It also allows new objects to be instantiated and related methods to be invoked based on the results of such checks.

The primary purpose of reflection is to enable a given program to adapt dynamically to different runtime situations. Polymorphism in object-oriented modeling can also simplify the writing of functional code that applies to multiple different scenarios, but reflection can address more general cases where polymorphism does not apply, thereby avoiding a hard-coded style—where code details are “fixed in place” and lack flexibility—to a greater extent.

**Reflection is also a key strategy in metaprogramming**.

The most common code looks like this:
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
Reflection may make code look more complex, but it enables far more flexible functionality. So when exactly should you use reflection? What are the best practices? This article discusses those questions in depth.


## I. Basic Data Structures and Methods

In the previous article on Go interfaces, we saw how ordinary objects exist in memory. For a variable, the parts we care about are essentially two things: its type and the value it stores. The variable’s type determines what the underlying type is and which method set it supports. The value is ultimately just about reads and writes: where in memory to read from, and where to write those 0101 bits. All of this is determined by the type. This is especially apparent when parsing different JSON data structures: if you use the wrong data type, the value you parse into the resulting variable will be garbage. Go provides reflection to support dynamically accessing a variable’s type and value at runtime.

To dynamically access type values at runtime, the application must necessarily store all type information it uses. The `"reflect"` library provides a set of access interfaces for developers. Reflection in Go is based on interfaces and types. Go cleverly leverages the data structure used when converting an object to an interface: it first passes the object to an internal empty interface, converting the type into an empty interface `emptyInterface` (whose data structure is the same as `eface`). Reflection then uses this `emptyInterface` to access and manipulate the value and type of the object instance.

So let’s start from the data structures and examine how Go implements reflection. In the `reflect` package, there is a general-purpose data structure, `rtype`, that describes common type information. Judging from the source code comments, it is the same data structure as `_type` inside interfaces. The two are duplicated here only because of package isolation and to avoid circular references.
```go
// rtype is the common implementation of most values.
// It is embedded in other struct types.
//
// rtype must be kept in sync with ../runtime/type.go:/^type._type.
type rtype struct {
	size       uintptr // memory size occupied by the type
	ptrdata    uintptr // size of the memory prefix containing all pointers
	hash       uint32  // type hash
	tflag      tflag   // flag bits, mainly used for reflection
	align      uint8   // alignment byte information
	fieldAlign uint8   // alignment byte count of fields in the current struct
	kind       uint8   // enum value of the basic type
	equal func(unsafe.Pointer, unsafe.Pointer) bool // whether the types of the objects corresponding to the two parameters are equal
	gcdata    *byte    // GC type data
	str       nameOff  // offset of the type name string in the binary file segment
	ptrToThis typeOff  // offset of the type metadata pointer in the binary file segment
}
```
Similarly, the metadata for all types is also copied once:
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
I won’t rehash all the basic types here; see the previous article, “A Deep Dive into the Underlying Implementation of Go interface,” for details. Next, let’s look at what useful methods the Type interface actually provides:


### 1. General reflect.Type Methods

The following methods are general-purpose methods that apply to any type.
```go
// Type is the representation of a Go type.
//
// Not all methods apply to all types.
// Before calling kind-specific methods, use the Kind method to find out the type's kind. Calling a method on a mismatched type will cause a panic.
//
// Type values are comparable, for example with the == operator. Therefore they can be used as map keys.
// If two Type values represent the same type, they are necessarily equal.
type Type interface {
	
	// Align returns the alignment in bytes when a value of this type is allocated in memory.
	Align() int
	
	// FieldAlign returns the alignment in bytes when this type is used as a field in a struct.
	FieldAlign() int
	
	// Method returns the i'th method in the type's method set.
	// It panics if i is not in the range [0, NumMethod()).
	// For a non-interface type T or *T, the returned Method's Type and Func.
	// fields field describes a function whose first argument is the receiver, and only exported methods are accessible.
	// For an interface type, the returned Method's Type field gives the method signature, with no receiver, and the Func field is nil.
	// Methods are sorted in lexicographic order.
	Method(int) Method
	
	// MethodByName returns the method with that name in the type.
	// The method set and a boolean indicating whether the method was found.
	// For a non-interface type T or *T, the returned Method's Type and Func.
	// fields field describes a function whose first argument is the receiver.
	// For an interface type, the returned Method's Type field gives the method signature, with no receiver, and the Func field is nil.
	MethodByName(string) (Method, bool)

	// NumMethod returns the number of methods accessible using Method.
	// Note that NumMethod counts unexported methods only when called on an interface type.
	NumMethod() int

	// For a defined type, Name returns the type name within its package.
	// For other (non-defined) types, it returns the empty string.
	Name() string

	// PkgPath returns the package path of a defined type, that is, the import path, which uniquely identifies a package, such as "encoding/base64".
	// If the type is predeclared (string, error) or not defined (*T, struct{}, []int, or A, where A is an alias for a non-defined type), the package path is the empty string.
	PkgPath() string

	// Size returns the number of bytes needed to store a value of the given type. It is similar to unsafe.Sizeof.
	Size() uintptr

	// String returns the string representation of the type.
	// The string representation may use shortened package names.
	// (For example, using base64 instead of "encoding/base64") and it is not guaranteed to be unique among types. To test type identity, compare Type values directly.
	String() string

	// Kind returns the specific kind of this type.
	Kind() Kind

	// Implements reports whether this type implements the interface type u.
	Implements(u Type) bool

	// AssignableTo reports whether a value of this type can be assigned to type u.
	AssignableTo(u Type) bool

	// ConvertibleTo reports whether a value of this type can be converted to type u.
	ConvertibleTo(u Type) bool

	// Comparable reports whether values of this type are comparable.
	Comparable() bool
}
```

### 2. reflect.Type-Specific Methods

The following methods are specific to certain types. If the type does not match, a panic will occur. If you are not sure of the type, it is best to call the Kind() method first to determine the concrete type before calling the type-specific method.


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


The type-specific methods are described as follows:
```go
type Type interface {

	// Bits returns the size of the type in bits.
	// If the type's Kind is not one of: sized or unsized Int, Uint, Float, or Complex, it panics.
	//Int, Uint, Float, or Complex types of varying sizes.
	Bits() int

	// ChanDir returns the direction of a channel type.
	// If the type's Kind is not Chan, it panics.
	ChanDir() ChanDir


	// IsVariadic reports whether a function type's final input parameter is a "..." variadic parameter. If so, t.In(t.NumIn() - 1) returns the parameter's implicit actual type []T.
	// More specifically, if t represents func(x int, y ... float64), then:
	// t.NumIn() == 2
	// t.In(0) is the reflect.Type for "int".
	// t.In(1) is the reflect.Type for "[]float64".
	// t.IsVariadic() == true
	// If the type's Kind is not Func.IsVariadic, IsVariadic panics
	IsVariadic() bool

	// Elem returns a type's element type.
	// If the type's Kind is not Array, Chan, Map, Ptr, or Slice, it panics
	Elem() Type

	// Field returns the i'th field of a struct type.
	// If the type's Kind is not Struct, it panics.
	// If i is not in the range [0, NumField()], it also panics.
	Field(i int) StructField

	// FieldByIndex returns the nested field corresponding to the index sequence. It is equivalent to calling Field for each index.
	// If the type's Kind is not Struct, it panics.
	FieldByIndex(index []int) StructField

	// FieldByName returns the struct field with the given name and a boolean indicating whether the field was found.
	FieldByName(name string) (StructField, bool)

	// FieldByNameFunc returns a named field that satisfies the match function. The boolean indicates whether it was found.
	// FieldByNameFunc first searches the fields of its own struct, then the fields in any embedded structs, in breadth-first order. It stops at the first depth containing one or more structs that satisfy the match function. If multiple fields at that depth satisfy the condition, those fields cancel each other out, and FieldByNameFunc returns no match.
	// This behavior reflects how Go handles name lookup in structs that contain embedded fields
	FieldByNameFunc(match func(string) bool) (StructField, bool)

	// In returns the type of the i'th input parameter of a function type.
	// If the type's Kind is not Func, it panics.
	// If i is not in the range [0, NumIn()), it panics.
	In(i int) Type

	// Key returns the key type of a map type.
	// If the type's Kind is not Map, it panics.
	Key() Type

	// Len returns the length of an array type.
	// If the type's Kind is not Array, it panics.
	Len() int

	// NumField returns the number of fields in a struct type.
	// If the type's Kind is not Struct, it panics.
	NumField() int

	// NumIn returns the number of input parameters of a function type.
	// If the type's Kind is not Func.NumIn(), it panics.
	NumIn() int

	// NumOut returns the number of output parameters of a function type.
	// If the type's Kind is not Func.NumOut(), it panics.
	NumOut() int

	// Out returns the type of the i'th output parameter of a function type.
	// If the type's type is not Func.Out, it panics.
	// If i is not in the range [0, NumOut()), it panics.
	Out(i int) Type

	common() *rtype
	uncommon() *uncommonType
}
```

### 3. reflect.Value Data Structure

In the `reflect` package, not all methods apply to values of all types. The specific restrictions are documented in the method comments. Before calling methods that are specific to a particular kind, it is best to use the `Kind` method to determine the kind of the `Value`. As with `reflect.Type`, calling a method that does not match the type will cause a panic. One special case to note is the zero `Value`, which represents no value. Its `IsValid()` method returns `false`, its `Kind()` method returns `Invalid`, its `String()` method returns `“<invalid Value>”`, and all other methods will panic. Most functions and methods never return an invalid value. If an invalid value is returned, the documentation will explicitly describe the special conditions.
	
A `Value` can be used concurrently by multiple goroutines, provided that the underlying Go value can be used concurrently for the equivalent direct operations. To compare two `Value`s, compare the results of the `Interface`-related methods. Using `==` on two `Value`s does not compare the underlying values they represent.	

The `Value` in the `reflect` package is very simple; its data structure is as follows:
```go
type Value struct {
	// typ holds the type of the value represented by the Value.
	typ *rtype

	// Pointer-valued data, or if flagIndir is set, pointer to data. Valid only when flagIndir is set or typ.pointers（） is true.
	ptr unsafe.Pointer

	// flag holds metadata about the value. The lowest bits are flag bits:
	//	- flagStickyRO: obtained via an unexported non-embedded field, so read-only
	//	- flagEmbedRO:  obtained via an unexported embedded field, so read-only
	//	- flagIndir:    val holds a pointer to data
	//	- flagAddr:     v.CanAddr is true (implies flagIndir)
	//	- flagMethod:   v is a method value.
    // The next 5 bits give the Kind of the Value, except for method values, where it repeats typ.Kind（）. The remaining 23+ bits give the method number for method values. If flag.kind（）!= Func, code can assume flagMethod is not set. If ifaceIndir(typ), code can assume flagIndir is set.
	flag
}
```
A method's Value represents the invocation of an associated method, much like calling `r.Read` on a method receiver `r`. The typ + val + flag bits describe the receiver `r`, but the Kind flag bit indicates Func (the method is a function), and the high bits of the flag give the method number in the method set of `r`'s type.


## II. Internal Implementation of Reflection

This chapter uses the two fundamental methods `reflect.TypeOf()` and `reflect.ValueOf()` as examples to examine how the underlying source code is actually implemented. In the face of source code, nothing remains secret.

### 1. Underlying Implementation of `reflect.TypeOf()`


The reflect package provides an important method, `TypeOf()`. This method can be used to obtain a Type interface. Through the Type interface, you can retrieve an object's type information.
```go
// TypeOf returns the Type of i's dynamic type. If i is a nil interface value, TypeOf returns nil.
func TypeOf(i interface{}) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}

func toType(t *rtype) Type {
	if t == nil {
		return nil
	}
	return t
}
```
The implementation of the above method is very simple: it converts the parameter into a `Type` interface. The first line of the `TypeOf()` method performs an explicit type conversion, converting `unsafe.Pointer` into `emptyInterface`. The `emptyInterface` data structure is as follows:
```go
// emptyInterface is the header for an interface{} value.
type emptyInterface struct {
	typ  *rtype
	word unsafe.Pointer
}
```
As the data structure above shows, `emptyInterface` is essentially the `reflect` version of `eface`; their data structures are exactly the same, so the forced type conversion here is safe. For a more detailed explanation of `eface`, see the previous article on the underlying implementation of `interface`. In addition, the design choice for `TypeOf()` to return an `interface` rather than an `rtype` data structure is deliberate. First, the designers did not want callers to obtain `rtype` and misuse it. After all, type information is read-only, and allowing it to be arbitrarily modified at runtime would be extremely unsafe. Second, the designers used the `interface` layer to encapsulate all caller requirements. The underlying implementation of the `Type` interface can correspond to many different types, and this interface provides a unified abstraction layer.

One point worth noting is the parameter to `TypeOf()`. Its parameter type is `i interface{}`, and it can be one of two kinds: an `interface` variable or a variable of a concrete type. If `i` is a variable of a concrete type, `TypeOf()` returns the concrete type information. If `i` is an `interface` variable and is bound to an instance of a concrete type, it returns the dynamic type information of the concrete type bound to `i`. If `i` is not bound to any concrete type instance, it returns the static type information of the interface itself. For example, consider the following code:
```go
import (
	"fmt"
	"reflect"
)

func main() {
	ifa := new(Person)
	var ifb Person = Student{name: "halfrost"}
    // Interface type not bound to a concrete variable 
	fmt.Println(reflect.TypeOf(ifa).Elem().Name())
	fmt.Println(reflect.TypeOf(ifa).Elem().Kind().String())
    // Interface type bound to a concrete variable 
	fmt.Println(reflect.TypeOf(ifb).Name())
	fmt.Println(reflect.TypeOf(ifb).Kind().String())
}
```
In the first set of output, the argument to `reflect.TypeOf()` is an interface type that is not bound to a concrete variable, so it returns the interface type itself, `Person`. The corresponding `Kind` is `interface`. In the second set of output, the argument to `reflect.TypeOf()` is an interface type bound to a concrete variable, so it returns the bound concrete type, `Student`. The corresponding `Kind` is `struct`.
```go
Person
interface

Student
struct
```
The `toType()` method only performs a single check for whether the value is nil. In `gc`, the only concern is that a nil `*rtype` must be converted to a nil `Type`. In `gccgo`, however, this function needs to ensure that multiple `*rtype` values for the same type are merged into a single `Type`.


### 2. Underlying implementation of reflect.ValueOf()

The `ValueOf()` method returns a new `Value`, initialized from the concrete value of the input parameter, the interface `i`. `ValueOf(nil)` returns the zero Value.
```go
func ValueOf(i interface{}) Value {
	if i == nil {
		return Value{}
	}
	escapes(i)
	return unpackEface(i)
}
```
All of the logic in `ValueOf()` resides in just two methods: `escapes()` and `unpackEface()`. Let’s first look at the implementation of `escapes()`. The comment for this method is still marked as TODO. From its name, we can tell that it is intended to prevent variable escape by storing the contents of `Value` on the stack. Currently, all of the contents are still stored on the heap. Storing them on the heap also has its advantages; for the specific benefits, see `chanrecv`/`mapassign`, which we won’t go into in detail here. The source implementation of `escapes()` is as follows:
```go
func escapes(x interface{}) {
	if dummy.b {
		dummy.x = x
	}
}

var dummy struct {
	b bool
	x interface{}
}
```
The `dummy` variable is a virtual annotation indicating that the input parameter `x` escapes. This annotation is used to prevent reflection code from becoming so advanced that the compiler cannot keep up. The main logic of `ValueOf()` is in the `unpackEface()` method:
```go
func ifaceIndir(t *rtype) bool {
	return t.kind&kindDirectIface == 0
}

func unpackEface(i interface{}) Value {
	e := (*emptyInterface)(unsafe.Pointer(&i))
	// NOTE: don't read e.word until we know whether it is really a pointer or not.
	t := e.typ
	if t == nil {
		return Value{}
	}
	f := flag(t.Kind())
	if ifaceIndir(t) {
		f |= flagIndir
	}
	return Value{t, e.word, f}
}
```
ifaceIndir() simply uses bit operations to extract a characteristic flag bit, indicating whether `t` is stored indirectly in an interface value. As its name suggests, unpackEface() is intended to convert an emptyInterface into a Value. The implementation consists of three steps: first, forcibly cast the input interface to emptyInterface; then check whether emptyInterface.typ is nil, and only if it is non-nil can emptyInterface.word be read. Finally, assemble the three fields in the Value data structure: \*rtype, unsafe.Pointer, and flag.


## III. The Three Laws of Reflection

The well-known article [“The Laws of Reflection”](https://blog.golang.org/laws-of-reflection) summarizes the three laws of reflection.

### 1. Reflection can obtain a reflection object from an interface value


![](https://img.halfrost.com/Blog/ArticleImage/148_1.png)


- Obtain a Value object from an instance using the reflect.ValueOf() function.
```go
// ValueOf returns a new Value initialized to the concrete value
// stored in the interface i. ValueOf(nil) returns the zero Value.
func ValueOf(i interface{}) Value {
	if i == nil {
		return Value{}
	}
	// TODO: Maybe allow contents of a Value to live on the stack.
	// For now we make the contents always escape to the heap. It
	// makes life easier in a few places (see chanrecv/mapassign
	// comment below).
	escapes(i)

	return unpackEface(i)
}
```
- Obtain the reflection object Type from an instance using the `reflect.TypeOf()` function.
```go
// TypeOf returns the reflection Type that represents the dynamic type of i.
// If i is a nil interface value, TypeOf returns nil.
func TypeOf(i interface{}) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}
```

### 2. Reflection can obtain an interface value from a reflection object

From the reflect.Value data structure, we can see that it contains type and value information, so converting a Value into an instance object is straightforward.

![](https://img.halfrost.com/Blog/ArticleImage/148_2.png)


- Convert the Value into an empty interface, which internally stores the concrete type instance. Use the interface() function.
```go
// Interface returns v's current value as an interface{}.
// It is equivalent to:
//	var i interface{} = (v's underlying value)
// It panics if the Value was obtained by accessing
// unexported struct fields.
func (v Value) Interface() (i interface{}) {
	return valueInterface(v, true)
}
```
- Value also includes many member methods that can convert a Value into an instance of a simple type. Note that a type mismatch will cause a panic.
```go
// Int returns v's underlying value, as an int64.
// It panics if v's Kind is not Int, Int8, Int16, Int32, or Int64.
func (v Value) Int() int64 {
	k := v.kind()
	p := v.ptr
	switch k {
	case Int:
		return int64(*(*int)(p))
	case Int8:
		return int64(*(*int8)(p))
	case Int16:
		return int64(*(*int16)(p))
	case Int32:
		return int64(*(*int32)(p))
	case Int64:
		return *(*int64)(p)
	}
	panic(&ValueError{"reflect.Value.Int", v.kind()})
}

// Uint returns v's underlying value, as a uint64.
// It panics if v's Kind is not Uint, Uintptr, Uint8, Uint16, Uint32, or Uint64.
func (v Value) Uint() uint64 {
	k := v.kind()
	p := v.ptr
	switch k {
	case Uint:
		return uint64(*(*uint)(p))
	case Uint8:
		return uint64(*(*uint8)(p))
	case Uint16:
		return uint64(*(*uint16)(p))
	case Uint32:
		return uint64(*(*uint32)(p))
	case Uint64:
		return *(*uint64)(p)
	case Uintptr:
		return uint64(*(*uintptr)(p))
	}
	panic(&ValueError{"reflect.Value.Uint", v.kind()})
}

// Bool returns v's underlying value.
// It panics if v's kind is not Bool.
func (v Value) Bool() bool {
	v.mustBe(Bool)
	return *(*bool)(v.ptr)
}

// Float returns v's underlying value, as a float64.
// It panics if v's Kind is not Float32 or Float64
func (v Value) Float() float64 {
	k := v.kind()
	switch k {
	case Float32:
		return float64(*(*float32)(v.ptr))
	case Float64:
		return *(*float64)(v.ptr)
	}
	panic(&ValueError{"reflect.Value.Float", v.kind()})
}
```

### 3. To Modify a Reflection Object, Its Value Must Be Settable


![](https://img.halfrost.com/Blog/ArticleImage/148_3.png)

- Convert a pointer Type to a value Type. The pointer type must be \*Array, \*Slice, \*Pointer, \*Map, or \*Chan; otherwise, a panic will occur. Type returns the Type of the internal element.
```go
// Elem returns element type of array a.
func (a *Array) Elem() Type { return a.elem }

// Elem returns the element type of slice s.
func (s *Slice) Elem() Type { return s.elem }

// Elem returns the element type for the given pointer p.
func (p *Pointer) Elem() Type { return p.base }

// Elem returns the element type of map m.
func (m *Map) Elem() Type { return m.elem }

// Elem returns the element type of channel c.
func (c *Chan) Elem() Type { return c.elem }
```
- Convert a value type `Type` to a pointer type `Type`. `PtrTo` returns the pointer type that points to `t`.
```go
// PtrTo returns the pointer type with element t.
// For example, if t represents type Foo, PtrTo(t) represents *Foo.
func PtrTo(t Type) Type {
	return t.(*rtype).ptrTo()
}
```
Regarding the third law of reflection, one point needs special clarification: what mutability of a `Value` means. For example:
```go
func main() {
	var x float64 = 3.4
	v := reflect.ValueOf(x)
	v.SetFloat(7.1) // Error: will panic.
}
```
As in the code above, it will crash after running, with the crash message `panic: reflect: reflect.Value.SetFloat using unaddressable value`. Why does `SetFloat()` panic here? The error message indicates that an unaddressable `Value` was used. In the code above, the argument passed to `reflect.ValueOf` is a value-type variable, so the resulting `Value` is actually a complete copy of that value, and this `Value` cannot be modified. If a pointer is passed in instead, the resulting `Value` is a copy of the pointer, but the object at the address the pointer points to can be changed. Modify the code above like this:
```go
func main() {
	var x float64 = 3.4
	p := reflect.ValueOf(&x)
	fmt.Println("type of p:", p.Type())
	fmt.Println("settability of p:", p.CanSet())

	v := p.Elem()
	v.SetFloat(7.1)
	fmt.Println(v.Interface()) // 7.1
	fmt.Println(x)             // 7.1
}
```
When calling the `reflect.ValueOf()` method, pass in a pointer so it won’t crash. The output is as expected:
```go
type of p: *float64
settability of p: false
7.1
7.1
```

### 4. Conversion Between Type and Value


![](https://img.halfrost.com/Blog/ArticleImage/148_4.png)

- Since Type contains only type information, you cannot obtain the Value of an instance object directly from Type. However, you can use the New() method to get a pointer to that type, whose value is the zero value. The MakeMap() method is similar to the New() method, except that it creates a Map.
```go
// New returns a Value representing a pointer to a new zero value
// for the specified type. That is, the returned Value's Type is PtrTo(typ).
func New(typ Type) Value {
	if typ == nil {
		panic("reflect: New(nil)")
	}
	t := typ.(*rtype)
	ptr := unsafe_New(t)
	fl := flag(Ptr)
	return Value{t.ptrTo(), ptr, fl}
}

// MakeMap creates a new map with the specified type.
func MakeMap(typ Type) Value {
	return MakeMapWithSize(typ, 0)
}
```
- One method that deserves special mention is Zero(), which returns the zero value for the specified type. This zero value is different from the zero value of the Value struct; it does not represent any value at all. For example, Zero(TypeOf(42)) returns a value with Kind Int and a value of 0. The returned value is neither addressable nor settable.
```go
// Zero returns a Value representing the zero value for the specified type.
// The result is different from the zero value of the Value struct,
// which represents no value at all.
// For example, Zero(TypeOf(42)) returns a Value with Kind Int and value 0.
// The returned value is neither addressable nor settable.
func Zero(typ Type) Value {
	if typ == nil {
		panic("reflect: Zero(nil)")
	}
	t := typ.(*rtype)
	fl := flag(t.Kind())
	if ifaceIndir(t) {
		var p unsafe.Pointer
		if t.size <= maxZero {
			p = unsafe.Pointer(&zeroVal[0])
		} else {
			p = unsafe_New(t)
		}
		return Value{t, p, fl | flagIndir}
	}
	return Value{t, nil, fl}
}
```
- Since a reflection object `Value` already contains the `Type` information, converting from `Value` to `Type` is relatively straightforward.
```go
// Type returns v's type.
func (v Value) Type() Type {
	f := v.flag
	if f == 0 {
		panic(&ValueError{"reflect.Value.Type", Invalid})
	}
	if f&flagMethod == 0 {
		// Easy case
		return v.typ
	}

	// Method value.
	// v.typ describes the receiver, not the method type.
	i := int(v.flag) >> flagMethodShift
	if v.typ.Kind() == Interface {
		// Method on interface.
		tt := (*interfaceType)(unsafe.Pointer(v.typ))
		if uint(i) >= uint(len(tt.methods)) {
			panic("reflect: internal error: invalid method index")
		}
		m := &tt.methods[i]
		return v.typ.typeOff(m.typ)
	}
	// Method on concrete type.
	ms := v.typ.exportedMethods()
	if uint(i) >= uint(len(ms)) {
		panic("reflect: internal error: invalid method index")
	}
	m := ms[i]
	return v.typ.typeOff(m.mtyp)
}
```

### 5. Converting a Value Pointer to a Value

![](https://img.halfrost.com/Blog/ArticleImage/148_5_.png)


- There are two methods for converting a pointer Value to a value Value: Indirect() and Elem().
```go
// Indirect returns the value that v points to.
// If v is a nil pointer, Indirect returns a zero Value.
// If v is not a pointer, Indirect returns v.
func Indirect(v Value) Value {
	if v.Kind() != Ptr {
		return v
	}
	return v.Elem()
}

// Elem returns the value that the interface v contains
// or that the pointer v points to.
// It panics if v's Kind is not Interface or Ptr.
// It returns the zero Value if v is nil.
func (v Value) Elem() Value {
	k := v.kind()
	switch k {
	case Interface:
		var eface interface{}
		if v.typ.NumMethod() == 0 {
			eface = *(*interface{})(v.ptr)
		} else {
			eface = (interface{})(*(*interface {
				M()
			})(v.ptr))
		}
		x := unpackEface(eface)
		if x.flag != 0 {
			x.flag |= v.flag.ro()
		}
		return x
	case Ptr:
		ptr := v.ptr
		if v.flag&flagIndir != 0 {
			ptr = *(*unsafe.Pointer)(ptr)
		}
		// The returned value's address is v's value.
		if ptr == nil {
			return Value{}
		}
		tt := (*ptrType)(unsafe.Pointer(v.typ))
		typ := tt.elem
		fl := v.flag&flagRO | flagIndir | flagAddr
		fl |= flag(typ.Kind())
		return Value{typ, ptr, fl}
	}
	panic(&ValueError{"reflectlite.Value.Elem", v.kind()})
}
```
From the source implementation, we can see that whether the input parameter is a pointer or an interface affects the output.

- The only method for converting a Value into a pointer Value is Addr().
```go
// Addr returns a pointer value representing the address of v.
// It panics if CanAddr() returns false.
// Addr is typically used to obtain a pointer to a struct field
// or slice element in order to call a method that requires a
// pointer receiver.
func (v Value) Addr() Value {
	if v.flag&flagAddr == 0 {
		panic("reflect.Value.Addr of unaddressable value")
	}
	// Preserve flagRO instead of using v.flag.ro() so that
	// v.Addr().Elem() is equivalent to v (#32772)
	fl := v.flag & flagRO
	return Value{v.typ.ptrTo(), v.ptr, fl | flag(Ptr)}
}
```

### 6. Summary

![](https://img.halfrost.com/Blog/ArticleImage/148_6_0.png)


This chapter used the three laws of reflection to introduce the relationships among reflection objects, `Type`, and `Value`. I have expanded those relationships into the diagram above. In the diagram, except for the conversion between `Type` and `interface`, which is one-way, all other conversions are bidirectional. Some readers may wonder: can `Type` really not be converted into an `interface`? What we mean here is that it cannot be done with a single method call. In the previous article on `interface`, we learned that an `interface` contains two parts: a type and a value. `Type` contains only the type part and does not contain the value part, so it cannot be converted back and forth with `interface`. So what if you really want to obtain an `interface` from a `Type`? Look closely at the diagram: you can first call `New()` to obtain a `Value`, and then call `interface()` to obtain an `interface`. By leveraging the fact that `interface` and `Value` can be converted to each other, you can achieve the goal of generating an `interface` from a `Type`.

## IV. Pros, Cons, and Best Practices

Finally, let’s discuss the pros, cons, and best practices of using reflection in Go.

### 1. Advantages  

- It can, to some extent, avoid hardcoding and provide flexibility and generality.
- It can discover and modify the structure of source code as a first-class object, such as code blocks, classes, methods, protocols, and so on.
- It can dynamically parse executable code in strings at runtime as if handling source-code statements, similar to JavaScript’s `eval()` function. This makes it possible to convert strings that match a class or function into calls or references to that class or function.
- It can create a new bytecode interpreter for a language, giving programming constructs new meaning or new use cases.

### 2. Disadvantages

- The learning curve is steep. Reflection-oriented programming requires substantial advanced knowledge, including frameworks, relational mapping, and object interaction, in order to implement more generic code execution.  
- Likewise, because the concepts and syntax of reflection are relatively abstract, excessive misuse of reflection can make code difficult for others to understand, which is detrimental to collaboration and communication.
- Because some information checks are deferred from compile time to runtime, method calls and object references are not direct address references; instead, they are accessed indirectly through an abstraction layer provided by the `reflect` package. While this improves code flexibility, it sacrifices a small amount of runtime efficiency. In performance-critical parts of a project, reflection must be used with great caution.
- Because it bypasses the compiler’s strict checks, some incorrect modifications can cause the program to panic.

By studying reflection’s characteristics and techniques in depth, these drawbacks can be avoided as much as possible, but doing so requires a great deal of time and accumulated experience.

### 3. Best Practices

- Use reflection appropriately inside libraries and frameworks. Encapsulate complex logic internally: keep the complexity to yourself, and expose only simple interfaces to users.
- There is no need to use reflection in business-logic code outside of libraries and frameworks. The drawbacks have already been discussed above, so they will not be repeated here.
- For scenarios not covered by the two points above, do not make reflection your first solution unless absolutely necessary.