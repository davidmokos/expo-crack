import UIKit

/// Visual configuration of the crack. Mirrors `CrackOptions` on the JS side.
struct CrackStyle {
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
  var color: UIColor = CrackStyle.defaultColor
  /// Which half of the screen the line crosses. The authentic one is the right half.
  var side: Side = .right
  /// Also draw the faint vertical line along the fold.
  var crease: Bool = false
  /// Let the line flicker a little.
  var flicker: Bool = true
  /// On a foldable, hide the line while the device is closed and show it on the open inner display.
  var hideWhenFolded: Bool = true
  /// On a foldable, react to the hinge angle: extra lines and a whole-panel glitch at some angles.
  var reactToHinge: Bool = true
}

/// What the overlay draws for a hinge angle, in degrees (0 is closed, 180 is flat).
struct CrackPose: Equatable {
  var showsLine = true
  var showsThinLine = false
  var showsHingeLine = false
  var showsPanelGlitch = false

  /// A device without a hinge, or a hinge the overlay is not reacting to: the classic line only.
  static let plain = CrackPose()

  static func forHingeAngle(_ degrees: Double) -> CrackPose {
    var pose = CrackPose()
    pose.showsLine = degrees >= 25
    pose.showsThinLine = (60..<118).contains(degrees) || (142...165).contains(degrees)
    pose.showsHingeLine = (95...150).contains(degrees)
    pose.showsPanelGlitch = (118...142).contains(degrees)
    return pose
  }
}

#if os(iOS)

/// Owns the overlay window and keeps it attached to the active scene.
final class CrackOverlay {
  static let shared = CrackOverlay()

  /// `ExpoCrackAutoStart` in Info.plist (written by the config plugin). Defaults to true: the crack is a feature.
  static var autoStartEnabled: Bool {
    return (Bundle.main.object(forInfoDictionaryKey: "ExpoCrackAutoStart") as? Bool) ?? true
  }

  private(set) var isEnabled = false
  private(set) var style = CrackStyle()
  private var window: CrackWindow?
  private var observers: [NSObjectProtocol] = []
  private var hingeInteraction: UIInteraction?
  private var hingeIsClosed = false
  private var hingeAngle: Double?

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

  func update(_ change: @escaping (inout CrackStyle) -> Void) {
    onMain { [self] in
      change(&style)
      window?.lineView.style = style
      refreshVisibility()
    }
  }

  func reset() {
    update { style in
      style = CrackStyle()
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
      attachHinge(near: window)
      refreshVisibility()
      return
    }
    guard let scene = Self.activeWindowScene() else {
      return
    }
    let window = CrackWindow(windowScene: scene)
    window.lineView.style = style
    self.window = window
    attachHinge(near: window)
    refreshVisibility()
  }

  private func detach() {
    window?.isHidden = true
    window = nil
    detachHinge()
  }

  private func refreshVisibility() {
    guard let window else {
      return
    }
    let pose: CrackPose
    if style.reactToHinge, let angle = hingeAngle {
      pose = .forHingeAngle(angle)
    } else {
      pose = .plain
    }
    window.lineView.pose = pose
    let hiddenByFold = style.hideWhenFolded && hingeIsClosed
    window.isHidden = !isEnabled || hiddenByFold || !pose.showsLine
  }

  /// Watches the device hinge (iPhone Duo, iOS 27.1+) through a `UIHingeInteraction` on the app's key window,
  /// the same way `expo-hinge` does. Devices without a hinge never report one, so they get the classic line.
  private func attachHinge(near window: UIWindow) {
    #if canImport(UIKit, _version: 9127.0.85) // iOS 27.1 SDK
    guard #available(iOS 27.1, *) else {
      return
    }
    let host = window.windowScene?.keyWindow ?? window
    if let hingeInteraction, hingeInteraction.view === host {
      return
    }
    detachHinge()
    let interaction = UIHingeInteraction { [weak self] _, update in
      guard let self else {
        return
      }
      if let hinge = update.hinge {
        self.hingeIsClosed = hinge.status == .closed
        self.hingeAngle = Double(hinge.angle) * 180 / .pi
      } else {
        self.hingeIsClosed = false
        self.hingeAngle = nil
      }
      self.refreshVisibility()
    }
    host.addInteraction(interaction)
    hingeInteraction = interaction
    #endif
  }

  private func detachHinge() {
    if let hingeInteraction {
      hingeInteraction.view?.removeInteraction(hingeInteraction)
    }
    hingeInteraction = nil
    hingeIsClosed = false
    hingeAngle = nil
  }

  private static func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
      ?? scenes.first { !$0.windows.isEmpty }
  }
}

/// A transparent, touch-transparent window that floats above everything the app draws.
final class CrackWindow: UIWindow {
  let lineView = CrackLineView()

  override init(windowScene: UIWindowScene) {
    super.init(windowScene: windowScene)
    windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1000)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    let controller = CrackViewController()
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
/// so the overlay never changes how the app looks (apart from the crack, obviously).
final class CrackViewController: UIViewController {
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

/// Draws the crack: the main line (glow, banded core, bloom at the fold), a hairline second line,
/// a faint vertical line right of the hinge, a whole-panel glitch, and an optional crease. Which of
/// them show depends on `pose`, which follows the hinge angle on a foldable.
final class CrackLineView: UIView {
  var style = CrackStyle() {
    didSet {
      applyStyle()
      setNeedsLayout()
    }
  }

  var pose = CrackPose.plain {
    didSet {
      if pose != oldValue {
        applyPose()
      }
    }
  }

  private let panelLayer = CALayer()
  private let bandsLayer = CAGradientLayer()
  private let hingeLineLayer = CAGradientLayer()
  private let thinLayer = CAGradientLayer()
  private let creaseLayer = CAGradientLayer()
  private let lineGroup = CALayer()
  private let glowLayer = CALayer()
  private let coreLayer = CAGradientLayer()
  private let bloomLayer = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    isOpaque = false

    panelLayer.masksToBounds = true
    bandsLayer.startPoint = CGPoint(x: 0.5, y: 0)
    bandsLayer.endPoint = CGPoint(x: 0.5, y: 1)
    panelLayer.addSublayer(bandsLayer)

    hingeLineLayer.startPoint = CGPoint(x: 0.5, y: 0)
    hingeLineLayer.endPoint = CGPoint(x: 0.5, y: 1)

    thinLayer.startPoint = CGPoint(x: 0, y: 0.5)
    thinLayer.endPoint = CGPoint(x: 1, y: 0.5)

    creaseLayer.startPoint = CGPoint(x: 0.5, y: 0)
    creaseLayer.endPoint = CGPoint(x: 0.5, y: 1)

    glowLayer.shadowOffset = .zero
    glowLayer.shadowOpacity = 0.95

    coreLayer.startPoint = CGPoint(x: 0, y: 0.5)
    coreLayer.endPoint = CGPoint(x: 1, y: 0.5)

    bloomLayer.type = .radial
    bloomLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
    bloomLayer.endPoint = CGPoint(x: 1, y: 1)

    for sublayer in [glowLayer, coreLayer, bloomLayer] {
      lineGroup.addSublayer(sublayer)
    }
    for sublayer in [panelLayer, hingeLineLayer, thinLayer, creaseLayer, lineGroup] {
      layer.addSublayer(sublayer)
    }
    applyStyle()
    applyPose()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applyAnimations),
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
    applyAnimations()
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
    let width = max(0, x1 - x0)

    lineGroup.frame = bounds
    let lineFrame = CGRect(x: x0, y: y - thickness / 2, width: width, height: thickness)
    coreLayer.frame = lineFrame
    glowLayer.frame = lineFrame.insetBy(dx: 0, dy: -thickness * 0.5)
    glowLayer.shadowRadius = max(3, thickness * 1.6)
    glowLayer.shadowPath = UIBezierPath(rect: glowLayer.bounds).cgPath

    let bloomSize = thickness * 9
    let bloomX = style.side == .left ? x1 : x0
    bloomLayer.frame = CGRect(x: bloomX - bloomSize / 2, y: y - bloomSize / 2, width: bloomSize, height: bloomSize)
    bloomLayer.isHidden = style.side == .full

    // The hairline sits higher up the panel, where the second defect usually shows.
    let thinY = (bounds.height * 0.41).rounded()
    thinLayer.frame = CGRect(x: x0, y: thinY, width: width, height: 1)

    // Just right of the hinge (or left, when the line is on the left half).
    let hingeOffset: CGFloat = style.side == .left ? -14 : 14
    hingeLineLayer.frame = CGRect(x: (bounds.midX + hingeOffset).rounded(), y: 0, width: 1, height: bounds.height)

    panelLayer.frame = CGRect(x: x0, y: 0, width: width, height: bounds.height)
    bandsLayer.frame = panelLayer.bounds.insetBy(dx: -8, dy: -48)

    creaseLayer.frame = CGRect(x: (bounds.midX - 0.5).rounded(), y: 0, width: 1, height: bounds.height)
    creaseLayer.isHidden = !style.crease
  }

  private func applyStyle() {
    let base = style.color
    let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    let hot = base.crackBlended(with: white, fraction: 0.45)
    let mid = base.crackBlended(with: white, fraction: 0.2)

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

    thinLayer.colors = [
      base.withAlphaComponent(0.9).cgColor,
      hot.withAlphaComponent(0.95).cgColor,
      base.withAlphaComponent(0.6).cgColor,
      hot.withAlphaComponent(0.9).cgColor,
    ]
    thinLayer.locations = [0, 0.3, 0.6, 1]

    let lime = UIColor(red: 0.85, green: 1.0, blue: 0.3, alpha: 1.0)
    let hingeTint = base.crackBlended(with: lime, fraction: 0.5)
    hingeLineLayer.colors = [
      hingeTint.withAlphaComponent(0).cgColor,
      hingeTint.withAlphaComponent(0.8).cgColor,
      hingeTint.withAlphaComponent(0.8).cgColor,
      hingeTint.withAlphaComponent(0).cgColor,
    ]
    hingeLineLayer.locations = [0, 0.12, 0.88, 1]

    let creaseTint = base.crackBlended(with: lime, fraction: 0.5)
    creaseLayer.colors = [
      creaseTint.withAlphaComponent(0).cgColor,
      creaseTint.withAlphaComponent(0.85).cgColor,
      creaseTint.withAlphaComponent(0.85).cgColor,
      creaseTint.withAlphaComponent(0).cgColor,
    ]
    creaseLayer.locations = [0, 0.08, 0.92, 1]

    panelLayer.backgroundColor = base.withAlphaComponent(0.1).cgColor
    applyBands(base: base)
    applyAnimations()
  }

  private func applyPose() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    thinLayer.isHidden = !pose.showsThinLine
    hingeLineLayer.isHidden = !pose.showsHingeLine
    panelLayer.isHidden = !pose.showsPanelGlitch
    CATransaction.commit()
    applyAnimations()
  }

  /// Rolling bands of uneven height, like a panel driver that lost sync. Deterministic, so every
  /// launch looks the same broken.
  private func applyBands(base: UIColor) {
    let magenta = UIColor(red: 1.0, green: 0.3, blue: 0.8, alpha: 1.0)
    let tints = [
      base.withAlphaComponent(0.28),
      UIColor.clear,
      magenta.withAlphaComponent(0.12),
      UIColor.clear,
      UIColor(red: 1, green: 1, blue: 1, alpha: 0.18),
      UIColor.clear,
    ]
    var seed: UInt32 = 0x9E37_79B9
    func next() -> CGFloat {
      seed = seed &* 1_664_525 &+ 1_013_904_223
      return CGFloat(seed >> 8) / CGFloat(1 << 24)
    }
    var colors: [CGColor] = []
    var locations: [NSNumber] = []
    var position: CGFloat = 0
    var index = 0
    while position < 1 {
      let height = 0.01 + next() * 0.06
      let end = min(1, position + height)
      let tint = tints[index % tints.count].cgColor
      colors.append(tint)
      colors.append(tint)
      locations.append(NSNumber(value: Double(position)))
      locations.append(NSNumber(value: Double(end)))
      position = end
      index += 1
    }
    bandsLayer.colors = colors
    bandsLayer.locations = locations
  }

  @objc private func applyAnimations() {
    for animated in [lineGroup, thinLayer, hingeLineLayer, panelLayer, bandsLayer] {
      animated.removeAllAnimations()
      animated.opacity = 1
    }
    guard style.flicker, !UIAccessibility.isReduceMotionEnabled else {
      return
    }
    lineGroup.add(Self.flicker([1, 1, 0.82, 1, 0, 1, 1, 0.9, 1, 0.7, 1, 1, 0.35, 1, 1], duration: 3.1), forKey: "crack.flicker")
    if pose.showsThinLine {
      thinLayer.add(Self.flicker([1, 1, 0, 1, 1, 0.6, 1, 0, 0, 1, 1, 0.3, 1], duration: 1.7), forKey: "crack.flicker")
    }
    if pose.showsHingeLine {
      hingeLineLayer.add(Self.flicker([1, 0, 0, 1, 1, 0, 1, 0.5, 0, 0, 1, 1, 0], duration: 2.3), forKey: "crack.flicker")
    }
    if pose.showsPanelGlitch {
      panelLayer.add(Self.flicker([1, 0.55, 1, 0.3, 0.9, 1, 0.45, 1, 0.7, 0.2, 1, 1], duration: 0.9), forKey: "crack.flicker")
      let roll = CAKeyframeAnimation(keyPath: "transform.translation.y")
      roll.values = [0.0, 3.0, -2.0, 0.0, 5.0, 0.0, -4.0, 1.0, 0.0, 7.0, -1.0, 0.0]
      roll.calculationMode = .discrete
      roll.duration = 0.7
      roll.repeatCount = .infinity
      bandsLayer.add(roll, forKey: "crack.roll")
      let tear = CAKeyframeAnimation(keyPath: "transform.translation.x")
      tear.values = [0.0, 2.0, -3.0, 0.0, 0.0, 4.0, 0.0, -2.0, 0.0]
      tear.calculationMode = .discrete
      tear.duration = 1.1
      tear.repeatCount = .infinity
      bandsLayer.add(tear, forKey: "crack.tear")
    }
  }

  private static func flicker(_ values: [Double], duration: CFTimeInterval) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.values = values
    animation.calculationMode = .discrete
    animation.duration = duration
    animation.repeatCount = .infinity
    return animation
  }
}

#else

/// tvOS has no fold, no green line and no status bar to protect: the API exists but does nothing.
final class CrackOverlay {
  static let shared = CrackOverlay()
  static var autoStartEnabled: Bool { return false }

  private(set) var isEnabled = false
  private(set) var style = CrackStyle()

  private init() {}

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
  }

  func update(_ change: @escaping (inout CrackStyle) -> Void) {
    change(&style)
  }

  func reset() {
    style = CrackStyle()
  }
}

#endif

extension UIColor {
  func crackBlended(with other: UIColor, fraction: CGFloat) -> UIColor {
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
  convenience init?(crackHex hexString: String) {
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
