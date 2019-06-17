//
//  AACDecoder.m
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import "AACDecoder.h"
#import <AudioToolBox/AudioConverter.h>
#import <AudioToolBox/AudioFormat.h>

//const uint32_t CONST_BUFFER_SIZE = 0x10000;


@interface AACDecoder (){
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    
    AudioConverterRef audioConverter;
}

@property (strong, nonatomic) NSCondition *converterCond;

@end

@implementation AACDecoder

typedef struct {
    uint8_t* data;
    int size;
    int channelCount;
} UserData;

OSStatus decodeProc(AudioConverterRef audioConverter, UInt32 *ioNumDataPackets, AudioBufferList* ioData, AudioStreamPacketDescription** ioPacketDesc, void* inUserData )
{
    UserData* ud = (UserData*)inUserData;
    
    *ioNumDataPackets = 1;
    
    *ioPacketDesc = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription));
    (*ioPacketDesc)[0].mStartOffset = 0;
    (*ioPacketDesc)[0].mVariableFramesInPacket = 0;
    (*ioPacketDesc)[0].mDataByteSize = ud->size;
    
    ioData->mBuffers[0].mData = ud->data;
    ioData->mBuffers[0].mDataByteSize = ud->size;
    ioData->mBuffers[0].mNumberChannels = ud->channelCount;
    
    return noErr;
}

- (instancetype)init
{
    if (self = [super init]) {
        _converterCond = [[NSCondition alloc] init];
        [self setup];
    }
    return self;
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

- (void)creatConverter
{
    if (!audioConverter) {
        /*
        AudioClassDescription *description = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
        OSStatus status = AudioConverterNewSpecific(&inputFormat, &outputFormat, 1, description, &audioConverter); // 创建转换器
        if (status != 0) {
            NSLog(@"setup converter: %d", (int)status);
        }
         */
        AudioConverterNew(&inputFormat, &outputFormat, &audioConverter);
    }
}

- (void)clearConverter
{
    if (audioConverter) {
        AudioConverterDispose(audioConverter);
        audioConverter=NULL;
    }
}

- (void)setup
{
//    AudioStreamBasicDescription inputFormat;
    memset(&inputFormat, 0, sizeof(inputFormat));
    inputFormat.mFormatID = kAudioFormatMPEG4AAC;
    inputFormat.mFormatFlags = kMPEG4Object_AAC_LC;
    inputFormat.mFramesPerPacket = 1024;
    inputFormat.mSampleRate = 16000;
    inputFormat.mChannelsPerFrame = 1;
    inputFormat.mBitsPerChannel = 0;
    inputFormat.mReserved=0;
    inputFormat.mBytesPerPacket = 0;
    inputFormat.mBytesPerFrame = 0;
    
    audioConverter = NULL;
    
    //initFormat
//    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 16000;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;//|kAudioFormatFlagIsPacked;
    outputFormat.mBytesPerPacket   = 2;//outputFormat.mBitsPerChannel/8*outputFormat.mChannelsPerFrame;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = 2;//outputFormat.mBitsPerChannel/8*outputFormat.mChannelsPerFrame;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel   = 16;
    
    [self creatConverter];
}

- (void)pushData:(uint8_t *)data size:(size_t)size completion:(void(^)(NSData *pcmData))block{
    UInt32 theOuputBufSize = 2048;
    UInt32 packetSize = 1024;
    void *outBuffer = malloc(theOuputBufSize);
    memset(outBuffer, 0, theOuputBufSize);
    
    UserData ud;
    ud.size = (int)size;
    ud.data = (uint8_t *)data;
    ud.channelCount = 1;
    
    AudioBufferList outputBuffers;
    outputBuffers.mNumberBuffers = 1;
    outputBuffers.mBuffers[0].mDataByteSize = theOuputBufSize;
    outputBuffers.mBuffers[0].mData = outBuffer;
    outputBuffers.mBuffers[0].mNumberChannels = 1;

    
    AudioStreamPacketDescription output_packet_desc[packetSize];
    
    [_converterCond lock];
    OSStatus status = AudioConverterFillComplexBuffer(audioConverter, decodeProc, &ud, &packetSize, &outputBuffers, output_packet_desc);
    [_converterCond unlock];
    
    if (status == noErr) {
        block([NSData dataWithBytes:outputBuffers.mBuffers[0].mData length:outputBuffers.mBuffers[0].mDataByteSize]);
    }

    free(outBuffer);
}

@end
