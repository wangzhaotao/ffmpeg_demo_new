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
    
    BOOL                _buffered;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    CGFloat             _moviePosition;
    
    CGFloat             _bufferedDuration;
}
@property (nonatomic, strong) WTAudioQueuePlay *pcmPalyer;
@property (nonatomic, strong) OpenglView *openglview;

@property (nonatomic, strong) WTMediaDecode7 *mediaDecoder;

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isDecoding;

@end

@implementation WTMediaPlayView

#pragma mark public methods
+(instancetype)createPlayViewWithPath:(NSString*)path {
    
    WTMediaPlayView *obj = [[WTMediaPlayView alloc]initWithVideo:path];
    return obj;
}

-(void)startPlayMovie {
    
    if (_dispatchQueue) {
        [self play];
    }
}

-(void)stopPlay {
    
    [self.pcmPalyer clearData];
    [self.pcmPalyer stop];
}

#pragma mark 生命周期
-(void)dealloc {
    
    [self.pcmPalyer clearData];
    [self.pcmPalyer stop];
}


#pragma mark private methods
-(instancetype)initWithVideo:(NSString *)moviePath {
    
    if (self = [super init]) {
        
        //
        [self inner_initMediaPlayWithPath:moviePath];
    }
    return self;
}

-(void)inner_initMediaPlayWithPath:(NSString*)path {
    
    _moviePosition = 0;
    
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
    
    self.isPlaying = YES;
    
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
    
    if (_openglview) {
        [_openglview clearFrame];
        _openglview = nil;
    }
    
    self.isPlaying = NO;
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
                    
                    NSArray *frames = [strongSelf.mediaDecoder decodeFrames:0.1];
                    
                    good = [strongSelf addFrames:frames];
                    if (_videoFrames.count>30) {
                        good = NO;
                    }
                }
            }
        }
        
        if (strongSelf) {
            strongSelf.isDecoding = NO;
        }
    });
}
-(void)tick {
    
    if ([self.mediaDecoder validVideo]) {
        @synchronized (_videoFrames) {
            if (_videoFrames.count>0) {
                WTVideoFrame *videoFrame = [_videoFrames objectAtIndex:0];
                [_videoFrames removeObjectAtIndex:0];
                
                
                [_openglview displayYUV420pData:(void*)videoFrame.dataYUV.bytes width:videoFrame.width height:videoFrame.height isKeyFrame:YES];
                
                _moviePosition = videoFrame.position;
            }
        }
    }
    
    if ([self.mediaDecoder validAudio]) {
        @synchronized (_audioFrames) {
            
            WTAudioFrame *audioFrame = nil;
            if (_audioFrames.count>0) {
                NSInteger count = _audioFrames.count;
                
                audioFrame = [_audioFrames objectAtIndex:0];
                [_audioFrames removeObjectAtIndex:0];
                
                const CGFloat delta = _moviePosition - audioFrame.position;
                if (delta<-0.1) {
                    audioFrame = nil;
                }
                if (delta>0.1 && count>1) {
                    audioFrame = nil;
                }
            }
            
            if (audioFrame) {
                [_pcmPalyer playWithData:audioFrame.samples];
            }
        }
    }else {
        WTAudioFrame *audioFrame = [_audioFrames objectAtIndex:0];
        [_audioFrames removeObjectAtIndex:0];
        _moviePosition = audioFrame.position;
        _bufferedDuration -= audioFrame.duration;
    }
    
    if (self.isPlaying) {
        
        const NSUInteger leftFrames = ([self.mediaDecoder validVideo] ? _videoFrames.count:0) +
        ([self.mediaDecoder validAudio] ? _audioFrames.count:0);
        
        if (0 == leftFrames) {
            if (_minBufferedDuration>0 && !_buffered) {
                _buffered = YES;
            }
        }
        
        if (!leftFrames) {
            [self asynDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
}

-(BOOL)addFrames:(NSArray*)frames {
    
    if ([self.mediaDecoder validVideo]) {
        @synchronized (_videoFrames) {
            for (WTMediaFrame *frame in frames) {
                if (frame.type == WTMediaTypeVideo) {
                    [_videoFrames addObject:frame];
                    
                    _bufferedDuration +=frame.duration;
                }
            }
        }
    }
    
    if ([self.mediaDecoder validAudio]) {
        @synchronized (_audioFrames) {
            for (WTMediaFrame *frame in frames) {
                if (frame.type == WTMediaTypeAudio) {
                    [_audioFrames addObject:frame];
                    
                    if (![self.mediaDecoder validVideo]) {
                        _bufferedDuration += frame.duration;
                    }
                }
            }
        }
    }
    
    return _isPlaying && _bufferedDuration<_maxBufferedDuration;
}

- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    if (correction > 1.f || correction < -1.f) {
        
        NSLog(@"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
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
