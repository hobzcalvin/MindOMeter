//
//  MindOMeterWaveformer.m
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "MindOMeterWaveformer.h"
#import <QuartzCore/QuartzCore.h>

#define POINTS_PER_SEGMENT 500.0


@interface WaveformerSegment : NSObject
{
	CAShapeLayer *layer;
    CGMutablePathRef rawPath;
    NSMutableArray *data;
	int index;
}


// The layer that this segment is drawing into
@property(nonatomic, readonly) CAShapeLayer *layer;
@property(nonatomic, readonly) CGMutablePathRef rawPath;

@end

UIColor* randomColor() {
    static BOOL seeded = NO;
    if (!seeded) {
        seeded = YES;
        srandom(time(NULL));
    }
    CGFloat red =  (CGFloat)random()/(CGFloat)RAND_MAX;
    CGFloat blue = (CGFloat)random()/(CGFloat)RAND_MAX;
    CGFloat green = (CGFloat)random()/(CGFloat)RAND_MAX;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
}

@implementation WaveformerSegment

@synthesize layer;
@synthesize rawPath;

-(id)initWithData:(NSMutableArray*)d Index:(int)idx
{
	self = [super init];
	if(self != nil)
	{
        data = d;
        index = idx;
        
        rawPath = CGPathCreateMutable();
		layer = [[CAShapeLayer alloc] init];

		// Make upper-left the origin.
        layer.anchorPoint = CGPointMake(0.0, 0.0);
		//layer.bounds = CGRectMake(0.0, 0.0, 0.0 /* addData will increase this over time */, [[UIScreen mainScreen] applicationFrame].size.height);
		// Disable blending as this layer consists of non-transperant content.
		// Unlike UIView, a CALayer defaults to opaque=NO
		layer.opaque = YES;
        
        layer.masksToBounds = YES;

        layer.actions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                         [NSNull null], @"onOrderIn",
                         [NSNull null], @"onOrderOut",
                         [NSNull null], @"sublayers",
                         [NSNull null], @"contents",
                         [NSNull null], @"bounds",
                         [NSNull null], @"frame",
                         [NSNull null], @"position",
                         nil];
    
        //layer.backgroundColor = randomColor().CGColor;
        layer.lineWidth = 1.0;
        layer.strokeColor = [UIColor greenColor].CGColor;
        layer.lineCap = kCALineCapRound;
        layer.lineJoin = kCALineJoinRound;
        layer.fillColor = nil;
    }

	return self;
}


@end



@implementation MindOMeterWaveformer

@synthesize scale;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        data = [[NSMutableArray alloc] init];
        segments = [[NSMutableArray alloc] init];
        [self setContentMode:UIViewContentModeLeft];
        self.layer.anchorPoint = CGPointMake(0, 0);
        [self setScale:1.5];
        self.following = YES;
        
        /*bigTransform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, -500), 1, 3);
        curTransform = CGAffineTransformIdentity;*/
    }
    return self;
}

- (void)updateSize {
    CGSize appSize = [[UIScreen mainScreen] applicationFrame].size;
    UIScrollView *parent = (UIScrollView*)self.superview;
    CGSize curSize = CGSizeMake(/* no longer will this ever be 0? [data count] ? */(float)[data count] * scale/* : 0*/, appSize.height);
    [self setBounds:CGRectMake(0, 0, curSize.width, curSize.height)];
    [parent setContentSize:curSize];
    
    if (curSize.width < appSize.width) {
        // If we've zoomed out so much that more than the waveform fits, turn on following to keep it on the right of the screen.
        self.following = YES;
    }
    
    if (self.following) {
        [parent setContentOffset:CGPointMake(floor(curSize.width - appSize.width), 0)];
    }
//    NSLog(@"UpdSize %@, offset %@", NSStringFromCGSize(curSize), NSStringFromCGPoint(parent.contentOffset));
}

- (void)addData:(int)value {
    //NSLog(@"Adding data %d", value);
    CGSize appSize = [[UIScreen mainScreen] applicationFrame].size;
    // Except the very first point, we always want to finish the line we started with the current data value.
    if ([data count]) {
        WaveformerSegment* lastSegment = (WaveformerSegment*)[segments lastObject];
        // + 1 because we could be drawing the POINTS_PER_SEGMENTth line, which will be at POINTS_PER_SEGMENT position
        int indexWithinSegment = ([data count] - 1) % (int)POINTS_PER_SEGMENT + 1;
        CGPathAddLineToPoint(lastSegment.rawPath, nil, indexWithinSegment, 200.0 + value);
        CGAffineTransform transform = CGAffineTransformMakeScale(scale, 1.0);
        lastSegment.layer.path = CGPathCreateCopyByTransformingPath(lastSegment.rawPath, &transform);
        lastSegment.layer.bounds = CGRectMake(0, 0, (float)indexWithinSegment * scale, appSize.height);
        //lastSegment.layer.frame = CGRectMake(0, 0, indexWithinSegment * scale, [[UIScreen mainScreen] applicationFrame].size.height);
        
//        NSLog(@"AddLine to %d, width %f, data %d, segments %d", indexWithinSegment, (float)indexWithinSegment * scale, [data count], [segments count]);
        [self updateSize];
        
    }
    // If this is the last line in a segment, create the next one.
    if ([segments count] <= [data count] / POINTS_PER_SEGMENT) {
        WaveformerSegment *segment = [[WaveformerSegment alloc] initWithData:data Index:[data count]];
        [self.layer addSublayer:segment.layer];
        segment.layer.frame = CGRectMake([segments count] * POINTS_PER_SEGMENT * scale, 0, 0, appSize.height);
        //segment.layer.position = CGPointMake((float)[segments count] * POINTS_PER_SEGMENT * scale, 0);
        // Just to save the extra line each time; maybe we don't want this?
        segment.layer.needsDisplayOnBoundsChange = YES;
        [segments addObject:segment];
        
        //CGPathMoveToPoint(segment.rawPath, nil, 0, 0);
        //CGPathAddLineToPoint(segment.rawPath, nil, 0, appSize.height);
        CGPathMoveToPoint(segment.rawPath, nil, 0, 200.0 + value);
        /*if ([data count]) {
            CGPathMoveToPoint(segment.rawPath, nil, -1, 200.0 + [(NSNumber*)[data lastObject] doubleValue]);
        } else {
            // If it's the very first data point, we'll draw a useless line to the same point. Oh well.
            CGPathMoveToPoint(segment.rawPath, nil, 0, 200.0 + value);
        }*/
//        NSLog(@"AddSegm %@", NSStringFromCGRect(segment.layer.frame));
    }
    
    // Add to data here so that the count is how we want it (see + 1 note above)
    [data addObject:@(value)];
    
    [(UIScrollView*)self.superview setNeedsDisplay];
    [self setNeedsDisplay];
}

//- (void)setScale:(float)s {
- (BOOL)trySetScale:(float)s {
    if (s > 30) {
        // XXX: This shouldn't be hard-coded; base it on...something...
        return NO;
    }
    float scaleFactor = s / scale;
    scale = s;
    
//    return YES;
    // XXX: You wouldn't think this is threadsafe with addData, but tests suggested it's actually fine.
    
    CGSize appSize = [[UIScreen mainScreen] applicationFrame].size;
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, 1.0);
    for (int i = 0; i < [segments count]; i++) {
        WaveformerSegment* segment = (WaveformerSegment*)segments[i];
        segment.layer.frame = CGRectMake((float)i * POINTS_PER_SEGMENT * scale, 0, POINTS_PER_SEGMENT * scale, appSize.height);
        segment.layer.path = CGPathCreateCopyByTransformingPath(segment.rawPath, &transform);
    }
    
    [self updateSize];
    
    if (!self.following) {
        UIScrollView *parent = (UIScrollView*)self.superview;
        CGPoint offset = [parent contentOffset];
        offset.x = offset.x * scaleFactor + appSize.width / 2 * (scaleFactor - 1);
        [parent setContentOffset:offset];
    }
    
//    NSLog(@"scale now %f", scale);
    return YES;
}

/*- (void)toggleSize {
    if (CGAffineTransformEqualToTransform(curTransform, bigTransform)) {
        curTransform = CGAffineTransformIdentity;
    } else {
        curTransform = bigTransform;
    }
    CGAffineTransform transform = CGAffineTransformScale(curTransform, scale, 1.0);
    for (int i = 0; i < [segments count]; i++) {
        WaveformerSegment* segment = (WaveformerSegment*)segments[i];
    
        CABasicAnimation *theAnimation;
        theAnimation=[CABasicAnimation animationWithKeyPath:@"path"];
        theAnimation.duration=0.5;
        theAnimation.fromValue= (id)segment.layer.path;
        theAnimation.toValue= (id)CFBridgingRelease(CGPathCreateCopyByTransformingPath(segment.rawPath, &transform));
        [segment.layer addAnimation:theAnimation forKey:@"path"];
        
        //segment.layer.path = ;
    }
}*/

/*- (float)scale {
    return _scale;
}*/


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
/*- (void)drawRect:(CGRect)rect
{
//    NSLog(@"WF drawRect: %f,%f %fx%f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    // Drawing code
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
	// Fill in the background
	CGContextSetFillColorWithColor(context, [[UIColor blueColor] CGColor]);
	CGContextFillRect(context, self.bounds);
}*/


    //UIScrollView *parent = (UIScrollView*)self.superview;
    
    // XXX: This will draw the parent's visible bounds constantly, which still isn't necessary.
    //CGRect realRect = CGRectIntersection(rect, [self convertRect:[parent bounds] fromView: parent]);
    //NSLog(@"WF realRect: %@", NSStringFromCGRect(realRect));
/*    if (self.reallyDrawAll) {
        realRect = rect;
    }*/
    
//    NSLog(@"WF drawRect: bounds %@, frame %@, parentbounds %@, parentframe %@", NSStringFromCGRect(myFrame), NSStringFromCGRect(self.frame), NSStringFromCGRect([self convertRect:[parent bounds] fromView: parent]), NSStringFromCGRect([self convertRect:[parent frame] fromView: parent]));
    
    // Set the line width to 10 and inset the rectangle by
    // 5 pixels on all sides to compensate for the wider line.
    /*
    CGContextSetLineWidth(context, 10);
    CGRectInset(myBounds, 5, 5);
    
    [[UIColor redColor] set];
    UIRectFrame(myBounds);
    */
    /*

    CGContextMoveToPoint(context, realRect.origin.x, 200 + [self->data[(int)(realRect.origin.x / self.scale)] floatValue]); //start at this point
    
    CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
    
    // Draw them with a 2.0 stroke width so they are a bit more visible.
    CGContextSetLineWidth(context, 2.0);
    

    for (int i = 1; i < realRect.size.width / self.scale; i++) {
        int idx = (int)(realRect.origin.x / self.scale) + i;
        if (idx >= [self->data count]) {
            NSLog(@"idx %d, size %d, origin %f, scale %f, i %d", idx, [self->data count], realRect.origin.x, self.scale, i);
            continue;
        }
        CGContextAddLineToPoint(context, realRect.origin.x + i * self.scale, 200 + [self->data[idx] floatValue]); //draw to this point
    }
    
    // and now draw the Path!
    CGContextStrokePath(context);
     */

- (float)getDesiredWidth {
    return self.scale * [self->data count];
}


@end
