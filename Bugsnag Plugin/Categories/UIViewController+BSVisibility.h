//
//  UIViewController+BSVisibility.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

@interface UIViewController (BSVisibility)
+ (UIViewController *)getVisible;
@end
#endif