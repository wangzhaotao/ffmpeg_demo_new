//
//  KxMovieDecoder.h
//  FFMPEG_PlayerDemo
//
//  Created by ocean on 2018/8/15.
//  Copyright © 2018年 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

typedef enum {
    
    kxMovieErrorNone,
    kxMovieErrorOpenFile,
    kxMovieErrorStreamInfoNotFound,
    kxMovieErrorStreamNotFound,
    kxMovieErrorCodecNotFound,
    kxMovieErrorOpenCodec,
    kxMovieErrorAllocateFrame,
    kxMovieErroSetupScaler,
    kxMovieErroReSampler,
    kxMovieErroUnsupported,
    
} kxMovieError;


typedef enum {
    
    KxMovieFrameTypeAudio,
    KxMovieFrameTypeVideo,
    KxMovieFrameTypeArtwork,
    KxMovieFrameTypeSubtitle,
    
} KxMovieFrameType;

typedef enum {
    
    KxVideoFrameFormatRGB,
    KxVideoFrameFormatYUV,
    
} KxVideoFrameFormat;




@interface KxMovieFrame : NSObject
@property (nonatomic, readwrite) KxMovieFrameType type;
@property (nonatomic, readwrite) CGFloat duration;
@property (nonatomic, readwrite) CGFloat position;
@end

@interface KxAudioFrame : KxMovieFrame
@property (nonatomic, strong, readwrite) NSData *samples;
@end

@interface KxVideoFrame : KxMovieFrame
@property (nonatomic, readwrite) KxVideoFrameFormat format;
@property (nonatomic, readwrite) NSUInteger width;
@property (nonatomic, readwrite) NSUInteger height;
@end

@interface KxVideoFrameRGB : KxVideoFrame
@property (nonatomic, readwrite) NSUInteger linesize;
@property (nonatomic, strong, readwrite) NSData *rgb;
-(UIImage*)asImage;
@end

@interface KxVideoFrameYUV :KxVideoFrame
@property (nonatomic, strong, readwrite) NSData *luma;
@property (nonatomic, strong, readwrite) NSData *chromaB;
@property (nonatomic, strong, readwrite) NSData *chromaR;
@end








typedef BOOL(^KxMovieDecoderInterruptCallback)();

@interface KxMovieDecoder : NSObject

@property (readonly, nonatomic, strong) NSString *path;
@property (readonly, nonatomic) BOOL isEOF;
@property (readonly, nonatomic) BOOL isNetwork;
@property (readonly, nonatomic) CGFloat fps;
@property (readonly, nonatomic) BOOL validVideo;
@property (readonly, nonatomic) BOOL validAudio;
@property (readonly, nonatomic) NSUInteger frameWidth;
@property (readonly, nonatomic) NSUInteger frameHeight;
@property (readwrite, nonatomic) BOOL disableDeinterlacing;
@property (readwrite, nonatomic, strong) KxMovieDecoderInterruptCallback interruptCallback;


- (BOOL) setupVideoFrameFormat: (KxVideoFrameFormat) format;
-(NSArray*)decodeFrames:(CGFloat)minDuration;

-(BOOL)openFile: (NSString *) path
            error: (NSError **) perror;
- (BOOL) interruptDecoder;

@end
