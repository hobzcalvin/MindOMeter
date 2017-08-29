//  FSKRecognizer.m
// Copyright 2010 PLX Devices Inc. All Rights Reserved


#import "FSKRecognizer.h"
#import "CharReceiver.h"
#import "lockfree.h"

struct FSKByteQueue: public lock_free::queue<uint8_t> {
	FSKByteQueue(): lock_free::queue<uint8_t>(20){};
};


@implementation FSKRecognizer
@synthesize receiver;

- (id) init
{
	if(self == [super init])
	{		
		byteQueue = new FSKByteQueue();
	}
	
	return self;
}

- (void) commitBytes
{
	uint8_t input;
	while (byteQueue->get(input))
	{
		[receiver receivedChar:input];
	}
}

- (void) dataBit:(BOOL)one
{
	if(one)
		bits |= (1 << bitPosition);
	bitPosition++;
}

- (void) freqRegion:(unsigned)length high:(BOOL)high
{
	FSKRecState newState = FSKFail;
	switch (state) {
		case FSKStart:
			if(!high)
			{
				//NSLog(@"Start bit: %c %d", high?'H':'L', length);
				newState = FSKBits;
			}
			else
				newState = FSKStart;
			break;
		case FSKBits:
			//NSLog(@"Bit: %c %d", high?'H':'L', length);
			[self dataBit:high];
			if(bitPosition == 8)
			{
				newState = FSKStart;
				byteQueue->put(bits);
				[self performSelectorOnMainThread:@selector(commitBytes)
									   withObject:nil
									waitUntilDone:NO];
				bits = 0;
				bitPosition = 0;
			}
			else
				newState = FSKBits;
			break;
        default:
            break;
	}
	state = newState;
}

- (void) halfWave:(unsigned)width
{
	for (int i = FSK_SMOOTH - 2; i >= 0; i--) {
		halfWaveHistory[i+1] = halfWaveHistory[i];
	}
	halfWaveHistory[0] = width;
	
	unsigned waveSum = 0;
	for(int i=0; i<FSK_SMOOTH; ++i)
	{
		waveSum += halfWaveHistory[i] * (FSK_SMOOTH - i);
	}
	
	BOOL high = (waveSum < DISCRIMINATOR);
	unsigned avgWidth = waveSum / SMOOTHER_COUNT;
	
	if (state == FSKStart)
	{
		if(!high)
		{
			recentLows += avgWidth;
		}
		else if(recentLows)
		{
			recentHighs += avgWidth;
			if(recentHighs > recentLows)
			{
//				NSLog(@"False start: %d", recentLows);
				recentLows = recentHighs = 0;
			}
		}
		
		if(recentLows + recentHighs >= BIT_PERIOD)
		{
			[self freqRegion:recentLows high:FALSE];
			if(recentLows < BIT_PERIOD)
			{
				recentLows = 0;
			}
			else
			{
				recentLows -= BIT_PERIOD;
			}
			if(!high)
				recentHighs = 0;
		}
	}
	else
	{
		if(high)
			recentHighs += avgWidth;
		else
			recentLows += avgWidth;
		
		if(recentLows + recentHighs >= BIT_PERIOD)
		{
			BOOL regionHigh = (recentHighs > recentLows);
			[self freqRegion:regionHigh?recentHighs:recentLows high:regionHigh];
			
			if(state == FSKStart)
			{
				// The byte ended, reset the accumulators
				recentLows = recentHighs = 0;
				return;
			}
			
			unsigned* matched = regionHigh?&recentHighs:&recentLows;
			unsigned* unmatched = regionHigh?&recentLows:&recentHighs;
			if(*matched < BIT_PERIOD)
			{
				*matched = 0;
			}
			else
			{
				*matched -= BIT_PERIOD;
			}
			if(high == regionHigh)
				*unmatched = 0;
		}		
	}	
}

- (void) edge: (int)height width:(UInt64)nsWidth interval:(UInt64)nsInterval
{
	if(nsInterval <= HWL_LOW + HWL_HIGH)
		[self halfWave:(unsigned)nsInterval];
}

- (void) idle: (UInt64)nsInterval
{
	[self reset];
}

- (void) reset
{
	bits = 0;
	bitPosition = 0;
	state = FSKStart;
	for (int i = 0; i < FSK_SMOOTH; i++) {
		halfWaveHistory[i] = (WL_HIGH + WL_LOW) / 4;
	}
	recentLows = recentHighs = 0;
}

- (void) dealloc
{
	if(byteQueue)
		delete byteQueue;
}

@end
