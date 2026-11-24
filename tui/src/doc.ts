// Pure edits of the template document. Every function returns a new Doc, or
// the same object when nothing changed, so a caller can tell a no-op by `===`.
//
// Invariant: `entries` is grouped by category, in the order of `categories`,
// and Uncategorized is the first category. The generator writes entries in
// array order and starts a new box header whenever the category changes, so
// this is also the order of the generated file.
import { type Category, type Doc, type Entry, UNCATEGORIZED } from "./types.ts";

export function normalize(doc: Doc): Doc {
  const cats = [...doc.categories];
  const u = cats.findIndex((c) => c.id === UNCATEGORIZED);
  if (u > 0) cats.unshift(...cats.splice(u, 1));
  const rank = new Map(cats.map((c, i) => [c.id, i]));
  const entries = doc.entries
    .map((e, i) => ({ e, i }))
    .sort((a, b) => (rank.get(a.e.category) ?? 0) - (rank.get(b.e.category) ?? 0) || a.i - b.i)
    .map((x) => x.e);
  return { categories: cats, entries };
}

export function entriesOf(doc: Doc, category: string): Entry[] {
  return doc.entries.filter((e) => e.category === category);
}

export function categoryOf(doc: Doc, id: string): Category | undefined {
  return doc.categories.find((c) => c.id === id);
}

/** Move entries to the end of another category. Entries already there stay put. */
export function moveEntries(doc: Doc, ids: ReadonlySet<string>, to: string): Doc {
  if (!categoryOf(doc, to)) return doc;
  const moving = doc.entries.filter((e) => ids.has(e.id) && e.category !== to);
  if (moving.length === 0) return doc;
  const movingIds = new Set(moving.map((e) => e.id));
  const rest = doc.entries.filter((e) => !movingIds.has(e.id));
  const moved = moving.map((e) => ({ ...e, category: to }));
  return normalize({ categories: doc.categories, entries: [...rest, ...moved] });
}

/** Shift the marked entries one place down (dir 1) or up (dir -1) inside their category. */
export function reorderEntries(doc: Doc, ids: ReadonlySet<string>, dir: 1 | -1): Doc {
  const entries = [...doc.entries];
  let changed = false;
  const n = entries.length;
  const lo = (i: number) => entries[i]?.category;
  const range = dir === 1 ? [...Array(n).keys()].reverse() : [...Array(n).keys()];
  for (const i of range) {
    const j = i + dir;
    const a = entries[i];
    const b = entries[j];
    if (!a || !b || !ids.has(a.id) || ids.has(b.id) || lo(i) !== lo(j)) continue;
    entries[i] = b;
    entries[j] = a;
    changed = true;
  }
  return changed ? { categories: doc.categories, entries } : doc;
}

export function addCategory(doc: Doc, title: string): { doc: Doc; id: string } {
  let n = 1;
  for (const c of doc.categories) {
    const m = /^new:(\d+)$/.exec(c.id);
    if (m) n = Math.max(n, Number(m[1]) + 1);
  }
  const id = `new:${n}`;
  return { doc: { categories: [...doc.categories, { id, title, isNew: true }], entries: doc.entries }, id };
}

export function renameCategory(doc: Doc, id: string, title: string): Doc {
  if (id === UNCATEGORIZED) return doc;
  const cur = categoryOf(doc, id);
  if (!cur || cur.title === title) return doc;
  return { categories: doc.categories.map((c) => (c.id === id ? { ...c, title } : c)), entries: doc.entries };
}

/** Delete a category; its entries go to the end of Uncategorized. */
export function deleteCategory(doc: Doc, id: string): Doc {
  if (id === UNCATEGORIZED || !categoryOf(doc, id)) return doc;
  const moved = moveEntries(doc, new Set(entriesOf(doc, id).map((e) => e.id)), UNCATEGORIZED);
  return { categories: moved.categories.filter((c) => c.id !== id), entries: moved.entries };
}

/** Move a category one place up (-1) or down (1). Uncategorized stays first. */
export function moveCategory(doc: Doc, id: string, dir: 1 | -1): Doc {
  const i = doc.categories.findIndex((c) => c.id === id);
  const j = i + dir;
  if (i < 1 || j < 1 || j >= doc.categories.length) return doc;
  const cats = [...doc.categories];
  const a = cats[i] as Category;
  cats[i] = cats[j] as Category;
  cats[j] = a;
  return normalize({ categories: cats, entries: doc.entries });
}

/** True when the entries sit in an order normalize() would change. */
export function isGrouped(doc: Doc): boolean {
  const n = normalize(doc);
  return n.entries.every((e, i) => e.id === doc.entries[i]?.id) && n.categories[0]?.id === doc.categories[0]?.id;
}
