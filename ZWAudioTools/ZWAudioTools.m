//
//  BIMAudioTool.m
//  IMSDK
//
//  Created by ziwen on 12/04/2017.
//  Copyright © 2017 baidu. All rights reserved.
//

#import "ZWAudioTools.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#define AVNumberOfChannels  1

NSString *const ZWAudioStartRecord  = @"com.baidu.bim.audioStartRecord";
NSString *const ZWAudioEndRecord    = @"com.baidu.bim.audioEndRecord";
NSString *const ZWAudioStartPlay    = @"com.baidu.bim.audioStartPlay";
NSString *const ZWAudioEndPlay      = @"com.baidu.bim.audioEndPlay";
NSString *const ZWSpeakLoudly       = @"com.baidu.bim.speakLoudly";


@interface ZWAudioRecorderTool () <AVAudioRecorderDelegate>

@property (nonatomic, strong)NSTimer *durationTimer;//录音时间计时器

@property (nonatomic, assign, readwrite) float duration; //音频的时长

@property (nonatomic, strong) AVAudioRecorder *recorder;

@end

@implementation ZWAudioRecorderTool

+(BOOL)canRecord{
    __block BOOL bCanRecord = YES;
    if (([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending))//7.0以下系统（包含）默认开启录音输入功能
    {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
            [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
                bCanRecord = granted;
            }];
        }
    }
    return bCanRecord;
}

- (BOOL)startRecord{
  NSString *audioDirPath = [[self class] audioDirPath];

    if (nil == audioDirPath|| audioDirPath.length <= 0)
    {
        NSLog(@"audio Folder not exist");
        return NO;
    }

    if (self.recorder)
    {
        [self.recorder stop];
        [self.recorder deleteRecording];
        self.recorder = nil;
    }

    _duration = 0;

    NSString *fileName = [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970] ];
    NSString *filePath = [audioDirPath stringByAppendingFormat:@"/%@.m4a",fileName];

    NSDictionary *recordSetting = [[self class] recordSetting];

    NSError *error = nil;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:filePath] settings:recordSetting error:&error];
    if (error) {
        recordSetting = nil;
        self.recorder = nil;
        return NO;
    }

    self.recorder.meteringEnabled = YES;
    [self.recorder prepareToRecord];


    //Make the default sound route for the session be to use the speaker ,重定向音频，
    //Activate the customized audio session

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    NSError * sessionError;

    // //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&sessionError];
    [audioSession setActive:YES error:nil]; //激活音频会话类别

    if (sessionError)
    {
        [_recorder stop];
        [_recorder deleteRecording];
        _recorder = nil;
        return NO;
    }
#else
    UInt32 doChangeDefaultRoute = 1;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof (doChangeDefaultRoute), &doChangeDefaultRoute);
#endif

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.recorder) {
            [self.recorder record];
            _durationTimer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(detectionVoice) userInfo:nil repeats:YES];
        }
    });

    return YES;
}

- (void)detectionVoice
{
    [self.recorder updateMeters];//刷新音量数据
    _duration = [self.recorder currentTime];
    //获取音量的平均值  [recorder averagePowerForChannel:0];
    //音量的最大值  [recorder peakPowerForChannel:0];
    float volume = [self calculateVolume];

    if (self.delegate && [self.delegate respondsToSelector:@selector(audioTool:volumeChanged:duration:)])
    {
        [self.delegate audioTool:self volumeChanged:volume duration:self.duration];
    }
}


- (Float32)calculateVolume
{
    Float32 averagePowerOfChannels = 0;
    for (int i = 0; i < AVNumberOfChannels; i++)
    {
        //使用平均值
        averagePowerOfChannels += [self.recorder averagePowerForChannel:i];
    }

    //获取音量百分比.
    return pow(10, (0.05 * averagePowerOfChannels));
}

 //录音设置
+ (NSDictionary *)recordSetting{
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    //设置录音格式  AVFormatIDKey==kAudioFormatLinearPCM,或者kAudioFormatMPEG4AAC
    [recordSetting setObject:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    //设置录音采样率(Hz) 如：AVSampleRateKey==8000/44100/96000（影响音频的质量）
    [recordSetting setObject:[NSNumber numberWithFloat:8000] forKey:AVSampleRateKey];
     //录音通道数  1 或 2
    [recordSetting setObject:[NSNumber numberWithInt:AVNumberOfChannels] forKey:AVNumberOfChannelsKey];
     //线性采样位数  8、16、24、32
    [recordSetting setObject:[NSNumber numberWithInt:8] forKey:AVLinearPCMBitDepthKey];
    //录音的质量
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    return recordSetting;
}

+ (NSString *)audioDirPath
{
    NSString *cacheDirPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *audioDir = [cacheDirPath stringByAppendingPathComponent:@"com.baidu.cloudim/share/audio"];

    BOOL isDir;
    NSError *error;
    //没有创建文件夹
    if (![[NSFileManager defaultManager] fileExistsAtPath:audioDir isDirectory:&isDir] || !isDir){
        [[NSFileManager defaultManager] createDirectoryAtPath:audioDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error)
        {
            return nil;
        }
    }

    return audioDir;
}


- (ZWRecordInfo )stopRecord{
    ZWRecordInfo info;

    if (self.recorder) {
        [_recorder stop];

        info.duration = self.duration;
        info.filePath = [self.recorder.url relativePath].UTF8String;

        [_durationTimer invalidate];
        _durationTimer = nil;

        _recorder.delegate = nil;
        _recorder = nil;

        [[NSNotificationCenter defaultCenter] postNotificationName:ZWAudioEndRecord object:nil];
    }

    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    return info;
}

- (void)cancelRecord{
    [_durationTimer invalidate];
    _durationTimer = nil;

    _duration = 0;

    [_recorder stop];
    [_recorder deleteRecording];

    _recorder.delegate = nil;
    _recorder = nil;

    [[AVAudioSession sharedInstance] setActive:NO error:NULL];

}

#pragma mark - AVAudioRecorderDelegate -
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{

}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * __nullable)error{
    [self cancelRecord];
}

#if TARGET_OS_IPHONE

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder NS_DEPRECATED_IOS(2_2, 8_0){

}

- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags NS_DEPRECATED_IOS(6_0, 8_0){

}

#endif //TARGET_OS_IPHONE
@end


#pragma mark - ZWAudioPlayerTool -

//////////////////////////////////////////////////////////
//              BIMAudioPlayerTool 播放工具               //
//////////////////////////////////////////////////////////

@interface ZWAudioPlayerTool () <AVAudioPlayerDelegate>
{
   BOOL isSpeakLoudly;//当前是否是扬声器模式
}
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSString *filePathString;
@end

@implementation ZWAudioPlayerTool


- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 *	@brief	播放语音消息
 *
 *	@param 	filePath  语音路径
 */
- (BOOL)play:(const char *)filePath{
    [self stop];

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    NSError *error = nil;
    NSString *fileURLString = [NSString stringWithUTF8String:filePath];
    if (fileURLString.length <= 0)
    {
        return NO;
    }

    self.filePathString = fileURLString;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fileURLString] error:&error];

    if (error || nil == self.player)
    {
        return NO;
    }

    self.player.delegate = self;
    self.player.volume = 1.0f;
    [self.player play];

    [self startProximityMonitering];

    return YES;
}

/**
 *	@brief	停止播放语音消息
 */
- (void)stop{
    if (self.player){
        if (self.player.isPlaying){
            [self.player stop];
        }
        self.player = nil;
       // self.currentMessage.readStatus = BIMFileMessageReadStatus_Normal;
        [[AVAudioSession sharedInstance] setActive:NO error:nil];
        if (_endStop) {
            _endStop(self.filePathString.UTF8String);
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:ZWAudioEndPlay object:self.filePathString];
    }

    if ([UIDevice currentDevice].isProximityMonitoringEnabled) {
        if ([[UIDevice currentDevice] proximityState] == NO) {
            [self stopProximityMonitering];
        }
    }
    isSpeakLoudly = YES;
}

- (void)registPlayer{
    //注册光感通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sensorStateChange:)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
}

//建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应
- (void)startProximityMonitering {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    [self sensorStateChange:nil];
}

- (void)stopProximityMonitering {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    [self  resetOutputTarget];
}


//设备是否存在，耳麦，耳机等
- (BOOL)isHeadsetPluggedIn
{
    AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription *desc in [route outputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            return YES;
        }
        else  if([[desc portType] isEqualToString:AVAudioSessionPortHeadsetMic]) {
            return YES;
        }else {
            continue;
        }
    }
    return NO;
}

//检测是否有耳机，只需在route中是否有Headphone或Headset存在
- (BOOL)hasHeadset {
#if TARGET_IPHONE_SIMULATOR
    // #warning *** Simulator mode: audio session code works only on a device
    return NO;
#else

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    return [self isHeadsetPluggedIn];
#else
    CFStringRef route;
    UInt32 propertySize = sizeof(CFStringRef);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
    if((route == NULL) || (CFStringGetLength(route) == 0)){
        // Silent Mode
        //      NSLog(@"AudioRoute: SILENT, do nothing!");
    } else {
        NSString* routeStr = (__bridge NSString*)route;
        //    NSLog(@"AudioRoute: %@", routeStr);
        NSRange headphoneRange = [routeStr rangeOfString : @"Headphone"];
        NSRange headsetRange = [routeStr rangeOfString : @"Headset"];
        if (headphoneRange.location != NSNotFound) {
            return YES;
        } else if(headsetRange.location != NSNotFound) {
            return YES;
        }
    }
    return NO;
#endif

#endif
}

//拔出耳机，强制修改系统声音输出设备：
- (void)resetOutputTarget {
    BOOL hasHeadset = [self hasHeadset];
    NSLog(@"Will Set output target is_headset = %@ .", hasHeadset ? @"YES" : @"NO");
    //None：听筒,耳机   Speaker：扬声器
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    if (hasHeadset) {
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

        NSLog(@"isSpeakLoudly = no，贴近面部，屏幕变暗");
    }else {
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    }
#else
    UInt32 audioRouteOverride = hasHeadset ?kAudioSessionOverrideAudioRoute_None:kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(audioRouteOverride), &audioRouteOverride);
#endif
}

- (BOOL)isNotUseBuiltInPort{
    NSArray *outputs = [[AVAudioSession sharedInstance] currentRoute].outputs;
    if (outputs.count <= 0) {
        return NO;
    }
    AVAudioSessionPortDescription *port = (AVAudioSessionPortDescription*)outputs[0];

    return ![port.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]&&![port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker];
}

- (void)sensorStateChange:(NSNotification *)notification {
    if ([self isNotUseBuiltInPort])
    {
      //  BIMLogInfo(@"有耳机");
        return;//带上耳机不需要这个
    }

    if (self.player && self.player.isPlaying)
    {
        //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗
        if ([UIDevice currentDevice].isProximityMonitoringEnabled)
        {
            if ([[UIDevice currentDevice] proximityState] == YES)
            {
                isSpeakLoudly = NO;
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
               // NSLog(@"isSpeakLoudly = no，贴近面部，屏幕变暗");
            }
            else
            {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
             //   NSLog(@"isSpeakLoudly = yes,正常状态下，扬声器模式");

                if (!isSpeakLoudly)
                {
                    isSpeakLoudly = YES;

                    [[NSNotificationCenter defaultCenter] postNotificationName:ZWSpeakLoudly object:nil];
                }
            }
        }
    }
    else
    {
        [self stopProximityMonitering];
    }
}

- (void)sessionRouteChange:(NSNotification *)notification {
    NSTimeInterval currentTime = self.player.currentTime;

    AVAudioSessionRouteChangeReason routeChangeReason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (AVAudioSessionRouteChangeReasonNewDeviceAvailable == routeChangeReason) {//新设备插入
        if ([self isNotUseBuiltInPort]) {
            if (currentTime > 0.35) {
                currentTime = currentTime - 0.35; //插入耳机需要时间，切换默认减去0.35s，继续播放
            } else{
                currentTime = 0;
            }

            if (self.player && [self.player isPlaying]) {
                self.player.currentTime = currentTime;
            }

            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
            [[AVAudioSession sharedInstance]  setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        }
    }else if (AVAudioSessionRouteChangeReasonOldDeviceUnavailable == routeChangeReason) { //新设备拔出
        if (![self isNotUseBuiltInPort]) {
            //拔出耳机切换默认减去1s，继续播放
            if (currentTime > 1.0) {
                currentTime = currentTime - 1.0;
            }else {
                currentTime = 0;
            }

            if (self.player && self.player.isPlaying){
                self.player.currentTime = currentTime;
            }

            [self sensorStateChange:nil];
        }
    } else {
        //  NSLog(@"没有设备音频变化");
    }
}
//电话等中断程序
- (void)sessionInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType) {
        //        NSLog(@"begin interruption");
        //直接停止播放
        [self stop];
    }  else if (AVAudioSessionInterruptionTypeEnded == interruptionType) {
        //        NSLog(@"end interruption");
    }
}


#pragma mark - AVAudioPlayerDelegate -
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    [self stop];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error{
    [self stop];
}

    #if TARGET_OS_IPHONE
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player NS_DEPRECATED_IOS(2_2, 8_0){
  [self stop];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags NS_DEPRECATED_IOS(6_0, 8_0){

}

    #endif // TARGET_OS_IPHONE

@end



