//
//  WTAudioPlayManage.m
//  FFMPEG_PlayerDemo
//
//  Created by tyler on 7/16/19.
//  Copyright © 2019 ocean. All rights reserved.
//

#import "WTAudioPlayManage.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define QUEUE_BUFFER_SIZE 3 //队列缓冲个数
#define MIN_SIZE_PER_FRAME 1280 //每帧最小数据长度
#define kMinSizePerFrame 1280 //每帧最小数据长度

@interface WTAudioPlayManage ()
{
    AudioStreamBasicDescription streamDescription; ///音频参数
    AudioQueueRef audioQueue; //音频播放队列
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //音频缓存
    BOOL audioQueueUsed[QUEUE_BUFFER_SIZE];
    UInt32        mNumPacketsToRead;
    UInt32        bufferByteSize;
}

@end

@implementation WTAudioPlayManage

- (instancetype)initWithSampleRate:(int)sampleRate {
    if (self = [self init]) {
        streamDescription.mSampleRate = sampleRate;//采样率
    }
    return self;
}
-(instancetype)init{
    if (self = [super init]) {
        [self setup];
    }
    return self;
}
- (void)dealloc
{
    if (audioQueue != nil) {
        AudioQueueStop(audioQueue, true);
    }
    audioQueue = nil;
    
    NSLog(@"PCMDataPlayer dealloc...");
}

- (void)setup {
    [self setUpStreamDescription];
    @synchronized (self){
        OSStatus status;
        //创建播放队列
        status = AudioQueueNewOutput(&streamDescription, outputCallback, (__bridge void * _Nullable)self, nil, nil, 0, &audioQueue); //使用player的内部线程播放
        if(status != noErr) {
            NSLog(@"error:%d",status);
            return;
        }
        //计算audioQueue实例的大小
        UInt32 maxPacketSize = 1;
        UInt32 size = sizeof(maxPacketSize);
        AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &size, &maxPacketSize);
        //计算0.01秒的数据大小
        CalculateBytesForTime(streamDescription, maxPacketSize, 0.01, &bufferByteSize, &mNumPacketsToRead);
        bool isFormatVBR = (streamDescription.mBytesPerPacket == 0 || streamDescription.mFramesPerPacket == 0);
        
        //初始化音频缓冲区
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            status = AudioQueueAllocateBufferWithPacketDescriptions(audioQueue, kMinSizePerFrame, (isFormatVBR ? mNumPacketsToRead : 0), &audioQueueBuffers[i]);
            if(status != noErr) {
                NSLog(@"Audio Queue alloc buffer error %d  %d",i,(int)status);
                return;
            }
        }
        
        //设置AudioQueue为软解码
        UInt32 value = kAudioQueueHardwareCodecPolicy_UseSoftwareOnly;
        status = AudioQueueSetProperty(audioQueue, kAudioQueueProperty_HardwareCodecPolicy, &value, sizeof(value));
        if(status != noErr) {
            NSLog(@"software code not use");
        }
        //设置音量
        Float32 gain=1.0;
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, gain);
    }
}
- (void)setUpStreamDescription {
    //设置音频参数
    streamDescription.mSampleRate       = kAudioPlaySampleRate;//采样率 44100 16000
    streamDescription.mFormatID         = kAudioFormatLinearPCM;
    streamDescription.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    streamDescription.mChannelsPerFrame = kAudioPlayChannel;//单声道
    streamDescription.mFramesPerPacket  = 1;//每一个packet一侦数据
    streamDescription.mBitsPerChannel   = 16;// 0 for compressed format
    streamDescription.mBytesPerFrame    = streamDescription.mChannelsPerFrame * (streamDescription.mBitsPerChannel/8);
    streamDescription.mBytesPerPacket   = streamDescription.mBytesPerFrame;
    streamDescription.mReserved         = 0;
}

- (void)playWith:(void *)audioData length:(unsigned int)length {
    OSStatus status;
    if (audioQueue == nil || ![self checkBufferHasUsed]) {
        [self setup];
        //播放
        status = AudioQueueStart(audioQueue, NULL);
        if(status != noErr) {
            NSLog(@"error:%d",status);
            return;
        }
    }
    @synchronized (self){
        AudioQueueBufferRef audioQueueBuffer = NULL;
        
        //获取可用buffer
        while (true) {
            audioQueueBuffer = [self getNotUsedBuffer];
            if (audioQueueBuffer != NULL) {
                break;
            }
        }
        memcpy(audioQueueBuffer->mAudioData, audioData, length);//将pcmdata按长度length赋值给audioQueueBuffer->mAudioData，内存拷贝
        audioQueueBuffer->mAudioDataByteSize = length;
        //将buffer放入buffer queue中
        AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer, 0, NULL);
    }
}
-(void)stop {
    @synchronized (self){
        AudioQueueReset(audioQueue);
        AudioQueueStop(audioQueue, YES);
    }
}

- (BOOL)checkBufferHasUsed
{
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (YES == audioQueueUsed[i]) {
            return YES;
        }
    }
    //buffer中有数据，可以开始播放数据了
    NSLog(@"开始播放............");
    return NO;
}

- (AudioQueueBufferRef)getNotUsedBuffer
{
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (NO == audioQueueUsed[i]) {
            audioQueueUsed[i] = YES;
            return audioQueueBuffers[i];
        }
    }
    return NULL;
}
#pragma mark - ccccc
void CalculateBytesForTime(AudioStreamBasicDescription inDesc, UInt32 inMaxPacketSize, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets)
{
    // we only use time here as a guideline
    // we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it
    static const int maxBufferSize = 0x1000; // limit size to 4K 4096
    static const int minBufferSize = 0x400; // limit size to 1K 1024
    
    if (inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * inMaxPacketSize;
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        *outBufferSize = maxBufferSize > inMaxPacketSize ? maxBufferSize : inMaxPacketSize;
    }
    
    // we're going to limit our size to our default
    if (*outBufferSize > maxBufferSize && *outBufferSize > inMaxPacketSize)
        *outBufferSize = maxBufferSize;
    else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    *outNumPackets = *outBufferSize / inMaxPacketSize;
}
static void outputCallback(void *inUserData, AudioQueueRef outAQ, AudioQueueBufferRef outBuffer) {
    WTAudioPlayManage *player = (__bridge WTAudioPlayManage *)inUserData;
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        if (outBuffer == player->audioQueueBuffers[i]) {
            // AudioQueue 使用完buffer
            player->audioQueueUsed[i] = NO;
        }
    }
}


@end
