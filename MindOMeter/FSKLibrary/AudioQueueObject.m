//  AudioQueueObject.m
// Copyright 2010 PLX Devices Inc. All Rights Reserved

#import "AudioQueueObject.h"


@implementation AudioQueueObject

@synthesize queueObject;
@synthesize audioFormat;

- (BOOL) isRunning {
	
	UInt32		isRunning;
	UInt32		propertySize = sizeof (UInt32);
	OSStatus	result;
	
	result =	AudioQueueGetProperty (
									   queueObject,
									   kAudioQueueProperty_IsRunning,
									   &isRunning,
									   &propertySize
									   );
	
	if (result != noErr) {
		return false;
	} else {
		return isRunning;
	}
}


@end
