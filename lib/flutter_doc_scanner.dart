import 'package:flutter/foundation.dart';
import 'package:flutter_doc_scanner/models/scan_result.dart';

import 'flutter_doc_scanner_platform_interface.dart';

class FlutterDocScanner {
  Future<String?> getPlatformVersion() {
    return FlutterDocScannerPlatform.instance.getPlatformVersion();
  }

  Future<DocumentScanResult?> getScanDocuments() {
    return FlutterDocScannerPlatform.instance.getScanDocuments();
  }

  Future<DocumentScanResult?> getScanDocumentsUri() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return FlutterDocScannerPlatform.instance.getScanDocumentsUri();
    } else {
      return Future.error(
          "Currently, this feature is supported only on Android Platform,");
    }
  }
}
