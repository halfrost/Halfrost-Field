//
//  ViewController.m
//  TestMultiXCConfig
//
//  Created by apple on 16-7-20.
//  Copyright (c) 2016年 boyce. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"name = %@",[self readValueFromConfigurationFile]);
}



- (NSString *) readValueFromConfigurationFile {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:@"Configuration" ofType:@"plist"];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
    return config[@"name"];
}


@end
