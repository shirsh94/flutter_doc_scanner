import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_doc_scanner_platform_interface.dart';
import 'models/scan_result.dart';

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
  Future<DocumentScanResult?> getScanDocuments() async {
    final Map<String, dynamic>? result = 
        await methodChannel.invokeMapMethod<String, dynamic>('getScanDocuments');
    return result != null ? DocumentScanResult.fromMap(result) : null;
  }

  @override
  Future<DocumentScanResult?> getScanDocumentsUri() async {
    final Map<String, dynamic>? result = 
        await methodChannel.invokeMapMethod<String, dynamic>('getScanDocumentsUri');
    return result != null ? DocumentScanResult.fromMap(result) : null;
  }
}
