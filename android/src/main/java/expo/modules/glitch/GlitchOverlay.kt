package expo.modules.glitch

import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import java.lang.ref.WeakReference

/** Visual configuration of the glitch line. Mirrors `GlitchOptions` on the JS side. */
data class GlitchStyle(
  /** Vertical position of the line as a fraction of the screen height. */
  val y: Float = 0.62f,
  /** Thickness of the bright core, in dp. */
  val thickness: Float = 3f,
  val color: Int = DEFAULT_COLOR,
  /** Which half of the screen the line crosses: "left", "right" (authentic) or "full". */
  val side: String = "right",
  /** Also draw the faint vertical line along the fold. */
  val crease: Boolean = false,
  /** Let the line flicker a little. */
  val flicker: Boolean = true,
) {
  companion object {
    val DEFAULT_COLOR: Int = Color.rgb(97, 255, 204)

    /** Parses `#RGB`, `#RRGGBB` and `#RRGGBBAA` (the `#` is optional). */
    fun parseColor(value: String): Int? {
      var hex = value.trim().removePrefix("#")
      if (hex.length == 3) {
        hex = hex.map { "$it$it" }.joinToString("")
      }
      if (hex.length != 6 && hex.length != 8) {
        return null
      }
      val parsed = hex.toLongOrNull(16) ?: return null
      return if (hex.length == 8) {
        val rgb = (parsed shr 8) and 0xffffff
        val alpha = parsed and 0xff
        ((alpha shl 24) or rgb).toInt()
      } else {
        (0xff000000L or parsed).toInt()
      }
    }
  }
}

/** Owns the overlay view and keeps it attached to the current activity. */
object GlitchOverlay {
  private const val META_DATA_KEY = "expo.modules.glitch.AUTO_START"

  @Volatile
  var isEnabled: Boolean = false
    private set

  @Volatile
  var style: GlitchStyle = GlitchStyle()
    private set

  private var view: GlitchLineView? = null
  private var host: WeakReference<Activity>? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  /** Reads the `expo.modules.glitch.AUTO_START` meta-data written by the config plugin. Defaults to true. */
  fun autoStartEnabled(context: Context): Boolean {
    return try {
      val info = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
      val value = info.metaData?.get(META_DATA_KEY)?.toString()
      !value.equals("false", ignoreCase = true)
    } catch (e: Exception) {
      true
    }
  }

  fun setEnabled(activity: Activity?, enabled: Boolean) {
    isEnabled = enabled
    runOnMain {
      if (enabled) {
        attach(activity)
      } else {
        detach()
      }
    }
  }

  fun update(change: (GlitchStyle) -> GlitchStyle) {
    style = change(style)
    runOnMain {
      view?.style = style
    }
  }

  fun reset() {
    update { GlitchStyle() }
  }

  /** Attaches the overlay to the given activity (or the last known one) when the glitch is enabled. */
  fun attach(activity: Activity?) {
    runOnMain {
      if (!isEnabled) {
        return@runOnMain
      }
      val target = activity ?: host?.get() ?: return@runOnMain
      val decor = target.window?.decorView as? ViewGroup ?: return@runOnMain
      val current = view
      if (current != null && current.parent === decor) {
        current.style = style
        return@runOnMain
      }
      (current?.parent as? ViewGroup)?.removeView(current)
      val lineView = GlitchLineView(target).also { it.style = style }
      decor.addView(lineView, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
      view = lineView
      host = WeakReference(target)
    }
  }

  /** Drops the overlay when its activity goes away, so nothing leaks. */
  fun onActivityDestroyed(activity: Activity) {
    runOnMain {
      if (host?.get() === activity) {
        detach()
      }
    }
  }

  private fun detach() {
    val current = view ?: return
    (current.parent as? ViewGroup)?.removeView(current)
    view = null
    host = null
  }

  private fun runOnMain(block: () -> Unit) {
    if (Looper.myLooper() == Looper.getMainLooper()) {
      block()
    } else {
      mainHandler.post(block)
    }
  }
}

/** Draws the line: a soft glow, a banded bright core and an optional crease. Touches pass through. */
class GlitchLineView(context: Context) : View(context) {
  var style: GlitchStyle = GlitchStyle()
    set(value) {
      field = value
      invalidate()
      applyFlicker()
    }

  private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val corePaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val creasePaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private var flickerAnimator: ValueAnimator? = null

  init {
    // BlurMaskFilter needs software rendering; the view is tiny in cost anyway.
    setLayerType(LAYER_TYPE_SOFTWARE, null)
    isClickable = false
    isFocusable = false
    elevation = 10_000f
    setWillNotDraw(false)
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    applyFlicker()
  }

  override fun onDetachedFromWindow() {
    flickerAnimator?.cancel()
    flickerAnimator = null
    super.onDetachedFromWindow()
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val width = width.toFloat()
    val height = height.toFloat()
    if (width <= 0f || height <= 0f) {
      return
    }
    val density = resources.displayMetrics.density
    val thickness = maxOf(1f, style.thickness) * density
    val y = Math.round(height * style.y.coerceIn(0f, 1f)).toFloat()
    val (x0, x1) = when (style.side) {
      "left" -> 0f to width / 2f
      "full" -> 0f to width
      else -> width / 2f to width
    }
    if (x1 <= x0) {
      return
    }

    val base = style.color
    val hot = blend(base, Color.WHITE, 0.8f)
    val mid = blend(base, Color.WHITE, 0.35f)

    glowPaint.color = base
    glowPaint.alpha = 140
    glowPaint.maskFilter = BlurMaskFilter(maxOf(3f, thickness * 1.6f), BlurMaskFilter.Blur.NORMAL)
    canvas.drawRect(x0, y - thickness, x1, y + thickness, glowPaint)

    corePaint.shader = LinearGradient(
      x0, 0f, x1, 0f,
      intArrayOf(hot, mid, base, hot, mid, withAlpha(base, 0.9f)),
      floatArrayOf(0f, 0.08f, 0.25f, 0.4f, 0.7f, 1f),
      Shader.TileMode.CLAMP,
    )
    canvas.drawRect(x0, y - thickness / 2f, x1, y + thickness / 2f, corePaint)

    if (style.crease) {
      val creaseColor = blend(base, Color.rgb(217, 255, 77), 0.5f)
      creasePaint.shader = LinearGradient(
        0f, 0f, 0f, height,
        intArrayOf(withAlpha(creaseColor, 0f), withAlpha(creaseColor, 0.85f), withAlpha(creaseColor, 0.85f), withAlpha(creaseColor, 0f)),
        floatArrayOf(0f, 0.08f, 0.92f, 1f),
        Shader.TileMode.CLAMP,
      )
      val half = 0.5f * density
      canvas.drawRect(width / 2f - half, 0f, width / 2f + half, height, creasePaint)
    }
  }

  private fun applyFlicker() {
    flickerAnimator?.cancel()
    flickerAnimator = null
    alpha = 1f
    if (!style.flicker || !isAttachedToWindow) {
      return
    }
    val steps = floatArrayOf(1f, 1f, 0.82f, 1f, 1f, 1f, 0.9f, 1f, 0.7f, 1f, 1f, 1f)
    flickerAnimator = ValueAnimator.ofInt(0, steps.size).apply {
      duration = 3100
      repeatCount = ValueAnimator.INFINITE
      interpolator = null
      addUpdateListener { animator ->
        val index = (animator.animatedValue as Int).coerceIn(0, steps.size - 1)
        alpha = steps[index]
      }
      start()
    }
  }

  private fun blend(from: Int, to: Int, fraction: Float): Int {
    val f = fraction.coerceIn(0f, 1f)
    fun channel(a: Int, b: Int) = Math.round(a + (b - a) * f)
    return Color.argb(
      channel(Color.alpha(from), Color.alpha(to)),
      channel(Color.red(from), Color.red(to)),
      channel(Color.green(from), Color.green(to)),
      channel(Color.blue(from), Color.blue(to)),
    )
  }

  private fun withAlpha(color: Int, alpha: Float): Int {
    return Color.argb(Math.round(255 * alpha.coerceIn(0f, 1f)), Color.red(color), Color.green(color), Color.blue(color))
  }
}
