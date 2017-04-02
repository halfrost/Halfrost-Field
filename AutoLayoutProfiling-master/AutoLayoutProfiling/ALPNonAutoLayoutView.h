//
// Created by Florian on 18.04.13.
//


#import <Foundation/Foundation.h>
#import "ALPAutoLayoutTypes.h"

@interface ALPNonAutoLayoutView : UIView
- (id)initWithFrame:(CGRect)frame type:(ALPLayoutType)aType viewCount:(NSUInteger)aViewCount;
@end