// Modified By @Waa

#import "AwemeHeaders.h"
#import "DYYYBottomAlertView.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 外观功能

// 调整评论区透明度
static BOOL WaaViewContainsVisibleSendDUXButton(UIView *view) {
    if (!view || view.hidden || view.alpha <= 0.01) {
        return NO;
    }

    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"DUXButton"] && CGRectGetWidth(view.frame) > 0 && CGRectGetHeight(view.frame) > 0) {
        UIButton *button = [view isKindOfClass:[UIButton class]] ? (UIButton *)view : nil;
        NSString *title = [button titleForState:UIControlStateNormal];
        return title.length == 0 || [title containsString:@"发送"];
    }

    for (UIView *subview in view.subviews) {
        if (WaaViewContainsVisibleSendDUXButton(subview)) {
            return YES;
        }
    }
    return NO;
}

static BOOL WaaCommentInputContainerIsCompactBottomBar(UIView *view) {
    if (!view) {
        return NO;
    }

    CGRect windowFrame = view.window ? [view convertRect:view.bounds toView:view.window] : view.frame;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    if (screenHeight <= 0 || CGRectGetWidth(windowFrame) <= 0 || CGRectGetHeight(windowFrame) <= 0) {
        return NO;
    }

    // 只在键盘展开后的底部紧凑输入栏跳过透明度；键盘收起后的大容器继续走透明度修改
    CGFloat height = CGRectGetHeight(windowFrame);
    CGFloat minY = CGRectGetMinY(windowFrame);
    return minY > screenHeight * 0.7 && height <= 140.0;
}

static void WaaInputLog(UIView *targetView, UIView *containerView, BOOL hasSendButton, BOOL isCompactBar, BOOL willSkip) {
    static NSInteger logCount = 0;
    if (logCount >= 120) {
        return;
    }
    logCount++;

    CGRect containerFrame = containerView ? containerView.frame : CGRectZero;
    CGRect windowFrame = containerView ? (containerView.window ? [containerView convertRect:containerView.bounds toView:containerView.window] : containerView.frame) : CGRectZero;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat midY = CGRectGetMidY(windowFrame);
    NSLog(@"[DYYY][WaaInput] target=%@ targetFrame=%@ container=%@ containerFrame=%@ windowFrame=%@ midY=%.1f screen=%.1f hasSend=%d compactBar=%d willSkip=%d",
          NSStringFromClass([targetView class]), NSStringFromCGRect(targetView.frame),
          containerView ? NSStringFromClass([containerView class]) : @"nil", NSStringFromCGRect(containerFrame), NSStringFromCGRect(windowFrame),
          midY, screenHeight, hasSendButton, isCompactBar, willSkip);
}

@interface UIView(Comment)
- (void)setBackgroundColor:(UIColor *)backgroundColor;
@end

%hook UIView
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    CGFloat transparency = 1.0;

    UIView *superview = self.superview;
    while (superview) {
        superview = superview.superview;
    }

    superview = self.superview;
    BOOL isTargetMiddleContainer = [self isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer")];
    BOOL isTargetCommentContainer = [self isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")];
    BOOL isFirstChildOfMiddleContainer = NO;
    BOOL isFirstChildOfCommentContainer = NO;
    BOOL inputContainerHasSendButton = NO;
    BOOL inputContainerIsCompactBar = NO;
    UIView *inputContainerView = nil;

    if (isTargetCommentContainer) {
        inputContainerView = self;
        inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(self);
        inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(self);
    } else if (isTargetMiddleContainer) {
        inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(self);
        UIView *parentView = self.superview;
        while (parentView) {
            if ([parentView isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")]) {
                inputContainerView = parentView;
                inputContainerHasSendButton = inputContainerHasSendButton || WaaViewContainsVisibleSendDUXButton(parentView);
                inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(parentView);
                break;
            }
            parentView = parentView.superview;
        }
    }
    
    while (!isTargetMiddleContainer && !isTargetCommentContainer && superview && !(isFirstChildOfMiddleContainer || isFirstChildOfCommentContainer)) {
        if ([superview isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer")]) {
            isFirstChildOfMiddleContainer = (superview.subviews.firstObject == self);
            inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(superview);
            UIView *parentView = superview.superview;
            while (parentView) {
                if ([parentView isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")]) {
                    inputContainerView = parentView;
                    inputContainerHasSendButton = inputContainerHasSendButton || WaaViewContainsVisibleSendDUXButton(parentView);
                    inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(parentView);
                    break;
                }
                parentView = parentView.superview;
            }
        }
        else if ([superview isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")]) {
            inputContainerView = superview;
            isFirstChildOfCommentContainer = (superview.subviews.firstObject == self);
            inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(superview);
            inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(superview);
        }
        superview = superview.superview;
    }

    UIResponder *responder = self.nextResponder;
    BOOL isInCommentPanel = [responder isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")];

    BOOL shouldSkipInputTransparency = (isTargetCommentContainer || isTargetMiddleContainer || isFirstChildOfCommentContainer || isFirstChildOfMiddleContainer) && inputContainerHasSendButton && inputContainerIsCompactBar;
    if (isTargetCommentContainer || isTargetMiddleContainer || isFirstChildOfCommentContainer || isFirstChildOfMiddleContainer) {
        WaaInputLog(self, inputContainerView, inputContainerHasSendButton, inputContainerIsCompactBar, shouldSkipInputTransparency);
    }

    if (shouldSkipInputTransparency) {
        %orig(backgroundColor);
        return;
    }

    if ((isTargetCommentContainer || isFirstChildOfCommentContainer) && !DYYYGetBool(@"DYYYEnableCommentBlur")) {
        NSString *transparencyStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"WaaInputBoxTransparency"];
        if (transparencyStr.length > 0) {
            transparency = [transparencyStr floatValue];
            transparency = MAX(0.0, MIN(1.0, transparency));
        }

        CGFloat r, g, b, a;
        if ([backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
            backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:transparency];
        } else {
            backgroundColor = [backgroundColor colorWithAlphaComponent:transparency];
        }
    } 
    else if ((isTargetMiddleContainer || isFirstChildOfMiddleContainer) && !DYYYGetBool(@"DYYYEnableCommentBlur")) {
        NSString *transparencyStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"WaaInputBoxTransparency"];
        if (transparencyStr.length > 0) {
            transparency = [transparencyStr floatValue];
            transparency = MAX(0.0, MIN(1.0, transparency));
        }

        CGFloat r, g, b, a;
        if ([backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
            backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:transparency];
        } else {
            backgroundColor = [backgroundColor colorWithAlphaComponent:transparency];
        }
    }
    else if (isInCommentPanel && !DYYYGetBool(@"DYYYEnableCommentBlur")) {
        NSString *transparencyStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"WaaCommentTransparency"];
        if (transparencyStr.length > 0) {
            transparency = [transparencyStr floatValue];
            transparency = MAX(0.0, MIN(1.0, transparency));
        }

        CGFloat r, g, b, a;
        if ([backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
            backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:transparency];
        } else {
            backgroundColor = [backgroundColor colorWithAlphaComponent:transparency];
        }
    }

    %orig(backgroundColor);
}
%end

// 调整评论区文字颜色
UIColor *darkerColorForColor(UIColor *color) {
    CGFloat hue, saturation, brightness, alpha;
    if ([color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness * 0.9 alpha:alpha];
    }
    return color;
}

@interface UIView (CustomColor)
- (void)traverseSubviews:(UIView *)view customColor:(UIColor *)customColor;
- (void)updateActionViewLabelColorRecursive:(UIView *)view;
@end

@implementation UIView (CustomColor)

- (void)traverseSubviews:(UIView *)view customColor:(UIColor *)customColor {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if ([label.text containsString:@"条评论"]) {
            label.textColor = customColor;
        }
    }

    for (UIView *subview in view.subviews) {
        [self traverseSubviews:subview customColor:customColor];
    }
}

- (void)updateActionViewLabelColorRecursive:(UIView *)view {
    NSString *customHexColor = DYYYGetString(@"WaaCommentColor");
    if (customHexColor.length == 0) return;

    unsigned int hexValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[customHexColor hasPrefix:@"#"] ? [customHexColor substringFromIndex:1] : customHexColor];
    if (![scanner scanHexInt:&hexValue]) return;

    UIColor *customColor = [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                                           green:((hexValue >> 8) & 0xFF) / 255.0
                                            blue:(hexValue & 0xFF) / 255.0
                                           alpha:1.0];
    UIColor *darkerColor = darkerColorForColor(customColor);

    if ([view isKindOfClass:[UILabel class]]) {
        ((UILabel *)view).textColor = darkerColor;
    }

    for (UIView *subview in view.subviews) {
        [self updateActionViewLabelColorRecursive:subview];
    }
}

@end

%hook UIView

- (void)layoutSubviews {
    %orig;

    NSString *className = NSStringFromClass([self class]);
    BOOL isCommentColorEnabled = DYYYGetBool(@"WaaEnableCommentColor");

    if (isCommentColorEnabled) {
        NSString *customHexColor = DYYYGetString(@"WaaCommentColor");
        UIColor *customColor = nil;

        if (customHexColor.length > 0) {
            unsigned int hexValue = 0;
            NSScanner *scanner = [NSScanner scannerWithString:[customHexColor hasPrefix:@"#"] ? [customHexColor substringFromIndex:1] : customHexColor];
            if ([scanner scanHexInt:&hexValue]) {
                customColor = [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                                              green:((hexValue >> 8) & 0xFF) / 255.0
                                               blue:(hexValue & 0xFF) / 255.0
                                              alpha:1.0];
            }
        }

        // 用户名、内容、时间属地
        if (customColor) {
            UIColor *darkerColor = darkerColorForColor(customColor);
            Class YYLabelClass = NSClassFromString(@"YYLabel");

            for (UIView *subview in self.subviews) {
                NSString *subviewClassName = NSStringFromClass([subview class]);

                if ([subview isKindOfClass:[UILabel class]] &&
                    [subviewClassName isEqualToString:@"AWECommentSwiftBizUI.CommentInteractionBaseLabel"]) {
                    ((UILabel *)subview).textColor = darkerColor;
                } else if (YYLabelClass && [subview isKindOfClass:YYLabelClass] &&
                           [subviewClassName isEqualToString:@"AWECommentPanelListSwiftImpl.BaseCellCommentLabel"]) {
                    ((UILabel *)subview).textColor = customColor;
                } else if ([subview isKindOfClass:[UILabel class]] &&
                           [subviewClassName isEqualToString:@"AWECommentPanelHeaderSwiftImpl.CommentHeaderCell"]) {
                    ((UILabel *)subview).textColor = customColor;
                }
            }

            // 展开按钮
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)subview;
                    NSString *buttonText = [button titleForState:UIControlStateNormal];
                    if ([buttonText containsString:@"展开"] && [buttonText containsString:@"条回复"]) {
                        [button setTitleColor:darkerColor forState:UIControlStateNormal];
                    }
                }
            }

            [self traverseSubviews:self customColor:customColor];
        }
    }

    // 点赞数量
    UIView *superview = self.superview;
    while (superview) {
        if ([NSStringFromClass([superview class]) isEqualToString:@"AWECommentPanelListSwiftImpl.ActionView"]) {
            if (isCommentColorEnabled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateActionViewLabelColorRecursive:self];
                });
            }
            break;
        }
        superview = superview.superview;
    }

    // 隐藏输入框上方横线
    for (UIView *subview in self.subviews) {
        CGRect frame = subview.frame;

        NSString *superclassName = NSStringFromClass([subview.superview class]);
        BOOL isInTargetContainer = [superclassName isEqualToString:@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer"];

        CGFloat parentWidth = self.bounds.size.width;
        BOOL widthMatch = fabs(frame.size.width - parentWidth) < 1.0;
        BOOL heightMatch = frame.size.height > 0 && frame.size.height < 1.0;

        if (isInTargetContainer && widthMatch && heightMatch) {
            subview.hidden = YES;
        }
    }
}

%end

// 调整评论区图标颜色
BOOL isTargetCommentSubview(UIView *view) {
    static NSSet<NSString *> *targetClassNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        targetClassNames = [NSSet setWithArray:@[
            @"AWECommentPanelListSwiftImpl.ActionView",
            @"AWECommentPanelListSwiftImpl.CommentFooterView"
        ]];
    });

    while (view) {
        if ([targetClassNames containsObject:NSStringFromClass([view class])]) {
            return YES;
        }
        view = view.superview;
    }
    return NO;
}

%hook UIImageView

- (void)setImage:(UIImage *)image {
    BOOL isCommentColorEnabled = DYYYGetBool(@"WaaEnableCommentColor");
    NSString *customHexColor = DYYYGetString(@"WaaCommentColor");
    UIColor *customColor = nil;

    if (customHexColor.length > 0) {
        unsigned int hexValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:[customHexColor hasPrefix:@"#"] ? [customHexColor substringFromIndex:1] : customHexColor];
        if ([scanner scanHexInt:&hexValue]) {
            customColor = [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                                          green:((hexValue >> 8) & 0xFF) / 255.0
                                           blue:(hexValue & 0xFF) / 255.0
                                          alpha:1.0];
        }
    }

    if (isCommentColorEnabled && customColor && isTargetCommentSubview(self)) {
        UIImage *templateImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        %orig(templateImage);
        self.tintColor = darkerColorForColor(customColor);
        return;
    }

    %orig;
}

%end

#pragma mark - 隐藏功能

// 双指清屏增强
static void removeTargetSubviews(UIView *view) {
    if (!view) return;

    // 查找 AFDRoundRectangleButton 的父视图并移除整个父视图
    Class buttonClass = objc_getClass("AFDRoundRectangleButton");
    if (buttonClass && [view isKindOfClass:buttonClass]) {
        [view.superview removeFromSuperview];
        return;
    }

    // 移除 AWEStoryProgressContainerView
    Class storyViewClass = objc_getClass("AWEStoryProgressContainerView");
    if (storyViewClass && [view isKindOfClass:storyViewClass]) {
        [view removeFromSuperview];
        return;
    }

    for (UIView *subview in view.subviews) {
        removeTargetSubviews(subview);
    }
}

%hook AFDPureModePageContainerViewController

- (void)viewDidLoad {
    %orig;

    Class targetClass = objc_getClass("AFDPureModePageContainerViewController");
    BOOL isPureModeEnabled = NO;
    @try {
        isPureModeEnabled = DYYYGetBool(@"WaaEnablePureModePlus");
    } @catch (NSException *e) {
        return;
    }
    if (!isPureModeEnabled || !targetClass || ![self isKindOfClass:targetClass]) {
        return;
    }

    // 检查是否为净化模式（假设控制器有 isPureMode 属性）
    BOOL isPureMode = NO;
    if ([self respondsToSelector:@selector(isPureMode)]) {
        isPureMode = ((NSNumber *)[self valueForKey:@"isPureMode"]).boolValue;
    } else {
        // 如果没有属性，假设控制器本身表示净化模式
        isPureMode = YES;
    }

    if (isPureMode) {
        UIView *mainView = self.view;
        if ([mainView isKindOfClass:[UIView class]]) {
            removeTargetSubviews(mainView);
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    Class targetClass = objc_getClass("AFDPureModePageContainerViewController");
    BOOL isPureModeEnabled = NO;
    @try {
        isPureModeEnabled = DYYYGetBool(@"WaaEnablePureModePlus");
    } @catch (NSException *e) {
        return;
    }
    if (!isPureModeEnabled || !targetClass || ![self isKindOfClass:targetClass]) {
        return;
    }

    // 检查是否为净化模式
    BOOL isPureMode = NO;
    if ([self respondsToSelector:@selector(isPureMode)]) {
        isPureMode = ((NSNumber *)[self valueForKey:@"isPureMode"]).boolValue;
    } else {
        isPureMode = YES;
    }

    if (isPureMode) {
        UIView *mainView = self.view;
        if ([mainView isKindOfClass:[UIView class]]) {
            removeTargetSubviews(mainView);
        }
    }
}

%end

#pragma mark - 增强功能

// 修复关注二次确认
%group WaaFollowfixGroup
%hook UITapGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateEnded) {
        UIView *targetView = self.view;
        if ([targetView isKindOfClass:NSClassFromString(@"AWEPlayInteractionFollowPromptView")] || 
            [targetView.superview isKindOfClass:NSClassFromString(@"AWEPlayInteractionFollowPromptView")]) {

            if (DYYYGetBool(@"DYYYfollowTips")) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [DYYYBottomAlertView showAlertWithTitle:@"关注确认"
						message:@"是否确认关注？"
					      avatarURL:nil
				       cancelButtonText:@"取消"
				      confirmButtonText:@"关注"
					   cancelAction:nil
					    closeAction:nil
					  confirmAction:^{
					    %orig(state);
					}];
                });
                return;
            }
        }
    }
    %orig(state);
}

%end
%end

%ctor {
    %init;

    if (DYYYGetBool(@"WaaFollowfix")) {
        %init(WaaFollowfixGroup);
    }
}