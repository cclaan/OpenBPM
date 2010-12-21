//
//  AccelerateHelper.m
//  BeatMatchTests
//
//  Created by Chris Laan on 8/18/10.
//  Copyright 2010 Laan Labs. All rights reserved.
//

#import "AccelerateHelper.h"


#define FFT_LENGTH 1024;
#define FFT_LENGTH_LOG2 102;


@implementation AccelerateHelper

-(void) setup {
	
	//fftSetup = vDSP_create_fftsetup();
	
}

-(void) testInverse {
	
	
	/*
	float scale = 1.0/((float) FFT_LENGTH);
	
	vDSP_fft_zop( setup, &A, 1, &B, 1, FFT_LENGTH_LOG2, FFT_FORWARD );
	
	vDSP_fft_zop( setup, &B, 1, &A, 1, FFT_LENGTH_LOG2, FFT_INVERSE );
	
	//scale the result 
	
	vDSP_vsmul( A.realp, 1, &scale, A.realp, 1, FFT_LENGTH );
	
	vDSP_vsmul( A.imagp, 1, &scale, A.imagp, 1, FFT_LENGTH );
	*/
	
	
}

@end
