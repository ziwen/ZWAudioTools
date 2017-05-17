//
//  BIMAudioTool.h
//  IMSDK
//
//  Created by ziwen on 12/04/2017.
//  Copyright © 2017 baidu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
////////////////////////////////////////////////////
//
//                 语音工具类                       //
//
////////////////////////////////////////////////////
@class ZWAudioRecorderTool;
@protocol ZWAudioRecorderToolProtocool <NSObject>

/**
 *	@brief	当音量发生变化时, 会收到回调
 *
 *	@param 	helper 	语音消息实例
 *	@param 	volume 	变化后的音量
  *	@param 	duration 	录音时长
 */
- (void)audioTool:(ZWAudioRecorderTool *)helper volumeChanged:(float)volume duration:(float)duration;

@end

typedef struct ZWRecordInfo_t
{
   const char *filePath;// urf 8
    float duration;
    
} ZWRecordInfo;

@interface ZWAudioRecorderTool : NSObject


@property (nonatomic, weak)id <ZWAudioRecorderToolProtocool> delegate;

@property (nonatomic, assign, readonly)float duration;
/**
 *	@brief	用户是否开启录音权限
 *
 *	@return	是否开启录音，yes:开启，no:禁用，仅适用与iOS7及以后,iOS 7之前默认开启
 */
+ (BOOL)canRecord;

/**
 *	@brief	开始录制
 *  @return 录制成功还是失败
 */
- (BOOL)startRecord;

/**
 *	@brief	停止录制
 *
 *	@return	录制完成后得到的语音消息
 */
- (ZWRecordInfo)stopRecord;

/**
 *	@brief	取消录制
 */
- (void)cancelRecord;

@end


////////////////////////////////////////////////////////////////
//
//                    播放语音
//
////////////////////////////////////////////////////////////////

typedef void(^EndStop)(const char *);

@interface ZWAudioPlayerTool : NSObject

@property (nonatomic, copy) EndStop endStop;

/**
 *	@brief	播放语音消息
 *
 *	@param 	filePath 	语音路径
 *  @return 播放成功还是失败
 */

- (BOOL)play:(const char *)filePath;

/**
 *	@brief	停止播放语音消息
 */
- (void)stop;
/**
 *	@brief	注册近距离传感器，耳机检测
 */
- (void)registPlayer;

@end



/**
 *  开启一次语音录制的通知
 */
extern NSString *const ZWAudioStartRecord;
/**
 *  结束一次录音的通知，返回参数
 */
extern NSString *const ZWAudioEndRecord;

/**
 *  @brief  开始一次语音播放的通知
 */
extern NSString *const ZWAudioStartPlay;
/**
 *  @brief  结束一次语音播放的通知
 */
extern NSString *const ZWAudioEndPlay;

/**
 *  @brief  切换扬声器的通知
 */
extern NSString * const ZWSpeakLoudly;



