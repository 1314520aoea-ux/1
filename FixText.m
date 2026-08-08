#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;
static IMP gOriginalSetTitle = NULL;
static IMP gOriginalTVSetText = NULL;
static IMP gOriginalCATextLayerSetString = NULL;

// 1. 模糊判断是否包含 watermark 字符
static BOOL ContainsWatermark(NSString *text) {
    if (!text || ![text isKindOfClass:[NSString class]]) return NO;
    
    // 匹配 HWVIP 或任意框框特殊字符 🄷 🅆 🅅 🄸 🄿
    if ([text containsString:@"HWVIP"] ||
        [text containsString:@"\U0001F137"] || // 🄷
        [text containsString:@"\U0001F146"] || // 🅆
        [text containsString:@"\U0001F145"] || // 🅅
        [text containsString:@"\U0001F138"] || // 🄸
        [text containsString:@"\U0001F13F"]) { // 🄿
        return YES;
    }
    return NO;
}

// 2. 判断是否位于底部 Dock / Tab 栏
static BOOL IsInDockBar(id viewOrLayer) {
    UIView *curr = nil;
    if ([viewOrLayer isKindOfClass:[UIView class]]) {
        curr = (UIView *)viewOrLayer;
    } else if ([viewOrLayer isKindOfClass:[CALayer class]]) {
        id delegate = [(CALayer *)viewOrLayer delegate];
        if ([delegate isKindOfClass:[UIView class]]) {
            curr = (UIView *)delegate;
        }
    }
    
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

// 3. 统一替换处理
static NSString *GetReplacementText(id viewOrLayer, NSString *originalText) {
    if (!ContainsWatermark(originalText)) {
        return originalText;
    }
    
    if (IsInDockBar(viewOrLayer)) {
        return @"\u9996\u9875"; // 底部 Dock 栏显示 "首页"
    } else {
        return @"Profile";    // 详情页等其他地方统一恢复为 "Profile"
    }
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
        if (ContainsWatermark(str)) {
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

// --- Hook 5: CATextLayer setString: (专门拦截媒体详情列表) ---
static void CustomCATextLayerSetString(id self, SEL _cmd, id string) {
    if ([string isKindOfClass:[NSString class]]) {
        NSString *newStr = GetReplacementText(self, (NSString *)string);
        ((void(*)(id, SEL, id))gOriginalCATextLayerSetString)(self, _cmd, newStr);
    } else if ([string isKindOfClass:[NSAttributedString class]]) {
        NSAttributedString *attrStr = (NSAttributedString *)string;
        if (ContainsWatermark(attrStr.string)) {
            NSString *replaced = GetReplacementText(self, attrStr.string);
            NSDictionary *attrs = attrStr.length > 0 ? [attrStr attributesAtIndex:0 effectiveRange:NULL] : nil;
            NSAttributedString *newAttr = [[NSAttributedString alloc] initWithString:replaced attributes:attrs];
            ((void(*)(id, SEL, id))gOriginalCATextLayerSetString)(self, _cmd, newAttr);
            return;
        }
        ((void(*)(id, SEL, id))gOriginalCATextLayerSetString)(self, _cmd, string);
    } else {
        ((void(*)(id, SEL, id))gOriginalCATextLayerSetString)(self, _cmd, string);
    }
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
    
    Class caTextLayerCls = NSClassFromString(@"CATextLayer");
    if (caTextLayerCls) {
        SEL sel5 = @selector(setString:);
        Method m5 = class_getInstanceMethod(caTextLayerCls, sel5);
        if (m5) gOriginalCATextLayerSetString = method_setImplementation(m5, (IMP)CustomCATextLayerSetString);
    }
}
