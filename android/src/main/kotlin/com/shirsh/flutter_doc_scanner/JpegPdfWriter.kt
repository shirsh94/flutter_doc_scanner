package com.shirsh.flutter_doc_scanner

import java.io.OutputStream
import java.util.Locale

/** Size and colour layout of a baseline or progressive JPEG, read from its frame header. */
internal data class JpegInfo(val width: Int, val height: Int, val components: Int) {
    companion object {
        /** Start-of-frame markers: C0–CF, except DHT (C4), JPG (C8) and DAC (CC). */
        private fun isStartOfFrame(marker: Int) =
            marker in 0xC0..0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC

        fun read(jpeg: ByteArray): JpegInfo {
            fun u(i: Int) = jpeg[i].toInt() and 0xFF
            require(jpeg.size >= 4 && u(0) == 0xFF && u(1) == 0xD8) { "Not a JPEG image" }
            var i = 2
            while (i + 3 < jpeg.size) {
                require(u(i) == 0xFF) { "Corrupt JPEG: expected a marker at offset $i" }
                val marker = u(i + 1)
                when {
                    marker == 0xFF -> i += 1 // fill byte
                    marker == 0x01 || marker in 0xD0..0xD7 -> i += 2 // markers without a length
                    marker == 0xD9 || marker == 0xDA -> break // end of image / start of scan
                    else -> {
                        val length = (u(i + 2) shl 8) or u(i + 3)
                        if (isStartOfFrame(marker)) {
                            require(i + 9 < jpeg.size) { "Corrupt JPEG: truncated frame header" }
                            val height = (u(i + 5) shl 8) or u(i + 6)
                            val width = (u(i + 7) shl 8) or u(i + 8)
                            return JpegInfo(width, height, u(i + 9))
                        }
                        i += 2 + length
                    }
                }
            }
            throw IllegalArgumentException("Corrupt JPEG: no frame header found")
        }
    }
}

/**
 * One PDF page: a JPEG image drawn over the whole page. [pageWidth] and [pageHeight] are the
 * page size in PDF points, independent of the image's pixel size.
 */
internal class JpegPdfPage(val jpeg: ByteArray, val pageWidth: Double, val pageHeight: Double)

/**
 * Writes a PDF in which every page is one JPEG, embedded byte for byte (`/DCTDecode`).
 *
 * Android's own `android.graphics.pdf.PdfDocument` re-encodes bitmaps losslessly, which
 * makes a scanned page several megabytes again; embedding the JPEG keeps the compression
 * chosen in [PdfCompression]. The output is a minimal PDF 1.4 file: catalog, page tree, and
 * per page a page object, an image object and a content stream.
 */
internal object JpegPdfWriter {

    fun write(pages: List<JpegPdfPage>, out: OutputStream) {
        require(pages.isNotEmpty()) { "A PDF needs at least one page" }
        val writer = PdfByteWriter(out)
        // Object numbers: 1 catalog, 2 page tree, then three per page.
        val objectCount = 2 + pages.size * 3
        val offsets = LongArray(objectCount + 1)
        fun pageObject(index: Int) = 3 + index * 3
        fun imageObject(index: Int) = 4 + index * 3
        fun contentObject(index: Int) = 5 + index * 3

        writer.ascii("%PDF-1.4\n")
        // A comment with bytes above 127 marks the file as binary for transfer tools.
        writer.bytes(byteArrayOf(0x25, 0xE2.toByte(), 0xE3.toByte(), 0xCF.toByte(), 0xD3.toByte(), 0x0A))

        offsets[1] = writer.offset
        writer.ascii("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

        offsets[2] = writer.offset
        val kids = pages.indices.joinToString(" ") { "${pageObject(it)} 0 R" }
        writer.ascii("2 0 obj\n<< /Type /Pages /Kids [$kids] /Count ${pages.size} >>\nendobj\n")

        pages.forEachIndexed { index, page ->
            val info = JpegInfo.read(page.jpeg)
            val width = number(page.pageWidth)
            val height = number(page.pageHeight)

            offsets[pageObject(index)] = writer.offset
            writer.ascii(
                "${pageObject(index)} 0 obj\n<< /Type /Page /Parent 2 0 R " +
                    "/MediaBox [0 0 $width $height] " +
                    "/Resources << /XObject << /Im0 ${imageObject(index)} 0 R >> >> " +
                    "/Contents ${contentObject(index)} 0 R >>\nendobj\n"
            )

            offsets[imageObject(index)] = writer.offset
            writer.ascii(
                "${imageObject(index)} 0 obj\n<< /Type /XObject /Subtype /Image " +
                    "/Width ${info.width} /Height ${info.height} ${colorSpace(info.components)} " +
                    "/BitsPerComponent 8 /Filter /DCTDecode /Length ${page.jpeg.size} >>\nstream\n"
            )
            writer.bytes(page.jpeg)
            writer.ascii("\nendstream\nendobj\n")

            val content = "q $width 0 0 $height 0 0 cm /Im0 Do Q".toByteArray(Charsets.US_ASCII)
            offsets[contentObject(index)] = writer.offset
            writer.ascii("${contentObject(index)} 0 obj\n<< /Length ${content.size} >>\nstream\n")
            writer.bytes(content)
            writer.ascii("\nendstream\nendobj\n")
        }

        val xrefOffset = writer.offset
        writer.ascii("xref\n0 ${objectCount + 1}\n0000000000 65535 f \n")
        for (number in 1..objectCount) {
            writer.ascii(String.format(Locale.ROOT, "%010d 00000 n \n", offsets[number]))
        }
        writer.ascii("trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n")
        out.flush()
    }

    private fun colorSpace(components: Int) = when (components) {
        1 -> "/ColorSpace /DeviceGray"
        3 -> "/ColorSpace /DeviceRGB"
        // Adobe CMYK JPEGs store inverted values.
        4 -> "/ColorSpace /DeviceCMYK /Decode [1 0 1 0 1 0 1 0]"
        else -> throw IllegalArgumentException("Unsupported JPEG with $components colour components")
    }

    /** A PDF number: no exponent, no locale-specific decimal separator. */
    private fun number(value: Double): String {
        require(value > 0 && value.isFinite()) { "Page size must be positive, was $value" }
        return String.format(Locale.ROOT, "%.2f", value).trimEnd('0').trimEnd('.')
    }

    private class PdfByteWriter(private val out: OutputStream) {
        var offset = 0L
            private set

        fun ascii(text: String) = bytes(text.toByteArray(Charsets.US_ASCII))

        fun bytes(data: ByteArray) {
            out.write(data)
            offset += data.size
        }
    }
}
