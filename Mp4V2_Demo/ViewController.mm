//
//  ViewController.m
//  Mp4v2Code
//
//  Created by 未成年大叔 on 16/9/24.
//  Copyright © 2016年 MinorUncle. All rights reserved.
//

#import "ViewController.h"
#import "mp4v2.h"
#import "src.h"
#import "RAViewController.h"
#import "GJCaptureTool.h"
#import "GJH264Encoder.h"
using namespace mp4v2::impl;
@interface ViewController ()<GJCaptureToolDelegate,GJH264EncoderDelegate>
{
    MP4FileHandle _fileHandle;
    MP4TrackId _videoTrackID;
    MP4TrackId _audioID;
    GJCaptureTool* _captureTool;
    GJH264Encoder* _gjEncoder;
    NSDate* _startTime;
    dispatch_queue_t _writeQueue;
    uint8_t* _dataCache;
    int _dataSize;
    NSDate* _beforeTime;
}
@property (weak, nonatomic) IBOutlet UILabel *descLab;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
    // Do any additional setup after loading the view.
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [_captureTool startRunning];
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_captureTool stopRunning];
}
-(void)loadData{
    [self readFile];
    
    _captureTool = [[GJCaptureTool alloc]initWithType: (GJCaptureType)(GJCaptureTypeAudioStream | GJCaptureTypeVideoStream) fps:15 layer:_imageView.layer];
    _captureTool.fps = 20;
    _captureTool.delegate = self;
    _gjEncoder = [[GJH264Encoder alloc]init];
    _gjEncoder.deleagte = self;
    
}
-(void)readFile{
    NSString* sourcePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    _fileHandle =  MP4Read(sourcePath.UTF8String);
    for (int i = 1; i <= MP4GetNumberOfTracks(_fileHandle,0,0); i++) {
        const char* type = MP4GetTrackType(_fileHandle, i);
        const char* normType = MP4NormalizeTrackType(type);
        if (!strcmp(normType, MP4_VIDEO_TRACK_TYPE)) {
            _videoTrackID = i;
            break;
        }
    }
}
-(void)createFile{
   NSString* path =  NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    path = [NSString stringWithFormat:@"%@/mp4Test.ma4",path];
    _fileHandle = MP4Create(path.UTF8String);
    _writeQueue = dispatch_queue_create("write", DISPATCH_QUEUE_SERIAL);
    _dataSize = 1024*1024*3;
}
- (IBAction)Analysis:(UIButton *)sender forEvent:(UIEvent *)event {
    RAViewController* controller = [[RAViewController alloc]init];
    controller.fileHandle = _fileHandle;
    [self presentViewController:controller animated:YES completion:nil];
}
static int sampleCount = 0;
- (IBAction)playOrStop:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [_captureTool startRecodeing];
        _startTime = [NSDate date];

        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            _descLab.text = [NSString stringWithFormat:@"fps:%d",sampleCount];
            sampleCount = 0;
        }];
    }else{
        [_captureTool stopRecode];
        MP4Close(_fileHandle);
    }
    return;
    uint8_t* bytes= NULL;
    uint32_t numByte = 0;
    MP4Timestamp startTime;
    MP4Duration dration;
    MP4Duration offset;
    bool isSyn;
    uint32_t numSample = MP4GetTrackNumberOfSamples(_fileHandle, _videoTrackID);
    numByte = MP4GetTrackMaxSampleSize(_fileHandle, _videoTrackID);
    bytes = (uint8_t*)malloc(sizeof(numByte));
    uint32_t outNum = numByte;
    for (int i = 1 ; i<= numSample; i++) {
        bool result = MP4ReadSample(_fileHandle, _videoTrackID, i, &bytes, &outNum, &startTime, &dration, &offset, &isSyn);
        NSData* data = [NSData dataWithBytesNoCopy:bytes length:outNum freeWhenDone:NO];
        
        NSLog(@"data:%@",data);
        outNum = numByte;
        if (result) {
//            [self getImageWithBuffer:bytes bytesPerRow:<#(int)#> width:<#(int)#> height:<#(int)#>]
        }

    }
}


-(void)GJCaptureTool:(GJCaptureTool *)captureTool recodeVideoYUVData:(CMSampleBufferRef)sampleBufferRef{
    sampleCount++;
//    NSDate* date =[NSDate date];
//    NSTimeInterval lenth =[date timeIntervalSinceDate:_startTime];
//    _startTime = date;
//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferRef);
//    CVPixelBufferLockBaseAddress(imageBuffer, 0);
//    void* baseAdd = CVPixelBufferGetBaseAddress(imageBuffer);
//    size_t w = CVPixelBufferGetWidth(imageBuffer);
//    size_t h = CVPixelBufferGetHeight(imageBuffer);
//    size_t size = CVPixelBufferGetDataSize(imageBuffer);
//    //    OSType p =CVPixelBufferGetPixelFormatType(imageBuffer);
//
//    
//
//    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    [_gjEncoder encodeSampleBuffer:sampleBufferRef fourceKey:NO];


}
-(void)GJCaptureTool:(GJCaptureTool *)captureTool recodeAudioPCMData:(CMSampleBufferRef)sampleBufferRef{

}

-(void)GJH264Encoder:(GJH264Encoder *)encoder encodeCompleteBuffer:(uint8_t *)buffer withLenth:(long)totalLenth keyFrame:(BOOL)keyFrame{
    if (_videoTrackID == 0) {
        u_char* sps = (u_char*)encoder.sps.bytes;
        _videoTrackID = MP4AddH264VideoTrack(_fileHandle, MP4_MSECS_TIME_SCALE,MP4_INVALID_DURATION, encoder.currentWidth, encoder.currentHeight, sps[5], sps[6], sps[7], 3);
        _beforeTime = [NSDate date];
        return;
//        _videoTrackID = MP4AddVideoTrack(_fileHandle, MP4_MSECS_TIME_SCALE, 1.0/ _captureTool.fps *MP4_MSECS_TIME_SCALE, encoder.currentWidth , encoder.currentHeight );
    }
    if(keyFrame){
        //设置sps和pps
        u_char* sps = (u_char*)encoder.sps.bytes;
        
        MP4AddH264SequenceParameterSet(_fileHandle, _videoTrackID, sps, encoder.sps.length-4);
        MP4AddH264PictureParameterSet(_fileHandle, _videoTrackID, (uint8_t*)encoder.pps.bytes, encoder.pps.length);
        MP4SetVideoProfileLevel(_fileHandle, 0x7F);
    }

    @autoreleasepool {
        NSDate* currentDate = [NSDate date];
        NSTimeInterval d = [currentDate timeIntervalSinceDate:_beforeTime];
        _beforeTime = currentDate;
        bool result = MP4WriteSample(_fileHandle, _videoTrackID, (const uint8_t*)buffer, (uint32_t)totalLenth,MP4_MSECS_TIME_SCALE*d,0,keyFrame);
        NSLog(@"write result:%d",result);
        NSLog(@"acc:%d",sampleCount);
    }
}


-(UIImage*)getImageWithBuffer:(void*)buffer bytesPerRow:(int)bytesPerRow width:(int)width height:(int)height{
    
    // Create a device-dependent gray color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    // Create a bitmap graphics context with the sample buffer data
    
    CGContextRef context = CGBitmapContextCreate(buffer, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGImageAlphaNone);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return image;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
