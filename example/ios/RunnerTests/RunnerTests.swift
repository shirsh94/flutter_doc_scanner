import Flutter
import PDFKit
import UIKit
import XCTest

@testable import flutter_doc_scanner

// Unit tests of the Swift portion of this plugin. Run them from Xcode (Runner workspace,
// RunnerTests target) or with `xcodebuild test` after `flutter build ios --config-only`.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testUnknownMethodIsNotImplemented() {
    let plugin = SwiftFlutterDocScannerPlugin()
    let call = FlutterMethodCall(methodName: "noSuchMethod", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue((result as AnyObject) === FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}

// MARK: - Test helpers

/// A noisy page of exactly `width` × `height` pixels, so JPEG quality visibly changes the size.
private func scannedPage(width: Int, height: Int, scale: CGFloat = 1) -> UIImage {
  let format = UIGraphicsImageRendererFormat.default()
  format.scale = scale
  format.opaque = true
  let size = CGSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale)
  var generator = SystemRandomNumberGenerator()
  return UIGraphicsImageRenderer(size: size, format: format).image { context in
    UIColor.white.setFill()
    context.fill(CGRect(origin: .zero, size: size))
    for _ in 0..<3000 {
      UIColor(
        red: .random(in: 0...1, using: &generator),
        green: .random(in: 0...1, using: &generator),
        blue: .random(in: 0...1, using: &generator),
        alpha: 1
      ).setFill()
      let x = CGFloat.random(in: 0..<size.width, using: &generator)
      let y = CGFloat.random(in: 0..<size.height, using: &generator)
      context.fill(CGRect(x: x, y: y, width: 6, height: 6))
    }
  }
}

/// A JPEG reduced to its markers: start of image, an APP0 segment, a baseline frame header
/// with `components` colour components, end of image. Enough for the header reader and the
/// PDF dictionary.
private func jpegHeader(width: Int, height: Int, components: Int) -> Data {
  var bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00]
  bytes += [0xFF, 0xC0, 0x00, UInt8(8 + components * 3), 0x08,
            UInt8(height >> 8), UInt8(height & 0xFF), UInt8(width >> 8), UInt8(width & 0xFF),
            UInt8(components)]
  for component in 0..<components { bytes += [UInt8(component + 1), 0x11, 0x00] }
  bytes += [0xFF, 0xD9]
  return Data(bytes)
}

// MARK: - PdfCompression

class PdfCompressionTests: XCTestCase {

  func testWithoutCompressionArgumentIsNil() {
    XCTAssertNil(PdfCompression(arguments: nil))
    XCTAssertNil(PdfCompression(arguments: ["page": 4]))
  }

  func testReadsQualityAndMaxDimension() {
    let compression = PdfCompression(arguments: [
      "page": 5, "compression": ["quality": 0.7, "maxDimension": 2500],
    ])
    XCTAssertEqual(compression, PdfCompression(quality: 0.7, maxDimension: 2500))
  }

  func testDefaultsMissingQualityAndIgnoresInvalidMaxDimension() {
    let compression = PdfCompression(arguments: ["compression": ["maxDimension": 0]])
    XCTAssertEqual(compression, PdfCompression(quality: PdfCompression.defaultQuality, maxDimension: nil))
  }

  func testClampsQualityIntoRange() {
    XCTAssertEqual(PdfCompression(arguments: ["compression": ["quality": 3.0]])?.quality, 1)
    XCTAssertEqual(PdfCompression(arguments: ["compression": ["quality": -1]])?.quality, 0)
  }

  func testTargetSizeWithoutLimitKeepsSize() {
    let compression = PdfCompression(quality: 0.8, maxDimension: nil)
    XCTAssertEqual(compression.targetPixelSize(for: CGSize(width: 3000, height: 4000)), CGSize(width: 3000, height: 4000))
  }

  func testTargetSizeScalesLongestEdgeAndKeepsAspectRatio() {
    let compression = PdfCompression(quality: 0.8, maxDimension: 2500)
    XCTAssertEqual(compression.targetPixelSize(for: CGSize(width: 3000, height: 4000)), CGSize(width: 1875, height: 2500))
    XCTAssertEqual(compression.targetPixelSize(for: CGSize(width: 4000, height: 3000)), CGSize(width: 2500, height: 1875))
  }

  func testTargetSizeNeverScalesUp() {
    let compression = PdfCompression(quality: 0.8, maxDimension: 2500)
    XCTAssertEqual(compression.targetPixelSize(for: CGSize(width: 800, height: 600)), CGSize(width: 800, height: 600))
  }

  func testTargetSizeKeepsAtLeastOnePixel() {
    let compression = PdfCompression(quality: 0.8, maxDimension: 100)
    XCTAssertEqual(compression.targetPixelSize(for: CGSize(width: 10, height: 10000)), CGSize(width: 1, height: 100))
  }
}

// MARK: - JpegPdfWriter

class JpegPdfWriterTests: XCTestCase {

  func testJpegInfoReadsSizeAndComponents() throws {
    let jpeg = try XCTUnwrap(scannedPage(width: 320, height: 240).jpegData(compressionQuality: 0.9))
    XCTAssertEqual(try JpegInfo.read(jpeg), JpegInfo(width: 320, height: 240, components: 3))
    XCTAssertEqual(try JpegInfo.read(jpegHeader(width: 50, height: 70, components: 1)),
                   JpegInfo(width: 50, height: 70, components: 1))
    XCTAssertEqual(try JpegInfo.read(jpegHeader(width: 3000, height: 4000, components: 3)),
                   JpegInfo(width: 3000, height: 4000, components: 3))
  }

  func testJpegInfoRejectsNonJpegData() {
    XCTAssertThrowsError(try JpegInfo.read(Data([0x89, 0x50, 0x4E, 0x47]))) { error in
      XCTAssertEqual(error as? JpegInfo.ReadError, .notAJpeg)
    }
    XCTAssertThrowsError(try JpegInfo.read(Data([0xFF, 0xD8, 0xFF, 0xD9])))
  }

  func testWritesOnePagePerJpegWithTheGivenPageSizes() throws {
    let pages = [
      JpegPdfPage(jpeg: try XCTUnwrap(scannedPage(width: 300, height: 400).jpegData(compressionQuality: 0.8)),
                  pageSize: CGSize(width: 3000, height: 4000)),
      JpegPdfPage(jpeg: try XCTUnwrap(scannedPage(width: 400, height: 300).jpegData(compressionQuality: 0.8)),
                  pageSize: CGSize(width: 4000, height: 3000)),
      JpegPdfPage(jpeg: try XCTUnwrap(scannedPage(width: 100, height: 100).jpegData(compressionQuality: 0.8)),
                  pageSize: CGSize(width: 595.5, height: 842.25)),
    ]

    let document = try XCTUnwrap(PDFDocument(data: try JpegPdfWriter.write(pages)))

    XCTAssertEqual(document.pageCount, 3)
    XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, CGSize(width: 3000, height: 4000))
    XCTAssertEqual(document.page(at: 1)?.bounds(for: .mediaBox).size, CGSize(width: 4000, height: 3000))
    XCTAssertEqual(document.page(at: 2)?.bounds(for: .mediaBox).size, CGSize(width: 595.5, height: 842.25))
  }

  func testEmbedsTheJpegBytesUnchanged() throws {
    let jpeg = try XCTUnwrap(scannedPage(width: 300, height: 400).jpegData(compressionQuality: 0.8))
    let pdf = try JpegPdfWriter.write([JpegPdfPage(jpeg: jpeg, pageSize: CGSize(width: 300, height: 400))])

    XCTAssertNotNil(pdf.range(of: jpeg), "the JPEG must appear byte for byte")
    let text = String(decoding: pdf, as: UTF8.self)
    XCTAssertTrue(text.contains("/Width 300 /Height 400 /ColorSpace /DeviceRGB"))
    XCTAssertTrue(text.contains("/Filter /DCTDecode /Length \(jpeg.count)"))
  }

  func testMarksGrayscaleJpegsAsDeviceGray() throws {
    let pdf = try JpegPdfWriter.write([
      JpegPdfPage(jpeg: jpegHeader(width: 60, height: 80, components: 1), pageSize: CGSize(width: 60, height: 80)),
    ])
    XCTAssertTrue(String(decoding: pdf, as: UTF8.self).contains("/ColorSpace /DeviceGray"))
  }

  func testHasAValidCrossReferenceTable() throws {
    let jpeg = try XCTUnwrap(scannedPage(width: 10, height: 10).jpegData(compressionQuality: 0.8))
    let pdf = try JpegPdfWriter.write([JpegPdfPage(jpeg: jpeg, pageSize: CGSize(width: 10, height: 10))])
    let bytes = [UInt8](pdf)
    func text(at offset: Int, length: Int) -> String {
      String(decoding: bytes[offset..<min(offset + length, bytes.count)], as: UTF8.self)
    }

    let tail = String(decoding: bytes.suffix(64), as: UTF8.self)
    let startXref = try XCTUnwrap(Int(tail.components(separatedBy: "startxref\n")[1].components(separatedBy: "\n")[0]))
    XCTAssertEqual(text(at: startXref, length: 5), "xref\n")

    // Every in-use entry must point at "<n> 0 obj".
    let entries = text(at: startXref, length: bytes.count - startXref)
      .components(separatedBy: "\n").dropFirst(3).prefix { $0.hasSuffix(" n ") }
    XCTAssertEqual(entries.count, 5)
    for (index, entry) in entries.enumerated() {
      let offset = try XCTUnwrap(Int(entry.prefix(10)))
      XCTAssertEqual(text(at: offset, length: "\(index + 1) 0 obj".count), "\(index + 1) 0 obj")
    }
  }

  func testRejectsEmptyDocumentsAndInvalidInput() throws {
    XCTAssertThrowsError(try JpegPdfWriter.write([])) { error in
      XCTAssertEqual(error as? JpegPdfWriter.WriteError, .noPages)
    }
    let jpeg = try XCTUnwrap(scannedPage(width: 10, height: 10).jpegData(compressionQuality: 0.8))
    XCTAssertThrowsError(try JpegPdfWriter.write([JpegPdfPage(jpeg: jpeg, pageSize: CGSize(width: 0, height: 10))])) { error in
      XCTAssertEqual(error as? JpegPdfWriter.WriteError, .invalidPageSize)
    }
    XCTAssertThrowsError(try JpegPdfWriter.write([
      JpegPdfPage(jpeg: jpegHeader(width: 10, height: 10, components: 2), pageSize: CGSize(width: 10, height: 10)),
    ])) { error in
      XCTAssertEqual(error as? JpegPdfWriter.WriteError, .unsupportedComponents(2))
    }
  }
}

// MARK: - CompressedPdfBuilder

class CompressedPdfBuilderTests: XCTestCase {

  func testScalesToMaxDimensionAndKeepsTheOriginalPageSize() throws {
    let page = try CompressedPdfBuilder.compressPage(
      scannedPage(width: 1200, height: 1600), compression: PdfCompression(quality: 0.7, maxDimension: 800))

    XCTAssertEqual(try JpegInfo.read(page.jpeg), JpegInfo(width: 600, height: 800, components: 3))
    XCTAssertEqual(page.pageSize, CGSize(width: 1200, height: 1600))
  }

  func testCountsPixelsNotPointsForRetinaImages() throws {
    // 1200 × 1600 pixels at scale 2 is 600 × 800 points.
    let page = try CompressedPdfBuilder.compressPage(
      scannedPage(width: 1200, height: 1600, scale: 2), compression: PdfCompression(quality: 0.7, maxDimension: 800))

    XCTAssertEqual(try JpegInfo.read(page.jpeg), JpegInfo(width: 600, height: 800, components: 3))
    XCTAssertEqual(page.pageSize, CGSize(width: 600, height: 800))
  }

  func testTurnsAPageThatIsNotUprightEvenWithoutResizing() throws {
    // 200 × 100 pixels stored sideways: displayed as 100 × 200.
    let stored = try XCTUnwrap(scannedPage(width: 200, height: 100).cgImage)
    let sideways = UIImage(cgImage: stored, scale: 1, orientation: .right)

    let page = try CompressedPdfBuilder.compressPage(sideways, compression: PdfCompression(quality: 0.7, maxDimension: nil))

    // The pixels are turned, not just tagged: PDF viewers ignore the JPEG orientation tag.
    XCTAssertEqual(try JpegInfo.read(page.jpeg), JpegInfo(width: 100, height: 200, components: 3))
    XCTAssertEqual(page.pageSize, CGSize(width: 100, height: 200))
  }

  func testRedrawsInSRGB() throws {
    let resized = CompressedPdfBuilder.resized(scannedPage(width: 400, height: 400), to: CGSize(width: 200, height: 200))
    XCTAssertEqual(resized.cgImage?.colorSpace?.name, CGColorSpace.sRGB)
  }

  func testWithoutMaxDimensionKeepsResolution() throws {
    let page = try CompressedPdfBuilder.compressPage(
      scannedPage(width: 640, height: 480), compression: PdfCompression(quality: 0.7, maxDimension: nil))
    XCTAssertEqual(try JpegInfo.read(page.jpeg), JpegInfo(width: 640, height: 480, components: 3))
  }

  func testLowerQualityGivesSmallerPages() throws {
    let image = scannedPage(width: 1000, height: 1000)
    let high = try CompressedPdfBuilder.compressPage(image, compression: PdfCompression(quality: 0.95, maxDimension: nil))
    let low = try CompressedPdfBuilder.compressPage(image, compression: PdfCompression(quality: 0.3, maxDimension: nil))
    XCTAssertLessThan(low.jpeg.count, high.jpeg.count)
  }

  func testBuildsOnePdfFarSmallerThanPDFKitsOwnOutput() throws {
    let images = [
      scannedPage(width: 1200, height: 1600),
      scannedPage(width: 1600, height: 1200),
      scannedPage(width: 1200, height: 1600),
    ]

    let compressed = try CompressedPdfBuilder.build(pages: images, compression: PdfCompression(quality: 0.6, maxDimension: 800))

    let document = try XCTUnwrap(PDFDocument(data: compressed))
    XCTAssertEqual(document.pageCount, 3)
    XCTAssertEqual(document.page(at: 1)?.bounds(for: .mediaBox).size, CGSize(width: 1600, height: 1200))

    // What the plugin produces without compression.
    let uncompressed = PDFDocument()
    for (index, image) in images.enumerated() {
      uncompressed.insert(try XCTUnwrap(PDFPage(image: image)), at: index)
    }
    let uncompressedSize = try XCTUnwrap(uncompressed.dataRepresentation()).count
    XCTAssertLessThan(compressed.count, uncompressedSize)
  }

  func testRejectsAnEmptyScan() {
    XCTAssertThrowsError(try CompressedPdfBuilder.build(pages: [], compression: PdfCompression(quality: 0.7, maxDimension: nil))) { error in
      XCTAssertEqual(error as? CompressedPdfBuilder.BuildError, .noPages)
    }
  }
}
