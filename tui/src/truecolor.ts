// Truecolor handling: detection, the override order, the path of the saved
// choice, and the hex -> nearest xterm-256 colour mapping used when truecolor
// is off. Pure functions, no I/O.
import { join } from "node:path";

type Env = Record<string, string | undefined>;

/** COLORTERM=truecolor or 24bit is how a terminal says it does 24-bit colour. */
export function detectTruecolor(env: Env): boolean {
  const v = (env.COLORTERM ?? "").toLowerCase();
  return v === "truecolor" || v === "24bit";
}

/** The command line flag wins, then the saved choice, then what the terminal says. */
export function resolveTruecolor(o: { flag?: boolean; saved?: boolean; detected: boolean }): boolean {
  return o.flag ?? o.saved ?? o.detected;
}

/** `$XDG_STATE_HOME/<NVIM_APPNAME>/keymap-helper/tui.json`, the same place nvim's stdpath("state") points at. */
export function settingsPath(env: Env): string {
  const state = env.XDG_STATE_HOME || join(env.HOME ?? "", ".local", "state");
  return join(state, env.NVIM_APPNAME || "nvim", "keymap-helper", "tui.json");
}

// xterm's 6x6x6 cube uses these levels per channel; 232..255 is a 24-step grey ramp.
const LEVELS = [0, 0x5f, 0x87, 0xaf, 0xd7, 0xff];
const GREYS = Array.from({ length: 24 }, (_, i) => 8 + i * 10);

const hex2 = (n: number) => n.toString(16).padStart(2, "0");
const near = (v: number, set: readonly number[]) => set.reduce((best, x) => (Math.abs(x - v) < Math.abs(best - v) ? x : best));

/** The closest xterm-256 colour (cube or grey ramp), written back as a hex string. */
export function nearest256(color: string): string {
  const m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(color);
  if (!m) return color;
  const rgb = [m[1], m[2], m[3]].map((h) => Number.parseInt(h as string, 16));
  const cube = rgb.map((v) => near(v, LEVELS));
  const grey = near(Math.round(((rgb[0] as number) + (rgb[1] as number) + (rgb[2] as number)) / 3), GREYS);
  const dist = (c: number[]) => c.reduce((sum, v, i) => sum + (v - (rgb[i] as number)) ** 2, 0);
  const best = dist([grey, grey, grey]) < dist(cube) ? [grey, grey, grey] : cube;
  return `#${best.map(hex2).join("")}`;
}

/** Colour as it should be drawn: untouched with truecolor, snapped to the 256 palette without. */
export function paint(color: string, truecolor: boolean): string;
export function paint(color: string | undefined, truecolor: boolean): string | undefined;
export function paint(color: string | undefined, truecolor: boolean): string | undefined {
  return color === undefined || truecolor ? color : nearest256(color);
}
