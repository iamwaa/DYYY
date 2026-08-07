// Modified By @Waa

#import "Sources/Core/AwemeHeaders.h"
#import "Sources/Features/DYYYFloatClearButton.h"
#import "Sources/UI/DYYYBottomAlertView.h"
#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/runtime.h>
#import <string.h>

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

    if (isTargetCommentContainer) {
        inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(self);
        inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(self);
    } else if (isTargetMiddleContainer) {
        inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(self);
        UIView *parentView = self.superview;
        while (parentView) {
            if ([parentView isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")]) {
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
                    inputContainerHasSendButton = inputContainerHasSendButton || WaaViewContainsVisibleSendDUXButton(parentView);
                    inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(parentView);
                    break;
                }
                parentView = parentView.superview;
            }
        }
        else if ([superview isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")]) {
            isFirstChildOfCommentContainer = (superview.subviews.firstObject == self);
            inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(superview);
            inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(superview);
        }
        superview = superview.superview;
    }

    UIResponder *responder = self.nextResponder;
    BOOL isInCommentPanel = [responder isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")];

    BOOL shouldSkipInputTransparency = (isTargetCommentContainer || isTargetMiddleContainer || isFirstChildOfCommentContainer || isFirstChildOfMiddleContainer) && inputContainerHasSendButton && inputContainerIsCompactBar;
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
static BOOL WaaPureModeEnabledForController(id controller) {
    if (!DYYYGetBool(@"WaaEnablePureModePlus")) {
        return NO;
    }
    if ([controller respondsToSelector:@selector(isPureMode)]) {
        return ((NSNumber *)[controller valueForKey:@"isPureMode"]).boolValue;
    }
    return YES;
}

static char kWaaDanmakuForceStateCapturedKey;
static char kWaaDanmakuOriginalHiddenKey;
static char kWaaDanmakuOriginalAlphaKey;
static char kWaaDanmakuOriginalLayerOpacityKey;
static char kWaaDanmakuMigrationStateKey;

static BOOL WaaShouldForceShowPureModeDanmaku(void);

@interface WaaDanmakuMigrationState : NSObject
@property(nonatomic, strong) UIView *player;
@property(nonatomic, strong) UIView *originalSuperview;
@property(nonatomic, assign) NSUInteger originalIndex;
@property(nonatomic, assign) CGRect originalBounds;
@property(nonatomic, assign) CGPoint originalCenter;
@property(nonatomic, assign) CGAffineTransform originalTransform;
@property(nonatomic, assign) BOOL originalHidden;
@property(nonatomic, assign) CGFloat originalAlpha;
@property(nonatomic, assign) float originalLayerOpacity;
@property(nonatomic, assign) BOOL originalTranslatesAutoresizingMaskIntoConstraints;
@property(nonatomic, assign) UIViewAutoresizing originalAutoresizingMask;
@property(nonatomic, strong) NSArray<NSLayoutConstraint *> *activeExternalConstraints;
@property(nonatomic, strong) NSTimer *timeSyncTimer;
@property(nonatomic, assign) BOOL hasLastTimeSyncValue;
@property(nonatomic, assign) double lastTimeSyncValue;
@property(nonatomic, assign) NSTimeInterval lastTimeSyncAdvanceTime;
@property(nonatomic, assign) BOOL hasPerformedStalledLoopRecovery;
@property(nonatomic, assign) BOOL isUsingSyntheticLoopTime;
@property(nonatomic, assign) double syntheticLoopDuration;
@property(nonatomic, assign) NSTimeInterval syntheticLoopStartTime;
@end

@implementation WaaDanmakuMigrationState
@end

static void WaaCollectDanmakuPlayerViews(UIView *view, NSMutableArray<UIView *> *results) {
    if (!view) {
        return;
    }
    Class playerClass = NSClassFromString(@"DDanmakuPlayerView");
    if (playerClass && [view isKindOfClass:playerClass]) {
        [results addObject:view];
    }
    for (UIView *subview in view.subviews) {
        WaaCollectDanmakuPlayerViews(subview, results);
    }
}

static BOOL WaaViewAndAncestorsAreVisible(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if (candidate.hidden || candidate.alpha <= 0.01 || candidate.layer.opacity <= 0.01) {
            return NO;
        }
    }
    return YES;
}

static UIView *WaaCurrentVisibleDanmakuPlayer(void) {
    UIView *bestPlayer = nil;
    CGFloat bestArea = 0.0;
    CGFloat secondBestArea = 0.0;

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        NSMutableArray<UIView *> *players = [NSMutableArray array];
        WaaCollectDanmakuPlayerViews(window, players);
        for (UIView *player in players) {
            if (!player.window || !player.superview || !WaaViewAndAncestorsAreVisible(player)) {
                continue;
            }
            CGRect windowRect = [player convertRect:player.bounds toView:window];
            CGRect visibleRect = CGRectIntersection(windowRect, window.bounds);
            CGFloat area = CGRectIsNull(visibleRect) ? 0.0 : CGRectGetWidth(visibleRect) * CGRectGetHeight(visibleRect);
            if (area > bestArea) {
                secondBestArea = bestArea;
                bestArea = area;
                bestPlayer = player;
            } else if (area > secondBestArea) {
                secondBestArea = area;
            }
        }
    }

    if (!bestPlayer || bestArea < 100.0 || fabs(bestArea - secondBestArea) < 1.0) {
        return nil;
    }
    return bestPlayer;
}

static NSArray<NSLayoutConstraint *> *WaaActiveExternalConstraintsForView(UIView *view) {
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    for (UIView *ancestor = view.superview; ancestor; ancestor = ancestor.superview) {
        for (NSLayoutConstraint *constraint in ancestor.constraints) {
            id firstItem = constraint.firstItem;
            id secondItem = constraint.secondItem;
            BOOL firstReferencesView = firstItem == view ||
                                       ([firstItem isKindOfClass:UILayoutGuide.class] && ((UILayoutGuide *)firstItem).owningView == view);
            BOOL secondReferencesView = secondItem == view ||
                                        ([secondItem isKindOfClass:UILayoutGuide.class] && ((UILayoutGuide *)secondItem).owningView == view);
            if (constraint.active && (firstReferencesView || secondReferencesView)) {
                [constraints addObject:constraint];
            }
        }
    }
    return constraints;
}

static UIView *WaaConstraintItemView(id item) {
    if ([item isKindOfClass:UIView.class]) {
        return (UIView *)item;
    }
    if ([item isKindOfClass:UILayoutGuide.class]) {
        return ((UILayoutGuide *)item).owningView;
    }
    return nil;
}

static BOOL WaaViewsShareAncestor(UIView *firstView, UIView *secondView) {
    if (!firstView || !secondView) {
        return YES;
    }
    NSHashTable<UIView *> *firstAncestors = [NSHashTable weakObjectsHashTable];
    for (UIView *view = firstView; view; view = view.superview) {
        [firstAncestors addObject:view];
    }
    for (UIView *view = secondView; view; view = view.superview) {
        if ([firstAncestors containsObject:view]) {
            return YES;
        }
    }
    return NO;
}

static NSArray<NSLayoutConstraint *> *WaaValidConstraintsForActivation(NSArray<NSLayoutConstraint *> *constraints) {
    NSMutableArray<NSLayoutConstraint *> *validConstraints = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in constraints) {
        UIView *firstView = WaaConstraintItemView(constraint.firstItem);
        UIView *secondView = WaaConstraintItemView(constraint.secondItem);
        if (WaaViewsShareAncestor(firstView, secondView)) {
            [validConstraints addObject:constraint];
        }
    }
    return validConstraints;
}

static void WaaAttachDanmakuPlayerToPureModeController(UIViewController *controller) {
    if (!WaaShouldForceShowPureModeDanmaku() || objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey)) {
        return;
    }

    UIView *player = WaaCurrentVisibleDanmakuPlayer();
    UIView *originalSuperview = player.superview;
    UIView *targetView = controller.view;
    if (!player || !originalSuperview || !targetView) {
        return;
    }

    WaaDanmakuMigrationState *state = [WaaDanmakuMigrationState new];
    state.player = player;
    state.originalSuperview = originalSuperview;
    state.originalIndex = [originalSuperview.subviews indexOfObject:player];
    state.originalBounds = player.bounds;
    state.originalCenter = player.center;
    state.originalTransform = player.transform;
    state.originalHidden = player.hidden;
    state.originalAlpha = player.alpha;
    state.originalLayerOpacity = player.layer.opacity;
    state.originalTranslatesAutoresizingMaskIntoConstraints = player.translatesAutoresizingMaskIntoConstraints;
    state.originalAutoresizingMask = player.autoresizingMask;
    state.activeExternalConstraints = WaaActiveExternalConstraintsForView(player);

    [NSLayoutConstraint deactivateConstraints:state.activeExternalConstraints];
    player.translatesAutoresizingMaskIntoConstraints = YES;
    player.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [targetView addSubview:player];
    player.transform = CGAffineTransformIdentity;
    player.frame = targetView.bounds;
    player.hidden = NO;
    player.alpha = 1.0;
    player.layer.opacity = 1.0f;
    [targetView bringSubviewToFront:player];
    objc_setAssociatedObject(controller, &kWaaDanmakuMigrationStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WaaLayoutMigratedDanmakuPlayer(UIViewController *controller) {
    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    if (state.player.superview == controller.view) {
        state.player.transform = CGAffineTransformIdentity;
        state.player.frame = controller.view.bounds;
        [controller.view bringSubviewToFront:state.player];
    }
}

static id WaaDanmakuPlayerForView(UIView *playerView) {
    if (!playerView || ![playerView respondsToSelector:@selector(delegate)]) {
        return nil;
    }

    id (*delegateImplementation)(id, SEL) =
        (id (*)(id, SEL))[playerView methodForSelector:@selector(delegate)];
    id danmakuPlayer = delegateImplementation ? delegateImplementation(playerView, @selector(delegate)) : nil;
    Class danmakuPlayerClass = NSClassFromString(@"DDanmakuPlayer");
    return danmakuPlayerClass && [danmakuPlayer isKindOfClass:danmakuPlayerClass] ? danmakuPlayer : nil;
}

static BOOL WaaDanmakuMethodHasType(id object, SEL selector, const char *expectedType) {
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    const char *actualType = method ? method_getTypeEncoding(method) : NULL;
    return actualType && expectedType && strcmp(actualType, expectedType) == 0;
}

static void WaaResumeMigratedDanmakuPlayer(UIViewController *controller) {
    if (!WaaShouldForceShowPureModeDanmaku()) {
        return;
    }

    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    UIView *playerView = state.player;
    if (!playerView || playerView.superview != controller.view || !playerView.window) {
        return;
    }

    id danmakuPlayer = WaaDanmakuPlayerForView(playerView);
    SEL playSelector = @selector(play);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, playSelector, "v16@0:8")) {
        return;
    }

    void (*playImplementation)(id, SEL) = (void (*)(id, SEL))[danmakuPlayer methodForSelector:playSelector];
    if (playImplementation) {
        playImplementation(danmakuPlayer, playSelector);
    }
}

static void WaaStopMigratedDanmakuTimeSync(UIViewController *controller) {
    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    [state.timeSyncTimer invalidate];
    state.timeSyncTimer = nil;
    state.hasLastTimeSyncValue = NO;
    state.lastTimeSyncValue = 0.0;
    state.lastTimeSyncAdvanceTime = 0.0;
    state.hasPerformedStalledLoopRecovery = NO;
    state.isUsingSyntheticLoopTime = NO;
    state.syntheticLoopDuration = 0.0;
    state.syntheticLoopStartTime = 0.0;
}

static void WaaSyncMigratedDanmakuTime(UIViewController *controller) {
    if (!WaaShouldForceShowPureModeDanmaku()) {
        WaaStopMigratedDanmakuTimeSync(controller);
        return;
    }

    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    UIView *playerView = state.player;
    if (!playerView || playerView.superview != controller.view || !playerView.window) {
        WaaStopMigratedDanmakuTimeSync(controller);
        return;
    }

    id danmakuPlayer = WaaDanmakuPlayerForView(playerView);
    SEL currentTimeSelector = @selector(timeDriverCurrentPlayTime);
    SEL updateSelector = @selector(optimizedTimeUpdated:);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, currentTimeSelector, "d16@0:8") ||
        !WaaDanmakuMethodHasType(danmakuPlayer, updateSelector, "v24@0:8d16")) {
        WaaStopMigratedDanmakuTimeSync(controller);
        return;
    }

    double (*currentTimeImplementation)(id, SEL) =
        (double (*)(id, SEL))[danmakuPlayer methodForSelector:currentTimeSelector];
    void (*updateImplementation)(id, SEL, double) =
        (void (*)(id, SEL, double))[danmakuPlayer methodForSelector:updateSelector];
    double currentTime = currentTimeImplementation ? currentTimeImplementation(danmakuPlayer, currentTimeSelector) : NAN;
    if (!updateImplementation || !isfinite(currentTime) || currentTime < 0.0) {
        return;
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    BOOL didRestartVideoLoop = state.hasLastTimeSyncValue && currentTime + 0.5 < state.lastTimeSyncValue;
    BOOL didAdvanceTime = !state.hasLastTimeSyncValue || currentTime > state.lastTimeSyncValue + 0.01;

    if (didRestartVideoLoop) {
        state.isUsingSyntheticLoopTime = NO;
    }

    if (!state.isUsingSyntheticLoopTime) {
        if (didAdvanceTime || didRestartVideoLoop) {
            state.lastTimeSyncAdvanceTime = now;
            state.hasPerformedStalledLoopRecovery = NO;
        }

        BOOL didRecoverStalledLoop = !didRestartVideoLoop &&
                                    !didAdvanceTime &&
                                    !state.hasPerformedStalledLoopRecovery &&
                                    currentTime >= 1.0 &&
                                    state.lastTimeSyncAdvanceTime > 0.0 &&
                                    now - state.lastTimeSyncAdvanceTime >= 1.0;
        if (didRecoverStalledLoop) {
            // 视频时间停在末尾时，先记录周期长度，再用墙钟驱动新的弹幕周期。
            state.hasPerformedStalledLoopRecovery = YES;
            state.isUsingSyntheticLoopTime = YES;
            state.syntheticLoopDuration = currentTime;
            state.syntheticLoopStartTime = now;
            state.lastTimeSyncValue = currentTime;
            SEL prepareReplaySelector = @selector(prepareRePlayForLoop);
            if (WaaDanmakuMethodHasType(danmakuPlayer, prepareReplaySelector, "v16@0:8")) {
                void (*prepareReplayImplementation)(id, SEL) =
                    (void (*)(id, SEL))[danmakuPlayer methodForSelector:prepareReplaySelector];
                if (prepareReplayImplementation) {
                    prepareReplayImplementation(danmakuPlayer, prepareReplaySelector);
                }
            }
            updateImplementation(danmakuPlayer, updateSelector, 0.0);
            WaaResumeMigratedDanmakuPlayer(controller);
            return;
        }
    }

    if (state.isUsingSyntheticLoopTime && state.syntheticLoopDuration > 0.0) {
        double elapsed = now - state.syntheticLoopStartTime;
        double syntheticTime = fmod(elapsed, state.syntheticLoopDuration);
        BOOL didRestartSyntheticLoop = state.hasLastTimeSyncValue && syntheticTime + 0.5 < state.lastTimeSyncValue;
        if (didRestartSyntheticLoop) {
            SEL prepareReplaySelector = @selector(prepareRePlayForLoop);
            if (WaaDanmakuMethodHasType(danmakuPlayer, prepareReplaySelector, "v16@0:8")) {
                void (*prepareReplayImplementation)(id, SEL) =
                    (void (*)(id, SEL))[danmakuPlayer methodForSelector:prepareReplaySelector];
                if (prepareReplayImplementation) {
                    prepareReplayImplementation(danmakuPlayer, prepareReplaySelector);
                }
            }
        }
        state.hasLastTimeSyncValue = YES;
        state.lastTimeSyncValue = syntheticTime;
        updateImplementation(danmakuPlayer, updateSelector, syntheticTime);
        WaaResumeMigratedDanmakuPlayer(controller);
        return;
    }

    state.hasLastTimeSyncValue = YES;
    state.lastTimeSyncValue = currentTime;
    updateImplementation(danmakuPlayer, updateSelector, currentTime);
    if (didRestartVideoLoop) {
        SEL prepareReplaySelector = @selector(prepareRePlayForLoop);
        if (WaaDanmakuMethodHasType(danmakuPlayer, prepareReplaySelector, "v16@0:8")) {
            void (*prepareReplayImplementation)(id, SEL) =
                (void (*)(id, SEL))[danmakuPlayer methodForSelector:prepareReplaySelector];
            if (prepareReplayImplementation) {
                prepareReplayImplementation(danmakuPlayer, prepareReplaySelector);
            }
        }
        WaaResumeMigratedDanmakuPlayer(controller);
    }
}

static void WaaStartMigratedDanmakuTimeSync(UIViewController *controller) {
    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    if (!state || state.timeSyncTimer) {
        return;
    }

    state.hasLastTimeSyncValue = NO;
    state.lastTimeSyncValue = 0.0;
    state.lastTimeSyncAdvanceTime = 0.0;
    state.hasPerformedStalledLoopRecovery = NO;
    state.isUsingSyntheticLoopTime = NO;
    state.syntheticLoopDuration = 0.0;
    state.syntheticLoopStartTime = 0.0;
    __weak UIViewController *weakController = controller;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.1
                                            repeats:YES
                                              block:^(__unused NSTimer *runningTimer) {
        UIViewController *strongController = weakController;
        if (strongController) {
            WaaSyncMigratedDanmakuTime(strongController);
        } else {
            [runningTimer invalidate];
        }
    }];
    state.timeSyncTimer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    WaaSyncMigratedDanmakuTime(controller);
}

static void WaaRestoreMigratedDanmakuPlayer(UIViewController *controller) {
    WaaStopMigratedDanmakuTimeSync(controller);
    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    if (!state) {
        return;
    }
    objc_setAssociatedObject(controller, &kWaaDanmakuMigrationStateKey, nil, OBJC_ASSOCIATION_ASSIGN);

    UIView *player = state.player;
    UIView *originalSuperview = state.originalSuperview;
    if (!player || !originalSuperview || player.superview != controller.view) {
        return;
    }

    NSUInteger index = MIN(state.originalIndex, originalSuperview.subviews.count);
    [originalSuperview insertSubview:player atIndex:index];
    player.translatesAutoresizingMaskIntoConstraints = state.originalTranslatesAutoresizingMaskIntoConstraints;
    player.autoresizingMask = state.originalAutoresizingMask;
    player.bounds = state.originalBounds;
    player.center = state.originalCenter;
    player.transform = state.originalTransform;
    player.hidden = state.originalHidden;
    player.alpha = state.originalAlpha;
    player.layer.opacity = state.originalLayerOpacity;
    [NSLayoutConstraint activateConstraints:WaaValidConstraintsForActivation(state.activeExternalConstraints)];
    [originalSuperview setNeedsLayout];
    [originalSuperview layoutIfNeeded];
}

static BOOL WaaFloatClearHidesDanmaku(void) {
    return hideButton.isElementsHidden && DYYYGetBool(@"DYYYHideDanmaku");
}

static BOOL WaaShouldHidePureModeDanmaku(void) {
    BOOL pureModePlusHidesDanmaku = dyyyPureModePlusActive &&
                                      DYYYGetBool(@"WaaEnablePureModePlus") &&
                                      !DYYYGetBool(@"WaaPureModePlusShowDanmaku");
    return WaaFloatClearHidesDanmaku() || pureModePlusHidesDanmaku;
}

static BOOL WaaShouldForceShowPureModeDanmaku(void) {
    return dyyyPureModePlusActive &&
           DYYYGetBool(@"WaaEnablePureModePlus") &&
           DYYYGetBool(@"WaaPureModePlusShowDanmaku") &&
           !WaaFloatClearHidesDanmaku();
}

static BOOL WaaIsDanmakuContainerView(UIView *view) {
    Class videoDanmakuClass = NSClassFromString(@"AWEVideoPlayDanmakuContainerView");
    Class danmakuClass = NSClassFromString(@"AWEDanmakuContainerView");
    return (videoDanmakuClass && [view isKindOfClass:videoDanmakuClass]) ||
           (danmakuClass && [view isKindOfClass:danmakuClass]);
}

static void WaaCaptureDanmakuStateIfNeeded(UIView *view) {
    if (!view || objc_getAssociatedObject(view, &kWaaDanmakuForceStateCapturedKey)) {
        return;
    }
    objc_setAssociatedObject(view, &kWaaDanmakuForceStateCapturedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kWaaDanmakuOriginalHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kWaaDanmakuOriginalAlphaKey, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kWaaDanmakuOriginalLayerOpacityKey, @(view.layer.opacity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WaaRestoreDanmakuStateIfNeeded(UIView *view) {
    if (!view || !objc_getAssociatedObject(view, &kWaaDanmakuForceStateCapturedKey)) {
        return;
    }

    NSNumber *originalHidden = objc_getAssociatedObject(view, &kWaaDanmakuOriginalHiddenKey);
    NSNumber *originalAlpha = objc_getAssociatedObject(view, &kWaaDanmakuOriginalAlphaKey);
    NSNumber *originalLayerOpacity = objc_getAssociatedObject(view, &kWaaDanmakuOriginalLayerOpacityKey);
    objc_setAssociatedObject(view, &kWaaDanmakuForceStateCapturedKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(view, &kWaaDanmakuOriginalHiddenKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(view, &kWaaDanmakuOriginalAlphaKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(view, &kWaaDanmakuOriginalLayerOpacityKey, nil, OBJC_ASSOCIATION_ASSIGN);

    if (originalHidden) {
        view.hidden = originalHidden.boolValue;
    }
    if (originalAlpha) {
        view.alpha = originalAlpha.floatValue;
    }
    if (originalLayerOpacity) {
        view.layer.opacity = originalLayerOpacity.floatValue;
    }
}

static void WaaApplyPureModeDanmakuStateToView(UIView *view) {
    if (!view || !WaaIsDanmakuContainerView(view)) {
        return;
    }

    if (WaaShouldHidePureModeDanmaku()) {
        WaaRestoreDanmakuStateIfNeeded(view);
        DYYYApplyClearTargetViewHiddenState(view);
        return;
    }

    DYYYRestoreClearTargetViewStateIfNeeded(view);
    if (WaaShouldForceShowPureModeDanmaku()) {
        WaaCaptureDanmakuStateIfNeeded(view);
        view.hidden = NO;
        view.alpha = 1.0;
        view.layer.opacity = 1.0f;
    } else {
        WaaRestoreDanmakuStateIfNeeded(view);
    }
}

static void WaaRefreshPureModeDanmakuViewsInView(UIView *view) {
    if (!view) {
        return;
    }
    WaaApplyPureModeDanmakuStateToView(view);
    for (UIView *subview in view.subviews) {
        WaaRefreshPureModeDanmakuViewsInView(subview);
    }
}

static void WaaRefreshPureModePlusState(BOOL active) {
    DYYYSetPureModePlusActive(active);
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        WaaRefreshPureModeDanmakuViewsInView(window);
    }
}

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

    if (!WaaPureModeEnabledForController(self)) {
        return;
    }

    UIView *mainView = self.view;
    if ([mainView isKindOfClass:[UIView class]]) {
        removeTargetSubviews(mainView);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    BOOL active = WaaPureModeEnabledForController(self);
    WaaRefreshPureModePlusState(active);
    if (active) {
        WaaAttachDanmakuPlayerToPureModeController(self);
    }
    %orig;
    WaaRefreshPureModePlusState(active);
    WaaLayoutMigratedDanmakuPlayer(self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    BOOL active = WaaPureModeEnabledForController(self);
    WaaRefreshPureModePlusState(active);
    if (!active) {
        return;
    }

    UIView *mainView = self.view;
    if ([mainView isKindOfClass:[UIView class]]) {
        removeTargetSubviews(mainView);
    }
    WaaLayoutMigratedDanmakuPlayer(self);
    WaaResumeMigratedDanmakuPlayer(self);
    WaaStartMigratedDanmakuTimeSync(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    WaaLayoutMigratedDanmakuPlayer(self);
}

- (void)viewWillDisappear:(BOOL)animated {
    WaaStopMigratedDanmakuTimeSync(self);
    WaaRefreshPureModePlusState(NO);
    %orig;
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    WaaRefreshPureModePlusState(NO);
    WaaRestoreMigratedDanmakuPlayer(self);
}

%end

%hook AWEVideoPlayDanmakuContainerView

- (void)layoutSubviews {
    %orig;
    WaaApplyPureModeDanmakuStateToView(self);
}

- (void)setHidden:(BOOL)hidden {
    if (WaaShouldForceShowPureModeDanmaku()) {
        WaaCaptureDanmakuStateIfNeeded(self);
        %orig(NO);
        return;
    }
    %orig(hidden);
}

- (void)setAlpha:(CGFloat)alpha {
    if (WaaShouldForceShowPureModeDanmaku()) {
        WaaCaptureDanmakuStateIfNeeded(self);
        %orig(1.0);
        return;
    }
    %orig(alpha);
}

%end

%hook AWEDanmakuContainerView

- (void)layoutSubviews {
    %orig;
    WaaApplyPureModeDanmakuStateToView(self);
}

- (void)setHidden:(BOOL)hidden {
    if (WaaShouldForceShowPureModeDanmaku()) {
        WaaCaptureDanmakuStateIfNeeded(self);
        %orig(NO);
        return;
    }
    %orig(hidden);
}

- (void)setAlpha:(CGFloat)alpha {
    if (WaaShouldForceShowPureModeDanmaku()) {
        WaaCaptureDanmakuStateIfNeeded(self);
        %orig(1.0);
        return;
    }
    %orig(alpha);
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