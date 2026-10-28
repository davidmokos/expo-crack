import { NativeModule, requireOptionalNativeModule } from 'expo';

import type { GlitchOptions } from './ExpoGlitch.types';

declare class ExpoGlitchModule extends NativeModule<{}> {
  setEnabled(enabled: boolean): void;
  isEnabled(): boolean;
  configure(options: GlitchOptions): void;
  reset(): void;
}

// Optional so that apps still run where the native code is missing (Expo Go, a stale dev client).
export default requireOptionalNativeModule<ExpoGlitchModule>('ExpoGlitch');
