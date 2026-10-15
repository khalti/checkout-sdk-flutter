package com.khalti.khalti_checkout_flutter

import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** KhaltiCheckoutFlutterPlugin */
class KhaltiCheckoutFlutterPlugin :
    FlutterPlugin,
    ActivityAware,
    KhaltiNativeApi,
    ActivityResultListener {
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingContinuation: CancellableContinuation<KhaltiAppResult>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        KhaltiNativeApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        KhaltiNativeApi.setUp(binding.binaryMessenger, null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override suspend fun openKhaltiApp(pidx: String): KhaltiAppResult {

        val activity =
            activityBinding?.activity ?: run {
                throw FlutterError("NO_ACTIVITY", "No attached activity", null)
            }

        return suspendCancellableCoroutine { continuation ->
            pendingContinuation = continuation
            val intent =
                Intent(activity, KhaltiProxyActivity::class.java).apply {
                    putExtra(KhaltiProxyActivity.EXTRA_PIDX, pidx)
                }
            activity.startActivityForResult(intent, REQUEST_CODE)
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false

        val continuation = pendingContinuation
        pendingContinuation = null

        when (resultCode) {
            KhaltiProxyActivity.RESULT_APP_NOT_FOUND -> {
                continuation?.resumeWithException(
                    FlutterError("APP_NOT_FOUND", "Khalti app is not installed", null),
                )
            }
            KhaltiProxyActivity.RESULT_MISSING_PIDX -> {
                continuation?.resumeWithException(
                    FlutterError("MISSING_PIDX", "No pidx was passed to the proxy activity", null),
                )
            }
            else -> {
                val result = parseResult(data)
                continuation?.resume(result)
            }
        }
        return true
    }

    /**
     * Builds the result from the Khalti app's `status` extra. A missing or
     * unrecognised status is reported as an error rather than guessed at.
     */
    private fun parseResult(data: Intent?): KhaltiAppResult {
        val message = data?.getStringExtra(EXTRA_REPLY)
        val status =
            when (data?.getStringExtra(EXTRA_STATUS)) {
                "completed" -> KhaltiAppStatus.COMPLETED
                "settled" -> KhaltiAppStatus.SETTLED
                "expired" -> KhaltiAppStatus.EXPIRED
                "error" -> KhaltiAppStatus.ERROR
                "cancelled" -> KhaltiAppStatus.CANCELLED
                else ->
                    return KhaltiAppResult(
                        status = KhaltiAppStatus.ERROR,
                        message = "Khalti app returned a result without a valid status",
                    )
            }
        return KhaltiAppResult(status = status, message = message)
    }

    companion object {
        private const val EXTRA_STATUS = "status"
        private const val EXTRA_REPLY = "reply"
        private const val REQUEST_CODE = 0x4B48
    }
}
