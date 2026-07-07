+++
author = "一缕殇流化隐半边冰霜"
categories = ["HTTP", "Protocol"]
date = 2017-02-14T09:29:00Z
description = ""
draft = false
image = "https://img.halfrost.com//Blog/ArticleTitleImage/d/1a/f00c6c77e792f5f8ca0246148c5ee.jpg"
slug = "http"
tags = ["HTTP", "Protocol"]
title = "HTTP Guide"

+++


The Web uses a protocol called HTTP (HyperText Transfer Protocol) as its specification.
> A more precise Chinese translation of HTTP would be “Hypertext Transfer Protocol.”


HTTP was introduced in 1990. At that time, HTTP was not a formal standard, so it was called HTTP/0.9   
HTTP was officially published as a standard in May 1996, with the version named HTTP/1.0, documented in RFC1945   
In January 1997, HTTP published what is currently the most widely used version, named HTTP/1.1, documented in RFC2616  
HTTP/2 was released on May 14, 2015. It introduced various features such as server push and is currently the latest version. It is documented in RFC7540
(It is not called HTTP/2.0 because the standards committee does not intend to release minor versions anymore; the next new version will be HTTP/3)


## I. HTTP-Supported Methods

HTTP is a protocol that does not preserve state, i.e., a stateless protocol. The HTTP protocol itself does not retain communication state between requests and responses. In other words, at the HTTP level, the protocol does not persistently process requests or responses that have been sent. This is also to process large volumes of transactions more quickly and ensure the scalability of the protocol.

Although HTTP/1.1 is a stateless protocol, it deliberately introduced Cookie technology to implement the desired stateful functionality.

![](https://img.halfrost.com/Blog/ArticleImage/89_1.png)


In the HTTP/1.1 specification, idempotence is defined as:

>Methods can also have the property of "idempotence" in that (aside from error or expiration issues) the side-effects of N > 0 identical requests is the same as for a single request.

By definition, the idempotence of an HTTP method means that making one request and making multiple requests for a given resource should have the same side effects. Idempotence belongs to the realm of semantics. Just as a compiler can only help detect syntax errors, the HTTP specification has no way to define it through syntactic mechanisms such as message formats. This may be one reason why it does not receive much attention. In practice, however, idempotence is a very important concept in distributed system design, and the distributed nature of HTTP also determines its importance in HTTP.


The safety of an HTTP method means that it does not change server state; in other words, it is read-only. Therefore, only OPTIONS, GET, and HEAD are safe; all others are unsafe.

![](https://img.halfrost.com/Blog/ArticleImage/89_2.png)

**POST and PATCH are not idempotent**.  
Two identical POST requests will create two resources on the server side, and they will have different URIs.  
The side effect of performing multiple PUT requests on the same URI is the same as performing one PUT request.  


## II. HTTP Status Codes


The first line of the  **response message**  returned by the server is the status line, which contains the status code and reason phrase, used to inform the client of the result of the request.

![](https://img.halfrost.com/Blog/ArticleImage/89_3.png)


### 1XX Informational

-  **100 Continue** ：Indicates that everything is normal so far, and the client can continue sending the request or ignore this response.

### 2XX Success

-  **200 OK** 

-  **204 No Content** ：The request has been successfully processed, but the returned response message does not contain an entity body. It is generally used when information only needs to be sent from the client to the server and no data needs to be returned.

-  **206 Partial Content** ：Indicates that the client made a range request. The response message contains the entity content for the range specified by Content-Range.

### 3XX Redirection

-  **301 Moved Permanently** ：Permanent redirection

-  **302 Found** ：Temporary redirection

-  **303 See Other** ：Has the same function as 302, but 303 explicitly requires the client to use the GET method to retrieve the resource.

- Note: Although the HTTP protocol specifies that, when redirecting under 301 or 302, the POST method must not be changed to GET, most browsers change POST to GET when redirecting under 301, 302, and 303.

-  **304 Not Modified** ：If the request message headers contain certain conditions, such as If-Match, If-ModifiedSince, If-None-Match, If-Range, or If-Unmodified-Since, and the conditions are not satisfied, the server returns the 304 status code.

-  **307 Temporary Redirect** ：Temporary redirection, similar in meaning to 302, but 307 requires that the browser not change the redirected request’s POST method to GET.

### 4XX Client Errors

-  **400 Bad Request** ：There is a syntax error in the request message.

-  **401 Unauthorized** ：This status code indicates that the request requires authentication information (BASIC authentication, DIGEST authentication). If a request has already been made previously, it indicates that user authentication failed.

-  **403 Forbidden** ：The request was rejected, and the server does not need to provide a detailed reason for the rejection.

-  **404 Not Found** 

### 5XX Server Errors

-  **500 Internal Server Error** ：An error occurred while the server was processing the request.

-  **503 Service Unavailable** ：The server is temporarily overloaded or undergoing downtime maintenance, and cannot process the request at this time.

------------------------------------------------------------

## RFC 2616 Status Codes

![](https://img.halfrost.com/Blog/ArticleImage/89_4.png)

>RFC2616 defines 40 HTTP status codes. webDAV (Web-based Distributed Authoring and Versioning) defines some special status codes in RFC4918 and RFC5842, and RFC2518, RFC2817, RFC2295, RFC2774, and RFC6585 additionally define some supplementary HTTP status codes. There are more than 60 in total. For specific links, see [HTTP status codes (Wikipedia)](https://zh.wikipedia.org/wiki/HTTP%E7%8A%B6%E6%80%81%E7%A0%81)


New status codes added by webDAV

![](https://img.halfrost.com/Blog/ArticleImage/89_5.png)

## III. MIME Media Content


HTTP carefully labels every type of object to be transmitted over the Web with a data format label called a MIME type. MIME (Multipurpose Internet Mail Extension) was originally designed to solve problems encountered when moving messages between different email systems. MIME works very well in email systems, so HTTP adopted it as well, using it to describe and label multimedia content.


RFC2045, “MIME: Format of Internet Message Bodies” (“MIME: Format of Internet Message Bodies”)


Common primary MIME types

![](https://img.halfrost.com/Blog/ArticleImage/89_6.png)


## IV. HTTP Message Structure

![](https://img.halfrost.com/Blog/ArticleImage/89_7.png)

![](https://img.halfrost.com/Blog/ArticleImage/89_8.png)

![](https://img.halfrost.com/Blog/ArticleImage/89_9.png)

![](https://img.halfrost.com/Blog/ArticleImage/89_10.png)

For example:
```http

General:

Request URL: https://github.com/halfrost
Request Method: GET
Status Code: 200 OK
Remote Address: 127.0.0.1:6152
Referrer Policy: no-referrer-when-downgrade


```


Response Headers:

![](https://img.halfrost.com/Blog/ArticleImage/89_11.png)


```http  

HTTP/1.1 200 OK
Date: Sun, 22 Apr 2018 15:47:27 GMT
Content-Type: text/html; charset=utf-8
Transfer-Encoding: chunked
Server: GitHub.com
Status: 200 OK
Cache-Control: no-cache
Vary: X-Requested-With
Set-Cookie: user_session=GYkmjrs9T6H9r16Gx85; path=/; expires=Sun, 06 May 2018 15:47:27 -0000; secure; HttpOnly
Set-Cookie: __Host-user_session_same_site=GYkmjre6H9r16Gx85; path=/; expires=Sun, 06 May 2018 15:47:27 -0000; secure; HttpOnly; SameSite=Strict
Set-Cookie: _gh_sess=OHppNS84T05ubXZFS2swUm9SUlBqdXNpWlA2bHZZ3alUyUGNLZ0pqMD0tLTNLWDI0K1pTUUFlaWJUVU5XUTJaNFE9PQ%3D%3D--74346822d2bf179f6ff73ce52c8b8606c8f78755; path=/; secure; HttpOnly
X-Request-Id: 855feee9-5be2-482f-911a-b0eb22d55088
X-Runtime: 0.170448
Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
X-Frame-Options: deny
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: origin-when-cross-origin, strict-origin-when-cross-origin
Expect-CT: max-age=2592000, report-uri="https://api.github.com/_private/browser/errors"
Content-Security-Policy: default-src 'none'; base-uri 'self'; block-all-mixed-content; child-src render.githubusercontent.com; connect-src 'self' uploads.github.com status.github.com collector.githubapp.com api.github.com www.google-analytics.com github-cloud.s3.amazonaws.com github-production-repository-file-5c1aeb.s3.amazonaws.com github-production-upload-manifest-file-7fdce7.s3.amazonaws.com github-production-user-asset-6210df.s3.amazonaws.com wss://live.github.com; font-src assets-cdn.github.com; form-action 'self' github.com gist.github.com; frame-ancestors 'none'; img-src 'self' data: assets-cdn.github.com identicons.github.com collector.githubapp.com github-cloud.s3.amazonaws.com *.githubusercontent.com; manifest-src 'self'; media-src 'none'; script-src assets-cdn.github.com; style-src 'unsafe-inline' assets-cdn.github.com
X-Runtime-rack: 0.175479
Content-Encoding: gzip
Vary: Accept-Encoding
X-GitHub-Request-Id: B706:3019:355B8D9:52B9B00:5ADCAE85


```


Request Headers:

![](https://img.halfrost.com/Blog/ArticleImage/89_12.png)


```http

GET /halfrost HTTP/1.1
Host: github.com
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.117 Mobile Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Referer: https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP.md
Accept-Encoding: gzip, deflate, br
Accept-Language: zh-CN,zh;q=0.9,en;q=0.8
Cookie: _octo=GH1.1.101205900.1486965233; logged_in=yes; dotcom_user=halfrost; _ga=GA1.2.183217117.1486965233; user_session=GYkmjrs9Ts80x85; __Host-user_session_same_site=GYkmjrs9THGx85; tz=Asia%2FShanghai; _gat=1; _gh_sess=S1JyM0tEbTVEcU50OXRERmUwOVlqRVZiQWp5SDlBeWt3RitrbEczRkxjaWVLWWNVc2k4YjhBTDVQT3BZajEwSGRJOEE2bz0tLVNLRHhiTlVDN2xEUXJ1OFM1ME1VeVE9PQ%3D%3D--59dc56a889d38d30125fbee36df9dab97e7a46c0


```
A request message consists of a request method, request URI, protocol version, optional request header fields, and a content entity.

A response message is basically composed of a protocol version, a status code (a numeric code indicating whether the request succeeded or failed), a reason phrase explaining the status code, optional response header fields, and an entity body.


### 1. General Headers


![](https://img.halfrost.com/Blog/ArticleImage/89_13.png)

The Cache-Control header is very powerful. Both servers and clients can use it to describe freshness, and in addition to lifetime or expiration time, many other directives are available. 

![](https://img.halfrost.com/Blog/ArticleImage/89_14.png)

> The difference between no-cache and no-store: no-cache means not using expired resources from cache; the cache will validate freshness with the origin server before processing the resource. no-store is what truly means no caching.


no-cache does not mean caching is completely disabled. Instead, it means the client will check the server-side Etag every time; if it is the same, it will not download the full resource from the server and will return a 304 Not Modified. (Maximum cache duration: 3 years)

no-store is what truly disables caching. It means the latest resource will be downloaded from the server every time. (Of course, in practice, it usually does not seem to be needed.)

The main difference between public and private is that, for pages involving user authentication, setting private means only the end-user browser will cache the response, while intermediate CDNs will not; setting public means it will be cached at every layer. By default, you do not need to set public, because max-age already indicates that each layer may cache it (in seconds). At this point, if the cache is hit, the client will no longer request the server to validate the Etag; it will directly return 200 (from disk).

Of course, because public caches at every layer, if a webpage has strong requirements for previewing modifications and updates, it is best not to use this caching strategy; otherwise, you will also need to refresh the CDN origin, which is troublesome.

If you need to choose a caching strategy, see the figure below:


![](https://img.halfrost.com/Blog/ArticleImage/89_15.png)

### HTTP Cache Control


![](https://img.halfrost.com/Blog/ArticleImage/89_16.png)

To address the issue that “the Expires time is relative to the server and cannot be guaranteed to be synchronized with the client time,” HTTP/1.1 introduced Cache-Control to define cache expiration time. Note: if both Expires and Cache-Control appear in a message, Cache-Control takes precedence.

In other words, the priority from highest to lowest is **Pragma -> Cache-Control -> Expires**.

![](https://img.halfrost.com/Blog/ArticleImage/89_17.png)

1. Expires / Cache-Control  
Expires uses an absolute point in time to identify the expiration time, so it is inevitably affected by time synchronization. Cache-Control solves this problem well by using a time interval. However, Cache-Control is only available in HTTP/1.1 and does not apply to HTTP/1.0, while Expires applies to both HTTP/1.0 and HTTP/1.1. Therefore, in most cases, sending both headers is a better choice. When the client can parse both headers, **it will prefer Cache-Control**.

2. Last-Modified / ETag  
Both request resources through some identifier value. If the server-side resource has not changed, the server automatically returns the HTTP 304 (Not Changed) status code with an empty body, thereby saving data transfer. When the resource changes, the returned response is similar to the first request. This ensures that resources are not repeatedly sent to the client, while also ensuring that when the server changes, the client can obtain the latest resource.  
Last-Modified uses the file’s last modification time as the file identifier. It cannot handle the case where a file is modified multiple times within one second, and as long as the file is modified—even if the actual file content has not changed—it will return the resource content again. ETag, as the “entity value of the requested variant,” can fully solve the problems of the Last-Modified header, but its calculation consumes server resources.

3. from-cache / 304    
Both Expires and Cache-Control have a problem: if the server-side resource is modified while it is still within the cache validity period, the client will not request the resource from the server (unless refreshed). This creates a resource version mismatch. A forced refresh will always initiate an HTTP request and return the resource content, regardless of whether the content has changed during that period. **Last-Modified and Etag, however, initiate a request every time a resource is requested; even for resources that will not change for a long time, there is still at least the cost of one request-response cycle**.

For all cacheable resources, it is critical to specify an Expires or Cache-Control max-age, as well as a Last-Modified or ETag. Using the former and the latter together allows them to complement each other well.  
**The former avoids having to initiate a request every time to validate resource freshness, while the latter ensures that when a resource has not changed, it does not need to be sent again**. In different user page-refresh behaviors, the combination of the two can also make good use of HTTP cache-control features. Whether the user enters a URI in the address bar and presses Enter to visit it, or clicks the refresh button, the browser can fully utilize cached content and avoid unnecessary requests and data transfer.

4. Avoiding 304

The approach is actually very simple: **it moves the server-side ETag theory to the frontend for use**. Static resources on the page are published in versioned form. A common method is to include an md5 string or timestamp in the filename or parameters:
```http
https://hm.baidu.com/hm.js?e23800c454aa573c0ccb16b52665ac26
http://tb1.bdstatic.com/tb/_/tbean_safe_ajax_94e7ca2.js
http://img1.gtimg.com/ninja/2/2016/04/ninja145972803357449.jpg
```
As you can see in the examples above, there are different approaches: some append an `md5` parameter to the URI, some use the `md5` value as part of the filename, and some place resources in a directory named after a feature version.

When the file has not changed, the browser can use the cached file directly without issuing a request. When the file changes, the file version changes as well, which changes the filename; the requested URL changes, and naturally the file is updated. This ensures that the client can receive newly modified files from the server in a timely manner. With this approach, you can extend the cache lifetime of static resources—especially image resources—to avoid those resources expiring too quickly, causing the client to frequently request them from the server and the server to return `304` responses (when `Last-Modified`/`Etag` is used).

![](https://img.halfrost.com/Blog/ArticleImage/89_18.png)

![](https://img.halfrost.com/Blog/ArticleImage/89_19.png)

Summary:

- When compatibility with HTTP/1.0 is required, use `Expires`; otherwise, you can consider using `Cache-Control` directly.
- Use `ETag` only when you need to handle multiple modifications within one second, or other cases that `Last-Modified` cannot handle; otherwise, use `Last-Modified`.
- For all cacheable resources, specify either `Expires` or `Cache-Control`, and also specify either `Last-Modified` or `Etag`.
- You can reduce `304` responses by identifying file versions in filenames and extending cache lifetimes.

------------------------------------------------------------------

The `Warning` header evolved from an HTTP/1.0 response header (`Retry-After`). This header typically warns the user about cache-related issues.

The format of the `Warning` header is as follows:
```http
Warning: [warning code][warning host：port number]"[warning message]"([date content])

```
HTTP/1.1 defines seven types of warnings. Warning codes are extensible, and new warning codes may be added in the future.

![](https://img.halfrost.com/Blog/ArticleImage/89_20.png)

### 2. Request Headers

### Informational Request Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_21.png)


### Accept Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_22.png)


Common Content Codings

Commonly used content codings include the following:

- gzip (GNU zip)  
  An encoding format generated by the gzip (GNU zip) file compression program (RFC1952). It uses the Lempel-Ziv algorithm (LZ77) and a 32-bit Cyclic Redundancy Check (CRC).
- compress (standard UNIX compression)  
  An encoding format generated by the UNIX file compression program compress. It uses the Lempel-Ziv-Welch algorithm (LZW).
- deflate (zlib)  
  An encoding format that combines the zlib format (RFC1950) with the deflate compression algorithm (RFC1951).
- identity (no encoding)  
  The default encoding format that performs no compression and leaves the representation unchanged.


### Conditional Request Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_23.png)

### Security Request Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_24.png)

 
### Proxy Request Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_25.png)

### 3. Response Headers

### Informational Response Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_26.png)

### Negotiation Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_27.png)

### Security Response Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_28.png)

The `HttpOnly` attribute of a Cookie is a Cookie extension that prevents JavaScript scripts from accessing the Cookie. Its primary purpose is to prevent cookie information theft via cross-site scripting (XSS) attacks.
```http
Set-Cookie: name-value;HttpOnly

```
Incidentally, this extension was not developed to prevent XSS.

### 4. Entity Headers


### Entity Informational Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_29.png)

### Content Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_30.png)


Because HTTP headers cannot record binary values, they must be processed with Base64 encoding. With an approach like Content-MD5, incidental changes to the content cannot be verified, nor can malicious tampering be detected. The reason is that if the content has been tampered with, it also means Content-MD5 can be recalculated and updated, and thus tampered with as well. Therefore, at the receiving stage, the client cannot tell that the message body and the Content-MD5 header field have already been tampered with.

### Entity Caching Headers

![](https://img.halfrost.com/Blog/ArticleImage/89_31.png)


If the two URIs are the same, it is difficult to specify the cached resource based on the URI alone. If repeated interruptions and reconnections occur during the download, the resource will be specified based on the ETag value.

ETag values are also divided into strong ETag values and weak ETag values:

Strong ETag value:

A strong ETag value changes whenever the entity undergoes even the slightest change.
```http  
ETag: "usagi-1234"

```
Weak ETag value:

A weak ETag value is used only to indicate whether resources are the same. The ETag value changes only when the resource has fundamentally changed and a difference is produced. In this case, `W/` is prepended to the beginning of the field value.
```http  
ETag: W/"usagi-1234"

```

### 5. Extension Headers


### (1) X-Frame-Options

The `X-Frame-Options` header field is an HTTP response header used to control whether website content can be displayed inside a `Frame` tag on another website. Its primary purpose is to prevent clickjacking attacks.

### (2) X-XSS-Protection

The `X-XSS-Protection` header field is an HTTP response header. It is a countermeasure against cross-site scripting (XSS) attacks and is used to enable or disable the browser’s XSS protection mechanism. `0`: disable XSS filtering; `1`: enable XSS filtering.

### (3) DNT

The `DNT` header field is an HTTP request header. `DNT` stands for `Do Not Track`, meaning refusal to have personal information collected; it is a way to indicate that the user refuses to be tracked for targeted advertising. `0`: consent to tracking; `1`: refuse tracking.

### (4) P3P

The `P3P` header field is an HTTP response header. By using P3P (The Platform for Privacy Preferences) technology, personal privacy information on websites can be represented in a form understandable only by programs, thereby helping protect user privacy.

>In HTTP and various other protocols, non-standard parameters have historically been prefixed with `X-` to distinguish them from standard parameters and make it possible for those non-standard parameters to serve as extensions. However, this crude approach does far more harm than good, so “RFC6648 - Deprecating the "X-" Prefix and Similar Constructs in Application Protocols” proposed discontinuing the practice. That said, existing uses of the `X-` prefix should not be required to change.


HTTP header fields define the behavior of caching proxies and non-caching proxies, and are divided into end-to-end headers and hop-by-hop headers.

- End-to-end headers: Headers in this category are forwarded to the final recipient of the corresponding request/response and must be stored in responses generated by caches. They are also required to be forwarded.
- Hop-by-hop headers: Headers in this category are valid only for a single forwarding step and are not forwarded through caches or proxies. In HTTP/1.1 and later, to use hop-by-hop headers, the `Connection` header field must be provided. (`Connection`, `Keep-Alive`, `Proxy-Authenticate`, `Proxy-Authorization`, `Trailer`, `TE`, `Transfer-Encoding`, and `Upgrade` are the eight hop-by-hop header fields; all other fields are end-to-end headers.)


## V. Improving HTTP Performance

### 1. Parallel Connections

Initiate concurrent HTTP requests over multiple TCP connections.

### 2. Persistent Connections 

Reuse TCP connections to eliminate the latency of connection setup and teardown. Persistent connections (HTTP Persistent Connections) are also known as HTTP keep-alive or HTTP connection reuse.

In HTTP/1.1, all connections are persistent by default. However, not all servers necessarily support persistent connections, so in addition to the server, the client must also support them.


### 3. Pipelined Connections 

Initiate concurrent HTTP requests over a shared TCP connection.

Persistent connections make it possible to send most requests in a pipelined manner. Previously, after sending a request, the client had to wait for and receive the response before sending the next request. With pipelining, the next request can be sent directly without waiting for the response.

For example, when requesting an HTML web page that contains 10 images, persistent connections can complete the requests faster than opening connections one by one. Pipelining is even faster than persistent connections. The more requests there are, the more obvious the time difference becomes.


### 4. Multiplexed Connections

Transmit request and response messages alternately (experimental stage).


## VI. Differences Between GET and POST

## Parameters

Both GET and POST requests can use additional parameters, but GET parameters appear in the URL as a query string, whereas POST parameters are stored in the message body (still transmitted in plaintext; they are simply stored in a different location than GET parameters).

Compared with POST, GET’s parameter-passing method is less secure because the parameters passed by GET are visible in the URL and may leak private information. In addition, GET only supports ASCII characters, so parameters in Chinese may become garbled, whereas POST supports standard character sets.
```http
GET /test/demo_form.asp?name1=value1&name2=value2 HTTP/1.1
```

```http
POST /test/demo_form.asp HTTP/1.1
Host: w3schools.com
name1=value1&name2=value2
```

## Safety

A safe HTTP method does not change server state; in other words, it is read-only.

The GET method is safe, while POST is not, because the purpose of POST is to send entity-body content. This content may be form data uploaded by a user; after the upload succeeds, the server may store that data in a database, so the state changes.

Safe methods, in addition to GET, include: HEAD and OPTIONS.

Unsafe methods, in addition to POST, include PUT and DELETE.

## Idempotency

An idempotent HTTP method has the same effect whether the same request is executed once or multiple times in succession, and the server state is the same as well. In other words, idempotent methods should not have side effects (except for statistical purposes). When implemented correctly, methods such as GET, HEAD, PUT, and DELETE are idempotent, while POST is not. All safe methods are also idempotent.

GET /pageX HTTP/1.1 is idempotent. When called multiple times in succession, the results received by the client are the same:
```http
GET /pageX HTTP/1.1
GET /pageX HTTP/1.1
GET /pageX HTTP/1.1
GET /pageX HTTP/1.1
```
POST /add_row HTTP/1.1 is not idempotent. If called multiple times, it will add multiple rows:
```http
POST /add_row HTTP/1.1
POST /add_row HTTP/1.1   -> Adds a 2nd row
POST /add_row HTTP/1.1   -> Adds a 3rd row
```
DELETE /idX/delete HTTP/1.1 is idempotent, even if the status codes received by different requests are not the same:
```http
DELETE /idX/delete HTTP/1.1   -> Returns 200 if idX exists
DELETE /idX/delete HTTP/1.1   -> Returns 404 as it just got deleted
DELETE /idX/delete HTTP/1.1   -> Returns 404
```

## Cacheable

To cache a response, the following conditions must be met:

1. The HTTP method of the request message itself is cacheable, including GET and HEAD; PUT and DELETE are not cacheable, and POST is not cacheable in most cases.
2. The status code of the response message is cacheable, including: 200, 203, 204, 206, 300, 301, 404, 405, 410, 414, and 501.
3. The Cache-Control header field of the response message does not specify that it must not be cached.

## XMLHttpRequest

To explain another difference between POST and GET, we first need to understand XMLHttpRequest:

> XMLHttpRequest is an API that provides clients with the ability to transfer data between the client and the server. It provides a simple way to retrieve data via a URL without refreshing the entire page. This allows a web page to update only part of the page without disrupting the user. XMLHttpRequest is heavily used in AJAX.

When using the POST method with XMLHttpRequest, the browser sends the Header first and then the Data. But not all browsers do this; for example, Firefox does not.


## 7. Comparison of HTTP Versions

## Differences Between HTTP/1.0 and HTTP/1.1

1. HTTP/1.1 uses persistent connections by default
2. HTTP/1.1 supports pipelining
3. HTTP/1.1 supports virtual hosts
4. HTTP/1.1 adds the 100 status code
5. HTTP/1.1 supports chunked transfer encoding
6. HTTP/1.1 adds the cache-control directive max-age

See the preceding sections for details.

## Differences Between HTTP/1.1 and HTTP/2.0

> [Introduction to HTTP/2](https://developers.google.com/web/fundamentals/performance/http2/?hl=zh-cn)

### 1. Multiplexing

HTTP/2.0 uses multiplexing, allowing a single TCP connection to handle multiple requests.

### 2. Header Compression

HTTP/1.1 headers carry a large amount of information, and they must be sent repeatedly every time. HTTP/2.0 requires both communicating parties to cache a header field table, thereby avoiding repeated transmission.

### 3. Server Push

When a client requests a resource, HTTP/2.0 can send related resources to the client as well, so the client does not need to initiate additional requests. For example, when the client requests the index.html page, the server also sends index.js to the client.

### 4. Binary Format

HTTP/1.1 parsing is text-based, whereas HTTP/2.0 uses a binary format.


## 8. CORS Cross-Origin

When a resource requests another resource from a domain or port different from the server where the resource itself resides, it initiates a cross-origin HTTP request.
 
For example, an HTML page on the site http://domain-a.com requests http://domain-b.com/image.jpg via the src of <img>. Many pages on the web load resources such as CSS stylesheets, images, and scripts from different domains.
 
For security reasons, browsers restrict cross-origin HTTP requests initiated from scripts. For example, XMLHttpRequest and the Fetch API follow the same-origin policy. This means that web applications using these APIs can request HTTP resources only from the same domain from which the application was loaded, unless CORS headers are used.

(Translator’s note: Cross-origin does not necessarily mean that the browser prevents a cross-site request from being initiated. It may also mean that the cross-site request is initiated successfully, but the returned result is blocked by the browser. The best example is the principle behind CSRF cross-site attacks: the request is sent to the backend server regardless of whether it is cross-origin! Note: Some browsers do not allow cross-origin access from an HTTPS domain to HTTP, such as Chrome and Firefox. These browsers block the request before it is sent, which is a special case.)
  
![](https://img.halfrost.com/Blog/ArticleImage/89_32.png)
  
The Web Applications Working Group under the W3C recommends a new mechanism: Cross-Origin Resource Sharing (CORS). This mechanism enables web application servers to support cross-site access control, making secure cross-site data transfer possible. It is important to note that this specification targets API containers (such as XMLHttpRequest or Fetch) to mitigate the risks of cross-origin HTTP requests. **CORS requires support from both the client and the server. Currently, all browsers support this mechanism. **

The cross-origin sharing standard allows cross-origin HTTP requests in the following scenarios:

- Cross-origin HTTP requests initiated by XMLHttpRequest or Fetch, as mentioned earlier.
- Web fonts (cross-origin font resources used via @font-face in CSS), so websites can publish TrueType font resources and allow only authorized websites to invoke them cross-site.
- WebGL textures
- Drawing Images/video frames to a canvas using drawImage
- Stylesheets (using CSSOM)
- Scripts (unhandled exceptions)

CORS can be divided into: simple requests, preflight requests, and requests with credentials.


### 1. Simple Requests

Some requests do not trigger a CORS preflight request. This article refers to such requests as “simple requests”. Note that this term is not part of the Fetch specification (where CORS is defined). If a request satisfies all of the following conditions, it can be considered a “simple request”:


(1). It uses one of the following methods:  

- GET
- HEAD
- POST

  
(2). The Fetch specification defines a set of CORS-safelisted request header fields; no other header fields outside this set may be set manually. The set is:

Accept  
Accept-Language  
Content-Language  
Content-Type (note the additional restrictions)  
DPR  
Downlink  
Save-Data  
Viewport-Width  
Width  

(3). The value of Content-Type is limited to one of the following three:  

- text/plain
- multipart/form-data
- application/x-www-form-urlencoded

(4). No event listeners are registered on any XMLHttpRequestUpload object in the request; the XMLHttpRequestUpload object can be accessed using the XMLHttpRequest.upload property.

(5). The request does not use a ReadableStream object.


In short, the two key points to remember are:

**(1) Only the GET, HEAD, or POST request methods are used. If POST is used to send data to the server, the data type (Content-Type) can only be one of application/x-www-form-urlencoded, multipart/form-data, or text/plain.  
(2) No custom request headers are used (such as X-Modified).**


Example:
```javascript

//For example, suppose a web app at http://foo.example wants to access resources at http://bar.other. The following JavaScript
//code should run on foo.example:    
var invocation = new XMLHttpRequest();
var url = 'http://bar.other/resources/public-data/';
function callOtherDomain() {
  if(invocation) {    
    invocation.open('GET', url, true);
    invocation.onreadystatechange = handler;
    invocation.send(); 
  }
}

```

![](https://img.halfrost.com/Blog/ArticleImage/89_33.png)


```http

//Let's see, in this scenario, what request the browser sends to the server and what the server returns to the browser:
GET /resources/public-data/ HTTP/1.1
Host: bar.other
User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1b3pre) Gecko/20081130 
Minefield/3.1b3pre
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Connection: keep-alive
Referer: http://foo.example/examples/access-control/simpleXSInvocation.html
Origin: http://foo.example //This request comes from http://foo.exmaple.
//The above is the request sent by the browser

HTTP/1.1 200 OK
Date: Mon, 01 Dec 2008 00:23:53 GMT
Server: Apache/2.0.61 
Access-Control-Allow-Origin: * //This indicates that the server accepts cross-site requests from any site. If set to http://foo.example, other sites cannot access resources at http://bar.other cross-site.
Keep-Alive: timeout=2, max=100
Connection: Keep-Alive
Transfer-Encoding: chunked
Content-Type: application/xml
//The above is the information returned by the server to the browser

```
In the following cases, the request will return the relevant response information:

- If the resource is publicly accessible (like any HTTP resource that allows GET access), returning the `Access-Control-Allow-Origin:*` header is sufficient, unless the request requires cookies or HTTP authentication information.  
- If access to the resource is restricted based on the same domain, or if the resource to be accessed requires credentials (or sets credentials), then it is necessary to filter the `ORIGIN` value in the request headers, or at least respond with the request’s origin (for example, `Access-Control-Allow-Origin:http://arunranga.com`).  
In addition, the `Access-Control-Allow-Credentials:TRUE` header will be sent; this will be discussed in a later section.

### 2. Preflight Requests

Unlike the simple requests described above, a “request that requires preflight” must first initiate a preflight request to the server using the OPTIONS method, in order to determine whether the server allows the actual request. The use of a “preflight request” prevents cross-origin requests from having unintended effects on the server’s user data.

A preflight request should be sent first when the request meets any of the following conditions:

(1). It uses any of the following HTTP methods:  

PUT  
DELETE  
CONNECT  
OPTIONS  
TRACE  
PATCH  

(2). It manually sets header fields outside the set of CORS-safelisted request headers. That set is:

Accept  
Accept-Language  
Content-Language  
Content-Type (but note the additional requirements below)  
DPR  
Downlink  
Save-Data  
Viewport-Width  
Width  

(3). The value of `Content-Type` is not one of the following:  

application/x-www-form-urlencoded  
multipart/form-data  
text/plain  

(4). Any number of event listeners are registered on the `XMLHttpRequestUpload` object in the request.  
(5). A `ReadableStream` object is used in the request.

Unlike the simple requests discussed above, a “preflight request” requires that an OPTIONS request first be sent to the target site to determine whether the cross-site request is safe and acceptable to that site. This is done because cross-site requests may modify or damage data on the target site. A request will be treated as a preflight request when it has the following characteristics:

**(1) The request is initiated with a method other than GET, HEAD, or POST. Or, POST is used, but the request data has a type other than application/x-www-form-urlencoded, multipart/form-data, or text/plain. For example, a request that uses POST to send XML data with a data type of application/xml or text/xml.  
(2) Custom request headers are used (for example, adding a header such as X-PINGOTHER).**

For example:
```javascript
var invocation = new XMLHttpRequest();
var url = 'http://bar.other/resources/post-here/';
var body = '{C}{C}{C}{C}{C}{C}{C}{C}{C}{C}Arun';
function callOtherDomain(){
  if(invocation){
    invocation.open('POST', url, true);
    invocation.setRequestHeader('X-PINGOTHER', 'pingpong');
    invocation.setRequestHeader('Content-Type', 'application/xml');
    invocation.onreadystatechange = handler;
    invocation.send(body); 
  }
}

```
As shown above, an XMLHttpRequest is used to create a POST request, a custom request header (`X-PINGOTHER: pingpong`) is added to that request, and the data type is specified as `application/xml`. Therefore, this request is a cross-origin request in the form of a “preflight request”. The browser sends a “preflight request” using OPTIONS. Based on the request parameters, Firefox 3.1 determines that it needs to send a “preflight request” to determine whether the server will accept the subsequent actual request. OPTIONS is a method in HTTP/1.1 used to obtain more information from the server, and it is a method that should not affect server data. Along with the OPTIONS request, the following two request headers are sent:
```http
Access-Control-Request-Method: POST
Access-Control-Request-Headers: X-PINGOTHER

```
Suppose the server returns the following partial information in a successful response:
```http
Access-Control-Allow-Origin: http://foo.example //Indicates that the server allows requests from http://foo.example
Access-Control-Allow-Methods: POST, GET, OPTIONS //Indicates that the server can accept the POST, GET, and OPTIONS request methods
Access-Control-Allow-Headers: X-PINGOTHER //Specifies a list of acceptable custom request headers. The server also needs to set one corresponding to the browser. Otherwise, the error Request header field X-Requested-With is not allowed by Access-Control-Allow-Headers in preflight response will occur
Access-Control-Max-Age: 1728000 //Tells the browser how long the response result for this "preflight request" remains valid. In the example above, 1728000 seconds means that for 20 days, when the browser handles cross-origin requests to this server, it can skip sending another "preflight request" and decide based on this result.

```
![](https://img.halfrost.com/Blog/ArticleImage/89_34.png)


### 3. Requests with Credentials

An interesting feature of Fetch and CORS is that credentials can be sent based on HTTP cookies and HTTP authentication information. In general, for cross-origin XMLHttpRequest or Fetch requests, browsers do not send credentials. To send credentials, you need to set a special flag on XMLHttpRequest.

In this example, a script from http://foo.example sends a GET request to http://bar.other and sets cookies:
```javascript
var invocation = new XMLHttpRequest();
var url = 'http://bar.other/resources/credentialed-content/';
    
function callOtherDomain(){
  if(invocation) {
    invocation.open('GET', url, true);
    invocation.withCredentials = true;
    invocation.onreadystatechange = handler;
    invocation.send(); 
  }
}

```
Line 7 sets the `withCredentials` flag of `XMLHttpRequest` to `true`, thereby sending Cookies to the server. Because this is a simple GET request, the browser will not issue a “preflight request” for it. However, if the server-side response does not include `Access-Control-Allow-Credentials: true`, the browser will not return the response content to the request initiator.

![](https://img.halfrost.com/Blog/ArticleImage/89_35.png)

Assuming the server responds successfully, part of the returned information is as follows:
```http
Access-Control-Allow-Origin: http://foo.example
Access-Control-Allow-Credentials: true
Set-Cookie: pageAccess=3; expires=Wed, 31-Dec-2008 01:34:53 GMT
```
If the response headers from bar.other do not include Access-Control-Allow-Credentials: true, the response will be ignored. Note in particular: when sending a response to a request with withCredentials, the server must specify the allowed requesting domain; it cannot use “\*”. In the example above, if the response header were Access-Control-Allow-Origin: \*, the response would fail. In this example, because the value of Access-Control-Allow-Origin is the specific requesting domain http://foo.example, the client returns the content containing credential information to the client. Also note that additional cookie information is created.


## 9. Comparison Between CORS and JSONP

- JSONP can only perform GET requests, whereas CORS supports all types of HTTP requests.

- With CORS, developers can use a standard XMLHttpRequest to send requests and retrieve data, providing better error handling than JSONP.

- JSONP is mainly supported by older browsers, which often do not support CORS, while the vast majority of modern browsers already support CORS.

- Compared with JSONP, CORS is undoubtedly more advanced, convenient, and reliable.


------------------------------------------------------

References:  
*An Illustrated Guide to HTTP*    
*HTTP: The Definitive Guide*    
[RFC2616](https://tools.ietf.org/html/rfc2616)  
[HTTP Access Control (CORS)](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Access_control_CORS)  
[A Detailed Explanation of Cross-Origin Resource Sharing (CORS)](http://www.ruanyifeng.com/blog/2016/04/cors.html)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/http/](https://halfrost.com/http/)