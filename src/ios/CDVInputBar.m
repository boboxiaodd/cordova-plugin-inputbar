#import <Cordova/CDV.h>
#import "CDVInputBar.h"

@interface CDVInputBar () <UITextFieldDelegate,UIScrollViewDelegate,UIGestureRecognizerDelegate>

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

- (void)onKeyboardWillHide:(NSNotification *)sender
{

}

- (void)onKeyboardWillShow:(NSNotification *)note
{

}

- (void)onKeyboardDidShow:(NSNotification *)note
{

}

- (void)onKeyboardDidHide:(NSNotification *)sender
{

}


@end
