//
//  ALPWeexLayoutView.m
//  AutoLayoutProfiling
//
//  Created by YDZ on 2017/4/2.
//  Copyright © 2017年 YDZ. All rights reserved.
//

#import "ALPWeexLayoutView.h"
#import "UIView+Helpers.h"

@implementation ALPWeexLayoutView {
    ALPLayoutType type;
    NSUInteger viewCount;
}

- (id)initWithFrame:(CGRect)frame type:(ALPLayoutType)aType viewCount:(NSUInteger)aViewCount {
    self = [super initWithFrame:frame];
    if (self) {
        type = aType;
        viewCount = aViewCount;
        [self setup];
    }
    return self;
}

- (void)layoutSubviews {
}


- (void)setup {
    if (type == ALPLayoutTypeIndependent) {
        [self setupIndependentLayout];
    } else if (type == ALPLayoutTypeNested) {
        [self setupNestedLayout];
    }
}

- (void)setupNestedLayout {
//    UIView* previousView = self;
//    for (NSUInteger i = 0; i < viewCount; i++) {
//        
//        
//        UIView *view = [[UIView alloc]init];
//        [view configureLayoutWithBlock:^(YGLayout * _Nonnull layout) {
//            layout.isEnabled = YES;
//            layout.width = previousView.bounds.size.width;
//            layout.height = previousView.bounds.size.height-1;
//            layout.marginLeft = 0;
//            layout.marginTop = 1;
//        }];
//        [previousView addSubview:view];
//        [view.yoga applyLayoutPreservingOrigin:YES];
//        view.backgroundColor = [self randomColor];
//        previousView = view;
//    }
    
}

- (void)setupIndependentLayout {
//    for (NSUInteger i = 0; i < viewCount; i++) {
//        CGFloat x = [self randomNumber] * self.bounds.size.width;
//        CGFloat y = [self randomNumber] * self.bounds.size.height;
//        
//        UIView *view = [[UIView alloc]init];
//        [view configureLayoutWithBlock:^(YGLayout * _Nonnull layout) {
//            layout.isEnabled = YES;
//            layout.width = 20;
//            layout.height = 20;
//            layout.marginLeft = x;
//            layout.marginTop = y;
//        }];
//        [self addSubview:view];
//        [view.yoga applyLayoutPreservingOrigin:YES];
//        view.backgroundColor = [self randomColor];
//    }
}

@end
