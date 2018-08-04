# 深入浅出 FlatBuffers 之 FlexBuffers

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_0.png'>
</p>

## 一. FlexBuffers 是什么？


FlexBuffers 是 FlatBuffers 中一个 schema-less 的版本。它和 FlatBuffers 其他类型编码原理一样，所有的数据也都是通过偏移量来访问的，所有的标量都按照它们自己的大小对齐，并且所有的数据总是以小端格式存储。

一个不同之处在于 FlexBuffers 是从前到后构建的，因此子项存储在父项之前，并且 root table 是从最后一个字节处开始。

另一个区别是标量数据的存储位数 bit 是可变的（8/16/32/64）。当前宽度总是由父级确定，即如果标量位于数组中，则数组一次确定所有元素的所占字节宽度。为特定的数组选择最小 bit 位宽是编码器自动执行的操作，因此通常不需要用户担心它，但是了解此功能(当然不会在一个每个元素大小都是一个字节的数组中插入一个 double)更有助于提高效率。

FlexBuffers 与 FlatBuffers 不同，它只有一种偏移量，它是一个无符号整数，用于表示自身地址（存储偏移量的地方）的负方向上的偏移的字节数。

## 二. 为什么要发明 FlexBuffers ？

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_1.png'>
</p>

有时候需要存储一些不符合 schema 格式的数据，因为无法提前知道需要存储哪些内容。出于此目的，FlexBuffers 就诞生了。FlatBuffers 有一个称为 FlexBuffers 的专用格式。这是一种二进制格式，可以与 FlatBuffers 一起使用（通过以 FlexBuffers 格式存储缓冲区的一部分），或者也可以作为自己独立的序列化格式。

虽然失去了强大的类型功能，但仍然保留 FlatBuffers 在其他序列化格式（基于 schema 或不基于 schema）上最独特的优势：也可以在不解析/复制/分配对象的情况下访问 FlexBuffers。这在效率/内存友好性方面是一个优势，并且允许独特的用法，例如映射大量的自由格式数据。

FlexBuffers 的设计和实现是一种非常紧凑的编码，将字符串的自动合并与容器大小结合在一起，自动跳转大小（8/16/32/64位）。许多值和 offset 可以用 8 位编码。虽然没有 schema 的结构，由于需要具有自描述性，所以通常体积会变得更大一些，但与常规 FlatBuffers 相比，FlexBuffers 在许多情况下会生成更小的二进制文件。

需要注意的是，**FlexBuffers 比普通的 FlatBuffers 还要慢**，所以我们建议只在需要时使用它。


## 三. FlexBuffers 中的 Vectors


如何表示一个 vectors 是 FlexBuffers 编码的核心。

正如上面提到的，一个数组中每个元素的宽度是由它的父类提供的，数组中会包含 size 字段。举个例子，一个数组中存储 1，2，3，编码如下：

```c
uint8_t 3, 1, 2, 3, 4, 4, 4
```

第一个字段存储的就是 size 字段，放在所有数组元素之前。这一点和 flatbuffer 是完全一致的。需要注意的是，从父类元素偏移到此数组，offset 是指向第一个元素的，而不是 size 字段，所以 size 字段位于 offset - 1 的地方。

由于这是一个无类型的数组 SL\_VECTOR，它后面跟着3个类型字节（每个矢量元素一个字节），它们总是跟随着矢量，并且即使矢量由更大的标量组成，类型也总是一个 uint8\_t。


## 四. FlexBuffers 中的 Types

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_2.png'>
</p>


一个类型字节由 2 个部分构成。

- 低 2 位代表的是孩子的位宽(8，16，32，64)，只有在通过偏移量访问孩子（如子数组）时才会使用此项。内联类型可以忽略这条规则。
- 高 6 位代表的实际类型。

因此，上面例子中 4 代表的是孩子是 8 bit 的，(低 2 位为 0，这里不会被用到，因为都是内联类型)，类型是 SL\_INT (value 1)。

具体可以见 flexbuffers.h

Typed vectors 仅适用于这些节省空间要求很高的类型子集，即内联有符号/无符号整数（TYPE\_VECTOR\_INT / TYPE\_VECTOR\_UINT），浮点数（TYPE\_VECTOR\_FLOAT）和键（TYPE\_VECTOR\_KEY，见下文）。

另外，对于标量来说，固定长度为 2 / 3 / 4 的数组，是不存储 size 字段的（TYPE\_VECTOR\_INT2等），以便在存储常用矢量或颜色数据时节省空间。



## 五. FlexBuffers 中的 Scalars


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_3.png'>
</p>




FlexBuffers 支持整数（TYPE\_INT 和 TYPE\_UINT）和浮点数（TYPE\_FLOAT）。它们可以以内联方式和偏移方式存储（TYPE\_INDIRECT\_ *）。

布尔值（TYPE\_BOOL）和空值（TYPE\_NULL）被编码为内联无符号整数。

blob（TYPE\_BLOB）的编码类似于一个数组，但有一点不同：它元素始终为 uint8\_t。父位宽度仅确定大小字段的宽度，允许 blob 很大而不会使元素变大。 

字符串（TYPE\_STRING）类似于 blob，但为了方便起见，它们有一个附加的 0 终止字节，它们必须是 UTF-8 编码的（因为不支持指向 UTF-8 数据的语言的访问器可能必须将它们转换到本地字符串类型）。

“Key”（TYPE\_KEY）类似于字符串，但不存储 size 字段。它们的命名是因为它们与 map 一起使用，它们不关心大小，因此可以更加紧凑。与字符串不同，键不能包含值为 0 的字节作为其数据的一部分（大小只能由 strlen 决定），因此，如果您愿意，可以在 map 上下文中使用它们，但通常情况下，您最好使用字符串。


## 六. FlexBuffers 中的 Maps



map（TYPE\_MAP）就像一个（无类型）数组，但在 size 字段之前有两个前缀：

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_6.png'>
</p>

由于 map 与数组相同，因此它可以像数组一样迭代（这可能比按 key 查找快）。

key 数组是以 key 为类型的数组。key 和相应的 value 必须按排序顺序（由 strcmp 确定顺序）存储，以便可以使用二分搜索进行查找。

key 向量是单独的值数组的原因是它可以在多个值数组之间共享，并且还允许它在代码中被视为它自己的单独数组。

举个例子，map { foo: 13, bar: 14 } 会被编码成下面的样子 ：

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


## 七. FlexBuffers 中的 root

如前所说的，FlexBuffers 中的 root 是开始于 buffer 的末尾。最后一个 uint8\_t 是 root 节点的宽度（通常父节点确定宽度，但根没有父节点）。在宽度之前的 uint8\_t 是 root 的类型字段。并且在宽度之前的字节是 root 的值（由最后一个字节指定的字节数）。

举个例子：如果 root 的值为 13：

```c
uint8_t 13, 4, 1    // Value, type, root byte width.
```




## 八. FlexBuffers 的用法举例

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/88_4.png'>
</p>


创建一个 buffer：

```c++
flexbuffers::Builder fbb;
fbb.Int(13);
fbb.Finish();
```

flexbuffers 可以创建任何值，只要最后调用 Finish() 即可。不像 FlatBuffers 要求 root 值是一个 table，这里任何值都可以是 root，包括一个孤立的 int 值。

您现在可以访问包含编码值为 `fbb.GetBuffer()` 的 `std::vector <uint8_t>`。这个时候 buffer 和 FlatBuffers 的 buffer 用法一样，可以继续写入，发送这个 buffer，或者将它存储在父 FlatBuffer 中。在这种情况下，buffer 的大小只有 3 个字节。

读取值非常简单：

```c++
auto root = flexbuffers::GetRoot(my_buffer);
int64_t i = root.AsInt64();
```

FlexBuffers 仅仅存储需要的大小，因此它不区分不同大小的整数。不管你输入什么内容，你都可以要求读取 64 位的版本。实际上，由于你需要将 root 作为一个 int 来读取，如果你提供一个实际上包含一个 float 的 buffer 或者一个带有数字的字符串，FlexBuffers 会随时为你转换它，如果不能转换，则返回 0。如果想在访问 buffer 之前知道 buffer 内的内容，则可以调用 `root.GetType()` 或`root.IsInt()` 等。

再举一个复杂一点的例子，往 FlexBuffers 中写入一下复杂的数据：

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

上面这段代码相当于一个 JSON 

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

root 是一个只有两个 key-value 的字典，key 为 vec 和 foo 。与 FlatBuffers 不同的是，它实际上必须将这些 key 存储在 buffer 中（如果通过 k-v 池来存储多个此类对象，它只会执行一次），但与 FlatBuffers 不同的是，它对使用的 key（字段）没有限制。

上面例子中 map 中的第一个值是一个数组。与 FlatBuffers 不同，数组里面可以使用混合类型。还有一种 TypedVector 变种，它只允许一种类型，并且能占用更少的内存。

IndirectFloat 是一个有趣的功能，允许你按偏移量 offset 去存储值，而不是内联的方式。虽然这不会对用户产生任何可见的变化，但是可以共享不止一次出现的很大的值（特别是双精度或 64 位整数）。另一个用法是数组内部，其中最大的元素导致所有元素的 size 都变大了（例如，单个 double 将所有元素强制为 64 位），因此如果 double 可以间接存储，利用 IndirectFloat，则将大量小整数与 double 分开存储会更有效。

读取上面例子中的 JSON：

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

当然 flexbuffer 也可以嵌套在 table 中的任何字段中。可以声明一个字段内包含 flexbuffer。

```c++
a:[ubyte] (flexbuffer);
```

经过编译以后，将为该字段生成一个特殊的访问器，允许你直接访问 root 值，例如 `a_flexbuffer_root().AsInt64（）`。


## 九. FlexBuffers 的一些建议

<p align='center'>
<img src='../images/flatbuffer_flexbuffer_end.gif'>
</p>

1. 数组通常比 map 更有效，所以当有很多小对象时，优先使用 数组。使用数组来代替具有 x，y 和 z key 的映射。更好的是，使用类型化的数组。或者甚至更好，使用固定大小的类型化的数组。
2. map 与数组兼容，并且可以像数组那样迭代。您可以只迭代值 (map.Values())，或者与 key 数组 (map.Keys()) 并行迭代。如果您打算访问大多数或全部元素，这比通过 key 查找每个元素要快，因为这涉及 key 数组的二分搜索。
3. 如果可能的话，不要在有很多小数字的数组中混合需要较大位宽（例如double）的值，因为所有元素都将调整到此宽度。如果有可能，请使用 IndirectDouble。请注意，整数自动使用尽可能小的宽度，即如果要求序列化一个实际数值很小的 int64\_t 值，则将自动使用较少的位。Double 会无损地表示为 float，但这只对少数值才有可能。由于嵌套数组/map 存储在偏移量上，因此它们通常不会影响数组宽度。
4. 要存储大量字节数据，请使用 blob 类型。如果您使用的是类型化数组去存储这个大数据，size 字段的位宽可能会使其占用空间超出预期，并且可能与 memcpy 不兼容。同样，如果它们的大小可能超过 64k 个元素，(u)int16\_t 的大数组可能更适合作为二进制 blob 存储。结构和用法和字符串类似。

------------------------------------------------------

Reference：  

[flatbuffers 官方文档](https://google.github.io/flatbuffers/index.html)        

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/flatBuffers\_flexBuffers/](https://halfrost.com/flatBuffers_flexBuffers/)