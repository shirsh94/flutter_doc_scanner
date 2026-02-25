import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_method_channel.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterDocScanner platform = MethodChannelFlutterDocScanner();
  const MethodChannel channel = MethodChannel('flutter_doc_scanner');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getPlatformVersion':
            return '42';
          case 'getScanDocuments':
            return {
              'pdfUri': 'content://scan.pdf',
              'pageCount': 1,
            };
          case 'getScannedDocumentAsImages':
            return {
              'images': ['content://img1.jpg'],
              'count': 1,
            };
          case 'getScannedDocumentAsPdf':
            return {
              'pdfUri': 'content://scan.pdf',
              'pageCount': 2,
            };
          case 'getScanDocumentsUri':
            return {
              'images': ['content://uri1'],
              'count': 1,
            };
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('getScanDocuments returns map', () async {
    final result = await platform.getScanDocuments(4);
    expect(result, isA<Map>());
    expect((result as Map)['pdfUri'], 'content://scan.pdf');
  });

  test('getScannedDocumentAsImages returns map', () async {
    final result = await platform.getScannedDocumentAsImages(4, 'jpeg');
    expect(result, isA<Map>());
    expect((result as Map)['images'], ['content://img1.jpg']);
  });

  test('getScannedDocumentAsPdf returns map', () async {
    final result = await platform.getScannedDocumentAsPdf(4);
    expect(result, isA<Map>());
    expect((result as Map)['pdfUri'], 'content://scan.pdf');
  });

  group('error handling', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'SCAN_FAILED',
            message: 'Test error',
            details: 'Some details',
          );
        },
      );
    });

    test('getScanDocuments wraps PlatformException as DocScanException',
        () async {
      expect(
        () => platform.getScanDocuments(4),
        throwsA(
          isA<DocScanException>()
              .having((e) => e.code, 'code', 'SCAN_FAILED')
              .having((e) => e.message, 'message', 'Test error'),
        ),
      );
    });

    test(
        'getScannedDocumentAsImages wraps PlatformException as DocScanException',
        () async {
      expect(
        () => platform.getScannedDocumentAsImages(4, 'jpeg'),
        throwsA(isA<DocScanException>()),
      );
    });

    test('getScannedDocumentAsPdf wraps PlatformException as DocScanException',
        () async {
      expect(
        () => platform.getScannedDocumentAsPdf(4),
        throwsA(isA<DocScanException>()),
      );
    });
  });
}
