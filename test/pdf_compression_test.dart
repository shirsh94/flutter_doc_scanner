import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_method_channel.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records what [FlutterDocScanner] hands to the platform layer.
class _RecordingPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDocScannerPlatform {
  int? page;
  DocScanCompression? compression;
  bool called = false;

  @override
  Future<dynamic> getScannedDocumentAsPdf(
    int page, {
    DocScanCompression? compression,
  }) async {
    called = true;
    this.page = page;
    this.compression = compression;
    return {'pdfUri': 'file:///scan.pdf', 'pageCount': 2};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocScanCompression', () {
    test('defaults to quality 0.8 and no size limit', () {
      const compression = DocScanCompression();
      expect(compression.quality, 0.8);
      expect(compression.maxDimension, isNull);
    });

    test('toMap leaves maxDimension out when it is not set', () {
      expect(const DocScanCompression(quality: 0.5).toMap(), {'quality': 0.5});
    });

    test('toMap carries both values when set', () {
      expect(
        const DocScanCompression(quality: 0.7, maxDimension: 2500).toMap(),
        {'quality': 0.7, 'maxDimension': 2500},
      );
    });

    test('equal values are equal', () {
      expect(
        const DocScanCompression(quality: 0.7, maxDimension: 2500),
        const DocScanCompression(quality: 0.7, maxDimension: 2500),
      );
      expect(
        const DocScanCompression(quality: 0.7),
        isNot(const DocScanCompression(quality: 0.7, maxDimension: 1)),
      );
    });
  });

  group('FlutterDocScanner.getScannedDocumentAsPdf', () {
    late _RecordingPlatform platform;
    final initialPlatform = FlutterDocScannerPlatform.instance;

    setUp(() {
      platform = _RecordingPlatform();
      FlutterDocScannerPlatform.instance = platform;
    });

    tearDown(() => FlutterDocScannerPlatform.instance = initialPlatform);

    test('passes no compression when none is given', () async {
      final result = await FlutterDocScanner().getScannedDocumentAsPdf(page: 3);
      expect(platform.page, 3);
      expect(platform.compression, isNull);
      expect(result?.pdfUri, 'file:///scan.pdf');
      expect(result?.pageCount, 2);
    });

    test('passes the compression through', () async {
      const compression = DocScanCompression(quality: 0.6, maxDimension: 2000);
      await FlutterDocScanner().getScannedDocumentAsPdf(
        page: 5,
        compression: compression,
      );
      expect(platform.page, 5);
      expect(platform.compression, compression);
    });

    for (final quality in [-0.1, 1.1, double.nan]) {
      test('rejects quality $quality before scanning', () {
        expect(
          () => FlutterDocScanner().getScannedDocumentAsPdf(
            compression: DocScanCompression(quality: quality),
          ),
          throwsArgumentError,
        );
        expect(platform.called, isFalse);
      });
    }

    test('accepts the quality bounds 0.0 and 1.0', () async {
      await FlutterDocScanner().getScannedDocumentAsPdf(
        compression: const DocScanCompression(quality: 0.0),
      );
      await FlutterDocScanner().getScannedDocumentAsPdf(
        compression: const DocScanCompression(quality: 1.0),
      );
      expect(platform.called, isTrue);
    });

    for (final maxDimension in [0, -1]) {
      test('rejects maxDimension $maxDimension before scanning', () {
        expect(
          () => FlutterDocScanner().getScannedDocumentAsPdf(
            compression: DocScanCompression(maxDimension: maxDimension),
          ),
          throwsArgumentError,
        );
        expect(platform.called, isFalse);
      });
    }
  });

  group('MethodChannelFlutterDocScanner.getScannedDocumentAsPdf', () {
    const channel = MethodChannel('flutter_doc_scanner');
    final platform = MethodChannelFlutterDocScanner();
    MethodCall? lastCall;

    setUp(() {
      lastCall = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            lastCall = call;
            return '/tmp/scan.pdf';
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends only the page when there is no compression', () async {
      await platform.getScannedDocumentAsPdf(4);
      expect(lastCall?.method, 'getScannedDocumentAsPdf');
      expect(lastCall?.arguments, {'page': 4});
    });

    test('sends the compression map when set', () async {
      await platform.getScannedDocumentAsPdf(
        5,
        compression: const DocScanCompression(quality: 0.7, maxDimension: 2500),
      );
      expect(lastCall?.arguments, {
        'page': 5,
        'compression': {'quality': 0.7, 'maxDimension': 2500},
      });
    });

    test('turns a PlatformException into a DocScanException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'PDF_CREATION_ERROR', message: 'x');
          });
      expect(
        () => platform.getScannedDocumentAsPdf(
          1,
          compression: const DocScanCompression(),
        ),
        throwsA(
          isA<DocScanException>().having(
            (e) => e.code,
            'code',
            'PDF_CREATION_ERROR',
          ),
        ),
      );
    });
  });
}
