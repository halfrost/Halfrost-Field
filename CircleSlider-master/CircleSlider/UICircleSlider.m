//
//  UICircleSlider.m
//  homer
//
//  Created by yu dezhi on 7/3/16.
//  Copyright (c) 2016 Quatanium Co., Ltd. All rights reserved.
//

#import "UICircleSlider.h"
#import "AppDelegate.h"

#define TOP_BAR_COLOR           [UIColor colorWithRed:217.0 / 255.0 green:160.0 / 255.0 blue:85.0 / 255.0 alpha:1.0]
#define BORDER_BG_COLOR         [UIColor colorWithRed:216.0 / 255.0 green:216.0 / 255.0 blue:216.0 / 255.0 alpha:1.0]

@interface UICircleSlider()
@property (nonatomic) NSInteger totalNum;
@property (nonatomic) NSInteger drawNum;
@property (nonatomic) NSInteger startNum;
@property (nonatomic) NSInteger endNum;
//@property (nonatomic) double innerCircleRadius;
//@property (nonatomic) double outerCircleRadius;
@property (nonatomic) NSInteger numScale;
@property (nonatomic) double intervalRadians;
@end

@implementation UICircleSlider

- (id)init
{
    self = [super init];
    if (self)
        [self setup];
    return  self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
        [self setup];
    return  self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
        [self setup];
    return  self;
}

- (void)setup
{
    [self initUICircleSliderWithTotalNum:288   // The number of total lines
                                 drawNum:100   // The number of displaying lines
                              startAngle:145   // The number of degrees to start drawing
                                numScale:2     // The number of space to skip when drawing lines
                     innerCircleDiameter:215]; // The number of pixels for diameter
}

- (void)initUICircleSliderWithTotalNum:(NSInteger)totalNum drawNum:(NSInteger)drawNum startAngle:(double)startAngle numScale:(NSInteger)numScale innerCircleDiameter:(double)innerCircleDiameter
{
    self.totalNum = totalNum;
    self.drawNum = drawNum;
    // The interval between each displayed line
    self.intervalRadians = 2.0 * M_PI / self.totalNum;
    // Draw start point, offset 1 for space
    self.startNum = startAngle / 360.0 * self.totalNum + 1;
    self.numScale = numScale;
    // Draw end point, offset 1 countering start point
    self.endNum = self.startNum - 1 + self.drawNum * self.numScale;
    self.innerCircleRadius = innerCircleDiameter / 2.0;
    self.outerCircleRadius = self.frame.size.height / 2.0;
}

- (void)setCurrentValue:(NSInteger)currentValue
{
    _currentValue = currentValue;
    // Refresh graphics
    [self setNeedsDisplay];
}

#pragma mark - UIControl Override -

/** Tracking starts **/
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [super beginTrackingWithTouch:touch withEvent:event];
    
    // Get touch location
    CGPoint lastPoint = [touch locationInView:self];
    // Use the location to design the handle
    [self moveHandle:lastPoint];
    
    // We need to track continuously
    return YES;
}

/** Tracking continues touch events **/
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [super continueTrackingWithTouch:touch withEvent:event];
    
    // Get touch location
    CGPoint lastPoint = [touch locationInView:self];
    // Use the location to design the handle
    [self moveHandle:lastPoint];
    // Control value has changed, should notify listener this event
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
    return YES;
}

/** Tracking finishes **/
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [super endTrackingWithTouch:touch withEvent:event];
    
    // Control value has changed, should notify listener for final event
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

/** Tracking canceled **/
- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [super cancelTrackingWithEvent:event];
    
    // Control value has changed, should notify listener for final event
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)moveHandle:(CGPoint)lastPoint
{
    // Get the center point first
    CGPoint centerPoint = CGPointMake(self.frame.size.width / 2.0, self.frame.size.height / 2.0);
    
    // Calculate the number from a center point to the current location
    NSInteger angleInt = round(radianFromNorth(centerPoint, lastPoint, NO) / self.intervalRadians) + 1;
    
    // Check direction to draw
    NSInteger currentNum = angleInt < self.startNum ? angleInt + self.totalNum : angleInt;
    if (currentNum >= self.startNum && currentNum <= self.endNum)
        // Store the new angle
        self.currentValue = round((double)(currentNum - self.startNum) / self.numScale);
}

- (CGPoint)pointOnCircleWithAngle:(NSInteger)angle onInnerOrOuterCircle:(double)r
{
    return CGPointMake(self.frame.size.width / 2.0 + r * cos(self.intervalRadians * angle), self.frame.size.height / 2.0 + r * sin(self.intervalRadians * angle));
}

- (void)drawRect:(CGRect)rect
{
    CGPoint point;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.8);
    
    // Draw past the end number to fill to 100
    for (NSInteger i = self.startNum; i <= self.endNum; i += self.numScale) {
        CGContextSetStrokeColorWithColor(ctx, (i < self.startNum + self.currentValue * self.numScale ? TOP_BAR_COLOR : BORDER_BG_COLOR).CGColor);
        point = [self pointOnCircleWithAngle:i onInnerOrOuterCircle:self.outerCircleRadius];
        CGContextMoveToPoint(ctx, point.x, point.y);
        point = [self pointOnCircleWithAngle:i onInnerOrOuterCircle:self.innerCircleRadius];
        CGContextAddLineToPoint(ctx, point.x, point.y);
        CGContextStrokePath(ctx);
    }
}

// Source code from Apple example ClockControl
// Calculate the direction in radians from a center point to an arbitrary position.
static inline double radianFromNorth(CGPoint p1, CGPoint p2, BOOL flipped)
{
    CGPoint v = CGPointMake(p2.x - p1.x, p2.y - p1.y);
    float vmag = sqrt(v.x * v.x + v.y * v.y);
    v.x /= vmag;
    v.y /= vmag;
    double radians = atan2(v.y, v.x);
    return radians >= 0 ? radians : radians + 2.0 * M_PI;
}

// Prevent touch event transmit to nextResponder
- (UIResponder *)nextResponder
{
    return nil;
}

@end
