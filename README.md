Official Bugsnag Notifier for iOS
=====================================

The Bugsnag Notifier for iOS is designed to give you
instant notification of exceptions thrown from your iOS applications. 
The notifier hooks into `NSSetUncaughtExceptionHandler`, which means any 
uncaught exceptions will trigger a notification to be sent to your Bugsnag
project. Bugsnag will also monitor for fatal signals sent to your application,
for example a Segmentation Fault.


What is Bugsnag?
----------------

[Bugsnag](http://bugsnag.com) captures errors in real-time from your web, 
mobile and desktop applications, helping you to understand and resolve them 
as fast as possible. [Create a free account](http://bugsnag.com).


Features
--------

-   Automatic notification of uncaught exceptions
-   Exceptions buffered to disk when no internet connection is available, and 
    sent later
-   Minimal cpu and memory footprint
-   Send your own [non-fatal exceptions](#send-non-fatal-exceptions-to-bugsnag)
    to Bugsnag
-   Track which View Controllers were open at the time of the exception
-   Send additional meta-data along with your exceptions using 
    [`extraData`](#extradata)
-   Filter sensitive data before sending exceptions with
    [`filters`](#filters)


Installation & Setup
--------------------

Include Bugsnag.h and Bugsnag.m in your Xcode project.

Import the `Bugsnag.h` file into your application delegate.

```objective-c
#import "Bugsnag.h"
```

In your application:didFinishLaunchingWithOptions: method, register with bugsnag by calling,

```objective-c
[Bugsnag startBugsnagWithApiKey:@"your-api-key-goes-here"];
```

###JSON Library

The Bugsnag iOS notifier requires a JSON library in order to function. It is able to use
the library included in iOS 5 if running on an iOS 5 device. Otherwise it looks for any of the
following libraries:

- [JSONKit](https://github.com/johnezang/JSONKit)
- [NextiveJson](https://github.com/nextive/NextiveJson)
- [SBJson](https://stig.github.com/json-framework/)
- [YAJL](https://lloyd.github.com/yajl/)

If none of these libraries are present, the iOS notifier will be unable to notify Bugsnag of
an error.


Send Non-Fatal Exceptions to Bugsnag
------------------------------------

If you would like to send non-fatal exceptions to Bugsnag, you can pass any
`NSException` to the `notify` method:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]];
```

You can also send additional meta-data with your exception:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]
       withData:[NSDictionary dictionaryWithObjectsAndKeys:@"username", @"bob-hoskins", nil]];
```


Configuration
-------------

###context

Bugsnag uses the concept of "contexts" to help display and group your
errors. Contexts represent what was happening in your application at the
time an error occurs. The iOS Notifier will set this to be the top most
UIViewController, but if in a certain case you need
to override the context, you can do so using this property:

```objective-c
[Bugsnag instance].context = @"MyUIViewController";
```

###userId

Bugsnag helps you understand how many of your users are affected by each
error. In order to do this, we send along a userId with every exception. 
By default we will generate a unique ID and send this ID along with every 
exception from an individual device.
    
If you would like to override this `userId`, for example to set it to be a
username of your currently logged in user, you can set the `userId` property:

```objective-c
[Bugsnag instance].setUserId = @"leeroy-jenkins";
```

###releaseStage

In order to distinguish between errors that occur in different stages of
the application release process a release stage is sent to Bugsnag when 
an error occurs. This is automatically configured by the iOS notifier to be
"production", unless DEBUG is defined during compilation. In this case it
will be set to "development". If you wish to override this, you can do so
by setting the releaseStage property manually:

```objective-c
[Bugsnag instance].releaseStage = @"development";
```

###notifyReleaseStages

By default, we will only notify Bugsnag of exceptions that happen when 
your `releaseStage` is set to be "production". If you would like to 
change which release stages notify Bugsnag of exceptions you can
set the `notifyReleaseStages` property:
    
```objective-c
[Bugsnag instance].notifyReleaseStages = [NSArray arrayWithObjects:@"development", @"production", nil];
```

###autoNotify

By default, we will automatically notify Bugsnag of any fatal exceptions
in your application. If you want to stop this from happening, you can set
`autoNotify` to NO:
    
```objective-c
[Bugsnag instance].autoNotify = NO;
```

###extraData

It if often very useful to send some extra application or user specific 
data along with every exception. To do this, you can set the
`extraData` property:
    
```objective-c
[Bugsnag instance].extraData = [NSDictionary dictionaryWithObjectsAndKeys:@"bob-hoskins", @"username", nil];
```

###dataFilters

Sets the strings to filter out from the `extraData` dictionary before sending
them to Bugsnag. Use this if you want to ensure you don't send 
sensitive data such as passwords, and credit card numbers to our 
servers. Any keys which contain these strings will be filtered.

```objective-c
[Bugsnag instance].dataFilters = [NSArray arrayWithObjects:@"password",@"credit-card-number",nil];
```

By default, `dataFilters` is set to `[NSArray arrayWithObject:@"password"]`

###enableSSL

Enables the use of SSL encryption when sending errors to Bugsnag. Enable this if you require the
extra security

```objective-c
[Bugsnag instance].enableSSL = NO;
```

By default, `enableSSL` is set to `NO`.


Reporting Bugs or Feature Requests
----------------------------------

Please report any bugs or feature requests on the github issues page for this
project here:

<https://github.com/bugsnag/bugsnag-ios/issues>


Contributing
------------
 
-   Check out the latest master to make sure the feature hasn't been 
    implemented or the bug hasn't been fixed yet
-   Check out the issue tracker to make sure someone already hasn't requested
    it and/or contributed it
-   Fork the project
-   Start a feature/bugfix branch
-   Commit and push until you are happy with your contribution
-   Thanks!


License
-------

The Bugsnag ios notifier is released under the 
MIT License. Read the full license here:

<https://github.com/bugsnag/bugsnag-ios/blob/master/LICENSE>