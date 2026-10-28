import ExpoModulesCore

struct GlitchOptions: Record {
  @Field var y: Double?
  @Field var thickness: Double?
  @Field var color: String?
  @Field var side: String?
  @Field var crease: Bool?
  @Field var flicker: Bool?
}

public class ExpoGlitchModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoGlitch")

    OnCreate {
      if GlitchOverlay.autoStartEnabled {
        GlitchOverlay.shared.setEnabled(true)
      }
    }

    Function("setEnabled") { (enabled: Bool) in
      GlitchOverlay.shared.setEnabled(enabled)
    }

    Function("isEnabled") { () -> Bool in
      return GlitchOverlay.shared.isEnabled
    }

    Function("configure") { (options: GlitchOptions) in
      let color = options.color.flatMap { UIColor(glitchHex: $0) }
      let side = options.side.flatMap { GlitchStyle.Side(rawValue: $0) }
      GlitchOverlay.shared.update { style in
        if let y = options.y {
          style.y = CGFloat(y)
        }
        if let thickness = options.thickness {
          style.thickness = CGFloat(thickness)
        }
        if let color {
          style.color = color
        }
        if let side {
          style.side = side
        }
        if let crease = options.crease {
          style.crease = crease
        }
        if let flicker = options.flicker {
          style.flicker = flicker
        }
      }
    }

    Function("reset") {
      GlitchOverlay.shared.reset()
    }
  }
}
