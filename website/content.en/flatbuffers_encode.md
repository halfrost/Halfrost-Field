+++
author = "一缕殇流化隐半边冰霜"
categories = ["FlatBuffers", "Protocol"]
date = 2018-06-10T09:06:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/87_0.png"
slug = "flatbuffers_encode"
tags = ["FlatBuffers", "Protocol"]
title = "FlatBuffers Explained: Encode"

+++


## I. FlatBuffers Generates Binary Streams

Using FlatBuffers is basically similar to using Protocol buffers. The only difference is that FlatBuffers provides an additional capability: parsing JSON.

- Write a schema file to describe the data structures and interface definitions.
- Compile it with `flatc` to generate code files for the corresponding language.
- Parse JSON data, store the data according to the corresponding schema, and write it into a FlatBuffers binary file.
- Develop using the files generated for languages supported by FlatBuffers, such as C++, Java, and so on.

Next, let’s define a simple schema file to see how FlatBuffers is used.
```schema
// Example IDL file for our monster's schema.
namespace MyGame.Sample;
enum Color:byte { Red = 0, Green, Blue = 2 }
union Equipment { Weapon } // Optionally add more tables.
struct Vec3 {
  x:float;
  y:float;
  z:float;
}
table Monster {
  pos:Vec3; // Struct.
  mana:short = 150;
  hp:short = 100;
  name:string;
  friendly:bool = false (deprecated);
  inventory:[ubyte];  // Vector of scalars.
  color:Color = Blue; // Enum.
  weapons:[Weapon];   // Vector of tables.
  equipped:Equipment; // Union.
  path:[Vec3];        // Vector of structs.
}
table Weapon {
  name:string;
  damage:short;
}
root_type Monster;
```
After compiling with `flatc`, you can start development using the generated files.
```go
import (
        flatbuffers "github.com/google/flatbuffers/go"
        sample "MyGame/Sample"
)

// Create a `FlatBufferBuilder` instance, use it to start creating FlatBuffers, with initial size 1024
// The buffer size grows automatically as needed, so don't worry about insufficient space
builder := flatbuffers.NewBuilder(1024)

weaponOne := builder.CreateString("Sword")
weaponTwo := builder.CreateString("Axe")
// Create the first weapon, a sword
sample.WeaponStart(builder)
sample.Weapon.AddName(builder, weaponOne)
sample.Weapon.AddDamage(builder, 3)
sword := sample.WeaponEnd(builder)
// Create the second weapon, an axe
sample.WeaponStart(builder)
sample.Weapon.AddName(builder, weaponTwo)
sample.Weapon.AddDamage(builder, 5)
axe := sample.WeaponEnd(builder)

```
Before serializing `Monster`, we first need to serialize all objects contained within `Monster`; that is, we use a depth-first, pre-order traversal to serialize the data tree. This is typically easy to implement for any tree structure.
```go
// Assign a value to the name field
name := builder.CreateString("Orc")

// Note that since PrependByte prepends bytes, the loop needs to iterate in reverse
sample.MonsterStartInventoryVector(builder, 10)
for i := 9; i >= 0; i-- {
        builder.PrependByte(byte(i))
}
inv := builder.EndVector(10)
```
In the code above, we serialized two built-in data types (a string and an array) and captured their return values. This value is the offset of the serialized data, indicating where it is stored. Once we have this offset, we can reference it when adding fields to Monster.

The recommendation here is that if you need to create an array of nested objects (for example, tables, string arrays, or other arrays), you can first collect their offsets in a temporary data structure, and then create an additional array containing those offsets to store all the offsets.

If you are not creating an array from an existing array, but instead serializing elements one by one, pay attention to the order: buffers are built from back to front.
```go
// Create a FlatBuffer array and prepend these weapons.
// Note: since we prepend data, remember to insert in reverse order.
sample.MonsterStartWeaponsVector(builder, 2)
builder.PrependUOffsetT(axe)
builder.PrependUOffsetT(sword)
weapons := builder.EndVector(2)
```
FlatBuffer arrays now contain their offsets.

Also note that handling arrays of structs is completely different from handling tables, because structs are stored entirely inline in the array. For example, to create an array for the `path` field above:
```go
sample.MonsterStartPathVector(builder, 2)
sample.CreateVec3(builder, 1.0, 2.0, 3.0)
sample.CreateVec3(builder, 4.0, 5.0, 6.0)
path := builder.EndVector(2)
```
The non-scalar fields have already been serialized above, so we can continue serializing the scalar fields next:
```go
// Build monster by calling `MonsterStart()` to start and `MonsterEnd()` to end.
sample.MonsterStart(builder)
vec3 := sample.CreateVec3(builder, 1.0, 2.0, 3.0)
sample.MonsterAddPos(builder, vec3)
sample.MonsterAddName(builder, name)
sample.MonsterAddColor(builder, sample.ColorRed)
sample.MonsterAddHp(builder, 500)
sample.MonsterAddInventory(builder, inv)
sample.MonsterAddWeapons(builder, weapons)
sample.MonsterAddEquippedType(builder, sample.EquipmentWeapon)
sample.MonsterAddEquipped(builder, axe)
sample.MonsterAddPath(builder, path)
orc := sample.MonsterEnd(builder)
```
You still need to be careful about how to create the `Vec3` struct in a table. Unlike tables, structs are simple combinations of scalars; they are always stored inline, just like scalars themselves.

**Important reminder**: Unlike structs, you should not nest the serialization of tables or other objects. This is why we created all the strings / vectors / tables referenced by this `monster` before calling `start`. If you try to create any of them between `start` and `end`, you will get an assert / exception / panic depending on your language.

The default values for `hp` and `mana` are defined in the schema. If you do not need to change them during initialization, you do not need to add the values to the buffer. In that case, the field will not be written to the buffer, which saves transmission overhead and reduces the buffer size. So setting a reasonable default value can save some space. Of course, you do not need to worry that the value is not stored in the buffer; when you `get` it, the default value will be read from another location.

**This also means you do not need to worry about adding many fields that are used only in a small number of instances. They all use their default values by default and will not take up buffer space**.

Before finishing serialization, let’s review the FlatBuffer union `Equipment`. Every FlatBuffer union has two parts (see the [previous article](https://halfrost.com/flatbuffers_schema/) for details). The first is the hidden field `_type`, which is generated to store the type of the table referenced by the union. This lets you know which type to use at runtime. The second field is the union’s data.

So we also need to add two fields: one is `Equipped Type`, and the other is the `Equipped` union. The specific code is here (initialized above):
```go
sample.MonsterAddEquippedType(builder, sample.EquipmentWeapon) // Union type
sample.MonsterAddEquipped(builder, axe) // Union data
```
After creating the buffer, you will get the offset of the entire data relative to the root. Finish the creation by calling the `finish` method; this offset will be stored in a variable. In the code below, the offset is stored in the `orc` variable:
```go
// Call the `Finish()` method to tell the builder that the monster is complete.
builder.Finish(orc)
```
At this point, the buffer has been fully constructed and can be sent over the network or compressed and stored. The final step is completed with the following method:
```go
// This method must be called only after the `Finish()` method has been called.
buf := builder.FinishedBytes() // Of type `byte[]`.
```
At this point, you can write the binary bytes to a file or send them over the network. **Be absolutely sure that the file mode (or transport protocol) you use is binary, not text**. If you transfer a FlatBuffer in text format, the buffer will be corrupted, which will make issues very difficult to diagnose when you read the buffer on the other side.


## II. Reading Binary Streams with FlatBuffers

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_2.png'>
</p>


The previous chapter covered how to use FlatBuffers to convert data into a binary stream. This section explains how to read it.

Before reading, you still need to ensure that you read in binary mode; other reading modes will not read the data correctly.
```go
import (
        flatbuffers "github.com/google/flatbuffers/go"
        sample "MyGame/Sample"
)

// First prepare a byte array to store the buffer binary stream
var buf []byte = /* the data you just read */
// Get the root accessor from the buffer
monster := sample.GetRootAsMonster(buf, 0)

```
Here, the default `offset` is 0. If you want to start reading data directly from `builder.Bytes`, you need to pass in an offset to skip `builder.Head()`. Because the builder constructs data in reverse, the offset will definitely not be 0.

Since the files generated by `flatc` have been imported, they already include the get and set methods. Fields marked as deprecated will not generate the corresponding methods by default.
```go
hp := monster.Hp()
mana := monster.Mana()
name := string(monster.Name()) // Note: `monster.Name()` returns a byte[].

pos := monster.Pos(nil)
x := pos.X()
y := pos.Y()
z := pos.Z()
```
In the code above, the value passed for pos is nil. If your program has especially high performance requirements, you can pass in a pointer variable instead. This allows it to be reused, reducing many of the performance issues caused by allocating small objects and the resulting garbage collection. If there are a particularly large number of small objects, this can also lead to GC-related issues.
```go
invLength := monster.InventoryLength()
thirdItem := monster.Inventory(2)
```
Reading from an array works the same way as with ordinary arrays, so I won’t go into it further here.
```go
weaponLength := monster.WeaponsLength()
weapon := new(sample.Weapon) // We need a `sample.Weapon` to pass into `monster.Weapons()`
                             // to capture the output of the function.
if monster.Weapons(weapon, 1) {
        secondWeaponName := weapon.Name()
        secondWeaponDamage := weapon.Damage()
}
```
An array of `table`s is used in essentially the same way as a regular array. The only difference is that its elements are all objects, so you just handle them using the corresponding object-processing approach.

Finally, there is the way to read a `union`. As we know, a `union` contains two fields: a type and the data. You need to use the type to determine what data to deserialize.
```go
// Create a new `flatbuffers.Table` to store the result of `monster.Equipped()`.
unionTable := new(flatbuffers.Table)
if monster.Equipped(unionTable) {
        unionType := monster.EquippedType()
        if unionType == sample.EquipmentWeapon {
                // Create a `sample.Weapon` object that can be initialized with the contents
                // of the `flatbuffers.Table` (`unionTable`), which was populated by
                // `monster.Equipped()`.
                unionWeapon = new(sample.Weapon)
                unionWeapon.Init(unionTable.Bytes, unionTable.Pos)
                weaponName = unionWeapon.Name()
                weaponDamage = unionWeapon.Damage()
        }
}
```
Use `unionType` to map to different types and deserialize data of different types. After all, a union contains only one table.


## III. Mutable FlatBuffers

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_4.gif'>
</p>

From the usage pattern above, the sender prepares a binary buffer stream and sends it to the consumer. After the consumer receives the binary buffer stream, it reads data from it. If the consumer also wants to make a small change to the buffer and pass it on to the next consumer, the only option is to create an entirely new buffer, modify the fields during creation, and then pass it to the next consumer.

If you only need to change a single field, having to recreate a very large buffer is extremely inconvenient. If you need to change many fields, you can consider creating a new buffer from scratch, because that is more efficient and the API is more general-purpose.

If you want to create a mutable flatbuffer, add the `--gen-mutable` compiler option when compiling the schema with flatc.

The generated code uses mutate rather than set to indicate that this is a special use case, minimizing confusion with the default way of constructing FlatBuffer data.

**The mutating API does not currently support golang**.

Note that any mutate function in a table returns a boolean value. If we try to set a field that does not exist in the buffer, it returns false. **There are two cases where a field does not exist in the buffer: one is that it was never set, and the other is that its value is the same as the default value**. For example, in the example above, mana = 150. Since this is the default value, it is not stored in the buffer. If you call the mutate method, it will return false, and the value will not be modified.

One way to solve this problem is to call ForceDefaults on FlatBufferBuilder to force all fields to be written. This of course increases the size of the buffer, but that is acceptable for mutable buffers.

If this approach is still unacceptable, call the corresponding API (--gen-object-api) or use reflection. Currently, the C++ version of the API has the most complete support in this area.


## IV. FlatBuffers Encoding Principles

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_7.png'>
</p>

Based on the simple usage flow above, let’s walk through the source code step by step.


### 1. Create a New FlatBufferBuilder
```go
builder := flatbuffers.NewBuilder(1024)
```
The first step is to create a FlatBufferBuilder. Inside the builder, it initializes the final serialized binary stream, encoded in little endian; the binary stream is written from higher memory addresses toward lower memory addresses.
```go
type Builder struct {
	// `Bytes` gives raw access to the buffer. Most users will want to use
	// FinishedBytes() instead.
	Bytes []byte

	minalign  int
	vtable    []UOffsetT
	objectEnd UOffsetT
	vtables   []UOffsetT
	head      UOffsetT
	nested    bool
	finished  bool
}


type (
	// A SOffsetT stores a signed offset into arbitrary data.
	SOffsetT int32
	// A UOffsetT stores an unsigned offset into vector data.
	UOffsetT uint32
	// A VOffsetT stores an unsigned offset in a vtable.
	VOffsetT uint16
)

```
There are three special types here: `SOffsetT`, `UOffsetT`, and `VOffsetT`. `SOffsetT` stores a signed offset, `UOffsetT` stores an unsigned offset for array data, and `VOffsetT` stores an unsigned offset in the vtable.

The `Bytes` in `Builder` are the final serialized binary stream. Creating a new `FlatBufferBuilder` means initializing the `Builder` struct:
```go
func NewBuilder(initialSize int) *Builder {
	if initialSize <= 0 {
		initialSize = 0
	}

	b := &Builder{}
	b.Bytes = make([]byte, initialSize)
	b.head = UOffsetT(initialSize)
	b.minalign = 1
	b.vtables = make([]UOffsetT, 0, 16) // sensible default capacity

	return b
}
```

### 2. Serializing Scalar Data

Scalar data includes the following types: Bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64, float32, float64, byte. The serialization method is the same for all data of these types; here, `PrependInt16` is used as an example:
```go
func (b *Builder) PrependInt16(x int16) {
	b.Prep(SizeInt16, 0)
	b.PlaceInt16(x)
}
```
The concrete implementation calls two functions: Prep() and PlaceXXX(). Prep() is a common function that is invoked when serializing every scalar.
```go
func (b *Builder) Prep(size, additionalBytes int) {
	// Track the biggest thing we've ever aligned to.
	if size > b.minalign {
		b.minalign = size
	}
	// Find the amount of alignment needed such that `size` is properly
	// aligned after `additionalBytes`:
	alignSize := (^(len(b.Bytes) - int(b.Head()) + additionalBytes)) + 1
	alignSize &= (size - 1)

	// Reallocate the buffer if needed:
	for int(b.head) <= alignSize+size+additionalBytes {
		oldBufSize := len(b.Bytes)
		b.growByteBuffer()
		b.head += UOffsetT(len(b.Bytes) - oldBufSize)
	}
	b.Pad(alignSize)
}
```
The first parameter of the `Prep()` function is `size`. Here, `size` is measured in bytes: however many bytes the value occupies, that is the value of `size`. For example, `SizeUint8 = 1`, `SizeUint16 = 2`, `SizeUint32 = 4`, and `SizeUint64 = 8`. The same applies to other types. The three special offsets also have fixed sizes: `SOffsetT int32`, whose `size = 4`; `UOffsetT uint32`, whose `size = 4`; and `VOffsetT uint16`, whose `size = 2`.

The `Prep()` method has two purposes:

1. Perform all alignment operations.
2. Allocate additional memory when there is not enough memory.

After adding `additional_bytes` bytes, it still needs to add another `size` bytes. What needs to be aligned here is these final `size` bytes, which in practice are also the size of the object being added; for example, an `Int` is 4 bytes. The end result is that after `additional_bytes` is allocated, the offset is an integer multiple of `size`. The number of bytes required for alignment is computed in two statements:
```go
	alignSize := (^(len(b.Bytes) - int(b.Head()) + additionalBytes)) + 1
	alignSize &= (size - 1)
```
After alignment, the buffer may also need to be reallocated if necessary:
```go
func (b *Builder) growByteBuffer() {
	if (int64(len(b.Bytes)) & int64(0xC0000000)) != 0 {
		panic("cannot grow buffer beyond 2 gigabytes")
	}
	newLen := len(b.Bytes) * 2
	if newLen == 0 {
		newLen = 1
	}

	if cap(b.Bytes) >= newLen {
		b.Bytes = b.Bytes[:newLen]
	} else {
		extension := make([]byte, newLen-len(b.Bytes))
		b.Bytes = append(b.Bytes, extension...)
	}

	middle := newLen / 2
	copy(b.Bytes[middle:], b.Bytes[:middle])
}
```
The `growByteBuffer()` method expands the buffer to twice its original size. It is worth noting the final `copy` operation:
```go
copy(b.Bytes[middle:], b.Bytes[:middle])
```
The old data is actually copied to the end of the newly expanded array, because the build buffer is built from back to front.

The final step of `Prep()` is to add a 0 at the current offset:
```go
func (b *Builder) Pad(n int) {
	for i := 0; i < n; i++ {
		b.PlaceByte(0)
	}
}
```
In the example above, hp = 500, and the binary representation of 500 is 111110100. Since the current buffer is 2 bytes, 500 is stored in reverse order as 1111 0100 0000 0001. According to the alignment rules mentioned above, the type of 500 is Sizeint16, whose byte size is 2. The current offset is 133 bytes (why it is 133 bytes will be covered below; for now, just accept this number). 133 + 2 = 135 bytes, which is not a multiple of Sizeint16, so byte alignment is required. The effect of alignment is to add 0 and align to an integer multiple of Sizeint16. According to the rules above, alignSize evaluates to 1, which means one additional byte of 0 must be added.

So the final representation of 500 in the binary stream is:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_10.png'>
</p>
```c
500 = 1111 0100 0000 0001 0000 0000
    = 244 1 0
```
Finally, we should also mention the issue of default values for scalars. We know that in flatbuffer, default values are not stored in the binary stream. So where are they stored? They are actually compiled directly into the code file by the flatc file. Let’s continue using `hp` here as an example; its default value is `100`.

When serializing `hp` for `Monster`, we call the `MonsterAddHp()` method:
```go
func MonsterAddHp(builder *flatbuffers.Builder, hp int16) {
	builder.PrependInt16Slot(2, hp, 100)
}
```
The concrete implementation is immediately visible: the default value is written directly, and the default value `100` is passed into the builder as an input parameter.
```go
func (b *Builder) PrependInt16Slot(o int, x, d int16) {
	if x != d {
		b.PrependInt16(x)
		b.Slot(o)
	}
}
```
When preparing a Slot, if the serialized value is equivalent to the default value, it will not continue to be written into the binary stream. The corresponding code is the `if` check above. Only when it differs from the default value will the `PrependInt16()` operation continue.

The final step in serializing all scalar values is to record the offset in the vtable:
```go
func (b *Builder) Slot(slotnum int) {
	b.vtable[slotnum] = UOffsetT(b.Offset())
}
```
`slotnum` is passed in by the caller; developers don’t need to worry about this value, because it is the number automatically generated by `flatc` based on the schema.
```schema
table Monster {
  pos:Vec3; // Struct.
  mana:short = 150;
  hp:short = 100;
  name:string;
  friendly:bool = false (deprecated);
  inventory:[ubyte];  // Vector of scalars.
  color:Color = Blue; // Enum.
  weapons:[Weapon];   // Vector of tables.
  equipped:Equipment; // Union.
  path:[Vec3];        // Vector of structs.
}
```
In the definition of `Monster`, counting downward from `pos`, starting at 0, `hp` is the second field. Therefore, in the builder’s vtable, `hp` occupies the second slot, and the value stored in `vtable[2]` is its corresponding offset.


### 3. Serializing Arrays

An array stores consecutive scalar values, and also stores a `SizeUint32` representing the array’s size. The array is not stored inline in its parent; instead, it is referenced via an offset.

In the example above, arrays are actually divided into three categories: scalar arrays, table arrays, and struct arrays. In fact, when serializing an array, you do not need to consider what it contains. The serialization method for all three types of arrays is the same: they all call the following method:
```go
func (b *Builder) StartVector(elemSize, numElems, alignment int) UOffsetT {
	b.assertNotNested()
	b.nested = true
	b.Prep(SizeUint32, elemSize*numElems)
	b.Prep(alignment, elemSize*numElems) // Just in case alignment > int.
	return b.Offset()
}
```
This method takes three input parameters: element size, element count, and alignment bytes.

In the example above, the scalar array `InventoryVector` contains `SizeInt8` values, which are one byte each, so the alignment is also 1 byte (use the largest byte size among the elements in the array). The table array `WeaponsVector` contains tables of type `Weapons`; the element size of the table is `string + short = 4` bytes, and the alignment is also 4 bytes. The struct array `PathVector` contains structs of type `Path`; the element size of the struct is `SizeFloat32 * 3 = 4 * 3 = 12` bytes, but the alignment size is only 4 bytes.

The `StartVector()` method first checks whether the current build has any nesting:
```go
func (b *Builder) assertNotNested() {
	if b.nested {
		panic("Incorrect creation order: object must not be nested.")
	}
}
```
`Table`/`Vector`/`String` cannot be created in a nested manner. The `nested` field in the builder also indicates whether the current state is nested. If they are created in a nested loop, a panic will be triggered here.

Next come two `Prep()` operations. `SizeUint32` is prepared first, followed by the alignment `Prep`, because the alignment may be larger than `SizeUint32`.

After the aligned space has been prepared and the offset has been calculated, the next step is to serialize the elements into the array by calling various `PrependXXXX()` methods. (The `PrependInt16()` method was used as an example above; other types are similar, so they will not be repeated here.)

After the data has been loaded into the array, the final step is to call `EndVector()` once to finish serializing the array:
```go
func (b *Builder) EndVector(vectorNumElems int) UOffsetT {
	b.assertNested()

	// we already made space for this, so write without PrependUint32
	b.PlaceUOffsetT(UOffsetT(vectorNumElems))

	b.nested = false
	return b.Offset()
}
```
`EndVector()` internally calls the `PlaceUOffsetT()` method:
```go
func (b *Builder) PlaceUOffsetT(x UOffsetT) {
	b.head -= UOffsetT(SizeUOffsetT)
	WriteUOffsetT(b.Bytes[b.head:], x)
}

func WriteUOffsetT(buf []byte, n UOffsetT) {
	WriteUint32(buf, uint32(n))
}

func WriteUint32(buf []byte, n uint32) {
	buf[0] = byte(n)
	buf[1] = byte(n >> 8)
	buf[2] = byte(n >> 16)
	buf[3] = byte(n >> 24)
}
```
The `PlaceUOffsetT()` method primarily sets the builder’s UOffset. `SizeUOffsetT = 4` bytes. It serializes the array length into the binary stream. The array length is 4 bytes.

In the example above, the offset to `InventoryVector` is 60. After adding ten 1-byte scalar elements, it reaches byte 70. Since `alignment = 1`, which is smaller than `SizeUint32 = 4`, it is aligned to 4 bytes. The nearest multiple of 4 to 70 is 72, so alignment requires adding 2 extra `0` bytes. The final representation in the binary stream is:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_11.png'>
</p>
```c
10 0 0 0 0 1 2 3 4 5 6 7 8 9 0 0
```

### 4. Serializing string

A string can be viewed as a byte array, except that it has a null string terminator at the end. A string also cannot be stored inline within its parent; it is referenced via an offset.

So serializing a string is very similar to serializing an array.
```go
func (b *Builder) CreateString(s string) UOffsetT {
	b.assertNotNested()
	b.nested = true

	b.Prep(int(SizeUOffsetT), (len(s)+1)*SizeByte)
	b.PlaceByte(0)

	l := UOffsetT(len(s))

	b.head -= l
	copy(b.Bytes[b.head:b.head+l], s)

	return b.EndVector(len(s))
}
```
The concrete implementation is basically the same as the process for serializing an array, with a few additional steps that will be explained one by one below. It also starts with Prep() and alignment. The difference from an array is that a string ends with a null terminator, so the last byte of the array needs an additional byte of 0. Therefore, there is one extra line: `b.PlaceByte(0)`.

`copy(b.Bytes[b.head:b.head+l], s)` copies the string into the corresponding offset.

Finally, `b.EndVector()` likewise writes the length into the binary stream. Note the two places where the length is handled: in Prep(), the trailing 0 is taken into account, so Prep() uses len(s) + 1; in the final EndVector(), the trailing 0 is not taken into account, so it uses len(s).


Let’s continue using the concrete example from above to illustrate this.
```go
weaponOne := builder.CreateString("Sword")
```
At the very beginning, we serialized the `Sword` string. The ASCII codes for this string are `83 119 111 114 100`. Since a trailing `0` also needs to be appended to the end of the string, the entire string in the binary stream should be `83 119 111 114 100 0`. Now consider alignment: because `SizeUOffsetT = 4` bytes, the current offset of the string is `0`; after adding the string length `6`, the nearest multiple of `4` greater than or equal to `6` is `8`, so two more `0` bytes need to be appended at the end. Finally, the string length `5` is added as well (note that this length does not include the trailing `0` at the end of the string).

So the final layout of the `Sword` string in the binary stream is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_12_.png'>
</p>
```c
5 0 0 0 83 119 111 114 100 0 0 0
```

### 5. Serializing structs


A struct is always stored inline within its parent (a struct, table, or vector) to achieve maximum compactness. A struct defines a consistent memory layout in which all fields are aligned to their size, and the struct itself is aligned to its largest scalar member. This approach enforces alignment rules independent of the underlying compiler, ensuring a cross-platform-compatible layout. This layout is constructed in the generated code. Next, let’s look at how it is constructed.

Serializing a struct is very straightforward: serialize it directly into binary form and insert it into the slot:
```go
func (b *Builder) PrependStructSlot(voffset int, x, d UOffsetT) {
	if x != d {
		b.assertNested()
		if x != b.Offset() {
			panic("inline data write outside of object")
		}
		b.Slot(voffset)
	}
}
```
In the concrete implementation, it first checks whether the two `UOffsetT` values in the input parameters are equal. It then checks whether there is any current nesting. If there is no nesting, it also verifies whether the `UOffsetT` matches the offset after actual serialization. If all of these checks pass, it generates the slot — recording the offset in the vtable.
```go
builder.PrependStructSlot(0, flatbuffers.UOffsetT(pos), 0)
```
When it is called, the struct’s `UOffsetT` is computed once (32-bit, 4 bytes).
```go
func CreateVec3(builder *flatbuffers.Builder, x float32, y float32, z float32) flatbuffers.UOffsetT {
	builder.Prep(4, 12)
	builder.PrependFloat32(z)
	builder.PrependFloat32(y)
	builder.PrependFloat32(x)
	return builder.Offset()
}
```
Because the type is `float32`, the size is 4 bytes. The struct contains 3 variables, so its total size is 12 bytes. As you can see, the struct’s values are placed directly in memory without any processing, and there is no issue of nested allocation involved, so it can be inlined into other structures. The storage order is also the same as the field order.
```c
1.0 as a floating-point number in binary is: 00111111100000000000000000000000
2.0 as a floating-point number in binary is: 01000000000000000000000000000000
3.0 as a floating-point number in binary is: 01000000010000000000000000000000

```
<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_13.png'>
</p>


```c
0 0 128 63 0 0 0 64 0 0 64 64
```

### 6. Serializing a table

Unlike a struct, a table is not stored inline within its parent; instead, it is referenced via an offset. A table contains an SOffsetT, which is the signed version of UOffsetT, and the offset it represents is directional. Since the vtable can be stored anywhere, its offset should be computed as the start of the stored object minus the start of the vtable, i.e., the offset between the object and the vtable.

Serializing a table is divided into three steps. The first step is StartObject:
```go
func (b *Builder) StartObject(numfields int) {
	b.assertNotNested()
	b.nested = true

	// use 32-bit offsets so that arithmetic doesn't overflow.
	if cap(b.vtable) < numfields || b.vtable == nil {
		b.vtable = make([]UOffsetT, numfields)
	} else {
		b.vtable = b.vtable[:numfields]
		for i := 0; i < len(b.vtable); i++ {
			b.vtable[i] = 0
		}
	}

	b.objectEnd = b.Offset()
	b.minalign = 1
}
```
The first step in serializing a table is to initialize the vtable. Before initialization, perform error checks to determine whether there is nesting. Next, initialize the vtable space. Here, UOffsetT = UOffsetT uint32 is used during initialization to prevent overflow. The input parameter to StartObject() is the number of fields. Note that a union has 2 fields.

Each table has its own vtable, which stores the offset of each field. This is the purpose of the slot function mentioned above: all generated slots are recorded in the vtable. Tables with identical vtables share the same vtable instance.

The second step is to add each field. Fields can be added in any order, because after flatc compiles the schema, the order of each field in the slots has already been arranged and will not change based on the order in which we call the serialization methods. For example:
```go
func MonsterAddPos(builder *flatbuffers.Builder, pos flatbuffers.UOffsetT) {
	builder.PrependStructSlot(0, flatbuffers.UOffsetT(pos), 0)
}
func MonsterAddMana(builder *flatbuffers.Builder, mana int16) {
	builder.PrependInt16Slot(1, mana, 150)
}
func MonsterAddHp(builder *flatbuffers.Builder, hp int16) {
	builder.PrependInt16Slot(2, hp, 100)
}
func MonsterAddName(builder *flatbuffers.Builder, name flatbuffers.UOffsetT) {
	builder.PrependUOffsetTSlot(3, flatbuffers.UOffsetT(name), 0)
}
func MonsterAddInventory(builder *flatbuffers.Builder, inventory flatbuffers.UOffsetT) {
	builder.PrependUOffsetTSlot(5, flatbuffers.UOffsetT(inventory), 0)
}
func MonsterStartInventoryVector(builder *flatbuffers.Builder, numElems int) flatbuffers.UOffsetT {
	return builder.StartVector(1, numElems, 1)
}
func MonsterAddColor(builder *flatbuffers.Builder, color int8) {
	builder.PrependInt8Slot(6, color, 2)
}
func MonsterAddWeapons(builder *flatbuffers.Builder, weapons flatbuffers.UOffsetT) {
	builder.PrependUOffsetTSlot(7, flatbuffers.UOffsetT(weapons), 0)
}
func MonsterStartWeaponsVector(builder *flatbuffers.Builder, numElems int) flatbuffers.UOffsetT {
	return builder.StartVector(4, numElems, 4)
}
func MonsterAddEquippedType(builder *flatbuffers.Builder, equippedType byte) {
	builder.PrependByteSlot(8, equippedType, 0)
}
func MonsterAddEquipped(builder *flatbuffers.Builder, equipped flatbuffers.UOffsetT) {
	builder.PrependUOffsetTSlot(9, flatbuffers.UOffsetT(equipped), 0)
}
func MonsterAddPath(builder *flatbuffers.Builder, path flatbuffers.UOffsetT) {
	builder.PrependUOffsetTSlot(10, flatbuffers.UOffsetT(path), 0)
}
func MonsterStartPathVector(builder *flatbuffers.Builder, numElems int) flatbuffers.UOffsetT {
	return builder.StartVector(12, numElems, 4)
```
The above is the serialization implementation for all fields in the Monster table. We can look at the first parameter of each function, which corresponds to the slot position in the vtable: 0 - pos, 1 - mana, 2 - hp, 3 - name, (no 4 - friendly, because it was deprecated), 5 - inventory, 6 - color, 7 - weapons, 8 - equippedType, 9 - equipped, 10 - path. Monster has 11 fields in total (including one deprecated field; the union counts as 2 fields), and the final serialization needs to serialize 10 fields. **This is also why ids can only increase going forward, cannot be added before existing ones, and deprecated fields cannot be removed: once a slot position is fixed, it cannot be changed**. With ids, field name changes no longer matter.

In addition, **the serialization list also shows that table / string / vector types cannot be serialized nested inside a table; they cannot be inlined and must be created before the root object is created**. `inventory` is a scalar array; after it is serialized, the Monster references its offset. `weapons` is a table array; similarly, it is serialized first and then its offset is referenced. `path` is a struct, and is likewise referenced. `pos` is a struct and is inlined directly in the table. `equipped` is a union and is also inlined directly in the table.
```go
func WeaponAddName(builder *flatbuffers.Builder, name flatbuffers.UOffsetT) {
	builder.PrependUOffsetTSlot(0, flatbuffers.UOffsetT(name), 0)
}
```
When serializing `name` in the `weapon` table, the offset is computed as a relative position: not relative to the end of the buffer, but relative to the current write position:
```go
// PrependSOffsetT prepends an SOffsetT, relative to where it will be written.
func (b *Builder) PrependSOffsetT(off SOffsetT) {
	b.Prep(SizeSOffsetT, 0) // Ensure alignment is already done.
	if !(UOffsetT(off) <= b.Offset()) {
		panic("unreachable: off <= b.Offset()")
	}
	// Note that the offset calculated here is relative to the current write position
	off2 := SOffsetT(b.Offset()) - off + SOffsetT(SizeSOffsetT)
	b.PlaceSOffsetT(off2)
}

// PrependUOffsetT prepends an UOffsetT, relative to where it will be written.
func (b *Builder) PrependUOffsetT(off UOffsetT) {
	b.Prep(SizeUOffsetT, 0) // Ensure alignment is already done.
	if !(off <= b.Offset()) {
		panic("unreachable: off <= b.Offset()")
	}
	// Note that the offset calculated here is relative to the current write position
	off2 := b.Offset() - off + UOffsetT(SizeUOffsetT)
	b.PlaceUOffsetT(off2)
}
```
For other scalar types, you can compute the offset directly; the only ones that require special attention are UOffsetT and SOffsetT.

The final step in serializing a table is EndObject():
```go
func (b *Builder) EndObject() UOffsetT {
	b.assertNested()
	n := b.WriteVtable()
	b.nested = false
	return n
}
```
Finally, when ending serialization, you also need to first check whether it is nested. The important part is calling WriteVtable(). Before looking at the concrete implementation of WriteVtable(), we need to introduce the data structure of the vtable.


The elements of a vtable are all of type VOffsetT, which is uint16. The first element is the size of the vtable in bytes, including itself. The second is the size of the object in bytes, including the vtable offset. This size can be used for streaming, so you know how many bytes need to be read in order to access all inline fields of the object. The third part consists of N offsets, where N is the number of fields declared in the schema at the time the code that builds this buffer is compiled (including deprecated fields). Therefore, the table size is N + 2. Each entry is SizeVOffsetT bytes wide. See the figure below:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_14_0.png'>
</p>


The first element of an object is SOffsetT: the offset between the object and the vtable, which may be positive or negative. The second element is the object’s data. When reading an object, SOffsetT is compared first to prevent new code from reading old data incorrectly. If the field to be read is beyond the bounds of the offset array, or the vtable entry is 0, it means that the field does not exist in this object, and the field’s default value is returned. If it is within range, the field’s offset is read.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_15.png'>
</p>


Next, let’s take a detailed look at the concrete implementation of WriteVtable():
```go
func (b *Builder) WriteVtable() (n UOffsetT) {
	// 1. Add a 0-aligned scalar, write the offset after alignment; this slot will later be overwritten by the offset to the vtable
	b.PrependSOffsetT(0)

	objectOffset := b.Offset()
	existingVtable := UOffsetT(0)

	// 2. Remove trailing zeros
	i := len(b.vtable) - 1
	for ; i >= 0 && b.vtable[i] == 0; i-- {
	}
	b.vtable = b.vtable[:i+1]

	// 3. Search backward through vtables for an already stored vtable; if an identical stored vtable exists, find it and point the index to it
	//    See the BenchmarkVtableDeduplication results; pointing the index to the same vtable instead of creating a new one improves performance by 30%
	for i := len(b.vtables) - 1; i >= 0; i-- {
		// Select a vtable from vtables
		vt2Offset := b.vtables[i]
		vt2Start := len(b.Bytes) - int(vt2Offset)
		vt2Len := GetVOffsetT(b.Bytes[vt2Start:])

		metadata := VtableMetadataFields * SizeVOffsetT
		vt2End := vt2Start + int(vt2Len)
		vt2 := b.Bytes[vt2Start+metadata : vt2End]

		// 4. Compare the current b.vtable with vt2; if they match, record the offset in existingVtable and break once one is found
		if vtableEqual(b.vtable, objectOffset, vt2) {
			existingVtable = vt2Offset
			break
		}
	}

	if existingVtable == 0 {
		// 5. If no identical vtable is found, create a new one and write it to the buffer
		//    It is also written backward, because serialization is tail-first.
		for i := len(b.vtable) - 1; i >= 0; i-- {
			var off UOffsetT
			if b.vtable[i] != 0 {
				// 6. Starting from the object header, calculate the offsets of the following fields
				off = objectOffset - b.vtable[i]
			}
			b.PrependVOffsetT(VOffsetT(off))
		}

		// 7. Finally write the two metadata fields
		//    First, write the object's size, including the vtable offset
		objectSize := objectOffset - b.objectEnd
		b.PrependVOffsetT(VOffsetT(objectSize))

		// 8. Second, store the vtable size
		vBytes := (len(b.vtable) + VtableMetadataFields) * SizeVOffsetT
		b.PrependVOffsetT(VOffsetT(vBytes))

		// 9. Finally, update the vtable-distance offset in the object's header; the value is SOffsetT, 4 bytes
		objectStart := SOffsetT(len(b.Bytes)) - SOffsetT(objectOffset)
		WriteSOffsetT(b.Bytes[objectStart:],
			SOffsetT(b.Offset())-SOffsetT(objectOffset))

		// 10. Finally, store the vtable in memory for future "deduplication" (identical vtables are not created; only the index is updated)
		b.vtables = append(b.vtables, b.Offset())
	} else {
		// 11. If an identical vtable was found
		objectStart := SOffsetT(len(b.Bytes)) - SOffsetT(objectOffset)
		b.head = UOffsetT(objectStart)

		// 12. Update the vtable-distance offset in the object's header; the value is SOffsetT, 4 bytes
		WriteSOffsetT(b.Bytes[b.head:],
			SOffsetT(existingVtable)-SOffsetT(objectOffset))
	}

	// 13. Finally destroy b.vtable
	b.vtable = b.vtable[:0]
	return objectOffset
}
```
Next, let’s explain it step by step:

Step 1: add a 0 alignment scalar. After alignment, write the offset; later, this position will be overwritten by the offset to the vtable. `b.PrependSOffsetT(0)`

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_16.png'>
</p>

The definition of Weapon in the schema is as follows:
```go
table Weapon {
  name:string;
  damage:short;
}
```
`Weapon` has two fields: `name` and `damage`. `name` is a `string`; it must be created before the table is created, and the table can only reference its offset. Here we have already created the `"sword"` string, whose offset is 12. Therefore, in the `sword` object, we need to reference this offset of 12. The current offset is 24; subtracting 12 gives 12, so we write 12 here. This means that the data stored 12 bytes back from here is the `name`. `damage` is a `short`, so it can be embedded directly in the `sword` object. Add two `0`s for 4-byte alignment, and also add the current offset at the beginning as a 4-byte offset value. **Note that at this point, the offset is relative to the end of the buffer; it is not yet an offset relative to the vtable**. The current `b.offset()` is 32, so fill in 4 bytes with `32`.

Step 3: search backward through `vtables` for a vtable that has already been stored. If an identical previously stored vtable exists, find it directly and point the index to it. You can check the test results of `BenchmarkVtableDeduplication`: pointing the index to the same vtable instead of creating a new one can improve performance by 30%.

This step is about looking up the vtable. If none is found, create a new vtable; if one is found, modify the index to point to it.

First assume none is found. Proceed to step 5.

The values stored in the current vtable are `[24,26]`, which are the offsets of `name` and `damage` in the `sword` object. Starting from the head of the object, compute the offsets of the subsequent properties. `off = objectOffset - b.vtable[i]`. This corresponds to step 6 in the code above.


The result of steps 6 through 8 is shown below:


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_17_.png'>
</p>


Compute the offset of `sword` from right to left. The current offset of `sword` is 32. Offset 6 bytes to reach the `Damage` field, then offset another 2 bytes to reach the `name` field. Therefore, the last 4 bytes in the vtable are `8 0 6 0`. The entire `sword` object is 12 bytes, including the header offset. Finally, write the vtable size, which is 8 bytes.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_18_.png'>
</p>

The final step is to fix up the offset in the header of the `sword` object, changing it to the offset from the vtable. Since the current vtable is at a lower address, and the `sword` object is to its right, the offset is positive: `offset = vtable size = 8` bytes. The corresponding code implementation is shown in step 10.


If an identical vtable was found in `vtables` earlier, then only the offset in the object header needs to be changed to the offset from that vtable. This corresponds to step 12 in the code.


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_19.png'>
</p>

The `axe` object can be used as an example to illustrate the case where the same vtable is found. Since both the `sword` object and the `axe` object are of type `Weapon`, the field offset layout inside the objects should be exactly the same, so they share a vtable with the same structure. The `sword` object is created first, with the vtable immediately following it, and then the `axe` object is created. Therefore, the offset in the header of the `axe` object is negative. Here it is `-12`.
```c
12's sign-magnitude = 00000000 00000000 00000000 00001100
12's one's complement = 11111111 11111111 11111111 11110011
12's two's complement = 11111111 11111111 11111111 11110100
```
Stored in reverse order, this is 244 255 255 255.

### 7. Finish Serialization
```go
func (b *Builder) Finish(rootTable UOffsetT) {
	b.assertNotNested()
	b.Prep(b.minalign, SizeUOffsetT)
	b.PrependUOffsetT(rootTable)
	b.finished = true
}
```
At the end of serialization, two more operations are required: byte alignment, and storing the offset that points to the root object.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_20.png'>
</p>

Because we defined the root object as Monster in the schema, after the Monster object is serialized, its vtable is generated immediately afterward. Therefore, the offset of the root table here is 32.


At this point, the entire Monster has been serialized. The final binary buffer is as follows:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_21.png'>
</p>

In the figure above, the numbers above the binary stream are the offset values of the fields. The labels below the binary stream are the field names.


## V. FlatBuffers Decoding Principles

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_3.png'>
</p>

The FlatBuffers decoding process is very simple. Because the offsets of each field were stored during serialization, deserialization is essentially just reading data from the specified offsets.

For scalars, there are two cases: with a default value and without a default value. In the example above, when serializing the Mana field, we directly used the default value. In the FlatBuffers binary stream, you can see that the Mana field is all 0, and its offset is also 0. In fact, this field uses the default value, so when reading it, the value is read directly from the default value recorded in the file generated by flatc.

The Hp field has a default value, but during serialization we did not use the default value; instead, we assigned it a new value. In this case, the binary stream records the offset of Hp, and the value is also stored in the binary stream.

The deserialization process reads the binary stream starting from the root table. It reads the corresponding offset from the vtable, then locates the corresponding field in the corresponding object. If it is a reference type, such as string / vector / table, it reads the offset and then looks up the value at that offset. If it is a non-reference type, it uses the offset in the vtable to locate the corresponding position and read the value directly.


The entire deserialization process is zero-copy and does not allocate or consume any additional memory resources. In addition, FlatBuffers can read any individual field directly, unlike JSON and protocol buffers, which need to read the entire object before a particular field can be accessed. This is where FlatBuffers’ main advantage lies: deserialization.


## VI. FlatBuffers Performance

Since FlatBuffers’ advantage is in deserialization, let’s compare how strong its performance really is.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_8.png'>
</p>

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_9.png'>
</p>


1. Encoding performance: flatbuf has lower encoding performance than protobuf. Among JSON, protobuf, and flatbuf, flatbuf has the worst encoding performance, while JSON sits between the two.

2. Encoded data size: In typical scenarios, transmitted data is compressed. Without compression, FlatBuffers produces the largest data size. The reason is straightforward: the binary stream contains many zero bytes inserted for alignment, and the original data does not undergo any special compression, so the overall data expands even more. Whether compressed or not, FlatBuffers produces the largest data size. After compression, JSON’s data size becomes close to protocol buffer. Since protocol buffer already has compression in its own encoding, after further compression with algorithms such as GZIP, its size remains the smallest.


3. Decoding performance: FlatBuffers is a binary format that does not require decoding, so its decoding performance is much higher—roughly hundreds of times faster than protobuf, and therefore even faster compared with JSON.


The conclusion is that if your scenario heavily depends on deserialization, FlatBuffers is worth considering. protobuf, on the other hand, shows very balanced capabilities across the board.


## VI. FlatBuffers Pros and Cons 

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_5.png'>
</p>

After reading this article on the encoding principles of FlatBuffers, readers should understand the following points:

FlatBuffers’ API is also relatively cumbersome. The API for creating a buffer feels somewhat similar to creating a sprite in Cocos2D-X with C++. Perhaps it was simply born for games.


Compared with protocol buffers, FlatBuffers has the following advantages:

1. Serialized data can be accessed without parsing/unpacking  
Accessing serialized data, even hierarchical data, does not require parsing. Thanks to this, we do not need to spend time initializing a parser (which means building complex field mappings) or parsing the data.
2. Direct memory usage  
FlatBuffers data uses its own memory buffer and does not require allocating additional memory. Unlike JSON, we do not need to allocate extra in-memory objects for the entire hierarchy while parsing data. **FlatBuffers are essentially a zero-copy + Random-access reads version of protobuf**.

The advantages provided by FlatBuffers do not come without compromises. Its disadvantages can also be seen as sacrifices made for those advantages.

1. No readability    
Both FlatBuffers and protocol buffers organize data in binary form, which means debugging becomes more difficult. (To some extent, this can also be considered an advantage, since it provides a certain degree of “security”.)  
2. Slightly cumbersome API    
Due to the construction method of the binary protocol, data must be inserted “from the inside out”. Building FlatBuffers objects is relatively troublesome.
3. Backward compatibility    
When dealing with structured binary data, we must consider the possibility of changes to that structure. Adding or removing fields from our schema must be done carefully. When reading older versions of objects, incorrect schema changes may cause errors silently, without any warning.
4. Serialization performance is sacrificed  
Because FlatBuffers prioritizes deserialization performance, it sacrifices some serialization performance. The serialized data size is the largest, and serialization performance is also the worst.


## VII. Finally


At the very end, as this article was nearing completion, I discovered another open-source library whose performance and characteristics are similar to FlatBuffers.

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_22.png'>
</p>


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/87_6.png'>
</p>

Cap'n Proto is an insanely fast data interchange format and can also be used in RPC systems. Here is an article comparing performance: [“Cap'n Proto: Cap'n Proto, FlatBuffers, and SBE”](https://capnproto.org/news/2014-06-17-capnproto-flatbuffers-sbe.html). Interested readers can treat it as additional reading material.


------------------------------------------------------

References:  

[FlatBuffers official documentation](https://google.github.io/flatbuffers/index.html)     
[flatcc official documentation](https://github.com/dvidelabs/flatcc/blob/master/doc/binary-format.md#flatbuffers-binary-format)       
[Improving Facebook's performance on Android with FlatBuffers](https://code.facebook.com/posts/872547912839369/improving-facebook-s-performance-on-android-with-flatbuffers/)   
[Cap'n Proto: Cap'n Proto, FlatBuffers, and SBE](https://capnproto.org/news/2014-06-17-capnproto-flatbuffers-sbe.html)  
[How much can flatbuffer speed up data reads and writes in real game projects?](https://www.zhihu.com/question/28500901)  
[Hands-on with FlatBuffers](https://www.race604.com/flatbuffers-intro/#fn:1)  
[Using FlatBuffers in Android](https://www.wolfcstech.com/2016/12/08/%E5%9C%A8Android%E4%B8%AD%E4%BD%BF%E7%94%A8FlatBuffers/)  


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/flatbuffers\_encode/](https://halfrost.com/flatbuffers_encode/)