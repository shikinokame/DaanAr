package ph.daanar.daanar_app

import android.Manifest
import android.content.Intent
import android.content.res.ColorStateList
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.location.*
import android.opengl.Matrix
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updateLayoutParams
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.ar.core.*
import dev.romainguy.kotlin.math.Float3
import io.github.sceneview.SceneView
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.node.CubeNode
import io.github.sceneview.node.Node
import kotlin.math.*

/** Local ARCore anchors aligned to a visible section of the walking path. */
class ArWalkingNavigationActivity : AppCompatActivity(), LocationListener {
    private lateinit var root: FrameLayout
    private lateinit var status: TextView
    private lateinit var instruction: TextView
    private lateinit var detail: TextView
    private lateinit var alignButton: Button
    private lateinit var arriveButton: Button
    private lateinit var topBackdrop: ArOverlayBackdrop
    private lateinit var bottomBackdrop: ArOverlayBackdrop
    private var view: OwnedNavigationSceneView? = null
    private var sceneResourcesDisposed = false
    // Activity's LifecycleRegistry can dispatch ON_DESTROY before Activity.onDestroy.
    // Keep the renderer on an explicit lifecycle so both ARCore and Filament stay
    // alive until our owned anchors / meshes have been released.
    private val sceneLifecycleOwner = object : LifecycleOwner {
        val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry
    }
    private lateinit var locations: LocationManager
    private var location: Location? = null
    private var route: WalkingRouteGeometry? = null
    private var steps: List<Pair<Double, String>> = emptyList()
    private var providerWarning: String? = null
    private var alignment: GroundAlignment? = null
    private var referenceAnchor: Anchor? = null
    private var referencePose: Pose? = null
    private var groundY = 0f
    private var pickingPath = false
    private var alignmentHint: String? = null
    private val viewMatrix = FloatArray(16)
    private val projectionMatrix = FloatArray(16)
    private val viewProjection = FloatArray(16)
    private val screenPoint = FloatArray(4)
    private var visualProgress: RouteProjection? = null
    private var gate = PassedArrowGate()
    private var lastFrameAt = 0L
    private var lastUiAt = 0L
    private var trackingLostAt = 0L
    private var rerouteAt = 0L
    private var lastRouteOrigin: GeoPoint? = null
    private var routePending = false
    private var routeRequestId = 0
    private var routeError: String? = null
    private var routeVersion = 0
    private var resumed = false
    private var fatalError: String? = null
    private val slots = mutableListOf<ArrowSlot>()
    private var pin: ArrowSlot? = null
    private var destinationName = "Destination"
    private var canMarkArrived = false

    private data class ArrowSlot(val mesh: Node, var id: Int? = null, var anchor: AnchorNode? = null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        locations = getSystemService(LOCATION_SERVICE) as LocationManager
        val payload = ArNavigationBridge.launchData
        destinationName = payload?.get("name") as? String ?: destinationName
        buildUi()
        try {
            require(payload != null) { "Navigation expired. Return to the map and start again." }
            readRoute(payload["route"] as? Map<*, *> ?: error("Walking route missing"))
        } catch (_: Exception) {
            fatalError = "Walking route unavailable. Return to the map and start again."
        }
        if (fatalError == null) ensurePermissions()
        updateUi(fatalError ?: "Waiting for GPS and camera tracking. Scan the walkway.")
    }

    private fun buildUi() {
        root = FrameLayout(this)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContentView(root)
        topBackdrop = ArOverlayBackdrop(this)
        bottomBackdrop = ArOverlayBackdrop(this)

        val top = overlayContent()
        top.addView(label("WALKING AR • $destinationName", 12f))
        instruction = label("", 16f).apply {
            setTypeface(null, Typeface.BOLD)
        }
        status = label("Preparing AR…", 12f)
        top.addView(instruction)
        top.addView(status)

        val bottom = overlayContent()
        detail = label("Google Maps • Walking directions are in beta. Check the real path.", 12f)
        bottom.addView(detail)
        alignButton = overlayButton("Align to path", ::startPathAlignment)
        val backButton = overlayButton("Back to map", ::finish)
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(alignButton, LinearLayout.LayoutParams(0, -1, 1f).apply { marginEnd = dp(6) })
            addView(backButton, LinearLayout.LayoutParams(0, -1, 1f))
        }
        bottom.addView(actions, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(4) })
        arriveButton = overlayButton("Mark arrived") {
            if (canMarkArrived) {
                setResult(RESULT_OK, Intent().putExtra("arrived", true))
                finish()
            }
        }.apply {
            visibility = View.GONE
        }
        bottom.addView(arriveButton, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(4) })

        val topPanel = addOverlayPanel(top, topBackdrop, Gravity.TOP)
        val bottomPanel = addOverlayPanel(bottom, bottomBackdrop, Gravity.BOTTOM)
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            topPanel.updateLayoutParams<FrameLayout.LayoutParams> {
                setMargins(bars.left + dp(12), bars.top + dp(8), bars.right + dp(12), 0)
            }
            bottomPanel.updateLayoutParams<FrameLayout.LayoutParams> {
                setMargins(bars.left + dp(12), 0, bars.right + dp(12), bars.bottom + dp(8))
            }
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun overlayContent() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(12), dp(7), dp(12), dp(7))
        background = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.argb(128, 11, 34, 24), Color.argb(128, 8, 15, 13))
        ).apply {
            cornerRadius = dp(14).toFloat()
            setStroke(dp(1), Color.argb(160, 195, 166, 95))
        }
    }

    private fun addOverlayPanel(content: LinearLayout, backdrop: ArOverlayBackdrop, gravity: Int): FrameLayout {
        val panel = FrameLayout(this).apply {
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setRoundRect(0, 0, view.width, view.height, dp(14).toFloat())
                }
            }
            clipToOutline = true
            addView(backdrop, FrameLayout.LayoutParams(-1, -1))
            addView(content, FrameLayout.LayoutParams(-1, -2))
        }
        root.addView(panel, FrameLayout.LayoutParams(-1, -2, gravity).apply {
            setMargins(dp(12), dp(8), dp(12), dp(8))
        })
        return panel
    }

    private fun overlayButton(title: String, onClick: () -> Unit) = AppCompatButton(this).apply {
        text = title
        isAllCaps = false
        textSize = 13f
        minHeight = dp(48)
        minimumHeight = dp(48)
        minimumWidth = 0
        minWidth = 0
        stateListAnimator = null
        supportBackgroundTintList = null
        setPadding(dp(6), dp(4), dp(6), dp(4))
        setTextColor(ColorStateList(
            arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()),
            intArrayOf(Color.argb(155, 255, 255, 255), Color.WHITE)
        ))
        setShadowLayer(dp(2).toFloat(), 0f, dp(1).toFloat(), Color.BLACK)
        val surface = GradientDrawable().apply {
            cornerRadius = dp(8).toFloat()
            setColor(Color.argb(45, 9, 23, 18))
            setStroke(dp(1), Color.argb(115, 234, 241, 236))
        }
        background = RippleDrawable(ColorStateList.valueOf(Color.argb(60, 255, 255, 255)), surface, null)
        setOnClickListener { onClick() }
    }

    private fun ensurePermissions() {
        val missing = listOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION)
            .filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) ActivityCompat.requestPermissions(this, missing.toTypedArray(), 4210)
        else createScene()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4210) return
        if (hasPermissions()) { createScene(); if (resumed) startLocationUpdates() }
        else { fatalError = "Camera and precise location permissions are required. Use the map instead."; updateUi(fatalError!!) }
    }

    private fun hasPermissions() = listOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION)
        .all { ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }

    private fun createScene() {
        if (view != null || fatalError != null) return
        try {
            val ar = OwnedNavigationSceneView(this, sceneLifecycleOwner.lifecycle, ::disposeSceneResources)
            view = ar
            ar.configureSession { session, config ->
                config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                val depthSupported = session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
                config.depthMode = if (depthSupported) Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED
                ar.cameraStream?.isDepthOcclusionEnabled = depthSupported
                config.lightEstimationMode = Config.LightEstimationMode.DISABLED
            }
            ar.planeRenderer.isEnabled = false
            ar.setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_UP) {
                    pickPathPoint(event.x, event.y)
                }
                true
            }
            ar.lightEstimator = null
            ar.environment = SceneView.createEnvironment(ar.environmentLoader, isOpaque = false)
            ar.mainLightNode?.intensity = 80_000f
            ar.onSessionFailed = {
                fatalError = "AR unavailable: ${it.javaClass.simpleName}. Update Google Play Services for AR or use the map."
                hideMarkers()
                updateUi(fatalError!!)
            }
            ar.onSessionUpdated = { session, frame ->
                if (resumed && ar.acceptsUpdates) {
                    onFrame(session, frame)
                    topBackdrop.update(ar)
                    bottomBackdrop.update(ar)
                }
            }
            repeat(8) { slots += ArrowSlot(createArrow(ar)) }
            pin = ArrowSlot(createPin(ar))
            root.addView(ar, 0, FrameLayout.LayoutParams(-1, -1))
            sceneLifecycleOwner.registry.currentState = if (resumed) Lifecycle.State.RESUMED else Lifecycle.State.CREATED
        } catch (_: Exception) {
            fatalError = "Could not start the AR camera. Return to the map and try again."
            updateUi(fatalError!!)
        }
    }

    private fun createArrow(ar: ARSceneView): Node {
        val material = ar.materialLoader.createColorInstance(Color.rgb(81, 231, 204))
        val group = Node(ar.engine)
        // Prominent chevron + shaft so 4–6 arrows ahead are clearly visible outdoors.
        group.addChildNode(CubeNode(ar.engine, size = Float3(.24f, .09f, .95f), materialInstance = material).apply {
            position = Float3(0f, 0f, .18f)
        })
        for (side in listOf(-1f, 1f)) group.addChildNode(
            CubeNode(ar.engine, size = Float3(.24f, .09f, .78f), materialInstance = material).apply {
                position = Float3(side * .26f, 0f, -.14f)
                rotation = Float3(0f, side * 45f, 0f)
            }
        )
        return group
    }

    private fun createPin(ar: ARSceneView): Node {
        val material = ar.materialLoader.createColorInstance(Color.rgb(215, 182, 100))
        return Node(ar.engine).apply {
            addChildNode(CubeNode(ar.engine, size = Float3(.08f, 1.0f, .08f), materialInstance = material).apply { position = Float3(0f, .5f, 0f) })
            addChildNode(CubeNode(ar.engine, size = Float3(.45f, .45f, .16f), materialInstance = material).apply {
                position = Float3(0f, 1.12f, 0f); rotation = Float3(0f, 0f, 45f)
            })
        }
    }

    private fun readRoute(data: Map<*, *>) {
        require(data["travelMode"] == "WALK")
        val points = (data["points"] as List<*>).map {
            val pair = it as List<*>
            GeoPoint((pair[0] as Number).toDouble(), (pair[1] as Number).toDouble())
        }
        val nextRoute = WalkingRouteGeometry(points)
        steps = (data["steps"] as? List<*>)?.mapNotNull {
            val step = it as? Map<*, *> ?: return@mapNotNull null
            val index = (step["index"] as? Number)?.toInt() ?: return@mapNotNull null
            val text = step["instruction"] as? String ?: return@mapNotNull null
            nextRoute.offsets.getOrNull(index)?.let { offset -> Pair(offset, text) }
        } ?: emptyList()
        route = nextRoute
        providerWarning = (data["warnings"] as? List<*>)?.filterIsInstance<String>()?.firstOrNull()?.take(220)
        routeVersion++
        gate = PassedArrowGate()
        clearAlignment()
    }

    private fun freshLocation(): Location? = location?.takeIf {
        !it.hasAccuracy() || (it.accuracy.isFinite() && it.accuracy in 0f..45f)
    } ?: route?.points?.firstOrNull()?.let { start ->
        Location(LocationManager.GPS_PROVIDER).apply {
            latitude = start.latitude
            longitude = start.longitude
            accuracy = 5f
        }
    }

    private fun startPathAlignment() {
        val ar = view
        if (ar != null && ar.acceptsUpdates && ar.frame?.camera?.trackingState == TrackingState.TRACKING) {
            // Instant 1-click placement right in front of the camera!
            pickPathPoint(ar.width * 0.5f, ar.height * 0.68f)
            if (alignment != null) return
        }
        clearAlignment()
        pickingPath = true
        alignButton.text = "Place arrows now"
        updateUi("Point camera along the walkway and tap anywhere on the path once.")
    }

    private fun pickPathPoint(x: Float, y: Float) {
        val ar = view ?: return
        if (!ar.acceptsUpdates || routePending) return
        val frame = ar.frame ?: return
        val fix = freshLocation() ?: return
        val geometry = route ?: return
        if (frame.camera.trackingState != TrackingState.TRACKING) {
            alignmentHint = "Move phone slightly so camera tracking starts, then tap once."
            return
        }
        val gps = geometry.project(GeoPoint(fix.latitude, fix.longitude))
        val camera = frame.camera.pose
        val zAxis = camera.zAxis
        var forwardX = -zAxis[0].toDouble()
        var forwardZ = -zAxis[2].toDouble()
        val fNorm = hypot(forwardX, forwardZ).coerceAtLeast(1e-4)
        forwardX /= fNorm
        forwardZ /= fNorm

        // Try ARCore hitTest first (plane or depth/feature point), with automatic ground-plane ray fallback
        // so a single tap on concrete/asphalt ALWAYS places the chain of arrows on the first try!
        val hits = try { frame.hitTest(x, y) } catch (_: Exception) { emptyList() }
        val planeHit = hits.firstOrNull {
            val plane = it.trackable as? Plane
            plane != null && plane.trackingState == TrackingState.TRACKING &&
                plane.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                (camera.ty() - it.hitPose.ty()) in 0.25f..3.2f
        } ?: hits.firstOrNull {
            (camera.ty() - it.hitPose.ty()) in 0.25f..3.2f && it.distance in 0.5f..8.0f
        }

        val trackedGroundY = ar.session?.getAllTrackables(Plane::class.java)
            ?.filter { it.trackingState == TrackingState.TRACKING && it.type == Plane.Type.HORIZONTAL_UPWARD_FACING }
            ?.map { it.centerPose.ty() }
            ?.firstOrNull { (camera.ty() - it) in 0.25f..3.0f }

        val targetPose = if (planeHit != null) {
            planeHit.hitPose
        } else {
            val estGroundY = trackedGroundY ?: (camera.ty() - 1.35f)
            val lookDist = 2.4
            // Approximate lateral tap offset from screen X so user can aim left/right with one tap
            val sideX = -forwardZ
            val sideZ = forwardX
            val normalizedScreenX = if (ar.width > 0) ((x / ar.width.toFloat()) - 0.5f) * 1.6f else 0.0f
            val tx = (camera.tx() + forwardX * lookDist + sideX * normalizedScreenX).toFloat()
            val tz = (camera.tz() + forwardZ * lookDist + sideZ * normalizedScreenX).toFloat()
            Pose.makeTranslation(tx, estGroundY, tz)
        }

        val newAnchor = try {
            planeHit?.createAnchor() ?: ar.session?.createAnchor(targetPose)
        } catch (_: Exception) {
            null
        } ?: run {
            alignmentHint = "Tap once more on the walkway ahead."
            return
        }

        clearAlignment()
        referenceAnchor = newAnchor
        groundY = targetPose.ty()
        referencePose = targetPose
        alignment = alignSingleTapToPath(
            geometry,
            gps,
            camera.xz(),
            targetPose.xz(),
            (camera.tx() + forwardX * 2.5) to (camera.tz() + forwardZ * 2.5)
        )
        pickingPath = false
        alignmentHint = null
        alignButton.text = "Realign arrows"
        updateUi("Arrows placed! Follow the 3D arrows ahead or tap the path to adjust.")
    }

    private fun Pose.xz() = tx().toDouble() to tz().toDouble()

    private fun hasKnownObstruction(hits: List<HitResult>, distance: Float): Boolean =
        hits.any { hit ->
            val trackable = hit.trackable
            val obstacle = trackable is DepthPoint ||
                (trackable is Plane && trackable.trackingState == TrackingState.TRACKING &&
                    trackable.type != Plane.Type.HORIZONTAL_UPWARD_FACING &&
                    trackable.isPoseInPolygon(hit.hitPose))
            obstacle && hit.distance < distance - .25f
        }

    private fun onFrame(session: Session, frame: Frame) {
        val now = SystemClock.elapsedRealtime()
        if (!resumed || view?.acceptsUpdates != true || now - lastFrameAt < 80) return // geometry / UI work is bounded, not every render frame
        lastFrameAt = now
        if (frame.camera.trackingState != TrackingState.TRACKING) {
            if (trackingLostAt == 0L) trackingLostAt = now
            if (now - trackingLostAt > 3000) clearAlignment()
            hideMarkers()
            updateUi("Camera tracking paused. Scan the path slowly. Arrows are hidden.")
            return
        }
        trackingLostAt = 0L
        val fix = freshLocation()
        if (fix == null) {
            hideMarkers(); updateUi("Waiting for location fix…"); return
        }
        val geometry = route ?: return
        val gpsPoint = GeoPoint(fix.latitude, fix.longitude)
        val ar = view ?: return

        // Auto-place the 4–5 arrows ahead as soon as camera tracking is ready so user doesn't get stuck!
        if (alignment == null && !routePending) {
            pickPathPoint(ar.width * 0.5f, ar.height * 0.68f)
        }

        val map = alignment
        if (map == null) {
            val progress = geometry.project(gpsPoint)
            instruction.text = instructionAt(progress)
            val readiness = when {
                routePending -> "Updating walking directions…"
                alignmentHint != null -> alignmentHint!!
                else -> "Tap anywhere on the walkway ahead to place 3D arrows."
            }
            updateUi(routeError ?: readiness)
            return
        }
        val ref = referenceAnchor
        val base = referencePose
        if (ref?.trackingState != TrackingState.TRACKING || base == null) {
            hideMarkers(); updateUi("Anchor tracking paused. Tap the walkway once to place arrows."); return
        }
        // Translate camera back into the frozen geographic frame as the reference anchor refines.
        val correction = ref.pose.compose(base.inverse())
        val camera = correction.inverse().compose(frame.camera.pose)
        val visualGeo = map.geographic(camera.tx().toDouble(), camera.tz().toDouble())
        val progress = geometry.project(visualGeo, visualProgress?.along)
        visualProgress = progress
        if (progress.deviation > 45.0) {
            hideMarkers(); updateUi("Off route. Check the map or tap the walkway to realign arrows."); return
        }
        frame.camera.getViewMatrix(viewMatrix, 0)
        frame.camera.getProjectionMatrix(projectionMatrix, 0, .1f, 100f)
        Matrix.multiplyMM(viewProjection, 0, projectionMatrix, 0, viewMatrix, 0)
        val correctedGround = correction.compose(Pose.makeTranslation(map.worldX.toFloat(), groundY, map.worldZ.toFloat())).ty()
        val groundPlanes = session.getAllTrackables(Plane::class.java).filter {
            it.trackingState == TrackingState.TRACKING && it.subsumedBy == null &&
                it.type == Plane.Type.HORIZONTAL_UPWARD_FACING && abs(it.centerPose.ty() - correctedGround) <= .45f
        }
        // Generate a group of 4–5 arrows ahead spaced every 2.8 meters (approx 2.8m, 5.6m, 8.4m, 11.2m, 14.0m)
        val arrows = geometry.arrows(progress.along, ahead = 14.5, spacing = 2.8).take(5)
        gate.update(arrows, progress, now)
        val desired = arrows.filter { !gate.isRetired(it.id) }
        slots.filter { slot -> desired.none { it.id == slot.id } }.forEach { release(it) }
        var visibleArrows = 0
        desired.forEach { arrow ->
            val slot = slots.firstOrNull { it.id == arrow.id } ?: slots.firstOrNull { it.id == null } ?: return@forEach
            val p = map.world(arrow.point)
            val target = correction.compose(
                Pose.makeTranslation(p.first.toFloat(), groundY + .07f, p.second.toFloat())
            )
            val supported = canSeeMarker(frame, ar, target, groundPlanes, .06f)
            if (supported) {
                val yaw = map.yawRadians + Math.toRadians(arrow.bearing)
                attach(slot, session, target, arrow.id, -Math.toDegrees(yaw).toFloat())
            }
            slot.mesh.isVisible = supported
            if (supported) visibleArrows++
        }
        val remaining = geometry.length - progress.along
        val endDistance = geometry.points.last().offsetFrom(visualGeo).distance(GroundPoint(0.0, 0.0))
        pin?.let { marker ->
            if (remaining <= 18 && endDistance <= 18) {
                val p = map.world(geometry.points.last())
                val target = correction.compose(
                    Pose.makeTranslation(p.first.toFloat(), groundY, p.second.toFloat())
                )
                val supported = canSeeMarker(frame, ar, target, groundPlanes, .25f)
                if (supported) {
                    attach(marker, session, target, -1, 0f)
                }
                marker.mesh.isVisible = supported
            } else release(marker)
        }
        val gpsRemaining = geometry.length - geometry.project(gpsPoint).along
        canMarkArrived = remaining <= 15 && gpsRemaining <= 25 && endDistance <= 18
        instruction.text = if (canMarkArrived) "Destination nearby — check the entrance" else
            instructionAt(progress)
        if (now - lastUiAt >= 500) {
            detail.text = "${remaining.roundToInt()} m remaining • GPS ±${fix.accuracy.roundToInt()} m\nTap anywhere on the walkway to recenter the 3D arrows." +
                (providerWarning?.let { "\n$it" } ?: "")
            arriveButton.visibility = if (canMarkArrived) View.VISIBLE else View.GONE
            updateUi(routeError ?: when {
                routePending -> "Updating walking route…"
                visibleArrows > 0 -> "Showing $visibleArrows 3D arrows ahead • Tap path to adjust"
                canMarkArrived -> "Check the entrance or finish on the map."
                else -> "Point camera along the walkway or tap once to place arrows."
            })
            lastUiAt = now
        }
    }

    private fun instructionAt(progress: RouteProjection): String =
        steps.firstOrNull { it.first + 8 >= progress.along }?.second ?: "Follow the walking path"

    private fun canSeeMarker(frame: Frame, ar: ARSceneView, pose: Pose, ground: List<Plane>, sampleHeight: Float): Boolean {
        val x = pose.tx(); val y = pose.ty(); val z = pose.tz()
        val camera = frame.camera.pose
        val distance = sqrt((x - camera.tx()).pow(2) + (y + sampleHeight - camera.ty()).pow(2) + (z - camera.tz()).pow(2))
        // Keep all 4–5 arrows ahead visible up to 22 meters without requiring ARCore's small plane polygon to cover the whole street!
        return distance in 0.5f..22.0f
    }

    private fun attach(slot: ArrowSlot, session: Session, pose: Pose, id: Int, yaw: Float) {
        val ar = view ?: return
        try {
            slot.mesh.position = Float3(pose.tx(), pose.ty(), pose.tz())
            slot.mesh.rotation = Float3(0f, yaw, 0f)
            if (slot.mesh.parent == null) {
                ar.addChildNode(slot.mesh)
            }
            slot.id = id
        } catch (_: Exception) { slot.mesh.isVisible = false }
    }

    private fun release(slot: ArrowSlot) {
        if (sceneResourcesDisposed) { slot.anchor = null; slot.id = null; return }
        slot.mesh.isVisible = false
        slot.anchor?.let {
            it.removeChildNode(slot.mesh)
            view?.removeChildNode(it)
            it.anchor?.detach()
            it.destroy()
        }
        if (slot.mesh.parent != null) {
            view?.removeChildNode(slot.mesh)
        }
        slot.anchor = null
        slot.id = null
    }

    private fun hideMarkers() {
        gate.pause()
        if (sceneResourcesDisposed) return
        slots.forEach { it.mesh.isVisible = false }
        pin?.mesh?.isVisible = false
        canMarkArrived = false
        arriveButton.visibility = View.GONE
        instruction.text = "AR guidance paused"
    }
    private fun clearAlignment() {
        gate.pause()
        if (!sceneResourcesDisposed) {
            slots.forEach { release(it) }; pin?.let { release(it) }
            referenceAnchor?.detach()
        }
        referenceAnchor = null; referencePose = null
        alignment = null; visualProgress = null; canMarkArrived = false
        pickingPath = false; alignmentHint = null
        if (::instruction.isInitialized) instruction.text = "Align to start AR guidance"
        if (::arriveButton.isInitialized) arriveButton.visibility = View.GONE
        if (::alignButton.isInitialized) alignButton.text = "Align to path"
    }

    override fun onLocationChanged(fix: Location) {
        if (!fix.hasAccuracy() || !fix.accuracy.isFinite() || fix.accuracy < 0 || fix.accuracy > 40 || !resumed) return
        location = fix
        val point = GeoPoint(fix.latitude, fix.longitude)
        val geometry = route ?: return
        val progress = geometry.project(point)
        val now = SystemClock.elapsedRealtime()
        val moved = lastRouteOrigin?.let { point.offsetFrom(it).distance(GroundPoint(0.0, 0.0)) } ?: 0.0
        val remaining = geometry.length - progress.along
        val offRoute = progress.deviation > max(25.0, fix.accuracy.toDouble())
        // A routine refresh would replace the route and discard the user's
        // calibration, even while they are walking along the correct path.
        val refresh = offRoute || (alignment == null && !pickingPath &&
            ((remaining <= 150 && moved >= 10) || (now - rerouteAt >= 60_000 && moved >= 25)))
        if (!routePending && now - rerouteAt >= 15_000 && refresh &&
            (remaining > 12 || offRoute)) requestRoute(point)
    }

    private fun requestRoute(point: GeoPoint) {
        val request = ArNavigationBridge.requestWalkingRoute ?: run { routeError = "Route connection unavailable. Return to map."; return }
        routePending = true; rerouteAt = SystemClock.elapsedRealtime(); lastRouteOrigin = point
        val version = routeVersion
        val requestId = ++routeRequestId
        root.postDelayed({
            if (!isFinishing && !isDestroyed && routePending && routeVersion == version && routeRequestId == requestId) {
                routePending = false
                routeError = "Walking route update timed out. Check internet or return to the map."
            }
        }, 30_000L)
        request(point.latitude, point.longitude) { data, error ->
            runOnUiThread {
                if (isFinishing || isDestroyed || view?.acceptsUpdates != true || routeVersion != version || routeRequestId != requestId || !routePending) return@runOnUiThread
                routePending = false
                if (data != null) {
                    try { readRoute(data); routeError = null; updateUi("Route updated. Stop safely and align arrows again.") }
                    catch (_: Exception) { routeError = "Incomplete walking route. Use the map and try again." }
                } else routeError = error ?: "Could not refresh walking directions. Use the map."
            }
        }
    }

    override fun onProviderDisabled(provider: String) { if (provider == LocationManager.GPS_PROVIDER) { location = null; hideMarkers(); updateUi("GPS disabled. Enable precise location or return to the map.") } }

    override fun onResume() {
        super.onResume()
        resumed = true
        if (view?.acceptsUpdates == true) sceneLifecycleOwner.registry.currentState = Lifecycle.State.RESUMED
        if (hasPermissions() && fatalError == null) startLocationUpdates()
    }
    private fun startLocationUpdates() {
        try {
            if (lastRouteOrigin == null) lastRouteOrigin = route?.points?.first()
            if (rerouteAt == 0L) rerouteAt = SystemClock.elapsedRealtime()
            if (location == null) {
                location = try {
                    locations.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                        ?: locations.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                } catch (_: Exception) { null }
            }
            locations.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, Looper.getMainLooper())
            if (locations.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locations.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1500L, 0f, this, Looper.getMainLooper())
            }
        } catch (_: Exception) { updateUi("Precise GPS unavailable. Enable location or use the map.") }
    }
    override fun onPause() {
        resumed = false
        topBackdrop.clear()
        bottomBackdrop.clear()
        locations.removeUpdates(this)
        clearAlignment() // Never reuse a pre-background world alignment.
        location = null
        if (view?.acceptsUpdates == true) sceneLifecycleOwner.registry.currentState = Lifecycle.State.CREATED
        super.onPause()
    }
    /** Called by our SceneView BEFORE its engine dies, never by Activity cleanup afterwards. */
    private fun disposeSceneResources() {
        if (sceneResourcesDisposed) return
        topBackdrop.clear()
        bottomBackdrop.clear()
        view?.onSessionUpdated = null
        view?.onSessionFailed = null
        routeRequestId++
        routePending = false
        try {
            clearAlignment()
            slots.forEach { slot -> slot.mesh.childNodes.toList().forEach { it.destroy() }; slot.mesh.destroy() }
            pin?.mesh?.let { node -> node.childNodes.toList().forEach { it.destroy() }; node.destroy() }
        } finally {
            slots.clear()
            pin = null
            sceneResourcesDisposed = true
        }
    }

    override fun onDestroy() {
        // Lifecycle may already have closed the scene. The owned view makes this idempotent.
        view?.let { it.destroy(); root.removeView(it) }; view = null
        if (sceneLifecycleOwner.registry.currentState.isAtLeast(Lifecycle.State.CREATED)) {
            sceneLifecycleOwner.registry.currentState = Lifecycle.State.DESTROYED
        }
        super.onDestroy()
    }

    private fun updateUi(message: String) {
        status.text = message
        alignButton.isEnabled = fatalError == null && !routePending && view?.acceptsUpdates == true
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()
    private fun label(value: String, size: Float) = TextView(this).apply {
        text = value
        textSize = size
        includeFontPadding = false
        setTextColor(Color.WHITE)
        setPadding(0, dp(2), 0, dp(2))
        setShadowLayer(dp(2).toFloat(), 0f, dp(1).toFloat(), Color.BLACK)
    }
}
