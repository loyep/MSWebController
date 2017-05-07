//
//  MSWebController.m
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "MSWebController.h"

@interface MSWebController ()

@property (nonatomic, strong, readwrite) MSWebView *webView;

@end

@implementation MSWebController

- (void)loadView {
    [super loadView];
    
    self.webView = [[MSWebView alloc] initWithFrame:self.view.bounds usingUIWebView:self.useUIWebView];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.webView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://baidu.com"]]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.webView.frame = self.view.bounds;
    
    UIEdgeInsets insets = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, 0, 0);
    self.webView.scrollView.contentInset = insets;
    self.webView.scrollView.scrollIndicatorInsets = insets;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
