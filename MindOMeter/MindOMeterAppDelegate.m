//
//  MindOMeterAppDelegate.m
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "MindOMeterAppDelegate.h"
#import "MindOMeterMainViewController.h"
#import "TGAccessoryManager.h"
#import <objc/runtime.h>

#define UPDATE_URL @"http://selfobserved.org/ios-data.php?version=1.0"


@implementation MindOMeterAppDelegate {
    MindOMeterMainViewController* mainView;
}

// XXX: Could any of this stuff go in application:willFinishLaunchingWithOptions: instead?
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
    
    TGAccessoryManager *tgam = [TGAccessoryManager sharedTGAccessoryManager];
    mainView = (MindOMeterMainViewController*)self.window.rootViewController;
    [tgam setDelegate:mainView];
    [tgam setupManagerWithInterval:0.05];
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    [mainView willResignActive];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [mainView didEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

    [mainView willEnterForeground];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    [mainView didBecomeActive];
    
    // Dispatch a thread to check on new messages
    [NSThread detachNewThreadSelector:@selector(doURLActions) toTarget:self withObject:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [mainView willTerminate];
    [[TGAccessoryManager sharedTGAccessoryManager] teardownManager];
}

#pragma mark Phone-Home

- (void)doURLActions {
    NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:UPDATE_URL]];
    if (!data) {
        return;
    }
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    if (!dict) {
        return;
    }
    NSArray* alerts = dict[@"alerts"];
    if (!alerts || ![alerts count]) {
        return;
    }
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray* shownAlerts = [[defaults arrayForKey:@"shownAlerts"] mutableCopy];
    if (!shownAlerts) {
        shownAlerts = [[NSMutableArray alloc] init];
    }
    
    for (NSDictionary* alert in alerts) {
        if (![shownAlerts containsObject:alert[@"id"]]) {
            // Remember that we've shown (or ignored) this alert.
            [shownAlerts addObject:alert[@"id"]];
            [defaults setObject:shownAlerts forKey:@"shownAlerts"];
            [defaults synchronize];
            
            // Don't show the alert unless it's last in the list OR it's specified to be definitely shown.
            if (alert == [alerts lastObject] || [alert[@"showIfNotLast"] boolValue]) {
                // Update UI in main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:alert[@"title"] message:alert[@"body"] delegate:self cancelButtonTitle:alert[@"cancelButton"] otherButtonTitles:alert[@"urlButton"], nil];
                    if (alert[@"urlButton"] && alert[@"url"]) {
                        objc_setAssociatedObject(alertView, "url", [NSURL URLWithString:alert[@"url"]], OBJC_ASSOCIATION_RETAIN);
                    }
                    [alertView show];
                });
                
                // Only show one alert per call of this function.
                break;
            }
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSURL* url = objc_getAssociatedObject(alertView, "url");
        if (url) {
            // I don't know much about weak/strong/atomic, but somebody did this to make sure things weren't leaked.
            objc_setAssociatedObject(alertView, "url", nil, OBJC_ASSOCIATION_RETAIN);
            
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}


@end
