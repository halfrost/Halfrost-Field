# 深入浅出 FlatBuffers 之 Schema

<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/86_0.png'>
</p>

## 一. FlatBuffers 是什么？

FlatBuffers 是一个序列化开源库，实现了与 Protocol Buffers，Thrift，Apache Avro，SBE 和 Cap'n Proto 类似的序列化格式，主要由 Wouter van Oortmerssen 编写，并由 Google 开源。Oortmerssen 最初为 Android 游戏和注重性能的应用而开发了FlatBuffers。现在它具有C ++，C＃，C，Go，Java，PHP，Python 和 JavaScript 的端口。


FlatBuffer 是一个二进制 buffer，它使用 offset 组织嵌套对象（struct，table，vectors，等），可以使数据像任何基于指针的数据结构一样，就地访问数据。然而 FlatBuffer 与大多数内存中的数据结构不同，它使用严格的对齐规则和字节顺序来确保 buffer 是跨平台的。此外，对于 table 对象，FlatBuffers 提供前向/后向兼容性和 optional 字段，以支持大多数格式的演变。 

FlatBuffers 的主要目标是避免反序列化。这是通过定义二进制数据协议来实现的，一种将定义好的将数据转换为二进制数据的方法。由该协议创建的二进制结构可以 wire 发送，并且无需进一步处理即可读取。相比较而言，在传输 JSON 时，我们需要将数据转换为字符串，通过 wire 发送，解析字符串，并将其转换为本地对象。Flatbuffers 不需要这些操作。你用二进制装入数据，发送相同的二进制文件，并直接从二进制文件读取。


尽管 FlatBuffers 有自己的接口定义语言来定义要与之序列化的数据，但它也支持 Protocol Buffers 中的 `.proto`格式。

在 schema 中定义对象类型，然后可以将它们编译为 C++ 或 Java 等各种主流语言，以实现零开销读写。FlatBuffers 还支持将 JSON 数据动态地分析到 buffer 中。

除了解析效率以外，二进制格式还带来了另一个优势，数据的二进制表示通常更具有效率。我们可以使用 4 字节的 UInt 而不是 10 个字符来存储 10 位数字的整数。

## 二. 为什么要发明 FlatBuffers ？


<p align='center'>
<img src='../images/flatbuffers.png'>
</p>

JSON 是一种独立于语言存在的数据格式，但是它解析数据并将之转换成如 Java 对象时，会消耗我们的时间和内存资源。客户端解析一个 20KB 的 JSON 流差不多需要 35ms，而 UI 一次刷新的时间是 16.6ms。在高实时游戏中，是不能有任何卡顿延迟的，所以需要一种新的数据格式；服务器在解析 JSON 时候，有时候会创建非常多的小对象，对于每秒要处理百万玩家的 JSON 数据，服务器压力会变大，如果每次解析 JSON 都会产生很多小对象，那么海量玩家带来的海量小对象，在内存回收的时候可能会造成 GC 相关的问题。Google 员工 Wouter van Oortmerssen 为了解决游戏中性能的问题，于是开发出了 FlatBuffers。(注：Protocol buffers 是 created by google，而 FlatBuffers 是 created at google)

几年前，Facebook 宣称自己的 Android app 在数据处理的性能方面有了极大的提升。在几乎整个 app 中，他们放弃了 JSON 而用 FlatBuffers 取而代之。

[FlatBuffers](https://github.com/google/flatbuffers) (9490 star) 和 [Cap'n Proto](https://github.com/capnproto/capnproto) (5527 star)、[simple-binary-encoding](https://github.com/real-logic/simple-binary-encoding) (1351 star) 一样，它支持“零拷贝”反序列化，在序列化过程中没有临时对象产生，没有额外的内存分配，访问序列化数据也不需要先将其复制到内存的单独部分，这使得以这些格式访问数据比需要格式的数据(如JSON，CSV 和 protobuf)快得多。

FlatBuffers 与 Protocol Buffers 确实比较相似，主要的区别在于 FlatBuffers 在访问数据之前不需要解析/解包。两者代码也是一个数量级的。但是 Protocol Buffers 既没有可选的文本导入/导出功能，也没有 union 这个语言特性，这两点 FlatBuffers 都有。

FlatBuffers 专注于移动硬件（内存大小和内存带宽比桌面端硬件更受限制），以及具有最高性能需求的应用程序：游戏。

## 三. FlatBuffers 使用量

说了这么多，读者会疑问，FlatBuffers 使用的人多么？Google 官方页面上提了 3 个著名的 app 和 1 个框架在使用它。

BobbleApp，印度第一贴图 App。BobbleApp 中使用 FlatBuffers 后 App 的性能明显增强。

Facebook 使用 FlatBuffers 在 Android App 中进行客户端服务端的沟通。他们写了一篇文章[《Improving Facebook's performance on Android with FlatBuffers》](https://code.facebook.com/posts/872547912839369/improving-facebook-s-performance-on-android-with-flatbuffers/)来描述 FlatBuffers 是如何加速加载内容的。

Google 的 Fun Propulsion Labs 在他们所有的库和游戏中大量使用 FlatBuffers。

Cocos2d-X，第一开源移动游戏引擎，使用 FlatBuffers 来序列化所有的游戏数据。

由此可见，在游戏类的 app 中，广泛使用 FlatBuffers。


## 四. 定义 .fbs schema 文件


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/86_1.png'>
</p>


编写一个 schema 文件，允许您定义您想要序列化的数据结构。字段可以有标量类型（所有大小的整数/浮点数），也可以是字符串，任何类型的数组，引用另一个对象，或者一组可能的对象（Union）。字段可以是可选 optional 的也可以有默认值，所以它们不需要存在于每个对象实例中。

举个例子：

```schema
// example IDL file

namespace MyGame;

attribute "priority";

enum Color : byte { Red = 1, Green, Blue }

union Any { Monster, Weapon, Pickup }

struct Vec3 {
  x:float;
  y:float;
  z:float;
}

table Monster {
  pos:Vec3;
  mana:short = 150;
  hp:short = 100;
  name:string;
  friendly:bool = false (deprecated, priority: 1);
  inventory:[ubyte];
  color:Color = Blue;
  test:Any;
}

root_type Monster;
```

上面是 schema 语言的语法，schema 又名 IDL(Interface Definition Language，接口定义语言)，代码和 C 家族的语言非常像。

在 FlatBuffers 的 schema 文件中，有两个非常重要的概念，struct 和 table 。

### 1. Table

Table 是在 FlatBuffers 中定义对象的主要方式，由一个名称（这里是 Monster）和一个字段列表组成。每个字段都有一个名称，一个类型和一个可选的默认值（如果省略，它默认为 0 / NULL）。

**Table 中每个字段都是可选 optional 的**：它不必出现在 wire 表示中，并且可以选择省略每个单独对象的字段。因此，您可以灵活地添加字段而不用担心数据膨胀。这种设计也是 FlatBuffer 的前向和后向兼容机制。

假设当前 schema 是如下：

```schema
table { a:int; b:int; }
```

现在想对这个 schema 进行更改。

有几点需要注意：

### 添加字段

只能在表定义的末尾添加新的字段。旧数据仍会正确读取，并在读取时为您提供默认值。旧代码将简单地忽略新字段。如果希望灵活地使用 schema 中字段的任何顺序，您可以手动分配 ids（很像 Protocol Buffers），请参阅下面的 [id 属性](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/FlatBuffers-schema.md#9-attributes)。


举例：

```schema
table { a:int; b:int; c:int; }
```

这样做可以。旧的 schema 读取新的数据结构会忽略新字段 c 的存在。新的 schema 读取旧的数据，将会取到 c 的默认值（在此情况下为 0，因为未指定）。


```schema
table { c:int a:int; b:int; }
```

在前面添加新字段是不允许的，因为这会使 schema 新旧版本不兼容。用老的代码读取新的数据，读取新字段 c 的时候，其实读到的是老的 a 字段。用新代码读取老的数据，读取老字段 a 的时候，其实读到的是老的 b 字段。


```schema
table { c:int (id: 2); a:int (id: 0); b:int (id: 1); }
```

这样做是可行的。如果您的意图是以有意义的方式对语义进行排序/分组，您可以使用显式标识赋值来完成。引入 id 以后，table 中的字段顺序就无所谓了，新的与旧的 schema 完全兼容，只要我们保留 id 序列即可。


### 删除字段

不能从 schema 中删除不再使用的字段，但可以简单地停止将它们写入数据中，和写入和删除字段，两种做法几乎相同的效果。此外，可以将它们标记为 deprecated，如上例所示，被标记的字段不会再生成 C ++ 的访问器，从而强制该字段不再被使用。 （小心：这可能会破坏代码！）。

```schema
table { b:int; }
```

这种删除字段的方法不可行。我们只能通过弃用来删除某个字段，而不管是否使用了明确的ID 标识。



```schema
table { a:int (deprecated); b:int; }
```

上面这样的做法也是可以的。旧的 schema 读取新的数据结构会获得 a 的默认值，因为它不存在。新的 schema 代码不能读取也不能写入 a（现有代码尝试这样做会导致编译错误），但仍可以读取旧数据（它们将忽略该字段）。


### 更改字段

可以更改字段名称和 table 名称，如果您的代码可以正常工作，那么您也可以更改它们。

```schema
table { a:uint; b:uint; }
```

直接修改字段的类型，这样做可能可行，也有情况不行。只有在类型改变是相同大小的情况下，是可行的。如果旧数据不包含任何负数，这将是安全的，如果包含了负数，这样改变会出现问题。


```schema
table { a:int = 1; b:int = 2; }
```

这样修改不可行。任何写入数值为 0 的旧数据都不会再写入 buffer，并依赖于重新创建的默认值。现在这些值将显示为1和2。有些情况下可能不会出错，但必须小心。


```schema
table { aa:int; bb:int; }
```

上面这种修改方法，修改原来的变量名以后，可能会出现问题。由于已经重命名了字段，这将破坏所有使用此版本 schema 的代码（和 JSON 文件），这与实际的二进制缓冲区不兼容。


table 是 FlatBuffers 的基石，因为对于大多数需要序列化应用来说，数据结构改变是必不可少的。通常情况下，处理数据结构的变更在大多数序列化解决方案的解析过程中可以透明地完成的。但是一个 FlatBuffer 在被访问之前不会被分析。 

为了解决数据结构变更的问题，table 通过 vtable 间接访问字段。每个 table 都带有一个 vtable（可以在具有相同布局的多个 table 之间共享），并且包含存储此特定类型 vtable 实例的字段的信息。vtable 还可能表明该字段不存在（因为此 FlatBuffer 是使用旧版本的软件编写的，仅仅因为信息对于此实例不是必需的，或者被视为已弃用），在这种情况下会返回默认值。 

table 的内存开销很小（因为 vtables 很小并且共享）访问成本也很小（间接访问），但是提供了很大的灵活性。table 甚至可能比等价的 struct 花费更少的内存，因为字段在等于默认值时不需要存储在 buffer 中。



### 2. Structs

structs 和 table 非常相似，只是 structs 没有任何字段是可选的（所以也没有默认值），字段可能不会被添加或被弃用。结构可能只包含标量或其他结构。如果确定以后不会进行任何更改（如 Vec3 示例中非常明显），请将其用于简单对象。structs 使用的内存少于 table，并且访问速度更快（它们总是以串联方式存储在其父对象中，并且不使用虚拟表）。

structs 不提供前向/后向兼容性，但占用内存更小。对于不太可能改变的非常小的对象（例如坐标对或RGBA颜色）存成 struct 是非常有用的。

### 3. Types

FlatBuffers 支持的 标量 类型有以下几种：

- 8 bit: byte (int8), ubyte (uint8), bool  
- 16 bit: short (int16), ushort (uint16)  
- 32 bit: int (int32), uint (uint32), float (float32)  
- 64 bit: long (int64), ulong (uint64), double (float64)  

括号里面的名字对应的是类型的别名。

FlatBuffers 支持的 非标量 类型有以下几种：

- 任何类型的数组。不过不支持嵌套数组，可以用 table 内定义数组的方式来取代嵌套数组。
- UTF-8 和 7-bit ASCII 的字符串。其他格式的编码字符串或者二进制数据，需要用 [byte] 或者 [ubyte] 来替代。
- table、structs、enums、unions

标量类型的字段有默认值，非标量的字段(string/vector/table)如果没有值的话，默认值为 NULL。

一旦一个类型声明了，**尽量不要改变它的类型，一旦改变了，很可能就会出现错误**。上面也提到过了，如果把 int 改成 uint，数据如果有负数，那么就会出错。

### 4. Enums


定义一系列命名常量，每个命名常量可以分别给一个定值，也可以默认的从前一个值增加一。默认的第一个值是 0。正如在上面例子中看到的枚举声明，使用:(上面例子中是 byte 字节）指定枚举的基本整型，然后确定用这个枚举类型声明的每个字段的类型。

通常，只应添加枚举值，不要去删除枚举值（对枚举不存在弃用一说）。**这需要开发者代码通过处理未知的枚举值来自行处理向前兼容性的问题**。

### 5. Unions

**这个是 Protocol buffers 中还不支持的类型**。

union 是 C 语言中的概念，一个 union 中可以放置多种类型，共同使用一个内存区域。

但是在 FlatBuffers 中，Unions 可以像 Enums 一样共享许多属性，但不是常量的新名称，而是使用 table 的名称。可以声明一个 Unions 字段，该字段可以包含对这些类型中的任何一个的引用，**即这块内存区域只能由其中一种类型使用**。另外还会生成一个带有后缀 `_type` 的隐藏字段，该字段包含相应的枚举值，从而可以在运行时知道要将哪些类型转换为类型。

**union 跟 enum 比较类似，但是 union 包含的是 table，enum 包含的是 scalar或者 struct。**

Unions 是一种能够在一个 FlatBuffer 中发送多种消息类型的好方法。请注意，因为union 字段实际上是两个字段(有一个隐藏字段)，所以它必须始终是表的一部分，它本身不能作为 FlatBuffer 的 root。

如果需要以更开放的方式区分不同的 FlatBuffers，例如文件，请参阅下面的[文件标识功能](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/FlatBuffers-schema.md#7-file-identification-and-extension)。

最后还有一个实验功能，只在 C++ 的版本实现中提供支持，如上面例子中，把 [Any] \(联合体数组) 作为一个类型添加到了 Monster 的 table 定义中。


### 6. Root type

这声明了您认为是序列化数据的根表（或结构）。这对于解析不包含对象类型信息的 JSON 数据尤为重要。


### 7. File identification and extension

通常情况下，FlatBuffer 二进制缓冲区不是自描述的，即它需要您了解其 schema 才能正确解析数据。但是如果你想使用一个 FlatBuffer 作为文件格式，那么能够在那里有一个“魔术数字”是很方便的，就像大多数文件格式一样，能够做一个完整的检查来看看你是否阅读你期望的文件类型。

FlatBuffer 虽然允许开发者可以在 FlatBuffer 前加上自己的文件头，但 FlatBuffers 有一种内置方法，可以让标识符占用最少空间，并且还能使 FlatBuffer 与不具有此类标识符的 FlatBuffer 相互兼容。

声明文件格式的方法类似于 root\_type：

```schema
file_identifier "MYFI";
```

**标识符必须正好 4 个字符。这 4 个字符将作为 buffer 末尾的 [4,7] 字节**。

对于具有这种标识符的任何 schema，flatc 会自动将标识符添加到它生成的任何二进制文件中（带-b），并且生成的调用如 FinishMonsterBuffer 也会添加标识符。如果你已经指定了一个标识符并希望生成一个没有标识符的缓冲区，你可以通过直接显示调用FlatBufferBuilder :: Finish 来完成这一目的。


加载缓冲区数据以后，可以使用像 MonsterBufferHasIdentifier 这样的调用来检查标识符是否存在。


给文件添加标识符是最佳实践。如果只是简单的想通过网络发送一组可能的消息中的一个，那么最好用 Union。

默认情况下，flatc 会将二进制文件输出为 `.bin`。schema 中的这个声明会将其改变为任何你想要的：

```schema
file_extension "ext";
```

### 8. RPC interface declarations

RPC 声明了一组函数，它将 FlatBuffer 作为入参（request）并返回一个 FlatBuffer 作为 response（它们都必须是 table 类型）：

```schema
rpc_service MonsterStorage {
  Store(Monster):StoreResponse;
  Retrieve(MonsterId):Monster;
}
```

这些产生的代码以及它的使用方式取决于使用的语言和 RPC 系统，可以通过增加 `--grpc` 编译参数，代码生成器会对 GRPC 有初步的支持。


### 9. Attributes


Attributes 可以附加到字段声明，放在字段后面或者 table/struct/enum/union 的名称之后。这些字段可能有值也有可能没有值。

一些 Attributes 只能被编译器识别，比如 deprecated。用户也可以定义一些 Attributes，但是需要提前进行 Attributes 声明。声明以后可以在运行时解析 schema 的时候进行查询。这个对于开发一个属于自己的代码编译/生成器来说是非常有用的。或者是想添加一些特殊信息(一些帮助信息等等)到自己的 FlatBuffers 工具之中。

目前最新版能识别到的 Attributes 有 11 种。

- `id:n` (on a table field)  
id 代表设置某个字段的标识符为 n 。一旦启用了这个 id 标识符，那么所有字段都必须使用 id 标识，并且 id 必须是从 0 开始的连续数字。需要特殊注意的是 Union，由于 Union 是由 2 个字段构成的，并且隐藏字段是排在 union 字段的前面。（假设在 union 前面字段的 id 排到了6，那么 union 将会占据 7 和 8 这两个 id 编号，7 是隐藏字段，8 是 union 字段）添加了 id 标识符以后，字段在 schema 内部的相互顺序就不重要了。新字段用的 id 必须是紧接着的下一个可用的 id(id 不能跳，必须是连续的)。
- `deprecated` (on a field)  
deprecated 代表不再为此字段生成访问器，代码应停止使用此数据。旧数据可能仍包含此字段，但不能再通过新的代码去访问这个字段。请注意，如果您弃用先前所需的字段，旧代码可能无法验证新数据（使用可选验证器时）。
- `required` (on a non-scalar table field)  
required 代表该字段不能被省略。默认情况下，所有字段都是可选的，即可以省略。这是可取的，因为它有助于向前/向后兼容性以及数据结构的灵活性。这也是阅读代码的负担，因为对于非标量字段，它要求您检查 NULL 并采取适当的操作。通过指定 required 字段，可以强制构建 FlatBuffers 的代码确保此字段已初始化，因此读取的代码可以直接访问它，而不检查 NULL。如果构造代码没有初始化这个字段，他们将得到一个断言，并提示缺少必要的字段。请注意，如果将此属性添加到现有字段，则只有在现有数据始终包含此字段/现有代码始终写入此字段，这两种情况下才有效。
- `force_align: size` (on a struct)  
force\_align 代表强制这个结构的对齐比它自然对齐的要高。如果 buffer 创建的时候是以 force\_align 声明创建的，那么里面的所有 structs 都会被强制对齐。（对于在 FlatBufferBuilder 中直接访问的缓冲区，这种情况并不是一定的）  
- `bit_flags` (on an enum)  
bit\_flags 这个字段的值表示比特，这意味着在 schema 中指定的任何值 N 最终将代表1 << N，或者默认不指定值的情况下，将默认得到序列1,2,4,8 ，...
- `nested_flatbuffer: "table_name"` (on a field)  
nested\_flatbuffer 代表该字段（必须是 ubyte 的数组）嵌套包含 flatbuffer 数据，其根类型由 table\_name 给出。生成的代码将为嵌套的 FlatBuffer 生成一个方便的访问器。
- `flexbuffer` (on a field)  
flexbuffer 表示该字段（必须是 ubyte 的数组）包含 flexbuffer 数据。生成的代码将为 FlexBuffer 的 root 创建一个方便的访问器。
- `key` (on a field)  
key 字段用于当前 table 中，对其所在类型的数组进行排序时用作关键字。可用于就地查找二进制搜索。
- `hash` (on a field)  
这是一个不带符号的 32/64 位整数字段，因为在 JSON 解析过程中它的值允许为字符串，然后将其存储为其哈希。属性的值是要使用的散列算法，即使用 fnv1\_32、fnv1\_64、fnv1a\_32、fnv1a\_64 其中之一。  
- `original_order` (on a table)  
由于表中的元素不需要以任何特定的顺序存储，因此通常为了优化空间，而对它们大小进行排序。而 original\_order 阻止了这种情况发生。通常应该没有任何理由使用这个标志。
- 'native_*'  
已经添加了几个属性来支持基于 [C++ 对象的 API](https://google.github.io/flatbuffers/flatbuffers_guide_use_cpp.html#flatbuffers_cpp_object_based_api)，所有这些属性都以 “native\_” 作为前缀。具体可以点[链接](https://google.github.io/flatbuffers/flatbuffers_guide_use_cpp.html#flatbuffers_cpp_object_based_api)查看支持的说明，`native_inline`、`native_default`、`native_custom_alloc`、`native_type`、`native_include: "path"`。

### 10. 设计建议

FlatBuffers 是一个高效的数据格式，但要实现效率，您需要一个高效的 schema。如何表示具有完全不同 size 大小特征的数据通常有多种选择。

由于 FlatBuffers 的灵活性和可扩展性，将任何类型的数据表示为字典（如在 JSON 中）是非常普遍的做法。尽管可以在 FlatBuffers（作为具有键和值的表的数组）中模拟这一点，但这对于像 FlatBuffers 这样的强类型系统来说，这样做是一种低效的方式，会导致生成相对较大的二进制文件。在大多数系统中，FlatBuffer table 比 classes/structs 更灵活，因为 table 在处理 field 数量非常多，但是实际使用只有其中少数几个 field 这种情况，效率依旧非常高。因此，组织数据应该尽可能的组织成 table 的形式。

同样，如果可能的话，尽量使用枚举的形式代替字符串。

FlatBuffers 中没有继承的概念，所以想表示一组相关数据结构的方式是 union。但是，union 确实有成本，另外一种高效的做法就是建立一个 table 。如果这些数据结构有很多相似或者可以共享的 field ，那么建议一个 table 是非常高效的。在这个 table 中包含所有数据结构的所有字段即可。高效的原因就是 optional 字段是非常廉价的，消耗少。

FlatBuffers 默认可以支持存放的下所有整数，因此尽量选择所需的最小大小，而不是默认为 int/long。

可以考虑用 buffer 中一个字符串或者 table 来共享一些公共的数据，这样做会提高效率，因此将重复的数据拆成共享数据结构 + 私有数据结构，这样做是非常值得的。


## 五. FlatBuffers 的 JSON 解析


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/86_2.png'>
</p>


FlatBuffers 是支持解析 JSON 成自己的格式的。即解析 schema 的解析器同样可以解析符合 schema 规则的 JSON 对象。所以和其他的 JSON 解析器不同，这个解析器是强类型的，并且解析结果也只是 FlatBuffers。具体做法请参照 flatc 文档和 C++ 对应的 FlatBuffers 文档，查看如何在运行时解析 JSON 成 FlatBuffers。

为了解析 JSON，除了需要定义一个 schema 以外，FlatBuffers 的解析器还有以下这些改变：

- 它接受带和不带引号的字段名称，就像许多 JSON 解析器已经做的那样。它也可以不用引号输出它们，但可以使用 `strict_json` 标志输出它们。
- 如果一个字段具有枚举类型，解析器会将枚举识别符号枚举值（带或不带引号）而不是数字，例如 field：EnumVal。如果一个字段是整数类型的，你仍然可以使用符号名称，但是这些值需要以它们的类型作为前缀，并且需要用引号引起来。field：“Enum.EnumVal”。对于代表标志的枚举，可以在多个字符串中插入空格或者利用点语法，例如。field：“EnumVal1 EnumVal2” 或 field：“Enum.EnumVal1 Enum.EnumVal2”。
- 对于 union，这些需要用两个 field 来指定，就像在从代码序列化时一样。例如。对于 field foo，您必须在 foo 字段之前添加一个 `foo_type：FooOne`，FooOne 就是可以在 union 之外使用的 table。
- 如果一个 field 的值是 null（例如，field：null）意味着这个字段是有默认值的（与完全未指定该字段，这两种情况具有相同的效果）。
- 解析器内置了一些转换函数，所以你可以用 rad(180) 函数替代写 3.14159 的地方。目前支持以下这些函数：rad，deg，cos，sin，tan，acos，asin，atan。

解析JSON时，解析器识别字符串中的以下转义码：

`\n` - 换行。   
`\t` - 标签。   
`\r` - 回车。   
`\b` - 退格。   
`\f` - 换页。   
`\“` - 双引号。   
`\\` - 反斜杠。   
`\/` - 正斜杠。  
`\uXXXX` - 16位 unicode，转换为等效的 UTF-8 表示。   
`\xXX` - 8 位二进制十六进制数字 XX。这是唯一一个不属于 JSON 规范的地方（请参阅[http://json.org/](http://json.org/)），但是需要能够将字符串中的任意二进制编码为文本并返回而不丢失信息（例如字节 0xFF 就不可以表示为标准的 JSON）。

当从二进制再反向表示生成 JSON 时，它还会再次生成这些转义代码。



## 六. FlatBuffers 命名规范

schema 中的标识符是为了翻译成许多不同的编程语言，所以把 schema 的编码风格改成和当前项目语言使用的风格，是一种错误的做法。应该让 schema 的代码风格更加通用。

- Table, struct, enum and rpc names (types) 采用大写驼峰命名法。
- Table and struct field names 采用下划线命名法。这样做方法自动生成小写驼峰命名的代码。
- Enum values 采用大写驼峰命名法。
- namespaces 采用大写驼峰命名法。

还有 2 条关于书写格式的建议：

- 大括号：与声明的开头位于同一行。
- 间距：缩进2个空格。`:`两边没有空格，`=`两边各一个空格。

## 七. FlatBuffers 一些"坑"

<p align='center'>
<img src='../images/flatbuffer_attention.gif'>
</p>



大多数可序列化格式（例如 JSON 或 Protocol Buffers）对于某个字段是否存在于某个对象中是非常明确，可以将其用作“额外”信息。 

但是在 FlatBuffers 中，除了标量值之外，这也适用于其他所有内容。 FlatBuffers 默认情况下不会写入等于默认值的字段（对于标量），这样可以节省大量空间。 然而，这也意味着测试一个字段是否“存在”有点没有意义，因为它不会告诉你，该字段是否是通过调用add_field 方法调来 set 的，除非你对非默认值的信息感兴趣。默认值是不会写入到 buffer 中的。


可变的 FlatBufferBuilder 实现了一个名为 force\_defaults 的方法，可以避免这种行为，因为即使与默认值相等，也会写入字段。然后可以使用 IsFieldPresent 来查询 buffer 中是否存在某个字段。 

另一种方法是将标量字段包装在 struct 中。这样，如果它不存在，它将返回 null。这种方法厉害的是，struct 不会占用比它们所代表的标量更多的空间。


## 八. 最后 


读完本篇 FlatBuffers 编码原理以后，读者应该能明白以下几点：

与 protocol buffers 相比，FlatBuffers 的数据结构定义文件，功能上有以下一些“改进”：

- 弃用的字段，不用手动分配字段的 ID。在 `.proto` 中扩展一个对象，需要在数字中寻找一个空闲的空位（因为 protocol buffers 有更紧凑的表示方式，所以必须选择更小的数字）。除了这点不方便之外，它还使得删除字段成为问题：如果保留它们，从语意表达上不是很明显的表达出这个字段不能读写了，保留它们，还会生成访问器。如果删除它们，就会有出现严重 bug 的风险，因为当有人重用了这些 ID，会导致读取到旧的数据，这样数据会发生错乱。
- FlatBuffers 区分 table 和 struct。所有 table 字段都是可选的，并且所有 struct 字段都是必需的。
- FlatBuffers 具有原生数组类型而不是 repeated。这给你一个长度，而不必收集所有项目，并且在标量的情况下提供更紧凑的表示，并且确保相邻性。
- FlatBuffers 具有 union 类型，这个也是 protocol buffers 没有的。一个 union 可以替代很多个 optional 字段，这样也可以节约每个字段都要一一检查的时间。
- FlatBuffers 能够为所有标量定义默认值，而不必在每次访问时处理它们的 optional，并且默认值不存在 buffer 中，也不用担心空间的问题。
- 可以统一处理模式和数据定义（并且和 JSON 兼容）的解析器。protocol buffers 不兼容 JSON。FlatBuffers 的 flatc 编译器可带的参数也更加强大，具体可带参数列表见[此文档](https://google.github.io/flatbuffers/flatbuffers_guide_using_schema_compiler.html)
- schema 扩展了一些 protocol buffers 没有的 Attributes。

除去功能上的不同，再就是一些 schema 语法上的细微不同：

- 定义对象，protocol buffers 是 message，FlatBuffers 是 table
- ID，protocol buffers 默认是从 1 开始标号，FlatBuffers 默认从 0 开始。


关于 schema 所有的语法，可以参考[这个文档](https://google.github.io/flatbuffers/flatbuffers_grammar.html)


关于 flatbuffers 编解码性能相关的，原理分析和源码分析，将在下篇进行。

------------------------------------------------------

Reference：  

[flatbuffers 官方文档](https://google.github.io/flatbuffers/index.html)        
[Improving Facebook's performance on Android with FlatBuffers](https://code.facebook.com/posts/872547912839369/improving-facebook-s-performance-on-android-with-flatbuffers/)   

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/flatbuffers\_schema/](https://halfrost.com/flatbuffers_schema/)