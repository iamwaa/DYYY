#import "DYYYHideMusicButtonHooks.h"

#import "AwemeHeaders.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdatomic.h>

static NSString *const kDYYYHideMusicButtonKey = @"DYYYHideMusicButton";
static NSString *const kDYYYHideCancelMuteKey = @"DYYYHideCancelMute";

typedef void (*DYYYVoidLayoutIMP)(id, SEL);
typedef void (*DYYYWillMoveToSuperviewIMP)(id, SEL, UIView *);

typedef struct {
    const char *className;
    DYYYVoidLayoutIMP *originalSlot;
    DYYYVoidLayoutIMP replacement;
    BOOL required;
} DYYYHideMusicLayoutHookSpec;

static atomic_bool gDYYYHideMusicButtonHooksStarted = false;

static DYYYVoidLayoutIMP gOrigMusicCoverButtonLayout = NULL;
static DYYYVoidLayoutIMP gOrigListenFeedViewLayout = NULL;
static DYYYVoidLayoutIMP gOrigCancelMuteAwemeViewLayout = NULL;
static DYYYWillMoveToSuperviewIMP gOrigCancelMuteAwemeViewWillMove = NULL;

static BOOL DYYYHideMusicButtonEnabled(void) {
    return DYYYGetBool(kDYYYHideMusicButtonKey);
}

static void DYYYHideMusicCoverButtonIfNeeded(UIView *button) {
    if (!DYYYHideMusicButtonEnabled() || ![button isKindOfClass:[UIView class]]) {
        return;
    }

    if ([button.accessibilityLabel isEqualToString:@"音乐详情"]) {
        button.alpha = 0;
    }
}

static void DYYYHideListenFeedViewIfNeeded(UIView *view) {
    if (DYYYHideMusicButtonEnabled() && [view isKindOfClass:[UIView class]]) {
        view.alpha = 0;
    }
}

static void DYYYHideCancelMuteViewIfNeeded(UIView *view) {
    if (!DYYYGetBool(kDYYYHideCancelMuteKey) || ![view isKindOfClass:[UIView class]]) {
        return;
    }

    UIView *superview = view.superview;
    if ([superview isKindOfClass:NSClassFromString(@"AWEBaseElementView")] && DYYYHideMusicButtonEnabled()) {
        [superview removeFromSuperview];
        return;
    }

    view.hidden = YES;
}

#pragma mark - Replacements

static void DYYYMusicCoverButtonLayoutSubviews(id self, SEL _cmd) {
    if (gOrigMusicCoverButtonLayout) {
        gOrigMusicCoverButtonLayout(self, _cmd);
    }
    DYYYHideMusicCoverButtonIfNeeded((UIView *)self);
}

static void DYYYListenFeedViewLayoutSubviews(id self, SEL _cmd) {
    if (gOrigListenFeedViewLayout) {
        gOrigListenFeedViewLayout(self, _cmd);
    }
    DYYYHideListenFeedViewIfNeeded((UIView *)self);
}

static void DYYYCancelMuteAwemeViewLayoutSubviews(id self, SEL _cmd) {
    if (gOrigCancelMuteAwemeViewLayout) {
        gOrigCancelMuteAwemeViewLayout(self, _cmd);
    }
    DYYYHideCancelMuteViewIfNeeded((UIView *)self);
}

static void DYYYCancelMuteAwemeViewWillMoveToSuperview(id self, SEL _cmd, UIView *newSuperview) {
    if (gOrigCancelMuteAwemeViewWillMove) {
        gOrigCancelMuteAwemeViewWillMove(self, _cmd, newSuperview);
    }

    if (newSuperview != nil || !DYYYHideMusicButtonEnabled()) {
        return;
    }

    UIView *superview = [(UIView *)self superview];
    if ([superview isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) {
        [superview removeFromSuperview];
    }
}

#pragma mark - Install

static BOOL DYYYMethodLooksLikeVoidLayoutSubviews(Method method) {
    if (!method) {
        return NO;
    }
    const char *typeEncoding = method_getTypeEncoding(method);
    if (!typeEncoding) {
        return NO;
    }
    // layoutSubviews -> v16@0:8
    return typeEncoding[0] == 'v';
}

static BOOL DYYYInstallLayoutSubviewsHook(Class cls, DYYYVoidLayoutIMP replacement, DYYYVoidLayoutIMP *originalSlot, BOOL required) {
    if (!cls || !replacement || !originalSlot) {
        return NO;
    }

    SEL selector = @selector(layoutSubviews);
    Method existing = class_getInstanceMethod(cls, selector);
    if (!existing || !DYYYMethodLooksLikeVoidLayoutSubviews(existing)) {
        if (required) {
            NSLog(@"[DYYY][RuntimeHook][HideMusicButton] 缺少 layoutSubviews：%@", NSStringFromClass(cls));
        }
        return NO;
    }

    const char *typeEncoding = method_getTypeEncoding(existing);
    IMP existingIMP = method_getImplementation(existing);
    if (existingIMP == (IMP)replacement) {
        return *originalSlot != NULL;
    }

    // class_getInstanceMethod 会沿继承链查找；用 class_copyMethodList 判断本类是否已有实现。
    BOOL methodDefinedOnClass = NO;
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        if (method_getName(methods[i]) == selector) {
            methodDefinedOnClass = YES;
            break;
        }
    }
    free(methods);

    if (!methodDefinedOnClass) {
        IMP superIMP = existingIMP;
        if (!class_addMethod(cls, selector, (IMP)replacement, typeEncoding)) {
            if (required) {
                NSLog(@"[DYYY][RuntimeHook][HideMusicButton] class_addMethod 失败：%@", NSStringFromClass(cls));
            }
            return NO;
        }
        *originalSlot = (DYYYVoidLayoutIMP)superIMP;
        return YES;
    }

    IMP previous = method_setImplementation(existing, (IMP)replacement);
    if (!previous || previous == (IMP)replacement) {
        NSLog(@"[DYYY][RuntimeHook][HideMusicButton] 无法保存原 IMP：%@", NSStringFromClass(cls));
        return NO;
    }
    *originalSlot = (DYYYVoidLayoutIMP)previous;
    return YES;
}

static BOOL DYYYInstallWillMoveToSuperviewHook(Class cls) {
    if (!cls) {
        return NO;
    }

    SEL selector = @selector(willMoveToSuperview:);
    Method existing = class_getInstanceMethod(cls, selector);
    if (!existing) {
        NSLog(@"[DYYY][RuntimeHook][HideMusicButton] 缺少 willMoveToSuperview:：%@", NSStringFromClass(cls));
        return NO;
    }

    const char *typeEncoding = method_getTypeEncoding(existing);
    IMP existingIMP = method_getImplementation(existing);
    if (existingIMP == (IMP)DYYYCancelMuteAwemeViewWillMoveToSuperview) {
        return gOrigCancelMuteAwemeViewWillMove != NULL;
    }

    BOOL methodDefinedOnClass = NO;
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        if (method_getName(methods[i]) == selector) {
            methodDefinedOnClass = YES;
            break;
        }
    }
    free(methods);

    if (!methodDefinedOnClass) {
        if (!class_addMethod(cls, selector, (IMP)DYYYCancelMuteAwemeViewWillMoveToSuperview, typeEncoding)) {
            NSLog(@"[DYYY][RuntimeHook][HideMusicButton] class_addMethod 失败：%@ willMoveToSuperview:", NSStringFromClass(cls));
            return NO;
        }
        gOrigCancelMuteAwemeViewWillMove = (DYYYWillMoveToSuperviewIMP)existingIMP;
        return YES;
    }

    IMP previous = method_setImplementation(existing, (IMP)DYYYCancelMuteAwemeViewWillMoveToSuperview);
    if (!previous || previous == (IMP)DYYYCancelMuteAwemeViewWillMoveToSuperview) {
        NSLog(@"[DYYY][RuntimeHook][HideMusicButton] 无法保存原 IMP：%@ willMoveToSuperview:", NSStringFromClass(cls));
        return NO;
    }
    gOrigCancelMuteAwemeViewWillMove = (DYYYWillMoveToSuperviewIMP)previous;
    return YES;
}

void DYYYStartHideMusicButtonHooks(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYHideMusicButtonHooksStarted, &expected, true)) {
        return;
    }

    DYYYHideMusicLayoutHookSpec specs[] = {
        {"AWEMusicCoverButton", &gOrigMusicCoverButtonLayout, DYYYMusicCoverButtonLayoutSubviews, YES},
        {"AWEPlayInteractionListenFeedView", &gOrigListenFeedViewLayout, DYYYListenFeedViewLayoutSubviews, YES},
        {"AFDCancelMuteAwemeView", &gOrigCancelMuteAwemeViewLayout, DYYYCancelMuteAwemeViewLayoutSubviews, YES},
    };

    NSUInteger installed = 0;
    for (size_t i = 0; i < sizeof(specs) / sizeof(specs[0]); i++) {
        Class cls = objc_getClass(specs[i].className);
        if (!cls) {
            if (specs[i].required) {
                NSLog(@"[DYYY][RuntimeHook][HideMusicButton] 类未加载：%s", specs[i].className);
            }
            continue;
        }
        if (DYYYInstallLayoutSubviewsHook(cls, specs[i].replacement, specs[i].originalSlot, specs[i].required)) {
            installed += 1;
        }
    }

    Class cancelMuteClass = objc_getClass("AFDCancelMuteAwemeView");
    if (DYYYInstallWillMoveToSuperviewHook(cancelMuteClass)) {
        installed += 1;
    }

    NSLog(@"[DYYY][RuntimeHook][HideMusicButton] 安装完成，成功 %lu 个目标", (unsigned long)installed);
}
