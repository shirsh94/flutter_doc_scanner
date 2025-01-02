// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'flutter_doc_scanner_platform_interface.dart';

/// A web implementation of the FlutterDocScannerPlatform of the FlutterDocScanner plugin.
class FlutterDocScannerWeb extends FlutterDocScannerPlatform {
  /// Constructs a FlutterDocScannerWeb
  FlutterDocScannerWeb();

  static void registerWith(Registrar registrar) {
    FlutterDocScannerPlatform.instance = FlutterDocScannerWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = html.window.navigator.userAgent;
    return version;
  }

  @override
  Future<String?> getScanDocuments([int page = 5]) async {
    final data = html.window.navigator.userAgent;
    return data;
  }

  @override
  Future<String?> getScanDocumentsUri([int page = 5]) async {
    final data = html.window.navigator.userAgent;
    return data;
  }
}
