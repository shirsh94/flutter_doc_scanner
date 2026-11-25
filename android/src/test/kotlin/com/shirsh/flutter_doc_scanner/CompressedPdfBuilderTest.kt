package com.shirsh.flutter_doc_scanner

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.Random
import org.apache.pdfbox.Loader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Real Bitmap decoding, scaling and JPEG encoding through Robolectric's native graphics. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class CompressedPdfBuilderTest {

    @get:Rule
    val temp = TemporaryFolder()

    /** A noisy page, so JPEG quality has a visible effect on the size. */
    private fun scannedPage(width: Int, height: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint()
        val random = Random(42)
        repeat(4000) {
            paint.color = Color.rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256))
            val x = random.nextInt(width).toFloat()
            val y = random.nextInt(height).toFloat()
            canvas.drawRect(x, y, x + 12f, y + 12f, paint)
        }
        val out = ByteArrayOutputStream()
        check(bitmap.compress(Bitmap.CompressFormat.JPEG, 100, out))
        return out.toByteArray()
    }

    private fun bounds(jpeg: ByteArray): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, options)
        return options.outWidth to options.outHeight
    }

    @Test
    fun compressPage_scalesToMaxDimension_andKeepsOriginalSizeAsPageSize() {
        val page = CompressedPdfBuilder.compressPage(scannedPage(1200, 1600), PdfCompression(0.7f, 800))

        assertEquals(600 to 800, bounds(page.jpeg))
        assertEquals(1200.0, page.pageWidth, 0.0)
        assertEquals(1600.0, page.pageHeight, 0.0)
        assertEquals(JpegInfo(600, 800, 3), JpegInfo.read(page.jpeg))
    }

    @Test
    fun compressPage_withoutMaxDimension_keepsResolution() {
        val page = CompressedPdfBuilder.compressPage(scannedPage(640, 480), PdfCompression(0.7f, null))
        assertEquals(640 to 480, bounds(page.jpeg))
    }

    @Test
    fun compressPage_lowerQualityGivesSmallerPages() {
        val source = scannedPage(1000, 1000)
        val high = CompressedPdfBuilder.compressPage(source, PdfCompression(0.95f, null)).jpeg.size
        val low = CompressedPdfBuilder.compressPage(source, PdfCompression(0.3f, null)).jpeg.size
        assertTrue("quality 0.3 ($low B) must be smaller than 0.95 ($high B)", low < high)
    }

    @Test
    fun compressPage_rejectsUnreadableData() {
        assertThrows(IOException::class.java) {
            CompressedPdfBuilder.compressPage(byteArrayOf(1, 2, 3), PdfCompression(0.7f, null))
        }
    }

    @Test
    fun build_writesAllPagesIntoOnePdf_smallerThanTheSources() {
        val sources = listOf(scannedPage(1200, 1600), scannedPage(1600, 1200), scannedPage(1200, 1600))
        val output = File(temp.root, "scan.pdf")

        CompressedPdfBuilder.build(sources.map { bytes -> { bytes } }, PdfCompression(0.6f, 800), output)

        assertTrue(output.length() < sources.sumOf { it.size })
        Loader.loadPDF(output).use { document ->
            assertEquals(3, document.numberOfPages)
            assertEquals(1600f, document.getPage(1).mediaBox.width)
            assertEquals(1200f, document.getPage(1).mediaBox.height)
        }
    }

    @Test
    fun build_deletesThePartialFileWhenAPageFails() {
        val output = File(temp.root, "broken.pdf").apply { writeText("stale") }
        val sources = listOf({ scannedPage(200, 200) }, { throw IOException("page gone") })

        assertThrows(IOException::class.java) {
            CompressedPdfBuilder.build(sources, PdfCompression(0.6f, null), output)
        }
        assertFalse(output.exists())
    }
}
