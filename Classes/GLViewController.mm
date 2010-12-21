//
//  GLViewController.m
//  BeatMatchTests
//
//  Created by Chris Laan on 8/17/10.
//  Copyright Laan Labs 2010. All rights reserved.
//

#import "GLViewController.h"

#import "AurioHelper.h"

#import "glStuff.h"

//#import "BPMDetector.h"

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif


#define BUFF_SIZE           2048



#pragma mark -RIO Render Callback

static OSStatus	PerformThru(
							void						*inRefCon, 
							AudioUnitRenderActionFlags 	*ioActionFlags, 
							const AudioTimeStamp 		*inTimeStamp, 
							UInt32 						inBusNumber, 
							UInt32 						inNumberFrames, 
							AudioBufferList 			*ioData)
{
	GLViewController *THIS = (GLViewController *)inRefCon;
	//OSStatus err = AudioUnitRender(THIS->rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	
	OSStatus err = noErr;//AudioUnitRender(THIS->rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	
	if (err) { 
		printf("PerformThru: error %d\n", (int)err); 
		//return err; 
	}
	
	
	[THIS modifyData:ioData numFrames:inNumberFrames];
	
	
	/*
	 if (THIS->fftBufferManager == NULL) return noErr;
	 
	 if (THIS->fftBufferManager->NeedsNewAudioData())
	 {
	 THIS->fftBufferManager->GrabAudioData(ioData); 
	 }
	 */
	
	return noErr;
}


@interface GLViewController()

-(float) getErrorInSongFromBeats:(DetectedBeat*) b1 andBeat2:(DetectedBeat*) b2;
-(void) activateBeatsFromBestPair:(DetectedBeat*) b1 andBeat2:(DetectedBeat*) b2;

@end




@implementation GLViewController

-(void) setupStuff {
	
	//player = [[AVAudioPlayer alloc] initWithData:<#(NSData *)data#> error:<#(NSError **)outError#>];
			  
	texWidth = 320;
	texHeight = 480;
	
	playSpeed = 1.0;
	playPointer = 0.0;
	
	follow = YES;
	
	[self initAudio];
	
	[self createGestureRecognizers];
	
	waveTexture = [[Texture2D alloc] initBGRAWithPixelsWide:texWidth pixelsHigh:texHeight];
	
	texPixels = (uint8_t*)malloc( texWidth * texHeight * 4 );
	
	//[self randomPixels];
	[self blackPixels];
	
	[waveTexture updatePixels:texPixels];
	
	// test different songs here....
	// or put in your own
	NSString * path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"modern.wav"];
	//NSString * path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"css.wav"];
	//NSString * path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"vampire.wav"];
	
	[self loadFileAtPath:path];
	
	//[self drawBufferIntoTexture];
	[self drawZoomedBufferIntoTexture];
	
	[waveTexture updatePixels:texPixels];
	
	//BPMDetector * bpm = [[BPMDetector alloc] init];
	//[bpm detectAtPath:path];
	
	//[self setupBeatBuffers];
	
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		//[self doFFT];
		[self doBeatDetect];
		
	});
	
	
	
	
}	

-(void) initAudio {
	
	
	NSError *error;
	if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error])
	{
		NSLog(@"Error Setting AudioSession: %@", [error localizedDescription]);
		return;
	}

	// Initialize our remote i/o unit
	
	inputProc.inputProc = PerformThru;
	inputProc.inputProcRefCon = self;
	
	CFURLRef url = NULL;
		
	// Initialize and configure the audio session
	//XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, self), "couldn't initialize audio session");
	
	//UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
	//UInt32 audioCategory = kAudioSessionCategory_LiveAudio;
	UInt32 audioCategory = kAudioSessionCategory_LiveAudio;
	AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory);
	//AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, self);
	
	
	Float32 preferredBufferSize = .005;
	AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize);
	
	Float64 hwSampleRate;
	
	UInt32 size = sizeof(hwSampleRate);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &hwSampleRate);
	NSLog(@"Sample rate: %4.4f" , hwSampleRate );
	
	AudioSessionSetActive(true);
	

	
	// Open the output unit
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	
	AudioComponent comp = AudioComponentFindNext(NULL, &desc);
	
	AudioComponentInstanceNew(comp, &rioUnit);
	
	UInt32 one = 1;
	//--XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one)), "couldn't enable input on the remote I/O unit");
	//--XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 1, &one, sizeof(one)), "couldn't enable input on the remote I/O unit");
	//--XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inRenderProc, sizeof(inRenderProc)), "couldn't set remote i/o render callback");
	AudioUnitSetProperty(rioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Output, 0, &inputProc, sizeof(inputProc));
	
	//SetupRemoteIO();
	[AurioHelper SetupRemoteIO:rioUnit];
	
	/*
	CAStreamBasicDescription outFormat;
	
	// set our required format - Canonical AU format: LPCM non-interleaved 8.24 fixed point
	outFormat.SetAUCanonical(2, false);
	AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outFormat, sizeof(outFormat));
	AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &outFormat, sizeof(outFormat));
	*/
	
	AudioUnitInitialize(rioUnit);
	
	
	UInt32 maxFPS;
	size = sizeof(maxFPS);
	AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size);
	
	NSLog(@"Max frames per slice: %i " , maxFPS );
	
	//fftBufferManager = new FFTBufferManager(maxFPS);
	//l_fftData = new int32_t[maxFPS/2];
	
	AudioOutputUnitStart(rioUnit);
	
	//size = sizeof(thruFormat);
	//XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
	
	//thruFormat.Print();
	
		

}

#pragma mark -
#pragma mark Audio Callback

-(void) modifyData:(AudioBufferList*)inData numFrames:(UInt32)inNumberFrames {
	
	if ( sampleBuffer == nil ) return;
	
	SInt32 *data_ptr_dst = (SInt32 *)(inData->mBuffers[0].mData);
	
	SInt32 *data_ptr_dst2 = nil;
	
	if ( inData->mNumberBuffers > 1 ) { 
		data_ptr_dst2 = (SInt32 *)(inData->mBuffers[1].mData);
	}
	
	
	for (int i = 0; i < inNumberFrames; i++) {
	
		playPointer += playSpeed;
		
		if ( playPointer > (numSongSamples-1) ) {
			playPointer = 0.0;			
		} else if ( playPointer < 0.0 ) {
			playPointer = numSongSamples-1;
		}
		
		UInt64 p = roundf(playPointer);
		SInt32 vOut = sampleBuffer[p];
		//vOut = vOut*800;
		vOut = vOut << 8;
		
		//SInt32 vOut = (-332000 + (arc4random() % 664000));
		
		*data_ptr_dst = vOut;
		*data_ptr_dst2 = vOut;
		
		data_ptr_dst++;
		data_ptr_dst2++;
		
	}
	
	
	
}


#pragma mark -
#pragma mark Draw Beats	

- (void)drawView:(UIView *)theView
{
    glColor4f(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	
	[self drawAudioTexture];
	
	glBasicDrawing();
	
	gliPhoneCoordSystem(320, 480);
	
	

	Float64 pt = (playPointer-startingIndex) / ((float)(endingIndex - startingIndex)) * 480.0;
	
	glColor4f(0.0, 1.0, 0.0, 0.0);
	
	glDrawLine(0, pt, 320, pt);
	
	
	int startingBeatIndex;
	int endingBeatIndex;
	
	//startingBeatIndex = (startingIndex / (Float64)numSongSamples) * beatBufferSize;
	//endingBeatIndex = (endingIndex / (Float64)numSongSamples) * beatBufferSize;
	
	//float totalSamples = (endingBeatIndex - startingBeatIndex);
	
	glColor4f(0, 0, 1, 1);
	
	/*
	for (int i = 0; i < 480; i++) {
		
		
		//int index = ((float)i/480.0) * beatBufferSize; 
		int index = startingBeatIndex + ( ((float)i/480.0) * totalSamples );
		float bval = bassBuffer[index];
		float tval = trebleBuffer[index];
		
		
		int xVal = 160 + bval*180; 
		
		glDrawPoint(xVal, i, 3);
		
		
	}
	*/
	
	/*
	glColor4f(1, 0.65, 0.3, 1);
	
	for (int i = 0; i < 480; i++) {
		
		
		//int index = ((float)i/480.0) * beatBufferSize; 
		int index = startingBeatIndex + ( ((float)i/480.0) * totalSamples );
		//float bval = bassBuffer[index];
		float tval = trebleBuffer[index];
		
		
		int xVal = 160 + tval*180; 
		
		glDrawPoint(xVal, i, 3);
		
		
	}
	*/
	
	if ( bpmDetector != nil ) {
		
		static int counter = 0;
		
		int numBeats = bpmDetector.numBeats;
		DetectedBeat * detectedBeats = bpmDetector.detectedBeats;
		
		glColor4f(0.15, 0.9, 0.8, 1);
		float total = (endingIndex-startingIndex);
		for (int i = 0; i < numBeats; i++) {
			
			DetectedBeat * beat;
			beat = &detectedBeats[i];
			
			if ( (beat->songSampleIndex > startingIndex) && (beat->songSampleIndex < endingIndex ) ) {
				
				float yVal = ((float)(beat->songSampleIndex - startingIndex)) / total;
				yVal = yVal*480.0;
				
				if ( beat->active ) {
					
					glColor4f(0.9, 0.15, 0.8, 1);
					glDrawLine(0, yVal, 320, yVal);
					
					if ( counter % 200 == 0 ) {
						//NSLog(@"BPM: %3.1f " , beat->BPM);
						
					}
					
					counter++;
					
				} else {
					glColor4f(0.0, 0.4, 0.2, 1);
					glDrawLine(0, yVal, 320, yVal);
				}
				
			}
			
		}
		
	
	}
	
	
	if ( follow && pt > 480.0 ) {
		
		int total = (endingIndex-startingIndex);
		startingIndex += total;
		endingIndex += total;
		startingIndex = CLAMP( 0 , startingIndex, numSongSamples );
		endingIndex = CLAMP( 0 , endingIndex, numSongSamples );
		
		[self redrawTextureAndUpdate];
		
			
	} else if ( follow && (pt < -1000 )) {
		
		//int total = (endingIndex-startingIndex);
		startingIndex=0;
		endingIndex=(numSongSamples/6);
		
		[self redrawTextureAndUpdate];
		
	}
	
	
	
    
}

-(void) drawAudioTexture {
	
	
	glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	
	glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
	
	//gliPhoneCoordSystem(320, 480);
	glOrthof(0, 320, 0, 480, -1.0f, 1.0f);
	
	glColor4f(1.0, 1.0, 1.0, 1.0);
	
	// glVertexPointer(3, GL_FLOAT, 0, squareVertices);
    glEnableClientState(GL_VERTEX_ARRAY);
	

	[waveTexture drawAtPoint:CGPointMake(160, 240) withScale:1.0 andRotation:0];
	
	
	
}

-(void) redrawTextureAndUpdate {
	
	[self blackPixels];
	[self drawZoomedBufferIntoTexture];
	[waveTexture updatePixels:texPixels];
	
	
}

-(void) blackPixels {
	
	memset(texPixels , 0 , texWidth*texHeight*4);
	
}

-(void) randomPixels {
	
	int counter = texWidth * texHeight;
	uint8_t * pixels = texPixels;
	
	
	 while (counter>0) {
	 
	 *pixels++ = (arc4random() % 255);
	 *pixels++ = (arc4random() % 255);
	 *pixels++ = (arc4random() % 255);
	 *pixels++ = 255;
	 
	 counter--;
	 
	 }
	 
	/*
	while (counter>0) {
		
		*pixels++ = 0;
		*pixels++ = 0;
		*pixels++ = 0;
		*pixels++ = 0;
		
		counter--;
		
	}
	 */
	
}

-(void) drawZoomedBufferIntoTexture {
	
	
	for (int yy = startingIndex; yy < endingIndex; yy+=10) {
		
		int x, y ;
		
		//Float64 progress = yy / (float)numSongSamples;
		Float64 progress = (yy-startingIndex) / (float)(endingIndex-startingIndex);
		
		y = progress * texHeight;
		//y = yy;
		
		x = 160;
		int byte;
		//int sampleIndex = numSongSamples * (y/(float)texHeight);
		int sampleIndex = yy;
		int grayVal = 80;
		
		SInt16 val = (sampleBuffer[sampleIndex]);
		Float64 scaledf = (abs(val) / 32000.0 ) * 60.0;
		uint8_t scaled = (uint8_t)scaledf;
		
		for (int i = 0; i < scaled; i++) {
			
			x = 160 + i;
			byte = x*4 + y*texWidth*4;
			texPixels[byte] = grayVal;
			texPixels[byte+1] = grayVal;
			texPixels[byte+2] = grayVal;
			texPixels[byte+3] = 255;
			
			x = 160 - i;
			byte = x*4 + y*texWidth*4;
			texPixels[byte] = grayVal;
			texPixels[byte+1] = grayVal;
			texPixels[byte+2] = grayVal;
			texPixels[byte+3] = 255;
			
		}
		/*
		if ( scaled > 50 ) {
			for (int i = 0; i < texWidth; i++) {
				x = i;
				byte = x*4 + y*texWidth*4;
				texPixels[byte] = 0;
				texPixels[byte+1] = 0;
				texPixels[byte+2] = 125;
				texPixels[byte+3] = 255;
				
			}
		}*/
		
	}
	
	
}

-(void) drawBufferIntoTexture {
	
	
	for (int yy = 0; yy < numSongSamples; yy++) {
		
		int x, y ;
		
		Float64 progress = yy / (float)numSongSamples;
		
		y = progress * texHeight;
		//y = yy;
		
		x = 160;
		int byte;
		//int sampleIndex = numSongSamples * (y/(float)texHeight);
		int sampleIndex = yy;
		
		SInt16 val = (sampleBuffer[sampleIndex]);
		Float64 scaledf = (abs(val) / 32000.0 ) * 60.0;
		uint8_t scaled = (uint8_t)scaledf;
		
		for (int i = 0; i < scaled; i++) {
			
			x = 160 + i;
			byte = x*4 + y*texWidth*4;
			texPixels[byte] = 125;
			texPixels[byte+1] = 125;
			texPixels[byte+2] = 125;
			texPixels[byte+3] = 255;
			
			x = 160 - i;
			byte = x*4 + y*texWidth*4;
			texPixels[byte] = 125;
			texPixels[byte+1] = 125;
			texPixels[byte+2] = 125;
			texPixels[byte+3] = 255;
			
		}
		
		if ( scaled > 50 ) {
			for (int i = 0; i < texWidth; i++) {
				x = i;
				byte = x*4 + y*texWidth*4;
				texPixels[byte] = 0;
				texPixels[byte+1] = 0;
				texPixels[byte+2] = 125;
				texPixels[byte+3] = 255;
				
			}
		}
	
	}
	
	
}


-(void) loadFileAtPath:(NSString*)path {
	
	
	
	float bpmValue;
    
	int nChannels;
    
	//BPMDetect bpm(inFile->getNumChannels(), inFile->getSampleRate());
	
	//BPMDetect bpm(1, 44100);
	
    //SAMPLETYPE sampleBuffer[BUFF_SIZE];
	//SInt16 sampleBuffer[BUFF_SIZE];
	
	if ( sampleBuffer != nil ) {
		free(sampleBuffer);
	}
	
	
	
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
	
	//NSLog(@"progress %3.1f " , progress	);
	
	sampleBuffer = (SInt16*)malloc( outDataSize * sizeof(SInt16) );
	memset(sampleBuffer , 0 , outDataSize );
	
	numSongSamples = outDataSize / theFileFormat.mBytesPerPacket;//44100 * 5;
	//recordedSamples = (SInt32*)malloc( recordBufferLength * sizeof(SInt32) );
	//recordedSamples16 = (SInt16*)malloc( numSongSamples * sizeof(SInt16) );
	
	//outData = malloc(outDataSize);
	
	//result = AudioFileReadBytes(theAFID, false, 0, &outDataSize, recordedSamples16);
	//AssertNoError("Error reading file data", fail)
	
	UInt32 actuallyRead = BUFF_SIZE;
	
	SInt64 startingByte = 0;
	
	int cunter = 0;
	
	Float64 samplesRead = 0;
	Float64 maxVal = 0;
	
	while (actuallyRead > 0)
    {
        UInt32 num, samples;
		
		Float64 progress = samplesRead / (Float64)numSongSamples;
		
        // Read sample data from input file
        //num = inFile->read(sampleBuffer, BUFF_SIZE);
		
		num = BUFF_SIZE * 2;
		
		
		int sread = samplesRead;
		SInt16 * current = sampleBuffer+sread;
		
		result = AudioFileReadBytes(theAFID, false, startingByte, &num, current);
		
		actuallyRead = num;
		
		startingByte += actuallyRead;
		
		//printf("read: %i \n", actuallyRead );
		
		//NSLog(@"progress %3.1f , %i " , progress , current[5] );

		
        // Enter the new samples to the bpm analyzer class
        //samples = num / nChannels;
		samples = num / 2;
		
		samplesRead += samples;
		
		// bpm.inputSamples(sampleBuffer, samples);
		
		cunter++;
		
		//if ( cunter % 10 == 0 ) {
		
		//bpmValue = bpm.getBpm();
		//printf("Detected BPM rate %.1f\n\n", bpmValue);
		
		//}
		
    }
	
	printf("Max Val: %3.2f" , maxVal );
	
	AudioFileClose(theAFID);
	
    // Now the whole song data has been analyzed. Read the resulting bpm.
	// bpmValue = bpm.getBpm();
    printf("Done!\n");
	
    // rewind the file after bpm detection
	// inFile->rewind();

	
	/*
	 if (params->goalBPM > 0)
	 {
	 // adjust tempo to given bpm
	 params->tempoDelta = (params->goalBPM / bpmValue - 1.0f) * 100.0f;
	 printf("The file will be converted to %.1f BPM\n\n", params->goalBPM);
	 }
	 */
	
	startingIndex = 0;
	endingIndex = numSongSamples / 6;
	
	
}

-(void) setupBeatBuffers {
	
}


-(void) doBeatDetect {
	
	bpmDetector = [[BPMDetector alloc] initWithSongLength:numSongSamples];
	
	/*
	int chunkSize = 512;
	int bufSize = 4096; // samples.. not bytes
	
	// numSongSamples ... slice Size ?
	*/
	
	int sliceStartOffset = 0;
	int sliceSize = 44100 * 5;
	int numSliceSamples = sliceSize;
	//int offset = 0;
	
	while (1) {
		
		numSliceSamples = CLAMP(0, sliceSize, (numSongSamples-sliceStartOffset));
		
		[bpmDetector addSamplesAndDetect:(sampleBuffer+sliceStartOffset) numFrames:numSliceSamples atSongOffset:sliceStartOffset];
		
		sliceStartOffset += numSliceSamples;
		
		if ( (sliceStartOffset + sliceSize) > (numSongSamples-1) ) {
			NSLog(@"FINISHED Outside");
			break;
		}
		
	}
	
	
}

/*
-(void) doFFT {
	
	
	int chunkSize = 512;
	int bufSize = 4096; // samples.. not bytes
	
	BPMDetector * bpm = [[BPMDetector alloc] initWithSize:bufSize];
	
	// numSongSamples ... slice Size ?
	
	int sliceStartOffset = 0;
	int sliceSize = 44100 * 5;
	int numSliceSamples = sliceSize;
	int offset = 0;
	
	while (1) {
		
		numSliceSamples = CLAMP(0, sliceSize, (numSongSamples-sliceStartOffset));
		
		//NSLog(@"\n\n starting loop.. num slice: %i , offset: %i ", numSliceSamples , sliceStartOffset );
		
		if ( !bassBuffer ) {
			beatBufferSize = numSliceSamples / chunkSize;
			bassBuffer = (float*)malloc( beatBufferSize * sizeof(float) );
			trebleBuffer = (float*)malloc( beatBufferSize * sizeof(float) );
		}
		
		memset(bassBuffer,0,beatBufferSize * sizeof(float));
		
		offset = sliceStartOffset;
		
		for (int i = 0; i < (numSliceSamples/chunkSize); i++) {
			
			BeatValues b = [bpm detectBeatValues:(sampleBuffer+offset) numFrames:bufSize];
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
			//NSLog(@"FINISHED SLICES");
			break;
		}
		
		
	}
	
	
	

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
				
			} 

			
	}
	
	//NSLog(@"Finished BPM: %3.2f " , minBeatPair.BPM );
	
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
*/






/*
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	
	
	
	
	UITouch * t = [touches anyObject];
	
	CGPoint p = [t locationInView:self.view];
	
	//oldPoint = p;
	
	
	
}



- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	
	if ( [touches count] == 1 ) {
		
		NSLog(@"tomoved");
		
		UITouch * t = [touches anyObject];
		
		CGPoint p = [t locationInView:self.view];
	
		
	}
	
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{

	
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	
	NSLog(@"ended");
	
}	
*/

#pragma mark -
#pragma mark Gestures

- (void)createGestureRecognizers {
	
    UITapGestureRecognizer *singleFingerDTap = [[UITapGestureRecognizer alloc]
												initWithTarget:self action:@selector(handleSingleDoubleTap:)];
    singleFingerDTap.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:singleFingerDTap];
    [singleFingerDTap release];
	
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
										  initWithTarget:self action:@selector(handlePanGesture:)];
    [self.view addGestureRecognizer:panGesture];
    [panGesture release];
	
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
											  initWithTarget:self action:@selector(handlePinchGesture:)];
    [self.view addGestureRecognizer:pinchGesture];
    [pinchGesture release];
	
}

- (IBAction)handlePinchGesture:(UIGestureRecognizer *)sender {
	
	static int centerIndex = 0;
	static int startingTotal = 0;
	
	if (sender.state == UIGestureRecognizerStateBegan ) {
		
		//NSLog(@"began");
		startingTotal = (endingIndex - startingIndex);
		centerIndex = startingIndex + startingTotal/2;
		
	}
	
    CGFloat factor = [(UIPinchGestureRecognizer *)sender scale];
   // self.view.transform = CGAffineTransformMakeScale(factor, factor);
	//NSLog(@"Scale: %3.1f " , factor );
	
	//float total = endingIndex-startingIndex;
	
	//total /= factor;
	
	startingIndex = centerIndex - (startingTotal/2)/factor;
	endingIndex = centerIndex + (startingTotal/2)/factor;
	
	startingIndex = CLAMP(0.0 , startingIndex , numSongSamples);
	endingIndex = CLAMP(0.0 , endingIndex , numSongSamples);
	
	[self redrawTextureAndUpdate];
	
}

- (IBAction)handlePanGesture:(UIPanGestureRecognizer *)sender {
	
	static int tstartingIndex = 0;
	static int tendingIndex = 0;
	
	if (sender.state == UIGestureRecognizerStateBegan ) {
		
		//NSLog(@"began");
		tstartingIndex = startingIndex;
		tendingIndex = endingIndex;
		
	}
	
    CGPoint translate = [sender translationInView:self.view];
	
	float samplesPerPixel = ((float)(endingIndex - startingIndex)) / 480.0;
	
	//NSLog(@"translate: %3.1f " , translate.y );
	
	startingIndex = tstartingIndex - (translate.y*samplesPerPixel);
	endingIndex = tendingIndex - (translate.y*samplesPerPixel);
	
	startingIndex = CLAMP(0.0 , startingIndex , numSongSamples);
	endingIndex = CLAMP(0.0 , endingIndex , numSongSamples);
	
	/*
    CGRect newFrame = currentImageFrame;
    newFrame.origin.x += translate.x;
    newFrame.origin.y += translate.y;
    sender.view.frame = newFrame;
	
    if (sender.state == UIGestureRecognizerStateEnded)
        currentImageFrame = newFrame;
	*/
	[self redrawTextureAndUpdate];
	
	
}

- (IBAction)handleSingleDoubleTap:(UIGestureRecognizer *)sender {
    
	//CGPoint tapPoint = [sender locationInView:sender.view.superview];
	
	startingIndex = 0;
	endingIndex = numSongSamples;
	[self redrawTextureAndUpdate];
	
    	
}




-(void)setupView:(GLView*)view
{
	const GLfloat zNear = 0.01, zFar = 1000.0, fieldOfView = 45.0; 
	GLfloat size; 
	glEnable(GL_DEPTH_TEST);
	glMatrixMode(GL_PROJECTION); 
	size = zNear * tanf(DEGREES_TO_RADIANS(fieldOfView) / 2.0); 
	CGRect rect = view.bounds; 
	glFrustumf(-size, size, -size / (rect.size.width / rect.size.height), size / 
			   (rect.size.width / rect.size.height), zNear, zFar); 
	glViewport(0, 0, rect.size.width, rect.size.height);  
	glMatrixMode(GL_MODELVIEW);
	
	glLoadIdentity(); 
	
	[self setupStuff];
	
}
- (void)dealloc 
{
    [super dealloc];
}
@end
