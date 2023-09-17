# HPACK: Header Compression for HTTP/2


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/134_0.jpg'>
</p>


## Table of Contents

## 1. Introduction
   
- 1.1. [Overview](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-%E6%80%BB%E8%A7%88)
- 1.2. [Conventions](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-%E7%BA%A6%E5%AE%9A)
- 1.3. [Terminology](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-%E6%9C%AF%E8%AF%AD)

## 2. Compression Process Overview

- 2.1. [Header List Ordering](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-header-list-ordering)
- 2.2. [Encoding and Decoding Contexts](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-encoding-and-decoding-contexts) 
- 2.3. [Indexing Tables](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-indexing-tables) 
- 2.3.1. [Static Table](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-静态表)
- 2.3.2. [Dynamic Table](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-%E5%8A%A8%E6%80%81%E8%A1%A8) 
- 2.3.3. [Index Address Space](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-%E7%B4%A2%E5%BC%95%E5%9C%B0%E5%9D%80%E7%A9%BA%E9%97%B4)
- 2.4. [Header Field Representation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#4-header-field-representation) 
   
## 3. Header Block Decoding

- 3.1. [Header Block Processing](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-header-block-processing) 
- 3.2. [Header Field Representation Processing](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-header-field-representation-processing) 
      

## 4. Dynamic Table Management

- 4.1. [Calculating Table Size](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-calculating-table-size)
- 4.2. [Maximum Table Size](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-maximum-table-size)
- 4.3. [Entry Eviction When Dynamic Table Size Changes](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-entry-eviction-when-dynamic-table-size-changes)
- 4.4. [Entry Eviction When Adding New Entries](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#4-entry-eviction-when-adding-new-entries) 


## 5. Primitive Type Representations

- 5.1. [Integer Representation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-integer-representation) 
- 5.2. [String Literal Representation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-string-literal-representation)

## 6. Binary Format

- 6.1. [Indexed Header Field Representation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-%E7%B4%A2%E5%BC%95-header-%E5%AD%97%E6%AE%B5%E8%A1%A8%E7%A4%BA)
- 6.2. [Literal Header Field Representation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5%E6%A0%87%E8%AF%86)
- 6.2.1. [Literal Header Field with Incremental Indexing](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-%E5%B8%A6%E5%A2%9E%E9%87%8F%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)
- 6.2.2. [Literal Header Field without Indexing](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-%E4%B8%8D%E5%B8%A6%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)
- 6.2.3. [Literal Header Field Never Indexed](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-%E4%BB%8E%E4%B8%8D%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)
- 6.3. [Dynamic Table Size Update](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-%E5%8A%A8%E6%80%81%E8%A1%A8%E5%A4%A7%E5%B0%8F%E6%9B%B4%E6%96%B0) 
      
      
## 7. Security Considerations

- 7.1. [Probing Dynamic Table State](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-%E6%8E%A2%E6%B5%8B%E5%8A%A8%E6%80%81%E8%A1%A8%E7%8A%B6%E6%80%81)
- 7.1.1. [Applicability to HPACK and HTTP](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#1-%E9%80%82%E7%94%A8%E4%BA%8E-hpack-%E5%92%8C-http)
- 7.1.2. [Mitigation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-%E5%87%8F%E8%BD%BB)
- 7.1.3. [Never-Indexed Literals](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-%E6%B0%B8%E4%B8%8D%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2)
- 7.2. [Static Huffman Encoding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#2-%E9%9D%99%E6%80%81%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81)
- 7.3. [Memory Consumption](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#3-%E5%86%85%E5%AD%98%E7%AE%A1%E7%90%86)
- 7.4. [Implementation Limits](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_Header-Compression.md#4-%E5%AE%9E%E7%8E%B0%E6%96%B9%E7%9A%84%E9%99%90%E5%88%B6)
      
      
## 8. References

> 这一章都是引用的论文，所以就不翻译了。

- 8.1. Normative References
- 8.2. Informative References
      
      
## [Appendix A. Static Table Definition](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#%E4%B8%80-%E9%9D%99%E6%80%81%E8%A1%A8%E5%AE%9A%E4%B9%89)


## [Appendix B. Huffman Code](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#%E4%BA%8C-%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81)



## Appendix C. Examples

- C.1. [Integer Representation Examples](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E6%95%B4%E6%95%B0%E8%A1%A8%E7%A4%BA%E7%9A%84%E7%A4%BA%E4%BE%8B) 
- C.1.1. [Example 1: Encoding 10 Using a 5-Bit Prefix](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E4%BD%BF%E7%94%A8-5-%E4%BD%8D%E5%89%8D%E7%BC%80%E5%AF%B9-10-%E8%BF%9B%E8%A1%8C%E7%BC%96%E7%A0%81)
- C.1.2. [Example 2: Encoding 1337 Using a 5-Bit Prefix](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-%E4%BD%BF%E7%94%A8-5-%E4%BD%8D%E5%89%8D%E7%BC%80%E5%AF%B9-1337-%E8%BF%9B%E8%A1%8C%E7%BC%96%E7%A0%81)
- C.1.3. [Example 3: Encoding 42 Starting at an Octet Boundary](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E4%BB%8E%E5%85%AB%E4%BD%8D%E5%AD%97%E8%8A%82%E8%BE%B9%E7%95%8C%E5%BC%80%E5%A7%8B%E5%AF%B9-42-%E8%BF%9B%E8%A1%8C%E7%BC%96%E7%A0%81)
- C.2. [Header Field Representation Examples](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-header-%E5%AD%97%E6%AE%B5%E8%A1%A8%E7%A4%BA%E7%9A%84%E7%A4%BA%E4%BE%8B)
- C.2.1. [Literal Header Field with Indexing](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E5%B8%A6%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)
- C.2.2. [Literal Header Field without Indexing](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-%E6%B2%A1%E6%9C%89%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)
- C.2.3. [Literal Header Field Never Indexed](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E4%BB%8E%E4%B8%8D%E7%B4%A2%E5%BC%95%E7%9A%84%E5%AD%97%E9%9D%A2-header-%E5%AD%97%E6%AE%B5)
- C.2.4. [Indexed Header Field](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#4-%E7%B4%A2%E5%BC%95%E7%9A%84-header-%E5%AD%97%E6%AE%B5)
- C.3. [Request Examples without Huffman Coding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E6%B2%A1%E6%9C%89%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81%E8%AF%B7%E6%B1%82%E7%9A%84%E7%A4%BA%E4%BE%8B)
- C.3.1. [First Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E7%AC%AC%E4%B8%80%E4%B8%AA%E8%AF%B7%E6%B1%82)
- C.3.2. [Second Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-%E7%AC%AC%E4%BA%8C%E4%B8%AA%E8%AF%B7%E6%B1%82) 
- C.3.3. [Third Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E7%AC%AC%E4%B8%89%E4%B8%AA%E8%AF%B7%E6%B1%82)
- C.4. [Request Examples with Huffman Coding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#4-%E6%9C%89%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81%E8%AF%B7%E6%B1%82%E7%9A%84%E7%A4%BA%E4%BE%8B) 
- C.4.1. [First Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E7%AC%AC%E4%B8%80%E4%B8%AA%E8%AF%B7%E6%B1%82-1)
- C.4.2. [Second Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-%E7%AC%AC%E4%BA%8C%E4%B8%AA%E8%AF%B7%E6%B1%82-1)
- C.4.3. [Third Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E7%AC%AC%E4%B8%89%E4%B8%AA%E8%AF%B7%E6%B1%82-1)
- C.5. [Response Examples without Huffman Coding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#5-%E6%B2%A1%E6%9C%89%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81%E5%93%8D%E5%BA%94%E7%9A%84%E7%A4%BA%E4%BE%8B)
- C.5.1. [First Response](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E7%AC%AC%E4%B8%80%E4%B8%AA%E5%93%8D%E5%BA%94) 
- C.5.2. [Second Response](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-%E7%AC%AC%E4%BA%8C%E4%B8%AA%E5%93%8D%E5%BA%94)
- C.5.3. [Third Response](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E7%AC%AC%E4%B8%89%E4%B8%AA%E5%93%8D%E5%BA%94)
- C.6. [Response Examples with Huffman Coding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#6-%E6%9C%89%E9%9C%8D%E5%A4%AB%E6%9B%BC%E7%BC%96%E7%A0%81%E5%93%8D%E5%BA%94%E7%9A%84%E7%A4%BA%E4%BE%8B)
- C.6.1. [First Response](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#1-%E7%AC%AC%E4%B8%80%E4%B8%AA%E5%93%8D%E5%BA%94-1)
- C.6.2. [Second Response](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#2-%E7%AC%AC%E4%BA%8C%E4%B8%AA%E5%93%8D%E5%BA%94-1)
- C.6.3. [Third Response](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2_HPACK-Example.md#3-%E7%AC%AC%E4%B8%89%E4%B8%AA%E5%93%8D%E5%BA%94-1)


      
------------------------------------------------------

Reference：
  
[RFC 7541](https://tools.ietf.org/html/rfc7541)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/http2\_rfc7541/](https://halfrost.com/http2_rfc7541/)