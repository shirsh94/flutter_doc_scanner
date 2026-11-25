package com.shirsh.flutter_doc_scanner

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class PdfCompressionTest {

    @Test
    fun fromArguments_withoutCompression_returnsNull() {
        assertNull(PdfCompression.fromArguments(null))
        assertNull(PdfCompression.fromArguments(mapOf("page" to 4)))
    }

    @Test
    fun fromArguments_readsQualityAndMaxDimension() {
        val compression = PdfCompression.fromArguments(
            mapOf("page" to 5, "compression" to mapOf("quality" to 0.7, "maxDimension" to 2500))
        )
        assertEquals(PdfCompression(0.7f, 2500), compression)
    }

    @Test
    fun fromArguments_defaultsMissingQuality_andIgnoresInvalidMaxDimension() {
        assertEquals(
            PdfCompression(PdfCompression.DEFAULT_QUALITY, null),
            PdfCompression.fromArguments(mapOf("compression" to mapOf("maxDimension" to 0)))
        )
    }

    @Test
    fun fromArguments_clampsQualityIntoRange() {
        assertEquals(1f, PdfCompression.fromArguments(mapOf("compression" to mapOf("quality" to 3.0)))?.quality)
        assertEquals(0f, PdfCompression.fromArguments(mapOf("compression" to mapOf("quality" to -1)))?.quality)
    }

    @Test
    fun jpegQuality_mapsToBitmapScale() {
        assertEquals(70, PdfCompression(0.7f, null).jpegQuality)
        assertEquals(0, PdfCompression(0f, null).jpegQuality)
        assertEquals(100, PdfCompression(1f, null).jpegQuality)
    }

    @Test
    fun targetSize_withoutLimit_keepsSize() {
        assertEquals(PageSize(3000, 4000), PdfCompression(0.8f, null).targetSize(3000, 4000))
    }

    @Test
    fun targetSize_scalesLongestEdgeAndKeepsAspectRatio() {
        assertEquals(PageSize(1875, 2500), PdfCompression(0.8f, 2500).targetSize(3000, 4000))
        assertEquals(PageSize(2500, 1875), PdfCompression(0.8f, 2500).targetSize(4000, 3000))
    }

    @Test
    fun targetSize_neverScalesUp() {
        assertEquals(PageSize(800, 600), PdfCompression(0.8f, 2500).targetSize(800, 600))
    }

    @Test
    fun targetSize_keepsAtLeastOnePixel() {
        assertEquals(PageSize(1, 100), PdfCompression(0.8f, 100).targetSize(10, 10000))
    }

    @Test
    fun sampleSize_isLargestPowerOfTwoStillCoveringTheTarget() {
        // 4000 -> target 1000: subsampling by 4 gives exactly 1000.
        assertEquals(4, PdfCompression(0.8f, 1000).sampleSize(3000, 4000))
        // 4000 -> target 2500: subsampling by 2 would give 2000 < 2500.
        assertEquals(1, PdfCompression(0.8f, 2500).sampleSize(3000, 4000))
        assertEquals(1, PdfCompression(0.8f, null).sampleSize(3000, 4000))
    }
}
