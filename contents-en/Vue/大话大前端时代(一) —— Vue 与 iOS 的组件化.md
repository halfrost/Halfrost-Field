![](http://upload-images.jianshu.io/upload_images/1194012-be7c923b3346f7f2.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


## Preface

This year, the concept of the “broader front end” has been mentioned again and again. So what exactly is the era of the broader front end? The term originally came from within Alibaba, where many front-end developers wrote both front-end code and Java Velocity templates. Today, however, its scope has become much broader, covering front end + mobile, front end, CDN, Nginx, Node, Hybrid, Weex, React Native, and Native App. I am an ordinary full-time iOS developer. After getting exposure to front-end development, I found that there are aspects of the front end that are worth learning from on the mobile side. That is how this series of articles on the era of the broader front end came about. I hope the two sides can learn from each other’s excellent ideas. When people talk about the broader front end, commonly mentioned topics include componentization, routing and decoupling, engineering practices (bundlers, scaffolding, package managers), MVC and MVVM architectures, event tracking, and performance monitoring. I will start with componentization. There are already many articles online comparing front-end frameworks (React, Vue, Angular), but there do not seem to be many cross-platform comparisons. So I plan to focus on comparing the front end with mobile development (mainly the iOS platform), look at the different approaches on both sides, and discuss whether there are ideas they can learn from each other.

The front-end portions of this article may seem fairly basic to front-end experts. If there are any mistakes, I sincerely welcome corrections.

-------------------------------------------------------------------------------------

## Vue Section


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-684fa2f2f2cb0685.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


### 1. The Need for Componentization

To improve code reuse and reduce repetitive development, we split related code into template, style, and script, then encapsulate it into individual components. Components can extend
 HTML elements and encapsulate reusable HTML code. We can think of components as custom HTML elements. In Vue, each encapsulated component can be considered a ViewModel.

### 2. How to Encapsulate Components

When discussing how to encapsulate components, we first need to talk about how to organize them.

In a simple SPA project, you can directly use Vue.component to define a global component. However, once the project becomes complex, this approach starts to show its drawbacks:

1. Global definitions require every component name to be unique
2. String templates lack syntax highlighting, and when HTML spans multiple lines, you have to use the ugly \
3. No CSS support means that when HTML and JavaScript are componentized, CSS is obviously left out
4. No build step restricts you to HTML and ES5 JavaScript, preventing you from using preprocessors such as Pug (formerly Jade) and Babel


Moreover, most company-level projects today introduce engineering-oriented management and use package managers such as npm or yarn. Therefore, in complex Vue projects, using Vue.component to define a component is no longer suitable. This is where single-file components come in, along with build tools such as Webpack or Browserify. For example, in the Hello.vue component below, the entire file is a component.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-df970b173f9ce00f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


In a single-file component, the entire file is a [CommonJS module](https://webpack.js.org/concepts/modules/#what-is-a-webpack-module), containing the component’s corresponding HTML, the component’s internal JavaScript logic, and the component’s CSS styles.

In the component’s script tag, you need to encapsulate the behavior of that component’s ViewModel.

- data
  The component’s initial data and private properties.
- props
  The component’s properties. These properties are specifically used to receive data for parent-child component communication. (This can be compared to @property in iOS.)
- methods
  Logic functions inside the component.
- watch
  Properties that need additional observation. (This can be compared to KVO in iOS.)
- computed
  The component’s computed properties

- components
  The child components used

- lifecycle hooks
  Lifecycle hook functions. A component also has a lifecycle, including the following: [beforeCreate](https://cn.vuejs.org/v2/api/#beforeCreate), [created](https://cn.vuejs.org/v2/api/#created), [beforeMount](https://cn.vuejs.org/v2/api/#beforeMount), [mounted](https://cn.vuejs.org/v2/api/#mounted), [beforeUpdate](https://cn.vuejs.org/v2/api/#beforeUpdate), [updated](https://cn.vuejs.org/v2/api/#updated), [activated](https://cn.vuejs.org/v2/api/#activated), [deactivated](https://cn.vuejs.org/v2/api/#deactivated), [beforeDestroy](https://cn.vuejs.org/v2/api/#beforeDestroy), [destroyed](https://cn.vuejs.org/v2/api/#destroyed), and others. In these hook functions, we can add the processing logic we have predefined. (This can be compared to the lifecycle of a ViewController in iOS.)


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-2bd002c5882c5f59.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


From this perspective, encapsulating a single-file component in Vue follows exactly the same line of thinking as encapsulating a ViewModel in iOS. Unless otherwise specified, the following discussion refers to single-file components.

### 3. How to Split Components

Components are generally split according to the following criteria:

1. Page regions:
    header, footer, sidebar……
2. Functional modules:
    select, pagenation……

Here is an example to illustrate how the front end splits components.

#### 1. Page Regions

Let’s again use the homepage of [objc China](https://objccn.io/) as an example.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-bbd112eb3c69962b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


We can take the page above and, based on its layout, first abstract the structure shown in the middle of the image, then continue splitting components by page region, and finally obtain the component tree on the far right.


In the root component of the Vue instance, load layout.
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
Based on the abstracted component tree, we can further break down each small component.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-1dabac090cd4534c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The components one level below layout are header, footer, and content. These three parts make up the entire `layout.vue` single-file component.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-db1dd792c3a99995.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The figure above shows the complete implementation of our `layout.vue`. This single-file component references three child components: `navigationBar`, `footerView`, and `content`. Since `content` consists of the various routed pages, it is declared here as `router-view`.

As for the concrete implementation of each child component, I won’t go into detail here. You can find the code here: [navigationBar.vue](https://github.com/halfrost/vue-objccn/blob/master/src/components/navigationBar.vue), [footerView](https://github.com/halfrost/vue-objccn/blob/master/src/components/footerView.vue), and [layout.vue](https://github.com/halfrost/vue-objccn/blob/master/src/components/layout.vue).


#### 2. Feature Modules

In a typical project, detail pages usually contain the most content. Let’s use the detail page from [objc China](https://objccn.io/products/functional-swift/) as an example.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-2da8a958d72370f1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The left side of the figure above is the detail page, and the right side shows the page divided by functionality. We split the entire page into six child components.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-a7320dfd2232e67b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


Expanded from top to bottom, as shown above.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-776b12675182b3d8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


After the functional decomposition, the code for the entire detail page becomes exceptionally clean. The whole page is just six single-file child components; each child component encapsulates its own logic, and the detail page simply composes them together. The code is highly readable and very easy to maintain later.

The concrete code for the detail page is here: [https://github.com/halfrost/vue-objccn/blob/master/src/pages/productsDetailInfo.vue](https://github.com/halfrost/vue-objccn/blob/master/src/pages/productsDetailInfo.vue)

The code for the six child components is here: [https://github.com/halfrost/vue-objccn/tree/master/src/components/productsDetailInfo](https://github.com/halfrost/vue-objccn/tree/master/src/components/productsDetailInfo). See the links for the specific code; I won’t go into detail here.


In summary, an abstracted frontend SPA page is essentially a large component tree.

### IV. Componentization Principles

For example:
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
            // Use the <child-component> tag inside the Parent component
            template :'<p>This is a Parent component !</p><child-component></child-component>',
            components: {
                // Locally register the Child component; it can only be used inside the Parent component
                'child-component': Child
            }
        })
        
        // Globally register the Parent component
        Vue.component('parent-component', Parent)
        
        new Vue({
            el: '#app'
        })
        
    </script>
</html>

```
In the example above, a `<child-component>` is declared inside the `<parent-component>` parent component. The final rendered result is:
```javascript

This is a Parent component !
This is a child component !

```
<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-6952239b3ee1ef64.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The execution order of the code above is as follows:

1. The child component is first registered in the parent component's components.
2. The parent component is registered globally using Vue.component.
3. When rendering the parent component, once `<child-component>` is encountered, the child component is also rendered.

One thing worth noting is that when Vue parses templates, it follows the following common HTML constraints:

- a cannot contain other interactive elements (such as buttons or links)
- ul and ol can only directly contain li
- select can only contain option and optgroup
- table can only directly contain thead, tbody, tfoot, tr, caption, col, colgroup
- tr can only directly contain th and td


### V. Component Categories

Components can be divided into the following four types:

1. Regular components
2. Dynamic components
3. Async components
4. Recursive components

#### 1. Regular Components

The components discussed earlier are all regular components, so they will not be repeated here.

#### 2. Dynamic Components

Dynamic components use the `is` feature, which allows multiple components to share the same mount point and be switched dynamically.
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
  <!-- The component changes when vm.currentview changes! -->
</component>

```
Now that the concrete type of the `<component>` component is represented by `currentView`, we can dynamically load different components by changing the value of `currentView`. In the example above, you can keep changing `currentView` in `data` to dynamically load the three different components: `home`, `posts`, and `archive`.


#### 3. Async Components

Vue allows you to define a component as a factory function. When the component needs to be rendered, Vue triggers the factory function to dynamically resolve the component and caches the result:
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
Dynamic components can be used with webpack to implement code splitting. webpack can split code into chunks and download a chunk via AJAX when it is needed:
```javascript

Vue.component('async-webpack-example', function(resolve) {
  // This special require syntax tells webpack
  // to automatically split the compiled code into separate chunks,
  // which will be automatically downloaded via ajax requests.
  require(['./my-async-component'], resolve)
});

```

#### 4. Recursive Components

If a component has the `name` property set, it can become a recursive component.

A recursive component can use its `name` inside the template to call itself recursively.
```javascript

name: 'recursion-component',
template: '<div><recursion-component></recursion-component></div>'

```
The code above is incorrect. Writing a template this way will cause infinite recursive loops, eventually resulting in the error “max stack size exceeded”. The solution is to break the infinite loop, for example by having `v-if` return false.

### VI. Message Passing and State Management Between Components

In Vue, component message passing is mainly divided into three approaches:

1. Message passing between parent and child components
2. Event Bus
3. Vuex unidirectional data flow

#### 1. Message Passing Between Parent and Child Components


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-80767515e312dbfe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The communication pattern between parent and child components is relatively straightforward. Since Vue 2.0, the relationship between parent and child components can be summarized as ** props down, events up **. The parent component passes data down to the child component via props, and the child component sends messages to the parent component via events.

#### Passing Data from Parent to Child

For example:
```javascript

Vue.component('child', {
  // Declare props
  props: ['msg'],
  // prop can be used in the template
  // can be set with `this.msg`
  template: '<span>{{ msg }}</span>'
})

<child msg="hello!"></child>

```
In the child component’s props, a `msg` property is declared, and the parent component uses this property to pass a value to the child component.

One thing to note here is that in non-string templates, camelCased prop names need to be converted to their corresponding kebab-case names.

The example above uses static binding. Vue also supports dynamic binding, where the `v-bind` directive can be used to bind props dynamically.

Passing data from parent to child is a one-way data flow. A prop is a one-way binding: when a parent component’s property changes, the change is propagated to the child component, but not the other way around. This is to prevent child components from accidentally modifying the parent component’s state—which would make the application’s data flow difficult to understand.

In addition, every time the parent component updates, all props in the child component are updated to their latest values. This means you should not mutate props inside a child component. Vue recommends treating a child component’s props as immutable.

This leads to two categories of problems:

1. Because of one-way data flow, the child component’s data or state may become inconsistent with the parent component’s. To synchronize them, you might try to modify the parent component’s data or state from the child component, going against the data flow.

2. After the child component receives the value of a prop, there are two reasons it might want to change it. The first is that after the prop is passed in as an initial value, the child component wants to use it as local data. The second is that after the prop is passed in as an initial value, the child component wants to process it into some other data for output.

Both of these categories of problems can technically be handled by forcibly changing the data, but doing so leads to undesirable consequences. For the first problem, forcibly and manually modifying the parent component’s data or state results in a chaotic data flow. Looking only at the parent component, it becomes difficult to understand its state, because it may be modified by any child component. Ideally, only a component itself should be able to modify its own state. For the second problem, if you forcibly and manually mutate a child component’s props, Vue will print a warning in the console.

So how can we solve these two problems elegantly? Let’s go through them one by one:

#### (1) The first problem can be solved by switching to two-way binding.

In Vue 2.3.0 and later, there are two ways to implement two-way binding.

First approach:  

Use the `.sync` modifier. In Vue 2.3.0 and later, it exists as compile-time syntactic sugar. It is expanded into a `v-on` listener that automatically updates the parent component’s property.
```javascript

// Declare a two-way binding
<comp :foo.sync="bar"></comp>


// The line above will be expanded to the following line:
<comp :foo="bar" @update:foo="val => bar = val"></comp>

// When the child component needs to update the value of foo, it explicitly triggers an update event:
this.$emit('update:foo', newValue)

```
The second approach:

Custom events can be used to create custom form input components, with v-model used for two-way data binding.
```javascript

<input :value="value" @input="updateValue($event.target.value)" >

```
Two-way binding implemented in this way must meet two conditions:

- Accept a `value` prop
- Trigger an `input` event when there is a new value


The two officially recommended ways to implement two-way binding are the two methods described above. However, there are also some implicit forms of two-way binding that may inadvertently introduce bugs.

Props are passed as one-way data flow: the parent component passes data to the child component. One thing to pay particular attention to is that if the data being passed is a reference type, such as an array or object, then by default it effectively becomes two-way data binding, and any changes made by the child component will affect the parent component. In this case, if developers are unaware of it, some inexplicable bugs may occur, so you need to be careful when passing reference-type data.


#### (2) For the second question, there are two approaches:

- The first approach is: define a local variable and initialize it with the prop value:
```javascript

props: ['initialCounter'],
data: function () {
  return { counter: this.initialCounter }
}

```
- The second approach is to define a computed property that processes the prop value and returns it.
```javascript

props: ['size'],
computed: {
  normalizedSize: function () {
    return this.size.trim().toLowerCase()
  }
}

```
A parent can also pass templates to a child, using slots to distribute content.

`slot` is a built-in custom element directive in Vue. In the `bind` callback, `slot` obtains the element that will replace the slot based on `name`. If the required replacement content exists in the current context, it calls the parent element’s `replaceChild` method to replace the `slot` element with the replacement element; otherwise, it directly removes the element to be replaced. If the replacement slot element has a top-level element, and the first child node of that top-level element is a DOM element, and that node has a `v-if` directive, and the `slot` element contains content, then the replacement template will add a `v-else` template containing the content placed in the slot. If the `v-if` directive is `false`, the `else` template content is rendered.


#### Passing from Child to Parent

For a child component to pass data back to its parent component, there is only one common approach: use custom events.

The parent component uses `$on(eventName)` to listen for events.  
The child component uses `$emit(eventName)` to trigger events.

Here is a simple example:
```javascript

// A button in the child component
<button @click="emitMyEvent">emit</button>

emitMyEvent() {
  this.$emit('my-event', this.hello);
}


// Listen for the child component's custom event in the parent component
<child @my-event="getMyEvent"></child>

getMyEvent() {
    console.log(' i got child event ');
}


```
Here, data can also be passed through the parent-child relationship (by directly modifying the data), but this approach is not recommended. For example, this.$parent or this.$children can be used to directly call methods on the parent or child component. This is analogous to the ViewControllers approach in iOS: you can directly obtain all VCs from this array, and then call the methods they expose in their .h files. However, this approach creates excessive direct coupling between components.


#### 2. Event Bus 

The concept of an Event Bus should also be familiar to mobile developers, since it exists in Android development as well. In iOS development, it can be compared to a message bus. A concrete implementation could be Notification, or signal passing in ReactiveCocoa.

The implementation of an Event Bus still relies on a Vue instance. Create a new Vue instance specifically to serve as the message bus.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-a66753d084e38d03.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>
```javascript

var eventBus = new Vue()

// Import eventBus in component A
eventBus.$emit('myEvent', 1)

// Listen in the component that needs it
eventBus.$on('id-selected', () => {
  // ...
})

```

#### 3. Vuex Unidirectional Data Flow

Since this article focuses on componentization, Vuex is only introduced here in terms of usage. As for its underlying principles, I will write a separate article to analyze them later.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-8e6a23db3eeae215.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


This diagram describes what Vuex is. Vuex is a state management pattern developed specifically for Vue.js applications. It uses a centralized store to manage the state of all components in an application, and applies corresponding rules to ensure that state changes in a predictable way.

The direction of the arrows in the diagram above describes the data flow. The data flow is unidirectional: it flows from Actions to State, and changes in the data in State then affect the data displayed in the View.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-3beeb181eee83538.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


From the three simple roles of Actions, State, and View, a new role has now been added: Mutations. Mutations are now the only way to change state in the Vuex store: by committing a mutation. Mutations in Vuex are very similar to events: each mutation has a string event type (type) and a callback function (handler).

Typically, a component calls a Mutation method by performing a commit.
```javascript

this.$store.commit('increment', payload);

```
The differences between Actions and Mutations are:

- An Action commits a mutation instead of directly changing state.
- An Action can contain arbitrary asynchronous operations, whereas Mutations must be synchronous functions.

Actions are generally invoked in components via `dispatch`.
```javascript

this.$store.dispatch('increment');

```
Vuex’s official best practices provide a project template structure, with the expectation that we organize our projects according to this pattern.
```javascript


├── index.html
├── main.js
├── api
│   └── ... # Extracted API requests
├── components
│   ├── App.vue
│   └── ...
└── store
    ├── index.js          # Where we assemble modules and export the store
    ├── actions.js        # Root-level actions
    ├── mutations.js      # Root-level mutations
    └── modules
        ├── cart.js       # Cart module
        └── products.js   # Products module

```
The detailed code for this example is [here](https://github.com/vuejs/vuex/tree/dev/examples/shopping-cart)

### 7. Component Registration Methods

Component registration mainly falls into two types: global registration and local registration.

#### 1. Global Registration

Use the Vue.component directive for global registration.
```javascript

Vue.component('my-component', {
  // Options
})

```
Once registered, the component can be used in the parent instance as a custom element: `<my-component></my-component>`.
```javascript

// Register
Vue.component('my-component', {
  template: '<div>A custom component!</div>'
})
// Create root instance
new Vue({
  el: '#example'
})

<div id="example">
  <my-component></my-component>
</div>

```

#### 2. Local Registration

Globally registered components can slow down the loading of some pages. Some components only need to be loaded when they are actually used, so there is no need to register every component globally. This is where local registration comes in.
```javascript


var Child = {
  template: '<div>A custom component!</div>'
}
new Vue({
  // ...
  components: {
    // <my-component> will only be available in the parent template
    'my-component': Child
  }
})

```
-------------------------------------------------------------------------------------

## iOS Section


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-b2abeb076a3d4a0a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


### 1. The Need for Componentization

During the early stages of iOS Native app development, if there are not many developers involved, most of the code is usually written in a single project. At that point, business growth is typically not too fast, so development efficiency can often be maintained.

However, once the project becomes large, the development team gradually grows, and the business starts advancing rapidly, the drawbacks of a single-project development model begin to surface.

- Code files within the project are tightly coupled.
- Conflicts are easy to introduce. In large companies, many people work on the same project at the same time. Every time you pull the latest code, there may be many conflicts. Sometimes merging code can take around half an hour, which hurts development efficiency.
- Business-side development efficiency is not high enough. Once there are many developers, everyone only wants to focus on their own component, but they still have to compile the entire project and work alongside unrelated code. Debugging is also inconvenient: even for a very small feature, the entire project has to be compiled, resulting in low debugging efficiency.

To solve these problems, the concept of componentization emerged in iOS projects. Therefore, iOS componentization is meant to address the issues above, which are different from the pain points solved by frontend componentization.

After iOS componentization, the following benefits can be achieved:

* Faster compilation speed (no need to compile the huge chunk of code in the main project; each component is a static library)
* Freedom to choose a development style (MVC / MVVM / FRP)
* Easier for QA to perform targeted testing
* Improved business development efficiency

Encapsulation is only a small part of iOS componentization. The bigger concerns are how to split components and how to decouple them. Frontend componentization may focus more on encapsulation and high reusability.

### 2. How to Encapsulate Components

The approach to iOS componentization is very straightforward: use CocoaPods to encapsulate code as pod libraries, and let the main project reference these pods respectively. More and more third-party libraries are also publishing their latest versions on CocoaPods, and large companies maintain private CocoaPods repositories internally. A well-encapsulated Pod component is very convenient for the main project to use.

As for how to use CocoaPods to package a static library .a or a framework, there are many tutorials online. Here is a [link](http://www.cnblogs.com/brycezhang/p/4117180.html); the detailed steps will not be repeated here.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-40000a4f3a3db8ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The ideal end state is that the main project becomes only a shell project. All other code lives inside component Pods, and the main project is only responsible for initialization and loading these components, with no other code.


### 3. How to Divide Components

Although there is no very explicit standard for dividing iOS components—because every project is different and the granularity of component boundaries varies—there are still guiding principles.

Things that can be reused across apps, such as Util, Category, the networking layer, and local storage, are extracted into Pod libraries. There are also some business-related pieces that are reused across different apps.

The principle is: code that should be shared across apps should be extracted into Pod libraries and treated as individual components. Business lines that are not shared between apps should also be extracted into Pods to decouple them from other files in the project.

A common way to split components is to start from the lower layers: networking libraries, routing, MVVM frameworks, database storage, encryption and decryption, utility classes, maps, base SDKs, APM, risk control, analytics tracking, and so on. Moving upward, you reach components owned by different business teams. The most common examples include shopping cart, my wallet, login, registration, and so forth.

### 4. Principles of Componentization

iOS componentization is accomplished with the help of CocoaPods. For details on how CocoaPods works, you can read this article: [“What Exactly Does CocoaPods Do?”](http://draveness.me/cocoapods.html).

Here is a brief analysis of how libraries brought in by pod are loaded into the main project.

Based on the dependency libraries specified in the Podfile, pod downloads the source code of these libraries and creates the Pods workspace. When the program is compiled, two scripts configured by pod are executed in advance.

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-be89228b5c8e836c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


In the script above, the packaged static libraries inside Pods are merged into the static library libPods-XXX.a, which is the library the main project depends on.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-879307a922464b83.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The image above shows the script that loads the Pods libraries into the main project.


Another script in Pods is used to load resources, as shown below.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-7d14f08e853739eb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The resources loaded here include image resources inside the Pods libraries, or xib, storyboard, music resources, and so on inside a Bundle. These resources are also packaged together into the static library libPods-XXX.a.


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-4d685a3753c16303.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


The image above shows the script that loads resources.


### 5. Component Categories

iOS components are mainly divided into two forms:

1. Static libraries
2. Dynamic libraries

Static libraries are generally files ending in .a and .framework, while dynamic libraries are generally files ending in .dylib and .framework.

As you can see, for a file ending in .framework, it is not possible to determine whether it is a static library or a dynamic library based only on the file type.

The differences between static libraries and dynamic libraries are:

1. A .a file is definitely a static library, a .dylib file is definitely a dynamic library, and a .framework file may be either a static library or a dynamic library;

2. When a static library is linked with other libraries, it is copied in full into the executable file. If multiple apps use the same static library, each app will copy its own copy. The downside is wasted memory. This is similar to defining a primitive variable: using that primitive variable creates a new copy of the data rather than using the originally defined data. The benefit of a static library is obvious: after compilation is complete, the library file effectively no longer matters. The target program has no external dependencies and can run directly. Of course, its drawback is also obvious: it increases the size of the target program.

3. A dynamic library is not copied. There is only one copy, which is dynamically loaded into memory when the program runs. The system loads it only once, and multiple programs share the same copy, saving memory. Moreover, with a dynamic library, you can update the application by updating the dynamic library file without recompiling and relinking the executable program.


### 6. Message Passing and State Management Between Components

As discussed earlier, iOS componentization is very concerned with decoupling, which is one of the important goals of componentization. Message passing between iOS components is implemented using routing. Regarding routing, the author previously wrote a fairly detailed article. If you are interested, you can read [“iOS Componentization — Analysis of Routing Design Ideas”](https://github.com/halfrost/Halfrost-Field/blob/master/contents-en/iOSRouter/iOS%20%E7%BB%84%E4%BB%B6%E5%8C%96%20%E2%80%94%E2%80%94%20%E8%B7%AF%E7%94%B1%E8%AE%BE%E8%AE%A1%E6%80%9D%E8%B7%AF%E5%88%86%E6%9E%90.md).


### 7. Component Registration Methods

There are mainly three ways to register iOS components:

1. Registration via the load method
2. Registration by reading a plist file
3. Registration via annotations

The first two approaches are relatively simple and easy to understand.

The first approach uses Runtime inside the load method to save the mapping between component names and component instances into a global dictionary, making it convenient for the program to call them at any time after startup.

The second approach predefines the mapping between component names and component instances in a plist file. When the program needs it, it reads the plist file directly. The plist file can be fetched from the server, which gives the App a certain degree of dynamism.

The third approach is rather hacky. It uses the Mach-O data structure: when the program is compiled and linked into an executable file, the relevant registration information is written directly into the Data segment of the final executable file. After the program runs, it can directly read the desired data from that segment.

For detailed implementations of these three approaches, you can read a previous article by the author: [“BeeHive — An Elegant Decoupling Framework That Is Still Being Improved”](https://halfrost.com/beehive/). That article analyzes the concrete implementation of the three registration processes above in detail.

-------------------------------------------------------------------------------------

## Summary

<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-62a679d7884a0b72.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


From the analysis above, we can see that there are still significant differences between Vue componentization and iOS componentization.

### There are differences in development models between the two platforms

This is mainly reflected in the difference between single-page applications and quasi-multi-page applications.

A currently popular type of frontend application is the single page web application (SPA). As the name suggests, it is an application with only one Web page: a Web application that loads a single HTML page and dynamically updates that page as the user interacts with the application.

The browser loads the initial page from the server, along with the scripts required by the entire application (frameworks, libraries, application code) and style sheets. When the user navigates to other pages, no page refresh is triggered. The page URL is updated through the HTML5 History API. The browser retrieves the new data required by the new page through AJAX requests, usually in JSON format. Then the SPA dynamically updates the new page through JavaScript using what has already been downloaded during the initial page load. This model is similar to how native mobile applications work.

However, iOS development is more like a quasi-MPA (Multi-Page Application).


<p align='center'>
<img src='http://upload-images.jianshu.io/upload_images/1194012-d479b1a5eca9a13c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240'>
</p>


A native App page structure usually looks roughly like the image above. Of course, some people may say that it is still possible to implement so many pages as a single page, controlling all Views inside one VC, just like the frontend DOM. Although this idea is theoretically feasible, the author has never seen anyone actually do this. Once there are many pages—more than 100 pages and thousands of Views—all controlled in one VC, development becomes rather painful.

### The requirements solved by the two also differ

iOS componentization partly solves the problem of code reuse, but it is more about addressing high coupling and low development/collaboration efficiency. Vue componentization, on the other hand, is more about solving the problem of code reuse.

### The directions of componentization also differ between the two.

On the iOS platform, because Apple has already encapsulated Frameworks such as UIKit, the basic controls are already packaged and do not need to be manually encapsulated by us. Therefore, iOS components focus on larger features, such as a networking library, shopping cart, my wallet, or an entire business module. Frontend page layout is done on the DOM, with only the most basic CSS tags, so controls all need to be written manually. The reusable single-file components encapsulated by Vue are actually more similar to ViewModels on the iOS side.

Therefore, from an encapsulation perspective, there is not much the two can learn from each other. What iOS can borrow from the frontend lies in state management and the idea of unidirectional data flow. Although this idea is good, how to put it into good practice in one’s own company’s app is still a matter of differing opinions, and not every business scenario is suitable for unidirectional data flow.


-------------------------------------------------------------------------------------

Reference:  
[Vue.js Official Documentation](https://cn.vuejs.org/)


> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/vue\_ios\_modularization/](https://halfrost.com/vue_ios_modularization/)