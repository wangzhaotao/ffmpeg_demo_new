//
//  WTPlayerVC5.m
//  FFMPEG_PlayerDemo
//
//  Created by wztMac on 2019/5/4.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTPlayerVC5.h"
#import "KxAudioManager.h"
#import "WTMediaDecoder1.h"
#import "KxMovieGLView.h"
#import "KxMovieDecoder.h"

@interface WTPlayerVC5 ()
{
    //播放队列
    dispatch_queue_t _playSerialQueue;
    //缓冲时长
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    //播放缓冲
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    CGFloat             _bufferedDuration;
    
    BOOL                _buffered;
    
    //6.不甚明了 音视频同步
    CGFloat             _moviePosition;
    
    //7.不甚明了
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    
    //8.不甚明了
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
}
//解码
@property (nonatomic, strong) WTMediaDecoder1 *mediaDecoder;
//opengl渲染界面
@property (nonatomic, strong) KxMovieGLView *glView;
//播放控制
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) BOOL decoding;

@end

@implementation WTPlayerVC5

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters {
    
    //初始化音频播放器
    [[KxAudioManager audioManager] activateAudioSession];
    
    WTPlayerVC5 *vc = [[WTPlayerVC5 alloc]initWithPath:path];
    return vc;
}

-(instancetype)initWithPath:(NSString*)path {
    if (self = [super init]) {
        [self openMediaPath:path];
    }
    return self;
}


#pragma mark Controller Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    //
    self.view.backgroundColor = [UIColor whiteColor];
    
}

-(void)viewDidDisappear:(BOOL)animated {
    
    [self pause];
    
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    if (_playSerialQueue) {
        _playSerialQueue = NULL;
    }
    
    [super viewDidDisappear:animated];
}


#pragma mark private methods
-(void)openMediaPath:(NSString*)path {
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (!weakSelf.mediaDecoder) {
            weakSelf.mediaDecoder = [[WTMediaDecoder1 alloc]init];
            [weakSelf.mediaDecoder openMediaWithPath:path];
            
            //回到主线程
            __strong WTPlayerVC5 *strongSelf = weakSelf;
            if (strongSelf) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    //初始化缓冲
                    [strongSelf initPlayBuffers];
                    //添加视频渲染界面
                    [strongSelf setupPresentView];
                    
                    //开始播放
                    [self restorePlay];
                });
            }
        }
    });
}

#pragma mark 初始化缓冲
-(void)restorePlay {
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    [self play];
}
-(void)pause {
    
    if (!self.playing) {
        return;
    }
    
    self.playing = NO;
    [self enableAudio:NO];
}
-(void)play {
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    if (self.playing) {
        return;
    }
    
    if (!_mediaDecoder.validVideo && _mediaDecoder.validAudio) {
        return;
    }
    
    self.playing = YES;
    //异步解码帧数据
    [self asynDecodeFrames];
    
    //主线程延迟执行
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self tick];
    });
    
    //播放音频
    if (_mediaDecoder.validAudio) {
        [self enableAudio:YES];
    }
}

//初始化缓冲
-(void)initPlayBuffers {
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    _playSerialQueue = dispatch_queue_create("WT_FFMpeg_Play_Seria_Queue", DISPATCH_QUEUE_SERIAL);
    _videoFrames = [NSMutableArray array];
    _audioFrames = [NSMutableArray array];
    
    _minBufferedDuration = 2.0;
    _maxBufferedDuration = 4.0;
    
    if (![_mediaDecoder validVideo]) {
        _minBufferedDuration *= 10;
    }
    
    if (_maxBufferedDuration<_minBufferedDuration) {
        _maxBufferedDuration = _minBufferedDuration*2;
    }
}
//添加视频渲染界面
-(void)setupPresentView {
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGRect bounds = CGRectMake(0, 64, screenSize.width, screenSize.height-64);
    
    if ([_mediaDecoder validVideo]) {
        _glView = [[KxMovieGLView alloc]initWithFrame:bounds decoder:_mediaDecoder];
    }
    
    UIView *frameView = _glView;
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view insertSubview:frameView atIndex:0];
    
    self.view.backgroundColor = [UIColor lightGrayColor];
}

#pragma mark 循环执行 解码帧数据
//循环执行
-(void)tick {
    
    if (_buffered && ((_bufferedDuration>_minBufferedDuration) || _mediaDecoder.isEOF)) {
        NSLog(@"WTPlayerVC2 缓存 _buffered=NO");
        _buffered = NO;
    }
    
    CGFloat interval = 0;
    if (!_buffered) {
        NSLog(@"WTPlayerVC2 缓存 presentFrame");
        interval = [self presentFrame];
    }
    
    if (self.playing) {
        
        const NSUInteger leftFrames = (_mediaDecoder.validVideo ? _videoFrames.count : 0) +
        (_mediaDecoder.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            NSLog(@"WTPlayerVC2 缓存leftFrames=0");
            if (_mediaDecoder.isEOF) {
                NSLog(@"WTPlayerVC2 缓存 isEOF");
                [self pause];
                //[self updateHUD];
                return;
            }
            
            if (_minBufferedDuration>0 && !_buffered) {
                NSLog(@"WTPlayerVC2 缓存 _buffered=YES");
                _buffered = YES;
            }
        }
        
        if (!leftFrames || !(_bufferedDuration>_minBufferedDuration)) {
            [self asynDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval+correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
        //[self updateHUD];
    }
}
//解码帧数据
-(void)asynDecodeFrames {
    
    if (self.decoding) {
        return;
    }
    
    //
    __weak WTPlayerVC5 *weakSelf = self;
    __weak WTMediaDecoder1 *weakDecoder = _mediaDecoder;
    
    const CGFloat duration = _mediaDecoder.isNetwork? .0f: 0.1f;
    self.decoding = YES;
    dispatch_async(_playSerialQueue, ^{
        {
            __strong WTPlayerVC5 *strongSelf = weakSelf;
            if (!strongSelf.playing) {
                return;
            }
        }
        
        BOOL good = YES;
        while (good) {
            good = NO;
            @autoreleasepool {
                __strong WTMediaDecoder1 *strongDecode = weakDecoder;
                if (strongDecode && strongDecode.validVideo && strongDecode.validAudio) {
                    NSArray *frames = [strongDecode decodeFrames:duration];
                    __strong WTPlayerVC5 *strongSelf = weakSelf;
                    if (strongSelf) {
                        [strongSelf addFrames:frames];
                    }
                }
            }
        }
        
        {
            __strong WTPlayerVC5 *strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf.decoding = NO;
            }
        }
    });
    
}
-(BOOL)addFrames:(NSArray*)frames {
    
    //视频帧
    if (_mediaDecoder.validVideo) {
        
        @synchronized(_videoFrames){
            for (KxMovieFrame *frame in frames) {
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration +=frame.duration;
                }
            }
        }
    }
    
    //音频帧
    if (_mediaDecoder.validAudio) {
        @synchronized(_audioFrames) {
            for (KxMovieFrame *frame in frames) {
                if (frame.type == KxMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (!_mediaDecoder.validVideo) {
                        _bufferedDuration += frame.duration;
                    }
                }
            }
        }
        
        if (!_mediaDecoder.validVideo) {
            for (KxMovieFrame *frame in frames) {
                if (frame.type==KxMovieFrameTypeArtwork) {
                    NSLog(@"Error: frame.type ArtWork");
                }
            }
        }
    }
    
    return self.playing && _bufferedDuration<_maxBufferedDuration;
}

-(CGFloat)presentFrame {
    
    CGFloat interval = 0;
    if (_mediaDecoder.validVideo) {
        KxVideoFrame *frame;
        @synchronized(_videoFrames) {
            if (_videoFrames.count>0) {
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame) {
            interval = [self presentVideoFrame:frame];
        }
    }else if (_mediaDecoder.validAudio) {
        
    }
    
    return interval;
}
-(CGFloat)presentVideoFrame:(KxVideoFrame*)frame {
    
    if (_glView) {
        [_glView render:frame];
    }else {
        
        //5.不甚明了 渲染RGB
    }
    
    _moviePosition = frame.position;
    
    return frame.duration;
}

#pragma mark 播放音频
-(void)enableAudio:(BOOL)on {
    
    id <KxAudioManager> audioManager = [KxAudioManager audioManager];
    if (on && _mediaDecoder.validAudio) {
        audioManager.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
            [self audioCallbackFillData:data numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
    }else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}
- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    
    if (_buffered) {
        memset(outData, 0, numFrames*numChannels*sizeof(float));
    }
    
    @autoreleasepool {
        
        while (numFrames>0) {
            if (!_currentAudioFrame) {
                @synchronized(_audioFrames) {
                    NSUInteger count = _audioFrames.count;
                    
                    if (count>0) {
                        KxAudioFrame *frame = _audioFrames[0];
                        
                        if (_mediaDecoder.validVideo) {
                            const CGFloat delta = _moviePosition - frame.position;
                            if (delta<-0.1) {
                                memset(outData, 0, numFrames*numChannels*sizeof(float));
                                
                                break;
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta>0.1 && count>1) {
                                continue;
                            }
                        }else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFrame = frame.samples;
                        _currentAudioFramePos = 0;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                const void *bytes = (Byte*)_currentAudioFrame.bytes+_currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels*sizeof(float);
                const NSUInteger bytesTOCopy = MIN(numFrames*frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesTOCopy/frameSizeOf;
                
                memcpy(outData, bytes, bytesTOCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy*numChannels;
                
                if (bytesTOCopy<bytesLeft) {
                    _currentAudioFramePos += bytesTOCopy;
                }else{
                    _currentAudioFrame = nil;
                }
            }else{
                
                memset(outData, 0, numFrames*numChannels*sizeof(float));
                break;
            }
        }
    }
}

//9.不甚明了 音视频同步
- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate]; //2001-01-01 00:00:00
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    //if ((_tickCounter % 200) == 0)
    //    LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 1.f || correction < -1.f) {
        
        NSLog(@"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

#pragma mark set/get


@end
