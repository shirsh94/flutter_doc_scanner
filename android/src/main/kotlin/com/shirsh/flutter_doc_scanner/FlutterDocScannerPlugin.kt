package com.shirsh.flutter_doc_scanner


import android.app.Activity
import android.app.Application
import android.app.Application.ActivityLifecycleCallbacks
import android.content.Intent
import android.content.IntentSender
import android.os.Bundle
import android.util.Log
import androidx.activity.result.IntentSenderRequest
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

class FlutterDocScannerPlugin : MethodCallHandler, ActivityResultListener,
    FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private var pluginBinding: FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var applicationContext: Application? = null
    private val CHANNEL = "flutter_doc_scanner"
    private var activity: Activity? = null
    private val TAG = FlutterDocScannerPlugin::class.java.simpleName

    private val REQUEST_CODE_SCAN = 213312
    private val REQUEST_CODE_SCAN_URI = 214412
    private val REQUEST_CODE_SCAN_IMAGES = 215512
    private val REQUEST_CODE_SCAN_PDF = 216612
    private lateinit var resultChannel: MethodChannel.Result


    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else if (call.method == "getScanDocuments") {
            val arguments = call.arguments as? Map<*, *>
            val page = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: 4
            resultChannel = result
            startDocumentScan(page)
        } else if (call.method == "getScannedDocumentAsImages") {
            val arguments = call.arguments as? Map<*, *>
            val page = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: 4
            resultChannel = result
            startDocumentScanImages(page)
        } else if (call.method == "getScannedDocumentAsPdf") {
            val arguments = call.arguments as? Map<*, *>
            val page = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: 4
            resultChannel = result
            startDocumentScanPDF(page)
        } else if (call.method == "getScanDocumentsUri") {
            val arguments = call.arguments as? Map<*, *>
            val page = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: 4
            resultChannel = result
            startDocumentScanUri(page)
        } else {
            result.notImplemented()
        }
    }

    private fun startDocumentScan(page: Int = 4) {
        val options =
            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
                .setResultFormats(
                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
                ).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
        val scanner = GmsDocumentScanning.getClient(options)
        val task: Task<IntentSender>? = activity?.let { scanner.getStartScanIntent(it) }
        task?.addOnSuccessListener { intentSender ->
            val intent = IntentSenderRequest.Builder(intentSender).build().intentSender
            try {

                startIntentSenderForResult(
                    activity!!,
                    intent,
                    REQUEST_CODE_SCAN,
                    null,
                    0,
                    0,
                    0,
                    null
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }?.addOnFailureListener { e ->
            // Handle failure here
        }
    }

    private fun startDocumentScanImages(page: Int = 4) {
        val options =
            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
                .setResultFormats(
                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
                ).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
        val scanner = GmsDocumentScanning.getClient(options)
        val task: Task<IntentSender>? = activity?.let { scanner.getStartScanIntent(it) }
        task?.addOnSuccessListener { intentSender ->
            val intent = IntentSenderRequest.Builder(intentSender).build().intentSender
            try {

                startIntentSenderForResult(
                    activity!!,
                    intent,
                    REQUEST_CODE_SCAN_IMAGES,
                    null,
                    0,
                    0,
                    0,
                    null
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }?.addOnFailureListener { e ->
            // Handle failure here
        }
    }

    private fun startDocumentScanPDF(page: Int = 4) {
        val options =
            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
                .setResultFormats(
                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
                ).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
        val scanner = GmsDocumentScanning.getClient(options)
        val task: Task<IntentSender>? = activity?.let { scanner.getStartScanIntent(it) }
        task?.addOnSuccessListener { intentSender ->
            val intent = IntentSenderRequest.Builder(intentSender).build().intentSender
            try {

                startIntentSenderForResult(
                    activity!!,
                    intent,
                    REQUEST_CODE_SCAN_PDF,
                    null,
                    0,
                    0,
                    0,
                    null
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }?.addOnFailureListener { e ->
            // Handle failure here
        }
    }

    private fun startDocumentScanUri(page: Int = 4) {
        val options =
            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
                .setResultFormats(
                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
                ).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
        val scanner = GmsDocumentScanning.getClient(options)
        val task: Task<IntentSender>? = activity?.let { scanner.getStartScanIntent(it) }
        task?.addOnSuccessListener { intentSender ->
            val intent = IntentSenderRequest.Builder(intentSender).build().intentSender
            try {

                startIntentSenderForResult(
                    activity!!,
                    intent,
                    REQUEST_CODE_SCAN_URI,
                    null,
                    0,
                    0,
                    0,
                    null
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }?.addOnFailureListener { e ->
            // Handle failure here
        }
    }


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_SCAN -> {
                if (resultCode == Activity.RESULT_OK) {
                    val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                    scanningResult?.getPdf()?.let { pdf ->
                        val pdfUri = pdf.getUri()
                        val pageCount = pdf.getPageCount()
                        resultChannel.success(
                            mapOf(
                                "pdfUri" to pdfUri.toString(),
                                "pageCount" to pageCount,
                            )
                        )
                    } ?: resultChannel.error("SCAN_FAILED", "No PDF result returned", null)
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    resultChannel.success(null)
                } else {
                    resultChannel.error("SCAN_FAILED", "Failed to start scanning", null)
                }
            }
            REQUEST_CODE_SCAN_IMAGES -> {
                if (resultCode == Activity.RESULT_OK) {
                    val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                    scanningResult?.getPages()?.let { pages ->
                        resultChannel.success(
                            mapOf(
                                "Uri" to pages.toString(),
                                "Count" to pages.size,
                            )
                        )
                    } ?: resultChannel.error("SCAN_FAILED", "No image results returned", null)
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    resultChannel.success(null)
                }
            }
            REQUEST_CODE_SCAN_PDF -> {
                if (resultCode == Activity.RESULT_OK) {
                    val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                    scanningResult?.getPdf()?.let { pdf ->
                        val pdfUri = pdf.getUri()
                        val pageCount = pdf.getPageCount()
                        resultChannel.success(
                            mapOf(
                                "pdfUri" to pdfUri.toString(),
                                "pageCount" to pageCount,
                            )
                        )
                    } ?: resultChannel.error("SCAN_FAILED", "No PDF result returned", null)
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    resultChannel.success(null)
                }
            }
            REQUEST_CODE_SCAN_URI -> {
                if (resultCode == Activity.RESULT_OK) {
                    val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                    scanningResult?.getPages()?.let { pages ->
                        resultChannel.success(
                            mapOf(
                                "Uri" to pages.toString(),
                                "Count" to pages.size,
                            )
                        )
                    } ?: resultChannel.error("SCAN_FAILED", "No URI results returned", null)
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    resultChannel.success(null)
                }
            }
        }
        return false
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        pluginBinding = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        pluginBinding = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    private fun createPluginSetup(
        messenger: BinaryMessenger,
        applicationContext: Application?,
        activity: Activity,
        activityBinding: ActivityPluginBinding?
    ) {
        this.activity = activity
        this.applicationContext = applicationContext
        channel = MethodChannel(messenger, CHANNEL)
        channel!!.setMethodCallHandler(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addActivityResultListener(this) // Register the plugin as an ActivityResultListener
        createPluginSetup(
            pluginBinding!!.binaryMessenger,
            pluginBinding!!.applicationContext as Application,
            activityBinding!!.activity,
            activityBinding
        )
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this) // Unregister the plugin as an ActivityResultListener
        activityBinding = null

    }
}


//package com.shirsh.flutter_doc_scanner
//
//
//import android.app.Activity
//import android.app.Application
//import android.app.Application.ActivityLifecycleCallbacks
//import android.content.Intent
//import android.content.IntentSender
//import android.os.Bundle
//import android.util.Log
//import androidx.activity.result.IntentSenderRequest
//import androidx.core.app.ActivityCompat.startIntentSenderForResult
//import androidx.lifecycle.DefaultLifecycleObserver
//import androidx.lifecycle.Lifecycle
//import androidx.lifecycle.LifecycleOwner
//import com.google.android.gms.common.api.CommonStatusCodes
//import com.google.android.gms.tasks.Task
//import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
//import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
//import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
//import io.flutter.embedding.engine.plugins.FlutterPlugin
//import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
//import io.flutter.embedding.engine.plugins.activity.ActivityAware
//import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
//import io.flutter.plugin.common.BinaryMessenger
//import io.flutter.plugin.common.EventChannel
//import io.flutter.plugin.common.EventChannel.EventSink
//import io.flutter.plugin.common.EventChannel.StreamHandler
//import io.flutter.plugin.common.MethodCall
//import io.flutter.plugin.common.MethodChannel
//import io.flutter.plugin.common.MethodChannel.MethodCallHandler
//import io.flutter.plugin.common.MethodChannel.Result
//import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
//import io.flutter.plugin.common.PluginRegistry.Registrar
//
//class FlutterDocScannerPlugin : MethodCallHandler, ActivityResultListener,
//    FlutterPlugin, ActivityAware {
//    private var channel: MethodChannel? = null
//    private var pluginBinding: FlutterPluginBinding? = null
//    private var activityBinding: ActivityPluginBinding? = null
//    private var applicationContext: Application? = null
//    private val CHANNEL = "flutter_doc_scanner"
//    private var activity: Activity? = null
//    private val TAG = FlutterDocScannerPlugin::class.java.simpleName
//
//    private val REQUEST_CODE_SCAN = 213312
//    private val REQUEST_CODE_SCAN_URI = 214412
//    private lateinit var resultChannel: MethodChannel.Result
//
//
//    override fun onMethodCall(call: MethodCall, result: Result) {
//        if (call.method == "getPlatformVersion") {
//            result.success("Android ${android.os.Build.VERSION.RELEASE}")
//        } else if (call.method == "getScanDocuments") {
//            val arguments = call.arguments as? Map<*, *>
//            val page = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: 4
//            resultChannel = result
//            startDocumentScan(page)
//        } else if (call.method == "getScanDocumentsUri") {
//            val arguments = call.arguments as? Map<*, *>
//            val page = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: 4
//            resultChannel = result
//            startDocumentScanUri(page)
//        } else {
//            result.notImplemented()
//        }
//    }
//
//    private fun startDocumentScan(page: Int = 4) {
//        val options =
//            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
//                .setResultFormats(
//                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
//                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
//                ).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
//        val scanner = GmsDocumentScanning.getClient(options)
//        val task: Task<IntentSender>? = activity?.let { scanner.getStartScanIntent(it) }
//        task?.addOnSuccessListener { intentSender ->
//            val intent = IntentSenderRequest.Builder(intentSender).build().intentSender
//            try {
//
//                startIntentSenderForResult(
//                    activity!!,
//                    intent,
//                    REQUEST_CODE_SCAN,
//                    null,
//                    0,
//                    0,
//                    0,
//                    null
//                )
//            } catch (e: Exception) {
//                e.printStackTrace()
//            }
//        }?.addOnFailureListener { e ->
//            // Handle failure here
//        }
//    }
//
//    private fun startDocumentScanUri(page: Int = 4) {
//        val options =
//            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
//                .setResultFormats(
//                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
//                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
//                ).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
//        val scanner = GmsDocumentScanning.getClient(options)
//        val task: Task<IntentSender>? = activity?.let { scanner.getStartScanIntent(it) }
//        task?.addOnSuccessListener { intentSender ->
//            val intent = IntentSenderRequest.Builder(intentSender).build().intentSender
//            try {
//
//                startIntentSenderForResult(
//                    activity!!,
//                    intent,
//                    REQUEST_CODE_SCAN_URI,
//                    null,
//                    0,
//                    0,
//                    0,
//                    null
//                )
//            } catch (e: Exception) {
//                e.printStackTrace()
//            }
//        }?.addOnFailureListener { e ->
//            // Handle failure here
//        }
//    }
//
//
//    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
//        if (requestCode == REQUEST_CODE_SCAN && resultCode == Activity.RESULT_OK) {
//            val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
//            scanningResult?.getPdf()?.let { pdf ->
//                val pdfUri = pdf.getUri()
//                val pageCount = pdf.getPageCount()
//                resultChannel.success(
//                    mapOf(
//                        "pdfUri" to pdfUri.toString(),
//                        "pageCount" to pageCount,
//                    )
//                )
//            }
//        } else if (requestCode == REQUEST_CODE_SCAN_URI && resultCode == Activity.RESULT_OK) {
//            val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
//            scanningResult?.getPages()?.let { pages ->
//                resultChannel.success(
//                    mapOf(
//                        "Uri" to pages.toString(),
//                        "Count" to pages.size,
//                    )
//                )
//                return@let true
//            }
//        } else if (requestCode == REQUEST_CODE_SCAN || requestCode == REQUEST_CODE_SCAN_URI) {
//            resultChannel.error("SCAN_FAILED", "Failed to start scanning", null)
//        }
//        return false
//    }
//
//    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
//        pluginBinding = binding
//    }
//
//    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
//        pluginBinding = null
//    }
//
//    override fun onDetachedFromActivityForConfigChanges() {
//        onDetachedFromActivity()
//    }
//
//    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
//        onAttachedToActivity(binding)
//    }
//
//    private fun createPluginSetup(
//        messenger: BinaryMessenger,
//        applicationContext: Application?,
//        activity: Activity,
//        registrar: Registrar?,
//        activityBinding: ActivityPluginBinding?
//    ) {
//        this.activity = activity
//        this.applicationContext = applicationContext
//        channel = MethodChannel(messenger, CHANNEL)
//        channel!!.setMethodCallHandler(this)
//    }
//
//    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
//        activityBinding = binding
//        activityBinding?.addActivityResultListener(this) // Register the plugin as an ActivityResultListener
//        createPluginSetup(
//            pluginBinding!!.binaryMessenger,
//            pluginBinding!!.applicationContext as Application,
//            activityBinding!!.activity,
//            null,
//            activityBinding
//        )
//    }
//
//    override fun onDetachedFromActivity() {
//        activityBinding?.removeActivityResultListener(this) // Unregister the plugin as an ActivityResultListener
//        activityBinding = null
//
//    }
//}