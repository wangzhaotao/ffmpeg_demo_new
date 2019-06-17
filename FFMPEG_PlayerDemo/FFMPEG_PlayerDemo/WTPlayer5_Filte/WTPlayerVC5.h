//
//  WTPlayerVC5.h
//  FFMPEG_PlayerDemo
//
//  Created by wztMac on 2019/5/4.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <UIKit/UIKit.h>

//目标: 重采样、音视频同步;

@interface WTPlayerVC5 : UIViewController

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters;

@end

