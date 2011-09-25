//
//  Bugsnag_NotifierViewController.h
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Bugsnag : NSObject {
    @private
    NSMutableDictionary *_bugsnagPayload;
    NSMutableDictionary *_applicationData;
    NSMutableDictionary *_metaData;
    NSString *_filename;
    NSString *_userId;
    NSMutableData *_data;
}

+ (void) startBugsnagWithApiKey:(NSString*)apiKey andReleaseStage:(NSString*)releaseStage;
+ (void) setUserId:(NSString*)userId;
+ (void) setAppVersion:(NSString*)appVersion;
@end