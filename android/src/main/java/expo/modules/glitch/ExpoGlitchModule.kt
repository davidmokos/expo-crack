package expo.modules.glitch

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

class GlitchOptions : Record {
  @Field val y: Double? = null
  @Field val thickness: Double? = null
  @Field val color: String? = null
  @Field val side: String? = null
  @Field val crease: Boolean? = null
  @Field val flicker: Boolean? = null
}

class ExpoGlitchModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoGlitch")

    OnActivityEntersForeground {
      GlitchOverlay.attach(appContext.currentActivity)
    }

    Function("setEnabled") { enabled: Boolean ->
      GlitchOverlay.setEnabled(appContext.currentActivity, enabled)
    }

    Function("isEnabled") {
      GlitchOverlay.isEnabled
    }

    Function("configure") { options: GlitchOptions ->
      val color = options.color?.let { GlitchStyle.parseColor(it) }
      val side = options.side?.takeIf { it == "left" || it == "right" || it == "full" }
      GlitchOverlay.update { current ->
        current.copy(
          y = options.y?.toFloat() ?: current.y,
          thickness = options.thickness?.toFloat() ?: current.thickness,
          color = color ?: current.color,
          side = side ?: current.side,
          crease = options.crease ?: current.crease,
          flicker = options.flicker ?: current.flicker,
        )
      }
    }

    Function("reset") {
      GlitchOverlay.reset()
    }
  }
}
