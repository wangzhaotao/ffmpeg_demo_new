//
//  WTTestVC4.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/5/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTTestVC4.h"
#import <CoreGraphics/CoreGraphics.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#import "libavutil/pixdesc.h"
#import <Accelerate/Accelerate.h>
#import "NSDate+Ex.h"

@interface WTTestVC4 ()

@end

@implementation WTTestVC4

- (void)viewDidLoad {
    [super viewDidLoad];
    //
    
    NSTimeInterval timeInterval = 1559729078.100;//[[NSDate date] timeIntervalSince1970];
    
    NSString *bannedTimeDes = [NSDate dateWithMilli:timeInterval*1000].postDateString.lowercaseString;
    NSLog(@"国际化下线提示语: %@", bannedTimeDes);
    
    
    [self process2];
}

-(void)process2 {
    
    uint8_t *data0 =     "!!!!!!!!!!!!!!!!\"\"\"\"\"\"\"\"\"\"\"\"\"\"##$$$%%%%%%%%%%%&&'''(((((((((((((((((((((((((((((((((((((((((((((((((((((((((())***+,,,./012344554444444444444444333333333333333322233333321100//..............................//000111111111111111111111111111112222222222222222333333333333334455566666666666778889999999999999::::::::::::::::;;;;;;;;;;;;;;;;<<<<<<<<<<<<<<<<================>>>>>>>>>>>>>>>>????????????????@@@@@@@@@@@@@@@@AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDDEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGIKRTUVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVUUUTTTTTSSRQPPPPQRSTTUUUUUVVVVVVVVVVVVVVWWXXXYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY[\\]\\VSSSSRRRQQQQQQQQQQQQRRSSSTTTTTTTTTTTUUVVVWWWWWWWWWWWWWXXXXXXXXXXXXXXYYZZZ[[[[[[[[[[[\\\\]]]^^^^^^^^^^^___```````````````________________________________````````````````aaaaaaaaaaaaaabbbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
    uint8_t *data1 =     "\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x84\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x82\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x82\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x82\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x82\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x84\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x84\x83\x83\x83\x83\x83\x83\x81~|||||||{zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz{|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\x7f\x80\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x83\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x84\x83\x82\x82\x82\x82\x82\x82\x82\x81\x80\x80\x80\x80\x80\x80~zxxvtrrtxzz|~\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x82\x85\x86\x86\x86\x86\x86\x86\x85\x84\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x84\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x84\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83";
    uint8_t *data2 =     "\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x83\x83\x83\x83\x83\x83\x83\x83\x84\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x83\x81\x81\x81\x81\x81\x81\x81\x81\x83\x83\x83\x83\x83\x83\x83\x83\x81\x81\x81\x81\x81\x81\x81\x81\x82\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x80\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x80\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x80\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f~}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}~\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f~}}}}}}}}}}}}}}}}}}}}}}~\x7f\x80\x80\x80\x80\x80\x80\x81\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x82\x81\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f~}}}}}}}}}}}}}}~\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x80\x81\x82\x82\x82\x82\x82\x82\x83\x84\x85\x85\x85\x85\x85\x85\x85\x84\x83\x83\x83\x83\x83\x83\x83\x82\x81\x81\x81\x81\x81\x81\x81\x80\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x80\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x81\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85\x85";
    
    //AVFrame->data数据
    uint8_t *data_frame[8] = {0};
    data_frame[0] = data0;
    data_frame[1] = data1;
    data_frame[2] = data2;
    //宽度
    int linesize[8] = {0};
    linesize[0] = 1920;
    linesize[1] = 960;
    linesize[2] = 960;
    
    float codec_width = 1920, codec_height = 1080;
    AVFrame *picture = cuatomAlloc_picture(AV_PIX_FMT_RGB24, codec_width, codec_height);;
    if(picture==NULL){
        av_frame_free(&picture);
        return;
    }
    
    struct SwsContext *img_convert_ctx = sws_getContext(codec_width, codec_height,AV_PIX_FMT_YUV420P,codec_width,codec_height,AV_PIX_FMT_RGB24,SWS_FAST_BILINEAR,NULL,NULL,NULL);
    // 图像处理
    sws_scale(img_convert_ctx, (const uint8_t* const*)data_frame, linesize, 0, codec_height, picture->data, picture->linesize);
    sws_freeContext(img_convert_ctx);
    img_convert_ctx = NULL;
    
    float width = 1920, height = 1080;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,picture->data[0],picture->linesize[0] * height);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       picture->linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    av_frame_free(&picture);
    
    UIImageView *imgView = [[UIImageView alloc]init];
    imgView.frame = CGRectMake(10, 64, 320, 640);
    [self.view addSubview:imgView];
    imgView.image = image;
}

/* video output */
AVFrame *cuatomAlloc_picture(enum AVPixelFormat pix_fmt, int width, int height)
{
    AVFrame *picture;
    int ret;
    picture = av_frame_alloc();
    if (!picture)
        return NULL;
    picture->format = pix_fmt;
    picture->width  = width;
    picture->height = height;
    /* allocate the buffers for the frame data */
    ret = av_frame_get_buffer(picture, 32);
    if (ret < 0) {
        av_frame_free(&picture);
        NSLog(@"Could not allocate frame data.\n");
        return NULL;
    }
    return picture;
}

-(void)process1 {
    
    uint8_t *data[3] = {0};
    data[0] = "\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1c\x10\x1f\x1c\x10\x1f\x1e\x11 \x1e\x11 \x1e\x11 \x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12!\x1f\x12! \x13\" \x13\"!\x14#!\x14#!\x14#\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16%\"\x16\"\"\x16\"\"\x16 \"\x16 \"\x16 \"\x16 \"\x16 \"\x16 \"\x16 \"\x16 \"\x16 \"\x16 \"\x16 #\x17!#\x17!%\x18\"%\x18\"%\x18\"&\x19#'\x1a%'\x1a%'\x1a%)\x1c'*\x1e(,\x1f)- *.!,/\"-0#.0#.1%/1%/-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.-%.,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-,#-.!,.!,.!,/\"-/\"-/\"-/\"-/\"-/\"-.!,- *- *,\x1f),\x1f)*\x1e(*\x1e()\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c')\x1c'*\x1e(*\x1e(,\x1f),\x1f),\x1f)- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *- *.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,.!,/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-/\"-0#.0#.1%/1%/1%/3&03&03&03&03&03&03&03&03&03&03&04'14'15(35(35(36)46)46)46)46)46)46)46)46)46)46)46)46)44,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,5\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1a\r\x1c\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b\x0f\x1e\x1b";
    
    printf("strlen=%lu\n", strlen(data[0]));
    
    NSInteger width = 1920, height = 1080;
    NSInteger linesize = 960;
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault, data[0], linesize * height);
    //NSData *dataPic = (NSData*)data;
    if (dataRef) {
        NSLog(@"存在");
    }else {
        NSLog(@"失败");
        return;
    }
    
    
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(dataRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       linesize,
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(dataRef);
    
    UIImageView *imgView = [[UIImageView alloc]init];
    imgView.frame = CGRectMake(10, 64, 320, 640);
    [self.view addSubview:imgView];
    
    imgView.image = image;
}


@end