//
//  AACEncoder.h
//  BatteryCam
//
//  Created by ocean on 2018/6/15.
//  Copyright © 2018年 oceanwing. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AACEncoder : NSObject

-(instancetype)initWithBitrate:(int)bitrate samplerate:(int)samplerate channel:(int)channel;

- (int)encodePCMToAAC:(char *)pcm len:(int)len callBack:(void(^)(char *aacData,int aac_len))completeBlock;

- (void)free;

@end
