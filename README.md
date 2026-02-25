# flutter_doc_scanner

A Flutter plugin for document scanning on Android and iOS using ML Kit Document Scanner API and VisionKit.

[![pub package](https://img.shields.io/pub/v/flutter_doc_scanner.svg)](https://pub.dev/packages/flutter_doc_scanner)

## Example

Check out the `example` directory for a sample Flutter app using `flutter_doc_scanner`.

## Document Scanner Demo
<p align="center">
	<img src="https://github.com/shirsh94/flutter_doc_scanner/blob/main/demo/doc_scan_demo.gif?raw=true" width="200"  />
</p>

## Screenshots
| ![Screenshot 1](https://raw.githubusercontent.com/shirsh94/flutter_doc_scanner/main/demo/screen_shot_1.jpg?raw=true) | ![Screenshot 2](https://raw.githubusercontent.com/shirsh94/flutter_doc_scanner/main/demo/screen_shot_2.jpg?raw=true) | ![Screenshot 3](https://raw.githubusercontent.com/shirsh94/flutter_doc_scanner/main/demo/screen_shot_3.jpg?raw=true) |
|----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| ![Screenshot 4](https://raw.githubusercontent.com/shirsh94/flutter_doc_scanner/main/demo/screen_shot_4.jpg?raw=true) | ![Screenshot 5](https://raw.githubusercontent.com/shirsh94/flutter_doc_scanner/main/demo/screen_shot_5.jpg?raw=true) | ![Screenshot 6](https://raw.githubusercontent.com/shirsh94/flutter_doc_scanner/main/demo/screen_shot_6.jpg?raw=true) |


## Features

- High-quality and consistent user interface for digitizing physical documents.
- Accurate document detection with precise corner and edge detection for optimal scanning results.
- Flexible functionality allows users to crop scanned documents, apply filters, remove fingers, remove stains and other blemishes.
- On-device processing helps preserve privacy.
- Support for sending digitized files in PDF and JPEG formats back to your app.
- Ability to set a scan page limit.
- **Typed return models** (`ImageScanResult`, `PdfScanResult`) for type-safe result handling.
- **Custom exceptions** (`DocScanException`) with error codes for proper error handling.
- **Configurable image format** (`ImageFormat.jpeg` or `ImageFormat.png`) on iOS.
- **Configurable JPEG quality** (0.0–1.0) for iOS image compression control.
- Camera permission checks on iOS before presenting the scanner.


## Installation

To use this plugin, add `flutter_doc_scanner` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_doc_scanner: ^0.0.17
```

## Usage

### Scan documents (default behavior)

Returns PDF on Android, images (PNG) on iOS:

```dart
Future<void> scanDocument() async {
  try {
    final scannedDocuments = await FlutterDocScanner().getScanDocuments(page: 3);
    print(scannedDocuments.toString());
  } on DocScanException catch (e) {
    print('Scan failed: ${e.code} - ${e.message}');
  }
}
```

### Scan as images (typed result)

Returns an `ImageScanResult` with a list of file paths/URIs:

```dart
Future<void> scanAsImages() async {
  try {
    final result = await FlutterDocScanner().getScannedDocumentAsImages(
      page: 4,
      imageFormat: ImageFormat.jpeg, // or ImageFormat.png
    );
    if (result == null) {
      print('User cancelled');
      return;
    }
    print('Scanned ${result.count} images');
    for (final path in result.images) {
      print('Image: $path');
    }
  } on DocScanException catch (e) {
    print('Scan failed: ${e.code} - ${e.message}');
  }
}
```

### Scan as PDF (typed result)

Returns a `PdfScanResult` with the PDF file path/URI:

```dart
Future<void> scanAsPdf() async {
  try {
    final result = await FlutterDocScanner().getScannedDocumentAsPdf(page: 4);
    if (result == null) {
      print('User cancelled');
      return;
    }
    print('PDF: ${result.pdfUri} (${result.pageCount} pages)');
  } on DocScanException catch (e) {
    print('Scan failed: ${e.code} - ${e.message}');
  }
}
```

### Scan document URIs (Android only)

Returns an `ImageScanResult`. Throws `DocScanException` on non-Android platforms:

```dart
Future<void> scanDocumentUri() async {
  try {
    final result = await FlutterDocScanner().getScanDocumentsUri(page: 4);
    if (result == null) {
      print('User cancelled');
      return;
    }
    print('URIs: ${result.images}');
  } on DocScanException catch (e) {
    print('Error: ${e.code} - ${e.message}');
  }
}
```

### Error handling

All scan methods throw `DocScanException` on failure. Error codes include:

| Code | Description |
|------|-------------|
| `NO_ACTIVITY` | No foreground activity available (Android) |
| `SCAN_IN_PROGRESS` | Another scan is already running |
| `SCAN_FAILED` | The scan operation failed |
| `PDF_CREATION_ERROR` | Failed to create PDF (iOS) |
| `PERMISSION_DENIED` | Camera permission was denied (iOS) |
| `UNSUPPORTED_PLATFORM` | Feature not supported on this platform |

Methods return `null` when the user cancels the scan.

### Image format

The `getScannedDocumentAsImages` method accepts an optional `imageFormat` parameter:

| Platform | `ImageFormat.jpeg` | `ImageFormat.png` |
|----------|-------------------|-------------------|
| **Android** | JPEG (always, ML Kit default) | JPEG (ML Kit always returns JPEG) |
| **iOS** | JPEG (configurable quality) | PNG (lossless) |

Default is `ImageFormat.jpeg`. On Android, ML Kit always returns JPEG regardless of this setting. On iOS, this controls the actual output format.

### JPEG quality (iOS only)

When using `ImageFormat.jpeg`, you can control the compression quality on iOS with the `quality` parameter (0.0 to 1.0):

```dart
final result = await FlutterDocScanner().getScannedDocumentAsImages(
  imageFormat: ImageFormat.jpeg,
  quality: 0.7, // lower = smaller file, more compression
);
```

Default is `0.9`. This parameter is ignored on Android (ML Kit controls quality) and when using `ImageFormat.png`.


## Project Setup
Follow the steps below to set up your Flutter project on Android and iOS.

### Android

#### Minimum Version Configuration
Ensure you meet the minimum version requirements to run the application on Android devices.
In the `android/app/build.gradle` file, verify that `minSdkVersion` is at least 21. This setting specifies the minimum Android API level required to run your app, ensuring compatibility with a wide range of Android devices.

```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 21
        ...
    }
    ...
}
```

#### Google Play Services Requirement
This plugin uses [ML Kit Document Scanner](https://developers.google.com/ml-kit/vision/doc-scanner), which requires **Google Play Services** to be installed on the device. It will not work on devices without Google Play (e.g. Huawei devices with HMS, Amazon Fire tablets, custom ROMs without GApps). If Google Play Services are unavailable, the scanner will fail with a `SCAN_FAILED` error.

### iOS
#### Minimum Version Configuration
Ensure you meet the minimum version requirements to run the application on iOS devices.
In the `ios/Podfile` file, make sure the iOS platform version is at least 13.0. This setting specifies the minimum iOS version required to run your app, ensuring compatibility with a wide range of iOS devices.

```ruby
platform :ios, '13.0'
```

#### Permission Configuration
Add a String property to the app's Info.plist file with the key `NSCameraUsageDescription` and the value as the description for why your app needs camera access. This step is required by Apple to explain to users why the app needs access to the camera, and it's crucial for App Store approval.

```xml
<key>NSCameraUsageDescription</key>
<string>Camera Permission Description</string>
```

### Web
Currently, we have removed web support for this library. For document scanning on the web, you can use the following library: [flutter_doc_scanner_web](https://pub.dev/packages/flutter_doc_scanner_web).

## Issues and Feedback

Please file [issues](https://github.com/shirsh94/flutter_doc_scanner/issues) to send feedback or report a bug. Thank you!

## License

The MIT License (MIT) Copyright (c) 2024 Shirsh Shukla

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
