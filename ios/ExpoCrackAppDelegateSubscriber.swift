import ExpoModulesCore

/// Turns the crack on at launch, before any JavaScript runs. Installing the package is enough.
public class ExpoCrackAppDelegateSubscriber: ExpoAppDelegateSubscriber {
  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if CrackOverlay.autoStartEnabled {
      CrackOverlay.shared.setEnabled(true)
    }
    return false
  }
}
