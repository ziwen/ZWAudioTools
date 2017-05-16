//
//  ZWMessage.h
//  ZWAudioTools
//
//  Created by ziwen on 16/05/2017.
//  Copyright © 2017 Baidu. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 消息的阅读状态，多用于媒体消息
 */
typedef NS_ENUM(NSInteger, ZWFileMessageReadStatus) {
    /**
     *  正常状态
     */
    ZWFileMessageReadStatus_Normal,
    /**
     *  正在加载的状态
     */
    ZWFileMessageReadStatus_Loading,
    /**
     *  正在阅读状态
     */
    ZWFileMessageReadStatus_Reading
};


@interface ZWMessage : NSObject
/**
 *	@brief	媒体消息的当前读取状态
 */
@property (nonatomic, assign) ZWFileMessageReadStatus readStatus;

@property (nonatomic, strong) NSString *domainPath;
@property (nonatomic, assign) float duration;

@end
