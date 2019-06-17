//
//  WTPlayFilte6VC.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/13/19.
//  Copyright © 2019 ocean. All rights reserved.
//

/**
 * 最简单的基于FFmpeg的AVFilter例子 - 纯净版
 * Simplest FFmpeg AVfilter Example - Pure
 *
 * 雷霄骅 Lei Xiaohua
 * leixiaohua1020@126.com
 * 中国传媒大学/数字电视技术
 * Communication University of China / Digital TV Technology
 * http://blog.csdn.net/leixiaohua1020
 *
 * 本程序使用FFmpeg的AVfilter实现了YUV像素数据的滤镜处理功能。
 * 可以给YUV数据添加各种特效功能。
 * 是最简单的FFmpeg的AVFilter方面的教程。
 * 适合FFmpeg的初学者。
 *
 * This software uses FFmpeg's AVFilter to process YUV raw data.
 * It can add many excellent effect to YUV data.
 * It's the simplest example based on FFmpeg's AVFilter.
 * Suitable for beginner of FFmpeg
 *
 */

#import "WTPlayFilte6VC.h"
#import "Utils.h"

#import "WTMultiMediaTool.h"
#import "WTYUV2Mp4Tool.h"


@interface WTPlayFilte6VC ()
@property (nonatomic, strong) UILabel *resultLabel;

@end

@implementation WTPlayFilte6VC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    //
    UIButton *button = [[UIButton alloc]init];
    [button setTitle:@"开始FFmpeg滤镜" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(startFFmpegFilteAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    
    UIButton *convertBtn = [[UIButton alloc]init];
    [convertBtn setTitle:@"开始FFmpeg转码YUV-MP4" forState:UIControlStateNormal];
    [convertBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [convertBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];
    [convertBtn addTarget:self action:@selector(convertYUVToMP4Action:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:convertBtn];
    
    
    UILabel *resultLabel = [[UILabel alloc]init];
    resultLabel.textAlignment = NSTextAlignmentCenter;
    resultLabel.textColor = [UIColor blackColor];
    [self.view addSubview:resultLabel];
    _resultLabel = resultLabel;
    
    
    CGFloat origin_x = 20;
    CGFloat origin_y = 50;
    CGFloat w = iScreenW-origin_x*2, h = 50;
    button.frame = CGRectMake(origin_x, origin_y, w, h);
    convertBtn.frame = CGRectMake(origin_x, origin_y*2+h, w, h);
    resultLabel.frame = CGRectMake(origin_x, origin_y*3+h*2, w, h);
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UINavigationBar *bar = self.navigationController.navigationBar;
    bar.shadowImage=[UIImage new];
    bar.translucent=NO;
    [bar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    bar.barTintColor=[UIColor whiteColor];
    bar.barTintColor=[UIColor groupTableViewBackgroundColor];
    
}

-(void)startFFmpegFilteAction:(UIButton*)sender {
    
    NSString *fileExt = @"yuv";
    
    NSString *file_in = @"test";
    NSString *file_out = @"copy";
    
    
    NSString *in_tmp_path = [[NSString stringWithFormat:@"%@.%@", file_in, fileExt] strByAppendToTempPath];
    NSString *out_tmp_path = [[NSString stringWithFormat:@"%@.%@", file_out, fileExt] strByAppendToTempPath];
    
    
    NSString *file_in_path = [[NSBundle mainBundle]pathForResource:file_in ofType:@"yuv"];
    NSString *file_out_path = [[NSBundle mainBundle]pathForResource:file_out ofType:@"yuv"];
    NSLog(@"Bundle Path源文件: %@", file_in_path);
    NSLog(@"Bundle Path目标文件: %@", file_out_path);
    NSLog(@"磁盘源文件: %@", in_tmp_path);
    NSLog(@"磁盘目标文件: %@", out_tmp_path);
    
    BOOL success = [Utils copyFileInPath:file_in_path toPath:in_tmp_path];
    NSLog(@"拷贝文件:%@, %@", [NSString stringWithFormat:@"%@.%@", file_in, fileExt], success?@"成功":@"失败");
    success = [Utils copyFileInPath:file_out_path toPath:out_tmp_path];
    NSLog(@"拷贝文件:%@, %@", [NSString stringWithFormat:@"%@.%@", file_in, fileExt], success?@"成功":@"失败");
    
    const char *file_in_p = [in_tmp_path UTF8String];
    const char *file_out_p = [out_tmp_path UTF8String];
    
    int ret = mainFilteActionC(file_in_p, file_out_p);
    if (ret == 0) {
        _resultLabel.text = @"滤镜成功";
        
    }else{
        _resultLabel.text = [NSString stringWithFormat:@"滤镜失败ret=%d", ret];
    }
}

-(void)convertYUVToMP4Action:(UIButton*)sender {
    
    [self yuv2MP4Method2];
}

-(void)yuv2MP4Method2 {
    
    NSString *fileExt = @"yuv";
    
    NSString *file_out = @"copy";
    NSString *file_mp4 = @"test.mp4";
    NSString *file_mp4_new = @"test_new.mp4";
    NSString *tmp_h264 = @"tmp.H264";
    
    NSString *out_tmp_path = [[NSString stringWithFormat:@"%@.%@", file_out, fileExt] strByAppendToTempPath];
    NSString *mp4_tmp_path = [file_mp4 strByAppendToTempPath];
    NSString *mp4_tmp_path_new = [file_mp4_new strByAppendToTempPath];
    NSString *h264_tmp_path = [tmp_h264 strByAppendToTempPath];
    
    NSString *mp4_out_path = [[NSBundle mainBundle]pathForResource:file_mp4 ofType:nil];
    NSString *h264_out_path = [[NSBundle mainBundle]pathForResource:tmp_h264 ofType:nil];
    
    BOOL success = [Utils copyFileInPath:mp4_out_path toPath:mp4_tmp_path];
    NSLog(@"拷贝文件:%@, %@", file_mp4, success?@"成功":@"失败");
    
    success = [Utils copyFileInPath:mp4_out_path toPath:mp4_tmp_path_new];
    NSLog(@"拷贝文件:%@, %@", file_mp4, success?@"成功":@"失败");
    
    success = [Utils copyFileInPath:h264_out_path toPath:h264_tmp_path];
    NSLog(@"拷贝文件:%@, %@", tmp_h264, success?@"成功":@"失败");
    
    const char *mp4_out_p = [mp4_tmp_path_new UTF8String];
    const char *file_out_p = [out_tmp_path UTF8String];
    const char *tmp_h264_p = [h264_tmp_path UTF8String];
    
    //转码YUV-->mp4
    int ret = convertYUVData2MP4Data(file_out_p, mp4_out_p, tmp_h264_p);
    NSLog(@"YUV转MP4，%@", ret==0?@"成功":@"失败");
}

-(void)yuv2MP4Method1 {
    
    NSString *fileExt = @"yuv";
    
    NSString *file_out = @"test";
    NSString *file_mp4 = @"test.mp4";
    
    NSString *out_tmp_path = [[NSString stringWithFormat:@"%@.%@", file_out, fileExt] strByAppendToTempPath];
    NSString *mp4_tmp_path = [file_mp4 strByAppendToTempPath];
    
    NSString *mp4_out_path = [[NSBundle mainBundle]pathForResource:file_mp4 ofType:nil];
    
    BOOL success = [Utils copyFileInPath:mp4_out_path toPath:mp4_tmp_path];
    NSLog(@"拷贝文件:%@, %@", file_mp4, success?@"成功":@"失败");
    
    const char *mp4_out_p = [mp4_tmp_path UTF8String];
    const char *file_out_p = [out_tmp_path UTF8String];
    
    //转码YUV-->mp4
    int ret = convertYUVToMP4(file_out_p, mp4_out_p);
    NSLog(@"YUV转MP4，%@", ret==0?@"成功":@"失败");
}



@end


