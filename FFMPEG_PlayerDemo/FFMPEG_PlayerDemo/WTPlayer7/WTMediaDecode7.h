//
//  WTMediaDecode7.h
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "WTAudioQueuePlay.h"

typedef enum
{
    WTMediaTypeAudio,
    WTMediaTypeVideo
} WTMediaType;

@interface WTMediaFrame : NSObject
@property (nonatomic, assign) WTMediaType type;
@property (nonatomic, assign) float       duration;
@property (nonatomic, assign) float       position;

@end

@interface WTVideoFrame : WTMediaFrame
@property (nonatomic, strong, readwrite) NSData *dataYUV;
@property (nonatomic, assign, readwrite) float width;
@property (nonatomic, assign, readwrite) float height;

@end

@interface WTAudioFrame : WTMediaFrame
@property (nonatomic, strong, readwrite) NSData *samples;

@end





@interface WTMediaDecode7 : NSObject

-(instancetype)initWithVideo:(NSString *)moviePath;

-(BOOL)validVideo;
-(BOOL)validAudio;

-(NSArray*)decodeFrames;

@end

