import { NativeModule, registerWebModule } from 'expo';

import type { CrackOptions, CrackSide } from './ExpoCrack.types';

type Style = {
  y: number;
  thickness: number;
  color: string;
  side: CrackSide;
  crease: boolean;
  flicker: boolean;
};

const DEFAULT_STYLE: Style = {
  y: 0.62,
  thickness: 3,
  color: '#61FFCC',
  side: 'right',
  crease: false,
  flicker: true,
};

class ExpoCrackModule extends NativeModule {
  private style: Style = { ...DEFAULT_STYLE };
  private enabled = false;
  private root: HTMLDivElement | null = null;

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (typeof document === 'undefined') {
      return;
    }
    if (enabled) {
      this.render();
    } else {
      this.root?.remove();
      this.root = null;
    }
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  configure(options: CrackOptions): void {
    this.style = {
      y: options.y ?? this.style.y,
      thickness: options.thickness ?? this.style.thickness,
      color: options.color ?? this.style.color,
      side: options.side ?? this.style.side,
      crease: options.crease ?? this.style.crease,
      flicker: options.flicker ?? this.style.flicker,
    };
    if (this.enabled) {
      this.render();
    }
  }

  reset(): void {
    this.style = { ...DEFAULT_STYLE };
    if (this.enabled) {
      this.render();
    }
  }

  private render() {
    if (typeof document === 'undefined') {
      return;
    }
    const { y, thickness, color, side, crease } = this.style;

    if (!this.root) {
      this.root = document.createElement('div');
      this.root.className = 'expo-crack';
      document.body.appendChild(this.root);
    }
    const root = this.root;
    // The crack only flickers while a hinge moves, and the web has no hinge: it holds still here.
    root.style.cssText = ['position: fixed', 'inset: 0', 'pointer-events: none', 'z-index: 2147483647'].join(';');

    const left = side === 'left' ? '0' : '50%';
    const width = side === 'full' ? '100%' : '50%';
    root.innerHTML = `
      <div style="position:absolute;left:${left};width:${width};top:calc(${y * 100}% - ${thickness / 2}px);height:${thickness}px;
        background:linear-gradient(90deg, #ffffff 0%, ${color} 25%, #ffffff 40%, ${color} 70%, ${color} 100%);
        box-shadow:0 0 ${thickness * 1.6}px ${thickness * 0.5}px ${color};"></div>
      <div style="position:absolute;left:${left};width:${width};top:calc(${y * 100}% + 16px);height:1px;opacity:0.8;
        background:linear-gradient(90deg, ${color} 0%, #ffffff 20%, ${color} 55%, ${color} 100%);"></div>
      ${
        crease
          ? `<div style="position:absolute;left:calc(50% - 0.5px);width:1px;top:0;bottom:0;
        background:linear-gradient(180deg, transparent 0%, ${color} 8%, ${color} 92%, transparent 100%);opacity:0.85;"></div>`
          : ''
      }`;
  }
}

const webModule = registerWebModule(ExpoCrackModule, 'ExpoCrackModule');

// The crack is on by default, just like on a real iPhone Duo.
if (typeof document !== 'undefined') {
  webModule.setEnabled(true);
}

export default webModule;
