#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "EmptyState" asset catalog image resource.
static NSString * const ACImageNameEmptyState AC_SWIFT_PRIVATE = @"EmptyState";

/// The "Settings" asset catalog image resource.
static NSString * const ACImageNameSettings AC_SWIFT_PRIVATE = @"Settings";

#undef AC_SWIFT_PRIVATE
