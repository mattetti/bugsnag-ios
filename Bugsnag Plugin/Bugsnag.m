#import <execinfo.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/sysctl.h>

#import <Foundation/Foundation.h>
#import <mach/mach.h>

#import "Bugsnag.h"

@interface Bugsnag ()
- (id) initWithAPIKey:(NSString*)apiKey;
- (void)sendCachedReports;
- (void)saveErrorWithClass:(NSString*)errorClass andMessage:(NSString*) errorMessage andStackTrace:(NSArray*) rawStacktrace;
+ (NSArray*) getCallStackFromFrames:(void*)frames andCount:(int)count startingAt:(int)start;
+ (NSString*) getJSONRepresentation:(NSDictionary*)dict;
- (UIViewController *)getVisibleViewController;
- (BOOL) shouldAutoNotify;

@property (readonly) NSString *errorPath;
@property (readonly) NSString *errorFilename;
@property (readonly) NSString *osVersion;
@property (readonly) NSString *platform;
@property (readonly) NSArray *outstandingReports;
@property (nonatomic, retain) NSMutableData *data;
@end

@interface NSNumber (FileSizes)
- (NSString *)fileSize;
@end

@implementation NSNumber (FileSizes)

- (NSString *)fileSize {
    float fileSize = [self floatValue];
    if (fileSize<1023.0f)
        return([NSString stringWithFormat:@"%i bytes",[self intValue]]);
    fileSize = fileSize / 1024.0f;
    if ([self intValue]<1023.0f)
        return([NSString stringWithFormat:@"%1.1f KB",fileSize]);
    fileSize = fileSize / 1024.0f;
    if (fileSize<1023.0f)
        return([NSString stringWithFormat:@"%1.1f MB",fileSize]);
    fileSize = fileSize / 1024.0f;
    
    return([NSString stringWithFormat:@"%1.1f GB",fileSize]);
}

@end

static Bugsnag *sharedBugsnagNotifier = nil;

int signals_count = 6;
int signals[] = {
	SIGABRT,
	SIGBUS,
	SIGFPE,
	SIGILL,
	SIGSEGV,
    EXC_BAD_ACCESS,
};

void remove_handlers(void);
void handle_signal(int);
void handle_exception(NSException *);

void remove_handlers() {
    for (NSUInteger i = 0; i < signals_count; i++) {
        int signalType = signals[i];
        signal(signalType, NULL);
    }
    NSSetUncaughtExceptionHandler(NULL);
}

// Handles a raised signal
void handle_signal(int signalReceived) {
    if (sharedBugsnagNotifier && [sharedBugsnagNotifier shouldAutoNotify]) {
        remove_handlers();
        
        // We limit to 128 lines of trace information for signals atm
        int count = 128;
		void *frames[count];
		count = backtrace(frames, count);

        [sharedBugsnagNotifier saveErrorWithClass:[NSString stringWithCString:strsignal(signalReceived) encoding:NSUTF8StringEncoding] 
                                       andMessage:@"" 
                                    andStackTrace:[Bugsnag getCallStackFromFrames:frames andCount:count startingAt:1]];
    }
    //Propagate the signal back up to take the app down
    raise(signalReceived);
}

// Handles an uncaught exception
void handle_exception(NSException *exception) {
    if (sharedBugsnagNotifier && [sharedBugsnagNotifier shouldAutoNotify]) {
        remove_handlers();
        
        NSUInteger frameCount = [[exception callStackReturnAddresses] count];
        void *frames[frameCount];
        for (NSInteger i = 0; i < frameCount; i++) {
            frames[i] = (void *)[[[exception callStackReturnAddresses] objectAtIndex:i] unsignedIntegerValue];
        }
        
        [sharedBugsnagNotifier saveErrorWithClass:[exception name] 
                                       andMessage:[exception reason] 
                                    andStackTrace:[Bugsnag getCallStackFromFrames:frames andCount:frameCount startingAt:0]];
    }
}

@implementation Bugsnag

@synthesize releaseStage;
@synthesize data;
@synthesize apiKey;
@synthesize enableSSL;
@synthesize autoNotify;
@synthesize extraData;
@synthesize dataFilters;
@synthesize notifyReleaseStages;

#ifdef DEBUG
#   define BugLog(__FORMAT__, ...) NSLog(__FORMAT__, ##__VA_ARGS__)
#else
#   define BugLog(...) do {} while (0)
#endif

#define BUGSNAG_IOS_VERSION @"1.0.0"
#define BUGSNAG_IOS_HOMEPAGE @"https://github.com/bugsnag/bugsnag-ios"

// The start function. Entry point that should be called early on in application load
+ (void) startBugsnagWithApiKey:(NSString*)apiKey {
    if (!sharedBugsnagNotifier) {
		if (!apiKey || ![apiKey length]) {
            BugLog(@"APIKey cannot be empty");
            return;
		}
        
        sharedBugsnagNotifier = [[Bugsnag alloc] initWithAPIKey:apiKey];
		
        if (!sharedBugsnagNotifier) {
            BugLog(@"Unable to alloc the notifier.");
            return;
        }
        
        NSSetUncaughtExceptionHandler(&handle_exception);
        
        for (NSUInteger i = 0; i < signals_count; i++) {
            int signalType = signals[i];
            if (signal(signalType, handle_signal) != 0) {
                BugLog(@"Unable to register signal handler for %s", strsignal(signalType));
            }
        }
        
        [sharedBugsnagNotifier sendCachedReports];
	}
}

+ (Bugsnag *)instance {
    return sharedBugsnagNotifier;
}

#pragma mark - Instance Methods
- (id) initWithAPIKey:(NSString*)passedApiKey {
    if ((self = [super init])) {
        self.apiKey = passedApiKey;
        _appVersion = nil;
        _errorPath = nil;
        _userId = nil;
        _outstandingReports = nil;
        self.enableSSL = NO;
        self.autoNotify = YES;
        [self.notifyReleaseStages = [[NSArray alloc] initWithObjects:@"production", nil] release];
        [self.dataFilters = [[NSArray alloc] initWithObjects:@"password", nil] release];
        
#ifdef DEBUG
        self.releaseStage = @"development";
#else
        self.releaseStage = @"production";
#endif
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (BOOL) shouldAutoNotify {
    return self.autoNotify && [self.notifyReleaseStages containsObject:self.releaseStage];
}

-(NSString*) platform {
    size_t size = 256;
	char *machineCString = malloc(size);
    sysctlbyname("hw.machine", machineCString, &size, NULL, 0);
    NSString *machine = [NSString stringWithCString:machineCString encoding:NSUTF8StringEncoding];
    free(machineCString);
    
    if ([machine isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([machine isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([machine isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([machine isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([machine isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([machine isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([machine isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([machine isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([machine isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([machine isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([machine isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([machine isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([machine isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([machine isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([machine isEqualToString:@"iPad2,4"])      return @"iPad 2";
    if ([machine isEqualToString:@"iPad3,1"])      return @"iPad-3G (WiFi)";
    if ([machine isEqualToString:@"iPad3,2"])      return @"iPad-3G (4G)";
    if ([machine isEqualToString:@"iPad3,3"])      return @"iPad-3G (4G)";
    if ([machine isEqualToString:@"i386"])         return @"Simulator";
    if ([machine isEqualToString:@"x86_64"])       return @"Simulator";
    
    return machine;
}

- (NSString*) appVersion {
    if(_appVersion) return [[_appVersion copy] autorelease];
    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	if (bundleVersion != nil && versionString != nil && ![bundleVersion isEqualToString:versionString]) {
        _appVersion = [NSString stringWithFormat:@"%@ (%@)", versionString, bundleVersion];
    } else if (bundleVersion != nil) {
        _appVersion = bundleVersion;
    } else if(versionString != nil) {
        _appVersion = versionString;
    }
	return [[_appVersion copy] autorelease];
}

- (void) setAppVersion:(NSString*)version {
    if (_appVersion) [_appVersion release];
    _appVersion = [version copy];
}

- (NSString*) userId {
    if(_userId) return [[_userId copy] autorelease];
    
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if([folders count]) {
        NSString *filename = [[folders objectAtIndex:0] stringByAppendingPathComponent:@"bugsnag-user-id"];

        _userId = [NSString stringWithContentsOfFile:filename encoding:NSStringEncodingConversionExternalRepresentation error:nil];
        if(_userId) {
            return [[_userId copy] autorelease];
        } else {
            CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
            _userId = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
            CFRelease(uuid);
            
            [_userId writeToFile:filename atomically:YES encoding:NSStringEncodingConversionExternalRepresentation error:nil];
            return [[_userId copy] autorelease];
        }
    } else {
        _userId = [[NSUserDefaults standardUserDefaults] stringForKey:@"bugsnag-user-id"];
        if(_userId) {
            return [[_userId copy] autorelease];
        } else {
            CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
            _userId = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
            CFRelease(uuid);
            [[NSUserDefaults standardUserDefaults] setValue:_userId forKey:@"bugsnag-user-id"];
            return [[_userId copy] autorelease];
        }
    }
}

- (void) setUserId:(NSString *)userId {
    if(_userId) [_userId release];
    _userId = [userId copy];
}

- (NSString*) context {
    if(_context) return [[_context copy] autorelease];
    return NSStringFromClass([[self getVisibleViewController] class]);
}

- (void) setContext:(NSString *)context {
    if(_context) [_context release];
    _context = [_context copy];
}

- (NSString *) osVersion {
#if TARGET_IPHONE_SIMULATOR
	return [[UIDevice currentDevice] systemVersion];
#else
	return [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
}

- (NSString*) errorPath{
    if(_errorPath) return _errorPath;
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *filename = [folders count] == 0 ? NSTemporaryDirectory() : [folders objectAtIndex:0];
    _errorPath = [[filename stringByAppendingPathComponent:@"bugsnag"] retain];
    return _errorPath;
}

- (NSString *) errorFilename {
    return [[self.errorPath stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] stringByAppendingPathExtension:@"bugsnag"];
}

- (UIViewController *)getVisibleViewController {
    UIViewController *viewController = nil;
    UIViewController *visibleViewController = nil;
    
    if ([[[UIApplication sharedApplication] keyWindow].rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *) [[UIApplication sharedApplication] keyWindow].rootViewController;
        viewController = navigationController.visibleViewController;
    }
    else {
        viewController = [[UIApplication sharedApplication] keyWindow].rootViewController;
    }
    
    while (visibleViewController == nil) {
        
        if (viewController.modalViewController == nil) {
            visibleViewController = viewController;  
        } else {
            
            if ([viewController.modalViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navigationController = (UINavigationController *)viewController.modalViewController;
                viewController = navigationController.visibleViewController;
            } else {
                viewController = viewController.modalViewController;
            }
        }
        
    }
    
    return visibleViewController;
}

- (NSArray *) outstandingReports {
    if(_outstandingReports) return _outstandingReports;
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.errorPath error:nil];
	_outstandingReports = [[NSMutableArray arrayWithCapacity:[directoryContents count]] retain];
	for (NSString *file in directoryContents) {
		if ([[file pathExtension] isEqualToString:@"bugsnag"]) {
			NSString *crashPath = [self.errorPath stringByAppendingPathComponent:file];
			[_outstandingReports addObject:crashPath];
		}
	}
	return _outstandingReports;
}

- (NSDictionary*) getNotifyPayload {
    NSDictionary *notifier = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: @"iOS Bugsnag Notifier", BUGSNAG_IOS_VERSION, BUGSNAG_IOS_HOMEPAGE, nil] 
                                                           forKeys:[NSArray arrayWithObjects: @"name", @"version", @"url", nil]];
    NSMutableArray *events = [[NSMutableArray alloc] init];
    NSDictionary *notifierPayload = [[[NSDictionary alloc] initWithObjectsAndKeys:notifier, @"notifier", self.apiKey, @"apiKey", events, @"events", nil] autorelease];
    
    [notifier release];
    [events release];
    return notifierPayload;
}

- (void)applicationDidBecomeActive:(NSNotification *)notif {
    [self sendCachedReports];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)passedData {
    [self.data appendData:passedData];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    int statusCode = [((NSHTTPURLResponse *)response) statusCode];
    if (statusCode != 200) {
        [connection cancel];
        BugLog(@"Bad response from bugnsag received: %d.", statusCode);
        self.data = nil;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [[NSFileManager defaultManager] removeItemAtPath:self.errorPath error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.data = nil;
}

+ (NSArray*) getCallStackFromFrames:(void*)frames andCount:(int)count startingAt:(int)start {
	char **strs = backtrace_symbols(frames, count);
	NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:count];
	for (NSInteger i = start; i < count; i++) {
		NSString *entry = [NSString stringWithUTF8String:strs[i]];
		[backtrace addObject:entry];
	}
	free(strs);
	return backtrace;
}

- (void) saveErrorWithClass:(NSString*)errorClass andMessage:(NSString*) errorMessage andStackTrace:(NSArray*) rawStacktrace {
    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
    
    [event setObject:self.userId forKey:@"userId"];
    [event setObject:self.appVersion forKey:@"appVersion"];
    [event setObject:self.osVersion forKey:@"osVersion"];
    [event setObject:self.releaseStage forKey:@"releaseStage"];
    [event setObject:self.context forKey:@"context"];
    
    NSMutableDictionary *exception = [[NSMutableDictionary alloc] init];
    NSArray *exceptions = [[NSArray alloc] initWithObjects:exception, nil];
    [exception release];
    [event setObject:exceptions forKey:@"exceptions"];
    [exceptions release];
    
    [exception setObject:errorClass forKey:@"errorClass"];
    [exception setObject:errorMessage forKey:@"message"];
    
    NSRegularExpression *stacktraceRegex = [NSRegularExpression regularExpressionWithPattern:@"[0-9]*(.*)(0x[0-9A-Fa-f]{8}) ([+-].+?]|[A-Za-z0-9_]+)"
                                                                                     options:NSRegularExpressionCaseInsensitive 
                                                                                       error:nil];
    
    NSMutableArray *stacktrace = [[NSMutableArray alloc] initWithCapacity:[rawStacktrace count]];
    for (NSString *stackLine in rawStacktrace) {
        NSMutableDictionary *lineDetails = [[NSMutableDictionary alloc] initWithCapacity:3];
        NSRange fullRange = NSMakeRange(0, [stackLine length]);
        
        NSTextCheckingResult* firstMatch = [stacktraceRegex firstMatchInString:stackLine options:0 range:fullRange];
        if (firstMatch) {
            NSString *packageName = [[stackLine substringWithRange:[firstMatch rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ( [packageName isEqualToString:[[NSProcessInfo processInfo] processName]] ) {
                [lineDetails setObject:[NSNumber numberWithBool:YES] forKey:@"inProject"];
            }
            [lineDetails setObject:[stackLine substringWithRange:[firstMatch rangeAtIndex:3]] forKey:@"method"];
            [lineDetails setObject:packageName forKey:@"file"];
            [lineDetails setObject:[stackLine substringWithRange:[firstMatch rangeAtIndex:2]] forKey:@"lineNumber"];
        } else {
            [lineDetails setObject:@"UnknownMethod" forKey:@"method"];
            [lineDetails setObject:@"UnknownLineNumber" forKey:@"lineNumber"];
            [lineDetails setObject:@"UnknownFile" forKey:@"file"];
        }
        
        [stacktrace addObject:lineDetails];
        [lineDetails release];
    }
    [exception setObject:stacktrace forKey:@"stacktrace"];
    [stacktrace release];
    
    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
    [event setObject:metadata forKey:@"metaData"];
    [metadata release];
    
    #ifdef _ARM_ARCH_7
        NSString *arch = @"armv7";
    #else
        #ifdef _ARM_ARCH_6
            NSString *arch = @"armv6";
        #else
            #ifdef __i386__
                NSString *arch = @"i386";  
            #endif
        #endif
    #endif
    
    natural_t usedMem = 0;
    natural_t freeMem = 0;
    natural_t totalMem = 0;
    
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        usedMem = info.resident_size;
        totalMem = info.virtual_size;
        freeMem = totalMem - usedMem;
    } 
    
    [metadata setObject:[NSDictionary dictionaryWithObjectsAndKeys:self.platform, @"Device",
                         arch, @"Architecture",
                         self.osVersion, @"OS Version",
                         [[NSNumber numberWithInt:freeMem] fileSize], @"Free Memory",
                         [[NSNumber numberWithInt:usedMem] fileSize], @"Used Memory",
                         [[NSNumber numberWithInt:totalMem] fileSize], @"Total Memory",nil] forKey:@"Device"];
    
    [metadata setObject:[NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([self.getVisibleViewController class]), @"Top View Comtroller",
                                                                   self.appVersion, @"App Version",
                                                                   [[NSBundle mainBundle] bundleIdentifier], @"Bundle Identifier",nil] forKey:@"Application"];
    
    // We need to add meta data to the event, as well as extra data and filter the extra data
    for(NSString *key in self.extraData) {
        if([self.dataFilters containsObject:key]) {
            [self.extraData setValue:@"[FILTERED]" forKey:key];
        }
    }
    
    [metadata setValuesForKeysWithDictionary:self.extraData];
    
    //Ensure the bugsnag dir is there
    [[NSFileManager defaultManager] createDirectoryAtPath:sharedBugsnagNotifier.errorPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    if(![event writeToFile:sharedBugsnagNotifier.errorFilename atomically:YES]) {
        BugLog(@"BUGSNAG: Unable to write notice file!");
    }
    [event release];
}

- (void) sendCachedReports {
    @synchronized(self) {
        if (!self.data) {
            if ( self.outstandingReports.count > 0 ) {
                NSDictionary *currentPayload = [self getNotifyPayload];
                NSMutableArray *events = [currentPayload objectForKey:@"events"];
                [events removeAllObjects];
                
                for ( NSString *file in self.outstandingReports ) {
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:file];
                    if (dict) {
                        [events addObject:dict];
                    }
                }
                if(events && events.count != 0) {
                    NSString *payload = [Bugsnag getJSONRepresentation:currentPayload];
                    if ( payload ) {
                        self.data = [NSMutableData data];
                        
                        NSMutableURLRequest *request = nil;
                        if(self.enableSSL) {
                            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://notify.bugsnag.com"]];
                        } else {
                            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://notify.bugsnag.com"]];
                        }
                        
                        [request setHTTPMethod:@"POST"];
                        [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
                        [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
                        [[[NSURLConnection alloc] initWithRequest:request delegate:self] release];
                    }
                }
            }
        }
    }
}

+ (NSString*) getJSONRepresentation:(NSDictionary*)dict {
    NSString *returnValue = nil;
    
    id NSJSONClass = NSClassFromString(@"NSJSONSerialization");
    SEL NSJSONSel = NSSelectorFromString(@"dataWithJSONObject:options:error:");
    
    SEL SBJsonSel = NSSelectorFromString(@"JSONRepresentation");
    
    SEL JSONKitSel = NSSelectorFromString(@"JSONString");
    
    SEL YAJLSel = NSSelectorFromString(@"yajl_JSONString");
    
    id NXJsonClass = NSClassFromString(@"NXJsonSerializer");
    SEL NXJsonSel = NSSelectorFromString(@"serialize:");
    
    if(NSJSONClass && [NSJSONClass respondsToSelector:NSJSONSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NSJSONClass methodSignatureForSelector:NSJSONSel]];
        invocation.target = NSJSONClass;
        invocation.selector = NSJSONSel;
        
        [invocation setArgument:&dict atIndex:2];
        NSUInteger writeOptions = 0;
        [invocation setArgument:&writeOptions atIndex:3];
        
        [invocation invoke];
        
        NSData *data = nil;
        [invocation getReturnValue:&data];
        
        returnValue = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    } else if (SBJsonSel && [dict respondsToSelector:SBJsonSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[dict methodSignatureForSelector:SBJsonSel]];
        invocation.target = dict;
        invocation.selector = SBJsonSel;
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    } else if (JSONKitSel && [dict respondsToSelector:JSONKitSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[dict methodSignatureForSelector:JSONKitSel]];
        invocation.target = dict;
        invocation.selector = JSONKitSel;
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    } else if (YAJLSel && [dict respondsToSelector:YAJLSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[dict methodSignatureForSelector:YAJLSel]];
        invocation.target = dict;
        invocation.selector = YAJLSel;
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    } else if (NXJsonClass && [NXJsonClass respondsToSelector:NXJsonSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NXJsonClass methodSignatureForSelector:NXJsonSel]];
        invocation.target = NXJsonClass;
        invocation.selector = NXJsonSel;
        
        [invocation setArgument:&dict atIndex:2];
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    }
    return returnValue;
}
@end