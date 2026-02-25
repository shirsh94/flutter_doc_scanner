package com.shirsh.flutter_doc_scanner

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
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

class FlutterDocScannerPlugin : MethodCallHandler, ActivityResultListener,
    FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val CHANNEL = "flutter_doc_scanner"
    @Volatile private var activity: Activity? = null
    @Volatile private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_CODE_SCAN = 213312
        private const val REQUEST_CODE_SCAN_URI = 214412
        private const val REQUEST_CODE_SCAN_IMAGES = 215512
        private const val REQUEST_CODE_SCAN_PDF = 216612
        private const val DEFAULT_PAGE_LIMIT = 4
        private val TAG = FlutterDocScannerPlugin::class.java.simpleName
    }

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
            "getScannedDocumentAsPdf" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN_PDF,
                intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
            )
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
        resultFormats: IntArray
    ) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Document scanner requires a foreground activity.", null)
            return
        }

        synchronized(this) {
            if (pendingResult != null) {
                result.error("SCAN_IN_PROGRESS", "Another scan is already running.", null)
                return
            }
            pendingResult = result
        }

        val pageLimit = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: DEFAULT_PAGE_LIMIT
        launchDocumentScanner(currentActivity, pageLimit, requestCode, resultFormats)
    }

    private fun launchDocumentScanner(
        currentActivity: Activity,
        pageLimit: Int,
        requestCode: Int,
        resultFormats: IntArray
    ) {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(pageLimit)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
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
                } catch (e: IntentSender.SendIntentException) {
                    Log.e(TAG, "Unable to launch document scanner", e)
                    finishWithError("SCAN_FAILED", "Unable to launch document scanner", e)
                } catch (e: Exception) {
                    Log.e(TAG, "Unable to launch document scanner", e)
                    finishWithError("SCAN_FAILED", "Unable to launch document scanner", e)
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Unable to start document scanner", e)
                finishWithError("SCAN_FAILED", "Unable to start document scanner", e)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (pendingResult == null) {
            Log.w(TAG, "onActivityResult called but pendingResult is null (requestCode=$requestCode)")
            return false
        }

        return when (requestCode) {
            REQUEST_CODE_SCAN, REQUEST_CODE_SCAN_PDF -> {
                handlePdfResult(resultCode, data)
                true
            }

            REQUEST_CODE_SCAN_IMAGES, REQUEST_CODE_SCAN_URI -> {
                handleImageResult(resultCode, data)
                true
            }

            else -> false
        }
    }

    private fun handlePdfResult(resultCode: Int, data: Intent?) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                if (scanResult == null) {
                    finishWithError("SCAN_FAILED", "Failed to parse scan result from intent")
                    return
                }
                val pdf = scanResult.getPdf()
                if (pdf != null) {
                    finishWithSuccess(
                        mapOf(
                            "pdfUri" to pdf.getUri().toString(),
                            "pageCount" to pdf.getPageCount(),
                        )
                    )
                } else {
                    finishWithError("SCAN_FAILED", "No PDF result returned from scanner")
                }
            }

            Activity.RESULT_CANCELED -> finishWithSuccess(null)
            else -> finishWithError("SCAN_FAILED", "Failed to scan document (resultCode=$resultCode)")
        }
    }

    private fun handleImageResult(resultCode: Int, data: Intent?) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                if (scanResult == null) {
                    finishWithError("SCAN_FAILED", "Failed to parse scan result from intent")
                    return
                }
                val pages = scanResult.getPages()
                val imageUris =
                    pages?.mapNotNull { page -> page.getImageUri()?.toString() } ?: emptyList()
                if (imageUris.isNotEmpty()) {
                    finishWithSuccess(
                        mapOf(
                            "images" to imageUris,
                            "count" to imageUris.size,
                        )
                    )
                } else {
                    finishWithError("SCAN_FAILED", "No image results returned from scanner")
                }
            }

            Activity.RESULT_CANCELED -> finishWithSuccess(null)
            else -> finishWithError("SCAN_FAILED", "Failed to scan document (resultCode=$resultCode)")
        }
    }

    private fun finishWithSuccess(payload: Any?) {
        synchronized(this) {
            pendingResult?.success(payload)
            pendingResult = null
        }
    }

    private fun finishWithError(code: String, message: String, throwable: Throwable? = null) {
        synchronized(this) {
            pendingResult?.error(code, message, throwable?.localizedMessage)
            pendingResult = null
        }
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
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        // Note: pendingResult is intentionally NOT cleared here so the scan
        // can still complete after a config change (e.g. device rotation).
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        activityBinding?.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        synchronized(this) {
            if (pendingResult != null) {
                pendingResult?.error("NO_ACTIVITY", "Activity was destroyed while scan was in progress", null)
                pendingResult = null
            }
        }
    }
}
