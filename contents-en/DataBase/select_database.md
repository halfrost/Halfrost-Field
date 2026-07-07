<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-0b9a654a1c10804e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


## Introduction

Mainstream storage products include MySQL, PostgreSQL, MongoDB, and RDS (also MySQL). These products differ in terms of deployment environment support (active-active) and DBA support. At present, the only product with full support for active-active architecture is MySQL (with data synchronized through DRC). PostgreSQL and MongoDB can only support a GlobalZone architecture (not pure active-active). When selecting a product, users need to consider differences in active-active scenarios, business characteristics, product capabilities, and maintenance, so that they can choose the right product (you can also consult a DBA).

Product selection mind map


![](https://img.halfrost.com/Blog/ArticleImage/select_database.png)

### MySQL
   Pros and cons:

        Pros: A mainstream storage product, flexible and lightweight, capable of meeting the vast majority of use cases (available in versions 5.6 and 5.7). It has a mature operations system and maintenance guarantees, and supports multiple active-active solutions (DB active-active architecture solutions). Core services are recommended to choose this storage solution first.

        Cons: Some scenarios with special requirements cannot be satisfied, such as location services, large-file storage, analytical applications, unstructured designs (frequent table schema changes), and so on.

   Applicable scenarios:

        Relational database design; low-latency, high-frequency data storage and reads; relatively high performance; suitable for the vast majority of scenarios.

   Red-line criteria:

      Single-instance performance: TPS<5000/s, QPS<10000/s 

      Disk capacity: 1.6T

      Table criteria: A single table should contain no more than 20 million rows, and its size should not exceed 50G. Archiving is required. Tables that exceed these criteria need to be designed as sharded tables.


      


### PostgreSQL

  Pros and cons:

          Pros: A classic relational database with rich data types (json,geo,array,range), multiple index types (btree,hash,brin,gist,gin), and multiple query execution methods (hash join,merge join,seq scan). It handles complex SQL better than MySQL.

          Cons: Tables are prone to bloat and require regular maintenance. TPS for a single table should not be too high (3000+). Multi-master writes are not yet supported.

   Applicable scenarios:

         High data consistency requirements; many SQL queries with multi-table joins; fast queries on json data; fast geospatial queries; medium-scale data analysis; recursive queries; fuzzy search and similarity search for images or content, etc.

   Red-line criteria:

      Single-instance performance: TPS<10000/s, QPS<15000/s 

      Disk capacity: 1.6T

      Table criteria: A single table should contain no more than 100 million rows, and its size should not exceed 50G. Archiving is required. Tables that exceed these criteria need to be designed as sharded tables.


### Mongo

   Pros and cons:

          Pros: A typical document database. Supports a schema-less design model, rapid development, and simple high-availability design.

          Cons: Does not support multi-writer active-active solutions, lacks complete middleware support, and does not provide continuous availability.

   Applicable scenarios:

          Scenarios that require rapid development, have strong demand for json, involve large-scale data writes for non-core services, and can tolerate service unavailability for a certain period of time.

   Red-line criteria:

      Single-instance performance: TPS<15k/s, QPS<10k/s 

      Disk capacity: 1.6T

      Table criteria: Below 500G


### RDS

   Pros and cons:

          Pros: Fast resource application and delivery. Can accommodate non-standard usage patterns (for example, third-party purchased software). Maintenance is handled by Alibaba Cloud.

          Cons: DBAs only provide the most basic service support (whether it is available). Everything else is handled by the requesting party itself (changes, optimization, etc.).

   Applicable scenarios:

        Services that require a non-standard DB environment (businesses that create tables, drop tables, and maintain SQL themselves), and services with low availability requirements (can tolerate service unavailability for hours or even days).


------------------------------------------------------

Reference:  


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: []()