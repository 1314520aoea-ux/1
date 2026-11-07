// DAMA Pro Unlock Dylib v3
// Target: tech.baye.placeholder (DAMA)
// Deferred hooking: waits for RevenueCat classes to be loaded before swizzling.
//
// Compile: clang -dynamiclib -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) -framework Foundation -framework UIKit -framework objc -mios-version-min=15.0 -o DAMAPro.dylib DAMAPro.m

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

#pragma mark - Helpers

static BOOL g_hooksInstalled = NO;

static void hookMethod(Class cls, SEL sel, IMP newImp) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, newImp);
        NSLog(@"[DAMAPro] Hooked -[%s %s]", class_getName(cls), sel_getName(sel));
    } else {
        NSLog(@"[DAMAPro] Method NOT found: -[%s %s]", class_getName(cls), sel_getName(sel));
    }
}

static void hookClassMethod(Class cls, SEL sel, IMP newImp) {
    if (!cls) return;
    Method m = class_getClassMethod(cls, sel);
    if (m) {
        method_setImplementation(m, newImp);
        NSLog(@"[DAMAPro] Hooked +[%s %s]", class_getName(cls), sel_getName(sel));
    } else {
        NSLog(@"[DAMAPro] Class method NOT found: +[%s %s]", class_getName(cls), sel_getName(sel));
    }
}

static void showLoadAlert(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        UIWindow *win = scene.windows.firstObject;
        if (!win) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DAMAPro Loaded"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *top = win.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        [top presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Fake entitlement singletons

static id fakeEntitlementInfo(void) {
    static id fake = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class c = NSClassFromString(@"RCEntitlementInfo");
        if (c) fake = [[c alloc] init];
    });
    return fake;
}

static id fakeEntitlementInfos(void) {
    static id fake = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class c = NSClassFromString(@"RCEntitlementInfos");
        if (c) fake = [[c alloc] init];
    });
    return fake;
}

static id fakeCustomerInfo(void) {
    static id fake = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class c = NSClassFromString(@"RCCustomerInfo");
        if (c) fake = [[c alloc] init];
    });
    return fake;
}

#pragma mark - RCEntitlementInfo instance hooks

static BOOL hooked_EI_isActive(id self, SEL _cmd) { return YES; }
static BOOL hooked_EI_isActiveInAnyEnvironment(id self, SEL _cmd) { return YES; }
static BOOL hooked_EI_isActiveInCurrentEnvironment(id self, SEL _cmd) { return YES; }
static NSString* hooked_EI_identifier(id self, SEL _cmd) { return @"pro"; }
static NSString* hooked_EI_productIdentifier(id self, SEL _cmd) { return @"dama.premium.ios"; }
static NSDate* hooked_EI_expirationDate(id self, SEL _cmd) { return [NSDate dateWithTimeIntervalSinceNow:365*24*3600*10]; }
static NSDate* hooked_EI_originalPurchaseDate(id self, SEL _cmd) { return [NSDate dateWithTimeIntervalSinceNow:-365*24*3600]; }
static NSDate* hooked_EI_latestPurchaseDate(id self, SEL _cmd) { return [NSDate dateWithTimeIntervalSinceNow:-24*3600]; }
static NSDate* hooked_EI_unsubscribeDetectedAt(id self, SEL _cmd) { return nil; }
static NSDate* hooked_EI_billingIssueDetectedAt(id self, SEL _cmd) { return nil; }
static BOOL hooked_EI_willRenew(id self, SEL _cmd) { return YES; }
static NSInteger hooked_EI_periodType(id self, SEL _cmd) { return 0; }
static NSString* hooked_EI_store(id self, SEL _cmd) { return @"app_store"; }
static BOOL hooked_EI_isSandbox(id self, SEL _cmd) { return NO; }

#pragma mark - RCEntitlementInfos instance hooks

static NSDictionary* hooked_EIs_activeEntitlements(id self, SEL _cmd) {
    return @{@"pro": fakeEntitlementInfo()};
}

static NSDictionary* hooked_EIs_all(id self, SEL _cmd) {
    return @{@"pro": fakeEntitlementInfo()};
}

static id hooked_EIs_objectForKeyedSubscript(id self, SEL _cmd, NSString* key) {
    return fakeEntitlementInfo();
}

static NSSet* hooked_EIs_active(id self, SEL _cmd) {
    return [NSSet setWithObject:@"pro"];
}

#pragma mark - RCCustomerInfo instance hooks

static id hooked_CI_entitlements(id self, SEL _cmd) {
    return fakeEntitlementInfos();
}

static NSDictionary* hooked_CI_allPurchasedProductIdentifiers(id self, SEL _cmd) {
    return @{@"dama.premium.ios": @1};
}

static NSSet* hooked_CI_nonSubscriptionTransactions(id self, SEL _cmd) {
    return [NSSet set];
}

static NSDate* hooked_CI_firstSeen(id self, SEL _cmd) {
    return [NSDate dateWithTimeIntervalSinceNow:-365*24*3600];
}

static NSDate* hooked_CI_originalPurchaseDate(id self, SEL _cmd) {
    return [NSDate dateWithTimeIntervalSinceNow:-365*24*3600];
}

static NSString* hooked_CI_originalApplicationVersion(id self, SEL _cmd) {
    return @"1.0";
}

static NSString* hooked_CI_managementURL(id self, SEL _cmd) {
    return @"https://apps.apple.com/account/subscriptions";
}

#pragma mark - RCPurchases hooks

static id hooked_Purchases_customerInfo(id self, SEL _cmd) {
    return fakeCustomerInfo();
}

static void hooked_Purchases_customerInfoWithCompletion(id self, SEL _cmd, id completion) {
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^block)(id, id) = completion;
            block(fakeCustomerInfo(), nil);
        });
    }
}

static void hooked_Purchases_getCustomerInfoWithCompletion(id self, SEL _cmd, id completion) {
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^block)(id, id) = completion;
            block(fakeCustomerInfo(), nil);
        });
    }
}

static void hooked_Purchases_restorePurchasesWithCompletion(id self, SEL _cmd, id completion) {
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^block)(id, id) = completion;
            block(fakeCustomerInfo(), nil);
        });
    }
}

static void hooked_Purchases_purchaseProductWithCompletion(id self, SEL _cmd, id product, id completion) {
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^block)(id, id, id, BOOL) = completion;
            block(nil, fakeCustomerInfo(), nil, NO);
        });
    }
}

#pragma mark - Swift Placeholder.Premium hook

static BOOL hooked_isPremium(id self, SEL _cmd) {
    return YES;
}

#pragma mark - NSUserDefaults common Pro flags

static BOOL (*orig_UD_boolForKey)(id, SEL, NSString *) = nil;

static BOOL hooked_UD_boolForKey(id self, SEL _cmd, NSString *key) {
    if ([key isEqualToString:@"isPro"] ||
        [key isEqualToString:@"isPremium"] ||
        [key isEqualToString:@"pro"] ||
        [key isEqualToString:@"premium"] ||
        [key isEqualToString:@"hasPurchasedPro"] ||
        [key isEqualToString:@"DAMAPro"] ||
        [key isEqualToString:@"isDAMAPro"]) {
        NSLog(@"[DAMAPro] NSUserDefaults boolForKey:%@ -> YES", key);
        return YES;
    }
    return orig_UD_boolForKey(self, _cmd, key);
}

#pragma mark - Hook installer

static BOOL installHooks(void) {
    if (g_hooksInstalled) return YES;

    Class EI = NSClassFromString(@"RCEntitlementInfo");
    Class EIs = NSClassFromString(@"RCEntitlementInfos");
    Class CI = NSClassFromString(@"RCCustomerInfo");
    Class Purchases = NSClassFromString(@"RCPurchases");
    if (!Purchases) Purchases = NSClassFromString(@"Purchases");
    Class Premium = NSClassFromString(@"_TtC11Placeholder7Premium");
    if (!Premium) Premium = NSClassFromString(@"Placeholder.Premium");

    if (!EI && !EIs && !CI && !Purchases && !Premium) {
        return NO; // Nothing to hook yet
    }

    g_hooksInstalled = YES;
    NSLog(@"[DAMAPro] ===== Installing hooks =====");

    if (EI) {
        hookMethod(EI, @selector(isActive), (IMP)hooked_EI_isActive);
        hookMethod(EI, @selector(isActiveInAnyEnvironment), (IMP)hooked_EI_isActiveInAnyEnvironment);
        hookMethod(EI, @selector(isActiveInCurrentEnvironment), (IMP)hooked_EI_isActiveInCurrentEnvironment);
        hookMethod(EI, @selector(identifier), (IMP)hooked_EI_identifier);
        hookMethod(EI, @selector(productIdentifier), (IMP)hooked_EI_productIdentifier);
        hookMethod(EI, @selector(expirationDate), (IMP)hooked_EI_expirationDate);
        hookMethod(EI, @selector(originalPurchaseDate), (IMP)hooked_EI_originalPurchaseDate);
        hookMethod(EI, @selector(latestPurchaseDate), (IMP)hooked_EI_latestPurchaseDate);
        hookMethod(EI, @selector(unsubscribeDetectedAt), (IMP)hooked_EI_unsubscribeDetectedAt);
        hookMethod(EI, @selector(billingIssueDetectedAt), (IMP)hooked_EI_billingIssueDetectedAt);
        hookMethod(EI, @selector(willRenew), (IMP)hooked_EI_willRenew);
        hookMethod(EI, @selector(periodType), (IMP)hooked_EI_periodType);
        hookMethod(EI, @selector(store), (IMP)hooked_EI_store);
        hookMethod(EI, @selector(isSandbox), (IMP)hooked_EI_isSandbox);
    }

    if (EIs) {
        hookMethod(EIs, @selector(activeEntitlements), (IMP)hooked_EIs_activeEntitlements);
        hookMethod(EIs, @selector(all), (IMP)hooked_EIs_all);
        hookMethod(EIs, @selector(active), (IMP)hooked_EIs_active);
        hookMethod(EIs, @selector(objectForKeyedSubscript:), (IMP)hooked_EIs_objectForKeyedSubscript);
    }

    if (CI) {
        hookMethod(CI, @selector(entitlements), (IMP)hooked_CI_entitlements);
        hookMethod(CI, @selector(allPurchasedProductIdentifiers), (IMP)hooked_CI_allPurchasedProductIdentifiers);
        hookMethod(CI, @selector(nonSubscriptionTransactions), (IMP)hooked_CI_nonSubscriptionTransactions);
        hookMethod(CI, @selector(firstSeen), (IMP)hooked_CI_firstSeen);
        hookMethod(CI, @selector(originalPurchaseDate), (IMP)hooked_CI_originalPurchaseDate);
        hookMethod(CI, @selector(originalApplicationVersion), (IMP)hooked_CI_originalApplicationVersion);
        hookMethod(CI, @selector(managementURL), (IMP)hooked_CI_managementURL);
    }

    if (Purchases) {
        hookMethod(Purchases, @selector(customerInfo), (IMP)hooked_Purchases_customerInfo);
        hookMethod(Purchases, @selector(customerInfoWithCompletion:), (IMP)hooked_Purchases_customerInfoWithCompletion);
        hookMethod(Purchases, @selector(getCustomerInfoWithCompletion:), (IMP)hooked_Purchases_getCustomerInfoWithCompletion);
        hookMethod(Purchases, @selector(restorePurchasesWithCompletion:), (IMP)hooked_Purchases_restorePurchasesWithCompletion);
        hookMethod(Purchases, @selector(purchaseProduct:withCompletion:), (IMP)hooked_Purchases_purchaseProductWithCompletion);
        NSLog(@"[DAMAPro] Found Purchases class: %s", class_getName(Purchases));
    }

    if (Premium) {
        hookMethod(Premium, @selector(isPremium), (IMP)hooked_isPremium);
    }

    // NSUserDefaults hook can be installed early since Foundation is always loaded
    Class UD = objc_getClass("NSUserDefaults");
    Method m = class_getInstanceMethod(UD, @selector(boolForKey:));
    if (m && !orig_UD_boolForKey) {
        orig_UD_boolForKey = (BOOL (*)(id, SEL, NSString *))method_getImplementation(m);
        method_setImplementation(m, (IMP)hooked_UD_boolForKey);
        NSLog(@"[DAMAPro] Hooked NSUserDefaults -boolForKey:");
    }

    NSLog(@"[DAMAPro] ===== hooks installed =====");
    return YES;
}

static void imageAddedCallback(const struct mach_header *mh, intptr_t vmaddr_slide) {
    // Try installing hooks whenever a new image is loaded
    installHooks();
}

static void scheduleRetries(void) {
    // Keep trying for 10 seconds in case dyld callbacks miss anything
    static int attempts = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        attempts++;
        if (!g_hooksInstalled && attempts < 10) {
            installHooks();
            scheduleRetries();
        } else if (g_hooksInstalled) {
            NSMutableString *info = [NSMutableString stringWithString:@"Hooks installed:\n"];
            if (NSClassFromString(@"RCEntitlementInfo")) [info appendString:@"- RCEntitlementInfo\n"];
            if (NSClassFromString(@"RCEntitlementInfos")) [info appendString:@"- RCEntitlementInfos\n"];
            if (NSClassFromString(@"RCCustomerInfo")) [info appendString:@"- RCCustomerInfo\n"];
            if (NSClassFromString(@"RCPurchases") || NSClassFromString(@"Purchases")) [info appendString:@"- RCPurchases\n"];
            if (NSClassFromString(@"_TtC11Placeholder7Premium")) [info appendString:@"- Placeholder.Premium\n"];
            showLoadAlert(info);
        }
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void init() {
    NSLog(@"[DAMAPro] ===== DAMA Pro Unlock dylib loaded =====");

    @autoreleasepool {
        // Install what we can immediately (NSUserDefaults etc.)
        installHooks();

        // Re-try when dynamic images are loaded
        _dyld_register_func_for_add_image(imageAddedCallback);

        // Also retry periodically after UI is up
        scheduleRetries();
    }
}
