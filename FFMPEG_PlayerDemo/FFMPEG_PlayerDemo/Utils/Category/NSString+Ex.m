//
//  NSString+Ex.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/13/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "NSString+Ex.h"

@implementation NSString (Ex)

-(instancetype)strByAppendToCachePath{
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:self.lastPathComponent];
}



-(instancetype)strByAppendToDocPath{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:self.lastPathComponent];
}
-(instancetype)strByAppendToTempPath{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:self.lastPathComponent];
}

@end
