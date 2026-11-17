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
// Build: clang -dynamiclib -arch arm64 \
//   -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
//   -framework Foundation -framework CloudKit -lobjc \
//   -mios-version-min=15.0 -o LibraCloudKitFix.dylib LibraCloudKitFix.m

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

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
@property (nonatomic, assign) CKDatabaseScope scope;
@property (nonatomic, weak) id container;
@end

@implementation LibraFakeDatabase

- (CKDatabaseScope)databaseScope { return _scope; }

- (void)fetchAllRecordZonesWithCompletionHandler:(void (^)(NSArray<CKRecordZone *> *zones, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchRecordZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(CKRecordZone *zone, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)saveRecordZone:(CKRecordZone *)zone completionHandler:(void (^)(CKRecordZone *zone, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)deleteRecordZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(CKRecordZoneID *zoneID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchRecordWithID:(CKRecordID *)recordID completionHandler:(void (^)(CKRecord *record, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchRecordsWithIDs:(NSArray<CKRecordID *> *)recordIDs completionHandler:(void (^)(NSDictionary<CKRecordID *, CKRecord *> *records, NSError *error))h {
    LibraCallBlock2(h, @{}, LibraCKUnavailable());
}

- (void)fetchRecordsWithIDs:(NSArray<CKRecordID *> *)recordIDs desiredKeys:(NSArray<NSString *> *)desiredKeys completionHandler:(void (^)(NSDictionary<CKRecordID *, CKRecord *> *records, NSError *error))h {
    LibraCallBlock2(h, @{}, LibraCKUnavailable());
}

- (void)saveRecord:(CKRecord *)record completionHandler:(void (^)(CKRecord *record, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)deleteRecordWithID:(CKRecordID *)recordID completionHandler:(void (^)(CKRecordID *recordID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)performQuery:(CKQuery *)query inZoneWithID:(CKRecordZoneID *)zoneID completionHandler:(void (^)(NSArray<CKRecord *> *results, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchAllSubscriptionsWithCompletionHandler:(void (^)(NSArray<CKSubscription *> *subscriptions, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)fetchSubscriptionWithID:(NSString *)subscriptionID completionHandler:(void (^)(CKSubscription *subscription, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)saveSubscription:(CKSubscription *)subscription completionHandler:(void (^)(CKSubscription *subscription, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)deleteSubscriptionWithID:(NSString *)subscriptionID completionHandler:(void (^)(NSString *subscriptionID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

// CKSyncEngine / Swift overlay route batches through CKOperation.
- (void)addOperation:(NSOperation *)operation {
    NSString *cls = NSStringFromClass([operation class]);
    NSError *err = LibraCKUnavailable();

    if ([cls isEqualToString:@"CKModifyRecordsOperation"]) {
        LibraCallBlock3([(id)operation valueForKey:@"modifyRecordsCompletionBlock"], @[], @[], err);
    } else if ([cls isEqualToString:@"CKFetchRecordsOperation"]) {
        LibraCallBlock2([(id)operation valueForKey:@"fetchRecordsCompletionBlock"], @{}, err);
    } else if ([cls isEqualToString:@"CKFetchRecordZonesOperation"]) {
        if ([(id)operation respondsToSelector:NSSelectorFromString(@"fetchAllRecordZonesCompletionBlock")]) {
            LibraCallBlock2([(id)operation valueForKey:@"fetchAllRecordZonesCompletionBlock"], @[], err);
        } else if ([(id)operation respondsToSelector:NSSelectorFromString(@"fetchRecordZonesCompletionBlock")]) {
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
@property (nonatomic, strong) LibraFakeDatabase *privateDB;
@property (nonatomic, strong) LibraFakeDatabase *publicDB;
@property (nonatomic, strong) LibraFakeDatabase *sharedDB;
@end

@implementation LibraFakeContainer

+ (instancetype)sharedWithIdentifier:(NSString *)identifier {
    static LibraFakeContainer *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[LibraFakeContainer alloc] init];
        shared.containerIdentifier = identifier ?: @"iCloud.com.sevenzx.Libra";
        shared.privateDB = [[LibraFakeDatabase alloc] init];
        shared.privateDB.scope = CKDatabaseScopePrivate;
        shared.privateDB.container = shared;
        shared.publicDB = [[LibraFakeDatabase alloc] init];
        shared.publicDB.scope = CKDatabaseScopePublic;
        shared.publicDB.container = shared;
        shared.sharedDB = [[LibraFakeDatabase alloc] init];
        shared.sharedDB.scope = CKDatabaseScopeShared;
        shared.sharedDB.container = shared;
    });
    return shared;
}

- (CKDatabase *)privateCloudDatabase { return (CKDatabase *)_privateDB; }
- (CKDatabase *)publicCloudDatabase { return (CKDatabase *)_publicDB; }
- (CKDatabase *)sharedCloudDatabase { return (CKDatabase *)_sharedDB; }

- (CKDatabase *)databaseWithDatabaseScope:(CKDatabaseScope)scope {
    switch (scope) {
        case CKDatabaseScopePublic: return (CKDatabase *)_publicDB;
        case CKDatabaseScopeShared: return (CKDatabase *)_sharedDB;
        case CKDatabaseScopePrivate:
        default: return (CKDatabase *)_privateDB;
    }
}

- (void)accountStatusWithCompletionHandler:(void (^)(CKAccountStatus status, NSError *error))h {
    LibraCallBlock2(h, (id)(NSInteger)CKAccountStatusNoAccount, LibraCKUnavailable());
}

- (void)fetchUserRecordIDWithCompletionHandler:(void (^)(CKRecordID *recordID, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)requestApplicationPermission:(CKApplicationPermissions)permission completionHandler:(void (^)(CKApplicationPermissionStatus status, NSError *error))h {
    LibraCallBlock2(h, (id)(NSInteger)CKApplicationPermissionStatusDenied, LibraCKUnavailable());
}

- (void)statusForApplicationPermission:(CKApplicationPermissions)permission completionHandler:(void (^)(CKApplicationPermissionStatus status, NSError *error))h {
    LibraCallBlock2(h, (id)(NSInteger)CKApplicationPermissionStatusDenied, LibraCKUnavailable());
}

- (void)fetchShareMetadataWithURL:(NSURL *)url completionHandler:(void (^)(id metadata, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)acceptShareMetadata:(id)metadata completionHandler:(void (^)(id share, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverAllIdentitiesWithCompletionHandler:(void (^)(NSArray *identities, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverUserIdentityWithEmailAddress:(NSString *)email completionHandler:(void (^)(id identity, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverUserIdentityWithPhoneNumber:(NSString *)phone completionHandler:(void (^)(id identity, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)discoverUserIdentityWithUserRecordID:(CKRecordID *)userRecordID completionHandler:(void (^)(id identity, NSError *error))h {
    LibraCallBlock2(h, nil, LibraCKUnavailable());
}

- (void)addOperation:(NSOperation *)operation {
    [(LibraFakeDatabase *)_privateDB addOperation:operation];
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

static id LibraHookedDefaultContainer(id self, SEL _cmd) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[LibraCKFix] CKContainer.default -> inert container");
    return [LibraFakeContainer sharedWithIdentifier:
            [NSString stringWithFormat:@"iCloud.%@", bundleID ?: @"com.sevenzx.Libra"]];
}

static id LibraHookedContainerWithIdentifierEnv(id self, SEL _cmd, NSString *identifier, id env) {
    NSLog(@"[LibraCKFix] CKContainer(identifier: %@, env: %@) -> inert container", identifier, env);
    return [LibraFakeContainer sharedWithIdentifier:identifier];
}

static void LibraInstallHooks(void) {
    if (g_installed) return;
    Class CK = NSClassFromString(@"CKContainer");
    if (!CK) return;

    g_installed = YES;

    Method m = class_getClassMethod(CK, @selector(containerWithIdentifier:));
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
