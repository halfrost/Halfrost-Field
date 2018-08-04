<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-0b9a654a1c10804e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



## 引言

主流的存储产品有：MySQL、PostgreSQL、MongoDB和RDS（也是MySQL），不同的产品在环境（多活）和DBA支持上面是有差别的，完整支持多活架构的产品目前只有MySQL（通过DRC同步数据），PostgreSQL和MongoDB 只能支持GlobalZone的架构（并非纯粹的多活）；用户在产品选型时，需要关注多活场景、业务特性、产品特性和维护方面的不同，这样才能选择合适的产品（也可以咨询DBA）。

产品选型导图


![](https://img.halfrost.com/Blog/ArticleImage/select_database.png)

### MySQL
   优劣：

        优： 主流存储产品，灵活轻量级，能满足绝大部分需求场景（有5.6和5.7两个版本），有成熟的运维体系和维护保障，支持多种多活方案（DB多活架构方案），核心业务建议优先选择此存储方案；

        劣： 部分特殊要求的场景不能满足，如：定位服务、大文件存储、分析型的应用、无结构化的设计（频繁变更表结构）等。

   适用场景：

        关系型数据库设计，短频快的数据存储和读取，性能比较高，绝大部分场景都能满足。

   红线标准：

      单实例性能：TPS<5000/s，QPS<10000/s 

      磁盘容量： 1.6T

      表标准： 单表数据量不超过2kw，表大小不超过50G ，需要有归档（对于超过标准的表，需要设计成Sharding表）



      



### PostgreSQL

  优劣：

          优: 经典关系型数据库,丰富数据类型(json,geo,array,range),多种索引(btree,hash,brin,gist,gin),多种查询组合方式(hash join,merge join,seq scan)，复杂SQL处理效果比MySQL好；

          劣: 表容易膨胀,需要定期维护,单表tps不要过大(3000+),多master写还不支持

   适用场景：

         数据一致性要求高, 多表join的sql多,json类快速查询,地理信息快速查询,中等量的数据分析,递归查询,图像或内容的模糊查询,相似查询等

   红线标准：

      单实例性能：TPS<10000/s，QPS<15000/s 

      磁盘容量： 1.6T

      表标准： 单表数据量不超过10kw，表大小不超过50G ，需要有归档（对于超过标准的表，需要设计成Sharding表)




### Mongo

   优劣：

          优：典型的文档型数据库，支持schema-less的设计模式，快速开发，简单的高可用设计

          劣：不能支持多写的多活方案，没有完善的中间件支撑，不提供持续可用性

   适用场景：

          需要快速开发，对json的需求较强烈，非核心业务的大量数据写入，可以容忍一定时间的服务不可用

   红线标准：

      单实例性能：TPS<15k/s，QPS<1w/s 

      磁盘容量： 1.6T

      表标准： 500G以下



### RDS

   优劣：

          优：资源申请交付快，能兼容不符合标准的使用姿势（比方第三方购买软件），有阿里云做维护；

          劣：DBA只提供最基础的服务支持（可不可用），其他由需求方自行保障（变更、优化等）。

   适用场景：

        要求提供非标DB环境（自行建表、删表和维护SQL的业务），可用性要求低的业务（能容忍小时甚至天级别的服务不可用）。




------------------------------------------------------

Reference：  



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()