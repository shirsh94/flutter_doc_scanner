#import "FlutterIOSDocScannerPlugin.h"
#if __has_include(<flutter_ios_doc_scanner/flutter_ios_doc_scanner-Swift.h>)
#import <flutter_ios_doc_scanner/flutter_ios_doc_scanner-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_ios_doc_scanner-Swift.h"
#endif

@implementation FlutterIOSDocScanner
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterIOSDocScanner registerWithRegistrar:registrar];
}
@end