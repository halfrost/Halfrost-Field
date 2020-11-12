---
title: VueのNavigation Guards
date: 2019-01-25 09:00:00
tags:
    - JavaScript
    - Vue.js
category: tech
keywords:
    - Vue.js
    - Javascript
    - ES2015
    - ES6
---

Navigation guards are provided by `vue-router`.
Three ways to hook:
* globally
* per-route
* in-component

__NOTE:__ 
1. Params or query changes won't trigger enter/leave navigation guards. You can either watch the `$route` object to react to those changes, or use the `beforeRouteUpdate` in-component guard.
2. Make sure to always call the next function, otherwise the hook will never be resolved.

## Global

```Javascript
const router = new VueRouter({ ... })

// Before Guards
router.beforeEach((to, from, next) => {
  // ...
})

// Resolve Guards
// beforeResolve guards will be called right before the navigation is confirmed
// after all in-component guards and async route components are resolved
router.beforeResolve((to, from, next) => {
  // ...
})

// After Hooks
router.afterEach((to, from) => {
  // ...
})
```

## Pre-reoute

```Javascript
const router = new VueRouter({
  routes: [
    {
      path: '/foo',
      component: Foo,
      beforeEnter: (to, from, next) => {
        // ...
      }
    }
  ]
})
```

## In-component

```Javascript
const Foo = {
  template: `...`,
  beforeRouteEnter (to, from, next) {
    // called before the route that renders this component is confirmed.
    // does NOT have access to `this` component instance,
    // because it has not been created yet when this guard is called!
    // However, you can access the instance by passing a callback to next. 
    // The callback will be called when the navigation is confirmed
    // and the component instance will be passed to the callback as the argument
    beforeRouteEnter (to, from, next) {
      next(vm => {
        // access to component instance via `vm`
      })
    }
  },
  beforeRouteUpdate (to, from, next) {
    // called when the route that renders this component has changed,
    // but this component is reused in the new route.
    // For example, for a route with dynamic params `/foo/:id`, when we
    // navigate between `/foo/1` and `/foo/2`, the same `Foo` component instance
    // will be reused, and this hook will be called when that happens.
    // has access to `this` component instance.
  },
  beforeRouteLeave (to, from, next) {
    // called when the route that renders this component is about to
    // be navigated away from.
    // has access to `this` component instance.
  }
}
```

## Resolve flow

+ Navigation triggered.
+ Call leave guards in deactivated components.
+ Call global beforeEach guards.
+ Call beforeRouteUpdate guards in reused components.
+ Call beforeEnter in route configs.
+ Resolve async route components.
+ Call beforeRouteEnter in activated components.
+ Call global beforeResolve guards.
+ Navigation confirmed.
+ Call global afterEach hooks.
+ DOM updates triggered.
+ Call callbacks passed to next in beforeRouteEnter guards with instantiated instances.
