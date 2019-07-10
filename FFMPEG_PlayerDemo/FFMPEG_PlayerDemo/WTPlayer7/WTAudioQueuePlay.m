//
//  WTAudioQueuePlay.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/10/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTAudioQueuePlay.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define QUEUE_BUFFER_SIZE 3      //队列缓冲个数

@interface WTAudioQueuePlay() {
    AudioQueueRef audioQueue;                                 //音频播放队列
    AudioStreamBasicDescription _audioDescription;
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //音频缓存
    NSLock *mAudioLock;
    NSMutableArray *pcmDataArray;
    unsigned int minSizePerFrame;
    //doorbell chenqi modify  at 2018.12.24
    NSInteger audioSampleRate;
    NSInteger audioChannel;
    
    NSInteger audioType;
}

@end

@implementation WTAudioQueuePlay

-(instancetype)initWithSampleRate:(NSInteger)rate channel:(NSInteger)channel
{
    if (self = [super init]) {
        audioChannel=channel;
        audioSampleRate=rate;
        AudioStreamBasicDescription localAsbd = {0};
        localAsbd.mSampleRate = rate;
        localAsbd.mChannelsPerFrame = (UInt32)channel;
        [self initAudioProcess:&localAsbd activeAudioSesion:NO];
        
        //切换音频
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }
    return self;
}

- (instancetype)initWithAudioType:(NSInteger)audioType{
    self = [super init];
    if (self){ //虽然不应该内部控制audioSession，但是保持对之前兼容性还是保留
        self->audioType=audioType;
        [self initAudioProcess:NULL activeAudioSesion:YES];
    }
    return self;
}

- (instancetype)initWithAudioStreamBasicDescription:(AudioStreamBasicDescription*)asbd {
    self = [super init];
    if (self) {
        [self initAudioProcess:asbd activeAudioSesion:NO];
    }
    return self;
}

-(void)fillDefaultAudioDescription:(AudioStreamBasicDescription*)pasdb {
    if (pasdb == NULL) {
        return ;
    }
    //默认播放16K，16bit，1ch的声音
    pasdb->mFormatID = kAudioFormatLinearPCM;
    pasdb->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    pasdb->mSampleRate = 16000;
    pasdb->mChannelsPerFrame = 1;
    pasdb->mBitsPerChannel = 16;
    pasdb->mFramesPerPacket = 1;
    pasdb->mReserved = 0;
    pasdb->mBytesPerFrame = pasdb->mChannelsPerFrame * (pasdb->mBitsPerChannel / 8);
    pasdb->mBytesPerPacket = pasdb->mBytesPerFrame * pasdb->mFramesPerPacket;
}

-(void)initAudioProcess:(AudioStreamBasicDescription*)asbd activeAudioSesion:(BOOL)active {
    if (active) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }
    
    
    mAudioLock = [[NSLock alloc]init];
    pcmDataArray=[NSMutableArray array];
    [self fillDefaultAudioDescription:&_audioDescription];
    if (asbd != NULL) {
        _audioDescription.mFormatFlags = asbd->mFormatFlags == 0 ? _audioDescription.mFormatFlags : asbd->mFormatFlags;
        _audioDescription.mSampleRate = fabs(asbd->mSampleRate) < 0.001 ? _audioDescription.mSampleRate : asbd->mSampleRate;
        _audioDescription.mChannelsPerFrame = asbd->mChannelsPerFrame == 0 ? _audioDescription.mChannelsPerFrame : asbd->mChannelsPerFrame;
        _audioDescription.mBitsPerChannel = asbd->mBitsPerChannel == 0 ? _audioDescription.mBitsPerChannel : asbd->mBitsPerChannel;
        _audioDescription.mFramesPerPacket = asbd->mFramesPerPacket == 0 ? _audioDescription.mFramesPerPacket : asbd->mFramesPerPacket;
        _audioDescription.mBytesPerFrame = _audioDescription.mChannelsPerFrame * (_audioDescription.mBitsPerChannel / 8);
        _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame * _audioDescription.mFramesPerPacket;
    }
    //    //设置音频参数
    //    _audioDescription.mSampleRate = audioSampleRate?audioSampleRate:16000;//采样率
    //    _audioDescription.mFormatID = kAudioFormatLinearPCM;
    //    // 下面这个是保存音频数据的方式的说明，如可以根据大端字节序或小端字节序，浮点数或整数以及不同体位去保存数据
    //    _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;
    //    //1单声道 2双声道
    //    _audioDescription.mChannelsPerFrame =audioChannel?audioChannel:1;
    //    //每一个packet一侦数据,每个数据包下的桢数，即     每个数据包里面有多少桢
    //    _audioDescription.mFramesPerPacket = 1;
    //    //每个采样点16bit量化 语音每采样点占用位数
    //    _audioDescription.mBitsPerChannel = 16;
    //    _audioDescription.mBytesPerFrame = 4;//(_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
    //    //每个数据包的bytes总数，每桢的bytes数*每个数据包的桢数
    //    _audioDescription.mBytesPerPacket = 4;//_audioDescription.mBytesPerFrame * _audioDescription.mFramesPerPacket;
    //    _audioDescription.mReserved =  0;
    
    //这里按照设备侧一个aac数据包带有1024个pcm sample来计算
    if (audioType==1) {
        minSizePerFrame=640;
    }else{
        minSizePerFrame=1024*_audioDescription.mBytesPerPacket;
    }
    
    // 使用player的内部线程播放 新建输出
    AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, 0, 0, &audioQueue);
    
    // 初始化需要的缓冲区
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        AudioQueueAllocateBuffer(audioQueue, minSizePerFrame, &audioQueueBuffers[i]);
        memset(audioQueueBuffers[i]->mAudioData, 0, minSizePerFrame);
        audioQueueBuffers[i]->mAudioDataByteSize = minSizePerFrame;
        AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffers[i], 0, NULL);
    }
    
    // 设置音量
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
    AudioQueueStart(audioQueue, NULL);
}

- (void)stop
{
    AudioQueueStop(audioQueue, YES);
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        AudioQueueFreeBuffer(audioQueue, audioQueueBuffers[i]);
    }
    AudioQueueDispose(audioQueue, YES);
    [pcmDataArray removeAllObjects];
    audioQueue = nil;
    mAudioLock = nil;
}

// 播放相关
-(void)playWithData:(NSData *)data {
    [mAudioLock lock];
    if(pcmDataArray.count>10){
        [pcmDataArray removeAllObjects];
    }
    [pcmDataArray addObject:data];
    [mAudioLock unlock];
}

// ************************** 回调 **********************************

// 回调回来把buffer状态设为未使用
static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef audioQueueRef, AudioQueueBufferRef audioQueueBufferRef) {
    WTAudioQueuePlay* player = (__bridge WTAudioQueuePlay*)inUserData;
    [player->mAudioLock lock];
    [player handlerOutputAudioQueue:audioQueueRef inBuffer:audioQueueBufferRef];
    [player->mAudioLock unlock];
}

-(void)handlerOutputAudioQueue:(AudioQueueRef)inAQ inBuffer:(AudioQueueBufferRef)inBuffer
{
    if (pcmDataArray!=nil&&pcmDataArray.count>0) {
        NSData *data=[pcmDataArray objectAtIndex:0];
        Byte *bytes = (Byte*)malloc(minSizePerFrame);
        [data getBytes:bytes length:minSizePerFrame];
        [pcmDataArray removeObjectAtIndex:0];
        memcpy(inBuffer->mAudioData, bytes, minSizePerFrame);
        free(bytes);
    }else{
        memset(inBuffer->mAudioData, 0, minSizePerFrame);
    }
    inBuffer->mAudioDataByteSize = minSizePerFrame;
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}


-(void)clearData{
    [mAudioLock lock];
    [pcmDataArray removeAllObjects];
    [mAudioLock unlock];
}

@end
