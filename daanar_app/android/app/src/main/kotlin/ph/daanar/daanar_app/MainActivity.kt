package ph.daanar.daanar_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val AR_CHANNEL = "ph.daanar/ar"
        private const val SCENE_VIEWER_HOST = "arvr.google.com"
        private const val PKG_GOOGLE_APP = "com.google.android.googlequicksearchbox"
        private const val PKG_ARCORE = "com.google.ar.core"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSceneViewer" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri != null && openSceneViewer(uri))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens Google Scene Viewer (native ARCore view) on top of the app.
     * Accepts the `intent://arvr.google.com/scene-viewer/...` URL produced by
     * <model-viewer>, or a plain https Scene Viewer URL. Only Scene Viewer
     * URLs are allowed so web content can't launch arbitrary intents.
     */
    private fun openSceneViewer(rawUri: String): Boolean {
        val data: Uri = try {
            if (rawUri.startsWith("intent:")) {
                Intent.parseUri(rawUri, Intent.URI_INTENT_SCHEME).data
            } else {
                Uri.parse(rawUri)
            }
        } catch (e: Exception) {
            null
        } ?: return false

        if (data.host != SCENE_VIEWER_HOST) return false

        // Try the Google app first (supports 3D + AR), then Google Play Services
        // for AR, which requires mode=ar_only.
        val attempts = listOf(
            PKG_GOOGLE_APP to data,
            PKG_ARCORE to withQueryParam(data, "mode", "ar_only"),
        )

        for ((pkg, uri) in attempts) {
            val intent = Intent(Intent.ACTION_VIEW, uri).setPackage(pkg)
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // try next package
            }
        }
        return false
    }

    private fun withQueryParam(uri: Uri, key: String, value: String): Uri {
        val builder = uri.buildUpon().clearQuery()
        for (name in uri.queryParameterNames) {
            if (name == key) continue
            for (v in uri.getQueryParameters(name)) builder.appendQueryParameter(name, v)
        }
        builder.appendQueryParameter(key, value)
        return builder.build()
    }
}
