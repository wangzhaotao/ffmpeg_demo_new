//
//  WTVideoFilterPure.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/11/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTVideoFilterPure.h"



AVFilterGraph *filter_graph_p;
AVFilterContext *buffersrc_ctx_p;
AVFilterContext *buffersink_ctx_p;
AVCodecContext *pCodecCtx_p;

const char *filter_descr_p = "movie=my_logo.png[wm];[in][wm]overlay=5:5[out]";

static int init_filters(const char *filters_descr);


@interface WTVideoFilterPure ()
{
    AVCodecContext *videoCodecContext;
}
@property (nonatomic, assign) int initSuccess;

@end

@implementation WTVideoFilterPure

-(instancetype)initWithCodecContex:(AVCodecContext*)codecContext {
    if (self = [super init]) {
        
        videoCodecContext = codecContext;
        pCodecCtx_p = codecContext;
        _initSuccess = init_filters(filter_descr_p);
    }
    return self;
}

-(void)destroy {
    
    avfilter_graph_free(&filter_graph_p);
}

-(int)pureFilteFrame:(AVFrame*)frame_in frameOut:(AVFrame*)frame_out {
    
    if (_initSuccess != 0) {
        NSLog(@"FFmpeg叠加水印-初始化失败...");
        return -1;
    }
    
    NSLog(@"AVFrame-width:%d, height:%d, fmt:%d", frame_in->width, frame_in->height, frame_in->format);
    if (buffersrc_ctx_p==NULL) {
        NSLog(@"FFmpeg叠加水印-添加帧数据判断为空...");
        return -1;
    }
    int ret = av_buffersrc_add_frame(buffersrc_ctx_p, frame_in);
    if (ret<0) {
        NSLog(@"FFmpeg叠加水印-添加帧数据失败...");
        return -1;
    }
    
    ret = av_buffersink_get_frame(buffersink_ctx_p, frame_out);
    if (ret<0) {
        NSLog(@"FFmpeg叠加水印-获取叠加水印帧失败...");
        return -1;
    }
    
    return 0;
}



@end


static int init_filters(const char *filters_descr)
{
    //注册
    avfilter_register_all();

    //初始化
    char args[512];
    int ret;
    const AVFilter *buffersrc  = avfilter_get_by_name("buffer");
    if (!buffersrc) {
        fprintf(stderr, "Can't find source fiter 'buffer'\n");
        return -1;
    }
    const AVFilter *buffersink = avfilter_get_by_name("buffersink"); //ffbuffersink --> buffersink
    if (!buffersink) {
        fprintf(stderr, "Can't find sink fiter 'buffersink'\n");
        return -1;
    }
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs  = avfilter_inout_alloc();
    enum AVPixelFormat pix_fmts[] = { AV_PIX_FMT_YUV420P, AV_PIX_FMT_NONE };
    AVBufferSinkParams *buffersink_params;
    
    filter_graph_p = avfilter_graph_alloc();
    
    /* buffer video source: the decoded frames from the decoder will be inserted here. */
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             pCodecCtx_p->width, pCodecCtx_p->height, pCodecCtx_p->pix_fmt,
             pCodecCtx_p->time_base.num, pCodecCtx_p->time_base.den,
             pCodecCtx_p->sample_aspect_ratio.num, pCodecCtx_p->sample_aspect_ratio.den);
    
    ret = avfilter_graph_create_filter(&buffersrc_ctx_p, buffersrc, "in",
                                       args, NULL, filter_graph_p);
    if (ret < 0) {
        NSLog(@"叠加水印 - 初始化滤波失败，Cannot create buffer source");
        return ret;
    }
    
    /* buffer video sink: to terminate the filter chain. */
    buffersink_params = av_buffersink_params_alloc();
    buffersink_params->pixel_fmts = pix_fmts;
    ret = avfilter_graph_create_filter(&buffersink_ctx_p, buffersink, "out",
                                       NULL, buffersink_params, filter_graph_p);
    av_free(buffersink_params);
    if (ret < 0) {
        NSLog(@"叠加水印 - 初始化滤波失败，Cannot create buffer sink");
        return ret;
    }
    
    /* Endpoints for the filter graph. */
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx_p;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;
    
    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx_p;
    inputs->pad_idx    = 0;
    inputs->next       = NULL;
    
    NSString *path = [[NSBundle mainBundle]pathForResource:@"my_logo" ofType:@"png"];
    NSString *descr = [NSString stringWithFormat:@"movie=%@[wm];[in][wm]overlay=5:5[out]", path];
    const char *filters_descr_new = [descr UTF8String];
    
    if ((ret = avfilter_graph_parse_ptr(filter_graph_p, filters_descr_new,
                                        &inputs, &outputs, NULL)) < 0) {
        NSLog(@"叠加水印 - 初始化滤波失败，avfilter_graph_parse_ptr");
        return ret;
    }
    
    if ((ret = avfilter_graph_config(filter_graph_p, NULL)) < 0) {
        NSLog(@"叠加水印 - 初始化滤波失败，avfilter_graph_config");
        return ret;
    }
    return 0;
}
