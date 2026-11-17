// Libra CloudKit Crash Fix
// Target: com.sevenzx.Libra (Libra Media Player 1.0.0 / build 71)
//
// Root cause: the IPA is re-signed with a certificate whose provisioning profile
// has no iCloud/CloudKit capability. The app embeds
// com.apple.developer.icloud-container-identifiers = iCloud.com.sevenzx.Libra and
// initializes CKContainer(identifier:) at launch. CloudKit validates the
// entitlement, throws an NSException inside a dispatch_once block, and the
// exception escapes a Swift async task -> _objc_terminate -> SIGABRT.
//
// Fix: swizzle +[CKContainer containerWithIdentifier:] and hand the app an inert
// container/database pair. Every CloudKit operation fails fast with a normal
// NSError instead of an uncatchable ObjC exception, so the app can fall back to
// its "iCloud unavailable" UI state.
//
// Deliberately Foundation-only: no CloudKit headers, so the dylib compiles
// against any iOS SDK version. All CloudKit types are handled as `id`.
//
// Build: clang -dynamiclib -arch arm64 \
//   -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
//   -framework Foundation -framework CloudKit -lobjc \
//   -mios-version-min=15.0 -o LibraCloudKitFix.dylib LibraCloudKitFix.m

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

// CloudKit enum values (stable ABI), hardcoded to avoid SDK dependencies.
enum {
    LibraCKScopePublic  = 1,
    LibraCKScopePrivate = 2,
    LibraCKScopeShared  = 3,
};

enum {
    LibraCKAccountStatusNoAccount = 3,
    LibraCKPermissionDenied       = 2,
};

static NSError *LibraCKUnavailable(void) {
    return [NSError errorWithDomain:@"CKErrorDomain"
                               code:1 // CKErrorInternalError
                           userInfo:@{NSLocalizedDescriptionKey: @"iCloud unavailable (patched)"}];
}

static void LibraCallBlock2(id block, id a, NSError *e) {
    if (!block) return;
    void (^b)(id, NSError *) = block;
    b(a, e);
}

static void LibraCallBlock3(id block, id a, id b2, NSError *e) {
    if (!block) return;
    void (^b)(id, id, NSError *) = block;
    b(a, b2, e);
}

#pragma mark - Fake database

@interface LibraFakeDatabase : NSObject
@property (nonatomic, assign) NSInteger scope;
@property (nonatomic, unsafe_unretained) id container;
@end

@implementation LibraFakeDatabase

- (NSInteger)databaseScope { return _scope; }

- (void)fetchAllRecordZonesWithCompletionHandler:(void (^)(id zones, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchRecordZoneWithID:(id)zoneID completionHandler:(void (^)(id zone, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)saveRecordZone:(id)zone completionHandler:(void (^)(id zone, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)deleteRecordZoneWithID:(id)zoneID completionHandler:(void (^)(id zoneID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchRecordWithID:(id)recordID completionHandler:(void (^)(id record, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchRecordsWithIDs:(id)recordIDs completionHandler:(void (^)(id records, NSError *error))h {
    LibraCallBlock2(h, @{}, LibraCKUnavailable());
}

- (void)fetchRecordsWithIDs:(id)recordIDs desiredKeys:(id)desiredKeys completionHandler:(void (^)(id records, NSError *error))h {
    LibraCallBlock2(h, @{}, LibraCKUnavailable());
}

- (void)saveRecord:(id)record completionHandler:(void (^)(id record, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)deleteRecordWithID:(id)recordID completionHandler:(void (^)(id recordID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)performQuery:(id)query inZoneWithID:(id)zoneID completionHandler:(void (^)(id results, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchAllSubscriptionsWithCompletionHandler:(void (^)(id subscriptions, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchSubscriptionWithID:(id)subscriptionID completionHandler:(void (^)(id subscription, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)saveSubscription:(id)subscription completionHandler:(void (^)(id subscription, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)deleteSubscriptionWithID:(id)subscriptionID completionHandler:(void (^)(id subscriptionID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

// CKSyncEngine / Swift overlay route batches through CKOperation.
- (void)addOperation:(id)operation {
    NSString *cls = NSStringFromClass([operation class]);
    NSError *err = LibraCKUnavailable();

    if ([cls isEqualToString:@"CKModifyRecordsOperation"]) {
        LibraCallBlock3([(id)operation valueForKey:@"modifyRecordsCompletionBlock"], @[], @[], err);
    } else if ([cls isEqualToString:@"CKFetchRecordsOperation"]) {
        LibraCallBlock2([(id)operation valueForKey:@"fetchRecordsCompletionBlock"], @{}, err);
    } else if ([cls isEqualToString:@"CKFetchRecordZonesOperation"]) {
        if ([operation respondsToSelector:NSSelectorFromString(@"fetchAllRecordZonesCompletionBlock")]) {
            LibraCallBlock2([(id)operation valueForKey:@"fetchAllRecordZonesCompletionBlock"], @[], err);
        } else if ([operation respondsToSelector:NSSelectorFromString(@"fetchRecordZonesCompletionBlock")]) {
            LibraCallBlock2([(id)operation valueForKey:@"fetchRecordZonesCompletionBlock"], @{}, err);
        }
    } else if ([cls isEqualToString:@"CKFetchRecordZoneChangesOperation"]) {
        void (^b)(NSError *) = [(id)operation valueForKey:@"fetchRecordZoneChangesCompletionBlock"];
        if (b) b(err);
    } else if ([cls isEqualToString:@"CKQueryOperation"]) {
        LibraCallBlock2([(id)operation valueForKey:@"queryCompletionBlock"], nil, err);
    } else if ([cls isEqualToString:@"CKModifySubscriptionsOperation"]) {
        LibraCallBlock3([(id)operation valueForKey:@"modifySubscriptionsCompletionBlock"], nil, nil, err);
    } else if ([cls isEqualToString:@"CKFetchSubscriptionsOperation"]) {
        LibraCallBlock2([(id)operation valueForKey:@"fetchSubscriptionCompletionBlock"], nil, err);
    } else if ([cls isEqualToString:@"CKFetchDatabaseChangesOperation"]) {
        void (^b)(id, BOOL, NSError *) = [(id)operation valueForKey:@"fetchDatabaseChangesCompletionBlock"];
        if (b) b(nil, NO, err);
    } else {
        NSLog(@"[LibraCKFix] ignored operation: %@", cls);
    }
}

// Never let an unexpected private selector abort the app.
- (void)doesNotRecognizeSelector:(SEL)aSelector {
    NSLog(@"[LibraCKFix] fake DB ignored selector: %@", NSStringFromSelector(aSelector));
}

@end

#pragma mark - Fake container

@interface LibraFakeContainer : NSObject
@property (nonatomic, copy) NSString *containerIdentifier;
@property (nonatomic, retain) LibraFakeDatabase *privateDB;
@property (nonatomic, retain) LibraFakeDatabase *publicDB;
@property (nonatomic, retain) LibraFakeDatabase *sharedDB;
@end

@implementation LibraFakeContainer

+ (instancetype)sharedWithIdentifier:(NSString *)identifier {
    static LibraFakeContainer *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[LibraFakeContainer alloc] init];
        shared.containerIdentifier = identifier ?: @"iCloud.com.sevenzx.Libra";
        shared.privateDB = [[LibraFakeDatabase alloc] init];
        shared.privateDB.scope = LibraCKScopePrivate;
        shared.privateDB.container = shared;
        shared.publicDB = [[LibraFakeDatabase alloc] init];
        shared.publicDB.scope = LibraCKScopePublic;
        shared.publicDB.container = shared;
        shared.sharedDB = [[LibraFakeDatabase alloc] init];
        shared.sharedDB.scope = LibraCKScopeShared;
        shared.sharedDB.container = shared;
    });
    return shared;
}

- (id)privateCloudDatabase { return _privateDB; }
- (id)publicCloudDatabase { return _publicDB; }
- (id)sharedCloudDatabase { return _sharedDB; }

- (id)databaseWithDatabaseScope:(NSInteger)scope {
    switch (scope) {
        case LibraCKScopePublic: return _publicDB;
        case LibraCKScopeShared: return _sharedDB;
        case LibraCKScopePrivate:
        default: return _privateDB;
    }
}

- (void)accountStatusWithCompletionHandler:(void (^)(NSInteger status, NSError *error))h {
    if (!h) return;
    void (^b)(NSInteger, NSError *) = h;
    b(LibraCKAccountStatusNoAccount, LibraCKUnavailable());
}

- (void)fetchUserRecordIDWithCompletionHandler:(void (^)(id recordID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)requestApplicationPermission:(NSInteger)permission completionHandler:(void (^)(NSInteger status, NSError *error))h {
    if (!h) return;
    void (^b)(NSInteger, NSError *) = h;
    b(LibraCKPermissionDenied, LibraCKUnavailable());
}

- (void)statusForApplicationPermission:(NSInteger)permission completionHandler:(void (^)(NSInteger status, NSError *error))h {
    if (!h) return;
    void (^b)(NSInteger, NSError *) = h;
    b(LibraCKPermissionDenied, LibraCKUnavailable());
}

- (void)fetchShareMetadataWithURL:(id)url completionHandler:(void (^)(id metadata, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)acceptShareMetadata:(id)metadata completionHandler:(void (^)(id share, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverAllIdentitiesWithCompletionHandler:(void (^)(id identities, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverUserIdentityWithEmailAddress:(id)email completionHandler:(void (^)(id identity, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverUserIdentityWithPhoneNumber:(id)phone completionHandler:(void (^)(id identity, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverUserIdentityWithUserRecordID:(id)userRecordID completionHandler:(void (^)(id identity, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)addOperation:(id)operation {
    [_privateDB addOperation:operation];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    NSLog(@"[LibraCKFix] fake container ignored selector: %@", NSStringFromSelector(aSelector));
}

@end

#pragma mark - Swizzles

static BOOL g_installed = NO;

static id LibraHookedContainerWithIdentifier(id self, SEL _cmd, NSString *identifier) {
    NSLog(@"[LibraCKFix] CKContainer(identifier: %@) -> inert container", identifier);
    return [LibraFakeContainer sharedWithIdentifier:identifier];
}

static id LibraHookedContainerWithIdentifierEnv(id self, SEL _cmd, NSString *identifier, id env) {
    NSLog(@"[LibraCKFix] CKContainer(identifier: %@, env: %@) -> inert container", identifier, env);
    return [LibraFakeContainer sharedWithIdentifier:identifier];
}

static id LibraHookedDefaultContainer(id self, SEL _cmd) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[LibraCKFix] CKContainer.default -> inert container");
    return [LibraFakeContainer sharedWithIdentifier:
            [NSString stringWithFormat:@"iCloud.%@", bundleID ?: @"com.sevenzx.Libra"]];
}

static void LibraInstallHooks(void) {
    if (g_installed) return;
    Class CK = NSClassFromString(@"CKContainer");
    if (!CK) return;

    g_installed = YES;

    Method m = class_getClassMethod(CK, NSSelectorFromString(@"containerWithIdentifier:"));
    if (m) {
        method_setImplementation(m, (IMP)LibraHookedContainerWithIdentifier);
        NSLog(@"[LibraCKFix] swizzled +[CKContainer containerWithIdentifier:]");
    } else {
        NSLog(@"[LibraCKFix] +[CKContainer containerWithIdentifier:] not found");
    }

    Method e = class_getClassMethod(CK, NSSelectorFromString(@"containerWithIdentifier:environment:"));
    if (e) {
        method_setImplementation(e, (IMP)LibraHookedContainerWithIdentifierEnv);
        NSLog(@"[LibraCKFix] swizzled +[CKContainer containerWithIdentifier:environment:]");
    }

    Method d = class_getClassMethod(CK, NSSelectorFromString(@"defaultContainer"));
    if (d) {
        method_setImplementation(d, (IMP)LibraHookedDefaultContainer);
        NSLog(@"[LibraCKFix] swizzled +[CKContainer defaultContainer]");
    }
}

static void LibraImageAdded(const struct mach_header *mh, intptr_t vmaddr_slide) {
    LibraInstallHooks();
}

static void LibraRetry(int attempt) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (g_installed) return;
        if (attempt >= 25) return;
        LibraInstallHooks();
        if (!g_installed) LibraRetry(attempt + 1);
    });
}

__attribute__((constructor))
static void LibraCKFixInit(void) {
    NSLog(@"[LibraCKFix] loaded");
    @autoreleasepool {
        LibraInstallHooks();
        _dyld_register_func_for_add_image(LibraImageAdded);
        LibraRetry(0);
    }
}
