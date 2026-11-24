import { type Effect, init, type State, update } from "../src/state.ts";
import type { Doc, Entry, Loaded } from "../src/types.ts";

export const SIZE = { w: 100, h: 30 };

export function map(id: string, lhs: string, category = "uncategorized", extra: Partial<Entry> = {}): Entry {
  return { id, kind: "map", category, modes: ["n"], lhs, rhs: `:${lhs}`, opts: { desc: `do ${lhs}` }, ...extra };
}

export function raw(id: string, text: string, category = "uncategorized"): Entry {
  return { id, kind: "raw", category, text };
}

export function doc(entries: Entry[], extraCats: string[] = []): Doc {
  return {
    categories: [
      { id: "uncategorized", title: "Uncategorized" },
      ...extraCats.map((c) => ({ id: c, title: c[0]?.toUpperCase() + c.slice(1) })),
    ],
    entries,
  };
}

export function loaded(d: Doc): Loaded {
  const calls: Record<string, string> = {};
  for (const e of d.entries) if (e.kind === "map") calls[e.id] = `map("n", "${e.lhs}", "${e.rhs}")`;
  return {
    status: "ready",
    root: "/r",
    template: "/r/lua/mappings.template.json",
    template_name: "lua/mappings.template.json",
    target: "/r/lua/mappings.lua",
    backups: true,
    target_exists: true,
    target_generated: false,
    doc: d,
    calls,
  };
}

export const start = (d: Doc, size = SIZE): State => init(loaded(d), size);

/** Press keys one after another; collect the effects they asked for. */
export function press(s: State, ...keys: string[]): { s: State; fx: Effect[] } {
  const fx: Effect[] = [];
  let cur = s;
  for (const key of keys) {
    const [next, e] = update(cur, { type: "key", key });
    cur = next;
    fx.push(...e);
  }
  return { s: cur, fx };
}

/** Type text into a prompt, one character per key. */
export const typed = (text: string) => [...text].map((c) => (c === " " ? "space" : c));

export const ids = (s: State, cat: string) => s.h.present.entries.filter((e) => e.category === cat).map((e) => e.id);
