<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/132_0.png'>
</p>

# 详解 HTTP/2 头压缩算法 —— HPACK


## 一. 简介

在 HTTP/1.1（请参阅[[RFC7230]](https://tools.ietf.org/html/rfc7230)）中，header 字段未被压缩。随着网页内的请求数增长到需要数十到数百个请求的时候，这些请求中的冗余 header 字段不必要地消耗了带宽，从而显着增加了延迟。

SPDY [[SPDY]](https://tools.ietf.org/html/rfc7541#ref-SPDY) 最初通过使用 DEFLATE [[DEFLATE]](https://tools.ietf.org/html/rfc7541#ref-DEFLATE) 格式压缩 header 字段来解决此冗余问题，事实证明，这种格式非常有效地表示了冗余 header 字段。但是，这种方法暴露了安全风险，如 CRIME（轻松实现压缩率信息泄漏）攻击所证明的安全风险（请参阅 [[CRIME]](https://tools.ietf.org/html/rfc7541#ref-CRIME)）。

本规范定义了 HPACK，这是一种新的压缩器，它消除了多余的 header 字段，将漏洞限制为已知的安全攻击，并且在受限的环境中具有有限的内存需求。[第 7 节](https://tools.ietf.org/html/rfc7541#section-7)介绍了 HPACK 的潜在安全问题。

HPACK 格式特意被设计成简单且不灵活的形式。两种特性都降低了由于实现错误而引起的互操作性或安全性问题的风险。没有定义扩展机制；只能通过定义完整的替换来更改格式。

### 1. 总览

本规范中定义的格式将 header 字段列表视为 name-value 对的有序集合，其中可以包括重复的对。名称和值被认为是八位字节的不透明序列，并且 header 字段的顺序在压缩和解压缩后保持不变。

header 字段表将 header 字段映射到索引值，从而得到编码。这些 header 字段表可以在编码或解码新 header 字段时进行增量更新。


在编码形式中，header 字段以字面形式表示或作为对 header 字段表中的一个 header 字段的引用。因此，可以使用引用和文字值的混合来编码 header 字段的列表。

文字值可以直接编码，也可以使用静态霍夫曼编码。

编码器负责决定将哪些 header 字段作为新条目插入 header 字段表中。解码器执行对编码器指定的 header 字段表的修改，从而在此过程中重建 header 字段的列表。这使解码器保持简单并可以与多种编码器互操作。

[附录C](https://tools.ietf.org/html/rfc7541#appendix-C) 中提供了使用这些不同的机制表示 header 字段的示例。



### 2. 约定

本文档中的关键字 “必须”，“不得”，“必须”，“应”，“应禁止”，“应”，“不应”，“建议”，“可以”和“可选”是 RFC 2119 [[RFC2119]](https://tools.ietf.org/html/rfc2119) 中定义的。

所有数值均以网络字节顺序排列。 除非另有说明，否则值是无符号的。适当时以十进制或十六进制提供文字值。


### 3. 术语


本文使用以下术语：

Header Field：一个名称/值 name-value 对。名称和值都被视为八位字节的不透明序列。

Dynamic Table：动态表（请参阅[第 2.3.2 节](https://tools.ietf.org/html/rfc7541#section-2.3.2)）是将存储的 header 字段与索引值相关联的表。该表是动态的，并且特定于编码或解码上下文。

Static Table：静态表（请参阅[第 2.3.1 节](https://tools.ietf.org/html/rfc7541#section-2.3.1)）是将经常出现的 header 字段与索引值静态关联的表。该表是有序的，只读的，始终可访问的，并且可以在所有编码或解码上下文之间共享。

Header List：header 列表是 header 字段的有序集合，这些 header 字段经过联合编码，可以包含重复的 header 字段。HTTP/2 header 块中包含的 header 字段的完整列表是 header 列表。

Header Field Representation：header 字段可以编码形式表示为文字或索引（请参见[第 2.4 节](https://tools.ietf.org/html/rfc7541#section-2.4)）。

Header Block：header 字段表示形式的有序列表，解码后会产生完整的 header 列表。



## 二. 压缩过程概述

本规范未描述编码器的具体算法。相反，它精确定义了解码器的预期工作方式，从而允许编码器产生此定义允许的任何编码。

### 1. Header List Ordering

HPACK 保留 header 列表内 header 字段的顺序。编码器必须根据其在原始 header 列表中的顺序对 header 块中的 header 字段表示进行排序。解码器必须根据其在 header 块中的顺序对已解码 header 列表中的 header 字段进行排序。

### 2. Encoding and Decoding Contexts

为了解压缩 header 块，解码器只需要维护一个动态表（参见[第 2.3.2 节](https://tools.ietf.org/html/rfc7541#section-2.3.2)）作为解码上下文。不需要其他动态状态。

当用于双向通信时（例如在 HTT P中），由端点维护的编码和解码动态表是完全独立的，即请求和响应动态表是分开的。

### 3. Indexing Tables

HPACK 使用两个表将 header 字段与索引相关联。静态表（请参阅[第 2.3.1 节](https://tools.ietf.org/html/rfc7541#section-2.3.1)）是预定义的，并包含公共 header 字段（其中大多数带有空值）。动态表（请参阅[第 2.3.2 节](https://tools.ietf.org/html/rfc7541#section-2.3.2)）是动态的，编码器可以使用它来索引已编码 header 列表中重复的 header 字段。

这两个表被合并到一个用于定义索引值的地址空间中（请参阅[第 2.3.3 节](https://tools.ietf.org/html/rfc7541#section-2.3.3)）。

### (1) 静态表

静态表由 header 字段的预定义静态列表组成。其条目在[附录 A](https://tools.ietf.org/html/rfc7541#appendix-A) 中定义。


### (2) 动态表


动态表包含以先进先出顺序维护的 header 字段列表。动态表中的第一个条目和最新条目在最低索引处，而动态表的最旧条目在最高索引处。


动态表最初是空的。当每个 header 块被解压缩时，将添加条目。动态表可以包含重复的条目（即，具有相同名称和相同值的条目）。因此，解码器不得将重复的条目视为错误。

编码器决定如何更新动态表，因此可以控制动态表使用多少内存。为了限制解码器的存储需求，动态表的大小受到严格限制（请参见[第 4.2 节](https://tools.ietf.org/html/rfc7541#section-4.2)）。

解码器在处理 header 字段表示列表时更新动态表（请参见[第 3.2 节](https://tools.ietf.org/html/rfc7541#section-3.2)）。




### (3) 索引地址空间


静态表和动态表被组合到单个索引地址空间中。

在 1 和静态表的长度（包括在内）之间的索引是指静态表中的元素（请参阅[第 2.3.1 节](https://tools.ietf.org/html/rfc7541#section-2.3.1)）。

严格大于静态表长度的索引是指动态表中的元素（请参见[第 2.3.2 节](https://tools.ietf.org/html/rfc7541#section-2.3.2)）。 减去静态表的长度即可找到动态表的索引。

严格大于两个表的长度之和的索引必须视为解码错误。

对于 s 的静态表大小和 k 的动态表大小，下图显示了整个有效索引地址空间

```c
<----------  Index Address Space ---------->
<-- Static  Table -->  <-- Dynamic Table -->
+---+-----------+---+  +---+-----------+---+
| 1 |    ...    | s |  |s+1|    ...    |s+k|
+---+-----------+---+  +---+-----------+---+
                       ^                   |
                       |                   V
                Insertion Point      Dropping Point
```



### 4. Header Field Representation

编码的 header 字段可以表示为索引或文字。

有索引的表示形式定义了一个 header 字段，作为对静态表或动态表中条目的引用（请参见[第 6.1 节](https://tools.ietf.org/html/rfc7541#section-6.1)）；文字表示形式通过指定其 name 和 value 来定义 header 字段。header 字段 name 可以用字面形式表示，也可以作为对静态表或动态表中条目的引用。header 字段 value 按字面表示。定义了三种不同的文字表示形式：

- 在动态表的开头添加 header 字段作为新条目的文字表示形式（请参见[第 6.2.1 节](https://tools.ietf.org/html/rfc7541#section-6.2.1)）。

- 不将 header 字段添加到动态表的文字表示形式（请参见[第 6.2.2 节](https://tools.ietf.org/html/rfc7541#section-6.2.2)）。

- 不将 header 字段添加到动态表的文字表示形式，另外规定该 header 字段始终使用文字表示形式，尤其是在由中介程序重新编码时（请参阅[第 6.2.3 节](https://tools.ietf.org/html/rfc7541#section-6.2.3)）。此表示旨在保护 header 字段值，这些 header 字段值通过压缩以后就不会受到威胁（有关更多详细信息，请参见[第 7.1.3 节](https://tools.ietf.org/html/rfc7541#section-7.1.3)）。

为了保护敏感的 header 字段值（请参阅[第 7.1 节](https://tools.ietf.org/html/rfc7541#section-7.1)），可以从安全考虑出发选择这些文字表示形式之一。

header 字段 name 或 header 字段 value 的文字表示可以直接或使用静态霍夫曼代码对八位字节序列进行编码（请参见[第 5.2 节](https://tools.ietf.org/html/rfc7541#section-5.2)）



## 三. header 块的解码

### 1. Header Block Processing

解码器顺序处理 header 块以重建原始 header 列表。

header 块是 header 字段表示形式的串联。[第 6 节](https://tools.ietf.org/html/rfc7541#section-6)中介绍了不同的可能的 header 字段表示形式。

一旦 header 字段被解码并添加到重建的 header 列表中，就不能删除 header 字段。添加到 header 列表的 header 字段可以安全地传递到应用程序。

通过将结果 header 字段传递给应用程序，除了动态表所需的内存外，还需要使用最少的临时内存来实现解码器。


### 2. Header Field Representation Processing

在本节中定义了对 header 块进行处理以获得 header 列表的过程。为了确保解码将成功产生 header 列表，解码器必须遵守以下规则。

header 块中包含的所有 header 字段表示形式将按照它们出现的顺序进行处理，如下所示。有关各种 header 字段表示形式的格式的详细信息以及一些其他处理指令，请参见[第 6 节](https://tools.ietf.org/html/rfc7541#section-6)。

\_indexed 表示形式\_需要执行以下操作：

- 与静态表或动态表中被引用条目相对应的 header 字段被附加到解码后的 header 列表中。

动态表中未添加的“文字表示形式”需要执行以下操作：

 header 字段被附加到解码的 header 列表中。

在动态表中添加了“文字表示形式”需要执行以下操作：

 header 字段被附加到解码的 header 列表中。

 header 字段插入在动态表的开头。这种插入可能导致驱逐动态表中的先前条目（请参见第4.4节）。



------------------------------------------------------

Reference：
  
[RFC 7541](https://tools.ietf.org/html/rfc7541)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTP/2\_RFC7540/](https://halfrost.com/HTTP/2_RFC7540/)