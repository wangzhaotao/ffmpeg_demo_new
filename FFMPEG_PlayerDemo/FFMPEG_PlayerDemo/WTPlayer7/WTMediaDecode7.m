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
#import "NSString+Ex.h"

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
}

@end

@implementation WTMediaDecode7

+(void)initialize {
    av_register_all();
    avformat_network_init();
}

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
    
    return 0;
}




@end
