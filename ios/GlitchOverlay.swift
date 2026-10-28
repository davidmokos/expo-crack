import UIKit

/// Visual configuration of the glitch line. Mirrors `GlitchOptions` on the JS side.
struct GlitchStyle {
  enum Side: String {
    case left
    case right
    case full
  }

  /// The minty green you get for free with a new iPhone Duo.
  static let defaultColor = UIColor(red: 0.38, green: 1.0, blue: 0.80, alpha: 1.0)

  /// Vertical position of the line as a fraction of the window height.
  var y: CGFloat = 0.62
  /// Thickness of the bright core, in points.
  var thickness: CGFloat = 3
  var color: UIColor = GlitchStyle.defaultColor
  /// Which half of the screen the line crosses. The authentic one is the right half.
  var side: Side = .right
  /// Also draw the faint vertical line along the fold.
  var crease: Bool = false
  /// Let the line flicker a little.
  var flicker: Bool = true
}

#if os(iOS)

/// Owns the overlay window and keeps it attached to the active scene.
final class GlitchOverlay {
  static let shared = GlitchOverlay()

  /// `ExpoGlitchAutoStart` in Info.plist (written by the config plugin). Defaults to true: the glitch is a feature.
  static var autoStartEnabled: Bool {
    return (Bundle.main.object(forInfoDictionaryKey: "ExpoGlitchAutoStart") as? Bool) ?? true
  }

  private(set) var isEnabled = false
  private(set) var style = GlitchStyle()
  private var window: GlitchWindow?
  private var observers: [NSObjectProtocol] = []

  private init() {}

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    onMain { [self] in
      if enabled {
        startObserving()
        attachIfPossible()
      } else {
        detach()
      }
    }
  }

  func update(_ change: @escaping (inout GlitchStyle) -> Void) {
    onMain { [self] in
      change(&style)
      window?.lineView.style = style
    }
  }

  func reset() {
    update { style in
      style = GlitchStyle()
    }
  }

  // MARK: - Internals

  private func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
      block()
    } else {
      DispatchQueue.main.async(execute: block)
    }
  }

  private func startObserving() {
    guard observers.isEmpty else {
      return
    }
    let center = NotificationCenter.default
    let triggers: [Notification.Name] = [
      UIScene.didActivateNotification,
      UIScene.willEnterForegroundNotification,
      UIApplication.didBecomeActiveNotification,
    ]
    for name in triggers {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.attachIfPossible()
      })
    }
    observers.append(center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] note in
      guard let self, let scene = note.object as? UIWindowScene, self.window?.windowScene === scene else {
        return
      }
      self.window = nil
    })
  }

  private func attachIfPossible() {
    guard isEnabled else {
      return
    }
    if let window, window.windowScene != nil {
      window.isHidden = false
      return
    }
    guard let scene = Self.activeWindowScene() else {
      return
    }
    let window = GlitchWindow(windowScene: scene)
    window.lineView.style = style
    window.isHidden = false
    self.window = window
  }

  private func detach() {
    window?.isHidden = true
    window = nil
  }

  private static func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
      ?? scenes.first { !$0.windows.isEmpty }
  }
}

/// A transparent, touch-transparent window that floats above everything the app draws.
final class GlitchWindow: UIWindow {
  let lineView = GlitchLineView()

  override init(windowScene: UIWindowScene) {
    super.init(windowScene: windowScene)
    windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1000)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    let controller = GlitchViewController()
    controller.view = lineView
    rootViewController = controller
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    return nil
  }
}

/// Forwards status bar and home indicator preferences to the app's own view controllers,
/// so the overlay never changes how the app looks (apart from the glitch, obviously).
final class GlitchViewController: UIViewController {
  override var prefersStatusBarHidden: Bool {
    return appViewController?.prefersStatusBarHidden ?? false
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return appViewController?.preferredStatusBarStyle ?? .default
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return appViewController?.prefersHomeIndicatorAutoHidden ?? false
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .all
  }

  private var appViewController: UIViewController? {
    guard let ownWindow = view.window, let scene = ownWindow.windowScene else {
      return nil
    }
    let appWindow = scene.keyWindow.flatMap { $0 === ownWindow ? nil : $0 }
      ?? scene.windows.first { $0 !== ownWindow && !$0.isHidden && $0.rootViewController != nil }
    var controller = appWindow?.rootViewController
    while let next = controller?.presentedViewController ?? controller?.childForStatusBarStyle {
      controller = next
    }
    return controller
  }
}

/// Draws the line: a soft glow, a banded bright core, a bloom where it meets the fold and an optional crease.
final class GlitchLineView: UIView {
  var style = GlitchStyle() {
    didSet {
      applyStyle()
      setNeedsLayout()
    }
  }

  private let glowLayer = CALayer()
  private let coreLayer = CAGradientLayer()
  private let bloomLayer = CAGradientLayer()
  private let creaseLayer = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    isOpaque = false

    glowLayer.shadowOffset = .zero
    glowLayer.shadowOpacity = 0.95

    coreLayer.startPoint = CGPoint(x: 0, y: 0.5)
    coreLayer.endPoint = CGPoint(x: 1, y: 0.5)

    bloomLayer.type = .radial
    bloomLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
    bloomLayer.endPoint = CGPoint(x: 1, y: 1)

    creaseLayer.startPoint = CGPoint(x: 0.5, y: 0)
    creaseLayer.endPoint = CGPoint(x: 0.5, y: 1)

    for sublayer in [glowLayer, coreLayer, bloomLayer, creaseLayer] {
      layer.addSublayer(sublayer)
    }
    applyStyle()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applyFlicker),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    applyFlicker()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }

    let bounds = self.bounds
    let thickness = max(1, style.thickness)
    let y = (bounds.height * min(max(style.y, 0), 1)).rounded()
    let x0: CGFloat
    let x1: CGFloat
    switch style.side {
    case .left:
      x0 = bounds.minX
      x1 = bounds.midX
    case .right:
      x0 = bounds.midX
      x1 = bounds.maxX
    case .full:
      x0 = bounds.minX
      x1 = bounds.maxX
    }
    let lineFrame = CGRect(x: x0, y: y - thickness / 2, width: max(0, x1 - x0), height: thickness)

    coreLayer.frame = lineFrame
    glowLayer.frame = lineFrame.insetBy(dx: 0, dy: -thickness * 0.5)
    glowLayer.shadowRadius = max(3, thickness * 1.6)
    glowLayer.shadowPath = UIBezierPath(rect: glowLayer.bounds).cgPath

    let bloomSize = thickness * 9
    let bloomX = style.side == .left ? x1 : x0
    bloomLayer.frame = CGRect(x: bloomX - bloomSize / 2, y: y - bloomSize / 2, width: bloomSize, height: bloomSize)
    bloomLayer.isHidden = style.side == .full

    creaseLayer.frame = CGRect(x: (bounds.midX - 0.5).rounded(), y: 0, width: 1, height: bounds.height)
    creaseLayer.isHidden = !style.crease
  }

  private func applyStyle() {
    let base = style.color
    let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    let hot = base.glitchBlended(with: white, fraction: 0.8)
    let mid = base.glitchBlended(with: white, fraction: 0.35)

    coreLayer.colors = [hot, mid, base, hot, mid, base.withAlphaComponent(0.9)].map { $0.cgColor }
    coreLayer.locations = [0, 0.08, 0.25, 0.4, 0.7, 1]

    glowLayer.backgroundColor = base.withAlphaComponent(0.55).cgColor
    glowLayer.shadowColor = base.cgColor

    bloomLayer.colors = [
      hot.withAlphaComponent(0.9).cgColor,
      base.withAlphaComponent(0.35).cgColor,
      UIColor.clear.cgColor,
    ]
    bloomLayer.locations = [0, 0.35, 1]

    let creaseTint = UIColor(red: 0.85, green: 1.0, blue: 0.3, alpha: 1.0)
    let crease = base.glitchBlended(with: creaseTint, fraction: 0.5)
    creaseLayer.colors = [
      crease.withAlphaComponent(0).cgColor,
      crease.withAlphaComponent(0.85).cgColor,
      crease.withAlphaComponent(0.85).cgColor,
      crease.withAlphaComponent(0).cgColor,
    ]
    creaseLayer.locations = [0, 0.08, 0.92, 1]

    applyFlicker()
  }

  @objc private func applyFlicker() {
    layer.removeAnimation(forKey: "glitch.flicker")
    guard style.flicker, !UIAccessibility.isReduceMotionEnabled else {
      layer.opacity = 1
      return
    }
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.values = [1.0, 1.0, 0.82, 1.0, 1.0, 1.0, 0.9, 1.0, 0.7, 1.0, 1.0, 1.0]
    animation.calculationMode = .discrete
    animation.duration = 3.1
    animation.repeatCount = .infinity
    layer.add(animation, forKey: "glitch.flicker")
  }
}

#else

/// tvOS has no fold, no green line and no status bar to protect: the API exists but does nothing.
final class GlitchOverlay {
  static let shared = GlitchOverlay()
  static var autoStartEnabled: Bool { return false }

  private(set) var isEnabled = false
  private(set) var style = GlitchStyle()

  private init() {}

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
  }

  func update(_ change: @escaping (inout GlitchStyle) -> Void) {
    change(&style)
  }

  func reset() {
    style = GlitchStyle()
  }
}

#endif

extension UIColor {
  func glitchBlended(with other: UIColor, fraction: CGFloat) -> UIColor {
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    let f = min(max(fraction, 0), 1)
    return UIColor(
      red: r1 + (r2 - r1) * f,
      green: g1 + (g2 - g1) * f,
      blue: b1 + (b2 - b1) * f,
      alpha: a1 + (a2 - a1) * f
    )
  }

  /// Parses `#RGB`, `#RRGGBB` and `#RRGGBBAA` (the `#` is optional).
  convenience init?(glitchHex hexString: String) {
    var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
    if hex.hasPrefix("#") {
      hex.removeFirst()
    }
    if hex.count == 3 {
      hex = hex.map { "\($0)\($0)" }.joined()
    }
    guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else {
      return nil
    }
    let hasAlpha = hex.count == 8
    let shift: UInt64 = hasAlpha ? 8 : 0
    let r = CGFloat((value >> (16 + shift)) & 0xff) / 255
    let g = CGFloat((value >> (8 + shift)) & 0xff) / 255
    let b = CGFloat((value >> shift) & 0xff) / 255
    let a = hasAlpha ? CGFloat(value & 0xff) / 255 : 1
    self.init(red: r, green: g, blue: b, alpha: a)
  }
}
