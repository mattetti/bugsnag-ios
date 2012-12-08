//
//  UIViewController+Visibility.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import "UIViewController+Visibility.h"

@implementation UIViewController (Visibility)
+ (UIViewController *)getVisible {
    UIViewController *viewController = nil;
    UIViewController *visibleViewController = nil;
    
    if ([[[UIApplication sharedApplication] keyWindow].rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *) [[UIApplication sharedApplication] keyWindow].rootViewController;
        viewController = navigationController.visibleViewController;
    }
    else {
        viewController = [[UIApplication sharedApplication] keyWindow].rootViewController;
    }
    
    int tries = 0;
    
    while (visibleViewController == nil && tries <= 30 && viewController) {
        tries++;
        if (viewController.modalViewController == nil) {
            visibleViewController = viewController;
        } else {
            if ([viewController.modalViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navigationController = (UINavigationController *)viewController.modalViewController;
                viewController = navigationController.visibleViewController;
            } else {
                viewController = viewController.modalViewController;
            }
        }
        
    }
    
    return visibleViewController;
}
@end
