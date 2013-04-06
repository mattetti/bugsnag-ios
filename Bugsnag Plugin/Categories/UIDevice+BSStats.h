//
//  UIDevice+BSStats.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#if !TARGET_OS_IPHONE
@interface UIDevice
@end
#endif

@interface UIDevice (BSStats)
+ (NSString*) platform;
+ (NSString *) osVersion;
+ (NSString *) arch;
+ (NSDictionary *) memoryStats;
+ (NSNumber *)uptime;
@end
