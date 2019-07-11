//
//  WTMediaDecode7.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTMediaDecode7.h"
#import <libavformat/avformat.h>
#import <libswscale/swscale.h>
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#import <Accelerate/Accelerate.h>
#import "NSString+Ex.h"


static void avStreamFPSTimeBase_wzt(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase) {
    
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
static BOOL audioCodecIsSupported_wzt(AVCodecContext *audioCodecCtx) {
    if (audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16) {
        
        return (int)kAudioSampleRate == audioCodecCtx->sample_rate &&
        kAudioChannel==audioCodecCtx->channels;
    }
    return NO;
}

@interface WTMediaDecode7 () {
    
    AVFormatContext     *_avFormatCtx;
    NSInteger           _videoStream;
    NSInteger           _audioStream;
    NSArray             *_videoStreams;
    NSArray             *_audioStreams;
    
    AVCodecContext      *_videoCodecCtx;
    AVCodecContext      *_audioCodecCtx;
    
    AVFrame             *_videoFrame;
    AVFrame             *_audioFrame;
    
    CGFloat             _videoTimeBase;
    CGFloat             _audioTimeBase;
    
    SwrContext          *_swrContex;
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
}

@property (readonly, nonatomic) CGFloat fps;

@end

@implementation WTMediaDecode7

+(void)initialize {
    av_register_all();
    avformat_network_init();
}

#pragma mark public methods
-(instancetype)initWithVideo:(NSString *)moviePath {
    
    if (!(self = [super init])) {
        return nil;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int error = [self inner_initWithVideo:moviePath];
        if (error!=0) {
            NSLog(@"播放失败....");
        }
    });
    
    return self;
}

-(BOOL)validVideo {
    return _videoStream != -1;
}
-(BOOL)validAudio {
    
    return _audioStream != -1;
}

-(NSArray*)decodeFrames:(float)duration {
    
    if (![self validAudio] && ![self validVideo]) {
        return nil;
    }
    if (!_avFormatCtx) {
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    AVPacket packet;
    BOOL finished = NO;
    while (!finished) {
        
        int err_code = av_read_frame(_avFormatCtx, &packet);
        if (err_code<0) {
            break;
        }
        
        if (packet.stream_index == _videoStream) {
            int pktSize = packet.size;
            
            while (pktSize>0) {
                
                int gotFrame = 0;
                int len = avcodec_decode_video2(_videoCodecCtx, _videoFrame, &gotFrame, &packet);
                
                if (len<0) {
                    NSLog(@"解码视频数据包失败....");
                    break;
                }
                
                if (gotFrame) {
                    //视频帧
                    int width = _videoCodecCtx->width,
                    height = _videoCodecCtx->height,
                    frameLen = 0;
                    int w0 = MIN(width, _videoFrame->linesize[0]);
                    frameLen += w0*height;
                    int w1 = MIN(width/2, _videoFrame->linesize[1]);
                    frameLen += w1*height;
                    int w2 = MIN(width/2, _videoFrame->linesize[2]);
                    frameLen += w2*height;
                    
                    NSMutableData *dataYUV = [NSMutableData dataWithLength:frameLen];
                    Byte *yuvBytes = dataYUV.mutableBytes;
                    memcpy(yuvBytes, _videoFrame->data[0], w0*height);
                    memcpy(yuvBytes+w0*height, _videoFrame->data[1], w1*height);
                    memcpy(yuvBytes+w0*height+w1*height, _videoFrame->data[2], w2*height);
                    
                    WTVideoFrame *videoFrame = [[WTVideoFrame alloc]init];
                    videoFrame.dataYUV = dataYUV;
                    
                    videoFrame.width = _videoCodecCtx->width;
                    videoFrame.height = _videoCodecCtx->height;
                    
                    if (videoFrame) {
                        //音视频同步
                        videoFrame.position =av_frame_get_best_effort_timestamp(_videoFrame)*_videoTimeBase;
                        
                        const int64_t frameDuration = av_frame_get_pkt_duration(_videoFrame);
                        if (frameDuration) {
                            
                            videoFrame.duration = frameDuration*_videoTimeBase;
                            videoFrame.duration += _videoFrame->repeat_pict*_videoTimeBase*0.5;
                        }else {
                            
                            videoFrame.duration = 1.0/_fps;
                        }
                        
                        [result addObject:videoFrame];
                    }
                    
                }
                
                
                if (len==0) {
                    break;
                }
                
                pktSize -= len;
            }
            
        }else if (packet.stream_index == _audioStream) {
            int pktSize = packet.size;
            
            while (pktSize>0) {
                
                int gotframe = 0;
                int len = avcodec_decode_audio4(_audioCodecCtx, _audioFrame, &gotframe, &packet);
                
                if (len<0) {
                    NSLog(@"解码音频数据包失败...");
                    break;
                }
                if (gotframe) {
                    WTAudioFrame *frame = [self handleAudioFrame];
                    if (frame) {
                        [result addObject:frame];
                        
                        if (_videoStream == -1) {
//                            _position = frame.position;
//                            decodeDuration += frame.duration;
//                            if (decodeDuration>minDuration) {
//                                finished = YES;
//                            }
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
-(WTAudioFrame*)handleAudioFrame {
    
    if (!_audioFrame->data[0]) {
        return nil;
    }
    
    const NSUInteger numChannels = kAudioChannel;
    NSUInteger numFrames;
    void *audioData;
    if (_swrContex) {
        
        const NSUInteger ratio = MAX(1, kAudioSampleRate/_audioCodecCtx->sample_rate)*MAX(1, numChannels / _audioCodecCtx->channels)*2;
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       numChannels,
                                                       _audioFrame->nb_samples*ratio,
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        if (!_swrBuffer || _swrBufferSize<bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = {_swrBuffer, 0};
        numFrames = swr_convert(_swrContex,
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
    
    WTAudioFrame *frame = [[WTAudioFrame alloc]init];
    frame.position = av_frame_get_best_effort_timestamp(_audioFrame)*_audioTimeBase;
    frame.duration = av_frame_get_pkt_duration(_audioFrame)*_audioTimeBase;
    frame.samples = data;
    
    if (frame.duration==0) {
        frame.duration = frame.samples.length/(sizeof(float)*numChannels*kAudioSampleRate);
    }
    
    return frame;
}

#pragma mark private methods
- (int)inner_initWithVideo:(NSString *)moviePath {
    
    BOOL isNetwork = [moviePath isNetworkPath];
    if (isNetwork) {
        avformat_network_init();
    }
    
    //1.
    AVFormatContext *avFormatCtx = NULL;
    int err_code = avformat_open_input(&avFormatCtx, [moviePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL);
    if (err_code<0) {
        NSLog(@"打开多媒体资源失败....");
        if (avFormatCtx) {
            avformat_free_context(avFormatCtx);
        }
        return -1;
    }
    _avFormatCtx = avFormatCtx;
    
    
    //2.
    //为avFormatCtx填充上正确的流信息avFormatCtx->streams
    err_code = avformat_find_stream_info(avFormatCtx, NULL);
    if (err_code<0) {
        NSLog(@"查找流信息失败....");
        avformat_close_input(&avFormatCtx);
        return -1;
    }
    
    //3.查找音视频流
    //3.1 视频流数组
    _videoStream = -1;
    enum AVMediaType codecType = AVMEDIA_TYPE_VIDEO;
//    NSMutableArray *videoStreams = [NSMutableArray array];
//    for (int i=0; i<avFormatCtx->nb_streams; i++) {
//        if (codecType == avFormatCtx->streams[i]->codec->codec_type) {
//            //视频流
//            [videoStreams addObject:[NSNumber numberWithInt:i]];
//        }
//    }
//    _videoStreams = videoStreams;
//
//    for (NSNumber *number in _videoStreams) {
//        NSUInteger iStream = [number integerValue];
//        if (0 == (avFormatCtx->streams[iStream]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
//
//        }
//    }
    //3.1.1
    AVCodec *videoCodec = NULL;
    _videoStream = av_find_best_stream(_avFormatCtx, codecType, -1, -1, &videoCodec, 0);
    
    //视频解码上下文
    _videoCodecCtx = avFormatCtx->streams[_videoStream]->codec;
    
    //解码器
    //AVCodec *videoCodec = avcodec_find_decoder(_videoCodecCtx->codec_id);
    err_code = avcodec_open2(_videoCodecCtx, videoCodec, NULL);
    if (err_code<0) {
        NSLog(@"打开视频解码器失败...");
        return -1;
    }
    
    //3.1.2
    _videoFrame = av_frame_alloc();
    if (!_videoFrame) {
        avcodec_close(_videoCodecCtx);
        NSLog(@"初始化视频帧失败....");
        return -1;
    }
    
    //3.1.3 音视频同步
    AVStream *st = _avFormatCtx->streams[_videoStream];
    avStreamFPSTimeBase_wzt(st, 0.04, &_fps, &_videoTimeBase);
    
    
    //3.2 音频流数组
    _audioStream = -1;
    codecType = AVMEDIA_TYPE_AUDIO;
    //3.2.1
    AVCodec *audioCodec = NULL;
    _audioStream = av_find_best_stream(_avFormatCtx, codecType, -1, -1, &audioCodec, 0);
    
    //音频解码上下文
    _audioCodecCtx = _avFormatCtx->streams[_audioStream]->codec;

    err_code = avcodec_open2(_audioCodecCtx, audioCodec, NULL);
    if (err_code<0) {
        NSLog(@"打开音频解码器失败...");
        return -1;
    }
    
    //3.2.2
    _audioFrame = av_frame_alloc();
    if (!_audioFrame) {
        NSLog(@"初始化音频帧失败....");
        return -1;
    }
    
    //3.2.3 音视频同步
    AVStream *st2 = _avFormatCtx->streams[_audioStream];
    avStreamFPSTimeBase_wzt(st2, 0.04, &_fps, &_audioTimeBase);
    
    //3.2.4
    SwrContext *swrContex = NULL;
    if (!audioCodecIsSupported_wzt(_audioCodecCtx)) {
        NSLog(@"11audio-channels: %d, audio-sample: %f", kAudioChannel, kAudioSampleRate);
        NSLog(@"11codec-channels: %d, codec-fmt: %d, codec-sample: %d", _audioCodecCtx->sample_fmt, _audioCodecCtx->channels, _audioCodecCtx->sample_rate);
        swrContex = swr_alloc_set_opts(NULL,
                                       av_get_default_channel_layout(kAudioChannel),
                                       AV_SAMPLE_FMT_S16,
                                       kAudioSampleRate,
                                       av_get_default_channel_layout(_audioCodecCtx->channels),
                                       _audioCodecCtx->sample_fmt,
                                       _audioCodecCtx->sample_rate,
                                       0,
                                       NULL);
        if (!swrContex || swr_init(swrContex)) {
            if (swrContex) {
                swr_free(&swrContex);
            }
            avcodec_close(_audioCodecCtx);
            
            return -1;
        }
    }
    _swrContex = swrContex;
    
    return 0;
}

@end




@interface WTMediaFrame ()
@end
@implementation WTMediaFrame

@end

@interface WTVideoFrame ()
@end
@implementation WTVideoFrame
-(instancetype)init {
    if (self = [super init]) {
        self.type = WTMediaTypeVideo;
    }
    return self;
}
@end

@interface WTAudioFrame ()
@end
@implementation WTAudioFrame
-(instancetype)init {
    if (self = [super init]) {
        self.type = WTMediaTypeAudio;
    }
    return self;
}

@end
