<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/131_0.png'>
</p>

# Common Questions About HTTP/2

The following are common questions about HTTP/2.

## I. General Questions

### 1. Why change HTTP?

HTTP/1.1 has served the Web for more than 15 years, but its shortcomings are starting to show. Loading web pages requires more resources than ever before (see [HTTP Archive’s page size statistics](http://httparchive.org/trends.php#bytesTotal&reqTotal)), and loading all of those resources efficiently is very difficult because, in practice, HTTP allows only one outstanding request per TCP connection.

In the past, browsers used multiple TCP connections to issue parallel requests. However, this has limitations. If too many connections are used, it becomes counterproductive (TCP congestion control is undermined, and the resulting congestion events harm both performance and the network), and fundamentally unfair (because the browser consumes many resources that arguably should not belong to it). At the same time, a large number of requests means a large amount of redundant data is sent “on the wire.”

Both factors mean that HTTP/1.1 requests carry a lot of associated overhead. Too many requests hurt performance.

This led the industry to adopt misunderstood “best practices,” such as image spriting, `data:` inlining, Domain Sharding, and Concatenation. These hacks indicate that the protocol itself has underlying problems and that many issues arise when using it.


### 2. Who developed HTTP/2?

HTTP/2 was developed by the [HTTP Working Group](https://httpwg.github.io/) of the [IETF](http://www.ietf.org/), the working group that maintains the HTTP protocol. It consists of many HTTP implementers, users, network operators, and HTTP experts.

Note that although our [mailing list](http://lists.w3.org/Archives/Public/ietf-http-wg/) is hosted on the W3C website, this is not a W3C effort. However, Tim Berners-Lee and the W3C TAG have kept in sync with the WG’s progress.

A large number of people contributed to this work. The most active participants include engineers from “large” projects such as Firefox, Chrome, Twitter, Microsoft’s HTTP stack, Curl, and Akamai, as well as many HTTP implementers for platforms such as Python, Ruby, and NodeJS.

To learn more about the IETF, see [The Tao of the IETF](http://www.ietf.org/tao.html). You can also see who contributed to the specification in GitHub’s contributor graph, and who is participating in the project in our [implementation list](https://github.com/http2/http2-spec/wiki/Implementations).


### 3. What is the relationship between HTTP/2 and SPDY?

When HTTP/2 first emerged and was discussed, SPDY was gradually gaining favor among implementers (such as Mozilla and nginx) and was seen as a major improvement over HTTP/1.x.

After a call for proposals and a selection process, [SPDY/2](http://tools.ietf.org/html/draft-mbelshe-httpbis-spdy-00) was chosen as the basis for HTTP/2. Since then, many changes have been made based on working group discussions and feedback from implementers. Throughout the process, SPDY’s core developers participated in the development of HTTP/2, including Mike Belshe and Roberto Peon. In February 2015, Google announced its plan to remove support for SPDY in favor of HTTP/2.


### 4. Is it HTTP/2.0 or HTTP/2?

The working group decided to remove the minor version (“.0”) because it caused a lot of confusion in HTTP/1.x. In other words, the HTTP version indicates only wire compatibility, not a feature set or “highlights.”


### 5. What are the main differences between HTTP/2 and HTTP/1.x?

At a high level, HTTP/2:

- is binary, rather than textual
- is fully multiplexed, rather than ordered and blocking
- can therefore use a single connection for parallelism
- uses header compression to reduce overhead
- allows servers to proactively "push" responses into the client cache


### 6. Why is HTTP/2 binary?

Compared with text protocols such as HTTP/1.x, binary protocols are more efficient to parse, more “compact,” and, most importantly, less error-prone, because they handle whitespace, capitalization, line endings, blank lines, and so on more consistently. For example, HTTP/1.1 defines [four different ways to parse a message](http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4). In HTTP/2, there is only one code path.

HTTP/2 is not usable through telnet, but we already have tool support, such as the [Wireshark plugin](https://bugs.wireshark.org/bugzilla/show_bug.cgi?id=9042).


### 7. Why does HTTP/2 need multiplexing?

HTTP/1.x has a problem known as “head-of-line blocking,” which means that, within a single connection, submitting only one request at a time is relatively efficient, while submitting more causes things to slow down.


HTTP/1.1 attempted to fix this problem with pipelining, but it did not fully solve it (larger or slower responses can still block others). In addition, because many intermediaries and servers do not handle pipelining correctly, it is difficult to deploy.

This forces clients to use various heuristics (often guesswork) to decide which requests should be submitted over which connections. Because the amount of data loaded by a page is usually 10 times (or more) the number of available connections, this seriously affects performance and often causes blocked requests to “pile up.”

Multiplexing solves these problems by allowing multiple request and response messages to be sent at the same time. It is even possible to interleave part of one message with another. In this case, the client needs only one connection to load a page.


### 8. Why only one TCP connection?

With HTTP/1, browsers open 4 to 8 connections per site. Many websites now use multiple origins, so a single page load can mean opening more than 30 connections.

Having one application open so many connections goes far beyond what TCP was originally designed for. Because each connection can carry a large amount of data, this creates a risk of buffer overflow in the intervening network, leading to network congestion events and retransmissions.

In addition, using so many connections also monopolizes many network resources. These resources are “stolen” from applications that “play by the rules” (VoIP is a good example).


### 9. What are the benefits of server push?

When a browser requests a page, the server sends the HTML in the response, and then must wait for the browser to parse the HTML and issue requests for all embedded resources before it can start sending JavaScript, images, and CSS.

Server push can avoid this server-side round-trip delay by “pushing” responses that it believes the client will need into the client’s cache.

However, “pushed” responses are not “magic”—if used incorrectly, they can harm performance. Correct use of Server Push is an active area of experimentation and research.


### 10. Why do we need header compression?

Mozilla’s Patrick McManus illustrated this vividly by calculating the effect of headers in an average page load.

Assume a page contains about 80 resources to load (a conservative number on today’s Web), and each request has 1400 bytes of headers (not uncommon, thanks to Cookie, Referer, and so on). It takes at least 7 to 8 round trips just to get those headers “on the wire.” This does not include response time—that is only the time needed to get them from the client.

This is caused by TCP slow start, which limits the amount of data sent on a new connection based on the number of acknowledged packets—effectively limiting the number of packets that can be sent during the first few round trips.

By contrast, even light compression of headers can allow those requests to be completed within a single round trip (or even a single packet).

This extra overhead is substantial, especially when considering its impact on mobile clients, where round-trip latency is often several hundred milliseconds even under good network conditions.


### 11. Why choose HPACK?

SPDY/2 proposed that each side use a separate GZIP context for header compression, an approach that was easy to implement and highly efficient.

Since then, an important attack, [CRIME](http://en.wikipedia.org/wiki/CRIME), has emerged. This attack targets compression streams (such as GZIP) used inside encrypted data.

With CRIME, an attacker who can inject data into an encrypted stream can “probe” the plaintext and recover it. Because this is the Web, JavaScript makes this possible, and there have already been cases where CRIME was used against TLS-protected HTTP resources to recover cookies and authentication tokens.

As a result, we could not use GZIP compression. Since we could not find another algorithm suitable for this use case that was safe to use, we created a new compression scheme specifically for headers. It operates in a coarse-grained compression mode; because HTTP headers usually do not change between messages, it can still provide reasonable compression efficiency while being safer.


### 12. Can HTTP/2 make Cookie (or other header fields) better?

This effort was chartered to work on a revision of the wire protocol—that is, how HTTP headers, methods, and so on are placed “on the wire” without changing HTTP semantics.

This is because HTTP is widely used. If we introduced a new state mechanism in this version of HTTP (such as examples discussed previously), or changed core methods (which, thankfully, has not been proposed), it would mean the new protocol was incompatible with the existing Web.

In particular, we want to be able to translate from HTTP/1 to HTTP/2 without losing any information. If we start “cleaning up” headers (and most people would agree that HTTP headers are messy), many interoperability problems with the existing Web will arise.

Doing so would only make adoption of the new protocol more difficult.

That said, the HTTP Working Group is responsible for all of HTTP, not just HTTP/2. This allows us to study new mechanisms that are independent of version, as long as they are backward-compatible with the existing Web.


### 13. What about non-browser HTTP users?

If non-browser applications are already using HTTP, they should be able to use HTTP/2 as well.

We previously received feedback that HTTP “APIs” can have good performance characteristics in HTTP/2, because APIs do not need to account for concerns such as request overhead in their design.

That said, the main focus of the improvements we are considering is the typical browsing use case, because it is the core use case for the protocol.

Our charter states:
```c
The resulting specification(s) are expected to meet these goals for common existing deployments of HTTP; in particular, Web browsing (desktop and mobile), non-browsers ("HTTP APIs"), Web serving (at a variety of scales), and intermediation (by proxies, corporate firewalls, "reverse" proxies and Content Delivery Networks). Likewise, current and future semantic extensions to HTTP/1.x (e.g., headers, methods, status codes, cache directives) should be supported in the new protocol.

The specifications being developed need to meet the functional requirements of HTTP as it is now widely deployed; specifically, they mainly include Web browsing (desktop and mobile), non-browsers (in the form of “HTTP APIs”), Web services (at broad scale), and various network intermediaries (implemented through proxies, corporate firewalls, reverse proxies, and content delivery networks). Likewise, current and future semantic extensions to HTTP/1.x (e.g., headers, methods, status codes, cache directives) should all be supported in the new protocol.


Note that this does not include uses of HTTP where non-specified behaviours are relied upon (e.g., connection state such as timeouts or client affinity,and "interception" proxies); these uses may or may not be enabled by the final product.

It is worth noting that this does not include scenarios where HTTP is used in reliance on unspecified behavior (such as timeouts, connection state, and interception proxies). These may or may not be enabled by the final product.

```

### 14. Does HTTP/2 require encryption?

No. After extensive discussion, the working group did not reach consensus that the new protocol must use encryption (such as TLS).

However, some implementations have stated that they support HTTP/2 only when it is used over an encrypted connection, and currently no browser supports unencrypted HTTP/2.


### 15. How does HTTP/2 improve security?

HTTP/2 defines a required TLS profile; this includes the version, a cipher suite blacklist, and the extensions to be used.

For details, see [the specification](http://http2.github.io/http2-spec/#TLSUsage).

Other mechanisms have also been discussed, such as using TLS for HTTP:// URLs (so-called “opportunistic encryption”); see [RFC 8164](https://tools.ietf.org/html/rfc8164).


### 16. Can I use HTTP/2 now?

In browsers, the latest versions of Edge, Safari, Firefox, and Chrome all support HTTP/2. Other Blink-based browsers will also support HTTP/2 (such as Opera and Yandex Browser). For more details, see [here](http://caniuse.com/#feat=http2).

Several servers are also available (including beta support provided by major sites from [Akamai](https://http2.akamai.com/), [Google](https://google.com/), and [Twitter](https://twitter.com/)), along with many open-source implementations that can be deployed and tested.

For more details, see the [implementation list](https://github.com/http2/http2-spec/wiki/Implementations).


### 17. Will HTTP/2 replace HTTP/1.x?

The working group’s goal is to make HTTP/2 available to those who use HTTP/1.x, so they can benefit from what HTTP/2 provides. They have stated that, because people deploy proxies and servers in different ways, we cannot force the entire world to migrate, so HTTP/1.x is likely to remain in use for some time.

### 18. Will there be HTTP/3?

If the negotiation mechanism introduced by HTTP/2 works well, supporting new versions of HTTP will be easier than it was in the past.


## II. Implementation-related questions

### 1. Why do the rules revolve around Continuation of HEADERS frames?

Continuation exists because a single value (such as Set-Cookie) may exceed 16KiB-1, which means it cannot fit into a single frame. It was decided that the least error-prone way to handle this problem was to require all header data to be delivered as a sequence of frames, one after another, which also makes decoding and buffer management easier.


### 2. What is the minimum or maximum size of HPACK state?

The receiver always controls the amount of memory used in HPACK, and can set it as low as 0; the maximum is related to the largest representable integer in the SETTINGS frame (currently 2^32-1).


### 3. How can HPACK state be avoided?

Send a SETTINGS frame that sets the state size (SETTINGS\_HEADER\_TABLE\_SIZE) to 0, then RST all streams until a SETTINGS frame with the ACK bit set is received.


### 4. Why is there only one compression/flow-control context?

Briefly:

The original proposal included the concept of stream groups, which could share context, flow control, and so on. Although this would have benefited proxies (and the experience of proxy users), it added a considerable amount of complexity. So we decided to start with something simple, see how bad the problems actually are, and address them in a future version of the protocol if necessary.


### 5. Why does HPACK have an EOS symbol?

HPACK’s Huffman coding pads Huffman-encoded strings to the next byte boundary for CPU efficiency and security reasons; any given string may require between 0 and 7 bits of padding.

If Huffman decoding is considered in isolation, any symbol longer than the required padding would work. However, HPACK is designed to allow Huffman-encoded strings to be compared byte-for-byte. By requiring the bits of the EOS symbol to be used for padding, we ensure that users can perform byte comparisons on Huffman-encoded strings to determine equality. In turn, this means many headers can be parsed without requiring Huffman decoding.


### 6. Can HTTP/2 be implemented without implementing HTTP/1.1?

Yes, in most cases.

For HTTP/2 over TLS (h2), if you do not implement the http1.1 ALPN identifier, you do not need to support any HTTP/1.1 functionality.

For HTTP/2 over TCP (h2c), you need to implement the initial Upgrade request.

Clients that support only h2c need to generate either an OPTIONS request for “*” or a HEAD request for “/”; these are relatively safe and easy to construct. Clients that want to implement only HTTP/2 will need to treat HTTP/1.1 responses without a 101 status code as errors.

Servers that support only h2c can use a fixed 101 response to accept a request containing the Upgrade header field. Requests without the h2c upgrade token can be rejected with a 505 (HTTP Version Not Supported) status code that includes an Upgrade header field. Servers that do not want to process HTTP/1.1 responses should, immediately after sending the connection preface, reject stream 1 with the REFUSED\_STREAM error code to encourage the client to retry the request over the upgraded HTTP/2 connection.


### 7. Is the priority example in Section 5.3.2 incorrect?

No, it is correct. Stream B has a weight of 4, and stream C has a weight of 12. To determine the proportion of available resources each of these streams receives, add all the weights together (16), then divide each stream’s weight by the total weight. Therefore, stream B receives one quarter of the available resources, and stream C receives three quarters. Thus, as stated in the specification: [stream B ideally receives one third of the resources allocated to stream C](http://http2.github.io/http2-spec/#rfc.section.5.3.2).


### 8. Does an HTTP/2 connection need TCP\_NODELAY?

It may. Even for a client implementation that uses only a single stream to download a large amount of data, it is still necessary to send some packets in the opposite direction to achieve maximum transfer speed. If TCP\_NODELAY is not set (and the Nagle algorithm is still allowed), outgoing packets may be held for a period of time so they can be coalesced with subsequent packets.

For example, if such a packet tells the peer that more window is available for sending data, delaying its transmission by a few milliseconds (or longer) can have a serious impact on high-speed connections.

## III. Deployment questions

### 1. If HTTP/2 is encrypted, how do I debug it?

There are many ways to access application data, but the simplest is to use [NSS keylogging](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS/Key_Log_Format) together with the Wireshark plugin (included in the latest development versions). This method works for both Firefox and Chrome.


### 2. How do I use HTTP/2 server push?


HTTP/2 server push allows a server to provide content to a client without waiting for a request. This can improve resource retrieval time, especially for connections with a large [bandwidth-delay product](https://en.wikipedia.org/wiki/Bandwidth-delay_product), where network round-trip time accounts for most of the time spent on the resource.

It may be unwise to push resources that vary based on request content. Currently, browsers only accept pushed requests if, had they not done so, they would have made a matching request (see [Section 4 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-4)).

Some caches do not take variations in all request header fields into account, even when they appear in the Vary header field. To maximize the likelihood that pushed resources will be accepted, content negotiation is the best option. Content negotiation based on the accept-encoding header field is widely respected by caches, but other header fields may not be well supported.


------------------------------------------------------

Reference：  

[HTTP/2 Frequently Asked Questions](https://http2.github.io/faq/)    

> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
> 
> Source: [https://halfrost.com/http2-frequently-asked-questions/](https://halfrost.com/http2-frequently-asked-questions/)
>