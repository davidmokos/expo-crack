import type { GlitchOptions } from './ExpoGlitch.types';
import ExpoGlitchModule from './ExpoGlitchModule';

export * from './ExpoGlitch.types';

let warned = false;

function native() {
  if (!ExpoGlitchModule && !warned) {
    warned = true;
    console.warn(
      '[expo-glitch] The native module is not available. The green line needs a development build ' +
        '(it does not run in Expo Go), so rebuild your app after installing expo-glitch.'
    );
  }
  return ExpoGlitchModule;
}

/**
 * Shows the green line. It is already on when the app starts, so you only need this after `disable()`.
 * Pass options to restyle it in the same call.
 */
export function enable(options?: GlitchOptions): void {
  if (options) {
    configure(options);
  }
  native()?.setEnabled(true);
}

/** Hides the green line. Your users will ask for it back. */
export function disable(): void {
  native()?.setEnabled(false);
}

/** Flips the green line and returns the new state. */
export function toggle(): boolean {
  const next = !isEnabled();
  native()?.setEnabled(next);
  return next;
}

/** Whether the green line is currently showing. */
export function isEnabled(): boolean {
  return native()?.isEnabled() ?? false;
}

/** Restyles the line. Only the options you pass change; the rest keep their current values. */
export function configure(options: GlitchOptions): void {
  native()?.configure(options);
}

/** Back to the factory defaults: right half, 62% down, mint green, flickering. */
export function reset(): void {
  native()?.reset();
}

const Glitch = { enable, disable, toggle, isEnabled, configure, reset };

export default Glitch;
