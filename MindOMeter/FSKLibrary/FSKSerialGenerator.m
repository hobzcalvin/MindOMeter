//  FSKSerialGenerator.m
// Copyright 2010 PLX Devices Inc. All Rights Reserved


#import "FSKSerialGenerator.h"
#import "Constants.h"
SAMPLE sineTable[SINE_TABLE_LENGTH];

@implementation FSKSerialGenerator

@synthesize bytesToSend;
@synthesize queuedBytes;

- (id) init
{
	if (self == [super init])
	{
		self.bytesToSend = nil;
		self.queuedBytes = [NSOutputStream outputStreamToMemory];
		[self.queuedBytes open];
		
		for(int i=0; i<SINE_TABLE_LENGTH; ++i)
		{
			sineTable[i] = (SAMPLE)(sin(i * 2 * 3.14159 / SINE_TABLE_LENGTH) * SAMPLE_MAX);
		}
	}
	
	return self;
}

- (void) setupAudioFormat
{
	audioFormat.mSampleRate			= SAMPLE_RATE;
	audioFormat.mFormatID			= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mFramesPerPacket	= 1;
	audioFormat.mChannelsPerFrame	= NUM_CHANNELS;
	audioFormat.mBitsPerChannel		= BITS_PER_CHANNEL;
	audioFormat.mBytesPerPacket		= BYTES_PER_FRAME;
	audioFormat.mBytesPerFrame		= BYTES_PER_FRAME;
	
	bufferByteSize = 0x4000;
}

- (BOOL) getNextByte
{
	UInt8 byte;
	if(self.bytesToSend && [self.bytesToSend hasBytesAvailable])
	{
		if([self.bytesToSend read:&byte maxLength:1] <= 0)
			return NO;
		//NSLog(@"Sending byte: %c (%02X)", (char)byte, (unsigned)byte);
		bits = ((UInt16)byte << 1) | (0x3f << 9);
		bitCount = 14;
		return YES;
	}
	else if(hasQueuedBytes)
	{
		NSOutputStream* temp;
		@synchronized(self)
		{
			temp = self.queuedBytes;
			self.queuedBytes = [NSOutputStream outputStreamToMemory];
			[self.queuedBytes open];
			hasQueuedBytes = NO;
		}
		NSData *data = [temp propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
		//NSLog(@"Bytes to send: %@", [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]);
		self.bytesToSend = [NSInputStream inputStreamWithData:data];
		[self.bytesToSend open];
		
		return [self getNextByte];
	}
	
	bits = 1;	// Make sure the output is HIGH when there is no data
	return NO;
}

- (void) fillBuffer:(void*)buffer
{
	SAMPLE* sample = (SAMPLE*)buffer;
	/*
    BOOL underflow = NO;
	
	if(!bitCount)
		underflow = ![self getNextByte];
	*/
	for(int i=0; i<bufferByteSize; i += BYTES_PER_FRAME, sample++)
	{
		if(nsBitProgress >= BIT_PERIOD)
		{
			if(bitCount)
			{
				--bitCount;
				bits >>= 1;
			}
			nsBitProgress -= BIT_PERIOD;
			/*
            if(!bitCount)
				underflow = ![self getNextByte];
             */
		}
		
		sineTableIndex += (bits & 1)?TABLE_JUMP_HIGH:TABLE_JUMP_LOW;		
		if(sineTableIndex >= SINE_TABLE_LENGTH)
			sineTableIndex -= SINE_TABLE_LENGTH;
		*sample = sineTable[sineTableIndex];
		
		if(bitCount)
			nsBitProgress += SAMPLE_DURATION;
	}
	
}

- (void) writeByte:(UInt8)byte
{
	@synchronized(self)
	{
		[self.queuedBytes write:&byte maxLength:1];
		hasQueuedBytes = YES;
	}
}

@end
