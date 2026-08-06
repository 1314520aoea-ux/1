#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;

// 拦截并替换 UILabel 文字
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    if (text && [text isKindOfClass:[NSString class]]) {
        // \U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F 对应 🄷🅆🅅🄸🄿
        if ([text containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [text containsString:@"HWVIP"]) {
            // \u9996\u9875 对应 首页
            text = @"\u9996\u9875";
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
