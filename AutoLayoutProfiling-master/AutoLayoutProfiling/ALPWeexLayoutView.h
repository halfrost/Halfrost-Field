//
//  ALPWeexLayoutView.h
//  AutoLayoutProfiling
//
//  Created by YDZ on 2017/4/2.
//  Copyright © 2017年 YDZ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ALPAutoLayoutTypes.h"

@interface ALPWeexLayoutView : UIView
- (id)initWithFrame:(CGRect)frame type:(ALPLayoutType)aType viewCount:(NSUInteger)aViewCount;
@end
