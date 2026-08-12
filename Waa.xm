// Modified By @Waa

#import "Sources/Core/AwemeHeaders.h"
#import "Sources/Features/DYYYFloatClearButton.h"
#import "Sources/UI/DYYYBottomAlertView.h"
#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/runtime.h>
#import <string.h>

#pragma mark - 外观功能

static BOOL WaaViewIsInCommentScope(UIView *view);
static BOOL WaaViewShouldReceiveCommentAppearance(UIView *view);
static BOOL WaaColorLooksLightForView(UIColor *color, UIView *view);
static UIColor *WaaCommentDarkBackgroundColorForView(UIView *view, UIColor *currentColor);

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

UIColor *WaaCommentBackgroundColorForView(UIView *view, UIColor *backgroundColor) {
    CGFloat transparency = 1.0;

    UIView *superview = view.superview;
    BOOL isTargetMiddleContainer = [view isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer")];
    BOOL isTargetCommentContainer = [view isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView")];
    BOOL isFirstChildOfMiddleContainer = NO;
    BOOL isFirstChildOfCommentContainer = NO;
    BOOL inputContainerHasSendButton = NO;
    BOOL inputContainerIsCompactBar = NO;

    if (isTargetCommentContainer) {
        inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(view);
        inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(view);
    } else if (isTargetMiddleContainer) {
        inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(view);
        UIView *parentView = view.superview;
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
            isFirstChildOfMiddleContainer = (superview.subviews.firstObject == view);
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
            isFirstChildOfCommentContainer = (superview.subviews.firstObject == view);
            inputContainerHasSendButton = WaaViewContainsVisibleSendDUXButton(superview);
            inputContainerIsCompactBar = WaaCommentInputContainerIsCompactBottomBar(superview);
        }
        superview = superview.superview;
    }

    UIResponder *responder = view.nextResponder;
    BOOL isInCommentPanel = [responder isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")];

    BOOL shouldSkipInputTransparency = (isTargetCommentContainer || isTargetMiddleContainer || isFirstChildOfCommentContainer || isFirstChildOfMiddleContainer) && inputContainerHasSendButton && inputContainerIsCompactBar;
    if (shouldSkipInputTransparency) {
        return backgroundColor;
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

    if (DYYYGetBool(@"WaaForceCommentDarkMode") && WaaViewShouldReceiveCommentAppearance(view) && WaaColorLooksLightForView(backgroundColor, view)) {
        backgroundColor = WaaCommentDarkBackgroundColorForView(view, backgroundColor);
    }

    return backgroundColor;
}

// 调整评论区文字颜色
UIColor *darkerColorForColor(UIColor *color) {
    CGFloat hue, saturation, brightness, alpha;
    if ([color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness * 0.9 alpha:alpha];
    }
    return color;
}

static char kWaaCommentAppearanceLogSignatureKey;
static char kWaaCommentVisualLogSignaturesKey;
static char kWaaCommentDarkTreeLogSignaturesKey;

static NSString *WaaCommentColorDescription(UIColor *color, UITraitCollection *traitCollection) {
    if (!color) {
        return @"nil";
    }
    UIColor *resolvedColor = traitCollection ? [color resolvedColorWithTraitCollection:traitCollection] : color;
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;
    if ([resolvedColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return [NSString stringWithFormat:@"rgba(%.3f,%.3f,%.3f,%.3f)", red, green, blue, alpha];
    }
    return resolvedColor.description;
}

static NSString *WaaCommentTextSummary(UIView *label) {
    NSString *text = nil;
    if ([label respondsToSelector:@selector(text)]) {
        text = [(id)label text];
    }
    if (text.length == 0 && [label respondsToSelector:@selector(attributedText)]) {
        text = [[(id)label attributedText] string];
    }
    text = text ?: @"";
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    return text.length > 40 ? [[text substringToIndex:40] stringByAppendingString:@"..."] : text;
}

static UIColor *WaaCommentAttributedForegroundColor(UIView *label) {
    if (![label respondsToSelector:@selector(attributedText)]) {
        return nil;
    }
    NSAttributedString *attributedText = [(id)label attributedText];
    if (attributedText.length == 0) {
        return nil;
    }
    return [attributedText attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:nil];
}

static void WaaLogCommentLabelIfChanged(UIView *label, NSString *stage, NSString *target, UIColor *beforeColor, UIColor *afterColor) {
    if (!label) {
        return;
    }
    NSString *attributedColor = WaaCommentColorDescription(WaaCommentAttributedForegroundColor(label), label.traitCollection);
    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@",
                                                     stage,
                                                     target ?: @"none",
                                                     WaaCommentTextSummary(label),
                                                     WaaCommentColorDescription(beforeColor, label.traitCollection),
                                                     WaaCommentColorDescription(afterColor, label.traitCollection),
                                                     attributedColor];
    NSString *signatureKey = [NSString stringWithFormat:@"%@|%@", stage, target ?: @"none"];
    NSDictionary *previousSignatures = objc_getAssociatedObject(label, &kWaaCommentAppearanceLogSignatureKey);
    if ([previousSignatures[signatureKey] isEqualToString:signature]) {
        return;
    }
    NSMutableDictionary *updatedSignatures = [previousSignatures mutableCopy] ?: [NSMutableDictionary dictionary];
    updatedSignatures[signatureKey] = signature;
    objc_setAssociatedObject(label, &kWaaCommentAppearanceLogSignatureKey, [updatedSignatures copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[DYYY][CommentAppearance][Text] stage=%@ target=%@ class=%@ parent=%@ trait=%ld text=\"%@\" before=%@ after=%@ attributedForeground=%@",
          stage,
          target ?: @"none",
          NSStringFromClass([label class]),
          NSStringFromClass([label.superview class]),
          (long)label.traitCollection.userInterfaceStyle,
          WaaCommentTextSummary(label),
          WaaCommentColorDescription(beforeColor, label.traitCollection),
          WaaCommentColorDescription(afterColor, label.traitCollection),
          attributedColor);
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
            UIColor *beforeColor = label.textColor;
            label.textColor = customColor;
            WaaLogCommentLabelIfChanged(label, @"comment-count", @"commentCount", beforeColor, label.textColor);
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

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        UIColor *beforeColor = label.textColor;
        label.textColor = customColor;
        WaaLogCommentLabelIfChanged(label, @"action-view", @"actionLabel", beforeColor, label.textColor);
    }

    for (UIView *subview in view.subviews) {
        [self updateActionViewLabelColorRecursive:subview];
    }
}

@end

static BOOL WaaClassNameMatches(UIView *view, NSString *moduleName, NSString *classSuffix) {
    NSString *className = NSStringFromClass([view class]);
    return [className containsString:moduleName] && [className hasSuffix:classSuffix];
}

static BOOL WaaViewIsInCommentScope(UIView *view) {
    for (UIView *currentView = view; currentView; currentView = currentView.superview) {
        NSString *className = NSStringFromClass([currentView class]);
        if ([className containsString:@"AWEComment"] || [className containsString:@"CommentPanel"] ||
            [className containsString:@"CommentInput"] || [className containsString:@"AWESearchAnchorItemView"] ||
            [className containsString:@"CommentLoadMoreFooter"] || [className containsString:@"ActionView"] ||
            [className containsString:@"AWECommentDownButton"]) {
            return YES;
        }
    }
    return NO;
}

static BOOL WaaViewShouldReceiveCommentAppearance(UIView *view) {
    if (WaaViewIsInCommentScope(view)) {
        return YES;
    }
    NSString *className = NSStringFromClass([view class]);
    return [className containsString:@"AWEComment"] || [className containsString:@"CommentPanel"] ||
           [className containsString:@"CommentInput"] || [className containsString:@"AWESearchAnchorItemView"] ||
           [className containsString:@"CommentLoadMoreFooter"] || [className containsString:@"ActionView"] ||
           [className containsString:@"AWECommentDownButton"];
}

static BOOL WaaViewIsCommentControllerRoot(UIView *view) {
    UIResponder *responder = view.nextResponder;
    NSString *responderClassName = responder ? NSStringFromClass([responder class]) : @"";
    return [responderClassName containsString:@"AWECommentContainerViewController"] ||
           [responderClassName containsString:@"CommentContainerInnerViewController"];
}

static BOOL WaaColorLooksLightForView(UIColor *color, UIView *view) {
    if (!color) {
        return NO;
    }
    UIColor *resolvedColor = [color resolvedColorWithTraitCollection:view.traitCollection];
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;
    if (![resolvedColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return NO;
    }
    return alpha > 0.01 && (red * 0.299 + green * 0.587 + blue * 0.114) > 0.72;
}

static UIColor *WaaCommentDarkBackgroundColorForView(UIView *view, UIColor *currentColor) {
    CGFloat alpha = 1.0;
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat currentAlpha = 0;
    if (currentColor && [[currentColor resolvedColorWithTraitCollection:view.traitCollection] getRed:&red green:&green blue:&blue alpha:&currentAlpha]) {
        alpha = currentAlpha;
    }
    return [UIColor colorWithRed:0.055 green:0.055 blue:0.065 alpha:alpha];
}

static BOOL WaaStoreCommentVisualSignatureIfChanged(UIView *view, NSString *key, NSString *signature) {
    NSDictionary *previousSignatures = objc_getAssociatedObject(view, &kWaaCommentVisualLogSignaturesKey);
    if ([previousSignatures[key] isEqualToString:signature]) {
        return NO;
    }
    NSMutableDictionary *updatedSignatures = [previousSignatures mutableCopy] ?: [NSMutableDictionary dictionary];
    updatedSignatures[key] = signature;
    objc_setAssociatedObject(view, &kWaaCommentVisualLogSignaturesKey, [updatedSignatures copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static NSString *WaaCommentImageDescription(UIImage *image) {
    if (!image) {
        return @"nil";
    }
    return [NSString stringWithFormat:@"ptr=%p size=%.1fx%.1f scale=%.1f mode=%ld",
                                      image,
                                      image.size.width,
                                      image.size.height,
                                      image.scale,
                                      (long)image.renderingMode];
}

static NSString *WaaCommentCGColorDescription(CGColorRef color, UITraitCollection *traitCollection) {
    return color ? WaaCommentColorDescription([UIColor colorWithCGColor:color], traitCollection) : @"nil";
}

static void WaaLogAllCommentTextAndIconColorsIfChanged(UIView *view) {
    if (!WaaViewIsInCommentScope(view) ||
        (!DYYYGetBool(@"WaaEnableCommentColor") && !DYYYGetBool(@"WaaForceCommentDarkMode"))) {
        return;
    }

    NSString *className = NSStringFromClass([view class]);
    NSString *parentClassName = NSStringFromClass([view.superview class]);
    NSString *accessibility = view.accessibilityLabel ?: @"";
    NSString *trait = [NSString stringWithFormat:@"%ld", (long)view.traitCollection.userInterfaceStyle];

    BOOL hasTextColor = [view respondsToSelector:@selector(textColor)];
    BOOL hasText = [view respondsToSelector:@selector(text)] || [view respondsToSelector:@selector(attributedText)];
    if (hasTextColor || hasText) {
        UIColor *textColor = hasTextColor ? [(id)view textColor] : nil;
        NSString *placeholderText = @"";
        UIColor *placeholderColor = nil;
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)view;
            placeholderText = textField.placeholder ?: textField.attributedPlaceholder.string ?: @"";
            placeholderColor = textField.attributedPlaceholder.length > 0
                                   ? [textField.attributedPlaceholder attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:nil]
                                   : nil;
        }
        NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@",
                                                         WaaCommentTextSummary(view),
                                                         WaaCommentColorDescription(textColor, view.traitCollection),
                                                         WaaCommentColorDescription(WaaCommentAttributedForegroundColor(view), view.traitCollection),
                                                         placeholderText,
                                                         WaaCommentColorDescription(placeholderColor, view.traitCollection),
                                                         WaaCommentColorDescription(view.tintColor, view.traitCollection),
                                                         trait];
        if (WaaStoreCommentVisualSignatureIfChanged(view, @"allText", signature)) {
            NSLog(@"[DYYY][CommentAppearance][TextAll] class=%@ parent=%@ trait=%@ accessibility=\"%@\" text=\"%@\" textColor=%@ attributedForeground=%@ placeholder=\"%@\" placeholderForeground=%@ tint=%@",
                  className,
                  parentClassName,
                  trait,
                  accessibility,
                  WaaCommentTextSummary(view),
                  WaaCommentColorDescription(textColor, view.traitCollection),
                  WaaCommentColorDescription(WaaCommentAttributedForegroundColor(view), view.traitCollection),
                  placeholderText,
                  WaaCommentColorDescription(placeholderColor, view.traitCollection),
                  WaaCommentColorDescription(view.tintColor, view.traitCollection));
        }
    }

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@|%@|%@|%@",
                                                         [button titleForState:UIControlStateNormal] ?: @"",
                                                         WaaCommentColorDescription([button titleColorForState:UIControlStateNormal], view.traitCollection),
                                                         WaaCommentColorDescription([button titleColorForState:UIControlStateHighlighted], view.traitCollection),
                                                         WaaCommentColorDescription([button titleColorForState:UIControlStateSelected], view.traitCollection),
                                                         WaaCommentColorDescription([button titleColorForState:UIControlStateDisabled], view.traitCollection),
                                                         WaaCommentImageDescription([button imageForState:UIControlStateNormal]),
                                                         WaaCommentImageDescription([button imageForState:UIControlStateHighlighted]),
                                                         WaaCommentImageDescription([button imageForState:UIControlStateSelected]),
                                                         WaaCommentColorDescription(button.tintColor, view.traitCollection),
                                                         trait];
        if (WaaStoreCommentVisualSignatureIfChanged(view, @"allButton", signature)) {
            NSLog(@"[DYYY][CommentAppearance][TextAll] kind=button class=%@ parent=%@ trait=%@ accessibility=\"%@\" title=\"%@\" normal=%@ highlighted=%@ selected=%@ disabled=%@ tint=%@ normalImage={%@} highlightedImage={%@} selectedImage={%@}",
                  className,
                  parentClassName,
                  trait,
                  accessibility,
                  [button titleForState:UIControlStateNormal] ?: @"",
                  WaaCommentColorDescription([button titleColorForState:UIControlStateNormal], view.traitCollection),
                  WaaCommentColorDescription([button titleColorForState:UIControlStateHighlighted], view.traitCollection),
                  WaaCommentColorDescription([button titleColorForState:UIControlStateSelected], view.traitCollection),
                  WaaCommentColorDescription([button titleColorForState:UIControlStateDisabled], view.traitCollection),
                  WaaCommentColorDescription(button.tintColor, view.traitCollection),
                  WaaCommentImageDescription([button imageForState:UIControlStateNormal]),
                  WaaCommentImageDescription([button imageForState:UIControlStateHighlighted]),
                  WaaCommentImageDescription([button imageForState:UIControlStateSelected]));
        }
    }

    BOOL isCustomIconView = ![view isKindOfClass:[UIImageView class]] && ![view isKindOfClass:[UIButton class]] &&
                            ([className containsString:@"Icon"] || [className containsString:@"Image"] ||
                             [className containsString:@"SVG"] || [className containsString:@"DUX"]);
    if (isCustomIconView) {
        NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@",
                                                         WaaCommentColorDescription(view.tintColor, view.traitCollection),
                                                         WaaCommentColorDescription(view.backgroundColor, view.traitCollection),
                                                         WaaCommentCGColorDescription(view.layer.backgroundColor, view.traitCollection),
                                                         WaaCommentCGColorDescription(view.layer.borderColor, view.traitCollection),
                                                         [NSString stringWithFormat:@"%.3f", view.alpha],
                                                         trait];
        if (WaaStoreCommentVisualSignatureIfChanged(view, @"allCustomIcon", signature)) {
            NSLog(@"[DYYY][CommentAppearance][IconAll] kind=custom class=%@ parent=%@ trait=%@ accessibility=\"%@\" tint=%@ background=%@ layerBackground=%@ layerBorder=%@ alpha=%.3f",
                  className,
                  parentClassName,
                  trait,
                  accessibility,
                  WaaCommentColorDescription(view.tintColor, view.traitCollection),
                  WaaCommentColorDescription(view.backgroundColor, view.traitCollection),
                  WaaCommentCGColorDescription(view.layer.backgroundColor, view.traitCollection),
                  WaaCommentCGColorDescription(view.layer.borderColor, view.traitCollection),
                  view.alpha);
        }
    }

    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@",
                                                         WaaCommentImageDescription(imageView.image),
                                                         WaaCommentImageDescription(imageView.highlightedImage),
                                                         WaaCommentColorDescription(imageView.tintColor, view.traitCollection),
                                                         trait];
        if (WaaStoreCommentVisualSignatureIfChanged(view, @"allIcon", signature)) {
            NSLog(@"[DYYY][CommentAppearance][IconAll] class=%@ parent=%@ trait=%@ accessibility=\"%@\" tint=%@ image={%@} highlightedImage={%@}",
                  className,
                  parentClassName,
                  trait,
                  accessibility,
                  WaaCommentColorDescription(imageView.tintColor, view.traitCollection),
                  WaaCommentImageDescription(imageView.image),
                  WaaCommentImageDescription(imageView.highlightedImage));
        }
    }
}

static BOOL WaaCommentViewHasIconContainerAncestor(UIView *view) {
    for (UIView *ancestor = view.superview; ancestor; ancestor = ancestor.superview) {
        NSString *ancestorClass = NSStringFromClass([ancestor class]);
        if ([ancestorClass containsString:@"ActionView"] || [ancestorClass containsString:@"FooterView"] ||
            [ancestorClass containsString:@"Toolbar"] || [ancestorClass containsString:@"InputView"] ||
            [ancestorClass containsString:@"HeaderView"]) {
            return YES;
        }
    }
    return NO;
}

static BOOL WaaCommentImageLooksLikeIcon(UIImageView *imageView) {
    UIImage *image = imageView.image;
    if (!image) {
        return NO;
    }
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    BOOL compactImage = width > 0 && height > 0 && width <= 48.0 && height <= 48.0;
    BOOL templateImage = image.renderingMode == UIImageRenderingModeAlwaysTemplate;
    NSString *className = NSStringFromClass([imageView class]);
    BOOL iconClass = [className containsString:@"Icon"] || [className containsString:@"SVG"] ||
                     [className containsString:@"CommentInteractionBaseButton"];
    BOOL iconContainer = WaaCommentViewHasIconContainerAncestor(imageView) ||
                         [NSStringFromClass([imageView.superview class]) containsString:@"CommentInteractionBaseButton"];
    return templateImage || iconClass || (compactImage && iconContainer);
}

static BOOL WaaCommentButtonImageLooksLikeIcon(UIButton *button, UIImage *image) {
    if (!image) {
        return NO;
    }
    NSString *className = NSStringFromClass([button class]);
    BOOL iconClass = [className containsString:@"Icon"] || [className containsString:@"SVG"] || [className containsString:@"DUX"] ||
                     [className containsString:@"CommentInteractionBaseButton"];
    BOOL compactImage = image.size.width > 0 && image.size.height > 0 && image.size.width <= 48.0 && image.size.height <= 48.0;
    return image.renderingMode == UIImageRenderingModeAlwaysTemplate || iconClass ||
           (compactImage && WaaCommentViewHasIconContainerAncestor(button));
}

static BOOL WaaColorsEqualForView(UIColor *leftColor, UIColor *rightColor, UIView *view) {
    if (leftColor == rightColor) {
        return YES;
    }
    if (!leftColor || !rightColor) {
        return NO;
    }
    UIColor *resolvedLeft = [leftColor resolvedColorWithTraitCollection:view.traitCollection];
    UIColor *resolvedRight = [rightColor resolvedColorWithTraitCollection:view.traitCollection];
    return CGColorEqualToColor(resolvedLeft.CGColor, resolvedRight.CGColor);
}

static BOOL WaaAttributedTextNeedsColor(NSAttributedString *attributedText, UIColor *targetColor, UIView *view) {
    if (attributedText.length == 0) {
        return NO;
    }
    __block BOOL needsUpdate = NO;
    [attributedText enumerateAttribute:NSForegroundColorAttributeName
                              inRange:NSMakeRange(0, attributedText.length)
                              options:0
                           usingBlock:^(id colorValue, NSRange range, BOOL *stop) {
                             UIColor *color = [colorValue isKindOfClass:[UIColor class]] ? colorValue : nil;
                             if (!WaaColorsEqualForView(color, targetColor, view)) {
                                 needsUpdate = YES;
                                 *stop = YES;
                             }
                           }];
    return needsUpdate;
}

static void WaaApplyAllCommentTextAndIconColors(UIView *view, UIColor *textColor, UIColor *iconColor) {
    if (!WaaViewShouldReceiveCommentAppearance(view)) {
        return;
    }

    if ([view respondsToSelector:@selector(setTextColor:)]) {
        UIColor *currentColor = [view respondsToSelector:@selector(textColor)] ? [(id)view textColor] : nil;
        if (!WaaColorsEqualForView(currentColor, textColor, view)) {
            [(id)view setTextColor:textColor];
        }
    }

    if ([view respondsToSelector:@selector(attributedText)] && [view respondsToSelector:@selector(setAttributedText:)]) {
        NSAttributedString *attributedText = [(id)view attributedText];
        if (WaaAttributedTextNeedsColor(attributedText, textColor, view)) {
            NSMutableAttributedString *updatedText = [attributedText mutableCopy];
            [updatedText addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, updatedText.length)];
            [(id)view setAttributedText:updatedText];
        }
    }

    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        NSAttributedString *placeholder = textField.attributedPlaceholder;
        if (WaaAttributedTextNeedsColor(placeholder, textColor, view)) {
            NSMutableAttributedString *updatedPlaceholder = [placeholder mutableCopy];
            [updatedPlaceholder addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, updatedPlaceholder.length)];
            textField.attributedPlaceholder = updatedPlaceholder;
        }
    }

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        for (NSNumber *stateValue in @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateSelected), @(UIControlStateDisabled)]) {
            UIControlState state = (UIControlState)stateValue.unsignedIntegerValue;
            if (!WaaColorsEqualForView([button titleColorForState:state], textColor, view)) {
                [button setTitleColor:textColor forState:state];
            }
            NSAttributedString *attributedTitle = [button attributedTitleForState:state];
            if (WaaAttributedTextNeedsColor(attributedTitle, textColor, view)) {
                NSMutableAttributedString *updatedTitle = [attributedTitle mutableCopy];
                [updatedTitle addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, updatedTitle.length)];
                [button setAttributedTitle:updatedTitle forState:state];
            }
            UIImage *image = [button imageForState:state];
            if (WaaCommentButtonImageLooksLikeIcon(button, image) && image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                [button setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:state];
            }
        }
        if (!WaaColorsEqualForView(button.tintColor, iconColor, view)) {
            button.tintColor = iconColor;
        }
    }

    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        if (WaaCommentImageLooksLikeIcon(imageView)) {
            if (imageView.image && imageView.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                imageView.image = [imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            if (imageView.highlightedImage && imageView.highlightedImage.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                imageView.highlightedImage = [imageView.highlightedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            if (!WaaColorsEqualForView(imageView.tintColor, iconColor, view)) {
                imageView.tintColor = iconColor;
            }
        }
    }

    NSString *className = NSStringFromClass([view class]);
    if (([className containsString:@"Icon"] || [className containsString:@"SVG"]) &&
        !WaaColorsEqualForView(view.tintColor, iconColor, view)) {
        view.tintColor = iconColor;
    }
}

void WaaForceCommentDarkModeForViewTree(UIView *view) {
    if (!view) {
        return;
    }

    BOOL forceDarkMode = DYYYGetBool(@"WaaForceCommentDarkMode");
    UIUserInterfaceStyle targetStyle = forceDarkMode ? UIUserInterfaceStyleDark : UIUserInterfaceStyleUnspecified;
    if (WaaViewShouldReceiveCommentAppearance(view) || WaaViewIsCommentControllerRoot(view)) {
        if (view.overrideUserInterfaceStyle != targetStyle) {
            view.overrideUserInterfaceStyle = targetStyle;
        }

        if (forceDarkMode && WaaColorLooksLightForView(view.backgroundColor, view)) {
            view.backgroundColor = WaaCommentDarkBackgroundColorForView(view, view.backgroundColor);
        }
        if (forceDarkMode && view.layer.backgroundColor && WaaColorLooksLightForView([UIColor colorWithCGColor:view.layer.backgroundColor], view)) {
            view.layer.backgroundColor = WaaCommentDarkBackgroundColorForView(view, [UIColor colorWithCGColor:view.layer.backgroundColor]).CGColor;
        }

        NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@",
                                                         NSStringFromClass([view class]),
                                                         NSStringFromClass([view.superview class]),
                                                         targetStyle == UIUserInterfaceStyleDark ? @"dark" : @"unspecified",
                                                         WaaCommentColorDescription(view.backgroundColor, view.traitCollection),
                                                         WaaCommentCGColorDescription(view.layer.backgroundColor, view.traitCollection),
                                                         @((long)view.traitCollection.userInterfaceStyle)];
        NSString *previousSignature = objc_getAssociatedObject(view, &kWaaCommentDarkTreeLogSignaturesKey);
        if (![previousSignature isEqualToString:signature]) {
            objc_setAssociatedObject(view, &kWaaCommentDarkTreeLogSignaturesKey, signature, OBJC_ASSOCIATION_COPY_NONATOMIC);
            NSLog(@"[DYYY][CommentAppearance][DarkTree] class=%@ parent=%@ override=%@ trait=%@ background=%@ layerBackground=%@",
                  NSStringFromClass([view class]),
                  NSStringFromClass([view.superview class]),
                  targetStyle == UIUserInterfaceStyleDark ? @"dark" : @"unspecified",
                  @((long)view.traitCollection.userInterfaceStyle),
                  WaaCommentColorDescription(view.backgroundColor, view.traitCollection),
                  WaaCommentCGColorDescription(view.layer.backgroundColor, view.traitCollection));
        }
    }

    for (UIView *subview in view.subviews) {
        WaaForceCommentDarkModeForViewTree(subview);
    }
}

static void WaaApplyCommentAppearanceToViewTree(UIView *view, UIColor *textColor, UIColor *iconColor) {
    if (!view) {
        return;
    }
    if (WaaViewShouldReceiveCommentAppearance(view)) {
        WaaApplyAllCommentTextAndIconColors(view, textColor, iconColor);
    }
    for (UIView *subview in view.subviews) {
        WaaApplyCommentAppearanceToViewTree(subview, textColor, iconColor);
    }
}

void WaaApplyCommentAppearanceAfterLayout(UIView *view) {
    BOOL isCommentControllerRoot = WaaViewIsCommentControllerRoot(view);
    BOOL shouldApplyCurrentView = WaaViewShouldReceiveCommentAppearance(view);
    if (shouldApplyCurrentView) {
        WaaForceCommentDarkModeForViewTree(view);
    }
    WaaLogAllCommentTextAndIconColorsIfChanged(view);
    BOOL isCommentColorEnabled = DYYYGetBool(@"WaaEnableCommentColor");
    static NSInteger lastLoggedEnabledState = -1;
    NSInteger enabledState = isCommentColorEnabled ? 1 : 0;
    if (lastLoggedEnabledState != enabledState) {
        lastLoggedEnabledState = enabledState;
        NSLog(@"[DYYY][CommentAppearance][Text] enabled=%@ entryViewClass=%@", isCommentColorEnabled ? @"YES" : @"NO", NSStringFromClass([view class]));
    }

    if (isCommentColorEnabled) {
        NSString *customHexColor = DYYYGetString(@"WaaCommentColor");
        static NSString *lastLoggedColorConfig = nil;
        @synchronized([UIView class]) {
            if (![lastLoggedColorConfig isEqualToString:customHexColor ?: @""]) {
                lastLoggedColorConfig = [customHexColor copy] ?: @"";
                NSLog(@"[DYYY][CommentAppearance][Text] config enabled=YES value=\"%@\" entryViewClass=%@", lastLoggedColorConfig, NSStringFromClass([view class]));
            }
        }
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

        if (!customColor) {
            static NSString *lastInvalidColorConfig = nil;
            @synchronized([UIView class]) {
                if (![lastInvalidColorConfig isEqualToString:customHexColor ?: @""]) {
                    lastInvalidColorConfig = [customHexColor copy] ?: @"";
                    NSLog(@"[DYYY][CommentAppearance][Text] invalidColor value=\"%@\"", lastInvalidColorConfig);
                }
            }
        }

        // 评论区全部文字与可识别图标统一改色
        if (customColor) {
            UIColor *darkerColor = darkerColorForColor(customColor);
            if (isCommentControllerRoot) {
                WaaApplyCommentAppearanceToViewTree(view, customColor, customColor);
            } else {
                WaaApplyAllCommentTextAndIconColors(view, customColor, customColor);
            }
            WaaLogAllCommentTextAndIconColorsIfChanged(view);

            Class YYLabelClass = NSClassFromString(@"YYLabel");

            for (UIView *subview in view.subviews) {
                BOOL isUILabel = [subview isKindOfClass:[UILabel class]];
                BOOL isYYLabel = YYLabelClass && [subview isKindOfClass:YYLabelClass];
                if (isUILabel || isYYLabel) {
                    UIColor *beforeColor = [subview respondsToSelector:@selector(textColor)] ? [(id)subview textColor] : nil;
                    NSString *target = nil;
                    UIColor *targetColor = nil;

                    if (isUILabel && WaaClassNameMatches(subview, @"AWECommentSwiftBizUI", @"CommentInteractionBaseLabel")) {
                        target = @"interaction";
                        targetColor = darkerColor;
                    } else if (isYYLabel && WaaClassNameMatches(subview, @"AWECommentPanelListSwiftImpl", @"BaseCellCommentLabel")) {
                        target = @"content";
                        targetColor = customColor;
                    } else if (isUILabel && WaaClassNameMatches(subview, @"AWECommentPanelHeaderSwiftImpl", @"CommentHeaderCell")) {
                        target = @"header";
                        targetColor = customColor;
                    }

                    if (targetColor && [subview respondsToSelector:@selector(setTextColor:)]) {
                        [(id)subview setTextColor:targetColor];
                        WaaLogCommentLabelIfChanged(subview, @"matched", target, beforeColor, [(id)subview textColor]);
                    } else if (WaaViewIsInCommentScope(subview)) {
                        WaaLogCommentLabelIfChanged(subview, @"candidate", @"unmatched", beforeColor, beforeColor);
                    }
                }
            }

            // 展开按钮
            for (UIView *subview in view.subviews) {
                if ([subview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)subview;
                    NSString *buttonText = [button titleForState:UIControlStateNormal];
                    if ([buttonText containsString:@"展开"] && [buttonText containsString:@"条回复"]) {
                        UIColor *beforeColor = [button titleColorForState:UIControlStateNormal];
                        [button setTitleColor:darkerColor forState:UIControlStateNormal];
                        UILabel *titleLabel = button.titleLabel;
                        WaaLogCommentLabelIfChanged(titleLabel, @"reply-button", @"expandReplies", beforeColor, [button titleColorForState:UIControlStateNormal]);
                    }
                }
            }

            [view traverseSubviews:view customColor:customColor];
        }
    }

    // 点赞数量
    UIView *superview = view.superview;
    while (superview) {
        if (WaaClassNameMatches(superview, @"AWECommentPanelListSwiftImpl", @"ActionView")) {
            if (isCommentColorEnabled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [view updateActionViewLabelColorRecursive:view];
                });
            }
            break;
        }
        superview = superview.superview;
    }

    // 隐藏输入框上方横线
    for (UIView *subview in view.subviews) {
        CGRect frame = subview.frame;

        BOOL isInTargetContainer = WaaClassNameMatches(subview.superview, @"AWECommentInputViewSwiftImpl", @"CommentInputViewMiddleContainer");
        CGFloat parentWidth = view.bounds.size.width;
        BOOL widthMatch = fabs(frame.size.width - parentWidth) < 1.0;
        BOOL heightMatch = frame.size.height > 0 && frame.size.height < 1.0;

        if (isInTargetContainer && widthMatch && heightMatch) {
            subview.hidden = YES;
        }
    }
}

// 调整评论区图标颜色
BOOL isTargetCommentSubview(UIView *view) {
    while (view) {
        if (WaaClassNameMatches(view, @"AWECommentPanelListSwiftImpl", @"ActionView") ||
            WaaClassNameMatches(view, @"AWECommentPanelListSwiftImpl", @"CommentFooterView")) {
            return YES;
        }
        view = view.superview;
    }
    return NO;
}

UIImage *WaaCommentImageForDisplay(UIImageView *imageView, UIImage *image) {
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

    if (isCommentColorEnabled && customColor && isTargetCommentSubview(imageView)) {
        imageView.tintColor = customColor;
        return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    return image;
}

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

// 清屏弹幕参数可从设置里调，未设置时用上面的硬编码默认值
static CGFloat WaaDanmakuFloatSetting(NSString *key, CGFloat fallback, CGFloat minValue, CGFloat maxValue) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    if (!value) {
        return fallback;
    }
    CGFloat number = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : fallback;
    if (!isfinite(number) || number < minValue || number > maxValue) {
        return fallback;
    }
    return number;
}

// 弹幕行数上限
static NSUInteger WaaDanmakuMaxLaneCount(void) {
    return (NSUInteger)WaaDanmakuFloatSetting(@"WaaPureDanmakuMaxLanes", kWaaDanmakuMaxLaneCount, 1, 20);
}

// 弹幕滚过屏幕所需秒数，越小越快
static NSTimeInterval WaaDanmakuTravelDuration(void) {
    return WaaDanmakuFloatSetting(@"WaaPureDanmakuSpeed", kWaaDanmakuTravelDuration, 2.0, 30.0);
}

// 弹幕轨道行高，影响密度
static CGFloat WaaDanmakuLaneHeight(void) {
    return WaaDanmakuFloatSetting(@"WaaPureDanmakuLaneHeight", kWaaDanmakuLaneHeight, 20.0, 60.0);
}

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

// 判断 UTF-32 码点是否落在 emoji 常用区间
static BOOL WaaScalarIsEmoji(UTF32Char scalar) {
    return (scalar >= 0x1F000 && scalar <= 0x1FAFF) ||  // 主 emoji 平面
           (scalar >= 0x2600 && scalar <= 0x27BF) ||    // 杂项符号与装饰符号（☀❤✌等）
           (scalar >= 0x2B00 && scalar <= 0x2BFF);      // 补充符号（⭐⭕等）
}

// 弹幕富文本：白字；阴影只加给非 emoji 字符——视频背景深浅不定，文字靠阴影保证可读，
// 而 emoji 是彩色字形，叠黑阴影会显脏，所以逐字判断跳过
static NSAttributedString *WaaDanmakuAttributedString(NSString *text) {
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc]
        initWithString:text
            attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:kWaaDanmakuFontSize weight:UIFontWeightMedium],
                         NSForegroundColorAttributeName : UIColor.whiteColor}];

    static NSShadow *danmakuShadow = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      danmakuShadow = [[NSShadow alloc] init];
      danmakuShadow.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.85];
      danmakuShadow.shadowOffset = CGSizeMake(0.0, 1.0);
      danmakuShadow.shadowBlurRadius = 2.0;
    });

    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop) {
                            unichar first = [substring characterAtIndex:0];
                            UTF32Char scalar = first;
                            if (CFStringIsSurrogateHighCharacter(first) && substring.length > 1) {
                                scalar = CFStringGetLongCharacterForSurrogatePair(first, [substring characterAtIndex:1]);
                            }
                            if (!WaaScalarIsEmoji(scalar)) {
                                [attributed addAttribute:NSShadowAttributeName value:danmakuShadow range:substringRange];
                            }
                          }];
    return attributed;
}

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
    CGFloat laneHeight = WaaDanmakuLaneHeight();
    CGFloat usableHeight = CGRectGetHeight(self.bounds) - kWaaDanmakuTopInset - kWaaDanmakuBottomInset;
    if (usableHeight < laneHeight) {
        return 0;
    }
    return MIN((NSUInteger)floor(usableHeight / laneHeight), WaaDanmakuMaxLaneCount());
}

- (void)updateToTime:(double)time {
    // 向前大跨度跳转（拖动进度）时直接对齐游标，不把积压的弹幕一次性吹上屏
    if (time > self.lastUpdateTime + 2.0) {
        self.cursor = [self indexAfterTime:time];
    }
    self.lastUpdateTime = time;

    NSUInteger laneCount = [self laneCount];
    if (laneCount == 0 || self.items.count == 0) {
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
    label.attributedText = WaaDanmakuAttributedString(item.text);
    label.backgroundColor = UIColor.clearColor;
    label.numberOfLines = 1;
    label.layer.shouldRasterize = YES;
    label.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [label sizeToFit];

    CGFloat labelWidth = ceil(CGRectGetWidth(label.bounds));
    CGFloat laneHeight = WaaDanmakuLaneHeight();
    CGFloat labelY = kWaaDanmakuTopInset + lane * laneHeight;
    label.frame = CGRectMake(containerWidth, labelY, labelWidth, laneHeight);
    [self addSubview:label];

    CGFloat distance = containerWidth + labelWidth;
    NSTimeInterval duration = WaaDanmakuTravelDuration() * (distance / containerWidth);
    CGFloat speed = duration > 0.0 ? distance / duration : 0.0;
    // 等本条弹幕尾部完全离开右边缘再释放轨道，避免后一条追尾
    self.laneFreeTimes[lane] = @(time + (speed > 0.0 ? (labelWidth + kWaaDanmakuLaneGap) / speed : 0.0));

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        label.frame = CGRectMake(-labelWidth, labelY, labelWidth, laneHeight);
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
}

static void WaaInstallDanmakuRuntimeHooksIfNeeded(void) {
    WaaInstallDanmakuDataPoolHooksIfNeeded();
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

// 抖音表情占位符 → 系统 emoji 映射，让自绘弹幕无需抖音图片资源也能显示表情
static NSDictionary<NSString *, NSString *> *WaaDanmakuEmojiMap(void) {
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      map = @{
          @"微笑" : @"😊",     @"撇嘴" : @"😕",   @"色" : @"😍",       @"发呆" : @"😑",
          @"得意" : @"😏",     @"流泪" : @"😢",   @"害羞" : @"☺️",     @"闭嘴" : @"🤐",
          @"睡" : @"😴",       @"大哭" : @"😭",   @"尴尬" : @"😅",     @"发怒" : @"😡",
          @"调皮" : @"😜",     @"呲牙" : @"😁",   @"惊讶" : @"😲",     @"难过" : @"😔",
          @"囧" : @"😖",       @"抓狂" : @"😫",   @"吐" : @"🤮",       @"偷笑" : @"🤭",
          @"愉快" : @"😄",     @"白眼" : @"🙄",   @"傲慢" : @"😤",     @"困" : @"🥱",
          @"惊恐" : @"😱",     @"流汗" : @"😓",   @"憨笑" : @"😆",     @"悠闲" : @"😌",
          @"奋斗" : @"💪",     @"咒骂" : @"🤬",   @"疑问" : @"🤔",     @"嘘" : @"🤫",
          @"晕" : @"😵",       @"衰" : @"😞",     @"骷髅" : @"💀",     @"敲打" : @"🔨",
          @"再见" : @"👋",     @"擦汗" : @"😥",   @"鼓掌" : @"👏",     @"坏笑" : @"😼",
          @"左哼哼" : @"😤",   @"右哼哼" : @"😤", @"哈欠" : @"🥱",     @"鄙视" : @"😒",
          @"委屈" : @"🥺",     @"快哭了" : @"🥹", @"阴险" : @"😈",     @"亲亲" : @"😘",
          @"可怜" : @"🥺",     @"笑脸" : @"😀",   @"生病" : @"🤒",     @"脸红" : @"😳",
          @"破涕为笑" : @"😂", @"笑哭" : @"😂",   @"恐惧" : @"😨",     @"失望" : @"😞",
          @"无语" : @"😶",     @"嘿哈" : @"😄",   @"捂脸" : @"🤦",     @"奸笑" : @"😈",
          @"机智" : @"🤓",     @"皱眉" : @"😟",   @"耶" : @"✌️",       @"吃瓜" : @"🍉",
          @"加油" : @"💪",     @"汗" : @"😓",     @"天啊" : @"😱",     @"Emm" : @"😐",
          @"社会社会" : @"😎", @"旺柴" : @"🐶",   @"好的" : @"👌",     @"哇" : @"😮",
          @"打脸" : @"🤦",     @"我想静静" : @"😌", @"舔屏" : @"😋",   @"暗中观察" : @"👀",
          @"酷" : @"😎",       @"可爱" : @"🥰",   @"饥饿" : @"🤤",     @"疯了" : @"🤪",
          @"糗大了" : @"😅",   @"示爱" : @"❤️",   @"爱心" : @"❤️",     @"心碎" : @"💔",
          @"玫瑰" : @"🌹",     @"凋谢" : @"🥀",   @"蛋糕" : @"🎂",     @"礼物" : @"🎁",
          @"便便" : @"💩",     @"月亮" : @"🌙",   @"太阳" : @"☀️",     @"闪电" : @"⚡",
          @"炸弹" : @"💣",     @"足球" : @"⚽",   @"篮球" : @"🏀",     @"咖啡" : @"☕",
          @"啤酒" : @"🍺",     @"西瓜" : @"🍉",   @"猪头" : @"🐷",     @"菜刀" : @"🔪",
          @"强" : @"👍",       @"弱" : @"👎",     @"握手" : @"🤝",     @"胜利" : @"✌️",
          @"抱拳" : @"🙏",     @"拳头" : @"✊",   @"OK" : @"👌",       @"爱你" : @"🤟",
          @"NO" : @"🙅",       @"点赞" : @"👍",   @"比心" : @"🫰",     @"666" : @"🤙",
          @"不失礼貌的微笑" : @"🙂"
      };
    });
    return map;
}

// 归一化弹幕文本：剥掉富文本附件残留的 U+FFFC，把 [表情] 占位符替换成系统 emoji
// 未识别的占位符原样保留，方便后续补映射
static NSString *WaaNormalizeDanmakuText(NSString *text) {
    if (text.length == 0) {
        return nil;
    }
    NSString *result = [text stringByReplacingOccurrencesOfString:@"\uFFFC" withString:@""];
    if (![result containsString:@"["]) {
        return result.length > 0 ? result : nil;
    }

    static NSRegularExpression *placeholderRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      placeholderRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\[\\]]{1,12})\\]" options:0 error:nil];
    });

    NSDictionary<NSString *, NSString *> *emojiMap = WaaDanmakuEmojiMap();
    NSMutableString *normalized = [NSMutableString stringWithCapacity:result.length];
    __block NSUInteger location = 0;
    [placeholderRegex enumerateMatchesInString:result
                                       options:0
                                         range:NSMakeRange(0, result.length)
                                    usingBlock:^(NSTextCheckingResult *match, __unused NSMatchingFlags flags, __unused BOOL *stop) {
                                      NSString *emoji = emojiMap[[result substringWithRange:[match rangeAtIndex:1]]];
                                      if (emoji.length == 0) {
                                          return;
                                      }
                                      [normalized appendString:[result substringWithRange:NSMakeRange(location, match.range.location - location)]];
                                      [normalized appendString:emoji];
                                      location = NSMaxRange(match.range);
                                    }];
    if (location == 0) {
        return result;
    }
    [normalized appendString:[result substringFromIndex:location]];
    return normalized.length > 0 ? normalized : nil;
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
        NSString *text = WaaNormalizeDanmakuText(WaaDanmakuTextOf(model));
        double time = WaaDanmakuTimeOf(model);
        if (text.length == 0 || time < 0.0) {
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
    }

    double previousTime = state.lastTimeSyncValue;
    // 严格限定：必须是可信播放时间（>1s）真实回到接近开头（<0.3s）才算循环。
    // 5.9→0、18.4→0 这种时间源切换造成的突变不满足条件，避免误触发清空
    BOOL didRestartVideoLoop = state.hasLastTimeSyncValue &&
                               previousTime > 1.0 &&
                               currentTime < 0.3 &&
                               currentTime + 0.5 < previousTime;

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
        [overlay resetForLoop];
    }
    if (isPaused) {
        return;
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