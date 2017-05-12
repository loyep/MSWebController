//
//  MSWebHTTPCookie.m
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "MSWebHTTPCookieStorage.h"

@interface MSWebHTTPCookieStorage ()

@property (nonatomic, strong, readwrite) WKProcessPool *processPool;

@end

@implementation MSWebHTTPCookieStorage

+ (instancetype)sharedStorage {
    static MSWebHTTPCookieStorage *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MSWebHTTPCookieStorage alloc] init];
    });
    return instance;
}

- (WKProcessPool *)processPool {
    if (!_processPool) {
        _processPool = [[WKProcessPool alloc] init];
    }
    return _processPool;
}

@end
