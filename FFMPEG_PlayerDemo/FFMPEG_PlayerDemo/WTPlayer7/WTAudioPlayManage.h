//
//  WTAudioPlayManage.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/16/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kAudioPlaySampleRate 44100 //16000
#define kAudioPlayBitRate    32000
#define kAudioPlayChannel    2


@interface WTAudioPlayManage : NSObject

- (instancetype)initWithSampleRate:(int)sampleRate;
- (void)playWith:(void *)audioData length:(unsigned int)length;

-(void)stop;

@end

