package ph.daanar.daanar_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.view.TextureView
import android.widget.FrameLayout
import dev.romainguy.kotlin.math.Float3
import io.github.sceneview.math.times
import io.github.sceneview.node.CameraNode
import io.github.sceneview.node.ModelNode
import kotlin.math.max
import kotlin.math.min

/** Composites the studio backdrop behind the transparent model surface. */
internal class StudioStage(context: Context) : FrameLayout(context) {
    val renderView = TextureView(context)

    private val backdrop = Paint(Paint.DITHER_FLAG)
    private val floor = Paint(Paint.DITHER_FLAG).apply {
        shader = RadialGradient(
            0f, 0f, 1f,
            intArrayOf(0xCF020704.toInt(), 0x8A080E0A.toInt(), 0x334F6958, 0x004F6958),
            floatArrayOf(0f, 0.50f, 0.78f, 1f),
            Shader.TileMode.CLAMP
        )
    }
    private val projection = DoubleArray(16)
    private var shadowNeedsUpdate = true
    private var shadowX = 0f
    private var shadowY = 0f
    private var shadowRadius = 0f

    init {
        setWillNotDraw(false)
        addView(renderView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        if (width == 0 || height == 0) return
        backdrop.shader = RadialGradient(
            width * 0.5f, height * 0.44f, max(width * 0.80f, height * 0.58f),
            intArrayOf(Color.rgb(40, 66, 50), Color.rgb(17, 34, 25), Color.rgb(5, 12, 9)),
            floatArrayOf(0f, 0.56f, 1f),
            Shader.TileMode.CLAMP
        )
        onModelTransformChanged()
    }

    fun onModelTransformChanged() {
        shadowNeedsUpdate = true
    }

    fun updateFloorShadow(camera: CameraNode, model: ModelNode) {
        if (!shadowNeedsUpdate) return
        val viewport = camera.viewport ?: return
        if (width == 0 || height == 0 || viewport.width != width || viewport.height != height) return
        shadowNeedsUpdate = false

        camera.camera.getProjectionMatrix(projection)
        val center = model.center
        val bounds = model.halfExtent
        val worldTransform = model.worldTransform
        val viewTransform = camera.worldToLocal
        var left = Float.POSITIVE_INFINITY
        var right = Float.NEGATIVE_INFINITY
        var bottom = Float.NEGATIVE_INFINITY
        shadowRadius = 0f

        // Project the model bounds so the floor treatment follows pan, rotation, and zoom.
        for (corner in 0 until 8) {
            val point = Float3(
                center.x + if (corner and 1 == 0) -bounds.x else bounds.x,
                center.y + if (corner and 2 == 0) -bounds.y else bounds.y,
                center.z + if (corner and 4 == 0) -bounds.z else bounds.z
            )
            val cameraPoint = viewTransform * (worldTransform * point)
            val depth = -cameraPoint.z
            if (depth <= camera.near) {
                invalidate()
                return
            }
            val x = width * (0.5f + 0.5f * projection[0].toFloat() * cameraPoint.x / depth)
            val y = height * (0.5f - 0.5f * projection[5].toFloat() * cameraPoint.y / depth)
            left = min(left, x)
            right = max(right, x)
            bottom = max(bottom, y)
        }

        shadowX = (left + right) * 0.5f
        shadowY = bottom
        shadowRadius = ((right - left) * 0.68f).coerceIn(0f, width * 0.75f)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), backdrop)
        if (shadowRadius > 0f) {
            val save = canvas.save()
            canvas.translate(shadowX, shadowY)
            canvas.scale(shadowRadius, shadowRadius * 0.23f)
            canvas.drawCircle(0f, 0f, 1f, floor)
            canvas.restoreToCount(save)
        }
    }
}
