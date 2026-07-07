+++
author = "一缕殇流化隐半边冰霜"
categories = ["iOS", "Runtime", "msgSend"]
date = 2016-09-17T01:47:58Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/24_0.png"
slug = "objc_runtime_objc_msgsend"
tags = ["iOS", "Runtime", "msgSend"]
title = "Objective-C Runtime Madhouse, Day 2—Message Sending and Forwarding"

+++


#### Preface

More and more apps are now using JSPatch to implement hotfixes. The fundamental reason JSPatch can call and rewrite OC methods from JS is that Objective-C is a dynamic language: all method calls and class creation in OC are performed at runtime through the Objective-C Runtime. We can use class names and method names to reflectively obtain the corresponding classes and methods, and we can also replace a method of a given class with a new implementation. In theory, at runtime you can call any OC method by class name and method name, replace the implementation of any class, and add arbitrary new classes. Today, let’s take a detailed look at the most fascinating aspects of the runtime in OC.

####Table of Contents
- 1.Introduction to the objc_msgSend function
- 2.Message sending phase — objc_msgSend source code analysis
- 3.Message forwarding phase
- 4.Example of forwardInvocation
- 5.Entrance exam
- 6.Optimizations in Runtime


#### 1.Introduction to the objc_msgSend function

When you first encounter the OC Runtime, it almost certainly starts with `[receiver message]`. `[receiver message]` is transformed by the compiler into:
```objectivec

id objc_msgSend ( id self, SEL op, ... );

```
This is a variadic function. The type of the second parameter is `SEL`. In Objective-C, `SEL` is a selector—a method selector.
```objectivec

typedef struct objc_selector *SEL;

```
`objc_selector` is a C string that maps to a method. Note that the `@selector()` selector **is only related to the function name**. Methods with the same name in different classes correspond to the same method selector; even if the method names are the same but the parameter types differ, they will still have the same method selector. Because of this characteristic, Objective-C does not support function overloading.

After the receiver obtains the corresponding selector, if it cannot execute the method itself, the message must be forwarded. Alternatively, a method implementation may be added dynamically at runtime. If the message still cannot be handled after the forwarding process completes, the program will crash.

Therefore, compile time only determines that a message needs to be sent; how that message is handled is something that must be resolved at runtime.

What exactly does the `objc_msgSend` function do? This article, [“objc_msgSend() Tour”](http://www.friday.com/bbum/2009/12/18/objc_msgsend-part-1-the-road-map/), provides a fairly detailed explanation.
```c
1. Check for ignored selectors (GC) and short-circuit.
 2. Check for nil target.
    If nil & nil receiver handler configured, jump to handler
    If nil & no handler (default), cleanup and return.
 3. Search the class’s method cache for the method IMP(use hash to find&store method in cache)
    -1. If found, jump to it.
    -2. Not found: lookup the method IMP in the class itself corresponding its hierarchy chain.
        If found, load it into cache and jump to it.
        If not found, jump to forwarding mechanism.
```
To summarize, `objc_msgSend` does the following:

1. Checks whether this selector should be ignored.
2. Checks whether the target is `nil`.

If there is a corresponding handler for `nil` here, it jumps to that function.
If there is no handler for `nil`, it automatically cleans up the current context and returns. This is why sending a message to `nil` in OC does not crash.

3. After confirming that the message is not being sent to `nil`, it looks up the IMP implementation corresponding to the method in the cache of that class.

If it is found, execution jumps to it.
If it is not found, the lookup continues in the method dispatch table, all the way up to `NSObject`.

![](https://img.halfrost.com/Blog/ArticleImage/24_1.png)


4. If it still cannot be found, the message forwarding phase begins. At this point, the Messaging phase is complete. The main purpose of this phase is to quickly look up the IMP via `select()`.


#### II. Message Sending Messaging Phase — `objc_msgSend` Source Code Analysis

![](https://img.halfrost.com/Blog/ArticleImage/24_2.png)


In this article, [Obj-C Optimization: The faster objc\_msgSend](http://www.mulle-kybernetik.com/artikel/Optimization/opti-9.html), I came across the following C version of the `objc_msgSend` source code.
```objectivec

#include <objc/objc-runtime.h>

id  c_objc_msgSend( struct objc_class /* ahem */ *self, SEL _cmd, ...)
{
   struct objc_class    *cls;
   struct objc_cache    *cache;
   unsigned int         hash;
   struct objc_method   *method;   
   unsigned int         index;
   
   if( self)
   {
      cls   = self->isa;
      cache = cls->cache;
      hash  = cache->mask;
      index = (unsigned int) _cmd & hash;
      
      do
      {
         method = cache->buckets[ index];
         if( ! method)
            goto recache;
         index = (index + 1) & cache->mask;
      }
      while( method->method_name != _cmd);
      return( (*method->method_imp)( (id) self, _cmd));
   }
   return( (id) self);

recache:
   /* ... */
   return( 0);
}
```
There is a do-while loop in the source code; this loop is the process mentioned in the previous chapter for looking up a method in the method dispatch table.

However, in the objc-msg-x86\_64.s file in obj4-680, it is implemented as a section of assembly code.
```asm


/********************************************************************
 *
 * id objc_msgSend(id self, SEL _cmd,...);
 *
 ********************************************************************/
 
 .data
 .align 3
 .globl _objc_debug_taggedpointer_classes
_objc_debug_taggedpointer_classes:
 .fill 16, 8, 0

 ENTRY _objc_msgSend
 MESSENGER_START

 NilTest NORMAL

 GetIsaFast NORMAL  // r11 = self->isa
 CacheLookup NORMAL  // calls IMP on success

 NilTestSupport NORMAL

 GetIsaSupport NORMAL

// cache miss: go search the method lists
LCacheMiss:
 // isa still in r11
 MethodTableLookup %a1, %a2 // r11 = IMP
 cmp %r11, %r11  // set eq (nonstret) for forwarding
 jmp *%r11   // goto *imp

 END_ENTRY _objc_msgSend

 
 ENTRY _objc_msgSend_fixup
 int3
 END_ENTRY _objc_msgSend_fixup

 
 STATIC_ENTRY _objc_msgSend_fixedup
 // Load _cmd from the message_ref
 movq 8(%a2), %a2
 jmp _objc_msgSend
 END_ENTRY _objc_msgSend_fixedup

```
Let's analyze this piece of assembly code.

At first glance, if you split it at `LCacheMiss:`, you can clearly see that `objc_msgSend` does only two things — `CacheLookup` and `MethodTableLookup`.
```asm


/////////////////////////////////////////////////////////////////////
//
// NilTest return-type
//
// Takes: $0 = NORMAL or FPRET or FP2RET or STRET
//  %a1 or %a2 (STRET) = receiver
//
// On exit:  Loads non-nil receiver in %a1 or %a2 (STRET), or returns zero.
//
/////////////////////////////////////////////////////////////////////

.macro NilTest
.if $0 == SUPER  ||  $0 == SUPER_STRET
 error super dispatch does not test for nil
.endif

.if $0 != STRET
 testq %a1, %a1
.else
 testq %a2, %a2
.endif
 PN
 jz LNilTestSlow_f
.endmacro

```
NilTest is used to check whether something is nil. There are four possible arguments: NORMAL / FPRET / FP2RET / STRET.

The argument passed to objc\_msgSend is NilTest NORMAL  
The argument passed to objc\_msgSend\_fpret is NilTest FPRET  
The argument passed to objc\_msgSend\_fp2ret is NilTest FP2RET  
The argument passed to objc\_msgSend\_stret is NilTest STRET


If the receiver of the method being checked is nil, the system will automatically clean up and return.


The GetIsaFast macro can quickly obtain the object's isa pointer address (placing it in the r11 register; r10 will be overwritten; on the arm architecture, it is assigned directly to r9).
```asm


.macro CacheLookup
 
 ldrh r12, [r9, #CACHE_MASK] // r12 = mask
 ldr r9, [r9, #CACHE] // r9 = buckets
.if $0 == STRET  ||  $0 == SUPER_STRET
 and r12, r12, r2  // r12 = index = SEL & mask
.else
 and r12, r12, r1  // r12 = index = SEL & mask
.endif
 add r9, r9, r12, LSL #3 // r9 = bucket = buckets+index*8
 ldr r12, [r9]  // r12 = bucket->sel
2:
.if $0 == STRET  ||  $0 == SUPER_STRET
 teq r12, r2
.else
 teq r12, r1
.endif
 bne 1f
 CacheHit $0
1: 
 cmp r12, #1
 blo LCacheMiss_f  // if (bucket->sel == 0) cache miss
 it eq   // if (bucket->sel == 1) cache wrap
 ldreq r9, [r9, #4]  // bucket->imp is before first bucket
 ldr r12, [r9, #8]!  // r12 = (++bucket)->sel
 b 2b

.endmacro

```
r12 stores the method, and r9 stores the cache. r1 and r2 are SELs. In the CacheLookup function, SEL is repeatedly compared with bucket\->sel in the cache. If r12 == 0, execution jumps to the LCacheMiss\_f label to continue. If r12 is found, r12 == 1, meaning the corresponding SEL has been found in the cache, then the IMP (stored in r10) is executed directly.

When the program jumps to LCacheMiss, it means there is no entry in the cache—a cache miss. At this point, it proceeds to the next phase: MethodTableLookup.
```asm

/////////////////////////////////////////////////////////////////////
//
// MethodTableLookup classRegister, selectorRegister
//
// Takes: $0 = class to search (a1 or a2 or r10 ONLY)
//  $1 = selector to search for (a2 or a3 ONLY)
//   r11 = class to search
//
// On exit: imp in %r11
//
/////////////////////////////////////////////////////////////////////
.macro MethodTableLookup

 MESSENGER_END_SLOW
 
 SaveRegisters

 // _class_lookupMethodAndLoadCache3(receiver, selector, class)

 movq $0, %a1
 movq $1, %a2
 movq %r11, %a3
 call __class_lookupMethodAndLoadCache3

 // IMP is now in %rax
 movq %rax, %r11

 RestoreRegisters

.endmacro

```
`MethodTableLookup` can be considered an interface-layer macro. It is mainly used to save the environment and prepare parameters in order to call the \_\_class\_lookupMethodAndLoadCache3 function (in objc-class.mm). Specifically, it passes the three parameters `receiver`, `selector`, and `class` to $0, $1, and r11, then calls the `lookupMethodAndLoadCache3` method. Finally, it returns the IMP (moving it from r11 to rax). The IMP is then invoked in objc\_msgSend.
```c


/***********************************************************************
* _class_lookupMethodAndLoadCache.
* Method lookup for dispatchers ONLY. OTHER CODE SHOULD USE lookUpImp().
* This lookup avoids optimistic cache scan because the dispatcher 
* already tried that.
**********************************************************************/
IMP _class_lookupMethodAndLoadCache3(id obj, SEL sel, Class cls)
{        
    return lookUpImpOrForward(cls, sel, obj, 
                              YES/*initialize*/, NO/*cache*/, YES/*resolver*/);
}
```
\_\_class\_lookupMethodAndLoadCache3 is also an interface layer (written in C). This function provides the corresponding parameter configuration; the actual functionality resides in the lookUpImpOrForward function.

Now let’s look at the implementation of the lookUpImpOrForward function.
```objectivec

IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                       bool initialize, bool cache, bool resolver)
{
    Class curClass;
    IMP imp = nil;
    Method meth;
    bool triedResolver = NO;

    /*
    The middle part is the lookup process; see below for a detailed analysis.
    */

    // paranoia: look for ignored selectors with non-ignored implementations
    assert(!(ignoreSelector(sel)  &&  imp != (IMP)&_objc_ignored_method));

    // paranoia: never let uncached leak out
    assert(imp != _objc_msgSend_uncached_impcache);

    return imp;
}

```
Next, let’s analyze it line by line.
```objectivec

    runtimeLock.assertUnlocked();

```
`runtimeLock.assertUnlocked();` adds a read-write lock to ensure thread safety.
```objectivec

    // Optimistic cache lookup
    if (cache) {
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }
```
The fifth new parameter of lookUpImpOrForward is a Boolean indicating whether to look up the cache. If YES is passed in, the cache\_getImp method will be called to find the IMP in the cache.
```asm

/********************************************************************
 * IMP cache_getImp(Class cls, SEL sel)
 *
 * On entry: a1 = class whose cache is to be searched
 *  a2 = selector to search for
 *
 * If found, returns method implementation.
 * If not found, returns NULL.
 ********************************************************************/

 STATIC_ENTRY _cache_getImp

// do lookup
 movq %a1, %r11  // move class to r11 for CacheLookup
 CacheLookup GETIMP  // returns IMP on success

LCacheMiss:
// cache miss, return nil
 xorl %eax, %eax
 ret

LGetImpExit:
 END_ENTRY  _cache_getImp


```
`cache_getImp` puts the found IMP in `r11`.
```objectivec

    if (!cls->isRealized()) {
        rwlock_writer_t lock(runtimeLock);
        realizeClass(cls);
    }

```
Calling the realizeClass method allocates readable and writable space for class\_rw\_t.
```objectivec

    if (initialize  &&  !cls->isInitialized()) {
        _class_initialize (_class_getNonMetaClass(cls, inst));
    }

```
\_class\_initialize is the process of class initialization.
```objectivec

retry:
    runtimeLock.read();

```
`runtimeLock.read();` adds a read lock here. Because methods can be added dynamically at runtime, locking is required to ensure thread safety. From here on, there will be five places below that `goto done`, and one place that `goto retry`.
```objectivec

 done:
    runtimeLock.unlockRead();

```
By the time execution reaches done, the IMP lookup has completed, so the read lock can be released.
```objectivec

    // Ignore GC selectors
    if (ignoreSelector(sel)) {
        imp = _objc_ignored_method;
        cache_fill(cls, sel, imp, inst);
        goto done;
    }

```
The following GC selectors are used to ignore methods used by macOS’s GC (garbage collection) mechanism; iOS does not have this step. If they are ignored, cache\_fill is performed, and execution then jumps to goto done.
```objectivec

void cache_fill(Class cls, SEL sel, IMP imp, id receiver)
{

#if !DEBUG_TASK_THREADS
    mutex_locker_t lock(cacheUpdateLock);
    cache_fill_nolock(cls, sel, imp, receiver);

#else
    _collecting_in_critical();
    return;

#endif
}


static void cache_fill_nolock(Class cls, SEL sel, IMP imp, id receiver)
{
    cacheUpdateLock.assertLocked();

    // Never cache before +initialize is done
    if (!cls->isInitialized()) return;

    // Make sure the entry wasn't added to the cache by some other thread 
    // before we grabbed the cacheUpdateLock.
    if (cache_getImp(cls, sel)) return;

    cache_t *cache = getCache(cls);
    cache_key_t key = getKey(sel);

    // Use the cache as-is if it is less than 3/4 full
    mask_t newOccupied = cache->occupied() + 1;
    mask_t capacity = cache->capacity();
    if (cache->isConstantEmptyCache()) {
        // Cache is read-only. Replace it.
        cache->reallocate(capacity, capacity ?: INIT_CACHE_SIZE);
    }
    else if (newOccupied <= capacity / 4 * 3) {
        // Cache is less than 3/4 full. Use it as-is.
    }
    else {
        // Cache is too full. Expand it.
        cache->expand();
    }
    bucket_t *bucket = cache->find(key, receiver);
    if (bucket->key() == 0) cache->incrementOccupied();
    bucket->set(key, imp);
}

```
In cache\_fill, the cache\_fill\_nolock function is also called. If the contents in the cache exceed 3/4 of its capacity, the cache is expanded, doubling its size. It then finds the first empty bucket\_t and fills it in the form of (SEL, IMP).
```objectivec

    // Try this class's cache.

    imp = cache_getImp(cls, sel);
    if (imp) goto done;

```
If it is not ignored, it attempts again to retrieve the `IMP` from the class’s cache. If found, it will also jump to `goto done`.
```objectivec


    // Try this class's method lists.

    meth = getMethodNoSuper_nolock(cls, sel);
    if (meth) {
        log_and_fill_cache(cls, meth->imp, sel, inst, cls);
        imp = meth->imp;
        goto done;
    }

```
If the lookup in the cache fails, then search the class method list. Once found, jump to `goto done`.
```objectivec

    // Try superclass caches and method lists.

    curClass = cls;
    while ((curClass = curClass->superclass)) {
        // Superclass cache.
        imp = cache_getImp(curClass, sel);
        if (imp) {
            if (imp != (IMP)_objc_msgForward_impcache) {
                // Found the method in a superclass. Cache it in this class.
                log_and_fill_cache(cls, imp, sel, inst, curClass);
                goto done;
            }
            else {
                // Found a forward:: entry in a superclass.
                // Stop searching, but don't cache yet; call method 
                // resolver for this class first.
                break;
            }
        }

```
If all the attempts above fail, it will then repeatedly try the superclass’s cache and method list, continuing until it reaches `NSObject`. Since `NSObject`’s `superclass` is `nil`, the loop then exits.

If the `IMP` for that `method` is found in a superclass, the method should then be cached back into the current class’s own cache. After the fill is complete, execution jumps to the `goto done` statement.
```objectivec

        // Superclass method list.
        meth = getMethodNoSuper_nolock(curClass, sel);
        if (meth) {
            log_and_fill_cache(cls, meth->imp, sel, inst, curClass);
            imp = meth->imp;
            goto done;
        }
    }


```
If the IMP is not found in the superclass's cache, continue searching the superclass's method list. If it is found, jump to the goto done statement.
```objectivec

static method_t * getMethodNoSuper_nolock(Class cls, SEL sel)
{
    runtimeLock.assertLocked();

    assert(cls->isRealized());
    // fixme nil cls? 
    // fixme nil sel?

    for (auto mlists = cls->data()->methods.beginLists(), 
              end = cls->data()->methods.endLists(); 
         mlists != end;
         ++mlists)
    {
        method_t *m = search_method_list(*mlists, sel);
        if (m) return m;
    }

    return nil;
}

```
Here we can analyze the method lookup process. In the getMethodNoSuper\_nolock method, it traverses the methodList linked list once, from begin to end. During the traversal, it calls the search\_method\_list function.
```objectivec

static method_t *search_method_list(const method_list_t *mlist, SEL sel)
{
    int methodListIsFixedUp = mlist->isFixedUp();
    int methodListHasExpectedSize = mlist->entsize() == sizeof(method_t);
    
    if (__builtin_expect(methodListIsFixedUp && methodListHasExpectedSize, 1)) {
        return findMethodInSortedMethodList(sel, mlist);
    } else {
        // Linear search of unsorted method list
        for (auto& meth : *mlist) {
            if (meth.name == sel) return &meth;
        }
    }

#if DEBUG
    // sanity-check negative results
    if (mlist->isFixedUp()) {
        for (auto& meth : *mlist) {
            if (meth.name == sel) {
                _objc_fatal("linear search worked when binary search did not");
            }
        }
    }

#endif

    return nil;
}


```
In the search\_method\_list function, it checks whether the current methodList is sorted. If it is sorted, it calls findMethodInSortedMethodList; the implementation of that method is a binary search, so I won’t paste the code here. If it is not sorted, it falls back to a naive linear traversal search.
```objectivec


    // No implementation found. Try method resolver once.

    if (resolver  &&  !triedResolver) {
        runtimeLock.unlockRead();
        _class_resolveMethod(cls, sel, inst);
        // Don't cache the result; we don't hold the lock so it may have 
        // changed already. Re-do the search from scratch instead.
        triedResolver = YES;
        goto retry;
    }

```
If the superclass chain has been searched all the way up to NSObject and the method still hasn’t been found, the runtime will start trying \_class\_resolveMethod. Note that the read lock needs to be released here, because the developer may dynamically add a method implementation at this point, so the result should not be cached. Since the lock has been released, threading issues may occur here. Therefore, after \_class\_resolveMethod finishes executing, it will `goto retry` and run through the previous lookup process again.
```objectivec

/***********************************************************************
* _class_resolveMethod
* Call +resolveClassMethod or +resolveInstanceMethod.
* Returns nothing; any result would be potentially out-of-date already.
* Does not check if the method already exists.
**********************************************************************/
void _class_resolveMethod(Class cls, SEL sel, id inst)
{
    if (! cls->isMetaClass()) {
        // try [cls resolveInstanceMethod:sel]
        _class_resolveInstanceMethod(cls, sel, inst);
    } 
    else {
        // try [nonMetaClass resolveClassMethod:sel]
        // and [cls resolveInstanceMethod:sel]
        _class_resolveClassMethod(cls, sel, inst);
        if (!lookUpImpOrNil(cls, sel, inst, 
                            NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
        {
            _class_resolveInstanceMethod(cls, sel, inst);
        }
    }
}


```
This function first checks whether it is a meta-class. If it is not a metaclass, it executes \_class\_resolveInstanceMethod; if it is a metaclass, it executes \_class\_resolveClassMethod. There is a call to lookUpImpOrNil here.
```objectivec


IMP lookUpImpOrNil(Class cls, SEL sel, id inst, 
                   bool initialize, bool cache, bool resolver)
{
    IMP imp = lookUpImpOrForward(cls, sel, inst, initialize, cache, resolver);
    if (imp == _objc_msgForward_impcache) return nil;
    else return imp;
}

```
In this function implementation, `lookUpImpOrForward` is also called to look up whether an implementation exists for the passed-in `sel`, but the return value may still be `nil`. When `imp == \_objc\_msgForward\_impcache`, it returns `nil`. `\_objc\_msgForward\_impcache` is a marker used to indicate that the lookup should stop continuing through the superclass cache.
```objectivec

IMP class_getMethodImplementation(Class cls, SEL sel)
{
    IMP imp;

    if (!cls  ||  !sel) return nil;

    imp = lookUpImpOrNil(cls, sel, nil, 
                         YES/*initialize*/, YES/*cache*/, YES/*resolver*/);

    // Translate forwarding function to C-callable external version
    if (!imp) {
        return _objc_msgForward;
    }

    return imp;
}
```
Returning to the implementation of \_class\_resolveMethod, if lookUpImpOrNil returns nil, it means it was found in the superclass’s cache, so \_class\_resolveInstanceMethod needs to be called again to ensure that the corresponding IMP has been added for sel.
```objectivec

    // No implementation found, and method resolver didn't help. 
    // Use forwarding.

    imp = (IMP)_objc_msgForward_impcache;
    cache_fill(cls, sel, imp, inst);

```
Back in the lookUpImpOrForward method, if no IMP implementation is found either, then the method resolver is no longer useful, and execution can only enter the message forwarding stage. Before entering this stage, imp becomes \_objc\_msgForward\_impcache. Finally, it is added to the cache.


#### III. Message Forwarding Phase

Once the forwarding stage is reached, the id \_objc\_msgForward(id self, SEL \_cmd,...) method is called. Its assembly implementation can be found in objc-msg-x86\_64.s.
```asm

 STATIC_ENTRY __objc_msgForward_impcache
 // Method cache version

 // THIS IS NOT A CALLABLE C FUNCTION
 // Out-of-band condition register is NE for stret, EQ otherwise.

 MESSENGER_START
 nop
 MESSENGER_END_SLOW
 
 jne __objc_msgForward_stret
 jmp __objc_msgForward

 END_ENTRY __objc_msgForward_impcache
 
 
 ENTRY __objc_msgForward
 // Non-stret version

 movq __objc_forward_handler(%rip), %r11
 jmp *%r11

 END_ENTRY __objc_msgForward

```
After executing \_objc\_msgForward, the \_\_objc\_forward\_handler function is called.
```objectivec


// Default forward handler halts the process.
__attribute__((noreturn)) void objc_defaultForwardHandler(id self, SEL sel)
{
    _objc_fatal("%c[%s %s]: unrecognized selector sent to instance %p "
                "(no message forward handler is installed)", 
                class_isMetaClass(object_getClass(self)) ? '+' : '-', 
                object_getClassName(self), sel_getName(sel), self);
}

```
In the latest Objc2.0, there is an objc\_defaultForwardHandler. Looking at the source implementation, we can see a familiar statement. When we send an unimplemented method to an object, and its superclass does not have that method either, the program will crash with an error message similar to: unrecognized selector sent to instance, followed by some stack information. That information comes from here.
```objectivec


void *_objc_forward_handler = (void*)objc_defaultForwardHandler;

#if SUPPORT_STRET
struct stret { int i[100]; };
__attribute__((noreturn)) struct stret objc_defaultForwardStretHandler(id self, SEL sel)
{
    objc_defaultForwardHandler(self, sel);
}
void *_objc_forward_stret_handler = (void*)objc_defaultForwardStretHandler;

#endif

#endif

void objc_setForwardHandler(void *fwd, void *fwd_stret)
{
    _objc_forward_handler = fwd;

#if SUPPORT_STRET
    _objc_forward_stret_handler = fwd_stret;

#endif
}

```
To set up forwarding, you only need to override the \_objc\_forward\_handler method. In the objc\_setForwardHandler method, you can set the ForwardHandler.

However, when you try to understand the call stack for objc\_setForwardHandler, you’ll find that the entry point cannot be printed. That’s because Apple has done a bit of sleight of hand here. To understand the invocation of objc\_setForwardHandler, as well as the subsequent message-forwarding call stack, you’ll need some reverse-engineering knowledge. I recommend reading the following two articles to understand the underlying principles.

[Objective-C Message Sending and Forwarding Mechanism](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)  
[Hmmm, What’s that Selector?](http://arigrant.com/blog/2013/12/13/a-selector-left-unhandled)

Back to message forwarding. When no corresponding IMP can be found for the current SEL, developers can override the - (id)forwardingTargetForSelector:(SEL)aSelector method to “swap in” another receiver, replacing the message’s recipient with an object that can handle the message.
```objectivec


- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if(aSelector == @selector(Method:)){
        return otherObject;
    }
    return [super forwardingTargetForSelector:aSelector];
}

```
Of course, class methods can also be replaced; in that case, you need to override + (id)forwardingTargetForSelector:(SEL)aSelector, and return a class object.
```objectivec


+ (id)forwardingTargetForSelector:(SEL)aSelector {
    if(aSelector == @selector(xxx)) {
        return NSClassFromString(@"Class name");
    }
    return [super forwardingTargetForSelector:aSelector];
}

```
This step looks for a fallback receiver for the message. If this step returns `nil`, the recovery mechanism fails completely. The Runtime system will send the object a `methodSignatureForSelector:` message and use the returned method signature to create an `NSInvocation` object. This generates an `NSMethodSignature` object for the subsequent full message forwarding process. The `NSMethodSignature` object is wrapped into an `NSInvocation` object, and the `forwardInvocation:` method can then handle the `NSInvocation`.

Next, before crashing due to an unrecognized method, the system performs a full message forwarding pass.

We only need to override the following method to customize our own forwarding logic.
```objectivec

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if ([someOtherObject respondsToSelector:
         [anInvocation selector]])
        [anInvocation invokeWithTarget:someOtherObject];
    else
        [super forwardInvocation:anInvocation];
}

```
After implementing this method, if it determines that a particular invocation should not be handled by this class, it will call the superclass’s method with the same name. In this way, every class in the inheritance hierarchy gets a chance to handle the method invocation request, all the way up to the root class, NSObject. If NSObject still cannot handle the message, then there is nothing left to recover; a `doesNotRecognizeSelector` exception can only be thrown.


At this point, the processes of message sending and forwarding should be clear.

![](https://img.halfrost.com/Blog/ArticleImage/24_3.png)


#### 4. An Example of forwardInvocation

![](https://img.halfrost.com/Blog/ArticleImage/24_4.png)


Here I’d like to give an interesting example to demonstrate how to use forwardInvocation.


In this example, we will use the runtime message forwarding mechanism to create a dynamic proxy, and use that dynamic proxy to forward messages. Here we will use another somewhat mysterious class among the base classes: NSProxy.

NSProxy, like NSObject, is a base class in OC. However, NSProxy is an abstract base class and cannot be instantiated directly; it can be used to implement the proxy pattern. By implementing a simplified set of methods, it intercepts and handles all messages on behalf of the target object. The NSProxy class also implements the methods declared by the NSObject protocol, and it has two methods that must be implemented.
```objectivec

- (void)forwardInvocation:(NSInvocation *)invocation;
- (nullable NSMethodSignature *)methodSignatureForSelector:(SEL)sel NS_SWIFT_UNAVAILABLE("NSInvocation and related APIs not available");

```
One additional point to note is that subclasses of the `NSProxy` class must declare and implement at least one `init` method so that they conform to the Objective-C convention for creating and initializing objects. The Foundation framework also contains several concrete implementations of the `NSProxy` class.

- `NSDistantObject` class: Defines a proxy class for objects in other applications or threads.
- `NSProtocolChecker` class: Defines an object that can be used to restrict which messages may be sent to another object.

Next, let’s take a look at the fun example below.
```objectivec

#import <Foundation/Foundation.h>

@interface Student : NSObject
-(void)study:(NSString *)subject andRead:(NSString *)bookName;
-(void)study:(NSString *)subject :(NSString *)bookName;
@end

```
Define a `student` class with any two methods.
```objectivec

#import "Student.h"

#import <objc/runtime.h>

@implementation Student

-(void)study:(NSString *)subject :(NSString *)bookName
{
    NSLog(@"Invorking method on %@ object with selector %@",[self class],NSStringFromSelector(_cmd));
}

-(void)study:(NSString *)subject andRead:(NSString *)bookName
{
    NSLog(@"Invorking method on %@ object with selector %@",[self class],NSStringFromSelector(_cmd));
}
@end

```
Add log messages to the implementations of both methods so that, when printing later, it’s easy to tell which method was called.
```objectivec

#import <Foundation/Foundation.h>

#import "Invoker.h"

@interface AspectProxy : NSProxy

/** The real object to which messages are forwarded via the NSProxy instance */
@property(strong) id proxyTarget;
/** Instance of a class capable of implementing cross-cutting functionality (conforming to the Invoker protocol) */
@property(strong) id<Invoker> invoker;
/** Defines which messages will invoke cross-cutting functionality */
@property(readonly) NSMutableArray *selectors;

// Initialization method for AspectProxy class instances
- (id)initWithObject:(id)object andInvoker:(id<Invoker>)invoker;
- (id)initWithObject:(id)object selectors:(NSArray *)selectors andInvoker:(id<Invoker>)invoker;
// Add a selector to the current selector list
- (void)registerSelector:(SEL)selector;

@end

```
Define an AspectProxy class specifically for forwarding messages.
```objectivec

#import "AspectProxy.h"

@implementation AspectProxy

- (id)initWithObject:(id)object selectors:(NSArray *)selectors andInvoker:(id<Invoker>)invoker{
    _proxyTarget = object;
    _invoker = invoker;
    _selectors = [selectors mutableCopy];
    
    return self;
}

- (id)initWithObject:(id)object andInvoker:(id<Invoker>)invoker{
    return [self initWithObject:object selectors:nil andInvoker:invoker];
}

// Add another selector
- (void)registerSelector:(SEL)selector{
    NSValue *selValue = [NSValue valueWithPointer:selector];
    [self.selectors addObject:selValue];
}

// Return an NSMethodSignature instance for the method invoked on the target object
// The runtime system requires this method to be implemented when performing standard forwarding
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
    return [self.proxyTarget methodSignatureForSelector:sel];
}

/**
 *  When the selector for the target method call matches a selector registered in the AspectProxy object, forwardInvocation: will
 *  call the method on the target object and invoke AOP (aspect-oriented programming) functionality based on the conditional result
 */
- (void)forwardInvocation:(NSInvocation *)invocation{
    // Execute cross-cutting functionality before calling the target method
    if ([self.invoker respondsToSelector:@selector(preInvoke:withTarget:)]) {
        if (self.selectors != nil) {
            SEL methodSel = [invocation selector];
            for (NSValue *selValue in self.selectors) {
                if (methodSel == [selValue pointerValue]) {
                    [[self invoker] preInvoke:invocation withTarget:self.proxyTarget];
                    break;
                }
            }
        }else{
            [[self invoker] preInvoke:invocation withTarget:self.proxyTarget];
        }
    }
    
    // Call the target method
    [invocation invokeWithTarget:self.proxyTarget];
    
    // Execute cross-cutting functionality after calling the target method
    if ([self.invoker respondsToSelector:@selector(postInvoke:withTarget:)]) {
        if (self.selectors != nil) {
            SEL methodSel = [invocation selector];
            for (NSValue *selValue in self.selectors) {
                if (methodSel == [selValue pointerValue]) {
                    [[self invoker] postInvoke:invocation withTarget:self.proxyTarget];
                    break;
                }
            }
        }else{
            [[self invoker] postInvoke:invocation withTarget:self.proxyTarget];
        }
    }
}
```
Next, we define a proxy protocol.
```objectivec

#import <Foundation/Foundation.h>

@protocol Invoker <NSObject>

@required
// Perform cross-cutting functionality before invoking a method on the object
- (void)preInvoke:(NSInvocation *)inv withTarget:(id)target;
@optional
// Perform cross-cutting functionality after invoking a method on the object
- (void)postInvoke:(NSInvocation *)inv withTarget:(id)target;

@end
```
Finally, a class that conforms to the protocol is also required.
```objectivec

#import <Foundation/Foundation.h>

#import "Invoker.h"

@interface AuditingInvoker : NSObject<Invoker>//conforms to the Invoker protocol
@end


#import "AuditingInvoker.h"

@implementation AuditingInvoker

- (void)preInvoke:(NSInvocation *)inv withTarget:(id)target{
    NSLog(@"before sending message with selector %@ to %@ object", NSStringFromSelector([inv selector]),[target className]);
}
- (void)postInvoke:(NSInvocation *)inv withTarget:(id)target{
    NSLog(@"after sending message with selector %@ to %@ object", NSStringFromSelector([inv selector]),[target className]);

}
@end
```
In this class conforming to the delegate protocol, we only implement the two methods in the protocol.

Write the test code
```objectivec

#import <Foundation/Foundation.h>

#import "AspectProxy.h"

#import "AuditingInvoker.h"

#import "Student.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        id student = [[Student alloc] init];

        // Set the selector array registered in the proxy
        NSValue *selValue1 = [NSValue valueWithPointer:@selector(study:andRead:)];
        NSArray *selValues = @[selValue1];
        // Create AuditingInvoker
        AuditingInvoker *invoker = [[AuditingInvoker alloc] init];
        // Create studentProxy, a proxy for the Student object
        id studentProxy = [[AspectProxy alloc] initWithObject:student selectors:selValues andInvoker:invoker];
        
        // Send a message to the proxy using the specified selector---example 1
        [studentProxy study:@"Computer" andRead:@"Algorithm"];
        
        // Send a message to this proxy using another selector not yet registered with the proxy!---example 2
        [studentProxy study:@"mathematics" :@"higher mathematics"];
        
        // Register a selector for this proxy and send it a message again---example 3
        [studentProxy registerSelector:@selector(study::)];
        [studentProxy study:@"mathematics" :@"higher mathematics"];
    }
    return 0;
}
```
Here are three examples. What will each of them output?
```vim


before sending message with selector study:andRead: to Student object
Invorking method on Student object with selector study:andRead:
after sending message with selector study:andRead: to Student object

Invorking method on Student object with selector study::

before sending message with selector study:: to Student object
Invorking method on Student object with selector study::
after sending message with selector study:: to Student object

```
Example 1 will output three lines. Calling the `study:andRead:` method on the proxy of the `Student` object will cause the proxy to call the `preInvoker:` method on the `AuditingInvoker` object, the `study:andRead:` method on the real target (the `Student` object), and the `postInvoker:` method on the `AuditingInvoker` object. A single method call triggers three method calls. The reason is that the `study:andRead:` method was registered through the proxy of the `Student` object.

Example 2 will output only one line. Calling the `study::` method on the proxy of the `Student` object, because this method has not yet been registered through the proxy, will only cause the program to forward the message for that method call to the `Student` object; it will not call the `AuditorInvoker` method.

Example 3 will output three lines again. Because `study::` has been registered through this proxy, when the program calls it again, during this call the program will invoke the AOP methods on the `AuditingInvoker` object and the `study::` method on the real target (the `Student` object).

This example implements a simple form of AOP (Aspect Oriented Programming). We “slice” out each piece of functionality and separate it from the rest, which improves the modularity of the program. AOP enables decoupling as well as dynamic composition. Through precompilation or runtime dynamic proxies, it can dynamically and uniformly add functionality to a program without modifying the source code. For example, in Example 3 above, by registering a method with the dynamic proxy class, we enable that class to handle the method as well.


#### V. Entrance Exam

![](https://img.halfrost.com/Blog/ArticleImage/23_18.png)


>What will the following code do? Compile Error / Runtime Crash / NSLog…?
```objectivec

     @interface NSObject (Sark)
     + (void)foo;
     - (void)foo;
     @end

     @implementation NSObject (Sark)
     - (void)foo
     {
        NSLog(@"IMP: -[NSObject(Sark) foo]");
     }

     @end

     int main(int argc, const char * argv[]) {
        @autoreleasepool {
          [NSObject foo];
          [[NSObject new] foo];
      }
       return 0;
     }
```
There are two tricky points in this question. The first is that a category is added to `NSObject`: the category declares a plus-sign class method, but the implementation provides a minus-sign instance method. In `main`, `foo` is called on `NSObject`. Will this cause a compile error, or will it crash?

The second tricky point is: what will it output?


Let’s first look at the first point. This involves knowledge of Category. The recommended article is still Meituan’s classic piece: [A Deep Understanding of Objective-C: Category](http://tech.meituan.com/DiveIntoCategory.html)
```objectivec

void _objc_init(void)
{
    static bool initialized = false;
    if (initialized) return;
    initialized = true;
    
    // fixme defer initialization until an objc-using image is found?
    environ_init();
    tls_init();
    lock_init();
    exception_init();
    
    // Register for unmap first, in case some +load unmaps something
    _dyld_register_func_for_remove_image(&unmap_image);
    dyld_register_image_state_change_handler(dyld_image_state_bound,
                                             1/*batch*/, &map_images);
    dyld_register_image_state_change_handler(dyld_image_state_dependents_initialized, 0/*not batch*/, &load_images);
}
```
During OC initialization, it loads `map_images`; `map_images` eventually calls the `_read_images` method in `objc-runtime-new.mm`. Inside `_read_images`, the in-memory maps are initialized. At this point, all classes, protocols, and categories are loaded. `NSOBject`’s `+load` method is called at this stage.
```objectivec

// Discover categories.
for (EACH_HEADER) {
    category_t **catlist =
    _getObjc2CategoryList(hi, &count);
    for (i = 0; i < count; i++) {
        category_t *cat = catlist[i];
        class_t *cls = remapClass(cat->cls);
        
        if (!cls) {
            // Category's target class is missing (probably weak-linked).
            // Disavow any knowledge of this category.
            catlist[i] = NULL;
            if (PrintConnecting) {
                _objc_inform("CLASS: IGNORING category \?\?\?(%s) %p with "
                             "missing weak-linked target class",
                             cat->name, cat);
            }
            continue;
        }
        
        // Process this category.
        // First, register the category with its target class.
        // Then, rebuild the class's method lists (etc) if
        // the class is realized.
        BOOL classExists = NO;
        if (cat->instanceMethods ||  cat->protocols
            ||  cat->instanceProperties)
        {
            addUnattachedCategoryForClass(cat, cls, hi);
            if (isRealized(cls)) {
                remethodizeClass(cls);
                classExists = YES;
            }
            if (PrintConnecting) {
                _objc_inform("CLASS: found category -%s(%s) %s",
                             getName(cls), cat->name,
                             classExists ? "on existing class" : "");
            }
        }
        
        if (cat->classMethods  ||  cat->protocols
            /* ||  cat->classProperties */)
        {
            addUnattachedCategoryForClass(cat, cls->isa, hi);
            if (isRealized(cls->isa)) {
                remethodizeClass(cls->isa);
            }
            if (PrintConnecting) {
                _objc_inform("CLASS: found category +%s(%s)",
                             getName(cls), cat->name);
            }
        }
    }
}

```
During this loading process, the for loop repeatedly calls the \_getObjc2CategoryList
method. The specific implementation of this method is:
```objectivec

//      function name                 content type     section name
GETSECT(_getObjc2CategoryList,        category_t *,    "__objc_catlist");

```
The last parameter, \_\_objc\_catlist, is the category array that the compiler just generated.

After all categories have been loaded, these categories start being processed. The overall approach is still to split them into two types and handle them separately.
```objectivec

if (cat->instanceMethods || cat->protocols || cat->instanceProperties){
}

```
The first category is instance methods.
```objectivec


if (cat->classMethods || cat->protocols /* || cat->classProperties */) {
}
```
The second category is class methods.

The result after processing is:  
1)、The category’s instance methods, protocols, and properties are added to the class.
2)、The category’s class methods and protocols are added to the class’s metaclass.

The handling in these two cases is largely the same: first, `addUnattachedCategoryForClass` is called to allocate memory and assign space. Inside `remethodizeClass`, the `attachCategories` method is called.

I won’t paste the code for `attachCategories` here; if you’re interested, you can take a look yourself. This method uses head insertion to insert newly added methods at the front of the method list. It also calls `flushCaches` at the end.

This is why we can override existing methods in a Category: because head insertion puts the new method at the front of the list, so it will be traversed first.


That is the overall flow when a Category is loaded.

Now back to the original question. When loading the Category on `NSObject`, the compiler will warn that we have not implemented the `+(void)foo` method, because no `+` method is found in the `.m` file; instead, there is a `-` method, so it emits a warning.

However, when the Category is actually loaded, `-(void)foo` is loaded. Since it is an instance method, it is placed in `NSObject`’s instance method list.

Based on the `objc_msgSend` source implementation analyzed in Chapter 2, we know that:

When `[NSObject foo]` is called, it first looks for the IMP of the `foo` method in `NSObject`’s meta-class. If it is not found, it continues searching in the superclass. The superclass of `NSObject`’s meta-class is `NSObject` itself, so the lookup returns to `NSObject`’s class method lookup path, where it finds the `foo` method, executes it, and prints the output.
```vim

IMP: -[NSObject(Sark) foo]

```
When `[[NSObject new] foo]` is called, an `NSObject` object is created first. Then, when this `NSObject` instance is used to call the `foo` method, it will look it up in `NSObject`’s class methods, find it, and therefore also produce output.
```vim

IMP: -[NSObject(Sark) foo]

```
So for the question above, it will not produce a Compile Error, much less a Runtime Crash, and it will output two identical results.


#### VI. Optimizations in the Runtime


![](https://img.halfrost.com/Blog/ArticleImage/24_5.png)


There are three areas in the Runtime system where optimizations are applied.

- 1.Method-list caching
- 2.Virtual function table vTable
- 3.dyld shared cache

##### 1.Method-list caching

During message sending, the process of looking up an IMP checks the cache first. This cache stores recently used methods. It works somewhat like the cache in a CPU. The rationale is that a method that has been called may very likely be called frequently. Without this cache, the runtime would have to search directly through the class method list, which would be far too inefficient. Therefore, IMP lookup searches the method cache first; if it is not found there, it then looks for the IMP in the virtual function table. If it is found, the IMP is stored in the cache for later use.

Because of this design, the Runtime system can perform method lookup quickly and efficiently.


##### 2.Virtual function table

A virtual function table, also known as a dispatch table, is a common mechanism used by programming languages to support dynamic binding. The Objective-C Runtime library implements a custom virtual-function-table dispatch mechanism. This table is designed specifically to improve performance and flexibility. The virtual function table is an array used to store values of type IMP. Every object-class has a pointer to such a virtual function table.


##### 3.dyld shared cache

In our programs, there are inevitably many custom classes, and among these classes many SELs have the same name, such as alloc, init, and so on. The Runtime system needs to assign a SEL pointer to every method, and then update the metadata for each method invocation to obtain a unique value. This process is completed when the application starts. To improve the efficiency of this part, the Runtime uses the dyld shared cache to ensure selector uniqueness.

dyld is a system service used to locate and load dynamic libraries. It contains a shared cache that allows multiple processes to share these dynamic libraries. The dyld shared cache contains a selector table, enabling the runtime system to access selectors for shared libraries and custom classes through the cache.

For more about dyld, see this article: [dyld: Dynamic Linking On OS X](https://www.mikeash.com/pyblog/friday-qa-2012-11-09-dyld-dynamic-linking-on-os-x.html)

To be continued. Feedback and suggestions are very welcome.