//
//  BeatMatchTestsAppDelegate.h
//  BeatMatchTests
//
//  Created by Chris Laan on 8/17/10.
//  Copyright Laan Labs 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GLView;

@interface BeatMatchTestsAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    GLView *glView;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet GLView *glView;

@end

