<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-65440c02af82bd8d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 

#### Preface

A Hybrid App is an app that sits between a web app and a native app, combining the advantages of a Native App’s strong user interaction experience with the cross-platform development benefits of a Web App.

Based on how web languages and programming languages are combined, Hybrid Apps are typically divided into three types: multi-View hybrid, single-View hybrid, and Web-centric. The three types are compared below:


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-101b71b37fb36dad.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


Today I’ll talk about PhoneGap, one of the better-known Hybrid frameworks in the Web-centric category.


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-8578bb25ee8b09b3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


#### 1. Cordova
When talking about PhoneGap, Cordova inevitably comes up.

Cordova is a library that enables JS and native code—including Android’s Java, iOS’s Objective-C, and so on—to communicate with each other. It also provides a series of plugin classes, such as plugins that allow JS to operate directly on a local database.

Cordova’s design concept is to present Web pages through Web controls inside an app, allowing Web developers to build apps using the languages and tools they are familiar with.  


To enable Web pages to satisfy more app functionality requirements, Cordova provides a Plugin mechanism, allowing Web pages to attach and invoke functional modules developed with Native technologies.

Cordova’s layer in the system should look like this:


<p align="center"> 
<img src="http://upload-images.jianshu.io/upload_images/1194012-22b52111118a47b6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240">
</p> 


  

#### 2. Communication Between JS and Objective-C
JS uses two approaches to communicate with Objective-C. One is to initiate requests using XMLHttpRequest; the other is to set the src attribute of a transparent iframe.

What I’ll discuss next is mainly the second approach: the iframe bridge.
By creating a transparent iframe on the JS side and setting the src of this ifame to a custom protocol, when the ifame’s src changes, UIWebView first calls back its delegate’s webView:shouldStartLoadWithRequest:navigationType: method.

That still sounds quite abstract, so let’s look at an actual code snippet.

In cordova.js, it is implemented like this:
```javascript

function iOSExec() {
    ...
    if (!isInContextOfEvalJs && commandQueue.length == 1)  {
        // If XMLHttpRequest is supported, use the XMLHttpRequest approach
        if (bridgeMode != jsToNativeModes.IFRAME_NAV) {
            // This prevents sending an XHR when there is already one being sent.
            // This should happen only in rare circumstances (refer to unit tests).
            if (execXhr && execXhr.readyState != 4) {
                execXhr = null;
            }
            // Re-using the XHR improves exec() performance by about 10%.
            execXhr = execXhr || new XMLHttpRequest();
            // Changing this to a GET will make the XHR reach the URIProtocol on 4.2.
            // For some reason it still doesn't work though...
            // Add a timestamp to the query param to prevent caching.
            execXhr.open('HEAD', "/!gap_exec?" + (+new Date()), true);
            if (!vcHeaderValue) {
                vcHeaderValue = /.*\((.*)\)/.exec(navigator.userAgent)[1];
            }
            execXhr.setRequestHeader('vc', vcHeaderValue);
            execXhr.setRequestHeader('rc', ++requestCount);
            if (shouldBundleCommandJson()) {
                // Set the request data
                execXhr.setRequestHeader('cmds', iOSExec.nativeFetchMessages());
            }
            // Send the request
            execXhr.send(null);
        } else {
            // If XMLHttpRequest is not supported, use a transparent iframe and set the iframe's src attribute
            execIframe = execIframe || createExecIframe();
            execIframe.src = "gap://ready";
        }
    }
    ...
}
```
On iOS, you need to implement the corresponding handler method in the WebView.
```objectivec

// Callback method before UIWebView loads a URL; return YES to start loading this URL, return NO to ignore it
- (BOOL)webView:(UIWebView*)theWebView
              shouldStartLoadWithRequest:(NSURLRequest*)request
              navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL* url = [request URL];
    
    /*
     * Execute any commands queued with cordova.exec() on the JS side.
     * The part of the URL after gap:// is irrelevant.
     */
    // Determine whether it is a Cordova request, for the line execIframe.src = "gap://ready" in the JS code
    if ([[url scheme] isEqualToString:@"gap"]) {
        // Get the request data, then analyze and process it
        [_commandQueue fetchCommandsFromJs];
        return NO;
    }
    ...
}

```
This completes the communication between JS and OC.

#### 3. Communication Between Objective-C and JS

First, OC retrieves the request data from JS.
```objectivec

- (void)fetchCommandsFromJs
{
    // Grab all the queued commands from the JS side.
    NSString* queuedCommandsJSON = [_viewController.webView
                                    stringByEvaluatingJavaScriptFromString:
                                    @"cordova.require('cordova/exec').nativeFetchMessages()"];
    
    [self enqueCommandBatch:queuedCommandsJSON];
    if ([queuedCommandsJSON length] > 0) {
        CDV_EXEC_LOG(@"Exec: Retrieved new exec messages by request.");
    }
}
```
Then OC handles the request passed from JS

OC then returns the processing result to JS
```objectivec

NSString *ret = [((HFNativeFunction*)strongSelf.actionDict[funcName]) doCall:argArr];
        NSString *js = [NSString stringWithFormat:@"if(typeof %@ == 'string') { paf.nativeInvocationObject=%@;} else {   paf.nativeInvocationObject=JSON.stringify(%@);} ", ret, ret, ret];
        DLog(@"\n\njs call fun=%@ ret=%@\n\n", funcName, ret);
        [self.webView stringByEvaluatingJavaScriptFromString: js];
```

#### IV. Cordova - How JS Works

Format of a Cordova JS-side request method:  

> // successCallback : success callback method  
> // failCallback    : failure callback method  
> // server          : name of the service to request  
> // action          : specific operation of the service to request  
> // actionArgs      : parameters carried by the requested operation  

cordova.exec(successCallback, failCallback, service, action, actionArgs);

These five parameters are not passed directly to the native code. The Cordova JS side performs the following processing:

 
1. A unique identifier called callbackId is generated for each request: this parameter needs to be passed to the Objective-C side. After Objective-C finishes processing, it returns the callbackId together with the processing result to the JS side. 

2. Using callbackId as the key and {success:successCallback, fail:failCallback} as the value, this key-value pair is stored in a dictionary on the JS side. The two parameters successCallback and failCallback do not need to be passed to the Objective-C side. When Objective-C returns the result with the callbackId, the JS side can use the callbackId to find the callback method.

3. For each JS request, the data ultimately sent to Objective-C includes: callbackId, service, action, actionArgs.

JS request handling
```javascript

function iOSExec() {
    ...
    // Generate a unique callbackId identifier, and store it with the success and failure callbacks on the JS side
    // Register the callbacks and add the callbackId to the positional
    // arguments if given.
    if (successCallback || failCallback) {
        callbackId = service + cordova.callbackId++;
        cordova.callbacks[callbackId] =
        {success:successCallback, fail:failCallback};
    }
    
    actionArgs = massageArgsJsToNative(actionArgs);
    
    // Store callbackId, service, action, and actionArgs in commandQueue
    // These four parameters are the data ultimately sent to native code
    var command = [callbackId, service, action, actionArgs];
    commandQueue.push(JSON.stringify(command));
    ...
}

// Get the request data, including callbackId, service, action, actionArgs
iOSExec.nativeFetchMessages = function() {
    // Each entry in commandQueue is a JSON string already.
    if (!commandQueue.length) {
        return '';
    }
    var json = '[' + commandQueue.join(',') + ']';
    commandQueue.length = 0;
    return json;
};
```

#### V. Cordova - How OC Works

After the Native OC side obtains `callbackId`, `service`, `action`, and `actionArgs`, it performs the following processing:


1. Finds the corresponding plugin class based on the `service` parameter

2. Finds the corresponding handler method in the plugin class based on the `action` parameter, and passes `actionArgs` to the handler method as part of the request parameters

3. After processing is complete, returns the result and `callbackId` to the JS side. After receiving them, the JS side finds the callback method based on `callbackId` and passes the result to that callback method

 Objective-C returning results to the JS side
   
 
```objectivec

- (void)sendPluginResult:(CDVPluginResult*)result callbackId:(NSString*)callbackId
{
    CDV_EXEC_LOG(@"Exec(%@): Sending result. Status=%@", callbackId, result.status);
    // This occurs when there is are no win/fail callbacks for the call.
    if ([@"INVALID" isEqualToString : callbackId]) {
        return;
    }
    int status = [result.status intValue];
    BOOL keepCallback = [result.keepCallback boolValue];
    NSString* argumentsAsJSON = [result argumentsAsJSON];
    
    // Return the request processing result and callbackId to the JS side by calling a JS method
    NSString* js = [NSString stringWithFormat:
                    @"cordova.require('cordova/exec').nativeCallback('%@',%d,%@,%d)",
                    callbackId, status, argumentsAsJSON, keepCallback];
    
    [self evalJsHelper:js];
}
```
A concrete example:

1. Convert the received JSON into a Command
```objectivec

// Execute the commands one-at-a-time.
     NSArray* jsonEntry = [commandBatch dequeue];
     if ([commandBatch count] == 0) {
                  [_queue removeObjectAtIndex:0];
      }
     HFCDVInvokedUrlCommand* command = [HFCDVInvokedUrlCommand commandFromJson:jsonEntry];
     HF_CDV_EXEC_LOG(@"Exec(%@): Calling %@.%@", command.callbackId, command.className, command.methodName);
```
2. OC Execution
```objectivec

- (BOOL)execute:(HFCDVInvokedUrlCommand*)command
{
    if ((command.className == nil) || (command.methodName == nil)) {
        DLog(@"ERROR: Classname and/or methodName not found for command.");
        return NO;
    }
    
    if ([command.className isEqualToString:@"DeviceReadyDummyClass"] &&
        [command.methodName isEqualToString:@"deviceReady"]) {
        [[NSNotificationCenter defaultCenter]postNotificationName:k_NOTIF_DEVICE_READY object:_viewController];
        return YES;
    }

    // Fetch an instance of this class
    HFCDVPlugin* obj = [_viewController.commandDelegate getCommandInstance:command.className];

    if (!([obj isKindOfClass:[HFCDVPlugin class]])) {
        DLog(@"ERROR: Plugin '%@' not found, or is not a HFCDVPlugin. Check your plugin mapping in config.xml.", command.className);
        return NO;
    }
    BOOL retVal = YES;
    double started = [[NSDate date] timeIntervalSince1970] * 1000.0;
    // Find the proper selector to call.
    NSString* methodName = [NSString stringWithFormat:@"%@:", command.methodName];
    SEL normalSelector = NSSelectorFromString(methodName);
    if ([obj respondsToSelector:normalSelector]) {
        // [obj performSelector:normalSelector withObject:command];
        ((void (*)(id, SEL, id))objc_msgSend)(obj, normalSelector, command);
    } else {
        // There's no method to call, so throw an error.
        DLog(@"ERROR: Method '%@' not defined in Plugin '%@'", methodName, command.className);
        retVal = NO;
    }
    double elapsed = [[NSDate date] timeIntervalSince1970] * 1000.0 - started;
    if (elapsed > 10) {
        DLog(@"THREAD WARNING: ['%@'] took '%f' ms. Plugin should use a background thread.", command.className, elapsed);
    }
    return retVal;
}

```

#### 6. Callback Method

The JS side receives the data and invokes the callback based on callbackId.
```javascript

// Find the callback method by callbackId and success flag, then pass the result to it
callbackFromNative: function(callbackId, success, status, args, keepCallback) {
    var callback = cordova.callbacks[callbackId];
    if (callback) {
        if (success && status == cordova.callbackStatus.OK) {
            callback.success && callback.success.apply(null, args);
        } else if (!success) {
            callback.fail && callback.fail.apply(null, args);
        }
        
        // Clear callback if not expecting any more results
        if (!keepCallback) {
            delete cordova.callbacks[callbackId];
        }
    }
}
```


> GitHub Repo：[Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/ios\_hybrid\_phonegap/](https://halfrost.com/ios_hybrid_phonegap/)

