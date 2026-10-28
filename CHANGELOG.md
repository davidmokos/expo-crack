# Changelog

## 0.1.0

- The green line, on by default, from the fold to the right edge at 62% of the screen height.
- On an iPhone Duo the line hides while the device is closed and shows on the open inner display (`hideWhenFolded`, iOS 27.1+).
- Reacts to the hinge angle on an iPhone Duo: a whole-panel glitch around half-open, a hairline second line and a faint vertical line near the hinge in some angle bands (`reactToHinge`).
- `enable`, `disable`, `toggle`, `isEnabled`, `configure` and `reset` on iOS, Android and web.
- Config plugin with `autoStart: false` to launch without the line.
- tvOS builds compile, with no line.
