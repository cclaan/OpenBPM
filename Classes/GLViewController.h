//
//  GLViewController.h
//  BeatMatchTests
//
//  Created by Chris Laan on 8/17/10.
//  Copyright Laan Labs 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GLView.h"
#import "Texture2D.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

#import "ConstantsAndMacros.h"
#import "OpenGLCommon.h"

#import "BPMDetector.h"

/*
typedef struct DetectedBeat {
	
	uint64_t songSampleIndex;
	float strength;
	BOOL active;
	Float64 distance;
	float BPM;
} DetectedBeat;

typedef struct BeatPair {
	DetectedBeat beat1;
	DetectedBeat beat2;
	Float64 distance;
	float totalError;
	float BPM;
} BeatPair;
*/

@interface GLViewController : UIViewController <GLViewDelegate>
{
	
	AVAudioPlayer * player;
	
	int texHeight, texWidth;
	
	Texture2D * waveTexture;
	
	uint8_t * texPixels;
	
	SInt16 * sampleBuffer;
	
	/*
	float * bassBuffer;
	float * trebleBuffer;
	int beatBufferSize;
	
	DetectedBeat * detectedBeats;
	int numBeats;
	Float64 currentBPMSearchWindowStartIndex;
	Float64 currentBPMSearchWindowEndIndex;
	
	int numBeatsInWindow;
	DetectedBeat ** detectedBeatsInWindow;
	*/
	BPMDetector * bpmDetector;
	
	UInt64 numSongSamples;
	
	UInt64 startingIndex;
	UInt64 endingIndex;

	Float64 playPointer;
	Float64 playSpeed;
	
	AURenderCallbackStruct inputProc;
	AudioUnit rioUnit;
	
	BOOL follow;
	
	
}

@end
