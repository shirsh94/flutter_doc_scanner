class DocumentScanResult {
  final String? pdfUri;
  final int? pageCount;
  final List<String>? pageUris;

  DocumentScanResult({
    this.pdfUri,
    this.pageCount,
    this.pageUris,
  });

  factory DocumentScanResult.fromMap(Map<String, dynamic> map) {
    return DocumentScanResult(
      pdfUri: map['pdfUri'] as String?,
      pageCount: map['pageCount'] as int?,
      pageUris: map['Uri'] != null ? (map['Uri'] as String).split(', ') : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pdfUri': pdfUri,
      'pageCount': pageCount,
      'Uri': pageUris?.join(', '),
    };
  }

  @override
  String toString() {
    return 'DocumentScanResult(pdfUri: $pdfUri, pageCount: $pageCount, pageUris: $pageUris)';
  }
}
