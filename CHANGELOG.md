## 0.0.17
- **Breaking:** Typed return models (`ImageScanResult`, `PdfScanResult`) for `getScannedDocumentAsImages`, `getScannedDocumentAsPdf`, and `getScanDocumentsUri`. `getScanDocuments` still returns `dynamic` for backward compatibility.
- **Breaking:** Custom `DocScanException` replaces raw `PlatformException` with named error codes.
- **Breaking:** Removed web, macOS, Linux, and Windows platform stubs (they were non-functional).
- Added page parameter validation (must be >= 1).
- **iOS:** Fixed memory leak from retain cycle on `VNDocumentCameraViewController`.
- **iOS:** Added camera permission check before presenting scanner.
- **iOS:** Replaced deprecated `UIApplication.shared.keyWindow` with `connectedScenes` API on iOS 15+.
- **iOS:** Fixed silent file write failures — errors now properly reported instead of returning invalid paths.
- **iOS:** Fixed silent PDF page skip — errors now reported if `PDFPage` creation fails.
- **iOS:** Added file cleanup on partial image save failures.
- **iOS:** Guard against concurrent scan calls.
- **iOS:** Removed legacy commented-out code.
- **Android:** Fixed thread safety with `@Volatile` and `synchronized` on `pendingResult`.
- **Android:** Fixed config change handling — `pendingResult` preserved across device rotation.
- **Android:** Added ProGuard consumer rules for ML Kit classes.
- **Android:** Improved error handling with specific `IntentSender.SendIntentException` catch.
- **Android:** Null-safe parsing of `GmsDocumentScanningResult`.
- **Android:** Error sent to Flutter when activity destroyed during scan (instead of silent hang).
- **Android:** Removed legacy backward-compatible keys (`Uri`/`Count`) from image results.
- Updated Kotlin to 2.1.0.
- Updated podspec with proper metadata and `AVFoundation` framework dependency.
- Expanded test suite from 2 to 22 tests covering typed models, error handling, and cancellation.

## 0.0.16
- Migrated to Flutter 3.29 and fixed error handling in onActivityResult.

## 0.0.15
- Added support for image format and PDF in different methods.

## 0.0.14
- Default page limit set.

## 0.0.13
- Added functionality to set a scan page limit.

## 0.0.12
- Fixed minor bugs.

## 0.0.11
- Temporarily removed web support.
- Fixed minor bugs.

## 0.0.10
- Added Web Support.

## 0.0.9
- Updated the library to Flutter 3.5.4.

## 0.0.8
- Fixed minor bugs.

## 0.0.7
- Updated Android request code to resolve conflicts with other libraries.

## 0.0.6
- Fixed Android minor bugs.

## 0.0.5
- Fixed Ios major bugs.

## 0.0.4
- Fixed Android bugs.

## 0.0.3
- Added support for retrieving document files from a URI.

## 0.0.2
- Added support for retrieving document files from a URI.

## 0.0.1
- Initial release of the `flutter_doc_scanner` plugin.
- Added support for document scanning on Android using ML Kit Document Scanner API.
- Added support for document scanning on iOS using VisionKit.
- Implemented functionality for high-quality document detection, cropping, and processing.
- Supported output formats include PDF.
