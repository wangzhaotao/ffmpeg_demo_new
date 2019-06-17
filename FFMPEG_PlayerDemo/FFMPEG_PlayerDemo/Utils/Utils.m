//
//  Utils.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 5/5/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "Utils.h"

@implementation Utils

+(NSArray*)makeDictionaryDataArrayWithTxtFile:(NSString*)file {
    
    NSMutableArray *result = [NSMutableArray array];
    
    NSString *fullPath = [[NSBundle mainBundle]pathForResource:@"PlayList" ofType:@"txt"];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"加载b电视直播源数据失败：%@", error);
    }
    
    NSArray *dataArray = [content componentsSeparatedByString:@"\n"];
    for (NSString *subStr in dataArray) {
        NSArray *tmpArr = [subStr componentsSeparatedByString:@","];
        if (tmpArr.count>1) {
            NSString *name = tmpArr[0];
            NSString *sourcePath = tmpArr[1];
            [result addObject:@{@"name":name, @"path":sourcePath}];
        }
    }
    
    NSString *path1 = @"http://live.xinhuashixun.com/live/chn01/desc.m3u8"; //新华社中文网
    [result insertObject:@{@"name":@"新华社中文网", @"path":path1} atIndex:0];
    path1 = @"http://media.fantv.hk/m3u8/archive/channel2_stream1.m3u8";
    [result insertObject:@{@"name":@"香港台", @"path":path1} atIndex:0];
    
    NSLog(@"直播源数据数组: %@", result);
    return result;
}


+(BOOL)copyFileInPath:(NSString*)resPath toPath:(NSString*)dstPath {
    
    NSError *error = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:resPath]) {
        
        if ([fileManager fileExistsAtPath:dstPath]) {
            [fileManager removeItemAtPath:dstPath error:&error];
            if (error) {
                NSLog(@"删除文件失败: %@", error.description);
                //return NO;
            }
        }
        
        [fileManager copyItemAtPath:resPath toPath:dstPath error:&error];
        if (error) {
            NSLog(@"拷贝文件失败: %@", error.description);
            return NO;
        }
        
        return YES;
    }else{
        NSLog(@"原文件不存在...");
        return NO;
    }
}


@end
