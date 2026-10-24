package ph.daanar.daanar_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ph.daanar/ar")
            .setMethodCallHandler { call, result ->
                if (call.method != "openSceneViewer") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val raw = requireNotNull(call.argument<String>("uri"))
                    result.success(openSceneViewer(raw))
                } catch (error: Exception) {
                    Log.e("DaanAR.AR", "Could not launch AR", error)
                    result.error("AR_LAUNCH_FAILED", error.message, null)
                }
            }
    }

    private fun openSceneViewer(raw: String): Boolean {
        val data = if (raw.startsWith("intent:")) {
            Intent.parseUri(raw, Intent.URI_INTENT_SCHEME).data
        } else Uri.parse(raw)
        require(data != null && data.scheme == "https" && data.host == "arvr.google.com" &&
            data.path?.startsWith("/scene-viewer/") == true) { "Invalid AR viewer URL" }

        val modelUrl = requireNotNull(data.getQueryParameter("file")) { "Missing model URL" }
        val model = Uri.parse(modelUrl)
        require(model.scheme == "https" && !model.host.isNullOrBlank() &&
            model.userInfo == null && model.path?.endsWith(".glb", ignoreCase = true) == true) {
            "AR needs a public HTTPS GLB model"
        }
        // These public storage files do not need the preview's cache query.
        val modelFile = model.buildUpon().clearQuery().fragment(null).build().toString()
        val viewers = listOf(
            "com.google.android.googlequicksearchbox" to "ar_preferred",
            "com.google.ar.core" to "ar_only",
        )
        for ((pkg, mode) in viewers) {
            val uri = Uri.Builder().scheme("https").authority("arvr.google.com")
                .path("/scene-viewer/1.0")
                .appendQueryParameter("file", modelFile)
                .appendQueryParameter("mode", mode)
                .apply {
                    for (key in listOf("title", "resizable", "enable_vertical_placement")) {
                        data.getQueryParameter(key)?.let { appendQueryParameter(key, it) }
                    }
                }.build()
            try {
                Log.i("DaanAR.AR", "Opening $pkg: $uri")
                // Restore the original native handoff on top of DaanAR. Scene
                // Viewer has no documented activity-result success contract.
                // Do not attach a result request or display a canceled-result dialog.
                startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage(pkg))
                return true
            } catch (error: ActivityNotFoundException) {
                Log.w("DaanAR.AR", "Viewer unavailable: $pkg", error)
            } catch (error: SecurityException) {
                Log.w("DaanAR.AR", "Viewer launch denied: $pkg", error)
            }
        }
        return false
    }
}
