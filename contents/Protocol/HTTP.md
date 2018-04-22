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

------------------------------------------------------------

## RFC 2616 状态码

| 状态码 | 类别 | 原因短语 |含义||
| :---: | :---: | :---: |:---: |:---:|
| 100 | Informational（信息性状态码） | Continue（继续） |收到了请求的起始部分，客户端应该继续请求。|❤|
| 101 | Informational（信息性状态码） | Switching Protocols（切换协议）|服务器正根据客户端的指示将协议切换成 Update 首部列出的协议。|❤|
|||||
| 200 | Success（成功状态码）| OK |服务器已成功处理请求|❤|
| 201 | Success（成功状态码）|Created（已创建）| 对那些要服务器创建对象的请求来说，资源已创建完毕|
| 202 | Success（成功状态码）|Accepted（已接受）| 请求已接受，但服务器尚未处理|
| 203 | Success（成功状态码）|Non-Authoritative Information（非权威信息）| 服务器已将事务成功处理，只是实体首部包含的信息不是来自原始服务器，而是来自资源的副本|
| 204 | Success（成功状态码）|No Content（没有内容）| 响应报文包含一些首部和一个状态行，**但不包含实体的主体内容**，**一般在只需要从客户端往服务器发送信息，而对客户端不需要发送新信息内容的情况下使用**|❤|
| 205 | Success（成功状态码）|Reset Content（重置内容）| 另一个主要用于浏览器的代码。意思是浏览器应该重置当前页面上所有的 HTML 表单 |
| 206 | Success（成功状态码） |Partial Content（部分内容）| 部分请求成功，<br>**响应报文中包含由 Content-Range 指定范围的实体内容**|❤|
|||||
|300| Redirection（重定向状态码） |Multiple Choices（多项选择）| 客户端请求了实际指向多个资源的 URL。这个代码是和一个选项列表一起返回的，然后用户就可以 选择他希望使用的选项了| 
|301| Redirection（重定向状态码） | Moved Permanently（永久移除）| **永久性重定向**，请求的 URL 已移走。响应中应该包含一个 Location URL，说明资源现在所处的位置|❤|
|302| Redirection（重定向状态码）| Found（已找到）| **临时性重定向**，与状态码 301 类似， 但这里的移除是临时的。客户端应该用 Location 首部给出的 URL 对资源进行临时定位|❤|
|303| Redirection（重定向状态码）| See Other（参见其他）| 告诉客户端应该用另一个 URL 获取资源。这个新的 URL 位于响应报文的 Location 首部。303 状态码 和 302 状态码有相同的功能，**但是 303 明确表示客户端应采用 GET 方法获取资源**。|❤|
||||当 301、302、303 响应状态码返回时，几乎所有的浏览器都会把 POST 改成 GET，并删除请求报文内的主体，之后请求会自动再次发送。<br>301、302 标准是禁止将 POST 方法改变成 GET 方法的，但实际使用时大家都会这么做||
|304| Redirection（重定向状态码）| Not Modified（未修改）| 该状态码表示客户端发送附带条件的请求时，服务器允许请求访问资源，但因发生请求未满足条件的情况后，直接返回 304 Not Modified（服务器端资源未改变，可直接使用客户端未过期的缓存）304 状态码返回时，不包含任何响应的主体部分。**304 虽然被划分在 3XX 类别中，但是和重定向一点关系也没有**|❤|
||||（附带条件的请求是指采用 GET 方法的请求报文中包含 If-Match，If-Modified-Since,If-None-Match，If-Range，If-Unmodified-Since 中任一首部）||
|305| Redirection（重定向状态码）| Use Proxy（使用代理）| 必须通过代理访问 资源，代理的位置是在 Location 首部中给出的|
|306|（未使用）||这个状态码当前并未使用|
|307| Redirection（重定向状态码）| Temporary Redirect（临时重定向）| 和状态码 302 类似。但客户端应该用 Location 首部给出的 URL 对资源进行临时定位。<br>307 会遵守浏览器标准，不会从 POST 变成 GET|❤|
|||||
|400|Client Error（客户端错误状态码）| Bad request（坏请求）| 告诉客户端它发送了一条异常请求|❤|
|401|Client Error（客户端错误状态码）| Unauthorized（未授权）| 与适当的首部一起返回，在客户端获得资源访问权之前，请它进行身份认证|❤|
|402|Client Error（客户端错误状态码）| Payment Required（要求付款）| 当前此状态码并未使用，是为未来使用预留的 |
|403|Client Error（客户端错误状态码）| Forbidden（禁止）| 服务器拒绝了请求|❤| 
|404|Client Error（客户端错误状态码）| Not Found（未找到）| 服务器无法找到 所请求的 URL|❤|
|405|Client Error（客户端错误状态码）| Method Not Allowed（不允许使用的方法）|请求中有一个所请求的 URI 不支持的方法。响应中应该包含一个 Allow 首部，以告知客户端所请求的资源支持使用哪些方法| 
|406|Client Error（客户端错误状态码）| Not Acceptable（无法接受）| 客户端可以指定一些参数来说明希望接受哪些类型的实体。服务器没有资源与客户端可接受的 URL 相匹配时可使用此代码| 
|407|Client Error（客户端错误状态码）| Proxy Authentication Required（要求进行代理认证）|和状态码 401 类似，但用于需要进行资源认证的代理服务器|
|408|Client Error（客户端错误状态码）| Request Timeout（请求超时）| 如果客户端完成其请求时花费的时间太长，服务器可以回送这个状态码并关闭连接 |
|409|Client Error（客户端错误状态码）| Conflict（ 冲突）| 发出的请求在资源上造成了一些冲突| 
|410|Client Error（客户端错误状态码）| Gone（消失了）| 除了服务器曾持有这些资源之外，与状态码 404 类似 |
|411|Client Error（客户端错误状态码）| Length Required（要求长度指示）| 服务器要求在请求报文中包含 Content- Length 首部时会使用这个代码。发起的请求中若没有 Content-Length 首部，服务器 是不会接受此资源请求的| 
|412|Client Error（客户端错误状态码）|Precondition Failed（先决条件失败）| 如果客户端发起了一个条件请求， 如果服务器无法满足其中的某个条件，就返回这个响应码| 
|413|Client Error（客户端错误状态码）| Request Entity Too Large（请求实体太大）| 客户端发送的实体主体部分比 服务器能够或者希望处理的要大|
|414|Client Error（客户端错误状态码）| Request URI Too Long（请求 URI 太长）| 客户端发送的请求所携带的请求 URL 超过了服务器能够或者希望处理的长度|
|415 |Client Error（客户端错误状态码）|Unsupported Media Type（不支持的媒体类型）| 服务器无法理解或不支持客户端所发送的实体的内容类型| 
|416 |Client Error（客户端错误状态码）|Requested Range Not Satisfiable（所请求的范围未得到满足）| 请求报文请求的是某范围内的指定资源，但那个范围无效，或者未得到满足 |
|417|Client Error（客户端错误状态码）| Expectation Failed（无法满足期望）| 请求的 Expect 首部包含了一个预期内容，但服务器无法满足|
|||||
|500|Server Error（服务器错误状态码）| Internal Server Error（内部服务器错误）| 服务器遇到了一个错误，使其无法为请求提供服务|❤|
|501 |Server Error（服务器错误状态码）|Not Implemented（未实现）| 服务器无法满足客户端请求的某个功能 |
|502 |Server Error（服务器错误状态码）|Bad Gateway（网关故障）| 作为代理或网关使用的服务器遇到了来自响应链中上游的无效响应 |
|503|Server Error（服务器错误状态码）| Service Unavailable（未提供此服务）| 服务器目前无法为请求提供服务，但过一段时间就可以恢复服务|❤|
|504|Server Error（服务器错误状态码） |Gateway Timeout（网关超时）| 与状态码 408 类似，但是响应来自网关或代理，此网关或代理在等待另一台服务器的响应时出现了超时 |
|505|Server Error（服务器错误状态码）| HTTP Version Not Supported（不支持的 HTTP 版本）| 服务器收到的请求是以它不支持或不愿支持的协议版本表示的|

>在 RFC2616 中定义了 40 种 HTTP 状态码，webDAV ( Web-based Distributed Authoring and Versioning，基于万维网的分布式创作和版本控制)在 RFC4918 和 RFC5842 中，定义了一些特殊的状态码，在 RFC2518、RFC2817、RFC2295、RFC2774、RFC6585 中还额外定义了一些附加的 HTTP 状态码。总共有 60+ 种。具体链接可以见 [HTTP状态码 (wikipedia)](https://zh.wikipedia.org/wiki/HTTP%E7%8A%B6%E6%80%81%E7%A0%81)


------------------------------------------------------

Reference：  
《图解 HTTP》
《HTTP 权威指南》


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()