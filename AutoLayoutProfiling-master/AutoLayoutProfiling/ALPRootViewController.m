//
// Created by Florian on 17.04.13.
//


#import "ALPRootViewController.h"
#import "ALPAutoLayoutView.h"
#import "ALPNonAutoLayoutView.h"
#import <UIView+Yoga.h>
#import "YGLayout.h"

@implementation ALPRootViewController {
    NSUInteger viewCount;
    UILabel* label;
    UIView* container;
    UITextField* textField;
    NSMutableDictionary *_resultDictionary;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupContainer];
    [self addControls];
    
    UIView *view = [[UIView alloc]init];
    view.backgroundColor = [UIColor redColor];
    
    [view configureLayoutWithBlock:^(YGLayout * _Nonnull layout) {
        layout.isEnabled = YES;
        layout.width = 100;
        layout.height = 200;
        layout.marginLeft = 200;
        layout.marginTop = 200;
    }];
    [self.view addSubview:view];
    
    [view.yoga applyLayoutPreservingOrigin:YES];
    
}

- (void)setupContainer {
    container = [[UIView alloc] initWithFrame:CGRectMake(0, 200, self.view.bounds.size.width, self.view.bounds.size.height-200)];
    [self.view addSubview:container];
}

- (void)clearViews {
    [container.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (void)printfResult {
    NSLog(@"_resultDictionary = %@",_resultDictionary);
}
- (void)addControls {
    UIButton* manualIndependentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    manualIndependentButton.frame = CGRectMake(0, 50, 300, 30);
    [manualIndependentButton setTitle:@"用frame方式创建相互无关联的View" forState:UIControlStateNormal];
    [manualIndependentButton addTarget:self action:@selector(addManualIndependent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:manualIndependentButton];

    UIButton* manualNestedButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    manualNestedButton.frame = CGRectMake(0, 80, 300, 30);
    [manualNestedButton setTitle:@"用frame方式创建嵌套的View" forState:UIControlStateNormal];
    [manualNestedButton addTarget:self action:@selector(addManualNested) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:manualNestedButton];

    UIButton* autoLayoutIndependentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    autoLayoutIndependentButton.frame = CGRectMake(0, 110, 300, 30);
    [autoLayoutIndependentButton setTitle:@"用AutoLayout方式创建相互无关联的View" forState:UIControlStateNormal];
    [autoLayoutIndependentButton addTarget:self action:@selector(addAutoLayoutIndependent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:autoLayoutIndependentButton];

    UIButton* autoLayoutChainedButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    autoLayoutChainedButton.frame = CGRectMake(0, 140, 300, 30);
    [autoLayoutChainedButton setTitle:@"用AutoLayout方式创建链式关联的View" forState:UIControlStateNormal];
    [autoLayoutChainedButton addTarget:self action:@selector(addAutoLayoutChained) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:autoLayoutChainedButton];

    UIButton* autoLayoutNestedButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    autoLayoutNestedButton.frame = CGRectMake(0, 170, 300, 30);
    [autoLayoutNestedButton setTitle:@"用AutoLayout方式创建嵌套的View" forState:UIControlStateNormal];
    [autoLayoutNestedButton addTarget:self action:@selector(addAutoLayoutNested) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:autoLayoutNestedButton];

    UIButton* clearButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    clearButton.frame = CGRectMake(300, 50, 200, 30);
    [clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearViews) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearButton];
    
    UIButton* printfButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    printfButton.frame = CGRectMake(300, 80, 200, 30);
    [printfButton setTitle:@"打印结果" forState:UIControlStateNormal];
    [printfButton addTarget:self action:@selector(printfResult) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:printfButton];
    

    label = [[UILabel alloc] initWithFrame:CGRectMake(250, 20, 470, 30)];
    label.text = @"Number of views:";
    [self.view addSubview:label];

    textField = [[UITextField alloc] initWithFrame:CGRectMake(490, 50, 200, 40)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.placeholder = @"输入要创建View的个数";
    [self.view addSubview:textField];
    
    
    _resultDictionary = [[NSMutableDictionary alloc] init];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"AutoLayout"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"NestedAutoLayout"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"ChainedAutoLayout"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"Frame"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"NestedFrame"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"Weex"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"NestedWeex"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"Yoga"];
    [_resultDictionary setObject:[[NSMutableDictionary alloc] init] forKey:@"NestedYoga"];
}

- (void)addAutoLayoutIndependent {
    
    [self clearViews];
    
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self addAutoLayoutView:(ALPLayoutTypeIndependent)];
    
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self calculateTimeWithStartTime:startTime endTime:endTime resultName:@"AutoLayout"];
}

- (void)addAutoLayoutChained {
    
    [self clearViews];
    
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self addAutoLayoutView:(ALPLayoutTypeChained)];
    
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self calculateTimeWithStartTime:startTime endTime:endTime resultName:@"ChainedAutoLayout"];
}

- (void)addAutoLayoutNested {
    
    [self clearViews];
    
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self addAutoLayoutView:(ALPLayoutTypeNested)];
    
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self calculateTimeWithStartTime:startTime endTime:endTime resultName:@"NestedAutoLayout"];
}


- (void)addAutoLayoutView:(ALPLayoutType)type {
    CGSize size = self.view.bounds.size;
    viewCount = (NSUInteger) [textField.text intValue];
    ALPAutoLayoutView* autoLayoutView = [[ALPAutoLayoutView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) type:type viewCount:viewCount];
    [container addSubview:autoLayoutView];
}

- (void)addManualIndependent {
    
    for (int i = 0; i < 1000; i ++) {
        
        [self clearViews];
        
        NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
        
        [self addNonAutoLayoutView:(ALPLayoutTypeIndependent)];
        
        NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
        
        [self calculateTimeWithStartTime:startTime endTime:endTime resultName:@"Frame"];
    }
    
}

- (void)addManualNested {
    
    [self clearViews];
    
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self addNonAutoLayoutView:(ALPLayoutTypeNested)];
    
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self calculateTimeWithStartTime:startTime endTime:endTime resultName:@"NestedFrame"];
}

- (void)addNonAutoLayoutView:(ALPLayoutType)type {
    
    CGSize size = self.view.bounds.size;
    viewCount = (NSUInteger) [textField.text intValue];
    ALPNonAutoLayoutView* nonAutoLayoutView = [[ALPNonAutoLayoutView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) type:type viewCount:viewCount];
    [container addSubview:nonAutoLayoutView];
}

- (void)calculateTimeWithStartTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime resultName:(NSString *)resultName {
    
    NSTimeInterval timeInterval = endTime - startTime;
    
    NSMutableDictionary *autoLayoutDictionary = _resultDictionary[resultName];
    NSMutableDictionary *currentTimesDictionary = autoLayoutDictionary[@(viewCount)] ?: [[NSMutableDictionary alloc] init];
    NSNumber *times = currentTimesDictionary[@"times"] ? : @0;
    NSNumber *avgTime = currentTimesDictionary[@"avgTime"] ? : @0;
    currentTimesDictionary[@"avgTime"] = @((times.integerValue * avgTime.doubleValue + timeInterval) / (double)(times.integerValue + 1));
    currentTimesDictionary[@"times"] = @(times.integerValue + 1);
    [autoLayoutDictionary setObject:currentTimesDictionary forKey:@(viewCount)];
    
    label.text = [NSString stringWithFormat:@"Number of views: %ld | Time: %f | avgTime: %f", (long)viewCount, endTime-startTime,[currentTimesDictionary[@"avgTime"] floatValue]];
    
}


@end
