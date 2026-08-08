#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;
static IMP gOriginalUILabelLayout = NULL;
static IMP gOriginalSetTitle = NULL;
static IMP gOriginalUIButtonLayout = NULL;

// 判断并获取替换后的文本
static NSString *GetReplacementText(UIView *view, NSString *text) {
    if (!text || ![text isKindOfClass:[NSString class]]) return text;
    
    // 只要包含 🄷 (\U0001F137) 或 HWVIP 均进行拦截
    if ([text containsString:@"\U0001F137"] || [text containsString:@"HWVIP"]) {
        BOOL isDock = NO;
        
        // 1. 判断父视图容器类名
        UIView *curr = view;
        while (curr) {
            NSString *cls = NSStringFromClass([curr class]);
            if ([cls containsString:@"TabBar"] || 
                [cls containsString:@"Dock"] || 
                [cls containsString:@"UITabBarButton"]) {
                isDock = YES;
                break;
            }
            curr = curr.superview;
        }
        
        // 2. 依据屏幕坐标判断：屏幕底部 120pt 区域判定为 Dock 栏
        if (!isDock && view && view.window) {
            CGRect rect = [view convertRect:view.bounds toView:nil];
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            if (rect.origin.y > (screenHeight - 120) && rect.origin.y <= screenHeight) {
                isDock = YES;
            }
        }
        
        return isDock ? @"\u9996\u9875" : @"Profile";
    }
    return text;
}

// --- UILabel 拦截 ---
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, newText);
}

static void CustomSetAttributedText(UILabel *self, SEL _cmd, NSAttributedString *attrText) {
    if (attrText && [attrText isKindOfClass:[NSAttributedString class]]) {
        NSString *str = attrText.string;
        if ([str containsString:@"\U0001F137"] || [str containsString:@"HWVIP"]) {
            NSString *replaced = GetReplacementText(self, str);
            NSDictionary *attrs = attrText.length > 0 ? [attrText attributesAtIndex:0 effectiveRange:NULL] : nil;
            NSAttributedString *newAttr = [[NSAttributedString alloc] initWithString:replaced attributes:attrs];
            ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, newAttr);
            return;
        }
    }
    ((void(*)(id, SEL, NSAttributedString *))gOriginalSetAttributedText)(self, _cmd, attrText);
}

static void CustomUILabelLayout(UILabel *self, SEL _cmd) {
    ((void(*)(id, SEL))gOriginalUILabelLayout)(self, _cmd);
    NSString *text = self.text;
    if (text && [text isKindOfClass:[NSString class]]) {
        if ([text containsString:@"\U0001F137"] || [text containsString:@"HWVIP"]) {
            NSString *replaced = GetReplacementText(self, text);
            if (![text isEqualToString:replaced]) {
                self.text = replaced;
            }
        }
    }
}

// --- UIButton 拦截 ---
static void CustomSetTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    NSString *newTitle = GetReplacementText(self, title);
    ((void(*)(id, SEL, NSString *, UIControlState))gOriginalSetTitle)(self, _cmd, newTitle, state);
}

static void CustomUIButtonLayout(UIButton *self, SEL _cmd) {
    ((void(*)(id, SEL))gOriginalUIButtonLayout)(self, _cmd);
    NSString *title = [self titleForState:UIControlStateNormal];
    if (title && [title isKindOfClass:[NSString class]]) {
        if ([title containsString:@"\U0001F137"] || [title containsString:@"HWVIP"]) {
            NSString *replaced = GetReplacementText(self, title);
            if (![title isEqualToString:replaced]) {
                [self setTitle:replaced forState:UIControlStateNormal];
            }
        }
    }
}

// 动态库初始化方法
__attribute__((constructor)) static void entry() {
    Class labelCls = [UILabel class];
    
    SEL sel1 = @selector(setText:);
    Method m1 = class_getInstanceMethod(labelCls, sel1);
    if (m1) gOriginalSetText = method_setImplementation(m1, (IMP)CustomSetText);
    
    SEL sel2 = @selector(setAttributedText:);
    Method m2 = class_getInstanceMethod(labelCls, sel2);
    if (m2) gOriginalSetAttributedText = method_setImplementation(m2, (IMP)CustomSetAttributedText);
    
    SEL sel3 = @selector(layoutSubviews);
    Method m3 = class_getInstanceMethod(labelCls, sel3);
    if (m3) gOriginalUILabelLayout = method_setImplementation(m3, (IMP)CustomUILabelLayout);
    
    Class btnCls = [UIButton class];
    
    SEL sel4 = @selector(setTitle:forState:);
    Method m4 = class_getInstanceMethod(btnCls, sel4);
    if (m4) gOriginalSetTitle = method_setImplementation(m4, (IMP)CustomSetTitle);
    
    SEL sel5 = @selector(layoutSubviews);
    Method m5 = class_getInstanceMethod(btnCls, sel5);
    if (m5) gOriginalUIButtonLayout = method_setImplementation(m5, (IMP)CustomUIButtonLayout);
}
