package com.khalti.khalti_checkout_flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts

/**
 * Transparent, single-use activity that launches the native Khalti app and
 * reports back how it finished (or whether it exists at all).
 *
 * It exists only because [ComponentActivity.registerForActivityResult] must
 * be called before the owning activity reaches STARTED -- a constraint the
 * plugin's long-lived host activity has always already violated by the time
 * a Flutter plugin attaches to it. A freshly created activity like this one
 * can always register in time, in its own onCreate, so the Khalti app launch
 * is delegated here instead.
 */
class KhaltiProxyActivity : ComponentActivity() {
    private val launcher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            setResult(result.resultCode, result.data)
            finish()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val pidx = intent.getStringExtra(EXTRA_PIDX)
        if (pidx == null) {
            setResult(RESULT_MISSING_PIDX)
            finish()
            return
        }

        val deepLink = "$KHALTI_DEEP_LINK_BASE_URL?t=intent-pay&pidx=$pidx"

        val khaltiIntent =
            Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(deepLink)
                setClassName(KHALTI_PACKAGE, KHALTI_ACTIVITY)
            }

        try {
            launcher.launch(khaltiIntent)
        } catch (e: ActivityNotFoundException) {
            setResult(RESULT_APP_NOT_FOUND)
            finish()
        }
    }

    companion object {
        const val EXTRA_PIDX = "pidx"
        const val RESULT_APP_NOT_FOUND = Activity.RESULT_FIRST_USER
        const val RESULT_MISSING_PIDX = Activity.RESULT_FIRST_USER + 1
        private const val KHALTI_PACKAGE = "com.khalti"
        private const val KHALTI_ACTIVITY = "com.khalti.MainActivity"
        private const val KHALTI_DEEP_LINK_BASE_URL = "https://khalti.com/go/"
    }
}
