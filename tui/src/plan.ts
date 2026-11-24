// What a save would change, as a summary for the confirm screen and as the
// plan that kh-template applies. Both compare the document the UI started
// from with the one it holds now.
import type { Doc, SavePlan } from "./types.ts";

export function toPlan(doc: Doc, base?: Doc): SavePlan {
  const kept = new Set(doc.entries.map((e) => e.id));
  const gone = (base?.entries ?? []).filter((e) => !kept.has(e.id)).map((e) => e.id);
  return {
    ...(gone.length ? { delete: gone } : {}),
    categories: doc.categories.map((c) => (c.isNew ? { id: c.id, title: c.title, new: true } : { id: c.id, title: c.title })),
    order: doc.entries.map((e) => ({ id: e.id, category: e.category })),
  };
}

export interface Summary {
  changed: boolean;
  moved: number;
  /** Titles of categories whose entries were put in a different order. */
  reorderedIn: string[];
  added: string[];
  renamed: { from: string; to: string }[];
  deleted: string[];
  categoriesReordered: boolean;
  /** Entries dropped from the template, as "n <leader>x" labels. */
  entriesDeleted: string[];
}

/** Order of `items` after dropping everything not in `keep`. */
function sameOrder(a: string[], b: string[]): boolean {
  const inB = new Set(b);
  const inA = new Set(a);
  const x = a.filter((i) => inB.has(i));
  const y = b.filter((i) => inA.has(i));
  return x.length === y.length && x.every((v, i) => v === y[i]);
}

export function summarize(orig: Doc, cur: Doc): Summary {
  const was = new Map(orig.entries.map((e) => [e.id, e.category]));
  let moved = 0;
  for (const e of cur.entries) if (was.get(e.id) !== e.category) moved++;

  const origCats = new Map(orig.categories.map((c) => [c.id, c]));
  const curCats = new Map(cur.categories.map((c) => [c.id, c]));
  const added = cur.categories.filter((c) => !origCats.has(c.id)).map((c) => c.title);
  const deleted = orig.categories.filter((c) => !curCats.has(c.id)).map((c) => c.title);
  const renamed = cur.categories
    .filter((c) => origCats.has(c.id) && origCats.get(c.id)?.title !== c.title)
    .map((c) => ({ from: origCats.get(c.id)?.title ?? "", to: c.title }));

  const reorderedIn: string[] = [];
  for (const c of cur.categories) {
    if (!origCats.has(c.id)) continue;
    const a = orig.entries.filter((e) => e.category === c.id).map((e) => e.id);
    const b = cur.entries.filter((e) => e.category === c.id).map((e) => e.id);
    if (!sameOrder(a, b)) reorderedIn.push(c.title);
  }
  const categoriesReordered = !sameOrder(
    orig.categories.map((c) => c.id),
    cur.categories.map((c) => c.id),
  );
  const kept = new Set(cur.entries.map((e) => e.id));
  const entriesDeleted = orig.entries.filter((e) => !kept.has(e.id)).map((e) => `${(e.modes ?? []).join("")} ${e.lhs ?? e.id}`);
  return {
    entriesDeleted,
    changed:
      entriesDeleted.length > 0 ||
      moved > 0 ||
      reorderedIn.length > 0 ||
      added.length > 0 ||
      deleted.length > 0 ||
      renamed.length > 0 ||
      categoriesReordered,
    moved,
    reorderedIn,
    added,
    renamed,
    deleted,
    categoriesReordered,
  };
}

const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

/** Plain sentences for the save screen, one fact each. */
export function describe(s: Summary): string[] {
  const out: string[] = [];
  if (s.moved) out.push(`moved ${plural(s.moved, "entry", "entries")}`);
  if (s.added.length) out.push(`new ${plural(s.added.length, "category", "categories")}: ${s.added.join(", ")}`);
  if (s.renamed.length) out.push(`renamed: ${s.renamed.map((r) => `${r.from} -> ${r.to}`).join(", ")}`);
  if (s.entriesDeleted.length) out.push(`deleted ${plural(s.entriesDeleted.length, "entry", "entries")}: ${s.entriesDeleted.join(", ")}`);
  if (s.deleted.length) out.push(`deleted ${plural(s.deleted.length, "category", "categories")}: ${s.deleted.join(", ")}`);
  if (s.reorderedIn.length) out.push(`reordered entries in: ${s.reorderedIn.join(", ")}`);
  if (s.categoriesReordered) out.push("reordered categories");
  return out;
}

export function changeCount(s: Summary): number {
  return (
    s.entriesDeleted.length +
    s.moved +
    s.added.length +
    s.renamed.length +
    s.deleted.length +
    s.reorderedIn.length +
    (s.categoriesReordered ? 1 : 0)
  );
}
