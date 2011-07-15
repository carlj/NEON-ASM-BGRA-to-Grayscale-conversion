//
//  NEON_ASMAppDelegate.h
//  NEON ASM
//
//  Created by Carl Jahn on 15.07.11.
//  Copyright 2011 Hochschule RheinMain. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NEON_ASMViewController;

@interface NEON_ASMAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    NEON_ASMViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet NEON_ASMViewController *viewController;

@end

