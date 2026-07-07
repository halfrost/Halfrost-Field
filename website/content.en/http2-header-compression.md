+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTP", "HTTP/2"]
date = 2019-06-16T07:31:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/132_0.png"
slug = "http2-header-compression"
tags = ["Protocol", "HTTP", "HTTP/2"]
title = "A Deep Dive into the HTTP/2 Header Compression Algorithm — HPACK"

+++


## I. Introduction

In HTTP/1.1 (see [[RFC7230]](https://tools.ietf.org/html/rfc7230)), header fields are not compressed. As the number of requests within a web page grows to dozens or hundreds, the redundant header fields in those requests unnecessarily consume bandwidth, significantly increasing latency.

SPDY [[SPDY]](https://tools.ietf.org/html/rfc7541#ref-SPDY) initially addressed this redundancy by compressing header fields using the DEFLATE [[DEFLATE]](https://tools.ietf.org/html/rfc7541#ref-DEFLATE) format, which proved to be highly effective at representing redundant header fields. However, this approach exposed security risks, as demonstrated by the CRIME (Compression Ratio Info-leak Made Easy) attack (see [[CRIME]](https://tools.ietf.org/html/rfc7541#ref-CRIME)).

This specification defines HPACK, a new compression method that eliminates redundant header fields, limits vulnerabilities to known security attacks, and has bounded memory requirements in constrained environments. [Section 7](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E6%8E%A2%E6%B5%8B%E5%8A%A8%E6%80%81%E8%A1%A8%E7%8A%B6%E6%80%81) discusses potential security issues with HPACK.

The HPACK format is deliberately designed to be simple and inflexible. Both properties reduce the risk of interoperability or security issues caused by implementation errors. No extension mechanism is defined; the format can only be changed by defining a complete replacement.


### 1. Overview

![](https://img.halfrost.com/Blog/ArticleImage/132_1.png)

The format defined in this specification treats a list of header fields as an ordered collection of name-value pairs, which can include duplicate pairs. Names and values are considered opaque sequences of octets, and the order of header fields is preserved after compression and decompression.

Header field tables map header fields to index values, producing the encoding. These header field tables can be updated incrementally as new header fields are encoded or decoded.


In the encoded form, header fields are represented either literally or as references to a header field in a header field table. Therefore, a list of header fields can be encoded using a mixture of references and literal values.

Literal values can be encoded directly or by using a static Huffman code (with a maximum compression ratio of 8:5).

The encoder is responsible for deciding which header fields to insert into the header field table as new entries. The decoder applies the modifications to the header field table specified by the encoder, reconstructing the list of header fields in the process. This keeps the decoder simple and interoperable with a variety of encoders.

[Appendix C](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_HPACK-Example.md#1-%E6%95%B4%E6%95%B0%E8%A1%A8%E7%A4%BA%E7%9A%84%E7%A4%BA%E4%BE%8B) provides examples of representing header fields using these different mechanisms.


>Note: In HTTP/2, the definitions of request and response header fields remain unchanged, with only minor differences: all header field names are lowercase, and the request line is now split into the :method, :scheme, :authority, and :path pseudo-header fields.
>

### 2. Conventions

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119 [[RFC2119]](https://tools.ietf.org/html/rfc2119).

All numeric values are represented in network byte order. Unless otherwise specified, values are unsigned. Literal values are provided in decimal or hexadecimal as appropriate.


### 3. Terminology


This document uses the following terms:

Header Field: A name/value name-value pair. Both the name and the value are treated as opaque sequences of octets.

Dynamic Table: The dynamic table (see [Section 2.3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-%E5%8A%A8%E6%80%81%E8%A1%A8)) is a table that associates stored header fields with index values. The table is dynamic and is specific to an encoding or decoding context.

Static Table: The static table (see [Section 2.3.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E9%9D%99%E6%80%81%E8%A1%A8)) is a table that statically associates frequently occurring header fields with index values. The table is ordered, read-only, always accessible, and can be shared across all encoding or decoding contexts.

Header List: A header list is an ordered collection of header fields that are encoded together and can contain duplicate header fields. The complete list of header fields contained in an HTTP/2 header block is the header list.

Header Field Representation: A header field can be represented in encoded form as either a literal or an index (see [Section 2.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#4-header-field-representation)).

Header Block: An ordered list of header field representations that, when decoded, yields the complete header list.


## II. Compression Process Overview

This specification does not describe a specific encoder algorithm. Instead, it precisely defines how a decoder is expected to operate, thereby allowing an encoder to produce any encoding permitted by this definition.

### 1. Header List Ordering

HPACK preserves the order of header fields within a header list. An encoder MUST order the header field representations in a header block according to their order in the original header list. A decoder MUST order the header fields in the decoded header list according to their order in the header block.

### 2. Encoding and Decoding Contexts

To decompress a header block, a decoder only needs to maintain a dynamic table (see [Section 2.3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-%E5%8A%A8%E6%80%81%E8%A1%A8)) as the decoding context. No other dynamic state is required.

When used for bidirectional communication (for example, in HTTP), the encoding and decoding dynamic tables maintained by an endpoint are completely independent; that is, the request and response dynamic tables are separate.

### 3. Indexing Tables

HPACK uses two tables to associate header fields with indexes. The static table (see [Section 2.3.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E9%9D%99%E6%80%81%E8%A1%A8)) is predefined and contains common header fields, most of which have empty values. The dynamic table (see [Section 2.3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-%E5%8A%A8%E6%80%81%E8%A1%A8)) is dynamic, and the encoder can use it to index repeated header fields in encoded header lists.

These two tables are combined into a single address space used to define index values (see [Section 2.3.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E7%B4%A2%E5%BC%95%E5%9C%B0%E5%9D%80%E7%A9%BA%E9%97%B4)).

### (1) Static Table

The static table consists of a predefined static list of header fields. Its entries are defined in [Appendix A](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_HPACK-Example.md#%E4%B8%80-%E9%9D%99%E6%80%81%E8%A1%A8%E5%AE%9A%E4%B9%89).


### (2) Dynamic Table


The dynamic table contains a list of header fields maintained in **first-in, first-out** order. The first and newest entry in the dynamic table is at the lowest index, while the oldest entry in the dynamic table is at the highest index.


The dynamic table is initially empty. Entries are added as each header block is decompressed. The dynamic table can contain duplicate entries (that is, entries with the same name and the same value). Therefore, a decoder MUST NOT treat duplicate entries as an error.

The encoder decides how to update the dynamic table, and therefore can control how much memory the dynamic table uses. To limit the decoder's storage requirements, the size of the dynamic table is strictly bounded (see [Section 4.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-maximum-table-size)).

The decoder updates the dynamic table while processing the list of header field representations (see [Section 3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-header-field-representation-processing)).


### (3) Index Address Space


The static table and the dynamic table are combined into a single index address space.

Indexes between 1 and the length of the static table, inclusive, refer to elements in the static table (see [Section 2.3.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E9%9D%99%E6%80%81%E8%A1%A8)).

Indexes strictly greater than the length of the static table refer to elements in the dynamic table (see [Section 2.3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-%E5%8A%A8%E6%80%81%E8%A1%A8)). Subtract the length of the static table to obtain the dynamic table index.
An index strictly greater than the sum of the lengths of the two tables MUST be treated as a decoding error.

For a static table of size s and a dynamic table of size k, the figure below shows the entire valid index address space.


![](https://img.halfrost.com/Blog/ArticleImage/132_3_.png)


### 4. Header Field Representation

An encoded header field can be represented either as an index or as a literal.

An indexed representation defines a header field as a reference to an entry in the static table or the dynamic table (see [Section 6.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E7%B4%A2%E5%BC%95-header-%E5%AD%97%E6%AE%B5%E8%A1%A8%E7%A4%BA)); a literal representation defines a header field by specifying its name and value. The header field name can be represented either as a literal or as a reference to an entry in the static table or the dynamic table. The header field value is represented literally. Three different literal representations are defined:

- A literal representation that adds the header field as a new entry at the beginning of the dynamic table (see [Section 6.2.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E5%B8%A6%E5%A2%9E%E9%87%8F%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)).

- A literal representation that does not add the header field to the dynamic table (see [Section 6.2.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-%E4%B8%8D%E5%B8%A6%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)).

- A literal representation that does not add the header field to the dynamic table, and additionally specifies that the header field is always represented as a literal, especially when re-encoded by an intermediary (see [Section 6.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E4%BB%8E%E4%B8%8D%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)). This representation is intended to protect header field values that would otherwise be put at risk by compression (for more details, see [Section 7.1.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E6%B0%B8%E4%B8%8D%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2)).

To protect sensitive header field values (see [Section 7.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E6%8E%A2%E6%B5%8B%E5%8A%A8%E6%80%81%E8%A1%A8%E7%8A%B6%E6%80%81)), one of these literal representations can be selected for security reasons.

The literal representation of a header field name or header field value can encode the sequence of octets directly or by using the static Huffman code (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation))


## III. Decoding Header Blocks

### 1. Header Block Processing

The decoder processes a header block sequentially to reconstruct the original header list.

A header block is the concatenation of header field representations. [Section 6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E7%B4%A2%E5%BC%95-header-%E5%AD%97%E6%AE%B5%E8%A1%A8%E7%A4%BA) describes the different possible header field representations.

Once a header field has been decoded and added to the reconstructed header list, it cannot be removed. A header field added to the header list can be safely passed to the application.

By passing the resulting header fields to the application, a decoder can be implemented with minimal transient memory in addition to the memory required for the dynamic table.


### 2. Header Field Representation Processing

This section defines the procedure for processing a header block to obtain a header list. To ensure that decoding successfully produces a header list, the decoder MUST follow the rules below.

All header field representations contained in a header block are processed in the order in which they appear, as follows. For details on the formats of the various header field representations and some additional processing instructions, see [Section 6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E7%B4%A2%E5%BC%95-header-%E5%AD%97%E6%AE%B5%E8%A1%A8%E7%A4%BA).

The \_indexed representation\_ requires the following action:

- The header field corresponding to the referenced entry in the static table or dynamic table is appended to the decoded header list.

A “\_literal representation\_” that is not added to the dynamic table requires the following action:

- The header field is appended to the decoded header list.

A “\_literal representation\_” that is added to the dynamic table requires the following actions:

- The header field is appended to the decoded header list.
- The header field is inserted at the beginning of the dynamic table. This insertion can cause previous entries in the dynamic table to be evicted (see [Section 4.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#4-entry-eviction-when-adding-new-entries)).

## IV. Dynamic Table Management

![](https://img.halfrost.com/Blog/ArticleImage/132_2.png)

To limit storage requirements on the decoder side, the size of the dynamic table is constrained.

> The dynamic dictionary is context-dependent; a separate dictionary needs to be maintained for each HTTP/2 connection.

### 1. Calculating Table Size

The size of the dynamic table is the sum of the sizes of its entries. The size of an entry is the sum of the length of its name (in octets) (as defined in [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)), the length of its value (in octets), and 32. The size of an entry is calculated using the lengths of its name and value, without applying any Huffman encoding.

>Note: The additional 32 octets account for the estimated overhead associated with an entry. For example, an entry structure that uses two 64-bit pointers to reference the entry’s name and value and two 64-bit integers to count references to that name and value would have an overhead of 32 octets. (64\*2\*2/8=32 bytes)


### 2. Maximum Table Size 

The protocol using HPACK determines the maximum size that the encoder is allowed to use for the dynamic table. In HTTP/2, this value is determined by the SETTINGS\_HEADER\_TABLE\_SIZE setting (see [Section 6.5.2 of [HTTP2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)).

The encoder can choose to use a capacity smaller than this maximum size (see [Section 6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E5%8A%A8%E6%80%81%E8%A1%A8%E5%A4%A7%E5%B0%8F%E6%9B%B4%E6%96%B0)), but the selected size MUST remain less than or equal to the protocol-defined maximum capacity.

Changes to the maximum size of the dynamic table are caused by updates to the dynamic table size (see [Section 6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E5%8A%A8%E6%80%81%E8%A1%A8%E5%A4%A7%E5%B0%8F%E6%9B%B4%E6%96%B0)). A dynamic table size update MUST occur at the beginning of the first header block after the dynamic table size is changed. In HTTP/2, this follows acknowledgment of the settings (see [Section 6.5.3 of [HTTP2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#3-settings-synchronization)).

Multiple updates to the maximum table size can occur between the transmission of two header blocks. If this size changes more than once during that interval, the smallest maximum table size that occurred during the interval MUST be signaled in a dynamic table size update. The final maximum size is always signaled as well, resulting in at most two dynamic table size updates. This ensures that the decoder can perform evictions based on reductions in the dynamic table size (see [Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-entry-eviction-when-dynamic-table-size-changes)).
Use this mechanism to completely clear entries from the dynamic table by setting the maximum size to 0; it can then be restored.

> HTTP/2 advocates using as few connections as possible, and header compression is one important reason: the more requests and responses are produced on the same connection, the more complete the accumulated dynamic dictionary becomes, and the better the header compression effect.

### 3. Entry Eviction When Dynamic Table Size Changes

Whenever the maximum size of the dynamic table is reduced, entries are evicted from the end of the dynamic table until the size of the dynamic table is less than or equal to the maximum size.


### 4. Entry Eviction When Adding New Entries 

Before adding a new entry to the dynamic table, entries are evicted from the end of the dynamic table until the size of the dynamic table is less than or equal to (maximum size - new entry size), or until the table is empty.

If the size of the new entry is less than or equal to the maximum size, the entry is added to the table. Attempting to add an entry larger than the maximum size is not an error; attempting to add an entry larger than the maximum size causes the table to be emptied of all existing entries and leaves the table empty.

A new entry can reference the name of an entry A in the dynamic table, and when this new entry is added to the dynamic table, entry A will be evicted. Note that if the referenced entry is removed from the dynamic table before the new entry is inserted, deleting the referenced name should be avoided.


## V. Representation of Primitive Types

HPACK encoding uses two primitive types: unsigned variable-length integers and octet strings.


### 1. Integer Representation

Integers are used to represent name indexes, header field indexes, or string lengths. An integer representation can start at any position within an octet. To optimize processing, an integer representation always ends at the end of an octet.

An integer consists of two parts: a prefix that fills the current octet, and an optional list of octets used if the integer value does not fit in the prefix. The number of bits in the prefix (called N) is a parameter of the integer representation.

If the integer value is small enough, that is, strictly less than 2^N-1, it is encoded in the N-bit prefix.

![](https://img.halfrost.com/Blog/ArticleImage/132_4.png)

In the example above, N = 5, so the largest integer that can be represented is 2^5-1 = 31


If the integer value is greater than 2^N-1, all bits of the prefix are set to 1, and the value reduced by 2^N-1 is encoded using a list of one or more octets. The most significant bit of each octet is used as a continuation flag: its value is set to 1 for every octet in the list except the last one. The remaining bits of the octets are used to encode the reduced value.


![](https://img.halfrost.com/Blog/ArticleImage/132_5_.png)


Decoding the integer value from the list of octets starts by reversing the order of the octets in the list. Then, for each octet, its most significant bit is removed. The remaining bits of the octets are concatenated, and the resulting value is increased by 2^N-1 to obtain the integer value.

The prefix size N is always between 1 and 8 bits. An integer that starts on an octet boundary has an 8-bit prefix.

The pseudocode for representing an integer I is as follows:
```c
   if I < 2^N - 1, encode I on N bits
   else
       encode (2^N - 1) on N bits
       I = I - (2^N - 1)
       while I >= 128
            encode (I % 128 + 128) on 8 bits
            I = I / 128
       encode I on 8 bits
```
The pseudocode for decoding integer I is as follows:
```c
   decode I from the next N bits
   if I < 2^N - 1, return I
   else
       M = 0
       repeat
           B = next octet
           I = I + (B & 127) * 2^M
           M = M + 7
       while B & 128 == 128
       return I
```
[Appendix C.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_HPACK-Example.md#1-%E6%95%B4%E6%95%B0%E8%A1%A8%E7%A4%BA%E7%9A%84%E7%A4%BA%E4%BE%8B) provides examples illustrating integer encoding.


The integer representation allows values of indeterminate size. An encoder could also send a large number of zero values, which may waste octets and may cause the integer value to overflow. Integer encodings that exceed implementation limits (in value or octet length) must be treated as decoding errors. Based on implementation constraints, different limits can be set for each different use of integers.


### 2. String Literal Representation

A header field name and a header field value can be represented as string literals. A string literal can be encoded as a sequence of octets either by directly encoding the octets of the string literal or by using a Huffman code (see [[HUFFMAN]](https://tools.ietf.org/html/rfc7541#ref-HUFFMAN)).


![](https://img.halfrost.com/Blog/ArticleImage/132_6.png)


A string literal representation contains the following fields:

- H:  
  A one-bit flag H indicating whether the octets of the string are Huffman encoded.

- String Length:  
  The number of octets used to encode the string literal, encoded as an integer with a 7-bit prefix (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)).

- String Data:
  The encoded data of the string literal. If H is '0', the encoded data is the raw octets of the string literal. If H is '1', the encoded data is the Huffman encoding of the string literal.

String literals that use Huffman encoding are encoded with the Huffman code defined in [Appendix B](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_HPACK-Example.md#%E4%BA%8C-%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81) (for examples, see the examples in [Appendix C.4](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_HPACK-Example.md#4-%E6%9C%89%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81%E8%AF%B7%E6%B1%82%E7%9A%84%E7%A4%BA%E4%BE%8B) and the response examples in [Appendix C.6](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_HPACK-Example.md#6-%E6%9C%89%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81%E5%93%8D%E5%BA%94%E7%9A%84%E7%A4%BA%E4%BE%8B)). The encoded data is the bitwise concatenation of the codes corresponding to each octet of the string literal.

Because Huffman-encoded data does not always end on an octet boundary, padding is inserted after it up to the next octet boundary. To avoid having this padding misinterpreted as part of the string literal, the most significant bits of the code corresponding to the EOS (end-of-string) symbol are used.

During decoding, an incomplete code at the end of the encoded data is treated as padding and discarded. Padding strictly longer than 7 bits must be treated as a decoding error. Padding that does not correspond to the most significant bits of the code for the EOS symbol must be treated as a decoding error. A Huffman-encoded string literal containing the EOS symbol must be treated as a decoding error.


## VI. Binary Format

This section describes the detailed format of each different header field representation, as well as the dynamic table size update instruction.

### 1. Indexed Header Field Representation


An indexed header field representation identifies an entry in the static table or the dynamic table (see [Section 2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-indexing-tables)).

An indexed header field representation adds the header field to the decoded header list, as described in [Section 3.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-header-field-representation-processing).


![](https://img.halfrost.com/Blog/ArticleImage/132_7_.png)

**The case above corresponds to both Name and Value being present in the index table (including the static table and the dynamic table).**

An indexed header field starts with the 1-bit pattern “1”, followed by the index of the matching header field, represented as an integer with a 7-bit prefix (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)).

The index value 0 is not used. If the index value 0 is found in an indexed header field representation, it must be treated as a decoding error.


### 2. Literal Header Field Representation

A header field representation contains a literal header field value. The header field name is provided either literally or by reference to an existing table entry in the static table or dynamic table (see [Section 2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-indexing-tables)).

This specification defines three forms of literal header field representation: with indexing, without indexing, and never indexed.


### (1). Literal Header Field with Incremental Indexing


A literal header field representation with incremental indexing appends the header field to the decoded header list and inserts it into the dynamic table as a new entry.


![](https://img.halfrost.com/Blog/ArticleImage/132_9.png)

**The case above corresponds to Name being present in the index table (including the static table and the dynamic table), while Value needs to be encoded and transmitted, and the field is also added to the dynamic table.**

![](https://img.halfrost.com/Blog/ArticleImage/132_10.png)

**The case above corresponds to both Name and Value needing to be encoded and transmitted, and the field is also added to the dynamic table.**

A literal header field representation with incremental indexing starts with the 2-bit pattern “01”.

If the header field name matches the header field name of an entry stored in the static table or dynamic table, the index of that entry can be used to represent the header field name. In this case, the entry's index is represented as an integer with a 6-bit prefix (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)). This value is generally non-zero.

Otherwise, the header field name is represented as a string literal (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)). The value 0 is used in place of the 6-bit index, followed by the header field name.

Both forms of header field name representation are followed by the header field value represented as a string literal (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)).


### (2). Literal Header Field without Indexing


A literal header field representation without indexing causes the header field to be appended to the decoded header list without changing the dynamic table.


![](https://img.halfrost.com/Blog/ArticleImage/132_11.png)

**The case above corresponds to Name being present in the index table (including the static table and the dynamic table), while Value needs to be encoded and transmitted, and the field is not added to the dynamic table.**

![](https://img.halfrost.com/Blog/ArticleImage/132_12.png)

**The case above corresponds to Name and Value needing to be encoded and transmitted, and the field is not added to the dynamic table.**

A literal header field representation without indexing starts with the 4-bit pattern “0000”.

If the header field name matches the header field name of an entry stored in the static table or dynamic table, the index of that entry can be used to represent the header field name. In this case, the entry's index is represented as an integer with a 4-bit prefix (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)). This value is generally non-zero.

Otherwise, the header field name is represented as a string literal (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)). The value 0 is used in place of the 4-bit index, followed by the header field name.

Both forms of header field name representation are followed by the header field value represented as a string literal (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)).

### (3). Never-Indexed Literal Header Fields

The never-indexed literal header field representation causes a header field to be appended to the decoded header list without modifying the dynamic table. Intermediaries must use the same representation to encode that header field.

![](https://img.halfrost.com/Blog/ArticleImage/132_13.png)

**The case above corresponds to the Name being in the index table (including the static table and the dynamic table), while the Value needs to be encoded and transmitted and is never added to the dynamic table**.


![](https://img.halfrost.com/Blog/ArticleImage/132_14.png)

**The case above corresponds to both the Name and Value needing to be encoded and transmitted, and neither is ever added to the dynamic table**.

The never-indexed literal header field representation begins with the 4-bit pattern “0001”.

When a header field is represented as a never-indexed literal header field, this specific literal representation must be used for encoding. In particular, when a peer sends a received header field, and the received header field was represented as a never-indexed literal header field, it must forward that header field using the same representation.

This representation is intended to protect header field values by ensuring they are not put at risk through compression (for more details, see [Section 7.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-%E6%8E%A2%E6%B5%8B%E5%8A%A8%E6%80%81%E8%A1%A8%E7%8A%B6%E6%80%81)).

The encoding of this representation is the same as that of a literal header field without indexing (see [Section 6.2.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-%E4%B8%8D%E5%B8%A6%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)).

### 3. Dynamic Table Size Update

A dynamic table size update represents a change to the dynamic table size.

![](https://img.halfrost.com/Blog/ArticleImage/132_8.png)

A dynamic table size update starts with the 3-bit pattern “001”, followed by the new maximum size represented as an integer with a 5-bit prefix (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)).

The new maximum size must be less than or equal to the limit determined by the protocol using HPACK. A value exceeding this limit must be treated as a decoding error. In HTTP/2, this limit is the last value of the SETTINGS\_HEADER\_TABLE\_SIZE parameter (see [Section 6.5.2 of [HTTP2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)) received from the decoder and acknowledged by the encoder (see [Section 6.5.3 of [HTTP2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#3-settings-synchronization)).

Reducing the maximum size of the dynamic table causes entries to be evicted (FIFO) (see [Section 4.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-entry-eviction-when-dynamic-table-size-changes)).

>
>There are two ways to update the dynamic table size as described above: one is to modify it directly in a HEADERS frame (starting with the 3-bit pattern “001”), and the other is through SETTINGS\_HEADER\_TABLE\_SIZE in a SETTINGS frame.
>

## Seven. Security Considerations

This section describes potential security risks in HPACK:

- Using compression as a length-based predictor to validate guesses about encrypted data compressed into a shared compression context.

- Denial of service caused by exhausting the decoder’s processing or storage capacity.


### 1. Probing Dynamic Table State

HPACK reduces the length of header field encodings by exploiting redundancy inherent in protocols such as HTTP. The ultimate goal is to reduce the amount of data required to send an HTTP request or response.

An attacker can probe the compression context used to encode header fields. The attacker can also define header fields to be encoded and transmitted, and observe the lengths of those fields after encoding. When an attacker can perform both operations, they can adaptively modify requests to confirm guesses about the state of the dynamic table. If a guess compresses to a shorter length, the attacker can observe the encoded length and infer that the guess was correct.

This kind of attack is possible even with the Transport Layer Security (TLS) protocol (see [[TLS12]](https://tools.ietf.org/html/rfc7541#ref-TLS12)), because TLS provides encryption protection for the contents, but only limited protection for content length.

>Note: Padding schemes can provide only limited protection against attackers with these capabilities. Their effect on the attacker may be limited to forcing them to increase the number of guesses needed to infer the length associated with a given guess. Padding schemes can also resist compression directly by increasing the number of transmitted bits.


Attacks such as CRIME [[CRIME]](https://tools.ietf.org/html/rfc7541#ref-CRIME) demonstrate the existence of such attackers. That particular attack exploits the fact that DEFLATE [[DEFLATE]](https://tools.ietf.org/html/rfc7541#ref-DEFLATE) removes redundancy based on prefix matching. This enables an attacker to determine one character at a time, reducing an exponential-time attack to a linear-time attack.


### (1). Applicability to HPACK and HTTP

HPACK mitigates, but does not completely prevent, attacks modeled on CRIME [[CRIME]](https://tools.ietf.org/html/rfc7541#ref-CRIME) by requiring guesses to match an entire header field value rather than a single character. The attacker can only learn whether a guess is correct, so the attack can be reduced to brute-force guessing of the header field value. Therefore, the feasibility of recovering a specific header field value depends on the entropy of the value. As a result, values with high entropy are unlikely to be recovered successfully. However, low-entropy values remain vulnerable.

Attacks of this nature can occur whenever two mutually untrusted entities receive and send requests or responses over a single HTTP/2 connection. If a shared HPACK compressor allows one entity to add entries to the dynamic table while another entity can access those entries, the state of the table can be learned.

Requests or responses from mutually untrusted entities arise when an intermediary does the following:

- Sends requests from multiple clients on a single connection to an origin server.

- Obtains responses from multiple origin servers and sends those responses over a shared connection with a client.

Web browsers also need to assume that requests issued by different web origins [[ORIGIN]](https://tools.ietf.org/html/rfc7541#ref-ORIGIN) over the same connection are issued by mutually untrusted entities.


### (2). Mitigation


HTTP users that require confidentiality for header fields can use values with enough entropy to make guessing infeasible. However, this is impractical as a general solution because it forces all users of HTTP to take measures to mitigate the attack. It would impose new constraints on how HTTP is used.


Rather than imposing constraints on HTTP users, HPACK implementations can constrain how compression is applied in order to limit the potential for dynamic table probing.

The ideal solution is to isolate access to the dynamic table based on the entity constructing the header fields. Header field values added to the table are attributed to one entity, and only the entity that created a particular value can extract that value.

To improve the compression performance of this option, some entries can be marked as public. For example, a web browser might make the value of the Accept-Encoding header field available across all requests.

Encoders with less knowledge of the provenance of header fields might introduce a penalty mechanism for header fields with many different values. If an attacker makes a large number of attempts to guess a header field value and triggers the penalty mechanism, the header field will no longer be compared against dynamic table entries in future messages. This effectively prevents further guessing.

>Note: If an attacker has a reliable way to reinstall a value, simply removing the entry corresponding to the header field from the dynamic table may not be an effective defense. For example, requests to load images in a web browser typically include the Cookie header field (a potentially high-value target for this type of attack), and a website can easily force an image to be loaded, thereby refreshing the entry in the dynamic table.

The response may be inversely proportional to the length of the header field value. Shorter values may be marked as no longer using the dynamic table at a faster rate or with a higher probability than longer values.


### (3). Never-Indexed Literals

Implementers can also choose not to compress sensitive header fields, instead encoding their values as literals to protect them.

Refusing to generate indexed representations of header fields is effective only if compression is avoided on all hops. A never-indexed literal (see [Section 6.2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E4%BB%8E%E4%B8%8D%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)) can be used to signal to intermediaries that a particular value is intentionally being sent as a literal.

An intermediary must not re-encode a value represented using the never-indexed literal representation into another representation that would index it. If re-encoding with HPACK, it must use the never-indexed literal representation.

The choice to use the never-indexed literal representation for a header field depends on multiple factors. Because HPACK cannot prevent guessing of an entire header field value, attackers can more easily recover short or low-entropy values. Therefore, an encoder may choose not to index values with low entropy.

An encoder may also choose not to add indexes for the values of header fields considered highly valuable or sensitive to recovery, such as Cookie or Authorization header fields.

Conversely, if a value is public, the encoder may prefer to index header fields whose values are small or have little value. For example, the User-Agent header field usually does not change between requests and is sent to any server. In this case, confirming that a particular User-Agent value was used provides little value.

Note that as new attacks continue to be discovered, the criteria for deciding to use the never-indexed literal representation will evolve over time.


### 2. Static Huffman Encoding

There are currently no attacks against static Huffman encoding. One study suggests that using a static Huffman coding table can cause information leakage; however, the same study concludes that attackers cannot exploit this leakage to recover any meaningful amount of information (see [[PETAL]](https://tools.ietf.org/html/rfc7541#ref-PETAL)).
> Dynamic Huffman coding is vulnerable to attacks!


### 3. Memory Management

An attacker can attempt to exhaust an endpoint's memory. HPACK is designed to limit the peak memory allocation and amount of state an endpoint maintains.

The amount of memory used by the compressor is limited by the maximum size defined for the dynamic table under the HPACK protocol. In HTTP/2, this value is controlled by the decoder via the SETTINGS\_HEADER\_TABLE\_SIZE setting parameter (see [Section 6.5.2 of HTTP2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)). This limit accounts for both the size of the data stored in the dynamic table and a small amount of overhead.


A decoder can limit its use of state memory by setting an appropriate maximum size for the dynamic table. In HTTP/2, this is done by setting an appropriate value for the SETTINGS\_HEADER\_TABLE\_SIZE parameter. An encoder can limit the amount of state memory it uses by signaling a dynamic table size smaller than the state allowed by the decoder (see [Section 6.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#3-%E5%8A%A8%E6%80%81%E8%A1%A8%E5%A4%A7%E5%B0%8F%E6%9B%B4%E6%96%B0)).

The amount of temporary memory consumed by an encoder or decoder can be limited by processing header fields sequentially. Implementations do not need to retain the complete list of header fields. Note, however, that applications may need to retain the complete header list for other reasons. Even though HPACK does not force this situation, application constraints may make it necessary.


### 4. Implementation Limits

HPACK implementations need to ensure that large integer values, long encodings of integers, or long string literals do not create security vulnerabilities.

An implementation must set limits on the integer values it accepts and on their encoded lengths (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)). Likewise, it must set a length limit for string literals (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)).


------------------------------------------------------

Reference:
  
[RFC 7541](https://tools.ietf.org/html/rfc7541)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/http2-header-compression/](https://halfrost.com/http2-header-compression/)