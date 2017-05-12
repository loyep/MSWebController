//
//  MSWebController.h
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MSWebView.h"

@interface MSWebController : UIViewController <MSWebViewDelegate>

@property (nonatomic, strong, readonly) MSWebView *webView;

@property (nonatomic, strong, readonly) NSURLRequest *originalRequest;

@property (nonatomic, assign) BOOL useUIWebView;

@property (nonatomic, assign) BOOL networkActivityIndicatorVisible;

@property (nonatomic, assign) BOOL showToolBar;

- (void)loadRequest:(NSURLRequest *)request;

// MARK: MSWebViewDelegate

- (void)webView:(MSWebView *)webView didFailLoadWithError:(NSError *)error;

- (BOOL)webView:(MSWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;

- (void)webViewDidStartLoad:(MSWebView *)webView;

- (void)webViewDidFinishLoad:(MSWebView *)webView;

// MARK: Target actions

- (void)goBackTapped:(UIBarButtonItem *)sender;

- (void)goForwardTapped:(UIBarButtonItem *)sender;

- (void)reloadTapped:(UIBarButtonItem *)sender;

- (void)stopTapped:(UIBarButtonItem *)sender;

- (void)actionButtonTapped:(id)sender;

- (void)doneButtonTapped:(id)sùender;

@end
