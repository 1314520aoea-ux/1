#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;
static IMP gOriginalSetTitle = NULL;
static IMP gOriginalTVSetText = NULL;

// 1. 判断是否属于底部 TabBar / Dock 容器
static BOOL IsInDockBar(UIView *view) {
    UIView *curr = view;
    while (curr) {
        NSString *cls = NSStringFromClass([curr class]);
        if ([cls containsString:@"TabBar"] || 
            [cls containsString:@"Dock"] || 
            [cls containsString:@"UITabBarButton"]) {
            return YES;
        }
        curr = curr.superview;
    }
    return NO;
}

// 2. 核心文本替换逻辑
static NSString *GetReplacementText(UIView *view, NSString *originalText) {
    if (!originalText || ![originalText isKindOfClass:[NSString class]]) {
        return originalText;
    }
    
    // 匹配 🄷🅆🅅🄸🄿 (\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F) 或 HWVIP
    if ([originalText containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || 
        [originalText containsString:@"HWVIP"]) {
        
        if (IsInDockBar(view)) {
            return @"\u9996\u9875"; // 底部 Dock 栏替换为 "首页"
        } else {
            return @"Profile";    // 详情页等其他位置替换为 "Profile"
        }
    }
    return originalText;
}

// --- Hook 1: UILabel setText: ---
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, newText);
}

// --- Hook 2: UILabel setAttributedText: ---
static void CustomSetAttributedText(UILabel *self, SEL _cmd, NSAttributedString *attrText) {
    if (attrText && [attrText isKindOfClass:[NSAttributedString class]]) {
        NSString *str = attrText.string;
        if ([str containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || 
            [str containsString:@"HWVIP"]) {
            
            NSString *replaced = GetReplacementText(self, str);
            NSMutableAttributedString *mutableAttr = [attrText mutableCopy];
            [mutableAttr replaceCharactersInRange:NSMakeRange(0, attrText.length) withString:replaced];
            ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, mutableAttr);
            return;
        }
    }
    ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, attrText);
}

// --- Hook 3: UIButton setTitle:forState: ---
static void CustomSetTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    NSString *newTitle = GetReplacementText(self, title);
    ((void(*)(id, SEL, NSString *, UIControlState))gOriginalSetTitle)(self, _cmd, newTitle, state);
}

// --- Hook 4: UITextView setText: ---
static void CustomTVSetText(UITextView *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalTVSetText)(self, _cmd, newText);
}

// 动态库初始化入口
__attribute__((constructor)) static void entry() {
    Class labelCls = [UILabel class];
    SEL sel1 = @selector(setText:);
    Method m1 = class_getInstanceMethod(labelCls, sel1);
    if (m1) gOriginalSetText = method_setImplementation(m1, (IMP)CustomSetText);
    
    SEL sel2 = @selector(setAttributedText:);
    Method m2 = class_getInstanceMethod(labelCls, sel2);
    if (m2) gOriginalSetAttributedText = method_setImplementation(m2, (IMP)CustomSetAttributedText);
    
    Class btnCls = [UIButton class];
    SEL sel3 = @selector(setTitle:forState:);
    Method m3 = class_getInstanceMethod(btnCls, sel3);
    if (m3) gOriginalSetTitle = method_setImplementation(m3, (IMP)CustomSetTitle);
    
    Class tvCls = [UITextView class];
    SEL sel4 = @selector(setText:);
    Method m4 = class_getInstanceMethod(tvCls, sel4);
    if (m4) gOriginalTVSetText = method_setImplementation(m4, (IMP)CustomTVSetText);
}
