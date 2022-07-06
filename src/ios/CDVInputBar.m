#import <Cordova/CDV.h>
#import "CDVInputBar.h"
#import "MXMp3Recorder.h"
#import "BBVoiceRecordController.h"
#import "UIImage+BBVoiceRecord.h"
#import "UIColor+BBVoiceRecord.h"
#import "BBHoldToSpeakButton.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AlignButton/AlignButton.h>
#define kFakeTimerDuration       0.2
#define kMaxRecordDuration       60     //最长录音时长
#define kRemainCountingDuration  10     //剩余多少秒开始倒计时

#define kInputBarHeight 36.0
#define kInputBarPadding 10.0
#define kInputBarTitleHeight 26.0

#define kChatBarHeight 48.0

#define kChatBarHeightDark 90.0


@interface CDVInputBar () <UITextFieldDelegate,UIScrollViewDelegate,UIGestureRecognizerDelegate,MXMp3RecorderDelegate>

@property (nonatomic, strong) BBVoiceRecordController *voiceRecordCtrl;
@property (nonatomic, strong) BBHoldToSpeakButton *voiceRecorderButton;
@property (nonatomic, assign) BBVoiceRecordState currentRecordState;
@property (nonatomic, strong) NSTimer *fakeTimer;
@property (nonatomic, assign) float duration;
@property (nonatomic, assign) BOOL canceled;
@property (nonatomic,readwrite) BOOL isStartRecord;
@property (nonatomic, strong) UILongPressGestureRecognizer* longTap;
@property (nonatomic, readwrite) NSTimeInterval startTime;
@property (nonatomic, readwrite) NSTimeInterval endTime;

@property (nonatomic,strong) CDVInvokedUrlCommand * chat_cdvcommand;
@property (nonatomic, readwrite) double KeyboardHeight;
@property (nonatomic,strong) UIView * chatBar;
@property (nonatomic, strong) UIButton* voiceButton;
@property (nonatomic, strong) UITextField* textField;
@property (nonatomic,readwrite) CGFloat inputBarHeight;     //关闭输入法时候 输入框高度
@property (nonatomic, readwrite) CGFloat chatExtbarHeight;  //聊天框扩展高度
@property (nonatomic, readwrite) NSArray* emoji_list;
@property (nonatomic,strong) UIButton * keyboardButton;
@property (nonatomic,strong) UIButton * emojiButton;
@property (nonatomic,strong) UIButton * moreButton;
@property (nonatomic, assign) BOOL isExtBarOpen;
@property (nonatomic,strong) UIView * emojiView;
@property (nonatomic,strong) UIView * moreView;

@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) UIPageControl *pageControl;

@end

@implementation CDVInputBar
- (void)pluginInitialize
{
    NSLog(@"--------------- init CDVInputBar --------");
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(onKeyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    [nc addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(onKeyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];

}

- (void)voiceButtonTap:(UIButton *)sender
{
    [self touchfeedback];
    [self resetChatBar];
    [_voiceButton setHidden:YES];
    [_textField resignFirstResponder];
    [_textField setHidden:YES];
    [_keyboardButton setHidden:NO];
    [_voiceRecorderButton setHidden:NO];
    _longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongTap:)];
    [self.viewController.view addGestureRecognizer:_longTap];
    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"busy"} Alive:YES State:YES];
}
-(void)resetChatBar
{
    CGRect r = [_chatBar frame];
    r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarHeight;
    r.size.height = _inputBarHeight;
    _isExtBarOpen = NO;
    [_emojiView setHidden:YES];
    [_moreView setHidden:YES];
    [_chatBar setFrame:r];
    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"resize",@"height": @(_inputBarHeight + _KeyboardHeight)} Alive:YES State:YES];
}

- (void)keyboardButtonTap:(UIButton *)sender
{
    [self touchfeedback];
    [self resetChatBar];
    [_textField becomeFirstResponder];
    [_voiceButton setHidden:NO];
    [_keyboardButton setHidden:YES];
    [_textField setHidden:NO];
    [_voiceRecorderButton setHidden:YES];
    [self.viewController.view removeGestureRecognizer:_longTap];
}
- (void)emojiButtonTap:(UIButton *)sender
{
    [self touchfeedback];
    [UIView animateWithDuration: 0.3 animations: ^(void){
        [self openExtBar:NO];
        [self.textField resignFirstResponder];
        [self.emojiView setHidden:NO];
        [self.moreView setHidden:YES];
    }];
}
- (void)moreButtonTap:(UIButton *)sender
{
    [self touchfeedback];
    [UIView animateWithDuration: 0.3 animations: ^(void){
        [self openExtBar:YES];
        [self.textField resignFirstResponder];
        [self.moreView setHidden:NO];
        [self.emojiView setHidden:YES];
    }];
}


-(void)openExtBar:(BOOL)type
{
    [_voiceButton setHidden:NO];
    [_keyboardButton setHidden:YES];
    [_voiceRecorderButton setHidden:YES];
    [_textField setHidden:NO];
    CGRect r = [_chatBar frame];
    CGFloat realExtHeight = _chatExtbarHeight;
    if(type){
        realExtHeight = _chatExtbarHeight / 2;
    }
    r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarHeight - realExtHeight;
    r.size.height = _inputBarHeight + realExtHeight;
    [_chatBar setFrame:r];
    _isExtBarOpen = YES;

    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"resize",@"height":@(_inputBarHeight + realExtHeight)} Alive:YES State:YES];
}

- (void)choseImage:(UITapGestureRecognizer *)sender {

    NSLog(@"emojiTap...");
    [self touchfeedback];
    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
    [message setObject:@"emoji" forKey:@"type"];
    [message setObject:@([sender.view tag]) forKey:@"emoji"];
    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [res setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult: res callbackId:_chat_cdvcommand.callbackId];
}
- (void)pageControlAction{
    CGFloat index = self.pageControl.currentPage;
    CGPoint point = CGPointMake(index*[UIScreen mainScreen].bounds.size.width, 0);
    [self.scrollView setContentOffset:point animated:YES];

}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat x = scrollView.contentOffset.x;
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    self.pageControl.currentPage = x/width;
}

-(void)moreButtonItemTap:(UIButton *)sender
{
    [self touchfeedback];
    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
    NSString *type;
    if(!sender.titleLabel.text){
        type = @"";
    }else{
        type = sender.titleLabel.text;
    }
    [message setObject: type  forKey:@"type"];
    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [res setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult: res callbackId:_chat_cdvcommand.callbackId];
}

- (void)createChatBar:(CDVInvokedUrlCommand *)command
{
    _chat_cdvcommand = command;
    CGFloat safeBottom =  UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    if(!_chatBar){
        NSDictionary *options = [command.arguments objectAtIndex: 0];

        _inputBarHeight = kChatBarHeight + safeBottom;
        _emoji_list = [options objectForKey:@"emoji"];
        CGFloat emojiWidth = (screenWidth - 6 * kInputBarPadding)/5;
        _chatExtbarHeight = emojiWidth * 4 + 5 * kInputBarPadding;

        _chatBar = [[UIView alloc] initWithFrame:CGRectMake(0.0, [UIScreen mainScreen].bounds.size.height , screenWidth, _inputBarHeight + 15 + _chatExtbarHeight)];
        _chatBar.backgroundColor = [self colorWithHex:0xFFFFFFFF];
        [self.viewController.view addSubview:_chatBar];

        CGFloat buttonWidth = kChatBarHeight - 2 * kInputBarPadding;
        _voiceButton = [[UIButton alloc] initWithFrame:CGRectMake(kInputBarPadding,kInputBarPadding,buttonWidth,buttonWidth)];
        [_voiceButton setImage:[UIImage imageNamed:@"ic-voice"] forState:UIControlStateNormal];

        [_voiceButton addTarget:self action:@selector(voiceButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_chatBar addSubview:_voiceButton];
        CGRect f;
        f = [_voiceButton frame];
        _keyboardButton = [[UIButton alloc] initWithFrame:f];
        [_keyboardButton setBackgroundImage:[UIImage imageNamed:@"ic-keyboard"] forState:UIControlStateNormal];

        [_keyboardButton addTarget:self action:@selector(keyboardButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_keyboardButton setHidden:YES];
        [_chatBar addSubview:_keyboardButton];

        CGFloat textFieldWidth = screenWidth - 3 * buttonWidth - 5 * kInputBarPadding;
        _textField = [[UITextField alloc] initWithFrame:CGRectMake(f.origin.x + buttonWidth + kInputBarPadding, kInputBarPadding, textFieldWidth,buttonWidth)];
        _textField.layer.cornerRadius = buttonWidth / 2;
        _textField.font = [UIFont systemFontOfSize:16];
        _textField.textColor = [UIColor blackColor];
        _textField.backgroundColor = [UIColor colorWithHex:0xf3f3f3 alpha:1];
        _textField.delegate = self;
        _textField.placeholder = [options objectForKey:@"placeholder"] ?: @"请输入...";
        UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 16.0, buttonWidth)];
        _textField.leftView = paddingView;
        _textField.rightView = paddingView;
        _textField.leftViewMode = UITextFieldViewModeAlways;
        _textField.rightViewMode = UITextFieldViewModeAlways;
        _textField.returnKeyType = UIReturnKeySend;
        [_chatBar addSubview:_textField];

        f = [_textField frame];
        _voiceRecorderButton = [[BBHoldToSpeakButton alloc] initWithFrame:f];
        [_voiceRecorderButton setBackgroundImage:[UIImage bb_imageWithColor:[UIColor colorWithHex:0xeeeeee alpha:0.5] withSize:CGSizeMake(1, 1)] forState:UIControlStateNormal];
        [_voiceRecorderButton setBackgroundImage:[UIImage bb_imageWithColor:[UIColor colorWithHex:0x666666 alpha:0.5] withSize:CGSizeMake(1, 1)] forState:UIControlStateHighlighted];

        _voiceRecorderButton.layer.cornerRadius = buttonWidth / 2;
        _voiceRecorderButton.layer.borderColor = [[UIColor blackColor] CGColor];
        _voiceRecorderButton.layer.borderWidth = 1.0f;
        _voiceRecorderButton.clipsToBounds = YES;
        _voiceRecorderButton.enabled = NO;
        _voiceRecorderButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
        [_voiceRecorderButton setTitleColor: [UIColor blackColor] forState:UIControlStateNormal];
        [_voiceRecorderButton setTitle:@"长按开始录音" forState:UIControlStateNormal];
        [_voiceRecorderButton setHidden:YES];
        [_chatBar addSubview:_voiceRecorderButton];


        _emojiButton = [[UIButton alloc] initWithFrame:CGRectMake(f.origin.x + textFieldWidth + kInputBarPadding ,kInputBarPadding, buttonWidth,buttonWidth)];
        [_emojiButton setBackgroundImage:[UIImage imageNamed:@"ic-emoji"] forState:UIControlStateNormal];
        [_emojiButton addTarget:self action:@selector(emojiButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_chatBar addSubview:_emojiButton];

        if([_emoji_list count] == 0){ //如果表情为空，隐藏表情按钮
            [_emojiButton setHidden:YES];
            f.size.width += (buttonWidth + kInputBarPadding);
            [_textField setFrame:f];
            [_voiceRecorderButton setFrame:f];
        }

        f = [_emojiButton frame];
        _moreButton = [[UIButton alloc] initWithFrame:CGRectMake(f.origin.x + buttonWidth + kInputBarPadding ,kInputBarPadding, buttonWidth,buttonWidth)];
        [_moreButton setBackgroundImage:[UIImage imageNamed:@"ic-more"] forState:UIControlStateNormal];
        [_moreButton addTarget:self action:@selector(moreButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_chatBar addSubview:_moreButton];


        f = [_chatBar frame];
        NSString * osspath = [options valueForKey:@"osspath"];
        _emojiView = [[UIView alloc] initWithFrame:CGRectMake(0.0,kChatBarHeight, screenWidth, _chatExtbarHeight)];

        self.scrollView = [[UIScrollView alloc] initWithFrame:_emojiView.bounds];
        self.scrollView.delegate = self;
        int page = ceil(_emoji_list.count / 24);
        if(_emoji_list.count % 24 > 0){
            page ++;
        }
        self.scrollView.contentSize = CGSizeMake(screenWidth*page, _chatExtbarHeight);
        [self.emojiView addSubview:self.scrollView];
        int w = round((screenWidth - 7*kInputBarPadding )/6);
        for (int i = 0; i < page; i++) {
            int line = -1;
            int c = 0; //当前行第几个
            int p = 0; //当前页第几个
            for(int j = i * 24; j< (i+1)*24; j++){
                if(j+1 > _emoji_list.count) break;
                if(p % 6 == 0) line ++ ;
                if(c >= 6) c = 0;
                NSLog(@"当前行第%d个 当前页第%d个 第%d行",c,p,line);
                NSString *img = [[NSString alloc]initWithFormat:@"%@%@",osspath,_emoji_list[j]];
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(kInputBarPadding + (w + kInputBarPadding) * c  +  i * screenWidth , kInputBarPadding + line * (w + kInputBarPadding)  , w, w)];
                [imageView setTag: j];
                [imageView setUserInteractionEnabled:YES];
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(choseImage:)];
                [imageView addGestureRecognizer:tap];
                imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:img]]];
                [self.scrollView addSubview:imageView];
                c++;
                p++;
            }
        }
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.pagingEnabled = YES;
        self.scrollView.bounces = YES;
        [_emojiView addSubview:self.scrollView];

        _isExtBarOpen = NO;
        [_emojiView setHidden:YES];
        [_chatBar addSubview:_emojiView];

        self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(50, _chatBar.bounds.size.height - kInputBarHeight - safeBottom - 15, screenWidth-100, 12)];
        self.pageControl.numberOfPages = page;
        self.pageControl.layer.cornerRadius = 3;
        self.pageControl.currentPageIndicatorTintColor = [UIColor orangeColor];
        self.pageControl.pageIndicatorTintColor = [UIColor grayColor];
        self.pageControl.currentPage = 0;
        [self.pageControl addTarget:self action:@selector(pageControlAction) forControlEvents:UIControlEventEditingChanged];
        [_chatBar addSubview:self.pageControl];

        _moreView = [[UIView alloc] initWithFrame:CGRectMake(0.0,kChatBarHeight, screenWidth, _chatExtbarHeight)];
        NSArray *moreButton = [options objectForKey:@"buttons"];
        CGFloat moreButtonWidth = (screenWidth - 5 * kInputBarPadding)/4;
        int i = 0;
        CGFloat row = 0.0;
        for (NSDictionary * button in moreButton) {

            if(i > 0 && i % 4 == 0) row = row + 1.0;
            AlignButton * btn =[[AlignButton alloc] initWithFrame :CGRectMake(kInputBarPadding + (i%4) * (kInputBarPadding + moreButtonWidth),
                                                                        kInputBarPadding + row * (kInputBarPadding + moreButtonWidth),
                                     moreButtonWidth,
                                     moreButtonWidth)];
            btn.alignType = AlignType_TextBottom;
            btn.padding = 5.0;
            [btn setImage: [UIImage imageNamed: [button objectForKey:@"icon"]] forState:UIControlStateNormal];
            btn.titleLabel.textAlignment = NSTextAlignmentCenter;
            [btn setTitle:[button objectForKey:@"title"] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:14.0];
            [btn setTitleColor: [self colorWithHex:0x333333FF] forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(moreButtonItemTap:) forControlEvents:UIControlEventTouchUpInside];
            [_moreView addSubview:btn];
            i ++ ;
        }

        [_moreView setHidden:YES];
        [_chatBar addSubview:_moreView];

        NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:2];
        [message setObject:@"inputbarShow" forKey:@"type"];

        [message setObject:@(_inputBarHeight) forKey:@"height"];
        CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [res setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult: res callbackId:_chat_cdvcommand.callbackId];
    }
    [UIView animateWithDuration: 0.1 animations: ^(void){
        CGRect r = [self.chatBar frame];
        r.origin.y = [UIScreen mainScreen].bounds.size.height - self.inputBarHeight;
        [self.chatBar setFrame:r];
    }];
}


- (void)onKeyboardWillHide:(NSNotification *)sender
{
    if (_chatBar){
        _KeyboardHeight = 0;
        if(!_isExtBarOpen){
            [self resetChatBar];
        }
    }
//    if (_inputbar){
//        CGRect r = [_inputbar frame];
//        r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarHeight;
//        r.size.height = _inputBarHeight;
//        [_inputbar setFrame:r];
//        [_backdropView removeFromSuperview];
//        [_inputTextField removeFromSuperview];
//        [_inputbar removeFromSuperview];
//        _inputbar = nil;
//        _cdvcommand = nil;
//    }
}

- (void)onKeyboardWillShow:(NSNotification *)note
{
    CGRect rect = [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat safeBottom =  UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    double height = rect.size.height;
//    if (_inputbar){
//        CGRect r = [_inputbar frame];
//        r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarHeight - height + safeBottom;
//        r.size.height = _inputBarHeight - safeBottom;
//        [_inputbar setFrame:r];
//    }
    if (_chatBar){
        _KeyboardHeight = height;
        if(_isExtBarOpen){
            _isExtBarOpen = NO;
            [_emojiView setHidden:YES];
            [_moreView setHidden:YES];
        }
        CGRect r = [_chatBar frame];
        r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarHeight - height + safeBottom;
        r.size.height = _inputBarHeight;
        [_chatBar setFrame:r];
        [self send_event:_chat_cdvcommand withMessage:@{@"type":@"resize",@"height": @(_inputBarHeight + _KeyboardHeight - safeBottom)} Alive:YES State:YES];
    }

}

- (void)onKeyboardDidShow:(NSNotification *)note
{

}

- (void)onKeyboardDidHide:(NSNotification *)sender
{

}


- (void)startFakeTimer
{
    if (_fakeTimer) {
        [_fakeTimer invalidate];
        _fakeTimer = nil;
    }
    self.fakeTimer = [NSTimer scheduledTimerWithTimeInterval:kFakeTimerDuration target:self selector:@selector(onFakeTimerTimeOut) userInfo:nil repeats:YES];
    [_fakeTimer fire];
}

- (void)stopFakeTimer
{
    if (_fakeTimer) {
        [_fakeTimer invalidate];
        _fakeTimer = nil;
    }
}

- (void)onFakeTimerTimeOut
{
    self.duration += kFakeTimerDuration;
    NSLog(@"+++duration+++ %f",self.duration);
    float remainTime = kMaxRecordDuration-self.duration;
    if ((int)remainTime == 0) {
        self.currentRecordState = BBVoiceRecordState_Ended;
        [self dispatchVoiceState];
        self.canceled = NO;
    }
    else if ([self shouldShowCounting]) {
        self.currentRecordState = BBVoiceRecordState_RecordCounting;
        [self dispatchVoiceState];
        [self.voiceRecordCtrl showRecordCounting:remainTime];
    }
    else
    {
        float fakePower = (float)(1+arc4random()%99)/100;
        [self.voiceRecordCtrl updatePower:fakePower];
    }
}

- (BOOL)shouldShowCounting
{
    if (self.duration >= (kMaxRecordDuration-kRemainCountingDuration) && self.duration < kMaxRecordDuration && self.currentRecordState != BBVoiceRecordState_ReleaseToCancel) {
        return YES;
    }
    return NO;
}

- (void)resetState
{
    [self stopFakeTimer];
    self.duration = 0;
    self.canceled = YES;
}

- (void)dispatchVoiceState
{
    if (_currentRecordState == BBVoiceRecordState_Recording) {
        self.canceled = NO;
        [self startFakeTimer];
    }
    else if (_currentRecordState == BBVoiceRecordState_Ended)
    {
        [self resetState];
    }
    [_voiceRecorderButton updateRecordButtonStyle:_currentRecordState];
    [self.voiceRecordCtrl updateUIWithRecordState:_currentRecordState];
}

- (BBVoiceRecordController *)voiceRecordCtrl
{
    if (_voiceRecordCtrl == nil) {
        _voiceRecordCtrl = [BBVoiceRecordController new];
    }
    return _voiceRecordCtrl;
}

#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;
{
    return YES;
}

#pragma mark MXMp3RecorderDelegate

- (void)mp3RecorderDidFailToRecord:(MXMp3Recorder *)recorder {
    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"error_time_short"} Alive:YES State:YES];
}

- (void)mp3RecorderDidBeginToConvert:(MXMp3Recorder *)recorder {
    NSLog(@"转换mp3中...");
}

- (void)mp3Recorder:(MXMp3Recorder *)recorder didFinishingConvertingWithMP3FilePath:(NSString *)filePath {
    if(_chat_cdvcommand){
        [self send_event:_chat_cdvcommand withMessage:@{@"event":@"filish",@"path": filePath,@"duration":@(_endTime - _startTime)} Alive:NO State:YES];
        return;
    }
    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"voice",@"duration":@(_endTime - _startTime),@"path":filePath} Alive:YES State:YES];
}




-(void)handleLongTap:(UILongPressGestureRecognizer *)sender
{
    CGPoint point = [sender locationInView: _chatBar];
    if(sender.state == UIGestureRecognizerStateEnded){
        if(_canceled){
            [MXMp3Recorder.shareInstance cancelRecording];
            [self send_event:_chat_cdvcommand withMessage:@{@"type":@"free"} Alive:YES State:YES];
            NSLog(@"录制取消");
        }else{
            if (CGRectContainsPoint(_voiceRecorderButton.frame, point)) {
                _endTime = [self timestamp];
                [MXMp3Recorder.shareInstance stopRecording];
                [self send_event:_chat_cdvcommand withMessage:@{@"type":@"free"} Alive:YES State:YES];
                NSLog(@"录制完成");
            }else{
                [MXMp3Recorder.shareInstance cancelRecording];
                [self send_event:_chat_cdvcommand withMessage:@{@"type":@"free"} Alive:YES State:YES];
                NSLog(@"录制取消");
            }
        }
        _isStartRecord = NO;
        self.currentRecordState = BBVoiceRecordState_Ended;
    }else{
        if (CGRectContainsPoint(_voiceRecorderButton.frame, point)) {
            if(!_isStartRecord){
                NSLog(@"开始录制");
                AudioServicesPlaySystemSound(1519);
                _isStartRecord = YES;
                _startTime = [self timestamp];
                MXMp3Recorder *recorder = MXMp3Recorder.shareInstance;
                recorder = [MXMp3Recorder recorderWithCachePath:nil delegate:self];
                // 开始录制音频
                [recorder startRecordingAndDecibelUpdate:NO];
                self.currentRecordState = BBVoiceRecordState_Recording;
            }
        }else{
            _canceled = YES;
            self.currentRecordState = BBVoiceRecordState_ReleaseToCancel;
        }
    }
    [self dispatchVoiceState];
    NSLog(@"handleLongTap!pointx:%f,y:%f",point.x,point.y);

}


#pragma mark 公共函数

- (void)send_event:(CDVInvokedUrlCommand *)command withMessage:(NSDictionary *)message Alive:(BOOL)alive State:(BOOL)state{
    if(!command) return;
    CDVPluginResult* res = [CDVPluginResult resultWithStatus: (state ? CDVCommandStatus_OK : CDVCommandStatus_ERROR) messageAsDictionary:message];
    if(alive) [res setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult: res callbackId: command.callbackId];
}

- (UIColor *) colorWithHex:(int)color {
    float red = (color & 0xff000000) >> 24;
    float green = (color & 0x00ff0000) >> 16;
    float blue = (color & 0x0000ff00) >> 8;
    float alpha = (color & 0x000000ff);
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha/255.0];
}

- (NSTimeInterval)timestamp
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceNow:0];
    return [date timeIntervalSince1970];
}

-(void)touchfeedback
{
    UIImpactFeedbackGenerator *feedBackGenertor = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedBackGenertor impactOccurred];
}

@end
