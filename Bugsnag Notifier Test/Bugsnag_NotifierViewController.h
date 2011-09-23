//
//  Bugsnag_NotifierViewController.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Bugsnag_NotifierViewController : UIViewController

-(IBAction) generateException:(UIButton*)sender;
-(IBAction) generateSignal:(UIButton*)sender;

@end
