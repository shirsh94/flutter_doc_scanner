import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  dynamic _scannedDocuments;
  @override
  void initState() {
    super.initState();
  }

  Future<void> scanDocument() async {
    dynamic scannedDocuments;
    try {
      scannedDocuments = await FlutterDocScanner().getScanDocuments() ??
          'Unknown platform documents';
    } on PlatformException {
      scannedDocuments = 'Failed to get scanned documents.';
    }
    // print(scannedDocuments.toString());
    if (!mounted) return;
    setState(() {
      _scannedDocuments = scannedDocuments;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Document Scanner example app'),
        ),
        body: Center(
          child: Column(
            children: [
              _scannedDocuments != null
                  ? Text(_scannedDocuments.toString())
                  : const Text("No Documents Scanned"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            scanDocument();
          },
          child: const Text("Scan Documents"),
        ),
      ),
    );
  }
}
