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

///无缝切换UIWebView   会根据系统版本自动选择 使用WKWebView 还是UIWebView
@interface MSWebView : UIView

///使用UIWebView
- (instancetype)initWithFrame:(CGRect)frame usingUIWebView:(BOOL)usingUIWebView;

///会转接 WKUIDelegate，WKNavigationDelegate 内部未实现的回调。
@property (nonatomic, weak) id <MSWebViewDelegate> delegate;

///内部使用的webView
@property (nonatomic, readonly) id realWebView;
///是否正在使用 UIWebView
@property (nonatomic, readonly) BOOL usingUIWebView;
///预估网页加载进度
@property (nonatomic, readonly) CGFloat estimatedProgress;

@property (nonatomic, readonly) NSURLRequest *originRequest;

///只有ios7以上的UIWebView才能获取到，WKWebView 请使用下面的方法.
@property (nonatomic, readonly) JSContext *jsContext;

///WKWebView 跟网页进行交互的方法。
- (void)addScriptMessageHandler:(id <WKScriptMessageHandler>)scriptMessageHandler name:(NSString * _Nullable)name;

///back 层数
- (NSInteger)countOfHistory;

- (void)gobackWithStep:(NSInteger)step;

///---- UI 或者 WK 的API
@property (nonatomic, readonly) UIScrollView *scrollView;

- (id)loadRequest:(NSURLRequest *)request;

- (id)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;

@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly) NSURLRequest *currentRequest;
@property (nonatomic, readonly) NSURL *URL;

@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;

@property (nonatomic, assign) BOOL showProgressView;
@property (nonatomic, strong) UIColor *progressColor;

- (id _Nullable)goBack;

- (id _Nullable)goForward;

- (id _Nullable)reload;

- (id _Nullable)reloadFromOrigin;

- (void)stopLoading;

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ _Nullable)(id, NSError *))completionHandler;

///不建议使用这个办法  因为会在内部等待webView 的执行结果
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)javaScriptString __deprecated_msg("Method deprecated. Use [evaluateJavaScript:completionHandler:]");

///是否根据视图大小来缩放页面  默认为YES
@property (nonatomic) BOOL scalesPageToFit;

@end

NS_ASSUME_NONNULL_END
