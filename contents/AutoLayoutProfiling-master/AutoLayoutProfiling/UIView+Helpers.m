//
// Created by Florian on 18.04.13.
//


#import "UIView+Helpers.h"


@implementation UIView (Helpers)

- (CGFloat)randomNumber {
    return (arc4random() % 1000) / 1000.0;
}

- (UIColor*)randomColor {
    CGFloat hue = (arc4random() % 256 / 256.0);
    return [UIColor colorWithHue:hue saturation:1 brightness:1 alpha:1];
}

@end