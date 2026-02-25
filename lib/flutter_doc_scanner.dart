import 'package:flutter/foundation.dart';

import 'flutter_doc_scanner_exception.dart';
import 'flutter_doc_scanner_models.dart';
import 'flutter_doc_scanner_platform_interface.dart';

export 'flutter_doc_scanner_exception.dart';
export 'flutter_doc_scanner_models.dart';

class FlutterDocScanner {
  Future<String?> getPlatformVersion() {
    return FlutterDocScannerPlatform.instance.getPlatformVersion();
  }

  /// Scans documents using the default behavior (images on iOS, PDF on Android).
  ///
  /// [page] is the maximum number of pages to scan (must be >= 1, defaults to 4).
  /// Returns `null` if the user cancelled the scan.
  /// Throws [DocScanException] on failure.
  Future<dynamic> getScanDocuments({int page = 4}) {
    _validatePage(page);
    return FlutterDocScannerPlatform.instance.getScanDocuments(page);
  }

  /// Scans documents and returns image file paths.
  ///
  /// [page] is the maximum number of pages to scan (must be >= 1, defaults to 4).
  /// [imageFormat] controls the output image format. On iOS, this determines
  /// whether images are saved as PNG or JPEG. On Android, ML Kit always returns
  /// JPEG regardless of this setting. Defaults to [ImageFormat.jpeg].
  /// [quality] controls JPEG compression quality on iOS (0.0 to 1.0, where 1.0
  /// is highest quality). Only applies when [imageFormat] is [ImageFormat.jpeg].
  /// Ignored on Android. Defaults to 0.9.
  /// Returns `null` if the user cancelled the scan.
  /// Throws [DocScanException] on failure.
  Future<ImageScanResult?> getScannedDocumentAsImages({
    int page = 4,
    ImageFormat imageFormat = ImageFormat.jpeg,
    double quality = 0.9,
  }) async {
    _validatePage(page);
    if (quality < 0.0 || quality > 1.0) {
      throw ArgumentError.value(quality, 'quality', 'Must be between 0.0 and 1.0');
    }
    final data = await FlutterDocScannerPlatform.instance
        .getScannedDocumentAsImages(page, imageFormat.name, quality);
    if (data == null) return null;
    return ImageScanResult.fromPlatformData(data);
  }

  /// Scans documents and returns a PDF file path.
  ///
  /// [page] is the maximum number of pages to scan (must be >= 1, defaults to 4).
  /// Returns `null` if the user cancelled the scan.
  /// Throws [DocScanException] on failure.
  Future<PdfScanResult?> getScannedDocumentAsPdf({int page = 4}) async {
    _validatePage(page);
    final data =
        await FlutterDocScannerPlatform.instance.getScannedDocumentAsPdf(page);
    if (data == null) return null;
    return PdfScanResult.fromPlatformData(data);
  }

  /// Scans documents and returns URIs. **Android only.**
  ///
  /// [page] is the maximum number of pages to scan (must be >= 1, defaults to 4).
  /// Returns `null` if the user cancelled the scan.
  /// Throws [DocScanException] on failure or if called on a non-Android platform.
  Future<ImageScanResult?> getScanDocumentsUri({int page = 4}) async {
    _validatePage(page);
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw const DocScanException(
        code: DocScanException.codeUnsupported,
        message: 'getScanDocumentsUri is only supported on Android',
      );
    }
    final data =
        await FlutterDocScannerPlatform.instance.getScanDocumentsUri(page);
    if (data == null) return null;
    return ImageScanResult.fromPlatformData(data);
  }

  void _validatePage(int page) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be at least 1');
    }
  }
}
