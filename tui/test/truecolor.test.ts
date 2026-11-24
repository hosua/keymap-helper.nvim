import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadSettings, saveSettings } from "../src/settings.ts";
import { detectTruecolor, nearest256, paint, resolveTruecolor, settingsPath } from "../src/truecolor.ts";

describe("nearest256", () => {
  test("pure greys land on the grey ramp", () => {
    expect(nearest256("#000000")).toBe("#000000");
    expect(nearest256("#ffffff")).toBe("#ffffff");
    expect(nearest256("#808080")).toBe("#808080");
  });
  test("cube colours map to themselves", () => {
    expect(nearest256("#5f87d7")).toBe("#5f87d7");
    expect(nearest256("#ff0000")).toBe("#ff0000");
  });
  test("a theme colour moves to the closest of the 256", () => {
    expect(nearest256("#60A5FA")).toBe("#5fafff");
    expect(nearest256("#0F172A")).toBe("#1c1c1c");
    expect(nearest256("#F1F5F9")).toBe("#eeeeee");
  });
  test("is case-insensitive and rejects non-hex input unchanged", () => {
    expect(nearest256("#60a5fa")).toBe(nearest256("#60A5FA"));
    expect(nearest256("transparent")).toBe("transparent");
  });
});

describe("paint", () => {
  test("true keeps the colour, false maps it, undefined stays undefined", () => {
    expect(paint("#60A5FA", true)).toBe("#60A5FA");
    expect(paint("#60A5FA", false)).toBe("#5fafff");
    expect(paint(undefined, false)).toBeUndefined();
  });
});

describe("detectTruecolor", () => {
  test("COLORTERM truecolor or 24bit means true", () => {
    expect(detectTruecolor({ COLORTERM: "truecolor" })).toBe(true);
    expect(detectTruecolor({ COLORTERM: "24bit" })).toBe(true);
    expect(detectTruecolor({ COLORTERM: "TrueColor" })).toBe(true);
  });
  test("anything else means false", () => {
    expect(detectTruecolor({})).toBe(false);
    expect(detectTruecolor({ COLORTERM: "yes" })).toBe(false);
    expect(detectTruecolor({ TERM: "xterm-256color" })).toBe(false);
  });
});

describe("resolveTruecolor", () => {
  test("flag beats saved beats detected", () => {
    expect(resolveTruecolor({ flag: true, saved: false, detected: false })).toBe(true);
    expect(resolveTruecolor({ flag: false, saved: true, detected: true })).toBe(false);
    expect(resolveTruecolor({ saved: false, detected: true })).toBe(false);
    expect(resolveTruecolor({ detected: true })).toBe(true);
    expect(resolveTruecolor({ detected: false })).toBe(false);
  });
});

describe("persistence", () => {
  let dir = "";
  afterEach(() => dir && rmSync(dir, { recursive: true, force: true }));
  const fresh = () => {
    dir = mkdtempSync(join(tmpdir(), "kh-settings-"));
    return { XDG_STATE_HOME: dir } as Record<string, string>;
  };
  test("the file lives in the nvim state dir of the plugin", () => {
    expect(settingsPath({ XDG_STATE_HOME: "/s" })).toBe("/s/nvim/keymap-helper/tui.json");
    expect(settingsPath({ XDG_STATE_HOME: "/s", NVIM_APPNAME: "mine" })).toBe("/s/mine/keymap-helper/tui.json");
    expect(settingsPath({ HOME: "/h" })).toBe("/h/.local/state/nvim/keymap-helper/tui.json");
  });
  test("missing file loads as empty", () => {
    expect(loadSettings(fresh())).toEqual({});
  });
  test("save then load round-trips and creates the folders", () => {
    const env = fresh();
    saveSettings({ truecolor: false }, env);
    expect(loadSettings(env)).toEqual({ truecolor: false });
    expect(JSON.parse(readFileSync(settingsPath(env), "utf8"))).toEqual({ truecolor: false });
  });
  test("a corrupt file loads as empty instead of crashing", () => {
    const env = fresh();
    mkdirSync(join(dir, "nvim", "keymap-helper"), { recursive: true });
    writeFileSync(settingsPath(env), "{nope");
    expect(loadSettings(env)).toEqual({});
  });
  test("wrong types are dropped", () => {
    const env = fresh();
    mkdirSync(join(dir, "nvim", "keymap-helper"), { recursive: true });
    writeFileSync(settingsPath(env), JSON.stringify({ truecolor: "yes" }));
    expect(loadSettings(env)).toEqual({});
  });
});
