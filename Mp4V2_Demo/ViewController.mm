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
using namespace mp4v2::impl;
@interface ViewController ()
{
    MP4FileHandle _fileHandle;
    int _videoTrackID;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
    // Do any additional setup after loading the view.
}
-(void)loadData{
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
- (IBAction)Analysis:(UIButton *)sender forEvent:(UIEvent *)event {
    RAViewController* controller = [[RAViewController alloc]init];
    controller.fileHandle = _fileHandle;
    [self presentViewController:controller animated:YES completion:nil];
}
- (IBAction)playOrStop:(UIButton *)sender {
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
