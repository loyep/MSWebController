//
//  MSWebActivity.m
//  Example
//
//  Created by Maxwell on 2017/5/8.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "MSWebActivity.h"

@implementation MSWebActivity

- (NSString *)activityType {
    return NSStringFromClass([self class]);
}

- (UIImage *)activityImage {
    NSString *imageName = self.activityType;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        imageName = [self.activityType stringByAppendingString:@"-iPad"];
    }
    return [MSWebActivity ms_imageNamed:imageName];
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    for (id activityItem in activityItems) {
        if ([activityItem isKindOfClass:[NSURL class]]) {
            self.URL = activityItem;
        }
    }
}

+ (UIImage *)ms_imageNamed:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleWithURL:[[NSBundle bundleForClass:NSClassFromString(@"MSWebController")] URLForResource:@"MSWebController" withExtension:@"bundle"]];
    UIImage *image;
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
    image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
#elif __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
    image = [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
#else
    if ([UIImage respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
        image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    } else {
        image = [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
    }
#endif
    return image;
}

@end
