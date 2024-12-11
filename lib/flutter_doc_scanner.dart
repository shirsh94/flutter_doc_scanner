import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_web.dart';
import 'flutter_doc_scanner_platform_interface.dart';

class FlutterDocScanner {
  Future<String?> getPlatformVersion() {
    return FlutterDocScannerPlatform.instance.getPlatformVersion();
  }

  Future<dynamic> getScanDocuments() {
    return FlutterDocScannerPlatform.instance.getScanDocuments();
  }

  /// Opens the document scanner dialog in a web environment.
   Future<String?> getScanDocumentsWeb(
      BuildContext context, {
        required String appBarTitle,
        required String captureButtonText,
        required String cropButtonText,
        required String cropPdfButtonText,
        required double width,
        required double height,
      }) async {
    return await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentScannerPage(
          appBarTitle: appBarTitle,
          captureButtonText: captureButtonText,
          cropButtonText: cropButtonText,
          cropPdfButtonText: cropPdfButtonText,
          width: width,
          height: height,
        ),
      ),
    );
  }


  Future<dynamic> getScanDocumentsUri() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return FlutterDocScannerPlatform.instance.getScanDocumentsUri();
    } else {
      return Future.error("Currently, this feature is supported only on Android Platform.");
    }
  }
}
