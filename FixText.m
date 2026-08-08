#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;

// 拦截并替换 UILabel 文字
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    if (text && [text isKindOfClass:[NSString class]]) {
        // 匹配 🄷🅆🅅🄸🄿 或 HWVIP
        if ([text containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [text containsString:@"HWVIP"]) {
            
            BOOL isDock = NO;
            UIView *curr = self;
            
            // 向上遍历父视图，判断是否属于底栏/Tab 栏容器
            while (curr) {
                NSString *cls = NSStringFromClass([curr class]);
                if ([cls containsString:@"Dock"] || 
                    [cls containsString:@"Tab"] || 
                    [cls containsString:@"Bar"] || 
                    [cls containsString:@"Bottom"]) {
                    isDock = YES;
                    break;
                }
                curr = curr.superview;
            }
            
            if (isDock) {
                text = @"\u9996\u9875"; // 底部 Dock 栏显示 "首页"
            } else {
                text = @"Profile";    // 详情页等其他地方恢复为 "Profile"
            }
        }
    }
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, text);
}

// 动态库入口
__attribute__((constructor)) static void entry() {
    Class class = [UILabel class];
    SEL selector = @selector(setText:);
    Method method = class_getInstanceMethod(class, selector);
    if (method) {
        gOriginalSetText = method_setImplementation(method, (IMP)CustomSetText);
    }
}

