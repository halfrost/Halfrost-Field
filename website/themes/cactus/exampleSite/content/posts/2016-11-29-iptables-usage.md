---
title: netfilter/iptables 笔记
date: 2016-11-29 21:08:52
category: notes
tags:
    - Linux
keywords:
    - iptables
    - netfilter
    - linux网络安全
    - 运维
---

## netfilter 与 iptables

`netfilter`是linux默认的防火墙，在2.4之后的版本正式进入内核。`netfilter` 使用四个表(Table)来存放控制信息包过滤处理的规则集。每张表由链(Chain)组成，每条链又包含了多条规则(rule)。

`iptables`是用来编辑操作这些表的一个工具。`iptables`包中也包含了针对IPv6的工具`ip6tables`。

四个表及其包含的链：

<!-- more -->

* filter
    - INPUT
    - FORWARD
    - OUTPUT
* nat
    - PREROUTING
    - POSTROUTING
    - OUTPUT
* mangle
    - PREROUTING
    - INPUT
    - FORWARD
    - OUTPUT
    - POSTROUTING
* raw
    - PREROUTING
    - OUTPUT

![img](/img/2016-11-29-iptables-usage_1.png)

### filter机制

`filter`是`netfilter`中最重要的机制，其任务是执行数据包的过滤操作。具有三种内建链：

* INPUT - 来自外部的数据包（访问本机）
* OUTPUT - 发往外部的数据包（本机访问外部）
* FORWORD - “路过”本机的数据包，转发到其他设备

链中规则的匹配方式遵循`first match`。`filter`会根据数据包特征从相应链中的第一条规则开始逐一进行匹配。只要遇到满足特征的规则后便不再继续。
每条链在最底端都定义了默认规则。默认规则只会有一种状态：`ACCEPT`或者`DROP`。默认为`ACCEPT`。

## iptables命令参数

格式：
```
iptables -操作方式 [链名] [条件匹配] [选项]

iptables -[ACD] chain rule-specification [options]
iptables -I chain [rulenum] rule-specification [options]
iptables -R chain rulenum rule-specification [options]
iptables -D chain rulenum [options]
iptables -[LS] [chain [rulenum]] [options]
iptables -[FZ] [chain] [options]
iptables -[NX] chain
iptables -E old-chain-name new-chain-name
iptables -P chain target [options]
iptables -h (print this help information)

```

常用操作方式：

* `-L(--list)` *[chain]* 列出所有规则或指定链的规则
* `-A(--append)` *chain* 在指定链中添加新规则
* `-C(--check)` *chain* 检查规则是否存在
* `-D(--delete)` *chain rule_num* 删除链中匹配的规则
* `-F(--flush)` *[chain]* 清除指定链或者全部链中的规则
* `-P(--policy)` *chain* 设置指定链的默认策略
* `-R(--replace)` *chain rule_num* 替换指定链中特定行的规则，第一行行数为1


常用选项：

* `-p(--protocol)` *proto* 指定协议，如`tcp` `udp` `icmp`
* `-j(--jump)` *target* 规则的目标（？？），如`ACCEPT` `DROP` `REJECT`
* `-s(--source)` *address[/mask]* 数据包源IP，可为单IP或CIDR网段或域名
* `-d(--destination)` *address[/mask]* 数据包目的IP，可为单IP或CIDR网段或域名
* `--dport` *port* 目的端口，必须指明`-p`
* `--sport` *port* 来源端口，必须指明`-p`
* `--line-numbers` 显示行号

>关于`-p`配置的上层协议，可参考`/etc/protocols`

## state模块

`state`模块实现了“连接跟踪”功能，用来解决某些情况下防火墙内主机对外建立链接的问题。
`state`模块定义了四种数据包链接状态，分别为`ESTABLISHED` `NEW` `RELATED` `INVALID` 四种。在TCP/IP标准的定义中，UDP和ICMP数据包是没有链接状态的，但是在state模块的定义中，任何数据包都有连接状态。

### ESTABLISHED状态

只要数据包能够成功穿过防火墙，则之后的所有数据包（包括响应数据包）都会被标记为是`ESTABLISHED`状态。

当我们设置防火墙INPUT链的默认策略为`DROP`时，防火墙内主机很多服务，如ssh客户端基本上就无法与外面的ssh服务端建立连接了。原因很简单，ssh客户端使用的端口是随机的，防火墙无法预知客户端会使用哪一个端口发起链接。因此即使客户端发出了请求，ssh服务端返回的相应数据包也会被防火墙的默认策略拦截。

ESTABLISHED状态可以很轻易的解决此问题，见[#解决应用程序无法从防火墙主机上对外建立新连接的问题](#解决应用程序无法从防火墙主机上对外建立新连接的问题)

### NEW状态

每一条链接中的地一个数据包的状态定义为`NEW`。

### RELATED状态

`RELATED`状态的数据包其含义是指，被动产成的应答数据包，且此数据包不属于当前任何链接。换一种说法就是，只要应答的数据包是因为本机发起的连接送出vhu一个数据包，导致了另一条连接的产生，那么这个新连接的所有数据包都属于`RELATED`状态。

以ubuntu上上的tracepath工具为例，在检测本机与目的主机间跳数时，tracepath是通过发送TTL值从1递增的`tcp`数据包来检测每一跳。路径中的路由器因TTL减为0而回送了一个`ICMP`数据包(ICMP Type 11)，该数据包就属于RELATED状态。

### INVALID状态

`INVALID`状态指的是状态不明的数据包，即不属于`ESTABLISHED` `NEW` `RELATED`三种类型的数据包。所有的`INVALID`数据包都应该视为恶意数据包。


## 实例

### 丢弃icmp协议包（禁止ping）

通过此规则实现禁止ping本机的效果
```
iptables -A INPUT -p icmp -j DROP
```

### 解决应用程序无法从防火墙主机上对外建立新连接的问题

```
iptables -A INPUT -p tcp -m state ESTABLISHED -j ACCEPT
```
