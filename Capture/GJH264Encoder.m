//
//  GJH264Encoder.m
//  视频录制
//
//  Created by tongguan on 15/12/28.
//  Copyright © 2015年 未成年大叔. All rights reserved.
//

#import "GJH264Encoder.h"

@interface GJH264Encoder()
{
    long encoderFrameCount;
    
    
}
@property(nonatomic)VTCompressionSessionRef enCodeSession;
@end

@implementation GJH264Encoder
int _keyInterval;////key内的p帧数量

GJH264Encoder* encoder ;
- (instancetype)init
{
    self = [super init];
    if (self) {
        _entropyMode = kVTH264EntropyMode_CABAC;
        _profileLevel = kVTProfileLevel_H264_Main_AutoLevel;
        _allowBFrame = YES;
        _bitRate = 300*1024;
        _quality = 1.0;
        _maxKeyFrameInterval = 10;
        _expectedFrameRate = 0;
        encoder = self;
    }
    return self;
}



//编码
-(void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer fourceKey:(BOOL)fourceKey
{
    CVImageBufferRef imgRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    int32_t h = (int32_t)CVPixelBufferGetHeight(imgRef);
    int32_t w = (int32_t)CVPixelBufferGetWidth(imgRef);
    if (_enCodeSession == nil || h != _currentHeight || w != _currentWidth) {
        [self creatEnCodeSessionWithWidth:w height:h];
    }
    CMTime presentationTimeStamp = CMTimeMake(encoderFrameCount, 10);
    NSMutableDictionary * properties;
    
    if (fourceKey) {
        properties = [[NSMutableDictionary alloc]init];
        [properties setObject:@YES forKey:(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame];
    }
    OSStatus status = VTCompressionSessionEncodeFrame(
                                                      _enCodeSession,
                                                      imgRef,
                                                      presentationTimeStamp,
                                                      kCMTimeInvalid, // may be kCMTimeInvalid
                                                      (__bridge CFDictionaryRef)properties,
                                                      NULL,
                                                      NULL );
    encoderFrameCount++;
    if (status != 0) {
        NSLog(@"encodeSampleBuffer error:%d",(int)status);
        return;
    }
}

-(void)creatEnCodeSessionWithWidth:(int32_t)w height:(int32_t)h{
    if (_enCodeSession != nil) {
        VTCompressionSessionInvalidate(_enCodeSession);
    }
    OSStatus result = VTCompressionSessionCreate(
                                                 NULL,
                                                 w,
                                                 h,
                                                 kCMVideoCodecType_H264,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 encodeOutputCallback,
                                                 NULL,
                                                 &_enCodeSession);
    NSLog(@"VTCompressionSessionCreate status:%d",(int)result);
    _currentWidth = w;
    _currentHeight = h;
    
    [self _setCompressionSession];
    
    result = VTCompressionSessionPrepareToEncodeFrames(_enCodeSession);
    
}

-(void)_setCompressionSession{
    //    kVTCompressionPropertyKey_MaxFrameDelayCount
    //    kVTCompressionPropertyKey_MaxH264SliceBytes
    //    kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder
    //    kVTCompressionPropertyKey_RealTime
    
    OSStatus result =0;
    //b帧
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_AllowFrameReordering, _allowBFrame?kCFBooleanTrue:kCFBooleanFalse);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_AllowFrameReordering set error");
    }
    //p帧
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_AllowTemporalCompression, _allowPFrame?kCFBooleanTrue:kCFBooleanFalse);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_AllowTemporalCompression set error");
    }
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_ProfileLevel, _profileLevel);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_ProfileLevel set error");
    }
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_H264EntropyMode, _entropyMode);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_H264EntropyMode set error");
    }
    
    CFNumberRef bitRate = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &_bitRate);
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_AverageBitRate, bitRate);
    CFRelease(bitRate);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_AverageBitRate set error");
    }
    
    CFNumberRef  qualityRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType,&_quality);
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_Quality,qualityRef);
    CFRelease(qualityRef);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_Quality set error");
    }
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &_maxKeyFrameInterval);
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_MaxKeyFrameInterval,frameIntervalRef);
    CFRelease(frameIntervalRef);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_MaxKeyFrameInterval set error");
    }
    
    CFNumberRef frameRate = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &_expectedFrameRate);
    result = VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_ExpectedFrameRate,frameRate);
    CFRelease(frameRate);
    if (result != 0) {
        NSLog(@"kVTCompressionPropertyKey_ExpectedFrameRate set error");
    }
}



void encodeOutputCallback(void *  outputCallbackRefCon,void *  sourceFrameRefCon,OSStatus statu,VTEncodeInfoFlags infoFlags,
                          CMSampleBufferRef sample ){
    if (statu != 0) return;
    if (!CMSampleBufferDataIsReady(sample))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sample);
    size_t length, totalLength;
    uint8_t *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, (char**)&dataPointer);
    
    
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sample, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (encoder.sps == nil && keyframe)
    {
        NSLog(@"key interval%d",_keyInterval);
        _keyInterval = -1;
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sample);
        size_t sparameterSetSize, sparameterSetCount;
        int spHeadSize;
        int ppHeadSize;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, &spHeadSize );
        if (statusCode == noErr)
        {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, &ppHeadSize );
            if (statusCode == noErr)
            {
                uint8_t* data = malloc(4+4+sparameterSetSize+pparameterSetSize);
                memcpy(&data[0], "\x00\x00\x00\x01", 4);
                memcpy(&data[4], sparameterSet, sparameterSetSize);
                memcpy(&data[4+sparameterSetSize], "\x00\x00\x00\x01", 4);
                memcpy(&data[8+sparameterSetSize], pparameterSet, pparameterSetSize);
                
                [encoder setSpsWithData:data size:4+sparameterSetSize];
                [encoder setPpsWithData:data+4+sparameterSetSize size:4+pparameterSetSize];

//                NSData* parm = [NSData dataWithBytesNoCopy:data length:pparameterSetSize+sparameterSetSize+8 freeWhenDone:YES];
                //                [NSData dataWithBytes:data length:pparameterSetSize+sparameterSetSize+8];
//                [encoder setParameterSet:parm];
//                NSLog(@"data:%@",parm);
                //                if ([encoder.deleagte respondsToSelector:@selector(GJH264Encoder:encodeCompleteBuffer:withLenth:)]) {
                //                    [encoder.deleagte GJH264Encoder:encoder encodeCompleteBuffer:data withLenth:pparameterSetSize+sparameterSetSize+8];
                //                }
                //                free(data);
            }
        }
        
        //抛弃sps,pps
//        NSData* dt = [NSData dataWithBytes:dataPointer length:MIN(totalLength, 100)];
        uint32_t spsPpsLength = 0;
        memcpy(&spsPpsLength, dataPointer, 4);
        spsPpsLength = CFSwapInt32BigToHost(spsPpsLength);
        dataPointer += spsPpsLength + 4;
        totalLength -= spsPpsLength + 4;
        
    }
    
    
    
    if (statusCodeRet == noErr) {
        
        uint32_t bufferOffset = 0;
        static const uint32_t AVCCHeaderLength = 4;
        while (bufferOffset < totalLength) {
            
            _keyInterval++;
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            uint8_t* data = dataPointer + bufferOffset;
            memcpy(&data[0], "\x00\x00\x00\x01", AVCCHeaderLength);
            
            [encoder.deleagte GJH264Encoder:encoder encodeCompleteBuffer:data withLenth:NALUnitLength +AVCCHeaderLength keyFrame:keyframe];
            keyframe = false;
            NSLog(@"h264编码成功,%d",NALUnitLength);
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}
//-(void)setParameterSet:(NSData*)parm{
//    _parameterSet = parm;
//}
-(void)setSpsWithData:(uint8_t*)data size:(size_t)size{
    _sps = [NSData dataWithBytesNoCopy:data length:size freeWhenDone:YES];
}
-(void)setPpsWithData:(uint8_t*)data size:(size_t)size{
    _pps = [NSData dataWithBytesNoCopy:data length:size freeWhenDone:YES];
}

-(void)stop{
    _enCodeSession = nil;
}
-(void)dealloc{
    VTCompressionSessionInvalidate(_enCodeSession);
    
}
//-(void)restart{
//
//    [self creatEnCodeSession];
//}

@end
