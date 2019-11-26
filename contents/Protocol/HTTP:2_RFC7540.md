# Hypertext Transfer Protocol Version 2 (HTTP/2)


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/129_0.png'>
</p>


## Table of Contents

## 1. [Introduction](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#%E8%A7%A3%E5%BC%80-http2-%E7%9A%84%E9%9D%A2%E7%BA%B1http2-%E6%98%AF%E5%A6%82%E4%BD%95%E5%BB%BA%E7%AB%8B%E8%BF%9E%E6%8E%A5%E7%9A%84)
   



## 2. HTTP/2 Protocol Overview


- 2.1. [Document Organization](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#%E4%B8%80-http2-protocol-overview)  
- 2.2. [Conventions and Terminology](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#%E4%B8%80-http2-protocol-overview)  
   
## 3. Starting HTTP/2

- 3.1. [HTTP/2 Version Identification](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#1-http2-version-identification)
- 3.2. [Starting HTTP/2 for "http" URIs](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#2-starting-http2-for-http-uris)
- 3.2.1 [HTTP2-Settings Header Field](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#3-http2-settings-header-field)  
- 3.3. [Starting HTTP/2 for "https" URIs](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#4-starting-http2-for-https-uris)
- 3.4. [Starting HTTP/2 with Prior Knowledge](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#5-starting-http2-with-prior-knowledge)
- 3.5. [HTTP/2 Connection Preface](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-begin.md#6-http2-connection-preface) 
  
  
## 4. HTTP Frames 

- 4.1. [Frame Format](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%80-frame-format-%E5%B8%A7%E6%A0%BC%E5%BC%8F)    
- 4.2. [Frame Size](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%BA%8C-frame-size-%E5%B8%A7%E5%A4%A7%E5%B0%8F)
- 4.3. [Header Compression and Decompression](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%89-header-compression-and-decompression)
   
## 5. Streams and Multiplexing

- 5.1. [Stream States](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%9B%9B-stream-%E6%B5%81%E7%8A%B6%E6%80%81%E6%9C%BA)   
- 5.1.1. [Stream Identifiers](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E6%A0%87%E8%AF%86%E7%AC%A6) 
- 5.1.2. [Stream Concurrency](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-stream-%E5%B9%B6%E5%8F%91) 
- 5.2. [Flow Control](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%BA%94-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6)
- 5.2.1. [Flow-Control Principles](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6%E5%8E%9F%E5%88%99) 
- 5.2.2. [Appropriate Use of Flow Control](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E9%80%82%E5%BD%93%E7%9A%84%E4%BD%BF%E7%94%A8%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6)   
- 5.3. [Stream Priority](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AD-stream-%E4%BC%98%E5%85%88%E7%BA%A7)
- 5.3.1. [Stream Dependencies](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-stream-%E4%BE%9D%E8%B5%96)
- 5.3.2. [Dependency Weighting](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E4%BE%9D%E8%B5%96%E6%9D%83%E9%87%8D)
- 5.3.3. [Reprioritization](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#3-%E4%BC%98%E5%85%88%E7%BA%A7%E8%B0%83%E6%95%B4)
- 5.3.4. [Prioritization State Management](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#4-%E4%BC%98%E5%85%88%E7%BA%A7%E7%9A%84%E7%8A%B6%E6%80%81%E7%AE%A1%E7%90%86)
- 5.3.5. [Default Priorities](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#5-%E9%BB%98%E8%AE%A4%E4%BC%98%E5%85%88%E7%BA%A7)
- 5.4. [Error Handling](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E4%B8%83-%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)
- 5.4.1. [Connection Error Handling](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#1-%E8%BF%9E%E6%8E%A5%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)
- 5.4.2. [Stream Error Handling](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#2-%E6%B5%81%E9%94%99%E8%AF%AF%E7%9A%84%E9%94%99%E8%AF%AF%E5%A4%84%E7%90%86)
- 5.4.3. [Connection Termination](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#3-%E8%BF%9E%E6%8E%A5%E7%BB%88%E6%AD%A2)   
- 5.5. [Extending HTTP/2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames.md#%E5%85%AB-http2-%E4%B8%AD%E7%9A%84%E6%89%A9%E5%B1%95)   

## 6. Frame Definitions

- 6.1. [DATA](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%80-data-%E5%B8%A7)   
- 6.2. [HEADERS](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%8C-headers-%E5%B8%A7)   
- 6.3. [PRIORITY](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%89-priority-%E5%B8%A7)  
- 6.4. [RST\_STREAM](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%9B%9B-rst_stream-%E5%B8%A7)  
- 6.5. [SETTINGS](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%BA%94-settings-%E5%B8%A7)
- 6.5.1 [SETTINGS Format](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#1-settings-format)
- 6.5.2 [Defined SETTINGS Parameters](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-defined-settings-parameters)
- 6.5.3 [Settings Synchronization](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#3-settings-synchronization)
- 6.6. [PUSH\_PROMISE](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AD-push_promise-%E5%B8%A7)   
- 6.7. [PING](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B8%83-ping-%E5%B8%A7)  
- 6.8. [GOAWAY](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%85%AB-goaway-%E5%B8%A7)  
- 6.9. [WINDOW\_UPDATE](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E4%B9%9D-window_update-%E5%B8%A7)
- 6.9.1 [The Flow-Control Window](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#1-the-flow-control-window)
- 6.9.2 [Initial Flow-Control Window Size](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#2-initial-flow-control-window-size)
- 6.9.3 [Reducing the Stream Window Size](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#3-reducing-the-stream-window-size)
- 6.10. [CONTINUATION](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81-continuation-%E5%B8%A7)   

     
## 7. [Error Codes](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Frames-Definitions.md#%E5%8D%81%E4%B8%80-error-codes) 


## 8. HTTP Message Exchanges

- 8.1. [HTTP Request/Response Exchange](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%B8%80-http-requestresponse-exchange)
- 8.1.1. [Upgrading from HTTP/2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#1-upgrading-from-http2)
- 8.1.2. [HTTP Header Fields](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#2-http-header-fields)
- 8.1.3. [Examples](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#3-examples)
- 8.1.4. [Request Reliability Mechanisms in HTTP/2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#4-request-reliability-mechanisms-in-http2) 
- 8.2. [Server Push](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%BA%8C-server-push)
- 8.2.1. [Push Requests](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#1-push-requests)
- 8.2.2. [Push Responses](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#2-push-responses)
- 8.3. [The CONNECT Method](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP:2-HTTP-Semantics.md#%E4%B8%89-the-connect-method)   

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
> Source: [https://halfrost.com/http2\_rfc7540/](https://halfrost.com/http2_rfc7540/)