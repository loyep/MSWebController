//
//  MSWebHTTPCookie.h
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface MSWebHTTPCookieStorage : NSObject

+ (instancetype)sharedStorage;

@property (nonatomic, strong, readonly) WKProcessPool *processPool;

@end

