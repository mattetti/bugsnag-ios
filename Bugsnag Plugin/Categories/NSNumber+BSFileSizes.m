//
//  NSNumber+BSFileSizes.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import "NSNumber+BSFileSizes.h"

@implementation NSNumber (BSFileSizes)
- (NSString *)fileSize {
    double fileSize = [self doubleValue];
    if (fileSize<1023.0)
        return [NSString stringWithFormat:@"%i bytes",[self intValue]];
    fileSize = fileSize / 1024.0;
    if (fileSize<1023.0)
        return [NSString stringWithFormat:@"%1.1f KB",fileSize];
    fileSize = fileSize / 1024.0;
    if (fileSize<1023.0)
        return [NSString stringWithFormat:@"%1.1f MB",fileSize];
    fileSize = fileSize / 1024.0;
    
    return [NSString stringWithFormat:@"%1.1f GB",fileSize];
}
@end
