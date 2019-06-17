//
//  WTMultiMediaTool.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/13/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#ifndef WTMultiMediaTool_h
#define WTMultiMediaTool_h

#include <stdio.h>

int convertYUVToMP4(const char *file_in_path, const char *file_out_path);
#pragma mark 滤镜
int mainFilteActionC(const char *file_name_in, const char *file_name_out);

#endif /* WTMultiMediaTool_h */
