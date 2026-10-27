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
import android.view.ScaleGestureDetector
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
import kotlin.math.atan2
import kotlin.math.hypot

/**
 * Native Kotlin 3D Studio + Google ARCore Instant Placement Activity.
 *
 * Touch Controls:
 * 1. 3D Studio Mode:
 *    - 1-finger drag: Smooth 360° yaw + pitch rotation
 *    - 2-finger pinch: Zoom / scale model smoothly
 *    - 2-finger drag: Pan model
 * 2. ARCore Instant Placement Mode (`Config.InstantPlacementMode.LOCAL_Y_UP`):
 *    - Tap or 1-finger drag (in Move Mode): Slides the 3D landmark smoothly across the floor
 *      in real time using ARCore's `hitTestInstantPlacement` / plane hit-test without recreating
 *      the 3D mesh every frame.
 *    - 1-finger drag (in Rotate Mode) or 2-finger twist (anytime): Rotates the 3D landmark 360°
 *      around its vertical Y-axis (`modelNode.rotation`).
 *    - 2-finger pinch or Scale Slider: Scales the 3D landmark (`0.3x` – `3.0x`).
 */
class ArCoreLandmarkActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "DaanAR.NativeAR"
        private const val REQ_CAMERA = 4102

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

    // 3D Studio Preview View & Transform State
    private var studioSceneView: SceneView? = null
    private var studioModelNode: ModelNode? = null
    private var studioInitialScale: Float3 = Float3(1.0f, 1.0f, 1.0f)
    private var studioYawDeg: Float = 0f
    private var studioPitchDeg: Float = 12f
    private var studioZoomFactor: Float = 1.0f
    private var studioPanX: Float = 0f
    private var studioPanY: Float = 0f

    // Native ARCore View & Transform State
    private var arSceneView: ARSceneView? = null
    private var arAnchorNode: AnchorNode? = null
    private var arModelNode: ModelNode? = null
    private var isArModeActive: Boolean = false
    private var autoPlacedInAr: Boolean = false
    private var baseArScale: Float = 1.15f
    private var initialNodeScale: Float3 = Float3(1.0f, 1.0f, 1.0f)
    private var userScaleMultiplier: Float = 1.0f
    private var arRotationYawDeg: Float = 0f
    // When true: 1-finger drag moves model on floor. When false: 1-finger drag rotates 360°.
    // (2-finger twist and Rotate Slider ALWAYS rotate in both modes!)
    private var arSingleFingerMovesFloor: Boolean = true
    private var lastAnchorRefreshMs: Long = 0L

    // Cached model ByteBuffer so switching between 3D Studio & AR is instantaneous
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
    private lateinit var rotateValueText: TextView
    private lateinit var rotateSeekBar: SeekBar
    private lateinit var modeMoveBtn: Button
    private lateinit var modeRotateBtn: Button
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
            text = "1-finger drag to rotate 360° • Pinch to zoom • 2-finger pan"
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
            background = roundedBg(Color.parseColor("#DF0B1812"), 20, Color.parseColor("#59D4A853"), 1)
            setPadding(dp(14), dp(12), dp(14), dp(12))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
        }

        // Touch Mode Switcher: [ ✥ Drag to Move ]  |  [ ⟳ Drag to Rotate ]
        val modeSwitchRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(10))
        }

        modeMoveBtn = Button(this).apply {
            text = "✥ 1-Finger Move"
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, dp(38), 1f).apply {
                marginEnd = dp(6)
            }
            setOnClickListener {
                setArTouchMode(moveFloor = true)
            }
        }
        modeSwitchRow.addView(modeMoveBtn)

        modeRotateBtn = Button(this).apply {
            text = "⟳ 1-Finger Rotate"
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, dp(38), 1f)
            setOnClickListener {
                setArTouchMode(moveFloor = false)
            }
        }
        modeSwitchRow.addView(modeRotateBtn)
        arControlsCard.addView(modeSwitchRow)

        // Rotate 360° Slider Row
        val rotateRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, dp(6))
        }
        val rotateTitle = TextView(this).apply {
            text = "Rotate"
            setTextColor(Color.parseColor("#D4A853"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(dp(46), ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        rotateRow.addView(rotateTitle)

        rotateSeekBar = SeekBar(this).apply {
            max = 360
            progress = 180
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(6)
                marginEnd = dp(6)
            }
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        arRotationYawDeg = (progress - 180).toFloat()
                        rotateValueText.text = "${arRotationYawDeg.toInt()}°"
                        applyArModelTransform()
                    }
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        rotateRow.addView(rotateSeekBar)

        rotateValueText = TextView(this).apply {
            text = "0°"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(dp(42), ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        rotateRow.addView(rotateValueText)
        arControlsCard.addView(rotateRow)

        // Scale Slider Row
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
            layoutParams = LinearLayout.LayoutParams(dp(46), ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        scaleRow.addView(scaleTitle)

        scaleSeekBar = SeekBar(this).apply {
            max = 270 // 0.3x to 3.0x
            progress = 70 // 1.0x
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(6)
                marginEnd = dp(6)
            }
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        userScaleMultiplier = (progress + 30) / 100f
                        scaleValueText.text = String.format("%.1fx", userScaleMultiplier)
                        applyArModelTransform()
                    }
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
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(dp(42), ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        scaleRow.addView(scaleValueText)
        arControlsCard.addView(scaleRow)

        val arButtonsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val placeCenterBtn = Button(this).apply {
            text = "🎯 Recenter Here"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            background = roundedBg(Color.parseColor("#26FFFFFF"), 14, Color.parseColor("#4DD4A853"), 1)
            layoutParams = LinearLayout.LayoutParams(0, dp(40), 1f).apply {
                marginEnd = dp(8)
            }
            setOnClickListener {
                placeAtScreenCenterInstant(forceRecreate = false)
            }
        }
        arButtonsRow.addView(placeCenterBtn)

        val exitArBtn = Button(this).apply {
            text = "✕ Back to 3D"
            isAllCaps = false
            setTextColor(Color.parseColor("#FFB4B4"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            background = roundedBg(Color.parseColor("#33EF4444"), 14, Color.parseColor("#66EF4444"), 1)
            layoutParams = LinearLayout.LayoutParams(0, dp(40), 1f)
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

        setArTouchMode(moveFloor = true)
        setContentView(rootContainer)
    }

    private fun setArTouchMode(moveFloor: Boolean) {
        arSingleFingerMovesFloor = moveFloor
        if (moveFloor) {
            modeMoveBtn.setTextColor(Color.parseColor("#0B1812"))
            modeMoveBtn.background = roundedBg(Color.parseColor("#D4A853"), 14)
            modeRotateBtn.setTextColor(Color.WHITE)
            modeRotateBtn.background = roundedBg(Color.parseColor("#26FFFFFF"), 14, Color.parseColor("#33FFFFFF"), 1)
            if (isArModeActive) {
                hintPillText.text = "Drag or tap floor to move • Pinch to scale • 2-finger twist to rotate"
            }
        } else {
            modeRotateBtn.setTextColor(Color.parseColor("#0B1812"))
            modeRotateBtn.background = roundedBg(Color.parseColor("#D4A853"), 14)
            modeMoveBtn.setTextColor(Color.WHITE)
            modeMoveBtn.background = roundedBg(Color.parseColor("#26FFFFFF"), 14, Color.parseColor("#33FFFFFF"), 1)
            if (isArModeActive) {
                hintPillText.text = "1-finger drag to rotate 360° • Tap floor to move • Pinch to scale"
            }
        }
    }

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
                    return Pair(patchGlbToMattePbr(input.readBytes()), "OFFLINE READY")
                }
            }
        }

        // 2. Check cached downloads in filesDir/ar_models/ (for newly uploaded admin models)
        val cacheDir = File(filesDir, "ar_models").apply { mkdirs() }
        for (name in candidateNames) {
            val cachedFile = File(cacheDir, name)
            if (cachedFile.exists() && cachedFile.length() > 1024) {
                Log.i(TAG, "Loading locally cached model: ${cachedFile.absolutePath}")
                return Pair(patchGlbToMattePbr(cachedFile.readBytes()), "CACHED OFFLINE")
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
                    return Pair(patchGlbToMattePbr(targetFile.readBytes()), "SYNCED FOR OFFLINE")
                }
            } catch (netErr: Exception) {
                Log.w(TAG, "Network download failed, falling back to any bundled asset", netErr)
            }
        }

        // 4. Final fallback: if URL had a new filename and user is offline, use mapped asset for this landmarkId
        if (mappedFileName.isNotEmpty() && assetList.contains(mappedFileName)) {
            assets.open("models/$mappedFileName").use { input ->
                return Pair(patchGlbToMattePbr(input.readBytes()), "OFFLINE READY")
            }
        }

        return null
    }

    /**
     * Ensures any `.glb` binary (bundled or freshly downloaded from an admin upload) uses standard
     * glTF 2.0 matte PBR (`metallicFactor = 0.0`, `roughnessFactor = 0.85`, keeping `normalTexture`
     * intact and WITHOUT `KHR_materials_unlit`, which causes Filament ubershader errors).
     */
    private fun patchGlbToMattePbr(glb: ByteArray): ByteArray {
        try {
            if (glb.size < 28) return glb
            val headerBuf = ByteBuffer.wrap(glb, 0, 20).order(java.nio.ByteOrder.LITTLE_ENDIAN)
            val magic = headerBuf.int
            val version = headerBuf.int
            val totalLength = headerBuf.int
            val jsonLen = headerBuf.int
            val jsonType = headerBuf.int
            if (magic != 0x46546C67 || version != 2 || jsonLen <= 0 || 20 + jsonLen > glb.size) {
                return glb
            }

            val jsonStr = String(glb, 20, jsonLen, Charsets.UTF_8)
            val root = org.json.JSONObject(jsonStr)

            // Strip KHR_materials_unlit if present so Filament always uses its standard PBR ubershader
            root.remove("extensionsUsed")
            root.remove("extensionsRequired")

            val materials = root.optJSONArray("materials")
            if (materials != null) {
                for (i in 0 until materials.length()) {
                    val mat = materials.optJSONObject(i) ?: continue
                    mat.remove("extensions")
                    val pbr = mat.optJSONObject("pbrMetallicRoughness")
                    if (pbr != null) {
                        pbr.remove("metallicRoughnessTexture")
                        pbr.put("metallicFactor", 0.0)
                        pbr.put("roughnessFactor", 0.85)
                    }
                }
            }

            var newJsonBytes = root.toString().toByteArray(Charsets.UTF_8)
            val pad = (4 - (newJsonBytes.size % 4)) % 4
            if (pad > 0) {
                val padded = ByteArray(newJsonBytes.size + pad)
                System.arraycopy(newJsonBytes, 0, padded, 0, newJsonBytes.size)
                for (i in newJsonBytes.size until padded.size) {
                    padded[i] = 0x20.toByte()
                }
                newJsonBytes = padded
            }

            val binOffset = 20 + jsonLen
            val binLen = glb.size - binOffset
            val newTotalLen = 20 + newJsonBytes.size + binLen
            val out = ByteArray(newTotalLen)
            val outHeader = ByteBuffer.wrap(out, 0, 20).order(java.nio.ByteOrder.LITTLE_ENDIAN)
            outHeader.putInt(0x46546C67)
            outHeader.putInt(2)
            outHeader.putInt(newTotalLen)
            outHeader.putInt(newJsonBytes.size)
            outHeader.putInt(jsonType)

            System.arraycopy(newJsonBytes, 0, out, 20, newJsonBytes.size)
            System.arraycopy(glb, binOffset, out, 20 + newJsonBytes.size, binLen)
            return out
        } catch (e: Exception) {
            Log.w(TAG, "GLB matte PBR patch skipped: ${e.message}")
            return glb
        }
    }

    // =========================================================================
    // 3D STUDIO PREVIEW (WITH CUSTOM 1-FINGER ROTATE + PINCH ZOOM + 2-FINGER PAN)
    // =========================================================================
    private fun startStudio3DPreview(glbBytes: ByteArray) {
        destroyArSceneView()
        destroyStudioSceneView()

        studioYawDeg = 0f
        studioPitchDeg = 12f
        studioZoomFactor = 1.0f
        studioPanX = 0f
        studioPanY = 0f

        val sceneView = SceneView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Natural neutral studio lighting (toned down so 3D Studio is not overly bright)
            indirectLight?.intensity = 30_000f
            mainLightNode?.intensity = 68_000f
            mainLightNode?.lightDirection = Float3(0.0f, -0.35f, -1.0f)
        }
        viewerStageContainer.addView(sceneView)
        studioSceneView = sceneView

        val modelInstance = sceneView.modelLoader.createModelInstance(ByteBuffer.wrap(glbBytes))
        val modelNode = ModelNode(
            modelInstance = modelInstance,
            scaleToUnits = 1.75f,
            centerOrigin = Float3(0.0f, 0.0f, 0.0f)
        )
        forceNonMetallicMaterials(modelNode)
        studioInitialScale = modelNode.scale
        sceneView.addChildNode(modelNode)
        studioModelNode = modelNode

        sceneView.cameraNode.position = Float3(0.0f, 0.35f, 2.55f)
        sceneView.cameraNode.lookAt(Float3(0.0f, 0.0f, 0.0f))
        applyStudioTransform()

        attachStudioTouchController(sceneView)
    }

    private fun applyStudioTransform() {
        val node = studioModelNode ?: return
        node.rotation = Float3(studioPitchDeg, studioYawDeg, 0f)
        node.position = Float3(studioPanX, studioPanY, 0f)
        node.scale = Float3(
            studioInitialScale.x * studioZoomFactor,
            studioInitialScale.y * studioZoomFactor,
            studioInitialScale.z * studioZoomFactor
        )
    }

    private fun attachStudioTouchController(view: View) {
        var prevX = 0f
        var prevY = 0f
        var prevMidX = 0f
        var prevMidY = 0f
        var twoFingerActive = false

        val scaleDetector = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                studioZoomFactor = (studioZoomFactor * detector.scaleFactor).coerceIn(0.35f, 3.8f)
                applyStudioTransform()
                return true
            }
        })

        view.setOnTouchListener { _, event ->
            scaleDetector.onTouchEvent(event)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    prevX = event.x
                    prevY = event.y
                    twoFingerActive = false
                }
                MotionEvent.ACTION_POINTER_DOWN -> {
                    if (event.pointerCount >= 2) {
                        twoFingerActive = true
                        prevMidX = (event.getX(0) + event.getX(1)) * 0.5f
                        prevMidY = (event.getY(0) + event.getY(1)) * 0.5f
                    }
                }
                MotionEvent.ACTION_MOVE -> {
                    if (event.pointerCount >= 2) {
                        twoFingerActive = true
                        val midX = (event.getX(0) + event.getX(1)) * 0.5f
                        val midY = (event.getY(0) + event.getY(1)) * 0.5f
                        val dx = midX - prevMidX
                        val dy = midY - prevMidY
                        studioPanX = (studioPanX + dx * 0.0022f).coerceIn(-1.2f, 1.2f)
                        studioPanY = (studioPanY - dy * 0.0022f).coerceIn(-1.2f, 1.2f)
                        prevMidX = midX
                        prevMidY = midY
                        applyStudioTransform()
                    } else if (!twoFingerActive && event.pointerCount == 1) {
                        val dx = event.x - prevX
                        val dy = event.y - prevY
                        studioYawDeg = (studioYawDeg + dx * 0.45f) % 360f
                        studioPitchDeg = (studioPitchDeg + dy * 0.25f).coerceIn(-45f, 65f)
                        prevX = event.x
                        prevY = event.y
                        applyStudioTransform()
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    twoFingerActive = false
                }
            }
            true
        }
    }

    // =========================================================================
    // NATIVE GOOGLE ARCORE INSTANT PLACEMENT + SMOOTH MOVE / ROTATE / SCALE
    // =========================================================================
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

    private fun enterNativeArCoreMode() {
        if (cachedModelBytes == null) return

        isArModeActive = true
        autoPlacedInAr = false
        userScaleMultiplier = 1.0f
        arRotationYawDeg = 0f
        scaleSeekBar.progress = 70
        scaleValueText.text = "1.0x"
        rotateSeekBar.progress = 180
        rotateValueText.text = "0°"

        launchArButton.visibility = View.GONE
        infoCard.visibility = View.GONE
        arControlsCard.visibility = View.VISIBLE
        setArTouchMode(moveFloor = true)

        destroyStudioSceneView()
        destroyArSceneView()

        val arView = ARSceneView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            planeRenderer.isEnabled = true
            planeRenderer.isVisible = true

            // CRITICAL FIX: By default, ARSceneView creates an empty AR Environment with
            // `indirectLight = null` (expecting ARCore LightEstimator to fill it).
            // By loading `SceneView.createEnvironment(environmentLoader, isOpaque = false)`,
            // ARSceneView receives the exact same `"environments/neutral/neutral_ibl.ktx"`
            // studio image-based lighting as the 3D Studio Preview while keeping a transparent
            // skybox for the AR camera feed!
            lightEstimator = null
            environment = SceneView.createEnvironment(environmentLoader, isOpaque = false)
            indirectLight?.intensity = 30_000f
            mainLightNode?.intensity = 68_000f
            mainLightNode?.lightDirection = Float3(0.0f, -0.35f, -1.0f)

            // Configure ARCore Session with Instant Placement (LOCAL_Y_UP)
            configureSession { session, config ->
                config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
                config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                config.lightEstimationMode = Config.LightEstimationMode.DISABLED
                if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    config.depthMode = Config.DepthMode.AUTOMATIC
                } else {
                    config.depthMode = Config.DepthMode.DISABLED
                }
            }

            onSessionUpdated = { _, frame ->
                // Ensure the neutral studio IBL environment and balanced intensity remain active
                if (indirectLight == null) {
                    environment = SceneView.createEnvironment(environmentLoader, isOpaque = false)
                }
                indirectLight?.intensity = 30_000f
                mainLightNode?.intensity = 68_000f

                // Align the main directional light with the user's camera viewing direction
                // so the front of the 3D landmark facing the user is always evenly lit!
                val zAxis = frame.camera.pose.zAxis
                mainLightNode?.lightDirection = Float3(-zAxis[0], -zAxis[1] - 0.35f, -zAxis[2])

                // Automatically place the landmark ~2.0m in front of the user as soon as ARCore tracks
                if (!autoPlacedInAr && frame.camera.trackingState == TrackingState.TRACKING) {
                    val placed = placeOrMoveModelAtScreenPoint(
                        frame = frame,
                        px = width / 2f,
                        py = height * 0.56f,
                        forceNewAnchor = true
                    )
                    if (placed) {
                        autoPlacedInAr = true
                    }
                }
            }
        }

        attachArTouchController(arView)
        viewerStageContainer.addView(arView)
        arSceneView = arView
    }

    /**
     * Custom multi-touch controller for AR mode:
     * - 2-finger pinch: Scales `userScaleMultiplier` smoothly & updates Scale SeekBar
     * - 2-finger twist: Rotates `arRotationYawDeg` smoothly & updates Rotate SeekBar
     * - 1-finger drag:
     *     - In `Move` mode (`arSingleFingerMovesFloor == true`): smoothly repositions the landmark
     *       along the floor where the user's finger drags!
     *     - In `Rotate` mode (`arSingleFingerMovesFloor == false`): rotates the landmark 360°!
     * - Single tap on floor: Always moves the landmark to the tapped floor point!
     */
    private fun attachArTouchController(arView: ARSceneView) {
        var downX = 0f
        var downY = 0f
        var prevX = 0f
        var prevY = 0f
        var prevTwoFingerAngle: Float? = null
        var multiTouchUsed = false

        val scaleDetector = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                userScaleMultiplier = (userScaleMultiplier * detector.scaleFactor).coerceIn(0.3f, 3.0f)
                scaleSeekBar.progress = ((userScaleMultiplier * 100f).toInt() - 30).coerceIn(0, 270)
                scaleValueText.text = String.format("%.1fx", userScaleMultiplier)
                applyArModelTransform()
                return true
            }
        })

        arView.setOnTouchListener { _, event ->
            scaleDetector.onTouchEvent(event)

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.x
                    downY = event.y
                    prevX = event.x
                    prevY = event.y
                    prevTwoFingerAngle = null
                    multiTouchUsed = false
                }

                MotionEvent.ACTION_POINTER_DOWN -> {
                    if (event.pointerCount >= 2) {
                        multiTouchUsed = true
                        prevTwoFingerAngle = computeAngleDegrees(event)
                    }
                }

                MotionEvent.ACTION_MOVE -> {
                    if (event.pointerCount >= 2) {
                        multiTouchUsed = true
                        val currentAngle = computeAngleDegrees(event)
                        val lastAngle = prevTwoFingerAngle
                        if (lastAngle != null) {
                            var delta = currentAngle - lastAngle
                            if (delta > 180f) delta -= 360f
                            if (delta < -180f) delta += 360f
                            // 2-finger twist rotates model yaw
                            arRotationYawDeg = normalizeYaw(arRotationYawDeg - delta * 1.35f)
                            updateRotateUiFromYaw()
                            applyArModelTransform()
                        }
                        prevTwoFingerAngle = currentAngle
                    } else if (!multiTouchUsed && event.pointerCount == 1) {
                        val dx = event.x - prevX
                        val dy = event.y - prevY
                        prevX = event.x
                        prevY = event.y

                        if (arSingleFingerMovesFloor) {
                            // Dragging finger slides the landmark along the floor in real time
                            val now = System.currentTimeMillis()
                            if (now - lastAnchorRefreshMs >= 32L && hypot(dx, dy) > 1.5f) {
                                lastAnchorRefreshMs = now
                                arView.frame?.let { currentFrame ->
                                    if (currentFrame.camera.trackingState == TrackingState.TRACKING) {
                                        placeOrMoveModelAtScreenPoint(
                                            frame = currentFrame,
                                            px = event.x,
                                            py = event.y,
                                            forceNewAnchor = false
                                        )
                                    }
                                }
                            }
                        } else {
                            // 1-finger drag rotates 360°
                            arRotationYawDeg = normalizeYaw(arRotationYawDeg + dx * 0.55f)
                            updateRotateUiFromYaw()
                            applyArModelTransform()
                        }
                    }
                }

                MotionEvent.ACTION_POINTER_UP -> {
                    prevTwoFingerAngle = null
                }

                MotionEvent.ACTION_UP -> {
                    val totalMove = hypot(event.x - downX, event.y - downY)
                    // Quick tap on the screen always moves the landmark to the tapped spot!
                    if (!multiTouchUsed && totalMove < dp(14)) {
                        arView.frame?.let { currentFrame ->
                            if (currentFrame.camera.trackingState == TrackingState.TRACKING) {
                                placeOrMoveModelAtScreenPoint(
                                    frame = currentFrame,
                                    px = event.x,
                                    py = event.y,
                                    forceNewAnchor = false
                                )
                            }
                        }
                    }
                    prevTwoFingerAngle = null
                }
            }
            true
        }
    }

    private fun computeAngleDegrees(event: MotionEvent): Float {
        val dx = (event.getX(1) - event.getX(0)).toDouble()
        val dy = (event.getY(1) - event.getY(0)).toDouble()
        return Math.toDegrees(atan2(dy, dx)).toFloat()
    }

    private fun normalizeYaw(deg: Float): Float {
        var d = deg % 360f
        if (d > 180f) d -= 360f
        if (d < -180f) d += 360f
        return d
    }

    private fun updateRotateUiFromYaw() {
        rotateValueText.text = "${arRotationYawDeg.toInt()}°"
        rotateSeekBar.progress = (arRotationYawDeg.toInt() + 180).coerceIn(0, 360)
    }

    /**
     * Moves or creates the ARCore anchor at screen coordinate `(px, py)` WITHOUT destroying/recreating
     * the `ModelNode` if it already exists—making floor dragging fast and lag-free!
     */
    private fun placeOrMoveModelAtScreenPoint(
        frame: Frame,
        px: Float,
        py: Float,
        forceNewAnchor: Boolean
    ): Boolean {
        val arView = arSceneView ?: return false
        val bytes = cachedModelBytes ?: return false

        // 1. Prefer horizontal plane hit if detected, otherwise InstantPlacementPoint (2.0m)
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

        val existingAnchorNode = arAnchorNode
        val existingModelNode = arModelNode

        // Fast path: if the model is already loaded, simply swap the Anchor on the existing AnchorNode!
        if (!forceNewAnchor && existingAnchorNode != null && existingModelNode != null) {
            try {
                val oldAnchor = existingAnchorNode.anchor
                existingAnchorNode.anchor = newAnchor
                oldAnchor?.detach()
                applyArModelTransform()
                return true
            } catch (e: Exception) {
                Log.w(TAG, "Fallback to recreating AnchorNode", e)
            }
        }

        // First-time creation (or forced reset)
        existingAnchorNode?.let { oldNode ->
            arView.removeChildNode(oldNode)
            try {
                oldNode.destroy()
            } catch (_: Exception) {}
        }

        val anchorNode = AnchorNode(arView.engine, newAnchor)
        val modelInstance = arView.modelLoader.createModelInstance(ByteBuffer.wrap(bytes))

        baseArScale = 1.15f
        val modelNode = ModelNode(
            modelInstance = modelInstance,
            scaleToUnits = baseArScale,
            centerOrigin = Float3(0.0f, -0.5f, 0.0f)
        )
        forceNonMetallicMaterials(modelNode)
        initialNodeScale = modelNode.scale

        anchorNode.addChildNode(modelNode)
        arView.addChildNode(anchorNode)

        arAnchorNode = anchorNode
        arModelNode = modelNode
        applyArModelTransform()
        return true
    }

    private fun placeAtScreenCenterInstant(forceRecreate: Boolean) {
        val arView = arSceneView ?: return
        val currentFrame = arView.frame ?: return
        if (currentFrame.camera.trackingState == TrackingState.TRACKING) {
            val ok = placeOrMoveModelAtScreenPoint(
                frame = currentFrame,
                px = arView.width / 2f,
                py = arView.height * 0.56f,
                forceNewAnchor = forceRecreate
            )
            if (!ok) {
                Toast.makeText(this, "Point camera slightly downward and tap again", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun applyArModelTransform() {
        val node = arModelNode ?: return
        node.scale = Float3(
            initialNodeScale.x * userScaleMultiplier,
            initialNodeScale.y * userScaleMultiplier,
            initialNodeScale.z * userScaleMultiplier
        )
        node.rotation = Float3(0f, arRotationYawDeg, 0f)
    }

    /**
     * Ensures any loaded glTF/GLB material (including future admin uploads) renders as matte
     * heritage stone/wood (`metallicFactor = 0.0f`, `roughnessFactor = 0.85f`) instead of dark
     * shiny chrome.
     */
    private fun forceNonMetallicMaterials(node: ModelNode) {
        try {
            node.modelInstance.materialInstances.forEach { mat ->
                try {
                    mat.setParameter("metallicFactor", 0.0f)
                } catch (_: Exception) {}
                try {
                    mat.setParameter("roughnessFactor", 0.85f)
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    private fun exitArModeToStudio() {
        isArModeActive = false
        arControlsCard.visibility = View.GONE
        launchArButton.visibility = View.VISIBLE
        infoCard.visibility = View.VISIBLE
        hintPillText.text = "1-finger drag to rotate 360° • Pinch to zoom • 2-finger pan"

        destroyArSceneView()
        cachedModelBytes?.let { startStudio3DPreview(it) }
    }

    private fun resetCurrentView() {
        if (isArModeActive) {
            userScaleMultiplier = 1.0f
            arRotationYawDeg = 0f
            scaleSeekBar.progress = 70
            scaleValueText.text = "1.0x"
            rotateSeekBar.progress = 180
            rotateValueText.text = "0°"
            placeAtScreenCenterInstant(forceRecreate = false)
        } else {
            studioYawDeg = 0f
            studioPitchDeg = 12f
            studioZoomFactor = 1.0f
            studioPanX = 0f
            studioPanY = 0f
            applyStudioTransform()
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
