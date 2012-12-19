//
//  NSDictionary+JSON.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 12/6/12.
//
//

#import "NSDictionary+JSON.h"

@implementation NSDictionary (JSON)

- (NSString*) toJSONRepresentation {
    NSString *returnValue = nil;
    
    id NSJSONClass = NSClassFromString(@"NSJSONSerialization");
    SEL NSJSONSel = NSSelectorFromString(@"dataWithJSONObject:options:error:");
    
    SEL SBJsonSel = NSSelectorFromString(@"JSONRepresentation");
    
    SEL JSONKitSel = NSSelectorFromString(@"JSONString");
    
    SEL YAJLSel = NSSelectorFromString(@"yajl_JSONString");
    
    id NXJsonClass = NSClassFromString(@"NXJsonSerializer");
    SEL NXJsonSel = NSSelectorFromString(@"serialize:");
    
    if(NSJSONClass && [NSJSONClass respondsToSelector:NSJSONSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NSJSONClass methodSignatureForSelector:NSJSONSel]];
        invocation.target = NSJSONClass;
        invocation.selector = NSJSONSel;
        
        [invocation setArgument:&self atIndex:2];
        NSUInteger writeOptions = 0;
        [invocation setArgument:&writeOptions atIndex:3];
        
        [invocation invoke];
        
        NSData *data = nil;
        [invocation getReturnValue:&data];
        
        returnValue = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    } else if (SBJsonSel && [self respondsToSelector:SBJsonSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:SBJsonSel]];
        invocation.target = self;
        invocation.selector = SBJsonSel;
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    } else if (JSONKitSel && [self respondsToSelector:JSONKitSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:JSONKitSel]];
        invocation.target = self;
        invocation.selector = JSONKitSel;
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    } else if (YAJLSel && [self respondsToSelector:YAJLSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:YAJLSel]];
        invocation.target = self;
        invocation.selector = YAJLSel;
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    } else if (NXJsonClass && [NXJsonClass respondsToSelector:NXJsonSel]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NXJsonClass methodSignatureForSelector:NXJsonSel]];
        invocation.target = NXJsonClass;
        invocation.selector = NXJsonSel;
        
        [invocation setArgument:&self atIndex:2];
        
        [invocation invoke];
        [invocation getReturnValue:&returnValue];
    }
    return returnValue;
}


@end
