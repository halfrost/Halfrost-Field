//
//  ALPYogaLayoutView.h
//  AutoLayoutProfiling
//
//  Created by YDZ on 2017/4/2.
//  Copyright © 2017年 YDZ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ALPAutoLayoutTypes.h"

@interface ALPYogaLayoutView : UIView
- (id)initWithFrame:(CGRect)frame type:(ALPLayoutType)aType viewCount:(NSUInteger)aViewCount;
@end
