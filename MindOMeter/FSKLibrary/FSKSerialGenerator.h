//  FSKSerialGenerator.h
// Copyright 2010 PLX Devices Inc. All Rights Reserved


#import "AudioSignalGenerator.h"


@interface FSKSerialGenerator : AudioSignalGenerator {
	unsigned nsBitProgress;
	unsigned sineTableIndex;

	unsigned bitCount;
	UInt16 bits;
	
	BOOL hasQueuedBytes;
	
	NSInputStream* bytesToSend;
	NSOutputStream* queuedBytes;
}

@property (nonatomic, retain) NSInputStream* bytesToSend;
@property (nonatomic, retain) NSOutputStream* queuedBytes;

- (void) writeByte:(UInt8)byte;

@end
