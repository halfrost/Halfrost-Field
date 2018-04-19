<p align='center'>
<img src='../images/HTTP_logo.png'>
</p>



## HTTP 状态码


服务器返回的  **响应报文**  中第一行为状态行，包含了状态码以及原因短语，用来告知客户端请求的结果。

| 状态码 | 类别 | 原因短语 |
| :---: | :---: | :---: |
| 1XX | Informational（信息性状态码） | 接收的请求正在处理 |
| 2XX | Success（成功状态码） | 请求正常处理完毕 |
| 3XX | Redirection（重定向状态码） | 需要进行附加操作以完成请求 |
| 4XX | Client Error（客户端错误状态码） | 服务器无法处理请求 |
| 5XX | Server Error（服务器错误状态码） | 服务器处理请求出错 |




## 1XX 信息

-  **100 Continue** ：表明到目前为止都很正常，客户端可以继续发送请求或者忽略这个响应。

## 2XX 成功

-  **200 OK** 

-  **204 No Content** ：请求已经成功处理，但是返回的响应报文不包含实体的主体部分。一般在只需要从客户端往服务器发送信息，而不需要返回数据时使用。

-  **206 Partial Content** ：表示客户端进行了范围请求。响应报文包含由 Content-Range 指定范围的实体内容。

## 3XX 重定向

-  **301 Moved Permanently** ：永久性重定向

-  **302 Found** ：临时性重定向

-  **303 See Other** ：和 302 有着相同的功能，但是 303 明确要求客户端应该采用 GET 方法获取资源。

- 注：虽然 HTTP 协议规定 301、302 状态下重定向时不允许把 POST 方法改成 GET 方法，但是大多数浏览器都会在 301、302 和 303 状态下的重定向把 POST 方法改成 GET 方法。

-  **304 Not Modified** ：如果请求报文首部包含一些条件，例如：If-Match，If-ModifiedSince，If-None-Match，If-Range，If-Unmodified-Since，如果不满足条件，则服务器会返回 304 状态码。

-  **307 Temporary Redirect** ：临时重定向，与 302 的含义类似，但是 307 要求浏览器不会把重定向请求的 POST 方法改成 GET 方法。

## 4XX 客户端错误

-  **400 Bad Request** ：请求报文中存在语法错误。

-  **401 Unauthorized** ：该状态码表示发送的请求需要有认证信息（BASIC 认证、DIGEST 认证）。如果之前已进行过一次请求，则表示用户认证失败。

-  **403 Forbidden** ：请求被拒绝，服务器端没有必要给出拒绝的详细理由。

-  **404 Not Found** 

## 5XX 服务器错误

-  **500 Internal Server Error** ：服务器正在执行请求时发生错误。

-  **503 Service Unavilable** ：服务器暂时处于超负载或正在进行停机维护，现在无法处理请求。



| 状态码 | 类别 | 原因短语 |含义|
| :---: | :---: | :---: |:---: |
| 100 | Informational（信息性状态码） | Continue（继续） |收到了请求的起始部分，客户端应该继续请求。|
| 101 | Informational（信息性状态码） | Switching Protocols（切换协议）|服务器正根据客户端的指示将协议切换成 Update 首部列出的协议。|
|||||
| 200 | Success（成功状态码）| OK |服务器已成功处理请求|
| 201 | Success（成功状态码）|Created（已创建）| 对那些要服务器创建对象的请求来说，资源已创建完毕|
| 202 | Success（成功状态码）|Accepted（已接受）| 请求已接受，但服务器尚未处理|
| 203 | Success（成功状态码）|Non-Authoritative Information（非权威信息）| 服务器已将事务成功处理，只是实体首部包含的信息不是来自原始服务器，而是来自资源的副本|
| 204 | Success（成功状态码）|No Content（没有内容）| 响应报文包含一些首部和一个状态行，但不包含实体 的主体内容|
| 205 | Success（成功状态码）|Reset Content（重置内容）| 另一个主要用于浏览器的代码。意思是浏览器应该重置当前页面上所有的 HTML 表单 |
| 206 | Success（成功状态码） |Partial Content（部分内容）| 部分请求成功|
|||||
| 3XX | Redirection（重定向状态码） | 需要进行附加操作以完成请求 ||
| 4XX | Client Error（客户端错误状态码） | 服务器无法处理请求 ||
| 5XX | Server Error（服务器错误状态码） | 服务器处理请求出错 ||



------------------------------------------------------

Reference：  



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()