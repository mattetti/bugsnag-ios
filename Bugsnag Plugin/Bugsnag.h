#import <Foundation/Foundation.h>

@interface Bugsnag : NSObject {
    @private
    NSString *_appVersion;
    NSString *_userId;
    NSString *_errorPath;
    NSString *_context;
    NSMutableArray *_outstandingReports;
}

+ (void) startBugsnagWithApiKey:(NSString*)apiKey;
+ (Bugsnag *)instance;

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy) NSString *releaseStage;
@property (nonatomic, copy) NSString *context;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic) BOOL enableSSL;
@property (nonatomic) BOOL autoNotify;
@property (nonatomic, retain) NSArray *notifyReleaseStages;
@property (nonatomic, retain) NSDictionary *extraData;
@property (nonatomic, retain) NSArray *dataFilters;
@end