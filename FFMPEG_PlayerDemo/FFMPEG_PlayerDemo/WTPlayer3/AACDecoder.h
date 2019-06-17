//
//  AACDecoder.h
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AACDecoderDelegate;

@interface AACDecoder : NSObject

- (instancetype)init;

-(void)creatConverter;

-(void)clearConverter;

- (void)pushData:(uint8_t*)data size:(size_t)size completion:(void(^)(NSData *pcmData))block;

@end
