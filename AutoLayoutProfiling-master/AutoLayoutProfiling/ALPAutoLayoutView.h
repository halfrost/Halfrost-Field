//
// Created by Florian on 18.04.13.
//


#import <Foundation/Foundation.h>
#import "ALPAutoLayoutTypes.h"


@interface ALPAutoLayoutView : UIView
- (id)initWithFrame:(CGRect)frame type:(ALPLayoutType)aType viewCount:(NSUInteger)aViewCount;
@end