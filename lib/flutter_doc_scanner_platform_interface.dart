import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_doc_scanner_method_channel.dart';

abstract class FlutterDocScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterDocScannerPlatform.
  FlutterDocScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDocScannerPlatform _instance = MethodChannelFlutterDocScanner();

  /// The default instance of [FlutterDocScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterDocScanner].
  static FlutterDocScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDocScannerPlatform] when
  /// they register themselves.
  static set instance(FlutterDocScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Scans documents and returns raw platform data.
  ///
  /// Returns `null` if the user cancelled. The raw data shape varies by
  /// platform and is normalized by [FlutterDocScanner].
  Future<dynamic> getScanDocuments(int page) {
    throw UnimplementedError('getScanDocuments() has not been implemented.');
  }

  /// Scans documents and returns raw image data from the platform.
  ///
  /// [imageFormat] controls the output format on iOS (Android always returns JPEG).
  /// Returns `null` if the user cancelled.
  Future<dynamic> getScannedDocumentAsImages(int page, String imageFormat) {
    throw UnimplementedError(
        'getScannedDocumentAsImages() has not been implemented.');
  }

  /// Scans documents and returns raw PDF data from the platform.
  ///
  /// Returns `null` if the user cancelled.
  Future<dynamic> getScannedDocumentAsPdf(int page) {
    throw UnimplementedError(
        'getScannedDocumentAsPdf() has not been implemented.');
  }

  /// Scans documents and returns URIs (Android only).
  ///
  /// Returns `null` if the user cancelled.
  Future<dynamic> getScanDocumentsUri(int page) {
    throw UnimplementedError('getScanDocumentsUri() has not been implemented.');
  }
}
