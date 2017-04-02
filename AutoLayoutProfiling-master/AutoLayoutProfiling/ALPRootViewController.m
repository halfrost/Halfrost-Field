//
// Created by Florian on 17.04.13.
//


#import "ALPRootViewController.h"
#import "ALPAutoLayoutView.h"
#import "ALPNonAutoLayoutView.h"

@implementation ALPRootViewController {
    NSUInteger viewCount;
    UILabel* label;
    UIView* container;
    UITextField* textField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupContainer];
    [self addControls];
}

- (void)setupContainer {
    container = [[UIView alloc] initWithFrame:CGRectMake(0, 200, self.view.bounds.size.width, self.view.bounds.size.height-200)];
    [self.view addSubview:container];
}

- (void)clearViews {
    [container.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (void)addControls {
    UIButton* manualIndependentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    manualIndependentButton.frame = CGRectMake(0, 0, 200, 30);
    [manualIndependentButton setTitle:@"Manual Independent" forState:UIControlStateNormal];
    [manualIndependentButton addTarget:self action:@selector(addManualIndependent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:manualIndependentButton];

    UIButton* manualNestedButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    manualNestedButton.frame = CGRectMake(0, 30, 200, 30);
    [manualNestedButton setTitle:@"Manual Nested" forState:UIControlStateNormal];
    [manualNestedButton addTarget:self action:@selector(addManualNested) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:manualNestedButton];

    UIButton* autoLayoutIndependentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    autoLayoutIndependentButton.frame = CGRectMake(0, 60, 200, 30);
    [autoLayoutIndependentButton setTitle:@"AutoLayout Independent" forState:UIControlStateNormal];
    [autoLayoutIndependentButton addTarget:self action:@selector(addAutoLayoutIndependent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:autoLayoutIndependentButton];

    UIButton* autoLayoutChainedButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    autoLayoutChainedButton.frame = CGRectMake(0, 90, 200, 30);
    [autoLayoutChainedButton setTitle:@"AutoLayout Chained" forState:UIControlStateNormal];
    [autoLayoutChainedButton addTarget:self action:@selector(addAutoLayoutChained) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:autoLayoutChainedButton];

    UIButton* autoLayoutNestedButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    autoLayoutNestedButton.frame = CGRectMake(0, 120, 200, 30);
    [autoLayoutNestedButton setTitle:@"AutoLayout Nested" forState:UIControlStateNormal];
    [autoLayoutNestedButton addTarget:self action:@selector(addAutoLayoutNested) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:autoLayoutNestedButton];

    UIButton* clearButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    clearButton.frame = CGRectMake(0, 150, 200, 30);
    [clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearViews) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearButton];

    label = [[UILabel alloc] initWithFrame:CGRectMake(300, 10, 170, 30)];
    label.text = @"Number of views:";
    [self.view addSubview:label];

    textField = [[UITextField alloc] initWithFrame:CGRectMake(490, 0, 100, 40)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:textField];
}

- (void)addAutoLayoutIndependent {
    [self addAutoLayoutView:(ALPLayoutTypeIndependent)];
}

- (void)addAutoLayoutChained {
    [self addAutoLayoutView:(ALPLayoutTypeChained)];
}

- (void)addAutoLayoutNested {
    [self addAutoLayoutView:(ALPLayoutTypeNested)];
}


- (void)addAutoLayoutView:(ALPLayoutType)type {
    CGSize size = self.view.bounds.size;
    viewCount = (NSUInteger) [textField.text intValue];
    ALPAutoLayoutView* autoLayoutView = [[ALPAutoLayoutView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) type:type viewCount:viewCount];
    [container addSubview:autoLayoutView];
}

- (void)addManualIndependent {
    [self addNonAutoLayoutView:(ALPLayoutTypeIndependent)];
}

- (void)addManualNested {
    [self addNonAutoLayoutView:(ALPLayoutTypeNested)];
}

- (void)addNonAutoLayoutView:(ALPLayoutType)type {
    CGSize size = self.view.bounds.size;
    viewCount = (NSUInteger) [textField.text intValue];
    ALPNonAutoLayoutView* nonAutoLayoutView = [[ALPNonAutoLayoutView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) type:type viewCount:viewCount];
    [container addSubview:nonAutoLayoutView];
}


@end