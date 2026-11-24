import { describe, expect, test } from "bun:test";
import { help, parseArgs } from "../src/args.ts";
import { addCategory, deleteCategory, moveCategory, moveEntries, renameCategory } from "../src/doc.ts";
import { rank, score } from "../src/fuzzy.ts";
import { keyName } from "../src/keys.ts";
import { grid, NORMAL } from "../src/legend.ts";
import { describe as describeChanges, summarize, toPlan } from "../src/plan.ts";
import { doc, map } from "./helpers.ts";

describe("plan", () => {
  const base = () => doc([map("a", "a"), map("b", "b"), map("c", "c")], ["nav", "lsp"]);
  test("an untouched document has no changes", () => {
    expect(summarize(base(), base()).changed).toBe(false);
  });
  test("counts moves, new, renamed and deleted categories", () => {
    let d = moveEntries(base(), new Set(["a", "b"]), "nav");
    d = renameCategory(d, "nav", "Navigation");
    d = deleteCategory(d, "lsp");
    d = addCategory(d, "Mine").doc;
    const s = summarize(base(), d);
    expect(s).toMatchObject({ moved: 2, added: ["Mine"], deleted: ["Lsp"], renamed: [{ from: "Nav", to: "Navigation" }] });
    expect(describeChanges(s)).toEqual([
      "moved 2 entries",
      "new 1 category: Mine",
      "renamed: Nav -> Navigation",
      "deleted 1 category: Lsp",
    ]);
  });
  test("a deleted category counts its entries as moved", () => {
    const d = deleteCategory(moveEntries(base(), new Set(["a"]), "nav"), "nav");
    expect(summarize(base(), d).moved).toBe(0);
    const orig = moveEntries(base(), new Set(["a"]), "nav");
    expect(summarize(orig, deleteCategory(orig, "nav")).moved).toBe(1);
  });
  test("reordering inside a category and reordering categories are changes", () => {
    const swapped = { ...base(), entries: [base().entries[1], base().entries[0], base().entries[2]] as never };
    expect(summarize(base(), swapped).reorderedIn).toEqual(["Uncategorized"]);
    expect(summarize(base(), moveCategory(base(), "nav", 1)).categoriesReordered).toBe(true);
  });
  test("the plan carries ids and categories only, with new ones flagged", () => {
    const d = addCategory(moveEntries(base(), new Set(["a"]), "nav"), "Mine").doc;
    const p = toPlan(d);
    expect(p.categories.at(-1)).toEqual({ id: "new:1", title: "Mine", new: true });
    expect(p.categories[0]).toEqual({ id: "uncategorized", title: "Uncategorized" });
    expect(Object.keys(p.order[0] ?? {}).sort()).toEqual(["category", "id"]);
  });
});

describe("fuzzy", () => {
  test("matches subsequences, case-insensitively, and rejects the rest", () => {
    expect(score("lsp", "LSP / diagnostics")).not.toBeNull();
    expect(score("gdl", "Git / goto")).toBeNull();
    expect(score("", "x")).toBe(0);
  });
  test("ranks consecutive and word-start matches first", () => {
    expect(rank("git", ["Digits and things", "Git / goto", "Toggles"], (x) => x)[0]).toBe("Git / goto");
  });
});

describe("args", () => {
  test("reads --flag value and --flag=value", () => {
    expect(parseArgs(["--root", "/r", "--template=t.json"])).toEqual({ kind: "run", args: { root: "/r", template: "t.json" } });
  });
  test("-h, unknown flags and a missing value", () => {
    expect(parseArgs(["-h"]).kind).toBe("help");
    expect(parseArgs(["--nope"])).toEqual({ kind: "error", message: "unknown option --nope" });
    expect(parseArgs(["--root"])).toEqual({ kind: "error", message: "--root needs a value" });
  });
  test("help follows the USAGE / OPTIONS / EXAMPLES layout", () => {
    const h = help(false);
    expect(h.startsWith("USAGE\n  $ keymap-helper-tui")).toBe(true);
    expect(h).toContain("\nOPTIONS\n");
    expect(h).toContain("\nEXAMPLES\n");
    expect(h).not.toContain("\x1b");
  });
});

describe("keys", () => {
  test("names printable keys by their character", () => {
    expect(keyName({ name: "j", sequence: "j" })).toBe("j");
    expect(keyName({ name: "j", sequence: "J", shift: true })).toBe("J");
    expect(keyName({ name: ",", sequence: "<", shift: true })).toBe("<");
    expect(keyName({ name: "/", sequence: "/" })).toBe("/");
  });
  test("names special and control keys", () => {
    expect(keyName({ name: "return", sequence: "\r" })).toBe("return");
    expect(keyName({ name: "escape", sequence: "\x1b" })).toBe("escape");
    expect(keyName({ name: "space", sequence: " " })).toBe("space");
    expect(keyName({ name: "r", sequence: "\x12", ctrl: true })).toBe("C-r");
    expect(keyName({ name: "tab", sequence: "\t", shift: true })).toBe("S-tab");
    expect(keyName({ name: "x", sequence: "x", meta: true })).toBeNull();
  });
});

describe("legend grid", () => {
  test("holds every item and keeps columns aligned", () => {
    for (const w of [80, 100, 140]) {
      const g = grid(NORMAL, w);
      expect(g.cells.flat().filter(Boolean)).toHaveLength(NORMAL.length);
      expect(g.cols * g.cell).toBeLessThanOrEqual(w);
    }
  });
});

describe("--truecolor flag", () => {
  test("true and false, with = or a separate value", () => {
    expect(parseArgs(["--truecolor=false"])).toEqual({ kind: "run", args: { truecolor: false } });
    expect(parseArgs(["--truecolor", "true"])).toEqual({ kind: "run", args: { truecolor: true } });
  });
  test("anything else is an error", () => {
    expect(parseArgs(["--truecolor=maybe"])).toEqual({ kind: "error", message: "--truecolor needs true or false" });
    expect(parseArgs(["--truecolor"])).toEqual({ kind: "error", message: "--truecolor needs true or false" });
  });
  test("help lists it", () => {
    expect(help(false)).toContain("--truecolor=BOOL");
  });
});
