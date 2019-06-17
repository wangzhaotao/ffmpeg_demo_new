//
//  WTMultiMediaTool.c
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/13/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#include "WTMultiMediaTool.h"
#include <stdio.h>

#include <libavfilter/avfiltergraph.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>


//YUV转mp4
int flush_encoder1(AVFormatContext *fmt_ctx,unsigned int stream_index);

int convertYUVToMP4(const char *file_in_path, const char *file_out_path)
{
    AVFormatContext *pFormatCtx=NULL;
    AVOutputFormat *fmt=NULL;
    AVStream *video_st=NULL;
    AVCodecContext *pCodecCtx=NULL;
    AVCodec *pCodec=NULL;
    
    uint8_t *picture_buf=NULL;
    AVFrame *picture=NULL;
    int size;
    
    //打开视频
    FILE *in_file = fopen(file_in_path, "rb");
    if(!in_file)
    {
        printf("can not open file!\n");
        return -1;
    }
    
    int in_w=480,in_h=272;
    int framenum=524;
    const char* out_file=file_out_path;
    
    //[1] --注册所有ffmpeg组件
    avcodec_register_all();
    av_register_all();
    //[1]
    
    //[2] --初始化AVFormatContext结构体,根据文件名获取到合适的封装格式
    avformat_alloc_output_context2(&pFormatCtx,NULL,NULL,out_file);
    fmt = pFormatCtx->oformat;
    //[2]
    
    //[3] --打开文件
    if(avio_open(&pFormatCtx->pb,out_file,AVIO_FLAG_READ_WRITE))
    {
        printf("output file open fail!");
        //goto end;
        // *** 释放内存 ***
        if(video_st)
        {
            avcodec_close(video_st->codec);
            av_free(picture);
            av_free(picture_buf);
        }
        if(pFormatCtx)
        {
            avio_close(pFormatCtx->pb);
            avformat_free_context(pFormatCtx);
        }
        fclose(in_file);
        // *** 释放内存 ***
    }
    //[3]
    
    //[4] --初始化视频码流
    video_st = avformat_new_stream(pFormatCtx,0);
    if(video_st==NULL)
    { printf("failed allocating output stram\n");
        //goto end;
        // *** 释放内存 ***
        if(video_st)
        {
            avcodec_close(video_st->codec);
            av_free(picture);
            av_free(picture_buf);
        }
        if(pFormatCtx)
        {
            avio_close(pFormatCtx->pb);
            avformat_free_context(pFormatCtx);
        }
        fclose(in_file);
        // *** 释放内存 ***
    }
    video_st->time_base.num = 1;
    video_st->time_base.den =25;
    //[4]
    
    //[5] --编码器Context设置参数
    pCodecCtx = video_st->codec;
    pCodecCtx->codec_id = fmt->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    pCodecCtx->width=in_w;
    pCodecCtx->height=in_h;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 25;
    pCodecCtx->bit_rate = 3960;
    pCodecCtx->gop_size = 12;
    
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264)
    {
        pCodecCtx->qmin = 10;
        pCodecCtx->qmax = 51;
        pCodecCtx->qcompress = 0.6;
    }
    if (pCodecCtx->codec_id == AV_CODEC_ID_MPEG2VIDEO)
        pCodecCtx->max_b_frames = 2;
    if (pCodecCtx->codec_id == AV_CODEC_ID_MPEG1VIDEO)
        pCodecCtx->mb_decision = 2;
    //[5]
    
    //[6] --寻找编码器并打开编码器
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if(!pCodec)
    {
        printf("no right encoder!\n");
        //goto end;
        // *** 释放内存 ***
        if(video_st)
        {
            avcodec_close(video_st->codec);
            av_free(picture);
            av_free(picture_buf);
        }
        if(pFormatCtx)
        {
            avio_close(pFormatCtx->pb);
            avformat_free_context(pFormatCtx);
        }
        fclose(in_file);
        // *** 释放内存 ***
    }
    if(avcodec_open2(pCodecCtx,pCodec,NULL)<0)
    {
        printf("open encoder fail!\n");
        //goto end;
        // *** 释放内存 ***
        if(video_st)
        {
            avcodec_close(video_st->codec);
            av_free(picture);
            av_free(picture_buf);
        }
        if(pFormatCtx)
        {
            avio_close(pFormatCtx->pb);
            avformat_free_context(pFormatCtx);
        }
        fclose(in_file);
        // *** 释放内存 ***
    }
    //[6]
    
    //输出格式信息
    av_dump_format(pFormatCtx,0,out_file,1);
    
    //初始化帧
    picture = av_frame_alloc();
    picture->width=pCodecCtx->width;
    picture->height=pCodecCtx->height;
    picture->format=pCodecCtx->pix_fmt;
    size = avpicture_get_size(pCodecCtx->pix_fmt,pCodecCtx->width,pCodecCtx->height);
    picture_buf = (uint8_t*)av_malloc(size);
    avpicture_fill((AVPicture*)picture,picture_buf,pCodecCtx->pix_fmt,pCodecCtx->width,pCodecCtx->height);
    
    //[7] --写头文件
    avformat_write_header(pFormatCtx,NULL);
    //[7]
    
    AVPacket pkt; //创建已编码帧
    int y_size = pCodecCtx->width*pCodecCtx->height;
    av_new_packet(&pkt,size*3);
    
    //[8] --循环编码每一帧
    for(int i=0;i<framenum;i++)
    {
        //读入YUV
        if(fread(picture_buf,1,y_size*3/2,in_file)<0)
        {
            printf("read file fail!\n");
            //goto end;
            // *** 释放内存 ***
            if(video_st)
            {
                avcodec_close(video_st->codec);
                av_free(picture);
                av_free(picture_buf);
            }
            if(pFormatCtx)
            {
                avio_close(pFormatCtx->pb);
                avformat_free_context(pFormatCtx);
            }
            fclose(in_file);
            // *** 释放内存 ***
            return -1;
        }
        else if(feof(in_file))
            break;
        
        picture->data[0] = picture_buf; //亮度Y
        picture->data[1] = picture_buf+y_size; //U
        picture->data[2] = picture_buf+y_size*5/4; //V
        //AVFrame PTS
        picture->pts=i;
        int got_picture = 0;
        
        //编码
        int ret = avcodec_encode_video2(pCodecCtx,&pkt,picture,&got_picture);
        if(ret<0)
        {
            printf("encoder fail!\n");
            return -1;
        }
        
        if(got_picture == 1)
        {
            printf("encoder success!\n");
            
            // parpare packet for muxing
            pkt.stream_index = video_st->index;
            av_packet_rescale_ts(&pkt, pCodecCtx->time_base, video_st->time_base);
            pkt.pos = -1;
            ret = av_interleaved_write_frame(pFormatCtx,&pkt);
            av_free_packet(&pkt);
        }
    }
    //[8]
    
    //[9] --Flush encoder
    int ret = flush_encoder1(pFormatCtx,0);
    if(ret < 0)
    {
        printf("flushing encoder failed!\n");
        goto end;
    }
    //[9]
    
    //[10] --写文件尾
    av_write_trailer(pFormatCtx);
    //[10]
    
end:
    //释放内存
    if(video_st)
    {
        avcodec_close(video_st->codec);
        av_free(picture);
        av_free(picture_buf);
    }
    if(pFormatCtx)
    {
        avio_close(pFormatCtx->pb);
        avformat_free_context(pFormatCtx);
    }
    
    fclose(in_file);
    
    return 0;
}


int flush_encoder1(AVFormatContext *fmt_ctx,unsigned int stream_index)
{
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    while (1) {
        printf("Flushing stream #%u encoder\n", stream_index);
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame)
        {ret=0;break;}
        printf("success encoder 1 frame\n");
        
        // parpare packet for muxing
        enc_pkt.stream_index = stream_index;
        av_packet_rescale_ts(&enc_pkt,
                             fmt_ctx->streams[stream_index]->codec->time_base,
                             fmt_ctx->streams[stream_index]->time_base);
        ret = av_interleaved_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}


#pragma mark 滤镜
int mainFilteActionC(const char *file_name_in, const char *file_name_out)
{
    int ret;
    AVFrame *frame_in;
    AVFrame *frame_out;
    unsigned char *frame_buffer_in;
    unsigned char *frame_buffer_out;
    
    AVFilterContext *buffersink_ctx;
    AVFilterContext *buffersrc_ctx;
    AVFilterGraph *filter_graph;
    //static int video_stream_index = -1;
    
    
    //Input YUV
    FILE *fp_in=fopen(file_name_in,"rb+");//“rb+”: 打开一个二进制文件，文件必须存在，允许读写
    if(fp_in==NULL){
        printf("Error open input file.\n");
        return -1;
    }
    int in_width=480;
    int in_height=272;
    
    //Output YUV
    FILE *fp_out=fopen(file_name_out,"wb+"); //“wb+”: 新建一个二进制文件，已存在的文件将被删除，允许读写;
    if(fp_out==NULL){
        printf("Error open output file.\n");
        return -1;
    }
    
    //const char *filter_descr = "lutyuv='u=128:v=128'";
    //const char *filter_descr = "boxblur";
    //const char *filter_descr = "hflip";
    //const char *filter_descr = "hue='h=60:s=-3'";
    //const char *filter_descr = "crop=2/3*in_w:2/3*in_h";
    //const char *filter_descr = "drawbox=x=100:y=100:w=100:h=100:color=pink@0.5";
    const char *filter_descr = "drawtext=fontfile=arial.ttf:fontcolor=green:fontsize=30:text='Lei Xiaohua'";
    
    avfilter_register_all();
    
    char args[512];
    AVFilter *buffersrc  = avfilter_get_by_name("buffer");
    AVFilter *buffersink = avfilter_get_by_name("buffersink"); //ffbuffersink
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs  = avfilter_inout_alloc();
    enum PixelFormat pix_fmts[] = { AV_PIX_FMT_YUV420P, PIX_FMT_NONE };
    AVBufferSinkParams *buffersink_params;
    
    filter_graph = avfilter_graph_alloc();
    
    /* buffer video source: the decoded frames from the decoder will be inserted here. */
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             in_width,in_height,AV_PIX_FMT_YUV420P,
             1, 25,1,1);
    
    ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in",
                                       args, NULL, filter_graph);
    if (ret < 0) {
        printf("Cannot create buffer source\n");
        return ret;
    }
    
    /* buffer video sink: to terminate the filter chain. */
    buffersink_params = av_buffersink_params_alloc();
    buffersink_params->pixel_fmts = pix_fmts;
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
                                       NULL, buffersink_params, filter_graph);
    av_free(buffersink_params);
    if (ret < 0) {
        printf("Cannot create buffer sink\n");
        return ret;
    }
    
    /* Endpoints for the filter graph. */
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;
    
    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next       = NULL;
    
    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_descr,
                                        &inputs, &outputs, NULL)) < 0)
        return ret;
    
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0)
        return ret;
    
    frame_in=av_frame_alloc();
    frame_buffer_in=(unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, in_width,in_height,1));
    av_image_fill_arrays(frame_in->data, frame_in->linesize,frame_buffer_in,
                         AV_PIX_FMT_YUV420P,in_width, in_height,1);
    
    frame_out=av_frame_alloc();
    frame_buffer_out=(unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, in_width,in_height,1));
    av_image_fill_arrays(frame_out->data, frame_out->linesize,frame_buffer_out,
                         AV_PIX_FMT_YUV420P,in_width, in_height,1);
    
    frame_in->width=in_width;
    frame_in->height=in_height;
    frame_in->format=AV_PIX_FMT_YUV420P;
    
    int i = 0;
    while (1) {
        
        i++;
        
        if(fread(frame_buffer_in, 1, in_width*in_height*3/2, fp_in)!= in_width*in_height*3/2){
            break;
        }
        //input Y,U,V
        frame_in->data[0]=frame_buffer_in;
        frame_in->data[1]=frame_buffer_in+in_width*in_height;
        frame_in->data[2]=frame_buffer_in+in_width*in_height*5/4;
        
        if (av_buffersrc_add_frame(buffersrc_ctx, frame_in) < 0) {
            printf( "Error while add frame.\n");
            break;
        }
        
        /* pull filtered pictures from the filtergraph */
        ret = av_buffersink_get_frame(buffersink_ctx, frame_out);
        if (ret < 0)
            break;
        
        //output Y,U,V
        if(frame_out->format==AV_PIX_FMT_YUV420P){
            printf("Process %d frame: AV_PIX_FMT_YUV420P\nwidth:%d, height:%d\n", i, frame_out->width, frame_out->height);
            for(int i=0;i<frame_out->height;i++){
                fwrite(frame_out->data[0]+frame_out->linesize[0]*i,1,frame_out->width,fp_out);
            }
            for(int i=0;i<frame_out->height/2;i++){
                fwrite(frame_out->data[1]+frame_out->linesize[1]*i,1,frame_out->width/2,fp_out);
            }
            for(int i=0;i<frame_out->height/2;i++){
                fwrite(frame_out->data[2]+frame_out->linesize[2]*i,1,frame_out->width/2,fp_out);
            }
        }
        printf("Process %d frame!\n", i);
        av_frame_unref(frame_out);
    }
    
    fclose(fp_in);
    fclose(fp_out);
    
    av_frame_free(&frame_in);
    av_frame_free(&frame_out);
    avfilter_graph_free(&filter_graph);
    
    return 0;
}
