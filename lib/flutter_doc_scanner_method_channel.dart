import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_doc_scanner_exception.dart';
import 'flutter_doc_scanner_platform_interface.dart';

/// An implementation of [FlutterDocScannerPlatform] that uses method channels.
class MethodChannelFlutterDocScanner extends FlutterDocScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_doc_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<dynamic> getScanDocuments(int page) async {
    try {
      return await methodChannel.invokeMethod<dynamic>(
        'getScanDocuments',
        {'page': page},
      );
    } on PlatformException catch (e) {
      throw DocScanException(
        code: e.code,
        message: e.message ?? 'Failed to scan documents',
        details: e.details,
      );
    }
  }

  @override
  Future<dynamic> getScannedDocumentAsImages(int page, String imageFormat, double quality) async {
    try {
      return await methodChannel.invokeMethod<dynamic>(
        'getScannedDocumentAsImages',
        {'page': page, 'imageFormat': imageFormat, 'quality': quality},
      );
    } on PlatformException catch (e) {
      throw DocScanException(
        code: e.code,
        message: e.message ?? 'Failed to scan document images',
        details: e.details,
      );
    }
  }

  @override
  Future<dynamic> getScannedDocumentAsPdf(int page) async {
    try {
      return await methodChannel.invokeMethod<dynamic>(
        'getScannedDocumentAsPdf',
        {'page': page},
      );
    } on PlatformException catch (e) {
      throw DocScanException(
        code: e.code,
        message: e.message ?? 'Failed to scan document as PDF',
        details: e.details,
      );
    }
  }

  @override
  Future<dynamic> getScanDocumentsUri(int page) async {
    try {
      return await methodChannel.invokeMethod<dynamic>(
        'getScanDocumentsUri',
        {'page': page},
      );
    } on PlatformException catch (e) {
      throw DocScanException(
        code: e.code,
        message: e.message ?? 'Failed to scan document URIs',
        details: e.details,
      );
    }
  }
}
