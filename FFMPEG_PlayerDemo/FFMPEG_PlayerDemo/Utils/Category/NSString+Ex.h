//
//  NSString+Ex.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/13/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Ex)

-(instancetype)strByAppendToCachePath;

-(instancetype)strByAppendToDocPath;
-(instancetype)strByAppendToTempPath;

@end

NS_ASSUME_NONNULL_END
