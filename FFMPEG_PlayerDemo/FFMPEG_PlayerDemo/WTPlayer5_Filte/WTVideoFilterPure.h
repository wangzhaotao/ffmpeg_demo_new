//
//  WTVideoFilterPure.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/11/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <stdio.h>
#include <libavfilter/avfiltergraph.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>


@interface WTVideoFilterPure : NSObject

-(instancetype)initWithCodecContex:(AVCodecContext*)codecContext;
-(int)pureFilteFrame:(AVFrame*)frame_in frameOut:(AVFrame*)frame_out;

@end

