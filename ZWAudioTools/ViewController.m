//
//  ViewController.m
//  ZWAudioTools
//
//  Created by ziwen on 16/05/2017.
//  Copyright © 2017 Baidu. All rights reserved.
//

#import "ViewController.h"
#import "ZWAudioTools.h"
#import "ZWMessage.h"
@interface ViewController ()<ZWAudioRecorderToolProtocool>

@property (weak, nonatomic) IBOutlet UILabel *volumeLabel;

@property (nonatomic, strong) ZWAudioPlayerTool *player;
@property (nonatomic, strong) ZWAudioRecorderTool *recorder;

@property (nonatomic, strong) ZWMessage *message;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didStopPlay:) name:ZWAudioEndPlay object:nil];

    // Do any additional setup after loading the view, typically from a nib.
}

-(ZWAudioRecorderTool *)recorder
{
    if (!_recorder)
    {
        _recorder = [ZWAudioRecorderTool new];
        _recorder.delegate = self;
    }
    return _recorder;
}

-(ZWAudioPlayerTool *)player
{
    if (!_player) {
        _player = [ZWAudioPlayerTool new];
        [_player registPlayer];
        __weak typeof(self)  weakSelf = self;
        _player.endStop = ^(const char *filePath) {
            if (filePath) {
                NSString *fileUrl = [NSString stringWithUTF8String:filePath];
                if ([fileUrl isEqualToString: weakSelf.message.domainPath]) {
                    weakSelf.message.readStatus = ZWFileMessageReadStatus_Normal;
                }
            }
        };

    }
    return _player;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startRecord:(UIButton *)sender {
    [self.recorder startRecord];
}

- (IBAction)cancelRecord:(UIButton *)sender {
    [self.recorder stopRecord];
}

- (IBAction)stopRecord:(UIButton *)sender {
    ZWRecordInfo info = [self.recorder stopRecord];
    if (info.filePath) {

        self.message = [ZWMessage new];
        self.message.duration = info.duration;
        self.message.domainPath = [NSString stringWithUTF8String:info.filePath];
    }
}

- (IBAction)startPlay:(UIButton *)sender {
    if (self.message.readStatus == ZWFileMessageReadStatus_Normal)
    {
        if (_message.domainPath.length > 0)
        {
            [self.player play:self.message.domainPath.UTF8String];
            self.message.readStatus = ZWFileMessageReadStatus_Reading;
        }
    }
    else
    {
        [self.player stop];
        self.message.readStatus = ZWFileMessageReadStatus_Normal;
        //stop animation
    }

}
- (IBAction)cancelPlay:(UIButton *)sender {
    [self.player stop];
    self.message.readStatus = ZWFileMessageReadStatus_Normal;
}
- (IBAction)stopPlay:(UIButton *)sender {
    [self.player stop];
    self.message.readStatus = ZWFileMessageReadStatus_Normal;
}

- (void)didStopPlay:(id)noti
{
    //stop animation
}

#pragma mark - ZWAudioRecorderToolProtocool -
- (void)audioTool:(ZWAudioRecorderTool *)helper volumeChanged:(float)volume duration:(float)duration
{
    NSLog(@"音量：%2f,时长：%ld", volume, (long)duration);
    _volumeLabel.text = [NSString stringWithFormat:@"%lld",(long long)(volume * 1000)];
}
@end
