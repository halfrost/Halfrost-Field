+++
author = "一缕殇流化隐半边冰霜"
categories = ["FlatBuffers", "Protocol"]
date = 2018-06-16T09:24:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/88_0.png"
slug = "flatbuffers_flexbuffers"
tags = ["FlatBuffers", "Protocol"]
title = "FlatBuffers Explained: FlexBuffers"

+++


## 1. What Is FlexBuffers?


FlexBuffers is a schema-less variant of FlatBuffers. Like other FlatBuffers encodings, all data is accessed via offsets, all scalars are aligned to their own size, and all data is always stored in little-endian format.

One difference is that FlexBuffers is built front to back, so child items are stored before their parents, and the root table starts at the last byte.

Another difference is that the bit width used to store scalar data is variable (8/16/32/64). The current width is always determined by the parent; that is, if a scalar is in an array, the array determines the byte width occupied by all elements at once. Choosing the minimum bit width for a specific array is something the encoder does automatically, so users generally do not need to worry about it. However, understanding this feature (for example, not inserting a `double` into an array whose elements are otherwise all one byte in size) can help improve efficiency.

Unlike FlatBuffers, FlexBuffers has only one kind of offset: an unsigned integer that represents the number of bytes in the negative direction from its own address (the location where the offset is stored).

## 2. Why Was FlexBuffers Invented?

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_1.png'>
</p>

Sometimes you need to store data that does not conform to a schema, because you cannot know in advance what needs to be stored. FlexBuffers was created for this purpose. FlatBuffers provides a dedicated format called FlexBuffers. It is a binary format that can be used together with FlatBuffers (by storing part of a buffer in the FlexBuffers format), or as a standalone serialization format of its own.

Although it gives up strong typing, it still preserves FlatBuffers’ most distinctive advantage over other serialization formats (schema-based or schema-less): FlexBuffers can also be accessed without parsing/copying/allocating objects. This is an advantage in terms of efficiency and memory friendliness, and it enables unique use cases such as mapping large amounts of free-form data.

The design and implementation of FlexBuffers use a very compact encoding that combines automatic string interning with container sizes and automatic jump sizes (8/16/32/64-bit). Many values and offsets can be encoded in 8 bits. Although a schema-less structure usually becomes somewhat larger because it must be self-describing, FlexBuffers often produces smaller binaries than regular FlatBuffers in many cases.

Note that **FlexBuffers is slower than regular FlatBuffers**, so we recommend using it only when necessary.


## 3. Vectors in FlexBuffers


How to represent vectors is central to FlexBuffers encoding.

As mentioned above, the width of each element in an array is provided by its parent, and the array contains a size field. For example, an array storing 1, 2, and 3 is encoded as follows:
```c
uint8_t 3, 1, 2, 3, 4, 4, 4
```
The first field stores the `size` field, placed before all array elements. This is exactly the same as in flatbuffer. Note that when offsetting from a parent element to this array, the offset points to the first element, not to the size field, so the size field is located at `offset - 1`.

Because this is an untyped array, SL\_VECTOR, it is followed by 3 type bytes (one byte per vector element). They always follow the vector, and even if the vector consists of larger scalars, the type is always a uint8\_t.


## IV. Types in FlexBuffers

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_2.png'>
</p>


A type byte consists of 2 parts.

- The low 2 bits represent the bit width of the child (8, 16, 32, 64). This is only used when accessing a child via an offset, such as a child array. Inline types can ignore this rule.
- The high 6 bits represent the actual type.

Therefore, in the example above, 4 means that the child is 8 bits (the low 2 bits are 0; they are not used here because these are all inline types), and the type is SL\_INT (value 1).

For details, see flexbuffers.h.

Typed vectors apply only to the subset of types with very high space-saving requirements: inline signed/unsigned integers (TYPE\_VECTOR\_INT / TYPE\_VECTOR\_UINT), floating-point numbers (TYPE\_VECTOR\_FLOAT), and keys (TYPE\_VECTOR\_KEY; see below).

In addition, for scalars, fixed-length arrays of length 2 / 3 / 4 do not store the size field (TYPE\_VECTOR\_INT2, etc.), in order to save space when storing common vector or color data.


## V. Scalars in FlexBuffers


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_3.png'>
</p>


FlexBuffers supports integers (TYPE\_INT and TYPE\_UINT) and floating-point numbers (TYPE\_FLOAT). They can be stored inline or by offset (TYPE\_INDIRECT\_ *).

Booleans (TYPE\_BOOL) and null values (TYPE\_NULL) are encoded as inline unsigned integers.

A blob (TYPE\_BLOB) is encoded similarly to an array, with one difference: its elements are always uint8\_t. The parent bit width determines only the width of the size field, allowing a blob to be very large without increasing the size of its elements. 

A string (TYPE\_STRING) is similar to a blob, but for convenience it has an additional 0 terminator byte, and it must be UTF-8 encoded (because accessors for languages that do not support pointing to UTF-8 data may have to convert it to the native string type).

A “Key” (TYPE\_KEY) is similar to a string, but it does not store a size field. They are named this way because they are used with maps, where the size is not needed, so they can be more compact. Unlike strings, keys cannot contain bytes with value 0 as part of their data (the size can only be determined by strlen). Therefore, you can use them in a map context if you want, but in general you are better off using strings.


## VI. Maps in FlexBuffers


A map (TYPE\_MAP) is like an (untyped) array, but with two prefixes before the size field:

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_6.png'>
</p>

Because a map is the same as an array, it can be iterated like an array (which may be faster than looking up by key).

The key array is an array whose type is key. Keys and their corresponding values must be stored in sorted order (as determined by strcmp), so that lookups can be performed with binary search.

The reason the key vector is a separate value array is that it can be shared among multiple value arrays, and it also allows it to be treated in code as its own separate array.

For example, the map { foo: 13, bar: 14 } would be encoded as follows:
```c
0 : uint8_t 'b', 'a', 'r', 0
4 : uint8_t 'f', 'o', 'o', 0
8 : uint8_t 2      // key vector of size 2
// key vector offset points here
9 : uint8_t 9, 6   // offsets to bar_key and foo_key
11: uint8_t 2, 1   // offset to key vector, and its byte width
13: uint8_t 2      // value vector of size
// value vector offset points here
14: uint8_t 14, 13 // values
16: uint8_t 4, 4   // types
```

## VII. The root in FlexBuffers

As mentioned earlier, the root in FlexBuffers starts at the end of the buffer. The final uint8\_t is the width of the root node (normally the parent determines the width, but the root has no parent). The uint8\_t before the width is the root’s type field. The bytes before the width are the root’s value (with the number of bytes specified by the final byte).

For example: if the root’s value is 13:
```c
uint8_t 13, 4, 1    // Value, type, root byte width.
```

## VIII. Examples of Using FlexBuffers

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_4.png'>
</p>


Create a buffer:
```c++
flexbuffers::Builder fbb;
fbb.Int(13);
fbb.Finish();
```
FlexBuffers can create any value, as long as you call Finish() at the end. Unlike FlatBuffers, which requires the root value to be a table, any value can be the root here, including a standalone int value.

You can now access the `std::vector <uint8_t>` containing the encoded value via `fbb.GetBuffer()`. At this point, the buffer can be used the same way as a FlatBuffers buffer: you can continue writing to it, send it, or store it in a parent FlatBuffer. In this case, the buffer is only 3 bytes in size.

Reading the value is straightforward:
```c++
auto root = flexbuffers::GetRoot(my_buffer);
int64_t i = root.AsInt64();
```
FlexBuffers stores only the size it needs, so it does not distinguish between integers of different sizes. Regardless of what you put in, you can request to read the 64-bit version. In fact, because you need to read the root as an int, if you provide a buffer that actually contains a float, or a string with a number in it, FlexBuffers will convert it for you on the fly; if it cannot convert it, it returns 0. If you want to know what is in the buffer before accessing it, you can call `root.GetType()` or `root.IsInt()`, and so on.

As a slightly more complex example, write the following complex data into FlexBuffers:
```c++
fbb.Map([&]() {
  fbb.Vector("vec", [&]() {
    fbb.Int(-100);
    fbb.String("Fred");
    fbb.IndirectFloat(4.0f);
  });
  fbb.UInt("foo", 100);
});
```
The code above is equivalent to a JSON
```c
{
    "vec":[
        -100,
        "Fred",
        4.0
    ],
    "foo":100
}
```
`root` is a dictionary with only two key-value pairs, whose keys are `vec` and `foo`. Unlike FlatBuffers, it actually has to store these keys in the buffer (if multiple such objects are stored via a k-v pool, it will do this only once), but unlike FlatBuffers, it imposes no restrictions on the keys (fields) used.

In the example above, the first value in the map is an array. Unlike FlatBuffers, arrays can contain mixed types. There is also a `TypedVector` variant, which allows only a single type and can use less memory.

`IndirectFloat` is an interesting feature that lets you store a value by offset rather than inline. Although this does not cause any user-visible change, it allows large values that appear more than once to be shared (especially doubles or 64-bit integers). Another use case is inside arrays, where the largest element causes the size of all elements to increase (for example, a single double forces all elements to 64 bits). Therefore, if the double can be stored indirectly, using `IndirectFloat` makes it more efficient to store many small integers separately from the double.

Reading the JSON in the example above:
```c++
auto map = flexbuffers::GetRoot(my_buffer).AsMap();
map.size();  // 2
auto vec = map["vec"].AsVector();
vec.size();  // 3
vec[0].AsInt64();  // -100;
vec[1].AsString().c_str();  // "Fred";
vec[1].AsInt64();  // 0 (Number parsing failed).
vec[2].AsDouble();  // 4.0
vec[2].AsString().IsTheEmptyString();  // true (Wrong Type).
vec[2].AsString().c_str();  // "" (This still works though).
vec[2].ToString().c_str();  // "4" (Or have it converted).
map["foo"].AsUInt8();  // 100
map["unknown"].IsNull();  // true
```
Of course, a flexbuffer can also be nested in any field within a table. You can declare that a field contains a flexbuffer.
```c++
a:[ubyte] (flexbuffer);
```
After compilation, a special accessor will be generated for this field, allowing you to directly access the root value, such as `a_flexbuffer_root().AsInt64（）`.


## IX. Some Recommendations for FlexBuffers

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_5.gif'>
</p>

1. Arrays are generally more efficient than maps, so when you have many small objects, prefer arrays. Use arrays instead of maps with x, y, and z keys. Better yet, use typed arrays. Or even better, use fixed-size typed arrays.
2. Maps are compatible with arrays and can be iterated like arrays. You can iterate over just the values (map.Values()), or iterate in parallel with the key array (map.Keys()). If you intend to access most or all elements, this is faster than looking up each element by key, because key lookup involves a binary search over the key array.
3. If possible, do not mix values that require a larger bit width (such as double) into arrays containing many small numbers, because all elements will be adjusted to that width. If possible, use IndirectDouble. Note that integers automatically use the smallest possible width; that is, if you request serialization of an int64\_t value whose actual numeric value is small, fewer bits will be used automatically. Doubles are represented losslessly as floats, but this is only possible for a small number of values. Because nested arrays/maps are stored as offsets, they usually do not affect the array width.
4. To store large amounts of byte data, use the blob type. If you use a typed array to store this large data, the bit width of the size field may cause it to take more space than expected, and it may not be compatible with memcpy. Similarly, if their size may exceed 64k elements, large arrays of (u)int16\_t may be better stored as binary blobs. Their structure and usage are similar to strings.

------------------------------------------------------

Reference:  

[flatbuffers official documentation](https://google.github.io/flatbuffers/index.html)        

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/flatBuffers\_flexBuffers/](https://halfrost.com/flatBuffers_flexBuffers/)