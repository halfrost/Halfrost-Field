<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/133_0.jpeg'>
</p>

# HTTP/2 HPACK: Practical Examples

In the previous article, we explained the 8 scenarios in the HPACK algorithm in detail (7 Name-value scenarios + 1 dynamic table update scenario).


>There are two ways to update the dynamic table size. One is to modify it directly in a HEADERS frame (starting with the 3-bit “001” pattern); the other is to set it via SETTINGS\_HEADER\_TABLE\_SIZE in a SETTINGS frame.
>

Before introducing practical HPACK usage, we first need to look at the definition of the static table and the definition of Huffman coding in HTTP/2.

## I. Static Table Definition

The static table (see [Section 2.3.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2_Header-Compression.md#1-%E9%9D%99%E6%80%81%E8%A1%A8)) contains a predefined, immutable list of header fields.

The static table was created based on the header fields most frequently used by popular websites, with HTTP/2-specific pseudo-header fields added as well (see [Section 8.1.2.1 of [HTTP2]](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2-HTTP-Semantics.md#2-http-header-fields)). For header fields that have a few frequent values, an entry is added for each of those frequent values. For other header fields, an entry with an empty value is added.

Table 1 lists the predefined header fields that make up the static table and provides the index for each entry.


|Index | Header Name | Header Value|
|:-------:|:-------:|:-------:|
| 1     | :authority                  |               |
| 2     | :method                     | GET           |
| 3     | :method                     | POST          |
| 4     | :path                       | /             |
| 5     | :path                       | /index.html   |
| 6     | :scheme                     | http          |
| 7     | :scheme                     | https         |
| 8     | :status                     | 200           |
| 9     | :status                     | 204           |
| 10    | :status                     | 206           |
| 11    | :status                     | 304           |
| 12    | :status                     | 400           |
| 13    | :status                     | 404           |
| 14    | :status                     | 500           |
| 15    | accept-charset              |               |
| 16    | accept-encoding             | gzip, deflate |
| 17    | accept-language             |               |
| 18    | accept-ranges               |               |
| 19    | accept                      |               |
| 20    | access-control-allow-origin |               |
| 21    | age                         |               |
| 22    | allow                       |               |
| 23    | authorization               |               |
| 24    | cache-control               |               |
| 25    | content-disposition         |               |
| 26    | content-encoding            |               |
| 27    | content-language            |               |
| 28    | content-length              |               |
| 29    | content-location            |               |
| 30    | content-range               |               |
| 31    | content-type                |               |
| 32    | cookie                      |               |
| 33    | date                        |               |
| 34    | etag                        |               |
| 35    | expect                      |               |
| 36    | expires                     |               |
| 37    | from                        |               |
| 38    | host                        |               |
| 39    | if-match                    |               |
| 40    | if-modified-since           |               |
| 41    | if-none-match               |               |
| 42    | if-range                    |               |
| 43    | if-unmodified-since         |               |
| 44    | last-modified               |               |
| 45    | link                        |               |
| 46    | location                    |               |
| 47    | max-forwards                |               |
| 48    | proxy-authenticate          |               |
| 49    | proxy-authorization         |               |
| 50    | range                       |               |
| 51    | referer                     |               |
| 52    | refresh                     |               |
| 53    | retry-after                 |               |
| 54    | server                      |               |
| 55    | set-cookie                  |               |
| 56    | strict-transport-security   |               |
| 57    | transfer-encoding           |               |
| 58    | user-agent                  |               |
| 59    | vary                        |               |
| 60    | via                         |               |
| 61    | www-authenticate            |               |

## II. Huffman Coding

### 1. The Huffman Algorithm


If every character is encoded with a fixed-length representation, is there an algorithm that can guarantee substantial compression of the data? The first problem fixed-length encodings face is how to avoid ambiguity and misinterpretation during decompression.

In 1952, Huffman discovered an algorithm for optimal prefix codes. The core idea is: symbols with higher probabilities are assigned shorter codes, while symbols with lower probabilities are assigned longer codes.

For example, suppose an article contains many words. If we count the frequency of every letter, and take the six letters a, b, c, d, e, and f as an example, their frequencies are as follows:

![](https://img.halfrost.com/Blog/ArticleImage/133_1.png)

The first step is to select the two lowest frequencies and merge them. The left subtree is the smaller one, and the right subtree is the larger one. After merging them into a new node, put the new node back among the original nodes.

![](https://img.halfrost.com/Blog/ArticleImage/133_2.png)

Repeat the first step until all nodes have been merged into a single tree.

![](https://img.halfrost.com/Blog/ArticleImage/133_3.png)

Finally, label every left-subtree edge with 0 and every right-subtree edge with 1. The final encodings for the six letters above are a = 0, b = 101, c = 100, d = 111, e = 1101, f = 1100.

### 2. Definition of Huffman Coding in HTTP/2

When a string literal is encoded using Huffman coding, the following Huffman codes are used (see [Section 5.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2_Header-Compression.md#2-string-literal-representation)).

## III. Examples


This section includes examples covering integer encoding, header field representations, and the encoding of complete lists of request and response header fields, both with and without Huffman encoding.


### 1. Examples of Integer Representation

This section shows the representation of integer values in detail (see [Section 5.1](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/HTTP_2_Header-Compression.md#1-integer-representation)).

### (1). Encoding 10 with a 5-bit Prefix

10 is less than 31 (2^5-1), and is represented using a 5-bit prefix.
```c
     0   1   2   3   4   5   6   7
   +---+---+---+---+---+---+---+---+
   | X | X | X | 0 | 1 | 0 | 1 | 0 |   10 stored on 5 bits
   +---+---+---+---+---+---+---+---+
```

### (2). Encoding 1337 with a 5-bit Prefix

1337 is greater than 31 (2^5-1), and a 5-bit prefix is used to represent it. The 5-bit prefix is filled with its maximum value (31).

I = 1337 - (2^5 - 1) = 1306. I (1306) is greater than or equal to 128. I % 128 == 26, 26 + 128 == 154, and 154 is represented in 8 bits as: 10011010. I is now 10 (1306 / 128 == 10), represented in 8 bits as: 00001010.
```c
     0   1   2   3   4   5   6   7
   +---+---+---+---+---+---+---+---+
   | X | X | X | 1 | 1 | 1 | 1 | 1 |  Prefix = 31, I = 1306
   | 1 | 0 | 0 | 1 | 1 | 0 | 1 | 0 |  1306>=128, encode(154), I=1306/128
   | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 0 |  10<128, encode(10), done
   +---+---+---+---+---+---+---+---+
```

### (3). Encode 42 starting at an octet boundary

42 is less than 255 (2^8 - 1), so it is represented with an 8-bit prefix.
```c
     0   1   2   3   4   5   6   7
   +---+---+---+---+---+---+---+---+
   | 0 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |   42 stored on 8 bits
   +---+---+---+---+---+---+---+---+
```

### 2. Examples of header field representations

This section shows several independent representation examples.

### (1). Literal header field with indexing

The header field representation uses a literal name `name` and a literal value `value`. The header field is added to the dynamic table.

Header list to be encoded:
```c
custom-key: custom-header
```
Hexadecimal representation of the encoded data:
```c
   400a 6375 7374 6f6d 2d6b 6579 0d63 7573 | @.custom-key.cus
   746f 6d2d 6865 6164 6572                | tom-header
```
Decoding process:
```c
   40                                      | == Literal indexed ==
   0a                                      |   Literal name (len = 10)
   6375 7374 6f6d 2d6b 6579                | custom-key
   0d                                      |   Literal value (len = 13)
   6375 7374 6f6d 2d68 6561 6465 72        | custom-header
                                           | -> custom-key:
                                           |   custom-header
```
![](https://img.halfrost.com/Blog/ArticleImage/133_4.png)

Because the H bit is set to 0, the following strings are represented in literal form, i.e., as ASCII codes. By looking them up in the table, we can see that the value represented by 6375 7374 6f6d 2d6b 6579 is custom-key, and the value represented by 6375 7374 6f6d 2d68 6561 6465 72 is custom-header.

The dynamic table after encoding:
```c
   [  1] (s =  55) custom-key: custom-header
         Table size:  55
```
Decoded header list:
```c
custom-key: custom-header
```

### (2). Literal header fields without indexing

The header field is represented using the indexed name name and the literal value value. The header field is not added to the dynamic table.

Header list to encode:
```c
   :path: /sample/path
```
Hexadecimal representation of the encoded data:
```c
   040c 2f73 616d 706c 652f 7061 7468      | ../sample/path
```
Decoding process:
```c
   04                                      | == Literal not indexed ==
                                           |   Indexed name (idx = 4)
                                           |     :path
   0c                                      |   Literal value (len = 12)
   2f73 616d 706c 652f 7061 7468           | /sample/path
                                           | -> :path: /sample/path
```
![](https://img.halfrost.com/Blog/ArticleImage/133_5_.png)


Since the H bit is set to 0, the following string is represented in literal form, i.e., as ASCII codes. By looking it up in the table, we can see that the value represented by `2f73 616d 706c 652f 7061 7468` is `/sample/path`. Since `:path` exists in the static table, only `index = 4` needs to be transmitted.


The encoded dynamic table:
```c
Empty
```
Decoded header list:
```c
   :path: /sample/path
```

### (3). Literal header field never indexed

The header field is represented using a literal name and a literal value. The header field is not added to the dynamic table, and if it is re-encoded by an intermediary, it must use the same representation.

List of headers to encode:
```c
   password: secret
```
Hexadecimal representation of the encoded data:
```c
   1008 7061 7373 776f 7264 0673 6563 7265 | ..password.secre
   74                                      | t
```
Decoding process:
```c
   10                                      | == Literal never indexed ==
   08                                      |   Literal name (len = 8)
   7061 7373 776f 7264                     | password
   06                                      |   Literal value (len = 6)
   7365 6372 6574                          | secret
                                           | -> password: secret
```
![](https://img.halfrost.com/Blog/ArticleImage/133_6.png)


Because the H bit is set to 0, the following strings are represented in literal form, i.e., as ASCII codes. Looking them up in the table shows that the value represented by 7061 7373 776f 7264  is password. The value represented by 7365 6372 6574 is secret.

The encoded dynamic table:
```c
Empty
```
Decoded header list:
```c
   password: secret
```

### (4). Indexed header field

The header field denotes a header field referenced by an index in the static table.


List of headers to encode:
```c
   :method: GET
```
Hexadecimal representation of the encoded data:
```c
   82                                      | .
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
```
![](https://img.halfrost.com/Blog/ArticleImage/133_7.png)

Since both :method and GET are in the static table, using the index in the static table is sufficient.

The dynamic table after encoding:
```c
Empty
```
Decoded header list:
```c
   :method: GET
```

### 3. Examples of Requests Without Huffman Coding

This section shows several consecutive header lists corresponding to HTTP requests on the same connection.


### (1). First Request


Header list to be encoded:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
```
Hexadecimal representation of the encoded data:
```c
   8286 8441 0f77 7777 2e65 7861 6d70 6c65 | ...A.www.example
   2e63 6f6d                               | .com
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
   86                                      | == Indexed - Add ==
                                           |   idx = 6
                                           | -> :scheme: http
   84                                      | == Indexed - Add ==
                                           |   idx = 4
                                           | -> :path: /
   41                                      | == Literal indexed ==
                                           |   Indexed name (idx = 1)
                                           |     :authority
   0f                                      |   Literal value (len = 15)
   7777 772e 6578 616d 706c 652e 636f 6d   | www.example.com
                                           | -> :authority:
                                           |   www.example.com
```
Encoded dynamic table:
```c
   [  1] (s =  57) :authority: www.example.com
         Table size:  57
```
Decoded header list:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
```

### (2). The Second Request

List of headers to encode:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
   cache-control: no-cache
```
Hexadecimal representation of the encoded data:
```c
   8286 84be 5808 6e6f 2d63 6163 6865      | ....X.no-cache
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
   86                                      | == Indexed - Add ==
                                           |   idx = 6
                                           | -> :scheme: http
   84                                      | == Indexed - Add ==
                                           |   idx = 4
                                           | -> :path: /
   be                                      | == Indexed - Add ==
                                           |   idx = 62
                                           | -> :authority:
                                           |   www.example.com
   58                                      | == Literal indexed ==
                                           |   Indexed name (idx = 24)
                                           |     cache-control
   08                                      |   Literal value (len = 8)
   6e6f 2d63 6163 6865                     | no-cache
                                           | -> cache-control: no-cache
```
Encoded dynamic table:
```c
   [  1] (s =  53) cache-control: no-cache
   [  2] (s =  57) :authority: www.example.com
         Table size: 110
```
Decoded header list:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
   cache-control: no-cache
```

### (3). Third Request


List of headers to encode:
```c
   :method: GET
   :scheme: https
   :path: /index.html
   :authority: www.example.com
   custom-key: custom-value
```
Hexadecimal representation of the encoded data:
```c
   8287 85bf 400a 6375 7374 6f6d 2d6b 6579 | ....@.custom-key
   0c63 7573 746f 6d2d 7661 6c75 65        | .custom-value
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
   87                                      | == Indexed - Add ==
                                           |   idx = 7
                                           | -> :scheme: https
   85                                      | == Indexed - Add ==
                                           |   idx = 5
                                           | -> :path: /index.html
   bf                                      | == Indexed - Add ==
                                           |   idx = 63
                                           | -> :authority:
                                           |   www.example.com
   40                                      | == Literal indexed ==
   0a                                      |   Literal name (len = 10)
   6375 7374 6f6d 2d6b 6579                | custom-key
   0c                                      |   Literal value (len = 12)
   6375 7374 6f6d 2d76 616c 7565           | custom-value
                                           | -> custom-key:
                                           |   custom-value
```
Encoded dynamic table:
```c
   [  1] (s =  54) custom-key: custom-value
   [  2] (s =  53) cache-control: no-cache
   [  3] (s =  57) :authority: www.example.com
         Table size: 164
```
Decoded header list:
```c
   :method: GET
   :scheme: https
   :path: /index.html
   :authority: www.example.com
   custom-key: custom-value
```

### 4. Example of a Request with Huffman Encoding

This section shows the same example as the previous section, but uses Huffman encoding for the literal value.

### (1). First Request

Header list to be encoded:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
```
Hexadecimal representation of the encoded data:
```c
   8286 8441 8cf1 e3c2 e5f2 3a6b a0ab 90f4 | ...A......:k....
   ff                                      | .
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
   86                                      | == Indexed - Add ==
                                           |   idx = 6
                                           | -> :scheme: http
   84                                      | == Indexed - Add ==
                                           |   idx = 4
                                           | -> :path: /
   41                                      | == Literal indexed ==
                                           |   Indexed name (idx = 1)
                                           |     :authority
   8c                                      |   Literal value (len = 12)
                                           |     Huffman encoded:
   f1e3 c2e5 f23a 6ba0 ab90 f4ff           | .....:k.....
                                           |     Decoded:
                                           | www.example.com
                                           | -> :authority:
                                           |   www.example.com
```
Dynamic table after encoding:
```c
   [  1] (s =  57) :authority: www.example.com
         Table size:  57
```
Decoded header list:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
```

### (2). The Second Request


List of headers to be encoded:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
   cache-control: no-cache
```
Hexadecimal representation of the encoded data:
```c
   8286 84be 5886 a8eb 1064 9cbf           | ....X....d..
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
   86                                      | == Indexed - Add ==
                                           |   idx = 6
                                           | -> :scheme: http
   84                                      | == Indexed - Add ==
                                           |   idx = 4
                                           | -> :path: /
   be                                      | == Indexed - Add ==
                                           |   idx = 62
                                           | -> :authority:
                                           |   www.example.com
   58                                      | == Literal indexed ==
                                           |   Indexed name (idx = 24)
                                           |     cache-control
   86                                      |   Literal value (len = 6)
                                           |     Huffman encoded:
   a8eb 1064 9cbf                          | ...d..
                                           |     Decoded:
                                           | no-cache
                                           | -> cache-control: no-cache
```
Dynamic table after encoding:
```c
   [  1] (s =  53) cache-control: no-cache
   [  2] (s =  57) :authority: www.example.com
         Table size: 110
```
Decoded header list:
```c
   :method: GET
   :scheme: http
   :path: /
   :authority: www.example.com
   cache-control: no-cache
```

### (3). The Third Request

List of headers to encode:
```c
   :method: GET
   :scheme: https
   :path: /index.html
   :authority: www.example.com
   custom-key: custom-value
```
Hexadecimal representation of the encoded data:
```c
   8287 85bf 4088 25a8 49e9 5ba9 7d7f 8925 | ....@.%.I.[.}..%
   a849 e95b b8e8 b4bf                     | .I.[....
```
Decoding process:
```c
   82                                      | == Indexed - Add ==
                                           |   idx = 2
                                           | -> :method: GET
   87                                      | == Indexed - Add ==
                                           |   idx = 7
                                           | -> :scheme: https
   85                                      | == Indexed - Add ==
                                           |   idx = 5
                                           | -> :path: /index.html
   bf                                      | == Indexed - Add ==
                                           |   idx = 63
                                           | -> :authority:
                                           |   www.example.com
   40                                      | == Literal indexed ==
   88                                      |   Literal name (len = 8)
                                           |     Huffman encoded:
   25a8 49e9 5ba9 7d7f                     | %.I.[.}.
                                           |     Decoded:
                                           | custom-key
   89                                      |   Literal value (len = 9)
                                           |     Huffman encoded:
   25a8 49e9 5bb8 e8b4 bf                  | %.I.[....
                                           |     Decoded:
                                           | custom-value
                                           | -> custom-key:
                                           |   custom-value
```
Encoded dynamic table:
```c
   [  1] (s =  54) custom-key: custom-value
   [  2] (s =  53) cache-control: no-cache
   [  3] (s =  57) :authority: www.example.com
         Table size: 164
```
Decoded header list:
```c
   :method: GET
   :scheme: https
   :path: /index.html
   :authority: www.example.com
   custom-key: custom-value
```

### 5. Example of Responses Without Huffman Coding

This section shows several consecutive header lists corresponding to HTTP responses on the same connection. The HTTP/2 setting parameter SETTINGS\_HEADER\_TABLE\_SIZE is set to a value of 256 octets, causing some entries to be evicted.


### (1). First Response

Header list to be encoded:
```c
   :status: 302
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```
Hexadecimal representation of the encoded data:
```c
   4803 3330 3258 0770 7269 7661 7465 611d | H.302X.privatea.
   4d6f 6e2c 2032 3120 4f63 7420 3230 3133 | Mon, 21 Oct 2013
   2032 303a 3133 3a32 3120 474d 546e 1768 |  20:13:21 GMTn.h
   7474 7073 3a2f 2f77 7777 2e65 7861 6d70 | ttps://www.examp
   6c65 2e63 6f6d                          | le.com
```
Decoding process:
```c
   48                                      | == Literal indexed ==
                                           |   Indexed name (idx = 8)
                                           |     :status
   03                                      |   Literal value (len = 3)
   3330 32                                 | 302
                                           | -> :status: 302
   58                                      | == Literal indexed ==
                                           |   Indexed name (idx = 24)
                                           |     cache-control
   07                                      |   Literal value (len = 7)
   7072 6976 6174 65                       | private
                                           | -> cache-control: private
   61                                      | == Literal indexed ==
                                           |   Indexed name (idx = 33)
                                           |     date
   1d                                      |   Literal value (len = 29)
   4d6f 6e2c 2032 3120 4f63 7420 3230 3133 | Mon, 21 Oct 2013
   2032 303a 3133 3a32 3120 474d 54        |  20:13:21 GMT
                                           | -> date: Mon, 21 Oct 2013
                                           |   20:13:21 GMT
   6e                                      | == Literal indexed ==
                                           |   Indexed name (idx = 46)
   17                                      |   Literal value (len = 23)
   6874 7470 733a 2f2f 7777 772e 6578 616d | https://www.exam
   706c 652e 636f 6d                       | ple.com
                                           | -> location:
                                           |   https://www.example.com
```
Encoded dynamic table:
```c
   [  1] (s =  63) location: https://www.example.com
   [  2] (s =  65) date: Mon, 21 Oct 2013 20:13:21 GMT
   [  3] (s =  52) cache-control: private
   [  4] (s =  42) :status: 302
         Table size: 222
```
Decoded header list:
```c
   :status: 302
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```

### (2). Second Response

Evict the (`":status"`, `"302"`) header field from the dynamic table to free up available space, allowing the (`":status"`, `"307"`) header field to be added.

Header list to be encoded:
```c
   :status: 307
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```
Hexadecimal representation of the encoded data:
```c
   4803 3330 37c1 c0bf                     | H.307...
```
Decoding process:
```c
   48                                      | == Literal indexed ==
                                           |   Indexed name (idx = 8)
                                           |     :status
   03                                      |   Literal value (len = 3)
   3330 37                                 | 307
                                           | - evict: :status: 302
                                           | -> :status: 307
   c1                                      | == Indexed - Add ==
                                           |   idx = 65
                                           | -> cache-control: private
   c0                                      | == Indexed - Add ==
                                           |   idx = 64
                                           | -> date: Mon, 21 Oct 2013
                                           |   20:13:21 GMT
   bf                                      | == Indexed - Add ==
                                           |   idx = 63
                                           | -> location:
                                           |   https://www.example.com
```
Encoded dynamic table:
```c
   [  1] (s =  42) :status: 307
   [  2] (s =  63) location: https://www.example.com
   [  3] (s =  65) date: Mon, 21 Oct 2013 20:13:21 GMT
   [  4] (s =  52) cache-control: private
         Table size: 222
```
Decoded header list:
```c
   :status: 307
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```

### (3). Third Response

While processing this header list, several header fields are evicted from the dynamic table.

Header list to be encoded:
```c
   :status: 200
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:22 GMT
   location: https://www.example.com
   content-encoding: gzip
   set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1
```
Hexadecimal representation of the encoded data:
```c
   88c1 611d 4d6f 6e2c 2032 3120 4f63 7420 | ..a.Mon, 21 Oct
   3230 3133 2032 303a 3133 3a32 3220 474d | 2013 20:13:22 GM
   54c0 5a04 677a 6970 7738 666f 6f3d 4153 | T.Z.gzipw8foo=AS
   444a 4b48 514b 425a 584f 5157 454f 5049 | DJKHQKBZXOQWEOPI
   5541 5851 5745 4f49 553b 206d 6178 2d61 | UAXQWEOIU; max-a
   6765 3d33 3630 303b 2076 6572 7369 6f6e | ge=3600; version
   3d31                                    | =1
```
Decoding process:
```c
   88                                      | == Indexed - Add ==
                                           |   idx = 8
                                           | -> :status: 200
   c1                                      | == Indexed - Add ==
                                           |   idx = 65
                                           | -> cache-control: private
   61                                      | == Literal indexed ==
                                           |   Indexed name (idx = 33)
                                           |     date
   1d                                      |   Literal value (len = 29)
   4d6f 6e2c 2032 3120 4f63 7420 3230 3133 | Mon, 21 Oct 2013
   2032 303a 3133 3a32 3220 474d 54        |  20:13:22 GMT
                                           | - evict: cache-control:
                                           |   private
                                           | -> date: Mon, 21 Oct 2013
                                           |   20:13:22 GMT
   c0                                      | == Indexed - Add ==
                                           |   idx = 64
                                           | -> location:
                                           |   https://www.example.com
   5a                                      | == Literal indexed ==
                                           |   Indexed name (idx = 26)
                                           |     content-encoding
   04                                      |   Literal value (len = 4)
   677a 6970                               | gzip
                                           | - evict: date: Mon, 21 Oct
                                           |    2013 20:13:21 GMT
                                           | -> content-encoding: gzip
   77                                      | == Literal indexed ==
                                           |   Indexed name (idx = 55)
                                           |     set-cookie
   38                                      |   Literal value (len = 56)
   666f 6f3d 4153 444a 4b48 514b 425a 584f | foo=ASDJKHQKBZXO
   5157 454f 5049 5541 5851 5745 4f49 553b | QWEOPIUAXQWEOIU;
   206d 6178 2d61 6765 3d33 3630 303b 2076 |  max-age=3600; v
   6572 7369 6f6e 3d31                     | ersion=1
                                           | - evict: location:
                                           |   https://www.example.com
                                           | - evict: :status: 307
                                           | -> set-cookie: foo=ASDJKHQ
                                           |   KBZXOQWEOPIUAXQWEOIU; ma
                                           |   x-age=3600; version=1
```
Encoded dynamic table:
```c
   [  1] (s =  98) set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU;
                    max-age=3600; version=1
   [  2] (s =  52) content-encoding: gzip
   [  3] (s =  65) date: Mon, 21 Oct 2013 20:13:22 GMT
         Table size: 215
```
Decoded header list:
```c
   :status: 200
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:22 GMT
   location: https://www.example.com
   content-encoding: gzip
   set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1
```

### 6. Example with Huffman-Encoded Responses

This section shows the same example as in the previous section, but uses Huffman encoding for literal values. The HTTP/2 setting parameter SETTINGS\_HEADER\_TABLE\_SIZE is set to a value of 256 octets, causing some eviction events to occur. The eviction mechanism uses the length of the decoded literal values, so the same evictions occur as in the previous section.

### (1). First Response

The header list to be encoded:
```c
   :status: 302
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```
Hexadecimal representation of the encoded data:
```c
   4882 6402 5885 aec3 771a 4b61 96d0 7abe | H.d.X...w.Ka..z.
   9410 54d4 44a8 2005 9504 0b81 66e0 82a6 | ..T.D. .....f...
   2d1b ff6e 919d 29ad 1718 63c7 8f0b 97c8 | -..n..)...c.....
   e9ae 82ae 43d3                          | ....C.
```
Decoding process:
```c
   48                                      | == Literal indexed ==
                                           |   Indexed name (idx = 8)
                                           |     :status
   82                                      |   Literal value (len = 2)
                                           |     Huffman encoded:
   6402                                    | d.
                                           |     Decoded:
                                           | 302
                                           | -> :status: 302
   58                                      | == Literal indexed ==
                                           |   Indexed name (idx = 24)
                                           |     cache-control
   85                                      |   Literal value (len = 5)
                                           |     Huffman encoded:
   aec3 771a 4b                            | ..w.K
                                           |     Decoded:
                                           | private
                                           | -> cache-control: private
   61                                      | == Literal indexed ==
                                           |   Indexed name (idx = 33)
                                           |     date
   96                                      |   Literal value (len = 22)
                                           |     Huffman encoded:
   d07a be94 1054 d444 a820 0595 040b 8166 | .z...T.D. .....f
   e082 a62d 1bff                          | ...-..
                                           |     Decoded:
                                           | Mon, 21 Oct 2013 20:13:21
                                           | GMT
                                           | -> date: Mon, 21 Oct 2013
                                           |   20:13:21 GMT
   6e                                      | == Literal indexed ==
                                           |   Indexed name (idx = 46)
                                           |     location
   91                                      |   Literal value (len = 17)
                                           |     Huffman encoded:
   9d29 ad17 1863 c78f 0b97 c8e9 ae82 ae43 | .)...c.........C
   d3                                      | .
                                           |     Decoded:
                                           | https://www.example.com
                                           | -> location:
                                           |   https://www.example.com
```
Encoded dynamic table:
```c
   [  1] (s =  63) location: https://www.example.com
   [  2] (s =  65) date: Mon, 21 Oct 2013 20:13:21 GMT
   [  3] (s =  52) cache-control: private
   [  4] (s =  42) :status: 302
         Table size: 222
```
Decoded header list:
```c
   :status: 302
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```

### (2). Second Response

Evict the (“:status”, “302”) header field from the dynamic table to free up available space, allowing the (“:status”, “307”) header field to be added.

Header list to be encoded:
```c
   :status: 307
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```
Hexadecimal representation of the encoded data:
```c
   4883 640e ffc1 c0bf                     | H.d.....
```
Decoding process:
```c
   48                                      | == Literal indexed ==
                                           |   Indexed name (idx = 8)
                                           |     :status
   83                                      |   Literal value (len = 3)
                                           |     Huffman encoded:
   640e ff                                 | d..
                                           |     Decoded:
                                           | 307
                                           | - evict: :status: 302
                                           | -> :status: 307
   c1                                      | == Indexed - Add ==
                                           |   idx = 65
                                           | -> cache-control: private
   c0                                      | == Indexed - Add ==
                                           |   idx = 64
                                           | -> date: Mon, 21 Oct 2013
                                           |   20:13:21 GMT
   bf                                      | == Indexed - Add ==
                                           |   idx = 63
                                           | -> location:
                                           |   https://www.example.com
```
Encoded dynamic table:
```c
   [  1] (s =  42) :status: 307
   [  2] (s =  63) location: https://www.example.com
   [  3] (s =  65) date: Mon, 21 Oct 2013 20:13:21 GMT
   [  4] (s =  52) cache-control: private
         Table size: 222
```
Decoded header list:
```c
   :status: 307
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:21 GMT
   location: https://www.example.com
```

### (3). The Third Response

While processing this header list, several header fields are evicted from the dynamic table.

Header list to be encoded:
```c
   :status: 200
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:22 GMT
   location: https://www.example.com
   content-encoding: gzip
   set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1
```
Hexadecimal representation of the encoded data:
```c
   88c1 6196 d07a be94 1054 d444 a820 0595 | ..a..z...T.D. ..
   040b 8166 e084 a62d 1bff c05a 839b d9ab | ...f...-...Z....
   77ad 94e7 821d d7f2 e6c7 b335 dfdf cd5b | w..........5...[
   3960 d5af 2708 7f36 72c1 ab27 0fb5 291f | 9`..'..6r..'..).
   9587 3160 65c0 03ed 4ee5 b106 3d50 07   | ..1`e...N...=P.
```
Decoding process:
```c
   88                                      | == Indexed - Add ==
                                           |   idx = 8
                                           | -> :status: 200
   c1                                      | == Indexed - Add ==
                                           |   idx = 65
                                           | -> cache-control: private
   61                                      | == Literal indexed ==
                                           |   Indexed name (idx = 33)
                                           |     date
   96                                      |   Literal value (len = 22)
                                           |     Huffman encoded:
   d07a be94 1054 d444 a820 0595 040b 8166 | .z...T.D. .....f
   e084 a62d 1bff                          | ...-..
                                           |     Decoded:
                                           | Mon, 21 Oct 2013 20:13:22
                                           | GMT
                                           | - evict: cache-control:
                                           |   private
                                           | -> date: Mon, 21 Oct 2013
                                           |   20:13:22 GMT
   c0                                      | == Indexed - Add ==
                                           |   idx = 64
                                           | -> location:
                                           |   https://www.example.com
   5a                                      | == Literal indexed ==
                                           |   Indexed name (idx = 26)
                                           |     content-encoding
   83                                      |   Literal value (len = 3)
                                           |     Huffman encoded:
   9bd9 ab                                 | ...
                                           |     Decoded:
                                           | gzip
                                           | - evict: date: Mon, 21 Oct
                                           |    2013 20:13:21 GMT
                                           | -> content-encoding: gzip
   77                                      | == Literal indexed ==
                                           |   Indexed name (idx = 55)
                                           |     set-cookie
   ad                                      |   Literal value (len = 45)
                                           |     Huffman encoded:
   94e7 821d d7f2 e6c7 b335 dfdf cd5b 3960 | .........5...[9`
   d5af 2708 7f36 72c1 ab27 0fb5 291f 9587 | ..'..6r..'..)...
   3160 65c0 03ed 4ee5 b106 3d50 07        | 1`e...N...=P.
                                           |     Decoded:
                                           | foo=ASDJKHQKBZXOQWEOPIUAXQ
                                           | WEOIU; max-age=3600; versi
                                           | on=1
                                           | - evict: location:
                                           |   https://www.example.com
                                           | - evict: :status: 307
                                           | -> set-cookie: foo=ASDJKHQ
                                           |   KBZXOQWEOPIUAXQWEOIU; ma
                                           |   x-age=3600; version=1
```
Encoded dynamic table:
```c
   [  1] (s =  98) set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU;
                    max-age=3600; version=1
   [  2] (s =  52) content-encoding: gzip
   [  3] (s =  65) date: Mon, 21 Oct 2013 20:13:22 GMT
         Table size: 215
```
Decoded header list:
```c
   :status: 200
   cache-control: private
   date: Mon, 21 Oct 2013 20:13:22 GMT
   location: https://www.example.com
   content-encoding: gzip
   set-cookie: foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1
```

### 7. Some Packet-Capture Examples

First, let’s look at how HPACK compresses the header fields in the HEADERS frame during the initial request.

![](https://img.halfrost.com/Blog/ArticleImage/133_8.png)

:method:GET is entry 2 in the static table. Both the Name and Value already exist. So this header field can be represented directly with 2.

![](https://img.halfrost.com/Blog/ArticleImage/133_9.png)

Similarly, :path:/ is entry 4 in the static table. Both the Name and Value already exist. So this header field can be represented directly with 4.

![](https://img.halfrost.com/Blog/ArticleImage/133_10.png)

Now let’s look at the second request. Again, :method:GET is the same as in the first request, so this header field can be represented directly with 2.

![](https://img.halfrost.com/Blog/ArticleImage/133_11.png)

Back to the first request: the if-none-match header field is entry 41 in the static table, but the static table does not contain a value for it. According to the HPACK algorithm explained in the previous article, the compressed string starts with 01; 101001 is 41; in 10011110, the first 1 indicates Huffman encoding, and 0011110 represents 30, indicating that the value is the content in the following 30 bytes.

![](https://img.halfrost.com/Blog/ArticleImage/133_12.png)

Still in the first request: the user-agent header field is entry 58 in the static table, but the static table does not contain a value for it. According to the HPACK algorithm explained in the previous article, the compressed string starts with 01; 111010 is 58; in 11011011, the first 1 indicates Huffman encoding, and 1011011 represents 91, indicating that the value is the content in the following 91 bytes.

![](https://img.halfrost.com/Blog/ArticleImage/133_13.png)

By the second request, the user-agent header field already has both its name and value stored in the dynamic table, so it directly hits entry 86 in the dynamic table. 1010110 represents 86. This example clearly shows that the dynamic table significantly reduces the header size.

Compare two identical requests on the same HTTP/2 connection. You can see that the header size has already been greatly reduced.

![](https://img.halfrost.com/Blog/ArticleImage/133_14.png)

In the first request, HPACK reduces the original headers by 44%.

![](https://img.halfrost.com/Blog/ArticleImage/133_15.png)

In the second request, because the dynamic table has been populated, HPACK reduces the original headers by 97%.

### 8. HPACK Optimization Effectiveness

Finally, let’s use a tool to measure HPACK’s “power” in practice. You can use [the h2load tool](https://nghttp2.org/documentation/h2load-howto.html) for testing.

The following are three test cases: the first test case sends only one request, the second sends two requests, and the third sends three requests. We can see how much header-field overhead is reduced in each test.

![](https://img.halfrost.com/Blog/ArticleImage/133_16_.png)

As shown above, the more requests there are, the smaller the header fields become.

|Number of requests|Header-field ratio|Percentage saved|
|:----:|:----:|:----:|
|1|1.002% | 29.89%|
|2|0.521% | 63.75%|
|3|0.359% | 75.04%|
|5|0.241% | 83.28%|
|10|0.137% | 90.48%|
|20|0.092% | 93.65%|
|30|0.074% | 94.85%|
|50|0.061% | 95.75%|
|100|0.052% | 96.39%|

From this, we can see that the HPACK algorithm in HTTP/2 achieves a very good overall compression ratio for headers.


------------------------------------------------------

Reference：
  
[RFC 7541](https://tools.ietf.org/html/rfc7541)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/http2-hpack-example/](https://halfrost.com/http2-hpack-example/)