//
//  BugsnagNotifier.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import "BugsnagNotifier.h"
#import "BugsnagEvent.h"
#import "Bugsnag.h"
#import "BugsnagLogging.h"
#import "NSDictionary+JSON.h"
#import "BugsnagPrivate.h"

#define BUGSNAG_IOS_VERSION @"1.0.0"
#define BUGSNAG_IOS_HOMEPAGE @"https://github.com/bugsnag/bugsnag-ios"

@implementation BugsnagNotifier

+ (NSDictionary*) getNotifyPayload {
    NSDictionary *notifier = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: @"iOS Bugsnag Notifier", BUGSNAG_IOS_VERSION, BUGSNAG_IOS_HOMEPAGE, nil]
                                                           forKeys:[NSArray arrayWithObjects: @"name", @"version", @"url", nil]];
    NSMutableArray *events = [[NSMutableArray alloc] init];
    NSDictionary *notifierPayload = [[[NSDictionary alloc] initWithObjectsAndKeys:notifier, @"notifier", [Bugsnag instance].apiKey, @"apiKey", events, @"events", nil] autorelease];
    
    [notifier release];
    [events release];
    return notifierPayload;
}

+ (void) backgroundNotifyAndSend:(NSDictionary*)event {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [BugsnagEvent writeEventToDisk:event];
    [self sendCachedReports];
    
    [pool release];
}

+ (void) backgroundSendCachedReports {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self sendCachedReports];
    [pool release];
}

+ (void) sendCachedReports {
    @synchronized(self) {
        NSArray *outstandingReports = [BugsnagEvent outstandingReports];
        if ( outstandingReports.count > 0 ) {
            NSDictionary *currentPayload = [self getNotifyPayload];
            NSMutableArray *events = [currentPayload objectForKey:@"events"];
            [events removeAllObjects];
            NSMutableArray *sentFilenames = [NSMutableArray array];
            
            for ( NSString *file in outstandingReports ) {
                [sentFilenames addObject:file];
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:file];
                if (dict) {
                    [events addObject:dict];
                }
            }
            
            if([events count]) {
                NSString *payload = [currentPayload toJSONRepresentation];
                if(payload){
                    NSMutableURLRequest *request = nil;
                    if([Bugsnag instance].enableSSL) {
                        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://notify.bugsnag.com"]];
                    } else {
                        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://notify.bugsnag.com"]];
                    }
                    
                    [request setHTTPMethod:@"POST"];
                    [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
                    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
                    
                    NSURLResponse* response = nil;
                    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
                    
                    int statusCode = [((NSHTTPURLResponse *)response) statusCode];
                    if (statusCode != 200) {
                        BugLog(@"Bad response from bugsnag received: %d.", statusCode);
                    }
                    
                    for(NSString *file in sentFilenames) {
                        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
                    }
                }
            }
            sentFilenames = nil;
        }
    }
}
@end
