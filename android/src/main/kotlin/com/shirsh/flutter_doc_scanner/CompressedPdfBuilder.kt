package com.shirsh.flutter_doc_scanner

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException

/**
 * Builds a compressed PDF from the JPEG pages ML Kit returns.
 *
 * ML Kit's own PDF output has no compression setting, so with a [PdfCompression] the plugin
 * asks ML Kit for JPEG pages instead, shrinks and re-encodes every page here, and writes
 * the PDF itself with [JpegPdfWriter].
 */
internal object CompressedPdfBuilder {

    /**
     * Compresses every page from [pageSources] (each returns the encoded bytes of one page
     * image) and writes the PDF to [output]. Pages are read one at a time, so only one
     * decoded page is in memory at once. A partially written [output] is deleted on failure.
     */
    fun build(pageSources: List<() -> ByteArray>, compression: PdfCompression, output: File) {
        require(pageSources.isNotEmpty()) { "No pages to write" }
        try {
            val pages = pageSources.map { source -> compressPage(source(), compression) }
            output.outputStream().buffered().use { JpegPdfWriter.write(pages, it) }
        } catch (e: Throwable) {
            output.delete()
            throw e
        }
    }

    /**
     * Scales one page down to [PdfCompression.targetSize] and re-encodes it as JPEG.
     * The PDF page keeps the original pixel size as its size in points, so the page
     * dimensions do not depend on the compression; only the image resolution does.
     */
    fun compressPage(source: ByteArray, compression: PdfCompression): JpegPdfPage {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(source, 0, source.size, bounds)
        val width = bounds.outWidth
        val height = bounds.outHeight
        if (width <= 0 || height <= 0) throw IOException("Unreadable page image")

        val target = compression.targetSize(width, height)
        val options = BitmapFactory.Options().apply { inSampleSize = compression.sampleSize(width, height) }
        val decoded = BitmapFactory.decodeByteArray(source, 0, source.size, options)
            ?: throw IOException("Unreadable page image")
        val scaled = if (decoded.width == target.width && decoded.height == target.height) {
            decoded
        } else {
            Bitmap.createScaledBitmap(decoded, target.width, target.height, true)
        }
        if (scaled !== decoded) decoded.recycle()

        try {
            val encoded = ByteArrayOutputStream()
            if (!scaled.compress(Bitmap.CompressFormat.JPEG, compression.jpegQuality, encoded)) {
                throw IOException("JPEG encoding failed")
            }
            return JpegPdfPage(encoded.toByteArray(), width.toDouble(), height.toDouble())
        } finally {
            scaled.recycle()
        }
    }
}
