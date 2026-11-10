// Based on pookjw/ClearAndBlurredWidgets, FooObject.mm by Jinwoo Kim.
// Experimental private WidgetKit descriptor hook. Compiled WITHOUT ARC.
// Missing APIs / ordinary Objective-C decoding errors fall back to the original
// result. These checks cannot make private Swift ABI changes safe or supported.
#import "FooObject.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static BOOL GTCanPatch(id descriptor, BOOL blur) {
    return [descriptor respondsToSelector:sel_registerName("setBackgroundRemovable:")]
        && [descriptor respondsToSelector:sel_registerName("setTransparent:")]
        && [descriptor respondsToSelector:sel_registerName("setPreferredBackgroundStyle:")]
        && (!blur || [descriptor respondsToSelector:sel_registerName("setSupportsVibrantContent:")]);
}

@interface GTDescriptorResult : NSObject <NSSecureCoding> {
    NSArray *_activityDescriptors;
    NSArray *_controlDescriptors;
    NSArray *_widgetDescriptors;
    BOOL _didPatch;
}
@property(nonatomic, readonly) BOOL didPatch;
@end

@implementation GTDescriptorResult
@synthesize didPatch = _didPatch;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (!(self = [super init])) return nil;
    Class activityClass = objc_lookUpClass("CHSBaseDescriptor");
    Class controlClass = objc_lookUpClass("CHSControlDescriptor");
    Class widgetClass = objc_lookUpClass("CHSWidgetDescriptor");
    if (!activityClass || !controlClass || !widgetClass) {
        [self release];
        return nil;
    }
    _activityDescriptors = [[coder decodeObjectOfClasses:
        [NSSet setWithObjects:NSArray.class, activityClass, nil]
        forKey:@"activityDescriptors"] retain];
    _controlDescriptors = [[coder decodeObjectOfClasses:
        [NSSet setWithObjects:NSArray.class, controlClass, nil]
        forKey:@"controlDescriptors"] retain];
    NSArray *widgets = [coder decodeObjectOfClasses:
        [NSSet setWithObjects:NSArray.class, widgetClass, nil]
        forKey:@"widgetDescriptors"];
    if (coder.error || ![widgets isKindOfClass:NSArray.class]) {
        [self release];
        return nil;
    }
    NSMutableArray *updated = [NSMutableArray arrayWithCapacity:widgets.count];
    for (id descriptor in widgets) {
        SEL kindSelector = sel_registerName("kind");
        if (![descriptor respondsToSelector:kindSelector]) {
            [updated addObject:descriptor];
            continue;
        }
        id kind = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(descriptor, kindSelector);
        if (![kind isKindOfClass:NSString.class]) {
            [updated addObject:descriptor];
            continue;
        }
        BOOL clear = [kind isEqualToString:@"MyClearWidget"];
        BOOL blur = [kind isEqualToString:@"MyBlurWidget"] || [kind isEqualToString:@"MyBlueWidget"];
        if ((!clear && !blur) || ![descriptor respondsToSelector:@selector(mutableCopyWithZone:)]) {
            [updated addObject:descriptor];
            continue;
        }
        id patched = [[descriptor mutableCopy] autorelease];
        if (!GTCanPatch(patched, blur)) {
            NSLog(@"[GlassTest] Required descriptor setters unavailable for %@", kind);
            [updated addObject:descriptor];
            continue;
        }
        reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
            patched, sel_registerName("setBackgroundRemovable:"), YES);
        reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
            patched, sel_registerName("setTransparent:"), YES);
        if (blur) {
            reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
                patched, sel_registerName("setSupportsVibrantContent:"), YES);
        }
        reinterpret_cast<void (*)(id, SEL, NSUInteger)>(objc_msgSend)(
            patched, sel_registerName("setPreferredBackgroundStyle:"), clear ? 0x1 : 0x2);
        [updated addObject:patched];
        _didPatch = YES;
        NSLog(@"[GlassTest] Requested background style for %@ (appearance not verified)", kind);
    }
    _widgetDescriptors = [updated copy];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_activityDescriptors forKey:@"activityDescriptors"];
    [coder encodeObject:_controlDescriptors forKey:@"controlDescriptors"];
    [coder encodeObject:_widgetDescriptors forKey:@"widgetDescriptors"];
}
- (void)dealloc {
    [_activityDescriptors release];
    [_controlDescriptors release];
    [_widgetDescriptors release];
    [super dealloc];
}
@end

static NSKeyedUnarchiver *GTReader(id<NSCoding> object) {
    // Keep archiver/data alive until the reader has consumed the archive.
    NSKeyedArchiver *writer = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:YES] autorelease];
    [object encodeWithCoder:writer];
    [writer finishEncoding];
    NSError *error = nil;
    NSKeyedUnarchiver *reader = [[[NSKeyedUnarchiver alloc]
        initForReadingFromData:writer.encodedData error:&error] autorelease];
    if (error || !reader) return nil;
    reader.requiresSecureCoding = YES;
    reader.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
    return reader;
}

static id GTPatchResult(id originalResult) {
    @try {
        Class resultClass = objc_lookUpClass("_TtC9WidgetKit21DescriptorFetchResult");
        if (!originalResult || !resultClass
            || ![originalResult respondsToSelector:@selector(encodeWithCoder:)]
            || ![resultClass instancesRespondToSelector:@selector(initWithCoder:)]) return originalResult;
        NSKeyedUnarchiver *firstReader = GTReader(originalResult);
        if (!firstReader) return originalResult;
        GTDescriptorResult *patched = [[[GTDescriptorResult alloc] initWithCoder:firstReader] autorelease];
        if (!patched || firstReader.error || !patched.didPatch) return originalResult;
        NSKeyedUnarchiver *secondReader = GTReader(patched);
        if (!secondReader) return originalResult;
        // Direct Objective-C initializer dispatch preserves ownership conventions.
        id rebuilt = [[[resultClass alloc] initWithCoder:secondReader] autorelease];
        if (!rebuilt || secondReader.error) return originalResult;
        return rebuilt;
    } @catch (NSException *exception) {
        NSLog(@"[GlassTest] Descriptor patch skipped: %@", exception.name);
        return originalResult;
    }
}

typedef void (^GTCompletion)(id);
static void (*GTOriginal)(id, SEL, GTCompletion) = nullptr;
static void GTGetDescriptors(id object, SEL selector, GTCompletion completion) {
    GTOriginal(object, selector, ^(id result) {
        id patched = GTPatchResult(result);
        if (completion) completion(patched);
    });
}
static BOOL GTInstall(void) {
    if (GTOriginal) return YES;
    Class exportClass = objc_lookUpClass("_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject");
    SEL selector = sel_registerName("getAllCurrentDescriptorsWithCompletion:");
    if (!exportClass) return NO;
    Method method = class_getInstanceMethod(exportClass, selector);
    if (!method) return NO;
    IMP implementation = method_getImplementation(method);
    if (!implementation) return NO;
    GTOriginal = reinterpret_cast<decltype(GTOriginal)>(implementation);
    // Do not modify an inherited method on its superclass.
    if (!class_addMethod(exportClass, selector, reinterpret_cast<IMP>(GTGetDescriptors), method_getTypeEncoding(method))) {
        method_setImplementation(class_getInstanceMethod(exportClass, selector), reinterpret_cast<IMP>(GTGetDescriptors));
    }
    NSLog(@"[GlassTest] Descriptor hook installed; verify actual appearance on device");
    return YES;
}
@implementation FooObject
+ (void)load {
    if (!GTInstall()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!GTInstall()) NSLog(@"[GlassTest] Hook unavailable; using standard widget rendering");
        });
    }
}
@end
