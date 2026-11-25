import Foundation

/// Size and colour layout of a JPEG, read from its frame header.
struct JpegInfo: Equatable {
    let width: Int
    let height: Int
    let components: Int

    enum ReadError: Error, Equatable {
        case notAJpeg
        case corrupt(String)
    }

    /// Start-of-frame markers: C0–CF, except DHT (C4), JPG (C8) and DAC (CC).
    private static func isStartOfFrame(_ marker: UInt8) -> Bool {
        (0xC0...0xCF).contains(marker) && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
    }

    static func read(_ jpeg: Data) throws -> JpegInfo {
        let bytes = [UInt8](jpeg)
        guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { throw ReadError.notAJpeg }
        var i = 2
        while i + 3 < bytes.count {
            guard bytes[i] == 0xFF else { throw ReadError.corrupt("expected a marker at offset \(i)") }
            let marker = bytes[i + 1]
            switch marker {
            case 0xFF:
                i += 1 // fill byte
            case 0x01, 0xD0...0xD7:
                i += 2 // markers without a length
            case 0xD9, 0xDA:
                throw ReadError.corrupt("no frame header found") // end of image / start of scan
            default:
                let length = Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
                if isStartOfFrame(marker) {
                    guard i + 9 < bytes.count else { throw ReadError.corrupt("truncated frame header") }
                    let height = Int(bytes[i + 5]) << 8 | Int(bytes[i + 6])
                    let width = Int(bytes[i + 7]) << 8 | Int(bytes[i + 8])
                    return JpegInfo(width: width, height: height, components: Int(bytes[i + 9]))
                }
                i += 2 + length
            }
        }
        throw ReadError.corrupt("no frame header found")
    }
}

/// One PDF page: a JPEG image drawn over the whole page. `pageSize` is in PDF points,
/// independent of the image's pixel size.
struct JpegPdfPage {
    let jpeg: Data
    let pageSize: CGSize
}

/// Writes a PDF in which every page is one JPEG, embedded byte for byte (`/DCTDecode`).
///
/// `PDFPage(image:)` embeds the page at full resolution without a compression setting, which
/// is what makes a multi-page scan large. Embedding the JPEG directly keeps the compression
/// chosen in `PdfCompression`, works the same on every supported iOS version, and produces
/// the same file layout as the Android implementation. The output is a minimal PDF 1.4 file:
/// catalog, page tree, and per page a page object, an image object and a content stream.
enum JpegPdfWriter {
    enum WriteError: Error, Equatable {
        case noPages
        case invalidPageSize
        case unsupportedComponents(Int)
    }

    static func write(_ pages: [JpegPdfPage]) throws -> Data {
        guard !pages.isEmpty else { throw WriteError.noPages }
        var out = Data()
        // Object numbers: 1 catalog, 2 page tree, then three per page.
        let objectCount = 2 + pages.count * 3
        var offsets = [Int](repeating: 0, count: objectCount + 1)
        func pageObject(_ index: Int) -> Int { 3 + index * 3 }
        func imageObject(_ index: Int) -> Int { 4 + index * 3 }
        func contentObject(_ index: Int) -> Int { 5 + index * 3 }
        func ascii(_ text: String) { out.append(text.data(using: .ascii)!) }

        ascii("%PDF-1.4\n")
        // A comment with bytes above 127 marks the file as binary for transfer tools.
        out.append(contentsOf: [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A])

        offsets[1] = out.count
        ascii("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

        offsets[2] = out.count
        let kids = pages.indices.map { "\(pageObject($0)) 0 R" }.joined(separator: " ")
        ascii("2 0 obj\n<< /Type /Pages /Kids [\(kids)] /Count \(pages.count) >>\nendobj\n")

        for (index, page) in pages.enumerated() {
            let info = try JpegInfo.read(page.jpeg)
            let width = try number(page.pageSize.width)
            let height = try number(page.pageSize.height)

            offsets[pageObject(index)] = out.count
            ascii("\(pageObject(index)) 0 obj\n<< /Type /Page /Parent 2 0 R "
                + "/MediaBox [0 0 \(width) \(height)] "
                + "/Resources << /XObject << /Im0 \(imageObject(index)) 0 R >> >> "
                + "/Contents \(contentObject(index)) 0 R >>\nendobj\n")

            offsets[imageObject(index)] = out.count
            ascii("\(imageObject(index)) 0 obj\n<< /Type /XObject /Subtype /Image "
                + "/Width \(info.width) /Height \(info.height) \(try colorSpace(info.components)) "
                + "/BitsPerComponent 8 /Filter /DCTDecode /Length \(page.jpeg.count) >>\nstream\n")
            out.append(page.jpeg)
            ascii("\nendstream\nendobj\n")

            let content = "q \(width) 0 0 \(height) 0 0 cm /Im0 Do Q".data(using: .ascii)!
            offsets[contentObject(index)] = out.count
            ascii("\(contentObject(index)) 0 obj\n<< /Length \(content.count) >>\nstream\n")
            out.append(content)
            ascii("\nendstream\nendobj\n")
        }

        let xrefOffset = out.count
        ascii("xref\n0 \(objectCount + 1)\n0000000000 65535 f \n")
        for number in 1...objectCount {
            ascii(String(format: "%010d 00000 n \n", offsets[number]))
        }
        ascii("trailer\n<< /Size \(objectCount + 1) /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n")
        return out
    }

    private static func colorSpace(_ components: Int) throws -> String {
        switch components {
        case 1: return "/ColorSpace /DeviceGray"
        case 3: return "/ColorSpace /DeviceRGB"
        // Adobe CMYK JPEGs store inverted values.
        case 4: return "/ColorSpace /DeviceCMYK /Decode [1 0 1 0 1 0 1 0]"
        default: throw WriteError.unsupportedComponents(components)
        }
    }

    /// A PDF number: no exponent, no locale-specific decimal separator.
    private static func number(_ value: CGFloat) throws -> String {
        guard value > 0, value.isFinite else { throw WriteError.invalidPageSize }
        var text = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(value))
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
