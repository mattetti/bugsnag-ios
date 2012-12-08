//
//  BugsnagEvent.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import <execinfo.h>

#import "NSMutableDictionary+Merge.h"
#import "NSNumber+Duration.h"
#import "UIDevice+Stats.h"
#import "UIViewController+Visibility.h"

#import "Reachability.h"
#import "BugsnagEvent.h"
#import "Bugsnag.h"
#import "BugsnagLogging.h"
#import "BugsnagPrivate.h"

@interface BugsnagEvent ()
+ (NSString *) generateErrorFilename;
+ (NSString *) errorPath;
@end

@implementation BugsnagEvent
+ (NSArray *) outstandingReports {
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.errorPath error:nil];
	NSMutableArray *outstandingReports = [NSMutableArray arrayWithCapacity:[directoryContents count]];
	for (NSString *file in directoryContents) {
		if ([[file pathExtension] isEqualToString:@"bugsnag"]) {
			NSString *crashPath = [self.errorPath stringByAppendingPathComponent:file];
			[outstandingReports addObject:crashPath];
		}
	}
	return outstandingReports;
}

+ (NSString*) errorPath {
    static NSString *errorPath = nil;
    if(errorPath) return errorPath;
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *filename = [folders count] == 0 ? NSTemporaryDirectory() : [folders objectAtIndex:0];
    errorPath = [[filename stringByAppendingPathComponent:@"bugsnag"] retain];
    return errorPath;
}

+ (NSString *) generateErrorFilename {
    return [[self.errorPath stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] stringByAppendingPathExtension:@"bugsnag"];
}

+ (void) writeEventToDisk:(NSDictionary*)event {
    //Ensure the bugsnag dir is there
    [[NSFileManager defaultManager] createDirectoryAtPath:[self errorPath] withIntermediateDirectories:YES attributes:nil error:nil];
    
    if(![event writeToFile:[self generateErrorFilename] atomically:YES]) {
        BugLog(@"BUGSNAG: Unable to write notice file!");
    }
}

+ (NSDictionary*) generateEventFromException:(NSException*)exception withMetaData:(NSDictionary*)passedMetaData {
    NSUInteger frameCount = [[exception callStackReturnAddresses] count];
    void *frames[frameCount];
    for (NSInteger i = 0; i < frameCount; i++) {
        frames[i] = (void *)[[[exception callStackReturnAddresses] objectAtIndex:i] unsignedIntegerValue];
    }
    NSArray *rawStacktrace = [BugsnagEvent getCallStackFromFrames:frames andCount:frameCount startingAt:0];
    
    return [self generateEventFromErrorClass:exception.name
                                errorMessage:exception.reason
                                  stackTrace:rawStacktrace
                                    metaData:passedMetaData];
}

+ (NSDictionary*) generateEventFromErrorClass:(NSString*)errorClass
                                 errorMessage:(NSString*)errorMessage
                                   stackTrace:(NSArray*)rawStacktrace
                                     metaData:(NSDictionary*)passedMetaData {
    NSMutableDictionary *event = [[[NSMutableDictionary alloc] init] autorelease];
    [event setObject:[Bugsnag instance].uuid forKey:@"userId"];
    [event setObject:[Bugsnag instance].appVersion forKey:@"appVersion"];
    [event setObject:[UIDevice osVersion] forKey:@"osVersion"];
    [event setObject:[Bugsnag instance].releaseStage forKey:@"releaseStage"];
    [event setObject:[Bugsnag instance].context forKey:@"context"];
    
    NSMutableDictionary *exceptionDetails = [[NSMutableDictionary alloc] init];
    NSArray *exceptions = [[NSArray alloc] initWithObjects:exceptionDetails, nil];
    [exceptionDetails release];
    [event setObject:exceptions forKey:@"exceptions"];
    [exceptions release];
    
    [exceptionDetails setObject:errorClass forKey:@"errorClass"];
    [exceptionDetails setObject:errorMessage forKey:@"message"];
    
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
    [exceptionDetails setObject:stacktrace forKey:@"stacktrace"];
    [stacktrace release];
    
    BugsnagMetaData *metaData = [[Bugsnag instance].metaData mutableCopy];
    [event setObject:metaData.dictionary forKey:@"metaData"];
    [metaData autorelease];
    
    NSMutableDictionary *device = [metaData getTab:@"device"];
    
    [device setObject:[UIDevice platform] forKey:@"Device"];
    [device setObject:[UIDevice arch] forKey:@"Architecture"];
    [device setObject:[UIDevice osVersion] forKey:@"OS Version"];
    [device setObject:[[UIDevice uptime] durationString] forKey:@"Time since boot"];
    
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    [reachability startNotifier];
    NetworkStatus status = [reachability currentReachabilityStatus];
    [reachability stopNotifier];
    
    if(status == NotReachable) {
        [device setObject:@"None" forKey:@"Network"];
    } else if (status == ReachableViaWiFi) {
        [device setObject:@"WiFi" forKey:@"Network"];
    } else if (status == ReachableViaWWAN) {
        [device setObject:@"3G" forKey:@"Network"];
    }
    
    NSDictionary *memoryStats = [UIDevice memoryStats];
    if(memoryStats) {
        [device setObject:memoryStats forKey:@"Memory"];
    }
    
    NSMutableDictionary *application = [metaData getTab:@"application"];
    
    [application setObject:NSStringFromClass([[UIViewController getVisible] class]) forKey:@"Top View Comtroller"];
    [application setObject:[Bugsnag instance].appVersion forKey:@"App Version"];
    [application setObject:[[NSBundle mainBundle] bundleIdentifier] forKey:@"Bundle Identifier"];
    
    NSMutableDictionary *session = [metaData getTab:@"session"];
    
    [session setObject:[[Bugsnag instance].sessionLength durationString] forKey:@"Session Length"];
    [session setObject:[NSNumber numberWithBool:[Bugsnag instance].inForeground] forKey:@"In Foreground"];
    
    if(passedMetaData) {
        [metaData mergeWith:passedMetaData];
    }
    return event;
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
@end
