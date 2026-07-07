+++
author = "一缕殇流化隐半边冰霜"
categories = ["JavaScript"]
date = 2017-07-15T09:25:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/53_0_.png"
slug = "jsconf_china_2017_final"
tags = ["JavaScript"]
title = "JSConf China 2017 Day Two — End And Beginning"

+++


The second day’s talks leaned more toward Web backends.

## Session 1: Node.js Microservices on Autopilot

![](https://img.halfrost.com/Blog/ArticleImage/53_1.png)


The opening briefly introduced what microservices are.


![](https://img.halfrost.com/Blog/ArticleImage/53_2.png)


### How Microservices Help

![](https://img.halfrost.com/Blog/ArticleImage/53_3.png)


- Hypothetical steps:
    - Break the cron service into many smaller services
    - Each microservice can be deployed independently
    - New microservices can all be load balanced

- When microservice architectures are the same as the services they replace, they face the same challenges.


### Advantages of Microservices

![](https://img.halfrost.com/Blog/ArticleImage/53_4.png)


- Tolerate failures and continue working despite external failures.

- Iterate quickly, with disposable services that can be deployed independently.

### Microservice Anti-patterns


![](https://img.halfrost.com/Blog/ArticleImage/53_5.png)


- Load balancers are needed between microservices

- Startup order matters

- Load balancing is everywhere.

![](https://img.halfrost.com/Blog/ArticleImage/53_6.png)


### Autopilot Pattern

![](https://img.halfrost.com/Blog/ArticleImage/53_7.png)


- Applications that can be deployed and scaled with a single click.

- Applications and workflows work the same way on our laptops and in the cloud, whether public or private.

- Applications and workflows are not tightly bound to any specific architecture or scheduler.

### Autopilot Applications

![](https://img.halfrost.com/Blog/ArticleImage/53_8.png)


- A solution based on the Autopilot pattern
- Services can be obtained through Containers

###  Autopilot in Practice

![](https://img.halfrost.com/Blog/ArticleImage/53_9.png)


- Applications consist of Docker containers
- Service discovery can use Consul or another catalog
- Container-local health checks and services respond to changes in service dependencies


![](https://img.halfrost.com/Blog/ArticleImage/53_10.png)


### ContainerPilot

![](https://img.halfrost.com/Blog/ArticleImage/53_11.png)


- Automates service discovery, lifecycle management, and telemetry reporting for a Container
- Features
	- Container-local health checks
	- PID 1 init process
	- Service discovery, registration, and observation
	- Telemetry reporting to Prometheus
	- Free and open source: [https://github.com/joyent/containerpilot](https://github.com/joyent/containerpilot)

![](https://img.halfrost.com/Blog/ArticleImage/53_12.png)


### Some tips:

- Guard against request patterns that can occur and overload services.
- Once the response-timeout threshold is reached, block subsequent service calls until the service can catch up or recover.
- Can this be implemented with a load balancer?

![](https://img.halfrost.com/Blog/ArticleImage/53_13.png)


### Load Balancers at the Edge

![](https://img.halfrost.com/Blog/ArticleImage/53_14.png)


- Do not expose microservices directly outside your organization.
- Set up a load balancer that can use Consul.
- API gateways are also important when creating business value through microservices.


## Session 2:	Serverless Architecture and APIs

![](https://img.halfrost.com/Blog/ArticleImage/53_15.png)


### Function as a Service

![](https://img.halfrost.com/Blog/ArticleImage/53_16.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_17.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_18.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_19.png)


### Software development needs to consider the following:

- Operability

- Scalability

- Security

- Stability

- Reliability

- High availability


### XaaS Comparison

![](https://img.halfrost.com/Blog/ArticleImage/53_20.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_21.png)


### Application Architecture and Execution Model of Function Computing

![](https://img.halfrost.com/Blog/ArticleImage/53_22.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_23.png)


### API Gateway & Function Computing

![](https://img.halfrost.com/Blog/ArticleImage/53_24.png)


Features of API Gateway:

- Attack prevention, replay protection, request encryption, identity authentication, permission management, and traffic control

- API definition, testing, publishing, and decommissioning lifecycle management

- Monitoring, alerting, analytics, and API marketplace

![](https://img.halfrost.com/Blog/ArticleImage/53_25.png)


Limitations of FaaS

![](https://img.halfrost.com/Blog/ArticleImage/53_26.png)


- Uncertainty of the runtime environment: IP changes

- The number of runtime environments and the pressure on dependent resources: for example, limits on the number of database connections.


## Session 3: From REST to GraphQL 


![](https://img.halfrost.com/Blog/ArticleImage/53_27.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_28.png)


GraphQL is a query language for APIs.

![](https://img.halfrost.com/Blog/ArticleImage/53_29.png)


A simple GraphQL query

Page load time = loading code + loading data


This talk was mainly divided into three major parts:

![](https://img.halfrost.com/Blog/ArticleImage/53_30.png)


### The Evolution of Web Development

Early Web development:

![](https://img.halfrost.com/Blog/ArticleImage/53_31.png)


A Web server returned static HTML to the browser.

Web development in 2017

![](https://img.halfrost.com/Blog/ArticleImage/53_32.png)


The Web server returns code, while the user service, Posts service, and external APIs return data to the browser. A page has many requests, requesting various kinds of data. Today there are also multiple clients: browsers, iOS, and Android.

### Pure REST - One endpoint per resource

![](https://img.halfrost.com/Blog/ArticleImage/53_33.png)


Advantages:

- Flexible  
- Decoupled  


Disadvantages

- Requires many requests  
- Fetches data that is not needed  
- Complex client-side logic  


### REST-like - One endpoint per view


![](https://img.halfrost.com/Blog/ArticleImage/53_34.png)


Advantages:

- One request  
- Get exactly what you need

Disadvantages:

- Not flexible enough
- Tightly coupled
- Very high maintenance cost
- Slow iteration


What we need:

- Only one request
- Get exactly what we need
- Flexible
- Decoupled

And what GraphQL can give us:

![](https://img.halfrost.com/Blog/ArticleImage/53_35.png)


- Only one request
- Get exactly what we need
- Decoupled


GraphQL has the following three important characteristics:

- An API definition language for describing data types and relationships
- A query language that can describe exactly which data needs to be fetched
- An executable model that can resolve down to individual fields of the data

GraphQL resolvers are roughly equivalent to REST endpoints


![](https://img.halfrost.com/Blog/ArticleImage/53_36.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_37.png)


GraphQL is a specification, not an implementation. It has corresponding specifications for servers, clients, and tools.


The following major companies are using GraphQL in production.


![](https://img.halfrost.com/Blog/ArticleImage/53_38.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_39.png)


In the second part, the speaker demonstrated a real-world example:


For the concrete example, you will need to watch the replay video.


![](https://img.halfrost.com/Blog/ArticleImage/53_40.png)


The third part looked ahead to the future of GraphQL.


![](https://img.halfrost.com/Blog/ArticleImage/53_41.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_42.png)


## Session 4: Visual Testing-Driven Development with React Storybook

![](https://img.halfrost.com/Blog/ArticleImage/53_43.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_44.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_45.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_46.png)
![](https://img.halfrost.com/Blog/ArticleImage/53_47.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_48.png)


In this session, the speaker shared a lot of practical lessons learned from real projects. The speaker delivered the entire talk in fluent English. If you are interested, I recommend watching the replay directly.

## Session 5: Graduating your node.js API to production environment

![](https://img.halfrost.com/Blog/ArticleImage/53_49.png)


The type of architecture we expect

![](https://img.halfrost.com/Blog/ArticleImage/53_50.png)


### What is a production system?

A system with real users and real data; a public service with at least thousands of daily users.

### What does it mean to be production-grade?

- Developers: The code runs, and all functional tests pass.

- Business managers: The system can run and deliver value and profit to users.

- Library developers: Their libraries are widely adopted and have good documentation.

- Operations: The runtime environment is stable, debuggable, and maintainable.

- Security experts: The system passes security checks.

### Avoid gaps in ownership

Prerequisites for writing production-grade code

- Stable
- Effective
- Debuggable

### How to trace logs across components


![](https://img.halfrost.com/Blog/ArticleImage/53_51.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_52.png)


### Debugging alone is not enough

![](https://img.halfrost.com/Blog/ArticleImage/53_53.png)


### How to survive upstream service failures


![](https://img.halfrost.com/Blog/ArticleImage/53_54.png)


### Add error handling 

![](https://img.halfrost.com/Blog/ArticleImage/53_55.png)


### How to run performance/stability tests

![](https://img.halfrost.com/Blog/ArticleImage/53_56.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_57.png)


### Security

![](https://img.halfrost.com/Blog/ArticleImage/53_58.png)


### Summary

Thinking:

- Consider every aspect of taking a product online
- Avoid gaps in ownership

Code:

- Proper logging
- Handle service failures
- Record error details
- Manage connections


System:

- Run performance and stability tests
- Do not implement all security-related logic on your own


## Session 6: Developing IoT Applications with Node.js

![](https://img.halfrost.com/Blog/ArticleImage/53_59.png)


## IoT Development  

Data generation -> sensors    
Data collection -> network transmission    
Data analysis -> cloud servers    
Act on analysis results -> actuators/push notifications    

![](https://img.halfrost.com/Blog/ArticleImage/53_60.png)


## Why choose Node.js?

- Ecosystem
- High concurrency
- Easy to extend
- Learning curve
- Development efficiency
- Communication between frontend and backend teams

At the end, the speaker demonstrated a small car on site, controlling its behavior by sending commands such as forward, backward, turn left, and turn right from a web page.

## Session 7: Upgrading to Progressive Web Apps

![](https://img.halfrost.com/Blog/ArticleImage/53_61.png)


Mr. Huang Xuan shared a lot in this talk, packed with practical insights. It was also one of the sessions I gained the most from at this conference. [Link to Mr. Huang Xuan’s slides](https://huangxuan.me/jsconfcn2017/#/)


From the title of the talk, you can tell that this session covers the evolution of PWA. It covered 10 stages in total.

### 1. A Web App

![](https://img.halfrost.com/Blog/ArticleImage/53_62.png)


Here, a simple example was shown: Githuber.js, a single-page application that can look up GitHub users by username.

As a typical web application, it has two obvious hard dependencies:
1. We depend on the browser as the runtime and the entry point to the application.
2. We depend on the network to download the client-side code of the application.


These two inherent characteristics of the web platform were once advantages of the Web in the desktop era. But on mobile devices, because of smaller screens, new interaction models, and fragile network conditions, web applications ended up at a clear disadvantage compared with native applications.

Although this Web app is fairly complete in terms of functionality, in the mobile Internet era, native apps have a much larger install base.

At this point, we start considering adding some native capabilities to the Web app. That brings us to the second stage.


### 2. A Standalone Web App

We want this Web application to stand on its own and become a first-class citizen of the operating system, just like a native application.

![](https://img.halfrost.com/Blog/ArticleImage/53_63.png)


In fact, as early as 2008, iOS 1.1.3 and iOS 2.1.0 respectively added support for web apps to use custom icons, be added to the home screen, and open in full-screen mode.


To implement the functionality above, the web page needs to include code similar to the following.
```javascript

<!-- Add to homescreen for Chrome on Android -->
<meta name="mobile-web-app-capable" content="yes">
<mate name="theme-color" content="#000000">

<!-- Add to homescreen for Safari on iOS -->
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black">
<meta name="apple-mobile-web-app-title" content="Lighten">

<!-- Tile icon for Win8 (144x144 + tile color) -->
<meta name="msapplication-TileImage" content="images/touch/ms-touch-icon-144x144-precomposed.png">
<meta name="msapplication-TileColor" content="#3372DF">

<!-- Icons for iOS and Android Chrome M31~M38 -->
<link rel="apple-touch-icon-precomposed" sizes="144x144" href="images/touch/apple-touch-icon-144x144-precomposed.png">
<link rel="apple-touch-icon-precomposed" sizes="114x114" href="images/touch/apple-touch-icon-114x114-precomposed.png">
<link rel="apple-touch-icon-precomposed" sizes="72x72" href="images/touch/apple-touch-icon-72x72-precomposed.png">
<link rel="apple-touch-icon-precomposed" href="images/touch/apple-touch-icon-57x57-precomposed.png">

<!-- Generic Icon -->
<link rel="shortcut icon" href="images/touch/touch-icon-57x57.png">

```
After a certain amount of exploration, in 2013 the W3C WebApps Working Group began standardizing a JSON-based Manifest, published the first public Working Draft at the end of that year, and gradually evolved it into what is now the W3C Web App Manifest.

You need to configure a Manifest here:
```javascript


<!-- Chrome Add to Homescreen -->
<link rel="shortcut icon" sizes="196x196" href="images/touch/touch-icon-196x196.png">
{
  "name": "Githuber.JS",
  "short_name": "Githuber.JS",
  "icons": [{
      "src": "logo-512x512.png",
      "type": "image/png",
      "sizes": "512x512"
    }],
  "start_url": "./",
  "display": "standalone",
  "orientation": "portrait",
  "theme_color": "#f36a84",
  "background_color": "#ffffff"
}
Web App Manifest
<link rel="manifest" href="/manifest.json">


```
For example, here we can see the name and icon of the web application, and we can specify that this web app should always launch from this URL, be displayed in a standalone mode, and lock the screen to portrait orientation.

Then, when this web app is added to the home screen, the browser can use this manifest file to integrate these application settings with the operating system. For example, the icon, full-screen launch, and theme color here are all very visible.


In this way, a web page can exist on the desktop like a native app. But that raises another question: if the phone currently has no network connection, then opening this bookmark means the app becomes completely unusable.


### 3. An Installable Web App

The third stage is becoming an installable web app. If our web application can be installed, doesn’t the network become a form of progressive enhancement?


The earliest example can be traced back to Google Gears in 2007. Gears began being standardized by the W3C in 2008, and its LocalServer was the predecessor of App Cache, which later became well known in HTML5.
```javascript

// Somewhere in your javascript
var localServer = google.gears.factory.create("localserver");
var store = localServer.createManagedStore(STORE_NAME);
store.manifestUrl = "manifest.json"

{
　　"betaManifestVersion":　1,
　　"version": 　"1.0",
　　"entries":　[　
　　　　{　"url": 　"index.html"},
　　　　{　"url": 　"main.js"}
　　]
}


```
Then, in 2011, it evolved into App Cache.
```javascript

<html manifest="cache.appcache">

CACHE MANIFEST

CACHE:
style/default.css
images/sound-icon.png
images/background.png

NETWORK:
comm.cgi


```
This is actually [**HTML5 Offline Web Applications**](https://www.w3.org/TR/2011/WD-html5-20110525/offline.html)

The design of App Cache was really terrible... It was not programmable, the cache could not be cleared, and if you accidentally set a one-year
 HTTP cache for the appcache file, your users would remain stuck on the same version for the rest of their lives, and you would have no kill switch.


![](https://img.halfrost.com/Blog/ArticleImage/53_64.png)


However, due to caching issues, Application Cache was removed on May 19, 2016.

Eventually, this led to the era of Service Workers. On October 11, 2016, a new draft proposed by W3C introduced the concept of Service Workers.
```vim

Service Workers 1
W3C Working Draft, 11 October 2016

```
Normally, all code resources for our web applications are fetched over HTTP—remember Cache Storage? A Service Worker is like a client-side proxy written in JavaScript that sits between the browser and the network, and can intercept, process, and respond to all HTTP requests that pass through it.

You can also cache Responses obtained from network requests in Cache Storage, which was introduced together with Service Workers. This enables a Service Worker to serve responses to a web application from the cache even when offline.

![](https://img.halfrost.com/Blog/ArticleImage/53_65.png)


Note: Service Workers must require HTTPS in production to prevent man-in-the-middle attacks.

![](https://img.halfrost.com/Blog/ArticleImage/53_66.png)


The figure above shows the Service Worker lifecycle. The two blue stages, Install and Activate, are lifecycle events: installation and activation. Once these two events are complete, the Service Worker is ready.

What does it mean for these two events to be complete? The Service Worker specification defines a new `ExtendableEvent` interface: an extendable event. It has only one method, `waitUntil`, which accepts a promise. The event is considered finished only when that promise is fulfilled.

For example, in the code below, the `install` event is not considered finished until `promiseA` is fulfilled; only then is the `activate` event triggered. Then, only after `Promise B` is fulfilled is the Service Worker truly ready.


Service Workers also have several extended events:
```javascript

// IDL
interface ExtendableEvent : Event {
  void waitUntil(Promise<any> f);
};
// sw.js
self.oninstall = (e) => {
  e.waitUntil(promiseA)
}
self.onactivate = (e) => {
  e.waitUntil(promiseB)
}

```
![](https://img.halfrost.com/Blog/ArticleImage/53_67.png)


Once the SW is in place, it starts receiving functional events, including network request `Fetch`, push notification `Push`, background synchronization `Sync`, and so on. These events wake the SW from its idle state to execute your event callbacks. At the same time, the SW also has a `message` event inherited from the abstract Web Worker, which is used for communication between the Worker and the document’s main thread. With that, we can start doing some interesting things. During the SW installation lifecycle, we can use `CacheStorage` to pre-cache resources.
```javascript

const CACHE_NAMESPACE = 'githuber.js.dev-'
const PRECACHE = CACHE_NAMESPACE + 'precache'
const PRECACHE_LIST = [
  './',
  './static/js/bundle.js',
]
self.oninstall = (e) => {
  e.waitUntil(
    caches.open(PRECACHE)
    .then(cache => cache.addAll(PRECACHE_LIST))
  )
}

```
How do we do it? As shown in the code, PRECACHE is the name of a cache, and PRECACHE LIST is the list of static assets we want to cache.

Inside waitUntil, we use caches.open to open a new cache named PRECACHE. Then we use cache.addAll to add PRECACHE LIST to this cache.

You’ve probably noticed that both SW and Node deal with things like network IO and disk IO. So all related APIs are asynchronous, and they are designed in the more modern Promise style.

So, cache.addAll effectively means that the SW will independently send two requests, fetch the responses, and put them into the cache. The installation succeeds only if both of these requests succeed.


In Chrome’s Application - cache panel, we can see that the Responses for these requests have been cached.  

This represents a real “installation” capability, similar to what native applications provide.


One major pitfall to be aware of here: CacheStorage, like localStorage, is Origin Storage. So you need to watch out for naming conflicts. Different Web apps must never overwrite or delete each other’s caches.


We can define a custom offline page for environments with no network connection. When the network is unavailable, users can still see a page when they open the app.
```javascript

self.onfetch = (e) => {
  const fetched = fetch(e.request)
  // match offline.html in all cache opened in caches
  const sorry = caches.match("offline.html")

  // if the fetched reject, we return the sorry Response.
  e.respondWith(
    fetched.catch(_ => sorry)
  )
}

```
After the above transformation, the Web app follows the logic below:

![](https://img.halfrost.com/Blog/ArticleImage/53_68.png)

Loading a page first requests the network through Service Workers. If the network is unavailable, it loads the content from the cache, and finally renders the data on the page.

Of course, we can also change the above logic to cache-first:
```javascript

self.onfetch = (e) => {
  // Cuz we are a SPA using History API, 
  // we need "rewrite" navigation requests to root route.
  let url = rewriteUrl(e);
  // match url in all cache opened in caches
  const cached = caches.match(url) 

  e.respondWith(
    cached
      .then(resp => resp || fetch(url))
      .catch(_ => {/* eat any errors */})
  )
}


```
The logic then becomes what is shown in the figure below:

![](https://img.halfrost.com/Blog/ArticleImage/53_69.png)


Loading a page still goes through Service Workers first, but it prioritizes looking for data in the cache. If the cache does not contain it, it then requests the network, and the data returned by the network is rendered onto the page.


In this way, we have effectively implemented a PWA architecture pattern advocated by Google: the App Shell architecture, where dynamic data comes from network requests.

![](https://img.halfrost.com/Blog/ArticleImage/53_70.png)


The process above all depends on Service Workers, but what if the Service Worker “dies”? If the SW is effectively dead, that obviously does not work either. How would we ship new releases? The cache will not update itself.


### 4. An Evergreen Web App


Our web application already has installation capabilities comparable to a native app, but we can still achieve seamless releases and ensure the app remains evergreen.

![](https://img.halfrost.com/Blog/ArticleImage/53_71.png)

Let’s first review how the first SW gets registered. The SW is installed and activated. Only after the page is refreshed will all requests from that page go through the SW. So by default, the first SW only takes effect on the second load.


There are three pitfalls here.

The first pitfall is: Service Workers are loaded only on the second visit. By default, when the page performs fetches, they do not go through Service Workers.


You might wonder: after the SW is installed, will requests issued by the page be intercepted?

The answer is no. If the page itself did not go through the SW, none of the requests from that page will go through the SW either. This is to avoid potential races.

Of course, this behavior can also be overridden. In `onactivate`, we can claim all clients, i.e. clients in the typical C/S model, indicating that I now want to take over your requests immediately.


Here you can consider overriding the `clients.claim()` method.
```javascript

self.onactivate = (e) => {
  // Clients.claim() let SW control the page in the first load
  clients.claim()
}

```
Once a SW is already installed, the SW is actually requested again on every page refresh.
If the browser detects even a single byte of difference, it considers the SW to have been updated.
For example, we can define a version number and increment it every time we ship a release. That will cause the SW to run again and fetch those static assets again.

Of course, in production, we use build tools to help with this.


The second pitfall is: new Service Workers do not immediately replace the old ones until the old Service Workers are shut down.

In other words, the new SW does not immediately replace the old one.

Why? Think about it: when there is no SW, if we hash every resource and use long-term HTTP caching, the entry point for the dependency graph of the entire web application is the entry module chunk referenced by the HTML, such as webpack’s entry chunk. But once you introduce a SW, you’ll find that the SW acts as an entry point even earlier than this entry chunk, because the version of your entry chunk actually follows the SW’s cache.

So the SW effectively becomes the entry point for the resource versions of the entire web application. If your SW has a breaking change, the application can run into resource versioning issues.

Think about Chrome’s update mechanism: when a new version is available, it only takes effect after you restart Chrome.

![](https://img.halfrost.com/Blog/ArticleImage/53_72.png)


The diagram above illustrates this: new Service Workers remain in the Waiting state until the current page is closed. Only then can the Service Worker in the Waiting state become Active.

Interestingly, a single refresh is not enough to replace the SW, because during a refresh, the browser only removes the old browsing context after the new navigation has completed. During that period, the clients overlap, so the old SW is not discarded.
```javascript

self.oninstall = (e) => {
  e.waitUntil(
    caches.open(PRECACHE)
    .then(cache => cache.addAll(PRECACHE_LIST))
    .then(self.skipWaiting())
    .catch(err => console.log(err))
  )
}


```
Similarly, this behavior can be overridden with SkipWaiting. (This means your web app may be served from caches belonging to two different versions, which can potentially break things.) So SkipWaiting effectively means that the new SW is controlling a page from an older version. Doing this without a refresh is potentially unsafe unless you can guarantee that every SW is backward-compatible. However, SkipWaiting is very useful. As mentioned, one way to update an app is to close all tabs, and the app will be updated when reopened. This is a silent update, but it may lag behind our release.

Sometimes, though, we want users to get the new version immediately, without being one step behind. In that case, having the new SW call SkipWaiting and then refreshing once ensures that all resources come from the new SW’s cache and its corresponding logic.

So after `skipWaiting`, we can prompt the user to refresh.

But what if the user is doing something at that moment and doesn’t refresh?

Quick Update = skipWaiting() + Refresh, but what if it fails? There are two solutions.

#### Method 1: Force a refresh after skipWaiting()

Force a refresh on every release. This is well suited to scenarios such as games that gate users on major versions.
```javascript

// broadcasting clients to do window.location.reload() 
self.clients.matchAll().then(clients => {
  clients.forEach(client => {
    client.postMessage(REFRESH_MSG)
  })
})

// new API: client.navigate
self.clients.matchAll().then(clients => {
  clients.forEach(client => {
    client.navigate(REFRESH_URL)
  })
})


```

#### Method 2: Refresh Using PostMessage()

After user interaction, perform skipwaiting and refresh at the same time.
```javascript

// registration.waiting.postMessage()
self.onmessage = (e) => {
  switch (e.data.command) {
    case "SKIP_WAITING_AND_RELOAD_ALL_CLIENTS_TO_ROOT":
      self.skipWaiting()
        .then(_ => reloadAllClients("/"))
        .catch(err => console.log(err))
      break;
  }
}


```
Every SW update will inevitably re-request the URLs in our PRECACHE list, which brings us to one of the major pitfalls of SW: how it works with the HTTP Cache.

The third pitfall is the interaction between Service Workers and the HTTP Cache when caching is present.

Cache Storage is just another cache outside the HTTP Cache. So all requests issued from the SW still go through the HTTP Cache.

Imagine our bundle.js is configured with this cache-control. Then no matter how we update the SW and bundle.js, each update will still get the version from the HTTP Cache, resulting in an infinite loop.

Because each time we request new files, and Cache Storage—unlike the HTTP Cache—is persistent storage that the browser allocates to you as much as possible, what happens if the cache keeps growing without bound?


There is a simple solution here: add a version to the cache, and then, on every onactivate, clean up caches that do not belong to the current version.

You might wonder: what if two versions contain the same resources—isn’t that wasteful? Fortunately, in this case, the HTTP Cache can still provide a fallback.

However, the HTTP Cache is more likely to fail to persist for various reasons. So if our cleanup can be precise at the request level rather than the cache level, that would definitely be better.


Here I recommend SW-Precache, a useful library for Service Workers.
```javascript

// sw-precache-config.js

module.exports = { 
      staticFileGlobs: [ 
            'app/css/**.css', 
            'app/**.html', 
            'app/images/**.*', 
            'app/js/**.js' 
    ]
};

$ sw-precache --config=path/to/sw-precache-config.js

```
It is a node module. By specifying Glob patterns for static files, it can help you generate a highly reliable SW. At build time, it collects asset versions and performs incremental updates at file (request) granularity during installation and migration.

At the same time, it provides a webpack plugin: **[sw-precache-webpack-plugin](https://github.com/GoogleChrome/sw-precache)**

You can directly feed the manifest produced by the webpack build into this sw-precache library.

1. No cachebust required
2. navigateFallback

This can very effectively solve the issues we encountered before.
```javascript

// webpack.config.js
const SWPrecacheWebpackPlugin = require('sw-precache-webpack-plugin');
module.exports = {
  plugins: [
    new SWPrecacheWebpackPlugin({
      // assets already hashed by webpack aren't concerned to be stale
      dontCacheBustUrlsMatching: /\.\w{8}\./,  
      filename: 'service-worker.js',
      minify: true,
      navigateFallback: PUBLIC_PATH + 'index.html',
      staticFileGlobsIgnorePatterns: [/\.map$/, /asset-manifest\.json$/],
    }),
  ],
};

```

### 5. An Offline-1st Web App

Offline-first: being offline should not be considered an error state.


Here, Mr. Huang Xuan compares Ajax, RWD, and PWA.


![](https://img.halfrost.com/Blog/ArticleImage/53_73.png)


We can listen for certain events.
```javascript

// here, we hard-code the online/offline logics
// In production, we can expose callbacks to subscribers
function updateOnlineStatus(event) {
  if(navigator.onLine){
    document.body.classList.remove('app-offline')
  }else{
    document.body.classList.add('app-offline');
    createSnackbar({ message: "you are offline." })
  }
}

window.addEventListener('online',  updateOnlineStatus);
window.addEventListener('offline', updateOnlineStatus);


```
By listening for offline events, we can reflect the offline state in the UI.

So we can change the caching logic as follows:
```javascript

// sw.js
self.onfetch = (e) => {
  // ...
  if(url.includes('api.github.com')){
    e.respondWith(networkFirst(url));
    return;
  } 
  if(url.includes('githubusercontent.com')){
    e.respondWith(staleWhileRevalidate(url));
    return;
  }
  if(PRECACHE_ABS_LIST.includes(url)){
    e.respondWith(cacheOnly(url));
    return;
  }
  // default: Network Only
}


```
So the logic would then look like this:


![](https://img.halfrost.com/Blog/ArticleImage/53_74.png)


To make our web app more useful when offline, we can also do runtime caching.

For example, for entries in the PRECACHE list, we can safely respond with a cacheOnly strategy. For APIs, we can use a network-first strategy.


For static assets, especially images, we can use an approach called stale-while-revalidate.

A page still requests data through the Service Worker, but it first checks the cache; if there is a hit, it returns the data to the page for rendering. At the same time, the Service Worker also requests fresh data from the network, and the returned data is used to update the cache.

stale while revalidate itself is an HTTP proposal, but we can use SW to polyfill it.


![](https://img.halfrost.com/Blog/ArticleImage/53_75.png)


Of course, there is another strategy here: fastest. Since the request has already been sent, why not write it back to the cache?

Of course, you can also request both the cache and the network at the same time. But there is a problem here: if both return data at the same time, which one should be used?

This is where you run into a pitfall:

The runtime Cache also needs an eviction mechanism; it cannot grow indefinitely. This is a cache replacement problem.

One solution here is FIFO.
```javascript


// sw.js
function replaceRuntimeCache(MAX_ENTRIES){
  caches.open(RUNTIME)
    .then(cache => {
      cache.keys()
        .then(entries => {
          // FIFO queue
          if(entries.length > MAX_ENTRIES) {
            cache.delete(entries[0])
          } 
        })
    })
}

```
Here, Mr. Huang Xuan recommends another Service Worker library: SW-Toolbox.

It is designed for use inside SW and can be imported via importScript, which is available in workers. swtoolbox also provides Express-style routing. In addition, it implements an LRU eviction policy via indexedDB; all we need to provide is a maxEntries value. It will automatically track usage for us. Combined with a maximum expiration time, this effectively implements full TLRU.

It has five caching strategies:

- CacheOnly
- CacheFirst
- Fastest (Stale-while-Revalidate)
- NetworkOnly
- NetworkFirst

sw-precache can be used together with sw-toolbox:
```javascript

// sw-precache-config.js
module.exports = {
  // ...
  runtimeCaching: [{
    urlPattern: /this\\.is\\.a\\.regex/,
    handler: 'networkFirst'
  }]
};

// sw.js with sw-toolbox imported
toolbox.precache([
  "./index.a35bc762.js",
  "./style.5217a6fb.css"
])


```
Here is another library, Workbox, which covers the functionality of both sw-precache and sw-toolbox. It may be a solid, complete solution for Service Worker going forward.

![](https://img.halfrost.com/Blog/ArticleImage/53_76.png)


### 6. A Streaming Web App

Unlike native apps, which require installing a large package up front, don’t web apps feel like they stream into your phone? Combined with SW’s installation capabilities, it feels almost like streaming installation.


![](https://img.halfrost.com/Blog/ArticleImage/53_77.png)


Loading a page is still relatively slow; it needs to go through all of the steps above.


![](https://img.halfrost.com/Blog/ArticleImage/53_78.png)


Common web performance issues:

1. HTTP overhead
2. Deep dependency chains that prevent parallelization
3. JS startup overhead
4. Bundling everything into one large package


Here we can use the PRPL pattern to solve these problems.


![](https://img.halfrost.com/Blog/ArticleImage/53_79.png)


PRPL is a pattern for structuring and serving Progressive Web Apps (PWAs), with an emphasis on application delivery and startup performance. It stands for:


![](https://img.halfrost.com/Blog/ArticleImage/53_80.png)


- Push - Push critical resources for the initial URL route.
- Render - Render the initial route.
- Pre-cache - Pre-cache the remaining routes.
- Lazy-load - Lazy-load and instantiate the remaining routes on demand.


In addition to the basic goals and standards of PWAs, PRPL also strives to optimize for:

- Minimizing time to interactive as much as possible, especially on first use (regardless of entry point), and especially on real mobile devices
- Maximizing cache efficiency as much as possible, especially when shipping updates
- Simplicity of development and deployment

It provides a high-level abstraction for organizing and designing high-performance PWA systems.


![](https://img.halfrost.com/Blog/ArticleImage/53_81.png)


The diagram above uses the PRPL pattern plus route-based code splitting.

After optimization, let’s look at the loading time again.

![](https://img.halfrost.com/Blog/ArticleImage/53_82.png)


![](https://img.halfrost.com/Blog/ArticleImage/53_83.png)


The time has been reduced quite a bit.


### 7. A Progressive Web App

PWA aims to draw on the strengths of both Web and Native.

Three attractive characteristics. 


![](https://img.halfrost.com/Blog/ArticleImage/53_84.png)


- Reliable 

![](https://img.halfrost.com/Blog/ArticleImage/53_85.png)


- Fast 

![](https://img.halfrost.com/Blog/ArticleImage/53_86.png)


- Engaging

![](https://img.halfrost.com/Blog/ArticleImage/53_87.png)


PWAs can also run on desktop. Samsung Internet DeX, Chromebook, and Win10 have all started supporting desktop-class PWAs one after another.

### 8. A JavaScript Web App


We’ve reached the eighth stage. Web Apps at this stage all integrate JS frameworks.

Take the three most typical frameworks as examples: all of them support PWA.

![](https://img.halfrost.com/Blog/ArticleImage/53_88.png)


create-react-app、Preact CLI、vue init pwa。


![](https://img.halfrost.com/Blog/ArticleImage/53_89.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_90.png)

![](https://img.halfrost.com/Blog/ArticleImage/53_91.png)


### 9. Any Web App/Site

Many people ask: does a PWA have to be an SPA? Why is it called PWA instead of PWS?

![](https://img.halfrost.com/Blog/ArticleImage/53_92.png)


PWA is the web. It exists to tell developers, users, and our bosses: hey, many, many new technologies on the Web platform can be combined to do things you never imagined.

And we also have AR/VR, WebGL/ WebGPU, Web ASM, and so on. Are they all PWAs? No? They are the web. Are they all PWAs? Yes, they are too. PWA is the web.


### 10. The Web

The final stop, The Web, is the destination, and also the starting point.

> Anyone, at any time, can publish anything from anywhere
> Anyone, at any time, can publish anything from anywhere.

The Web is free. The so-called open spirit of the Web also lies in this: “Anyone, at any time, from anywhere, can publish any information on the World Wide Web and have it accessed by anyone in the world.” And this is the most revolutionary aspect of the web—arguably an evolution of us humans as a species.”

Yes, this is what the author of phonegap said.

>The leader behind PWA, Alex Russell, said
>"Progressive Web Apps: Escaping Tabs Without Losing Our Soul"
>@slightlylate


Let us, without losing our open soul and without relying on Hybrid to put applications into the App Store, break out of browser tabs and become, in the eyes of users, more powerful and more usable software applications. That is PWA.


![](https://img.halfrost.com/Blog/ArticleImage/53_93.png)


This is the Web.

This is the thing that brought those browser vendors, who used to argue with each other every day, back together to work on.” 


Mr. Huang Xuan elevated the theme beautifully at the end!


## Session 8: Speaker Panel Discussion


![](https://img.halfrost.com/Blog/ArticleImage/53_94.png)


Evan You was busy and did not come on the second day. I actually really wanted to hear his perspective.


## Reflections

After attending this conference, the two words I kept hearing were GraphQL and Go, and these were also the two technologies discussed most often in the group chat. Go had just entered the top ten of the programming language rankings in July, landing exactly at number ten. Google has also officially announced that it is preparing to release version 2.0. Go is indeed very hot recently. As for GraphQL, this technology has already been used for some time by large companies in the United States, and it is becoming increasingly popular. Looking back at China, there are still very few companies using this technology in production environments—at least, very few people at the venue raised their hands. Perhaps it will become popular in China in a few years.


What was rather disappointing this time was that no official Weex developers came to share anything. I have always wanted to talk face-to-face with the official Weex developers about the technology, but I have never had the opportunity. The Weex team has always kept a very low profile, and at this conference there were once again “rumors” that the Weex team might be disbanding soon. I believe these are just rumors.

The final speaker Q&A session belonged to Angular and React. Because Evan You was busy, he did not attend the final Q&A. As expected, the audience loved stirring things up, and the questions were all provocative! Questions included: How should we choose between Vue, Angular, and React? Front-end frameworks are changing with each passing day—how should we view the current state where front-end frameworks keep emerging and updating so rapidly? Where exactly is the future of front-end? For these questions, the speakers could only provide reference answers. How to put them into practice ultimately depends on each person’s own answer. As for choosing among the three major front-end frameworks, that depends on your company’s business scenarios. Regarding the rapid updates of front-end frameworks, the speaker’s answer was “let it go”—just go with it. Finally, regarding the future of front-end, the speakers discussed many things, including whether TypeScript and Flow might replace JavaScript, as well as WebAssembly, PWA, and so on. In short, no one can say for sure what the future of front-end will be; we still need to continue adapting to the times.

Attending this conference really broadened my horizons. I gained a lot, and this is about as much as I can share with everyone. The biggest takeaways for me were Evan You’s and Mr. Huang Xuan’s talks. As for the other speakers’ talks, because my front-end experience is still too shallow, I did not fully grasp their “essence.”

![](https://img.halfrost.com/Blog/ArticleImage/53_95.png)


<div style="position: relative; padding-bottom: 56.25%;padding-top: 25px;height: 0;">
<iframe width="1920" height="1080" src="http://player.youku.com/player.php/sid/XMjkwNzI1Mzg2MA==/v.swf" frameborder="0" allowfullscreen style="position: absolute;top: 0;left: 0;width: 100%;height: 100%;"></iframe>
</div>

(The above is a Youku video. If it shows up blank, please check whether your browser has blocked certain plugins.)

<div style="position: relative; padding-bottom: 56.25%;padding-top: 25px;height: 0;">
<iframe width="1920" height="1080" src="https://www.youtube.com/embed/E6rVjWZy13s?ecver=1" frameborder="0" allowfullscreen style="position: absolute;top: 0;left: 0;width: 100%;height: 100%;"></iframe>
</div>

(The above is a YouTube video. If it shows up blank, please check whether you have proper access to the internet.)

[Official behind-the-scenes video for JSConf China 2017](http://v.youku.com/v_show/id_XMjkwNzI1Mzg2MA==.html?spm=a2h0k.8191407.0.0&from=s1.8-1-1.2)(JSConf China 2017 official HD video. I saw the drone when I checked in on the first day, and it turned out they really edited me into the video: at 39 and 40 seconds, that is my close-up. At 50 seconds, in the middle of the seventh row, wearing a pink T-shirt, with the Mac screen glowing on my lap—that is also me, the author.)


Finally, here is the [JSConf China official website](http://2017.jsconf.cn/), which has some PPT decks whose copyrights allow public release. You can download them and study them.


JSConf China 2017 has wrapped up perfectly!


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/jsconf\_china\_2017\_final/](https://halfrost.com/jsconf_china_2017_final/)

