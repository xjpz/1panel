#import "WidgetDescriptorBackgroundInjector.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <TargetConditionals.h>

static NSDictionary<NSString *, NSDictionary *> *_kindBackgroundStyles;

@interface MonoDashDescriptorFetchResult : NSObject <NSSecureCoding> {
@public
  NSArray *_activityDescriptors;
  NSArray *_controlDescriptors;
  NSArray *_widgetDescriptors;
}
@end

@implementation MonoDashDescriptorFetchResult

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder {
  if (self = [super init]) {
    Class baseDescriptorClass = objc_lookUpClass("CHSBaseDescriptor");
    Class controlDescriptorClass = objc_lookUpClass("CHSControlDescriptor");
    Class widgetDescriptorClass = objc_lookUpClass("CHSWidgetDescriptor");

    NSArray *activityDescriptors = [coder decodeObjectOfClasses:
      [NSSet setWithObjects:NSArray.class, baseDescriptorClass, nil]
      forKey:@"activityDescriptors"];
    NSArray *controlDescriptors = [coder decodeObjectOfClasses:
      [NSSet setWithObjects:NSArray.class, controlDescriptorClass, nil]
      forKey:@"controlDescriptors"];
    NSArray *widgetDescriptors = [coder decodeObjectOfClasses:
      [NSSet setWithObjects:NSArray.class, widgetDescriptorClass, nil]
      forKey:@"widgetDescriptors"];

    NSMutableArray *updatedDescriptors = [[NSMutableArray alloc] initWithCapacity:widgetDescriptors.count];
    for (id descriptor in widgetDescriptors) {
      NSString *kind = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)
        (descriptor, sel_registerName("kind"));
      NSDictionary *styleInfo = _kindBackgroundStyles[kind];
      if (!styleInfo) {
        [updatedDescriptors addObject:descriptor];
        continue;
      }

      id mutableDescriptor = [descriptor mutableCopy];
      reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)
        (mutableDescriptor, sel_registerName("setBackgroundRemovable:"), YES);
      reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)
        (mutableDescriptor, sel_registerName("setTransparent:"), YES);

      NSUInteger style = [styleInfo[@"style"] unsignedIntegerValue];
      if ([styleInfo[@"vibrant"] boolValue]) {
        reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)
          (mutableDescriptor, sel_registerName("setSupportsVibrantContent:"), YES);
      }
      reinterpret_cast<void (*)(id, SEL, NSUInteger)>(objc_msgSend)
        (mutableDescriptor, sel_registerName("setPreferredBackgroundStyle:"), style);

      [updatedDescriptors addObject:mutableDescriptor];
      [mutableDescriptor release];
    }

    _activityDescriptors = [activityDescriptors retain];
    _controlDescriptors = [controlDescriptors retain];
    _widgetDescriptors = [updatedDescriptors copy];
    [updatedDescriptors release];
  }
  return self;
}

- (void)dealloc {
  [_activityDescriptors release];
  [_controlDescriptors release];
  [_widgetDescriptors release];
  [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:_activityDescriptors forKey:@"activityDescriptors"];
  [coder encodeObject:_controlDescriptors forKey:@"controlDescriptors"];
  [coder encodeObject:_widgetDescriptors forKey:@"widgetDescriptors"];
}

@end

namespace MonoDashDescriptorInjection {
  void (*original)(id, SEL, id);

  void replacement(id self, SEL command, void (^completion)(id fetchResult)) {
    original(self, command, ^(id originalResult) {
      NSError *error = nil;
      NSKeyedArchiver *sourceArchiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
      [originalResult encodeWithCoder:sourceArchiver];
      NSData *sourceData = sourceArchiver.encodedData;
      [sourceArchiver release];

      NSKeyedUnarchiver *sourceUnarchiver = [[NSKeyedUnarchiver alloc]
        initForReadingFromData:sourceData error:&error];
      if (error) {
        [sourceUnarchiver release];
        completion(originalResult);
        return;
      }

      MonoDashDescriptorFetchResult *updatedResult = [[MonoDashDescriptorFetchResult alloc]
        initWithCoder:sourceUnarchiver];
      [sourceUnarchiver release];

      NSKeyedArchiver *updatedArchiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
      [updatedResult encodeWithCoder:updatedArchiver];
      NSData *updatedData = updatedArchiver.encodedData;
      [updatedArchiver release];
      [updatedResult release];

      NSKeyedUnarchiver *updatedUnarchiver = [[NSKeyedUnarchiver alloc]
        initForReadingFromData:updatedData error:&error];
      if (error) {
        [updatedUnarchiver release];
        completion(originalResult);
        return;
      }

      Class originalClass = objc_lookUpClass("_TtC9WidgetKit21DescriptorFetchResult");
      if (!originalClass) {
        originalClass = objc_lookUpClass("_TtCC9WidgetKit24DescriptorFetchResult");
      }
      if (!originalClass) {
        originalClass = [originalResult class];
      }

      id finalResult = reinterpret_cast<id (*)(id, SEL, id)>(objc_msgSend)
        ([originalClass alloc], @selector(initWithCoder:), updatedUnarchiver);
      [updatedUnarchiver release];

      if (finalResult) {
        completion(finalResult);
        [finalResult release];
      } else {
        completion(originalResult);
      }
    });
  }

  void install() {
    const char *classNames[] = {
      "_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject",
      "_TtC9WidgetKit21WidgetExtensionXPCServer14ExportedObject",
      "_TtCC9WidgetKit21WidgetExtensionXPCServer14ExportedObject",
      NULL
    };

    Class targetClass = nil;
    for (int index = 0; classNames[index] != NULL; index++) {
      targetClass = objc_lookUpClass(classNames[index]);
      if (targetClass) break;
    }

    SEL selector = sel_registerName("getAllCurrentDescriptorsWithCompletion:");
    if (!targetClass) {
      unsigned int classCount = 0;
      Class *classes = objc_copyClassList(&classCount);
      for (unsigned int index = 0; index < classCount; index++) {
        if (class_getInstanceMethod(classes[index], selector)) {
          targetClass = classes[index];
          break;
        }
      }
      free(classes);
    }

    Method method = targetClass ? class_getInstanceMethod(targetClass, selector) : nil;
    if (!method) return;

    original = reinterpret_cast<decltype(original)>(method_getImplementation(method));
    method_setImplementation(method, reinterpret_cast<IMP>(replacement));
  }
}

@implementation WidgetDescriptorBackgroundInjector
@end

__attribute__((constructor))
static void InstallMonoDashWidgetDescriptorBackgroundInjector(void) {
#if TARGET_OS_IOS
  _kindBackgroundStyles = @{
    @"MonoDashTransparentWidget": @{ @"style": @(0x1), @"vibrant": @NO },
    @"MonoDashLiquidGlassWidget": @{ @"style": @(0x2), @"vibrant": @YES },
    @"MonoDashDarkWidget": @{ @"style": @(0x1), @"vibrant": @NO },
  };
  MonoDashDescriptorInjection::install();
#endif
}
