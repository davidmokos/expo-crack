import ExpoModulesCore

struct CrackOptions: Record {
  @Field var y: Double?
  @Field var thickness: Double?
  @Field var color: String?
  @Field var side: String?
  @Field var crease: Bool?
  @Field var flicker: Bool?
  @Field var hideWhenFolded: Bool?
}

public class ExpoCrackModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoCrack")

    OnCreate {
      if CrackOverlay.autoStartEnabled {
        CrackOverlay.shared.setEnabled(true)
      }
    }

    Function("setEnabled") { (enabled: Bool) in
      CrackOverlay.shared.setEnabled(enabled)
    }

    Function("isEnabled") { () -> Bool in
      return CrackOverlay.shared.isEnabled
    }

    Function("configure") { (options: CrackOptions) in
      let color = options.color.flatMap { UIColor(crackHex: $0) }
      let side = options.side.flatMap { CrackStyle.Side(rawValue: $0) }
      CrackOverlay.shared.update { style in
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
        if let hideWhenFolded = options.hideWhenFolded {
          style.hideWhenFolded = hideWhenFolded
        }
      }
    }

    Function("reset") {
      CrackOverlay.shared.reset()
    }
  }
}
