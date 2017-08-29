//  AudioQueueObject.h
// Copyright 2010 PLX Devices Inc. All Rights Reserved

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>

#define kNumberAudioDataBuffers	3

@interface AudioQueueObject : NSObject {
	AudioQueueRef					queueObject;					// the audio queue object being used for playback
	AudioStreamBasicDescription		audioFormat;
}

@property (readwrite)			AudioQueueRef				queueObject;
@property (readwrite)			AudioStreamBasicDescription	audioFormat;

- (BOOL) isRunning;

@end
