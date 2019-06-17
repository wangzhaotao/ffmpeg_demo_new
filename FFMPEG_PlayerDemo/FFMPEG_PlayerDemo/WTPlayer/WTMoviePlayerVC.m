//
//  WTMoviePlayerVC.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 4/29/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTMoviePlayerVC.h"
#import "KxAudioManager.h"
#import <CoreGraphics/CoreGraphics.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#import "libavutil/pixdesc.h"
#import "KxAudioManager.h"
#import <Accelerate/Accelerate.h>
#import "KxMovieGLView.h"
#import "KxLogger.h"
#import "KxMovieDecoder.h"

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase) {
    
    CGFloat fps, timebase;
    if (st->time_base.den && st->time_base.num) {
        timebase = av_q2d(st->time_base);
    }else if (st->codec->time_base.den && st->codec->time_base.num) {
        timebase = av_q2d(st->codec->time_base);
    }else {
        timebase = defaultTimeBase;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num) {
        fps = av_q2d(st->avg_frame_rate);
    }else if (st->r_frame_rate.den && st->r_frame_rate.num) {
        fps = av_q2d(st->r_frame_rate);
    }else {
        fps =  1.0/timebase;
    }
    
    if (pFPS) {
        *pFPS = fps;
    }
    if (pTimeBase) {
        *pTimeBase = timebase;
    }
}

static BOOL audioCodecIsSupported(AVCodecContext *audioCodecCtx) {
    if (audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16) {
        
        id<KxAudioManager> audioManager = [KxAudioManager audioManager];
        return (int)audioManager.samplingRate == audioCodecCtx->sample_rate &&
        audioManager.numOutputChannels==audioCodecCtx->channels;
    }
    return NO;
}
static NSData* wt_copyFrameData(UInt8 *src, int linesize, int width, int height) {
    
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength:width*height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i=0; i<height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}


@interface WTMoviePlayerVC () {
    
    AVFormatContext *_formatCxt;
    
    NSArray             *_videoStreams;
    NSArray             *_audioStreams;
    
    NSInteger           _videoStream;
    NSInteger           _audioStream;
    AVCodecContext      *_videoCodecCtx;
    AVCodecContext      *_audioCodecCtx;
    AVFrame             *_videoFrame;
    AVFrame             *_audioFrame;
    
    
    //播放缓冲
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    //播放队列
    dispatch_queue_t    playSerialQueue;
    //缓冲时长
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    
    //播放界面
    KxMovieGLView       *_glView;
    CGFloat             _position;
    CGFloat             _bufferedDuration;
    
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
    
    //音频重采样
    SwrContext          *_swrContext;
    struct SwrContext   *_swsContext;
    AVPicture           _picture;
    BOOL                _pictureValid;
    
    BOOL                _buffered;
    CGFloat             _moviePosition;
    NSUInteger          _tickCounter;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
}
@property (nonatomic, assign) CGFloat fps;
@property (nonatomic, assign) CGFloat videoTimeBase;
@property (nonatomic, assign) CGFloat audioTimeBase;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) BOOL decoding;
@property (nonatomic, assign) BOOL isEOF;

@end

@implementation WTMoviePlayerVC

+(void)initialize {
    av_register_all();
    avformat_network_init();
}

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters {
    //音频
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];
    
    //视频
    return [[WTMoviePlayerVC alloc] initWithContentPath: path parameters: parameters];
}

-(id)initWithContentPath:(NSString*)path parameters:(NSDictionary*)parameters {
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf openMediaPath:path];
        });
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    
}

-(void)viewDidDisappear:(BOOL)animated {
    
    [self pause];
    
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    if (playSerialQueue) {
        playSerialQueue = NULL;
    }
    
    [super viewDidDisappear:animated];
}




#pragma mark private methods
-(void)openMediaPath:(NSString*)path {
    
    NSLog(@"---- %@ ----", NSStringFromSelector(_cmd));
    
    //1.AVFormatContext是一个贯穿始终的结构体，很多函数都以它为参数；是FFMpeg的解封装功能的结构体；
    AVFormatContext *formatCxt = NULL;
    //(1)avformat_alloc_context
    //(2)avformat_open_input
    if (avformat_open_input(&formatCxt, [path cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL)<0) {
        if (formatCxt) {
            avformat_free_context(formatCxt);
        }
        NSLog(@"FFMpeg 解封装功能结构体s初始化失败...");
        return;
    }
    NSLog(@"---- avformat_open_input success ----");
    
    //2.为formatCxt->streams填充上正确的流信息
    if (avformat_find_stream_info(formatCxt, NULL)<0) {
        avformat_close_input(&formatCxt);
        NSLog(@"ormatCxt->streams填充上正确的流信息-失败");
        return;
    }
    _formatCxt = formatCxt;
    
    //3.遍历视频流、遍历音频流
    NSMutableArray *videoStreams = [NSMutableArray array];
    NSMutableArray *audioStreams = [NSMutableArray array];
    for (int i=0; i<_formatCxt->nb_streams; i++) {
        if (_formatCxt->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO) {
            [videoStreams addObject:@(i)];
        }else if (_formatCxt->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO) {
            [audioStreams addObject:@(i)];
        }
    }
    _videoStreams = videoStreams;
    _audioStreams = audioStreams;
    
    
    //4.1 查找视频流
    [self findBestVideoStream];
    
    //4.2 查找音频流
    [self findBestAudioStream];
    
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //5.初始化播放缓冲数据
        [weakSelf initPlauBufferDatas];
        
        //6.播放
        [weakSelf play];
    });
    
}

//4.1 查找视频流
-(void)findBestVideoStream {
    
    for (NSNumber *number in _videoStreams) {
        NSUInteger vStream = number.integerValue;
        if (0 == (_formatCxt->streams[vStream]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
            
            AVCodecContext *videoCodeCtx = _formatCxt->streams[vStream]->codec;
            //获取视频解码器
            AVCodec *codec = avcodec_find_decoder(videoCodeCtx->codec_id);
            if (!codec) {
                NSLog(@"查找视频解码器失败");
                return;
            }
            
            if (avcodec_open2(videoCodeCtx, codec, NULL)<0) {
                NSLog(@"打开视频解码器失败");
                return;
            }
            
            //4.1.1 AVFrame结构体 用于存储音、视频原始数据(YUV、RGB、PCM)
            _videoFrame = av_frame_alloc();
            if (!_videoFrame) {
                NSLog(@"初始化视频帧失败");
            }
            
            //4.2
            _videoStream = vStream;
            _videoCodecCtx = videoCodeCtx;
            
            AVStream *st = _formatCxt->streams[vStream];
            avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
        }else{
            //artworkStream
        }
    }
}

//4.2 查找音频流
-(void)findBestAudioStream {
    
    for (NSNumber *number in _audioStreams) {
        NSUInteger aStream = number.integerValue;
        AVCodecContext *audioCodecCtx = _formatCxt->streams[aStream]->codec;
        AVCodec *codec = avcodec_find_decoder(audioCodecCtx->codec_id);
        if (!codec) {
            NSLog(@"查找音频解码器失败");
            return;
        }
        
        if (avcodec_open2(audioCodecCtx, codec, NULL)<0) {
            NSLog(@"打开音频解码器失败");
            return;
        }
        
        //4.2.1音频重采样
        SwrContext *swrContex = NULL;
        if (!audioCodecIsSupported(audioCodecCtx)) {
            id<KxAudioManager> audioManager = [KxAudioManager audioManager];
            NSLog(@"audio-channels: %d, audio-sample: %f", audioManager.numOutputChannels, audioManager.samplingRate);
            NSLog(@"codec-channels: %d, codec-fmt: %d, codec-sample: %d", audioCodecCtx->sample_fmt, audioCodecCtx->channels, audioCodecCtx->sample_rate);
            swrContex = swr_alloc_set_opts(NULL, av_get_default_channel_layout(audioManager.numOutputChannels),
                                             AV_SAMPLE_FMT_S16,
                                             audioManager.samplingRate,
                                             av_get_default_channel_layout(audioCodecCtx->channels),
                                             audioCodecCtx->sample_fmt,
                                             audioCodecCtx->sample_rate,
                                             0,
                                             NULL);
            if (!swrContex || swr_init(swrContex)) {
                if (swrContex) {
                    swr_free(&swrContex);
                }
                avcodec_close(_audioCodecCtx);
                NSLog(@"音频重采样 h初始化失败...");
                //return;
            }
        }
        
        //4.2.2 AVFrame结构体 用于存储音视频原始数据
        _audioFrame = av_frame_alloc();
        if (!_audioFrame) {
            NSLog(@"初始化音频帧失败");
            return;
        }
        
        //4.2.3
        _audioStream = aStream;
        _audioCodecCtx = audioCodecCtx;
        _swrContext = swrContex;
        
        AVStream *st = _formatCxt->streams[aStream];
        avStreamFPSTimeBase(st, 0.025, &_fps, &_audioTimeBase);
    }
}

//5.初始化播放缓冲数据
-(void)initPlauBufferDatas {
    
    playSerialQueue = dispatch_queue_create("WTFFMpeg_Play_Queue", DISPATCH_QUEUE_SERIAL);
    _videoFrames = [NSMutableArray array];
    _audioFrames = [NSMutableArray array];
    
    //network
    _minBufferedDuration = 2.0;
    _maxBufferedDuration = 4.0;
    
    if (![self validVideo]) {
        _minBufferedDuration *= 10;
    }
    if (_maxBufferedDuration < _minBufferedDuration) {
        _maxBufferedDuration = _minBufferedDuration*2;
    }
    
    //添加渲染界面
    if (self.isViewLoaded) {
        [self setupPresentView];
    }
}

//6.播放
-(void)play {
    
    if (self.playing) {
        return;
    }
    
    if (![self validVideo] && ![self validAudio]) {
        return;
    }
    
    self.playing = YES;
    
    [self asyncDecodeFrames];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self tick];
    });
    
    if ([self validAudio]) {
        [self enableAudio:YES];
    }
}


#pragma mark private methods
- (BOOL) validVideo
{
    return _videoStream != -1;
}
- (BOOL) validAudio
{
    return _audioStream != -1;
}
//创建播放界面
-(void)setupPresentView {
    
    CGRect bounds = CGRectMake(30, 64, Screen_Width-60, Screen_Height-64-60);//self.view.boudns;
    
    if ([self validVideo]) {
        _glView = [[KxMovieGLView alloc]initWithFrame:bounds decoder:self];
    }
    
    UIView *frameView = _glView;
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view insertSubview:frameView atIndex:0];
    
    self.view.backgroundColor = [UIColor blackColor];
}

- (BOOL) setupVideoFrameFormat: (int) format {
    
    return YES;
}
- (NSUInteger) frameWidth {
    return _videoCodecCtx ? _videoCodecCtx->width : 0;
}
- (NSUInteger) frameHeight {
    return _videoCodecCtx ? _videoCodecCtx->height : 0;
}

//解码帧
-(void)asyncDecodeFrames {
    
    
    //decoding
    if (_decoding) {
        return;
    }
    
    __strong WTMoviePlayerVC *weakSelf = self;
    
    const CGFloat duration = 0.0f;
    self.decoding = YES;
    dispatch_async(playSerialQueue, ^{
        
        {
            __strong WTMoviePlayerVC *strongSelf = weakSelf;
            if (!strongSelf.playing) {
                return;
            }
        }
        
        BOOL good = YES;
        while (good) {
            good = NO;
            @autoreleasepool {
                
                __strong WTMoviePlayerVC *strongSelf = weakSelf;
                if (strongSelf && ([strongSelf validVideo] || [strongSelf validAudio])) {
                    
                    NSArray *frames = [strongSelf decodeFrames:duration];
                    good = [strongSelf addFrames:frames];
                }
            }
        }
        
        {
            __strong WTMoviePlayerVC *strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf.decoding = NO;
            }
        }
    });
}
-(NSArray*)decodeFrames:(CGFloat)minDuration {
    
    if (_videoStream==-1 && _audioStream==-1) {
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    AVPacket packet;
    CGFloat decodeDuration = 0;
    BOOL finished = NO;
    while (!finished) {
        
        if (av_read_frame(_formatCxt, &packet)<0) {
            _isEOF = YES;
            break;
        }
        
        if (packet.stream_index == _videoStream) {
            int pktSize = packet.size;
            
            while (pktSize>0) {
                
                int gotframe = 0;
                int len = avcodec_decode_video2(_videoCodecCtx,
                                                _videoFrame,
                                                &gotframe,
                                                &packet);
                if (len<0) {
                    NSLog(@"Error: decode video error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    
                    KxVideoFrame *frame = [self handleVideoFrame];
                    if (frame) {
                        [result addObject:frame];
                        
                        _position = frame.position;
                        decodeDuration += frame.duration;
                        if (decodeDuration>minDuration) {
                            finished = YES;
                        }
                    }
                }
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
            }
        }else if (packet.stream_index == _audioStream) {
            
            int pktSize = packet.size;
            while (pktSize>0) {
                
                int gotFrame = 0;
                int len = avcodec_decode_audio4(_audioCodecCtx,
                                                _audioFrame,
                                                &gotFrame,
                                                &packet);
                if (len<0) {
                    NSLog(@"Error: decode audio error, skip packet");
                    break;
                }
                
                if (gotFrame) {
                    KxAudioFrame *frame = [self handleAudioFrame];
                    if (frame) {
                        [result addObject:frame];
                        
                        if (_videoStream == -1) {
                            _position = frame.position;
                            decodeDuration += frame.duration;
                            if (decodeDuration>minDuration) {
                                finished = YES;
                            }
                        }
                    }
                }
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
            }
        }
        
        av_free_packet(&packet);
    }
    
    return result;
}

-(BOOL)addFrames:(NSArray*)frames {
    
    if ([self validVideo]) {
        
        @synchronized(_videoFrames){
            for (KxMovieFrame *frame in frames) {
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration +=frame.duration;
                }
            }
        }
    }
    
    if ([self validAudio]) {
        
        @synchronized(_audioFrames) {
            for (KxMovieFrame *frame in frames) {
                if (frame.type == KxMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (![self validVideo]) {
                        _bufferedDuration += frame.duration;
                    }
                }
            }
        }
        
        if (![self validVideo]) {
            for (KxMovieFrame *frame in frames) {
                if (frame.type==KxMovieFrameTypeArtwork) {
                    NSLog(@"Error: frame.type ArtWork");
                }
            }
        }
    }
    
    return self.playing && _bufferedDuration<_maxBufferedDuration;
}
-(KxVideoFrame*)handleVideoFrame {
    
    if (!_videoFrame->data[0]) {
        return nil;
    }
    
    KxVideoFrame *frame;
    KxVideoFrameFormat _videoFrameFormat = KxVideoFrameFormatYUV;
    if (_videoFrameFormat == KxVideoFrameFormatYUV) {
        KxVideoFrameYUV *yuvFrame = [[KxVideoFrameYUV alloc]init];
        yuvFrame.luma = wt_copyFrameData(_videoFrame->data[0],
                                      _videoFrame->linesize[0],
                                      _videoCodecCtx->width,
                                      _videoCodecCtx->height);
        yuvFrame.chromaB = wt_copyFrameData(_videoFrame->data[1],
                                         _videoFrame->linesize[1],
                                         _videoCodecCtx->width/2,
                                         _videoCodecCtx->height/2);
        yuvFrame.chromaR = wt_copyFrameData(_videoFrame->data[2],
                                         _videoFrame->linesize[2],
                                         _videoCodecCtx->width/2,
                                         _videoCodecCtx->height/2);
        
        frame = yuvFrame;
    }else {
        
        if (!_swsContext && ![self setupScaler]) {
            NSLog(@"Error: fail setup video scaler");
            return nil;
        }

        sws_scale(_swsContext, (const uint8_t **)_videoFrame->data,
                  _videoFrame->linesize,
                  0,
                  _videoCodecCtx->height,
                  _picture.data,
                  _picture.linesize);

        KxVideoFrameRGB *rgbFrame = [[KxVideoFrameRGB alloc]init];
        rgbFrame.linesize = _picture.linesize[0];
        rgbFrame.rgb = [NSData dataWithBytes:_picture.data[0] length:rgbFrame.linesize*_videoFrame->height];
        frame = rgbFrame;
    }
    
    frame.width = _videoCodecCtx->width;
    frame.height = _videoCodecCtx->height;
    frame.position =av_frame_get_best_effort_timestamp(_videoFrame)*_videoTimeBase;
    
    const int64_t frameDuration = av_frame_get_pkt_duration(_videoFrame);
    if (frameDuration) {
        
        frame.duration = frameDuration*_videoTimeBase;
        frame.duration += _videoFrame->repeat_pict*_videoTimeBase*0.5;
    }else {
        
        frame.duration = 1.0/_fps;
    }
    
    return frame;
}

-(KxAudioFrame*)handleAudioFrame {
    
    if (!_audioFrame->data[0]) {
        return nil;
    }
    
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    const NSUInteger numChannels = audioManager.numOutputChannels;
    NSUInteger numFrames;
    void *audioData;
    if (_swrContext) {
        
        const NSUInteger ratio = MAX(1, audioManager.samplingRate/_audioCodecCtx->sample_rate)*MAX(1, audioManager.numOutputChannels / _audioCodecCtx->channels)*2;
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       audioManager.numOutputChannels,
                                                       _audioFrame->nb_samples*ratio,
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        if (!_swrBuffer || _swrBufferSize<bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = {_swrBuffer, 0};
        numFrames = swr_convert(_swrContext,
                                outbuf,
                                _audioFrame->nb_samples*ratio,
                                (const uint8_t **)_audioFrame->data,
                                _audioFrame->nb_samples);
        if (numFrames<0) {
            NSLog(@"Error: fail resample audio");
            return nil;
        }
        
        audioData = _swrBuffer;
    }else {
        
        if (_audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSLog(@"Error: bucheck, audio format is invalid");
            return nil;
        }
        audioData = _audioFrame->data[0];
        numFrames = _audioFrame->nb_samples;
    }
    
    const NSUInteger numElements = numFrames*numChannels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements*sizeof(float)];
    
    float scale = 1.0/(float)INT16_MAX;
    vDSP_vflt16((SInt16*)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    KxAudioFrame *frame = [[KxAudioFrame alloc]init];
    frame.position = av_frame_get_best_effort_timestamp(_audioFrame)*_audioTimeBase;
    frame.duration = av_frame_get_pkt_duration(_audioFrame)*_audioTimeBase;
    frame.samples = data;
    
    if (frame.duration==0) {
        frame.duration = frame.samples.length/(sizeof(float)*numChannels*audioManager.samplingRate);
    }
    
    return frame;
}

-(BOOL)setupScaler {
    [self chooseScaler];
    
    _pictureValid = avpicture_alloc(&_picture,
                                    AV_PIX_FMT_RGB24,
                                    _videoCodecCtx->width,
                                    _videoCodecCtx->height);
    if (!_pictureValid) {
        return NO;
    }
    
    _swsContext = sws_getCachedContext(_swsContext,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       _videoCodecCtx->pix_fmt,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       AV_PIX_FMT_RGB24,
                                       SWS_FAST_BILINEAR,
                                       NULL,
                                       NULL,
                                       NULL);
    
    return _swsContext != NULL;
}
-(void)chooseScaler {
    
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    if (_pictureValid) {
        avpicture_free(&_picture);
        _pictureValid = NO;
    }
}

-(void)tick {
    
    if (_buffered && ((_bufferedDuration>_minBufferedDuration) || self.isEOF)) {
        _buffered = NO;
    }
    
    CGFloat interval = 0;
    if (!_buffered) {
        interval = [self presentFrame];
    }
    
    if (self.playing) {
        
        const NSUInteger leftFrames = (self.validVideo ? _videoFrames.count : 0) +
        (self.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            if (self.isEOF) {
                [self pause];
                //[self updateHUD];
                return;
            }
            
            if (_minBufferedDuration>0 && !_buffered) {
                _buffered = YES;
            }
        }
        
        if (!leftFrames || !(_bufferedDuration>_minBufferedDuration)) {
            [self asyncDecodeFrames];
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
-(CGFloat)presentFrame {
    
    CGFloat interval = 0;
    if (self.validVideo) {
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
    }else if (self.validAudio) {
    }
    
    return interval;
}
-(CGFloat)presentVideoFrame:(KxVideoFrame*)frame {
    
    if (_glView) {
        [_glView render:frame];
    }else {
        
        KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB*)frame;
        //_imageView.image = [rgbFrame asImage];
    }
    
    _moviePosition = frame.position;
    
    return frame.duration;
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
    
    //if ((_tickCounter % 200) == 0)
    //    LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 1.f || correction < -1.f) {
        
        NSLog(@"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

-(void)enableAudio:(BOOL)on {
    
    id <KxAudioManager> audioManager = [KxAudioManager audioManager];
    if (on && self.validAudio) {
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
                        
                        if (self.validVideo) {
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
-(void)pause {
    
    if (!self.playing) {
        return;
    }
    
    self.playing = NO;
    [self enableAudio:NO];
}

@end
