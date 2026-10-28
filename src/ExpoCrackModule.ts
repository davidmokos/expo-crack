import { NativeModule, requireOptionalNativeModule } from 'expo';

import type { CrackOptions } from './ExpoCrack.types';

declare class ExpoCrackModule extends NativeModule {
  setEnabled(enabled: boolean): void;
  isEnabled(): boolean;
  configure(options: CrackOptions): void;
  reset(): void;
}

// Optional so that apps still run where the native code is missing (Expo Go, a stale dev client).
export default requireOptionalNativeModule<ExpoCrackModule>('ExpoCrack');
