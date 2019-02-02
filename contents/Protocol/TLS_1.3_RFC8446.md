# The Transport Layer Security (TLS) Protocol Version 1.3


<p align='center'>
<img src='https://img.halfrost.com/Blog/ArticleImage/117_0.png'>
</p>


## Table of Contents

## 1. [Introduction](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#%E4%B8%80tls-%E5%8D%8F%E8%AE%AE%E7%9A%84%E7%9B%AE%E7%9A%84)

- 1.1. Conventions and Terminology 
- 1.2. [Major Differences from TLS 1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#%E4%B8%89tls-13-%E5%92%8C-tls-12-%E4%B8%BB%E8%A6%81%E7%9A%84%E4%B8%8D%E5%90%8C)  
- 1.3. [Updates Affecting TLS 1.2](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#%E5%9B%9B%E5%AF%B9-tls-12-%E4%BA%A7%E7%94%9F%E5%BD%B1%E5%93%8D%E7%9A%84%E6%94%B9%E8%BF%9B)  
   
## 2. [Protocol Overview](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#%E4%BA%94tls-13-%E5%8D%8F%E8%AE%AE%E6%A6%82%E8%A7%88)

- 2.1. [Incorrect DHE Share](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#1-%E9%94%99%E8%AF%AF%E7%9A%84-dhe-%E5%85%B1%E4%BA%AB)  
- 2.2. [Resumption and Pre-Shared Key (PSK)](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#2-%E5%A4%8D%E7%94%A8%E5%92%8C%E9%A2%84%E5%85%B1%E4%BA%AB%E5%AF%86%E9%92%A5pre-shared-keypsk)  
- 2.3. [0-RTT Data](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Introduction.md#3-0-rtt-%E6%95%B0%E6%8D%AE)   
   
## 3. Presentation Language

> 这一章都是一些公认的表达语言，笔者觉得读者基本都清楚，所以就不翻译了。

- 3.1. Basic Block Size  
- 3.2. Miscellaneous   
- 3.3. Numbers
- 3.4. Vectors  
- 3.5. Enumerateds  
- 3.6. Constructed Types  
- 3.7. Constants  
- 3.8. Variants 
  
  
## 4. Handshake Protocol 

- 4.1. [Key Exchange Messages](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%B8%80-key-exchange-messages)   
- 4.1.1. [Cryptographic Negotiation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-cryptographic-negotiation)  
- 4.1.2. [Client Hello](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-client-hello)   
- 4.1.3. [Server Hello](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-server-hello)   
- 4.1.4. [Hello Retry Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#4-hello-retry-request)  
- 4.2. [Extensions](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%BA%8C-extensions)   
- 4.2.1. [Supported Versions](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-supported-versions)  
- 4.2.2. [Cookie](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-cookie)   
- 4.2.3. [Signature Algorithms](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-signature-algorithms)   
- 4.2.4. [Certificate Authorities](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#4-certificate-authorities)   
- 4.2.5. [OID Filters](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#5-oid-filters)  
- 4.2.6. [Post-Handshake Client Authentication](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#6-post-handshake-client-authentication)  
- 4.2.7. [Supported Groups](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#7-supported-groups)   
- 4.2.8. [Key Share](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#8-key-share)   
- 4.2.9. [Pre-Shared Key Exchange Modes](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#9-pre-shared-key-exchange-modes)   
- 4.2.10. [Early Data Indication](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#10-early-data-indication)   
- 4.2.11. [Pre-Shared Key Extension](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#11-pre-shared-key-extension)   
- 4.3. [Server Parameters](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E4%B8%89-server-parameters)  
- 4.3.1. [Encrypted Extensions](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-encrypted-extensions)   
- 4.3.2. [Certificate Request](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-certificate-request)  
- 4.4. [Authentication Messages](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#%E5%9B%9B-authentication-messages)  
- 4.4.1. [The Transcript Hash](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-the-transcript-hash)   
- 4.4.2. [Certificate](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-certificate)   
- 4.4.3. [Certificate Verify](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-certificate-verify)   
- 4.4.4. [Finished](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#4-finished)   
- 4.5. [End of Early Data](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#5-end-of-early-data)   
- 4.6. [Post-Handshake Messages](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#6-post-handshake-messages)  
- 4.6.1. [New Session Ticket Message](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#1-new-session-ticket-message)   
- 4.6.2. [Post-Handshake Authentication](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#2-post-handshake-authentication)   
- 4.6.3. [Key and Initialization Vector Update](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Handshake_Protocol.md#3-key-and-initialization-vector-update)  
   
## 5. Record Protocol 

- 5.1. [Record Layer](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%80-record-layer)   
- 5.2. [Record Payload Protection](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%BA%8C-record-payload-protection)   
- 5.3. [Per-Record Nonce](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%B8%89-per-record-nonce)   
- 5.4. [Record Padding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E5%9B%9B-record-padding)   
- 5.5. [Limits on Key Usage](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Record_Protocol.md#%E4%BA%94-limits-on-key-usage)   

## 6. Alert Protocol 

- 6.1. [Closure Alerts](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Alert_Protocol.md#%E4%B8%80-closure-alerts)   
- 6.2. [Error Alerts](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Alert_Protocol.md#%E4%BA%8C-error-alerts)   
   
## 7. Cryptographic Computations 

- 7.1. [Key Schedule](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%B8%80-key-schedule)   
- 7.2. [Updating Traffic Secrets](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%BA%8C-updating-traffic-secrets)  
- 7.3. [Traffic Key Calculation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%B8%89-traffic-key-calculation)  
- 7.4. [(EC)DHE Shared Secret Calculation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E5%9B%9B-ecdhe-shared-secret-calculation)   
- 7.4.1. [Finite Field Diffie-Hellman](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#1-finite-field-diffie-hellman)  
- 7.4.2. [Elliptic Curve Diffie-Hellman](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#2-elliptic-curve-diffie-hellman)   
- 7.5. [Exporters](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Cryptographic_Computations.md#%E4%BA%94-exporters)   

## 8. 0-RTT and Anti-Replay

- 8.1. [Single-Use Tickets](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%B8%80-single-use-tickets)   
- 8.2. [Client Hello Recording](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%BA%8C-client-hello-recording)   
- 8.3. [Freshness Checks](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_0-RTT.md#%E4%B8%89-freshness-checks)   

## 9. Compliance Requirements

- 9.1. [Mandatory-to-Implement Cipher Suites](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Compliance_Requirements.md#%E4%B8%80-mandatory-to-implement-cipher-suites)   
- 9.2. [Mandatory-to-Implement Extensions](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Compliance_Requirements.md#%E4%BA%8C-mandatory-to-implement-extensions)   
- 9.3. [Protocol Invariants](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Compliance_Requirements.md#%E4%B8%89-protocol-invariants)   

## 10. Security Considerations

## 11. IANA Considerations

## 12. References

> 这一章都是引用的论文，所以就不翻译了。

- 12.1. Normative References  
- 12.2. Informative References   

## Appendix A. State Machine

> 这一章是两张状态机的图，所以就不翻译了。

- A.1. Client   
- A.2. Server   

## Appendix B. Protocol Data Structures and Constant Values 

> 这一章讲的都是数据结构，所以就不翻译了。

- B.1. Record Layer     
- B.2. Alert Messages    
- B.3. Handshake Protocol  
- B.3.1. Key Exchange Messages   
- B.3.2. Server Parameters Messages   
- B.3.3. Authentication Messages   
- B.3.4. Ticket Establishment   
- B.3.5. Updating Keys   
- B.4. Cipher Suites  

## Appendix C. Implementation Notes

- C.1. [Random Number Generation and Seeding](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E4%BA%8C-random-number-generation-and-seeding)   
- C.2. [Certificates and Authentication](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E4%B8%89-certificates-and-authentication)   
- C.3. [Implementation Pitfalls](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E5%9B%9B-implementation-pitfalls)   
- C.4. [Client Tracking Prevention](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E4%BA%94-client-tracking-prevention)   
- C.5. [Unauthenticated Operation](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Implementation_Notes.md#%E5%85%AD-unauthenticated-operation)   

## Appendix D. Backward Compatibility 

- D.1. [Negotiating with an Older Server](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%B8%80negotiating-with-an-older-server)   
- D.2. [Negotiating with an Older Client](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%BA%8C-negotiating-with-an-older-client)   
- D.3. [0-RTT Backward Compatibility](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%B8%89-0-rtt-backward-compatibility)   
- D.4. [Middlebox Compatibility Mode](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E5%9B%9B-middlebox-compatibility-mode)   
- D.5. [Security Restrictions Related to Backward Compatibility](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Backward_Compatibility.md#%E4%BA%94-security-restrictions-related-to-backward-compatibility)   

## Appendix E. Overview of Security Properties

- E.1. [Handshake](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%B8%80-handshake)   
- E.1.1. [Key Derivation and HKDF](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#1-key-derivation-and-hkdf)   
- E.1.2. [Client Authentication](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#2-client-authentication)   
- E.1.3. [0-RTT](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#3-0-rtt)   
- E.1.4. [Exporter Independence](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#4-exporter-independence)   
- E.1.5. [Post-Compromise Security](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#5-post-compromise-security)   
- E.1.6. [External References](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#6-external-references)   
- E.2. [Record Layer](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%BA%8C-record-layer)   
- E.2.1. [External References](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#1-external-references)   
- E.3. [Traffic Analysis](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%B8%89-traffic-analysis)   
- E.4. [Side-Channel Attacks](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E5%9B%9B-side-channel-attacks)   
- E.5. [Replay Attacks on 0-RTT](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%BA%94-replay-attacks-on-0-rtt)   
- E.5.1. [Replay and Exporters](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#1-replay-and-exporters)   
- E.6. [PSK Identity Exposure](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E5%85%AD-psk-identity-exposure)   
- E.7. [Sharing PSKs](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E4%B8%83-sharing-psks)   
- E.8. [Attacks on Static RSA](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/TLS_1.3_Security_Properties.md#%E5%85%AB-attacks-on-static-rsa)  




------------------------------------------------------

Reference：
  
[RFC 8446](https://tools.ietf.org/html/rfc8446)

> GitHub Repo：[Halfrost-Field](HTTPS://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](HTTPS://github.com/halfrost)
>
> Source: [https://halfrost.com/TLS\_1.3\_RFC8446/](https://halfrost.com/tls_1-3_RFC8446/)