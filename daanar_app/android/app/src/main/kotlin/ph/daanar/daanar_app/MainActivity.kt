package ph.daanar.daanar_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQ_WAYFINDING = 4821
    }

    private var pendingWayfindingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ph.daanar/ar")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNativeArScreen" -> {
                        try {
                            val landmarkId = call.argument<Int>("landmarkId") ?: 0
                            val landmarkName = call.argument<String>("landmarkName") ?: "Landmark"
                            val municipalityName = call.argument<String>("municipalityName") ?: "Pangasinan"
                            val category = call.argument<String>("category") ?: "heritage"
                            val description = call.argument<String>("description") ?: ""
                            val modelUrl = call.argument<String>("modelUrl") ?: ""

                            val intent = Intent(this, ArCoreLandmarkActivity::class.java).apply {
                                putExtra("landmarkId", landmarkId)
                                putExtra("landmarkName", landmarkName)
                                putExtra("municipalityName", municipalityName)
                                putExtra("category", category)
                                putExtra("description", description)
                                putExtra("modelUrl", modelUrl)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            Log.e("DaanAR.AR", "Could not launch ArCoreLandmarkActivity", error)
                            result.error("AR_LAUNCH_FAILED", error.message, null)
                        }
                    }
                    "openSceneViewer" -> {
                        try {
                            val raw = requireNotNull(call.argument<String>("uri"))
                            result.success(openSceneViewer(raw))
                        } catch (error: Exception) {
                            Log.e("DaanAR.AR", "Could not launch AR", error)
                            result.error("AR_LAUNCH_FAILED", error.message, null)
                        }
                    }
                    "isArCoreSupported" -> {
                        result.success(isArCoreSupported())
                    }
                    "openArWayfinding" -> {
                        if (!isArCoreSupported()) {
                            result.success("unsupported")
                            return@setMethodCallHandler
                        }
                        try {
                            pendingWayfindingResult?.success("closed")
                            pendingWayfindingResult = result
                            val route = call.argument<List<Double>>("route") ?: emptyList()
                            val intent = Intent(this, ArWayfindingActivity::class.java).apply {
                                putExtra("stopName", call.argument<String>("stopName") ?: "Destination")
                                putExtra("description", call.argument<String>("description") ?: "")
                                putExtra("instruction", call.argument<String>("instruction") ?: "")
                                putExtra("stopNumber", call.argument<Int>("stopNumber") ?: 1)
                                putExtra("totalStops", call.argument<Int>("totalStops") ?: 1)
                                putExtra("targetLat", call.argument<Double>("targetLat") ?: 0.0)
                                putExtra("targetLng", call.argument<Double>("targetLng") ?: 0.0)
                                call.argument<Double>("userLat")?.let { putExtra("userLat", it) }
                                call.argument<Double>("userLng")?.let { putExtra("userLng", it) }
                                putExtra("route", route.toDoubleArray())
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQ_WAYFINDING)
                        } catch (error: Exception) {
                            pendingWayfindingResult = null
                            Log.e("DaanAR.AR", "Could not launch ArWayfindingActivity", error)
                            result.error("AR_LAUNCH_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isArCoreSupported(): Boolean = try {
        val availability = ArCoreApk.getInstance().checkAvailability(this)
        availability.isSupported ||
            availability == ArCoreApk.Availability.UNKNOWN_CHECKING
    } catch (_: Exception) {
        false
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_WAYFINDING) {
            val outcome = if (resultCode == ArWayfindingActivity.RESULT_ARRIVED) "arrived" else "closed"
            pendingWayfindingResult?.success(outcome)
            pendingWayfindingResult = null
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
