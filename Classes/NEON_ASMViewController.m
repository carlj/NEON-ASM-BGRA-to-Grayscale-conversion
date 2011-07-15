//
//  NEON_ASMViewController.m
//  NEON ASM
//
//  Created by Carl Jahn on 15.07.11.
//  Copyright 2011 Hochschule RheinMain. All rights reserved.
//

NSInteger fps = 0;

#import "NEON_ASMViewController.h"

@implementation NEON_ASMViewController


@synthesize captureSession = _captureSession;
@synthesize imageView = _imageView;
@synthesize prevLayer = _prevLayer;
@synthesize fpsLabel = _fpsLabel; 

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
		
	[self initCapture];
}

- (void)calc
{
	NSLog(@"fps: %i", fps);
	fps = 0;
}

- (void)initCapture {
	
	//[NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(calc) userInfo:nil repeats:YES];
	
	/*We setup the input*/
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput 
										  deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] 
										  error:nil];
	/*We setupt the output*/
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	/*While a frame is processes in -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
	 If you don't want this behaviour set the property to NO */
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
	/*We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
	 in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
	 In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
	 we are not able to process more than 10 frames per second.*/
	//captureOutput.minFrameDuration = CMTimeMake(1, 10);
	
	/*We create a serial queue to handle the processing of our frames*/
	dispatch_queue_t queue;
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	
	
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings]; 
	/*And we create a capture session*/
	self.captureSession = [[AVCaptureSession alloc] init];
	self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
	/*We add input and output*/
	[self.captureSession addInput:captureInput];
	[self.captureSession addOutput:captureOutput];
	
	
	self.prevLayer = [AVCaptureVideoPreviewLayer layerWithSession: self.captureSession];
	
	CGRect bounds = [UIScreen mainScreen].bounds;
	self.prevLayer.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
	self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	[self.view.layer addSublayer: self.prevLayer];
	
	/*We add the imageView*/
	
	self.imageView = [[UIImageView alloc] init];
	self.imageView.frame = CGRectMake(0, 0, 180, 240);
	self.imageView.backgroundColor = [UIColor blackColor];
	[self.view addSubview:self.imageView];
		
	
	/* Add the fps Label */
	UILabel *fps = [[UILabel alloc] initWithFrame:CGRectMake(bounds.size.width - 100, 0, 100, 20)];
	self.fpsLabel = fps;
	[self.view addSubview:self.fpsLabel];
	[self.view bringSubviewToFront:self.fpsLabel];
	[fps release];
	
	
	/*We start the capture*/
	[self.captureSession startRunning];
	
}

#include <arm_neon.h>
void neon_convert(uint8_t * __restrict dest, uint8_t * __restrict src, int numPixels)
{
	int i;
	uint8x8_t rfac = vdup_n_u8 (77);
	uint8x8_t gfac = vdup_n_u8 (151);
	uint8x8_t bfac = vdup_n_u8 (28);
	int n = numPixels / 8;
	
	// Convert per eight pixels
	for (i=0; i < n; ++i)
	{
		uint16x8_t  temp;
		uint8x8x4_t rgb  = vld4_u8 (src);
		uint8x8_t result;
		
		temp = vmull_u8 (rgb.val[0],      bfac);
		temp = vmlal_u8 (temp,rgb.val[1], gfac);
		temp = vmlal_u8 (temp,rgb.val[2], rfac);
		
		result = vshrn_n_u16 (temp, 8);
		vst1_u8 (dest, result);
		src  += 8*4;
		dest += 8;
	}
}

static void neon_asm_convert(uint8_t * __restrict dest, uint8_t * __restrict src, int numPixels)
{
	__asm__ volatile("lsr          %2, %2, #3      \n"
					 "# build the three constants: \n"
					 "mov         r4, #28          \n" // Blue channel multiplier
					 "mov         r5, #151         \n" // Green channel multiplier
					 "mov         r6, #77          \n" // Red channel multiplier
					 "vdup.8      d4, r4           \n"
					 "vdup.8      d5, r5           \n"
					 "vdup.8      d6, r6           \n"
					 "0:						   \n"
					 "# load 8 pixels:             \n"
					 "vld4.8      {d0-d3}, [%1]!   \n"
					 "# do the weight average:     \n"
					 "vmull.u8    q7, d0, d4       \n"
					 "vmlal.u8    q7, d1, d5       \n"
					 "vmlal.u8    q7, d2, d6       \n"
					 "# shift and store:           \n"
					 "vshrn.u16   d7, q7, #8       \n" // Divide q3 by 256 and store in the d7
					 "vst1.8      {d7}, [%0]!      \n"
					 "subs        %2, %2, #1       \n" // Decrement iteration count
					 "bne         0b            \n" // Repeat unil iteration count is not zero
					 :
					 : "r"(dest), "r"(src), "r"(numPixels)
					 : "r4", "r5", "r6"
					 );
}


#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{ 

	// Calculate FPS
	fpsAverageAgingFactor = 0.2;
	framesInSecond++;
	endTime = [[NSDate date] timeIntervalSince1970];
	
	if (startTime <= 0) {
		startTime = [[NSDate date] timeIntervalSince1970];
	}
	else {
		if (endTime - startTime >= 1) {
			double currentFPS = framesInSecond / (endTime - startTime);
			fpsAverage = fpsAverageAgingFactor * fpsAverage + (1.0 - fpsAverageAgingFactor) * currentFPS;
			startTime = [[NSDate date] timeIntervalSince1970];
			framesInSecond = 0;
		}
		
		[self.fpsLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"FPS: %.2f", fpsAverage] waitUntilDone:NO];
	}
	
	/*We create an autorelease pool because as we are not in the main_queue our code is
	 not executed in the main thread. So we have to create an autorelease pool for the thread we are in*/
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);  
    	
	//create memory
	uint8_t* baseAddressGray = (uint8_t*) malloc(width*height);
	
	//convert 
	neon_asm_convert(baseAddressGray, baseAddress, width*height); // 1 ms
	//neon_convert(baseAddressGray, baseAddress, width*height); // 16 ms

	
	//from gray conversion to cgcontext
	CGColorSpaceRef colorSpaceGray = CGColorSpaceCreateDeviceGray();
	CGContextRef newContextGray = CGBitmapContextCreate(baseAddressGray, width, height, 8, width, colorSpaceGray, kCGImageAlphaNone);
	
	//Create CgImageRef from cgcontext
	CGImageRef GrayImage = CGBitmapContextCreateImage(newContextGray);
	
	//convert to uiimage
	UIImage *img= [UIImage imageWithCGImage:GrayImage scale:1.0 orientation:UIImageOrientationRight];
	[self.imageView performSelectorOnMainThread:@selector(setImage:) withObject:img waitUntilDone:NO];
	
	//save in photostream
	//UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
	
	//release the source
	free(baseAddressGray);
	CGColorSpaceRelease(colorSpaceGray);
	CGContextRelease(newContextGray);

	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	[pool drain];
	
	fps += 1;
} 

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[_captureSession release];
	[_imageView release];
	[_prevLayer release];
	[_fpsLabel release];
    [super dealloc];
}

@end
