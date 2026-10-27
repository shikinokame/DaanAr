package ph.daanar.daanar_app

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.InstantPlacementPoint
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import dev.romainguy.kotlin.math.Float3
import io.github.sceneview.SceneView
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer

/**
 * Native Kotlin 3D Studio + Google ARCore Instant Placement Activity.
 *
 * Features:
 * 1. 100% Offline-first 3D Studio Viewer using native Google Filament (`SceneView`):
 *    - Loads bundled `.glb` from `assets/models/<filename>` immediately with zero internet.
 *    - Checks & caches admin-uploaded `.glb` files in `filesDir/ar_models/` so new models
 *      work offline too after their first download.
 * 2. True Google ARCore Instant Placement (`Config.InstantPlacementMode.LOCAL_Y_UP`):
 *    - Tapping "View in your Space (AR)" switches directly to `ARSceneView` inside DaanAR
 *      without ever launching the external Google Search App (`ViewerActivity`).
 *    - Automatically places the 3D landmark in front of the user using ARCore's
 *      `hitTestInstantPlacement` / plane hit-test as soon as the first AR frame is ready,
 *      and lets the user tap anywhere on the floor to move it, pinch/slide to scale it,
 *      and rotate it 360°.
 */
class ArCoreLandmarkActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "DaanAR.NativeAR"
        private const val REQ_CAMERA = 4102

        // Fallback mapping from landmarkId -> bundled asset filename in assets/models/
        private val LANDMARK_ASSET_MAP = mapOf(
            1 to "01M3V1DR3QRRHX25THD630R5G1.glb",  // Old PNR Dagupan/Mayombo (1st) Station
            2 to "01M3V95CJWDJ047YT8SGA7HX4A.glb",  // Santuario de San Juan Evangelista
            3 to "01M5RKFAQ2CDHWE9QCNDK4NC72.glb",  // Minor Basilica of Our Lady of Manaoag
            4 to "01M47XWZY4TBX87KT1E4AHPJ1M.glb",  // McArthur Landing Park / historic
            5 to "01M3W5A4N3MS5H46YRNDJBR324.glb",  // Saint Thomas Aquinas Parish Church
            6 to "01M3W89Y2WAQSZJMPZEFEQSCZB.glb",  // PNR Mangaldan Station
            7 to "01M3R00X2DQCWJJNBWB6KKT984.glb",  // Battle of San Jacinto Monument
            8 to "01M3VY05M15WQGJVXYFV07Z1RW.glb",  // St. Hyacinth Parish Church
            9 to "01M3WF2YSJCQCDZMSVAKBGBQJY.glb",  // Parish of St. Fabian, Pope and Martyr
            10 to "01M3WGHD4YFVX2EHF8ZX5WXY0M.glb", // Old PNR San Fabian Station
            11 to "01M47XWZY4TBX87KT1E4AHPJ1M.glb"
        )
    }

    private var landmarkId: Int = 0
    private var landmarkName: String = "Heritage Landmark"
    private var municipalityName: String = "Pangasinan"
    private var category: String = "Heritage"
    private var description: String = ""
    private var modelUrl: String = ""

    private lateinit var rootContainer: FrameLayout
    private lateinit var viewerStageContainer: FrameLayout

    // 3D Studio Preview View
    private var studioSceneView: SceneView? = null
    private var studioModelNode: ModelNode? = null

    // Native ARCore View
    private var arSceneView: ARSceneView? = null
    private var arAnchorNode: AnchorNode? = null
    private var arModelNode: ModelNode? = null
    private var isArModeActive: Boolean = false
    private var autoPlacedInAr: Boolean = false
    private var baseArScale: Float = 1.0f
    private var initialNodeScale: Float3 = Float3(1.0f, 1.0f, 1.0f)
    private var userScaleMultiplier: Float = 1.0f

    // Cached model ByteBuffer so switching between 3D Studio & AR is instantaneous (0ms)
    private var cachedModelBytes: ByteArray? = null

    // UI Elements
    private lateinit var loadingOverlay: LinearLayout
    private lateinit var loadingStatusText: TextView
    private lateinit var offlineBadgeText: TextView
    private lateinit var hintPillText: TextView
    private lateinit var launchArButton: Button
    private lateinit var arControlsCard: LinearLayout
    private lateinit var infoCard: LinearLayout
    private lateinit var scaleValueText: TextView
    private lateinit var scaleSeekBar: SeekBar
    private var descExpanded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        landmarkId = intent.getIntExtra("landmarkId", 0)
        landmarkName = intent.getStringExtra("landmarkName") ?: "Heritage Landmark"
        municipalityName = intent.getStringExtra("municipalityName") ?: "Pangasinan"
        category = intent.getStringExtra("category") ?: "Heritage"
        description = intent.getStringExtra("description") ?: ""
        modelUrl = intent.getStringExtra("modelUrl") ?: ""

        buildUi()
        load3DModelOfflineFirst()
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()

    private fun roundedBg(
        fillColor: Int,
        cornerDp: Int,
        strokeColor: Int = Color.TRANSPARENT,
        strokeWidthDp: Int = 0
    ): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(cornerDp).toFloat()
            setColor(fillColor)
            if (strokeWidthDp > 0) {
                setStroke(dp(strokeWidthDp), strokeColor)
            }
        }
    }

    private fun buildUi() {
        rootContainer = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0B1812"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // 1. Stage Container (holds SceneView in 3D mode, or ARSceneView in AR mode)
        viewerStageContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        rootContainer.addView(viewerStageContainer)

        // 2. Top Navigation Bar (Back + Landmark Title + Offline Ready Badge + Reset Button)
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(20), dp(16), dp(12))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
            )
        }

        val backBtn = TextView(this).apply {
            text = "←"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = roundedBg(Color.parseColor("#B30B1812"), 22, Color.parseColor("#33FFFFFF"), 1)
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(44))
            setOnClickListener {
                if (isArModeActive) {
                    exitArModeToStudio()
                } else {
                    finish()
                }
            }
        }
        topBar.addView(backBtn)

        val titlePill = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = roundedBg(Color.parseColor("#BF0B1812"), 24, Color.parseColor("#26FFFFFF"), 1)
            setPadding(dp(16), dp(8), dp(16), dp(8))
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(10)
                marginEnd = dp(10)
            }
        }

        val titleText = TextView(this).apply {
            text = landmarkName
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            gravity = Gravity.CENTER
        }
        titlePill.addView(titleText)

        offlineBadgeText = TextView(this).apply {
            text = "${municipalityName.uppercase()} • OFFLINE 3D & AR READY"
            setTextColor(Color.parseColor("#D4A853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        titlePill.addView(offlineBadgeText)
        topBar.addView(titlePill)

        val resetBtn = TextView(this).apply {
            text = "↺"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = roundedBg(Color.parseColor("#B30B1812"), 22, Color.parseColor("#33FFFFFF"), 1)
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(44))
            setOnClickListener {
                resetCurrentView()
            }
        }
        topBar.addView(resetBtn)
        rootContainer.addView(topBar)

        // 3. Interaction Hint Pill under Top Bar
        hintPillText = TextView(this).apply {
            text = "1-finger rotate • Pinch to zoom • 2-finger pan"
            setTextColor(Color.parseColor("#E6FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(dp(16), dp(8), dp(16), dp(8))
            background = roundedBg(Color.parseColor("#B30B1812"), 20, Color.parseColor("#4DD4A853"), 1)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.CENTER_HORIZONTAL
            ).apply {
                topMargin = dp(86)
            }
        }
        rootContainer.addView(hintPillText)

        // 4. Bottom Stack (View in your Space AR button + Landmark Info Card + AR HUD Controls)
        val bottomColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(16), dp(8), dp(16), dp(20))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        }

        // 4A. "View in your Space (AR)" Launch Button (shown in 3D Studio Mode)
        launchArButton = Button(this).apply {
            text = "✨  View in your Space (AR)"
            isAllCaps = false
            setTextColor(Color.parseColor("#0B1812"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.DEFAULT_BOLD
            background = roundedBg(Color.parseColor("#D4A853"), 28, Color.parseColor("#66FFFFFF"), 2)
            setPadding(dp(26), dp(14), dp(26), dp(14))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(14)
            }
            setOnClickListener {
                requestCameraAndStartAr()
            }
        }
        bottomColumn.addView(launchArButton)

        // 4B. ARCore Instant Placement HUD Controls (shown in AR Mode)
        arControlsCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            background = roundedBg(Color.parseColor("#D90B1812"), 20, Color.parseColor("#59D4A853"), 1)
            setPadding(dp(16), dp(14), dp(16), dp(14))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
        }

        val arTopHintRow = TextView(this).apply {
            text = "⚡ ARCore Instant Placement Active — Tap anywhere on floor to move"
            setTextColor(Color.parseColor("#34D399"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(10))
        }
        arControlsCard.addView(arTopHintRow)

        val scaleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, dp(10))
        }
        val scaleTitle = TextView(this).apply {
            text = "Scale"
            setTextColor(Color.parseColor("#D4A853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
        }
        scaleRow.addView(scaleTitle)

        scaleSeekBar = SeekBar(this).apply {
            max = 260 // 0.3x to 2.9x
            progress = 70 // 1.0x
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(10)
                marginEnd = dp(10)
            }
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    userScaleMultiplier = (progress + 30) / 100f
                    scaleValueText.text = String.format("%.1fx", userScaleMultiplier)
                    applyArModelScale()
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        scaleRow.addView(scaleSeekBar)

        scaleValueText = TextView(this).apply {
            text = "1.0x"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
        }
        scaleRow.addView(scaleValueText)
        arControlsCard.addView(scaleRow)

        val arButtonsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val placeCenterBtn = Button(this).apply {
            text = "🎯 Place in Front"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            background = roundedBg(Color.parseColor("#26FFFFFF"), 14, Color.parseColor("#4DD4A853"), 1)
            layoutParams = LinearLayout.LayoutParams(0, dp(42), 1f).apply {
                marginEnd = dp(8)
            }
            setOnClickListener {
                placeAtScreenCenterInstant()
            }
        }
        arButtonsRow.addView(placeCenterBtn)

        val exitArBtn = Button(this).apply {
            text = "✕ Back to 3D"
            isAllCaps = false
            setTextColor(Color.parseColor("#FFB4B4"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            background = roundedBg(Color.parseColor("#33EF4444"), 14, Color.parseColor("#66EF4444"), 1)
            layoutParams = LinearLayout.LayoutParams(0, dp(42), 1f)
            setOnClickListener {
                exitArModeToStudio()
            }
        }
        arButtonsRow.addView(exitArBtn)
        arControlsCard.addView(arButtonsRow)
        bottomColumn.addView(arControlsCard)

        // 4C. Landmark Details Card (shown in 3D Studio Mode)
        infoCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedBg(Color.parseColor("#CC0B1812"), 18, Color.parseColor("#26FFFFFF"), 1)
            setPadding(dp(16), dp(14), dp(16), dp(14))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        val infoHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val badgeView = TextView(this).apply {
            text = category.uppercase()
            setTextColor(Color.parseColor("#D4A853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            background = roundedBg(Color.parseColor("#2EE8A838"), 10, Color.parseColor("#59D4A853"), 1)
            setPadding(dp(10), dp(4), dp(10), dp(4))
        }
        infoHeader.addView(badgeView)

        val tapDetailsHint = TextView(this).apply {
            text = "Tap for details"
            setTextColor(Color.parseColor("#D4A853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        infoHeader.addView(tapDetailsHint)
        infoCard.addView(infoHeader)

        val descTextView = TextView(this).apply {
            text = if (description.isNotBlank()) description else "$landmarkName in $municipalityName, Pangasinan."
            setTextColor(Color.parseColor("#B8CEC2"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(8), 0, 0)
        }
        infoCard.addView(descTextView)
        infoCard.setOnClickListener {
            descExpanded = !descExpanded
            descTextView.maxLines = if (descExpanded) 12 else 2
            tapDetailsHint.text = if (descExpanded) "Tap to collapse" else "Tap for details"
        }
        bottomColumn.addView(infoCard)

        rootContainer.addView(bottomColumn)

        // 5. Loading Overlay
        loadingOverlay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E60B1812"))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        val spinner = ProgressBar(this).apply {
            indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#D4A853"))
        }
        loadingOverlay.addView(spinner)

        val loadingTitle = TextView(this).apply {
            text = "Loading 3D Landmark"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, dp(16), 0, dp(6))
        }
        loadingOverlay.addView(loadingTitle)

        loadingStatusText = TextView(this).apply {
            text = "Preparing offline 3D asset..."
            setTextColor(Color.parseColor("#D4A853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        }
        loadingOverlay.addView(loadingStatusText)
        rootContainer.addView(loadingOverlay)

        setContentView(rootContainer)
    }

    /**
     * Resolves the `.glb` bytes 100% offline-first:
     * 1. Extracts filename from `modelUrl` (e.g., `01M5RKFAQ2CDHWE9QCNDK4NC72.glb`) or falls back to `LANDMARK_ASSET_MAP[landmarkId]`.
     * 2. Checks if that file is bundled in `assets/models/<filename>` -> loads in <50ms with zero internet.
     * 3. Else checks if it was previously downloaded into `filesDir/ar_models/<filename>` -> loads offline.
     * 4. Else downloads from `modelUrl` over HTTPS and saves to `filesDir/ar_models/<filename>` for future offline use.
     */
    private fun load3DModelOfflineFirst() {
        lifecycleScope.launch {
            try {
                loadingOverlay.visibility = View.VISIBLE
                loadingStatusText.text = "Loading offline 3D model..."

                val resolved = withContext(Dispatchers.IO) {
                    resolveModelBytes()
                }

                if (resolved == null) {
                    loadingStatusText.text = "⚠️ 3D model unavailable offline. Connect once to sync."
                    return@launch
                }

                cachedModelBytes = resolved.first
                offlineBadgeText.text = "${municipalityName.uppercase()} • ${resolved.second}"

                startStudio3DPreview(resolved.first)
                loadingOverlay.visibility = View.GONE
            } catch (e: Exception) {
                Log.e(TAG, "Error loading 3D model", e)
                loadingStatusText.text = "⚠️ Failed to load 3D model: ${e.localizedMessage}"
            }
        }
    }

    private fun resolveModelBytes(): Pair<ByteArray, String>? {
        val urlFileName = modelUrl.substringAfterLast('/', "").substringBefore('?').trim()
        val mappedFileName = LANDMARK_ASSET_MAP[landmarkId] ?: ""
        val candidateNames = listOfNotNull(
            urlFileName.takeIf { it.endsWith(".glb", ignoreCase = true) },
            mappedFileName.takeIf { it.isNotEmpty() }
        ).distinct()

        val assetList = try {
            assets.list("models")?.toSet() ?: emptySet()
        } catch (_: Exception) {
            emptySet()
        }

        // 1. Check bundled APK assets first (100% Offline out-of-the-box)
        for (name in candidateNames) {
            if (assetList.contains(name)) {
                Log.i(TAG, "Loading bundled offline asset: models/$name")
                assets.open("models/$name").use { input ->
                    return Pair(input.readBytes(), "OFFLINE READY")
                }
            }
        }

        // 2. Check cached downloads in filesDir/ar_models/ (for newly uploaded admin models)
        val cacheDir = File(filesDir, "ar_models").apply { mkdirs() }
        for (name in candidateNames) {
            val cachedFile = File(cacheDir, name)
            if (cachedFile.exists() && cachedFile.length() > 1024) {
                Log.i(TAG, "Loading locally cached model: ${cachedFile.absolutePath}")
                return Pair(cachedFile.readBytes(), "CACHED OFFLINE")
            }
        }

        // 3. Download from remote URL if online and save to local cache for future offline use
        if (modelUrl.startsWith("http", ignoreCase = true)) {
            try {
                val targetName = urlFileName.ifEmpty { "landmark_${landmarkId}.glb" }
                val targetFile = File(cacheDir, targetName)
                val conn = (URL(modelUrl).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15000
                    readTimeout = 30000
                    instanceFollowRedirects = true
                }
                conn.inputStream.use { input ->
                    FileOutputStream(targetFile).use { output ->
                        input.copyTo(output)
                    }
                }
                if (targetFile.exists() && targetFile.length() > 1024) {
                    return Pair(targetFile.readBytes(), "SYNCED FOR OFFLINE")
                }
            } catch (netErr: Exception) {
                Log.w(TAG, "Network download failed, falling back to any bundled asset", netErr)
            }
        }

        // 4. Final fallback: if URL had a new filename and user is offline, use mapped asset for this landmarkId
        if (mappedFileName.isNotEmpty() && assetList.contains(mappedFileName)) {
            assets.open("models/$mappedFileName").use { input ->
                return Pair(input.readBytes(), "OFFLINE READY")
            }
        }

        return null
    }

    /**
     * Renders the interactive 3D Studio View using native Filament (`SceneView`).
     */
    private fun startStudio3DPreview(glbBytes: ByteArray) {
        destroyArSceneView()
        destroyStudioSceneView()

        val sceneView = SceneView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        viewerStageContainer.addView(sceneView)
        studioSceneView = sceneView

        val modelInstance = sceneView.modelLoader.createModelInstance(ByteBuffer.wrap(glbBytes))
        val modelNode = ModelNode(
            modelInstance = modelInstance,
            scaleToUnits = 1.65f,
            centerOrigin = Float3(0.0f, 0.0f, 0.0f)
        ).apply {
            isEditable = true
        }

        sceneView.addChildNode(modelNode)
        studioModelNode = modelNode

        // Position camera slightly above looking at the landmark
        sceneView.cameraNode.position = Float3(0.0f, 0.55f, 2.55f)
        sceneView.cameraNode.lookAt(Float3(0.0f, 0.0f, 0.0f))
    }

    private fun requestCameraAndStartAr() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), REQ_CAMERA)
            return
        }
        enterNativeArCoreMode()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                enterNativeArCoreMode()
            } else {
                Toast.makeText(
                    this,
                    "Camera permission is required for View in your Space (AR).",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    /**
     * Switches from the 3D Studio Preview into Native Kotlin Google ARCore mode with
     * `Config.InstantPlacementMode.LOCAL_Y_UP` enabled!
     */
    private fun enterNativeArCoreMode() {
        val bytes = cachedModelBytes ?: return

        isArModeActive = true
        autoPlacedInAr = false
        userScaleMultiplier = 1.0f
        scaleSeekBar.progress = 70
        scaleValueText.text = "1.0x"

        launchArButton.visibility = View.GONE
        infoCard.visibility = View.GONE
        arControlsCard.visibility = View.VISIBLE
        hintPillText.text = "Tap floor to reposition • Pinch/Slider to scale • 2-finger rotate"

        destroyStudioSceneView()
        destroyArSceneView()

        val arView = ARSceneView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            planeRenderer.isEnabled = true
            planeRenderer.isVisible = true

            // Configure ARCore Session with Instant Placement (LOCAL_Y_UP)
            configureSession { session, config ->
                config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
                config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    config.depthMode = Config.DepthMode.AUTOMATIC
                } else {
                    config.depthMode = Config.DepthMode.DISABLED
                }
            }

            onSessionUpdated = { session, frame ->
                // Instant Placement: As soon as ARCore is tracking, automatically place
                // the landmark ~2.0m in front of the user so they never wait for floor scanning!
                if (!autoPlacedInAr && frame.camera.trackingState == TrackingState.TRACKING) {
                    val placed = performInstantOrPlanePlacement(
                        session = session,
                        frame = frame,
                        px = width / 2f,
                        py = height * 0.58f
                    )
                    if (placed) {
                        autoPlacedInAr = true
                    }
                }
            }

            // Allow single-tap on floor to reposition the landmark instantly via ARCore hitTestInstantPlacement
            onTouchEvent = { e: MotionEvent, _ ->
                if (e.action == MotionEvent.ACTION_UP && e.pointerCount == 1) {
                    val currentSession = session
                    val currentFrame = frame
                    if (currentSession != null && currentFrame != null &&
                        currentFrame.camera.trackingState == TrackingState.TRACKING
                    ) {
                        performInstantOrPlanePlacement(
                            session = currentSession,
                            frame = currentFrame,
                            px = e.x,
                            py = e.y
                        )
                    }
                }
                false
            }
        }

        viewerStageContainer.addView(arView)
        arSceneView = arView
    }

    /**
     * Uses ARCore's `frame.hitTestInstantPlacement(px, py, 2.0f)` (or horizontal plane hit-test)
     * to immediately anchor the 3D landmark in real 3D world space without waiting for floor scanning.
     */
    private fun performInstantOrPlanePlacement(
        session: Session,
        frame: Frame,
        px: Float,
        py: Float
    ): Boolean {
        val arView = arSceneView ?: return false
        val bytes = cachedModelBytes ?: return false

        // 1. Prefer real horizontal plane hit if already detected, else use InstantPlacementPoint
        val planeHit: HitResult? = frame.hitTest(px, py).firstOrNull { hit ->
            val trackable = hit.trackable
            (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose) &&
                    trackable.type == Plane.Type.HORIZONTAL_UPWARD_FACING) ||
                    (trackable is Point && trackable.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL)
        }

        val targetHit: HitResult = planeHit
            ?: frame.hitTestInstantPlacement(px, py, 2.0f).firstOrNull { hit ->
                hit.trackable is InstantPlacementPoint
            }
            ?: return false

        val newAnchor = try {
            targetHit.createAnchor()
        } catch (e: Exception) {
            Log.w(TAG, "Could not create ARCore anchor", e)
            return false
        }

        // Remove previous anchor node if moving
        arAnchorNode?.let { oldAnchor ->
            arView.removeChildNode(oldAnchor)
            oldAnchor.destroy()
        }

        val anchorNode = AnchorNode(arView.engine, newAnchor)
        val modelInstance = arView.modelLoader.createModelInstance(ByteBuffer.wrap(bytes))

        baseArScale = 1.15f
        val modelNode = ModelNode(
            modelInstance = modelInstance,
            scaleToUnits = baseArScale,
            // Place bottom of model flush on the floor anchor
            centerOrigin = Float3(0.0f, -0.5f, 0.0f)
        ).apply {
            isEditable = true
        }
        initialNodeScale = modelNode.scale
        modelNode.scale = Float3(
            initialNodeScale.x * userScaleMultiplier,
            initialNodeScale.y * userScaleMultiplier,
            initialNodeScale.z * userScaleMultiplier
        )

        anchorNode.addChildNode(modelNode)
        arView.addChildNode(anchorNode)

        arAnchorNode = anchorNode
        arModelNode = modelNode
        return true
    }

    private fun placeAtScreenCenterInstant() {
        val arView = arSceneView ?: return
        val currentSession = arView.session ?: return
        val currentFrame = arView.frame ?: return
        if (currentFrame.camera.trackingState == TrackingState.TRACKING) {
            val ok = performInstantOrPlanePlacement(
                session = currentSession,
                frame = currentFrame,
                px = arView.width / 2f,
                py = arView.height * 0.58f
            )
            if (!ok) {
                Toast.makeText(this, "Point camera slightly downward and tap again", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun applyArModelScale() {
        val node = arModelNode ?: return
        node.scale = Float3(
            initialNodeScale.x * userScaleMultiplier,
            initialNodeScale.y * userScaleMultiplier,
            initialNodeScale.z * userScaleMultiplier
        )
    }

    private fun exitArModeToStudio() {
        isArModeActive = false
        arControlsCard.visibility = View.GONE
        launchArButton.visibility = View.VISIBLE
        infoCard.visibility = View.VISIBLE
        hintPillText.text = "1-finger rotate • Pinch to zoom • 2-finger pan"

        destroyArSceneView()
        cachedModelBytes?.let { startStudio3DPreview(it) }
    }

    private fun resetCurrentView() {
        if (isArModeActive) {
            userScaleMultiplier = 1.0f
            scaleSeekBar.progress = 70
            scaleValueText.text = "1.0x"
            placeAtScreenCenterInstant()
        } else {
            cachedModelBytes?.let { startStudio3DPreview(it) }
        }
    }

    private fun destroyStudioSceneView() {
        studioModelNode = null
        studioSceneView?.let { view ->
            viewerStageContainer.removeView(view)
            try {
                view.destroy()
            } catch (_: Exception) {}
        }
        studioSceneView = null
    }

    private fun destroyArSceneView() {
        arModelNode = null
        arAnchorNode = null
        arSceneView?.let { view ->
            viewerStageContainer.removeView(view)
            try {
                view.destroy()
            } catch (_: Exception) {}
        }
        arSceneView = null
    }

    override fun onBackPressed() {
        if (isArModeActive) {
            exitArModeToStudio()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        destroyArSceneView()
        destroyStudioSceneView()
        super.onDestroy()
    }
}

