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
import io.flutter.plugin.common.PluginRegistry.Registrar

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
    private lateinit var resultChannel: MethodChannel.Result


    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else if (call.method == "getScanDocuments") {
            resultChannel = result
            startDocumentScan()
        } else if (call.method == "getScanDocumentsUri") {
            resultChannel = result
            startDocumentScanUri()
        } else {
            result.notImplemented()
        }
    }

    private fun startDocumentScan() {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(9)
            .setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF
            )
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
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

    private fun startDocumentScanUri() {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(9)
            .setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF
            )
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
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
        if ((requestCode == REQUEST_CODE_SCAN || requestCode == REQUEST_CODE_SCAN_URI) 
            && resultCode == Activity.RESULT_OK) {
            val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
            
            // Get PDF data
            val pdfUri = scanningResult?.getPdf()?.getUri()?.toString()
            val pageCount = scanningResult?.getPdf()?.getPageCount()
            
            // Get individual page URIs
            val pageUris = scanningResult?.getPages()?.map { page -> 
                page.getImageUri().toString()
            }

            resultChannel.success(
                mapOf(
                    "pdfUri" to pdfUri,
                    "pageCount" to pageCount,
                    "Uri" to pageUris?.joinToString(", "),
                    "Count" to pageUris?.size
                )
            )
            return true
        } else if (requestCode == REQUEST_CODE_SCAN || requestCode == REQUEST_CODE_SCAN_URI) {
            resultChannel.error("SCAN_FAILED", "Failed to start scanning", null)
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
        registrar: Registrar?,
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
            null,
            activityBinding
        )
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this) // Unregister the plugin as an ActivityResultListener
        activityBinding = null

    }
}