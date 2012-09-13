//
//  ObjectTrackerLibrary.mm
//  CKObjectTrackerShared
//
//  Created by Christoph Kapffer on 07.09.12.
//  Copyright (c) 2012 HTW Berlin. All rights reserved.
//

#import "ObjectTrackerLibrary.h" // Obj-C
#import "ObjectTrackerParameter.h" // Obj-C
#import "ObjectTrackerDebugger.h" // C++
#import "ObjectTracker.h" // C++

#import "CVImageConverter+PixelBuffer.h"

using namespace ck;
using namespace cv;

@interface ObjectTrackerLibrary ()
{
    Mat _objectImage;
    ObjectTracker* _tracker;

    TrackerOutput _output;
    TrackerDebugInfo _frameDebugInfo;
    vector<TrackerDebugInfoStripped> _videoDebugInfo;
}

@property (nonatomic, assign) dispatch_queue_t stillImageTrackerQueue;

- (void)handleTrackingInVideoResult;
- (void)handleTrackingInImageResult;
- (Homography)homographyWithMatrix:(Mat&)matrix;
- (void)showError:(NSError*)error;

@end

@implementation ObjectTrackerLibrary

#pragma mark - properties

@synthesize delegate = _delegate;
@synthesize recordDebugInfo = _recordDebugInfo;
@synthesize stillImageTrackerQueue = _stillImageTrackerQueue;

- (ObjectTrackerParameterCollection*) parameters
{
    return [self parameterCollectionFromSettings:_tracker->getSettings()];
}

- (Homography)homography
{
    return [self homographyWithMatrix:_output.homography];
}
- (BOOL)foundObject
{
    return _output.isObjectPresent;
}

- (NSString*)frameDebugInfoString
{
    string result = ObjectTrackerDebugger::getDebugString(TrackerDebugInfoStripped(_frameDebugInfo));
    return [NSString stringWithUTF8String:result.c_str()];
}
- (NSString*)videoDebugInfoString
{
    string result = ObjectTrackerDebugger::getDebugString(_videoDebugInfo);
    return [NSString stringWithUTF8String:result.c_str()];
}

#pragma mark - initialization

+ (id)instance
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (id)init
{
    self = [super init];
    if (self) {
        _objectImage = Mat();
        _tracker = new ObjectTracker();
        _videoDebugInfo = vector<TrackerDebugInfoStripped>();
        _stillImageTrackerQueue = dispatch_queue_create("ck.objecttracker.trackerlibrary.stillimage", DISPATCH_QUEUE_SERIAL);
        _recordDebugInfo = YES;
    }
    return self;
}

- (void)dealloc
{
    delete _tracker;
    _tracker = 0;
    
    dispatch_release(_stillImageTrackerQueue);
}

#pragma mark - object related methods

- (UIImage*)objectImage
{
    UIImage* image;
    NSError* error = NULL;
    image = [CVImageConverter UIImageFromCVMat:_objectImage error:&error];
    if (error != NULL) {
        [self showError:error];
    }
    return image;
}

- (UIImage*)objectHistogram
{
    UIImage* histogram;
//    NSError* error = NULL;
//    Mat hist = ObjectTrackerDebugger::getHistogramImage(_frameDebugInfo.objectHistogram);
//    histogram = [CVImageConverter UIImageFromCVMat:_objectImage error:&error];
//    if (error != NULL) {
//        [self showError:error];
//    }
    return histogram;
}

- (void)setObjectImageWithImage:(UIImage *)objectImage
{
    NSError* error = NULL;
    UIImage* test = objectImage;
    Mat test2;
    [CVImageConverter CVMat:test2 FromUIImage:test error:&error];
    if (error == NULL) {
        _tracker->setObject(test2);
    } else {
        [self showError:error];
    }
}

- (void)setObjectImageWithBuffer:(CVPixelBufferRef)objectImage
{
    NSError* error = NULL;
    [CVImageConverter CVMat:_objectImage FromCVPixelBuffer:objectImage error:&error];
    if (error == NULL) {
        _tracker->setObject(_objectImage);
    } else {
        [self showError:error];
    }
}

#pragma mark - parameter related methods

- (void)setBoolParameterWithName:(NSString*)name Value:(BOOL)value
{
    _tracker->getSettings().setBoolValue([name UTF8String], value);
}

- (void)setintParameterWithName:(NSString*)name Value:(int)value
{
    _tracker->getSettings().setIntValue([name UTF8String], value);
}

- (void)setFloatParameterWithName:(NSString*)name Value:(float)value
{
    _tracker->getSettings().setFloatValue([name UTF8String], value);
}

- (void)setStringParameterWithName:(NSString*)name Value:(NSString*)value
{
    _tracker->getSettings().setStringValue([name UTF8String], [value UTF8String]);
}

#pragma mark - tracking related methods

- (void)trackObjectInImageWithImage:(UIImage*)image
{
    __block UIImage* retainedImage = [image copy];
    dispatch_async(self.stillImageTrackerQueue, ^{
        Mat frame;
        NSError* error = NULL;
        [CVImageConverter CVMat:frame FromUIImage:retainedImage error:&error];
        if (error == NULL) {
            vector<TrackerOutput> output;
            vector<TrackerDebugInfo> debugInfo;
            _tracker->trackObjectInStillImage(frame, output, debugInfo);
            _frameDebugInfo = *(debugInfo.end() - 1);
            _output = *(output.end() - 1);
            [self handleTrackingInImageResult];
        } else {
            [self showError:error];
        }
    });
}

- (void)trackObjectInVideoWithImage:(UIImage*)image
{
    Mat frame;
    NSError* error = NULL;
    [CVImageConverter CVMat:frame FromUIImage:image error:&error];
    if (error == NULL) {
        TrackerOutput output = _output;
        TrackerDebugInfo debugInfo = _frameDebugInfo;
        _tracker->trackObjectInVideo(frame, output, debugInfo);
        _frameDebugInfo = debugInfo;
        _output = output;
        [self handleTrackingInVideoResult];
    } else {
        [self showError:error];
    }
}

- (void)trackObjectInVideoWithBuffer:(CVPixelBufferRef)buffer
{
    Mat frame;
    NSError* error = NULL;
    [CVImageConverter CVMat:frame FromCVPixelBuffer:buffer error:&error];
    if (error == NULL) {
        TrackerOutput output = _output;
        TrackerDebugInfo debugInfo = _frameDebugInfo;
        _tracker->trackObjectInVideo(frame, output, debugInfo);
        _frameDebugInfo = debugInfo;
        _output = output;
        [self handleTrackingInVideoResult];
    } else {
        [self showError:error];
    }
}

#pragma mark - debug methods

- (void)clearVideoDebugInfo
{
    _videoDebugInfo.clear();
}

- (BOOL)detectionDebugImage:(UIImage**)image WithSearchWindow:(BOOL)searchWindow
{
    Mat matrix;
    if (ObjectTrackerDebugger::getDetectionModuleDebugImage(matrix, _frameDebugInfo, searchWindow)) {
        NSError* error = NULL;
        *image = [CVImageConverter UIImageFromCVMat:matrix error:&error];
        if (error == NULL) {
            return YES;
        }
        [self showError:error];
    }
    return NO;
}

- (BOOL)validationDebugImage:(UIImage**)image WithObjectRect:(BOOL)objectRect ObjectKeyPoints:(BOOL)objectKeyPoints SceneKeyPoints:(BOOL)sceneKeyPoints FilteredMatches:(BOOL)filteredMatches AllMatches:(BOOL)allmatches
{
    Mat matrix;
    if (ObjectTrackerDebugger::getValidationModuleDebugImage(matrix, _frameDebugInfo, objectRect, objectKeyPoints, sceneKeyPoints, filteredMatches, allmatches)) {
        NSError* error = NULL;
        *image = [CVImageConverter UIImageFromCVMat:matrix error:&error];
        if (error == NULL) {
            return YES;
        }
        [self showError:error];
    }
    return NO;
}

- (BOOL)trackingDebugImage:(UIImage**)image WithObjectRect:(BOOL)objectRect FilteredPoints:(BOOL)filteredPoints AllPoints:(BOOL)allPoints SearchWindow:(BOOL)searchWindow
{
    Mat matrix;
    if (ObjectTrackerDebugger::getTrackingModuleDebugImage(matrix, _frameDebugInfo, objectRect, filteredPoints, allPoints, searchWindow)) {
        NSError* error = NULL;
        *image = [CVImageConverter UIImageFromCVMat:matrix error:&error];
        if (error == NULL) {
            return YES;
        }
        [self showError:error];
    }
    return NO;
}

#pragma mark - helper methods
     
- (void)handleTrackingInVideoResult
{
    if (self.recordDebugInfo) {
        _videoDebugInfo.push_back(TrackerDebugInfoStripped(_frameDebugInfo));
        if (_videoDebugInfo.size() >= MAX_RECORDED_FRAMES) {
            if ([self.delegate respondsToSelector:@selector(reachedDebugInfoRecordingLimit:)])
                [self.delegate reachedDebugInfoRecordingLimit:[self videoDebugInfoString]];
            _videoDebugInfo.clear();
        }
    }
    if (_output.isObjectPresent) {
        if ([self.delegate respondsToSelector:@selector(trackedObjectWithHomography:)]) {
            [self.delegate trackedObjectWithHomography:[self homography]];
        }
    }
    if ([self.delegate respondsToSelector:@selector(trackerLibraryDidProcessFrame)]) {
        [self.delegate trackerLibraryDidProcessFrame];
    }
}

- (void)handleTrackingInImageResult
{
    if (_output.isObjectPresent) {
        if ([self.delegate respondsToSelector:@selector(trackedObjectWithHomography:)]) {
            [self.delegate trackedObjectWithHomography:[self homography]];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(failedToTrackObjectInImage)]) {
            [self.delegate failedToTrackObjectInImage];
        }
    }
    if ([self.delegate respondsToSelector:@selector(trackerLibraryDidProcessFrame)]) {
        [self.delegate trackerLibraryDidProcessFrame];
    }
}

- (Homography)homographyWithMatrix:(Mat&)matrix
{
    Homography result;
    result.m00 = matrix.at<double>(0,0);
    result.m01 = matrix.at<double>(0,1);
    result.m02 = matrix.at<double>(0,2);
    result.m10 = matrix.at<double>(1,0);
    result.m11 = matrix.at<double>(1,1);
    result.m12 = matrix.at<double>(1,2);
    result.m20 = matrix.at<double>(2,0);
    result.m21 = matrix.at<double>(2,1);
    result.m22 = matrix.at<double>(2,2);
    return result;
}

- (void)showError:(NSError*)error
{
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:error.domain message:error.description delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    NSLog(@"\n%@\n%@", error.domain, error.description);
}

- (ObjectTrackerParameter*)boolParameterWithName:(string)name FromSettings:(Settings)settings
{
    bool critical;
    bool value;
    settings.getBoolValue(name, value);
    settings.getBoolInfo(name, critical);

    ObjectTrackerParameter* parameter = [[ObjectTrackerParameter alloc] init];
    [parameter setName:[NSString stringWithUTF8String:name.c_str()]];
    [parameter setType:ObjectTrackerParameterTypeBool];
    [parameter setBoolValue:value];
    [parameter setCritical:critical];
    return parameter;
}

- (ObjectTrackerParameter*)intParameterWithName:(string)name FromSettings:(Settings)settings
{
    bool critical;
    int value, min, max;
    vector<int> values;
    settings.getIntValue(name, value);
    settings.getIntInfo(name, min, max, values, critical);
    NSMutableArray* intValues = [NSMutableArray arrayWithCapacity:values.size()];
    for (int i = 0; i < values.size(); i++) {
        [intValues addObject:[NSNumber numberWithInt:values[i]]];
    }
    
    ObjectTrackerParameter* parameter = [[ObjectTrackerParameter alloc] init];
    [parameter setName:[NSString stringWithUTF8String:name.c_str()]];
    [parameter setType:ObjectTrackerParameterTypeInt];
    [parameter setIntValue:value];
    [parameter setIntMax:max];
    [parameter setIntMin:min];
    [parameter setIntValues:intValues];
    [parameter setCritical:critical];
    return parameter;
}

- (ObjectTrackerParameter*)floatParameterWithName:(string)name FromSettings:(Settings)settings
{
    bool critical;
    float value, min, max;
    settings.getFloatValue(name, value);
    settings.getFloatInfo(name, min, max, critical);

    ObjectTrackerParameter* parameter = [[ObjectTrackerParameter alloc] init];
    [parameter setName:[NSString stringWithUTF8String:name.c_str()]];
    [parameter setType:ObjectTrackerParameterTypeFloat];
    [parameter setFloatValue:value];
    [parameter setFloatMax:max];
    [parameter setFloatMin:min];
    [parameter setCritical:critical];
    return parameter;
}

- (ObjectTrackerParameter*)stringParameterWithName:(string)name FromSettings:(Settings)settings
{
    bool critical;
    string value;
    vector<string> values;
    settings.getStringValue(name, value);
    settings.getStringInfo(name, values, critical);
    NSMutableArray* stringValues = [NSMutableArray arrayWithCapacity:values.size()];
    for (int i = 0; i < values.size(); i++) {
        [stringValues addObject:[NSString stringWithUTF8String:values[i].c_str()]];
    }
    
    ObjectTrackerParameter* parameter = [[ObjectTrackerParameter alloc] init];
    [parameter setName:[NSString stringWithUTF8String:name.c_str()]];
    [parameter setType:ObjectTrackerParameterTypeString];
    [parameter setStringValue:[NSString stringWithUTF8String:value.c_str()]];
    [parameter setStringValues:stringValues];
    [parameter setCritical:critical];
    return parameter;
}

- (ObjectTrackerParameter*)parameterWithName:(string)name FromSettings:(Settings)settings
{
    ObjectTrackerParameter* parameter = nil;
    Type type; settings.getParameterType(name, type);
    switch (type) {
        case ck::CK_TYPE_BOOL:
            parameter = [self boolParameterWithName:name FromSettings:settings];
            break;
        case ck::CK_TYPE_INT:
            parameter = [self intParameterWithName:name FromSettings:settings];
            break;
        case ck::CK_TYPE_FLOAT:
            parameter = [self floatParameterWithName:name FromSettings:settings];
            break;
        case ck::CK_TYPE_STRING:
            parameter = [self stringParameterWithName:name FromSettings:settings];
            break;
    }
    return parameter;
}

- (ObjectTrackerParameterCollection*) parameterCollectionFromSettings:(Settings)settings
{
    vector<string> parameterNames = settings.getParameterNames();
    NSMutableArray* parameters = [NSMutableArray arrayWithCapacity:parameterNames.size()];
    for (int i = 0; i < parameterNames.size(); i++) {
        [parameters addObject:[self parameterWithName:parameterNames[i] FromSettings:settings]];
    }
    
    vector<Settings> subCategories = settings.getSubCategories();
    NSMutableArray* subCollections = [NSMutableArray arrayWithCapacity:subCategories.size()];
    for (int i = 0; i < subCategories.size(); i++) {
        [subCollections addObject:[self parameterCollectionFromSettings:subCategories[i]]];
    }
    
    ObjectTrackerParameterCollection* collection = [[ObjectTrackerParameterCollection alloc] init];
    [collection setName:[NSString stringWithUTF8String:settings.getName().c_str()]];
    [collection setSubCollections:subCollections];
    [collection setParameters:parameters];
    return collection;
}

@end
