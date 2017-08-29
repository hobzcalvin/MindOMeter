//  AudioSignalAnalyzer.h
// Copyright 2010 PLX Devices Inc. All Rights Reserved

#import "AudioQueueObject.h"
#import "FSKRecognizer.h"

//#define DETAILED_ANALYSIS

typedef struct
{
	int			lastFrame;
	int			lastEdgeSign;
	unsigned	lastEdgeWidth;
	int			edgeSign;
	int			edgeDiff;
	unsigned	edgeWidth;
	unsigned	plateauWidth;
#ifdef DETAILED_ANALYSIS
	SInt64		edgeSum;
	int			edgeMin;
	int			edgeMax;
	SInt64		plateauSum;
	int			plateauMin;
	int			plateauMax;
#endif
}
analyzerData;

@interface AudioSignalAnalyzer : AudioQueueObject {
	BOOL	stopping;
	analyzerData pulseData;
    FSKRecognizer *recognizer;
}

@property (readwrite) BOOL	stopping;
@property (readonly) analyzerData* pulseData;
@property (nonatomic, retain) FSKRecognizer *recognizer;

- (void) setupRecording;

- (void) record;
- (void) stop;

- (void) edge: (int)height width:(unsigned)width interval:(unsigned)interval;
- (void) idle: (unsigned)samples;
- (void) reset;

@end
