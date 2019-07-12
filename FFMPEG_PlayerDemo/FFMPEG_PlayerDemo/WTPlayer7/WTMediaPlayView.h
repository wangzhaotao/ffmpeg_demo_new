//
//  WTMediaPlayView.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Masonry.h"



@interface WTMediaPlayView : UIView

+(instancetype)createPlayViewWithPath:(NSString*)path;
-(void)startPlayMovie;
-(void)stopPlay;

@end

