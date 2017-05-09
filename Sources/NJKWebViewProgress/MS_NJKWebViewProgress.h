//
//  MS_NJKWebViewProgress.h
//
//  Created by Satoshi Aasano on 4/20/13.
//  Copyright (c) 2013 Satoshi Asano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#undef njk_weak
#if __has_feature(objc_arc_weak)
#define njk_weak weak
#else
#define njk_weak unsafe_unretained
#endif

extern const float MS_NJKInitialProgressValue;
extern const float MS_NJKInteractiveProgressValue;
extern const float MS_NJKFinalProgressValue;

typedef void (^MS_NJKWebViewProgressBlock)(float progress);

@protocol MS_NJKWebViewProgressDelegate;

@interface MS_NJKWebViewProgress : NSObject <UIWebViewDelegate>

@property (nonatomic, njk_weak) id <MS_NJKWebViewProgressDelegate> progressDelegate;
@property (nonatomic, njk_weak) id <UIWebViewDelegate> webViewProxyDelegate;
@property (nonatomic, copy) MS_NJKWebViewProgressBlock progressBlock;
@property (nonatomic, readonly) float progress; // 0.0..1.0

- (void)reset;

@end

@protocol MS_NJKWebViewProgressDelegate <NSObject>

- (void)webViewProgress:(MS_NJKWebViewProgress *)webViewProgress updateProgress:(CGFloat)progress;

@end

