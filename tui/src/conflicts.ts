// Who else defines the keys a template entry binds. Pure: it takes the
// document and the analysis snapshot, so every edit (a move, a delete) can
// recompute it on the spot.
//
// Two cases, and only these:
//   duplicate  two template entries bind the same mode and lhs. The one that
//              comes later in the generated file runs later and wins.
//   override   one template entry binds a key that something else (NvChad's
//              defaults, a plugin) bound before the template ran.
// Buffer-local entries and lazy.nvim `keys` are not looked at.
import type { Def, Doc, Entry, Snapshot } from "./types.ts";

/** Same key, whatever way it is spelled: <leader>, <Space> and a literal space agree. */
export function canonLhs(lhs: string, leader = " "): string {
  return lhs.replace(/<([^<>]+)>/g, (_m, inner: string) => {
    const t = inner.toLowerCase();
    if (t === "leader") return leader;
    if (t === "space") return " ";
    return `<${t}>`;
  });
}

/** The concrete modes a mode list stands for (v is x and s, "" is n x s o). */
export function expandModes(modes: readonly string[] | undefined): string[] {
  const out: string[] = [];
  const add = (m: string) => {
    if (!out.includes(m)) out.push(m);
  };
  for (const m of modes ?? []) {
    if (m === "") for (const c of ["n", "x", "s", "o"]) add(c);
    else if (m === "v") for (const c of ["x", "s"]) add(c);
    else if (m === "!") for (const c of ["i", "c"]) add(c);
    else for (const c of m) add(c);
  }
  return out;
}

export interface DupInfo {
  mode: string;
  /** Every entry on this key, in the order they run. */
  members: string[];
  winner: string;
}

export interface OverrideInfo {
  mode: string;
  lhs: string;
  old: Def;
}

export interface EntryConflict {
  level: "danger" | "warn";
  dups: DupInfo[];
  overrides: OverrideInfo[];
  removed: { mode: string; lhs: string; def: Def }[];
}

export interface Removed {
  mode: string;
  lhs: string;
  def: Def;
}

export interface Conflicts {
  byEntry: ReadonlyMap<string, EntryConflict>;
  /** Ids of entries with a duplicate or an override, in document order. */
  order: string[];
  duplicates: number;
  overrides: number;
  removed: Removed[];
}

export const NONE: Conflicts = { byEntry: new Map(), order: [], duplicates: 0, overrides: 0, removed: [] };

const keyOf = (mode: string, lhs: string, leader: string) => `${mode}\u0000${canonLhs(lhs, leader)}`;

export const isBuffer = (e: Entry): boolean => {
  const has = (o: Entry["opts"]) => !!o && !Array.isArray(o) && o.buffer !== undefined && o.buffer !== false;
  return has(e.opts) || (!!e.opts_raw && !Array.isArray(e.opts_raw) && e.opts_raw.buffer !== undefined);
};

/** A definition the template did not write itself (raw blocks count: they cannot be moved here). */
const outside = (d: Def) => !d.source.startsWith("template:") || d.source === "template:raw";

export function analyze(doc: Doc, snap: Snapshot | null): Conflicts {
  const leader = snap?.leader ?? " ";
  const base = new Map<string, Def[]>();
  const removed: Removed[] = [];
  for (const k of snap?.keys ?? []) {
    const key = keyOf(k.mode, k.lhs, leader);
    const defs = k.defs.filter(outside);
    if (defs.length) base.set(key, defs);
    for (const def of k.removed) removed.push({ mode: k.mode, lhs: k.lhs, def });
  }
  const removedByKey = new Map<string, Removed[]>();
  for (const r of removed) {
    const key = keyOf(r.mode, r.lhs, leader);
    removedByKey.set(key, [...(removedByKey.get(key) ?? []), r]);
  }

  const groups = new Map<string, { mode: string; ids: string[] }>();
  const bound: { e: Entry; mode: string; key: string }[] = [];
  for (const e of doc.entries) {
    if (e.kind !== "map" || !e.lhs || isBuffer(e)) continue;
    for (const mode of expandModes(e.modes)) {
      const key = keyOf(mode, e.lhs, leader);
      const g = groups.get(key) ?? { mode, ids: [] };
      g.ids.push(e.id);
      groups.set(key, g);
      bound.push({ e, mode, key });
    }
  }

  const byEntry = new Map<string, EntryConflict>();
  const get = (id: string): EntryConflict => {
    let c = byEntry.get(id);
    if (!c) {
      c = { level: "warn", dups: [], overrides: [], removed: [] };
      byEntry.set(id, c);
    }
    return c;
  };
  let duplicates = 0;
  let overrides = 0;
  const counted = new Set<string>();
  for (const { e, mode, key } of bound) {
    const g = groups.get(key);
    if (!g) continue;
    const first = g.ids[0] === e.id;
    if (g.ids.length > 1) {
      const c = get(e.id);
      c.level = "danger";
      c.dups.push({ mode, members: g.ids, winner: g.ids[g.ids.length - 1] as string });
      if (!counted.has(`d${key}`)) {
        counted.add(`d${key}`);
        duplicates++;
      }
    }
    const old = base.get(key);
    if (first && old) {
      get(e.id).overrides.push({ mode, lhs: e.lhs ?? "", old: old[old.length - 1] as Def });
      overrides++;
    }
    for (const r of removedByKey.get(key) ?? []) if (first) get(e.id).removed.push(r);
  }
  const order = doc.entries
    .filter((e) => {
      const c = byEntry.get(e.id);
      return c !== undefined && (c.dups.length > 0 || c.overrides.length > 0);
    })
    .map((e) => e.id);
  return { byEntry, order, duplicates, overrides, removed };
}

const memo = new WeakMap<Doc, { snap: Snapshot | null; result: Conflicts }>();

/** analyze(), remembered per document and snapshot so a redraw costs nothing. */
export function conflictsOf(doc: Doc, snap: Snapshot | null): Conflicts {
  const hit = memo.get(doc);
  if (hit && hit.snap === snap) return hit.result;
  const result = analyze(doc, snap);
  memo.set(doc, { snap, result });
  return result;
}

/** The text of a definition for a chip or a line: its desc, else what it runs. */
export function labelOf(d: Def): string {
  return d.desc || d.summary || "(no description)";
}

export function sourceName(source: string): string {
  const i = source.indexOf(":");
  return i < 0 ? source : source.slice(i + 1);
}
