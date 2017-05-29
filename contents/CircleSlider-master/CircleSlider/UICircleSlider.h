//
//  UICircleSlider.h
//  homer
//
//  Created by yu dezhi on 7/3/16.
//  Copyright (c) 2016 Quatanium Co., Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface UICircleSlider : UIControl
@property (nonatomic) IBInspectable NSInteger currentValue;
@property (nonatomic) IBInspectable double innerCircleRadius;
@property (nonatomic) IBInspectable double outerCircleRadius;
- (void)initUICircleSliderWithTotalNum:(NSInteger)totalNum drawNum:(NSInteger)drawNum startAngle:(double)startAngle numScale:(NSInteger)numScale innerCircleDiameter:(double)innerCircleDiameter;
@end
