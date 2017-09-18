
![](http://upload-images.jianshu.io/upload_images/1194012-be7c923b3346f7f2.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





## 序

今年大前端的概念一而再再而三的被提及，那么大前端时代究竟是什么呢？大前端这个词最早是因为在阿里内部有很多前端开发人员既写前端又写 Java 的 Velocity 模板而得来，不过现在大前端的范围已经越来越大了，包含前端 + 移动端，前端、CDN、Nginx、Node、Hybrid、Weex、React Native、Native App。笔者是一名普通的全职 iOS 开发者，在接触到了前端开发以后，发现了前端有些值得移动端学习的地方，于是便有了这个大前端时代系列的文章，希望两者能相互借鉴优秀的思想。谈及到大前端，常常被提及的话题有：组件化，路由与解耦，工程化（打包工具，脚手架，包管理工具），MVC 和 MVVM 架构，埋点和性能监控。笔者就先从组件化方面谈起。网上关于前端框架对比的文章也非常多（对比 React，Vue，Angular），不过跨端对比的文章好像不多？笔者就打算以前端和移动端（以 iOS 平台为主）对比为主，看看这两端的不同做法，并讨论讨论有无相互借鉴学习的地方。

本文前端的部分也许前端大神看了会觉得比较基础，如有错误还请各位大神不吝赐教。

-------------------------------------------------------------------------------------

## Vue 篇


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-684fa2f2f2cb0685.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>







### 一. 组件化的需求

为了提高代码复用性，减少重复性的开发，我们就把相关的代码按照  template、style、script 拆分，封装成一个个的组件。组件可以扩展
 HTML 元素，封装可重用的 HTML 代码，我们可以将组件看作自定义的 HTML 元素。在 Vue 里面，每个封装好的组件可以看成一个个的 ViewModel。

### 二. 如何封装组件

谈到如何封装的问题，就要先说说怎么去组织组件的问题。

如果在简单的 SPA 项目中，可以直接用 Vue.component 去定义一个全局组件，项目一旦复杂以后，就会出现弊端了：

1. 全局定义(Global definitions) 强制要求每个 component 中的命名不得重复
2. 字符串模板(String templates) 缺乏语法高亮，在 HTML 有多行的时候，需要用到丑陋的 \
3. 不支持 CSS(No CSS support) 意味着当 HTML 和 JavaScript 组件化时，CSS 明显被遗漏
4. 没有构建步骤(No build step) 限制只能使用 HTML 和 ES5 JavaScript, 而不能使用预处理器，如 Pug (formerly Jade) 和 Babel


而且现在公司级的项目，大多数都会引入工程化的管理，用包管理工具去管理，npm 或者 yarn。所以 Vue 在复杂的项目中用 Vue.component 去定义一个组件的方式就不适合了。这里就需要用到单文件组件，还可以使用 Webpack 或 Browserify 等构建工具。比如下面这个Hello.vue组件，整个文件就是一个组件。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-df970b173f9ce00f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



在单文件组件中，整个文件都是一个 [CommonJS 模块](https://webpack.js.org/concepts/modules/#what-is-a-webpack-module)，里面包含了组件对应的 HTML、组件内的处理逻辑 Javascript、组件的样式 CSS。

在组件的 script 标签中，需要封装该组件 ViewModel 的行为。

- data
  组件的初始化数据，以及私有属性。
- props
  组件的属性，这里的属性专门用来接收父子组件通信的数据。（这里可以类比 iOS 里面的 @property ）
- methods
  组件内的处理逻辑函数。
- watch
  需要额外监听的属性（这里可以类比 iOS 里面的 KVO ）
- computed
  组件的计算属性

- components
  所用到的子组件

- lifecycle hooks
  生命周期的钩子函数。一个组件也是有生命周期的，有如下这些：[beforeCreate](https://cn.vuejs.org/v2/api/#beforeCreate)、[created](https://cn.vuejs.org/v2/api/#created)、[beforeMount](https://cn.vuejs.org/v2/api/#beforeMount)、[mounted](https://cn.vuejs.org/v2/api/#mounted)、[beforeUpdate](https://cn.vuejs.org/v2/api/#beforeUpdate)、[updated](https://cn.vuejs.org/v2/api/#updated)、[activated](https://cn.vuejs.org/v2/api/#activated)、[deactivated](https://cn.vuejs.org/v2/api/#deactivated)、[beforeDestroy](https://cn.vuejs.org/v2/api/#beforeDestroy)、[destroyed](https://cn.vuejs.org/v2/api/#destroyed)等生命周期。在这些钩子函数里面可以加上我们预设的处理逻辑。（这里可以类比 iOS 里面的 ViewController 的生命周期 ）


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-2bd002c5882c5f59.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






如此看来，在 Vue 里面封装一个单文件组件，和在 iOS 里面封装一个 ViewModel 的思路是完全一致的。接下来的讨论无特殊说明，针对的都是单文件组件。

### 三. 如何划分组件

一般划分组件分可以按照以下标准去划分：

1. 页面区域：
    header、footer、sidebar……
2. 功能模块：
    select、pagenation……

这里举个例子来说明一起前端是如何划分组件的。

#### 1. 页面区域

还是以 [objc中国](https://objccn.io/) 的首页页面为例



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-bbd112eb3c69962b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






我们可以把上面的页面按照布局，先抽象图片中间的样子，然后接着按照页面的区域划分组件，最后可以得到最右边的组件树。


在 Vue 实例的根组件，加载 layout。

```javascript

import Vue from 'vue';
import store from './store';
import router from './router';
import Layout from './components/layout';

new Vue({
  el: '#app',
  router,
  store,
  template: '<Layout/>',
  components: {
    Layout
  }
});


```

根据抽象出来的组件树，可以进一步的向下细分各个小组件。



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-1dabac090cd4534c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>




layout 下一层的组件是 header、footer、content，这三部分就组成了 layout.vue 单文件组件的全部部分。




<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-db1dd792c3a99995.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






上图就是我们的 layout.vue 的全部实现。在这个单文件组件中里面引用了三个子组件，navigationBar、footerView、content。由于 content 里面是由各个路由页面组成，所以这里声明成 router-view。

至于各个子组件的具体实现这里就不在赘述了，具体代码可以看这里[navigationBar.vue](https://github.com/halfrost/vue-objccn/blob/master/src/components/navigationBar.vue)、[footerView](https://github.com/halfrost/vue-objccn/blob/master/src/components/footerView.vue)、[layout.vue](https://github.com/halfrost/vue-objccn/blob/master/src/components/layout.vue)


#### 2. 功能模块

一般项目里面详情页的内容最多，我们就以 [objc中国](https://objccn.io/products/functional-swift/) 的详情页面为例




<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-2da8a958d72370f1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>





上图左边是详情页，右图是按照功能区分的图，我们把整个页面划分为6个子组件。



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-a7320dfd2232e67b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






从上往下依次展开，见上图。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-776b12675182b3d8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



经过功能上的划分以后，整个详情页面的代码变的异常清爽，整个页面就是6个单文件的子组件，每个子组件的逻辑封装在各自的组件里面，详情页面就是把他们都组装在了一起，代码可读性高，后期维护也非常方便。

详情页面具体的代码在这里[https://github.com/halfrost/vue-objccn/blob/master/src/pages/productsDetailInfo.vue](https://github.com/halfrost/vue-objccn/blob/master/src/pages/productsDetailInfo.vue)

6个子组件的代码在这里[https://github.com/halfrost/vue-objccn/tree/master/src/components/productsDetailInfo](https://github.com/halfrost/vue-objccn/tree/master/src/components/productsDetailInfo)，具体的代码见链接，这里就不在赘述了。


综上可以看出，前端 SPA 页面抽象出来就是一个大的组件树。

### 四. 组件化原理

举个例子：

```javascript


<!DOCTYPE html>
<html>
    <body>
        <div id="app">
            <parent-component>
            </parent-component>
        </div>
    </body>
    <script src="js/vue.js"></script>
    <script>
        
        var Child = Vue.extend({
            template: '<p>This is a child component !</p>'
        })
        
        var Parent = Vue.extend({
            // 在Parent组件内使用<child-component>标签
            template :'<p>This is a Parent component !</p><child-component></child-component>',
            components: {
                // 局部注册Child组件，该组件只能在Parent组件内使用
                'child-component': Child
            }
        })
        
        // 全局注册Parent组件
        Vue.component('parent-component', Parent)
        
        new Vue({
            el: '#app'
        })
        
    </script>
</html>

```

在上面的例子中，在 `<parent-component>` 父组件里面声明了一个 `<child-component>`，最终渲染出来的结果是：

```javascript

This is a Parent component !
This is a child component !

```



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-6952239b3ee1ef64.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>





上述代码的执行顺序如下：

1. 子组件先在父组件中的 components 中进行注册。
2. 父组件利用 Vue.component 注册到全局。
3. 当渲染父组件的时候，渲染到 `<child-component>` ，会把子组件也渲染出来。

值得说明的一点是，Vue 进行模板解析的时候会遵循以下 html 常见的限制：

- a 不能包含其它的交互元素（如按钮，链接）
- ul 和 ol 只能直接包含 li
- select 只能包含 option 和 optgroup
- table 只能直接包含 thead, tbody, tfoot, tr, caption, col, colgroup
- tr 只能直接包含 th 和 td


### 五. 组件分类

组件的种类可分为以下4种：

1. 普通组件
2. 动态组件
3. 异步组件
4. 递归组件

#### 1. 普通组件

之前讲的都是普通的组件，这里就不在赘述了。

#### 2. 动态组件

动态组件利用的是 `is` 的特性，可以设置多个组件可以使用同一个挂载点，并动态切换。

```javascript

var vm = new Vue({
  el: '#example',
  data: {
    currentView: 'home'
  },
  components: {
    home: { /* ... */ },
    posts: { /* ... */ },
    archive: { /* ... */ }
  }
})


<component v-bind:is="currentView">
  <!-- 组件在 vm.currentview 变化时改变！ -->
</component>

```

现在 `<component>` 组件的具体类型用 currentView 来表示了，我们就可以通过更改 currentView 的值，来动态加载各个组件。上述例子中，可以不断的更改 data 里面的 currentView ，来达到动态加载 home、posts、archive 三个不同组件的目的。


#### 3. 异步组件

Vue允许将组件定义为一个工厂函数，在组件需要渲染时触发工厂函数动态地解析组件，并且将结果缓存起来：

```javascript

Vue.component("async-component", function(resolve, reject){
    // async operation
    setTimeout(function() {
        resolve({
            template: '<div>something async</div>'
        });
    },1000);
});

```

动态组件可配合 webpack 实现代码分割，webpack 可以将代码分割成块，在需要此块时再使用 ajax 的方式下载：

```javascript

Vue.component('async-webpack-example', function(resolve) {
  // 这个特殊的 require 语法告诉 webpack
  // 自动将编译后的代码分割成不同的块，
  // 这些块将通过 ajax 请求自动下载。
  require(['./my-async-component'], resolve)
});

```


#### 4. 递归组件

如果一个组件设置了 name 属性，那么它就可以变成递归组件了。

递归组件可以利用模板里面的 name 不断的递归调用自己。


```javascript

name: 'recursion-component',
template: '<div><recursion-component></recursion-component></div>'

```

上面这段代码是一个错误代码，这样写模板的话就会导致递归死循环，最终报错 “max stack size exceeded”。解决办法需要打破死循环，比如 v-if 返回 false。

### 六. 组件间的消息传递和状态管理

在 Vue 中，组件消息传递的方式主要分为3种：

1. 父子组件之间的消息传递
2. Event Bus
3. Vuex 单向数据流

#### 1. 父子组件之间的消息传递


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-80767515e312dbfe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>





父子组件的传递方式比较单一，在 Vue 2.0 以后，父子组件的关系可以总结为 ** props down, events up **。父组件通过 props 向下传递数据给子组件，子组件通过 events 给父组件发送消息。

#### 父向子传递

举个例子：

```javascript

Vue.component('child', {
  // 声明 props
  props: ['msg'],
  // prop 可以用在模板内
  // 可以用 `this.msg` 设置
  template: '<span>{{ msg }}</span>'
})

<child msg="hello!"></child>

```

在 child 组件的 props 中声明了一个 msg 属性，在父组件中利用这个属性把值传给子组件。

这里有一点需要注意的是，在非字符串模板中， camelCased (驼峰式) 命名的 prop 需要转换为相对应的 kebab-case (短横线隔开式) 命名。

上面这个例子是静态的绑定，Vue 也支持动态绑定，这里也支持 v-bind 指令进行动态的绑定 props 。

父向子传递是一个单向数据流的过程，prop 是单向绑定的：当父组件的属性变化时，将传导给子组件，但是不会反过来。这是为了防止子组件无意修改了父组件的状态——这会让应用的数据流难以理解。

另外，每次父组件更新时，子组件的所有 prop 都会更新为最新值。这意味着你不应该在子组件内部改变 prop。Vue 建议子组件的 props 是 immutable 的。

这里就会牵涉到2类问题：

1. 由于单向数据流的原因，会导致子组件的数据或者状态和父组件的不一致，为了同步，在子组件里面反数据流的去修改父组件的数据或者数据。

2. 子组件接收到了 props 的值以后，有2种原因想要改变它，第一种原因是，prop 作为初始值传入后，子组件想把它当作局部数据来用；第二种原因是，prop 作为初始值传入，由子组件处理成其它数据输出。


这两类问题，开发者强行更改，也都是可以实现的，但是会导致不令人满意的 “后果” 。第一个问题强行手动修改父组件的数据或者状态以后，导致数据流混乱不堪。只看父组件，很难理解父组件的状态。因为它可能被任意子组件修改！理想情况下，只有组件自己能修改它的状态。第二个问题强行手动修改子组件的 props 以后，Vue 会在控制台给出警告。

如果优雅的解决这2种问题呢？一个个的来说：

#### （1）第一个问题，换成双向绑定就可以解决。

在 Vue 2.3.0+ 以后的版本，双向绑定有2种方式

第一种方式：  

利用 `.sync` 修饰符，在 Vue 2.3.0+ 以后作为一个编译时的语法糖存在。它会被扩展为一个自动更新父组件属性的 v-on 侦听器。

```javascript

// 声明一个双向绑定
<comp :foo.sync="bar"></comp>


// 上面一行代码会被会被扩展为下面这一行：
<comp :foo="bar" @update:foo="val => bar = val"></comp>

// 当子组件需要更新 foo 的值时，它会显式地触发一个更新事件：
this.$emit('update:foo', newValue)

```

第二种方式：

自定义事件可以用来创建自定义的表单输入组件，使用 v-model 来进行数据双向绑定。

```javascript

<input :value="value" @input="updateValue($event.target.value)" >

```

在这种方式下进行的双向绑定必须满足2个条件：

- 接受一个 value 属性
- 在有新的值时触发 input 事件


官方推荐的2种双向绑定的方式就是上述2种方法。不过还有一些隐性的双向绑定，可能无意间就会造成bug的产生。

pros 是单向数据传递，父组件把数据传递给子组件，需要尤其注意的是，传递的数据如果是引用类型（比如数组和对象），那么默认就是双向数据绑定，子组件的更改都会影响到父组件里面。在这种情况下，如果人为不知情，就会出现一些莫名其妙的bug，所以需要注意引用类型的数据传递。



#### （2）第二个问题，有两种做法：

- 第一种做法是：定义一个局部变量，并用 prop 的值初始化它：

```javascript

props: ['initialCounter'],
data: function () {
  return { counter: this.initialCounter }
}

```

- 第二种做法是：定义一个计算属性，处理 prop 的值并返回。

```javascript

props: ['size'],
computed: {
  normalizedSize: function () {
    return this.size.trim().toLowerCase()
  }
}

```

父向子传递还可以传递模板，使用 slot 分发内容。

slot 是 Vue 的一个内置的自定义元素指令。slot 在 bind 回调函数中，根据 name 获取将要替换插槽的元素，如果上下文环境中有所需替换的内容，则调用父元素的 replaceChild 方法，用替换元素讲 slot 元素替换；否则直接删除将要替换的元素。如果替换插槽元素中有一个顶级元素，且顶级元素的第一子节点为 DOM 元素，且该节点有 v-if 指令，且 slot 元素中有内容，则替换模板将增加 v-else 模板放入插槽中的内容。如果 v-if 指令为 false，则渲染 else 模板内容。


#### 子向父传递

子组件要把数据传递回父组件，方式很单一，那利用自定义事件！

父组件使用 $on(eventName) 监听事件
子组件使用 $emit(eventName) 触发事件

举个简单的例子：

```javascript

// 在子组件里面有一个 button
<button @click="emitMyEvent">emit</button>

emitMyEvent() {
  this.$emit('my-event', this.hello);
}


// 在父组件里面监听子组件的自定义事件
<child @my-event="getMyEvent"></child>

getMyEvent() {
    console.log(' i got child event ');
}


```

这里也可以通过父子之间的关系进行传递数据（直接修改数据），但是不推荐这种方法，例如 this.$parent 或者 this.$children 直接调用父或者子组件的方法，这里类比iOS里面的ViewControllers方法，在这个数组里面可以直接拿到所有 VC ，然后就可以调用他们暴露在.h里面的方法了。但是这种方式相互直接耦合性太大了。


#### 2. Event Bus 

Event Bus 这个概念对移动端的同学来说也比较熟悉，因为在安卓开发中就有这个概念。在 iOS 开发中，可以类比消息总线。具体实现可以是通知 Notification 或者 ReactiveCocoa 中的信号传递。

Event Bus 的实现还是借助 Vue 的实例。新建一个新的 Vue，专门用来做消息总线。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-a66753d084e38d03.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>









```javascript

var eventBus = new Vue()

// 在 A 组件中引入 eventBus
eventBus.$emit('myEvent', 1)

// 在要监听的组件中监听
eventBus.$on('id-selected', () => {
  // ...
})

```


#### 3. Vuex 单向数据流

由于本篇文章重点讨论组件化的问题，所以这里 Vuex 只是说明用法，至于原理的东西之后会单独开一篇文章来分析。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-8e6a23db3eeae215.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






这一张图就描述了 Vuex 是什么。Vuex 专为 Vue.js 应用程序开发的状态管理模式。它采用集中式存储管理应用的所有组件的状态，并以相应的规则保证状态以一种可预测的方式发生变化。

上图中箭头的指向就描述了数据的流向。数据的流向是单向的，从 Actions 流向 State，State 中的数据改变了从而影响到 View 展示数据的变化。



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-3beeb181eee83538.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>





从简单的 Actions、State、View 三个角色，到现在增加了一个 Mutations。Mutations 现在变成了更改 Vuex 的 store 中的状态的唯一方法是提交 mutation。Vuex 中的 mutations 非常类似于事件：每个 mutation 都有一个字符串的 事件类型 (type) 和 一个 回调函数 (handler)。

一般在组件中进行 commit 调用 Mutation 方法

```javascript

this.$store.commit('increment', payload);

```

Actions 和 Mutations 的区别在于：

- Action 提交的是 mutation，而不是直接变更状态。
- Action 可以包含任意异步操作，而 Mutations 必须是同步函数。

一般在组件中进行 dispatch 调用 Actions 方法

```javascript

this.$store.dispatch('increment');

```


Vuex 官方针对 Vuex 的最佳实践，给出了一个项目模板结构，希望大家都能按照这种模式去组织我们的项目。

```javascript


├── index.html
├── main.js
├── api
│   └── ... # 抽取出API请求
├── components
│   ├── App.vue
│   └── ...
└── store
    ├── index.js          # 我们组装模块并导出 store 的地方
    ├── actions.js        # 根级别的 action
    ├── mutations.js      # 根级别的 mutation
    └── modules
        ├── cart.js       # 购物车模块
        └── products.js   # 产品模块

```

关于这个例子的详细代码在[这里](https://github.com/vuejs/vuex/tree/dev/examples/shopping-cart)

### 七. 组件注册方式

组件的注册方式主要就分为2种：全局注册和局部注册

#### 1. 全局注册

利用 Vue.component 指令进行全局注册

```javascript

Vue.component('my-component', {
  // 选项
})

```

注册完的组件就可以在父实例中以自定义元素 `<my-component></my-component>` 的形式使用。

```javascript

// 注册
Vue.component('my-component', {
  template: '<div>A custom component!</div>'
})
// 创建根实例
new Vue({
  el: '#example'
})

<div id="example">
  <my-component></my-component>
</div>

```


#### 2. 局部注册

全局注册组件会拖慢一些页面的加载速度，有些组件只需要用的到时候再加载，所以不必在全局注册每个组件。于是就有了局部注册的方式。

```javascript


var Child = {
  template: '<div>A custom component!</div>'
}
new Vue({
  // ...
  components: {
    // <my-component> 将只在父模板可用
    'my-component': Child
  }
})

```



-------------------------------------------------------------------------------------

## iOS 篇


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-b2abeb076a3d4a0a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






### 一. 组件化的需求

在 iOS Native app 前期开发的时候，如果参与的开发人员也不多，那么代码大多数都是写在一个工程里面的，这个时候业务发展也不是太快，所以很多时候也能保证开发效率。

但是一旦项目工程庞大以后，开发人员也会逐渐多起来，业务发展突飞猛进，这个时候单一的工程开发模式就会暴露出弊端了。

- 项目内代码文件耦合比较严重
- 容易出现冲突，大公司同时开发一个项目的人多，每次 pull 一下最新代码就会有很多冲突，有时候合并代码需要半个小时左右，这会耽误开发效率。
- 业务方的开发效率不够高，开发人员一多，每个人都只想关心自己的组件，但是却要编译整个项目，与其他不相干的代码糅合在一起。调试起来也不方便，即使开发一个很小的功能，都要去把整个项目都编译一遍，调试效率低。

为了解决这些问题，iOS 项目就出现了组件化的概念。所以 iOS 的组件化是为了解决上述这些问题的，这里与前端组件化解决的痛点不同。

iOS 组件化以后能带来如下的好处：

* 加快编译速度（不用编译主客那一大坨代码了，各个组件都是静态库）
* 自由选择开发姿势（MVC / MVVM / FRP）
* 方便 QA 有针对性地测试
* 提高业务开发效率

iOS 组件化的封装性只是其中的一小部分，更加关心的是如何拆分组件，如何解除耦合。前端的组件化可能会更加注重组件的封装性，高可复用性。

### 二. 如何封装组件

iOS 的组件化手段非常单一，就是利用 Cocoapods 封装成 pod 库，主工程分别引用这些 pod 即可。越来越多的第三方库也都在 Cocoapods 上发布自己的最新版本，大公司也在公司内部维护了公司私有的 Cocoapods 仓库。一个封装完美的 Pod 组件，主工程使用起来非常方便。

具体如果用 Cocoapods 打包一个静态库 .a 或者 framework ，网上教程很多，这里给一个[链接](http://www.cnblogs.com/brycezhang/p/4117180.html)，详细的操作方法就不再赘述了。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-40000a4f3a3db8ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






最终想要达到的理想目标就是主工程就是一个壳工程，其他所有代码都在组件 Pods 里面，主工程的工作就是初始化，加载这些组件的，没有其他任何代码了。




### 三. 如何划分组件

iOS 划分组件虽然没有一个很明确的标准，因为每个项目都不同，划分组件的粗粒度也不同，但是依旧有一个划分的原则。

App之间可以重用的 Util、Category、网络层和本地存储 storage 等等这些东西抽成了 Pod 库。还有些一些和业务相关的，也是在各个App之间重用的。

原则就是：要在App之间共享的代码就应该抽成 Pod 库，把它们作为一个个组件。不在 App 间共享的业务线，也应该抽成 Pod，解除它与工程其他的文件耦合性。

常见的划分方法都是从底层开始动手，网络库，路由，MVVM框架，数据库存储，加密解密，工具类，地图，基础SDK，APM，风控，埋点……从下往上，到了上层就是各个业务方的组件了，最常见的就类似于购物车，我的钱包，登录，注册等。

### 四. 组件化原理

iOS 的组件化是借助 Cocoapods 完成的。关于 Cocoapods 的具体工作原理，可以看这篇文章[《CocoaPods 都做了什么？》](http://draveness.me/cocoapods.html)。

这里简单的分析一下 pod 进来的库是什么加载到主工程的。

pod 会依据 Podfile 文件里面的依赖库，把这些库的源代码下载下来，并创建好 Pods workspace。当程序编译的时候，会预先执行2个 pod 设置进来的脚本。

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-be89228b5c8e836c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>



在上面这个脚本中，会把 Pods 里面的打包好的静态库合并到 libPods-XXX.a 这个静态库里面，这个库是主工程依赖的库。



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-879307a922464b83.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>





上图就是给主项目加载 Pods 库的脚本。


Pods 另外一个脚本是加载资源的。见下图。



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-7d14f08e853739eb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>




这里加载的资源是 Pods 库里面的一些图片资源，或者是 Boudle 里面的 xib ，storyboard，音乐资源等等。这些资源也会一起打到 libPods-XXX.a 这个静态库里面。



<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-4d685a3753c16303.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>




上图就是加载资源的脚本。


### 五. 组件分类

iOS 的组件主要分为2种形式：

1. 静态库
2. 动态库

静态库一般是以 .a 和 .framework 结尾的文件，动态库一般是以 .dylib 和 .framework 结尾的文件。

这里可以看到，一个 .framework 结尾的文件仅仅通过文件类型是无法判断出它是一个静态库还是一个动态库。

静态库和动态库的区别在于：

1. .a文件肯定是静态库，.dylib肯定是动态库，.framework可能是静态库也可能是动态库；

2. 静态库在链接其他库的情况时，它会被完整的复制到可执行文件中，如果多个App都使用了同一个静态库，那么每个App都会拷贝一份，缺点是浪费内存。类似于定义一个基本变量，使用该基本变量是是新复制了一份数据，而不是原来定义的；静态库的好处很明显，编译完成之后，库文件实际上就没有作用了。目标程序没有外部依赖，直接就可以运行。当然其缺点也很明显，就是会使用目标程序的体积增大。

3. 动态库不会被复制，只有一份，程序运行时动态加载到内存中，系统只会加载一次，多个程序共用一份，节约了内存。而且使用动态库，可以不重新编译连接可执行程序的前提下，更新动态库文件达到更新应用程序的目的。




### 六. 组件间的消息传递和状态管理

之前我们讨论过了，iOS 组件化十分关注解耦性，这算是组件化的一个重要目的。iOS 各个组件之间消息传递是用路由来实现的。关于路由，笔者曾经写过一篇比较详细的文章，感兴趣的可以来看这篇文章[《iOS 组件化 —— 路由设计思路分析》](https://github.com/halfrost/Halfrost-Field/blob/master/contents/iOSRouter/iOS%20%E7%BB%84%E4%BB%B6%E5%8C%96%20%E2%80%94%E2%80%94%20%E8%B7%AF%E7%94%B1%E8%AE%BE%E8%AE%A1%E6%80%9D%E8%B7%AF%E5%88%86%E6%9E%90.md)。


### 七. 组件注册方式

iOS 组件注册的方式主要有3种：

1. load方法注册
2. 读取 plist 文件注册
3. Annotation注解方式注册

前两种方式都比较简单，容易理解。

第一种方式在 load 方法里面利用 Runtime 把组件名和组件实例的映射关系保存到一个全局的字典里，方便程序启动以后可以随时调用。

第二种方式是把组件名和组件实例的映射关系预先写在 plist 文件中。程序需要的时候直接去读取这个 plist 文件。plist 文件可以从服务器读取过来，这样 App 还能有一定的动态性。

第三种方式比较黑科技。利用的是 Mach-o 的数据结构，在程序编程链接成可执行文件的时候，就把相关注册信息直接写入到最终的可执行文件的 Data 数据段内。程序执行以后，直接去那个段内去读取想要的数据即可。

关于这三种做法的详细实现，可以看笔者之前的一篇文章[《BeeHive —— 一个优雅但还在完善中的解耦框架》](https://halfrost.com/beehive/)，在这篇文章里面详细的分析了上述3种注册过程的具体实现。

-------------------------------------------------------------------------------------

## 总结

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-62a679d7884a0b72.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>






经过上面的分析，我们可以看出 Vue 的组件化和 iOS 的组件化区别还是比较大的。

### 两者平台上开发方式存在差异

主要体现在单页应用和类多页应用的差异。

现在前端比较火的一种应用就是单页Web应用（single page web application，SPA），顾名思义，就是只有一张Web页面的应用，是加载单个HTML 页面并在用户与应用程序交互时动态更新该页面的Web应用程序。

浏览器从服务器加载初始页面，以及整个应用所需的脚本（框架、库、应用代码）和样式表。当用户定位到其他页面时，不会触发页面刷新。通过 HTML5 History API 更新页面的 URL 。浏览器通过 AJAX 请求检索新页面（通常以 JSON 格式）所需的新数据。然后， SPA 通过 JavaScript 动态更新已经在初始页面加载中已经下载好的新页面。这种模式类似于原生手机应用的工作原理。

但是 iOS 开发更像类 MPA (Multi-Page Application)。


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-d479b1a5eca9a13c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>




往往一个原生的 App ，页面差不多应该是上图这样。当然，可能有人会说，依旧可以把这么多页面写成一个页面，在一个 VC 里面控制所有的 View，就像前端的 DOM 那样。这种思路虽然理论上是可行的，但是笔者没有见过有人这么做，页面一多起来，100多个页面，上千个 View，都在一个 VC 上控制，这样开发有点蛋疼。

### 两者解决的需求也存在差异

iOS 的组件化一部分也是解决了代码复用性的问题，但是更多的是解决耦合性大，开发效率合作性低的问题。而 Vue 的组件化更多的是为了解决代码复用性的问题。

### 两者的组件化的方向也有不同。

iOS 平台由于有 UIKit 这类苹果已经封装好的 Framework，所以基础控件已经封装完成，不需要我们自己手动封装了，所以 iOS 的组件着眼于一个大的功能，比如网络库，购物车，我的钱包，整个业务块。前端的页面布局是在 DOM 上进行的，只有最基础的 CSS 的标签，所以控件都需要自己写，Vue 的组件化封装的可复用的单文件组件其实更加类似于 iOS 这边的 ViewModel。

所以从封装性上来讲，两者可以相互借鉴的地方并不多。iOS 能从前端借鉴的东西在状态管理这一块，单向数据流的思想。不过这一块思想虽然好，但是如何能在自家公司的app上得到比较好的实践，依旧是仁者见仁智者见智的事了，并不是所有的业务都适合单向数据流。


-------------------------------------------------------------------------------------

Reference：  
[Vue.js 官方文档](https://cn.vuejs.org/)



> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/vue\_ios\_modularization/](https://halfrost.com/vue_ios_modularization/)
