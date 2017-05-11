//
//  MSWebHTTPCookie.h
//  Pods
//
//  Created by eony on 11/05/2017.
//
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface MSWebHTTPCookieStorage : NSObject

+ (instancetype)sharedStorage;

@property (nonatomic, strong, readonly) WKProcessPool *processPool;

@end

