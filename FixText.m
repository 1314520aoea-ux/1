#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;

// 判断是否属于底部 TabBar 或 Dock 容器
static BOOL IsInDockBar(UIView *view) {
    UIView *curr = view;
    while (curr) {
        NSString *cls = NSStringFromClass([curr class]);
        // 严格精确匹配底部导航栏类名
        if ([cls containsString:@"TabBar"] || 
            [cls containsString:@"Dock"] || 
            [cls containsString:@"UITabBarButton"]) {
            return YES;
        }
        curr = curr.superview;
    }
    return NO;
}

// 提取与替换逻辑
static NSString *GetReplacementText(UILabel *label, NSString *originalText) {
    if (!originalText || ![originalText isKindOfClass:[NSString class]]) {
        return originalText;
    }
    
    // 匹配 🄷🅆🅅🄸🄿 (\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F) 或 HWVIP
    if ([originalText containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || 
        [originalText containsString:@"HWVIP"]) {
        
        if (IsInDockBar(label)) {
            return @"\u9996\u9875"; // 底部 Dock 栏替换为 "首页"
        } else {
            return @"Profile";    // 详情页等其他位置替换为 "Profile"
        }
    }
    return originalText;
}

// 1. Hook 普通文本 setText:
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, newText);
}

// 2. Hook 富文本 setAttributedText:
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

// 动态库入口
__attribute__((constructor)) static void entry() {
    Class class = [UILabel class];
    
    SEL sel1 = @selector(setText:);
    Method m1 = class_getInstanceMethod(class, sel1);
    if (m1) {
        gOriginalSetText = method_setImplementation(m1, (IMP)CustomSetText);
    }
    
    SEL sel2 = @selector(setAttributedText:);
    Method m2 = class_getInstanceMethod(class, sel2);
    if (m2) {
        gOriginalSetAttributedText = method_setImplementation(m2, (IMP)CustomSetAttributedText);
    }
}
