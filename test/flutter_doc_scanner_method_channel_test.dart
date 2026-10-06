import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_method_channel.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterDocScanner platform = MethodChannelFlutterDocScanner();
  final initialPlatform = FlutterDocScannerPlatform.instance;
  const MethodChannel channel = MethodChannel('flutter_doc_scanner');

  setUp(() {
    FlutterDocScannerPlatform.instance = platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    FlutterDocScannerPlatform.instance = initialPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  for (final automaticProcessing in [false, true]) {
    test(
        'getScannedDocumentAsImages omits scannerMode with '
        'automatic processing $automaticProcessing', () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          capturedCall = methodCall;
          return null;
        },
      );

      await FlutterDocScanner().getScannedDocumentAsImages(
        page: 1,
        useAutomaticSinglePictureProcessing: automaticProcessing,
      );

      expect(capturedCall?.method, 'getScannedDocumentAsImages');
      expect(capturedCall?.arguments, {
        'page': 1,
        'imageFormat': 'jpeg',
        'quality': 0.9,
        'useAutomaticSinglePictureProcessing': automaticProcessing,
      });
    });
  }

  for (final scannerMode in DocumentScannerMode.values) {
    test('getScannedDocumentAsImages passes ${scannerMode.name} scannerMode',
        () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          capturedCall = methodCall;
          return null;
        },
      );

      await FlutterDocScanner().getScannedDocumentAsImages(
        page: 1,
        scannerMode: scannerMode,
      );

      expect(capturedCall?.method, 'getScannedDocumentAsImages');
      expect(capturedCall?.arguments,
          containsPair('scannerMode', scannerMode.name));
    });
  }
}
