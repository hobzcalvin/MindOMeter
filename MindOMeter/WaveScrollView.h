//
//  WaveScrollView.h
//  MindOMeter
//
//  Created by Grant Patterson on 11/30/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WaveScrollView : UIScrollView <UIScrollViewDelegate>

- (id)initWithFrame:(CGRect)frame numScales:(int)numScales scaleFactor:(int)scaleFactor data:d properties:p;
- (void)reset;
- (void)dataStarted;
- (BOOL)trySetScale:(float)s;
- (void)selectedChanged;
- (void)startSizeTimer;
- (void)stopSizeTimer;
- (void)drawWaveLayer:(CALayer *)layer inContext:(CGContextRef)ctx;

@property float scale;

@end
