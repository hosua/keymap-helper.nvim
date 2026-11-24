import { describe, expect, test } from "bun:test";
import { docOf, entryAt, init, isDirty, pickItems, summaryOf, update } from "../src/state.ts";
import { doc, ids, loaded, map, press, raw, SIZE, start, typed } from "./helpers.ts";

const six = () => doc([map("a", "a"), map("b", "b"), raw("r", "local m = 1"), map("c", "c"), map("d", "d"), map("e", "e")], ["nav"]);

describe("cursor and marks", () => {
  test("l focuses the entries, j and k move, G and gg jump", () => {
    let { s } = press(start(six()), "l", "j", "j");
    expect(s.ui.focus).toBe("entries");
    expect(entryAt(s)?.id).toBe("r");
    ({ s } = press(s, "G"));
    expect(entryAt(s)?.id).toBe("e");
    ({ s } = press(s, "g", "g"));
    expect(entryAt(s)?.id).toBe("a");
    ({ s } = press(s, "k"));
    expect(s.ui.entIdx).toBe(0);
  });
  test("space marks and moves down, v marks in place, esc clears", () => {
    let { s } = press(start(six()), "l", "space", "space", "v");
    expect([...s.ui.marks].sort()).toEqual(["a", "b", "r"]);
    expect(s.ui.entIdx).toBe(2);
    ({ s } = press(s, "v"));
    expect([...s.ui.marks].sort()).toEqual(["a", "b"]);
    ({ s } = press(s, "escape"));
    expect(s.ui.marks.size).toBe(0);
  });
  test("V starts a range that follows the cursor and a second V turns it into marks", () => {
    let { s } = press(start(six()), "l", "j", "V", "j", "j");
    expect(s.ui.anchor).toBe(1);
    ({ s } = press(s, "V"));
    expect([...s.ui.marks].sort()).toEqual(["b", "c", "r"]);
    expect(s.ui.anchor).toBeNull();
  });
  test("A marks every entry of the category", () => {
    const { s } = press(start(six()), "l", "A");
    expect(s.ui.marks.size).toBe(6);
  });
});

describe("categorize", () => {
  test("m opens the picker only from the entries pane", () => {
    expect(press(start(six()), "m").s.ui.overlay).toBeNull();
    expect(press(start(six()), "l", "m").s.ui.overlay?.kind).toBe("picker");
  });
  test("picking a category moves the marked entries and clears the marks", () => {
    let { s } = press(start(six()), "l", "v", "j", "v", "m");
    // picker lists Nav, then "new category"
    expect(pickItems(s, "").map((i) => (i.kind === "cat" ? i.title : "+"))).toEqual(["Nav", "+"]);
    ({ s } = press(s, "return"));
    expect(ids(s, "nav")).toEqual(["a", "b"]);
    expect(ids(s, "uncategorized")).toEqual(["r", "c", "d", "e"]);
    expect(s.ui.marks.size).toBe(0);
    expect(s.ui.message?.text).toBe("moved 2 entries to Nav");
    expect(isDirty(s)).toBe(true);
  });
  test("with no marks the entry under the cursor moves", () => {
    const { s } = press(start(six()), "l", "j", "m", "return");
    expect(ids(s, "nav")).toEqual(["b"]);
  });
  test("a raw entry can be moved", () => {
    const { s } = press(start(six()), "l", "j", "j", "m", "return");
    expect(ids(s, "nav")).toEqual(["r"]);
  });
  test("the picker filters by fuzzy match and offers a new category", () => {
    let { s } = press(start(six()), "l", "m", ...typed("nv"));
    expect(pickItems(s, "nv").map((i) => (i.kind === "cat" ? i.title : "+"))).toEqual(["Nav", "+"]);
    ({ s } = press(s, "C-n", "return"));
    expect(ids(s, "new:1")).toEqual(["a"]);
    expect(s.h.present.categories.at(-1)?.title).toBe("nv");
  });
  test("picking new category with no text asks for a name", () => {
    let { s } = press(start(six()), "l", "m", "up", "return");
    expect(s.ui.overlay).toMatchObject({ kind: "input", purpose: "newcat-move" });
    ({ s } = press(s, ...typed("Fresh start"), "return"));
    expect(s.h.present.categories.at(-1)?.title).toBe("Fresh start");
    expect(ids(s, "new:1")).toEqual(["a"]);
  });
  test("a new category must have a free name", () => {
    const { s } = press(start(six()), "c", ...typed("nav"), "return");
    expect(s.ui.overlay?.kind).toBe("input");
    expect(s.ui.message?.level).toBe("warn");
  });
  test("the picker leaves out the category the entries already sit in", () => {
    const { s } = press(start(six()), "l", "m", "return");
    const again = press(s, "h", "j", "l", "m").s;
    expect(pickItems(again, "").map((i) => (i.kind === "cat" ? i.title : "+"))).toContain("Uncategorized");
    expect(pickItems(again, "").map((i) => (i.kind === "cat" ? i.title : "+"))).not.toContain("Nav");
  });
});

describe("undo and redo", () => {
  test("u undoes a move and ctrl-r redoes it", () => {
    const base = press(start(six()), "l", "m", "return").s;
    expect(ids(base, "nav")).toEqual(["a"]);
    let { s } = press(base, "u");
    expect(ids(s, "nav")).toEqual([]);
    expect(isDirty(s)).toBe(false);
    ({ s } = press(s, "C-r"));
    expect(ids(s, "nav")).toEqual(["a"]);
  });
  test("undo with nothing to undo says so and changes nothing", () => {
    const s0 = start(six());
    const { s } = press(s0, "u");
    expect(s.h).toBe(s0.h);
    expect(s.ui.message?.text).toBe("nothing to undo");
  });
  test("a new edit drops the redo history", () => {
    let { s } = press(start(six()), "l", "m", "return", "u", "j", "m", "return");
    ({ s } = press(s, "C-r"));
    expect(s.ui.message?.text).toBe("nothing to redo");
  });
  test("undo covers category edits too", () => {
    let { s } = press(start(six()), "c", ...typed("Mine"), "return");
    expect(s.h.present.categories.map((c) => c.title)).toContain("Mine");
    ({ s } = press(s, "u"));
    expect(s.h.present.categories.map((c) => c.title)).not.toContain("Mine");
  });
});

describe("reorder", () => {
  test("J and K move the entry and the cursor follows it", () => {
    let { s } = press(start(six()), "l", "J");
    expect(ids(s, "uncategorized").slice(0, 2)).toEqual(["b", "a"]);
    expect(entryAt(s)?.id).toBe("a");
    ({ s } = press(s, "K"));
    expect(ids(s, "uncategorized").slice(0, 2)).toEqual(["a", "b"]);
  });
  test("J moves every marked entry", () => {
    const { s } = press(start(six()), "l", "v", "j", "v", "J");
    expect(ids(s, "uncategorized").slice(0, 3)).toEqual(["r", "a", "b"]);
  });
  test("< and > reorder categories and Uncategorized stays first", () => {
    let d = doc([map("a", "a")], ["nav", "lsp"]);
    let { s } = press(start(d), "j", "j", "<");
    expect(s.h.present.categories.map((c) => c.id)).toEqual(["uncategorized", "lsp", "nav"]);
    expect(s.ui.catIdx).toBe(1);
    ({ s } = press(s, "<"));
    expect(s.ui.message?.level).toBe("warn");
    ({ s } = press(s, ">"));
    expect(s.h.present.categories.map((c) => c.id)).toEqual(["uncategorized", "nav", "lsp"]);
    d = doc([]);
  });
});

describe("rename and delete", () => {
  test("r renames the selected category from a prefilled prompt", () => {
    let { s } = press(start(six()), "j", "r");
    expect(s.ui.overlay).toMatchObject({ kind: "input", text: "Nav" });
    ({ s } = press(s, "backspace", "backspace", "backspace", ...typed("Navigation"), "return"));
    expect(s.h.present.categories[1]?.title).toBe("Navigation");
    expect(summaryOf(s).renamed).toEqual([{ from: "Nav", to: "Navigation" }]);
  });
  test("Uncategorized cannot be renamed or deleted", () => {
    expect(press(start(six()), "r").s.ui.overlay).toBeNull();
    expect(press(start(six()), "d").s.ui.overlay).toBeNull();
  });
  test("d asks first, and n keeps the category", () => {
    const { s } = press(start(six()), "j", "d", "n");
    expect(s.h.present.categories).toHaveLength(2);
    expect(s.ui.overlay).toBeNull();
  });
  test("d then y deletes the category and its entries return to Uncategorized", () => {
    let { s } = press(start(six()), "l", "m", "return", "h", "j", "d");
    expect(s.ui.overlay).toMatchObject({ kind: "confirm", level: "error" });
    ({ s } = press(s, "y"));
    expect(s.h.present.categories.map((c) => c.id)).toEqual(["uncategorized"]);
    expect(ids(s, "uncategorized")).toContain("a");
    expect(s.ui.catIdx).toBe(0);
    ({ s } = press(s, "u"));
    expect(ids(s, "nav")).toEqual(["a"]);
  });
});

describe("search", () => {
  test("/ finds entries, n and N step through the matches", () => {
    let { s } = press(start(doc([map("a", "gx"), map("b", "gb"), map("c", "gx2")])), "l", "/", ...typed("gx"), "return");
    expect(s.ui.entIdx).toBe(0);
    ({ s } = press(s, "n"));
    expect(s.ui.entIdx).toBe(2);
    ({ s } = press(s, "n"));
    expect(s.ui.entIdx).toBe(0);
    ({ s } = press(s, "N"));
    expect(s.ui.entIdx).toBe(2);
  });
  test("a search with no hit says so", () => {
    const { s } = press(start(six()), "l", "/", ...typed("zzz"), "return");
    expect(s.ui.message?.text).toContain("no match");
  });
  test("searching in the category pane matches titles", () => {
    const { s } = press(start(six()), "/", ...typed("nav"), "return");
    expect(s.ui.catIdx).toBe(1);
  });
});

describe("save and quit", () => {
  test("w with no change says nothing to save", () => {
    const { s, fx } = press(start(six()), "w");
    expect(s.ui.message?.text).toBe("nothing to save");
    expect(fx).toEqual([]);
  });
  test("w shows a summary, y asks the bridge to save the plan", () => {
    let { s } = press(start(six()), "l", "m", "up", "return", ...typed("Mine"), "return");
    ({ s } = press(s, "w"));
    expect(s.ui.overlay).toMatchObject({ kind: "confirm", purpose: "save" });
    const lines = (s.ui.overlay as { lines: string[] }).lines.join("\n");
    expect(lines).toContain("moved 1 entry");
    expect(lines).toContain("new 1 category: Mine");
    expect(lines).toContain("hand-written");
    const out = press(s, "y");
    expect(out.fx).toHaveLength(1);
    expect(out.fx[0]).toMatchObject({ type: "save" });
    const plan = (out.fx[0] as { plan: { categories: unknown[]; order: { id: string; category: string }[] } }).plan;
    expect(plan.categories).toContainEqual({ id: "new:1", title: "Mine", new: true });
    expect(plan.order).toHaveLength(6);
    expect(plan.order.find((o) => o.id === "a")?.category).toBe("new:1");
    expect(out.s.busy).toBe(true);
  });
  test("n at the save confirm writes nothing", () => {
    const { fx } = press(start(six()), "l", "m", "return", "w", "n");
    expect(fx).toEqual([]);
  });
  test("q with no change quits at once", () => {
    expect(press(start(six()), "q").fx).toEqual([{ type: "quit" }]);
  });
  test("q with changes asks, n stays, y discards, w goes to the save screen", () => {
    const dirty = press(start(six()), "l", "m", "return").s;
    let out = press(dirty, "q");
    expect(out.s.ui.overlay).toMatchObject({ kind: "confirm", purpose: "quit" });
    expect(out.fx).toEqual([]);
    expect(press(out.s, "n").s.ui.overlay).toBeNull();
    expect(press(out.s, "y").fx).toEqual([{ type: "quit" }]);
    out = press(out.s, "w");
    expect(out.s.ui.overlay).toMatchObject({ purpose: "save" });
  });
  test("keys are ignored while a save is running", () => {
    const { s } = press(start(six()), "l", "m", "return", "w", "y");
    const again = press(s, "q", "j");
    expect(again.s).toBe(s);
  });
});

describe("import preview", () => {
  const preview = () => {
    const d = doc([map("p", "p", "keys"), map("q", "q", "keys")], ["keys"]);
    return { ...loaded(d), status: "preview" as const };
  };
  test("i asks for a preview; the answer shows it read-only; i leaves it", () => {
    const asked = press(start(six()), "i");
    expect(asked.fx).toEqual([{ type: "preview", keepHeaders: true }]);
    const [shown] = update(asked.s, { type: "previewed", loaded: preview() });
    expect(shown.preview?.doc.categories.map((c) => c.title)).toEqual(["Uncategorized", "Keys"]);
    expect(docOf(shown).entries).toHaveLength(2);
    const edit = press(shown, "l", "m", "J", "d", "c", "u", "w");
    expect(edit.s.h).toBe(shown.h);
    expect(edit.fx).toEqual([]);
    expect(press(shown, "i").s.preview).toBeNull();
  });
  test("enter asks, y imports with the categories kept, and the unsaved edits are named in the question", () => {
    const edited = press(start(six()), "l", "m", "return").s;
    const [shown] = update(edited, { type: "previewed", loaded: preview() });
    const asked = press(shown, "return");
    const text = (asked.s.ui.overlay as { lines: string[] }).lines.join("\n");
    expect(text).toContain("unsaved change");
    expect(press(asked.s, "n").fx).toEqual([]);
    expect(press(asked.s, "y").fx).toEqual([{ type: "import", keepHeaders: true }]);
  });
});

describe("no template yet", () => {
  const missing = (source: boolean) =>
    init(
      {
        status: "missing",
        source_exists: source,
        root: "/r",
        template: "/r/t.json",
        template_name: "t.json",
        target: "/r/lua/mappings.lua",
        backups: true,
        target_exists: source,
        target_generated: false,
      },
      SIZE,
    );
  test("y imports as Uncategorized, h keeps the headers, q quits", () => {
    expect(press(missing(true), "y").fx).toEqual([{ type: "import", keepHeaders: true }]);
    expect(press(missing(true), "d").fx).toEqual([{ type: "import", keepHeaders: false }]);
    expect(press(missing(true), "h").fx).toEqual([]);
    expect(press(missing(true), "q").fx).toEqual([{ type: "quit" }]);
  });
  test("with no mappings file there is nothing to import", () => {
    expect(press(missing(false), "y").fx).toEqual([]);
  });
});

describe("untouched entries", () => {
  test("a move leaves every other entry exactly as it was", () => {
    const d = six();
    const s0 = start(d);
    const { s } = press(s0, "l", "j", "m", "return");
    for (const e of s.h.present.entries) {
      if (e.id === "b") continue;
      expect(e).toBe(s0.h.present.entries.find((x) => x.id === e.id) as typeof e);
    }
  });
});
