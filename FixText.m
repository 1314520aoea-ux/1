#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;

// 判断并返回替换后的文本
static NSString *GetReplacementText(UILabel *label, NSString *text) {
    if (!text || ![text isKindOfClass:[NSString class]]) return text;
    
    // 匹配 🄷🅆🅅🄸🄿 或 HWVIP
    if ([text containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [text containsString:@"HWVIP"]) {
        BOOL isDock = NO;
        UIView *curr = label;
        while (curr) {
            NSString *cls = NSStringFromClass([curr class]);
            if ([cls containsString:@"Dock"] || [cls containsString:@"TabBar"] || [cls containsString:@"Bottom"]) {
                isDock = YES;
                break;
            }
            curr = curr.superview;
        }
        
        if (!isDock && label.window) {
            CGRect rect = [label convertRect:label.bounds toView:nil];
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            if (rect.origin.y > screenHeight * 0.75) {
                isDock = YES;
            }
        }
        
        return isDock ? @"\u9996\u9875" : @"Profile";
    }
    return text;
}

// Hook setText:
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, newText);
}

// Hook setAttributedText:
static void CustomSetAttributedText(UILabel *self, SEL _cmd, NSAttributedString *attrText) {
    if (attrText && [attrText isKindOfClass:[NSAttributedString class]]) {
        NSString *str = attrText.string;
        if ([str containsString:@"\U0001F137\U0001F146\U0001F145\U0001F138\U0001F13F"] || [str containsString:@"HWVIP"]) {
            NSString *replaced = GetReplacementText(self, str);
            NSDictionary *attrs = attrText.length > 0 ? [attrText attributesAtIndex:0 effectiveRange:NULL] : nil;
            NSAttributedString *newAttr = [[NSAttributedString alloc] initWithString:replaced attributes:attrs];
            ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, newAttr);
            return;
        }
    }
    ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, attrText);
}

__attribute__((constructor)) static void entry() {
    Class class = [UILabel class];
    
    SEL sel1 = @selector(setText:);
    Method m1 = class_getInstanceMethod(class, sel1);
    if (m1) gOriginalSetText = method_setImplementation(m1, (IMP)CustomSetText);
    
    SEL sel2 = @selector(setAttributedText:);
    Method m2 = class_getInstanceMethod(class, sel2);
    if (m2) gOriginalSetAttributedText = method_setImplementation(m2, (IMP)CustomSetAttributedText);
}
