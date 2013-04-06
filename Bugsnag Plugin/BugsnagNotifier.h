//
//  BugsnagNotifier.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import <Foundation/Foundation.h>

@interface BugsnagNotifier : NSObject
+ (void) backgroundNotifyAndSend:(NSDictionary*)event;
+ (void) backgroundSendCachedReports;
+ (void) sendCachedReports;
@end
