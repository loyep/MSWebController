//
//  MSWebActivitySafari.m
//  MSWebController
//
//  Created by Maxwell on 2017/5/9.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "MSWebActivitySafari.h"

@implementation MSWebActivitySafari

- (NSString *)activityTitle {
    return NSLocalizedStringFromTable(@"Open In Safari", @"Open in Safari", nil);
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    for (id activityItem in activityItems) {
        if ([activityItem isKindOfClass:[NSURL class]] && [[UIApplication sharedApplication] canOpenURL:activityItem]) {
            return YES;
        }
    }
    return NO;
}

- (void)performActivity {
    BOOL completed = [[UIApplication sharedApplication] openURL:self.URL];
    [self activityDidFinish:completed];
}

- (UIImage *)activityImage {
    NSString *imageName = @"MSWebViewControllerActivitySafari";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        imageName = [imageName stringByAppendingString:@"-iPad"];
    }
    return [UIImage imageWithContentsOfFile:[[NSBundle bundleForClass:NSClassFromString(@"MSWebController")] pathForResource:imageName ofType:@"png"]];
}

@end
