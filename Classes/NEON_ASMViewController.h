//
//  NEON_ASMViewController.h
//  NEON ASM
//
//  Created by Carl Jahn on 15.07.11.
//  Copyright 2011 Hochschule RheinMain. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@interface NEON_ASMViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate> {
	AVCaptureSession *_captureSession;
	UIImageView *_imageView;
	AVCaptureVideoPreviewLayer *_prevLayer;
}

@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *prevLayer;

- (void)initCapture;

@end

