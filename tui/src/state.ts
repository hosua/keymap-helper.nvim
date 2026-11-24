// The whole app as one pure function: update(state, event) gives the next
// state and the side effects to run (save, preview, import, quit). The views
// only draw the state; the bridge runs the effects and reports back as events.
import {
  addCategory,
  categoryOf,
  deleteCategory,
  entriesOf,
  isGrouped,
  moveCategory,
  moveEntries,
  normalize,
  renameCategory,
  reorderEntries,
} from "./doc.ts";
import { rank } from "./fuzzy.ts";
import * as H from "./history.ts";
import { layout, type Size } from "./layout.ts";
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
  UNCATEGORIZED,
} from "./types.ts";

export type Focus = "cats" | "entries";

export type PickItem = { kind: "cat"; id: string; title: string } | { kind: "new" };

export type Overlay =
  | { kind: "picker"; query: string; sel: number }
  | { kind: "input"; purpose: "newcat" | "newcat-move" | "rename" | "search"; label: string; text: string }
  | { kind: "confirm"; purpose: "delete" | "quit" | "save" | "apply" | "import"; level: Level; lines: string[]; target?: string }
  | { kind: "result"; level: Level; lines: string[] };

export interface Message {
  text: string;
  level: Level;
}

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
  ui: UI;
  busy: boolean;
  quit: boolean;
}

export type Effect =
  | { type: "save"; plan: SavePlan }
  | { type: "preview"; keepHeaders: boolean }
  | { type: "import"; keepHeaders: boolean }
  | { type: "reload" }
  | { type: "quit" };

export type Event =
  | { type: "key"; key: string }
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
    colors: {},
    size,
  };
}

export function init(loaded: Loaded | Missing, size: Size): State {
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
      ui: freshUI(size),
      busy: false,
      quit: false,
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
    ui: { ...ui, message: note },
    busy: false,
    quit: false,
  };
}

// ---- selectors -----------------------------------------------------------

export const docOf = (s: State): Doc => s.preview?.doc ?? s.h.present;
export const callsOf = (s: State): Readonly<Record<string, string>> => s.preview?.calls ?? s.calls;
export const categoryAt = (s: State) => docOf(s).categories[s.ui.catIdx];
export const entriesIn = (s: State): Entry[] => {
  const c = categoryAt(s);
  return c ? entriesOf(docOf(s), c.id) : [];
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
  return withUI(s, { message: note("the keep_headers preview is read-only: enter applies it, i leaves it", "warn") });
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

function handleNormal(s: State, key: string): [State, Effect[]] {
  const ui = s.ui;
  const pending = ui.pending;
  const cur = pending ? withUI(s, { pending: "" }) : s;
  if (pending === "g") {
    if (key === "g") return [jump(cur, "first"), []];
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
      if (s.preview) return [withUI({ ...cur, preview: null }, { message: note("left the keep_headers preview") }), []];
      return [withUI(cur, { message: note("reading the file with keep_headers...") }), [{ type: "preview", keepHeaders: true }]];
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
      return [{ ...close, busy: true, ui: { ...close.ui, message: note("saving...") } }, [{ type: "save", plan: toPlan(s.h.present) }]];
    case "apply":
      return [{ ...close, busy: true, ui: { ...close.ui, message: note("importing...") } }, [{ type: "import", keepHeaders: true }]];
    case "import":
      return [{ ...close, busy: true, ui: { ...close.ui, message: note("importing...") } }, [{ type: "import", keepHeaders: false }]];
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

function handleMissing(s: State, key: string): [State, Effect[]] {
  if (key === "q" || key === "escape" || key === "C-c") return [{ ...s, quit: true }, [{ type: "quit" }]];
  if (!s.sourceExists) return [s, []];
  if (key === "y" || key === "h") {
    return [{ ...s, busy: true, ui: { ...s.ui, message: note("importing...") } }, [{ type: "import", keepHeaders: key === "h" }]];
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
    case "loaded": {
      const fresh = init(ev.loaded, s.ui.size);
      return [{ ...fresh, ui: { ...fresh.ui, message: ev.note ?? fresh.ui.message, colors: s.ui.colors } }, []];
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
            message: note(`preview: keep_headers would make ${plural(n, "category", "categories")}. enter applies it, i leaves it`, "warn"),
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
      const fresh = ev.loaded ? init(ev.loaded, s.ui.size) : { ...s, busy: false };
      return [
        { ...fresh, busy: false, ui: { ...fresh.ui, overlay: { kind: "result", level, lines }, colors: s.ui.colors, message: null } },
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
    return handlePicker(base, key, o);
  }
  if (base.screen === "missing") return handleMissing(base, key);
  return handleNormal(base, key);
}
