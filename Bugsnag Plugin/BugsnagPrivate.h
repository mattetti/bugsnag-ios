#import <Foundation/Foundation.h>
#import "BugsnagMetaData.h"

@interface Bugsnag ()
- (id) init;
- (BOOL) shouldAutoNotify;

@property (retain) BugsnagMetaData *metaData;
@property (retain) NSDate *sessionStartDate;
@property (readonly) NSNumber *sessionLength;
@property BOOL inForeground;
@end