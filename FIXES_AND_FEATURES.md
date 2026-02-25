# flutter_doc_scanner v0.0.17 — Fixes & Features

## New Features

### 1. Typed Return Models
Previously all scan methods returned `Future<dynamic>`, forcing consumers to guess the data shape. Now:

- **`getScannedDocumentAsImages()`** returns `Future<ImageScanResult?>` with:
  - `images` — `List<String>` of file paths (iOS) or content URIs (Android)
  - `count` — number of scanned images
- **`getScannedDocumentAsPdf()`** returns `Future<PdfScanResult?>` with:
  - `pdfUri` — file path (iOS) or content URI (Android)
  - `pageCount` — number of pages in the PDF
- **`getScanDocumentsUri()`** returns `Future<ImageScanResult?>` (Android only)
- Both models normalize the different data shapes returned by Android (Map) and iOS (List/String)
- Returns `null` when the user cancels the scan

**Files:** `lib/flutter_doc_scanner_models.dart`, `lib/flutter_doc_scanner.dart`

---

### 2. Custom Exception Type (`DocScanException`)
Replaced raw `PlatformException` and string errors with a structured `DocScanException`:

```dart
try {
  final result = await FlutterDocScanner().getScannedDocumentAsPdf();
} on DocScanException catch (e) {
  print('${e.code}: ${e.message}');
}
```

Error codes:
| Code | When |
|------|------|
| `NO_ACTIVITY` | No foreground activity (Android) |
| `SCAN_IN_PROGRESS` | Another scan already running |
| `SCAN_FAILED` | Generic scan failure |
| `PDF_CREATION_ERROR` | PDF generation failed (iOS) |
| `IMAGE_ENCODING_ERROR` | Image encoding failed (iOS) |
| `FILE_WRITE_ERROR` | Disk write failed (iOS) |
| `PERMISSION_DENIED` | Camera permission denied (iOS) |
| `UNSUPPORTED_PLATFORM` | Feature not available on platform |
| `UNSUPPORTED` | Device doesn't support scanning (iOS) |
| `NO_VIEW_CONTROLLER` | Can't find VC to present scanner (iOS) |

**File:** `lib/flutter_doc_scanner_exception.dart`

---

### 3. Configurable Image Format (iOS)
New `imageFormat` parameter on `getScannedDocumentAsImages()`:

```dart
// JPEG (default) — smaller files, lossy
await scanner.getScannedDocumentAsImages(imageFormat: ImageFormat.jpeg);

// PNG — larger files, lossless
await scanner.getScannedDocumentAsImages(imageFormat: ImageFormat.png);
```

- On iOS: controls actual output format (JPEG at 0.9 quality or PNG lossless)
- On Android: ML Kit always returns JPEG regardless of this setting

**Files:** `lib/flutter_doc_scanner_models.dart` (enum), `ios/Classes/SwiftFlutterDocScannerPlugin.swift`

---

### 4. Page Parameter Validation
All scan methods now validate the `page` parameter:
- Must be >= 1
- Throws `ArgumentError` immediately if invalid (e.g. `page: 0` or `page: -1`)

**File:** `lib/flutter_doc_scanner.dart`

---

### 5. iOS Camera Permission Check
The plugin now checks camera permission before presenting the scanner:
- If permission is `notDetermined`: requests access via system prompt
- If permission is `denied`/`restricted`: returns `PERMISSION_DENIED` error
- If permission is `authorized`: proceeds normally

Previously the scanner was presented without any permission check, causing undefined behavior if camera access was denied.

**File:** `ios/Classes/SwiftFlutterDocScannerPlugin.swift`

---

### 6. Expanded Test Suite
Grew from **2 tests** to **23 tests** covering:
- Typed model parsing (Android Map format, iOS List/String format)
- Page validation (zero, negative values)
- Scan cancellation (null returns)
- Error wrapping (PlatformException → DocScanException)
- ImageFormat parameter passing
- Method channel communication
- FormatException for invalid data shapes

**Files:** `test/flutter_doc_scanner_test.dart`, `test/flutter_doc_scanner_method_channel_test.dart`

---

## Bug Fixes

### iOS

#### 7. Fixed Memory Leak — Retain Cycle
**Problem:** `presentingController` (strong) held a reference to the plugin via its `delegate`, and the plugin held a strong reference back. Neither could be deallocated.
**Fix:** Changed `presentingController` to `weak var`. The view controller is owned by UIKit's presentation stack, not the plugin.

#### 8. Fixed Silent File Write Failures
**Problem:** `try? page.pngData()?.write(to: url)` silently swallowed errors. If disk write failed, invalid file paths were returned to Flutter.
**Fix:** Replaced `try?` with proper `do/catch`. On failure, returns `FILE_WRITE_ERROR` or `IMAGE_ENCODING_ERROR` and cleans up any partially-written files.

#### 9. Fixed Silent PDF Page Skip
**Problem:** If `PDFPage(image:)` returned nil for a page, that page was silently omitted from the PDF.
**Fix:** Now returns `PDF_CREATION_ERROR` immediately if any page fails to convert.

#### 10. Fixed Deprecated `keyWindow` API
**Problem:** `UIApplication.shared.keyWindow` is deprecated since iOS 13 and broken on iPadOS multi-window.
**Fix:** Uses `connectedScenes` API on iOS 15+, falls back to `keyWindow` on iOS 13-14.

#### 11. Fixed Force Unwrapping / Missing Nil Guard
**Problem:** `presentedVC?.present(self.presentingController!, ...)` — if `presentedVC` was nil, presentation silently failed and `resultChannel` was never called (Flutter caller hangs forever).
**Fix:** Added `guard let rootVC` with proper error return (`NO_VIEW_CONTROLLER`).

#### 12. Fixed Race Condition on Concurrent Scans
**Problem:** Instance properties (`resultChannel`, `currentMethod`, etc.) on the singleton could be overwritten by concurrent method calls.
**Fix:** Added `isScanInProgress` flag. Second scan call returns `SCAN_IN_PROGRESS` error.

#### 13. Fixed Dismiss/FileIO Race Condition
**Problem:** `dismiss(animated:)` was called before file I/O completed in the delegate callback.
**Fix:** File saving now happens inside the `dismiss` completion handler.

#### 14. Removed Legacy Commented-Out Code
Removed ~60 lines of commented-out legacy implementation (lines 116-178).

---

### Android

#### 15. Fixed Thread Safety on `pendingResult`
**Problem:** `pendingResult` was checked and set without synchronization. Two concurrent method calls could both pass the null check before either sets it.
**Fix:** Added `@Volatile` annotation and `synchronized(this)` blocks around all `pendingResult` access.

#### 16. Fixed Config Change State Loss
**Problem:** `onDetachedFromActivityForConfigChanges()` called `onDetachedFromActivity()` which cleared `pendingResult`. Device rotation during a scan caused the Flutter caller to hang forever.
**Fix:** `onDetachedFromActivityForConfigChanges()` now only clears `activityBinding` and `activity`, preserving `pendingResult` so the scan can complete after reattachment.

#### 17. Fixed Silent Hang on Activity Destruction
**Problem:** `onDetachedFromActivity()` set `pendingResult = null` without sending any response. The Flutter caller would hang indefinitely.
**Fix:** Now sends `NO_ACTIVITY` error to `pendingResult` before clearing it.

#### 18. Improved Error Specificity
**Problem:** `finishWithError` only accepted a message string, always using `SCAN_FAILED` code.
**Fix:** Now accepts a `code` parameter. Added specific `IntentSender.SendIntentException` catch. Null-safe parsing of `GmsDocumentScanningResult` with explicit error if null.

#### 19. Added ProGuard Consumer Rules
**Problem:** No ProGuard/R8 rules existed. ML Kit classes could be obfuscated in release builds, causing runtime crashes.
**Fix:** Added `consumer-rules.pro` with keep rules for `com.google.mlkit.vision.documentscanner.**` and referenced it in `build.gradle`.

#### 20. Removed Legacy Backward-Compatible Keys
**Problem:** Image results returned duplicate keys: `images`/`count` (new) and `Uri`/`Count` (legacy).
**Fix:** Removed `Uri` and `Count` keys. Only `images` and `count` are returned.

---

## Configuration Changes

### 21. Removed Non-Functional Platform Stubs
**Problem:** `pubspec.yaml` registered web, macOS, Linux, and Windows platforms, but none had working implementations. Web returned `navigator.userAgent` instead of scan results.
**Fix:** Removed all non-functional platform registrations. Only Android and iOS are registered. Deleted `flutter_doc_scanner_web.dart` and `flutter_doc_scanner_platform_check.dart` (dead code).

### 22. Removed `flutter_web_plugins` Dependency
No longer needed after removing the broken web platform.

### 23. Updated Podspec Metadata
**Problem:** Podspec had placeholder values: version `0.0.1`, description "A new Flutter project", homepage `http://example.com`.
**Fix:** Updated to version `0.0.17`, proper description, real GitHub homepage. Added `AVFoundation` framework dependency (needed for camera permission check).

### 24. Updated Kotlin to 2.1.0
**Problem:** Kotlin 2.0.21 triggered Flutter deprecation warning.
**Fix:** Updated to 2.1.0 in both `android/build.gradle` and `example/android/settings.gradle`.

---

## Summary

| Category | Count |
|----------|-------|
| New features | 6 |
| iOS bug fixes | 8 |
| Android bug fixes | 6 |
| Config/cleanup | 4 |
| **Total changes** | **24** |
| Tests before | 2 |
| Tests after | 23 |
| Files created | 3 (`flutter_doc_scanner_models.dart`, `flutter_doc_scanner_exception.dart`, `consumer-rules.pro`) |
| Files deleted | 2 (`flutter_doc_scanner_web.dart`, `flutter_doc_scanner_platform_check.dart`) |
| Files modified | 10 |
