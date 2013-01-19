//
//  Bugsnag_NotifierAppDelegate.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Bugsnag_NotifierViewController;

@interface Bugsnag_NotifierAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;

@property (nonatomic, strong) IBOutlet Bugsnag_NotifierViewController *viewController;

@end
