//
//  MSWebController.h
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MSWebView.h"

//! Project version number for MSWebController.
FOUNDATION_EXPORT double MSWebControllerVersionNumber;

//! Project version string for MSWebController.
FOUNDATION_EXPORT const unsigned char MSWebControllerVersionString[];

@interface MSWebController : UIViewController

@property (nonatomic, strong, readonly) MSWebView *webView;

@property (nonatomic, assign) BOOL useUIWebView;

- (void)loadRequest:(NSURLRequest *)request;

@end
