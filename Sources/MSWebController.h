//
//  MSWebController.h
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MSWebView.h"

//#define MSWebController() [NSBundle bundleWithURL:[[NSBundle bundleForClass:[MSWebController class]] URLForResource:@"MSWebController" withExtension:@"bundle"]]

@interface MSWebController : UIViewController <MSWebViewDelegate>

@property (nonatomic, strong, readonly) MSWebView *webView;

@property (nonatomic, assign) BOOL useUIWebView;

@property (nonatomic, assign) BOOL networkActivityIndicatorVisible;

- (void)loadRequest:(NSURLRequest *)request;

#pragma mark - MSWebViewDelegate

- (void)webView:(MSWebView *)webView didFailLoadWithError:(NSError *)error;

- (BOOL)webView:(MSWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;

- (void)webViewDidStartLoad:(MSWebView *)webView;

- (void)webViewDidFinishLoad:(MSWebView *)webView;

#pragma mark - Target actions

- (void)goBackTapped:(UIBarButtonItem *)sender;

- (void)goForwardTapped:(UIBarButtonItem *)sender;

- (void)reloadTapped:(UIBarButtonItem *)sender;

- (void)stopTapped:(UIBarButtonItem *)sender;

- (void)actionButtonTapped:(id)sender;

- (void)doneButtonTapped:(id)sùender;

@end
