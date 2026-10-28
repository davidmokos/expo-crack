/** Which half of the screen the line crosses. The authentic one is `'right'`. */
export type CrackSide = 'left' | 'right' | 'full';

export type CrackOptions = {
  /**
   * Vertical position of the line as a fraction of the screen height (0 = top, 1 = bottom).
   * @default 0.62
   */
  y?: number;
  /**
   * Thickness of the bright core of the line, in points.
   * @default 3
   */
  thickness?: number;
  /**
   * Color of the line as a hex string (`#RGB`, `#RRGGBB` or `#RRGGBBAA`).
   * @default '#61FFCC'
   */
  color?: string;
  /**
   * Which half of the screen the line crosses, starting at the fold.
   * @default 'right'
   */
  side?: CrackSide;
  /**
   * Also draw the faint vertical line along the fold.
   * @default false
   */
  crease?: boolean;
  /**
   * Let the crack flicker while the hinge is moving (iPhone Duo). It holds still when the hinge is not
   * moving, and on platforms without a hinge it never flickers.
   * @default true
   */
  flicker?: boolean;
  /**
   * On a foldable, hide the line while the device is closed and show it on the open inner display,
   * which is where it belongs. Uses the hinge on iOS 27.1 and later (iPhone Duo); other devices never report
   * a hinge, so the line stays visible there.
   * @default true
   */
  hideWhenFolded?: boolean;
  /**
   * On a foldable, react to the hinge angle (iOS 27.1 and later, iPhone Duo). Around half-open (118° to 142°)
   * the whole panel on the line's side glitches with rolling bands; between 60° and 118° and between 142° and
   * 165° a hairline second line shows; between 95° and 150° a faint vertical line shows just right of the
   * hinge. Fully open is the classic single line.
   * @default true
   */
  reactToHinge?: boolean;
};
