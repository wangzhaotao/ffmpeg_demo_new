//
//  WTMediaDecoder1.h
//  FFMPEG_PlayerDemo
//
//  Created by wztMac on 2019/5/4.
//  Copyright © 2019 ocean. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>


@interface WTMediaDecoder1 : NSObject

@property (nonatomic, assign) BOOL isNetwork;
@property (nonatomic, assign) BOOL isEOF;

-(void)openMediaWithPath:(NSString*)path;

-(BOOL)validVideo;
-(BOOL)validAudio;

- (BOOL) setupVideoFrameFormat: (int) format;
- (NSUInteger) frameWidth;
- (NSUInteger) frameHeight;

//循环解码
-(NSArray*)decodeFrames:(CGFloat)duration;

#pragma mark 关闭音视频流
-(void)closeFile;

@end

