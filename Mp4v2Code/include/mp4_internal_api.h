//
//  mp4_internal_api.h
//  Mp4v2Code
//
//  Created by 未成年大叔 on 16/9/24.
//  Copyright © 2016年 MinorUncle. All rights reserved.
//
//#include "src.h"
////#include "mp4atom.h"
////using namespace mp4v2;
namespace mp4v2 { namespace impl {
    
    class MP4Atom;
    class MP4Property;
    class MP4Float32Property;
    class MP4StringProperty;
    class MP4BytesProperty;
    class MP4Descriptor;
    class MP4DescriptorProperty;
    class MP4File;
class mp4_internal_api{
public:
    static void CopySample(
                           MP4File*    srcFile,
                           MP4TrackId  srcTrackId,
                           MP4SampleId srcSampleId,
                           MP4File*    dstFile,
                           MP4TrackId  dstTrackId,
                           MP4Duration dstSampleDuration );
};
}
}
