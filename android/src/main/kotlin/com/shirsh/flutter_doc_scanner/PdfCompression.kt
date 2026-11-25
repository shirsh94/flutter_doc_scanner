package com.shirsh.flutter_doc_scanner

import kotlin.math.max
import kotlin.math.roundToInt

/** Pixel size of a page image. */
internal data class PageSize(val width: Int, val height: Int)

/**
 * Compression for a scanned PDF, as sent by the Dart side under the `compression`
 * argument of `getScannedDocumentAsPdf`.
 *
 * [quality] is the JPEG quality from 0.0 to 1.0. [maxDimension] caps the longest
 * edge of every page in pixels; `null` keeps the scanned resolution.
 */
internal data class PdfCompression(val quality: Float, val maxDimension: Int?) {

    /** [quality] on the 0–100 scale `Bitmap.compress` expects. */
    val jpegQuality: Int
        get() = (quality * 100f).roundToInt().coerceIn(0, 100)

    /**
     * The size a page of [width] × [height] pixels is scaled to: the longest edge is at
     * most [maxDimension], the aspect ratio is kept, and a page is never scaled up.
     */
    fun targetSize(width: Int, height: Int): PageSize {
        val limit = maxDimension ?: return PageSize(width, height)
        val longest = max(width, height)
        if (longest <= limit) return PageSize(width, height)
        val scale = limit.toDouble() / longest
        return PageSize(
            max(1, (width * scale).roundToInt()),
            max(1, (height * scale).roundToInt()),
        )
    }

    /**
     * The largest power-of-two decode subsampling that still yields at least [targetSize].
     * Decoding with it keeps a 12-megapixel page from ever being held in memory at full size.
     */
    fun sampleSize(width: Int, height: Int): Int {
        val target = targetSize(width, height)
        var sample = 1
        while (width / (sample * 2) >= target.width && height / (sample * 2) >= target.height) {
            sample *= 2
        }
        return sample
    }

    companion object {
        const val DEFAULT_QUALITY = 0.8f

        /**
         * Reads the `compression` entry of the method-call arguments. Returns `null` when it
         * is absent, which keeps the original ML Kit PDF path for existing callers.
         */
        fun fromArguments(arguments: Map<*, *>?): PdfCompression? {
            val map = arguments?.get("compression") as? Map<*, *> ?: return null
            val quality = (map["quality"] as? Number)?.toFloat() ?: DEFAULT_QUALITY
            val maxDimension = (map["maxDimension"] as? Number)?.toInt()
            return PdfCompression(
                quality = if (quality.isNaN()) DEFAULT_QUALITY else quality.coerceIn(0f, 1f),
                maxDimension = maxDimension?.takeIf { it > 0 },
            )
        }
    }
}
