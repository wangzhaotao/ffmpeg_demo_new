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

@interface WTMediaPlayView ()
{
    //播放队列
    dispatch_queue_t    _dispatchQueue;
    //缓冲数据帧
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
}
@property (nonatomic, strong) WTAudioQueuePlay *pcmPalyer;
@property (nonatomic, strong) OpenglView *openglview;

@property (nonatomic, strong) WTMediaDecode7 *mediaDecoder;

@property (nonatomic, assign) BOOL isPlaying;


@end

@implementation WTMediaPlayView

+(instancetype)createPlayViewWithPath:(NSString*)path {
    
    WTMediaPlayView *obj = [[WTMediaPlayView alloc]initWithVideo:path];
    return obj;
}

-(instancetype)initWithVideo:(NSString *)moviePath {
    
    if (self = [super init]) {
        
        //初始化音频播放器
        [self.pcmPalyer class];
        
        //创建播放界面
        [self setupPlayView];
        
        //
        [self inner_initMediaPlayWithPath:moviePath];
    }
    return self;
}

-(void)inner_initMediaPlayWithPath:(NSString*)path {
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //初始化FFmpeg解码
        weakSelf.mediaDecoder = [[WTMediaDecode7 alloc]initWithVideo:path];
        
        __strong WTMediaPlayView *strongSelf = weakSelf;
        if (strongSelf) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [strongSelf startPlayMovie];
            });
        }
    });
}

-(void)startPlayMovie {
    
    _dispatchQueue = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
    
}

#pragma mark 播放控制
-(void)play {
    
}

-(void)stop {
    
    if (self.pcmPalyer) {
        [self.pcmPalyer stop];
        self.pcmPalyer=nil;
    }
}


#pragma mark private methods
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
