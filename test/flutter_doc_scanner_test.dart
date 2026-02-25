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
  Future<dynamic> getScanDocuments(int page) =>
      Future.value(['path/to/image1.png', 'path/to/image2.png']);

  @override
  Future<dynamic> getScannedDocumentAsImages(int page, String imageFormat) =>
      Future.value({'images': ['path/to/image1.png'], 'count': 1});

  @override
  Future<dynamic> getScannedDocumentAsPdf(int page) =>
      Future.value({'pdfUri': 'path/to/doc.pdf', 'pageCount': 2});

  @override
  Future<dynamic> getScanDocumentsUri(int page) =>
      Future.value({'images': ['content://uri1'], 'count': 1});
}

class MockCancelledScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDocScannerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<dynamic> getScanDocuments(int page) => Future.value(null);

  @override
  Future<dynamic> getScannedDocumentAsImages(int page, String imageFormat) => Future.value(null);

  @override
  Future<dynamic> getScannedDocumentAsPdf(int page) => Future.value(null);

  @override
  Future<dynamic> getScanDocumentsUri(int page) => Future.value(null);
}

void main() {
  final FlutterDocScannerPlatform initialPlatform =
      FlutterDocScannerPlatform.instance;

  test('$MethodChannelFlutterDocScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterDocScanner>());
  });

  group('FlutterDocScanner', () {
    late FlutterDocScanner scanner;

    setUp(() {
      scanner = FlutterDocScanner();
      FlutterDocScannerPlatform.instance = MockFlutterDocScannerPlatform();
    });

    test('getPlatformVersion', () async {
      expect(await scanner.getPlatformVersion(), '42');
    });

    test('getScannedDocumentAsImages returns ImageScanResult', () async {
      final result = await scanner.getScannedDocumentAsImages();
      expect(result, isNotNull);
      expect(result, isA<ImageScanResult>());
      expect(result!.images, ['path/to/image1.png']);
      expect(result.count, 1);
    });

    test('getScannedDocumentAsPdf returns PdfScanResult', () async {
      final result = await scanner.getScannedDocumentAsPdf();
      expect(result, isNotNull);
      expect(result, isA<PdfScanResult>());
      expect(result!.pdfUri, 'path/to/doc.pdf');
      expect(result.pageCount, 2);
    });

    test('getScannedDocumentAsImages accepts imageFormat parameter', () async {
      final result = await scanner.getScannedDocumentAsImages(
        imageFormat: ImageFormat.png,
      );
      expect(result, isNotNull);
      expect(result!.images, ['path/to/image1.png']);
    });

    test('page validation rejects zero', () {
      expect(
        () => scanner.getScannedDocumentAsImages(page: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('page validation rejects negative', () {
      expect(
        () => scanner.getScannedDocumentAsPdf(page: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FlutterDocScanner with cancelled scan', () {
    late FlutterDocScanner scanner;

    setUp(() {
      scanner = FlutterDocScanner();
      FlutterDocScannerPlatform.instance = MockCancelledScannerPlatform();
    });

    test('getScannedDocumentAsImages returns null on cancel', () async {
      final result = await scanner.getScannedDocumentAsImages();
      expect(result, isNull);
    });

    test('getScannedDocumentAsPdf returns null on cancel', () async {
      final result = await scanner.getScannedDocumentAsPdf();
      expect(result, isNull);
    });
  });

  group('ImageScanResult.fromPlatformData', () {
    test('parses Map with images key', () {
      final result = ImageScanResult.fromPlatformData({
        'images': ['path1.png', 'path2.png'],
        'count': 2,
      });
      expect(result.images, ['path1.png', 'path2.png']);
      expect(result.count, 2);
    });

    test('parses List directly (iOS format)', () {
      final result =
          ImageScanResult.fromPlatformData(['path1.png', 'path2.png']);
      expect(result.images, ['path1.png', 'path2.png']);
      expect(result.count, 2);
    });

    test('throws FormatException for invalid data', () {
      expect(
        () => ImageScanResult.fromPlatformData(42),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PdfScanResult.fromPlatformData', () {
    test('parses Map with pdfUri (Android format)', () {
      final result = PdfScanResult.fromPlatformData({
        'pdfUri': 'content://doc.pdf',
        'pageCount': 3,
      });
      expect(result.pdfUri, 'content://doc.pdf');
      expect(result.pageCount, 3);
    });

    test('parses String directly (iOS format)', () {
      final result = PdfScanResult.fromPlatformData('/docs/scan.pdf');
      expect(result.pdfUri, '/docs/scan.pdf');
      expect(result.pageCount, 0);
    });

    test('throws FormatException for Map without pdfUri', () {
      expect(
        () => PdfScanResult.fromPlatformData({'pageCount': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for invalid data', () {
      expect(
        () => PdfScanResult.fromPlatformData(42),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
