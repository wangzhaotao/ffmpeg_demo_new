//
//  WTAudioPlayVC8.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/18/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTAudioPlayVC8.h"
#import "Masonry.h"
#import "KxAudioManager.h"

@interface WTAudioPlayVC8 ()

@end

@implementation WTAudioPlayVC8

- (void)viewDidLoad {
    [super viewDidLoad];
    //
    
    [self initUI];
}


#pragma mark private methods
-(void)start {
    
    
}


#pragma mark actions
-(void)playAudioAction:(UIButton*)sender {
    
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];
    
    
}


#pragma mark initUI
-(void)initUI {
    
    UIButton *playBtn = [[UIButton alloc]init];
    [playBtn setTitle:@"Play Audio" forState:UIControlStateNormal];
    [playBtn addTarget:self action:@selector(playAudioAction:) forControlEvents:UIControlEventTouchUpInside];
    [playBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:playBtn];
    
    [playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(@0);
    }];
}


@end
