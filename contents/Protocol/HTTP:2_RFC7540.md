# Hypertext Transfer Protocol Version 2 (HTTP/2)


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/117_0.png'>
</p>


## Table of Contents

## 1. [Introduction]()
   
## 2. [HTTP/2 Protocol Overview]()

- 2.1. [Document Organization]()  
- 2.2. [Conventions and Terminology]()  
   
## 3. Starting HTTP/2

- 3.1. [HTTP/2 Version Identification]()
- 3.2. [Starting HTTP/2 for "http" URIs]()
- 3.2.1 [HTTP2-Settings Header Field]()  
- 3.3. [Starting HTTP/2 for "https" URIs]()
- 3.4. [Starting HTTP/2 with Prior Knowledge]()
- 3.5. [HTTP/2 Connection Preface]() 
  
  
## 4. HTTP Frames 

- 4.1. [Frame Format]()    
- 4.2. [Frame Size]()
- 4.3. [Header Compression and Decompression]()
   
## 5. Streams and Multiplexing

- 5.1. [Stream States]()   
- 5.1.1. [Stream Identifiers]() 
- 5.1.2. [Stream Concurrency]() 
- 5.2. [Flow Control]()
- 5.2.1. [Flow-Control Principles]() 
- 5.2.2. [Appropriate Use of Flow Control]()   
- 5.3. [Stream Priority]()
- 5.3.1. [Stream Dependencies]()
- 5.3.2. [Dependency Weighting]()
- 5.3.3. [Reprioritization]()
- 5.3.4. [Prioritization State Management]()
- 5.3.5. [Default Priorities]()
- 5.4. [Error Handling]()
- 5.4.1. [Connection Error Handling]()
- 5.4.2. [Stream Error Handling]()
- 5.4.3. [Connection Termination]()   
- 5.5. [Extending HTTP/2]()   

## 6. Frame Definitions

- 6.1. [DATA]()   
- 6.2. [HEADERS]()   
- 6.3. [PRIORITY]()  
- 6.4. [RST\_STREAM]()  
- 6.5. [SETTINGS]()
- 6.5.1 [SETTINGS Format]()
- 6.5.2 [Defined SETTINGS Parameters]()
- 6.5.3 [Settings Synchronization]()
- 6.6. [PUSH\_PROMISE]()   
- 6.7. [PING]()  
- 6.8. [GOAWAY]()  
- 6.9. [WINDOW\_UPDATE]()
- 6.9.1 [The Flow-Control Window]()
- 6.9.2 [Initial Flow-Control Window Size]()
- 6.9.3 [Reducing the Stream Window Size]()
- 6.10. [CONTINUATION]()   

     
## 7. Error Codes 


## 8. HTTP Message Exchanges

- 8.1. [HTTP Request/Response Exchange]()
- 8.1.1. [Upgrading from HTTP/2]()
- 8.1.2. [HTTP Header Fields]()
- 8.1.3. [Examples]()
- 8.1.4. [Request Reliability Mechanisms in HTTP/2]() 
- 8.2. [Server Push]()
- 8.2.1. [Push Requests]()
- 8.2.2. [Push Responses]()
- 8.3. [The CONNECT Method]()   

## 9. Additional HTTP Requirements/Considerations

- 9.1. [Connection Management](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E8%BF%9E%E6%8E%A5%E7%AE%A1%E7%90%86)
- 9.1.1. [Connection Reuse](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E8%BF%9E%E6%8E%A5%E9%87%8D%E7%94%A8)
- 9.1.2. [The 421 (Misdirected Request) Status Code](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-421-%E7%8A%B6%E6%80%81%E7%A0%81)
- 9.2. [Use of TLS Features](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E4%BD%BF%E7%94%A8-tls-%E7%89%B9%E6%80%A7) 
- 9.2.1. [TLS 1.2 Features](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-tls-12-%E7%89%B9%E6%80%A7)
- 9.2.2. [TLS 1.2 Cipher Suites](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-tls-12-%E5%8A%A0%E5%AF%86%E5%A5%97%E4%BB%B6)
 

## 10. Security Considerations

- 10.1. [Server Authority](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%9D%83%E9%99%90)
- 10.2. [Cross-Protocol Attacks](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E8%B7%A8%E5%8D%8F%E8%AE%AE%E6%94%BB%E5%87%BB) 
- 10.3. [Intermediary Encapsulation Attacks](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#3-%E4%B8%AD%E9%97%B4%E4%BB%B6%E5%B0%81%E8%A3%85%E6%94%BB%E5%87%BB) 
- 10.4. [Cacheability of Pushed Responses](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#4-%E6%8E%A8%E9%80%81%E5%93%8D%E5%BA%94%E7%9A%84%E5%8F%AF%E7%BC%93%E5%AD%98%E6%80%A7) 
- 10.5. [Denial-of-Service Considerations](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#5-%E5%85%B3%E4%BA%8E%E6%8B%92%E7%BB%9D%E6%9C%8D%E5%8A%A1) 
- 10.5.1. [Limits on Header Block Size](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-%E9%99%90%E5%88%B6%E5%A4%B4%E5%9D%97%E5%A4%A7%E5%B0%8F) 
- 10.5.2. [CONNECT Issues](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E8%BF%9E%E6%8E%A5%E9%97%AE%E9%A2%98) 
- 10.6. [Use of Compression](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#6-%E4%BD%BF%E7%94%A8%E5%8E%8B%E7%BC%A9) 
- 10.7. [Use of Padding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#7-%E4%BD%BF%E7%94%A8%E5%A1%AB%E5%85%85) 
- 10.8. [Privacy Considerations](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#8-%E5%85%B3%E4%BA%8E%E9%9A%90%E7%A7%81%E7%9A%84%E6%B3%A8%E6%84%8F%E4%BA%8B%E9%A1%B9) 


## 11. IANA Considerations

- 11.1. [Registration of HTTP/2 Identification Strings](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#1-http2-%E6%A0%87%E8%AF%86%E5%AD%97%E7%AC%A6%E4%B8%B2%E6%B3%A8%E5%86%8C) 
- 11.2. [Frame Type Registry](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#2-%E5%B8%A7%E7%B1%BB%E5%9E%8B%E6%B3%A8%E5%86%8C) 
- 11.3. [Settings Registry](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#3-settings-%E6%B3%A8%E5%86%8C) 
- 11.4. [Error Code Registry](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#4-%E9%94%99%E8%AF%AF%E7%A0%81%E6%B3%A8%E5%86%8C) 
- 11.5. [HTTP2-Settings Header Field Registration](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#5-http2-settings-%E5%A4%B4%E5%AD%97%E6%AE%B5%E6%B3%A8%E5%86%8C) 
- 11.6. [PRI Method Registration](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#6-pri-%E6%96%B9%E6%B3%95%E6%B3%A8%E5%86%8C) 
- 11.7. [The 421 (Misdirected Request) HTTP Status Code](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#7-421-http-%E7%8A%B6%E6%80%81%E7%A0%81) 
- 11.8. [The h2c Upgrade Token](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-Considerations.md#8-%E5%85%B3%E4%BA%8E-h2c-%E5%8D%87%E7%BA%A7-token) 


## 12. References

> 这一章都是引用的论文，所以就不翻译了。

- 12.1. Normative References 
- 12.2. Informative References 

## Appendix A. TLS 1.2 Cipher Suite Black List

> 这一章是 TLS 1.2 中加入黑名单的加密套件



------------------------------------------------------

Reference：
  
[RFC 7540](https://tools.ietf.org/html/rfc7540)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/HTTP/2\_RFC7540/](https://halfrost.com/HTTP/2_RFC7540/)