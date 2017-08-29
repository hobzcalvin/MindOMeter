//
//  MindOMeterFlipsideViewController.h
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MindOMeterFlipsideViewController;

@protocol MindOMeterFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(MindOMeterFlipsideViewController *)controller;
@end

@interface MindOMeterFlipsideViewController : UIViewController

@property (weak, nonatomic) id <MindOMeterFlipsideViewControllerDelegate> delegate;
@property (weak, nonatomic) NSDictionary* waveProperties;
@property (weak, nonatomic) NSArray* waveOrder;

- (IBAction)done:(id)sender;

@end
