#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;

// 统一替换处理逻辑
static NSString *ProcessText(UILabel *label, NSString *text) {
    if (!text || ![text isKindOfClass:[NSString class]]) return text;
    
    // 匹配 🄷🅆🅅🄸🄿 (\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F) 或 HWVIP
    if ([text containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [text containsString:@"HWVIP"]) {
        
        BOOL isDock = NO;
        
        // 1. 检查视图父级类名
        UIView *curr = label;
        while (curr) {
            NSString *cls = NSStringFromClass([curr class]);
            if ([cls containsString:@"Dock"] || [cls containsString:@"TabBar"] || [cls containsString:@"Bottom"]) {
                isDock = YES;
                break;
            }
            curr = curr.superview;
        }
        
        // 2. 检查屏幕位置：如果 Y 轴位于屏幕底部 20% 区域内，判定为底部 Dock 栏
        if (!isDock && label.window) {
            CGRect rect = [label convertRect:label.bounds toView:nil];
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            if (rect.origin.y > screenHeight * 0.75) {
                isDock = YES;
            }
        }
        
        if (isDock) {
            return @"\u9996\u9875"; // 替换为 "首页"
        } else {
            return @"Profile";    // 详情页恢复为 "Profile"
        }
    }
    return text;
}

// 1. Hook 普通文本 setText:
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    NSString *newText = ProcessText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, newText);
}

// 2. Hook 富文本 setAttributedText:
static void CustomSetAttributedText(UILabel *self, SEL _cmd, NSAttributedString *attrText) {
    if (attrText && [attrText isKindOfClass:[NSAttributedString class]]) {
        NSString *str = attrText.string;
        if ([str containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [str containsString:@"HWVIP"]) {
            NSString *replacedStr = ProcessText(self, str);
            NSMutableAttributedString *mutableAttr = [attrText mutableCopy];
            [mutableAttr replaceCharactersInRange:NSMakeRange(0, attrText.length) withString:replacedStr];
            ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, mutableAttr);
            return;
        }
    }
    ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, attrText);
}

// 入口
__attribute__((constructor)) static void entry() {
    Class class = [UILabel class];
    
    // 拦截 setText:
    SEL selSetText = @selector(setText:);
    Method mSetText = class_getInstanceMethod(class, selSetText);
    if (mSetText) {
        gOriginalSetText = method_setImplementation(mSetText, (IMP)CustomSetText);
    }
    
    // 拦截 setAttributedText:
    SEL selSetAttr = @selector(setAttributedText:);
    Method mSetAttr = class_getInstanceMethod(class, selSetAttr);
    if (mSetAttr) {
        gOriginalSetAttributedText = method_setImplementation(mSetAttr, (IMP)CustomSetAttributedText);
    }
}
