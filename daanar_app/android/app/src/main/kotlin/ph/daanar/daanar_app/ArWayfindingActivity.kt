package ph.daanar.daanar_app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.SystemClock
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.Config
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import dev.romainguy.kotlin.math.Float3
import io.github.sceneview.SceneView
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.node.ModelNode
import java.nio.ByteBuffer
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * World-anchored ARCore Wayfinding Activity (inspired by campus AR wayfinder reference):
 *  - Places 3D red ground arrows (`models/nav/nav_arrow.glb`) in real ARCore world space
 *    every ~2.4 m along the route so the user physically walks past each arrow.
 *  - Places a 3D red destination pin (`models/nav/nav_pin.glb`) standing on the ground at
 *    the landmark stop.
 *  - Displays green corner reticles, top destination/distance card, live route mini-map,
 *    "Stabilizing AR… / GPS accuracy" calibration card, and Exit / Map / Info / Arrived bar.
 */
class ArWayfindingActivity : AppCompatActivity(), SensorEventListener, LocationListener {

    companion object {
        private const val TAG = "DaanAR.Wayfind"
        const val RESULT_ARRIVED = 101
        private const val REQ_PERMS = 7311

        private const val ARROW_COUNT = 10
        private const val ARROW_SPACING_M = 2.4
        private const val ARROW_SIZE_M = 0.82f
        private const val PIN_SIZE_M = 1.45f
        private const val PIN_SHOW_WITHIN_M = 75.0
        private const val ARRIVE_RADIUS_M = 20.0
        private const val MAX_FIX_ACCURACY_M = 35f
        private const val STABILIZE_TARGET_SEC = 5

        private const val COLOR_INK = 0xE612301F.toInt()
        private const val COLOR_BRASS = 0xFFD4A853.toInt()
        private const val COLOR_IVORY = 0xFFFBF8F1.toInt()
        private const val COLOR_RETICLE = 0xCC2EE585.toInt()
    }

    // ── Intent data ────────────────────────────────────────────────────────────
    private lateinit var stopName: String
    private var stopDescription: String = ""
    private var nextInstruction: String = ""
    private var stopNumber = 1
    private var totalStops = 1
    private var targetLat = 0.0
    private var targetLng = 0.0
    private var seedUserLat = Double.NaN
    private var seedUserLng = Double.NaN
    private var routeLatLng: DoubleArray = DoubleArray(0)

    // ── AR scene ───────────────────────────────────────────────────────────────
    private var arView: ARSceneView? = null
    private val arrowNodes = mutableListOf<ModelNode>()
    private var pinNode: ModelNode? = null
    private var camX = 0f
    private var camY = 0f
    private var camZ = 0f
    private var camFwdX = 0f
    private var camFwdZ = -1f
    private var cameraTracking = false
    private var floorY: Float? = null
    private var frameCounter = 0

    // ── Compass → AR yaw alignment ─────────────────────────────────────────────
    private var sensorManager: SensorManager? = null
    private var deviceHeadingDeg = Double.NaN
    private var declinationDeg = 0f
    private var yawSin = 0.0
    private var yawCos = 0.0
    private var yawSamples = 0
    private val rotMatrix = FloatArray(9)

    // ── GPS → AR position alignment ────────────────────────────────────────────
    private var locationManager: LocationManager? = null
    private var lastFix: Location? = null
    private var originLat = Double.NaN
    private var originLng = Double.NaN
    private var originArX = Double.NaN
    private var originArZ = Double.NaN
    private var baseRouteEnu: List<DoubleArray> = emptyList()
    private var activeRouteEnu: List<DoubleArray> = emptyList()
    private var activeRouteCum: DoubleArray = DoubleArray(0)

    // ── State ──────────────────────────────────────────────────────────────────
    private var stabilized = false
    private var stabilizeStartMs = 0L
    private var arStarted = false
    private var miniMapState = 1 // 0 = hidden, 1 = compact, 2 = expanded

    // ── UI ─────────────────────────────────────────────────────────────────────
    private lateinit var root: FrameLayout
    private lateinit var titleText: TextView
    private lateinit var distanceText: TextView
    private lateinit var hintText: TextView
    private lateinit var stabilizeCard: LinearLayout
    private lateinit var stabilizeTitleText: TextView
    private lateinit var stabilizeSubText: TextView
    private lateinit var miniMapView: RouteMiniMapView
    private lateinit var arrivedButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stopName = intent.getStringExtra("stopName") ?: "Destination"
        stopDescription = intent.getStringExtra("description") ?: ""
        nextInstruction = intent.getStringExtra("instruction") ?: ""
        stopNumber = intent.getIntExtra("stopNumber", 1)
        totalStops = intent.getIntExtra("totalStops", 1)
        targetLat = intent.getDoubleExtra("targetLat", 0.0)
        targetLng = intent.getDoubleExtra("targetLng", 0.0)
        seedUserLat = intent.getDoubleExtra("userLat", Double.NaN)
        seedUserLng = intent.getDoubleExtra("userLng", Double.NaN)
        routeLatLng = intent.getDoubleArrayExtra("route") ?: DoubleArray(0)

        sensorManager = getSystemService(SENSOR_SERVICE) as? SensorManager
        locationManager = getSystemService(LOCATION_SERVICE) as? LocationManager

        buildUi()

        val missing = listOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION)
            .filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) startEverything()
        else ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQ_PERMS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_PERMS) return
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startEverything()
        } else {
            stabilizeTitleText.text = "Permissions Required"
            stabilizeSubText.text = "Camera and GPS permissions are needed for AR wayfinding."
        }
    }

    private fun startEverything() {
        if (arStarted) return
        arStarted = true
        stabilizeStartMs = SystemClock.elapsedRealtime()

        // Seed immediate GPS position from Flutter if available so indoors / slow GPS never blocks
        if (!seedUserLat.isNaN() && !seedUserLng.isNaN() &&
            (abs(seedUserLat) > 0.001 || abs(seedUserLng) > 0.001)
        ) {
            val seeded = Location("flutter_seed").apply {
                latitude = seedUserLat
                longitude = seedUserLng
                accuracy = 12f
                time = System.currentTimeMillis()
            }
            onLocationChanged(seeded)
        }

        startLocation()
        startArScene()
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // UI
    // ═══════════════════════════════════════════════════════════════════════════

    private fun dp(v: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).roundToInt()

    private fun panelBg(fill: Int, stroke: Int = COLOR_BRASS, radius: Int = 10): GradientDrawable =
        GradientDrawable().apply {
            setColor(fill)
            cornerRadius = dp(radius).toFloat()
            setStroke(dp(1), (stroke and 0x00FFFFFF) or 0x77000000)
        }

    private fun label(size: Float, color: Int, bold: Boolean = false): TextView =
        TextView(this).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            setTextColor(color)
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }

        // 1. Green AR Corner Reticle Brackets (matching reference video)
        val reticleView = CornerReticleOverlay(this)
        root.addView(
            reticleView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        // 2. Top Header Row: Back | Destination + Distance Pill | Recalibrate
        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val backBtn = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_revert)
            setColorFilter(COLOR_IVORY)
            background = panelBg(COLOR_INK, radius = 22)
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        }
        topRow.addView(backBtn, LinearLayout.LayoutParams(dp(42), dp(42)))

        val banner = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = panelBg(0xCC162920.toInt(), COLOR_RETICLE, radius = 14)
            setPadding(dp(14), dp(8), dp(14), dp(8))
        }
        titleText = label(17f, Color.WHITE, bold = true).apply {
            text = stopName
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            gravity = Gravity.CENTER
        }
        banner.addView(titleText)
        distanceText = label(14f, COLOR_BRASS, bold = true).apply {
            text = "Locating…"
            gravity = Gravity.CENTER
        }
        banner.addView(distanceText)
        topRow.addView(
            banner,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                setMargins(dp(10), 0, dp(10), 0)
            }
        )

        val recalibBtn = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_popup_sync)
            setColorFilter(COLOR_BRASS)
            background = panelBg(COLOR_INK, radius = 22)
            contentDescription = "Recalibrate AR"
            setOnClickListener { recalibrate() }
        }
        topRow.addView(recalibBtn, LinearLayout.LayoutParams(dp(42), dp(42)))

        root.addView(
            topRow,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
            ).apply { setMargins(dp(14), dp(42), dp(14), 0) }
        )

        // 3. Floating Route Mini-Map (top-right below header, tap to expand/collapse)
        miniMapView = RouteMiniMapView(this).apply {
            setOnClickListener { toggleMiniMap() }
        }
        root.addView(
            miniMapView,
            FrameLayout.LayoutParams(dp(118), dp(118), Gravity.TOP or Gravity.END).apply {
                setMargins(0, dp(108), dp(16), 0)
            }
        )

        // 4. Turn Hint Pill (top-left / center when turning needed)
        hintText = label(12.5f, COLOR_IVORY, bold = true).apply {
            background = panelBg(COLOR_INK, radius = 18)
            setPadding(dp(14), dp(6), dp(14), dp(6))
            visibility = View.GONE
        }
        root.addView(
            hintText,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START
            ).apply { setMargins(dp(16), dp(112), 0, 0) }
        )

        // 5. Center "Stabilizing AR…" Card (matching TikTok video popup)
        stabilizeCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = panelBg(0xF20D261A.toInt(), COLOR_RETICLE, radius = 14)
            setPadding(dp(24), dp(22), dp(24), dp(22))
        }
        stabilizeCard.addView(
            ProgressBar(this).apply {
                indeterminateTintList = android.content.res.ColorStateList.valueOf(COLOR_RETICLE)
            },
            LinearLayout.LayoutParams(dp(44), dp(44))
        )
        stabilizeTitleText = label(15f, Color.WHITE, bold = true).apply {
            gravity = Gravity.CENTER
            text = "Stabilizing AR… 1/${STABILIZE_TARGET_SEC}s"
            setPadding(0, dp(14), 0, 0)
            setTypeface(typeface, Typeface.BOLD_ITALIC)
        }
        stabilizeCard.addView(stabilizeTitleText)
        stabilizeSubText = label(13f, 0xFFD0E8DA.toInt()).apply {
            gravity = Gravity.CENTER
            text = "GPS accuracy: searching…\nPoint camera along the walkway"
            setPadding(0, dp(6), 0, 0)
        }
        stabilizeCard.addView(stabilizeSubText)
        root.addView(
            stabilizeCard,
            FrameLayout.LayoutParams(
                dp(276),
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        )

        // 6. Bottom Bar: Exit | Map | Information | Arrived
        val bottomDock = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = panelBg(0xEB0E1713.toInt(), stroke = 0x55FFFFFF, radius = 12)
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }
        fun dockBtn(title: String, fill: Int, fg: Int, onClick: () -> Unit) =
            Button(this).apply {
                text = title
                isAllCaps = false
                setTextColor(fg)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
                setTypeface(typeface, Typeface.BOLD)
                background = panelBg(fill, stroke = fill, radius = 8)
                setPadding(dp(4), dp(2), dp(4), dp(2))
                setOnClickListener { onClick() }
            }

        fun dockParams(weight: Float = 1f) =
            LinearLayout.LayoutParams(0, dp(48), weight).apply {
                setMargins(dp(4), 0, dp(4), 0)
            }

        bottomDock.addView(
            dockBtn("« Exit", 0xFF5D2626.toInt(), 0xFFFFB4B4.toInt()) {
                setResult(RESULT_CANCELED)
                finish()
            },
            dockParams()
        )
        bottomDock.addView(
            dockBtn("Map", 0xFF3A353B.toInt(), 0xFFE2DCE5.toInt()) {
                toggleMiniMap()
            },
            dockParams(0.85f)
        )
        bottomDock.addView(
            dockBtn("Info", 0xFF23471C.toInt(), 0xFFB8E994.toInt()) {
                showStopInfoDialog()
            },
            dockParams(0.85f)
        )
        arrivedButton = dockBtn("✓ Arrived", 0xFF1B4332.toInt(), COLOR_IVORY) {
            setResult(RESULT_ARRIVED)
            finish()
        }
        bottomDock.addView(arrivedButton, dockParams(1.1f))

        root.addView(
            bottomDock,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            ).apply { setMargins(dp(12), 0, dp(12), dp(24)) }
        )

        setContentView(root)
    }

    private fun toggleMiniMap() {
        miniMapState = (miniMapState + 1) % 3
        when (miniMapState) {
            0 -> miniMapView.visibility = View.GONE
            1 -> {
                miniMapView.visibility = View.VISIBLE
                miniMapView.layoutParams = (miniMapView.layoutParams as FrameLayout.LayoutParams).apply {
                    width = dp(118)
                    height = dp(118)
                }
            }
            2 -> {
                miniMapView.visibility = View.VISIBLE
                miniMapView.layoutParams = (miniMapView.layoutParams as FrameLayout.LayoutParams).apply {
                    width = dp(200)
                    height = dp(200)
                }
            }
        }
        miniMapView.invalidate()
    }

    private fun showStopInfoDialog() {
        val distStr = distanceText.text?.toString() ?: ""
        val msg = buildString {
            append("Stop $stopNumber of $totalStops • $distStr\n\n")
            if (nextInstruction.isNotBlank()) {
                append("Direction: $nextInstruction\n\n")
            }
            if (stopDescription.isNotBlank()) {
                append(stopDescription)
            } else {
                append("Follow the 3D red ground arrows along the walkway toward $stopName. A 3D red pin marks the destination when you approach.")
            }
        }
        AlertDialog.Builder(this)
            .setTitle(stopName)
            .setMessage(msg)
            .setPositiveButton("Close", null)
            .setNeutralButton("Recalibrate AR") { _, _ -> recalibrate() }
            .show()
    }

    private fun recalibrate() {
        yawSin = 0.0
        yawCos = 0.0
        yawSamples = 0
        originArX = Double.NaN
        originArZ = Double.NaN
        floorY = null
        stabilized = false
        stabilizeStartMs = SystemClock.elapsedRealtime()
        stabilizeCard.visibility = View.VISIBLE
        arView?.planeRenderer?.isVisible = true
        arrowNodes.forEach { it.isVisible = false }
        pinNode?.isVisible = false
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARCore Scene & 3D Navigation Models
    // ═══════════════════════════════════════════════════════════════════════════

    private fun startArScene() {
        val view = ARSceneView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            planeRenderer.isEnabled = true
            planeRenderer.isVisible = true
            lightEstimator = null
            environment = SceneView.createEnvironment(environmentLoader, isOpaque = false)
            indirectLight?.intensity = 32_000f
            mainLightNode?.intensity = 75_000f

            configureSession { session, config ->
                config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                config.lightEstimationMode = Config.LightEstimationMode.DISABLED
                config.focusMode = Config.FocusMode.AUTO
                config.depthMode = if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    Config.DepthMode.AUTOMATIC
                } else {
                    Config.DepthMode.DISABLED
                }
            }
            onSessionUpdated = { session, frame ->
                if (indirectLight == null) {
                    environment = SceneView.createEnvironment(environmentLoader, isOpaque = false)
                }
                indirectLight?.intensity = 32_000f
                mainLightNode?.intensity = 75_000f
                val zAxis = frame.camera.pose.zAxis
                mainLightNode?.lightDirection = Float3(-zAxis[0], -zAxis[1] - 0.6f, -zAxis[2])
                onArFrame(session, frame)
            }
        }
        root.addView(view, 0)
        arView = view

        try {
            val arrowBytes = assets.open("models/nav/nav_arrow.glb").use { it.readBytes() }
            val pinBytes = assets.open("models/nav/nav_pin.glb").use { it.readBytes() }

            repeat(ARROW_COUNT) {
                val instance = view.modelLoader.createModelInstance(ByteBuffer.wrap(arrowBytes))
                val node = ModelNode(
                    modelInstance = instance,
                    scaleToUnits = ARROW_SIZE_M,
                    centerOrigin = Float3(0f, -1f, 0f)
                )
                node.isVisible = false
                view.addChildNode(node)
                arrowNodes.add(node)
            }

            val pinInstance = view.modelLoader.createModelInstance(ByteBuffer.wrap(pinBytes))
            pinNode = ModelNode(
                modelInstance = pinInstance,
                scaleToUnits = PIN_SIZE_M,
                centerOrigin = Float3(0f, -1f, 0f)
            ).also {
                it.isVisible = false
                view.addChildNode(it)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not load navigation GLB models", e)
        }
    }

    private fun onArFrame(session: Session, frame: com.google.ar.core.Frame) {
        val camera = frame.camera
        cameraTracking = camera.trackingState == TrackingState.TRACKING
        if (!cameraTracking) {
            if (!stabilized) updateStabilizeText()
            return
        }

        val displayPose = camera.displayOrientedPose
        camX = displayPose.tx()
        camY = displayPose.ty()
        camZ = displayPose.tz()

        // Tilt-compensated forward ray `0.5 * (+Y) - 0.866 * (+Z)` so yaw alignment stays stable
        // whether the user holds the phone upright OR tilts it down toward the walkway!
        val yAx = displayPose.yAxis
        val zAx = displayPose.zAxis
        val fx = 0.5f * yAx[0] - 0.8660254f * zAx[0]
        val fz = 0.5f * yAx[2] - 0.8660254f * zAx[2]
        val horiz = hypot(fx, fz)
        if (horiz > 0.05f) {
            camFwdX = fx / horiz
            camFwdZ = fz / horiz
        }

        if (horiz > 0.25f && !deviceHeadingDeg.isNaN()) {
            val phi = atan2(fx.toDouble(), -fz.toDouble()) - Math.toRadians(deviceHeadingDeg)
            if (!stabilized) {
                yawSin += sin(phi)
                yawCos += cos(phi)
                yawSamples++
            } else {
                val norm = hypot(yawSin, yawCos).coerceAtLeast(1e-6)
                yawSin = 0.996 * (yawSin / norm) + 0.004 * sin(phi)
                yawCos = 0.996 * (yawCos / norm) + 0.004 * cos(phi)
            }
        }

        frameCounter++
        if (frameCounter % 8 == 0) {
            detectFloor(session)
            miniMapView.updateHeading(deviceHeadingDeg)
        }

        if (!stabilized) {
            checkStabilized()
            return
        }
        updateArrowsAndPin()
    }

    private fun detectFloor(session: Session) {
        val target = camY - 1.35f
        val plane = session.getAllTrackables(Plane::class.java)
            .filter {
                it.trackingState == TrackingState.TRACKING &&
                    it.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                    it.subsumedBy == null &&
                    it.centerPose.ty() < camY - 0.45f
            }
            .minByOrNull { abs(it.centerPose.ty() - target) }
        if (plane != null) {
            val y = plane.centerPose.ty()
            floorY = floorY?.let { it * 0.75f + y * 0.25f } ?: y
        }
    }

    private fun checkStabilized() {
        val elapsed = SystemClock.elapsedRealtime() - stabilizeStartMs
        val fix = lastFix
        val ready = cameraTracking && fix != null && yawSamples >= 25 && elapsed >= 3200L
        val fallback = cameraTracking && elapsed >= (STABILIZE_TARGET_SEC * 1000L)
        if (ready || fallback) {
            if (yawSamples == 0) {
                yawCos = 1.0
                yawSin = 0.0
                yawSamples = 1
            }
            if (originLat.isNaN()) {
                // Extreme fallback if neither Flutter seed nor GPS arrived yet
                buildBaseRoute(targetLat - 0.00025, targetLng)
                originArX = camX.toDouble()
                originArZ = camZ.toDouble()
                rebuildActiveRoute(0.0, 0.0)
            } else if (fix != null) {
                applyFixToOrigin(fix, force = true)
            }
            stabilized = true
            stabilizeCard.visibility = View.GONE
            arView?.planeRenderer?.isVisible = false
        } else {
            updateStabilizeText()
        }
    }

    private fun updateStabilizeText() {
        val secs = (((SystemClock.elapsedRealtime() - stabilizeStartMs) / 1000L).toInt() + 1)
            .coerceIn(1, STABILIZE_TARGET_SEC)
        val acc = lastFix?.accuracy?.let { "%.1fm".format(it) } ?: "acquiring…"
        stabilizeTitleText.text = "Stabilizing AR... ${secs}/${STABILIZE_TARGET_SEC}s"
        val tip = when {
            !cameraTracking -> "Move phone gently to scan walkway"
            floorY == null -> "Scanning ground surface…"
            else -> "Locking compass & route alignment…"
        }
        stabilizeSubText.text = "GPS accuracy: $acc\n$tip"
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ENU ↔ AR World Geometry
    // ═══════════════════════════════════════════════════════════════════════════

    private fun yawOffset(): Double = atan2(yawSin, yawCos)

    private fun toEnu(lat: Double, lng: Double): DoubleArray {
        val e = (lng - originLng) * cos(Math.toRadians(originLat)) * 111_320.0
        val n = (lat - originLat) * 110_540.0
        return doubleArrayOf(e, n)
    }

    private fun rotateEnu(e: Double, n: Double): DoubleArray {
        val phi = yawOffset()
        val c = cos(phi)
        val s = sin(phi)
        return doubleArrayOf(e * c + n * s, e * s - n * c)
    }

    private fun enuToAr(p: DoubleArray): DoubleArray {
        val r = rotateEnu(p[0], p[1])
        return doubleArrayOf(originArX + r[0], originArZ + r[1])
    }

    private fun buildBaseRoute(startLat: Double, startLng: Double) {
        originLat = startLat
        originLng = startLng
        val pts = mutableListOf<DoubleArray>()
        if (routeLatLng.size >= 4) {
            var i = 0
            while (i + 1 < routeLatLng.size) {
                pts.add(toEnu(routeLatLng[i], routeLatLng[i + 1]))
                i += 2
            }
        } else {
            pts.add(doubleArrayOf(0.0, 0.0))
        }
        val dest = toEnu(targetLat, targetLng)
        if (pts.isEmpty() || hypot(pts.last()[0] - dest[0], pts.last()[1] - dest[1]) > 2.5) {
            pts.add(dest)
        }
        baseRouteEnu = pts
        rebuildActiveRoute(0.0, 0.0)
    }

    /**
     * Ensures the active route starts near the user even if they begin >12m off the trail
     * polyline, so ground arrows always appear right in front of them on the walkway.
     */
    private fun rebuildActiveRoute(userE: Double, userN: Double) {
        if (baseRouteEnu.isEmpty()) return
        var closestIdx = 0
        var closestDist = Double.MAX_VALUE
        for (i in baseRouteEnu.indices) {
            val d = hypot(baseRouteEnu[i][0] - userE, baseRouteEnu[i][1] - userN)
            if (d < closestDist) {
                closestDist = d
                closestIdx = i
            }
        }

        val pts = mutableListOf<DoubleArray>()
        if (closestDist > 12.0) {
            pts.add(doubleArrayOf(userE, userN))
            for (i in closestIdx until baseRouteEnu.size) {
                pts.add(baseRouteEnu[i])
            }
        } else {
            pts.addAll(baseRouteEnu)
        }
        if (pts.size == 1) {
            pts.add(toEnu(targetLat, targetLng))
        }

        activeRouteEnu = pts
        activeRouteCum = DoubleArray(pts.size)
        for (k in 1 until pts.size) {
            activeRouteCum[k] = activeRouteCum[k - 1] +
                hypot(pts[k][0] - pts[k - 1][0], pts[k][1] - pts[k - 1][1])
        }
        miniMapView.setRouteData(activeRouteEnu, userE, userN)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // World-Space Arrow & Pin Placement
    // ═══════════════════════════════════════════════════════════════════════════

    private fun updateArrowsAndPin() {
        if (activeRouteEnu.size < 2 || originArX.isNaN()) return
        val ar = activeRouteEnu.map { enuToAr(it) }
        val total = activeRouteCum.last()
        if (total < 0.5) return

        // Project AR camera onto active route XZ polyline → distance `sUser` along walkway
        var bestDist = Double.MAX_VALUE
        var sUser = 0.0
        for (k in 0 until ar.size - 1) {
            val ax = ar[k][0]
            val az = ar[k][1]
            val dx = ar[k + 1][0] - ax
            val dz = ar[k + 1][1] - az
            val len2 = dx * dx + dz * dz
            val t = if (len2 < 1e-6) 0.0 else {
                (((camX - ax) * dx + (camZ - az) * dz) / len2).coerceIn(0.0, 1.0)
            }
            val px = ax + dx * t
            val pz = az + dz * t
            val d = hypot(camX - px, camZ - pz)
            if (d < bestDist) {
                bestDist = d
                sUser = activeRouteCum[k] + (activeRouteCum[k + 1] - activeRouteCum[k]) * t
            }
        }

        val floor = floorY ?: (camY - 1.38f)
        val firstK = ceil((sUser + 1.5) / ARROW_SPACING_M).toInt()
        var firstVisibleDir: DoubleArray? = null

        arrowNodes.forEachIndexed { i, node ->
            val s = (firstK + i) * ARROW_SPACING_M
            if (s > total - 0.8) {
                node.isVisible = false
                return@forEachIndexed
            }
            val p = pointAt(ar, s)
            val ahead = pointAt(ar, (s + 1.4).coerceAtMost(total))
            var dx = ahead[0] - p[0]
            var dz = ahead[1] - p[1]
            if (hypot(dx, dz) < 1e-3) {
                dx = ar.last()[0] - p[0]
                dz = ar.last()[1] - p[1]
            }
            if (firstVisibleDir == null) {
                firstVisibleDir = doubleArrayOf(p[0] - camX, p[1] - camZ)
            }

            // `nav_arrow.glb` tip points along -Z in local space; rotate around +Y to face (dx, dz)
            val yawDeg = Math.toDegrees(atan2(-dx, -dz)).toFloat()
            node.position = Float3(p[0].toFloat(), floor + 0.03f, p[1].toFloat())
            node.rotation = Float3(0f, yawDeg, 0f)
            node.isVisible = true
        }

        // Destination 3D red pin standing at the landmark
        val dest = ar.last()
        val distToStop = gpsDistanceToStop() ?: hypot(dest[0] - camX, dest[1] - camZ)
        val time = SystemClock.elapsedRealtime() / 1000.0
        pinNode?.let { pin ->
            if (distToStop <= PIN_SHOW_WITHIN_M) {
                val bob = (0.05 * sin(time * 2.2)).toFloat()
                pin.position = Float3(dest[0].toFloat(), floor + 0.04f + bob, dest[1].toFloat())
                pin.rotation = Float3(0f, ((time * 45.0) % 360.0).toFloat(), 0f)
                pin.isVisible = true
            } else {
                pin.isVisible = false
            }
        }

        updateTurnHint(firstVisibleDir ?: doubleArrayOf(dest[0] - camX, dest[1] - camZ))
    }

    private fun pointAt(ar: List<DoubleArray>, s: Double): DoubleArray {
        for (k in 0 until ar.size - 1) {
            if (s <= activeRouteCum[k + 1] || k == ar.size - 2) {
                val segLen = activeRouteCum[k + 1] - activeRouteCum[k]
                val t = if (segLen < 1e-6) 0.0 else {
                    ((s - activeRouteCum[k]) / segLen).coerceIn(0.0, 1.0)
                }
                return doubleArrayOf(
                    ar[k][0] + (ar[k + 1][0] - ar[k][0]) * t,
                    ar[k][1] + (ar[k + 1][1] - ar[k][1]) * t
                )
            }
        }
        return ar.last()
    }

    private fun updateTurnHint(dir: DoubleArray) {
        val len = hypot(dir[0], dir[1])
        if (len < 0.5) {
            hintText.visibility = View.GONE
            return
        }
        val tx = dir[0] / len
        val tz = dir[1] / len
        val cross = camFwdX * tz - camFwdZ * tx
        val dot = camFwdX * tx + camFwdZ * tz
        val angle = Math.toDegrees(atan2(cross, dot))
        if (abs(angle) > 42) {
            hintText.visibility = View.VISIBLE
            hintText.text = if (angle > 0) "Turn right ▶" else "◀ Turn left"
        } else {
            hintText.visibility = View.GONE
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GPS & Compass Sensors
    // ═══════════════════════════════════════════════════════════════════════════

    @SuppressLint("MissingPermission")
    private fun startLocation() {
        val lm = locationManager ?: return
        try {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).forEach { p ->
                if (lm.isProviderEnabled(p)) {
                    lm.getLastKnownLocation(p)?.let { onLocationChanged(it) }
                    lm.requestLocationUpdates(p, 1000L, 0f, this)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Location start failed", e)
        }
    }

    override fun onLocationChanged(location: Location) {
        val prev = lastFix
        if (prev != null && prev.provider != "flutter_seed" &&
            location.accuracy > prev.accuracy * 2f &&
            location.time - prev.time < 5000L
        ) {
            return
        }
        lastFix = location

        if (originLat.isNaN()) {
            buildBaseRoute(location.latitude, location.longitude)
            declinationDeg = GeomagneticField(
                location.latitude.toFloat(),
                location.longitude.toFloat(),
                location.altitude.toFloat(),
                System.currentTimeMillis()
            ).declination
        } else {
            val userEnu = toEnu(location.latitude, location.longitude)
            rebuildActiveRoute(userEnu[0], userEnu[1])
        }

        gpsDistanceToStop()?.let { d ->
            distanceText.text = if (d >= 1000) "%.1f km".format(d / 1000.0) else "${d.roundToInt()} m"
            val near = d <= ARRIVE_RADIUS_M
            arrivedButton.background = panelBg(
                if (near) COLOR_BRASS else 0xFF1B4332.toInt(),
                stroke = if (near) COLOR_BRASS else 0xFF1B4332.toInt(),
                radius = 8
            )
            arrivedButton.setTextColor(if (near) 0xFF12301F.toInt() else COLOR_IVORY)
        }

        if (stabilized) applyFixToOrigin(location, force = false)
    }

    private fun applyFixToOrigin(fix: Location, force: Boolean) {
        if (originLat.isNaN() || !cameraTracking) return
        if (fix.accuracy > MAX_FIX_ACCURACY_M && !force) return
        val enu = toEnu(fix.latitude, fix.longitude)
        val r = rotateEnu(enu[0], enu[1])
        val estX = camX - r[0]
        val estZ = camZ - r[1]
        if (originArX.isNaN() || force) {
            originArX = estX
            originArZ = estZ
            return
        }
        val alpha = when {
            fix.accuracy <= 5f -> 0.22
            fix.accuracy <= 10f -> 0.12
            else -> 0.05
        }
        originArX += (estX - originArX) * alpha
        originArZ += (estZ - originArZ) * alpha
    }

    private fun gpsDistanceToStop(): Double? {
        val fix = lastFix ?: return null
        val out = FloatArray(1)
        Location.distanceBetween(fix.latitude, fix.longitude, targetLat, targetLng, out)
        return out[0].toDouble()
    }

    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onResume() {
        super.onResume()
        sensorManager?.let { sm ->
            val rotSensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                ?: sm.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            rotSensor?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
        }
    }

    override fun onPause() {
        sensorManager?.unregisterListener(this)
        super.onPause()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ROTATION_VECTOR &&
            event.sensor.type != Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR
        ) return
        SensorManager.getRotationMatrixFromVector(rotMatrix, event.values)
        // Same tilt-compensated ray `0.5 * (+Y) - 0.866 * (+Z)` used for ARCore `displayOrientedPose`
        val east = 0.5f * rotMatrix[1] - 0.8660254f * rotMatrix[2]
        val north = 0.5f * rotMatrix[4] - 0.8660254f * rotMatrix[5]
        if (sqrt(east * east + north * north) < 0.25f) return
        val heading = Math.toDegrees(atan2(east.toDouble(), north.toDouble())) + declinationDeg
        deviceHeadingDeg = (heading + 360.0) % 360.0
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        try {
            locationManager?.removeUpdates(this)
        } catch (_: Exception) {}
        sensorManager?.unregisterListener(this)
        arrowNodes.clear()
        pinNode = null
        arView?.let {
            root.removeView(it)
            try {
                it.destroy()
            } catch (_: Exception) {}
        }
        arView = null
        super.onDestroy()
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Lightweight Custom Overlays (Zero extra GL/Map memory overhead)
    // ═══════════════════════════════════════════════════════════════════════════

    /** Green corner brackets matching the campus AR wayfinder reference UI. */
    private class CornerReticleOverlay(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = COLOR_RETICLE
            style = Paint.Style.STROKE
            strokeWidth = context.resources.displayMetrics.density * 3f
            strokeCap = Paint.Cap.SQUARE
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val d = resources.displayMetrics.density
            val left = 22f * d
            val right = width - 22f * d
            val top = 96f * d
            val bottom = height - 92f * d
            val arm = 26f * d

            // Top-left
            canvas.drawLine(left, top + arm, left, top, paint)
            canvas.drawLine(left, top, left + arm, top, paint)
            // Top-right
            canvas.drawLine(right - arm, top, right, top, paint)
            canvas.drawLine(right, top, right, top + arm, paint)
            // Bottom-left
            canvas.drawLine(left, bottom - arm, left, bottom, paint)
            canvas.drawLine(left, bottom, left + arm, bottom, paint)
            // Bottom-right
            canvas.drawLine(right - arm, bottom, right, bottom, paint)
            canvas.drawLine(right, bottom, right, bottom - arm, paint)
        }
    }

    /** Compact route radar mini-map showing route path, destination pin, and live heading. */
    private class RouteMiniMapView(context: Context) : View(context) {
        private var pts: List<DoubleArray> = emptyList()
        private var userE = 0.0
        private var userN = 0.0
        private var headingDeg = 0.0

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xD9162B20.toInt()
            style = Paint.Style.FILL
        }
        private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xAA2EE585.toInt()
            style = Paint.Style.STROKE
            strokeWidth = context.resources.displayMetrics.density * 1.5f
        }
        private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x26FFFFFF
            style = Paint.Style.STROKE
            strokeWidth = context.resources.displayMetrics.density * 1f
        }
        private val routePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF38BDF8.toInt()
            style = Paint.Style.STROKE
            strokeWidth = context.resources.displayMetrics.density * 3f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        private val destPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFEF4444.toInt()
            style = Paint.Style.FILL
        }
        private val userPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF2EE585.toInt()
            style = Paint.Style.FILL
        }
        private val whiteStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = context.resources.displayMetrics.density * 1.6f
        }
        private val rect = RectF()
        private val path = Path()

        fun setRouteData(routeEnu: List<DoubleArray>, uE: Double, uN: Double) {
            pts = routeEnu
            userE = uE
            userN = uN
            postInvalidate()
        }

        fun updateHeading(deg: Double) {
            if (!deg.isNaN()) {
                headingDeg = deg
                postInvalidate()
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val d = resources.displayMetrics.density
            val r = 10f * d
            rect.set(d, d, width - d, height - d)
            canvas.drawRoundRect(rect, r, r, bgPaint)

            // Subtle cartographic crosshair
            canvas.drawLine(width / 2f, 8f * d, width / 2f, height - 8f * d, gridPaint)
            canvas.drawLine(8f * d, height / 2f, width - 8f * d, height / 2f, gridPaint)

            if (pts.isNotEmpty()) {
                var minE = userE
                var maxE = userE
                var minN = userN
                var maxN = userN
                for (p in pts) {
                    minE = min(minE, p[0])
                    maxE = max(maxE, p[0])
                    minN = min(minN, p[1])
                    maxN = max(maxN, p[1])
                }
                val span = max(max(maxE - minE, maxN - minN), 25.0) * 1.28
                val midE = (minE + maxE) * 0.5
                val midN = (minN + maxN) * 0.5
                val pad = 14f * d
                val drawSize = (min(width, height) - pad * 2f).coerceAtLeast(10f)

                fun sx(e: Double): Float = (width * 0.5 + ((e - midE) / span) * drawSize).toFloat()
                fun sy(n: Double): Float = (height * 0.5 - ((n - midN) / span) * drawSize).toFloat()

                path.reset()
                pts.forEachIndexed { idx, p ->
                    val x = sx(p[0])
                    val y = sy(p[1])
                    if (idx == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                canvas.drawPath(path, routePaint)

                // Red destination dot
                val dest = pts.last()
                val dx = sx(dest[0])
                val dy = sy(dest[1])
                canvas.drawCircle(dx, dy, 5f * d, destPaint)
                canvas.drawCircle(dx, dy, 5f * d, whiteStroke)

                // User dot + heading pointer
                val ux = sx(userE)
                val uy = sy(userN)
                val rad = Math.toRadians(headingDeg)
                val hx = ux + (sin(rad) * 11.0 * d).toFloat()
                val hy = uy - (cos(rad) * 11.0 * d).toFloat()
                canvas.drawLine(ux, uy, hx, hy, whiteStroke)
                canvas.drawCircle(ux, uy, 4.5f * d, userPaint)
                canvas.drawCircle(ux, uy, 4.5f * d, whiteStroke)
            }

            canvas.drawRoundRect(rect, r, r, borderPaint)
        }
    }
}
