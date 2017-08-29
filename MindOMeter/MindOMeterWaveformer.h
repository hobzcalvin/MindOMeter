//
//  MindOMeterWaveformer.h
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WaveformerSegment;
@interface MindOMeterWaveformer : UIView {
    @public NSMutableArray *data;
	NSMutableArray *segments;
    /*CGAffineTransform curTransform;
    CGAffineTransform bigTransform;*/
}

- (void)addData:(int)value;
- (BOOL)trySetScale:(float)s;
//- (void)toggleSize;
- (float)getDesiredWidth;

@property float scale;
@property BOOL following;


@end
