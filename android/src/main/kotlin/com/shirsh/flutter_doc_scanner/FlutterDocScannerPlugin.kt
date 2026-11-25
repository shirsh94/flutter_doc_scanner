package com.shirsh.flutter_doc_scanner


import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class FlutterDocScannerPlugin : MethodCallHandler, ActivityResultListener,
    FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val CHANNEL = "flutter_doc_scanner"
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null
    /** Set while a compressed-PDF scan runs; read when ML Kit returns its JPEG pages. */
    private var pendingPdfCompression: PdfCompression? = null
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    private val pdfExecutor: ExecutorService by lazy {
        // A daemon thread, so an idle executor never keeps the process alive.
        Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "doc-scan-pdf").apply { isDaemon = true } }
    }

    private val REQUEST_CODE_SCAN = 213312
    private val REQUEST_CODE_SCAN_URI = 214412
    private val REQUEST_CODE_SCAN_IMAGES = 215512
    private val REQUEST_CODE_SCAN_PDF = 216612
    private val REQUEST_CODE_SCAN_PDF_COMPRESSED = 217712
    private val DEFAULT_PAGE_LIMIT = 4
    private val TAG = FlutterDocScannerPlugin::class.java.simpleName


    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "getScanDocuments" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN,
                intArrayOf(
                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
                )
            )
            "getScannedDocumentAsImages" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN_IMAGES,
                intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            )
            "getScannedDocumentAsPdf" -> {
                val arguments = call.arguments as? Map<*, *>
                val compression = PdfCompression.fromArguments(arguments)
                if (compression == null) {
                    startDocumentScan(
                        result,
                        arguments,
                        REQUEST_CODE_SCAN_PDF,
                        intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
                    )
                } else {
                    // ML Kit's PDF output cannot be compressed, so ask for JPEG pages
                    // and assemble the PDF ourselves once they are shrunk.
                    startDocumentScan(
                        result,
                        arguments,
                        REQUEST_CODE_SCAN_PDF_COMPRESSED,
                        intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG),
                        compression
                    )
                }
            }
            "getScanDocumentsUri" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN_URI,
                intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            )
            else -> result.notImplemented()
        }
    }

    private fun startDocumentScan(
        result: Result,
        arguments: Map<*, *>?,
        requestCode: Int,
        resultFormats: IntArray,
        pdfCompression: PdfCompression? = null
    ) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Document scanner requires a foreground activity.", null)
            return
        }

        if (pendingResult != null) {
            result.error("SCAN_IN_PROGRESS", "Another scan is already running.", null)
            return
        }

        val pageLimit = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: DEFAULT_PAGE_LIMIT
        val useAutomaticSinglePictureProcessing =
            (arguments?.get("useAutomaticSinglePictureProcessing") as? Boolean) ?: false
        // New fast path: single page + base scanner mode (page argument is intentionally ignored).
        val fastSinglePageMode =
            requestCode == REQUEST_CODE_SCAN_IMAGES && useAutomaticSinglePictureProcessing
        val effectivePageLimit = if (fastSinglePageMode) 1 else pageLimit
        val scannerMode = if (fastSinglePageMode) {
            GmsDocumentScannerOptions.SCANNER_MODE_BASE
        } else {
            GmsDocumentScannerOptions.SCANNER_MODE_FULL
        }
        val galleryImportAllowed = !fastSinglePageMode

        pendingResult = result
        pendingPdfCompression = pdfCompression
        launchDocumentScanner(
            currentActivity,
            effectivePageLimit,
            requestCode,
            resultFormats,
            scannerMode,
            galleryImportAllowed
        )
    }

    private fun launchDocumentScanner(
        currentActivity: Activity,
        pageLimit: Int,
        requestCode: Int,
        resultFormats: IntArray,
        scannerMode: Int,
        galleryImportAllowed: Boolean
    ) {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(galleryImportAllowed)
            .setPageLimit(pageLimit)
            .setScannerMode(scannerMode)
        if (resultFormats.isNotEmpty()) {
            val firstFormat = resultFormats.first()
            val remainingFormats = resultFormats.drop(1).toIntArray()
            options.setResultFormats(firstFormat, *remainingFormats)
        }
        val builtOptions = options.build()

        GmsDocumentScanning.getClient(builtOptions)
            .getStartScanIntent(currentActivity)
            .addOnSuccessListener { intentSender: IntentSender ->
                try {
                    startIntentSenderForResult(
                        currentActivity,
                        intentSender,
                        requestCode,
                        null,
                        0,
                        0,
                        0,
                        null
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Unable to launch document scanner", e)
                    finishWithError("Unable to launch document scanner", e)
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Unable to start document scanner", e)
                finishWithError("Unable to start document scanner", e)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (pendingResult == null) return false

        return when (requestCode) {
            REQUEST_CODE_SCAN, REQUEST_CODE_SCAN_PDF -> {
                handlePdfResult(resultCode, data)
                true
            }

            REQUEST_CODE_SCAN_IMAGES, REQUEST_CODE_SCAN_URI -> {
                handleImageResult(resultCode, data)
                true
            }

            REQUEST_CODE_SCAN_PDF_COMPRESSED -> {
                handleCompressedPdfResult(resultCode, data)
                true
            }

            else -> false
        }
    }

    private fun handlePdfResult(resultCode: Int, data: Intent?) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val pdf = GmsDocumentScanningResult.fromActivityResultIntent(data)?.getPdf()
                if (pdf != null) {
                    finishWithSuccess(
                        mapOf(
                            "pdfUri" to pdf.getUri().toString(),
                            "pageCount" to pdf.getPageCount(),
                        )
                    )
                } else {
                    finishWithError("No PDF result returned")
                }
            }

            Activity.RESULT_CANCELED -> finishWithSuccess(null)
            else -> finishWithError("Failed to scan document (code $resultCode)")
        }
    }

    private fun handleCompressedPdfResult(resultCode: Int, data: Intent?) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val compression = pendingPdfCompression
                val context = activity?.applicationContext
                val pageUris = GmsDocumentScanningResult.fromActivityResultIntent(data)
                    ?.getPages()
                    ?.mapNotNull { page -> page.getImageUri() }
                    ?: emptyList()
                when {
                    compression == null || context == null ->
                        finishWithError("Scanner state was lost before the PDF could be created")
                    pageUris.isEmpty() -> finishWithError("No PDF result returned")
                    else -> buildCompressedPdf(context, pageUris, compression)
                }
            }

            Activity.RESULT_CANCELED -> finishWithSuccess(null)
            else -> finishWithError("Failed to scan document (code $resultCode)")
        }
    }

    /** Decoding and encoding pages takes a moment, so it runs off the main thread. */
    private fun buildCompressedPdf(
        context: android.content.Context,
        pageUris: List<Uri>,
        compression: PdfCompression
    ) {
        pdfExecutor.execute {
            try {
                val output = File(context.cacheDir, "doc_scan_${System.currentTimeMillis()}.pdf")
                val sources = pageUris.map { uri ->
                    {
                        context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            ?: throw java.io.IOException("Cannot read scanned page $uri")
                    }
                }
                CompressedPdfBuilder.build(sources, compression, output)
                mainHandler.post {
                    finishWithSuccess(
                        mapOf(
                            "pdfUri" to Uri.fromFile(output).toString(),
                            "pageCount" to pageUris.size,
                        )
                    )
                }
            } catch (e: Throwable) {
                // Throwable, not Exception: decoding a page can run out of memory, and an
                // uncaught OutOfMemoryError would leave the scan pending forever.
                Log.e(TAG, "Unable to create compressed PDF", e)
                mainHandler.post { finishWithError("Failed to create compressed PDF", e) }
            }
        }
    }

    private fun handleImageResult(resultCode: Int, data: Intent?) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val pages = GmsDocumentScanningResult.fromActivityResultIntent(data)?.getPages()
                val imageUris = pages
                    ?.mapNotNull { page -> page.getImageUri()?.toString() }
                    ?: emptyList()
                if (imageUris.isNotEmpty()) {
                    finishWithSuccess(
                        mapOf(
                            "images" to imageUris,
                            "count" to imageUris.size,
                            "Uri" to imageUris, // Backward compatible keys
                            "Count" to imageUris.size,
                        )
                    )
                } else {
                    finishWithError("No image results returned")
                }
            }

            Activity.RESULT_CANCELED -> finishWithSuccess(null)
            else -> finishWithError("Failed to scan document (code $resultCode)")
        }
    }

    private fun finishWithSuccess(payload: Any?) {
        pendingResult?.success(payload)
        pendingResult = null
        pendingPdfCompression = null
    }

    private fun finishWithError(message: String, throwable: Throwable? = null) {
        pendingResult?.error("SCAN_FAILED", message, throwable?.localizedMessage)
        pendingResult = null
        pendingPdfCompression = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        activityBinding?.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        pendingResult = null
        pendingPdfCompression = null
    }
}
