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

static BOOL canUseWkWebView = NO;

@interface MSWebView () <UIWebViewDelegate, WKNavigationDelegate, WKUIDelegate, MS_NJKWebViewProgressDelegate>

@property (nonatomic, assign) CGFloat estimatedProgress;
@property (nonatomic, strong) NSURLRequest *originRequest;
@property (nonatomic, strong) NSURLRequest *currentRequest;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) MS_NJKWebViewProgress *njkWebViewProgress;
@property (nonatomic, strong, readwrite) UIProgressView *progressView;

/// Array that hold snapshots of pages.
@property (strong, nonatomic) NSMutableArray *snapshots;
/// Current snapshotview displaying on screen when start swiping.
@property (strong, nonatomic) UIView *currentSnapshotView;
/// Previous snapshotview.
@property (strong, nonatomic) UIView *previousSnapshotView;
/// Background alpha black view.
@property (strong, nonatomic) UIView *swipingBackgoundView;
/// Left pan ges.
@property (nonatomic, strong) UIPanGestureRecognizer *swipePanGesture;

@property (nonatomic, assign) BOOL isSwipingBack;

@end

@implementation MSWebView

@synthesize usingUIWebView = _usingUIWebView;
@synthesize realWebView = _realWebView;
@synthesize scalesPageToFit = _scalesPageToFit;

+ (void)load {
    canUseWkWebView = (NSClassFromString(@"WKWebView") != nil);
}

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
    [self.realWebView addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
    self.allowsBackForwardNavigationGestures = YES;
    self.scalesPageToFit = YES;
    
    // Set auto layout enabled.
    [(UIWebView *) self.realWebView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    [self.realWebView setFrame:self.bounds];
    [self.realWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self addSubview:self.realWebView];
    
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 2)];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self addSubview:self.progressView];
}

- (void)setDelegate:(id <MSWebViewDelegate>)delegate {
    _delegate = delegate;
    if (_usingUIWebView) {
        UIWebView *webView = self.realWebView;
        webView.delegate = nil;
        webView.delegate = self;
    } else {
        WKWebView *webView = self.realWebView;
        webView.UIDelegate = nil;
        webView.navigationDelegate = nil;
        webView.UIDelegate = self;
        webView.navigationDelegate = self;
    }
}

- (void)setEstimatedProgress:(CGFloat)estimatedProgress {
    if (_estimatedProgress == estimatedProgress) {
        return;
    }
    _estimatedProgress = estimatedProgress;
    
    [self.progressView setProgress:estimatedProgress animated:estimatedProgress > 0.1];
    CGFloat hideProgress = estimatedProgress >= 0.95f ? 0.0f : 1.0f;
    if (self.progressView.alpha != hideProgress) {
        [UIView animateWithDuration:1.0f * estimatedProgress delay:0.5f options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.progressView.alpha = hideProgress;
        } completion:nil];
    }
}

#pragma mark - UIWebView Swipe

- (UIPanGestureRecognizer *)swipePanGesture {
    if (!_swipePanGesture) {
        _swipePanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipePanGestureHandler:)];
        _swipePanGesture.enabled = self.allowsBackForwardNavigationGestures;
    }
    return _swipePanGesture;
}

- (void)swipePanGestureHandler:(UIPanGestureRecognizer *)panGesture {
    CGPoint translation = [panGesture translationInView:self.realWebView];
    CGPoint location = [panGesture locationInView:self.realWebView];
    
    if (panGesture.state == UIGestureRecognizerStateBegan) {
        // Begin gesture pop animation
        if (location.x <= 50 && translation.x >= 0) {
            [self startPopSnapshotView];
        }
    } else if (panGesture.state == UIGestureRecognizerStateCancelled || panGesture.state == UIGestureRecognizerStateEnded) {
        [self endPopSnapShotView];
    } else if (panGesture.state == UIGestureRecognizerStateChanged) {
        [self popSnapShotViewWithPanGestureDistance:translation.x];
    }
}

-(void)pushCurrentSnapshotViewWithRequest:(NSURLRequest*)request{
    NSURLRequest* lastRequest = (NSURLRequest*)[[self.snapshots lastObject] objectForKey:@"request"];
    
    // 如果url是很奇怪的就不push
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return;
    }
    
    //如果url一样就不进行push
    if ([lastRequest.URL.absoluteString isEqualToString:request.URL.absoluteString]) {
        return;
    }
    
    UIView* currentSnapshotView = [self.realWebView snapshotViewAfterScreenUpdates:YES];
    [self.snapshots addObject:
     @{
       @"request":request,
       @"snapShotView":currentSnapshotView}
     ];
}

- (void)startPopSnapshotView {
    if (self.isSwipingBack) {
        return;
    }
    if (!((UIWebView *) self.realWebView).canGoBack) {
        return;
    }
    
    self.isSwipingBack = YES;
    //create a center of scrren
    CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    
    self.currentSnapshotView = [self.realWebView snapshotViewAfterScreenUpdates:YES];
    
    //add shadows just like UINavigationController
    self.currentSnapshotView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.currentSnapshotView.layer.shadowOffset = CGSizeMake(3, 3);
    self.currentSnapshotView.layer.shadowRadius = 5;
    self.currentSnapshotView.layer.shadowOpacity = 0.75;
    
    //move to center of screen
    self.currentSnapshotView.center = center;
    
    self.previousSnapshotView = (UIView *) [[self.snapshots lastObject] objectForKey:@"snapShotView"];
    center.x -= 60;
    self.previousSnapshotView.center = center;
    self.previousSnapshotView.alpha = 1;
    self.backgroundColor = [UIColor colorWithRed:0.180 green:0.192 blue:0.196 alpha:1.00];
    
    [self addSubview:self.previousSnapshotView];
    [self addSubview:self.swipingBackgoundView];
    [self addSubview:self.currentSnapshotView];
}

- (void)popSnapShotViewWithPanGestureDistance:(CGFloat)distance {
    if (!self.isSwipingBack) {
        return;
    }
    
    if (distance <= 0) {
        return;
    }
    
    CGFloat boundsWidth = CGRectGetWidth(self.bounds);
    CGFloat boundsHeight = CGRectGetHeight(self.bounds);
    
    CGPoint currentSnapshotViewCenter = CGPointMake(boundsWidth / 2, boundsHeight / 2);
    currentSnapshotViewCenter.x += distance;
    CGPoint previousSnapshotViewCenter = CGPointMake(boundsWidth / 2, boundsHeight / 2);
    previousSnapshotViewCenter.x -= (boundsWidth - distance) * 60 / boundsWidth;
    
    self.currentSnapshotView.center = currentSnapshotViewCenter;
    self.previousSnapshotView.center = previousSnapshotViewCenter;
    self.swipingBackgoundView.alpha = (boundsWidth - distance) / boundsWidth;
}

- (void)endPopSnapShotView {
    if (!self.isSwipingBack) {
        return;
    }
    
    //prevent the user touch for now
    self.userInteractionEnabled = NO;
    
    CGFloat boundsWidth = CGRectGetWidth(self.bounds);
    CGFloat boundsHeight = CGRectGetHeight(self.bounds);
    
    if (self.currentSnapshotView.center.x >= boundsWidth) {
        //When pop success.
        [UIView animateWithDuration:0.2 animations:^{
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            
            self.currentSnapshotView.center = CGPointMake(boundsWidth * 3 / 2, boundsHeight / 2);
            self.previousSnapshotView.center = CGPointMake(boundsWidth / 2, boundsHeight / 2);
            self.swipingBackgoundView.alpha = 0;
        }                completion:^(BOOL finished) {
            [self.previousSnapshotView removeFromSuperview];
            [self.swipingBackgoundView removeFromSuperview];
            [self.currentSnapshotView removeFromSuperview];
            [(UIWebView *) self.realWebView goBack];
            [self.snapshots removeLastObject];
            self.userInteractionEnabled = YES;
            
            self.isSwipingBack = NO;
        }];
    } else {
        //If pop fail.
        [UIView animateWithDuration:0.2 animations:^{
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            
            self.currentSnapshotView.center = CGPointMake(boundsWidth / 2, boundsHeight / 2);
            self.previousSnapshotView.center = CGPointMake(boundsWidth / 2 - 60, boundsHeight / 2);
            self.previousSnapshotView.alpha = 1;
        }                completion:^(BOOL finished) {
            [self.previousSnapshotView removeFromSuperview];
            [self.swipingBackgoundView removeFromSuperview];
            [self.currentSnapshotView removeFromSuperview];
            self.userInteractionEnabled = YES;
            
            self.isSwipingBack = NO;
        }];
    }
}

- (void)setAllowsBackForwardNavigationGestures:(BOOL)allowsBackForwardNavigationGestures {
    _allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures;
    
    if (_usingUIWebView) {
        self.swipePanGesture.enabled = self.allowsBackForwardNavigationGestures;
    } else {
        [(WKWebView *)self.realWebView setAllowsBackForwardNavigationGestures:self.allowsBackForwardNavigationGestures];
    }
}

- (void)initWKWebView {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.preferences.minimumFontSize = 9.0;
    
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
    SEL linkPreviewSelector = NSSelectorFromString(@"setAllowsLinkPreview:");
    if ([webView respondsToSelector:linkPreviewSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [webView performSelector:linkPreviewSelector withObject:@(YES)];
#pragma clang diagnostic pop
    }
    
    [webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
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

- (void)initUIWebView {
    self.snapshots = [NSMutableArray array];
    
    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.bounds];
    webView.backgroundColor = [UIColor clearColor];
    webView.allowsInlineMediaPlayback = YES;
    webView.mediaPlaybackRequiresUserAction = NO;
    [webView addGestureRecognizer:self.swipePanGesture];
    
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

#pragma mark - js Core

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

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    if (self.originRequest == nil) {
        self.originRequest = webView.request;
    }
    [self callback_webViewDidFinishLoad];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self callback_webViewDidStartLoad];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self callback_webViewDidFailLoadWithError:error];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    BOOL resultBOOL = [self callback_webViewShouldStartLoadWithRequest:request navigationType:navigationType];
    if (resultBOOL) {
        switch (navigationType) {
            case UIWebViewNavigationTypeLinkClicked:
            case UIWebViewNavigationTypeFormSubmitted:
            case UIWebViewNavigationTypeOther: {
                [self pushCurrentSnapshotViewWithRequest:request];
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

#pragma mark - WKUIDelegate

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
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        completionHandler(NO);
    }];
    // Initialize ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:prompt ?: NSLocalizedString(@"messages", nil) message:host preferredStyle:UIAlertControllerStyleAlert];
    // Add text field.
    [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.placeholder = defaultText ?: NSLocalizedString(@"input", nil);
        textField.font = [UIFont systemFontOfSize:12];
    }];
    // Initialize cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        // Get inputed string.
        NSString *string = [alert.textFields firstObject].text;
        completionHandler(string ?: defaultText);
    }];
    // Initialize ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        // Get inputed string.
        NSString *string = [alert.textFields firstObject].text;
        completionHandler(string ?: defaultText);
    }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    BOOL resultBOOL = [self callback_webViewShouldStartLoadWithRequest:navigationAction.request navigationType:navigationAction.navigationType];
    BOOL isLoadingDisableScheme = [self isLoadingWKWebViewDisableScheme:navigationAction.request.URL];
    
    // Disable all the '_blank' target in page's target.
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView evaluateJavaScript:@"var a = document.getElementsByTagName('a');for(var i=0;i<a.length;i++){a[i].setAttribute('target','');}" completionHandler:nil];
    }
    
    if (!resultBOOL || isLoadingDisableScheme) {
        // For can deal something.
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        // Call the decision handler to allow to load web page.
        self.currentRequest = navigationAction.request;
        if (navigationAction.targetFrame == nil) {
            [webView loadRequest:navigationAction.request];
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self callback_webViewDidStartLoad];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self callback_webViewDidFinishLoad];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self callback_webViewDidFailLoadWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self callback_webViewDidFailLoadWithError:error];
}

#pragma mark - CALLBACK MSKWebView Delegate

- (void)callback_webViewDidFinishLoad {
    self.estimatedProgress = 1.0f;
    
    if ([self.delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [self.delegate webViewDidFinishLoad:self];
    }
}

- (void)callback_webViewDidStartLoad {
    if ([self.delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.delegate webViewDidStartLoad:self];
    }
}

- (void)callback_webViewDidFailLoadWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [self.delegate webView:self didFailLoadWithError:error];
    }
}

- (BOOL)callback_webViewShouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
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

#pragma mark - 基础方法

///判断当前加载的url是否是WKWebView不能打开的协议类型
- (BOOL)isLoadingWKWebViewDisableScheme:(NSURL *)url {
    BOOL retValue = NO;
    
    //判断是否正在加载WKWebview不能识别的协议类型：phone numbers, email address, maps, etc.
    if ([url.scheme isEqual:@"tel"]) {
        UIApplication *app = [UIApplication sharedApplication];
        if ([app canOpenURL:url]) {
            [app openURL:url];
            retValue = YES;
        }
    }
    
    return retValue;
}

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
        __block BOOL isExecuted = NO;
        [(WKWebView *) self.realWebView evaluateJavaScript:javaScriptString completionHandler:^(id obj, NSError *error) {
            result = obj;
            isExecuted = YES;
        }];
        
        while (isExecuted == NO) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
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
        
        NSString *jScript = [NSString stringWithFormat:@"var head = document.getElementsByTagName('head')[0];\
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
                             }"];
        
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
            /// 没法修改数组 只能移除全部 再重新添加
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
        
        int count = [[webView stringByEvaluatingJavaScriptFromString:@"window.history.length"] intValue];
        if (count) {
            return count;
        } else {
            return 1;
        }
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

#pragma mark -  如果没有找到方法 去realWebView 中调用

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL hasResponds = [super respondsToSelector:aSelector];
    if (hasResponds == NO) {
        hasResponds = [self.delegate respondsToSelector:aSelector];
    }
    if (hasResponds == NO) {
        hasResponds = [self.realWebView respondsToSelector:aSelector];
    }
    return hasResponds;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *methodSign = [super methodSignatureForSelector:selector];
    if (methodSign == nil) {
        if ([self.realWebView respondsToSelector:selector]) {
            methodSign = [self.realWebView methodSignatureForSelector:selector];
        } else {
            methodSign = [(id) self.delegate methodSignatureForSelector:selector];
        }
    }
    return methodSign;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([self.realWebView respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:self.realWebView];
    } else {
        [invocation invokeWithTarget:self.delegate];
    }
}

#pragma mark - 清理

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
    [_realWebView removeObserver:self forKeyPath:@"loading"];
    [_realWebView scrollView].delegate = nil;
    [_realWebView stopLoading];
    [(UIWebView *) _realWebView loadHTMLString:@"" baseURL:nil];
    [_realWebView stopLoading];
    [_realWebView removeFromSuperview];
    _realWebView = nil;
}

@end
