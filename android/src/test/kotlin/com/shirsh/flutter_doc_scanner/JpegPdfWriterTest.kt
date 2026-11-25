package com.shirsh.flutter_doc_scanner

import android.graphics.Bitmap
import android.graphics.Color
import java.io.ByteArrayOutputStream
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import org.apache.pdfbox.Loader
import org.apache.pdfbox.cos.COSName
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** JPEGs come from Android's encoder (Robolectric), the written PDF is read back with PDFBox. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class JpegPdfWriterTest {

    private fun jpeg(width: Int, height: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.rgb(200, 40, 40))
        val out = ByteArrayOutputStream()
        check(bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out))
        return out.toByteArray()
    }

    /**
     * A JPEG reduced to its markers: start of image, an APP0 segment, a baseline frame
     * header with [components] colour components, end of image. Enough for the header
     * reader and the PDF dictionary; no viewer ever decodes it in these tests.
     */
    private fun jpegHeader(width: Int, height: Int, components: Int): ByteArray {
        val frame = mutableListOf(0xFF, 0xC0, 0x00, 8 + components * 3, 0x08,
            height shr 8, height and 0xFF, width shr 8, width and 0xFF, components)
        repeat(components) { frame += listOf(it + 1, 0x11, 0x00) }
        val app0 = listOf(0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00)
        return (listOf(0xFF, 0xD8) + app0 + frame + listOf(0xFF, 0xD9)).map { it.toByte() }.toByteArray()
    }

    private fun writePdf(pages: List<JpegPdfPage>): ByteArray =
        ByteArrayOutputStream().also { JpegPdfWriter.write(pages, it) }.toByteArray()

    @Test
    fun jpegInfo_readsSizeAndComponents() {
        assertEquals(JpegInfo(320, 240, 3), JpegInfo.read(jpeg(320, 240)))
        assertEquals(JpegInfo(50, 70, 1), JpegInfo.read(jpegHeader(50, 70, 1)))
        assertEquals(JpegInfo(3000, 4000, 3), JpegInfo.read(jpegHeader(3000, 4000, 3)))
    }

    @Test
    fun jpegInfo_rejectsNonJpegData() {
        assertFailsWith<IllegalArgumentException> { JpegInfo.read(byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47)) }
        assertFailsWith<IllegalArgumentException> { JpegInfo.read(byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xD9.toByte())) }
    }

    @Test
    fun write_producesAPdfWithOnePagePerJpeg() {
        val pdf = writePdf(
            listOf(
                JpegPdfPage(jpeg(300, 400), 3000.0, 4000.0),
                JpegPdfPage(jpeg(400, 300), 4000.0, 3000.0),
                JpegPdfPage(jpeg(100, 100), 595.5, 842.25),
            )
        )

        Loader.loadPDF(pdf).use { document ->
            assertEquals(3, document.numberOfPages)
            assertEquals(3000f, document.getPage(0).mediaBox.width)
            assertEquals(4000f, document.getPage(0).mediaBox.height)
            assertEquals(4000f, document.getPage(1).mediaBox.width)
            assertEquals(595.5f, document.getPage(2).mediaBox.width)
            assertEquals(842.25f, document.getPage(2).mediaBox.height)
        }
    }

    @Test
    fun write_embedsTheJpegBytesUnchanged() {
        val source = jpeg(300, 400)
        val pdf = writePdf(listOf(JpegPdfPage(source, 300.0, 400.0)))

        Loader.loadPDF(pdf).use { document ->
            val resources = document.getPage(0).resources
            val image = resources.getXObject(resources.xObjectNames.single()) as PDImageXObject
            assertEquals(300, image.width)
            assertEquals(400, image.height)
            assertEquals(listOf(COSName.DCT_DECODE), image.stream.filters)
            val embedded = image.cosObject.createRawInputStream().use { it.readBytes() }
            assertContentEquals(source, embedded)
        }
    }

    @Test
    fun write_marksGrayscaleJpegsAsDeviceGray() {
        val pdf = writePdf(listOf(JpegPdfPage(jpegHeader(60, 80, 1), 60.0, 80.0)))

        Loader.loadPDF(pdf).use { document ->
            val resources = document.getPage(0).resources
            val image = resources.getXObject(resources.xObjectNames.single()) as PDImageXObject
            assertEquals("DeviceGray", image.colorSpace.name)
        }
    }

    @Test
    fun write_hasAValidCrossReferenceTable() {
        val pdf = writePdf(listOf(JpegPdfPage(jpeg(10, 10), 10.0, 10.0)))
        val text = String(pdf, Charsets.ISO_8859_1)
        val startXref = text.substringAfterLast("startxref\n").substringBefore("\n").toInt()
        assertTrue(text.startsWith("xref\n", startIndex = startXref), "startxref must point at the xref table")

        // Every in-use entry must point at "<n> 0 obj".
        val entries = text.substring(startXref).lines().drop(3).takeWhile { it.endsWith(" n ") }
        entries.forEachIndexed { index, entry ->
            val offset = entry.substring(0, 10).toInt()
            assertTrue(text.startsWith("${index + 1} 0 obj", startIndex = offset), "object ${index + 1} offset")
        }
        assertEquals(5, entries.size)
    }

    @Test
    fun write_rejectsAnEmptyDocumentAndInvalidPageSizes() {
        assertFailsWith<IllegalArgumentException> { writePdf(emptyList()) }
        assertFailsWith<IllegalArgumentException> { writePdf(listOf(JpegPdfPage(jpeg(10, 10), 0.0, 10.0))) }
        assertFailsWith<IllegalArgumentException> { writePdf(listOf(JpegPdfPage(jpegHeader(10, 10, 2), 10.0, 10.0))) }
    }
}
