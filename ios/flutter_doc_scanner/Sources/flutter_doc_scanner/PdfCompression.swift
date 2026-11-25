import CoreGraphics
import Foundation

/// Compression for a scanned PDF, as sent by the Dart side under the `compression`
/// argument of `getScannedDocumentAsPdf`.
///
/// `quality` is the JPEG quality from 0.0 to 1.0. `maxDimension` caps the longest edge of
/// every page in pixels; `nil` keeps the scanned resolution.
struct PdfCompression: Equatable {
    static let defaultQuality: CGFloat = 0.8

    let quality: CGFloat
    let maxDimension: Int?

    init(quality: CGFloat, maxDimension: Int?) {
        self.quality = quality
        self.maxDimension = maxDimension
    }

    /// Reads the `compression` entry of the method-call arguments. Returns `nil` when it is
    /// absent, which keeps the original PDF path for existing callers.
    init?(arguments: Any?) {
        guard let arguments = arguments as? [String: Any],
              let map = arguments["compression"] as? [String: Any] else {
            return nil
        }
        let rawQuality = (map["quality"] as? NSNumber).map { CGFloat($0.doubleValue) }
        let quality = rawQuality.flatMap { $0.isNaN ? nil : $0 } ?? PdfCompression.defaultQuality
        let maxDimension = (map["maxDimension"] as? NSNumber)?.intValue
        self.init(
            quality: min(max(quality, 0), 1),
            maxDimension: maxDimension.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    /// The pixel size a page of `pixelSize` is scaled to: the longest edge is at most
    /// `maxDimension`, the aspect ratio is kept, and a page is never scaled up.
    func targetPixelSize(for pixelSize: CGSize) -> CGSize {
        guard let limit = maxDimension else { return pixelSize }
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > CGFloat(limit) else { return pixelSize }
        let scale = CGFloat(limit) / longest
        return CGSize(
            width: max(1, (pixelSize.width * scale).rounded()),
            height: max(1, (pixelSize.height * scale).rounded())
        )
    }
}
