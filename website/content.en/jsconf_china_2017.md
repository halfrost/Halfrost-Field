+++
author = "一缕殇流化隐半边冰霜"
categories = ["JavaScript"]
date = 2017-07-15T06:21:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/52_0.png"
slug = "jsconf_china_2017"
tags = ["JavaScript"]
title = "JSConf China 2017 Day One — Change The World"

+++


I had the privilege of attending JSConf China 2017 today. Since this was the first day of the conference, I’d like to share some personal takeaways and appreciation for the event. For more detailed notes on the talks, you can jump directly to the end of this post. I wrote very detailed notes together with another frontend colleague; the copyright belongs to Juejin. If you’re interested, feel free to click the link and read them.

![](https://img.halfrost.com/Blog/ArticleImage/52_1_0.png)

## Talk 1: Programming the Universal Future with next.js

![](https://img.halfrost.com/Blog/ArticleImage/52_1_1.png)


![](https://img.halfrost.com/Blog/ArticleImage/52_1.png)


The first talk was given by an expert from ZEIT, and the topic was next.js.


The speaker demonstrated how React uses next.js for server-side rendering.

next.js supports one-click deployment for static projects, package.json (Node projects), and Dockerfile project configurations.

Common development requirements such as custom URLs, server-side rendering, and real-time logs can all be handled with a single next command!

The speaker also demonstrated the performance of server-side rendering after adopting next.js. The first screen loaded instantly, with no more long loading delays. The user experience was excellent. In addition, the talk demonstrated lazy loading of React components. React components can be loaded on demand, so there is no longer any need to load all components upfront, which significantly improves performance. The demo also showcased next.js’s hot-reload capability, which greatly improves development efficiency.


## Talk 2: Understanding Modern Web Development

![](https://img.halfrost.com/Blog/ArticleImage/52_2_0.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_2.png)


This talk covered a huge number of topics. The speaker also spoke very quickly, going through the keynote slide by slide. The scope was extremely broad; it is said that without five to ten years of frontend experience, it is hard to fully grasp the essence of it.


The speaker shared the PPT for this talk, and it is well worth studying. Here is the link: [Understanding Modern Web Development](https://speakerdeck.com/dexteryy/understanding-modern-web-development-at-jsconf-china-2017-zhong-wen)

The speaker also has a GitHub project called [Spellbook of Modern Web Dev](https://github.com/dexteryy/spellbook-of-modern-webdev), which is also highly recommended.
     

### 1. How to Think About Changes in Development

Future forms of development (mobile-first ----> AI era ----> the eve of the XXX era) are all questions worth thinking deeply about.

### 2. JavaScript Fatigue

The root causes are:

1. Diversity  
The developer base is huge, growing by 100% every year, and will surpass Java next year. At any given time, 50% of community members only started writing JS this year.
2. Many requirements
3. Low cost  
JS is one of the languages with the highest level of abstraction, and the APIs it uses are also APIs at a very high level of abstraction.

The solution to JavaScript Fatigue is to popularize low-cost maintenance and fill in the missing middle layers.

### 3. Awesome List

The talk criticized repos like awesome lists: the lists keep expanding, there is too much invalid and outdated curation, and they lack structure. The speaker then recommended spellbook, which improves on the shortcomings of awesome lists and provides very fine-grained categories.

### 4. The Future of CSS

The biggest trend in CSS is the shift from being document-oriented to being component-oriented.

### 5. The Web Open-Source Ecosystem
  
1. Web open-source ecosystem = npm ecosystem  
2. Five major schools  
3. universal JS


## Talk 3: JavaScript in the Post-ES6 Era


![](https://img.halfrost.com/Blog/ArticleImage/52_3_0.png)

This talk was given by Hax from Baixing. The first half mainly discussed how the new features of ES6 came to be well supported by major browser vendors. There were quite a few difficulties along the way. It also covered how various proposals gradually moved from S0 to S4 and eventually landed.

The middle part mainly covered new ES7 features. It discussed the single-threaded nature of JS, and I paid close attention to this part, since client-side developers are usually familiar with the concept of multithreading.

Is JS single-threaded?

Worker is actually similar to a thread. Worker communication is message passing, delivered via message events. In typical multithreaded programming, memory is shared.

RTC, run to completion, means a JS function runs from beginning to end and generally will not be interrupted. JS is a language that uses run-to-completion semantics. The addition of Async/Await breaks run-to-completion semantics, but it is still controllable: variables may only change at points marked with Async/Await, while other unmarked places are still governed by run-to-completion. SharedArrayBuffer is similar.

node.js does not have worker, but the node.js development team is already considering adding related APIs.

Finally, Hax mentioned more new features: dynamic loading with import(), spread operators for arrays and objects, some regular expression features, the global variable, Class feature extensions supporting private properties, the newly proposed Pattern Match from last week, WebAssembly, and more. There are also many smaller points; see the images below:

![](https://img.halfrost.com/Blog/ArticleImage/52_3.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_4.png)


## Talk 4: Compile-Time Optimization in Frontend Engineering

![](https://img.halfrost.com/Blog/ArticleImage/52_5_0.png)


![](https://img.halfrost.com/Blog/ArticleImage/52_5.png)


This was Evan You’s talk! [Evan You’s slide deck](https://docs.google.com/presentation/d/1ot0JYflhGmPq5Y_PAIEEyYH4APWBK17Zf7-d1dM4v7g/edit#slide=id.p)


![](https://img.halfrost.com/Blog/ArticleImage/52_6.png)

Although frontend JavaScript is a scripting language and traditionally has no build time, modern frontend engineering still requires a compilation process. During compilation, analysis and optimization can be performed. V8’s implementation includes a related compilation pipeline that ultimately compiles JavaScript source code into machine code.

![](https://img.halfrost.com/Blog/ArticleImage/52_7.png)


We often use JS modules in daily development, but after modularization, bundled code becomes harder to compress. Rollup was created to solve this problem.


![](https://img.halfrost.com/Blog/ArticleImage/52_8.png)


Versions after webpack 3.0 support Tree Shaking through the ModuleConcatenationPlugin plugin.

### Optimization Strategies for Frontend Compilation

As frontend engineering has evolved to where it is today, people have gradually started thinking about what optimizations compilers can perform. The principle is:

![](https://img.halfrost.com/Blog/ArticleImage/52_9.png)


Do more at build time, Do less at runtime.

So at build time, people have come up with many optimization opportunities:

![](https://img.halfrost.com/Blog/ArticleImage/52_10.png)


Svelte is a framework that relies entirely on compilation. It can compile JS code without depending on any runtime lib.

![](https://img.halfrost.com/Blog/ArticleImage/52_11.png)


Relay Modern uses static precompilation to avoid expensive runtime query construction.

![](https://img.halfrost.com/Blog/ArticleImage/52_12.png)


Prepack takes a rather unconventional approach: during compilation, it computes everything that can be computed, then directly replaces the source code with the computed results. For example, if a function’s return value is fixed, Prepack will compute that return value at compile time, delete the function, and leave only the return value.

![](https://img.halfrost.com/Blog/ArticleImage/52_13.png)


Rakt performs compile-time optimization at the application layer.

Finally, the talk covered eight compiler optimizations in Vue:

1. Hoisting Static Trees
2. Skipping Static Bindings
3. Skipping Children Array Normalization
4. SSR Optimizing Virtual DOM render functions into string concat
5. SSR inferring async chunks
6. SSR inlining Critical CSS
7. IDEA compile away parts of vue that's not used in your app
8. IDEA styletron-style atomic CSS generation at build time

I mainly focused on the three SSR optimizations:

![](https://img.halfrost.com/Blog/ArticleImage/52_14.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_15.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_16.png)


## Talk 5: Everything You Need to Know to Learn React Native

![](https://img.halfrost.com/Blog/ArticleImage/52_17_0.jpg)

React Native is fairly familiar to many client-side developers.

The talk started by analyzing why RN has become so popular:

1. Hot updates
2. Using modern web technologies to develop mobile apps
3. Cross-platform

The corresponding drawbacks of RN:

1. Too many breaking changes
2. Documentation is hard to understand, leading to a high learning curve
3. Navigation: issues with navigation components


The talk focused on Navigation issues and gave the following optional solutions:

![](https://img.halfrost.com/Blog/ArticleImage/52_17_1.png)


Finally, it discussed State management. The speaker also mentioned that Redux is relatively heavyweight and recommended three other libraries: Mobx, Mobx State Tree, and Dva.

So for state management in RN, the following approaches can be used:

![](https://img.halfrost.com/Blog/ArticleImage/52_17_2.png)
1. Built-in state
2. Redux
3. Mobx
4. Mobx State Tree
5. Dva


## Session 6: TypeScript, Angular, and Cross-Platform Mobile Development

![](https://img.halfrost.com/Blog/ArticleImage/52_18_0.png)

This session was an engineer from Google talking about Angular.

At the beginning, he gave TypeScript a strong recommendation.


![](https://img.halfrost.com/Blog/ArticleImage/52_18_1.png)


Then he moved on to Angular.

![](https://img.halfrost.com/Blog/ArticleImage/52_18_2.png)


![](https://img.halfrost.com/Blog/ArticleImage/52_18_3.png)


![](https://img.halfrost.com/Blog/ArticleImage/52_18_4.png)

I have honestly never used Angular, so I won’t cover it here.

After Angular, he talked about the Ionic Framework.


![](https://img.halfrost.com/Blog/ArticleImage/52_18_5.png)


![](https://img.halfrost.com/Blog/ArticleImage/52_18_6.png)

Finally, he talked about Native Script. This is Angular’s cross-platform native framework; its counterparts are Weex for Vue and React Native for React.

The following three diagrams introduce Native Script and explain how its cross-platform mechanism works.

![](https://img.halfrost.com/Blog/ArticleImage/52_18_7.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_18_8.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_18_9.png)


At the moment, React Native is the most widely used. There are not that many people using Weex (if you are still using Weex, feel free to leave a comment below the article). Around me, the number of people developing with Native Script can be counted on both hands (if you are developing with Native Script, feel free to leave a comment below the article).

Given that Native Script is not very widely used, I won’t say much more about it here. 


## Session 7: Ruff Application Development


![](https://img.halfrost.com/Blog/ArticleImage/52_19_0.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_19_1.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_19_2.png)

![](https://img.halfrost.com/Blog/ArticleImage/52_19_3.png)


This session was about how to use JS to develop hardware. Software engineers can now use a high-level abstraction language like JavaScript to develop IoT applications as well. Ruff encapsulates the underlying hardware code.
Traditional hardware code looks roughly like this:
```vim

GPIO.output(11, GPIO.HIGH)

```
Most software engineers probably wouldn’t find this code very easy to understand.

General Purpose Input/Output, abbreviated as GPIO, or a bus expander, uses industry-standard I2C, SMBus, or SPI interfaces to simplify I/O port expansion. When a microcontroller or chipset does not have enough I/O ports, or when a system needs remote [serial communication](http://baike.baidu.com/item/%E4%B8%B2%E8%A1%8C%E9%80%9A%E4%BF%A1) or control, GPIO products can provide additional control and monitoring capabilities.

Most people also wouldn’t know what the first input parameter, 11, is for. In hardware, there are values such as 00, 01, 10, and 11.

HIGH means a high level. In hardware programming, there are high levels and low levels.

If these hardware-oriented code segments that software engineers find hard to understand can be encapsulated into higher-level code with better readability, it would be much more friendly to software engineers.

If it were encapsulated like this:
```javascript

led.turnon()

```
Software engineers can tell at a glance what this is doing; it is highly readable. This line is simply turning on an LED light.


The Ruff platform does exactly this: it encapsulates complex hardware code into simple, easy-to-use JS APIs.

JavaScript engineers can use jQuery to build toys for their kids!


Finally, if you want to read more detailed notes, check out this [link](https://juejin.im/post/5969821851882534a31cab5b) on Juejin, which was recorded by me and another friend.

## Thoughts


The first day covered so many topics. You can really feel that today’s JavaScript language can do more and more, which is why I titled the article JavaScript Change The World.


After listening to the entire event, the biggest takeaway was probably Evan You’s talk. Some of the other speakers’ sessions at this conference may not be something we use in day-to-day development, but it was still quite interesting to hear different perspectives from various teams on the evolution of frontend technology.


Although frontend has advanced rapidly in recent years, extending its “claws” forward into clients, backward into backend systems, and downward into hardware—seemingly capable of anything—there is still plenty of room for improvement. For example, JS classes and multithreading are areas where JavaScript can learn from object-oriented languages. Frontend engineering can also gradually start considering compile-time optimization. For client-side development languages, which are inherently compiled languages, the almost “black magic” optimizations in Clang + LLVM may offer many lessons worth learning for frontend development.


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jsconf\_china\_2017/](https://halfrost.com/jsconf_china_2017/)