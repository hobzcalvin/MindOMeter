//
//  MyThinkgearParser.h
//  MindOMeter
//
//  Created by Grant Patterson on 11/29/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyThinkgearParser : NSObject

+ (NSDictionary*)parsePacket:(uint8_t*)data length:(int)len;

@end
