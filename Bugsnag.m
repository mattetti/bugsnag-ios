//
//  Bugsnag_NotifierViewController.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <execinfo.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/sysctl.h>

#import "Bugsnag.h"

int signals_count = 6;
int signals[] = {
	SIGABRT,
	SIGBUS,
	SIGFPE,
	SIGILL,
	SIGSEGV,
	SIGTRAP
};

void handle_signal(int, siginfo_t *, void *);
void handle_exception(NSException *);

void handle_signal(int signal, siginfo_t *info, void *context) {    
    NSLog(@"Signal caught!");
}
void handle_exception(NSException *exception) {
    NSLog(@"Exception caught!");
}

static Bugsnag *sharedBugsnagNotifier;

@implementation Bugsnag

@synthesize environment=_environment;
@synthesize apiKey=_apiKey;

+ (void) startBugsnagWithApiKey:(NSString*)apiKey andEnvironment:(NSString*)environment {
    if (!sharedBugsnagNotifier) {
		// validate
		if (![apiKey length]) {
            [NSException raise:@"BugsnagException" format:@"apiKey cannot be empty."];
		}
        
        // create
        if (!environment) {
#ifdef DEBUG
            environment = @"Development";
#else
            environment = @"Release";
#endif
        }
        sharedBugsnagNotifier = [[Bugsnag alloc] initWithAPIKey:apiKey environmentName:environment];
		
		// log
        if (!sharedBugsnagNotifier) {
            [NSException raise:@"BugsnagException" format:@"Unable to alloc the notifier."];
        }
	}
    NSSetUncaughtExceptionHandler(&handle_exception);
    
    for (NSUInteger i = 0; i < signals_count; i++) {
		int signal = signals[i];
		struct sigaction action;
		sigemptyset(&action.sa_mask);
		action.sa_flags = SA_SIGINFO;
		action.sa_sigaction = handle_signal;
		if (sigaction(signal, &action, NULL)) {
            NSLog(@"Unable to register signal handler for %s", strsignal(signal));
		}
	}
}

-(id) initWithAPIKey:key environmentName:environment {
    if ((self = [super init])) {
        
    }
    return self;
}
@end
