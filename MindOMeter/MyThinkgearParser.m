//
//  MyThinkgearParser.m
//  MindOMeter
//
//  Created by Grant Patterson on 11/29/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "MyThinkgearParser.h"

@implementation MyThinkgearParser


+ (NSDictionary*)parsePacket:(uint8_t*)data length:(int)len {
    NSDictionary* dict = [[NSDictionary alloc] init];
    
    static BOOL tried = NO;
    if (tried) return dict;
    tried = YES;

    
    NSLog(@"Length %d, data %@", len, [[[NSData alloc] initWithBytes:data length:len] description]);
    
    int i = 0;
    
    while (i < len) {
        
        while (i < len && data[i] != 0xAA) {
            i++;
        }
        if (i + 1 >= len) {
            NSLog(@"Ran out of data");
            return dict;
        } else if (data[i + 1] != 0xAA) {
            NSLog(@"Didn't see packet start; trying from here");
            i += 1;
            continue;
        }/* else if (i > 0) {
          NSLog(@"Had to skip %d bytes to see packet start", i);
          }*/
        
        uint8_t packetLen = data[i + 2];
        if (len < packetLen + 4) {
            NSLog(@"data length is %d but packet length is %d", len, packetLen);
            return nil;
        }
        unsigned int total = 0;
        int checksumIdx = i + 3 + packetLen;
        for (i += 3; i < checksumIdx && i < len; i++) {
            //    for (i += 3; i < packetLen + 3 && i < len; i++) {
            //        NSLog(@"i %d, j %d, saw %02x", i, j, data[i + j]);
            // Parse this data row.
            total += (unsigned int)data[i];
            //NSLog(@"i %d, saw %02x, total now %d", i, data[i], total);
        }
        total = total & 0xFF;
        total = ~total & 0xFF;
        if (i >= len) {
            NSLog(@"Ran out of data");
            return nil;
        } else if (total != data[i]) {
            NSLog(@"Inverted lowest 8 bytes of payload sum %02x doesn't match checksum %02x", total, data[i]);
            return nil;
        }
        NSLog(@"This pass worked");
    }

    NSLog(@"SUCCESS!");
    return dict;
}

@end
