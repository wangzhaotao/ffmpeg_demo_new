//
//  WTMainController.m
//  FFMPEG_PlayerDemo
//
//  Created by ocean on 2018/8/15.
//  Copyright © 2018年 ocean. All rights reserved.
//

#import "WTMainController.h"
#import "KxMovieViewController.h"
#import "WTMoviePlayerVC.h"
#import "WTPlayerVC2.h"
#import "Utils.h"
#import "WTPlayerVC3.h"
#import "WTTestVC4.h"
#import "WTPlayerVC5.h"


@interface WTMainController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *dataArray;

@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) NSMutableArray *btnsArray;

@end

@implementation WTMainController

- (void)viewDidLoad {
    [super viewDidLoad];
    //
    NSLog(@"View Did Load 1");
    
    self.dataArray = [Utils makeDictionaryDataArrayWithTxtFile:@"PlayList.txt"];
    [self.tableView reloadData];
    
    [self initUI];
    [self clickChangeControllerAction:_btnsArray[2]];
}

-(void)playMediaWithPath:(NSString*)path {
    
//    NSString *path1 = @"http://live.xinhuashixun.com/live/chn01/desc.m3u8"; //新华社中文网
//    path1 = @"http://media.fantv.hk/m3u8/archive/channel2_stream1.m3u8";
    NSDictionary *parameters = @{@"KxMovieParameterDisableDeinterlacing":@"1"};
    
    if (_index==0) {
        KxMovieViewController *vc = [KxMovieViewController movieViewControllerWithContentPath:path parameters:parameters];
        [self.navigationController pushViewController:vc animated:YES];
    }else if (_index==1) {
        WTMoviePlayerVC *vc = [WTMoviePlayerVC movieViewControllerWithContentPath:path parameters:parameters];
        [self.navigationController pushViewController:vc animated:YES];
    }else if (_index==2) {
        WTPlayerVC2 *vc = [WTPlayerVC2 movieViewControllerWithContentPath:path parameters:parameters];
        [self.navigationController pushViewController:vc animated:YES];
    }else if (_index==3) {
        WTPlayerVC3 *vc = [WTPlayerVC3 movieViewControllerWithContentPath:path parameters:parameters];
        [self.navigationController pushViewController:vc animated:YES];
    }else if (_index==4) {
        WTPlayerVC5 *vc = [WTPlayerVC5 movieViewControllerWithContentPath:path parameters:parameters];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

-(void)clickChangeControllerAction:(UIButton*)sender {
    
    _index = sender.tag;
    for (int i=0; i<self.btnsArray.count; i++) {
        UIButton *btn = [self.btnsArray objectAtIndex:i];
        if (_index == i) {
            [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        }else{
            [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        }
    }
}


#pragma mark UITableViewDataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArray.count;
}
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(UITableViewCell.class) forIndexPath:indexPath];
    NSDictionary *dic = [self.dataArray objectAtIndex:indexPath.row];
    NSString *name = dic[@"name"];
    NSString *path = dic[@"path"];
    
    cell.textLabel.text = name;
    if ([path containsString:@"https"]) {
        cell.textLabel.textColor = [UIColor lightGrayColor];
    }else{
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    return cell;
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
#if 0
    WTTestVC4 *vc = [[WTTestVC4 alloc]init];
    [self.navigationController pushViewController:vc animated:YES];
    return;
#else
    
    NSDictionary *dic = [self.dataArray objectAtIndex:indexPath.row];
    NSString *path = dic[@"path"];
    NSLog(@"点播地址: %@", path);
    if (path) {
        [self playMediaWithPath:path];
    }
#endif
}
-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.1;
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.1;
}
-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc]init];
}
-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [[UIView alloc]init];
}


#pragma mark initUI
-(void)initUI {
    
    _btnsArray = [NSMutableArray array];
    
    NSArray *array = @[@"KxMovieViewController", @"WTMoviePlayerVC", @"WTPlayerVC2", @"WTPlayerVC3", @"WTPlayerVC5"];
    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat originX = 15;
    CGFloat btnWidth = (screenWidth-originX*(array.count+1))/array.count;
    
    for (int i =0; i<array.count; i++) {
        NSString *keyName = array[i];
        UIButton *btn1 = [[UIButton alloc]init];
        btn1.tag = i;
        [btn1 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [btn1 setTitle:keyName forState:UIControlStateNormal];
        btn1.layer.cornerRadius = 5;
        btn1.layer.borderWidth = 0.5;
        btn1.layer.borderColor = [UIColor lightGrayColor].CGColor;
        [btn1 addTarget:self action:@selector(clickChangeControllerAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn1];
        
        btn1.frame = CGRectMake((i+1)*originX+i*btnWidth, screenHeight-60, btnWidth, 50);
        [_btnsArray addObject:btn1];
    }
    
}
    
#pragma mark set/get
-(UITableView*)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass(UITableViewCell.class)];
        [self.view addSubview:_tableView];
    }
    return _tableView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
