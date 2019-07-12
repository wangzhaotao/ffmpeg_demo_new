//
//  WTAudioQueuePlay.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kAudioSampleRate 44100 //16000
#define kAudioBitRate 32000
#define kAudioChannel 2


@interface WTAudioQueuePlay : NSObject

- (instancetype)initWithSampleRate:(NSInteger)rate channel:(NSInteger)channel;

- (instancetype)initWithAudioType:(NSInteger)audioType;


- (void)playWithData:(NSData *)data;

- (void)stop;

- (void)clearData;

@end


