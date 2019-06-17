//
//  WTMoviePlayerVC.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 4/29/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface WTMoviePlayerVC : UIViewController

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters;

- (BOOL) setupVideoFrameFormat: (int) format;
- (NSUInteger) frameWidth;
- (NSUInteger) frameHeight;

@end

