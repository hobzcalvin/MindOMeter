//  FSKRecognizer.h
// Copyright 2010 PLX Devices Inc. All Rights Reserved


#import "CharReceiver.h"
#import "Constants.h"
#define FSK_SMOOTH 3

typedef enum
{
	FSKStart,
	FSKBits,
	FSKSuccess,
	FSKFail
} FSKRecState;

struct FSKByteQueue;

@interface FSKRecognizer : NSObject {
	unsigned recentLows;
	unsigned recentHighs;
	unsigned halfWaveHistory[FSK_SMOOTH];
	unsigned bitPosition;
	uint8_t bits;
	FSKRecState state;
	id<CharReceiver> receiver;
	struct FSKByteQueue* byteQueue;
}
@property (nonatomic, retain) id<CharReceiver> receiver;

- (void) edge: (int)height width:(UInt64)nsWidth interval:(UInt64)nsInterval;
- (void) idle: (UInt64)nsInterval;
- (void) reset;


@end
