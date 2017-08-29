//
//  TGAccessoryManager.h
//  ThinkGearTouch
//
//  Created by Horace Ko on 12/3/09.
//  Copyright 2009 NeuroSky, Inc.. All rights reserved.
//
//  The TGAccessoryManager class handles ThinkGear-enabled accessories connected to a device,
//  sending accessory connect/disconnect and data receipt notifications to a designated delegate.
//

#import "TGAccessoryDelegate.h"

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>
#import <UIKit/UIKit.h>

#pragma mark ThinkGear accessory types

enum {
    TGAccessoryTypeDongle = 0,
    TGAccessoryTypeAudioWired = 1,
    TGAccessoryTypeSimulated = 2
};
typedef NSUInteger TGAccessoryType;

@interface TGAccessoryManager : NSObject <EAAccessoryDelegate, NSStreamDelegate> {
    EAAccessory * accessory;
    EASession * session;
    
    BOOL connected;
    BOOL rawEnabled;
    
    id<TGAccessoryDelegate> delegate;
    NSTimeInterval dispatchInterval;
                 
    NSThread * notificationThread;
    uint8_t buffer[1024];
    NSInputStream * inputStream;
    NSOutputStream * outputStream;
    NSMutableDictionary * data;
    
    TGAccessoryType accessoryType;
    
    uint8_t * payloadBuffer;
    int payloadBytesRemaining;
    
    int rawPackets;
}

#pragma mark -
#pragma mark Properties


@property (nonatomic, readonly) EAAccessory * accessory;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, assign) id<TGAccessoryDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval dispatchInterval;
@property BOOL rawEnabled;

#pragma mark -
#pragma mark Messages

+ (TGAccessoryManager *)sharedTGAccessoryManager;
- (void)setupManagerWithInterval:(NSTimeInterval)dispatchIntervalOrNil;
- (void)setupManagerWithInterval:(NSTimeInterval)dispatchIntervalOrNil forAccessoryType:(TGAccessoryType)type;
- (void)teardownManager;
- (void)startStream;
- (void)stopStream;
- (int)getVersion;
@end
