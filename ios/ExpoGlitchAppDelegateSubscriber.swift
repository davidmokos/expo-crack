import ExpoModulesCore

/// Turns the glitch on at launch, before any JavaScript runs. Installing the package is enough.
public class ExpoGlitchAppDelegateSubscriber: ExpoAppDelegateSubscriber {
  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if GlitchOverlay.autoStartEnabled {
      GlitchOverlay.shared.setEnabled(true)
    }
    return false
  }
}
