#import "FlutterRadioPlayerPlugin.h"
#if __has_include(<flutter_radio_player/flutter_radio_player-Swift.h>)
#import <flutter_radio_player/flutter_radio_player-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_radio_player-Swift.h"
#endif

@implementation FlutterRadioPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterRadioPlayerPlugin registerWithRegistrar:registrar];
}
@end
