//
// Created by Florian on 18.04.13.
//


#import "ALPAutoLayoutView.h"
#import "UIView+Helpers.h"


@implementation ALPAutoLayoutView {
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

- (void)setup {
    if (type == ALPLayoutTypeIndependent) {
        [self setupIndependentLayout];
    } else if (type == ALPLayoutTypeChained) {
        [self setupChainedLayout];
    } else if (type == ALPLayoutTypeNested) {
        [self setupNestedLayout];
    }
}

- (void)setupNestedLayout {
    UIView* previousView = self;
    for (NSUInteger i = 0; i < viewCount; i++) {
        UIView* view = [[UIView alloc] init];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [previousView addSubview:view];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeHeight multiplier:1 constant:-1]];
        view.backgroundColor = [self randomColor];
        previousView = view;
    }
}

- (void)setupChainedLayout {
    UIView* previousView = self;
    for (NSUInteger i = 0; i < viewCount; i++) {
        UIView* view = [[UIView alloc] init];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:view];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeTop multiplier:1 constant:1]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20]];
        view.backgroundColor = [self randomColor];
        previousView = view;
    }
}

- (void)setupIndependentLayout {
    for (NSUInteger i = 0; i < viewCount; i++) {
        UIView* view = [[UIView alloc] init];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:view];
        CGFloat x = [self randomNumber] * 2 + 0.0000001;
        CGFloat y = [self randomNumber] * 2 + 0.0000001;
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:x constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:y constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20]];
        view.backgroundColor = [self randomColor];
    }
}

@end
