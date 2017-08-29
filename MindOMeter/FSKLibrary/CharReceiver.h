//  CharReceiver.h
// Copyright 2010 PLX Devices Inc. All Rights Reserved


#import <Foundation/Foundation.h>


@protocol CharReceiver <NSObject>

- (void) receivedChar:(uint8_t)input;

@end
