/// Image format for scanned document images.
///
/// On Android, ML Kit always returns JPEG regardless of this setting.
/// On iOS, this controls whether images are saved as PNG or JPEG.
enum ImageFormat {
  /// PNG format. Lossless, larger file size. Default on iOS.
  png,

  /// JPEG format. Lossy, smaller file size. Default on Android.
  jpeg,
}

/// Result from scanning documents as images.
class ImageScanResult {
  /// List of file paths (iOS) or content URIs (Android) for the scanned images.
  final List<String> images;

  /// Number of scanned images.
  int get count => images.length;

  const ImageScanResult({required this.images});

  /// Creates an [ImageScanResult] from the raw platform channel data.
  ///
  /// On Android, the data is a Map with 'images' key.
  /// On iOS, the data is a List of file paths.
  factory ImageScanResult.fromPlatformData(dynamic data) {
    if (data is Map) {
      final images = (data['images'] as List?)?.cast<String>() ?? [];
      return ImageScanResult(images: images);
    }
    if (data is List) {
      return ImageScanResult(images: data.cast<String>());
    }
    throw FormatException(
      'Unexpected image scan result type: ${data.runtimeType}',
    );
  }

  @override
  String toString() => 'ImageScanResult(images: $images, count: $count)';
}

/// Result from scanning documents as a PDF.
class PdfScanResult {
  /// File path (iOS) or content URI (Android) of the generated PDF.
  final String pdfUri;

  /// Number of pages in the PDF. Only available on Android; defaults to 0 on iOS.
  final int pageCount;

  const PdfScanResult({required this.pdfUri, this.pageCount = 0});

  /// Creates a [PdfScanResult] from the raw platform channel data.
  ///
  /// On Android, the data is a Map with 'pdfUri' and 'pageCount' keys.
  /// On iOS, the data is a String file path.
  factory PdfScanResult.fromPlatformData(dynamic data) {
    if (data is Map) {
      final uri = data['pdfUri'] as String?;
      if (uri == null) {
        throw const FormatException('Missing pdfUri in PDF scan result');
      }
      return PdfScanResult(
        pdfUri: uri,
        pageCount: (data['pageCount'] as int?) ?? 0,
      );
    }
    if (data is String) {
      return PdfScanResult(pdfUri: data);
    }
    throw FormatException(
      'Unexpected PDF scan result type: ${data.runtimeType}',
    );
  }

  @override
  String toString() => 'PdfScanResult(pdfUri: $pdfUri, pageCount: $pageCount)';
}
