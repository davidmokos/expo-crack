package expo.modules.crack

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record

class CrackOptions : Record {
  @Field val y: Double? = null
  @Field val thickness: Double? = null
  @Field val color: String? = null
  @Field val side: String? = null
  @Field val crease: Boolean? = null
  @Field val flicker: Boolean? = null
  @Field val hideWhenFolded: Boolean? = null
  @Field val reactToHinge: Boolean? = null
}

class ExpoCrackModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoCrack")

    OnActivityEntersForeground {
      CrackOverlay.attach(appContext.currentActivity)
    }

    Function("setEnabled") { enabled: Boolean ->
      CrackOverlay.setEnabled(appContext.currentActivity, enabled)
    }

    Function("isEnabled") {
      CrackOverlay.isEnabled
    }

    Function("configure") { options: CrackOptions ->
      val color = options.color?.let { CrackStyle.parseColor(it) }
      val side = options.side?.takeIf { it == "left" || it == "right" || it == "full" }
      CrackOverlay.update { current ->
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
      CrackOverlay.reset()
    }
  }
}
