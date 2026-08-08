#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;

// 辅助函数：判断 Label 是否位于底部 Dock 栏/ Tab 栏区域
static BOOL IsInDockBar(UIView *view) {
    UIView *current = view;
    while (current) {
        NSString *className = NSStringFromClass([current class]);
        if ([className containsString:@"Dock"] ||
            [className containsString:@"Tab"] ||
            [className containsString:@"Bar"] ||
            [className containsString:@"Bottom"] ||
            [className containsString:@"Footer"] ||
            [className containsString:@"Menu"]) {
            return YES;
        }
        current = current.superview;
    }
    return NO;
}

// 拦截并替换 UILabel 文字
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    if (text && [text isKindOfClass:[NSString class]]) {
        // 匹配 🄷🅆🅅🄸🄿 (\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F) 或 HWVIP
        if ([text containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [text containsString:@"HWVIP"]) {
            
            // 判断逻辑：如果在 Dock 栏内、或文字居中对齐、或字号小于 12pt，则判定为首页标签
            if (IsInDockBar(self) || self.textAlignment == NSTextAlignmentCenter || self.font.pointSize < 12.0) {
                text = @"\u9996\u9875"; // 替换为 "首页"
            } else {
                text = @"Profile";    // 详情页等其他地方恢复为 "Profile"
            }
        }
    }
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, text);
}

// 动态库加载入口
__attribute__((constructor)) static void entry() {
    Class class = [UILabel class];
    SEL selector = @selector(setText:);
    Method method = class_getInstanceMethod(class, selector);
    if (method) {
        gOriginalSetText = method_setImplementation(method, (IMP)CustomSetText);
    }
}
