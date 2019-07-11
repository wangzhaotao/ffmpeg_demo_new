//
//  WTMediaPlayView.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTMediaPlayView.h"
#import "WTAudioQueuePlay.h"
#import "OpenglView.h"
#import "WTMediaDecode7.h"

#define NETWORK_MIN_Data_BUFFERED_DURATION 2.0
#define NETWORK_MAX_Data_BUFFERED_DURATION 4.0

@interface WTMediaPlayView ()
{
    //播放队列
    dispatch_queue_t    _dispatchQueue;
    //缓冲数据帧
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
}
@property (nonatomic, strong) WTAudioQueuePlay *pcmPalyer;
@property (nonatomic, strong) OpenglView *openglview;

@property (nonatomic, strong) WTMediaDecode7 *mediaDecoder;

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isDecoding;

@end

@implementation WTMediaPlayView

+(instancetype)createPlayViewWithPath:(NSString*)path {
    
    WTMediaPlayView *obj = [[WTMediaPlayView alloc]initWithVideo:path];
    return obj;
}

-(instancetype)initWithVideo:(NSString *)moviePath {
    
    if (self = [super init]) {
        
        //
        [self inner_initMediaPlayWithPath:moviePath];
    }
    return self;
}

-(void)inner_initMediaPlayWithPath:(NSString*)path {
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //初始化FFmpeg解码
        weakSelf.mediaDecoder = [[WTMediaDecode7 alloc]initWithVideo:path];
        
        __strong WTMediaPlayView *strongSelf = weakSelf;
        if (strongSelf) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [strongSelf initPlayBuffer];
                
                [strongSelf play];
            });
        }
    });
}

-(void)initPlayBuffer {
    
    _dispatchQueue = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
    _videoFrames = [NSMutableArray array];
    _audioFrames = [NSMutableArray array];
    
    _minBufferedDuration = NETWORK_MIN_Data_BUFFERED_DURATION;
    _maxBufferedDuration = NETWORK_MAX_Data_BUFFERED_DURATION;
    
    _minBufferedDuration *= 10;
    _maxBufferedDuration = _minBufferedDuration*2;
    
    //创建播放界面
    [self setupPlayView];
}

#pragma mark 播放控制
-(void)play {
    
    if (self.isPlaying) {
        return;
    }
    
    if (!self.mediaDecoder.validVideo && !self.mediaDecoder.validAudio) {
        return;
    }
    
    //解码帧数据
    [self asynDecodeFrames];
    
    //循环渲染、解码
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC);
    dispatch_after(popTime, _dispatchQueue, ^{
        [self tick];
    });
    
    
    if (self.mediaDecoder.validAudio) {
        //初始化音频播放器
        [self.pcmPalyer class];
    }
}

-(void)stop {
    
    if (self.pcmPalyer) {
        [self.pcmPalyer stop];
        self.pcmPalyer=nil;
    }
}

#pragma mark private methdos
-(void)asynDecodeFrames {
    
    if (self.isDecoding) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    self.isDecoding = YES;
    dispatch_async(_dispatchQueue, ^{
        
        if (!weakSelf || !weakSelf.isPlaying) {
            weakSelf.isDecoding = NO;
            return;
        }
        
        __strong WTMediaPlayView *strongSelf = weakSelf;
        BOOL good = YES;
        while (good) {
            good = NO;
            
            @autoreleasepool {
                if (strongSelf && (strongSelf.mediaDecoder.validVideo||strongSelf.mediaDecoder.validAudio)) {
                    
                    NSArray *frames = [strongSelf.mediaDecoder decodeFrames];
                    
                    good = [strongSelf addFrames:frames];
                }
            }
        }
        
        if (strongSelf) {
            strongSelf.isDecoding = NO;
        }
    });
}
-(void)tick {
    
    
}

-(BOOL)addFrames:(NSArray*)frames {
    
    if ([self.mediaDecoder validVideo]) {
        @synchronized (_videoFrames) {
            for (WTMediaFrame *frame in frames) {
                if (frame.type == WTMediaTypeVideo) {
                    [_videoFrames addObject:frame];
                }
            }
        }
    }
    
    if ([self.mediaDecoder validAudio]) {
        @synchronized (_audioFrames) {
            for (WTMediaFrame *frame in frames) {
                if (frame.type == WTMediaTypeAudio) {
                    [_audioFrames addObject:frame];
                }
            }
        }
    }
    
    return YES;
}

#pragma mark init methods
-(WTAudioQueuePlay *)pcmPalyer{
    if (!_pcmPalyer) {
        _pcmPalyer=[[WTAudioQueuePlay alloc] initWithSampleRate:kAudioSampleRate channel:kAudioChannel];
    }
    return _pcmPalyer;
}
- (void)setupPlayView{
    self.openglview=[[OpenglView alloc] initWithFrame:self.bounds];
    self.openglview.backgroundColor=[UIColor clearColor];
    [self addSubview:self.openglview];
    self.clipsToBounds=YES;
    [self.openglview setVideoSize:1920 height:1080];
    [self.openglview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(@0);
    }];
}


@end
