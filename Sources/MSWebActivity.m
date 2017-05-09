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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return [UIImage imageNamed:[NSString stringWithFormat:@"MSWebController.bundle/%@",[self.activityType stringByAppendingString:@"-iPad"]]];
    else
        return [UIImage imageNamed:[NSString stringWithFormat:@"MSWebController.bundle/%@",self.activityType]];
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    for (id activityItem in activityItems) {
        if ([activityItem isKindOfClass:[NSURL class]]) {
            self.URL = activityItem;
        }
    }
}

@end
