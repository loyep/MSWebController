//
//  MSWebView.m
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "MSWebView.h"
#import "MS_NJKWebViewProgress.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "MSWebActivity.h"
#import "MSWebHTTPCookieStorage.h"

static BOOL canUseWkWebView = NO;
static BOOL canUseWKWebsiteDataStore = NO;

const NSString *JSFuncString =
@"function setCookie(name,value,expires)\
{\
var oDate=new Date();\
oDate.setDate(oDate.getDate()+expires);\
document.cookie=name+'='+value+';expires='+oDate;\
}\
function getCookie(name)\
{\
var arr = document.cookie.match(new RegExp('(^| )'+name+'=([^;]*)(;|$)'));\
if(arr != null) return unescape(arr[2]); return null;\
}\
function delCookie(name)\
{\
var exp = new Date();\
exp.setTime(exp.getTime() - 1);\
var cval=getCookie(name);\
if(cval!=null) document.cookie= name + '='+cval+';expires='+exp.toGMTString();\
}";

NS_INLINE NSString *MSGenerateJSSentence(NSArray <NSHTTPCookie *>* cookies) {
    // Piece together JS strings
    NSMutableString *JSCookieString = [JSFuncString mutableCopy];
    for (NSHTTPCookie *cookie in cookies) {
        NSString *excuteJSString = [NSString stringWithFormat:@"setCookie('%@', '%@', 1);", cookie.name, cookie.value];
        [JSCookieString appendString:excuteJSString];
    }
    return JSCookieString;
}

static CGFloat swipeDistance = 100;

@interface MSWebView () <UIWebViewDelegate, WKNavigationDelegate, WKUIDelegate, MS_NJKWebViewProgressDelegate, NSURLSessionDelegate>

@property (nonatomic, assign) CGFloat estimatedProgress;

@property (nonatomic, strong, readwrite) UIProgressView *progressView;

@property (nonatomic, strong, readwrite) NSURLRequest *originRequest;

@property (nonatomic, strong, readwrite) NSURLRequest *currentRequest;

@property (nonatomic, copy, readwrite) NSString *title;

@property (nonatomic, strong) MS_NJKWebViewProgress *njkWebViewProgress;

/// Left pan ges.
@property (nonatomic, strong, readwrite) UIPanGestureRecognizer *swipePanGesture;

@property (nonatomic, assign) BOOL isSwipingBack;

@property (nonatomic, strong, readwrite) UILabel *backgroundLabel;

@property (nonatomic, strong) UIImageView *swipeBackArrow;

@property (nonatomic, strong) UIImageView *swipeForwardArrow;

@end

@implementation MSWebView

@synthesize usingUIWebView = _usingUIWebView;
@synthesize realWebView = _realWebView;
@synthesize scalesPageToFit = _scalesPageToFit;
@synthesize originRequest = _originRequest;

+ (void)load {
    canUseWkWebView = (NSClassFromString(@"WKWebView") != nil);
    canUseWKWebsiteDataStore = (NSClassFromString(@"WKWebsiteDataStore") != nil);
}

// MARK: initialize

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame usingUIWebView:NO];
}

- (instancetype)initWithFrame:(CGRect)frame usingUIWebView:(BOOL)usingUIWebView {
    self = [super initWithFrame:frame];
    if (self) {
        _usingUIWebView = usingUIWebView;
        [self initialize];
    }
    return self;
}

- (void)initialize {
    if (canUseWkWebView && self.usingUIWebView == NO) {
        [self initWKWebView];
        _usingUIWebView = NO;
    } else {
        [self initUIWebView];
        _usingUIWebView = YES;
    }
    
    self.allowsBackForwardNavigationGestures = YES;
    self.showsBackgroundLabel = YES;
    self.scalesPageToFit = YES;
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
    // Set auto layout enabled.
    [(UIWebView *) self.realWebView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    [self.realWebView setFrame:self.bounds];
    [self.realWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self addSubview:self.realWebView];
    
    // Add web view.
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_realWebView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_realWebView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_realWebView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_realWebView)]];
    
    // Add label and constraints.
    UIView *contentView = self.scrollView.subviews.firstObject;
    [contentView addSubview:self.backgroundLabel];
    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_backgroundLabel(<=width)]" options:0 metrics:@{@"width": @([UIScreen mainScreen].bounds.size.width)} views:NSDictionaryOfVariableBindings(_backgroundLabel)]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:_backgroundLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:_backgroundLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1.0 constant:-20]];
    
    // Add progressView and constraints.
    self.progressView = [[UIProgressView alloc] init];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.progressView];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_progressView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_progressView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_progressView(==2)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_progressView)]];
}

- (UILabel *)backgroundLabel {
    if (_backgroundLabel) return _backgroundLabel;
    _backgroundLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _backgroundLabel.textColor = [UIColor colorWithRed:0.322 green:0.322 blue:0.322 alpha:1.00];
    _backgroundLabel.font = [UIFont systemFontOfSize:12];
    _backgroundLabel.numberOfLines = 0;
    _backgroundLabel.textAlignment = NSTextAlignmentCenter;
    _backgroundLabel.backgroundColor = [UIColor clearColor];
    _backgroundLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_backgroundLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    _backgroundLabel.hidden = !self.showsBackgroundLabel;
    return _backgroundLabel;
}

- (void)setAllowsBackForwardNavigationGestures:(BOOL)allowsBackForwardNavigationGestures {
    _allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures;
    
    if (_usingUIWebView) {
        self.swipePanGesture.enabled = self.allowsBackForwardNavigationGestures;
    } else {
        [(WKWebView *) self.realWebView setAllowsBackForwardNavigationGestures:self.allowsBackForwardNavigationGestures];
    }
}

// MARK: initWKWebView

- (void)initWKWebView {
    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    NSMutableString *cookies = [NSMutableString string];
    WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource:[cookies copy]
                                                         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                      forMainFrameOnly:NO];
    [userContentController addUserScript:cookieScript];
    
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.preferences.minimumFontSize = 9.0;
    configuration.userContentController = userContentController;
    configuration.processPool = [MSWebHTTPCookieStorage sharedStorage].processPool;
    
    if ([configuration respondsToSelector:@selector(setApplicationNameForUserAgent:)]) {
        [configuration setApplicationNameForUserAgent:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"]];
    }
    if ([configuration respondsToSelector:@selector(setAllowsInlineMediaPlayback:)]) {
        [configuration setAllowsInlineMediaPlayback:YES];
    }
    
    configuration.userContentController = [[WKUserContentController alloc] init];
    
    WKPreferences *preferences = [[WKPreferences alloc] init];
    preferences.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.preferences = preferences;
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:configuration];
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    
    webView.allowsBackForwardNavigationGestures = self.allowsBackForwardNavigationGestures;
    
    [webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
    
    SEL allowsLinkPreviewSelector = NSSelectorFromString(@"setAllowsLinkPreview:");
    if ([webView respondsToSelector:allowsLinkPreviewSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [webView performSelector:allowsLinkPreviewSelector withObject:@(YES)];
#pragma clang diagnostic pop
    }
    _realWebView = webView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.estimatedProgress = [change[NSKeyValueChangeNewKey] doubleValue];
    } else if ([keyPath isEqualToString:@"title"]) {
        self.title = change[NSKeyValueChangeNewKey];
    } else {
        [self willChangeValueForKey:keyPath];
        [self didChangeValueForKey:keyPath];
    }
}

// MARK: initUIWebView

- (void)initUIWebView {
    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.bounds];
    webView.backgroundColor = [UIColor clearColor];
    webView.allowsInlineMediaPlayback = YES;
    webView.mediaPlaybackRequiresUserAction = NO;
    [self addGestureRecognizer:self.swipePanGesture];
    
    webView.opaque = NO;
    for (UIView *subview in [webView.scrollView subviews]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            ((UIImageView *) subview).image = nil;
            subview.backgroundColor = [UIColor clearColor];
        }
    }
    
    self.njkWebViewProgress = [[MS_NJKWebViewProgress alloc] init];
    webView.delegate = self.njkWebViewProgress;
    self.njkWebViewProgress.webViewProxyDelegate = self;
    self.njkWebViewProgress.progressDelegate = self;
    
    _realWebView = webView;
}

// MARK: delegate

- (void)setDelegate:(id <MSWebViewDelegate>)delegate {
    _delegate = delegate;
    if (_usingUIWebView) {
        UIWebView *webView = self.realWebView;
        webView.delegate = self.njkWebViewProgress;
    } else {
        WKWebView *webView = self.realWebView;
        webView.UIDelegate = self;
        webView.navigationDelegate = self;
    }
}

// MARK: progress

- (void)setEstimatedProgress:(CGFloat)estimatedProgress {
    if (_estimatedProgress == estimatedProgress) {
        return;
    }
    _estimatedProgress = estimatedProgress;
    
    [self.progressView setProgress:estimatedProgress animated:estimatedProgress > 0.1];
    CGFloat hideProgress = estimatedProgress >= 0.95f ? 0.0f : 1.0f;
    if (self.progressView.alpha != hideProgress) {
        [UIView animateWithDuration:1.0f * estimatedProgress
                              delay:0.5f
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.progressView.alpha = hideProgress;
                         }
                         completion:nil];
    }
}

// MARK: UIWebView Swipe

- (UIPanGestureRecognizer *)swipePanGesture {
    if (!_swipePanGesture) {
        _swipePanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipePanGestureHandler:)];
        _swipePanGesture.enabled = self.allowsBackForwardNavigationGestures;
    }
    return _swipePanGesture;
}

- (UIImageView *)swipeBackArrow {
    if (!_swipeBackArrow) {
        _swipeBackArrow = [[UIImageView alloc] initWithImage:[MSWebActivity ms_imageNamed:@"MSWebViewControllerBack"]];
        _swipeBackArrow.backgroundColor = [UIColor lightGrayColor];
        CGSize imageSize = _swipeBackArrow.image.size;
        _swipeBackArrow.frame = CGRectMake(0, 0, imageSize.width * 2, imageSize.height * 2);
    }
    return _swipeBackArrow;
}

- (UIImageView *)swipeForwardArrow {
    if (!_swipeForwardArrow) {
        _swipeForwardArrow = [[UIImageView alloc] initWithImage:[MSWebActivity ms_imageNamed:@"MSWebViewControllerNext"]];
        _swipeForwardArrow.backgroundColor = [UIColor lightGrayColor];
        CGSize imageSize = _swipeForwardArrow.image.size;
        _swipeForwardArrow.frame = CGRectMake(0, 0, imageSize.width * 2, imageSize.height * 2);
    }
    return _swipeForwardArrow;
}

- (void)swipePanGestureHandler:(UIPanGestureRecognizer *)panGesture {
    CGPoint translation = [panGesture translationInView:self];
    
    if (panGesture.state == UIGestureRecognizerStateBegan) {
        // Begin gesture pop animation
        if (translation.x >= 0) {
            [self startSwipeAnimation:YES];
        } else if (translation.x < 0) {
            [self startSwipeAnimation:NO];
        }
    } else if (panGesture.state == UIGestureRecognizerStateCancelled || panGesture.state == UIGestureRecognizerStateEnded) {
        [self endSwipeAnimation];
    } else if (panGesture.state == UIGestureRecognizerStateChanged) {
        [self swipeWithPanGestureDistance:translation.x];
    }
}

- (void)startSwipeAnimation:(BOOL)isBack {
    if (self.isSwipingBack) {
        return;
    }
    
    self.isSwipingBack = YES;
    
    BOOL canGoBack = self.canGoBack;
    if (isBack && !canGoBack) {
        return;
    }
    
    BOOL canGoForward = self.canGoForward;
    if (!isBack && !canGoForward) {
        return;
    }
    
    CGRect backFrame = self.swipeBackArrow.frame;
    backFrame.origin.x = -backFrame.size.width;
    backFrame.origin.y = (self.bounds.size.height - backFrame.size.height) / 2;
    
    CGRect forwardFrame = self.swipeForwardArrow.frame;
    forwardFrame.origin.x = self.bounds.size.width;
    forwardFrame.origin.y = (self.bounds.size.height - forwardFrame.size.height) / 2;
    
    self.swipeBackArrow.frame = backFrame;
    self.swipeForwardArrow.frame = forwardFrame;
    
    self.swipeForwardArrow.alpha = 1;
    self.swipeBackArrow.alpha = 1;
    
    if (canGoForward) {
        [self addSubview:self.swipeForwardArrow];
    }
    
    if (canGoBack) {
        [self addSubview:self.swipeBackArrow];
    }
}

- (void)swipeWithPanGestureDistance:(CGFloat)distance {
    
    CGRect forwardFrame = self.swipeForwardArrow.frame;
    forwardFrame.origin.x = MAX(distance * forwardFrame.size.width / swipeDistance, - forwardFrame.size.width)  + self.bounds.size.width;
    
    CGRect backFrame = self.swipeBackArrow.frame;
    backFrame.origin.x =  MIN(distance * backFrame.size.width / swipeDistance, backFrame.size.width) - backFrame.size.width;
    
    self.swipeForwardArrow.frame = forwardFrame;
    self.swipeBackArrow.frame = backFrame;
}

- (void)endSwipeAnimation {
    if (!self.isSwipingBack) {
        return;
    }
    
    self.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.swipeForwardArrow.alpha = 0;
        self.swipeBackArrow.alpha = 0;
    } completion:^(BOOL finished) {
        self.userInteractionEnabled = YES;
        [self.swipeBackArrow removeFromSuperview];
        [self.swipeForwardArrow removeFromSuperview];
        if (CGRectGetMinX(self.swipeBackArrow.frame) == 0 && self.canGoBack) {
            [(UIWebView *)self.realWebView goBack];
        } else if (CGRectGetMaxX(self.swipeForwardArrow.frame) == self.bounds.size.width && self.canGoForward) {
            [(UIWebView *)self.realWebView goForward];
        }
        self.isSwipingBack = NO;
    }];
    
}

// MARK: JS Core

- (void)addScriptMessageHandler:(id <WKScriptMessageHandler>)scriptMessageHandler name:(NSString *)name {
    if (!_usingUIWebView) {
        WKWebViewConfiguration *configuration = [(WKWebView *) self.realWebView configuration];
        [configuration.userContentController addScriptMessageHandler:scriptMessageHandler name:name];
    }
}

- (JSContext *)jsContext {
    if (_usingUIWebView) {
        return [(UIWebView *) self.realWebView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    } else {
        return nil;
    }
}

// MARK: UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    if (self.originRequest == nil) {
        self.originRequest = webView.request;
    }
    
    [self ms_webViewDidFinishLoad];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self ms_webViewDidStartLoad];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self ms_webViewDidFailLoadWithError:error];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    BOOL resultBOOL = [self ms_webViewShouldStartLoadWithRequest:request navigationType:navigationType];
    if (resultBOOL) {
        switch (navigationType) {
            case UIWebViewNavigationTypeLinkClicked:
            case UIWebViewNavigationTypeFormSubmitted:
            case UIWebViewNavigationTypeOther: {
                
            }
                break;
            case UIWebViewNavigationTypeBackForward:
            case UIWebViewNavigationTypeReload:
            case UIWebViewNavigationTypeFormResubmitted:
            default: {
                break;
            }
        }
    }
    return resultBOOL;
}

- (void)webViewProgress:(MS_NJKWebViewProgress *)webViewProgress updateProgress:(CGFloat)progress {
    self.estimatedProgress = progress;
}

// MARK: WKUIDelegate

- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    WKFrameInfo *frameInfo = navigationAction.targetFrame;
    if (![frameInfo isMainFrame]) {
        if (navigationAction.request) {
            [webView loadRequest:navigationAction.request];
        }
    }
    return nil;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
- (void)webViewDidClose:(WKWebView *)webView {
    
}
#endif

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    // Get host name of url.
    NSString *host = webView.URL.host;
    // Init the alert view controller.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:host ?: NSLocalizedString(@"messages", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    // Init the cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel") style:UIAlertActionStyleCancel handler:NULL];
    // Init the ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        completionHandler();
    }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    // Get the host name.
    NSString *host = webView.URL.host;
    // Initialize alert view controller.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:host ?: NSLocalizedString(@"messages", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    // Initialize cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
                                                             [alert dismissViewControllerAnimated:YES completion:NULL];
                                                             completionHandler(NO);
                                                         }];
    // Initialize ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         [alert dismissViewControllerAnimated:YES completion:NULL];
                                                         completionHandler(YES);
                                                     }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *__nullable result))completionHandler {
    // Get the host of url.
    NSString *host = webView.URL.host;
    // Initialize alert view controller.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:prompt ?: NSLocalizedString(@"messages", nil)
                                                                   message:host
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // Add text field.
    [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.placeholder = defaultText ?: NSLocalizedString(@"input", nil);
        textField.font = [UIFont systemFontOfSize:12];
    }];
    // Initialize cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
                                                             [alert dismissViewControllerAnimated:YES completion:NULL];
                                                             // Get inputed string.
                                                             NSString *string = [alert.textFields firstObject].text;
                                                             completionHandler(string ?: defaultText);
                                                         }];
    // Initialize ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         [alert dismissViewControllerAnimated:YES completion:NULL];
                                                         // Get inputed string.
                                                         NSString *string = [alert.textFields firstObject].text;
                                                         completionHandler(string ?: defaultText);
                                                     }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
    NSArray *cookies =[NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:response.URL];
    //读取wkwebview中的cookie 方法1
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
    
    //    NSLog(@"wkwebview cookie:%@", [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies);
    decisionHandler(WKNavigationResponsePolicyAllow);
}


// MARK: WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    BOOL resultBOOL = [self ms_webViewShouldStartLoadWithRequest:navigationAction.request navigationType:navigationAction.navigationType];
    
    // Disable all the '_blank' target in page's target.
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView evaluateJavaScript:@"var a = document.getElementsByTagName('a');for(var i=0;i<a.length;i++){a[i].setAttribute('target','');}" completionHandler:nil];
    }
    
    if (!resultBOOL) {
        // For can deal something.
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        // Call the decision handler to allow to load web page.
        self.currentRequest = navigationAction.request;
        if (navigationAction.targetFrame == nil) {
            //        if (navigationAction.navigationType == WKNavigationTypeLinkActivated || navigationAction.navigationType == WKNavigationTypeOther) {
            [webView loadRequest:navigationAction.request];
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self ms_webViewDidStartLoad];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    // store cookies
    NSString *JSCookieString = MSGenerateJSSentence([NSHTTPCookieStorage sharedHTTPCookieStorage].cookies);
    
    // execute js
    [webView evaluateJavaScript:JSCookieString completionHandler:nil];
    
    if (canUseWKWebsiteDataStore) {
        // FIXME: Later deal with WKWebCookie synchronization issues
    }
    [self ms_webViewDidFinishLoad];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self ms_webViewDidFailLoadWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self ms_webViewDidFailLoadWithError:error];
}

// MARK: MSKWebView Delegate

- (void)ms_webViewDidFinishLoad {
    if ([self isLoading]) {
        return;
    }
    
    self.estimatedProgress = 1.0f;
    
    NSString *host = self.currentRequest.URL.host;
    self.backgroundLabel.text = [NSString stringWithFormat:@"%@\"%@\"%@.", NSLocalizedString(@"web page", @""), host, NSLocalizedString(@"provided", @"")];
    if ([self.delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [self.delegate webViewDidFinishLoad:self];
    }
}

- (void)ms_webViewDidStartLoad {
    self.backgroundLabel.text = NSLocalizedString(@"loading", @"Loading");
    if ([self.delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.delegate webViewDidStartLoad:self];
    }
}

- (void)ms_webViewDidFailLoadWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [self.delegate webView:self didFailLoadWithError:error];
    }
}

- (BOOL)ms_webViewShouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    BOOL resultBOOL = YES;
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:request.URL.absoluteString];
    if ([self.delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        if (navigationType == -1) {
            navigationType = UIWebViewNavigationTypeOther;
        }
        resultBOOL = [self.delegate webView:self shouldStartLoadWithRequest:request navigationType:navigationType];
    } else if ([[NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] 'https://itunes.apple.com/cn/app/' OR SELF BEGINSWITH[cd] 'mailto:' OR SELF BEGINSWITH[cd] 'tel:' OR SELF BEGINSWITH[cd] 'telprompt:'"] evaluateWithObject:request.URL.absoluteString]) {
        // For appstore.
        if ([[UIApplication sharedApplication] canOpenURL:request.URL]) {
            if (UIDevice.currentDevice.systemVersion.floatValue >= 10.0) {
                [UIApplication.sharedApplication openURL:request.URL options:@{} completionHandler:NULL];
            } else {
                [[UIApplication sharedApplication] openURL:request.URL];
            }
        }
        resultBOOL = NO;
    } else if (![[NSPredicate predicateWithFormat:@"SELF MATCHES[cd] 'https' OR SELF MATCHES[cd] 'http' OR SELF MATCHES[cd] 'file' OR SELF MATCHES[cd] 'about'"] evaluateWithObject:components.scheme]) {
        // For any other schema.
        if ([[UIApplication sharedApplication] canOpenURL:request.URL]) {
            if (UIDevice.currentDevice.systemVersion.floatValue >= 10.0) {
                [UIApplication.sharedApplication openURL:request.URL options:@{} completionHandler:NULL];
            } else {
                [[UIApplication sharedApplication] openURL:request.URL];
            }
        }
        resultBOOL = NO;
    }
    return resultBOOL;
}

// MARK: The basic methods

- (UIScrollView *)scrollView {
    return [(id) self.realWebView scrollView];
}

- (id)loadRequest:(NSURLRequest *)request {
    self.originRequest = request;
    self.currentRequest = request;
    
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView loadRequest:request];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView loadRequest:request];
    }
}

- (id)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView loadHTMLString:string baseURL:baseURL];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView loadHTMLString:string baseURL:baseURL];
    }
}

- (void)setHideProgress:(BOOL)hideProgress {
    _hideProgress = hideProgress;
    self.progressView.hidden = hideProgress;
}

- (NSURLRequest *)currentRequest {
    if (_usingUIWebView) {
        return [(UIWebView *) self.realWebView request];
    } else {
        return _currentRequest;
    }
}

- (NSURL *)URL {
    if (_usingUIWebView) {
        return [(UIWebView *) self.realWebView request].URL;;
    } else {
        return [(WKWebView *) self.realWebView URL];
    }
}

- (BOOL)isLoading {
    return [self.realWebView isLoading];
}

- (BOOL)canGoBack {
    return [self.realWebView canGoBack];
}

- (BOOL)canGoForward {
    return [self.realWebView canGoForward];
}

- (id)goBack {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView goBack];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView goBack];
    }
}

- (id)goForward {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView goForward];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView goForward];
    }
}

- (id)reload {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView reload];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView reload];
    }
}

- (id)reloadFromOrigin {
    if (_usingUIWebView) {
        if (self.originRequest) {
            [self evaluateJavaScript:[NSString stringWithFormat:@"window.location.replace('%@')", self.originRequest.URL.absoluteString] completionHandler:nil];
        }
        return nil;
    } else {
        return [(WKWebView *) self.realWebView reloadFromOrigin];
    }
}

- (void)stopLoading {
    [self.realWebView stopLoading];
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    if (_usingUIWebView) {
        NSString *result = [(UIWebView *) self.realWebView stringByEvaluatingJavaScriptFromString:javaScriptString];
        if (completionHandler) {
            completionHandler(result, nil);
        }
    } else {
        return [(WKWebView *) self.realWebView evaluateJavaScript:javaScriptString completionHandler:completionHandler];
    }
}

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)javaScriptString {
    if (_usingUIWebView) {
        NSString *result = [(UIWebView *) self.realWebView stringByEvaluatingJavaScriptFromString:javaScriptString];
        return result;
    } else {
        __block NSString *result = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [(WKWebView *) self.realWebView evaluateJavaScript:javaScriptString completionHandler:^(id obj, NSError *error) {
            result = obj;
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore,dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
        return result;
    }
}

- (void)setScalesPageToFit:(BOOL)scalesPageToFit {
    if (_usingUIWebView) {
        UIWebView *webView = _realWebView;
        webView.scalesPageToFit = scalesPageToFit;
    } else {
        if (_scalesPageToFit == scalesPageToFit) {
            return;
        }
        
        WKWebView *webView = _realWebView;
        
        NSString *jScript = @"var head = document.getElementsByTagName('head')[0];\
                             var hasViewPort = 0;\
                             var metas = head.getElementsByTagName('meta');\
                             for (var i = metas.length; i>=0 ; i--) {\
                             var m = metas[i];\
                             if (m.name == 'viewport') {\
                             hasViewPort = 1;\
                             break;\
                             }\
                             }; \
                             if(hasViewPort == 0) { \
                             var meta = document.createElement('meta'); \
                             meta.name = 'viewport'; \
                             meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'; \
                             head.appendChild(meta);\
                             }";
        
        WKUserContentController *userContentController = webView.configuration.userContentController;
        NSMutableArray<WKUserScript *> *array = [userContentController.userScripts mutableCopy];
        WKUserScript *fitWKUScript = nil;
        for (WKUserScript *wkUScript in array) {
            if ([wkUScript.source isEqual:jScript]) {
                fitWKUScript = wkUScript;
                break;
            }
        }
        if (scalesPageToFit) {
            if (!fitWKUScript) {
                fitWKUScript = [[WKUserScript alloc] initWithSource:jScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
                [userContentController addUserScript:fitWKUScript];
            }
        } else {
            if (fitWKUScript) {
                [array removeObject:fitWKUScript];
            }
            // There is no way to modify the array, only remove all, and then add it again.
            [userContentController removeAllUserScripts];
            for (WKUserScript *wkUScript in array) {
                [userContentController addUserScript:wkUScript];
            }
        }
    }
    _scalesPageToFit = scalesPageToFit;
}

- (BOOL)scalesPageToFit {
    if (_usingUIWebView) {
        return [_realWebView scalesPageToFit];
    } else {
        return _scalesPageToFit;
    }
}

- (NSInteger)countOfHistory {
    if (_usingUIWebView) {
        UIWebView *webView = self.realWebView;
        // FIXME: The results obtained by this method are not particularly accurate.
        NSInteger count = [[webView stringByEvaluatingJavaScriptFromString:@"window.history.length"] integerValue];
        return count ?: 1;
    } else {
        WKWebView *webView = self.realWebView;
        return webView.backForwardList.backList.count;
    }
}

- (void)gobackWithStep:(NSInteger)step {
    if (self.canGoBack == NO)
        return;
    
    if (step > 0) {
        NSInteger historyCount = self.countOfHistory;
        if (step >= historyCount) {
            step = historyCount - 1;
        }
        
        if (_usingUIWebView) {
            UIWebView *webView = self.realWebView;
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.history.go(-%ld)", (long) step]];
        } else {
            WKWebView *webView = self.realWebView;
            WKBackForwardListItem *backItem = webView.backForwardList.backList[step];
            [webView goToBackForwardListItem:backItem];
        }
    } else {
        [self goBack];
    }
}

// MARK: forwardInvocation

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL hasResponds = [super respondsToSelector:aSelector] || [self.delegate respondsToSelector:aSelector] || [self.realWebView respondsToSelector:aSelector];
    return hasResponds;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature* methodSign = [super methodSignatureForSelector:selector];
    if (methodSign == nil) {
        if ([self.realWebView respondsToSelector:selector]) {
            methodSign = [self.realWebView methodSignatureForSelector:selector];
        } else {
            methodSign = [(id)self.delegate methodSignatureForSelector:selector];
        }
    }
    return methodSign;
}

- (void)forwardInvocation:(NSInvocation*)invocation {
    if ([self.realWebView respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:self.realWebView];
    } else {
        [invocation invokeWithTarget:self.delegate];
    }
}

// MARK: clean

- (void)dealloc {
    if (_usingUIWebView) {
        UIWebView *webView = _realWebView;
        webView.delegate = nil;
    } else {
        WKWebView *webView = _realWebView;
        webView.UIDelegate = nil;
        webView.navigationDelegate = nil;
        
        [webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [webView removeObserver:self forKeyPath:@"title"];
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [_realWebView scrollView].delegate = nil;
    [_realWebView stopLoading];
    [(UIWebView *) _realWebView loadHTMLString:@"" baseURL:nil];
    [_realWebView stopLoading];
    [_realWebView removeFromSuperview];
    _realWebView = nil;
}

@end
