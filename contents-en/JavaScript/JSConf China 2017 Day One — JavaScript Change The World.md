# JSConf China 2017 Day One — JavaScript Change The World

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-95173eecbedc3a16.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


I had the privilege of attending JSConf China 2017 today. As this was the first day of the conference, I’d like to share some personal impressions. For more detailed coverage of the talks, you can jump directly to the end of this article. Another frontend colleague and I wrote very detailed notes together; the copyright belongs to Juejin. If you’re interested, you can follow the link and take a look.


![](http://upload-images.jianshu.io/upload_images/1194012-cdb59b045ad66da8.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## Talk 1: Programming the Universal Future with next.js


![](http://upload-images.jianshu.io/upload_images/1194012-0168f7d29121b285.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-a8a8b0a1802cc6a1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


The first talk was by an expert from ZEIT, and it focused on next.js.


The live demo showed how React uses next.js for server-side rendering.

next.js supports one-click deployment for static projects, package.json (Node projects), and Dockerfile-based project configuration.

Common requirements in development—custom URLs, server-side rendering, and real-time logs—can all be handled with a single next command.

The speaker demonstrated the performance of server-side rendering after adopting next.js: the first screen opened instantly, with no more long loading states. The user experience was excellent. In addition, the talk also demonstrated lazy loading of React components. React components can be loaded on demand, so there is no longer a need to load all components upfront, which greatly improves performance. The demo also showed next.js’s hot-reload capability, which significantly improves development efficiency.


## Talk 2: Understanding Modern Web Development


![](http://upload-images.jianshu.io/upload_images/1194012-1723c635f861885a.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-0b653a0018884074.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This talk covered an enormous number of topics. The speaker also talked very quickly, moving through the keynote slide by slide. The scope was really broad; it’s said that without five to ten years of frontend experience, it’s hard to fully grasp the essence of it.


The speaker shared the slides for this talk, and they are well worth studying. The link is here: [“Understanding Modern Web Development”](https://speakerdeck.com/dexteryy/understanding-modern-web-development-at-jsconf-china-2017-zhong-wen)

The speaker also has a GitHub repo called [“Spellbook of Modern Web Dev”](https://github.com/dexteryy/spellbook-of-modern-webdev), which is also highly recommended reading.


### 1. How to Think About Changes in Development

The future trajectory of software development (mobile-first ----> the AI era ----> the eve of the XXX era) raises questions that are very much worth reflecting on.

### 2. JavaScript Fatigue

The root causes are:

1. Diversity  
The developer base is huge, growing 100% every year, and will surpass Java next year. At any given time, 50% of the community members only started writing JS this year.
2. High demand
3. Low cost  
JS is one of the languages with the highest level of abstraction, and the APIs it uses are also among the most highly abstracted APIs.

The solution to JavaScript Fatigue is: popularize low-cost maintenance and fill in the missing middle layer.

### 3. Awesome List

The speaker criticized repos like awesome list: the lists keep expanding, there is too much ineffective and outdated curation, and they lack hierarchy and structure. He then recommended spellbook. spellbook improves on the shortcomings of awesome list and also provides the most fine-grained categories.

### 4. The Future of CSS

The biggest trend in CSS is a shift from being document-oriented to being component-oriented.

### 5. The Web Open Source Ecosystem
  
1. Web open source ecosystem = npm ecosystem  
2. Five major schools of thought  
3. universal JS


## Talk 3: The JavaScript Language in the Post-ES6 Era


![](http://upload-images.jianshu.io/upload_images/1194012-8a16f95517d86c8f.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This session was presented by Hax from Baixing. The first half mainly discussed how the new ES6 features came to be fully supported by major browser vendors. There were many difficulties along the way. It also covered how each proposal gradually progressed from S0 to S4 and eventually landed.

The middle part mainly discussed new ES7 features. Here the speaker talked about the single-threaded nature of JS, and I paid close attention to this part, since client-side developers are usually exposed to the concept of multithreading.

Is JS single-threaded?

Worker is actually similar to a thread. Communication between Workers is done via message passing, through message events. In typical multithreaded programming, memory is shared.

RTC, run to completion, means that a JS function runs from start to finish and generally is not interrupted. JS is a language that uses run-to-completion semantics. Adding Async/Await breaks run-to-completion semantics, but it is still controlled: variables may change only at places marked with Async/Await, while unmarked places are still controlled by run-to-completion semantics. The same applies to SharedArrayBuffer.

node.js does not have worker, but the node.js team is already considering adding the relevant APIs.

Finally, Hax mentioned more new features: import() dynamic loading, spread operators for arrays and objects, some regular expression features, the global variable, Class feature extensions supporting private properties, the newly proposed Pattern Match from last week, WebAssembly, and so on. There are many more smaller details; see the images below:


![](http://upload-images.jianshu.io/upload_images/1194012-ee82cc21476ce79d.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-3f44e82ab0445028.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## Talk 4: Compile-Time Optimization in Frontend Engineering


![](http://upload-images.jianshu.io/upload_images/1194012-5bc42f94a8c1cfd9.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-27a89ac2eabf3c8e.JPG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This was Evan You’s talk! [Link to Evan You’s slides](https://docs.google.com/presentation/d/1ot0JYflhGmPq5Y_PAIEEyYH4APWBK17Zf7-d1dM4v7g/edit#slide=id.p)


![](http://upload-images.jianshu.io/upload_images/1194012-e806bd0f5143235b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Although frontend JavaScript is a scripting language and does not have build time in the traditional sense, modern frontend engineering still requires a compilation process. During compilation, analysis and optimization can be performed. V8’s implementation includes a related compilation pipeline that eventually compiles JavaScript source code into machine code.


![](http://upload-images.jianshu.io/upload_images/1194012-7d33677f33e7e73a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


We often use JS modules in day-to-day development, but after modularization, once code is bundled, it can become difficult to minify. Rollup was created to solve this problem.


![](http://upload-images.jianshu.io/upload_images/1194012-ca035c084825f981.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Versions after webpack 3.0 support the Treeshaking feature through the ModuleConcatenationPlugin plugin.

### Optimization Approaches for Frontend Compilation

As frontend engineering has evolved to where it is today, people have gradually begun thinking about what optimizations compilers can perform. The principle is:


![](http://upload-images.jianshu.io/upload_images/1194012-f45276d03dc753fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Do more at build time, Do less at runtime.

So at build time, people have come up with many optimization opportunities:


![](http://upload-images.jianshu.io/upload_images/1194012-9b577f4146fcc65e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Svelte is a framework that relies entirely on compilation. It can compile JS code without depending on any runtime lib.


![](http://upload-images.jianshu.io/upload_images/1194012-dda705e3c56c0909.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Relay Modern gets rid of expensive runtime query construction through static precompilation.


![](http://upload-images.jianshu.io/upload_images/1194012-619ca41b62be174d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Prepack’s idea is rather unusual: during compilation, it computes everything that can be computed, and then directly replaces the source code with the computed results. For example, if a function’s return value is fixed, Prepack will compute that return value during compilation, remove the function, and leave only the return value.


![](http://upload-images.jianshu.io/upload_images/1194012-217112a91ae4c102.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

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


![](http://upload-images.jianshu.io/upload_images/1194012-1f42b6626852a18a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-5cec91553c4b6e14.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-5b27eb8f8d7555ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## Talk 5: Everything You Need to Know to Learn React Native


![](http://upload-images.jianshu.io/upload_images/1194012-ef3ef23ec052c1d5.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


React Native is fairly familiar to many client-side developers.

The talk started by analyzing why RN has become so popular:

1. Hot updates
2. Developing mobile apps with modern web technologies
3. Cross-platform support

The corresponding downsides of RN:

1. Too many Breaking changes
2. The documentation is not easy to understand, resulting in a high learning cost
3. Navigation: issues with navigation components


The talk focused on the Navigation problem and provided the following possible options:


![](http://upload-images.jianshu.io/upload_images/1194012-b06f79884c746021.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Finally, it discussed State management. The speaker also mentioned that Redux is relatively heavyweight and recommended three other libraries: Mobx, Mobx State Tree, and Dva.

So RN state management can be handled in the following ways:


![](http://upload-images.jianshu.io/upload_images/1194012-3eec96a6fd5b3209.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


1. Built-in state
2. Redux
3. Mobx
4. Mobx State Tree
5. Dva


## Talk 6: TypeScript, Angular, and Cross-Platform Mobile Development


![](http://upload-images.jianshu.io/upload_images/1194012-caa18c05112ce356.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This session was delivered by an engineer from Google and focused on Angular.

At the beginning, he strongly recommended TypeScript.


![](http://upload-images.jianshu.io/upload_images/1194012-21f65fc2d43ff43a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Then he moved on to Angular.


![](http://upload-images.jianshu.io/upload_images/1194012-a00d6cc3d09b1285.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-13a02596e43c36c1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-b2a7cf0e4a97dce1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


I personally have never really used Angular, so I won’t go into much detail about it here.

After Angular, he talked about Ionic Framework.


![](http://upload-images.jianshu.io/upload_images/1194012-f6bfe0c9ba0af607.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-71674837b0c272ec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


Finally, he discussed Native Script. This is Angular’s cross-platform native framework, competing with Vue’s Weex and React’s React Native.

The three images below introduce Native Script and explain its cross-platform principles.


![](http://upload-images.jianshu.io/upload_images/1194012-0ada56ab65594d97.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-96c2474aca1dc617.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![](http://upload-images.jianshu.io/upload_images/1194012-e8f7a35f0fbb72e8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


At the moment, React Native is the most widely used. Weex does not have that many users either (if you are still using Weex, feel free to leave a comment below the article). Among the people around me, I can count the number of developers using Native Script on both hands (if you are developing with Native Script, feel free to leave a comment below the article).

Given that Native Script adoption is not very high, I won’t say much more about it here.

## Session 7: Ruff IoT Application Development


![](http://upload-images.jianshu.io/upload_images/1194012-21887867f8cd48d6.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-8d2473197ea7f6da.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-0a6332289d5442fa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![](http://upload-images.jianshu.io/upload_images/1194012-c9e3dd6f61c3fa66.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


This session covered how to develop hardware with JS. Software engineers can now use JavaScript, a high-level abstraction language, to develop IoT applications. Ruff encapsulates all the low-level hardware code.
Traditional hardware code looks roughly like this:
```

GPIO.output(11, GPIO.HIGH)

```
Most software engineers probably would not understand much of this code.

General Purpose Input Output, abbreviated as GPIO, or a bus expander, simplifies I/O port expansion through industry-standard I2C, SMBus, or SPI interfaces. When a microcontroller or chipset does not have enough I/O ports, or when a system needs remote [serial communication](http://baike.baidu.com/item/%E4%B8%B2%E8%A1%8C%E9%80%9A%E4%BF%A1) or control, GPIO products can provide additional control and monitoring capabilities.

Most people would not know what the first input parameter, 11, is for. In hardware, there are values such as 00, 01, 10, and 11.

HIGH is a high level. In hardware programming, there are high levels and low levels.

If these hardware-related code constructs that confuse software engineers can be encapsulated into higher-level code that is more readable to software engineers, it will be much more developer-friendly.

For example, if it is encapsulated as follows:
```

led.turnon()

```
Software engineers can tell at a glance what this is doing; it is extremely readable. This line is simply turning on an LED.


The Ruff platform does exactly this: it wraps complex hardware code into simple, easy-to-use JS APIs.

JavaScript engineers can use jQuery to build toys for their kids!


Finally, if you want to read more detailed notes, check out this [link](https://juejin.im/post/5969821851882534a31cab5b) on Juejin, which another friend and I recorded together.

## Reflections

The first day covered so many topics. You could really feel that today’s JavaScript can do more and more, which is why I titled this article JavaScript Change The World.

After listening to the whole event, the biggest takeaway was probably Evan You’s talk. Some of the other speakers’ sessions may not be things we use in day-to-day development, but it was still great to hear different perspectives from various teams on the evolution of frontend technology.


Although frontend has advanced rapidly in recent years, extending its “claws” forward into clients, backward into backends, and downward into hardware—seemingly becoming capable of anything—there is still a lot of room for improvement. For example, JS `Class` and multithreading can both learn from object-oriented languages. Frontend engineering can also gradually start considering compile-time optimizations. In this area, for client-side development languages, which are compiled languages by nature, the almost black-magic optimizations in Clang + LLVM may offer quite a lot for frontend to learn from.


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jsconf\_china\_2017/](https://halfrost.com/jsconf_china_2017/)