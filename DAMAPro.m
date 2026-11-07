// DAMA Pro Unlock Dylib
// Target: tech.baye.placeholder (DAMA) v26.10.3
// Hooks RevenueCat entitlement checks to unlock Pro
//
// Compile: clang -dynamiclib -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) -framework Foundation -framework objc -o DAMAPro.dylib DAMAPro.m
// Or use Theos/Logos

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Hook Helpers

static void hookMethod(Class cls, SEL sel, IMP newImp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, newImp);
        NSLog(@"[DAMAPro] Hooked %s.%s", class_getName(cls), sel_getName(sel));
    } else {
        NSLog(@"[DAMAPro] Method not found: %s.%s", class_getName(cls), sel_getName(sel));
    }
}

#pragma mark - RCEntitlementInfo Hooks

static BOOL hooked_isActive(id self, SEL _cmd) {
    return YES;
}

static BOOL hooked_isActiveInAnyEnvironment(id self, SEL _cmd) {
    return YES;
}

static BOOL hooked_isActiveInCurrentEnvironment(id self, SEL _cmd) {
    return YES;
}

static NSString* hooked_identifier(id self, SEL _cmd) {
    return @"pro";
}

static NSString* hooked_productIdentifier(id self, SEL _cmd) {
    return @"dama.premium.ios";
}

static NSDate* hooked_expirationDate(id self, SEL _cmd) {
    return [NSDate dateWithTimeIntervalSinceNow:365*24*3600*10]; // 10 years
}

static NSDate* hooked_originalPurchaseDate(id self, SEL _cmd) {
    return [NSDate dateWithTimeIntervalSinceNow:-365*24*3600]; // 1 year ago
}

static NSDate* hooked_latestPurchaseDate(id self, SEL _cmd) {
    return [NSDate dateWithTimeIntervalSinceNow:-24*3600]; // yesterday
}

static BOOL hooked_willRenew(id self, SEL _cmd) {
    return YES;
}

static NSInteger hooked_periodType(id self, SEL _cmd) {
    return 0; // normal
}

static NSString* hooked_store(id self, SEL _cmd) {
    return @"app_store";
}

static BOOL hooked_isSandbox(id self, SEL _cmd) {
    return NO;
}

#pragma mark - RCEntitlementInfos Hooks

static NSDictionary* hooked_activeEntitlements(id self, SEL _cmd) {
    // Return a dict with "pro" key pointing to self (the entitlement info)
    // We need to create a fake RCEntitlementInfo object
    Class entInfoClass = objc_getClass("RCEntitlementInfo");
    if (entInfoClass) {
        id fakeEnt = [[entInfoClass alloc] init];
        return @{@"pro": fakeEnt};
    }
    return @{};
}

static NSDictionary* hooked_all(id self, SEL _cmd) {
    Class entInfoClass = objc_getClass("RCEntitlementInfo");
    if (entInfoClass) {
        id fakeEnt = [[entInfoClass alloc] init];
        return @{@"pro": fakeEnt};
    }
    return @{};
}

static id hooked_objectForKeyedSubscript(id self, SEL _cmd, NSString* key) {
    Class entInfoClass = objc_getClass("RCEntitlementInfo");
    if (entInfoClass) {
        return [[entInfoClass alloc] init];
    }
    return nil;
}

#pragma mark - RCCustomerInfo Hooks

static id hooked_entitlements(id self, SEL _cmd) {
    Class entInfosClass = objc_getClass("RCEntitlementInfos");
    if (entInfosClass) {
        return [[entInfosClass alloc] init];
    }
    return nil;
}

static NSDate* hooked_originalApplicationVersion(id self, SEL _cmd) {
    return nil;
}

static NSString* hooked_managementURL(id self, SEL _cmd) {
    return @"https://apps.apple.com/account/subscriptions";
}

#pragma mark - Premium Class Hook (Swift)

static BOOL hooked_isPremium(id self, SEL _cmd) {
    return YES;
}

#pragma mark - RCOffering Hooks

static id hooked_lifetime(id self, SEL _cmd) {
    Class packageClass = objc_getClass("RCPackage");
    if (packageClass) {
        return [[packageClass alloc] init];
    }
    return nil;
}

#pragma mark - Constructor

__attribute__((constructor))
static void init() {
    NSLog(@"[DAMAPro] DAMA Pro Unlock loaded");
    
    @autoreleasepool {
        // Hook RCEntitlementInfo
        Class entInfo = objc_getClass("RCEntitlementInfo");
        if (entInfo) {
            hookMethod(entInfo, @selector(isActive), (IMP)hooked_isActive);
            hookMethod(entInfo, @selector(isActiveInAnyEnvironment), (IMP)hooked_isActiveInAnyEnvironment);
            hookMethod(entInfo, @selector(isActiveInCurrentEnvironment), (IMP)hooked_isActiveInCurrentEnvironment);
            hookMethod(entInfo, @selector(identifier), (IMP)hooked_identifier);
            hookMethod(entInfo, @selector(productIdentifier), (IMP)hooked_productIdentifier);
            hookMethod(entInfo, @selector(expirationDate), (IMP)hooked_expirationDate);
            hookMethod(entInfo, @selector(originalPurchaseDate), (IMP)hooked_originalPurchaseDate);
            hookMethod(entInfo, @selector(latestPurchaseDate), (IMP)hooked_latestPurchaseDate);
            hookMethod(entInfo, @selector(willRenew), (IMP)hooked_willRenew);
            hookMethod(entInfo, @selector(periodType), (IMP)hooked_periodType);
            hookMethod(entInfo, @selector(store), (IMP)hooked_store);
            hookMethod(entInfo, @selector(isSandbox), (IMP)hooked_isSandbox);
        }
        
        // Hook RCEntitlementInfos
        Class entInfos = objc_getClass("RCEntitlementInfos");
        if (entInfos) {
            hookMethod(entInfos, @selector(activeEntitlements), (IMP)hooked_activeEntitlements);
            hookMethod(entInfos, @selector(all), (IMP)hooked_all);
            hookMethod(entInfos, @selector(objectForKeyedSubscript:), (IMP)hooked_objectForKeyedSubscript);
        }
        
        // Hook RCCustomerInfo
        Class customerInfo = objc_getClass("RCCustomerInfo");
        if (customerInfo) {
            hookMethod(customerInfo, @selector(entitlements), (IMP)hooked_entitlements);
            hookMethod(customerInfo, @selector(managementURL), (IMP)hooked_managementURL);
        }
        
        // Hook Placeholder.Premium (Swift class exposed to ObjC)
        Class premium = objc_getClass("_TtC11Placeholder7Premium");
        if (premium) {
            hookMethod(premium, @selector(isPremium), (IMP)hooked_isPremium);
        }
        
        // Hook RCOffering
        Class offering = objc_getClass("RCOffering");
        if (offering) {
            hookMethod(offering, @selector(lifetime), (IMP)hooked_lifetime);
        }
        
        NSLog(@"[DAMAPro] All hooks installed successfully");
    }
}
