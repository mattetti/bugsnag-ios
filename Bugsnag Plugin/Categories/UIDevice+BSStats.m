//
//  UIDevice+BSStats.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import <fcntl.h>
#import <unistd.h>
#import <mach/mach.h>
#import <sys/sysctl.h>

#import "NSNumber+BSFileSizes.h"
#import "UIDevice+BSStats.h"

@implementation UIDevice
@end

@implementation UIDevice (BSStats)

+ (NSString*) platform {
    size_t size = 256;
	char *machineCString = malloc(size);
    sysctlbyname("hw.machine", machineCString, &size, NULL, 0);
    NSString *machine = [NSString stringWithCString:machineCString encoding:NSUTF8StringEncoding];
    free(machineCString);

    if ([machine isEqualToString:@"i386"])         return @"Simulator";
    if ([machine isEqualToString:@"x86_64"])       return @"Simulator";
    
    return machine;
}

+ (NSString *) osVersion {
#if TARGET_IPHONE_SIMULATOR
	return [[UIDevice currentDevice] systemVersion];
#else
	return [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
}

+ (NSString *) arch {
#ifdef _ARM_ARCH_7
    NSString *arch = @"armv7";
#else
#ifdef _ARM_ARCH_6
    NSString *arch = @"armv6";
#else
#ifdef __i386__
    NSString *arch = @"i386";
#else
#ifdef __x86_64__
    NSString *arch = @"x86_64";
#endif
#endif
#endif
#endif
    return arch;
}

+ (NSDictionary *) memoryStats {
    vm_size_t usedMem = 0;
    vm_size_t freeMem = 0;
    vm_size_t totalMem = 0;
    
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
        return [NSDictionary dictionaryWithObjectsAndKeys:
                [[NSNumber numberWithLong:freeMem] fileSize], @"Free",
                [[NSNumber numberWithLong:totalMem] fileSize], @"Total",
                [[NSNumber numberWithLong:usedMem] fileSize], @"Used", nil];
    } else {
        return nil;
    }
}

+ (NSNumber *)uptime {
    struct timeval boottime;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    time_t now;
    time_t uptime = -1;
    
    (void)time(&now);
    
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0)
    {
        uptime = now - boottime.tv_sec;
    }
    
    return [NSNumber numberWithLong:uptime];
}

@end
