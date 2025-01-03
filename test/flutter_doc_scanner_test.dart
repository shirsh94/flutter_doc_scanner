import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_platform_interface.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterDocScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDocScannerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> getScanDocuments([int page = 5]) => Future.value();

  @override
  Future<String?> getScannedDocumentAsImages([int page = 5]) => Future.value();

  @override
  Future<String?> getScannedDocumentAsPdf([int page = 5]) => Future.value();

  @override
  Future<String?> getScanDocumentsUri([int page = 5]) => Future.value();
}

void main() {
  final FlutterDocScannerPlatform initialPlatform =
      FlutterDocScannerPlatform.instance;

  test('$MethodChannelFlutterDocScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterDocScanner>());
  });

  test('getPlatformVersion', () async {
    FlutterDocScanner flutterDocScannerPlugin = FlutterDocScanner();
    MockFlutterDocScannerPlatform fakePlatform =
        MockFlutterDocScannerPlatform();
    FlutterDocScannerPlatform.instance = fakePlatform;

    expect(await flutterDocScannerPlugin.getPlatformVersion(), '42');
  });
}
