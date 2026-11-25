import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

void main() {
  runApp(
    MaterialApp(
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  dynamic _scannedDocuments;

  Future<void> scanDocument() async {
    dynamic scannedDocuments;
    try {
      scannedDocuments = await FlutterDocScanner().getScanDocuments(page: 4) ??
          'Unknown platform documents';
    } on PlatformException {
      scannedDocuments = 'Failed to get scanned documents.';
    }
    print(scannedDocuments.toString());
    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  Future<void> scanDocumentAsImages() async {
    dynamic scannedDocuments;
    try {
      scannedDocuments =
          await FlutterDocScanner().getScannedDocumentAsImages(page: 4) ??
              'Unknown platform documents';
    } on PlatformException {
      scannedDocuments = 'Failed to get scanned documents.';
    }
    print(scannedDocuments.toString());
    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  Future<void> scanDocumentAsPdf() async {
    dynamic scannedDocuments;
    try {
      scannedDocuments =
          await FlutterDocScanner().getScannedDocumentAsPdf(page: 4) ??
              'Unknown platform documents';
    } on PlatformException {
      scannedDocuments = 'Failed to get scanned documents.';
    }
    print(scannedDocuments.toString());
    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  Future<void> scanDocumentAsCompressedPdf() async {
    dynamic scannedDocuments;
    try {
      scannedDocuments = await FlutterDocScanner().getScannedDocumentAsPdf(
            page: 4,
            compression: const DocScanCompression(
              quality: 0.7,
              maxDimension: 2500,
            ),
          ) ??
          'Unknown platform documents';
    } on DocScanException catch (e) {
      scannedDocuments = 'Failed to get scanned documents: ${e.message}';
    }
    print(scannedDocuments.toString());
    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  Future<void> scanDocumentUri() async {
    //This Feature only supported for Android.
    dynamic scannedDocuments;
    try {
      scannedDocuments =
          await FlutterDocScanner().getScanDocumentsUri(page: 4) ??
              'Unknown platform documents';
    } on PlatformException {
      scannedDocuments = 'Failed to get scanned documents.';
    }
    print(scannedDocuments.toString());
    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner Example',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Document Scanner example app'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _scannedDocuments != null
                    ? Text(_scannedDocuments.toString())
                    : const Text("No Documents Scanned"),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    scanDocument();
                  },
                  child: const Text("Scan Documents"),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    scanDocumentAsImages();
                  },
                  child: const Text("Scan Documents As Images"),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    scanDocumentAsPdf();
                  },
                  child: const Text("Scan Documents As PDF"),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    scanDocumentAsCompressedPdf();
                  },
                  child: const Text("Scan Documents As Compressed PDF"),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    scanDocumentUri();
                  },
                  child: const Text("Get Scan Documents URI"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
