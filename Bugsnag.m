//
//  Bugsnag_NotifierViewController.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 Bugsnag. All rights reserved.
//

#import <execinfo.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/sysctl.h>

#import <Foundation/Foundation.h>
#import <mach/mach.h>

#import "SBJson.h"
#import "Bugsnag.h"

#define BUGSNAG_ENDPOINT @"http://api.bugsnag.com/notify"
#define BUGSNAG_IOS_VERSION @"1.0.0"
#define BUGSNAG_IOS_HOMEPAGE @"http://www.bugsnag.com"

@interface Bugsnag ()
- (id) initWithAPIKey:(NSString*)apiKey andReleaseStage:(NSString*)releaseStage;
- (void)sendReports;
- (void)registerNotifications;
- (void)unregisterNotifications;

@property (nonatomic, retain) NSMutableDictionary *bugsnagPayload;
@property (nonatomic, retain) NSMutableDictionary *applicationData;
@property (nonatomic, retain) NSMutableDictionary *metaData;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, retain) NSMutableData *data;
@end

static Bugsnag *sharedBugsnagNotifier = nil;

int signals_count = 6;
int signals[] = {
	SIGABRT,
	SIGBUS,
	SIGFPE,
	SIGILL,
	SIGSEGV,
	SIGTRAP,
    EXC_BAD_ACCESS,
};

void handle_signal(int);
void handle_exception(NSException *);
NSArray *getCallStackFromFrames(void *, int);
NSArray *getOutstandingErrorFilenames(void);
NSString *generateBugsnagReportFilename(void);
NSString *getPlatform(void);
NSString *getAppVersion(void);
NSString *getOSVersion(void);
NSString *generateBugsnagReportPath(void);
NSString *getBugsnagPayload(void);
void deleteCachedReports(void);
void saveError(NSString *, NSString *, NSArray *);

// Deletes all the cached reports. Only call after we've sent them!
void deleteCachedReports(void) {
    [[NSFileManager defaultManager] removeItemAtPath:generateBugsnagReportPath() error:nil];
}

// Gets the JSON payload that represents the currently cached errors
NSString *getBugsnagPayload(void) {
    NSArray *errorFiles = getOutstandingErrorFilenames();
    if ( [errorFiles count] > 0 ) {
        for ( NSString *file in errorFiles ) {
            [(NSMutableArray*)[sharedBugsnagNotifier.bugsnagPayload objectForKey:@"errors"] addObject:[NSMutableDictionary dictionaryWithContentsOfFile:file]];
        }
        return [sharedBugsnagNotifier.bugsnagPayload JSONRepresentation];
    }
    return nil;
}

// Retrieves the filenames of any outstanding errors
NSArray *getOutstandingErrorFilenames(void) {
    NSString *path = generateBugsnagReportPath();
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
	NSMutableArray *crashes = [NSMutableArray arrayWithCapacity:[directoryContents count]];
	for (NSString *file in directoryContents) {
		if ([[file pathExtension] isEqualToString:@"bugsnag"]) {
			NSString *crashPath = [path stringByAppendingPathComponent:file];
			[crashes addObject:crashPath];
		}
	}
	return crashes;
}

// Generates the path used to store the error reports
NSString *generateBugsnagReportPath(void) {
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *filename = [folders count] == 0 ? NSTemporaryDirectory() : [folders objectAtIndex:0];
	return [filename stringByAppendingPathComponent:@"bugsnag"];
}

// Generates a GUID filename to store an error in
NSString *generateBugsnagReportFilename(void) {
	NSString *filename = generateBugsnagReportPath();
    filename = [filename stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    return [filename stringByAppendingPathExtension:@"bugsnag"];
}

// Gets a textual representation of the current platform
NSString *getPlatform(void) {
#if TARGET_IPHONE_SIMULATOR
	return @"iPhone Simulator";
#endif
    size_t size = 256;
	char *machineCString = malloc(size);
    sysctlbyname("hw.machine", machineCString, &size, NULL, 0);
    NSString *machine = [NSString stringWithCString:machineCString encoding:NSUTF8StringEncoding];
    free(machineCString);
    // iPhone
	if ([machine isEqualToString:@"iPhone1,1"]) { return @"iPhone"; }
	else if ([machine isEqualToString:@"iPhone1,2"]) { return @"iPhone 3G"; }
	else if ([machine isEqualToString:@"iPhone2,1"]) { return @"iPhone 3GS"; }
	else if ([machine isEqualToString:@"iPhone3,1"]) { return @"iPhone 4 (GSM)"; }
    else if ([machine isEqualToString:@"iPhone3,3"]) { return @"iPhone 4 (CDMA)"; }
	// iPad
	else if ([machine isEqualToString:@"iPad1,1"]) { return @"iPad"; }
    else if ([machine isEqualToString:@"iPad2,1"]) { return @"iPad 2 (WiFi)"; }
    else if ([machine isEqualToString:@"iPad2,2"]) { return @"iPad 2 (GSM)"; }
    else if ([machine isEqualToString:@"iPad2,3"]) { return @"iPad 2 (CDMA)"; }
	// iPod
	else if ([machine isEqualToString:@"iPod1,1"]) { return @"iPod Touch"; }
	else if ([machine isEqualToString:@"iPod2,1"]) { return @"iPod Touch (2nd generation)"; }
	else if ([machine isEqualToString:@"iPod3,1"]) { return @"iPod Touch (3rd generation)"; }
	else if ([machine isEqualToString:@"iPod4,1"]) { return @"iPod Touch (4th generation)"; }
	// Unknown
	else { return machine; }
}

// Gets the application version information
NSString *getAppVersion(void) {
    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	if (bundleVersion != nil && versionString != nil) {
		return [NSString stringWithFormat:@"%@ (%@)", versionString, bundleVersion];
	}
	else if (bundleVersion != nil) { return bundleVersion; }
	else if (versionString != nil) { return versionString; }
	else { return nil; }
}

// Gets the OS version information
NSString *getOSVersion(void) {
#if TARGET_IPHONE_SIMULATOR
	return [[UIDevice currentDevice] systemVersion];
#else
	return [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
}

// Returns the call stack from the frame numbers. Uses the iOS format
NSArray *getCallStackFromFrames(void *frames, int count) {
	char **strs = backtrace_symbols(frames, count);
	NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:count];
	for (NSInteger i = 0; i < count; i++) {
		NSString *entry = [NSString stringWithUTF8String:strs[i]];
		[backtrace addObject:entry];
	}
	free(strs);
	return backtrace;
}

// Handles a raised signal
void handle_signal(int signalReceived) {
    if (sharedBugsnagNotifier) {
        for (NSUInteger i = 0; i < signals_count; i++) {
            int signalType = signals[i];
            signal(signalType, NULL);
        }
        
        // We limit to 128 lines of trace information for signals atm
        int count = 128;
		void *frames[count];
		count = backtrace(frames, count);

        saveError([NSString stringWithCString:strsignal(signalReceived) encoding:NSUTF8StringEncoding], 
                  @"", 
                  getCallStackFromFrames(frames,count));
    }
    //Propagate the signal back up to take the app down
    raise(signalReceived);
}

// Handles an uncaught exception
void handle_exception(NSException *exception) {
    if (sharedBugsnagNotifier) {
        NSUInteger frameCount = [[exception callStackReturnAddresses] count];
        void *frames[frameCount];
        for (NSInteger i = 0; i < frameCount; i++) {
            frames[i] = (void *)[[[exception callStackReturnAddresses] objectAtIndex:i] unsignedIntegerValue];
        }
        
        saveError([exception name], [exception reason], getCallStackFromFrames(frames, frameCount));
    }
}

// Creates an error from the provided information and saves it
void saveError(NSString *name, NSString *message, NSArray *rawStacktrace) {
    NSMutableDictionary *error = [[NSMutableDictionary alloc] init];
    
    [error setObject:sharedBugsnagNotifier.applicationData forKey:@"appEnvironment"];
    [error setObject:sharedBugsnagNotifier.metaData forKey:@"metaData"];
    [error setObject:sharedBugsnagNotifier.userId forKey:@"userId"];
    
    NSMutableDictionary *cause = [[NSMutableDictionary alloc] init];
    [error setObject:[[NSArray alloc] initWithObjects:cause, nil] forKey:@"causes"];
    
    [cause setObject:name forKey:@"errorClass"];
    [cause setObject:message forKey:@"message"];
    
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
                [lineDetails setObject:@"true" forKey:@"inProject"];
            } else {
                [lineDetails setObject:@"false" forKey:@"inProject"];
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
    [cause setObject:stacktrace forKey:@"stacktrace"];
    [stacktrace release];
    [cause release];
    
    //Ensure the bugsnag dir is there
    [[NSFileManager  defaultManager] createDirectoryAtPath:generateBugsnagReportPath() withIntermediateDirectories:YES attributes:nil error:nil];
    
    [error writeToFile:sharedBugsnagNotifier.filename atomically:NO];
    [error release];
}

@implementation Bugsnag

@synthesize bugsnagPayload = _bugsnagPayload;
@synthesize applicationData = _applicationData;
@synthesize metaData = _metaData;
@synthesize filename = _filename;
@synthesize userId = _userId;
@synthesize data = _data;

#pragma mark - Static Methods

// The start function. Entry point that should be called early on in application load
+ (void) startBugsnagWithApiKey:(NSString*)apiKey andReleaseStage:(NSString*)releaseStage {
    if (!sharedBugsnagNotifier) {
		if (![apiKey length]) {
            [NSException raise:@"BugsnagException" format:@"apiKey cannot be empty."];
		}
        
        NSString *stage = releaseStage;
        if (!stage) {
#ifdef DEBUG
            stage = @"Development";
#else
            stage = @"Release";
#endif
        }
        sharedBugsnagNotifier = [[Bugsnag alloc] initWithAPIKey:apiKey andReleaseStage:stage];
		
        if (!sharedBugsnagNotifier) {
            [NSException raise:@"BugsnagException" format:@"Unable to alloc the notifier."];
        }
        
        [sharedBugsnagNotifier sendReports];
        
        NSSetUncaughtExceptionHandler(&handle_exception);
        
        for (NSUInteger i = 0; i < signals_count; i++) {
            int signalType = signals[i];
            if (signal(signalType, handle_signal) != 0) {
                NSLog(@"Unable to register signal handler for %s", strsignal(signalType));
            }
        }
	}
}

// Allows the user to override the version number information
+ (void) setAppVersion:(NSString *)appVersion {
    if (sharedBugsnagNotifier) {
        [sharedBugsnagNotifier.applicationData setObject:[NSString stringWithString:appVersion] forKey:@"appVersion"];
    } else {
        [NSException raise:@"BugsnagException" format:@"Unable to set AppVersion before start called."];
    }
}

// Allows the user to set a user Id rather than using the UDID.
+ (void) setUserId:(NSString *)userId {
    if (sharedBugsnagNotifier) {
        sharedBugsnagNotifier.userId = [NSString stringWithString:userId];
    } else {
        [NSException raise:@"BugsnagException" format:@"Unable to change UserID before start called."];
    }
}

#pragma mark - Instance Methods
// Internal init function. Sets up the class nicely
- (id) initWithAPIKey:(NSString*)apiKey andReleaseStage:(NSString*)releaseStage {
    if ((self = [super init])) {
        NSDictionary *notifier = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: @"iOS Bugsnag Notifier", BUGSNAG_IOS_VERSION, BUGSNAG_IOS_HOMEPAGE, nil] 
                                                               forKeys:[NSArray arrayWithObjects: @"name", @"version", @"url", nil]];
        
        self.bugsnagPayload = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: notifier, [NSString stringWithString:apiKey], [[NSMutableArray alloc] init], nil] 
                                                            forKeys:[NSArray arrayWithObjects: @"notifier", @"apiKey", @"errors", nil]];
        
        self.applicationData = [[NSMutableDictionary alloc] init];
        self.metaData = [[NSMutableDictionary alloc] init];
        
        [self.applicationData setObject:getAppVersion() forKey:@"appVersion"];
        [self.applicationData setObject:releaseStage forKey:@"releaseStage"];
        [self.applicationData setObject:getOSVersion() forKey:@"osVersion"];
        [self.applicationData setObject:getPlatform() forKey:@"device"];
        
        self.userId = [[UIDevice currentDevice]uniqueIdentifier];
        self.filename = generateBugsnagReportFilename();
        
        [self registerNotifications];
    }
    return self;
}

// Register for application level notifications
- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

// Unregister for application level notifications
- (void)unregisterNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

// When the application comes from the background check to see if we can send any cached reports
- (void)applicationDidBecomeActive:(NSNotification *)notif {
    [self sendReports];
}

// Append data received
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
}

// Check the response code received
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    int statusCode = [((NSHTTPURLResponse *)response) statusCode];
    if (statusCode != 200) {
        [connection cancel];
        NSLog(@"Bad response from bugnsag received: %d.", statusCode);
        self.data = nil;
    }
}

// Connection finished successfully
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self unregisterNotifications];
    deleteCachedReports();
}

// No net connection
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.data = nil;
}

// Send any cached reports - will check a send isn't already underway
- (void)sendReports {
    @synchronized(self) {
        if (!self.data) {
            NSString *payload = getBugsnagPayload();
            if ( payload ) {
                sharedBugsnagNotifier.data = [NSMutableData data];
                
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:BUGSNAG_ENDPOINT]];
                
                [request setHTTPMethod:@"POST"];
                [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
                [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
                [[NSURLConnection alloc] initWithRequest:request delegate:sharedBugsnagNotifier];
            } else {
                [self unregisterNotifications];
            }
        }
    }
}

// Called on dealloc - will never be called due to private singleton pattern
- (void)dealloc {
    [super dealloc];
}
@end