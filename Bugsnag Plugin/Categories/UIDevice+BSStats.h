//
//  UIDevice+BSStats.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

@interface UIDevice : NSObject
@end

@interface UIDevice (BSStats)
+ (NSString*) platform;
+ (NSString *) osVersion;
+ (NSString *) arch;
+ (NSDictionary *) memoryStats;
+ (NSNumber *)uptime;
@end
