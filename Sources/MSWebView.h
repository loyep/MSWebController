//
//  MSWebView.h
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WKScriptMessageHandler;
@class MSWebView, JSContext;

@protocol MSWebViewDelegate <NSObject>

@optional

- (void)webViewDidStartLoad:(MSWebView *)webView;

- (void)webViewDidFinishLoad:(MSWebView *)webView;

- (void)webView:(MSWebView *)webView didFailLoadWithError:(NSError *)error;

- (BOOL)webView:(MSWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;

@end

@interface MSWebView : UIView

/// init
- (instancetype)initWithFrame:(CGRect)frame usingUIWebView:(BOOL)usingUIWebView;

/// Delegate.
@property (nonatomic, weak) id <MSWebViewDelegate> delegate;

/// realWebView
@property (nonatomic, readonly) id realWebView;
/// Is UIWebView in use?
@property (nonatomic, readonly) BOOL usingUIWebView;
/// Progress
@property (nonatomic, readonly) CGFloat estimatedProgress;

@property (nonatomic, readonly) NSURLRequest *originRequest;

/// UIWebView jsContext. Only usingUIWebView is YES can be used.
@property (nonatomic, readonly) JSContext *jsContext;

/// WKWebView method of interacting with web pages.
- (void)addScriptMessageHandler:(id <WKScriptMessageHandler>)scriptMessageHandler name:(NSString *_Nullable)name;

/// History length.
- (NSInteger)countOfHistory;

- (void)gobackWithStep:(NSInteger)step;

/// The scroll view associated with the web view.
@property (nonatomic, readonly) UIScrollView *scrollView;

/// Default YES.
@property (nonatomic, assign) BOOL allowsBackForwardNavigationGestures;

/// Pan ges for UIWebView.
@property (nonatomic, readonly) UIPanGestureRecognizer *swipePanGesture;

- (id)loadRequest:(NSURLRequest *)request;

- (id)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;

@property (nonatomic, readonly) NSString *title;

@property (nonatomic, readonly) NSURLRequest *currentRequest;

@property (nonatomic, readonly) NSURL *URL;

@property (nonatomic, readonly, getter=isLoading) BOOL loading;

@property (nonatomic, readonly) BOOL canGoBack;

@property (nonatomic, readonly) BOOL canGoForward;

@property (nonatomic, assign) BOOL hideProgress;

@property (nonatomic, readonly) UIProgressView *progressView;

@property (nonatomic, readonly) UILabel *backgroundLabel;

@property (nonatomic, assign) BOOL showsBackgroundLabel;

- (id _Nullable)goBack;

- (id _Nullable)goForward;

- (id _Nullable)reload;

- (id _Nullable)reloadFromOrigin;

- (void)stopLoading;

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ _Nullable)(id, NSError *))completionHandler;

/// This approach is not recommended because the results of webView execution will be waiting internally
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)javaScriptString __deprecated_msg("Method deprecated. Use [evaluateJavaScript:completionHandler:]");

/// Default YES.
@property (nonatomic) BOOL scalesPageToFit;

@end

NS_ASSUME_NONNULL_END
