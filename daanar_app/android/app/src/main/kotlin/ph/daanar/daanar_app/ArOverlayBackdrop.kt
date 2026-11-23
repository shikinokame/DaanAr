package ph.daanar.daanar_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import kotlin.math.roundToInt

/** Draw a small, blurred copy of just the AR surface under this panel. */
internal class ArOverlayBackdrop(context: Context) : View(context) {
    private val handler = Handler(Looper.getMainLooper())
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val destination = Rect()
    private val backdropLocation = IntArray(2)
    private val surfaceLocation = IntArray(2)
    private var displayed: Bitmap? = null
    private var spare: Bitmap? = null
    private var copying = false
    private var revision = 0
    private var nextCopyAt = 0L

    init {
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val radius = 7f * resources.displayMetrics.density
            setRenderEffect(RenderEffect.createBlurEffect(radius, radius, Shader.TileMode.CLAMP))
        }
    }

    fun update(source: SurfaceView) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || copying || !isShown ||
            width == 0 || height == 0 || source.width == 0 || source.height == 0 ||
            !source.holder.surface.isValid
        ) return
        val now = SystemClock.uptimeMillis()
        if (now < nextCopyAt) return
        nextCopyAt = now + 90L

        getLocationInWindow(backdropLocation)
        source.getLocationInWindow(surfaceLocation)
        val left = backdropLocation[0] - surfaceLocation[0]
        val top = backdropLocation[1] - surfaceLocation[1]
        val buffer = source.holder.surfaceFrame
        val scaleX = buffer.width().toFloat() / source.width
        val scaleY = buffer.height().toFloat() / source.height
        val region = Rect(
            (left * scaleX).roundToInt(),
            (top * scaleY).roundToInt(),
            ((left + width) * scaleX).roundToInt(),
            ((top + height) * scaleY).roundToInt()
        )
        if (region.isEmpty || !buffer.contains(region)) return

        // Interpolation also gives older devices without RenderEffect a soft backdrop.
        val sampleStep = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) 6 else 18
        val sampleWidth = (width / sampleStep).coerceIn(1, 192)
        val sampleHeight = (height.toFloat() * sampleWidth / width).roundToInt().coerceAtLeast(1)
        val target = spare?.takeIf { it.width == sampleWidth && it.height == sampleHeight }
            ?: Bitmap.createBitmap(sampleWidth, sampleHeight, Bitmap.Config.ARGB_8888)
        spare = null
        copying = true
        val copyRevision = revision
        try {
            PixelCopy.request(source, region, target, { result ->
                copying = false
                if (revision == copyRevision && isShown) {
                    if (result == PixelCopy.SUCCESS) {
                        spare = displayed
                        displayed = target
                    } else {
                        // The gradient underneath can show the live camera during a failed copy.
                        displayed = null
                        spare = target
                    }
                    invalidate()
                }
            }, handler)
        } catch (_: IllegalArgumentException) {
            // The surface was released between checking it and requesting the copy.
            copying = false
            clear()
        }
    }

    fun clear() {
        revision++
        displayed = null
        spare = null
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Match the content-driven panel size without expanding its wrap-content height.
        setMeasuredDimension(resolveSize(0, widthMeasureSpec), resolveSize(0, heightMeasureSpec))
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        destination.set(0, 0, w, h)
        clear()
    }

    override fun onDraw(canvas: Canvas) {
        displayed?.let { canvas.drawBitmap(it, null, destination, paint) }
    }
}
