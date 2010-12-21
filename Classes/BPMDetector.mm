//
//  BPMDetector.mm
//  RealDJ
//
//  Created by Chris Laan on 8/11/10.
//  Copyright 2010 Laan Labs. All rights reserved.
//

#import "BPMDetector.h"


#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>




#define BUFF_SIZE           2048

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif


@interface BPMDetector()

-(float) getErrorInSongFromBeats:(DetectedBeat*) b1 andBeat2:(DetectedBeat*) b2;
-(void) activateBeatsFromBestPair:(DetectedBeat*) b1 andBeat2:(DetectedBeat*) b2;

@end


@implementation BPMDetector

@synthesize numBeats , detectedBeats;

// TODO: will break with 2 records...
//static FFTBufferManager * fftBufferManager;
//static FFTBufferManager * fftBufferManagers[2];

- (id) initWithSongLength:(UInt64) songLen
{
	self = [super init];
	if (self != nil) {
		
		numSongSamples = songLen;
		
		chunkSize = 512;
		bufSize = 4096; // samples.. not bytes
		
		samples32 = nil;
		
		/*
		int sliceStartOffset = 0;
		int sliceSize = 44100 * 5;
		int numSliceSamples = sliceSize;
		int offset = 0;
		*/
		
		//int maxFPS = bSize / (sizeof(int32_t));
		//int maxFPS = bufSize;
		
		fftBufferManager = new FFTBufferManager(bufSize);
		
		//fftBufferManagers[0] = new FFTBufferManager(bufSize);
		//fftBufferManagers[1] = new FFTBufferManager(bufSize);
		
		l_fftData = new int32_t[bufSize/2];
		
		
		
	}
	return self;
}

- (id) initWithSize:(int) bSize
{
	self = [super init];
	if (self != nil) {
		
		//int maxFPS = bSize / (sizeof(int32_t));
		int maxFPS = bSize;
		
		fftBufferManager = new FFTBufferManager(maxFPS);
		
		l_fftData = new int32_t[maxFPS/2];
		
		
		
	}
	return self;
}

-(void) clearBeatData {
	
	free(detectedBeats);
	detectedBeats = nil;
	numBeats = 0;
	
	free(bassBuffer);
	bassBuffer = nil;
	
	free(trebleBuffer);
	trebleBuffer = nil;
	
	beatBufferSize = 0;
	
	numSongSamples = 0;
	
}


-(void) addSamplesAndDetect:(SInt16*)sampleBuffer numFrames:(int)numSliceSamples atSongOffset:(int)sliceStartOffset {

	
	//int sliceStartOffset = 0;
	
	int sliceSize = numSliceSamples;//44100 * 5;
	
	//int numSliceSamples = sliceSize;
	
	int offset = 0;
	
	//while (1) {
		
		numSliceSamples = CLAMP(0, sliceSize, (numSongSamples-sliceStartOffset));
		
		//NSLog(@"\n\n starting loop.. num slice: %i , offset: %i ", numSliceSamples , sliceStartOffset );
		
		if ( !bassBuffer ) {
			beatBufferSize = numSliceSamples / chunkSize;
			bassBuffer = (float*)malloc( beatBufferSize * sizeof(float) );
			trebleBuffer = (float*)malloc( beatBufferSize * sizeof(float) );
		}
		
		memset(bassBuffer,0,beatBufferSize * sizeof(float));
		
		offset = 0;//sliceStartOffset;
		
		for (int i = 0; i < (numSliceSamples/chunkSize); i++) {
			
			BeatValues b = [self detectBeatValues:(sampleBuffer+offset) numFrames:bufSize];
			offset += chunkSize;
			
			bassBuffer[i] = b.bassValue;
			trebleBuffer[i] = b.trebleValue;
			
		}
		
		if ( !detectedBeats ) {
			
			detectedBeats = (DetectedBeat*)malloc( 4*beatBufferSize * sizeof(DetectedBeat) );
			memset(detectedBeats,0, 4*beatBufferSize * sizeof(DetectedBeat) );
			numBeats = 0;
			
		}
		
		
		// a simple peak detection from the FFT data...
		// this also uses a threshold, which should be replaced with a local energy-based method like that student's paper
		// this just gives a bunch of points that could be beats, having too many is probably good
		
		// it also misses beats that are right on the edge of a buffer...
		// i guess i have to process windows here too
		
		for (int i = 6; i < beatBufferSize-6; i++) {
			
			int index = i;
			int indexGlobal = (sliceStartOffset/chunkSize) + i;
			
			float bval = bassBuffer[index];
			
			float bvalL = bassBuffer[index-1];
			float bvalR = bassBuffer[index+1];
			
			float bvalL2 = bassBuffer[index-2];
			float bvalR2 = bassBuffer[index+2];
			
			float bvalL3 = bassBuffer[index-3];
			float bvalR3 = bassBuffer[index+3];
			
			float bvalL4 = bassBuffer[index-4];
			float bvalR4 = bassBuffer[index+4];
			
			float bvalL5 = bassBuffer[index-5];
			float bvalR5 = bassBuffer[index+5];
			
			float bvalL6 = bassBuffer[index-6];
			float bvalR6 = bassBuffer[index+6];
			
			if ( bval > 0.6 ) {
				
				if (   (bval > bvalR)  && (bval > bvalL) 
					&& (bval > bvalR2) && (bval > bvalL2) 
					&& (bval > bvalR3) && (bval > bvalL3)   
					&& (bval > bvalR4) && (bval > bvalL4)
					&& (bval > bvalR5) && (bval > bvalL5)
					&& (bval > bvalR6) && (bval > bvalL6) 
					) {
					
					// TODO: this is a super simplified guess of where the peak is... 
					// need some greater guessing about its exact location... may not matter though
					
					detectedBeats[numBeats].songSampleIndex = (indexGlobal*chunkSize + (bufSize/2));
					
					numBeats++;
					
				}
				
			}
			
			
		}
		
		
		int currentWindowStart = sliceStartOffset;
		int windowSize = numSliceSamples;//44100 * 10;
		int windowIncrement = windowSize;// - (windowSize/10); // a little overlap
		
		while (1) {
			
			currentBPMSearchWindowStartIndex = currentWindowStart;
			currentBPMSearchWindowEndIndex = CLAMP(0, currentBPMSearchWindowStartIndex + windowSize , ((sliceStartOffset+numSliceSamples)-1) );
			
			[self estimateBPM];
			
			if ( currentBPMSearchWindowEndIndex >= ((sliceStartOffset+numSliceSamples)-1) ) {
				//NSLog(@"finished");
				break;
			}
			
			currentWindowStart += windowIncrement;
			
		}
		
		
		sliceStartOffset += numSliceSamples;
		
		if ( (sliceStartOffset + sliceSize) > (numSongSamples-1) ) {
			NSLog(@"FINISHED SLICES in function");
			//break;
		}
		
		
	//}
	
	
	
	
}


-(void) estimateBPM {
	//-(void) estimateBPMInWindow:(int)startIndex end:(int) endIndex {	
	
	// I means the integer variable representing a multiple of the distance between 2 randomly chosen relatively close neighbor beats
	// I = 0 would give the first chosen point... I = 1 gives the second... I = -5 would be 5 distances backwards
	
	
	if ( !detectedBeatsInWindow ) {
		
		detectedBeatsInWindow = (DetectedBeat**)malloc( numBeats * sizeof(DetectedBeat*) );
		
	}
	
	memset(detectedBeatsInWindow,0, numBeats * sizeof(DetectedBeat*) );
	numBeatsInWindow = 0;
	
	for (int i = 0; i < numBeats; i++) {
		
		DetectedBeat * beat = &detectedBeats[i];
		
		if ( ( beat->songSampleIndex >= currentBPMSearchWindowStartIndex ) && ( beat->songSampleIndex <= currentBPMSearchWindowEndIndex ) ) {
			detectedBeatsInWindow[numBeatsInWindow] = beat;
			numBeatsInWindow++;
		}
		
	}
	
	//NSLog(@"found %i beats in the window" , numBeatsInWindow );
	
	if ( numBeatsInWindow == 0 ) return;
	
	//int numIterations = numBeats/4;
	int numIterations = numBeatsInWindow-1;
	float lowestBPM = 60;
	float highestBPM = 190;
	
	BeatPair minBeatPair;
	
	// pick a random point
	
	// is the right-ward neighbor in our BPM search range ( 30 -> 210 ? )
	
	//   get the lowest and highest I values
	
	//   for each I
	//     find the nearest beat in the detectedBeats array
	//     add the abs(distance) to the accumulated error
	
	
	float minErr = 9000000.0;
	
	
	for (int q = 0; q < numIterations; q++) {
		
		//int randomBeatIndex = (arc4random() % (numBeatsInWindow-2));
		
		int randomBeatIndex = q;
		randomBeatIndex = CLAMP(0,randomBeatIndex,numBeatsInWindow-2);
		
		//NSLog(@"chose random beat: %i out of %i - 2 " , randomBeatIndex , numBeatsInWindow );
		
		BOOL isInRange = YES;
		BOOL isValidIndex = YES;
		int nextIndex=randomBeatIndex+1;
		int count = 0;
		
		//while ( count < 2 ) {
		
		//count++;
		
		DetectedBeat * beat1;
		DetectedBeat * beat2;
		beat1 = &detectedBeats[randomBeatIndex];
		beat2 = &detectedBeats[nextIndex];
		
		float BPM = 60.0 / ((beat2->songSampleIndex - beat1->songSampleIndex) / 44100.0);
		
		if ( BPM >= lowestBPM && BPM <= highestBPM ) {
			
			//--NSLog(@"checking err for BPM: %3.1f" , BPM );
			float err = [self getErrorInSongFromBeats:beat1 andBeat2:beat2];
			
			if ( err < minErr ) {
				
				//--NSLog(@"min err: %3.2f for BPM: %3.1f" , err , BPM );
				minErr = err;
				minBeatPair.beat1 = *beat1;
				minBeatPair.beat2 = *beat2;
				minBeatPair.totalError = err;
				minBeatPair.BPM = BPM;
			}
			
		} /*else if ( BPM > highestBPM ) {
		   
		   NSLog(@"BPM too fast, going to next neigbhor");
		   
		   } else if ( BPM < lowestBPM ) {
		   
		   NSLog(@"BPM too SLOW, breaking..");
		   break;
		   }
		   
		   
		   if ( nextIndex == (numBeats-1) ) {
		   NSLog(@"hit last beat, continuing");
		   break;
		   }
		   
		   nextIndex += 1;		
		   
		   }*/
		
		
	}
	
	NSLog(@"Finished BPM: %3.2f " , minBeatPair.BPM );
	
	[self activateBeatsFromBestPair:&minBeatPair.beat1 andBeat2:&minBeatPair.beat2];
	
	
}



-(float) getErrorInSongFromBeats:(DetectedBeat*) b1 andBeat2:(DetectedBeat*) b2 {
	
	
	//   get the lowest and highest I values
	
	//   for each I
	//     find the nearest beat in the detectedBeats array
	//     add the abs(distance) to the accumulated error
	
	float accErr = 0.0;
	
	
	Float64 sampleDistance = (b2->songSampleIndex - b1->songSampleIndex);
	
	//int lowI = - floorf( b1->songSampleIndex / sampleDistance );
	//int highI = floorf( (numSongSamples - b1->songSampleIndex) / sampleDistance );
	
	int lowI = - floorf( (b1->songSampleIndex-currentBPMSearchWindowStartIndex) / sampleDistance );
	int highI = floorf( (currentBPMSearchWindowEndIndex - b1->songSampleIndex) / sampleDistance );
	
	//lowI -= 1;
	//highI += 1;
	
	UInt64 beatSamplePosition;
	
	int totalI = (highI-lowI);
	
	//--NSLog(@"checking low: %i to high: %i -- total: %i " , lowI, highI , (highI-lowI) );
	
	for (int I = (int)lowI; I <= (int)highI; I++) {
		
		beatSamplePosition = b1->songSampleIndex + sampleDistance * I;
		Float64 minDistance = 100000;
		
		// maybe look only in detectedBeatsInWindow , thought it might find some on the boundaries of a window this way
		for (int j = 0; j < numBeats; j++) {
			
			DetectedBeat * testBeat = &detectedBeats[j];
			
			// get the distance between the predicted place of a beat, and a beat that exists...
			Float64 dist = fabs( beatSamplePosition - testBeat->songSampleIndex );
			
			if ( dist < minDistance ) {
				minDistance = dist;
			}
			
		}
		
		// add the closest beat's distance to the total error...
		accErr += minDistance;
		
	}
	
	float avgError = accErr / (float)totalI;
	
	return avgError;
	
}


-(void) activateBeatsFromBestPair:(DetectedBeat*) b1 andBeat2:(DetectedBeat*) b2 {
	
	float accErr = 0.0;
	
	Float64 sampleDistance = (b2->songSampleIndex - b1->songSampleIndex);
	
	//int lowI = - floorf( b1->songSampleIndex / sampleDistance );
	//int highI = floorf( (numSongSamples - b1->songSampleIndex) / sampleDistance );
	
	int lowI = - floorf( (b1->songSampleIndex-currentBPMSearchWindowStartIndex) / sampleDistance );
	int highI = floorf( (currentBPMSearchWindowEndIndex - b1->songSampleIndex) / sampleDistance );
	
	UInt64 beatSamplePosition;
	
	int totalI = (highI-lowI);
	
	float BPM = 60.0 / ((b2->songSampleIndex - b1->songSampleIndex) / 44100.0);
	
	//--NSLog(@"Activating beats for BPM: %3.1f -- %i to high: %i -- total: %i " , BPM,  lowI, highI , (highI-lowI) );
	
	for (int I = lowI; I <= highI; I++) {
		
		beatSamplePosition = b1->songSampleIndex + sampleDistance * I;
		Float64 minDistance = 44100;
		DetectedBeat * minBeat = nil;
		
		for (int j = 0; j < numBeats; j++) {
			
			DetectedBeat * testBeat = &detectedBeats[j];
			
			// get the distance between the predicted place of a beat, and a beat that exists...
			Float64 dist = fabs( beatSamplePosition - testBeat->songSampleIndex );
			
			if ( dist < minDistance ) {
				minDistance = dist;
				minBeat = testBeat;
			}
			
		}
		
		if ( minBeat ) {
			
			if ( minBeat->active ) {
				// if this beat was already active, make sure this new one is closer to a beat
				if ( minBeat->distance > minDistance ) {
					minBeat->distance = minDistance;
					minBeat->BPM = BPM;
				}
				
			} else {
				
				minBeat->active = YES;
				minBeat->distance = minDistance;
				minBeat->BPM = BPM;
				
			}
			
		}
		
		// add the closest beat's distance to the total error...
		//accErr += minDistance;
		
	}
	
	//float avgError = accErr / (float)totalI;
	
	//return avgError;
	
}



-(void) detectInSamples16:(SInt16*) samples numFrames:(int) num {
	
	if ( !samples32 ) {
		samples32 = (SInt32*)malloc( num * sizeof(SInt32) );
	}
	
	for (int i = 0; i < num; i++) {
		//samples32[i] = ( samples[i] << 8 );
		samples32[i] = ( samples[i] * 800 );
	}
	
	[self detectInSamples32:samples32 numFrames:num];
	//[self detectInSamples32Buffered:samples32 numFrames:num];
	
	
}

-(BeatValues) detectBeatValues:(SInt16*) samples numFrames:(int) num {
	
	BeatValues b;
	
	//static SInt32 * samples32 = nil;
	
	if ( !samples32 ) {
		samples32 = (SInt32*)malloc( num * sizeof(SInt32) );
	}
	
	for (int i = 0; i < num; i++) {
		//samples32[i] = ( samples[i] << 8 );
		samples32[i] = ( samples[i] * 800 );
	}
	
	//FFTBufferManager * fftb = (FFTBufferManager*)fftBufferManager;
	
	if (fftBufferManager->ComputeFFT_Now( (int32_t*)samples32, l_fftData)) {
		
		[self setFFTData:l_fftData length:fftBufferManager->GetNumberFrames() / 2];
		
		// fftData
		// fftLength
		
		int numBassSamples = fftLength;
		Float64 totalBass=0.0;
		SInt8 val;
		int start = 0;
		
		for (int i = start; i < (numBassSamples+start); i++) {
			
			val = (fftData[i] & 0xFF000000) >> 24;
			totalBass += (float)(val + 80) / 64.;
			
		}
		
		totalBass = totalBass / (float)numBassSamples;
		
		//b.bassValue = CLAMP(0., totalBass, 1.);
		b.bassValue = totalBass;
		
		
		
		int numTrebleSamples = fftLength/10;
		Float64 totalTreble=0.0;
		
		for (int i = (fftLength-numTrebleSamples); i < fftLength; i++) {
			
			val = (fftData[i] & 0xFF000000) >> 24;
			totalTreble += (float)(val + 80) / 64.;
			
		}
		
		totalTreble = totalTreble / (float)numTrebleSamples;
		
		b.trebleValue = totalTreble;
		
		b.bassValue += totalTreble;
		
		
	}
	
	
	
	return b;
	
}

-(void) detectInSamples32:(SInt32*) samples numFrames:(int) num {
	

	if (fftBufferManager->ComputeFFT_Now( (int32_t*)samples, l_fftData)) {
			
		//int numf = fftBufferManager->GetNumberFrames() / 2;
		//printf("numf : %i \n " , numf );
		[self setFFTData:l_fftData length:fftBufferManager->GetNumberFrames() / 2];
		
		int y, maxY;
		maxY = 40;//drawBufferLen;
		for (y=0; y<maxY; y++)
		{
			CGFloat yFract = (CGFloat)y / (CGFloat)(maxY - 1);
			CGFloat fftIdx = yFract * ((CGFloat)fftLength);
			
			double fftIdx_i, fftIdx_f;
			fftIdx_f = modf(fftIdx, &fftIdx_i);
			
			SInt8 fft_l, fft_r;
			CGFloat fft_l_fl, fft_r_fl;
			CGFloat interpVal;
			
			fft_l = (fftData[(int)fftIdx_i] & 0xFF000000) >> 24;
			fft_r = (fftData[(int)fftIdx_i + 1] & 0xFF000000) >> 24;
			fft_l_fl = (CGFloat)(fft_l + 80) / 64.;
			fft_r_fl = (CGFloat)(fft_r + 80) / 64.;
			interpVal = fft_l_fl * (1. - fftIdx_f) + fft_r_fl * fftIdx_f;
			
			interpVal = CLAMP(0., interpVal, 1.);
			
			printf(" %3.1f " , interpVal );
			
			//drawBuffers[0][y] = (interpVal * 120);
			
		}
		
		//cycleOscilloscopeLines();
		printf("\n");
		
	}
	
}


-(void) detectInSamples32Buffered:(SInt32*) samples numFrames:(int) num {
	
	
	
	if (fftBufferManager == NULL) return;
	
	if (fftBufferManager->NeedsNewAudioData())
	{
		//fftBufferManager->GrabAudioData(ioData); 
		fftBufferManager->GrabRawAudioData(samples , num ); 
		
	}

	
	if (fftBufferManager->HasNewAudioData())
	{
		if (fftBufferManager->ComputeFFT(l_fftData)) {
			
			[self setFFTData:l_fftData length:fftBufferManager->GetNumberFrames() / 2];
			
		} else {
			
			hasNewFFTData = NO;
			
		}
	}
	
	if (hasNewFFTData)
	{
		
		int y, maxY;
		maxY = 40;//drawBufferLen;
		for (y=0; y<maxY; y++)
		{
			CGFloat yFract = (CGFloat)y / (CGFloat)(maxY - 1);
			CGFloat fftIdx = yFract * ((CGFloat)fftLength);
			
			double fftIdx_i, fftIdx_f;
			fftIdx_f = modf(fftIdx, &fftIdx_i);
			
			SInt8 fft_l, fft_r;
			CGFloat fft_l_fl, fft_r_fl;
			CGFloat interpVal;
			
			fft_l = (fftData[(int)fftIdx_i] & 0xFF000000) >> 24;
			fft_r = (fftData[(int)fftIdx_i + 1] & 0xFF000000) >> 24;
			fft_l_fl = (CGFloat)(fft_l + 80) / 64.;
			fft_r_fl = (CGFloat)(fft_r + 80) / 64.;
			interpVal = fft_l_fl * (1. - fftIdx_f) + fft_r_fl * fftIdx_f;
			
			interpVal = CLAMP(0., interpVal, 1.);
			
			printf(" %3.1f " , interpVal );
			
			//drawBuffers[0][y] = (interpVal * 120);
			
		}
		
		//cycleOscilloscopeLines();
		printf("\n");
		
	}
	
}


- (void)setFFTData:(int32_t *)FFTDATA length:(NSUInteger)LENGTH
{
	if (LENGTH != fftLength)
	{
		fftLength = LENGTH;
		fftData = (SInt32 *)(realloc(fftData, LENGTH * sizeof(SInt32)));
	}
	memmove(fftData, FFTDATA, fftLength * sizeof(SInt32));
	hasNewFFTData = YES;
}





-(void) detectAtPath:(NSString*)path {
	

		
	float bpmValue;
    
	int nChannels;
    
	//BPMDetect bpm(inFile->getNumChannels(), inFile->getSampleRate());

	//BPMDetect bpm(1, 44100);
	
    //SAMPLETYPE sampleBuffer[BUFF_SIZE];
	SInt16 sampleBuffer[BUFF_SIZE];
	
    // detect bpm rate
    printf("Detecting BPM rate...");
    fflush(stdout);
	
    nChannels = 1;//inFile->getNumChannels();
	
    // Process the 'inFile' in small blocks, repeat until whole file has 
    // been processed
	/*
    while (inFile->eof() == 0)
    {
        int num, samples;
		
        // Read sample data from input file
        num = inFile->read(sampleBuffer, BUFF_SIZE);
		
        // Enter the new samples to the bpm analyzer class
        samples = num / nChannels;
        bpm.inputSamples(sampleBuffer, samples);
    }*/
	
	
	AudioFileID theAFID = 0;
	OSStatus result = noErr;
	UInt64 theFileSize = 0;
	UInt32 outDataSize = 0;
	AudioStreamBasicDescription theFileFormat;
	
	//const char *inFilePath = [[[NSBundle mainBundle] pathForResource:@"AmenBrotherMono16" ofType:@"wav"] UTF8String];
	//const char *inFilePath = [[[NSBundle mainBundle] pathForResource:name ofType:@"wav"] UTF8String];
	const char *inFilePath = [path UTF8String];
	
	UInt32 thePropSize = sizeof(theFileFormat);				
	
	CFURLRef theURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (UInt8*)inFilePath, strlen(inFilePath), false);
	if (theURL == NULL) {
		NSLog(@"errr");
	}
	
	result = AudioFileOpenURL(theURL, kAudioFileReadPermission, 0, &theAFID);
	
	
	result = AudioFileGetProperty(theAFID, kAudioFilePropertyDataFormat, &thePropSize, &theFileFormat);
	//AssertNoError("Error getting file format", end);
	
	
	thePropSize = sizeof(UInt64);
	result = AudioFileGetProperty(theAFID, kAudioFilePropertyAudioDataByteCount, &thePropSize, &theFileSize);
	//AssertNoError("Error getting file data size", end);
	
	
	outDataSize = (UInt32)theFileSize;
	//AssertNoError("Error loading file info", fail)
	
	NSLog(@"file size: %i " , outDataSize	);
	
	int numSongSamples = outDataSize / theFileFormat.mBytesPerPacket;//44100 * 5;
	//recordedSamples = (SInt32*)malloc( recordBufferLength * sizeof(SInt32) );
	//recordedSamples16 = (SInt16*)malloc( numSongSamples * sizeof(SInt16) );
	
	//outData = malloc(outDataSize);
	
	//result = AudioFileReadBytes(theAFID, false, 0, &outDataSize, recordedSamples16);
	//AssertNoError("Error reading file data", fail)
	
	UInt32 actuallyRead = BUFF_SIZE;
	
	SInt64 startingByte = 0;
	
	int cunter = 0;
	
	while (actuallyRead > 0)
    {
        UInt32 num, samples;
		
        // Read sample data from input file
        //num = inFile->read(sampleBuffer, BUFF_SIZE);
		
		num = BUFF_SIZE * 2;
		
		result = AudioFileReadBytes(theAFID, false, startingByte, &num, sampleBuffer);
		
		actuallyRead = num;
		
		startingByte += actuallyRead;
		
		printf("read: %i \n", actuallyRead );
		
        // Enter the new samples to the bpm analyzer class
        //samples = num / nChannels;
		samples = num / 2;
		
       // bpm.inputSamples(sampleBuffer, samples);
		
		cunter++;
		
		//if ( cunter % 10 == 0 ) {
			
			//bpmValue = bpm.getBpm();
			//printf("Detected BPM rate %.1f\n\n", bpmValue);
			
		//}
		
    }
	
	AudioFileClose(theAFID);
	
    // Now the whole song data has been analyzed. Read the resulting bpm.
   // bpmValue = bpm.getBpm();
    printf("Done!\n");
	
    // rewind the file after bpm detection
   // inFile->rewind();
	
    if (bpmValue > 0)
    {
        printf("Detected BPM rate %.1f\n\n", bpmValue);
    }
    else
    {
        printf("Couldn't detect BPM rate.\n\n");
        return;
    }
	
	/*
    if (params->goalBPM > 0)
    {
        // adjust tempo to given bpm
        params->tempoDelta = (params->goalBPM / bpmValue - 1.0f) * 100.0f;
        printf("The file will be converted to %.1f BPM\n\n", params->goalBPM);
    }
	*/
	
}

- (void) dealloc
{
	
	delete[] l_fftData;
	delete fftBufferManager;
	
	free(detectedBeats);
	detectedBeats = nil;
	numBeats = 0;
	
	free(bassBuffer);
	bassBuffer = nil;
	
	free(trebleBuffer);
	trebleBuffer = nil;
	
	beatBufferSize = 0;
	
	numSongSamples = 0;
	
	
	[super dealloc];
	
	
}




@end
