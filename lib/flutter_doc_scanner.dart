import 'package:flutter/foundation.dart';
import 'flutter_doc_scanner_platform_interface.dart';

class FlutterDocScanner {
  Future<String?> getPlatformVersion() {
    return FlutterDocScannerPlatform.instance.getPlatformVersion();
  }

  Future<dynamic> getScanDocuments() {
    return FlutterDocScannerPlatform.instance.getScanDocuments();
  }

  Future<dynamic> getScanDocumentsUri() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return FlutterDocScannerPlatform.instance.getScanDocumentsUri();
    } else {
      return Future.error("Currently, this feature is supported only on Android Platform,");
    }
  }
}
