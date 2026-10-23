package ph.daanar.daanar_app

import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    companion object {
        private const val AR_CHANNEL = "ph.daanar/ar"
        private const val TAG = "DaanAR.SceneViewer"
        private const val AR_REQUEST = 7101
        private const val GOOGLE_APP = "com.google.android.googlequicksearchbox"
        private const val ARCORE = "com.google.ar.core"
    }

    private lateinit var arChannel: MethodChannel
    private var pendingLaunch = false
    private var lastModelUrl = ""
    private var lastPackage = ""
    private var lastData: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        arChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CHANNEL)
        arChannel.setMethodCallHandler { call, result ->
            if (call.method != "openSceneViewer") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingLaunch) {
                result.success(true)
                return@setMethodCallHandler
            }
            var modelUrl = "(missing)"
            val data = try {
                val raw = requireNotNull(call.argument<String>("uri")) { "Missing Scene Viewer URI" }
                val parsed = if (raw.startsWith("intent:")) {
                    Intent.parseUri(raw, Intent.URI_INTENT_SCHEME).data
                } else Uri.parse(raw)
                require(parsed != null && parsed.scheme == "https" &&
                    parsed.host == "arvr.google.com" && parsed.path?.startsWith("/scene-viewer/") == true) {
                    "Invalid Scene Viewer endpoint"
                }
                // Decode once; appendQueryParameter re-encodes the entire nested URL.
                modelUrl = parsed.getQueryParameter("file") ?: error("Missing model file URL")
                validateModelUrl(modelUrl)
                parsed
            } catch (e: Exception) {
                report("error", "Invalid AR request: ${e.message}", modelUrl)
                result.success(false)
                return@setMethodCallHandler
            }
            pendingLaunch = true
            lastModelUrl = modelUrl
            report("checking", "Checking anonymous HTTPS model download", modelUrl)
            // Scene Viewer downloads independently of WebView cookies and headers.
            Thread {
                val failure = try {
                    checkModelDownload(modelUrl)
                    null
                } catch (e: Exception) {
                    Log.e(TAG, "Model download failed: $modelUrl", e)
                    "${e.javaClass.simpleName}: ${e.message}"
                }
                runOnUiThread {
                    if (isFinishing || isDestroyed) {
                        pendingLaunch = false
                        result.success(false)
                    } else if (failure != null) {
                        pendingLaunch = false
                        report("error", "Model download failed: $failure", modelUrl)
                        result.success(false)
                    } else {
                        result.success(launchViewer(data))
                    }
                }
            }.start()
        }
    }

    private fun validateModelUrl(value: String) {
        // Android Uri.parse is permissive; reject spaces and malformed escapes
        // before handing a URL to a separate downloader.
        val strictUri = java.net.URI(value)
        require(strictUri.host != null) { "Malformed model URL: $value" }
        val uri = Uri.parse(value)
        val host = uri.host?.lowercase().orEmpty()
        val octets = host.split('.').mapNotNull { it.toIntOrNull() }
        val privateIp = octets.size == 4 && (octets[0] in listOf(0, 10, 127) ||
            (octets[0] == 169 && octets[1] == 254) ||
            (octets[0] == 172 && octets[1] in 16..31) ||
            (octets[0] == 192 && octets[1] == 168))
        require(uri.scheme == "https" && host.contains('.') && !host.contains(':') &&
            host != "localhost" && !host.endsWith(".localhost") &&
            !host.endsWith(".local") && !privateIp && uri.userInfo == null && uri.fragment == null) {
            "Model must use a public HTTPS URL without credentials or a fragment: $value"
        }
        require(uri.path?.endsWith(".glb", ignoreCase = true) == true) {
            "Expected a .glb model URL: $value"
        }
    }

    private fun checkModelDownload(value: String) {
        var current = value
        repeat(6) {
            validateModelUrl(current)
            val connection = URL(current).openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                connection.setRequestProperty("Range", "bytes=0-3")
                val code = connection.responseCode
                Log.i(TAG, "Model HTTP $code, type=${connection.contentType}, URL=$current")
                if (code in listOf(301, 302, 303, 307, 308)) {
                    val location = connection.getHeaderField("Location") ?: error("Redirect missing Location")
                    current = URL(URL(current), location).toString()
                } else {
                    require(code == 200 || code == 206) { "HTTP $code at $current" }
                    val magic = ByteArray(4)
                    connection.inputStream.use { stream ->
                        var count = 0
                        while (count < magic.size) {
                            val read = stream.read(magic, count, magic.size - count)
                            require(read > 0) { "Incomplete GLB header at $current" }
                            count += read
                        }
                    }
                    require(magic.contentEquals(byteArrayOf(0x67, 0x6c, 0x54, 0x46))) {
                        "Response is not a GLB file (type=${connection.contentType}) at $current"
                    }
                    return
                }
            } finally {
                connection.disconnect()
            }
        }
        error("Too many model redirects")
    }

    @Suppress("DEPRECATION")
    private fun launchViewer(data: Uri, googleOnly: Boolean = false): Boolean {
        val packages = if (googleOnly) listOf(GOOGLE_APP) else listOf(ARCORE, GOOGLE_APP)
        for (pkg in packages) {
            // ar_only is for ARCore; the Google app needs ar_preferred.
            val builder = Uri.Builder().scheme("https").authority("arvr.google.com")
                .path("/scene-viewer/1.0")
                .appendQueryParameter("file", lastModelUrl)
                .appendQueryParameter("mode", if (pkg == ARCORE) "ar_only" else "ar_preferred")
            for (key in listOf("title", "resizable", "enable_vertical_placement")) {
                data.getQueryParameter(key)?.let { builder.appendQueryParameter(key, it) }
            }
            val uri = builder.build()
            try {
                lastPackage = pkg
                lastData = data
                pendingLaunch = true
                Log.i(TAG, "Launching package=$pkg intent=$uri model=$lastModelUrl")
                startActivityForResult(Intent(Intent.ACTION_VIEW, uri).setPackage(pkg), AR_REQUEST)
                report("launched", "Opened $pkg", lastModelUrl)
                return true
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "Viewer unavailable: $pkg", e)
            } catch (e: SecurityException) {
                Log.e(TAG, "Viewer launch denied: $pkg", e)
                report("error", "Launch denied for $pkg: ${e.message}", lastModelUrl)
            }
        }
        pendingLaunch = false
        report("error", "No viewer could open. Install/update Google and Google Play Services for AR.", lastModelUrl)
        return false
    }

    @Deprecated("Scene Viewer uses the legacy activity result contract")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != AR_REQUEST) return
        pendingLaunch = false
        @Suppress("DEPRECATION")
        val extras = data?.extras?.let { bundle ->
            bundle.keySet().joinToString { key -> "$key=${bundle.get(key)}" }
        }.orEmpty()
        val message = "Viewer returned from $lastPackage. resultCode=$resultCode, " +
            "data=${data?.data}, extras=$extras. " +
            "A canceled result may mean Back was pressed; Scene Viewer may provide no failure reason."
        report("returned", message, lastModelUrl)
        val retryData = lastData
        AlertDialog.Builder(this)
            .setTitle("AR viewer returned")
            .setMessage("$message\n\nModel URL:\n$lastModelUrl")
            .setPositiveButton("Close", null)
            .apply {
                if (lastPackage == ARCORE && retryData != null) {
                    setNeutralButton("Try Google viewer") { _, _ -> launchViewer(retryData, true) }
                }
            }.show()
    }

    private fun report(status: String, message: String, modelUrl: String) {
        val details = "$message\nModel URL: $modelUrl"
        if (status == "error") Log.e(TAG, details) else Log.i(TAG, details)
        arChannel.invokeMethod("sceneViewerDiagnostic", mapOf(
            "status" to status, "message" to message, "modelUrl" to modelUrl,
        ))
        if (status == "error" || status == "returned") {
            Toast.makeText(this, details, Toast.LENGTH_LONG).show()
        }
    }
}
