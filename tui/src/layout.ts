import { grid, NORMAL } from "./legend.ts";

export interface Size {
  w: number;
  h: number;
}

export interface Layout {
  leftW: number;
  midW: number;
  rightW: number;
  /** Rows of the legend, fixed by the normal legend so panes do not jump when a prompt opens. */
  legendRows: number;
  /** Rows of each pane including its header row. */
  paneH: number;
  /** Rows available for list items. */
  listRows: number;
  tooSmall: boolean;
}

export const MIN_W = 60;
export const MIN_H = 14;

const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, n));

export function layout(size: Size): Layout {
  const legendRows = grid(NORMAL, size.w).rows;
  const paneH = Math.max(2, size.h - 2 - legendRows); // top bar and message line
  const leftW = clamp(Math.floor(size.w * 0.25), 20, 32);
  const rightW = clamp(Math.floor(size.w * 0.34), 24, 64);
  return {
    leftW,
    rightW,
    midW: size.w - leftW - rightW,
    legendRows,
    paneH,
    listRows: paneH - 1,
    tooSmall: size.w < MIN_W || size.h < MIN_H,
  };
}
