#import <Foundation/Foundation.h>

@interface Bugsnag : NSObject {
    @private
    NSString *_appVersion;
    NSString *_userId;
    NSString *_errorPath;
    NSString *_context;
}

+ (void) startBugsnagWithApiKey:(NSString*)apiKey;
+ (Bugsnag *)instance;
+ (void) notify:(NSException *)exception;
+ (void) notify:(NSException *)exception withData:(NSDictionary*)extraData;

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