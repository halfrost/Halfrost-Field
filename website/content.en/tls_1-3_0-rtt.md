+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol", "HTTPS"]
date = 2018-11-18T00:46:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/112_0_.png"
slug = "tls_1-3_0-rtt"
tags = ["Protocol", "HTTPS"]
title = "TLS 1.3 0-RTT and Anti-Replay"

+++


As described in [Section 2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3.md#3-0-rtt-%E6%95%B0%E6%8D%AE) and [Appendix E.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%BA%94-replay-attacks-on-0-rtt), TLS does not provide inherent replay protection for 0-RTT data. There are two potential threats of concern:

- A network attacker that performs a replay attack by simply copying and sending 0-RTT data

- A network attacker that exploits Client retry behavior to cause the Server to receive multiple copies of application messages. This threat already exists to some extent, because Clients that value robustness respond to network errors by attempting to retry requests. However, 0-RTT adds an extra dimension for any Server system that does not maintain globally consistent server state. Specifically, if a server system has multiple zones, and tickets from zone A are not accepted in zone B, then an attacker can copy the ClientHello and early data from A to both A and B. For A, the data will be accepted in 0-RTT, but for B, the Server will reject the 0-RTT data and instead force a full handshake. If the attacker blocks A’s ServerHello, then the Client will complete the handshake with B and will likely retry the request, resulting in duplicates across the overall server system.


The first class of attack can be prevented by sharing state, to ensure that 0-RTT data is accepted at most once. Servers should provide some level of replay safety by implementing one of the methods described in this document or by an equivalent method. However, it is understood that, because of operational issues, not all deployments will maintain this level of state. Therefore, in normal operation, Clients do not know which mechanisms (if any) these Servers actually implement, and so must send only early data that they believe is safe to replay.

In addition to the direct effects of replay, there is a class of attacks in which even operations that are usually considered idempotent can be exploited by being replayed many times (timing attacks, exhaustion of resource limits, and so on, as described in Appendix E.5). These issues can be mitigated by approaches that ensure each 0-RTT payload can be replayed only a limited number of times. A Server MUST ensure that any of its instances (whether a machine, thread, or any other entity within the associated service infrastructure) can accept 0-RTT, and can do so for a given 0-RTT handshake at most once; this limits the number of replays to the number of Server instances in the deployment. This can be achieved by locally recording recently received ClientHello data and rejecting duplicates, or by any other method that provides the same or stronger guarantees. The guarantee of “one 0-RTT, at most one response per Server instance” is the minimum requirement; Servers should further limit 0-RTT replay where feasible.

The second class of attack cannot be prevented at the TLS layer and must be handled by the application. Note that any application whose Client implements any kind of retry behavior needs to implement some form of anti-replay defense.


## 1. Single-Use Tickets


The simplest form of anti-replay defense is for the Server to allow a session ticket to be used only once. For example, the Server can maintain a database of all outstanding valid tickets and delete each ticket from the database when it is used. If an unknown ticket is presented, the Server falls back to a full handshake.


If a ticket is not self-contained but instead is a database key, and the corresponding PSK is deleted when it is used, then connections established with the PSK enjoy forward secrecy. When PSKs are used without (EC)DHE, this improves the security of all 0-RTT data and of PSK usage.

Because this mechanism requires the session database to be shared among Server nodes in an environment with multiple distributed servers, it may be difficult to sustain high rates of successful PSK 0-RTT connections compared with self-encrypted tickets. Unlike a session database, session tickets can successfully perform PSK-based session establishment even without consistent storage; however, when 0-RTT is allowed, they still require consistent storage for anti-replay of 0-RTT data, as described in the next section.


## 2. Client Hello Recording


Another form of anti-replay is to record a unique value derived from the ClientHello (typically a random value or a PSK binder) and reject duplicates. Recording every ClientHello would cause unbounded state growth, but the Server can record ClientHellos within a given time window and use "obfuscated\_ticket\_age" to ensure that tickets are not reused outside that window.

To implement this, when a ClientHello is received, the Server first validates the PSK binder, as described in [Section 4.2.11](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension). It then computes expected\_arrival\_time, as described in the next section; if it is outside the recording window, it rejects 0-RTT and falls back to a 1-RTT handshake.


If expected\_arrival\_time is within the window, the Server checks whether it has recorded a matching ClientHello. If it finds one, it aborts the handshake with an "illegal\_parameter" alert message or accepts the PSK but rejects 0-RTT. If no matching ClientHello is found, it accepts 0-RTT and then stores the ClientHello as long as expected\_arrival\_time remains within the window. The Server can also implement a data store with false positives, such as a Bloom filter; in that case, it MUST respond to apparent replays by rejecting 0-RTT, but MUST NOT abort the handshake.

The Server MUST derive the storage key only from the valid portions of the ClientHello. If the ClientHello contains multiple PSK identities, an attacker can create multiple ClientHellos with different binder values for less-preferred identities, provided the Server does not verify them (as described in [Section 4.2.11](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension)). That is, if the Client sends PSK A and B but the Server selects A, the attacker can change B’s binder without affecting A’s binder. If B’s binder is part of the storage key, this ClientHello will not appear to be a duplicate, which will cause it to be accepted and may lead to side effects such as replay-cache pollution, although any 0-RTT data will not be decrypted because it uses a different key. If the verified binder or ClientHello.random is used as the storage key, this attack is not possible.


Because this mechanism does not require storing all outstanding tickets, it may be easier to implement in a distributed system with high resumption rates and 0-RTT, possibly at the cost of weaker anti-replay protection, because it is difficult to reliably store and retrieve received ClientHello messages. In many such systems, globally consistent storage of all received ClientHellos is impractical. In this case, the best anti-replay approach is for a single storage zone to have authoritative tickets and to reject 0-RTT tickets from other zones. This method prevents an attacker from performing simple replays, because only one zone can accept 0-RTT data. A weaker design is to implement separate storage for each zone but allow 0-RTT to be used in any zone. This method limits replays to once per zone. Of course, the designs above may still result in duplicate application messages.

When an implementation has just started, it should reject 0-RTT as long as any part of its recording window overlaps with the startup time. Otherwise, there is a risk of accepting replays that were originally sent during that period.


Note: If the Client’s clock runs faster than the Server’s, a ClientHello may be received outside the window in the future, in which case it may be accepted with 1-RTT, causing the Client to retry and then be accepted again with 0-RTT. This is another variant of the second form of attack described in [Section 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay).


## 3. Freshness Checks


Because the ClientHello contains the time at which the Client sent it, the Server can effectively determine whether the ClientHello was sent reasonably recently, accept 0-RTT only for such ClientHellos, and otherwise fall back to a 1-RTT handshake. This is necessary for the ClientHello storage mechanism described in [Section 8.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording); otherwise, the Server would need to store an unbounded number of ClientHellos. This storage mechanism is also a useful optimization for self-contained single-use tickets, because it can efficiently reject ClientHellos that cannot be used for 0-RTT.

To implement this mechanism, the Server needs to store the time at which it generated the session ticket and compensate for it by estimating the round-trip time between the Client and Server. For example:
```c
adjusted_creation_time = creation_time + estimated_RTT
```
This value can be encoded in the ticket, avoiding the need to maintain state for each outstanding ticket. The Server can determine the Client's ticket age by subtracting the ticket's "ticket\_age\_add" value from the "obfuscated\_ticket\_age" parameter in the Client's "pre\_shared\_key" extension. The Server can determine the ClientHello's expected\_arrival\_time as:
```c
expected_arrival_time = adjusted_creation_time + clients_ticket_age
```
When a new ClientHello is received, `expect_arrival_time` is compared with the current Server time. If they differ by more than a certain amount, 0-RTT is rejected, although the 1-RTT handshake can still complete.


There are several potential sources of error that can cause `expected_arrival_time` and the measured time to diverge. Variations in the clock rates of the Client and Server are the least likely, but the absolute time may become very large, eventually leading to shutdown. Network propagation delay is the most likely cause of the timing mismatch. Both the NewSessionTicket and ClientHello messages may be retransmitted and therefore delayed, which may be hidden by TCP. For Clients on the Internet, this means there is roughly a 10-second window to account for clock error and measurement variation; other deployment scenarios may have different requirements. The distribution of clock skew is not symmetric, so the best approach is to strike a balance within an asymmetric range that allows for some margin of error.


Note that a lifetime check alone is not sufficient to prevent replay, because replays cannot be detected during the error window. Depending on bandwidth and system capacity, this may include billions of replays in real-world environments. In addition, this lifetime check is performed only when the ClientHello is received, not when subsequent early Application Data records are received. After early data has been accepted, records can continue streaming to the Server for a longer period of time.


------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_0-RTT/](https://halfrost.com/tls_1-3_0-rtt/)