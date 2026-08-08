#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP gOriginalSetText = NULL;
static IMP gOriginalSetAttributedText = NULL;
static IMP gOriginalSetTitle = NULL;
static IMP gOriginalTVSetText = NULL;
static IMP gOriginalCATextLayerSetString = NULL;

// 1. 匹配 watermark 字符
static BOOL ContainsWatermark(NSString *text) {
    if (!text || ![text isKindOfClass:[NSString class]]) return NO;
    
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

// 2. 判断是否位于媒体详情页的信息卡片内（Profile 所在的区域）
static BOOL IsInMediaDetailProfile(id viewOrLayer) {
    UIView *curr = nil;
    if ([viewOrLayer isKindOfClass:[UIView class]]) {
        curr = (UIView *)viewOrLayer;
    } else {
        Class caLayerCls = NSClassFromString(@"CALayer");
        if (caLayerCls && [viewOrLayer isKindOfClass:caLayerCls]) {
            id delegate = [viewOrLayer performSelector:@selector(delegate)];
            if ([delegate isKindOfClass:[UIView class]]) {
                curr = (UIView *)delegate;
            }
        }
    }
    
    while (curr) {
        NSString *cls = NSStringFromClass([curr class]);
        // 如果父容器包含媒体信息、卡片、规格列表等类名
        if ([cls containsString:@"MediaInfo"] || 
            [cls containsString:@"Detail"] || 
            [cls containsString:@"Codec"] || 
            [cls containsString:@"StreamInfo"]) {
            return YES;
        }
        curr = curr.superview;
    }
    return NO;
}

// 3. 精准替换处理
static NSString *GetReplacementText(id viewOrLayer, NSString *originalText) {
    if (!ContainsWatermark(originalText)) {
        return originalText;
    }
    
    // 如果是详情页里的 Profile 字段，替换为 "Profile"
    if (IsInMediaDetailProfile(viewOrLayer)) {
        return @"Profile";
    }
    
    // 其他所有地方（包括底部 Dock 栏、左上角下拉菜单选项），统一恢复为 "首页"
    return @"\u9996\u9875";
}

// --- Hook 方法 ---
static void CustomSetText(UILabel *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalSetText)(self, _cmd, newText);
}

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

static void CustomSetTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    NSString *newTitle = GetReplacementText(self, title);
    ((void(*)(id, SEL, NSString *, UIControlState))gOriginalSetTitle)(self, _cmd, newTitle, state);
}

static void CustomTVSetText(UITextView *self, SEL _cmd, NSString *text) {
    NSString *newText = GetReplacementText(self, text);
    ((void(*)(id, SEL, NSString *))gOriginalTVSetText)(self, _cmd, newText);
}

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
