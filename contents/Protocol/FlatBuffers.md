# 深入浅出 FlatBuffers

<p align='center'>
<img src='https://ob6mci30g.qnssl.com/Blog/ArticleImage/86_0.png'>
</p>

## 一. FlatBuffers 是什么？

FlatBuffers 是一个序列化开源库，实现了与 Protocol Buffers，Thrift，Apache Avro，SBE 和 Cap'n Proto 类似的序列化格式，主要由 Wouter van Oortmerssen 编写，并由 Google 开源。Oortmerssen 最初为 Android 游戏和注重性能的应用而开发了FlatBuffers。现在它具有C ++，C＃，C，Go，Java，PHP，Python 和 JavaScript 的端口。

FlatBuffers 的主要目标是避免反序列化。这是通过定义二进制数据协议来实现的，一种将定义好的将数据转换为二进制数据的方法。由该协议创建的二进制结构可以 wire 发送，并且无需进一步处理即可读取。相比较而言，在传输 JSON 时，我们需要将数据转换为字符串，通过 wire 发送，解析字符串，并将其转换为本地对象。Flatbuffers 不需要这些操作。你用二进制装入数据，发送相同的二进制文件，并直接从二进制文件读取。

除了解析效率以外，二进制格式还带来了另一个优势，数据的二进制表示通常更具有效率。我们可以使用 4 字节的 UInt 而不是 10 个字符来存储 10 位数字的整数。

尽管 FlatBuffers 有自己的接口定义语言来定义要与之序列化的数据，但它也支持Protocol Buffers 中的 `.proto`格式。


## 二. 为什么要发明 FlatBuffers ？


<p align='center'>
<img src='../images/flatbuffers.png'>
</p>

JSON 是一种独立于语言存在的数据格式，但是它解析数据并将之转换成如 Java 对象时，会消耗我们的时间和内存资源。客户端解析一个 20KB 的 JSON 流差不多需要 35ms，而 UI 一次刷新的时间是 16.6ms。在高实时游戏中，是不能有任何卡顿延迟的，所以需要一种新的数据格式；服务器在解析 JSON 时候，有时候会创建非常多的小对象，对于每秒要处理百万玩家的 JSON 数据，服务器压力会变大，如果每次解析 JSON 都会产生很多小对象，那么海量玩家带来的海量小对象，在内存回收的时候可能会造成 GC 相关的问题。Google 员工 Wouter van Oortmerssen 为了解决游戏中性能的问题，于是开发出了 FlatBuffers。(注：Protocol buffers 是 created by google，而 FlatBuffers 是 created at google)

几年前，Facebook 宣称自己的 Android app 在数据处理的性能方面有了极大的提升。在几乎整个 app 中，他们放弃了 JSON 而用 FlatBuffers 取而代之。

[FlatBuffers](https://github.com/google/flatbuffers)(9490 star) 和 [Cap'n Proto](https://github.com/capnproto/capnproto)(5527 star)、[simple-binary-encoding](https://github.com/real-logic/simple-binary-encoding)(1351 star) 一样，它支持“零拷贝”反序列化，在序列化过程中没有临时对象产生，没有额外的内存分配，访问序列化数据也不需要先将其复制到内存的单独部分，这使得以这些格式访问数据比需要格式的数据(如JSON，CSV 和 protobuf)快得多。

FlatBuffers 与 Protocol Buffers 确实比较相似，主要的区别在于 FlatBuffers 在访问数据之前不需要解析/解包。两者代码也是一个数量级的。但是 Protocol Buffers既没有可选的文本导入/导出功能，也没有 union 这个语言特性，这两点 FlatBuffers 都有。

FlatBuffers 专注于移动硬件（内存大小和内存带宽比桌面端硬件更受限制），以及具有最高性能需求的应用程序：游戏。

## 三. FlatBuffers 使用量

说了这么多，读者会疑问，FlatBuffers 使用的人多么？Google 官方页面上提了 3 个著名的 app 和 1 个框架在使用它。

BobbleApp，印度第一贴图 App。BobbleApp 中使用 FlatBuffers 后 App 的性能明显增强。

Facebook 使用 FlatBuffers 在 Android App 中进行客户端服务端的沟通。他们写了一篇文章[《Improving Facebook's performance on Android with FlatBuffers》](https://code.facebook.com/posts/872547912839369/improving-facebook-s-performance-on-android-with-flatbuffers/)来描述 FlatBuffers 是如何加速加载内容的。

Google 的 Fun Propulsion Labs 在他们所有的库和游戏中大量使用 FlatBuffers。

Cocos2d-X，第一开源移动游戏引擎，使用 FlatBuffers 来序列化所有的游戏数据。

由此可见，在游戏类的 app 中，广泛使用 FlatBuffers。


## 四. 定义 .fbs

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

只能在表定义的末尾添加新的字段。旧数据仍会正确读取，并在读取时为您提供默认值。旧代码将简单地忽略新字段。如果希望灵活地使用 schema 中字段的任何顺序，您可以手动分配 ids（很像 Protocol Buffers），请参阅下面的 id 属性。


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

修改原来的变量名以后，可能会出现问题。由于已经重命名了字段，这将破坏所有使用此版本 schema 的代码（和 JSON 文件），这与实际的二进制缓冲区不兼容。


## 五. FlatBuffers 命名规范



## 六. FlatBuffers 编码原理



## 七. FlatBuffers 的优缺点

FlatBuffers 优点：

- 1. 不需要解析/拆包就可以访问序列化数据  
访问序列化数据甚至层级数据都不需要解析。归功于此，我们不需要花费时间去初始化解析器（意味着构建复杂的字段映射）和解析数据。
- 2. 直接使用内存  
FlatBuffers 数据使用自己的内存缓冲区，不需要分配其他更多的内存。我们不需要像 JSON 那样在解析数据的时候，为整个层级数据分配额外的内存对象。**FlatBuffers 算是 zero-copy + Random-access reads 版本的 protobuf**。

FlatBuffers 提供的优点并不是无任何妥协。它的缺点也算是为了它的优点做的牺牲。

- 1. 无可读性    
flatBuffers 和 protocol buffers 组织数据的形式都使用的二进制数据形式，这就意味着调试程序难度会增加。(一定程度上也算是优点，有一定“安全性”)  
- 2. API 略繁琐    
由于二进制协议的构造方法，数据必须以“从内到外”的方式插入。构建 FlatBuffers 对象比较麻烦。
- 3. 向后兼容性    
在处理结构化二进制数据时，我们必须考虑对该结构进行更改的可能性。从我们的 schema 中添加或删除字段必须小心。读取旧版本对象时，错误的 schema 更改可能会导致出错了但是没有提示。
- 4. 缺少数据流的处理方式  
在处理大量数据时，如果想流式处理 flatBuffers 数组，可能会遇到一些问题。Flatbuffers 是向后写入的。这意味着我们数据的关键部分都会出现在文件末尾，使流式传输不可行。

## 八. 最后 


读完本篇 FlatBuffers 编码原理以后，读者应该能明白以下几点：



最后的最后，邻近文章结束，又发现了一个性能和特点和 Flatbuffers 类似的开源库

<p align='center'>
<img src='../images/infinity-times-faster.png'>
</p>

Cap'n Proto 是一个疯狂快速的数据交换格式并且也同样可用于 RPC 系统中。这里有一篇性能对比的文章，[《Cap'n Proto: Cap'n Proto, FlatBuffers, and SBE》](https://capnproto.org/news/2014-06-17-capnproto-flatbuffers-sbe.html)，感兴趣的同学可以当额外的阅读材料看看。



------------------------------------------------------

Reference：  

[flatbuffers 官方文档](https://google.github.io/flatbuffers/index.html)        
[Improving Facebook's performance on Android with FlatBuffers](https://code.facebook.com/posts/872547912839369/improving-facebook-s-performance-on-android-with-flatbuffers/)   
[ Cap'n Proto: Cap'n Proto, FlatBuffers, and SBE](https://capnproto.org/news/2014-06-17-capnproto-flatbuffers-sbe.html)

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/flatbuffers/](https://halfrost.com/flatbuffers/)