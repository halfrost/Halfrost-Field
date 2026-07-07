+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTP", "HTTP/2"]
date = 2019-05-26T07:25:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/131_0.png"
slug = "http2-frequently-asked-questions"
tags = ["Protocol", "HTTP", "HTTP/2"]
title = "Common Issues in HTTP/2"

+++


The following are frequently asked questions about HTTP/2.

## I. General Questions

### 1. Why revise HTTP?

HTTP/1.1 has served the Web for more than 15 years, but its shortcomings are beginning to show. Loading web pages requires more resources than ever before (see [HTTP Archive’s page size statistics](http://httparchive.org/trends.php#bytesTotal&reqTotal)), and loading all of those resources efficiently is very difficult because, in practice, HTTP allows only one outstanding request per TCP connection.

In the past, browsers used multiple TCP connections to issue parallel requests. However, this has limitations. If too many connections are used, the result is counterproductive (TCP congestion control is undermined, and the resulting congestion events hurt performance and the network), and it is fundamentally unfair (because the browser consumes many resources that should not belong to it). At the same time, a large number of requests means there is a great deal of duplicate data “on the wire.”

Both of these factors mean HTTP/1.1 requests carry a lot of associated overhead. If there are too many requests, performance suffers.

This led the industry to adopt misunderstood “best practices,” doing things such as image spriting, data: inlining, Domain Sharding, and Concatenation. These hacks indicate that there are underlying problems in the protocol itself, and they cause many issues in practice.


### 2. Who developed HTTP/2?

HTTP/2 was developed by the [HTTP Working Group](https://httpwg.github.io/) of the [IETF](http://www.ietf.org/), the working group that maintains the HTTP protocol. It consists of many HTTP implementers, users, network operators, and HTTP experts.

Note that although our [mailing list](http://lists.w3.org/Archives/Public/ietf-http-wg/) is hosted on the W3C site, this is not a W3C effort. However, Tim Berners-Lee and the W3C TAG keep in sync with the WG’s progress.

A large number of people contributed to this work. The most active participants include engineers from “large” projects such as Firefox, Chrome, Twitter, Microsoft’s HTTP stack, Curl, and Akamai, as well as many HTTP implementers for languages and platforms such as Python, Ruby, and NodeJS.

To learn more about the IETF, see the [Tao of the IETF](http://www.ietf.org/tao.html). You can also see who contributed to the specification in GitHub’s contributor graphs, and who is involved in the project in our [implementation list](https://github.com/http2/http2-spec/wiki/Implementations).


### 3. What is the relationship between HTTP/2 and SPDY?

When HTTP/2 first appeared and was being discussed, SPDY was gradually gaining favor among implementers (such as Mozilla and nginx), and was regarded as a major improvement over HTTP/1.x.

After a call for proposals and a selection process, [SPDY/2](http://tools.ietf.org/html/draft-mbelshe-httpbis-spdy-00) was chosen as the basis for HTTP/2. Since then, many changes have been made based on working group discussions and implementer feedback. Throughout the process, SPDY’s core developers were involved in the development of HTTP/2, including Mike Belshe and Roberto Peon. In February 2015, Google announced its plan to remove support for SPDY in favor of HTTP/2.


### 4. Is it HTTP/2.0 or HTTP/2?

The working group decided to drop the minor version (“.0”) because it caused a lot of confusion in HTTP/1.x. In other words, an HTTP version indicates only wire compatibility, not a feature set or “highlights.”


### 5. What are the main differences between HTTP/2 and HTTP/1.x?

In the higher version of HTTP/2:

- It is binary, rather than textual
- It is fully multiplexed, rather than ordered and blocking
- It can therefore use a single connection for parallel processing
- It uses header compression to reduce overhead
- It allows servers to proactively “push” responses into the client cache


### 6. Why is HTTP/2 binary?

Compared with textual protocols such as HTTP/1.x, binary protocols are more efficient to parse, more “compact,” and, most importantly, less error-prone than textual protocols, because they help with handling whitespace, capitalization, line endings, blank lines, and so on. For example, HTTP/1.1 defines [four different ways to parse messages](http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.4). In HTTP/2, there is only one code path.

HTTP/2 is not usable via telnet, but we already have tool support, such as the [Wireshark plugin](https://bugs.wireshark.org/bugzilla/show_bug.cgi?id=9042).


### 7. Why does HTTP/2 need multiplexing?

HTTP/1.x has a problem known as “head-of-line blocking,” which means that within a single connection, submitting only one request at a time is relatively efficient; adding more makes things slower.


HTTP/1.1 tried to fix this problem with pipelining, but it did not fully solve it (larger or slower responses still block others). In addition, because many intermediaries and servers do not handle pipelining correctly, it is difficult to deploy.

This forces clients to use various heuristics (often guesswork) to decide which requests to submit over which connections. Because the amount of data loaded by a page is usually 10 times (or more) the number of available connections, this has a serious impact on performance and often causes “floods” of blocked requests.

Multiplexing solves these problems by allowing multiple request and response messages to be sent at the same time. It is even possible to interleave part of one message with another message. In this case, the client needs only one connection to load a page.


### 8. Why only one TCP connection?

With HTTP/1, browsers need 4 to 8 connections per site. Today many websites use multiple origins, so this may mean that loading a single page opens more than 30 connections.

A single application opening so many connections is far beyond what TCP was originally designed for. Because each connection responds with a large amount of data, this creates a risk of buffer overflow in intermediate networks, leading to congestion events and retransmissions.

In addition, using so many connections seizes a large number of network resources. These resources are “stolen” from “well-behaved” applications (VoIP is a good example).


### 9. What are the benefits of server push?

When a browser requests a page, the server sends the HTML in the response, and then has to wait for the browser to parse the HTML and issue requests for all embedded resources before it can start sending JavaScript, images, and CSS.

Server push can avoid this round-trip delay on the server by “pushing” responses it believes the client will need into the client’s cache.

However, “pushed” responses are not “magic”—if used incorrectly, they can harm performance. Correct use of Server Push is an ongoing area of experimentation and research.


### 10. Why do we need header compression?

Mozilla’s Patrick McManus illustrated this vividly by calculating the effect of headers on an average page load.

Assume a page contains about 80 resources to load (a conservative number on today’s Web), and each request has 1400 bytes of headers (not uncommon, thanks to Cookie, Referer, and so on). It takes at least 7 to 8 round trips to get those headers “on the wire.” This does not include response time—that is only the time required to get them from the client.

This is caused by TCP slow start, which limits the amount of data that can be sent on a new connection based on the number of acknowledged packets—effectively limiting the number of packets that can be sent in the first few round trips.

By contrast, even modest compression of headers allows these requests to be handled in a single round trip (or even a single packet).

This extra overhead is substantial, especially when considering the impact on mobile clients, where round-trip latency is typically several hundred milliseconds even under good network conditions.


### 11. Why choose HPACK?

SPDY/2 proposed that each side use a separate GZIP context for header compression, an approach that was easy to implement and highly efficient.

Since then, an important attack method, [CRIME](http://en.wikipedia.org/wiki/CRIME), has emerged. It can attack compression streams (such as GZIP) used inside encrypted data.

With CRIME, an attacker is able to inject data into an encrypted stream and can “probe” the plaintext and recover it. Because this is the Web, JavaScript makes this possible, and there have already been cases of recovering cookies and authentication tokens (Token) from TLS-protected HTTP resources by using CRIME.

As a result, we could not use GZIP compression. After failing to find another algorithm suitable for this use case and safe to use, we created a new compression scheme specifically for headers that operates with a coarse-grained compression model. Because HTTP headers typically do not change between messages, it can still provide reasonable compression efficiency while being more secure.


### 12. Can HTTP/2 make Cookie (or other header fields) better?

This effort was chartered to work on a revision of the wire protocol—that is, how HTTP headers, methods, and so on can be put “on the wire” without changing HTTP semantics.

This is because HTTP is widely used. If we introduced a new state mechanism in this version of HTTP (as in examples discussed previously) or changed core methods (thankfully, this has not been proposed), it would mean that the new protocol was incompatible with the existing Web.

In particular, we want to be able to convert from HTTP/1 to HTTP/2 without losing any information. If we start “cleaning up” headers (and most people would agree that HTTP headers are messy), many interoperability problems with the existing Web will arise.

Doing so would only create trouble for the adoption of the new protocol.

That said, the HTTP Working Group is responsible for all of HTTP, not just HTTP/2. As such, we can study new mechanisms that are independent of version, as long as they are backward-compatible with the existing Web.


### 13. What about non-browser HTTP users?

If non-browser applications are already using HTTP, they should be able to use HTTP/2 as well.

We previously received feedback that HTTP “APIs” would have good performance characteristics in HTTP/2, because APIs do not need to account for issues such as request overhead in their design.

That said, the main focus of the improvements we are considering is the typical browsing use case, because that is the core use case of the protocol.

Our charter states this:
```c
The resulting specification(s) are expected to meet these goals for common existing deployments of HTTP; in particular, Web browsing (desktop and mobile), non-browsers ("HTTP APIs"), Web serving (at a variety of scales), and intermediation (by proxies, corporate firewalls, "reverse" proxies and Content Delivery Networks). Likewise, current and future semantic extensions to HTTP/1.x (e.g., headers, methods, status codes, cache directives) should be supported in the new protocol.

The specifications being developed need to meet the functional requirements of HTTP as it is widely deployed today; specifically, Web browsing (desktop and mobile), non-browsers (in the form of “HTTP APIs”), Web serving (at large scales), and various network intermediaries (implemented through proxies, corporate firewalls, reverse proxies, and content delivery networks). Likewise, current and future semantic extensions to HTTP/1.x (e.g., headers, methods, status codes, cache directives) should be supported in the new protocol.


Note that this does not include uses of HTTP where non-specified behaviours are relied upon (e.g., connection state such as timeouts or client affinity,and "interception" proxies); these uses may or may not be enabled by the final product.

It is worth noting that this does not include scenarios where HTTP is used in reliance on non-specified behavior (such as timeouts, connection state, and interception proxies). These may not be enabled by the final product.

```

### 14. Does HTTP/2 require encryption?

No. After extensive discussion, the working group did not reach consensus that the new protocol must use encryption (for example, TLS).

However, some implementations have stated that they support HTTP/2 only when it is used over an encrypted connection, and no browser currently supports unencrypted HTTP/2.


### 15. How does HTTP/2 improve security?

HTTP/2 defines a required TLS profile; this includes the version, a blacklist of cipher suites, and the extensions to use.

For details, see the [specification](http://http2.github.io/http2-spec/#TLSUsage).

Other mechanisms have also been discussed, such as using TLS for HTTP:// URLs (so-called “opportunistic encryption”); see [RFC 8164](https://tools.ietf.org/html/rfc8164).


### 16. Can I use HTTP/2 now?

In browsers, the latest versions of Edge, Safari, Firefox, and Chrome all support HTTP/2. Other Blink-based browsers will also support HTTP/2 (for example, Opera and Yandex Browser). For more details, see [here](http://caniuse.com/#feat=http2).

There are also several available servers (including beta support from major sites such as [Akamai](https://http2.akamai.com/), [Google](https://google.com/), and [Twitter](https://twitter.com/)), as well as many open-source implementations that can be deployed and tested.

For more details, see the [list of implementations](https://github.com/http2/http2-spec/wiki/Implementations).


### 17. Will HTTP/2 replace HTTP/1.x?

The working group’s goal is to make HTTP/2 available to people who use HTTP/1.x, so they can benefit from what HTTP/2 provides. They have said that, because people deploy proxies and servers in different ways, we cannot force the whole world to migrate, so HTTP/1.x will likely remain in use for some time.

### 18. Will there be HTTP/3?

If the negotiation mechanism introduced by HTTP/2 works well, supporting new versions of HTTP will be much easier than it was in the past.


## II. Implementation-related questions

### 1. Why do the rules revolve around CONTINUATION for HEADERS frames?

CONTINUATION exists because a single value (for example, Set-Cookie) may exceed 16KiB-1, which means it cannot fit into a single frame. The least error-prone way to handle this was determined to be requiring all header data to be delivered as one frame after another, which also makes decoding and buffer management easier.


### 2. What is the minimum or maximum size of HPACK state?

The receiver always controls the amount of memory used by HPACK, and can set it to a minimum of 0. The maximum is related to the largest integer representable in a SETTINGS frame (currently 2^32-1).


### 3. How can HPACK state be avoided?

Send a SETTINGS frame that sets the state size (SETTINGS\_HEADER\_TABLE\_SIZE) to 0, and then RST all streams until a SETTINGS frame with the ACK bit set is received.


### 4. Why is there only one compression/flow-control context?

In short:

The original proposal included the concept of stream groups, which could share context, flow control, and so on. Although this would have benefited proxies (and the experience of proxy users), it added considerable complexity. So we decided to start with something simple, see how bad the problems were, and address them in a future version of the protocol (if necessary).


### 5. Why does HPACK have an EOS symbol?

HPACK’s Huffman coding pads Huffman-encoded strings to the next byte boundary for CPU efficiency and security reasons; any particular string may require between 0 and 7 bits of padding.

If Huffman decoding is considered in isolation, any symbol longer than the required padding could work. However, HPACK’s design allows byte-wise comparison of Huffman-encoded strings. By requiring the bits of the EOS symbol to be used for padding, we ensure that users can compare Huffman-encoded strings byte by byte to determine equality. In turn, this means many headers can be parsed without requiring Huffman decoding.


### 6. Is it possible to implement HTTP/2 without implementing HTTP/1.1?

Yes, in most cases.

For HTTP/2 over TLS (h2), if you do not implement the http/1.1 ALPN identifier, you do not need to support any HTTP/1.1 functionality.

For HTTP/2 over TCP (h2c), you need to implement the initial Upgrade request.

Clients that support only h2c need to generate an OPTIONS request for “*” or a HEAD request for “/”; both are fairly safe and easy to construct. Clients that want to implement only HTTP/2 will need to treat HTTP/1.1 responses without a 101 status code as errors.

Servers that support only h2c can use a fixed 101 response to receive a request containing the Upgrade header field. Requests without the h2c upgrade token can be rejected with a 505 (HTTP Version Not Supported) status code that includes the Upgrade header field. Servers that do not want to process HTTP/1.1 responses should, after sending the connection preface, immediately reject stream 1 with a REFUSED\_STREAM error code to encourage the client to retry the request over the upgraded HTTP/2 connection.


### 7. Is the priority example in Section 5.3.2 incorrect?

It is correct. Stream B has a weight of 4, and stream C has a weight of 12. To determine the proportion of available resources each of these streams receives, add all the weights together (16), then divide each stream’s weight by the total weight. Therefore, stream B receives one quarter of the available resources, and stream C receives three quarters. Thus, as stated in the specification: [stream B ideally receives one third of the resources allocated to stream C](http://http2.github.io/http2-spec/#rfc.section.5.3.2).


### 8. Do HTTP/2 connections need TCP\_NODELAY?

Possibly. Even for a client implementation that uses only a single stream to download a large amount of data, it will still be necessary to send some packets in the opposite direction to achieve maximum transfer speed. If TCP\_NODELAY is not set (so the Nagle algorithm is still allowed), outgoing packets may be held for a while so they can be coalesced with subsequent packets.

For example, if such a packet tells the peer that more window is available for sending data, delaying its transmission by several milliseconds (or longer) can seriously impact high-speed connections.

## III. Deployment questions

### 1. If HTTP/2 is encrypted, how do I debug it?

There are many ways to access application data, but the easiest is to use [NSS keylogging](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS/Key_Log_Format) together with the Wireshark plugin (included in the latest development versions). This method works for both Firefox and Chrome.


### 2. How do I use HTTP/2 server push?


HTTP/2 server push allows the server to provide content to the client without waiting for a request. This can improve resource retrieval times, especially for connections with a [large bandwidth-delay product](https://en.wikipedia.org/wiki/Bandwidth-delay_product), where network round-trip time accounts for most of the time spent on the resource.

Pushing resources that vary based on request content may be unwise. Currently, browsers will only push requests for which they would otherwise make a matching request (see [Section 4 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-4)).

Some caches do not account for variation across all request header fields, even when those fields appear in the Vary header field. To maximize the likelihood that pushed resources are accepted, content negotiation is the best option. Content negotiation based on the accept-encoding header field is widely respected by caches, but other header fields may not be well supported.


------------------------------------------------------

Reference:  

[HTTP/2 Frequently Asked Questions](https://http2.github.io/faq/)    

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
> 
> Source: [https://halfrost.com/http2-frequently-asked-questions/](https://halfrost.com/http2-frequently-asked-questions/)
>