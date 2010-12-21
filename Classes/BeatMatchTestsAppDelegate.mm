//
//  BeatMatchTestsAppDelegate.m
//  BeatMatchTests
//
//  Created by Chris Laan on 8/17/10.
//  Copyright Laan Labs 2010. All rights reserved.
//

#import "BeatMatchTestsAppDelegate.h"
#import "GLView.h"

@implementation BeatMatchTestsAppDelegate

@synthesize window;
@synthesize glView;

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    
	glView.animationInterval = 1.0 / kRenderingFrequency;
	[glView startAnimation];
}


- (void)applicationWillResignActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / kInactiveRenderingFrequency;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / 60.0;
}


- (void)dealloc {
	[window release];
	[glView release];
	[super dealloc];
}

@end
