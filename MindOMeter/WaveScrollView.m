//
//  WaveScrollView.m
//  MindOMeter
//
//  Created by Grant Patterson on 11/30/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "WaveScrollView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#define SCALE_INITIAL 30
#define PATH_SECONDS 7
#define TIME_GRAY 0.75
#define TIME_BAR_HEIGHT 15
#define PIXELS_PER_VALUE_MIN 2
#define PIXELS_PER_VALUE_MAX 60

void removeAnimations(CALayer* layer) {
    layer.actions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                     [NSNull null], @"onOrderIn",
                     [NSNull null], @"onOrderOut",
                     [NSNull null], @"sublayers",
                     [NSNull null], @"contents",
                     [NSNull null], @"bounds",
                     [NSNull null], @"frame",
                     [NSNull null], @"position",
                     nil];
}

NSString* formatSeconds(CFTimeInterval s) {
    int seconds = floorf(s);
    int hours = seconds / 3600;
    int minutes = (seconds / 60) % 60;
    seconds = seconds % 60;
    
    if (hours) {
        return [NSString stringWithFormat:@"%d:%d:%02d", hours, minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    }
}

@interface WaveLayerDelegate : NSObject
- (id)initWithScrollView:(id)scrollView;
- (void)drawLayer:(CALayer*)layer inContext:(CGContextRef)ctx;
@end

@implementation WaveLayerDelegate {
    WaveScrollView* wsv;
}
- (id)initWithScrollView:(id)scrollView {
    self = [super init];
    if (self) {
        wsv = scrollView;
    }
    return self;
}
- (void)drawLayer:(CALayer*)layer inContext:(CGContextRef)ctx {
    [wsv drawWaveLayer:layer inContext:ctx];
}
@end

@implementation WaveScrollView {
    BOOL following;
    NSMutableArray* values;
    NSDictionary* waveProperties;
    CFTimeInterval baseTime;
    CALayer* backgroundLayer;
    WaveLayerDelegate* waveLayerDelegate;
    CALayer* waveLayer;
    CAShapeLayer* topSepLayer;
    CAShapeLayer* botSepLayer;
    CATextLayer* curTimeLayer;
    CAGradientLayer* curTimeFader;
    NSMutableArray* timeLabels;
    CAShapeLayer* gridLayer;
    int pointLeft;
    int pointRight;
    CGMutablePathRef curPath;
    NSArray* selectedWaves;
    float waveHeight;
    NSTimer* sizeTimer;
    NSTimer* curTimeTimer;
    int curTimeWidth;
    int gridWidthIndex;
    int dataScale;
    int numDataScales;
    int dataScaleFactor;
    boolean_t iPadRetina;
}
static const int WaveScrollView_gridWidths[] = { 5, 10, 15, 30, 60, 2*60, 5*60, 10*60, 15*60, 30*60, 60*60 };

@synthesize scale;

- (id)initWithFrame:(CGRect)frame numScales:(int)numScales scaleFactor:(int)scaleFactor data:d properties:p {
    self = [super initWithFrame:frame];
    if (self) {
        values = d;
        numDataScales = numScales;
        waveProperties = p;
        
        // iPad with Retina has too many pixels to handle all of this; we tweak a few (surprising) things to make it relatively smooth.
        // scale also appears in earlier versions of iOS to not indicate retina, but we only support iOS5+.
        iPadRetina = ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
                      [[UIScreen mainScreen] scale] == 2.00 &&
                      [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
        
        scale = SCALE_INITIAL; // pixels per second
        gridWidthIndex = 0; // seconds between grid lines
        dataScale = 0;
        dataScaleFactor = scaleFactor;
        
        waveHeight = 0;
        sizeTimer = nil;
        
        [self setDelegate:self];
        
        UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
                                                  initWithTarget:self action:@selector(handlePinchGesture:)];
        [self addGestureRecognizer:pinchGesture];

        backgroundLayer = [[CALayer alloc] init];
        [self.layer addSublayer:backgroundLayer];
        backgroundLayer.frame = self.bounds;
        backgroundLayer.opaque = YES;
        if (!iPadRetina) {
            backgroundLayer.rasterizationScale = [[UIScreen mainScreen] scale];
        }
        backgroundLayer.shouldRasterize = YES;
        removeAnimations(backgroundLayer);
        
        topSepLayer = [[CAShapeLayer alloc] init];
        topSepLayer.opaque = YES;
        topSepLayer.lineWidth = 1;
        topSepLayer.strokeColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
        
        botSepLayer = [[CAShapeLayer alloc] init];
        botSepLayer.opaque = YES;
        botSepLayer.lineWidth = 1;
        botSepLayer.strokeColor = [UIColor colorWithWhite:0 alpha:0.2].CGColor;
        
        [self refreshBackground];
        
        curTimeFader = [[CAGradientLayer alloc] init];
        //curTimeFader.opaque = YES;
        //curTimeFader.backgroundColor = [UIColor redColor].CGColor;
        curTimeFader.startPoint = CGPointMake(0, 0.5);
        curTimeFader.endPoint = CGPointMake(TIME_BAR_HEIGHT * 2 / self.bounds.size.width, 0.5);
        curTimeFader.colors = @[(id)[UIColor colorWithWhite:0 alpha:0].CGColor, (id)[UIColor colorWithWhite:0 alpha:1].CGColor];
        //curTimeFader.colors = @[(id)[UIColor redColor].CGColor, (id)[UIColor greenColor].CGColor];
        [self.layer addSublayer:curTimeFader];
        removeAnimations(curTimeFader);
        
        curTimeLayer = [self setupTimeLabel];
        [self.layer addSublayer:curTimeLayer];
        
        timeLabels = [[NSMutableArray alloc] init];
        
        gridLayer = [[CAShapeLayer alloc] init];
        [self.layer addSublayer:gridLayer];
        gridLayer.strokeColor = [UIColor colorWithWhite:0 alpha:0.4].CGColor;
        gridLayer.fillColor = nil;
        gridLayer.lineWidth = 1.5;
        removeAnimations(gridLayer);
        
        waveLayer = [[CALayer alloc] init];
        [self.layer addSublayer:waveLayer];
        waveLayerDelegate = [[WaveLayerDelegate alloc] initWithScrollView:self];
        waveLayer.delegate = waveLayerDelegate;
        waveLayer.anchorPoint = CGPointMake(0.0, 0.0);
        waveLayer.frame = self.bounds;
        waveLayer.opaque = YES;
        waveLayer.masksToBounds = YES;
        /*waveLayer.lineWidth = 1.0;
        waveLayer.strokeColor = [UIColor colorWithWhite:0.9 alpha:1].CGColor;
        waveLayer.lineCap = kCALineCapRound;
        waveLayer.lineJoin = kCALineJoinRound;
        waveLayer.fillColor = nil;*/
        //waveLayer.contentsScale /= 2;
        removeAnimations(waveLayer);
        //waveLayer.hidden = YES;
        
        [self reset];
    }
    return self;
}

- (void)reset {
    [self stopSizeTimer];
    [curTimeTimer invalidate];
    curTimeTimer = nil;
    baseTime = 0;
    following = YES;
    pointLeft = 0;
    pointRight = 0;
    curPath = NULL;
    //waveLayer.path = NULL;
    curTimeLayer.string = formatSeconds(0);
    curTimeWidth = ([curTimeLayer.string length] - 1) * TIME_BAR_HEIGHT;
    self.contentSize = CGSizeZero;
    self.contentOffset = CGPointMake(-1 * self.bounds.size.width, 0);

    [self setNeedsLayout];
}

- (CATextLayer*)setupTimeLabel {
    CATextLayer* layer = [[CATextLayer alloc] init];
    layer.string = @"0:00";
    layer.font = CFBridgingRetain(@"Helvetica-Bold");
    layer.fontSize = TIME_BAR_HEIGHT;
    layer.foregroundColor = [UIColor colorWithWhite:TIME_GRAY alpha:1].CGColor;
    // For some reason this causes the buffer not to refresh, bleeding old versions.
    //layer.opaque = YES;
    layer.masksToBounds = YES;
    layer.backgroundColor = [UIColor blackColor].CGColor;
    if (!iPadRetina) {
        layer.contentsScale = [[UIScreen mainScreen] scale];
    }
    layer.alignmentMode = kCAAlignmentRight;
    removeAnimations(layer);
    
    return layer;
}

- (CATextLayer*)getTimeLabelAtIndex:(int)i {
    while (i >= [timeLabels count]) {
        CATextLayer* layer = [self setupTimeLabel];
        [self.layer insertSublayer:layer below:curTimeFader];
        [timeLabels addObject:layer];
    }
    return timeLabels[i];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!CGSizeEqualToSize(self.bounds.size, waveLayer.bounds.size)) {
        // Because we were resized, our contentOffset (if < 0) was reset to 0. Fix this in case we're following.
        if (following) {
            self.contentOffset = CGPointMake(self.contentSize.width - self.bounds.size.width, 0);
        }
        // The background needs to be redone.
        [self refreshBackground];
        // Make sure we redraw the waveform.
        curPath = NULL;
    }
    
    // These layers should always cover the entire screen.
    // XXX: These should actually be TIME_BAR_HEIGHT shorter, but the correctness isn't worth the math.
    backgroundLayer.frame = self.bounds;
    waveLayer.frame = self.bounds;
    gridLayer.frame = self.bounds;
    
    // This jitters due to rounding errors on the simulator, but not on my phone.
    curTimeLayer.frame = CGRectMake(self.contentSize.width - curTimeWidth, self.bounds.size.height - TIME_BAR_HEIGHT, curTimeWidth, TIME_BAR_HEIGHT);
    // Add 1 to width because sometimes labels below peek through
    curTimeFader.frame = CGRectMake(self.contentSize.width - curTimeWidth - TIME_BAR_HEIGHT * 2, self.bounds.size.height - TIME_BAR_HEIGHT, self.bounds.size.width, TIME_BAR_HEIGHT);
    curTimeFader.endPoint = CGPointMake(TIME_BAR_HEIGHT * 2 / self.bounds.size.width, 0.5);

    CGMutablePathRef gridPath = CGPathCreateMutable();
    int j = 0;
    for (float i = ceilf((self.contentOffset.x - curTimeWidth) / (WaveScrollView_gridWidths[gridWidthIndex] * scale)) * (WaveScrollView_gridWidths[gridWidthIndex] * scale) - self.contentOffset.x;
         i < self.bounds.size.width + curTimeWidth;
         i += WaveScrollView_gridWidths[gridWidthIndex] * scale) {
        // XXX: A float rounding issue I don't entirely understand causes i to be e.g. 149.999999 and contentOffset.x -150, making the 0 test case here fail. So, hackily fix it for now.
        if (i + self.contentOffset.x < -0.1) {
            continue;
        }
        CGPathMoveToPoint(gridPath, nil, i, 0);
        CGPathAddLineToPoint(gridPath, nil, i, self.bounds.size.height - TIME_BAR_HEIGHT);
        
        
        // TODO: These flicker sometimes, as if either the gridWidthIndex is flicking back and forth (don't think so; would've seen that) or something else weird is placing these funny. Or they're displaying before we're done moving them all. Or...
        // ALSO, remember how the 0:00 didn't appear when you rotated to landscape! Fix that...
        CATextLayer* timeLabel = [self getTimeLabelAtIndex:j];
        timeLabel.hidden = NO;
        // Round this because sometimes it isn't quite as intended, and we need the formatter to floor its input.
        timeLabel.string = formatSeconds(roundf((i + self.contentOffset.x) / scale));
        timeLabel.frame = CGRectMake(self.contentOffset.x + i - curTimeWidth, self.bounds.size.height - TIME_BAR_HEIGHT, curTimeWidth, TIME_BAR_HEIGHT);
        // Put this here because we don't want j incremented in the continue case.
        j++;
    }
    for (; j < [timeLabels count]; j++) {
        [(CATextLayer*)timeLabels[j] setHidden:YES];
    }
    gridLayer.path = gridPath;
}

- (void)drawWaveLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    CGContextSetStrokeColorWithColor(ctx, [UIColor greenColor].CGColor);
    
    CGContextMoveToPoint(ctx, 100, 100);
    CGContextAddLineToPoint(ctx, 400, 400);
    CGContextStrokePath(ctx);
    
    NSLog(@"drew");
}

/*
    // We need 2 values to draw any data at all.
    int dataCount = [values[dataScale] count];
    if (dataCount < 2) {
        return;
    }
    
    // Due to data scale changes, these may be way off. Make sure they're within bounds.
    pointLeft = MAX(0, MIN(pointLeft, dataCount - 1));
    pointRight = MAX(0, MIN(pointRight, dataCount - 1));
    
    int desiredLeft = pointLeft;
    int desiredRight = pointRight;
    
    for (int i = pointLeft + 1; i < [values[dataScale] count]; i++) {
        if ([values[dataScale][i][@"time"] floatValue] - baseTime < self.contentOffset.x / scale) {
            desiredLeft = i;
        } else {
            break;
        }
    }
    if (desiredLeft == pointLeft) {
        for (int i = pointLeft; i >= 0; i--) {
            if ([values[dataScale][i][@"time"] floatValue] - baseTime > self.contentOffset.x / scale
                && i - 1 >= 0) {
                desiredLeft = i - 1;
            } else {
                break;
            }
        }
    }
    for (int i = pointRight; i < [values[dataScale] count]; i++) {
        if ([values[dataScale][i][@"time"] floatValue] - baseTime < (self.contentOffset.x + self.bounds.size.width) / scale
            && i + 1 < [values[dataScale] count]) {
            desiredRight = i + 1;
        } else {
            break;
        }
    }
    if (desiredRight == pointRight) {
        for (int i = pointRight - 1; i >= 0; i--) {
            if ([values[dataScale][i][@"time"] floatValue] - baseTime > (self.contentOffset.x + self.bounds.size.width) / scale) {
                desiredRight = i;
            } else {
                break;
            }
        }
    }
    
    if (desiredLeft != pointLeft || desiredRight != pointRight || !curPath) {
        [self refreshPathWithLeft:desiredLeft right:desiredRight];
    }
    
    CGAffineTransform transform = CGAffineTransformMake(scale, 0, 0, 1, -1 * self.contentOffset.x, 0);
    //waveLayer.path = CGPathCreateCopyByTransformingPath(curPath, &transform);
}
 */

- (void)dataStarted {
    baseTime = CACurrentMediaTime();
    [self startSizeTimer];
    curTimeTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(updateCurTime) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:curTimeTimer forMode:NSRunLoopCommonModes];
}

- (void)updateCurTime {
    curTimeLayer.string = formatSeconds(CACurrentMediaTime() - baseTime);
    if ([curTimeLayer.string length] * TIME_BAR_HEIGHT - TIME_BAR_HEIGHT > curTimeWidth) {
        curTimeWidth = [curTimeLayer.string length] * TIME_BAR_HEIGHT - TIME_BAR_HEIGHT;
        [self setNeedsLayout];
    }
}

- (void)startSizeTimer {
    // Don't overlap with another timer, and only run a timer if we've gotten some data and have a baseTime.
    if (!sizeTimer && baseTime) {
        sizeTimer = [NSTimer timerWithTimeInterval:0.01 target:self selector:@selector(updateSize) userInfo:nil repeats:YES];
        // TODO: NSRunLoopCommonModes means the timer will fire during (scroll) tracking, but as-is it causes weirdness, probably related to following.
        [[NSRunLoop currentRunLoop] addTimer:sizeTimer forMode:NSDefaultRunLoopMode];//NSRunLoopCommonModes];
    }
}

- (void)stopSizeTimer {
    if (sizeTimer) {
        [sizeTimer invalidate];
        sizeTimer = nil;
    }
}

- (void)updateSize {
    // Assumes baseTime has been set (see startSizeTimer).
    
    self.contentSize = CGSizeMake((CACurrentMediaTime() - baseTime) * scale, self.bounds.size.height);
    if (following) {
        self.contentOffset = CGPointMake(self.contentSize.width - self.bounds.size.width, 0);
    }
}

- (void)selectedChanged {
    [self refreshBackground];
    // In certain cases (not following) the layout won't be updated otherwise.
    [self refreshPathWithLeft:pointLeft right:pointRight];
    [self setNeedsLayout];
}

- (void)refreshBackground {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    selectedWaves = [defaults arrayForKey:@"selectedWaves"];

    waveHeight = (self.bounds.size.height - TIME_BAR_HEIGHT) / [selectedWaves count];
    
    backgroundLayer.sublayers = nil;
    float width = self.bounds.size.width;
    NSArray* gradient = @[(id)[UIColor colorWithWhite:1 alpha:0.1].CGColor, (id)[UIColor colorWithWhite:0 alpha:0.1].CGColor];
    CGMutablePathRef topSepPath = CGPathCreateMutable();
    CGMutablePathRef botSepPath = CGPathCreateMutable();
    
    float i = 0;
    for (NSString* name in selectedWaves) {
        CAGradientLayer* layer = [[CAGradientLayer alloc] init];
        layer.opaque = YES;
        layer.backgroundColor = [UIColor colorWithHue: [waveProperties[name][@"hue"] floatValue]
                                           saturation: [waveProperties[name][@"sat"] floatValue]
                                           brightness: 0.3
                                                alpha: 1].CGColor;
        layer.masksToBounds = YES;
        layer.colors = gradient;
        [backgroundLayer addSublayer:layer];
        layer.frame = CGRectMake(0, i * waveHeight, width, waveHeight);
        
        CGPathMoveToPoint(topSepPath, nil, 0, i * waveHeight + 0.5);
        CGPathAddLineToPoint(topSepPath, nil, width, i * waveHeight + 0.5);
        CGPathMoveToPoint(botSepPath, nil, 0, (i + 1) * waveHeight - 0.5);
        CGPathAddLineToPoint(botSepPath, nil, width, (i + 1) * waveHeight - 0.5);
        
        //CALayer* text = [[CALayer alloc] init];
        CATextLayer* text = [[CATextLayer alloc] init];
        text.string = waveProperties[name][@"label"];
        text.foregroundColor = [UIColor blackColor].CGColor;
        text.opacity = 0.4;
        text.masksToBounds = YES;
        //text.backgroundColor = [UIColor blueColor].CGColor;
        text.contentsScale = [[UIScreen mainScreen] scale];
        text.font = CFBridgingRetain(@"Cochin-Bold");//@"Helvetica-Bold");
        text.fontSize = waveHeight - (i == [selectedWaves count] - 1 ? 5 : 0);
        text.shadowColor = [UIColor whiteColor].CGColor;
        text.shadowOffset = CGSizeMake(0.0, 1.0);
        text.shadowOpacity = 0.3;
        text.shadowRadius = 0.5;
        [layer addSublayer:text];
        text.frame = CGRectMake(13.0 + [waveProperties[name][@"labelXOff"] floatValue], -3.0 + [waveProperties[name][@"labelYOff"] floatValue], width, waveHeight * 2);
        
        i++;
    }
    topSepLayer.path = topSepPath;
    botSepLayer.path = botSepPath;
    // XXX: Silly to add these every time.
    [backgroundLayer addSublayer:topSepLayer];
    [backgroundLayer addSublayer:botSepLayer];
}


- (void)refreshPathWithLeft:(int)left right:(int)right {
    int dataCount = [values[dataScale] count];
    // We need 2 values to draw any lines at all.
    if (dataCount < 2) {
        return;
    }
    
    curPath = CGPathCreateMutable();
    
    // TODO: This can probably be sped up using tricks like just adding new needed points, hacking the CGPathRef ourselves, etc.
    for (int i = 0; i < [selectedWaves count]; i++) {
        NSString* name = selectedWaves[i];
        // XXX: Are floats really the right thing for all this crazy scaling math? ints might be fine, at least until one of the last steps.
        float min = [waveProperties[name][@"min"] floatValue];
        float max = [waveProperties[name][@"max"] floatValue];
        for (int j = left; j <= right; j++) {
            (j == left ? CGPathMoveToPoint : CGPathAddLineToPoint)(curPath, nil, [values[dataScale][j][@"time"] floatValue] - baseTime,
                                                                   ((([values[dataScale][j][name] floatValue] - min) * (4.0 - waveHeight)) / (max - min)) +
                                                                   (float)(i + 1) * waveHeight - 2.0);
        }
    }
    
    pointLeft = left;
    pointRight = right;
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)sender {
    if ([sender state] == UIGestureRecognizerStateChanged ||
        [sender state] == UIGestureRecognizerStateEnded) {
        [self trySetScale:scale * sender.scale];
        sender.scale = 1;
    }
}

//- (void)setScale:(float)s {
- (BOOL)trySetScale:(float)s {
    if (s > PIXELS_PER_VALUE_MAX || s < PIXELS_PER_VALUE_MIN / powf(dataScaleFactor, numDataScales - 1)) {
        return NO;
    }
    float scaleFactor = s / scale;
    scale = s;
    while (scale * WaveScrollView_gridWidths[gridWidthIndex] <= 75 && gridWidthIndex + 1 < sizeof(WaveScrollView_gridWidths) / sizeof(int)) {
        gridWidthIndex++;
    }
    while (scale * WaveScrollView_gridWidths[gridWidthIndex] > 150 && gridWidthIndex > 0) {
        gridWidthIndex--;
    }
    
    while (powf(dataScaleFactor, dataScale) * scale <= PIXELS_PER_VALUE_MIN && dataScale + 1 < numDataScales) {
        dataScale++;
        // Approximate new left/right points (only a guess; they'll be recalculated).
        pointLeft /= dataScaleFactor;
        pointRight /= dataScaleFactor;
        // Force redraw of the waveform.
        curPath = NULL;
    }
    while (powf(dataScaleFactor, dataScale) * scale > PIXELS_PER_VALUE_MIN * dataScaleFactor && dataScale > 0) {
        dataScale--;
        // Approximate new left/right points (only a guess; they'll be recalculated).
        pointLeft *= dataScaleFactor;
        pointRight *= dataScaleFactor;
        // Force redraw of the waveform.
        curPath = NULL;
    }
    
    if (!following) {
        float newOff = self.contentOffset.x * scaleFactor + self.bounds.size.width / 2 * (scaleFactor - 1);
        // XXX: It'd be nice if it only turned following on when the pinch stops, but for some reason I can't get it to stay over on the left using manual placement. Conflicting placement elsewhere?
        if (newOff < 0) {
            if (self.contentSize.width * scaleFactor > self.bounds.size.width) {
                // XXX TODO: A value between 0 and -0.1 (it should be 0) causes the framerate to plummet. Why??? So, hackily, do this.
                newOff = -1;
            } else {
                following = YES;
            }
        }
        if (!following) {
            self.contentOffset = CGPointMake(newOff, 0);
        }
    }

    [self updateSize];

    return YES;
}


BOOL bounceRight(UIScrollView *scrollView) {
    return scrollView.contentOffset.x > scrollView.contentSize.width - scrollView.frame.size.width + scrollView.contentInset.right;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.decelerating && !following && bounceRight(scrollView)) {
        following = YES;
    }
}

// User stops dragging the table view.

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if(!following && bounceRight(scrollView)) {
        following = YES;
    } else if (following) {
        following = NO;
    }
}

// Control slows to a halt after the user drags it

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if(!following && bounceRight(scrollView)) {
        following = YES;
    }
}


@end
