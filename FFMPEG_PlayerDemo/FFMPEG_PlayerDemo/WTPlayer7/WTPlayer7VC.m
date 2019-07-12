//
//  WTPlayer7VC.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTPlayer7VC.h"
#import "WTMediaPlayView.h"

@interface WTPlayer7VC ()
@property (nonatomic, strong) WTMediaPlayView *playView;

@end

@implementation WTPlayer7VC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    //
    [self initUI];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_playView startPlayMovie];
}
-(void)viewWillDisappear:(BOOL)animated {
    
    [_playView stopPlay];
    
    [super viewWillDisappear:animated];
}


#pragma mark init UI
-(void)initUI {
    
    NSString *moviePath = @"http://live.xinhuashixun.com/live/chn01/desc.m3u8";
    moviePath = @"http://media.fantv.hk/m3u8/archive/channel2_stream1.m3u8";
    
    WTMediaPlayView *playView = [WTMediaPlayView createPlayViewWithPath:moviePath];
    [self.view addSubview:playView];
    _playView = playView;
    
    CGFloat width = iScreenW;
    CGFloat height = iScreenW*9/16;
    [playView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(@0);
        make.center.equalTo(@0);
        make.width.equalTo(@(width));
        make.height.equalTo(@(height));
    }];
}


@end
