import { describe, expect, test } from "bun:test";
import { cycle, OPTIONS } from "../src/options.ts";
import { legendItems } from "../src/rows.ts";
import { doc, map, press, start } from "./helpers.ts";

const row = OPTIONS[0] as (typeof OPTIONS)[number];

describe("cycle", () => {
  test("True and False swap in both directions and wrap", () => {
    expect(cycle({ truecolor: true }, row, 1)).toEqual({ truecolor: false });
    expect(cycle({ truecolor: false }, row, 1)).toEqual({ truecolor: true });
    expect(cycle({ truecolor: true }, row, -1)).toEqual({ truecolor: false });
  });
  test("does not mutate its input", () => {
    const s = { truecolor: true };
    cycle(s, row, 1);
    expect(s).toEqual({ truecolor: true });
  });
});

describe("options screen keys", () => {
  const s0 = () => start(doc([map("a", "a")]));
  test("O opens it, esc closes it", () => {
    const open = press(s0(), "O").s;
    expect(open.ui.overlay).toEqual({ kind: "options", sel: 0 });
    expect(press(open, "escape").s.ui.overlay).toBeNull();
  });
  test("l, right, h and left cycle the value and ask for a save", () => {
    const r = press(s0(), "O", "l");
    expect(r.s.settings.truecolor).toBe(false);
    expect(r.fx).toEqual([{ type: "settings", settings: { truecolor: false } }]);
    expect(press(r.s, "h").s.settings.truecolor).toBe(true);
    expect(press(s0(), "O", "right").s.settings.truecolor).toBe(false);
    expect(press(s0(), "O", "left").s.settings.truecolor).toBe(false);
  });
  test("j and k stay inside the single row", () => {
    const r = press(s0(), "O", "j", "j", "k", "k");
    expect(r.s.ui.overlay).toEqual({ kind: "options", sel: 0 });
    expect(r.fx).toEqual([]);
  });
  test("other keys do nothing and the main screen is untouched", () => {
    const base = s0();
    const r = press(base, "O", "d", "x", "m");
    expect(r.fx).toEqual([]);
    expect(r.s.h.present).toBe(base.h.present);
  });
  test("starts from the given settings", () => {
    expect(start(doc([])).settings).toEqual({ truecolor: true });
  });
  test("the legend switches to the options keys", () => {
    expect(legendItems(press(s0(), "O").s).map(([k]) => k)).toEqual(["j k", "h l", "esc"]);
  });
});
