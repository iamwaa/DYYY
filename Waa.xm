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
static char kWaaPureDanmakuStateKey;

static BOOL WaaShouldForceShowPureModeDanmaku(void);
static id WaaDanmakuPlayerForView(UIView *playerView);

@class WaaDanmakuOverlayView;

// 清屏页自绘弹幕的运行状态：覆盖层、时间来源播放器与轮询定时器
@interface WaaPureDanmakuState : NSObject
@property(nonatomic, strong) WaaDanmakuOverlayView *overlay;
@property(nonatomic, strong) id sourcePlayer;
@property(nonatomic, strong) NSTimer *timeSyncTimer;
@property(nonatomic, assign) BOOL hasLastTimeSyncValue;
@property(nonatomic, assign) double lastTimeSyncValue;
@property(nonatomic, assign) CFTimeInterval lastTimeAdvancedAt;
@property(nonatomic, assign) NSUInteger loadedDanmakuCount;
@property(nonatomic, assign) NSUInteger tickCount;
@end

@implementation WaaPureDanmakuState
@end

static const CGFloat kWaaDanmakuFontSize = 15.0;
static const CGFloat kWaaDanmakuLaneHeight = 27.0;
static const CGFloat kWaaDanmakuTopInset = 96.0;
static const CGFloat kWaaDanmakuBottomInset = 120.0;
static const CGFloat kWaaDanmakuLaneGap = 24.0;
static const NSTimeInterval kWaaDanmakuTravelDuration = 8.0;
static const NSUInteger kWaaDanmakuMaxActiveCount = 60;
static const NSUInteger kWaaDanmakuMaxLaneCount = 8;

// 从原生弹幕对象里提取出的最小渲染单元
@interface WaaDanmakuItem : NSObject
@property(nonatomic, copy) NSString *text;
@property(nonatomic, assign) double time;
@end

@implementation WaaDanmakuItem
@end

// 清屏页自绘弹幕层：不依赖抖音渲染管线，按视频时间自行调度标签从右往左飘
@interface WaaDanmakuOverlayView : UIView
@property(nonatomic, copy) NSArray<WaaDanmakuItem *> *items;
@property(nonatomic, assign) NSUInteger cursor;
@property(nonatomic, assign) double lastUpdateTime;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *laneFreeTimes;
@property(nonatomic, assign, getter=isPlaybackPaused) BOOL playbackPaused;
- (void)loadItems:(NSArray<WaaDanmakuItem *> *)items currentTime:(double)time;
- (void)resetForLoop;
- (void)updateToTime:(double)time;
- (void)setPlaybackPaused:(BOOL)paused;
@end

@implementation WaaDanmakuOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.backgroundColor = UIColor.clearColor;
        _laneFreeTimes = [NSMutableArray array];
    }
    return self;
}

// 弹幕是逐步入池的，换列表后把游标对齐到当前时间，避免重放已显示过的弹幕
- (void)loadItems:(NSArray<WaaDanmakuItem *> *)items currentTime:(double)time {
    _items = [items copy];
    self.cursor = [self indexAfterTime:time];
}

// 首个出现时间晚于 time 的弹幕下标；items 已按时间升序
- (NSUInteger)indexAfterTime:(double)time {
    NSUInteger index = 0;
    while (index < self.items.count && self.items[index].time <= time) {
        index++;
    }
    return index;
}

// 视频循环时回到弹幕列表开头，并清掉屏幕上残留的标签
- (void)resetForLoop {
    self.cursor = 0;
    self.lastUpdateTime = 0.0;
    for (UIView *subview in [self.subviews copy]) {
        [subview.layer removeAllAnimations];
        [subview removeFromSuperview];
    }
    [self.laneFreeTimes removeAllObjects];
}

// 视频暂停时冻结整层的动画时钟，让弹幕跟着停下
- (void)setPlaybackPaused:(BOOL)paused {
    if (paused == _playbackPaused) {
        return;
    }
    _playbackPaused = paused;

    CALayer *layer = self.layer;
    if (paused) {
        CFTimeInterval frozenTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
        layer.speed = 0.0;
        layer.timeOffset = frozenTime;
        return;
    }

    CFTimeInterval frozenTime = layer.timeOffset;
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    layer.beginTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - frozenTime;
}

// 弹幕只占画面上方一条带，不遮挡视频主体
- (NSUInteger)laneCount {
    CGFloat usableHeight = CGRectGetHeight(self.bounds) - kWaaDanmakuTopInset - kWaaDanmakuBottomInset;
    if (usableHeight < kWaaDanmakuLaneHeight) {
        return 0;
    }
    return MIN((NSUInteger)floor(usableHeight / kWaaDanmakuLaneHeight), kWaaDanmakuMaxLaneCount);
}

- (void)updateToTime:(double)time {
    // 向前大跨度跳转（拖动进度）时直接对齐游标，不把积压的弹幕一次性吹上屏
    if (time > self.lastUpdateTime + 2.0) {
        self.cursor = [self indexAfterTime:time];
    }
    self.lastUpdateTime = time;

    NSUInteger laneCount = [self laneCount];
    if (laneCount == 0 || self.items.count == 0) {
        // 尺寸不够会静默丢弃所有弹幕，这里把原因记下来
        static BOOL hasLoggedIdle = NO;
        if (!hasLoggedIdle) {
            hasLoggedIdle = YES;
            NSLog(@"[DYYY][PureDanmaku] 覆盖层未出弹幕 bounds=%@ lanes=%lu items=%lu window=%d",
                  NSStringFromCGRect(self.bounds), (unsigned long)laneCount,
                  (unsigned long)self.items.count, self.window != nil);
        }
        return;
    }

    while (self.cursor < self.items.count && self.items[self.cursor].time <= time) {
        WaaDanmakuItem *item = self.items[self.cursor];
        self.cursor++;
        [self spawnItem:item atTime:time laneCount:laneCount];
    }
}

// 轨道占用一律用视频时间计算，暂停期间不会被墙钟推着提前释放
- (void)spawnItem:(WaaDanmakuItem *)item atTime:(double)time laneCount:(NSUInteger)laneCount {
    if (item.text.length == 0 || self.subviews.count >= kWaaDanmakuMaxActiveCount) {
        return;
    }

    NSInteger lane = -1;
    for (NSUInteger index = 0; index < laneCount; index++) {
        while (index >= self.laneFreeTimes.count) {
            [self.laneFreeTimes addObject:@(0.0)];
        }
        if (self.laneFreeTimes[index].doubleValue <= time) {
            lane = (NSInteger)index;
            break;
        }
    }
    // 轨道全忙时直接丢弃，宁可少显示也不重叠
    if (lane < 0) {
        return;
    }

    CGFloat containerWidth = CGRectGetWidth(self.bounds);
    if (containerWidth <= 0.0) {
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = item.text;
    label.font = [UIFont systemFontOfSize:kWaaDanmakuFontSize weight:UIFontWeightMedium];
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = UIColor.clearColor;
    label.numberOfLines = 1;
    // 视频背景深浅不定，用阴影保证白字在亮画面上也能读
    label.layer.shadowColor = UIColor.blackColor.CGColor;
    label.layer.shadowOffset = CGSizeMake(0.0, 1.0);
    label.layer.shadowRadius = 2.0;
    label.layer.shadowOpacity = 0.85;
    label.layer.shouldRasterize = YES;
    label.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [label sizeToFit];

    CGFloat labelWidth = ceil(CGRectGetWidth(label.bounds));
    CGFloat labelY = kWaaDanmakuTopInset + lane * kWaaDanmakuLaneHeight;
    label.frame = CGRectMake(containerWidth, labelY, labelWidth, kWaaDanmakuLaneHeight);
    [self addSubview:label];

    // 确认标签真的上屏了，以及它落在什么位置
    static BOOL hasLoggedSpawn = NO;
    if (!hasLoggedSpawn) {
        hasLoggedSpawn = YES;
        NSLog(@"[DYYY][PureDanmaku] 首条弹幕上屏 text=%@ frame=%@ overlay=%@ lanes=%lu",
              item.text, NSStringFromCGRect(label.frame), NSStringFromCGRect(self.bounds),
              (unsigned long)laneCount);
    }

    CGFloat distance = containerWidth + labelWidth;
    NSTimeInterval duration = kWaaDanmakuTravelDuration * (distance / containerWidth);
    CGFloat speed = duration > 0.0 ? distance / duration : 0.0;
    // 等本条弹幕尾部完全离开右边缘再释放轨道，避免后一条追尾
    self.laneFreeTimes[lane] = @(time + (speed > 0.0 ? (labelWidth + kWaaDanmakuLaneGap) / speed : 0.0));

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        label.frame = CGRectMake(-labelWidth, labelY, labelWidth, kWaaDanmakuLaneHeight);
    }
                     completion:^(__unused BOOL finished) {
        [label removeFromSuperview];
    }];
}

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

// 清屏页 view 在 viewWillAppear 时可能还是 zero，尺寸不足会让弹幕静默丢弃，回退到屏幕尺寸
static CGRect WaaDanmakuOverlayBounds(UIViewController *controller) {
    CGRect bounds = controller.view.bounds;
    if (CGRectGetWidth(bounds) < 1.0 || CGRectGetHeight(bounds) < 1.0) {
        bounds = UIScreen.mainScreen.bounds;
    }
    return bounds;
}

static void WaaAttachDanmakuOverlayToPureModeController(UIViewController *controller) {
    if (!WaaShouldForceShowPureModeDanmaku() || objc_getAssociatedObject(controller, &kWaaPureDanmakuStateKey)) {
        return;
    }

    UIView *targetView = controller.view;
    if (!targetView) {
        return;
    }

    // 只借原生播放器做时间源与弹幕数据源，不再搬动它的视图；此刻可能还找不到，交给后续轮询重试
    WaaPureDanmakuState *state = [WaaPureDanmakuState new];
    state.sourcePlayer = WaaDanmakuPlayerForView(WaaCurrentVisibleDanmakuPlayer());

    WaaDanmakuOverlayView *overlay = [[WaaDanmakuOverlayView alloc] initWithFrame:WaaDanmakuOverlayBounds(controller)];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [targetView addSubview:overlay];
    [targetView bringSubviewToFront:overlay];
    state.overlay = overlay;

    objc_setAssociatedObject(controller, &kWaaPureDanmakuStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[DYYY][PureDanmaku] 弹幕覆盖层已挂载 controller=%p player=%p", controller, state.sourcePlayer);
}

static void WaaLayoutDanmakuOverlay(UIViewController *controller) {
    WaaPureDanmakuState *state = objc_getAssociatedObject(controller, &kWaaPureDanmakuStateKey);
    WaaDanmakuOverlayView *overlay = state.overlay;
    if (overlay.superview != controller.view) {
        return;
    }

    overlay.frame = WaaDanmakuOverlayBounds(controller);
    [controller.view bringSubviewToFront:overlay];
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

static BOOL WaaIsDanmakuPlayer(id object) {
    Class playerClass = NSClassFromString(@"DDanmakuPlayer");
    return playerClass && [object isKindOfClass:playerClass];
}

static void WaaRecordAppendedDanmakus(id danmakuPlayer, id danmakus) {
    if (!WaaIsDanmakuPlayer(danmakuPlayer) || ![danmakus isKindOfClass:NSArray.class]) {
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
    if (!WaaIsDanmakuPlayer(danmakuPlayer)) {
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

// 只校验无参 + 返回类型，不做完整签名 strcmp；完整编码在不同版本上会带类名导致失配
static BOOL WaaDanmakuGetterReturns(id object, SEL selector, char expectedReturnType) {
    if (![object respondsToSelector:selector]) {
        return NO;
    }
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    const char *returnType = signature.methodReturnType;
    return signature.numberOfArguments == 2 && returnType && returnType[0] == expectedReturnType;
}

static id WaaDanmakuObjectValue(id object, SEL selector) {
    if (!WaaDanmakuGetterReturns(object, selector, '@')) {
        return nil;
    }
    id (*implementation)(id, SEL) = (id (*)(id, SEL))[object methodForSelector:selector];
    return implementation ? implementation(object, selector) : nil;
}

// 读取原生弹幕对象的文本；纯文本为空时回退到富文本
static NSString *WaaDanmakuTextOf(id danmaku) {
    id text = WaaDanmakuObjectValue(danmaku, @selector(text));
    if ([text isKindOfClass:NSString.class] && ((NSString *)text).length > 0) {
        return text;
    }

    id attributedText = WaaDanmakuObjectValue(danmaku, @selector(attributedString));
    if ([attributedText isKindOfClass:NSAttributedString.class]) {
        NSString *plainText = ((NSAttributedString *)attributedText).string;
        if (plainText.length > 0) {
            return plainText;
        }
    }
    return nil;
}

// 读取弹幕相对视频起点的出现时间；两种模型字段名不同
static double WaaDanmakuTimeOf(id danmaku) {
    SEL selectors[] = {@selector(timeOffset), @selector(offsetTime)};
    for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(selectors[0]); index++) {
        if (!WaaDanmakuGetterReturns(danmaku, selectors[index], 'd')) {
            continue;
        }
        double (*implementation)(id, SEL) = (double (*)(id, SEL))[danmaku methodForSelector:selectors[index]];
        double time = implementation ? implementation(danmaku, selectors[index]) : -1.0;
        if (isfinite(time) && time >= 0.0) {
            return time;
        }
    }
    return -1.0;
}

// 取不到字段时把对象真实形状打出来，避免再靠猜
static void WaaLogDanmakuShapeOnce(id danmaku) {
    static BOOL hasLogged = NO;
    if (hasLogged || !danmaku) {
        return;
    }
    hasLogged = YES;

    NSMutableString *selectorList = [NSMutableString string];
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([danmaku class], &methodCount);
    for (unsigned int index = 0; index < methodCount && selectorList.length < 600; index++) {
        [selectorList appendFormat:@"%@ ", NSStringFromSelector(method_getName(methods[index]))];
    }
    free(methods);

    NSLog(@"[DYYY][PureDanmaku] 弹幕对象形状 class=%@ 方法=%@",
          NSStringFromClass([danmaku class]), selectorList);
}

// 数据池里存的可能是 AWEDanmakuItemDescriptor 这类包装器，
// 真正的模型挂在 danmakuModel / metaData 上，逐层剥到带 text 的对象为止
static id WaaResolveDanmakuModel(id danmaku) {
    id candidate = danmaku;
    for (NSUInteger depth = 0; depth < 3 && candidate; depth++) {
        if (WaaDanmakuGetterReturns(candidate, @selector(text), '@')) {
            return candidate;
        }
        id unwrapped = WaaDanmakuObjectValue(candidate, @selector(danmakuModel));
        if (!unwrapped) {
            unwrapped = WaaDanmakuObjectValue(candidate, @selector(metaData));
        }
        if (!unwrapped || unwrapped == candidate) {
            break;
        }
        candidate = unwrapped;
    }
    return candidate;
}

// 把抖音的弹幕对象转成自绘所需的最小结构，按时间排序并去重
// 循环时抖音会重新创建描述符，按对象身份去重不可靠，改用内容+时间
static NSArray<WaaDanmakuItem *> *WaaBuildDanmakuItems(NSArray *danmakus) {
    NSMutableArray<WaaDanmakuItem *> *items = [NSMutableArray arrayWithCapacity:danmakus.count];
    NSMutableSet<NSString *> *seenKeys = [NSMutableSet setWithCapacity:danmakus.count];
    for (id danmaku in danmakus) {
        id model = WaaResolveDanmakuModel(danmaku);
        NSString *text = WaaDanmakuTextOf(model);
        double time = WaaDanmakuTimeOf(model);
        if (text.length == 0 || time < 0.0) {
            WaaLogDanmakuShapeOnce(danmaku);
            continue;
        }

        NSString *key = [NSString stringWithFormat:@"%.2f|%@", time, text];
        if ([seenKeys containsObject:key]) {
            continue;
        }
        [seenKeys addObject:key];

        WaaDanmakuItem *item = [WaaDanmakuItem new];
        item.text = text;
        item.time = time;
        [items addObject:item];
    }
    [items sortUsingComparator:^NSComparisonResult(WaaDanmakuItem *lhs, WaaDanmakuItem *rhs) {
        if (lhs.time < rhs.time) {
            return NSOrderedAscending;
        }
        return lhs.time > rhs.time ? NSOrderedDescending : NSOrderedSame;
    }];
    return items;
}

static void WaaStopPureDanmakuTimeSync(UIViewController *controller) {
    WaaPureDanmakuState *state = objc_getAssociatedObject(controller, &kWaaPureDanmakuStateKey);
    [state.timeSyncTimer invalidate];
    state.timeSyncTimer = nil;
    state.hasLastTimeSyncValue = NO;
    state.lastTimeSyncValue = 0.0;
    state.lastTimeAdvancedAt = 0.0;
}

// 从原生播放器取视频时间，驱动自绘覆盖层；时间回退即视为视频循环
// 清屏页自己的播放控制器会持续推送播放时间（驱动进度条与控制中心），
// 而弹幕播放器的 timeDriver 在清屏模式下会被抖音冻住，所以以推送值为准
static double gWaaPureModePushedPlayTime = -1.0;
static CFTimeInterval gWaaPureModePushedAt = 0.0;

static void WaaInstallPureModePlaybackTimeHookIfNeeded(void) {
    static BOOL hasInstalled = NO;
    if (hasInstalled) {
        return;
    }
    Class controllerClass = NSClassFromString(@"AFDPureModePagePlaybackController");
    SEL updateSelector = @selector(player:updatePlayTime:canPlayTime:totalTime:);
    Method updateMethod = WaaOwnInstanceMethod(controllerClass, updateSelector);
    if (!updateMethod) {
        return;
    }

    hasInstalled = YES;
    static void (*originalUpdate)(id, SEL, id, double, double, double) = NULL;
    originalUpdate = (void (*)(id, SEL, id, double, double, double))method_getImplementation(updateMethod);
    method_setImplementation(updateMethod, imp_implementationWithBlock(
        ^(id controller, id player, double playTime, double canPlayTime, double totalTime) {
        if (originalUpdate) {
            originalUpdate(controller, updateSelector, player, playTime, canPlayTime, totalTime);
        }
        if (isfinite(playTime) && playTime >= 0.0) {
            gWaaPureModePushedPlayTime = playTime;
            gWaaPureModePushedAt = CACurrentMediaTime();
        }
    }));

    NSLog(@"[DYYY][PureDanmaku] 已接管清屏页播放时间");
}

// 推送值需要新鲜；超过 2s 没更新就认为不可信（页面已退出或真暂停）
static BOOL WaaPureModePushedPlayTime(double *playTime) {
    if (gWaaPureModePushedPlayTime < 0.0 ||
        CACurrentMediaTime() - gWaaPureModePushedAt > 2.0) {
        return NO;
    }
    if (playTime) {
        *playTime = gWaaPureModePushedPlayTime;
    }
    return YES;
}

static void WaaSyncPureDanmakuTime(UIViewController *controller) {
    if (!WaaShouldForceShowPureModeDanmaku()) {
        WaaStopPureDanmakuTimeSync(controller);
        return;
    }

    WaaPureDanmakuState *state = objc_getAssociatedObject(controller, &kWaaPureDanmakuStateKey);
    WaaDanmakuOverlayView *overlay = state.overlay;
    if (!overlay || overlay.superview != controller.view || !overlay.window) {
        WaaStopPureDanmakuTimeSync(controller);
        return;
    }

    WaaInstallDanmakuRuntimeHooksIfNeeded();
    WaaInstallPureModePlaybackTimeHookIfNeeded();

    id danmakuPlayer = state.sourcePlayer;
    // 挂载时可能还没找到播放器，这里惰性补上
    if (!danmakuPlayer) {
        danmakuPlayer = WaaDanmakuPlayerForView(WaaCurrentVisibleDanmakuPlayer());
        if (!danmakuPlayer) {
            return;
        }
        state.sourcePlayer = danmakuPlayer;
        NSLog(@"[DYYY][PureDanmaku] 覆盖层补绑播放器 controller=%p player=%p", controller, danmakuPlayer);
    }

    SEL currentTimeSelector = @selector(timeDriverCurrentPlayTime);
    if (!WaaDanmakuMethodHasType(danmakuPlayer, currentTimeSelector, "d16@0:8")) {
        return;
    }

    double (*currentTimeImplementation)(id, SEL) =
        (double (*)(id, SEL))[danmakuPlayer methodForSelector:currentTimeSelector];
    double currentTime = currentTimeImplementation ? currentTimeImplementation(danmakuPlayer, currentTimeSelector) : NAN;

    // 清屏模式下弹幕播放器的时钟会停走，优先用清屏页推送的真实播放时间
    double pushedTime = 0.0;
    if (WaaPureModePushedPlayTime(&pushedTime)) {
        currentTime = pushedTime;
    }
    if (!isfinite(currentTime) || currentTime < 0.0) {
        return;
    }

    // 弹幕是逐步入池的，每次轮询都用累积到的最新全量刷新覆盖层
    NSArray *allDanmakus = WaaAccumulatedDanmakus(danmakuPlayer);
    if (allDanmakus.count == 0) {
        allDanmakus = WaaAllBookDanmakus(danmakuPlayer);
    }
    // 源数据被抖音清空时保留已载入的列表，否则循环后就没弹幕可放
    if (allDanmakus.count > 0 && allDanmakus.count != state.loadedDanmakuCount) {
        NSArray<WaaDanmakuItem *> *items = WaaBuildDanmakuItems(allDanmakus);
        state.loadedDanmakuCount = allDanmakus.count;
        [overlay loadItems:items currentTime:currentTime];
        NSLog(@"[DYYY][PureDanmaku] 覆盖层载入弹幕 player=%p source=%lu usable=%lu",
              danmakuPlayer, (unsigned long)allDanmakus.count, (unsigned long)items.count);
    }

    double previousTime = state.lastTimeSyncValue;
    BOOL didRestartVideoLoop = state.hasLastTimeSyncValue && currentTime + 0.5 < previousTime;

    // 轮询（0.1s）比播放时间推送更密，相邻两次拿到同一个值是正常的；
    // 因此按“持续停止前进的墙钟时长”判定暂停，避免误判造成弹幕抽动
    CFTimeInterval now = CACurrentMediaTime();
    if (!state.hasLastTimeSyncValue || didRestartVideoLoop ||
        fabs(currentTime - previousTime) >= 0.001) {
        state.lastTimeAdvancedAt = now;
    }
    BOOL isPaused = state.hasLastTimeSyncValue && !didRestartVideoLoop &&
                    now - state.lastTimeAdvancedAt > 0.7;
    overlay.playbackPaused = isPaused;
    state.hasLastTimeSyncValue = YES;
    state.lastTimeSyncValue = currentTime;
    if (didRestartVideoLoop) {
        NSLog(@"[DYYY][PureDanmaku] 覆盖层重播 player=%p previous=%.3f current=%.3f",
              danmakuPlayer, previousTime, currentTime);
        [overlay resetForLoop];
    }
    if (isPaused) {
        return;
    }

    // 每 30 tick（约 3s）采样一次，确认时钟确实在前进且游标在推进
    state.tickCount++;
    if (state.tickCount % 30 == 1) {
        NSLog(@"[DYYY][PureDanmaku] 覆盖层心跳 time=%.3f pushed=%d cursor=%lu items=%lu 在屏=%lu",
              currentTime, WaaPureModePushedPlayTime(NULL),
              (unsigned long)overlay.cursor, (unsigned long)overlay.items.count,
              (unsigned long)overlay.subviews.count);
    }

    [overlay updateToTime:currentTime];
}

static void WaaStartPureDanmakuTimeSync(UIViewController *controller) {
    WaaPureDanmakuState *state = objc_getAssociatedObject(controller, &kWaaPureDanmakuStateKey);
    if (!state || state.timeSyncTimer) {
        return;
    }

    state.hasLastTimeSyncValue = NO;
    state.lastTimeSyncValue = 0.0;
    state.lastTimeAdvancedAt = CACurrentMediaTime();
    __weak UIViewController *weakController = controller;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.1
                                            repeats:YES
                                              block:^(__unused NSTimer *runningTimer) {
        UIViewController *strongController = weakController;
        if (strongController) {
            WaaSyncPureDanmakuTime(strongController);
        } else {
            [runningTimer invalidate];
        }
    }];
    state.timeSyncTimer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    WaaSyncPureDanmakuTime(controller);
}

static void WaaRemoveDanmakuOverlay(UIViewController *controller) {
    WaaStopPureDanmakuTimeSync(controller);
    WaaPureDanmakuState *state = objc_getAssociatedObject(controller, &kWaaPureDanmakuStateKey);
    if (!state) {
        return;
    }
    objc_setAssociatedObject(controller, &kWaaPureDanmakuStateKey, nil, OBJC_ASSOCIATION_ASSIGN);

    [state.overlay resetForLoop];
    [state.overlay removeFromSuperview];
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
        WaaAttachDanmakuOverlayToPureModeController(self);
    }
    %orig;
    WaaRefreshPureModePlusState(active);
    WaaLayoutDanmakuOverlay(self);
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
    WaaLayoutDanmakuOverlay(self);
    WaaStartPureDanmakuTimeSync(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    WaaLayoutDanmakuOverlay(self);
}

- (void)viewWillDisappear:(BOOL)animated {
    WaaStopPureDanmakuTimeSync(self);
    WaaRefreshPureModePlusState(NO);
    %orig;
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    WaaRefreshPureModePlusState(NO);
    WaaRemoveDanmakuOverlay(self);
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