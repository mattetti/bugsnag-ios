//
//  Bugsnag_NotifierViewController.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Bugsnag : NSObject {
    NSString *_apiKey;
    NSString *environment;
}

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *environment;

+ (void) startBugsnagWithApiKey:(NSString*)apiKey andEnvironment:(NSString*)environment;

-(id) initWithAPIKey:key environmentName:environment;

@end