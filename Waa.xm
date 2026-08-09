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
@property(nonatomic, strong) NSArray *cachedDanmakus;
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

// 累积抖音实际喂入数据池的弹幕，避免循环时数据已被消费
// key 为 DDanmakuPlayer 弱引用，value 为保留顺序且自动去重的弹幕集合
static NSMapTable<id, NSMutableOrderedSet *> *WaaAccumulatedDanmakuTable(void) {
    static NSMapTable *table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
                                     valueOptions:NSPointerFunctionsStrongMemory];
    });
    return table;
}

// 回填期间的自发调用不应再次计入累积，也不应清空累积
static BOOL gWaaIsReplayingDanmakus = NO;

static BOOL WaaIsDanmakuPlayer(id object) {
    Class playerClass = NSClassFromString(@"DDanmakuPlayer");
    return playerClass && [object isKindOfClass:playerClass];
}

static void WaaRecordAppendedDanmakus(id danmakuPlayer, id danmakus) {
    if (gWaaIsReplayingDanmakus || !WaaIsDanmakuPlayer(danmakuPlayer) || ![danmakus isKindOfClass:NSArray.class]) {
        return;
    }
    NSArray *incomingDanmakus = danmakus;
    if (incomingDanmakus.count == 0) {
        return;
    }

    NSMapTable *table = WaaAccumulatedDanmakuTable();
    NSMutableOrderedSet *accumulatedDanmakus = [table objectForKey:danmakuPlayer];
    if (!accumulatedDanmakus) {
        accumulatedDanmakus = [NSMutableOrderedSet orderedSet];
        [table setObject:accumulatedDanmakus forKey:danmakuPlayer];
    }

    NSUInteger previousCount = accumulatedDanmakus.count;
    [accumulatedDanmakus addObjectsFromArray:incomingDanmakus];
    NSUInteger addedCount = accumulatedDanmakus.count - previousCount;
    if (addedCount == 0) {
        return;
    }

    NSLog(@"[DYYY][PureDanmaku] 累积弹幕入池 player=%p added=%lu total=%lu",
          danmakuPlayer, (unsigned long)addedCount, (unsigned long)accumulatedDanmakus.count);
}

static void WaaClearAccumulatedDanmakus(id danmakuPlayer) {
    if (gWaaIsReplayingDanmakus || !WaaIsDanmakuPlayer(danmakuPlayer)) {
        return;
    }
    NSMapTable *table = WaaAccumulatedDanmakuTable();
    NSMutableOrderedSet *accumulatedDanmakus = [table objectForKey:danmakuPlayer];
    if (accumulatedDanmakus.count == 0) {
        return;
    }
    NSLog(@"[DYYY][PureDanmaku] 清空累积弹幕 player=%p count=%lu",
          danmakuPlayer, (unsigned long)accumulatedDanmakus.count);
    [table removeObjectForKey:danmakuPlayer];
}

// 仅当方法由该类自身实现时才可替换，避免改到父类而影响其他子类
static Method WaaOwnInstanceMethod(Class targetClass, SEL selector) {
    Method method = targetClass ? class_getInstanceMethod(targetClass, selector) : NULL;
    if (!method) {
        return NULL;
    }
    Method superclassMethod = class_getInstanceMethod(class_getSuperclass(targetClass), selector);
    return method == superclassMethod ? NULL : method;
}

// DDanmakuPlayer 可能在启动后才加载，因此用运行时替换实现而不是 %hook
static void WaaInstallDanmakuDataPoolHooksIfNeeded(void) {
    static BOOL hasInstalled = NO;
    if (hasInstalled) {
        return;
    }
    Class playerClass = NSClassFromString(@"DDanmakuPlayer");
    SEL appendSelector = @selector(appendDanmakusToDataPool:);
    SEL clearSelector = @selector(clearDanmakusInDataPool);
    Method appendMethod = WaaOwnInstanceMethod(playerClass, appendSelector);
    Method clearMethod = WaaOwnInstanceMethod(playerClass, clearSelector);
    if (!appendMethod || !clearMethod) {
        return;
    }

    hasInstalled = YES;
    static void (*originalAppend)(id, SEL, id) = NULL;
    static void (*originalClear)(id, SEL) = NULL;
    originalAppend = (void (*)(id, SEL, id))method_getImplementation(appendMethod);
    originalClear = (void (*)(id, SEL))method_getImplementation(clearMethod);

    method_setImplementation(appendMethod, imp_implementationWithBlock(^(id player, id danmakus) {
        if (originalAppend) {
            originalAppend(player, appendSelector, danmakus);
        }
        WaaRecordAppendedDanmakus(player, danmakus);
    }));
    method_setImplementation(clearMethod, imp_implementationWithBlock(^(id player) {
        if (originalClear) {
            originalClear(player, clearSelector);
        }
        WaaClearAccumulatedDanmakus(player);
    }));

    NSLog(@"[DYYY][PureDanmaku] 已拦截弹幕入池接口");
}

// 诊断抖音清屏页自带的弹幕控制器：是否创建、是否允许显示、循环回调是否触发
// 只记录日志，不修改任何返回值与行为
static void WaaInstallPureModeDanmakuDiagnosticsIfNeeded(void) {
    static BOOL hasInstalled = NO;
    if (hasInstalled) {
        return;
    }
    Class controllerClass = NSClassFromString(@"AFDPureModePageDanmakuController");
    if (!controllerClass) {
        return;
    }

    SEL canShowSelector = @selector(canShowDanmakuView);
    SEL addContainerSelector = @selector(addDanmakuContainerView);
    SEL loopSelector = @selector(videoWillLoopTimes:);
    SEL viewDidLoadSelector = @selector(viewDidLoad);
    Method canShowMethod = WaaOwnInstanceMethod(controllerClass, canShowSelector);
    Method addContainerMethod = WaaOwnInstanceMethod(controllerClass, addContainerSelector);
    Method loopMethod = WaaOwnInstanceMethod(controllerClass, loopSelector);
    Method viewDidLoadMethod = WaaOwnInstanceMethod(controllerClass, viewDidLoadSelector);
    if (!canShowMethod || !addContainerMethod || !loopMethod || !viewDidLoadMethod) {
        NSLog(@"[DYYY][PureDanmaku][Official] 清屏弹幕控制器诊断未安装 canShow=%d addContainer=%d loop=%d viewDidLoad=%d",
              canShowMethod != NULL, addContainerMethod != NULL, loopMethod != NULL, viewDidLoadMethod != NULL);
        return;
    }

    hasInstalled = YES;
    static BOOL (*originalCanShow)(id, SEL) = NULL;
    static void (*originalAddContainer)(id, SEL) = NULL;
    static void (*originalLoop)(id, SEL, long long) = NULL;
    static void (*originalViewDidLoad)(id, SEL) = NULL;
    originalCanShow = (BOOL (*)(id, SEL))method_getImplementation(canShowMethod);
    originalAddContainer = (void (*)(id, SEL))method_getImplementation(addContainerMethod);
    originalLoop = (void (*)(id, SEL, long long))method_getImplementation(loopMethod);
    originalViewDidLoad = (void (*)(id, SEL))method_getImplementation(viewDidLoadMethod);

    method_setImplementation(canShowMethod, imp_implementationWithBlock(^BOOL(id controller) {
        BOOL canShow = originalCanShow ? originalCanShow(controller, canShowSelector) : NO;
        NSLog(@"[DYYY][PureDanmaku][Official] canShowDanmakuView controller=%p result=%d", controller, canShow);
        return canShow;
    }));
    method_setImplementation(addContainerMethod, imp_implementationWithBlock(^(id controller) {
        NSLog(@"[DYYY][PureDanmaku][Official] addDanmakuContainerView controller=%p", controller);
        if (originalAddContainer) {
            originalAddContainer(controller, addContainerSelector);
        }
    }));
    method_setImplementation(loopMethod, imp_implementationWithBlock(^(id controller, long long times) {
        NSLog(@"[DYYY][PureDanmaku][Official] videoWillLoopTimes controller=%p times=%lld", controller, times);
        if (originalLoop) {
            originalLoop(controller, loopSelector, times);
        }
    }));
    method_setImplementation(viewDidLoadMethod, imp_implementationWithBlock(^(id controller) {
        if (originalViewDidLoad) {
            originalViewDidLoad(controller, viewDidLoadSelector);
        }
        NSLog(@"[DYYY][PureDanmaku][Official] 清屏弹幕控制器已创建 controller=%p", controller);
    }));

    NSLog(@"[DYYY][PureDanmaku][Official] 已安装清屏弹幕控制器诊断");
}

// 诊断通用弹幕容器控制器：循环官方回调与当前视频是否允许弹幕
static void WaaInstallDanmakuContainerDiagnosticsIfNeeded(void) {
    static BOOL hasInstalled = NO;
    if (hasInstalled) {
        return;
    }
    Class controllerClass = NSClassFromString(@"AWEDanmakuContainerController");
    if (!controllerClass) {
        return;
    }

    SEL loopSelector = @selector(onPlayerWillLoopPlaying);
    SEL shouldShowSelector = @selector(shouldCurrentModelShowDanmaku);
    Method loopMethod = WaaOwnInstanceMethod(controllerClass, loopSelector);
    Method shouldShowMethod = WaaOwnInstanceMethod(controllerClass, shouldShowSelector);
    if (!loopMethod || !shouldShowMethod) {
        NSLog(@"[DYYY][PureDanmaku][Official] 弹幕容器控制器诊断未安装 loop=%d shouldShow=%d",
              loopMethod != NULL, shouldShowMethod != NULL);
        return;
    }

    hasInstalled = YES;
    static void (*originalLoop)(id, SEL) = NULL;
    static BOOL (*originalShouldShow)(id, SEL) = NULL;
    originalLoop = (void (*)(id, SEL))method_getImplementation(loopMethod);
    originalShouldShow = (BOOL (*)(id, SEL))method_getImplementation(shouldShowMethod);

    method_setImplementation(loopMethod, imp_implementationWithBlock(^(id controller) {
        NSLog(@"[DYYY][PureDanmaku][Official] onPlayerWillLoopPlaying controller=%p", controller);
        if (originalLoop) {
            originalLoop(controller, loopSelector);
        }
    }));
    method_setImplementation(shouldShowMethod, imp_implementationWithBlock(^BOOL(id controller) {
        BOOL shouldShow = originalShouldShow ? originalShouldShow(controller, shouldShowSelector) : NO;
        NSLog(@"[DYYY][PureDanmaku][Official] shouldCurrentModelShowDanmaku controller=%p result=%d", controller, shouldShow);
        return shouldShow;
    }));

    NSLog(@"[DYYY][PureDanmaku][Official] 已安装弹幕容器控制器诊断");
}

static void WaaInstallDanmakuRuntimeHooksIfNeeded(void) {
    WaaInstallDanmakuDataPoolHooksIfNeeded();
    WaaInstallPureModeDanmakuDiagnosticsIfNeeded();
    WaaInstallDanmakuContainerDiagnosticsIfNeeded();
}

static NSArray *WaaAccumulatedDanmakus(id danmakuPlayer) {
    NSMutableOrderedSet *accumulatedDanmakus = [WaaAccumulatedDanmakuTable() objectForKey:danmakuPlayer];
    return accumulatedDanmakus.count > 0 ? accumulatedDanmakus.array : nil;
}

static NSArray *WaaAllBookDanmakus(id danmakuPlayer) {
    SEL selector = @selector(allBookDanmakusArray);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, selector, "@16@0:8")) {
        return nil;
    }
    NSArray *(*implementation)(id, SEL) = (NSArray *(*)(id, SEL))[danmakuPlayer methodForSelector:selector];
    id result = implementation ? implementation(danmakuPlayer, selector) : nil;
    return [result isKindOfClass:NSArray.class] ? result : nil;
}

// 取出播放器持有的原生数据池，循环时可直接复用其中已缓存的完整弹幕
static id WaaDanmakuDataPool(id danmakuPlayer) {
    SEL selector = @selector(dataPool);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, selector, "@16@0:8")) {
        return nil;
    }
    id (*implementation)(id, SEL) = (id (*)(id, SEL))[danmakuPlayer methodForSelector:selector];
    id dataPool = implementation ? implementation(danmakuPlayer, selector) : nil;
    Class dataPoolClass = NSClassFromString(@"DDanmakuDataPool");
    return dataPoolClass && [dataPool isKindOfClass:dataPoolClass] ? dataPool : nil;
}

static NSUInteger WaaDanmakuDataPoolCount(id dataPool) {
    SEL selector = @selector(danmakusArray);
    if (!WaaDanmakuMethodHasType(dataPool, selector, "@16@0:8")) {
        return 0;
    }
    id (*implementation)(id, SEL) = (id (*)(id, SEL))[dataPool methodForSelector:selector];
    id danmakus = implementation ? implementation(dataPool, selector) : nil;
    return [danmakus isKindOfClass:NSArray.class] ? [danmakus count] : 0;
}

static unsigned long long WaaDanmakuTraveledIndex(id dataPool) {
    SEL selector = @selector(traveledDanmakuIndex);
    if (!WaaDanmakuMethodHasType(dataPool, selector, "Q16@0:8")) {
        return 0;
    }
    unsigned long long (*implementation)(id, SEL) =
        (unsigned long long (*)(id, SEL))[dataPool methodForSelector:selector];
    return implementation ? implementation(dataPool, selector) : 0;
}

// 数据池已有完整弹幕时只把消费游标归零重放，避免每次循环都重复追加导致数据池无限增长
static BOOL WaaResetDanmakuDataPoolCursor(id danmakuPlayer, NSUInteger *poolCount, unsigned long long *traveledIndex) {
    id dataPool = WaaDanmakuDataPool(danmakuPlayer);
    SEL resetSelector = @selector(resetTravledDanmakuIndex);
    if (!dataPool || !WaaDanmakuMethodHasType(dataPool, resetSelector, "v16@0:8")) {
        return NO;
    }

    NSUInteger count = WaaDanmakuDataPoolCount(dataPool);
    if (count == 0) {
        return NO;
    }

    void (*resetImplementation)(id, SEL) = (void (*)(id, SEL))[dataPool methodForSelector:resetSelector];
    if (!resetImplementation) {
        return NO;
    }

    if (poolCount) {
        *poolCount = count;
    }
    if (traveledIndex) {
        *traveledIndex = WaaDanmakuTraveledIndex(dataPool);
    }
    resetImplementation(dataPool, resetSelector);
    return YES;
}

// 清掉屏幕上仍在飞的弹幕，避免重放后新旧两批叠在一起
static void WaaClearDisplayingDanmakus(id danmakuPlayer) {
    SEL selector = @selector(clearAllDisplayingDanmakus);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, selector, "v16@0:8")) {
        return;
    }
    void (*implementation)(id, SEL) = (void (*)(id, SEL))[danmakuPlayer methodForSelector:selector];
    if (implementation) {
        implementation(danmakuPlayer, selector);
    }
}

// 数据池为空时的兜底：把累积到的完整弹幕重新灌回去
static BOOL WaaRefillDanmakuDataPool(id danmakuPlayer, NSArray *cachedDanmakus) {
    SEL appendDanmakusSelector = @selector(appendDanmakusToDataPool:);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, appendDanmakusSelector, "v24@0:8@16")) {
        return NO;
    }
    void (*appendDanmakusImplementation)(id, SEL, id) =
        (void (*)(id, SEL, id))[danmakuPlayer methodForSelector:appendDanmakusSelector];
    if (!appendDanmakusImplementation) {
        return NO;
    }

    NSString *danmakuSource = @"pool";
    NSArray *allDanmakus = WaaAccumulatedDanmakus(danmakuPlayer);
    if (allDanmakus.count == 0) {
        danmakuSource = @"cached";
        allDanmakus = cachedDanmakus;
    }
    if (allDanmakus.count == 0) {
        danmakuSource = @"live";
        allDanmakus = WaaAllBookDanmakus(danmakuPlayer);
    }
    if (allDanmakus.count == 0) {
        return NO;
    }

    appendDanmakusImplementation(danmakuPlayer, appendDanmakusSelector, allDanmakus);
    NSLog(@"[DYYY][PureDanmaku] 循环补充弹幕池 player=%p source=%@ count=%lu",
          danmakuPlayer, danmakuSource, (unsigned long)allDanmakus.count);
    return YES;
}

static void WaaRestartMigratedDanmakuForLoop(id danmakuPlayer, NSArray *cachedDanmakus) {
    SEL prepareReplaySelector = @selector(prepareRePlayForLoop);
    SEL updateSelector = @selector(optimizedTimeUpdated:);
    SEL playSelector = @selector(play);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, prepareReplaySelector, "v16@0:8") ||
        !WaaDanmakuMethodHasType(danmakuPlayer, updateSelector, "v24@0:8d16") ||
        !WaaDanmakuMethodHasType(danmakuPlayer, playSelector, "v16@0:8")) {
        return;
    }

    void (*prepareReplayImplementation)(id, SEL) =
        (void (*)(id, SEL))[danmakuPlayer methodForSelector:prepareReplaySelector];
    void (*updateImplementation)(id, SEL, double) =
        (void (*)(id, SEL, double))[danmakuPlayer methodForSelector:updateSelector];
    void (*playImplementation)(id, SEL) =
        (void (*)(id, SEL))[danmakuPlayer methodForSelector:playSelector];
    if (!prepareReplayImplementation || !updateImplementation || !playImplementation) {
        return;
    }

    gWaaIsReplayingDanmakus = YES;

    // 优先重置原生数据池游标；池子被清空时才回退到重新灌入累积弹幕
    NSUInteger poolCount = 0;
    unsigned long long traveledIndex = 0;
    BOOL didReset = WaaResetDanmakuDataPoolCursor(danmakuPlayer, &poolCount, &traveledIndex);
    if (didReset) {
        NSLog(@"[DYYY][PureDanmaku] 循环重置数据池 player=%p poolCount=%lu traveled=%llu",
              danmakuPlayer, (unsigned long)poolCount, traveledIndex);
    } else if (!WaaRefillDanmakuDataPool(danmakuPlayer, cachedDanmakus)) {
        gWaaIsReplayingDanmakus = NO;
        NSLog(@"[DYYY][PureDanmaku] 循环补池失败 player=%p count=0", danmakuPlayer);
        return;
    }

    WaaClearDisplayingDanmakus(danmakuPlayer);
    prepareReplayImplementation(danmakuPlayer, prepareReplaySelector);
    updateImplementation(danmakuPlayer, updateSelector, 0.0);
    playImplementation(danmakuPlayer, playSelector);
    gWaaIsReplayingDanmakus = NO;
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

    WaaInstallDanmakuRuntimeHooksIfNeeded();

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

    NSArray *allDanmakus = WaaAllBookDanmakus(danmakuPlayer);
    if (allDanmakus.count > 0 && state.cachedDanmakus.count == 0) {
        state.cachedDanmakus = [allDanmakus copy];
        NSLog(@"[DYYY][PureDanmaku] 首次缓存完整弹幕列表 player=%p count=%lu", danmakuPlayer, (unsigned long)state.cachedDanmakus.count);
    }

    double previousTime = state.lastTimeSyncValue;
    BOOL didRestartVideoLoop = state.hasLastTimeSyncValue && currentTime + 0.5 < previousTime;
    state.hasLastTimeSyncValue = YES;
    state.lastTimeSyncValue = currentTime;
    if (didRestartVideoLoop) {
        NSLog(@"[DYYY][PureDanmaku] 完整重置弹幕循环 player=%p previous=%.3f current=%.3f",
              danmakuPlayer, previousTime, currentTime);
        WaaRestartMigratedDanmakuForLoop(danmakuPlayer, state.cachedDanmakus);
        return;
    }

    updateImplementation(danmakuPlayer, updateSelector, currentTime);
}

static void WaaStartMigratedDanmakuTimeSync(UIViewController *controller) {
    WaaDanmakuMigrationState *state = objc_getAssociatedObject(controller, &kWaaDanmakuMigrationStateKey);
    if (!state || state.timeSyncTimer) {
        return;
    }

    state.hasLastTimeSyncValue = NO;
    state.lastTimeSyncValue = 0.0;
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
    WaaInstallDanmakuRuntimeHooksIfNeeded();
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
    WaaInstallDanmakuRuntimeHooksIfNeeded();
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
    WaaInstallDanmakuRuntimeHooksIfNeeded();
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

    WaaInstallDanmakuRuntimeHooksIfNeeded();

    if (DYYYGetBool(@"WaaFollowfix")) {
        %init(WaaFollowfixGroup);
    }
}