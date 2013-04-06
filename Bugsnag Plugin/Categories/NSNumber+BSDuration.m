//
//  NSNumber+BSDuration
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/7/12.
//
//

#import "NSNumber+BSDuration.h"

@implementation NSNumber (BSDuration)

- (NSString *) durationString {
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:-[self intValue]];
    NSCalendar *sysCalendar = [NSCalendar currentCalendar];
    
    unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSSecondCalendarUnit | NSYearCalendarUnit;
    
    NSDateComponents *conversionInfo = [sysCalendar components:unitFlags fromDate:date toDate:[NSDate date] options:0];
    NSMutableString *result = [[NSMutableString alloc] init];
    int entries = 0;
    
    if (conversionInfo.year) {
        [result appendFormat:@"%ld years", (long)conversionInfo.year];
        entries++;
    }
    
    if (entries < 2 && conversionInfo.month) {
        if (entries != 0) {
            [result appendFormat:@" and "];
        }
        [result appendFormat:@"%ld months", (long)conversionInfo.month];
        entries++;
    }
    
    if (entries < 2 && conversionInfo.day) {
        if (entries != 0) {
            [result appendFormat:@" and "];
        }
        [result appendFormat:@"%ld days", (long)conversionInfo.day];
        entries++;
    }
    
    if (entries < 2 && conversionInfo.minute) {
        if (entries != 0) {
            [result appendFormat:@" and "];
        }
        [result appendFormat:@"%ld minutes", (long)conversionInfo.minute];
        entries++;
    }
    
    if (entries < 2 && conversionInfo.second) {
        if (entries != 0) {
            [result appendFormat:@" and "];
        }
        [result appendFormat:@"%ld seconds", (long)conversionInfo.second];
        entries++;
    }
    
    return result;
}

@end
