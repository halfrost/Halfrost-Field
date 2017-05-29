//
// Created by Florian on 18.04.13.
//


#import "ALPNonAutoLayoutView.h"
#import "UIView+Helpers.h"


@implementation ALPNonAutoLayoutView {
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
    UIView* previousView = self;
    for (NSUInteger i = 0; i < viewCount; i++) {
        UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 1, previousView.bounds.size.width, previousView.bounds.size.height-1)];
        [previousView addSubview:view];
        view.backgroundColor = [self randomColor];
        previousView = view;
    }
}

- (void)setupIndependentLayout {
    for (NSUInteger i = 0; i < viewCount; i++) {
        CGFloat x = [self randomNumber] * self.bounds.size.width;
        CGFloat y = [self randomNumber] * self.bounds.size.height;
        UIView* view = [[UIView alloc] initWithFrame:CGRectMake(x, y, 20, 20)];
        [self addSubview:view];
        view.backgroundColor = [self randomColor];
    }
}


@end
