// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'flutter_doc_scanner_platform_interface.dart';
import 'dart:html' as html;
import 'package:flutter/material.dart';
/// A web implementation of the FlutterDocScannerPlatform of the FlutterDocScanner plugin.
class FlutterDocScannerWeb extends FlutterDocScannerPlatform {
  /// Constructs a FlutterDocScannerWeb
  FlutterDocScannerWeb();

  static void registerWith(Registrar registrar) {
    FlutterDocScannerPlatform.instance = FlutterDocScannerWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = html.window.navigator.userAgent;
    return version;
  }

  @override
  Future<String?> getScanDocuments() async {
    final data = html.window.navigator.userAgent;
    return data;
  }

  @override
  Future<String?> getScanDocumentsUri() async {
    final data = html.window.navigator.userAgent;
    return data;
  }
}

class DocumentScannerPage extends StatefulWidget {
  final String appBarTitle;
  final String captureButtonText;
  final String cropButtonText;
  final String cropPdfButtonText;
  final double width;
  final double height;

  DocumentScannerPage({
    required this.appBarTitle,
    required this.captureButtonText,
    required this.cropButtonText,
    required this.cropPdfButtonText,
    required this.width,
    required this.height,
  });

  @override
  _DocumentScannerPageState createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  String? _imageUrl;
  String? _pdfUrl;
  double top = 100;
  double left = 50;
  double cropWidth = 200;
  double cropHeight = 200;

  void _captureImage() {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      final reader = html.FileReader();
      reader.readAsDataUrl(files[0]);

      reader.onLoadEnd.listen((event) {
        setState(() {
          _imageUrl = reader.result as String;
          _pdfUrl = null; // Reset PDF URL when a new image is picked
        });
      });
    });
  }

  void _cropImage() {
    if (_imageUrl == null) return;

    final canvas = html.CanvasElement();
    final img = html.ImageElement(src: _imageUrl!);

    img.onLoad.listen((event) {
      canvas.width = cropWidth.toInt();
      canvas.height = cropHeight.toInt();

      final ctx = canvas.context2D;
      ctx.drawImageScaledFromSource(
        img,
        left,
        top,
        cropWidth,
        cropHeight,
        0,
        0,
        cropWidth,
        cropHeight,
      );

      final croppedImageUrl = canvas.toDataUrl();
      Navigator.of(context).pop(croppedImageUrl);
    });
  }

  void _convertToPDF() {
    if (_imageUrl == null) return;

    final canvas = html.CanvasElement(width: 595, height: 842); // A4 size in points
    final img = html.ImageElement(src: _imageUrl!);

    img.onLoad.listen((event) {
      final ctx = canvas.context2D;
      ctx.drawImageScaled(img, 0, 0, 595, 842); // Scale the image to fit A4

      final pdfBlob = html.Blob([canvas.toDataUrl()], 'application/pdf');
      final pdfUrl = html.Url.createObjectUrl(pdfBlob);
      _pdfUrl = pdfUrl; // Set the generated PDF URL
      Navigator.of(context).pop(_pdfUrl); // Return the PDF URL
    });
  }

  @override
  void initState() {
    super.initState();
    _captureImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_imageUrl == null)
                ElevatedButton(
                  onPressed: _captureImage,
                  child: Text(widget.captureButtonText),
                )
              else
                Stack(
                  children: [
                    Image.network(
                      _imageUrl!,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      top: top,
                      left: left,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            left += details.delta.dx;
                            top += details.delta.dy;
                          });
                        },
                        child: Container(
                          width: cropWidth,
                          height: cropHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -10,
                                left: -10,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      cropWidth -= details.delta.dx;
                                      cropHeight -= details.delta.dy;
                                      left += details.delta.dx;
                                      top += details.delta.dy;
                                    });
                                  },
                                  child: _buildHandle(),
                                ),
                              ),
                              Positioned(
                                top: -10,
                                right: -10,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      cropWidth += details.delta.dx;
                                      cropHeight -= details.delta.dy;
                                      top += details.delta.dy;
                                    });
                                  },
                                  child: _buildHandle(),
                                ),
                              ),
                              Positioned(
                                bottom: -10,
                                left: -10,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      cropWidth -= details.delta.dx;
                                      cropHeight += details.delta.dy;
                                      left += details.delta.dx;
                                    });
                                  },
                                  child: _buildHandle(),
                                ),
                              ),
                              Positioned(
                                bottom: -10,
                                right: -10,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      cropWidth += details.delta.dx;
                                      cropHeight += details.delta.dy;
                                    });
                                  },
                                  child: _buildHandle(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_imageUrl != null) ...[
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   ElevatedButton(
                     onPressed: _cropImage,
                     child: Text(widget.cropButtonText),
                   ),
                   SizedBox(width: 10,),
                   ElevatedButton(
                     onPressed: _convertToPDF,
                     child: Text(widget.cropPdfButtonText),
                   ),
                 ],
               )
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}



