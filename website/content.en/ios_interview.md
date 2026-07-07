+++
author = "一缕殇流化隐半边冰霜"
categories = ["面试总结", "iOS", "interview"]
date = 2016-04-28T07:56:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/3_0_.png"
slug = "ios_interview"
tags = ["面试总结", "iOS", "interview"]
title = "March 2016 iOS Interview Summary"

+++


In mid-to-late March this year, I changed jobs for personal reasons. During that period, I interviewed with four or five companies, most of which were Series D or publicly listed companies. Through their interviews and written tests, I also saw some of my own shortcomings, so I wanted to write them down and share them with everyone. If this can help students who are currently interviewing, even better. From the interview questions, you can actually see some trends in the industry and what the overall talent demand looks like.

####I. Written Test
The written tests basically all included one or two fundamental questions, such as the reuse mechanism of UITableView, the basic principles of ARC, how to avoid retain cycles, your understanding of MVC, and the iOS memory management mechanism. Everyone should be very familiar with these. The written test formats included several types: multiple-choice questions, short-answer questions, and the harder ones were multiple-select questions. One company I interviewed with gave me 10 multiple-select questions. Selecting too many, too few, or the wrong options would all be marked incorrect. After finishing, I felt pretty bad about it. For some questions, the prompt simply asked which of the following were correct, and then ABCD each described four different concepts. One such question was effectively testing four separate points. In short, if you run into this kind of “nasty” multiple-select question, don’t panic too much. Calm down and evaluate each option carefully, and you should be able to get a decent score.

Next, I’ll talk about a few questions that I didn’t answer very well at the time. I took some notes afterward and would like to share them with everyone.

#####1. The differences and relationship between processes and threads
This is actually an operating systems question. At the time, it caught me off guard. Later, after thinking about it carefully and adding my own understanding, I answered it. Below is a relatively complete answer. You can prepare for it, and if you get asked this kind of question again, you’ll be able to answer it perfectly.

>A process is an execution activity of a program with certain independent functionality over a particular data set. A process is an independent unit for system resource allocation and scheduling. A thread is an entity within a process and is the basic unit of CPU scheduling and dispatch. It is a smaller basic unit than a process that can run independently. A thread basically does not own system resources itself; it only owns a few resources that are indispensable during execution, such as a program counter, a set of registers, and a stack. However, it can share all resources owned by the process with other threads belonging to the same process. 

>A thread can create and terminate another thread; multiple threads within the same process can execute concurrently.


#####2. The difference between parallelism and concurrency
>Parallelism means that two or more events occur at the same moment;
concurrency means that two or more events occur within the same time interval.


#####3. Talk about your understanding of Block and delegate
Here’s how I answered it at the time: delegate callbacks are more process-oriented, while blocks are result-oriented. If you need to be notified about a multi-step process, you should use delegation. If you only want to get the information you requested (or an error message when retrieving that information), you should use a block. (If you combine this with the previous three conclusions, you’ll find that a delegate can maintain state across all events, while multiple independent blocks cannot.)

#####4. Talk about the **similarities and differences between instancetype and id**
1. Similarity: both can be used as a method’s return type

2. Differences:
①instancetype can return an object of the same type as the class where the method is defined, while id can only return an object of an unknown type;  
②instancetype can only be used as a return value and cannot be used as a parameter like id


#####5. Can declared properties be used in a category? Why? If so, how can it be implemented?
When I was asked this question, I felt it definitely had to be possible, but I really didn’t know how to do it. Later, after looking it up, I realized it involved Runtime knowledge. Here’s the answer:

Adding properties to a category  
Use Runtime to implement getter/setter methods
```objectivec  
@interface ClassName (CategoryName)
@property (nonatomic, strong) NSString *str;
@end

//Implementation file

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

#####6. Difference between isKindOfClass and isMemberOfClass
This question is simple, but under pressure it is easy to answer it the other way around.

isKindOfClass determines whether an object is a member of a class, or a member of a class derived from that class.  
isMemberOfClass can only determine whether an object is a member of the current class.

#####7. How to prevent a retain cycle inside a block
Use a weak reference to break the retain cycle inside the block.  
In MRC, __ _block __ does not cause a retain; but in ARC, __ _block __ does cause a retain. In ARC, you should use __ _weak __ or __unsafe_unretained weak references.

#####8. What are the ways to implement multithreading in iOS? What queues are there in GCD? Are they concurrent or serial?
There are mainly three multithreading programming tools in iOS:
1. NSThread
2. NSOperation
3. GCD

dispatch queue is divided into the following three types. By default, the system provides one serial queue, main_queue, and one concurrent queue, global_queue:

There are three queue types in GCD:
**The main queue:** It has the same function as the main thread. In fact, tasks submitted to the main queue are executed on the main thread. The main queue can be obtained by calling dispatch_get_main_queue(). Because the main queue is associated with the main thread, it is a serial queue.

**Global queues:** Global queues are concurrent queues and are shared by the entire process. There are three global queues in a process: high, medium (default), and low priority queues. You can access a queue by calling the dispatch_get_global_queue function and passing in the priority.

**User queues:** User queues (GCD does not call them this, but there is no specific name for this kind of queue, so we call them user queues) are queues created with the function dispatch_queue_create
. These queues are serial. Because of this, they can be used to implement synchronization mechanisms, somewhat like mutexes in traditional threading.

##### 9. Difference between load and initialize

When this question was asked, I was honestly stunned. Although I usually use them a lot, I had never really compared the two carefully. It seems that when studying, I should ask more about the "why" behind things!

![](https://img.halfrost.com/Blog/ArticleImage/3_2.png)


##### 10. Is Core Data a database? What are its important classes?
When I saw that the question asked whether it "is" something, I became cautious, because I felt the answer probably was not the conventional one. After thinking it through carefully, Core Data is indeed not a database. It only maps tables to OC objects. Of course, it is not merely simple mapping; under the hood, it still uses Sqlite3 for storage. So Core Data is not a database.

There are the following six important classes:  
(1)NSManagedObjectContext (managed data context)  
Operates on the actual content (operates on the persistence layer)  
Purpose: insert data, query data, delete data  
(2)NSManagedObjectModel (managed data model)  
All database tables or data structures, containing the definition information of each entity  
Purpose: add entity attributes and establish relationships between attributes   
Operation methods: visual editor, or code  
(3)NSPersistentStoreCoordinator (persistent store coordinator)  
Equivalent to a database connector  
Purpose: set the data store's name, location, storage method, and storage timing  
(4)NSManagedObject (managed data record)  
Equivalent to a table record in a database  
(5)NSFetchRequest (request for fetching data)  
Equivalent to a query statement  
(6)NSEntityDescription (entity structure)  
Equivalent to a table structure  


##### 11. Are frame and bound always equal? If there are cases where they are not equal, please give an example  

![](https://img.halfrost.com/Blog/ArticleImage/3_3.jpeg)


In the image above, if the blue View is rotated, its frame is the large outer rectangle, while its bound is the blue border.


The above are the questions I encountered in interviews in March that I either could not answer completely on the spot or did not answer well. If you are an expert and know all of them, please just ignore this. There were also two open-ended questions, which are basically a complete test of one's ability and depth of understanding. One was to talk about your understanding of Runtime, and the other was to talk about your understanding of Runloop. Since my own understanding of these two topics is not very deep, I will not post my thoughts here. If you also feel lacking in these areas, hurry up and read more online!

#### II. Coding Test
This stage usually appears at large companies or during second-round interviews, because writing code on a computer can very quickly distinguish who is strong and who is not. Of course, I also interviewed at one such company, where they simply gave me a blank sheet of paper and asked me to write code by hand the whole time. That completely tests your fundamentals, because without code completion and without a compiler telling you where the errors are, everything depends on your own basic skills.

Coding tests are basically about algorithm problems. Of course, algorithm problems may also appear as the final few questions in a written test; it depends on how the company arranges its interviews.

Two years ago, I was also interviewing for iOS positions. At that time, the requirements for algorithms and data structures were very low, and many interviews basically did not ask about them. This year, these questions appeared much more often, which was eye-opening for me. I also sighed at how fast technology has developed in two years: interviews now involve algorithms. The path for programmers who do not know algorithms and data structures will become narrower and narrower.

The algorithm problems I encountered were not difficult after all; these were not companies like BAT. The simpler ones directly asked you to write an algorithm. The slightly more advanced ones gave you a background scenario and asked you to solve a problem. In fact, they were like ACM problems, just not that complicated. I will post a few of the most frequently asked algorithms. For the really hard problems, you can only rely on your own algorithm fundamentals.
```c  
Binary search θ(logn)

Recursive method
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

Non-recursive method
int binarySearch2(int a[] , int low , int high , int findNum)
{    
       while (low <= high)
      {
            int mid = ( low + high) / 2;   //Must be inside the while loop
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
Bubble sort   θ(n^2)
void bubble_sort(int a[], int n)
{
    int i, j, temp;
    for (j = 0; j < n - 1; j++)
        for (i = 0; i < n - 1 - j; i++) //Each outer-loop pass fixes one bubble (maximum or minimum), so the inner loop need not check the already sorted part
        {
            if(a[i] > a[i + 1])
            {
                temp = a[i];
                a[i] = a[i + 1];
                a[i + 1] = temp;
            }
        }
}

Quicksort  call as  quickSort(a,0,n);  θ(nlogn)
void quickSort (int a[] , int low , int high)
{
    if (high < low + 2)
        return;
    int start = low;
    int end = high;
    int temp;
    
    while (start < end)
    {
        while ( ++start < high && a[start] <= a[low]);//Find the first position start whose value is greater than a[low]

        while ( --end  > low  && a[end]  >= a[low]);//Find the first position end whose value is less than a[low]

        //At this point, a[end] < a[low] < a[start], but the physical positions are still low < start < end, so next swap a[start] and a[end]; then all values in [low,start] are less than a[low], and all values in [end,hight] are greater than a[low]
        
        if (start < end)
        {
            temp = a[start];
            a[start]=a[end];
            a[end]=temp;
        }
        //Under the GCC compiler, this form cannot perform the swap: a[start] ^= a[end] ^= a[start] ^= a[end]; compiler issue
    }
    //At this point, all numbers in [low,end] are less than a[low], and all numbers in [end,higt] are greater than a[low]; just put a[low] in the middle

    //Under the GCC compiler, this form cannot perform the swap: a[low] ^= a[end] ^= a[low] ^= a[end]; compiler issue
    
    temp = a[low];
    a[low]=a[end];
    a[end]=temp;
    
    //Now it is split into 3 parts, separated by the original a[low] pivot
    quickSort(a, low, end);
    quickSort(a, start, high);
}
```
I’ve also added comments. These algorithms are basically enough to handle most simple algorithm problems.

For data structure questions, I encountered reversing a linked list, implementing a stack data structure with LIFO semantics, pre-order, in-order, and post-order tree traversal, and DFS and BFS for graphs. I won’t paste the code here—it’s too long. If you’ve forgotten any of these, you can go back and review them again.


####III. Interview
Interviews are mostly about asking what projects you’ve worked on before, what problems you ran into, how you solved them yourself, your thoughts on XXX, and so on. As long as you usually complete your projects seriously, the interview questions are actually easier to answer, because they are all about your own projects—the things you understand best and know most clearly.


That’s it for the iOS developer hiring market in Shanghai in March 2016, excluding BAT companies. Compared with two years ago, my biggest takeaway is that interviews now cover a broader range of topics and the requirements are higher. Nowadays, in addition to knowing OC, you also need to understand algorithms and data structures. You also need to know either ReactNative, or a series of hybrid development frameworks like PhoneGap, or be familiar with Swift. Programmers must keep up with the mainstream to avoid being eliminated by the times and to remain competitive. This is also what I learned from interviewing with these companies: live and learn! Finally, I hope everyone can exchange ideas with me. I’m also an iOS newbie, so please feel free to give me your advice!


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_interview/](https://halfrost.com/ios_interview/)