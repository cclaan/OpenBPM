//
//  AurioHelper.h
//  BeatMatchTests
//
//  Created by Chris Laan on 8/17/10.
//  Copyright 2010 Laan Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AurioHelper : NSObject {
	
}

//static void SetupRemoteIO();

+(void) SetupRemoteIO:(AudioUnit)rioUnit;

@end
