//
//  WTMediaDecoder1.m
//  FFMPEG_PlayerDemo
//
//  Created by wztMac on 2019/5/4.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTMediaDecoder1.h"
#import <CoreGraphics/CoreGraphics.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#import "libavutil/pixdesc.h"
#import <Accelerate/Accelerate.h>

#import "KxAudioManager.h"
#import "KxMovieDecoder.h"
#import "WTVideoFilterPure.h"

static BOOL isNetworkPath (NSString *path)
{
    NSRange r = [path rangeOfString:@":"];
    if (r.location == NSNotFound)
        return NO;
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"])
        return NO;
    return YES;
}

static NSData* wt2_copyFrameData(UInt8 *src, int linesize, int width, int height) {
    
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


@interface WTMediaDecoder1 ()
{
    AVFormatContext *formatCxt; //解封装功能结构体
    
    AVCodecContext *videoCodecCxt;
    AVCodecContext *audioCodecCxt;
    
    NSArray *videoStreams;
    NSArray *audioStreams;
    
    NSInteger videoStream;
    NSInteger audioStream;
    
    //
    AVFrame *filte_in_videoFrame;
    AVFrame *videoFrame;
    AVFrame *audioFrame;
    
    //1.不甚明了
    CGFloat             _videoTimeBase;
    CGFloat             _audioTimeBase;
    CGFloat             _fps;
    
    //3.不甚明了
    KxVideoFrameFormat  _videoFrameFormat;
    CGFloat             _position;
    
    //4.不甚明了
    SwrContext          *_swrContext;
    struct SwrContext   *_swsContext;
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
}


@property (nonatomic, assign) BOOL disableDeinterlacing;

@property (nonatomic, strong) WTVideoFilterPure *pureFilte;

@end



@implementation WTMediaDecoder1

+(void)initialize {
    //av_log_set_callback(FFLog);
    av_register_all();
    avformat_network_init();
}

-(void)dealloc {
    [self closeFile];
}

#pragma mark public methods
-(BOOL)validVideo {
    return videoStream != -1;
}
-(BOOL)validAudio {
    return audioStream != -1;
}
- (BOOL) setupVideoFrameFormat: (int) format {
    if (format == KxVideoFrameFormatYUV && videoCodecCxt &&
        (videoCodecCxt->pix_fmt==AV_PIX_FMT_YUV420P || videoCodecCxt->pix_fmt==AV_PIX_FMT_YUVJ420P)) {
        _videoFrameFormat = KxVideoFrameFormatYUV;
        
        return YES;
    }
    
    _videoFrameFormat = KxVideoFrameFormatRGB;
    return _videoFrameFormat==format;
}
- (NSUInteger) frameWidth {
    return videoCodecCxt ? videoCodecCxt->width : 0;
}
- (NSUInteger) frameHeight {
    return videoCodecCxt ? videoCodecCxt->height : 0;
}
-(void)openMediaWithPath:(NSString*)path {
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    _isNetwork = isNetworkPath(path);
    if (_isNetwork) {
        av_register_all();
        avformat_network_init();
    }
    //1.解封装功能结构体
    AVFormatContext *avformatCxt = NULL;
    //1.1结构体初始化
    BOOL tmpCondition = NO;
    if (tmpCondition) {
        avformatCxt = avformat_alloc_context();
        if (!avformatCxt) {
            NSLog(@"初始化 '解封装功能结构体' 失败");
            return;
        }
    }
    //1.2结构体初始化
    int err_code = -1;
    char buf[1024] = "";
    err_code = avformat_open_input(&avformatCxt, [path cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL);
    if (err_code<0) {
        if (avformatCxt) {
            avformat_free_context(avformatCxt);
        }
        av_strerror(err_code, buf, 1024);
        NSLog(@"FFMpeg 解封装功能结构体 初始化失败: %d(%s)", err_code, buf);
        return;
    }
    formatCxt = avformatCxt;
    
    
    
    //2.为结构体填充上正确的流信息: formatCxt->streams
    if (avformat_find_stream_info(formatCxt, NULL)<0) {
        avformat_close_input(&formatCxt);
        NSLog(@"为结构体填充流信息失败");
        return;
    }
    
    
    
    //3.遍历查找视频流
    //3.1查找视频流
    NSMutableArray *videoStreamsArr = [NSMutableArray array];
    for (int i=0; i<formatCxt->nb_streams; i++) {
        if (formatCxt->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            [videoStreamsArr addObject:@(i)];
        }
    }
    videoStreams = videoStreamsArr;
    //3.2打开视频流
    for (int i=0; i<videoStreams.count; i++) {
        NSNumber *number = videoStreams[i];
        if (0 == (formatCxt->streams[number.integerValue]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
            NSLog(@"openMediaWithPath:打开视频流-i=%d", [number intValue]);
            [self openVideoStream:number.integerValue];
        }else{
            //artwork stream
        }
    }
    
    
    
    //4.遍历查找音频流
    //4.1查找音频流
    NSMutableArray *audioStreamsArr = [NSMutableArray array];
    for (int i=0; i<formatCxt->nb_streams; i++) {
        if (formatCxt->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
            [audioStreamsArr addObject:@(i)];
        }
    }
    audioStreams = audioStreamsArr;
    //4.2打开音频流
    for (NSNumber *number in audioStreams) {
        NSLog(@"openMediaWithPath:打开音频流-i=%d", [number intValue]);
        [self openAudioStream:number.integerValue];
    }
}
//循环解码
-(NSArray*)decodeFrames:(CGFloat)duration {
    
    if (videoStream==-1 && audioStream==-1) {
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    AVPacket packet;
    CGFloat decodeDuration = 0;
    BOOL finished = NO;
    while (!finished) {
        if (formatCxt==NULL) {
            return nil;
        }
        if (av_read_frame(formatCxt, &packet)<0) {
            _isEOF = YES;
            break;
        }
        
        if (packet.stream_index == videoStream) {
            //视频帧
            int packetSize = packet.size;
            
            //循环读取
            while (packetSize>0) {
                int gotFrame = 0;
                int len = avcodec_decode_video2(videoCodecCxt, videoFrame, &gotFrame, &packet);
                //int len = avcodec_decode_video2(videoCodecCxt, filte_in_videoFrame, &gotFrame, &packet);
                if (len<0) {
                    NSLog(@"错误: 解码错误，忽略子包数据");
                    break;
                }
                
                // ***** 叠加水印 - start *****
                if (!_pureFilte) {
                    _pureFilte = [[WTVideoFilterPure alloc]initWithCodecContex:videoCodecCxt];
                    NSLog(@"codecContext-width:%d, height:%d, fmt:%d", videoCodecCxt->width, videoCodecCxt->height, videoCodecCxt->pix_fmt);
                }
                if (_pureFilte) {
                    int ret = [_pureFilte pureFilteFrame:videoFrame frameOut:filte_in_videoFrame];
                    if (ret==0) {
                        NSLog(@"成功...");
                        if (filte_in_videoFrame->format==AV_PIX_FMT_YUV420P) {
                            //Y, U, V
                            avFrame_copyFrameData(filte_in_videoFrame, videoFrame);
                        }
                    }
                }
                // ***** 叠加水印 - end   *****
                
                
                if (gotFrame) {
                    if (!_disableDeinterlacing && videoFrame->interlaced_frame) {
                        avpicture_deinterlace((AVPicture*)videoFrame,
                                              (AVPicture*)videoFrame,
                                              videoCodecCxt->pix_fmt,
                                              videoCodecCxt->width,
                                              videoCodecCxt->height);
                    }
                    
                    //3.不甚明了 YUV RGB
                    KxVideoFrame *frame = [self handleVideoFrame];
                    if (frame) {
                        [result addObject:frame];
                        
                        _position = frame.position;
                        decodeDuration += frame.duration;
                        if (decodeDuration>duration) {
                            finished = YES;
                        }
                    }
                }
                
                if (0 == len) {
                    break;
                }
                
                packetSize -= len;
            }
            
        }else if (packet.stream_index == audioStream) {
            //音频帧
            int pktSize = packet.size;
            while (pktSize>0) {
                
                int gotFrame = 0;
                int len = avcodec_decode_audio4(audioCodecCxt,
                                                audioFrame,
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
                        
                        if (videoStream == -1) {
                            _position = frame.position;
                            decodeDuration += frame.duration;
                            if (decodeDuration>duration) {
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

static void avFrame_copyFrameData(AVFrame *frame_src, AVFrame *frame_dst) {
    
    int width = frame_src->width, height = frame_src->height,
        linesize0 = frame_src->linesize[0],
        linesize1 = frame_src->linesize[1],
        linesize2 = frame_src->linesize[2];
    
    uint8_t *src0 = frame_src->data[0];
    uint8_t *src1 = frame_src->data[1];
    uint8_t *src2 = frame_src->data[2];
    
    uint8_t *dst0 = frame_dst->data[0];
    uint8_t *dst1 = frame_dst->data[1];
    uint8_t *dst2 = frame_dst->data[2];
    
    linesize0 = MIN(width, linesize0);
    linesize1 = MIN(width, linesize1);
    linesize2 = MIN(width, linesize2);
    
    const char *space = "";
    
    if (linesize0>0 && strcmp((const char*)src0, space)==0) {
        for (NSUInteger i=0; i<height; ++i) {
            memcpy(dst0, src0, linesize0);
            dst0 += linesize0;
            src0 += linesize0;
        }
    }
    if (linesize1>0  && strcmp((const char*)src1, space)==0) {
        for (NSUInteger i=0; i<height; ++i) {
            memcpy(dst1, src1, linesize1);
            dst1 += linesize1;
            src1 += linesize1;
        }
    }
    if (linesize2>0  && strcmp((const char*)src2, space)==0) {
        for (NSUInteger i=0; i<height; ++i) {
            memcpy(dst2, src2, linesize2);
            dst2 += linesize2;
            src2 += linesize2;
        }
    }
}


#pragma mark private methods
-(void)openVideoStream:(NSInteger)videoStr {
    
    videoStream = -1;
    
    AVCodecContext *codecCxt = formatCxt->streams[videoStr]->codec;
    AVCodec *codec = avcodec_find_decoder(codecCxt->codec_id);
    if (!codec) {
        NSLog(@"查找解码器失败");
        return;
    }
    
    if (avcodec_open2(codecCxt, codec, NULL)<0) {
        NSLog(@"视频流解码失败");
        return;
    }
    
    videoFrame = av_frame_alloc();
    if (!videoFrame) {
        avcodec_close(codecCxt);
        NSLog(@"初始化视频帧数据失败");
        return;
    }
    
    // *** FFmpeg叠加水印 start ***
    filte_in_videoFrame = av_frame_alloc(); //初始化中间变量
    if (!filte_in_videoFrame) {
        NSLog(@"初始化叠加水印视频帧数据失败...");
    }
    // *** FFmpeg叠加水印 end   ***
    
    videoStream = videoStr;
    videoCodecCxt = codecCxt;
    
    //1.不甚明了
    //时间校正
    AVStream *st = formatCxt->streams[videoStr];
    [self avStreamFPSTimeBase:st defTimeBase:0.04 fps:&_fps pTimeBase:&_videoTimeBase];
}
//打开音频流
-(void)openAudioStream:(NSUInteger)audioStr {
    
    audioStream = -1;
    
    AVCodecContext *codecCxt = formatCxt->streams[audioStr]->codec;
    AVCodec *codec = avcodec_find_decoder(codecCxt->codec_id);
    if (!codec) {
        NSLog(@"查找音频解码器失败");
        return;
    }
    
    if (avcodec_open2(codecCxt, codec, NULL)<0) {
        NSLog(@"音频解码失败");
        return;
    }
    
    //3.不甚明了
    //重采样
    SwrContext *swrContext = NULL;
    if (![self isAudioSupport:codecCxt]) {
        id<KxAudioManager> audioManager = [KxAudioManager audioManager];
        swrContext = swr_alloc_set_opts(NULL,
                                                    av_get_default_channel_layout(audioManager.numOutputChannels),
                                                    AV_SAMPLE_FMT_S16,
                                                    audioManager.samplingRate,
                                                    av_get_default_channel_layout(codecCxt->channels),
                                                    codecCxt->sample_fmt,
                                                    codecCxt->sample_rate,
                                                    0,
                                                    NULL);
        if (!swrContext || swr_init(swrContext)) {
            if (swrContext) {
                swr_free(&swrContext);
            }
            avcodec_close(codecCxt);
            NSLog(@"重采样初始化失败");
            return;
        }
    }
    
    audioFrame = av_frame_alloc();
    if (!audioFrame) {
        if (swrContext) {
            swr_free(&swrContext);
        }
        avcodec_close(codecCxt);
        NSLog(@"初始化音频帧失败");
        return;
    }
    
    audioStream = audioStr;
    audioCodecCxt = codecCxt;
    _swrContext = swrContext;
    
    //2.不甚明了
    AVStream *st = formatCxt->streams[audioStr];
    [self avStreamFPSTimeBase:st defTimeBase:0.025 fps:0 pTimeBase:&_audioTimeBase];
}

//3.不甚明了 YUV RGB
-(KxVideoFrame*)handleVideoFrame {
    
    if (!videoFrame->data[0]) {
        return nil;
    }
    
    KxVideoFrame *frame;
    if (_videoFrameFormat == KxVideoFrameFormatYUV) {
        KxVideoFrameYUV *yuvFrame = [[KxVideoFrameYUV alloc]init];
        yuvFrame.luma = wt2_copyFrameData(videoFrame->data[0],
                                      videoFrame->linesize[0],
                                      videoCodecCxt->width,
                                      videoCodecCxt->height);
        yuvFrame.chromaB = wt2_copyFrameData(videoFrame->data[1],
                                         videoFrame->linesize[1],
                                         videoCodecCxt->width/2,
                                         videoCodecCxt->height/2);
        yuvFrame.chromaR = wt2_copyFrameData(videoFrame->data[2],
                                         videoFrame->linesize[2],
                                         videoCodecCxt->width/2,
                                         videoCodecCxt->height/2);
        
        frame = yuvFrame;
    }else {
        
//        if (!_swsContext && ![self setupScaler]) {
//
//            NSLog(@"Error: fail setup video scaler");
//            return nil;
//        }
//
//        sws_scale(_swsContext, (const uint8_t **)_videoFrame->data,
//                  _videoFrame->linesize,
//                  0,
//                  _videoCodecCtx->height,
//                  _picture.data,
//                  _picture.linesize);
//
//        KxVideoFrameRGB *rgbFrame = [[KxVideoFrameRGB alloc]init];
//        rgbFrame.linesize = _picture.linesize[0];
//        rgbFrame.rgb = [NSData dataWithBytes:_picture.data[0] length:rgbFrame.linesize*_videoFrame->height];
//        frame = rgbFrame;
    }
    
    frame.width = videoCodecCxt->width;
    frame.height = videoCodecCxt->height;
    frame.position =av_frame_get_best_effort_timestamp(videoFrame)*_videoTimeBase;
    
    const int64_t frameDuration = av_frame_get_pkt_duration(videoFrame);
    if (frameDuration) {
        
        frame.duration = frameDuration*_videoTimeBase;
        frame.duration += videoFrame->repeat_pict*_videoTimeBase*0.5;
    }else {
        
        frame.duration = 1.0/_fps;
    }
    
    return frame;
}
//4.不甚明了
-(KxAudioFrame*)handleAudioFrame {
    
    if (!audioFrame->data[0]) {
        return nil;
    }
    
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    const NSUInteger numChannels = audioManager.numOutputChannels;
    NSUInteger numFrames;
    void *audioData;
    if (_swrContext) {
        
        const NSUInteger ratio = MAX(1, audioManager.samplingRate/audioCodecCxt->sample_rate)*MAX(1, audioManager.numOutputChannels / audioCodecCxt->channels)*2;
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       audioManager.numOutputChannels,
                                                       audioFrame->nb_samples*ratio,
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        if (!_swrBuffer || _swrBufferSize<bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = {_swrBuffer, 0};
        numFrames = swr_convert(_swrContext,
                                outbuf,
                                audioFrame->nb_samples*ratio,
                                (const uint8_t **)audioFrame->data,
                                audioFrame->nb_samples);
        if (numFrames<0) {
            NSLog(@"Error: fail resample audio");
            return nil;
        }
        
        audioData = _swrBuffer;
    }else {
        
        if (audioCodecCxt->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSLog(@"Error: bucheck, audio format is invalid");
            return nil;
        }
        audioData = audioFrame->data[0];
        numFrames = audioFrame->nb_samples;
    }
    
    const NSUInteger numElements = numFrames*numChannels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements*sizeof(float)];
    
    float scale = 1.0/(float)INT16_MAX;
    vDSP_vflt16((SInt16*)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    KxAudioFrame *frame = [[KxAudioFrame alloc]init];
    frame.position = av_frame_get_best_effort_timestamp(audioFrame)*_audioTimeBase;
    frame.duration = av_frame_get_pkt_duration(audioFrame)*_audioTimeBase;
    frame.samples = data;
    
    if (frame.duration==0) {
        frame.duration = frame.samples.length/(sizeof(float)*numChannels*audioManager.samplingRate);
    }
    
    return frame;
}







//重采样相关 - 查看是否是支持的音频播放格式
-(BOOL)isAudioSupport:(AVCodecContext *)codecCxt {
    if (codecCxt->sample_fmt == AV_SAMPLE_FMT_S16) {
        id <KxAudioManager> audioManager = [KxAudioManager audioManager];
        return audioManager.samplingRate==codecCxt->sample_rate && audioManager.numOutputChannels==codecCxt->channels;
    }
    return NO;
}

#pragma mark 不甚明了
//1.不甚明了
-(void)avStreamFPSTimeBase:(AVStream *)st defTimeBase:(CGFloat)defaultTimeBase
                       fps:(CGFloat*)pFPS pTimeBase:(CGFloat *)pTimeBase {
    
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



#pragma mark 关闭音视频流
-(void)closeFile {
    
    [self closeAudioStream];
    [self closeVideoStream];
    
    videoStreams = nil;
    audioStreams = nil;
    
    if (formatCxt) {
        formatCxt->interrupt_callback.opaque = NULL;
        formatCxt->interrupt_callback.callback = NULL;
        
        avformat_close_input(&formatCxt);
        formatCxt = NULL;
    }
}
-(void)closeAudioStream {
    
    videoStream = -1;
    
    if (videoFrame) {
        av_free(videoFrame);
        videoFrame = NULL;
    }
    
    if (videoCodecCxt) {
        avcodec_close(videoCodecCxt);
        videoCodecCxt = NULL;
    }
}
-(void)closeVideoStream {
    
    audioStream = -1;
    
    
    if (_swrBuffer) {
        free(_swrBuffer);
        _swrBuffer = NULL;
        _swrBufferSize = 0;
    }
    
    if (_swrContext) {
        swr_free(&_swrContext);
        _swrContext = NULL;
    }
    
    
    if (audioFrame) {
        av_free(audioFrame);
        audioFrame = NULL;
    }
    
    if (audioCodecCxt) {
        avcodec_close(audioCodecCxt);
        audioCodecCxt = NULL;
    }
    
    if (_swsContext) {
        swr_free(&_swsContext);
        _swsContext = NULL;
    }
}


@end
