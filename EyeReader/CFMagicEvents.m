//  CFMagicEvents.m
//  Copyright (c) 2013 Cédric Floury
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  1. The above copyright notice and this permission notice shall be included
//     in all copies or substantial portions of the Software.
//
//  2. This Software cannot be used to archive or collect data such as (but not
//     limited to) that of events, news, experiences and activities, for the
//     purpose of any concept relating to diary/journal keeping.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "CFMagicEvents.h"
#import <AVFoundation/AVFoundation.h>


#define NUMBER_OF_FRAME_PER_S 5
#define BRIGHTNESS_THRESHOLD 70
#define MIN_BRIGHTNESS_THRESHOLD 10

@interface CFMagicEvents() <AVCaptureAudioDataOutputSampleBufferDelegate>
{
    AVCaptureSession *_captureSession;
    int tempArray[27648];
    int firstArray[144][192];
    int secondArray[144][192];
    int differenceOf2ndComparedTo1stArray[144][192];
    int tallyOfPositiveDeltaBlinksArray[144][192];
    int highestDifference;
    int lowestDifference;
    BOOL blinkTestIsOn;
    int totalPicturesProcessed;
    int blinkTestCount;
    NSString* lastSavedDelta;
    
    NSMutableArray* aMArray;
    int  _lastTotalBrightnessValue;
    int lastTotalBrightness2;
    int _brightnessThreshold;
    BOOL _started;
    BOOL setFirstArray;
    BOOL setSecondArray;
}
@end

@implementation CFMagicEvents

#pragma mark - init

- (id)init
{
    if ((self = [super init])) { [self initMagicEvents];}
    aMArray = [[NSMutableArray alloc]init];
    setFirstArray = NO;
    setSecondArray = NO;
    highestDifference = 0;
    lowestDifference = 0;
    lastSavedDelta = @"";
    blinkTestIsOn = NO;
    blinkTestCount = 0;
    totalPicturesProcessed = 0;
    return self;
}

- (void)initMagicEvents
{
    _started = NO;
    _brightnessThreshold = BRIGHTNESS_THRESHOLD;
    
    [NSThread detachNewThreadSelector:@selector(initCapture) toTarget:self withObject:nil];
}

- (void)initCapture {
    
    
    NSError *error = nil;
    
    AVCaptureDevice *captureDevice = [self searchForBackCameraIfAvailable];
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if ( ! videoInput)
    {
   //     NSLog(@"Could not get video input: %@", error);
        return;
    }
    
    
    //  the capture session is where all of the inputs and outputs tie together.
    
    _captureSession = [[AVCaptureSession alloc] init];
    
    //  sessionPreset governs the quality of the capture. we don't need high-resolution images,
    //  so we'll set the session preset to low quality.
    
    _captureSession.sessionPreset = AVCaptureSessionPresetLow;
    
    [_captureSession addInput:videoInput];
    
    //  create the thing which captures the output
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    //  pixel buffer format
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                              kCVPixelBufferPixelFormatTypeKey, nil];
    videoDataOutput.videoSettings = settings;
    
  //  AVCaptureConnection *conn = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    

    //  we need a serial queue for the video capture delegate callback
    dispatch_queue_t queue = dispatch_queue_create("com.zuckerbreizh.cf", NULL);
    
    [videoDataOutput setSampleBufferDelegate:(id)self queue:queue];
    [_captureSession addOutput:videoDataOutput];
    
    
    [_captureSession startRunning];
    _started = YES;
    
    
}

-(int)getTotalBrightness{
    return  _lastTotalBrightnessValue;
}

-(void)updateBrightnessThreshold:(int)pValue
{
    _brightnessThreshold = pValue;
}

-(BOOL)startCapture
{
    if(!_started){
        _lastTotalBrightnessValue = 0;
        [_captureSession startRunning];
        _started = YES;
    }
    return _started;
}

-(BOOL)stopCapture
{
    if(_started){
        [_captureSession stopRunning];
        _started = NO;
    }
    return _started;
}


-(void)setFirstArray{
    highestDifference = 0;
    lowestDifference = 0;
    setFirstArray = YES;
}

-(void)setSecondArray{
   // NSLog(@"dde");
    setSecondArray = YES;
}


-(void)turnOnBlinkTest{
    blinkTestIsOn = YES;
    blinkTestCount = 0;
    
    // reset the tallyArray.
    for (int rowCount = 0; rowCount<144; rowCount++){
        for (int columnCount = 0 ; columnCount<192; columnCount++){
            tallyOfPositiveDeltaBlinksArray[rowCount][columnCount] =  0;
        }
    }
}



-(NSString*)getLastDelta{
    return lastSavedDelta;
}

-(UIImage*)getDeltaUIImage{
    const int width = 192  , height = 144;
    const int area = width * height;
    // This array will be put into a UIImage.
    unsigned char *pixelData = (unsigned char*)malloc(area * 4);
    // Lets load the array.
    int offset = 0;
 
    for (int rowCount = 0; rowCount<height; rowCount++){// Loop through each row.
        for (int columnCount = 0 ; columnCount<width*4; columnCount = columnCount+4){

            // I suppose the int in the differenceArray could be anywhere from -256 to +255, 0 meaning no change.
            
            // For the afterpic, let's have white (255) mean the square just got brighter, and pitch black (0) means it just got darker. Lets have grey (128) mean that the square didn't change at all since last time.
                                // Divide by 3 to average the 3 rgb sums back to a 0-255 num.
            int diffHolder = differenceOf2ndComparedTo1stArray[rowCount][columnCount/4]/3;

            
            // If the square got brighter.
         //   Start it at 128 because grey is neutral
                int zeroTo255 = 128+diffHolder/2;
                pixelData[offset] =  zeroTo255;
                pixelData[offset + 1] = zeroTo255;
                pixelData[offset + 2] = zeroTo255;
                pixelData[offset+3] = 255;
            offset = offset+4;
        }
    }

    // Done.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef gtx = CGBitmapContextCreate(pixelData, width, height, 8, width*4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGImageRef toCGImage = CGBitmapContextCreateImage(gtx);
    return [[UIImage alloc] initWithCGImage:toCGImage];
}

-(UIImage*)getBlinkTallyUIImage{
    const int width = 192  , height = 144;
    const int area = width * height;
    // This array will be put into a UIImage.
    unsigned char *pixelData = (unsigned char*)malloc(area * 4);
    // Lets load the array.
    int offset = 0;
    
    for (int rowCount = 0; rowCount<height; rowCount++){// Loop through each row.
        for (int columnCount = 0 ; columnCount<width*4; columnCount = columnCount+4){

            int talliedPosDiffHolder = tallyOfPositiveDeltaBlinksArray[rowCount][columnCount/4];
            // This int could be from 0 to (255*20 frames analyzed) 5100
            // We will divide by 20 because thats the ratio of 5100 / 256
            int zeroTo255 = talliedPosDiffHolder;
      //      NSLog(@"this zero to 255 is %d" , zeroTo255);
            pixelData[offset] =  zeroTo255;
            pixelData[offset + 1] = zeroTo255;
            pixelData[offset + 2] = zeroTo255;
            pixelData[offset+3] = 255;
            offset = offset+4;
        }
    }
    
    // Done.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef gtx = CGBitmapContextCreate(pixelData, width, height, 8, width*4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGImageRef toCGImage = CGBitmapContextCreateImage(gtx);
    return [[UIImage alloc] initWithCGImage:toCGImage];
}

#pragma mark - Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef cVIBR = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(cVIBR, 0) == kCVReturnSuccess){ // If locking in on this pixel buffer was a success.
        // A UInt8 is an 8-bit unsigned integer (basically like a char). I think this byte holds the "red value" of the very firss pixel. It's address is the very 1st address in a long array of bytes. No seperation into rows or anything. We are on our own to sift through this.
        UInt8 *EightBitUnsignedInt = (UInt8 *)CVPixelBufferGetBaseAddress(cVIBR);
        size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(cVIBR); // Which is 768 for iphone 4s.
        
        UInt32 totalBrightness  = 0; // Lets start with 0 brightness, and add it up as we go.
        
        int totalRows = 144;
        int totalCount = 0;
        int totalColumns = 768;// Theres only 192 squares, but with 4 values each
        
        // If this our 1st photo weve ever seen, lets add it to the firstArray, so we wont crash when we try to compare 2 pics.
        if(totalPicturesProcessed == 0){
            for (int rowCount = 0; rowCount<totalRows; rowCount++){// Loop through each row.
                for (int columnCount = 0 ; columnCount<totalColumns; columnCount = columnCount+4){
                    // Add the 3 rgb values.
                    UInt32 value = EightBitUnsignedInt[rowCount*totalColumns+columnCount];
                    value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+1] + value;
                    value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+2] + value;
                    firstArray[rowCount][columnCount/4] = (int)value;
                }
            }
        }
        
        // Then, no matter what we load up this current pic into our "secondArray", which represents our current pic.
        for (int rowCount = 0; rowCount<totalRows; rowCount++){// Loop through each row.
            for (int columnCount = 0 ; columnCount<totalColumns; columnCount = columnCount+4){
                // Add the 3 rgb values.
                UInt32 value = EightBitUnsignedInt[rowCount*totalColumns+columnCount];
                value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+1] + value;
                value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+2] + value;
                secondArray[rowCount][columnCount/4] = (int)value;
            }
        }

        // Then, for now, I'm going to load up the difference array no matter what, Im using it for now.
        [self loadDifferenceArray];
        
        // THese next two methods are just for that initial testing I did.
        // The following for loop cycles through each square.
        if(setFirstArray){
            setFirstArray = NO;
            for (int rowCount = 0; rowCount<totalRows; rowCount++){// Loop through each row.
                for (int columnCount = 0 ; columnCount<totalColumns; columnCount = columnCount+4){
                    // Add the 3 rgb values.
                    UInt32 value = EightBitUnsignedInt[rowCount*totalColumns+columnCount];
                    value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+1] + value;
                    value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+2] + value;
                    firstArray[rowCount][columnCount/4] = (int)value;
                }
            }
            
        }
        // The following for loop cycles through each square.
        if(setSecondArray){
          //  NSLog(@"rrd");
            setSecondArray = NO;
            for (int rowCount = 0; rowCount<totalRows; rowCount++){// Loop through each row.
                for (int columnCount = 0 ; columnCount<totalColumns; columnCount = columnCount+4){
                    // Add the 3 rgb values.
                    UInt32 value = EightBitUnsignedInt[rowCount*totalColumns+columnCount];
                    value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+1] + value;
                    value = EightBitUnsignedInt[rowCount*totalColumns+columnCount+2] + value;
                    secondArray[rowCount][columnCount/4] = (int)value;
                }
            }
        }
        
        // For each pic, we see if the user wants to perform a blink test.
        if(blinkTestIsOn && totalPicturesProcessed%6==0){
            if(blinkTestCount<10){
                // Lets check the delta of every pixel in our previously set differenceArray, and add it to the tallyArray if positive.
                for (int rowCount = 0; rowCount<totalRows; rowCount++){// Loop through each row.
                    for (int columnCount = 0 ; columnCount<totalColumns; columnCount++){

                        
                        // Im constantly checking the differenceArray, and adding to the tally if it's positive, I have to keep updating the dArray thow.
                        // Divide by 3 because all these arrays hold values from 0 to 760ish..... -760ish to +760ish if its a difference array.
                        int neg256ToPos255 = differenceOf2ndComparedTo1stArray[rowCount][columnCount]/3;
                        if(neg256ToPos255>0){
                            // Add whatever brightness increase we see in this current pixel to this current pixel.
                            tallyOfPositiveDeltaBlinksArray[rowCount][columnCount] = neg256ToPos255 + tallyOfPositiveDeltaBlinksArray[rowCount][columnCount];
                        }
                        // And lets add the negation of the negative to our totalPositives also, for now.
                        else{
                            tallyOfPositiveDeltaBlinksArray[rowCount][columnCount] =  tallyOfPositiveDeltaBlinksArray[rowCount][columnCount]-neg256ToPos255 ;
                        }
                    }
                }
                // Done adding the pixels from THIS picture frame, we probably will be called again until blinkTestIsOn == NO;
            }
            else{
                blinkTestIsOn = NO;
                
                
                // 1) There are 2 smudges in the pic that have a combined total brightness larger than the rest of the pic. Locate their frames.
                
                
                
            }
            blinkTestCount++;
        }
        
        // We always end up putting this pic into the "firstArray" so the next iteration has something to compare with.
        for (int rowCount = 0; rowCount<totalRows; rowCount++){// Loop through each row.
            for (int columnCount = 0 ; columnCount<totalColumns; columnCount++){
                firstArray[rowCount][columnCount] = secondArray[rowCount][columnCount];
            }
        }
        totalPicturesProcessed++; // And finish analyzing this photo, by adding 1 to this.
        
        
        
        
        
        
        
        
        _lastTotalBrightnessValue = totalBrightness;
      //  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        if(_lastTotalBrightnessValue==0) _lastTotalBrightnessValue = totalBrightness;
        if([self calculateLevelOfBrightness:totalBrightness]<_brightnessThreshold)
        {
            if([self calculateLevelOfBrightness:totalBrightness]>MIN_BRIGHTNESS_THRESHOLD)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"onMagicEventDetected" object:nil];
            }
            else //Mobile phone is probably on a table (too dark - camera obturated)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"onMagicEventNotDetected" object:nil];
            }
            //NSLog(@"%d",[self calculateLevelOfBrightness:totalBrightness]);
        }
        else{
            _lastTotalBrightnessValue = totalBrightness;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"onMagicEventNotDetected" object:nil];
        }
    }
}

-(void)loadDifferenceArray{
    for(int rowCount = 0 ; rowCount< 144 ; rowCount++){
        for(int colCount = 0 ; colCount<192 ; colCount++){
            differenceOf2ndComparedTo1stArray[rowCount][colCount] = secondArray[rowCount][colCount] - firstArray[rowCount][colCount];
            if(highestDifference < differenceOf2ndComparedTo1stArray[rowCount][colCount] ){
                highestDifference = differenceOf2ndComparedTo1stArray[rowCount][colCount];
            }
            if(lowestDifference > differenceOf2ndComparedTo1stArray[rowCount][colCount]){
                lowestDifference = differenceOf2ndComparedTo1stArray[rowCount][colCount];
            }
          //  NSLog(@"Row %d Col %d difference is %d" ,rowCount,colCount,differenceOf2ndComparedTo1stArray[rowCount][colCount]);
        }
    }

 //   lastSavedDelta = [NSString stringWithFormat:(@"lowest %d highest %d"),lowestDifference,highestDifference];
}

-(int*)getArray{
    return tempArray;
}


-(int) calculateLevelOfBrightness:(int) pCurrentBrightness
{
    return (pCurrentBrightness*100) /_lastTotalBrightnessValue;
}



#pragma mark - Tools
- (AVCaptureDevice *)searchForBackCameraIfAvailable
{
    //  look at all the video devices and get the first one that's on the front
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice = nil;
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionFront)
        {
            captureDevice = device;
            break;
        }
    }
    
    //  couldn't find one on the front, so just get the default video device.
    if ( ! captureDevice)
    {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    return captureDevice;
}
@end