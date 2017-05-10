//
//  MSWebActivity.h
//  Example
//
//  Created by Maxwell on 2017/5/8.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MSWebActivity : UIActivity

/// URL to open.
@property (nonatomic, strong) NSURL *URL;
/// Scheme prefix value.
@property (nonatomic, strong) NSString *scheme;

+ (UIImage *)ms_imageNamed:(NSString *)name;

@end
