//
//  main.m
//  NEON ASM
//
//  Created by Carl Jahn on 15.07.11.
//  Copyright 2011 Hochschule RheinMain. All rights reserved.
//

#import <UIKit/UIKit.h>

int main(int argc, char *argv[]) {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [pool release];
    return retVal;
}
