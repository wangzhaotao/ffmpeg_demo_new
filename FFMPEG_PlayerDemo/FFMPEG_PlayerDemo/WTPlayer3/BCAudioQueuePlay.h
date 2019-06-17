//
//  BCAudioQueuePlay.h
//  BatteryCam
//
//  Created by ocean on 2018/1/13.
//  Copyright © 2018年 oceanwing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface BCAudioQueuePlay : NSObject

//doorbell chenqi modify  at 2018.12.24
- (instancetype)initWithSampleRate:(NSInteger)rate channel:(NSInteger)channel;

- (instancetype)initWithAudioType:(NSInteger)audioType;

- (instancetype)initWithAudioStreamBasicDescription:(AudioStreamBasicDescription*)asbd;

- (void)playWithData:(NSData *)data;

- (void)stop;

- (void)clearData;

@end
