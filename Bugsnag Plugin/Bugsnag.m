#import <execinfo.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/sysctl.h>

#import <Foundation/Foundation.h>
#import <mach/mach.h>

#import "UIViewController+Visibility.h"

#import "Bugsnag.h"
#import "BugsnagEvent.h"
#import "BugsnagNotifier.h"
#import "BugsnagLogging.h"
#import "BugsnagMetaData.h"
#import "BugsnagPrivate.h"

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
        
        NSDictionary *event = [BugsnagEvent generateEventFromErrorClass:[NSString stringWithCString:strsignal(signalReceived) encoding:NSUTF8StringEncoding]
                                                           errorMessage:@""
                                                             stackTrace:[BugsnagEvent getCallStackFromFrames:frames andCount:count startingAt:1]
                                                               metaData:nil];
        
        [BugsnagEvent writeEventToDisk:event];
    }
    //Propagate the signal back up to take the app down
    raise(signalReceived);
}

// Handles an uncaught exception
void handle_exception(NSException *exception) {
    if (sharedBugsnagNotifier && [sharedBugsnagNotifier shouldAutoNotify]) {
        remove_handlers();
        
        NSDictionary *event = [BugsnagEvent generateEventFromException:exception withMetaData:nil];
        
        [BugsnagEvent writeEventToDisk:event];
    }
}

@implementation Bugsnag

@synthesize releaseStage;
@synthesize apiKey;
@synthesize enableSSL;
@synthesize autoNotify;
@synthesize notifyReleaseStages;
@synthesize metaData;

// The start function. Entry point that should be called early on in application load
+ (void) startBugsnagWithApiKey:(NSString*)apiKey {
    NSLog(@"Starting the Bugsnag iOS Notifier!");
    [self instance].apiKey = apiKey;
    [BugsnagNotifier performSelectorInBackground:@selector(backgroundSendCachedReports) withObject:nil];
}

+ (Bugsnag *)instance {
    if(sharedBugsnagNotifier == nil) sharedBugsnagNotifier = [[Bugsnag alloc] init];
    return sharedBugsnagNotifier;
}

+ (void) notify:(NSException *)exception {
    [self notify:exception withData:nil];
}

+ (void) notify:(NSException *)exception withData:(NSDictionary*)metaData {
    if([self instance] && exception) {
        NSDictionary *event = [BugsnagEvent generateEventFromException:exception withMetaData:metaData];
        [BugsnagNotifier performSelectorInBackground:@selector(backgroundNotifyAndSend:) withObject:event];
    }
}

+ (void) setUserAttribute:(NSString*)attributeName withValue:(id)value {
    [self addAttribute:attributeName withValue:value toTabWithName:@"user"];
}

+ (void) clearUser {
    [self clearTabWithName:@"user"];
}

+ (void) addAttribute:(NSString*)attributeName withValue:(id)value toTabWithName:(NSString*)tabName {
    if(value) {
        [[[self instance].metaData getTab:tabName] setObject:value forKey:attributeName];
    } else {
        [[[self instance].metaData getTab:tabName] removeObjectForKey:attributeName];
    }
}

+ (void) clearTabWithName:(NSString*)tabName {
    [[self instance].metaData clearTab:tabName];
}

#pragma mark - Instance Methods
- (id) init {
    if ((self = [super init])) {
        _appVersion = nil;
        _userId = nil;
        _uuid = nil;
        [self.metaData = [[BugsnagMetaData alloc] init] release];
        self.sessionStartDate = [NSDate date];
        self.enableSSL = YES;
        self.autoNotify = YES;
        self.inForeground = YES;
        self.notifyReleaseStages = [NSArray arrayWithObject:@"production"];
        
        NSSetUncaughtExceptionHandler(&handle_exception);
        
        for (NSUInteger i = 0; i < signals_count; i++) {
            int signalType = signals[i];
            if (signal(signalType, handle_signal) != 0) {
                BugLog(@"Unable to register signal handler for %s", strsignal(signalType));
            }
        }
        
#ifdef DEBUG
        self.releaseStage = @"development";
#else
        self.releaseStage = @"production";
#endif
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (BOOL) shouldAutoNotify {
    return self.autoNotify && [self.notifyReleaseStages containsObject:self.releaseStage];
}

- (NSString*) appVersion {
    @synchronized(self){
        if(_appVersion) {
            return [[_appVersion copy] autorelease];
        } else {
            NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
            NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            if (bundleVersion != nil && versionString != nil && ![bundleVersion isEqualToString:versionString]) {
                self.appVersion = [NSString stringWithFormat:@"%@ (%@)", versionString, bundleVersion];
            } else if (bundleVersion != nil) {
                self.appVersion = bundleVersion;
            } else if(versionString != nil) {
                self.appVersion = versionString;
            }
            return [[_appVersion copy] autorelease];
        }
    }
}

- (void) setAppVersion:(NSString*)version {
    @synchronized(self) {
        if (_appVersion) [_appVersion release];
        _appVersion = [version copy];
    }
}

- (NSString*) userId {
    @synchronized(self) {
        if(_userId) {
            return [[_userId copy] autorelease];
        } else {
            return self.uuid;
        }
    }
}

- (void) setUserId:(NSString *)userId {
    @synchronized(self) {
        if(_userId) [_userId release];
        _userId = [userId copy];
    }
}

- (NSString*) context {
    @synchronized(self) {
        if(_context) return [[_context copy] autorelease];
        return NSStringFromClass([[UIViewController getVisible] class]);
    }
}

- (void) setContext:(NSString *)context {
    @synchronized(self) {
        if(_context) [_context release];
        _context = [context copy];
    }
}

- (NSString*) uuid {
    @synchronized(self) {
        if(_uuid) return [[_uuid copy] autorelease];
        NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        if([folders count]) {
            NSString *filename = [[folders objectAtIndex:0] stringByAppendingPathComponent:@"bugsnag-user-id"];
            
            _uuid = [[NSString stringWithContentsOfFile:filename encoding:NSStringEncodingConversionExternalRepresentation error:nil] retain];
            if(_uuid) {
                return [[_uuid copy] autorelease];
            } else {
                CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
                _uuid = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
                CFRelease(uuid);
                
                [_uuid writeToFile:filename atomically:YES encoding:NSStringEncodingConversionExternalRepresentation error:nil];
                return [[_uuid copy] autorelease];
            }
        } else {
            _uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"bugsnag-user-id"];
            if(_uuid) {
                return [[_uuid copy] autorelease];
            } else {
                CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
                [_uuid = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid) release];
                CFRelease(uuid);
                [[NSUserDefaults standardUserDefaults] setValue:_uuid forKey:@"bugsnag-user-id"];
                return [[_uuid copy] autorelease];
            }
        }
    }
}

- (NSNumber *) sessionLength {
    return [NSNumber numberWithInt:-(int)[self.sessionStartDate timeIntervalSinceNow]];
}

- (void)applicationDidBecomeActive:(NSNotification *)notif {
    [BugsnagNotifier performSelectorInBackground:@selector(backgroundSendCachedReports) withObject:nil];
    self.inForeground = YES;
}

- (void)applicationDidEnterBackground:(NSNotification *)notif {
    self.inForeground = NO;
}
@end