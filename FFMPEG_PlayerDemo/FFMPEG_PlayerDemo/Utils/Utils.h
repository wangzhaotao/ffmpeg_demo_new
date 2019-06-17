//
//  Utils.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 5/5/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+Ex.h"

@interface Utils : NSObject

+(NSArray*)makeDictionaryDataArrayWithTxtFile:(NSString*)file;

+(BOOL)copyFileInPath:(NSString*)resPath toPath:(NSString*)dstPath;

@end

