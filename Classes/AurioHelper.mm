//
//  AurioHelper.m
//  BeatMatchTests
//
//  Created by Chris Laan on 8/17/10.
//  Copyright 2010 Laan Labs. All rights reserved.
//

#import "AurioHelper.h"
#import "CAStreamBasicDescription.h"

@implementation AurioHelper

+(void) SetupRemoteIO:(AudioUnit)rioUnit {
	
	
	CAStreamBasicDescription outFormat;
	
	// set our required format - Canonical AU format: LPCM non-interleaved 8.24 fixed point
	outFormat.SetAUCanonical(2, false);
	
	AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outFormat, sizeof(outFormat));
	AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &outFormat, sizeof(outFormat));
	
	
	
	NSLog(@"OK SETUP!!");
	
}


@end
