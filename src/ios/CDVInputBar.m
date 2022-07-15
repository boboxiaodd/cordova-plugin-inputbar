#import <Cordova/CDV.h>
#import "CDVInputBar.h"
#import "MXMp3Recorder.h"
#import "BBVoiceRecordController.h"
#import "UIImage+BBVoiceRecord.h"
#import "UIColor+BBVoiceRecord.h"
#import "BBHoldToSpeakButton.h"
#import <AudioToolbox/AudioToolbox.h>
#import <SDWebImage/SDWebImage.h>
#define kFakeTimerDuration       0.2
#define kMaxRecordDuration       60     //最长录音时长
#define kRemainCountingDuration  10     //剩余多少秒开始倒计时

//#define kInputBarHeight 36.0
//#define kInputBarPadding 10.0
//#define kChatBarHeight 48.0

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
@property (nonatomic,readwrite) CGFloat kChatBarHeight;
@property (nonatomic,readwrite) CGFloat kInputBarPadding;
@property (nonatomic, readwrite) CGFloat chatExtbarHeight;  //聊天框扩展高度
@property (nonatomic, readwrite) NSArray* emoji_list;
@property (nonatomic,strong) UIButton * keyboardButton;
@property (nonatomic,strong) UIButton * emojiButton;
@property (nonatomic,strong) UIButton * moreButton;
@property (nonatomic, assign) BOOL isExtBarOpen;
@property (nonatomic,strong) UIView * emojiView;
@property (nonatomic,strong) UIView * moreView;
@property (nonatomic,assign) BOOL needfeedback; //是否需要点击反馈
@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) UIPageControl *pageControl;
@property (nonatomic, readwrite) NSString * filepath;


@property (nonatomic,strong) UIView * inputBar;
@property (nonatomic,strong) CDVInvokedUrlCommand * input_command;
@property (nonatomic,strong) UIView * backdropView;
@property (nonatomic,strong) UITextField * inputTextField;
@property (nonatomic,readwrite) int inputBarRealHeight;

@property (nonatomic,strong) CDVInvokedUrlCommand * record_command;
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
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *directoryPaths = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    NSURL *distPath = [[directoryPaths firstObject] URLByAppendingPathComponent:@"NoCloud/www/www"];
    _filepath = [distPath path];

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
    if(!_chatBar) return;
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
    [_pageControl setHidden:NO];
    [UIView animateWithDuration: 0.3 animations: ^(void){
        [self openExtBar];
        [self.textField resignFirstResponder];
        [self.emojiView setHidden:NO];
        [self.moreView setHidden:YES];
    }];
}
- (void)moreButtonTap:(UIButton *)sender
{
    [self touchfeedback];
    [_pageControl setHidden:YES];
    [UIView animateWithDuration: 0.3 animations: ^(void){
        [self openExtBar];
        [self.textField resignFirstResponder];
        [self.moreView setHidden:NO];
        [self.emojiView setHidden:YES];
    }];
}


-(void)openExtBar
{
    [_voiceButton setHidden:NO];
    [_keyboardButton setHidden:YES];
    [_voiceRecorderButton setHidden:YES];
    [_textField setHidden:NO];
    CGRect r = [_chatBar frame];
    r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarHeight - _chatExtbarHeight;
    r.size.height = _inputBarHeight + _chatExtbarHeight;
    [_chatBar setFrame:r];
    _isExtBarOpen = YES;

    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"resize",@"height":@(_inputBarHeight + _chatExtbarHeight)} Alive:YES State:YES];
}

- (void)choseImage:(UITapGestureRecognizer *)sender {

    NSLog(@"emojiTap...");
    [self touchfeedback];
    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"emoji",@"index":@([sender.view tag])} Alive:YES State:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat x = scrollView.contentOffset.x;
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    self.pageControl.currentPage = x/width;
}

-(void)moreButtonItemTap:(UIButton *)sender
{
    [self touchfeedback];
    [self send_event:_chat_cdvcommand withMessage:@{@"type":@"more",@"index":@([sender tag])} Alive:YES State:YES];
}

-(void)closeInputBar
{
    if(_inputBar){
        [_backdropView removeFromSuperview];
        [_inputTextField removeFromSuperview];
        [_inputBar removeFromSuperview];
        _inputBar = nil;
        _input_command = nil;
    }
}
-(void)closeInputBar:(UIView *)sender
{
    [self closeInputBar];
}

#pragma mark Cordova 接口


- (void)createChatBar:(CDVInvokedUrlCommand *)command
{
    _chat_cdvcommand = command;
    CGFloat safeBottom =  UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    if(!_chatBar){
        NSDictionary *options = [command.arguments objectAtIndex: 0];

        _kChatBarHeight = [[options objectForKey:@"height"] intValue];
        _needfeedback = [[options valueForKey:@"feedback"] boolValue];
        int text_color = [[options valueForKey:@"textcolor"] intValue] ?: 0x000000;
        int placeholder_color = [[options valueForKey:@"placeholder_color"] intValue] ?: 0x999999;
        int input_bgcolor = [[options valueForKey:@"input_bgcolor"] intValue] ?: 0xeeeeee;
        _inputBarHeight = _kChatBarHeight + safeBottom;
        _emoji_list = [options objectForKey:@"emoji"];
        NSString * ic_voice = [NSString stringWithFormat:@"%@/%@",_filepath , [[options objectForKey:@"icons"] valueForKey:@"ic_voice"]];
        NSString * ic_keyboard = [NSString stringWithFormat:@"%@/%@",_filepath , [[options objectForKey:@"icons"] valueForKey:@"ic_keyboard"]];
        NSString * ic_emoji = [NSString stringWithFormat:@"%@/%@",_filepath , [[options objectForKey:@"icons"] valueForKey:@"ic_emoji"]];
        NSString * ic_more = [NSString stringWithFormat:@"%@/%@",_filepath , [[options objectForKey:@"icons"] valueForKey:@"ic_more"]];
        int input_radius = [[options objectForKey:@"radius"] intValue];
        _kInputBarPadding = [[options objectForKey:@"padding"] intValue];
        CGFloat emojiWidth = (screenWidth - 6 * _kInputBarPadding)/5;
        _chatExtbarHeight = emojiWidth * 4 + 5 * _kInputBarPadding;

        _chatBar = [[UIView alloc] initWithFrame:CGRectMake(0.0, [UIScreen mainScreen].bounds.size.height , screenWidth, _inputBarHeight + 15 + _chatExtbarHeight)];
        _chatBar.backgroundColor = [self colorWithHex:0xFFFFFF];
        [self.viewController.view addSubview:_chatBar];

        CGFloat buttonWidth = _kChatBarHeight - 2 * _kInputBarPadding;
        _voiceButton = [[UIButton alloc] initWithFrame:CGRectMake(_kInputBarPadding,_kInputBarPadding,buttonWidth,buttonWidth)];
        UIImage * voice_img = [UIImage imageWithContentsOfFile:ic_voice];
        [_voiceButton setImage: voice_img forState:UIControlStateNormal];

        [_voiceButton addTarget:self action:@selector(voiceButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_chatBar addSubview:_voiceButton];
        CGRect f;
        f = [_voiceButton frame];
        _keyboardButton = [[UIButton alloc] initWithFrame:f];
        [_keyboardButton setBackgroundImage:[UIImage imageWithContentsOfFile:ic_keyboard] forState:UIControlStateNormal];

        [_keyboardButton addTarget:self action:@selector(keyboardButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_keyboardButton setHidden:YES];
        [_chatBar addSubview:_keyboardButton];

        CGFloat textFieldWidth = screenWidth - 3 * buttonWidth - 5 * _kInputBarPadding;
        _textField = [[UITextField alloc] initWithFrame:CGRectMake(f.origin.x + buttonWidth + _kInputBarPadding, _kInputBarPadding, textFieldWidth,buttonWidth)];
        if(input_radius){
            _textField.layer.cornerRadius = input_radius;
        }else{
            _textField.layer.cornerRadius = buttonWidth / 2;
        }
        _textField.font = [UIFont systemFontOfSize:16];
        _textField.textColor = [self colorWithHex:text_color];
        _textField.backgroundColor = [self colorWithHex:input_bgcolor];
        _textField.delegate = self;
        _textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:[options objectForKey:@"placeholder"] ?: @"请输入..."
                                                                           attributes:@{
                                                                              NSForegroundColorAttributeName: [UIColor colorWithHex:placeholder_color],
                                                                              NSFontAttributeName : [UIFont systemFontOfSize:16]
                                                                           }
                                                                         ];
        UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, _kInputBarPadding, buttonWidth)];
        _textField.leftView = paddingView;
        _textField.rightView = paddingView;
        _textField.leftViewMode = UITextFieldViewModeAlways;
        _textField.rightViewMode = UITextFieldViewModeAlways;
        _textField.returnKeyType = UIReturnKeySend;
        [_chatBar addSubview:_textField];

        f = [_textField frame];
        _voiceRecorderButton = [[BBHoldToSpeakButton alloc] initWithFrame:f];
        [_voiceRecorderButton setBackgroundImage:[UIImage bb_imageWithColor:[UIColor colorWithHex:0xeeeeee alpha:1] withSize:CGSizeMake(1, 1)] forState:UIControlStateNormal];
        [_voiceRecorderButton setBackgroundImage:[UIImage bb_imageWithColor:[UIColor colorWithHex:0x555555 alpha:1] withSize:CGSizeMake(1, 1)] forState:UIControlStateHighlighted];

        if(input_radius)
            _voiceRecorderButton.layer.cornerRadius = input_radius;
        else
            _voiceRecorderButton.layer.cornerRadius = buttonWidth / 2;
        _voiceRecorderButton.layer.borderColor = [[UIColor colorWithHex:0xeeeeee alpha:1] CGColor];
        _voiceRecorderButton.layer.borderWidth = 1.0f;
        _voiceRecorderButton.clipsToBounds = YES;
        _voiceRecorderButton.enabled = NO;
        _voiceRecorderButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
        [_voiceRecorderButton setTitleColor: [UIColor blackColor] forState:UIControlStateNormal];
        [_voiceRecorderButton setTitle:@"按住说话" forState:UIControlStateNormal];
        [_voiceRecorderButton setHidden:YES];
        [_chatBar addSubview:_voiceRecorderButton];


        _emojiButton = [[UIButton alloc] initWithFrame:CGRectMake(f.origin.x + textFieldWidth + _kInputBarPadding ,_kInputBarPadding, buttonWidth,buttonWidth)];
        [_emojiButton setBackgroundImage:[UIImage imageWithContentsOfFile:ic_emoji] forState:UIControlStateNormal];
        [_emojiButton addTarget:self action:@selector(emojiButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_chatBar addSubview:_emojiButton];

        if([_emoji_list count] == 0){ //如果表情为空，隐藏表情按钮
            [_emojiButton setHidden:YES];
            f.size.width += (buttonWidth + _kInputBarPadding);
            [_textField setFrame:f];
            [_voiceRecorderButton setFrame:f];
        }

        f = [_emojiButton frame];
        _moreButton = [[UIButton alloc] initWithFrame:CGRectMake(f.origin.x + buttonWidth + _kInputBarPadding ,_kInputBarPadding, buttonWidth,buttonWidth)];
        [_moreButton setBackgroundImage:[UIImage imageWithContentsOfFile:ic_more] forState:UIControlStateNormal];
        [_moreButton addTarget:self action:@selector(moreButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [_chatBar addSubview:_moreButton];


        f = [_chatBar frame];
        NSString * osspath = [options valueForKey:@"osspath"];
        _emojiView = [[UIView alloc] initWithFrame:CGRectMake(0.0,_kChatBarHeight, screenWidth, _chatExtbarHeight)];

        self.scrollView = [[UIScrollView alloc] initWithFrame:_emojiView.bounds];
        self.scrollView.delegate = self;
        int page = ceil(_emoji_list.count / 24);
        if(_emoji_list.count % 24 > 0){
            page ++;
        }
        self.scrollView.contentSize = CGSizeMake(screenWidth*page, _chatExtbarHeight);
        [self.emojiView addSubview:self.scrollView];
        int w = round((screenWidth - 7*_kInputBarPadding )/6);
        for (int i = 0; i < page; i++) {
            int line = -1;
            int c = 0; //当前行第几个
            int p = 0; //当前页第几个
            for(int j = i * 24; j< (i+1)*24; j++){
                if(j+1 > _emoji_list.count) break;
                if(p % 6 == 0) line ++ ;
                if(c >= 6) c = 0;
                NSString *img = [[NSString alloc]initWithFormat:@"%@%@",osspath,_emoji_list[j]];
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(_kInputBarPadding + (w + _kInputBarPadding) * c  +  i * screenWidth , _kInputBarPadding + line * (w + _kInputBarPadding)  , w, w)];
                [imageView setTag: j];
                [imageView setUserInteractionEnabled:YES];
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(choseImage:)];
                [imageView addGestureRecognizer:tap];
                [imageView sd_setImageWithURL:[NSURL URLWithString:img]];
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

        self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(50, _chatBar.bounds.size.height - _kChatBarHeight - safeBottom - 15, screenWidth-100, 12)];
        self.pageControl.numberOfPages = page;
        self.pageControl.layer.cornerRadius = 3;
        self.pageControl.currentPageIndicatorTintColor = [UIColor orangeColor];
        self.pageControl.pageIndicatorTintColor = [UIColor grayColor];
        self.pageControl.currentPage = 0;
        self.pageControl.userInteractionEnabled = NO;
//        [self.pageControl addTarget:self action:@selector(pageControlAction) forControlEvents:UIControlEventEditingChanged];
        [_chatBar addSubview:self.pageControl];

        _moreView = [[UIView alloc] initWithFrame:CGRectMake(0.0,_kChatBarHeight, screenWidth, _chatExtbarHeight)];
        NSArray *moreButton = [options objectForKey:@"buttons"];
        CGFloat moreButtonWidth = (screenWidth - 5 * 2 * _kInputBarPadding)/4;
        int i = 0;
        CGFloat row = 0.0;
        for (NSDictionary * button in moreButton) {

            if(i > 0 && i % 4 == 0) row = row + 1.0;

                UIButton * btn = [[UIButton alloc] initWithFrame:CGRectMake(_kInputBarPadding*2 + (i%4) * (_kInputBarPadding*2 + moreButtonWidth),
                                                                          _kInputBarPadding*2 + row * (_kInputBarPadding*5 + moreButtonWidth),
                                                                          moreButtonWidth,
                                                                          moreButtonWidth)];
                NSString * path = [NSString stringWithFormat:@"%@/%@",_filepath , [button objectForKey:@"icon"]];
                [btn setImage: [UIImage imageWithContentsOfFile:path] forState:UIControlStateNormal];
                [btn setTag: i];
                [btn addTarget:self action:@selector(moreButtonItemTap:) forControlEvents:UIControlEventTouchUpInside];
                [_moreView addSubview:btn];
                CGRect btnf = btn.frame;
                UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(btnf.origin.x, btnf.origin.y +  moreButtonWidth + _kInputBarPadding, moreButtonWidth, 20)];
                [label setFont:[UIFont systemFontOfSize: 12]];
                [label setTextColor:[UIColor grayColor]];
                [label setText:[button objectForKey:@"title"]];
                [label setTextAlignment:NSTextAlignmentCenter];
                [_moreView addSubview:label];
                i ++ ;
        }

        [_moreView setHidden:YES];
        [_chatBar addSubview:_moreView];
        [self send_event:_chat_cdvcommand withMessage:@{@"type":@"inputbarShow",@"height":@(_inputBarHeight)} Alive:YES State:YES];
    }
    [UIView animateWithDuration: 0.1 animations: ^(void){
        CGRect r = [self.chatBar frame];
        r.origin.y = [UIScreen mainScreen].bounds.size.height - self.inputBarHeight;
        [self.chatBar setFrame:r];
    }];
}

- (void)change_textField_placeholder:(CDVInvokedUrlCommand *)command
{
    if(_textField){
        NSDictionary *options = [command.arguments objectAtIndex: 0];
        _textField.placeholder = [options objectForKey:@"placeholder"] ?: @"请输入...";
    }
}

-(void)resetChatBar:(CDVInvokedUrlCommand *)command
{
    [self resetChatBar];
}
- (void)closeChatBar:(CDVInvokedUrlCommand *)command
{
    if(_chatBar){
        _chat_cdvcommand = nil;
        [self.textField removeFromSuperview];
        [self.chatBar removeFromSuperview];
        self.chatBar = nil;
        if(self->_longTap){
            [self.viewController.view removeGestureRecognizer:self->_longTap];
            self->_longTap = nil;
        }
    }
}


- (void)showInputBar:(CDVInvokedUrlCommand *)command
{
    if (_inputBar) return;
    NSDictionary *options = [command.arguments objectAtIndex: 0];
    _input_command = command;

    BOOL is_send = [[options valueForKey:@"is_send"] boolValue] || NO;
    _kInputBarPadding = [[options valueForKey:@"padding"] intValue];
    int InputBarHeight = [[options valueForKey:@"height"] intValue];
    int InputBarTitleHeight = [[options valueForKey:@"titleHeight"] intValue];
    int bgcolor = [[options valueForKey:@"bgcolor"] intValue] ?: 0xffffff;
    int radius = [[options valueForKey:@"radius"] intValue];
    int text_color = [[options valueForKey:@"textcolor"] intValue] ?: 0x000000;
    int placeholder_color = [[options valueForKey:@"placeholder_color"] intValue] ?: 0x999999;
    int input_bgcolor = [[options valueForKey:@"input_bgcolor"] intValue] ?: 0xf3f3f3;
    //Draw backdrop
    _backdropView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _backdropView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
    [_backdropView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeInputBar:)]];
    [self.viewController.view addSubview:_backdropView];

    //Draw InputBar
    CGFloat safeBottom =  UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;

    _inputBarRealHeight = _kInputBarPadding * 3 + InputBarHeight + InputBarTitleHeight + safeBottom;

    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGRect inputBarRect = CGRectMake(0.0, screen.height - _inputBarRealHeight, screen.width, _inputBarRealHeight);
    _inputBar = [[UIView alloc] initWithFrame: inputBarRect];
    _inputBar.backgroundColor = [self colorWithHex:bgcolor];
    [self.viewController.view addSubview:_inputBar];

    if(InputBarTitleHeight > 0){

        UILabel * titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(_kInputBarPadding + 3, _kInputBarPadding,
                                                                         screen.width - _kInputBarPadding * 2 - 3,
                                                                         InputBarTitleHeight)];
        titleLabel.text = [options valueForKey:@"title"] ?: @"请输入...";
        titleLabel.font = [UIFont systemFontOfSize:14.0];
        titleLabel.textColor = [UIColor grayColor];
        [_inputBar addSubview:titleLabel];
    }

    //Draw textField
    CGFloat textFieldWidth = screen.width - _kInputBarPadding * 2;
    CGRect textFieldRect = CGRectMake(_kInputBarPadding, _kInputBarPadding * 2 + InputBarTitleHeight,
                                      textFieldWidth,
                                      InputBarHeight);
    _inputTextField = [[UITextField alloc] initWithFrame:textFieldRect];
    _inputTextField.layer.cornerRadius = radius;
    _inputTextField.backgroundColor = [self colorWithHex:input_bgcolor];
    _inputTextField.delegate = self;
    _inputTextField.textColor = [self colorWithHex:text_color];
    _inputTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:[options objectForKey:@"placeholder"] ?: @"请输入..."
                                                                       attributes:@{
                                                                          NSForegroundColorAttributeName: [UIColor colorWithHex:placeholder_color],
                                                                          NSFontAttributeName : [UIFont systemFontOfSize:16]
                                                                       }
                                                                     ];


    _inputTextField.text = [options valueForKey:@"text"] ?: @"";
    if(is_send){
        _inputTextField.returnKeyType = UIReturnKeySend;
    }else{
        _inputTextField.returnKeyType = UIReturnKeyDone;
    }

    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, _kInputBarPadding, _kInputBarPadding)];
    _inputTextField.leftView = paddingView;
    _inputTextField.rightView = paddingView;
    _inputTextField.leftViewMode = UITextFieldViewModeAlways;
    _inputTextField.rightViewMode = UITextFieldViewModeAlways;

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screen.width, 1.0)];
    borderView.backgroundColor = [UIColor colorWithHex:0xEEEEEEFF];
    [_inputBar addSubview: borderView];
    [_inputBar addSubview: _inputTextField];

    [_inputTextField becomeFirstResponder];
}


-(void)start_voice_record:(CDVInvokedUrlCommand *)command
{

    NSLog(@"开始录制");
    _record_command = command;
    _startTime = [self timestamp];
    MXMp3Recorder.shareInstance.cachePath = nil;
    MXMp3Recorder.shareInstance.delegate = self;
    [MXMp3Recorder.shareInstance startRecordingAndDecibelUpdate:NO];
    [self send_event:_record_command withMessage:@{@"type":@"start"} Alive:YES State:YES];

}
-(void)stop_voice_record:(CDVInvokedUrlCommand *)command
{
    _endTime = [self timestamp];
    [MXMp3Recorder.shareInstance stopRecording];
}



#pragma mark Keyboard Event

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if(_chatBar){
        [self send_event:_chat_cdvcommand withMessage:@{@"type":@"send",@"text":textField.text} Alive:YES State:YES];
        [_textField setText:@""];
    }
    if(_inputBar){
        [self send_event:_input_command withMessage:@{@"type":@"send",@"text":textField.text} Alive:NO State:YES];
        [self closeInputBar];
    }
    return true;
}

- (void)onKeyboardWillHide:(NSNotification *)sender
{
    if (_inputBar){
        [self closeInputBar];
        return;
    }
    if (_chatBar){
        _KeyboardHeight = 0;
        if(!_isExtBarOpen){
            [self resetChatBar];
        }
    }
}

- (void)onKeyboardWillShow:(NSNotification *)note
{
    CGRect rect = [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat safeBottom =  UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    double height = rect.size.height;
    if (_inputBar){
        CGRect r = [_inputBar frame];
        r.origin.y = [UIScreen mainScreen].bounds.size.height - _inputBarRealHeight - height + safeBottom;
        r.size.height = _inputBarRealHeight - safeBottom;
        [_inputBar setFrame:r];
    }
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
    if(_chat_cdvcommand) [self send_event:_chat_cdvcommand withMessage:@{@"type":@"error_time_short"} Alive:YES State:YES];
    if(_record_command) [self send_event:_record_command withMessage:@{@"type":@"error_time_short"} Alive:YES State:YES];
}

- (void)mp3RecorderDidBeginToConvert:(MXMp3Recorder *)recorder {
    NSLog(@"转换mp3中...");
}

- (void)mp3Recorder:(MXMp3Recorder *)recorder didFinishingConvertingWithMP3FilePath:(NSString *)filePath {
    NSLog(@"转换完成 %@",filePath);
    if(_chat_cdvcommand) [self send_event:_chat_cdvcommand withMessage:@{@"type":@"voice",@"path": filePath,@"duration":@(_endTime - _startTime)} Alive:YES State:YES];
    if(_record_command) [self send_event:_record_command withMessage:@{@"type":@"voice",@"duration":@(_endTime - _startTime),@"path":filePath} Alive:NO State:YES];
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
    float red = (color & 0xff0000) >> 16;
    float green = (color & 0x00ff00) >> 8;
    float blue = (color & 0x0000ff);
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1];
}

- (NSTimeInterval)timestamp
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceNow:0];
    return [date timeIntervalSince1970];
}

-(void)touchfeedback
{
    if(!_needfeedback) return;
    UIImpactFeedbackGenerator *feedBackGenertor = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedBackGenertor impactOccurred];
}

@end
