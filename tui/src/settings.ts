// The TUI's saved choices, one small JSON file in the plugin's nvim state dir.
// Everything read back is validated: a hand-edited or half-written file must
// never stop the UI from starting.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { settingsPath } from "./truecolor.ts";

export interface Saved {
  truecolor?: boolean;
}

export function loadSettings(env: Record<string, string | undefined> = process.env): Saved {
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(settingsPath(env), "utf8"));
  } catch {
    return {};
  }
  const out: Saved = {};
  if (raw && typeof raw === "object" && typeof (raw as Saved).truecolor === "boolean") out.truecolor = (raw as Saved).truecolor;
  return out;
}

export function saveSettings(s: Saved, env: Record<string, string | undefined> = process.env): void {
  const path = settingsPath(env);
  try {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, `${JSON.stringify(s)}\n`);
  } catch (e) {
    throw new Error(`could not save the options to ${path}: ${e instanceof Error ? e.message : String(e)}`);
  }
}
