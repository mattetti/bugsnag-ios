//
//  Bugsnag_NotifierViewController.m
//  Bugsnag Notifier
//
//  Created by Simon Maynard on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Bugsnag_NotifierViewController.h"
#import "Bugsnag.h"

@implementation Bugsnag_NotifierViewController

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (IBAction)generateSignal:(UIButton *)sender {
    raise(SIGSEGV);
}

- (IBAction)generateException:(UIButton *)sender {
    [NSException raise:@"BugsnagException" format:@"Test exception."];
}

- (IBAction) generateNonFatalException:(UIButton*)sender {
    [Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]];
}

- (IBAction) delayedNotify:(UIButton*)sender {
    [self performSelector:@selector(generateNonFatalException:) withObject:sender afterDelay:5];
}

- (IBAction)nonFatalWithMetaData:(id)sender {
    [Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil] withData:[NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:@"metaDataValue", @"metaDataKey", nil], @"metaDataTab", nil]];
}

- (IBAction)nonFatalWithCustomData:(id)sender {
    [Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil] withData:[NSDictionary dictionaryWithObject:@"customDataValue" forKey:@"customDataKey"]];
}

- (IBAction)addUserToTab:(id)sender {
    [Bugsnag addAttribute:@"attributeNameUser" withValue:@"attributeValueUser" toTabWithName:@"user"];
}

- (IBAction)addDeviceToTab:(id)sender {
    [Bugsnag addAttribute:@"attributeNameDevice" withValue:@"attributeValueDevice" toTabWithName:@"device"];
}

#pragma mark - View lifecycle

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
