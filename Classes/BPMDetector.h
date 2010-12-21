//
//  BPMDetector.h
//  RealDJ
//
//  Created by Chris Laan on 8/11/10.
//  Copyright 2010 Laan Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FFTBufferManager.h"

//@class FFTBufferManager;

typedef struct BeatValues {
	float bassValue;
	float trebleValue;
} BeatValues ;

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




@interface BPMDetector : NSObject {
	
	
	// FFT
	int bufSize;
	int chunkSize;
	int32_t * l_fftData;
	SInt32 * fftData;
	
	int fftLength;
	
	BOOL hasNewFFTData;
	
	// conversion
	
	SInt32 * samples32;
	
	FFTBufferManager * fftBufferManager;
	
	// Beat...
	
	float * bassBuffer;
	float * trebleBuffer;
	int beatBufferSize;
	
	DetectedBeat * detectedBeats;
	int numBeats;
	Float64 currentBPMSearchWindowStartIndex;
	Float64 currentBPMSearchWindowEndIndex;
	
	int numBeatsInWindow;
	DetectedBeat ** detectedBeatsInWindow;
	
	UInt64 numSongSamples;
	
}

@property int numBeats;
@property DetectedBeat * detectedBeats;

- (id) initWithSize:(int) bSize;

- (id) initWithSongLength:(UInt64) songLen;
- (void) addSamplesAndDetect:(SInt16*)sampleBuffer numFrames:(int)numSliceSamples atSongOffset:(int)sliceStartOffset;


-(void) detectAtPath:(NSString*)path;

-(void) detectInSamples32:(SInt32*) samples numFrames:(int) num;
-(void) detectInSamples16:(SInt16*) samples numFrames:(int) num;

-(BeatValues) detectBeatValues:(SInt16*) samples numFrames:(int) num;


@end
