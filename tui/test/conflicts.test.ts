import { describe, expect, test } from "bun:test";
import { analyze, canonLhs, displayLhs, expandModes, labelOf } from "../src/conflicts.ts";
import { moveEntries } from "../src/doc.ts";
import { conflictDoc, doc, map, snapshot } from "./helpers.ts";

describe("canonLhs and expandModes", () => {
  test("<leader>, <Space> and a space spell the same key; case inside <> is ignored", () => {
    expect(canonLhs("<leader>h")).toBe(" h");
    expect(canonLhs("<Space>h")).toBe(" h");
    expect(canonLhs("<LEADER>h", ",")).toBe(",h");
    expect(canonLhs("<C-H>")).toBe(canonLhs("<c-h>"));
    expect(canonLhs("gd")).toBe("gd");
  });
  test("mode lists expand to concrete modes", () => {
    expect(expandModes(["n", "x"])).toEqual(["n", "x"]);
    expect(expandModes(["v"])).toEqual(["x", "s"]);
    expect(expandModes(["n", "v"])).toEqual(["n", "x", "s"]);
    expect(expandModes([""])).toEqual(["n", "x", "s", "o"]);
  });
});

describe("analyze", () => {
  test("a duplicate is red, the later entry wins, the earlier is shadowed", () => {
    const c = analyze(conflictDoc(), null);
    expect(c.duplicates).toBe(1);
    const x1 = c.byEntry.get("x1");
    const x2 = c.byEntry.get("x2");
    expect(x1?.level).toBe("danger");
    expect(x1?.dups[0]?.winner).toBe("x2");
    expect(x2?.dups[0]?.members).toEqual(["x1", "x2"]);
  });

  test("an override of a default is a warning with the old definition, and never a duplicate", () => {
    const c = analyze(conflictDoc(), snapshot());
    const h = c.byEntry.get("h1");
    expect(h?.level).toBe("warn");
    expect(h?.dups).toEqual([]);
    expect(labelOf(h?.overrides[0]?.old ?? { source: "" })).toBe("Telescope help_tags");
    expect(c.overrides).toBe(1);
    expect(c.order).toEqual(["h1", "x1", "x2"]);
  });

  test("removed defaults are listed, and noted on an entry that binds the same key again", () => {
    const d = doc([map("v1", "<leader>v", "uncategorized")]);
    const c = analyze(d, snapshot());
    expect(c.removed.map((r) => r.lhs)).toEqual(["<leader>v"]);
    expect(c.byEntry.get("v1")?.removed[0]?.def.desc).toBe("terminal vertical");
    expect(c.byEntry.get("v1")?.overrides).toEqual([]);
    expect(c.order).toEqual([]);
  });

  test("buffer-local entries are ignored", () => {
    const d = doc([map("a", "gd", "uncategorized", { opts: { buffer: true } }), map("b", "gd")]);
    expect(analyze(d, null).duplicates).toBe(0);
  });

  test("the same lhs in different modes is not a duplicate; a mode list collides per mode", () => {
    const d = doc([map("a", "q", "uncategorized", { modes: ["n"] }), map("b", "q", "uncategorized", { modes: ["x"] })]);
    expect(analyze(d, null).duplicates).toBe(0);
    const e = doc([map("a", "q", "uncategorized", { modes: ["n", "x"] }), map("b", "q", "uncategorized", { modes: ["x"] })]);
    const c = analyze(e, null);
    expect(c.duplicates).toBe(1);
    expect(c.byEntry.get("a")?.dups.map((x) => x.mode)).toEqual(["x"]);
  });

  test("spellings of one key collide", () => {
    const d = doc([map("a", "<leader>x"), map("b", "<Space>x")]);
    expect(analyze(d, null).duplicates).toBe(1);
  });

  test("moving the earlier entry after the later one flips the winner at once", () => {
    const d = conflictDoc();
    const moved = moveEntries(d, new Set(["x1"]), "git");
    const c = analyze(moved, null);
    expect(c.byEntry.get("x1")?.dups[0]?.winner).toBe("x1");
    expect(c.byEntry.get("x2")?.dups[0]?.members).toEqual(["x2", "x1"]);
  });

  test("a snapshot's own template definitions are ignored: the document decides", () => {
    const c = analyze(doc([map("h1", "<leader>h")]), snapshot());
    expect(c.byEntry.get("h1")?.overrides).toHaveLength(1);
    expect(c.duplicates).toBe(0);
  });
});

describe("spelling", () => {
  test("<C-j>, <NL> and <C-J> are one key; removed defaults read as <leader>", () => {
    expect(canonLhs("<C-j>")).toBe(canonLhs("<NL>"));
    expect(canonLhs("<C-m>")).toBe(canonLhs("<CR>"));
    expect(displayLhs("<Space>n", " ")).toBe("<leader>n");
    expect(displayLhs(",x", ",")).toBe("<leader>x");
    expect(displayLhs("gd", " ")).toBe("gd");
  });
  test("the removed list uses the leader spelling", () => {
    const c = analyze(doc([]), snapshot());
    expect(c.removed[0]?.lhs).toBe("<leader>v");
  });
});
