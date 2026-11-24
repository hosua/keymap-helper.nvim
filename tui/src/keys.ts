// OpenTUI KeyEvent -> the key names state.ts understands: "j", "J", "/", "<",
// "space", "return", "escape", "C-d", "S-tab". Printable keys are named by the
// character they type, so shifted keys and non-US layouts need no table.
export interface KeyLike {
  name: string;
  sequence: string;
  ctrl?: boolean;
  meta?: boolean;
  shift?: boolean;
}

const NAMED = new Set([
  "return",
  "escape",
  "tab",
  "backspace",
  "up",
  "down",
  "left",
  "right",
  "pageup",
  "pagedown",
  "home",
  "end",
  "delete",
  "space",
]);

export function keyName(e: KeyLike): string | null {
  if (e.ctrl) return e.name ? `C-${e.name}` : null;
  if (e.meta) return null;
  if (e.name === "enter") return "return";
  if (e.name === "tab" && e.shift) return "S-tab";
  if (e.name === "space" || e.sequence === " ") return "space";
  if (NAMED.has(e.name)) return e.name;
  if ([...e.sequence].length === 1 && e.sequence >= " ") return e.sequence;
  return null;
}
