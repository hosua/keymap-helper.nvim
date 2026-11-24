import { describe, expect, test } from "bun:test";
import {
  addCategory,
  deleteCategory,
  isGrouped,
  moveCategory,
  moveEntries,
  normalize,
  renameCategory,
  reorderEntries,
} from "../src/doc.ts";
import { doc, map, raw } from "./helpers.ts";

const base = () => doc([map("a", "a"), map("b", "b"), raw("r", "local x = 1"), map("c", "c")], ["nav", "lsp"]);
const order = (d: { entries: { id: string }[] }) => d.entries.map((e) => e.id).join("");

describe("moveEntries", () => {
  test("puts entries at the end of the target and keeps the rest where it was", () => {
    const d = moveEntries(base(), new Set(["b", "r"]), "nav");
    expect(d.entries.filter((e) => e.category === "nav").map((e) => e.id)).toEqual(["b", "r"]);
    expect(d.entries.filter((e) => e.category === "uncategorized").map((e) => e.id)).toEqual(["a", "c"]);
    expect(d.entries.find((e) => e.id === "r")?.kind).toBe("raw");
  });
  test("appends after what the target already holds", () => {
    const d = moveEntries(moveEntries(base(), new Set(["a"]), "nav"), new Set(["c"]), "nav");
    expect(d.entries.filter((e) => e.category === "nav").map((e) => e.id)).toEqual(["a", "c"]);
  });
  test("returns the same document when nothing moves", () => {
    const d = base();
    expect(moveEntries(d, new Set(["zzz"]), "nav")).toBe(d);
    expect(moveEntries(d, new Set(["a"]), "uncategorized")).toBe(d);
    expect(moveEntries(d, new Set(["a"]), "ghost")).toBe(d);
  });
  test("does not change the document it was given", () => {
    const d = base();
    const before = JSON.stringify(d);
    moveEntries(d, new Set(["a"]), "nav");
    expect(JSON.stringify(d)).toBe(before);
  });
  test("keeps the fields of an entry, including _-prefixed ones", () => {
    const d = doc([map("a", "a", "uncategorized", { _note: "x" })], ["nav"]);
    expect(moveEntries(d, new Set(["a"]), "nav").entries[0]?._note).toBe("x");
  });
});

describe("reorderEntries", () => {
  test("moves one entry down and up inside its category", () => {
    const down = reorderEntries(base(), new Set(["a"]), 1);
    expect(order(down)).toBe("barc");
    expect(order(reorderEntries(down, new Set(["a"]), -1))).toBe("abrc");
  });
  test("moves a marked block together", () => {
    const d = reorderEntries(base(), new Set(["a", "b"]), 1);
    expect(order(d)).toBe("rabc");
  });
  test("stops at the ends", () => {
    const d = base();
    expect(reorderEntries(d, new Set(["a"]), -1)).toBe(d);
    expect(reorderEntries(d, new Set(["c"]), 1)).toBe(d);
  });
  test("never crosses into another category", () => {
    const d = moveEntries(base(), new Set(["b"]), "nav");
    expect(order(reorderEntries(d, new Set(["r"]), 1))).toBe("acrb");
    expect(reorderEntries(d, new Set(["b"]), 1)).toBe(d);
  });
});

describe("categories", () => {
  test("addCategory makes a temporary id and appends it", () => {
    const { doc: d, id } = addCategory(base(), "Mine");
    expect(id).toBe("new:1");
    expect(d.categories.at(-1)).toEqual({ id: "new:1", title: "Mine", isNew: true });
    expect(addCategory(d, "Two").id).toBe("new:2");
  });
  test("renameCategory renames, but never Uncategorized", () => {
    expect(renameCategory(base(), "nav", "Moving").categories[1]?.title).toBe("Moving");
    const d = base();
    expect(renameCategory(d, "uncategorized", "x")).toBe(d);
    expect(renameCategory(d, "nav", "Nav")).toBe(d);
  });
  test("deleteCategory sends its entries to the end of Uncategorized", () => {
    const d = deleteCategory(moveEntries(base(), new Set(["a", "b"]), "nav"), "nav");
    expect(d.categories.map((c) => c.id)).toEqual(["uncategorized", "lsp"]);
    expect(d.entries.every((e) => e.category === "uncategorized")).toBe(true);
    expect(order(d)).toBe("rcab");
  });
  test("deleteCategory refuses Uncategorized and unknown ids", () => {
    const d = base();
    expect(deleteCategory(d, "uncategorized")).toBe(d);
    expect(deleteCategory(d, "ghost")).toBe(d);
  });
  test("moveCategory reorders the blocks and keeps Uncategorized first", () => {
    let d = moveEntries(moveEntries(base(), new Set(["a"]), "nav"), new Set(["b"]), "lsp");
    d = moveCategory(d, "lsp", -1);
    expect(d.categories.map((c) => c.id)).toEqual(["uncategorized", "lsp", "nav"]);
    expect(order(d)).toBe("rcba");
    expect(moveCategory(d, "lsp", -1)).toBe(d);
    expect(moveCategory(d, "nav", 1)).toBe(d);
    expect(moveCategory(d, "uncategorized", 1)).toBe(d);
  });
});

describe("normalize", () => {
  test("groups entries by category order and puts Uncategorized first", () => {
    const d = normalize({
      categories: [
        { id: "nav", title: "Nav" },
        { id: "uncategorized", title: "Uncategorized" },
      ],
      entries: [map("a", "a", "nav"), map("b", "b"), map("c", "c", "nav")],
    });
    expect(d.categories[0]?.id).toBe("uncategorized");
    expect(order(d)).toBe("bac");
    expect(isGrouped(d)).toBe(true);
  });
  test("isGrouped says no for an interleaved document", () => {
    const d = { categories: base().categories, entries: [map("a", "a", "nav"), map("b", "b"), map("c", "c", "nav")] };
    expect(isGrouped(d)).toBe(false);
  });
});
