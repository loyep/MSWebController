#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "MSWebActivity.h"
#import "MSWebActivityChrome.h"
#import "MSWebActivitySafari.h"
#import "MSWebController.h"
#import "MSWebHTTPCookieStorage.h"
#import "MSWebView.h"
#import "MS_NJKWebViewProgress.h"

FOUNDATION_EXPORT double MSWebControllerVersionNumber;
FOUNDATION_EXPORT const unsigned char MSWebControllerVersionString[];

