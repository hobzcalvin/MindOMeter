//
//  MindOMeterMainViewController.m
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "MindOMeterMainViewController.h"
#import "TGAccessoryManager.h"
#import "WaveScrollView.h"

#define DATA_SCALES 5
#define SCALE_FACTOR 2
#define REDUCE_USING_MINMAX
#define DEMO_BAR_HEIGHT 20
#define DATA_TIMEOUT_BG (5 * 60) // Wait in background before giving up on the data.
#define DATA_TIMEOUT_FG (2 * 60) // Wait if app is active and data stops.
#define DATA_TIMEOUT_FIRST 8     // Wait if the accessory connects but no data comes in. (Bug somewhere; not our fault.)

@interface MindOMeterMainViewController () {
    IBOutlet UIView *mainView;
    WaveScrollView *scroller;
    UILabel* demoLabel;
    NSTimer* demoTimer;
    NSTimer* realDataTimeout;
    NSMutableArray* values;
    NSMutableArray* reducingValues;
    NSDictionary* waveProperties;
    NSArray* waveOrder;
    boolean_t ignoreData;
}

@end

@implementation MindOMeterMainViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    ignoreData = NO;
    
    waveProperties = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"WaveProperties" ofType:@"plist"]];
    waveOrder = [waveProperties keysSortedByValueUsingComparator:^(id obj1, id obj2) {
        return [obj1[@"index"] compare:obj2[@"index"]];
    }];
    
    values = [[NSMutableArray alloc] init];
    reducingValues = [[NSMutableArray alloc] init];
    for (int i = 0; i < DATA_SCALES; i++) {
        values[i] = [[NSMutableArray alloc] init];
    }

    scroller = [[WaveScrollView alloc] initWithFrame:[mainView bounds] numScales:DATA_SCALES scaleFactor:SCALE_FACTOR data:values properties:waveProperties];
    scroller.autoresizingMask = mainView.autoresizingMask;
    [mainView insertSubview:scroller atIndex:0];
    
    demoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, mainView.bounds.size.width, DEMO_BAR_HEIGHT)];
    demoLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    demoLabel.text = @"⚠ Demo mode - Check Bluetooth connection";
    demoLabel.textColor = [UIColor redColor];
    demoLabel.backgroundColor = [UIColor blackColor];
    demoLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    demoLabel.textAlignment = NSTextAlignmentCenter;
    demoLabel.hidden = YES;
    [mainView addSubview:demoLabel];
    
    demoTimer = nil;
    
    if (![[TGAccessoryManager sharedTGAccessoryManager] accessory]) {
        [self startDemo];
    }
}

- (void)clearData {
    for (int i = 0; i < DATA_SCALES; i++) {
        [values[i] removeAllObjects];
    }
    for (NSString* key in [waveProperties allKeys]) {
        if (waveProperties[key][@"dynamic"] == @YES) {
            [waveProperties[key] removeObjectForKey:@"min"];
            [waveProperties[key] removeObjectForKey:@"max"];
        }
    }
    [scroller reset];
}

- (void)startDemo {
    CGRect bounds = mainView.bounds;
    bounds.origin.y += demoLabel.bounds.size.height;
    bounds.size.height -= demoLabel.bounds.size.height;
    scroller.frame = bounds;
    demoLabel.hidden = NO;
    
    [self stopRealDataTimeout];
    [self clearData];
    ignoreData = NO;
    demoTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(addData:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:demoTimer forMode:NSRunLoopCommonModes];
}

- (void)stopDemo {
    if (!demoTimer) {
        // We never started the demo; do nothing.
        return;
    }
    [demoTimer invalidate];
    demoTimer = nil;
    scroller.frame = mainView.bounds;
    demoLabel.hidden = YES;
    [self clearData];
}

- (void)startRealDataTimeout:(float)seconds {
    if (realDataTimeout) {
        [realDataTimeout invalidate];
    }
    realDataTimeout = [NSTimer timerWithTimeInterval:seconds target:self selector:@selector(realDataTimeoutFunc) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:realDataTimeout forMode:NSRunLoopCommonModes];
}
- (void)stopRealDataTimeout {
    if (realDataTimeout) {
        [realDataTimeout invalidate];
        realDataTimeout = nil;
    }
}
- (void)realDataTimeoutFunc {
    realDataTimeout = nil;
    [self stopStream];
    [self clearData];
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        [self startDemo];
    }
}

- (void)stopStream {
    ignoreData = YES;
    [[TGAccessoryManager sharedTGAccessoryManager] stopStream];
}
- (void)startStream {
    ignoreData = NO;
    if (![TGAccessoryManager sharedTGAccessoryManager].accessory || [TGAccessoryManager sharedTGAccessoryManager].connected) {
        NSLog(@"XXX: startStream, accessory %p, connected %d", [TGAccessoryManager sharedTGAccessoryManager].accessory, [TGAccessoryManager sharedTGAccessoryManager].connected);
    }
    [[TGAccessoryManager sharedTGAccessoryManager] startStream];
    [self startRealDataTimeout:DATA_TIMEOUT_FIRST];
}

// XXX: Does all this this really need to happen on main? Maybe it'd offload graphics processing to move it to the receiver thread.
// On the other hand, we need to stop the realDataTimeout on the same thread we started it on...
- (void)dataReceivedMain:(NSDictionary *)data {
    //NSLog(@"dataMain");
    if (!ignoreData && data[@"eSenseMeditation"] != nil) {
        if (!demoTimer) {
            [self startRealDataTimeout:([UIApplication sharedApplication].applicationState == UIApplicationStateBackground ? DATA_TIMEOUT_BG : DATA_TIMEOUT_FG)];
        }
            
        NSMutableDictionary* finalData = [data mutableCopy];
        finalData[@"time"] = @(CACurrentMediaTime());
        
        for (NSString* key in finalData) {
            if (waveProperties[key][@"dynamic"] == @YES) {
                if (!waveProperties[key][@"min"] ||
                    // XXX: Are these all really unsigned ints? should they be?
                    [waveProperties[key][@"min"] unsignedIntValue] > [finalData[key] unsignedIntValue]) {
                    waveProperties[key][@"min"] = finalData[key];
                }
                if (!waveProperties[key][@"max"] ||
                    // XXX: Are these all really unsigned ints? should they be?
                    [waveProperties[key][@"max"] unsignedIntValue] < [finalData[key] unsignedIntValue]) {
                    waveProperties[key][@"max"] = finalData[key];
                }
            }
        }

        if (![values[0] count]) {
            [scroller dataStarted];
        }
        
        [values[0] addObject:finalData];
        [self updateDataScale:1];
    }
}

- (boolean_t)firstCloserToMinOrMax:(unsigned int)first second:(unsigned int)second key:(NSString*)key {
    unsigned int min = [waveProperties[key][@"min"] unsignedIntValue];
    unsigned int max = [waveProperties[key][@"max"] unsignedIntValue];

    return MIN(first - min, max - first) < MIN(second - min, max - second);
}

- (void)updateDataScale:(int)scale {
    int subIndex = [values[scale - 1] count] % SCALE_FACTOR;
    NSMutableDictionary* latest = [values[scale - 1] lastObject];
    NSMutableDictionary* reducingValue;
    if (subIndex == 1) {
        reducingValue = [[NSMutableDictionary alloc] init];
        reducingValue[@"time"] = latest[@"time"];
        reducingValues[scale - 1] = reducingValue;
    } else {
        reducingValue = reducingValues[scale - 1];
    }
    for (NSString* key in latest) {
        if ([key isEqualToString:@"time"]) {
            continue;
        }
#ifdef REDUCE_USING_MINMAX
        id oldValue = [reducingValue valueForKey:key];
        if (oldValue == nil ||
            [self firstCloserToMinOrMax:[latest[key] unsignedIntValue] second:[oldValue unsignedIntValue] key:key]) {
            reducingValue[key] = latest[key];
        }
        
#else // Reduce using average.
        // Add the new data value divided by SCALE_FACTOR.
        reducingValue[key] = @([reducingValue[key] doubleValue] + [latest[key] doubleValue] / (double)SCALE_FACTOR);
#endif
    }
    if (subIndex == 0) {
        [values[scale] addObject:reducingValue];
        if (scale + 1 < DATA_SCALES) {
            // We've collected SCALE_FACTOR data points and found their average. Update the next scale level.
            [self updateDataScale:scale + 1];
        }
    }
}

- (void)dataReceived:(NSDictionary *)data {
    [self performSelectorOnMainThread:@selector(dataReceivedMain:) withObject:data waitUntilDone:NO];
}

- (void)accessoryDidConnect:(EAAccessory *)accessory {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground ||
        [[NSUserDefaults standardUserDefaults] boolForKey:@"runInBackground"]) {
        [self stopDemo];
        [self startStream];
    }
}
- (void)accessoryDidDisconnect {
    // If the connected accessory stopped working, we started a demo instead.
    if (!demoTimer) {
        [self stopStream];
    }
}


- (void)addData:(NSTimer*)theTimer {
    NSDictionary* dict = @{
    @"eSenseMeditation" : @(arc4random_uniform(100)),
    @"eSenseAttention" : @(arc4random_uniform(100)),
    @"eegDelta" : @(arc4random()),
    @"eegHighAlpha" : @(arc4random()),
    @"eegHighBeta" : @(arc4random()),
    @"eegHighGamma" : @(arc4random()),
    @"eegLowAlpha" : @(arc4random()),
    @"eegLowBeta" : @(arc4random()),
    @"eegLowGamma" : @(arc4random()),
    @"eegTheta" : @(arc4random()),
    @"poorSignal" : @(arc4random_uniform(200)),
    };
    [self dataReceivedMain:[NSMutableDictionary dictionaryWithDictionary:dict]];
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [scroller stopSizeTimer];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    [scroller startSizeTimer];
}

- (UIView *)rotatingHeaderView {
    return mainView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    if (orientation == UIInterfaceOrientationPortraitUpsideDown &&
        [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return NO;
    }
    
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Application State Changes

- (void)willResignActive {
    [scroller stopSizeTimer];
}
- (void)didBecomeActive {
    // It'll make sure it has a baseTime before it actually starts anything.
    [scroller startSizeTimer];
}
- (void)willEnterForeground {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"runInBackground"]) {
        if ([TGAccessoryManager sharedTGAccessoryManager].accessory) {
            // We've theoretically been collecting data and can continue to do so.
            // But just make sure things are as they should be.
            if (![TGAccessoryManager sharedTGAccessoryManager].connected) {
                NSLog(@"XXX: willEnterForeground, accessory %p but connected %d", [TGAccessoryManager sharedTGAccessoryManager].accessory, [TGAccessoryManager sharedTGAccessoryManager].connected);
                [self startStream];
            }
        } else if (realDataTimeout) {
            // We're waiting for a data timeout; make it short now that we're back in front of the user.
            [self startRealDataTimeout:DATA_TIMEOUT_FG];
        } else {
            // No headset in sight; start demo.
            [self startDemo];
        }
    } else {
        if ([TGAccessoryManager sharedTGAccessoryManager].accessory) {
            // We have a headset, but were ignoring it while in background. Pretend it just reconnected.
            // XXX: This ought to look exactly like accessoryDidConnect, but we won't register as in the foreground yet.
            [self startStream];
        } else {
            // No headset at all. Demo.
            [self startDemo];
        }
    }
}
- (void)didEnterBackground {
    if (demoTimer) {
        [self stopDemo];
    } else {
        // We've been logging real data.
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"runInBackground"]) {
            // Just keep running in background. Switch to the long timeout.
            [self startRealDataTimeout:DATA_TIMEOUT_BG];
        } else {
            [self stopStream];
            [self clearData];
        }
    }
}
- (void)willTerminate {
    
}


#pragma mark - Flipside View Controller

- (void)flipsideViewControllerDidFinish:(MindOMeterFlipsideViewController *)controller
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    }
    [scroller selectedChanged];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.flipsidePopoverController = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
        [(MindOMeterFlipsideViewController*)[segue destinationViewController] setWaveProperties:waveProperties];
        [(MindOMeterFlipsideViewController*)[segue destinationViewController] setWaveOrder:waveOrder];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            UIPopoverController *popoverController = [(UIStoryboardPopoverSegue *)segue popoverController];
            self.flipsidePopoverController = popoverController;
            popoverController.delegate = self;
        }
    }
}

- (IBAction)togglePopover:(id)sender
{
    if (self.flipsidePopoverController) {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    } else {
        [self performSegueWithIdentifier:@"showAlternate" sender:sender];
    }
}



- (void)viewDidUnload {
    scroller = nil;
    mainView = nil;
    [super viewDidUnload];
}
@end





/*
 
 
 UNNECESSARY FANCY ROTATION STUFF
 
 rotatingHeaderView is good enough for us.
 
 
 @interface UIApplication (AppDimensions)
 +(CGSize) currentSize;
 +(CGSize) sizeInOrientation:(UIInterfaceOrientation)orientation;
 @end
 
 @implementation UIApplication (AppDimensions)
 
 +(CGSize) currentSize
 {
 return [UIApplication sizeInOrientation:[UIApplication sharedApplication].statusBarOrientation];
 }
 +(CGSize) sizeInOrientation:(UIInterfaceOrientation)orientation
 {
 CGSize size = [UIScreen mainScreen].bounds.size;
 UIApplication *application = [UIApplication sharedApplication];
 if (UIInterfaceOrientationIsLandscape(orientation))
 {
 size = CGSizeMake(size.height, size.width);
 }
 if (application.statusBarHidden == NO)
 {
 size.height -= MIN(application.statusBarFrame.size.width, application.statusBarFrame.size.height);
 }
 return size;
 }
 
 @end
 
 
 - (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
 [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
 
 NSLog(@"size now: %@ size next: %@", NSStringFromCGSize([UIApplication currentSize]), NSStringFromCGSize([UIApplication sizeInOrientation:toInterfaceOrientation]));
 CGSize now = [UIApplication currentSize];
 CGSize next = [UIApplication sizeInOrientation:toInterfaceOrientation];
 
 //mainView.transform = CGAffineTransformIdentity;
 //scroller.transform = CGAffineTransformMakeScale(next.width / now.width, next.height / now.height);
 //rotationTransform = CGAffineTransformMakeScale(now.width / next.width, now.height / next.height);//CGAffineTransformMakeScale(1, 2);
 //scroller.transform = CGAffineTransformConcat(mainView.transform, rotationTransform);
 
 //mainView.transform = rotationTransform;
 NSLog(@"willrotate, scroller trans %@, main trans %@", NSStringFromCGAffineTransform(scroller.transform), NSStringFromCGAffineTransform(mainView.transform));
 }
 
 - (void)viewWillLayoutSubviews {
 //scroller.transform = CGAffineTransformConcat(scroller.transform, CGAffineTransformInvert(rotationTransform));
 //mainView.transform = CGAffineTransformConcat(mainView.transform, rotationTransform);
 NSLog(@"willlayout, scroller trans %@, main trans %@", NSStringFromCGAffineTransform(scroller.transform), NSStringFromCGAffineTransform(mainView.transform));
 
 [super viewWillLayoutSubviews];
 }
 
 - (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 
 CGSize now = [UIApplication currentSize];
 //NSLog(@"size now: %@", NSStringFromCGSize(now));
 
 NSLog(@"didlayout, scroller trans %@, main trans %@", NSStringFromCGAffineTransform(scroller.transform), NSStringFromCGAffineTransform(mainView.transform));
 
 //mainView.transform = CGAffineTransformConcat(mainView.transform, rotationTransform);
 //mainView.transform = rotationTransform;//CGAffineTransformInvert(rotationTransform);//CGAffineTransformMakeScale(1, 0.5);//rotationTransform;
 }
 
 - (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
 [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
 
 NSLog(@"willanim, scroller trans %@, main trans %@", NSStringFromCGAffineTransform(scroller.transform), NSStringFromCGAffineTransform(mainView.transform));
 //    mainView.transform = CGAffineTransformConcat(mainView.transform, CGAffineTransformInvert(rotationTransform));
 //  rotationTransform = CGAffineTransformIdentity;
 //NSLog(@"size now: %@ size next: %@", NSStringFromCGSize([UIApplication currentSize]), NSStringFromCGSize([UIApplication sizeInOrientation:interfaceOrientation]));
 //scroller.transform = CGAffineTransformInvert(rotationTransform);
 //rotationTransform = CGAffineTransformIdentity;
 //CGAffineTransformMakeRotation(M_PI / 2);
 }
 
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
 NSLog(@"didrotate, scroller trans %@, main trans %@", NSStringFromCGAffineTransform(scroller.transform), NSStringFromCGAffineTransform(mainView.transform));
 
 }*/
