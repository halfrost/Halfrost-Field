# TLS 1.3 0-RTT and Anti-Replay


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/112_0_.png'>
</p>

As described in [Section 2.3](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3.md#3-0-rtt-%E6%95%B0%E6%8D%AE) and [Appendix E.5](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Security_Properties.md#%E4%BA%94-replay-attacks-on-0-rtt), TLS does not provide inherent replay protection for 0-RTT data. There are two potential threats worth considering:

- A network attacker performing a replay attack by simply copying 0-RTT data and sending it again

- A network attacker exploiting client retry behavior to cause the server to receive multiple copies of an application message. This threat already exists to some extent, because robustness-oriented clients respond to network errors by attempting to retry requests. However, 0-RTT adds an extra dimension for any server system that does not maintain globally consistent server state. Specifically, if a server system has multiple zones, and tickets from zone A are not accepted in zone B, then an attacker can copy a ClientHello and early data from A to both A and B. In A, the data will be accepted in 0-RTT, but in B, the server will reject the 0-RTT data and instead force a full handshake. If the attacker blocks A's ServerHello, then the client will complete the handshake with B and will very likely retry the request, resulting in duplication across the overall server system.


The first class of attack can be prevented by sharing state to ensure that 0-RTT data is accepted at most once. Servers should provide some level of replay safety by implementing one of the methods described in this document, or an equivalent method. However, it is understood that due to operational constraints, not all deployments will maintain that level of state. Therefore, during normal operation, clients do not know what mechanisms, if any, these servers actually implement, and therefore must only send early data that they consider safe to replay.

Beyond the direct impact of replay, there is also a class of attacks in which even operations that are normally considered idempotent can be exploited by being replayed in large numbers (timing attacks, resource-limit exhaustion, and so on, as described in Appendix E.5). These issues can be mitigated by ensuring that each 0-RTT payload can only be replayed a limited number of times. A server must ensure that any of its instances (whether a machine, thread, or any other entity within the associated service infrastructure) can accept 0-RTT, and can do so for at most one 0-RTT handshake; this limits the number of replays to the number of server instances in the deployment. This can be implemented by locally recording recently received ClientHellos and rejecting duplicates, or by any other method that provides the same or stronger guarantees. The guarantee of "one 0-RTT, at most one response per server instance" is the minimum requirement; servers should further limit 0-RTT replay when feasible.

The second class of attack cannot be prevented at the TLS layer and must be handled by the application. Note that any application whose client implements any kind of retry behavior needs to implement some form of anti-replay defense.


## I. Single-Use Tickets


The simplest form of anti-replay defense is for the server to allow each session ticket to be used only once. For example, the server can maintain a database of all outstanding valid tickets and delete each ticket from the database when it is used. If an unknown ticket is presented, the server falls back to a full handshake.


If a ticket is not self-contained but instead is a database key, and the corresponding PSK is deleted when it is used, then connections established with that PSK enjoy forward secrecy. When PSKs are used without (EC)DHE, this improves the security of all 0-RTT data and PSK usage.

Because this mechanism requires the session database to be shared among server nodes in an environment with multiple distributed servers, it may be difficult to guarantee high rates of successful PSK 0-RTT connections compared with self-encrypted tickets. Unlike session databases, session tickets can successfully perform PSK-based session establishment even without consistent storage; however, when 0-RTT is allowed, they still require consistent storage to prevent replay of 0-RTT data, as described in the next section.


## II. Client Hello Recording


Another form of anti-replay is to record a unique value derived from the ClientHello (usually a random value or PSK binder) and reject duplicates. Recording all ClientHellos would cause unbounded state growth, but the server can record ClientHellos within a given time window and use "obfuscated\_ticket\_age" to ensure that tickets are not reused outside that window.

To implement this, when a ClientHello is received, the server first validates the PSK binder, as described in [Section 4.2.11](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension). It then computes expected\_arrival\_time, as described in the next section. If it falls outside the recording window, the server rejects 0-RTT and falls back to a 1-RTT handshake.


If expected\_arrival\_time is within the window, the server checks whether it has recorded a matching ClientHello. If one is found, it aborts the handshake with an "illegal\_parameter" alert message, or accepts the PSK but rejects 0-RTT. If no matching ClientHello is found, it accepts 0-RTT and then stores the ClientHello as long as expected\_arrival\_time remains within the window. Servers can also implement data stores with false positives, such as Bloom filters; in that case, they must respond to apparent replays by rejecting 0-RTT, but must never abort the handshake.

The server must derive the storage key only from valid parts of the ClientHello. If the ClientHello contains multiple PSK identities, an attacker can create multiple ClientHellos with different binder values for less-preferred identities, provided the server does not validate them (as described in [Section 4.2.11](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension)). That is, if the client sends PSKs A and B but the server selects A, then the attacker can change B's binder without affecting A's binder. If B's binder is part of the storage key, this ClientHello will not appear to be a duplicate, which will cause the ClientHello to be accepted and may lead to side effects such as replay-cache pollution, even though any 0-RTT data will not be decrypted because it uses a different key. If a validated binder or ClientHello.random is used as the storage key, this attack is not possible.


Because this mechanism does not require storing all outstanding tickets, it may be easier to implement in distributed systems with high resumption rates and 0-RTT, at the possible cost of weaker anti-replay protection, since it is difficult to reliably store and retrieve received ClientHello messages. In many such systems, globally consistent storage for all received ClientHellos is impractical. In that case, the best anti-replay approach is for a single storage zone to have authoritative tickets and to reject 0-RTT tickets from other zones. This method prevents an attacker from performing simple replay, because only one zone can accept 0-RTT data. A weaker design is to implement separate storage for each zone while allowing 0-RTT to be used in any zone. This method limits replays to once per zone. Of course, the designs above may still result in duplicate application messages.

When implementations have just started, they should reject 0-RTT as long as any part of their recording window overlaps the startup time. Otherwise, there is a risk of accepting replays that were originally sent during that time period.


Note: If the client's clock runs faster than the server's, a ClientHello may be received in the future outside the window. In that case, it may be accepted with 1-RTT, causing the client to retry, and then later accepted with 0-RTT. This is another variant of the second form of attack described in [Section 8](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#tls-13-0-rtt-and-anti-replay).


## III. Freshness Checks


Because the ClientHello contains the time at which the client sent it, it is possible to effectively determine whether the ClientHello was sent reasonably recently, accept 0-RTT only for such ClientHellos, and otherwise fall back to a 1-RTT handshake. This is necessary for the ClientHello storage mechanism described in [Section 8.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording); otherwise, the server would need to store an unbounded number of ClientHellos. This storage mechanism is also a useful optimization for self-contained single-use tickets, because it can efficiently reject ClientHellos that cannot be used for 0-RTT.

To implement this mechanism, the server needs to store the time at which it generated the session ticket and compensate for it by estimating the round-trip time between the client and the server. For example:
```c
adjusted_creation_time = creation_time + estimated_RTT
```
This value can be encoded in the ticket, avoiding the need to maintain state for each outstanding ticket. The Server can determine the Client’s ticket age by subtracting the ticket’s "ticket\_age\_add" value from the "obfuscated\_ticket\_age" parameter in the Client’s "pre\_shared\_key" extension. The Server can determine the ClientHello’s expected\_arrival\_time as:
```c
expected_arrival_time = adjusted_creation_time + clients_ticket_age
```
When a new ClientHello is received, compare `expect_arrival_time` with the current Server time. If they differ by more than a certain amount, reject 0-RTT, although the 1-RTT handshake can still complete.


Several potential sources of error can cause `expected_arrival_time` to differ from the measured time. Variations in Client and Server clock rates are the least likely cause, but absolute time differences can become large and eventually lead to shutdown. Network propagation delay is the most likely cause of time discrepancies. Both NewSessionTicket and ClientHello messages may be retransmitted and therefore delayed, which can be hidden by TCP. For Clients on the Internet, this means a window of roughly 10 seconds is available to account for clock errors and measurement variance; other deployment scenarios may have different requirements. The clock-skew distribution is not symmetric, so the best approach is to make a trade-off within an asymmetric range that allows for some error.


Note that a validity-time check alone is not sufficient to prevent replay, because replays cannot be detected during the error window. Depending on bandwidth and system capacity, this could include billions of replays in real-world environments. In addition, this validity-time check is performed only when the ClientHello is received, not when subsequent early Application Data records are received. After early data has been accepted, records can continue streaming to the Server for a much longer period.


------------------------------------------------------

References:
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo: [Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_0-RTT/](https://halfrost.com/tls_1-3_0-rtt/)