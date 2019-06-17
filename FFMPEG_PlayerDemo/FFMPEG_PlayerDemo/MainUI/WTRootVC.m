//
//  WTRootVC.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 6/13/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTRootVC.h"
#import "Masonry.h"

@interface WTRootVC ()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray <NSDictionary*>*dataArray;

@end

@implementation WTRootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    //
    self.title = @"Hello world";
    //
    [self initData];
}

#pragma mark init
-(void)initData {
    
    NSString *fileName = @"main.plist";
    NSString *filePath = [[NSBundle mainBundle]pathForResource:fileName ofType:nil];
    
    NSDictionary *dataDic = [NSDictionary dictionaryWithContentsOfFile:filePath];
    
    NSArray *datas = dataDic[@"datas"];
    [self.dataArray addObjectsFromArray:datas];
    [self.tableView reloadData];
}

#pragma mark actions
-(void)clickCellAction:(NSIndexPath*)idxPath {
    
    NSDictionary *dic = self.dataArray[idxPath.row];
    NSString *vcName = dic[@"vc"];
    if (vcName) {
        UIViewController *controller = [NSClassFromString(vcName) new];
        [self.navigationController pushViewController:controller animated:YES];
    }
}



#pragma mark UITableViewDataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.dataArray.count;
}
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(UITableViewCell.class) forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = self.dataArray[indexPath.row][@"title"];
    
    return cell;
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSDictionary *dic = self.dataArray[indexPath.row];
    
    NSString *method = dic[@"method"];
    if (method) {
        SEL methodAction = NSSelectorFromString(method);
        if ([self respondsToSelector:methodAction]) {
            [self performSelector:methodAction withObject:indexPath afterDelay:0];
        }
    }else {
        
        //方法为空
        
    }
    
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.1;
}
-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.1;
}
-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [UIView new];
}
-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [UIView new];
}


#pragma mark set/get
-(UITableView*)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [self.view addSubview:_tableView];
        
        [_tableView registerClass:UITableViewCell.class forCellReuseIdentifier:NSStringFromClass(UITableViewCell.class)];
        [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.leading.bottom.trailing.equalTo(@0);
        }];
    }
    return _tableView;
}
-(NSMutableArray<NSDictionary*>*)dataArray {
    if (!_dataArray) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}


@end
