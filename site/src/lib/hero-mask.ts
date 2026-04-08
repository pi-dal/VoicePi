export interface HeroMaskRect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface HeroMaskVars {
  left: string;
  right: string;
  top: string;
  bottom: string;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function resolveHeroMaskVars(
  rect: HeroMaskRect,
  viewportWidth: number,
  viewportHeight: number,
  bleed = 0
): HeroMaskVars {
  const left = clamp(rect.left - bleed, 0, viewportWidth);
  const top = clamp(rect.top - bleed, 0, viewportHeight);
  const right = clamp(rect.right + bleed, 0, viewportWidth);
  const bottom = clamp(rect.bottom + bleed, 0, viewportHeight);

  return {
    left: `${left}px`,
    right: `${right}px`,
    top: `${top}px`,
    bottom: `${bottom}px`
  };
}
