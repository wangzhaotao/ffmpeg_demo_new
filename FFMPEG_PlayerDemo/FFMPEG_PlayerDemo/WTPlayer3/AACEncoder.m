//
//  AACEncoder.m
//  BatteryCam
//
//  Created by ocean on 2018/6/15.
//  Copyright © 2018年 oceanwing. All rights reserved.
//

#import "AACEncoder.h"
#include "aacenc_lib.h"

#define PROFILE_AAC_LC 2
#define PROFILE_AAC_HE 5
#define PROFILE_AAC_HE_v2 29
#define PROFILE_AAC_LD 23
#define PROFILE_AAC_ELD 39

@interface AACEncoder(){
    HANDLE_AACENCODER _encoder;
    
    int _bitrate;
    int _samplerate;
    int _channel;
}

@end

@implementation AACEncoder

-(instancetype)initWithBitrate:(int)bitrate samplerate:(int)samplerate channel:(int)channel{
    self=[super init];
    if (self) {
        _bitrate=bitrate;
        _samplerate=samplerate;
        _channel=channel;
        
        [self initEncoder];
    }
    return self;
}

- (int)initEncoder{
    if (aacEncOpen(&_encoder, 0, _channel)!= AACENC_OK) {
        return -1;
    }
    
    if (aacEncoder_SetParam(_encoder, AACENC_AOT, PROFILE_AAC_LC)!= AACENC_OK) {
        return -1;
    }
    
    if (aacEncoder_SetParam(_encoder, AACENC_BITRATE, _bitrate)!= AACENC_OK) {
        return -1;
    }
    
    if (aacEncoder_SetParam(_encoder, AACENC_SAMPLERATE, _samplerate)!= AACENC_OK) {
        return -1;
    }
    
    //doorbell chenqi modify  at 2018.12.24
    if (aacEncoder_SetParam(_encoder, AACENC_CHANNELMODE, _channel)!= AACENC_OK) {//MODE_1
        return -1;
    }
    
    if (aacEncoder_SetParam(_encoder, AACENC_TRANSMUX, 2)!= AACENC_OK) {
        return -1;
    }
    
    if (aacEncEncode(_encoder, NULL, NULL, NULL, NULL)!= AACENC_OK) {
        return -1;
    }
    return 0;
}


- (int)encodePCMToAAC:(char *)pcm len:(int)len callBack:(void(^)(char *aacData,int aac_len))completeBlock{
    if (!_encoder) {
        [self initEncoder];
    }
    
    AACENC_BufDesc in_buf = {0};
    AACENC_BufDesc out_buf = {0};
    AACENC_InArgs in_args = {0};
    AACENC_OutArgs out_args = {0};
    int in_identifier = IN_AUDIO_DATA;
    int in_elem_size = 2;
    
    INT size = 1024;
    int out_identifier = OUT_BITSTREAM_DATA;
    void *out_ptr[1] =  {malloc(1024)};
    int out_elem_size = 1;
    out_buf.bufs = out_ptr;
    out_buf.bufSizes = &size;
    out_buf.numBufs = 1;
    out_buf.bufferIdentifiers = &out_identifier;
    out_buf.bufElSizes = &out_elem_size;
    
    
    in_args.numInSamples = len / 2;
    in_buf.numBufs = 1;
    void *inputBuf[1] = {pcm};
    in_buf.bufs =inputBuf;
    in_buf.bufferIdentifiers = &in_identifier;
    in_buf.bufElSizes = &in_elem_size;
    
    
    AACENC_ERROR rt = aacEncEncode(_encoder, &in_buf, &out_buf, &in_args, &out_args);
    if (rt != AACENC_OK) {
        NSLog(@"aac enc encode error %u",rt);
        return -1;
    }
    
    if (out_args.numOutBytes > 0){
        completeBlock(out_buf.bufs[0],out_args.numOutBytes);
    }

    if (out_buf.bufs[0]) {
        free(out_buf.bufs[0]);
    }
    
    return 0;
}

- (void)free{
    if (_encoder) {
        aacEncClose(&_encoder);
        _encoder = NULL;
    }
}

@end
