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
    //
    [self initUI];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_playView startPlayMovie];
}


#pragma mark init UI
-(void)initUI {
    
    WTMediaPlayView *playView = [[WTMediaPlayView alloc]init];
    [self.view addSubview:playView];
    _playView = playView;
    
    [playView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(@0);
        make.center.equalTo(@0);
    }];
}


@end
