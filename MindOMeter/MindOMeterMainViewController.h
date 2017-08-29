//
//  MindOMeterMainViewController.h
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "MindOMeterFlipsideViewController.h"
#import "TGAccessoryDelegate.h"

@interface MindOMeterMainViewController : UIViewController <MindOMeterFlipsideViewControllerDelegate, UIPopoverControllerDelegate, UIScrollViewDelegate, TGAccessoryDelegate> {
}

@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;

- (void)dataReceived:(NSDictionary *)data;
- (void)accessoryDidConnect:(EAAccessory *)accessory;
- (void)accessoryDidDisconnect;
- (void)willResignActive;
- (void)didBecomeActive;
- (void)willEnterForeground;
- (void)didEnterBackground;
- (void)willTerminate;

@end
