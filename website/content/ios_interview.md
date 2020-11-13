+++
author = "一缕殇流化隐半边冰霜"
categories = ["面试总结", "iOS", "interview"]
date = 2016-04-28T07:56:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/3_0_.png"
slug = "ios_interview"
tags = ["面试总结", "iOS", "interview"]
title = "2016 年 3 月 iOS 面试总结"

+++


今年3月中下旬因为个人原因，换了一份工作，期间面试了有4，5家，基本都是D轮或者上市公司，也从他们的面试笔试中看到了自己的一些不足，于是就想写出来和大家分享一下，如果能帮到正在面试的同学更好。从面试题中，其实可以看到一些行业的发展，以及总体人才需求是怎样的了。

####一.笔试题
笔试基本都有一两道基础题，比如说UITableView的重用机制，ARC的基本原理，如何避免retain cycle，谈谈对MVC的理解，iOS内存管理机制。这些大家应该都很清楚了。笔试的内容有几种有选择题，问答题，难一点的就是多选题了。我面试了一家就是给了10道多选题，多选，少选，错选都不行，当时做完以后就感觉不是很好，有些题目题干就是一下哪些是对的，然后ABCD依次给4个不同的概念，这种一道题相当于考了4个点。总之遇到这种“恶心”的多选题也不要太慌，静下心来一一甄别应该能拿到不错的成绩。

接下来我说几个我当时答的不怎么好的题目，我当时记了一下，和大家分享一下。

#####1.进程和线程的区别和联系
这个其实是操作系统的问题，当时一下子把我问的懵了，后来仔细回想了一下，加上自己的理解就答了，下面说说稍微完整的答案，大家可以准备准备，再问这种问题就可以完美作答了。

>进程是具有一定独立功能的程序关于某个数据集合上的一次运行活动,进程是系统进行资源分配和调度的一个独立单位. 线程是进程的一个实体,是CPU调度和分派的基本单位,它是比进程更小的能独立运行的基本单位.线程自己基本上不拥有系统资源,只拥有一点在运行中必不可少的资源(如程序计数器,一组寄存器和栈),但是它可与同属一个进程的其他的线程共享进程所拥有的全部资源. 

>一个线程可以创建和撤销另一个线程;同一个进程中的多个线程之间可以并发执行.


#####2.并行和并发的区别
>并行是指两个或者多个事件在同一时刻发生；
并发是指两个或多个事件在同一时间间隔内发生。


#####3.谈谈你对Block和delegate的理解
我当时是这么答的，delegate的回调更多的面向过程，而block则是面向结果的。如果你需要得到一条多步进程的通知，你应该使用delegation。而当你只是希望得到你请求的信息（或者获取信息时的错误提示），你应该使用block。（如果你结合之前的3个结论，你会发现delegate可以在所有事件中维持state，而多个独立的block却不能）

#####4.谈谈**instancetype和id的异同**
1、相同点：都可以作为方法的返回类型

2、不同点：
①instancetype可以返回和方法所在类相同类型的对象，id只能返回未知类型的对象；  
②instancetype只能作为返回值，不能像id那样作为参数


#####5.category中能不能使用声明属性？为什么？如果能，怎么实现？
这种问题一问，我当时就感觉肯定能实现的，但是实在不知道怎么做，后来回来查了一下，才知道是用到了Runtime的知识了。贴一下答案

给分类（Category）添加属性  
利用Runtime实现getter/setter 方法

```objectivec  
@interface ClassName (CategoryName)
@property (nonatomic, strong) NSString *str;
@end

//实现文件
#import "ClassName + CategoryName.h"
#import <objc/runtime.h>
  
static void *strKey = &strKey;
@implementation ClassName (CategoryName)

-(void)setStr:(NSString *)str
{
    objc_setAssociatedObject(self, & strKey, str, OBJC_ASSOCIATION_COPY);
}

-(NSString *)str
{
    return objc_getAssociatedObject(self, &strKey);
}

@end
```


#####6.isKindOfClass和isMemberOfClass的区别
这个题目简单，但是就是当时紧张的情况下，别答反了。

isKindOfClass来确定一个对象是否是一个类的成员，或者是派生自该类的成员
isMemberOfClass只能确定一个对象是否是当前类的成员

#####7.block里面的如何防止retain cycle
使用弱引用打断block里面的retain cycle
MRC中__ _block __是不会引起retain；但在ARC中__ _block __则会引起retain。ARC中应该使用__ _weak __或__unsafe_unretained弱引用

#####8.iOS多线程有哪几种实现方法？GCD中有哪些队列？分别是并行还是串行？
iOS中多线程编程工具主要3有：
1. NSThread
2. NSOperation
3. GCD

dispatch queue分为下面3种：而系统默认就有一串行队列main_queue和并行队列global_queue：

GCD中有三种队列类型：
**The main queue:** 与主线程功能相同。实际上，提交至main queue的任务会在主线程中执行。main queue可以调用dispatch_get_main_queue()来获得。因为main queue是与主线程相关的，所以这是一个串行队列。

**Global queues:** 全局队列是并发队列，并由整个进程共享。进程中存在三个全局队列：高、中（默认）、低三个优先级队列。可以调用dispatch_get_global_queue函数传入优先级来访问队列。

**用户队列:** 用户队列 (GCD并不这样称呼这种队列, 但是没有一个特定的名字来形容这种队列，所以我们称其为用户队列) 是用函数 dispatch_queue_create
 创建的队列. 这些队列是串行的。正因为如此，它们可以用来完成同步机制, 有点像传统线程中的mutex。

##### 9.谈谈load和initialize的区别

这个题目当时问出来，真的是一下子就傻了，平时虽然用的多，但是真的没有注意比较过他们俩，看来平时学习还是多要问问所以然！

![](https://img.halfrost.com/Blog/ArticleImage/3_2.png)


##### 10.Core Data是数据库么？有哪些重要的类？
我当时一看问到是不是的问题，我就留神，感觉应该不是常理的，当时仔细想了想，Core Data确实不是一个数据库，只是把表和OC对象进行的映射，当时并不是进进映射那么简单，底层还是用的Sqlite3进行存储的，所以Core Data不是数据库。

有以下6个重要的类：  
(1)NSManagedObjectContext（被管理的数据上下文）  
操作实际内容（操作持久层）  
作用：插入数据，查询数据，删除数据  
(2)NSManagedObjectModel（被管理的数据模型）  
数据库所有表格或数据结构，包含各实体的定义信息  
作用：添加实体的属性，建立属性之间的关系   
操作方法：视图编辑器，或代码  
(3)NSPersistentStoreCoordinator（持久化存储助理）  
相当于数据库的连接器  
作用：设置数据存储的名字，位置，存储方式，和存储时机  
(4)NSManagedObject（被管理的数据记录）  
相当于数据库中的表格记录  
(5)NSFetchRequest（获取数据的请求）  
相当于查询语句  
(6)NSEntityDescription（实体结构）  
相当于表格结构  


##### 11. frame和bound 一定都相等么？如果有不等的情况，请举例说明  

![](https://img.halfrost.com/Blog/ArticleImage/3_3.jpeg)



在上图中，如果蓝色的View旋转了，那么它的frame是外面的大框，而bound是蓝色的边框。



以上是我3月份面试遇到的问到的我一下子没有答全或者没答好的问题，大神全部都会的话请忽略哈。然后还有2个开放性的问题，那基本就是完全考验实力和自己理解的深度了。一个是谈谈你对Runtime的理解，另一个是谈谈你对Runloop的理解，由于我个人这两个理解都不是很深，这里就不贴我的理解了。大家如果也感觉欠缺的，就赶紧去网上多看看吧！

#### 二.机试
这个环节基本都是大公司，或者是复试的时候会出现，因为上机打代码确实很很快区分出谁好谁坏，当然我也面了一家这样的公司，就给一张白纸，全程都是手写代码，这就完全是考验基本功了，因为没了代码补全，没有了编译器告诉你哪里错了，一切都要靠自己的基本功来了。

机试基本就是靠靠算法题了。当然也有算法题在笔试的最后几道题出现，那就看公司面试怎么安排的。

2年前我也是面试iOS，当时对算法和 数据结构要求很低的，很多面试基本都不问这些，今年面试多了这些问题，也让我眼前一亮，也感叹，2年技术发展之快，面试如今都会涉及到算法，不会算法和数据结构的程序员的道路会越走越窄。

算法题，我遇到的都不难，毕竟不是BAT那种公司，简单的就是直接要你写一个算法出来，稍微高级点的就是有一个背景，然后要你解决问题，其实就是和ACM题目一样的，不过就是没有那么复杂。我贴几段问的最多的算法，太难的题只能考自己的算法功底了。

```c  
二分查找 θ(logn)

递归方法
int binarySearch1(int a[] , int low , int high , int findNum)
{    
      int mid = ( low + high ) / 2;       
      if (low > high)        
            return -1;   
     else   
     {        
              if (a[mid] > findNum)          
                    return binarySearch1(a, low, mid - 1, findNum);        
              else if (a[mid] < findNum)            
                    return binarySearch1(a, mid + 1, high, findNum);                    
              else            
                    return mid;   
    }
}

非递归方法
int binarySearch2(int a[] , int low , int high , int findNum)
{    
       while (low <= high)
      {
            int mid = ( low + high) / 2;   //此处一定要放在while里面
            if (a[mid] < findNum)           
                low = mid + 1;        
            else if (a[mid] > findNum)            
                high = mid - 1;       
             else           
                return mid;    
    }       
    return  -1;
}
```

```c  
冒泡排序   θ(n^2)
void bubble_sort(int a[], int n)
{
    int i, j, temp;
    for (j = 0; j < n - 1; j++)
        for (i = 0; i < n - 1 - j; i++) //外层循环每循环一次就能确定出一个泡泡（最大或者最小），所以内层循环不用再计算已经排好的部分
        {
            if(a[i] > a[i + 1])
            {
                temp = a[i];
                a[i] = a[i + 1];
                a[i + 1] = temp;
            }
        }
}

快速排序  调用方法  quickSort(a,0,n);  θ(nlogn)
void quickSort (int a[] , int low , int high)
{
    if (high < low + 2)
        return;
    int start = low;
    int end = high;
    int temp;
    
    while (start < end)
    {
        while ( ++start < high && a[start] <= a[low]);//找到第一个比a[low]数值大的位子start

        while ( --end  > low  && a[end]  >= a[low]);//找到第一个比a[low]数值小的位子end

        //进行到此，a[end] < a[low] < a[start],但是物理位置上还是low < start < end，因此接下来交换a[start]和a[end],于是[low,start]这个区间里面全部比a[low]小的，[end,hight]这个区间里面全部都是比a[low]大的
        
        if (start < end)
        {
            temp = a[start];
            a[start]=a[end];
            a[end]=temp;
        }
        //在GCC编译器下，该写法无法达到交换的目的，a[start] ^= a[end] ^= a[start] ^= a[end];编译器的问题
    }
    //进行到此，[low,end]区间里面的数都比a[low]小的,[end,higt]区间里面都是比a[low]大的，把a[low]放到中间即可

    //在GCC编译器下，该写法无法达到交换的目的，a[low] ^= a[end] ^= a[low] ^= a[end];编译器的问题
    
    temp = a[low];
    a[low]=a[end];
    a[end]=temp;
    
    //现在就分成了3段了，由最初的a[low]枢纽分开的
    quickSort(a, low, end);
    quickSort(a, start, high);
}
```

注释我也写上了，这些算法基本上简单的算法题都能应对了。

数据结构的题目我就遇到了链表翻转，实现一个栈的结构，先进后出的，树先跟，中跟，后跟遍历，图的DFS和BFS。代码就不贴了，太长了。如果有忘记的，可以再去翻翻回顾一下。


####三.面试
面试基本都是问你之前做过什么项目啦，遇到了哪些问题了，自己如何解决的。谈谈对XXX的看法等等这些问题，只要平时认真完成项目，其实面试反而问的东西更好答，因为都是关于你项目的，这些你最了解和清楚了。


好了，到此就是2016年3月上海地区除了BAT公司，招聘iOS开发工程师的行情了，比2年前，最大的体会就是面试面更广了，要求更高了。现在要求除了会OC，还要懂算法和数据结构，还有要么会ReactNative，或者PhoneGap一系列混合开发的框架，或者熟悉Swift，程序员要一直跟上主流才能不能被时代淘汰。才能具有竞争力。这也是我面试了这些公司的感悟，活到老学到老！最后希望大家都和我交流交流，我也是个iOS菜鸟，请大家多多指教！


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_interview/](https://halfrost.com/ios_interview/)

