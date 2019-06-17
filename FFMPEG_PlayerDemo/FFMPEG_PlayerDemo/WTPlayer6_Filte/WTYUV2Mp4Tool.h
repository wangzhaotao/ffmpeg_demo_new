//
//  WTYUV2Mp4Tool.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/14/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#ifndef WTYUV2Mp4Tool_h
#define WTYUV2Mp4Tool_h

#include <stdio.h>

//res_file: *.yuv; dst_file: *.mp4; tmp: *.H264;
int convertYUVData2MP4Data(const char *res_file, const char *dst_file, const char *tmp);

#endif /* WTYUV2Mp4Tool_h */
