// The whole app as one pure function: update(state, event) gives the next
// state and the side effects to run (save, preview, import, quit). The views
// only draw the state; the bridge runs the effects and reports back as events.

import { type Conflicts, conflictsOf, labelOf } from "./conflicts.ts";
import {
  addCategory,
  categoryOf,
  deleteCategory,
  entriesOf,
  isGrouped,
  moveCategory,
  moveEntries,
  normalize,
  placeNear,
  removeEntries,
  renameCategory,
  reorderEntries,
} from "./doc.ts";
import { rank } from "./fuzzy.ts";
import * as H from "./history.ts";
import { layout, type Size } from "./layout.ts";
import { cycle, OPTIONS, type Settings } from "./options.ts";
import { changeCount, describe, summarize, toPlan } from "./plan.ts";
import {
  type Doc,
  type Entry,
  type Info,
  type Level,
  type Loaded,
  type Missing,
  type SavePlan,
  type SaveResult,
  type Snapshot,
  UNCATEGORIZED,
} from "./types.ts";

export type Focus = "cats" | "entries";

export type PickItem = { kind: "cat"; id: string; title: string } | { kind: "new" };

export type Overlay =
  | { kind: "picker"; query: string; sel: number }
  | { kind: "input"; purpose: "newcat" | "newcat-move" | "rename" | "search"; label: string; text: string }
  | { kind: "confirm"; purpose: "delete" | "quit" | "save" | "apply" | "import" | "entry"; level: Level; lines: string[]; target?: string }
  | { kind: "result"; level: Level; lines: string[] }
  | { kind: "options"; sel: number };

export interface Message {
  text: string;
  level: Level;
}

/** The keymap analysis: idle until the screen is ready, then running, then done or failed. */
export type Analysis =
  | { status: "idle" }
  | { status: "running"; frame: number }
  | { status: "done"; snapshot: Snapshot }
  | { status: "failed"; message: string };

export interface UI {
  catIdx: number;
  entIdx: number;
  focus: Focus;
  marks: ReadonlySet<string>;
  /** Entry index where a V range started in the selected category. */
  anchor: number | null;
  overlay: Overlay | null;
  message: Message | null;
  /** First key of a two-key command (g). */
  pending: string;
  search: string;
  /** Show only entries with a duplicate or an override. */
  filter: boolean;
  /** Palette slot picked with C, by category id. */
  colors: Readonly<Record<string, number>>;
  size: Size;
}

export interface State {
  screen: "main" | "missing";
  info: Info;
  sourceExists: boolean;
  calls: Readonly<Record<string, string>>;
  /** The document as loaded; the summary and the dirty flag compare against it. */
  base: Doc;
  h: H.History;
  preview: { doc: Doc; calls: Readonly<Record<string, string>> } | null;
  analysis: Analysis;
  ui: UI;
  busy: boolean;
  quit: boolean;
  settings: Settings;
}

export type Effect =
  | { type: "settings"; settings: Settings }
  | { type: "analyze" }
  | { type: "save"; plan: SavePlan }
  | { type: "preview"; keepHeaders: boolean }
  | { type: "import"; keepHeaders: boolean }
  | { type: "reload" }
  | { type: "quit" };

export type Event =
  | { type: "key"; key: string }
  | { type: "analysis-start" }
  | { type: "analyzed"; snapshot: Snapshot }
  | { type: "analysis-failed"; message: string }
  | { type: "tick" }
  | { type: "resize"; size: Size }
  | { type: "select"; pane: Focus; index: number }
  | { type: "scroll"; delta: number }
  | { type: "loaded"; loaded: Loaded; note?: Message }
  | { type: "previewed"; loaded: Loaded }
  | { type: "saved"; result: SaveResult; loaded: Loaded | null }
  | { type: "failed"; message: string };

export const PALETTE_SIZE = 12;

const emptyDoc: Doc = { categories: [{ id: UNCATEGORIZED, title: "Uncategorized" }], entries: [] };

function freshUI(size: Size): UI {
  return {
    catIdx: 0,
    entIdx: 0,
    focus: "cats",
    marks: new Set(),
    anchor: null,
    overlay: null,
    message: null,
    pending: "",
    search: "",
    filter: false,
    colors: {},
    size,
  };
}

export const DEFAULT_SETTINGS: Settings = { truecolor: true };

export function init(loaded: Loaded | Missing, size: Size, settings: Settings = DEFAULT_SETTINGS): State {
  const info: Info = { ...loaded };
  if (loaded.status === "missing") {
    return {
      screen: "missing",
      info,
      sourceExists: loaded.source_exists,
      calls: {},
      base: emptyDoc,
      h: H.start(emptyDoc),
      preview: null,
      analysis: { status: "idle" },
      ui: freshUI(size),
      busy: false,
      quit: false,
      settings,
    };
  }
  const doc = normalize(loaded.doc);
  const ui = freshUI(size);
  const note: Message | null = isGrouped(loaded.doc)
    ? null
    : { text: "entries are grouped by category on load; nothing is written until you save", level: "info" };
  return {
    screen: "main",
    info,
    sourceExists: true,
    calls: loaded.calls,
    base: doc,
    h: H.start(doc),
    preview: null,
    analysis: { status: "idle" },
    ui: { ...ui, message: note },
    busy: false,
    quit: false,
    settings,
  };
}

// ---- selectors -----------------------------------------------------------

export const docOf = (s: State): Doc => s.preview?.doc ?? s.h.present;
export const callsOf = (s: State): Readonly<Record<string, string>> => s.preview?.calls ?? s.calls;
export const categoryAt = (s: State) => docOf(s).categories[s.ui.catIdx];
export const snapshotOf = (s: State): Snapshot | null => (s.analysis.status === "done" ? s.analysis.snapshot : null);
export const conflictsFor = (s: State): Conflicts => conflictsOf(docOf(s), snapshotOf(s));
export const entriesIn = (s: State): Entry[] => {
  const c = categoryAt(s);
  if (!c) return [];
  const all = entriesOf(docOf(s), c.id);
  if (!s.ui.filter) return all;
  const hit = new Set(conflictsFor(s).order);
  return all.filter((e) => hit.has(e.id));
};
export const entryAt = (s: State): Entry | undefined => entriesIn(s)[s.ui.entIdx];
export const summaryOf = (s: State) => summarize(s.base, s.h.present);
export const isDirty = (s: State): boolean => s.screen === "main" && summaryOf(s).changed;

/** Entries a command acts on: marks, plus the V range, else the one under the cursor. */
export function selection(s: State): string[] {
  const doc = docOf(s);
  const ids = new Set(s.ui.marks);
  const list = entriesIn(s);
  if (s.ui.anchor !== null) {
    const [a, b] = [Math.min(s.ui.anchor, s.ui.entIdx), Math.max(s.ui.anchor, s.ui.entIdx)];
    for (const e of list.slice(a, b + 1)) ids.add(e.id);
  }
  if (ids.size === 0) {
    const e = list[s.ui.entIdx];
    if (e) ids.add(e.id);
  }
  // Document order, and only entries that still exist.
  return doc.entries.filter((e) => ids.has(e.id)).map((e) => e.id);
}

export function haystack(e: Entry, titleOf: (id: string) => string): string {
  const o = Array.isArray(e.opts) ? undefined : e.opts;
  const desc = typeof o?.desc === "string" ? o.desc : "";
  const body = e.kind === "raw" ? (e.text ?? "") : `${e.rhs ?? e.lua ?? ""}`;
  return [e.lhs ?? "", (e.modes ?? []).join(""), desc, body.split("\n")[0] ?? "", titleOf(e.category)].join(" ").toLowerCase();
}

export function pickItems(s: State, query: string): PickItem[] {
  const doc = docOf(s);
  const ids = new Set(selection(s));
  const sources = new Set(doc.entries.filter((e) => ids.has(e.id)).map((e) => e.category));
  const only = sources.size === 1 ? [...sources][0] : undefined;
  const cats = doc.categories.filter((c) => c.id !== only).map((c) => ({ kind: "cat" as const, id: c.id, title: c.title }));
  return [...rank(query, cats, (c) => c.title), { kind: "new" }];
}

// ---- helpers -------------------------------------------------------------

const note = (text: string, level: Level = "info"): Message => ({ text, level });
const clampIdx = (n: number, len: number) => Math.max(0, Math.min(n, Math.max(0, len - 1)));
const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

function withUI(s: State, patch: Partial<UI>): State {
  return { ...s, ui: { ...s.ui, ...patch } };
}

/** Put the cursors back inside the lists after an edit. */
function settle(s: State, follow?: { cat?: string; entry?: string }): State {
  const doc = docOf(s);
  let catIdx = s.ui.catIdx;
  if (follow?.cat) {
    const i = doc.categories.findIndex((c) => c.id === follow.cat);
    if (i >= 0) catIdx = i;
  }
  catIdx = clampIdx(catIdx, doc.categories.length);
  const cat = doc.categories[catIdx];
  const list = cat ? entriesOf(doc, cat.id) : [];
  let entIdx = s.ui.entIdx;
  if (follow?.entry) {
    const i = list.findIndex((e) => e.id === follow.entry);
    if (i >= 0) entIdx = i;
  }
  entIdx = clampIdx(entIdx, list.length);
  const anchor = s.ui.anchor === null ? null : clampIdx(s.ui.anchor, list.length);
  return withUI(s, { catIdx, entIdx, anchor });
}

function edit(s: State, doc: Doc, msg: Message | null, follow?: { cat?: string; entry?: string }, patch: Partial<UI> = {}): State {
  const next = withUI({ ...s, h: H.commit(s.h, doc) }, { ...patch, message: msg });
  return settle(next, follow);
}

const colorOverride = (s: State, id: string) => s.ui.colors[id];

function titleOf(s: State, id: string): string {
  return categoryOf(docOf(s), id)?.title ?? id;
}

// ---- keys ----------------------------------------------------------------

const printable = (key: string) => key.length === 1 || key === "space";
const charOf = (key: string) => (key === "space" ? " " : key);

function openPicker(s: State): [State, Effect[]] {
  if (s.ui.focus !== "entries" || entriesIn(s).length === 0) {
    return [withUI(s, { message: note("move needs entries: press l to focus the entries pane first", "warn") }), []];
  }
  return [withUI(s, { overlay: { kind: "picker", query: "", sel: 0 } }), []];
}

function readOnly(s: State): State | null {
  if (!s.preview) return null;
  return withUI(s, { message: note("the import preview is read-only: enter applies it, i leaves it", "warn") });
}

function moveCursor(s: State, delta: number): State {
  const ui = s.ui;
  if (ui.focus === "cats") {
    const n = docOf(s).categories.length;
    const catIdx = clampIdx(ui.catIdx + delta, n);
    return catIdx === ui.catIdx ? s : withUI(s, { catIdx, entIdx: 0, anchor: null });
  }
  return withUI(s, { entIdx: clampIdx(ui.entIdx + delta, entriesIn(s).length) });
}

function jump(s: State, to: "first" | "last"): State {
  const n = s.ui.focus === "cats" ? docOf(s).categories.length : entriesIn(s).length;
  const idx = to === "first" ? 0 : Math.max(0, n - 1);
  if (s.ui.focus === "cats") return withUI(s, { catIdx: idx, entIdx: 0, anchor: null });
  return withUI(s, { entIdx: idx });
}

function searchMatches(s: State): number[] {
  const q = s.ui.search.toLowerCase();
  if (!q) return [];
  const doc = docOf(s);
  const out: number[] = [];
  if (s.ui.focus === "cats") {
    for (const [i, c] of doc.categories.entries()) if (c.title.toLowerCase().includes(q)) out.push(i);
  } else {
    const t = (id: string) => titleOf(s, id);
    for (const [i, e] of entriesIn(s).entries()) if (haystack(e, t).includes(q)) out.push(i);
  }
  return out;
}

export function matchSet(s: State): Set<number> {
  return new Set(searchMatches(s));
}

function nextMatch(s: State, dir: 1 | -1): State {
  if (!s.ui.search) return withUI(s, { message: note("no search yet: press /", "warn") });
  const hits = searchMatches(s);
  if (hits.length === 0) return withUI(s, { message: note(`no match for "${s.ui.search}"`, "warn") });
  const cur = s.ui.focus === "cats" ? s.ui.catIdx : s.ui.entIdx;
  const pick = dir === 1 ? (hits.find((i) => i > cur) ?? hits[0]) : ([...hits].reverse().find((i) => i < cur) ?? hits[hits.length - 1]);
  const idx = pick ?? cur;
  const where = hits.indexOf(idx) + 1;
  const text = `/${s.ui.search}  ${where}/${hits.length}`;
  return s.ui.focus === "cats"
    ? withUI(s, { catIdx: idx, entIdx: 0, anchor: null, message: note(text) })
    : withUI(s, { entIdx: idx, message: note(text) });
}

function startSave(s: State): [State, Effect[]] {
  if (s.preview) return [readOnly(s) as State, []];
  const sum = summaryOf(s);
  if (!sum.changed) return [withUI(s, { message: note("nothing to save") }), []];
  const lines = describe(sum);
  lines.push("");
  lines.push(`the template ${s.info.template_name} is saved, its old copy kept as a .bak next to it`);
  lines.push(
    s.info.target_exists && !s.info.target_generated
      ? `${relTo(s.info.root, s.info.target)} is hand-written: it is replaced, its old copy kept as a .bak`
      : `${relTo(s.info.root, s.info.target)} is generated again, its old copy kept as a .bak`,
  );
  return [withUI(s, { overlay: { kind: "confirm", purpose: "save", level: "warn", lines } }), []];
}

export function relTo(root: string, p: string): string {
  const r = root.replace(/\/+$/, "");
  return p.startsWith(`${r}/`) ? p.slice(r.length + 1) : p;
}

function startQuit(s: State): [State, Effect[]] {
  if (!isDirty(s)) return [{ ...s, quit: true }, [{ type: "quit" }]];
  const sum = summaryOf(s);
  const lines = [`${plural(changeCount(sum), "unsaved change")}:`, ...describe(sum).map((l) => `  ${l}`)];
  return [withUI(s, { overlay: { kind: "confirm", purpose: "quit", level: "error", lines } }), []];
}

// ---- conflicts -----------------------------------------------------------

/** Put the cursor on an entry, whatever category it is in. */
function focusEntry(s: State, id: string): State {
  const doc = docOf(s);
  const e = doc.entries.find((x) => x.id === id);
  if (!e) return s;
  const catIdx = Math.max(
    0,
    doc.categories.findIndex((c) => c.id === e.category),
  );
  const at = withUI(s, { catIdx, focus: "entries", anchor: null });
  const entIdx = Math.max(
    0,
    entriesIn(at).findIndex((x) => x.id === id),
  );
  return withUI(at, { entIdx });
}

const where = (s: State, id: string): string => {
  const e = docOf(s).entries.find((x) => x.id === id);
  return e ? `${e.category}/${e.id}` : id;
};

function jumpConflict(s: State, dir: 1 | -1): State {
  const c = conflictsFor(s);
  if (c.order.length === 0) return withUI(s, { message: note(analysisHint(s, "no conflicts"), "warn") });
  const doc = docOf(s);
  const pos = new Map(doc.entries.map((e, i) => [e.id, i]));
  const here = entryAt(s);
  const at = here && s.ui.focus === "entries" ? (pos.get(here.id) ?? -1) : -1;
  const ordered = c.order.map((id) => ({ id, i: pos.get(id) ?? 0 }));
  const next =
    dir === 1
      ? (ordered.find((o) => o.i > at) ?? ordered[0])
      : ([...ordered].reverse().find((o) => o.i < at) ?? ordered[ordered.length - 1]);
  if (!next) return s;
  const n = c.order.indexOf(next.id) + 1;
  return withUI(focusEntry(s, next.id), { message: note(`conflict ${n}/${c.order.length}: ${where(s, next.id)}`) });
}

function analysisHint(s: State, none: string): string {
  const a = s.analysis;
  if (a.status === "running" || a.status === "idle") return `${none} yet: still analysing keymaps`;
  if (a.status === "failed") return `${none} found: the analysis failed (${a.message.split("\n")[0]})`;
  return none;
}

function toggleFilter(s: State): State {
  const filter = !s.ui.filter;
  const n = conflictsFor(s).order.length;
  const msg = filter ? (n ? `showing the ${n} conflicted entries; ! shows all` : analysisHint(s, "no conflicts")) : "showing all entries";
  return settle(withUI(s, { filter, entIdx: 0, anchor: null, message: note(msg, filter && !n ? "warn" : "info") }));
}

/** The duplicate group of the entry under the cursor, or a message saying why there is none. */
function dupOf(s: State): { id: string; members: string[]; winner: string } | string {
  const e = entryAt(s);
  if (!e || s.ui.focus !== "entries") return "press l to focus the entries pane first";
  const d = conflictsFor(s).byEntry.get(e.id)?.dups[0];
  if (!d) return "this entry has no duplicate";
  return { id: e.id, members: d.members, winner: d.winner };
}

function otherEntry(s: State): State {
  const d = dupOf(s);
  if (typeof d === "string") return withUI(s, { message: note(d, "warn") });
  const i = d.members.indexOf(d.id);
  const other = d.members[(i + 1) % d.members.length] as string;
  return withUI(focusEntry(s, other), { message: note(`the other entry on this key: ${where(s, other)}`) });
}

function startDeleteEntry(s: State): [State, Effect[]] {
  const ro = readOnly(s);
  if (ro) return [ro, []];
  const d = dupOf(s);
  if (typeof d === "string") return [withUI(s, { message: note(d, "warn") }), []];
  const e = entryAt(s);
  if (d.winner === d.id) {
    return [withUI(s, { message: note("x deletes the shadowed entry: press o to jump to it, or P to let the other one win", "warn") }), []];
  }
  const lines = [
    `delete ${(e?.modes ?? []).join("")} ${e?.lhs ?? d.id} (${where(s, d.id)})?`,
    `it never runs: ${where(s, d.winner)} binds the same key later`,
    "the entry leaves the template when you save, the old template is kept as a .bak",
  ];
  return [withUI(s, { overlay: { kind: "confirm", purpose: "entry", level: "error", lines, target: d.id } }), []];
}

function swapPrecedence(s: State): State {
  const ro = readOnly(s);
  if (ro) return ro;
  const d = dupOf(s);
  if (typeof d === "string") return withUI(s, { message: note(d, "warn") });
  const doc = s.h.present;
  const others = d.members.filter((m) => m !== d.id);
  const mine = doc.entries.find((x) => x.id === d.id);
  let next: Doc;
  let text: string;
  if (d.winner === d.id) {
    const anchor = others[others.length - 1] as string;
    next = placeNear(doc, d.id, anchor, "before");
    text = `${where(s, d.id)} now runs before ${where(s, anchor)}, which wins`;
  } else {
    next = placeNear(doc, d.id, d.winner, "after");
    text = `${where(s, d.id)} now runs after ${where(s, d.winner)} and wins`;
  }
  const target = next.entries.find((x) => x.id === d.id);
  if (target && mine && target.category !== mine.category) {
    text += `; it moved to ${next.categories.find((c) => c.id === target.category)?.title ?? target.category}`;
  }
  if (next === doc) return withUI(s, { message: note("already in that order", "warn") });
  return edit(s, next, note(text, "ok"), { cat: target?.category, entry: d.id });
}

function showRemoved(s: State): State {
  const r = conflictsFor(s).removed;
  if (r.length === 0) return withUI(s, { message: note(analysisHint(s, "your template removes no defaults"), "info") });
  const lines = [`${plural(r.length, "default")} removed by the template (shown, not editable):`];
  for (const x of r) lines.push(`  ${x.mode} ${x.lhs}  ${labelOf(x.def)}  (${x.def.source})`);
  return withUI(s, { overlay: { kind: "result", level: "dim", lines } });
}

function handleNormal(s: State, key: string): [State, Effect[]] {
  const ui = s.ui;
  const pending = ui.pending;
  const cur = pending ? withUI(s, { pending: "" }) : s;
  if (pending === "g") {
    if (key === "g") return [jump(cur, "first"), []];
    return [cur, []];
  }
  if (pending === "]" || pending === "[") {
    if (key === "c") return [jumpConflict(cur, pending === "]" ? 1 : -1), []];
    return [cur, []];
  }
  const half = Math.max(1, Math.floor(layout(ui.size).listRows / 2));
  const inEntries = ui.focus === "entries";
  switch (key) {
    case "j":
    case "down":
      return [moveCursor(cur, 1), []];
    case "k":
    case "up":
      return [moveCursor(cur, -1), []];
    case "g":
      return [withUI(cur, { pending: "g" }), []];
    case "G":
      return [jump(cur, "last"), []];
    case "]":
    case "[":
      return [withUI(cur, { pending: key }), []];
    case "!":
      return [toggleFilter(cur), []];
    case "D":
      return [showRemoved(cur), []];
    case "C-d":
    case "pagedown":
      return [moveCursor(cur, half), []];
    case "C-u":
    case "pageup":
      return [moveCursor(cur, -half), []];
    case "h":
    case "left":
    case "S-tab":
      return [withUI(cur, { focus: "cats", anchor: null }), []];
    case "l":
    case "right":
    case "tab":
      return [withUI(cur, { focus: "entries" }), []];
    case "return":
      if (s.preview) return startApply(cur);
      return [withUI(cur, { focus: "entries" }), []];
    case "/":
      return [withUI(cur, { overlay: { kind: "input", purpose: "search", label: "/", text: "" } }), []];
    case "n":
      return [nextMatch(cur, 1), []];
    case "N":
      return [nextMatch(cur, -1), []];
    case "i":
      if (s.preview) return [withUI({ ...cur, preview: null }, { message: note("left the import preview") }), []];
      return [withUI(cur, { message: note("reading the file...") }), [{ type: "preview", keepHeaders: true }]];
    case "w":
      return startSave(cur);
    case "q":
    case "C-c":
      return startQuit(cur);
    case "u":
    case "C-r": {
      const ro = readOnly(cur);
      if (ro) return [ro, []];
      const next = key === "u" ? H.undo(cur.h) : H.redo(cur.h);
      if (next === cur.h) return [withUI(cur, { message: note(key === "u" ? "nothing to undo" : "nothing to redo") }), []];
      const moved = { ...cur, h: next };
      const what = key === "u" ? `undone, ${next.past.length} more to undo` : `redone, ${next.future.length} more to redo`;
      return [settle(withUI(moved, { message: note(what) }), {}), []];
    }
    case "O":
      return [withUI(cur, { overlay: { kind: "options", sel: 0 } }), []];
    case "escape":
      return [withUI(cur, { marks: new Set(), anchor: null, message: null }), []];
    case "C": {
      const c = categoryAt(cur);
      if (!c) return [cur, []];
      const slot = ((colorOverride(cur, c.id) ?? hashSlot(c.id)) + 1) % PALETTE_SIZE;
      return [withUI(cur, { colors: { ...cur.ui.colors, [c.id]: slot } }), []];
    }
    default:
      break;
  }
  // Entry commands.
  if (inEntries) {
    const list = entriesIn(cur);
    const e = list[ui.entIdx];
    switch (key) {
      case "space":
      case "v": {
        if (!e) return [cur, []];
        const marks = new Set(ui.marks);
        if (marks.has(e.id)) marks.delete(e.id);
        else marks.add(e.id);
        const moved = key === "space" ? moveCursor(withUI(cur, { marks }), 1) : withUI(cur, { marks });
        return [moved, []];
      }
      case "V": {
        if (ui.anchor === null) return [withUI(cur, { anchor: ui.entIdx }), []];
        const marks = new Set(ui.marks);
        for (const id of selection(cur)) marks.add(id);
        return [withUI(cur, { marks, anchor: null }), []];
      }
      case "A": {
        const marks = new Set(ui.marks);
        for (const x of list) marks.add(x.id);
        return [withUI(cur, { marks, message: note(`${plural(list.length, "entry", "entries")} marked`) }), []];
      }
      case "m": {
        const ro = readOnly(cur);
        return ro ? [ro, []] : openPicker(cur);
      }
      case "o":
        return [otherEntry(cur), []];
      case "x":
        return startDeleteEntry(cur);
      case "P":
        return [swapPrecedence(cur), []];
      case "J":
      case "K": {
        const ro = readOnly(cur);
        if (ro) return [ro, []];
        const ids = new Set(selection(cur));
        const doc = reorderEntries(cur.h.present, ids, key === "J" ? 1 : -1);
        return [edit(cur, doc, null, { entry: e?.id }), []];
      }
      default:
        break;
    }
  }
  // Category commands work from either pane, on the selected category.
  const cat = categoryAt(cur);
  switch (key) {
    case "c": {
      const ro = readOnly(cur);
      if (ro) return [ro, []];
      return [withUI(cur, { overlay: { kind: "input", purpose: "newcat", label: "new category: ", text: "" } }), []];
    }
    case "r": {
      const ro = readOnly(cur);
      if (ro) return [ro, []];
      if (!cat || cat.id === UNCATEGORIZED) return [withUI(cur, { message: note("Uncategorized cannot be renamed", "warn") }), []];
      return [withUI(cur, { overlay: { kind: "input", purpose: "rename", label: `rename ${cat.title}: `, text: cat.title } }), []];
    }
    case "d": {
      const ro = readOnly(cur);
      if (ro) return [ro, []];
      if (!cat || cat.id === UNCATEGORIZED) return [withUI(cur, { message: note("Uncategorized cannot be deleted", "warn") }), []];
      const n = entriesOf(cur.h.present, cat.id).length;
      const lines = [
        `delete the category "${cat.title}"?`,
        n ? `its ${plural(n, "entry", "entries")} go back to Uncategorized` : "it has no entries",
      ];
      return [withUI(cur, { overlay: { kind: "confirm", purpose: "delete", level: "error", lines, target: cat.id } }), []];
    }
    case "<":
    case ">": {
      const ro = readOnly(cur);
      if (ro) return [ro, []];
      if (!cat) return [cur, []];
      const doc = moveCategory(cur.h.present, cat.id, key === ">" ? 1 : -1);
      return [
        edit(cur, doc, doc === cur.h.present ? note("Uncategorized stays first; that is as far as it goes", "warn") : null, {
          cat: cat.id,
        }),
        [],
      ];
    }
    default:
      return [cur, []];
  }
}

export function hashSlot(id: string): number {
  let h = 2166136261;
  for (const ch of id) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return (h >>> 0) % PALETTE_SIZE;
}

function startApply(s: State): [State, Effect[]] {
  const p = s.preview;
  if (!p) return [s, []];
  const lines = [
    `replace the template with what an import would build (${plural(p.doc.categories.length, "category", "categories")}, ${plural(p.doc.entries.length, "entry", "entries")})?`,
    "the old template is backed up first",
  ];
  if (isDirty(s)) lines.push(`your ${plural(changeCount(summaryOf(s)), "unsaved change")} in this session are dropped`);
  return [withUI(s, { overlay: { kind: "confirm", purpose: "apply", level: "warn", lines } }), []];
}

function handleConfirm(s: State, key: string, o: Extract<Overlay, { kind: "confirm" }>): [State, Effect[]] {
  const close = withUI(s, { overlay: null });
  const yes = key === "y";
  const no = key === "n" || key === "escape" || key === "q";
  if (o.purpose === "quit") {
    if (yes) return [{ ...close, quit: true }, [{ type: "quit" }]];
    if (key === "w") return startSave(close);
    return [no ? close : s, []];
  }
  if (!yes) return [no ? close : s, []];
  switch (o.purpose) {
    case "delete": {
      const doc = deleteCategory(s.h.present, o.target ?? "");
      return [edit(close, doc, note("category deleted; its entries are in Uncategorized", "warn"), { cat: UNCATEGORIZED }), []];
    }
    case "save":
      return [
        { ...close, busy: true, ui: { ...close.ui, message: note("saving...") } },
        [{ type: "save", plan: toPlan(s.h.present, s.base) }],
      ];
    case "apply":
      return [{ ...close, busy: true, ui: { ...close.ui, message: note("importing...") } }, [{ type: "import", keepHeaders: true }]];
    case "import":
      return [{ ...close, busy: true, ui: { ...close.ui, message: note("importing...") } }, [{ type: "import", keepHeaders: false }]];
    case "entry": {
      const doc = removeEntries(s.h.present, new Set([o.target ?? ""]));
      return [edit(close, doc, note("entry deleted; it leaves the template when you save", "warn")), []];
    }
  }
}

function validTitle(s: State, title: string, except?: string): string | null {
  if (!title.trim()) return "a category needs a name";
  if (title.length > 70) return "a category name is at most 70 columns";
  const dup = docOf(s).categories.find((c) => c.id !== except && c.title.toLowerCase() === title.trim().toLowerCase());
  return dup ? `a category called "${dup.title}" already exists` : null;
}

function handleInput(s: State, key: string, o: Extract<Overlay, { kind: "input" }>): [State, Effect[]] {
  const set = (text: string) => withUI(s, { overlay: { ...o, text } });
  if (key === "escape" || key === "C-c") return [withUI(s, { overlay: null }), []];
  if (key === "backspace") return [set(o.text.slice(0, -1)), []];
  if (key === "C-u") return [set(""), []];
  if (printable(key)) return [set(o.text + charOf(key)), []];
  if (key !== "return") return [s, []];
  const closed = withUI(s, { overlay: null });
  const text = o.text.trim();
  switch (o.purpose) {
    case "search": {
      const found = withUI(closed, { search: text });
      if (!text) return [found, []];
      const hits = searchMatches(found);
      if (hits.length === 0) return [withUI(found, { message: note(`no match for "${text}"`, "warn") }), []];
      const cur = found.ui.focus === "cats" ? found.ui.catIdx : found.ui.entIdx;
      const idx = hits.find((i) => i >= cur) ?? (hits[0] as number);
      const msg = note(`/${text}  ${hits.indexOf(idx) + 1}/${hits.length}`);
      return [
        found.ui.focus === "cats" ? withUI(found, { catIdx: idx, entIdx: 0, message: msg }) : withUI(found, { entIdx: idx, message: msg }),
        [],
      ];
    }
    case "newcat": {
      const bad = validTitle(s, text);
      if (bad) return [withUI(s, { message: note(bad, "warn"), overlay: o }), []];
      const made = addCategory(s.h.present, text);
      return [edit(closed, made.doc, note(`new category "${text}"`, "ok"), { cat: made.id }), []];
    }
    case "newcat-move": {
      const bad = validTitle(s, text);
      if (bad) return [withUI(s, { message: note(bad, "warn"), overlay: o }), []];
      return [moveToNew(closed, text), []];
    }
    case "rename": {
      const cat = categoryAt(s);
      if (!cat) return [closed, []];
      const bad = validTitle(s, text, cat.id);
      if (bad) return [withUI(s, { message: note(bad, "warn"), overlay: o }), []];
      return [edit(closed, renameCategory(s.h.present, cat.id, text), note(`renamed to "${text}"`, "ok"), { cat: cat.id }), []];
    }
  }
}

function moveTo(s: State, ids: string[], to: string, doc: Doc = s.h.present): State {
  const next = moveEntries(doc, new Set(ids), to);
  const title = categoryOf(next, to)?.title ?? to;
  if (next === s.h.present) return withUI(s, { message: note("those entries are already there", "warn") });
  return edit(s, next, note(`moved ${plural(ids.length, "entry", "entries")} to ${title}`, "ok"), {}, { marks: new Set(), anchor: null });
}

function moveToNew(s: State, title: string): State {
  const ids = selection(s);
  const made = addCategory(s.h.present, title);
  const next = moveEntries(made.doc, new Set(ids), made.id);
  return edit(
    s,
    next,
    note(`moved ${plural(ids.length, "entry", "entries")} to the new category "${title}"`, "ok"),
    {},
    { marks: new Set(), anchor: null },
  );
}

function handlePicker(s: State, key: string, o: Extract<Overlay, { kind: "picker" }>): [State, Effect[]] {
  const items = pickItems(s, o.query);
  const set = (patch: Partial<typeof o>) => withUI(s, { overlay: { ...o, ...patch } });
  if (key === "escape" || key === "C-c") return [withUI(s, { overlay: null }), []];
  if (key === "down" || key === "C-n" || key === "tab") return [set({ sel: (o.sel + 1) % items.length }), []];
  if (key === "up" || key === "C-p" || key === "S-tab") return [set({ sel: (o.sel - 1 + items.length) % items.length }), []];
  if (key === "backspace") return [set({ query: o.query.slice(0, -1), sel: 0 }), []];
  if (key === "C-u") return [set({ query: "", sel: 0 }), []];
  if (printable(key)) return [set({ query: o.query + charOf(key), sel: 0 }), []];
  if (key !== "return") return [s, []];
  const pick = items[Math.min(o.sel, items.length - 1)];
  const closed = withUI(s, { overlay: null });
  if (!pick) return [closed, []];
  if (pick.kind === "cat") return [moveTo(closed, selection(s), pick.id), []];
  const q = o.query.trim();
  if (q) {
    const bad = validTitle(s, q);
    if (bad) return [withUI(s, { message: note(bad, "warn") }), []];
    return [moveToNew(closed, q), []];
  }
  return [withUI(s, { overlay: { kind: "input", purpose: "newcat-move", label: "new category for the selection: ", text: "" } }), []];
}

/** Up and down pick a row, left and right cycle its value; the new settings go out as an effect so they get saved. */
function handleOptions(s: State, key: string, o: Extract<Overlay, { kind: "options" }>): [State, Effect[]] {
  const n = OPTIONS.length;
  if (key === "escape" || key === "q" || key === "O" || key === "return" || key === "C-c") return [withUI(s, { overlay: null }), []];
  if (key === "j" || key === "down") return [withUI(s, { overlay: { ...o, sel: Math.min(n - 1, o.sel + 1) } }), []];
  if (key === "k" || key === "up") return [withUI(s, { overlay: { ...o, sel: Math.max(0, o.sel - 1) } }), []];
  const dir = key === "l" || key === "right" ? 1 : key === "h" || key === "left" ? -1 : 0;
  const row = OPTIONS[o.sel];
  if (!dir || !row) return [s, []];
  const settings = cycle(s.settings, row, dir);
  return [{ ...s, settings }, [{ type: "settings", settings }]];
}

function handleMissing(s: State, key: string): [State, Effect[]] {
  if (key === "O") return [withUI(s, { overlay: { kind: "options", sel: 0 } }), []];
  if (key === "q" || key === "escape" || key === "C-c") return [{ ...s, quit: true }, [{ type: "quit" }]];
  if (!s.sourceExists) return [s, []];
  if (key === "y" || key === "d") {
    return [{ ...s, busy: true, ui: { ...s.ui, message: note("importing...") } }, [{ type: "import", keepHeaders: key === "y" }]];
  }
  return [s, []];
}

// ---- update --------------------------------------------------------------

export function update(s: State, ev: Event): [State, Effect[]] {
  switch (ev.type) {
    case "resize":
      return [withUI(s, { size: ev.size }), []];
    case "failed": {
      const base = { ...s, busy: false };
      return [
        withUI(base, { overlay: { kind: "result", level: "error", lines: ev.message.split("\n").filter(Boolean) }, message: null }),
        [],
      ];
    }
    case "analysis-start":
      if (s.analysis.status !== "idle" || s.screen !== "main") return [s, []];
      return [{ ...s, analysis: { status: "running", frame: 0 } }, [{ type: "analyze" }]];
    case "tick":
      return s.analysis.status === "running" ? [{ ...s, analysis: { status: "running", frame: s.analysis.frame + 1 } }, []] : [s, []];
    case "analyzed": {
      const partial = ev.snapshot.status === "partial";
      const warned = ev.snapshot.warnings?.[0];
      const text = partial
        ? `analysis incomplete: ${ev.snapshot.error ?? "the generated file stopped early"}`
        : warned
          ? `analysis incomplete: ${warned}`
          : (ev.snapshot.note ?? null);
      const message = s.ui.message ?? (text ? note(text, partial ? "warn" : "dim") : null);
      return [settle(withUI({ ...s, analysis: { status: "done", snapshot: ev.snapshot } }, { message })), []];
    }
    case "analysis-failed": {
      const first = ev.message.split("\n").find(Boolean) ?? "unknown error";
      return [
        withUI({ ...s, analysis: { status: "failed", message: ev.message } }, { message: note(`analysis failed: ${first}`, "dim") }),
        [],
      ];
    }
    case "loaded": {
      const fresh = init(ev.loaded, s.ui.size, s.settings);
      const next: State = {
        ...fresh,
        analysis: s.analysis,
        ui: { ...fresh.ui, message: ev.note ?? fresh.ui.message, colors: s.ui.colors, filter: s.ui.filter },
      };
      return next.analysis.status === "idle" && next.screen === "main" ? update(next, { type: "analysis-start" }) : [next, []];
    }
    case "select": {
      if (s.busy || s.ui.overlay || s.screen !== "main") return [s, []];
      if (ev.pane === "cats") {
        const catIdx = clampIdx(ev.index, docOf(s).categories.length);
        return [withUI(s, { focus: "cats", catIdx, entIdx: catIdx === s.ui.catIdx ? s.ui.entIdx : 0, anchor: null }), []];
      }
      return [withUI(s, { focus: "entries", entIdx: clampIdx(ev.index, entriesIn(s).length) }), []];
    }
    case "scroll":
      if (s.busy || s.ui.overlay || s.screen !== "main") return [s, []];
      return [moveCursor(s, ev.delta), []];
    case "previewed": {
      const doc = normalize(ev.loaded.doc);
      const n = doc.categories.length;
      return [
        withUI(
          { ...s, preview: { doc, calls: ev.loaded.calls } },
          {
            catIdx: 0,
            entIdx: 0,
            focus: "cats",
            anchor: null,
            message: note(`preview: the import would make ${plural(n, "category", "categories")}. enter applies it, i leaves it`, "warn"),
          },
        ),
        [],
      ];
    }
    case "saved": {
      const none = "none (there was no file to back up)";
      const lines = ["template saved", `  backup: ${ev.result.templateBackup ? relTo(s.info.root, ev.result.templateBackup) : none}`];
      if (ev.result.generateError) {
        lines.push(
          `${relTo(s.info.root, ev.result.target)} was NOT generated:`,
          ...ev.result.generateError
            .split("\n")
            .filter(Boolean)
            .map((l) => `  ${l}`),
        );
        lines.push("fix that, then run scripts/kh-generate");
      } else if (ev.result.targetStatus === "unchanged") {
        lines.push(`${relTo(s.info.root, ev.result.target)} already matched, nothing written`);
      } else {
        lines.push(
          `wrote ${relTo(s.info.root, ev.result.target)}`,
          `  backup: ${ev.result.targetBackup ? relTo(s.info.root, ev.result.targetBackup) : none}`,
        );
      }
      const level: Level = ev.result.generateError ? "error" : "ok";
      const fresh = ev.loaded ? init(ev.loaded, s.ui.size, s.settings) : { ...s, busy: false };
      return [
        {
          ...fresh,
          busy: false,
          analysis: s.analysis,
          ui: { ...fresh.ui, overlay: { kind: "result", level, lines }, colors: s.ui.colors, message: null, filter: s.ui.filter },
        },
        [],
      ];
    }
    case "key":
      break;
  }
  if (s.busy) return [s, []];
  const key = ev.key;
  const base = s.ui.message && !s.ui.overlay ? withUI(s, { message: null }) : s;
  const o = base.ui.overlay;
  if (o) {
    if (o.kind === "result") return [withUI(base, { overlay: null }), []];
    if (o.kind === "confirm") return handleConfirm(base, key, o);
    if (o.kind === "input") return handleInput(base, key, o);
    if (o.kind === "options") return handleOptions(base, key, o);
    return handlePicker(base, key, o);
  }
  if (base.screen === "missing") return handleMissing(base, key);
  return handleNormal(base, key);
}
