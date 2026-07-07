# March 2016 iOS Interview Summary

![](https://img.halfrost.com/Blog/ArticleTitleImage/3_0_.png)


In mid-to-late March this year, I changed jobs for personal reasons. During that period, I interviewed with four or five companies, most of them Series D or publicly listed companies. Their interviews and written tests also revealed some of my own shortcomings, so I wanted to write them down and share them with everyone. It would be even better if this helps students who are currently interviewing. From interview questions, you can actually see some trends in the industry and what the overall demand for talent looks like.

#### I. Written Test Questions
Written tests basically all include one or two fundamental questions, such as the reuse mechanism of UITableView, the basic principles of ARC, how to avoid retain cycle, your understanding of MVC, and the iOS memory management mechanism. Everyone should be very familiar with these. Written tests come in several formats: multiple-choice questions, short-answer questions, and the harder ones are multiple-select questions. One company I interviewed with gave me 10 multiple-select questions; selecting too many, too few, or the wrong options were all unacceptable. After finishing them, I felt it had not gone very well. For some questions, the prompt was simply “which of the following are correct,” and then A, B, C, and D each gave a different concept. One such question was effectively testing four separate points. In short, if you run into these “nasty” multiple-select questions, do not panic too much. Calm down and evaluate each option one by one, and you should be able to get a decent score.

Next, I will discuss a few questions that I did not answer very well at the time. I made a note of them then, and I will share them here.

##### 1. The differences and relationship between processes and threads
This is actually an operating system question. At the time, it caught me completely off guard. Later, I thought it through carefully, combined it with my own understanding, and came up with an answer. Below is a relatively complete answer. You can prepare for it, and if you are asked this kind of question again, you can answer it perfectly.

>A process is an execution activity of a program with certain independent functionality on a particular data set. A process is an independent unit used by the system for resource allocation and scheduling. A thread is an entity within a process and is the basic unit of CPU scheduling and dispatching. It is a basic unit smaller than a process that can run independently. A thread basically does not own system resources itself; it only owns a few resources essential for execution, such as a program counter, a set of registers, and a stack. However, it can share all resources owned by the process with other threads in the same process. 

>One thread can create and terminate another thread; multiple threads within the same process can execute concurrently.


##### 2. The difference between parallelism and concurrency
>Parallelism means that two or more events occur at the same instant;
Concurrency means that two or more events occur within the same time interval.


##### 3. Discuss your understanding of Block and delegate
My answer at the time was this: delegate callbacks are more process-oriented, whereas block is result-oriented. If you need to be notified throughout a multi-step process, you should use delegation. When you only want to get the information you requested (or an error message when retrieving it), you should use block. (If you combine this with the previous three conclusions, you will find that delegate can maintain state across all events, whereas multiple independent blocks cannot.)

##### 4. Discuss the **similarities and differences between instancetype and id**
1. Similarity: both can be used as a method’s return type

2. Differences:
① instancetype can return an object of the same type as the class where the method is defined, while id can only return an object of an unknown type;  
② instancetype can only be used as a return value and cannot be used as a parameter like id


##### 5. Can you declare properties in a category? Why? If yes, how would you implement it?
When I was asked this kind of question, I immediately felt that it must be possible, but I really did not know how to do it. Later, after looking it up, I found out that it involved Runtime knowledge. Here is the answer:

Adding properties to a Category  
Use Runtime to implement the getter/setter methods
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

##### 6. The Difference Between isKindOfClass and isMemberOfClass
This question is simple, but under interview pressure, just make sure you do not answer it backwards.

isKindOfClass determines whether an object is an instance of a class, or an instance of a subclass derived from that class.  
isMemberOfClass can only determine whether an object is an instance of the current class.

##### 7. How to Prevent a Retain Cycle Inside a block
Use weak references to break the retain cycle inside the block.  
In MRC, __ _block __ does not cause a retain; but in ARC, __ _block __ does cause a retain. In ARC, you should use __ _weak __ or __unsafe_unretained weak references.

##### 8. What Are the Ways to Implement Multithreading in iOS? What Queues Are There in GCD? Are They Concurrent or Serial?
There are mainly three multithreading programming tools in iOS:
1. NSThread
2. NSOperation
3. GCD

dispatch queue is divided into the following three types. By default, the system provides one serial queue, main_queue, and one concurrent queue, global_queue:

There are three types of queues in GCD:
**The main queue:** It has the same functionality as the main thread. In fact, tasks submitted to the main queue are executed on the main thread. The main queue can be obtained by calling dispatch_get_main_queue(). Because the main queue is associated with the main thread, it is a serial queue.

**Global queues:** Global queues are concurrent queues and are shared by the entire process. There are three global queues in a process: high-, medium- (default), and low-priority queues. You can access a queue by calling the dispatch_get_global_queue function and passing in the priority.

**User queues:** User queues (GCD does not call them this, but there is no specific name for this kind of queue, so we call them user queues) are queues created with the function dispatch_queue_create
. These queues are serial. Because of that, they can be used to implement synchronization mechanisms, somewhat like mutexes in traditional threading.

##### 9. Discuss the Difference Between load and initialize

When this question came up, I was honestly stunned for a moment. Although I use them quite often, I had never really paid attention to comparing the two. It seems that when studying, you really do need to ask more “why” questions!

![](https://img.halfrost.com/Blog/ArticleImage/3_2.png)


##### 10. Is Core Data a Database? What Are Its Important Classes?
When I saw that the question asked whether it “is” something, I became cautious and felt that the answer was probably not the obvious one. After thinking it through carefully, Core Data is indeed not a database. It only maps tables to OC objects. Of course, it is not merely a simple mapping; at the bottom layer it still uses Sqlite3 for storage. So Core Data is not a database.

There are the following six important classes:  
(1)NSManagedObjectContext (managed object context)  
Operates on the actual content (operates on the persistence layer)  
Purpose: insert data, query data, delete data  
(2)NSManagedObjectModel (managed object model)  
All database tables or data structures, containing the definition information for each entity  
Purpose: add entity attributes and establish relationships between attributes   
How to operate: visual editor, or code  
(3)NSPersistentStoreCoordinator (persistent store coordinator)  
Equivalent to a database connector  
Purpose: configure the data store’s name, location, storage type, and timing of persistence  
(4)NSManagedObject (managed data record)  
Equivalent to a table record in a database  
(5)NSFetchRequest (data fetch request)  
Equivalent to a query statement  
(6)NSEntityDescription (entity structure)  
Equivalent to a table structure  


##### 11. Are frame and bound Always Equal? If There Are Cases Where They Are Not Equal, Please Give an Example  

![](https://img.halfrost.com/Blog/ArticleImage/3_3.jpeg)


In the image above, if the blue View is rotated, then its frame is the larger outer rectangle, while its bound is the blue border.


The above are the questions I encountered in interviews in March where I either could not answer completely right away or did not answer well. If you are an expert and know all of them, please feel free to ignore this. There were also two open-ended questions, which basically test your actual skill and depth of understanding. One was to discuss your understanding of Runtime, and the other was to discuss your understanding of Runloop. Since my own understanding of these two is not very deep, I will not post my thoughts here. If you also feel that you are lacking in this area, hurry up and read more online!

#### II. Coding Test
This stage usually appears at large companies, or during a second-round interview, because having candidates write code on a machine can quickly distinguish stronger candidates from weaker ones. Of course, I also interviewed at one such company where they just gave me a blank sheet of paper and had me write code by hand throughout the entire process. That is a pure test of fundamentals, because there is no code completion and no compiler to tell you where you made a mistake. Everything depends on your own fundamentals.

Coding tests are basically about algorithm problems. Of course, algorithm problems may also appear as the last few questions in a written test; it depends on how the company arranges the interview.

Two years ago, I also interviewed for iOS roles. At that time, the requirements for algorithms and data structures were very low, and many interviews basically did not ask about them. This year, there were many more of these questions, which was eye-opening for me. It also made me sigh at how quickly technology has developed over the past two years. Interviews now involve algorithms, and the path for programmers who do not know algorithms and data structures will become narrower and narrower.

The algorithm problems I encountered were not difficult. After all, these were not companies like BAT. The simple ones directly ask you to write an algorithm; the slightly more advanced ones provide some background and ask you to solve a problem. In essence, they are just like ACM problems, only not that complex. I will paste a few of the algorithms that were asked most often. For very difficult problems, you can only rely on your own algorithmic foundation.
```c  
Binary search θ(logn)

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

Iterative method
int binarySearch2(int a[] , int low , int high , int findNum)
{    
       while (low <= high)
      {
            int mid = ( low + high) / 2;   //Must be placed inside the while loop
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
        for (i = 0; i < n - 1 - j; i++) //Each outer-loop iteration determines one bubble (largest or smallest), so the inner loop need not process the already sorted part
        {
            if(a[i] > a[i + 1])
            {
                temp = a[i];
                a[i] = a[i + 1];
                a[i + 1] = temp;
            }
        }
}

Quick sort  call as  quickSort(a,0,n);  θ(nlogn)
void quickSort (int a[] , int low , int high)
{
    if (high < low + 2)
        return;
    int start = low;
    int end = high;
    int temp;
    
    while (start < end)
    {
        while ( ++start < high && a[start] <= a[low]);//Find the first position start with a value greater than a[low]

        while ( --end  > low  && a[end]  >= a[low]);//Find the first position end with a value less than a[low]

        //At this point, a[end] < a[low] < a[start], but their physical positions are still low < start < end, so next swap a[start] and a[end]; then everything in [low,start] is less than a[low], and everything in [end,hight] is greater than a[low]
        
        if (start < end)
        {
            temp = a[start];
            a[start]=a[end];
            a[end]=temp;
        }
        //Under the GCC compiler, this form cannot perform the swap, a[start] ^= a[end] ^= a[start] ^= a[end]; a compiler issue
    }
    //At this point, all numbers in [low,end] are less than a[low], and all in [end,higt] are greater than a[low]; just put a[low] in the middle

    //Under the GCC compiler, this form cannot perform the swap, a[low] ^= a[end] ^= a[low] ^= a[end]; a compiler issue
    
    temp = a[low];
    a[low]=a[end];
    a[end]=temp;
    
    //Now it is divided into 3 parts, split by the original pivot a[low]
    quickSort(a, low, end);
    quickSort(a, start, high);
}
```
I’ve also included comments. These algorithms are basically enough to handle most simple algorithm problems.

For data structure questions, I only encountered reversing a linked list, implementing a stack with LIFO semantics, pre-order/in-order/post-order tree traversal, and DFS and BFS on graphs. I won’t paste the code here—it’s too long. If you’ve forgotten any of these, you can go back and review them again.

   
   
#### III. Interview

Interviews basically ask what projects you’ve worked on before, what problems you encountered, how you solved them, your views on XXX, and so on. As long as you usually complete projects seriously, the interview questions are actually easier to answer, because they are all about your projects—the things you understand and know best.


That’s it for the iOS developer hiring market in Shanghai in March 2016, excluding BAT companies. Compared with two years ago, my biggest takeaway is that interviews now cover a broader range of topics and have higher requirements. Nowadays, besides knowing Objective-C, you also need to understand algorithms and data structures. You also need to either know React Native, or a series of hybrid development frameworks like PhoneGap, or be familiar with Swift. Programmers have to keep up with the mainstream to avoid being left behind by the times and to stay competitive. This is also what I learned from interviewing with these companies: you’re never too old to learn! Finally, I hope everyone will communicate with me more. I’m also an iOS beginner, so please feel free to give me your guidance!


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_interview/](https://halfrost.com/ios_interview/)