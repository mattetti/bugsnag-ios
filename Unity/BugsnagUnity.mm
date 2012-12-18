#import "Bugsnag.h"
#import "BugsnagEvent.h"
#import "BugsnagNotifier.h"

extern "C" {
    void SetUserId(char *userId);
    void SetContext(char *context);
    void SetReleaseStage(char *releaseStage);
    void SetUseSSL(int useSSL);
    void SetAutoNotify(int autoNotify);
    void Notify(char *errorClass, char *errorMessage, char *stackTrace);
    void Register(char *apiKey);
    void AddToTab(char *tabName, char *attributeName, char *attributeValue);
    void ClearTab(char *tabName);
    NSMutableArray *parseStackTrace(NSString *stackTrace, NSRegularExpression *stacktraceRegex);
    
    void SetUserId(char *userId)
    {
        NSString *ns_userId = [NSString stringWithUTF8String: userId];
        [Bugsnag instance].userId = ns_userId;
    }
    
    void SetContext(char *context) {
        NSString *ns_context = [NSString stringWithUTF8String: context];
        [Bugsnag instance].context = ns_context;
    }
    
    void SetReleaseStage(char *releaseStage) {
        NSString *ns_releaseStage = [NSString stringWithUTF8String: releaseStage];
        [Bugsnag instance].releaseStage = ns_releaseStage;
    }
    
    void SetUseSSL(int useSSL) {
        [Bugsnag instance].enableSSL = useSSL;
    }
    
    void SetAutoNotify(int autoNotify) {
        [Bugsnag instance].autoNotify = autoNotify;
    }
    
    void AddToTab(char *tabName, char *attributeName, char *attributeValue) {
        NSString *ns_tabName = [NSString stringWithUTF8String:tabName];
        NSString *ns_attributeName = [NSString stringWithUTF8String:attributeName];
        NSString *ns_attributeValue = [NSString stringWithUTF8String:attributeValue];
        [Bugsnag addAttribute:ns_attributeName withValue:ns_attributeValue toTabWithName:ns_tabName];
    }
    
    void ClearTab(char *tabName) {
        NSString *ns_tabName = [NSString stringWithUTF8String:tabName];
        [Bugsnag clearTabWithName:ns_tabName];
    }
    
    void Notify(char *errorClass, char *errorMessage, char *stackTrace) {
        NSString *ns_stackTrace = [NSString stringWithUTF8String:stackTrace];
        
        NSRegularExpression *manualNotifyExpression = [NSRegularExpression regularExpressionWithPattern:@"at\\s(\\S+).+?(<filename unknown>|\\S+):(\\d*)\\s*"
                                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                                  error:nil];
        NSRegularExpression *autoNotifyExpression = [NSRegularExpression regularExpressionWithPattern:@"\\s*(\\S+)\\ \\(.*?(?:([\\\\\\/]\\S*?):(\\d*)|\\n)"
                                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                                error:nil];
        
        NSMutableArray *stacktrace;
        
        if([ns_stackTrace hasPrefix:@"  at "]) {
            stacktrace = parseStackTrace(ns_stackTrace, manualNotifyExpression);
        } else {
            stacktrace = parseStackTrace(ns_stackTrace, autoNotifyExpression);
        }
        
        
        NSDictionary *event = [BugsnagEvent generateEventFromErrorClass:[NSString stringWithUTF8String:errorClass]
                                                           errorMessage:[NSString stringWithUTF8String:errorMessage]
                                                             stackTrace:stacktrace
                                                               metaData:nil];
        
        [BugsnagNotifier performSelectorInBackground:@selector(backgroundNotifyAndSend:) withObject:event];
    }
    
    void Register(char *apiKey) {
        [BugsnagNotifier setUnityNotifier];
        
        NSString *ns_apiKey = [NSString stringWithUTF8String: apiKey];
        [Bugsnag startBugsnagWithApiKey:ns_apiKey];
    }
    
    NSMutableArray *parseStackTrace(NSString *stackTrace, NSRegularExpression *stacktraceRegex) {
        NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
        
        [stacktraceRegex enumerateMatchesInString:stackTrace options:0 range:NSMakeRange(0, [stackTrace length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSMutableDictionary *lineDetails = [[NSMutableDictionary alloc] initWithCapacity:3];
            if(result) {
                if(result.numberOfRanges >= 1) {
                    [lineDetails setObject:[stackTrace substringWithRange:[result rangeAtIndex:1]] forKey:@"method"];
                }
                
                if(result.numberOfRanges >= 2) {
                    [lineDetails setObject:[stackTrace substringWithRange:[result rangeAtIndex:2]] forKey:@"file"];
                }
                
                if(result.numberOfRanges >= 3) {
                    [lineDetails setObject:[NSNumber numberWithInt:[[stackTrace substringWithRange:[result rangeAtIndex:3]] integerValue]] forKey:@"lineNumber"];
                }
            } else {
                [lineDetails setObject:@"unknown method" forKey:@"method"];
                [lineDetails setObject:[NSNumber numberWithInt:0] forKey:@"lineNumber"];
                [lineDetails setObject:@"unknown file" forKey:@"file"];
            }
            [returnArray addObject:lineDetails];
            [lineDetails release];
        }];
        return returnArray;
    }
}