import UIKit

/// Builds a compressed PDF from scanned page images.
///
/// Every page is scaled down to `PdfCompression.targetPixelSize(for:)`, encoded as JPEG with
/// `PdfCompression.quality`, and embedded as is by `JpegPdfWriter`. The PDF page keeps the
/// scanned image's size in points (what `PDFPage(image:)` uses), so the page dimensions are
/// the same with and without compression; only the image resolution and encoding change.
enum CompressedPdfBuilder {
    enum BuildError: Error, Equatable {
        case noPages
        case encodingFailed
    }

    static func build(pages: [UIImage], compression: PdfCompression) throws -> Data {
        guard !pages.isEmpty else { throw BuildError.noPages }
        let compressed = try pages.map { try compressPage($0, compression: compression) }
        return try JpegPdfWriter.write(compressed)
    }

    static func compressPage(_ image: UIImage, compression: PdfCompression) throws -> JpegPdfPage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let target = compression.targetPixelSize(for: pixelSize)
        // Redrawn unless it is already exactly right: a smaller size, a scale other than 1,
        // or an orientation other than up all need new pixels. JPEG would only record the
        // orientation as a tag, which PDF viewers ignore, so the page would come out turned.
        let needsRedraw = target != pixelSize || image.scale != 1 || image.imageOrientation != .up
        let source = needsRedraw ? resized(image, to: target) : image
        guard let jpeg = source.jpegData(compressionQuality: compression.quality) else {
            throw BuildError.encodingFailed
        }
        return JpegPdfPage(jpeg: jpeg, pageSize: image.size)
    }

    /// Redraws `image` at exactly `pixelSize` pixels, upright.
    static func resized(_ image: UIImage, to pixelSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // one point per pixel, so the bitmap has exactly `pixelSize` pixels
        format.opaque = true // scanned pages have no transparency; JPEG has none anyway
        // sRGB, not the device's wide gamut: the PDF declares the image as /DeviceRGB and would
        // ignore a Display P3 profile, shifting saturated colours.
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}
