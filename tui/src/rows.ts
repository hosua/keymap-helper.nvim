// Rows of styled text for every part of the screen, built as plain data.
// A row is a list of segments; the views turn them into <span>s, and the tests
// read them as strings. Nothing here touches a renderer.
import { categoryOf } from "./doc.ts";
import type { Layout } from "./layout.ts";
import * as L from "./legend.ts";
import { grid, type LegendItem } from "./legend.ts";
import { C, CATEGORY_COLORS, levelColor, modeColor } from "./palette.ts";
import { changeCount } from "./plan.ts";
import {
  callsOf,
  categoryAt,
  docOf,
  entriesIn,
  entryAt,
  hashSlot,
  isDirty,
  matchSet,
  pickItems,
  relTo,
  type State,
  selection,
  summaryOf,
} from "./state.ts";
import { type Category, type Entry, UNCATEGORIZED } from "./types.ts";

export interface Seg {
  t: string;
  fg?: string;
  bg?: string;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
}
export type Row = Seg[];

const width = (s: string) => Bun.stringWidth(s);

export const rowText = (r: Row): string => r.map((s) => s.t).join("");

/** Cut text to `w` columns, ending in an ellipsis when something was dropped. */
export function clip(text: string, w: number): string {
  if (w <= 0) return "";
  if (width(text) <= w) return text;
  let out = "";
  for (const ch of text) {
    if (width(out + ch) > w - 1) break;
    out += ch;
  }
  return `${out}…`;
}

/** Fit a row to exactly `w` columns: clip, then pad with `bg`. */
export function fit(row: Row, w: number, bg?: string): Row {
  const out: Row = [];
  let used = 0;
  for (const seg of row) {
    const room = w - used;
    if (room <= 0) break;
    const text = width(seg.t) > room ? clip(seg.t, room) : seg.t;
    out.push({ ...seg, t: text });
    used += width(text);
  }
  if (used < w) out.push({ t: " ".repeat(w - used), bg });
  return out;
}

const plural = (n: number, one: string) => `${n} ${n === 1 ? one : `${one}s`}`;
const pad = (s: string, w: number) => s + " ".repeat(Math.max(0, w - width(s)));

export function categoryColor(s: State, id: string): string {
  const slot = s.ui.colors[id] ?? hashSlot(id);
  return CATEGORY_COLORS[slot % CATEGORY_COLORS.length] as string;
}

const blank = (w: number, bg?: string): Row => [{ t: " ".repeat(w), bg }];

// ---- panes ---------------------------------------------------------------

export function paneHeader(title: string, right: string, w: number, active: boolean, bg: string): Row {
  const left = ` ${title}`;
  const gap = Math.max(1, w - width(left) - width(right) - 1);
  return fit(
    [
      { t: left, fg: active ? C.text : C.grey, bold: true, bg: C.bar },
      { t: " ".repeat(gap), bg: C.bar },
      { t: `${right} `, fg: C.dim, bg: C.bar },
    ],
    w,
    C.bar,
  ).map((seg) => ({ ...seg, bg: seg.bg ?? bg }));
}

/** First index to draw so the cursor stays on screen, roughly centered. */
export function scrollTop(cursor: number, total: number, rows: number): number {
  if (total <= rows) return 0;
  return Math.max(0, Math.min(cursor - Math.floor(rows / 2), total - rows));
}

export function categoryRows(s: State, l: Layout): Row[] {
  const doc = docOf(s);
  const w = l.leftW;
  const hits = s.ui.focus === "cats" ? matchSet(s) : new Set<number>();
  const counts = new Map<string, number>();
  for (const e of doc.entries) counts.set(e.category, (counts.get(e.category) ?? 0) + 1);
  const top = scrollTop(s.ui.catIdx, doc.categories.length, l.listRows);
  const rows: Row[] = [];
  for (let i = top; i < Math.min(doc.categories.length, top + l.listRows); i++) {
    const c = doc.categories[i] as Category;
    const n = counts.get(c.id) ?? 0;
    const selected = i === s.ui.catIdx;
    const bg = selected ? (s.ui.focus === "cats" ? C.cursorFocus : C.cursorBlur) : C.left;
    const unc = c.id === UNCATEGORIZED;
    const loud = unc && n > 0;
    const color = unc ? (n > 0 ? C.warn : C.ok) : categoryColor(s, c.id);
    const count = String(n);
    const label = unc ? (n > 0 ? "! " : "✓ ") : "■ ";
    const titleW = w - width(label) - width(count) - 3;
    rows.push(
      fit(
        [
          { t: " ", bg },
          { t: label, fg: color, bold: loud, bg },
          {
            t: pad(clip(c.title, titleW), titleW),
            fg: loud ? C.warn : hits.has(i) ? C.match : n === 0 ? C.dim : C.text,
            bold: loud || selected,
            underline: hits.has(i),
            bg,
          },
          { t: ` ${count} `, fg: loud ? C.warn : C.grey, bold: loud, bg },
        ],
        w,
        bg,
      ),
    );
  }
  return rows;
}

function descOf(e: Entry): string {
  const o = Array.isArray(e.opts) ? undefined : e.opts;
  if (typeof o?.desc === "string" && o.desc) return o.desc;
  if (e.rhs !== undefined) return e.rhs;
  return (e.lua ?? "").split("\n")[0] ?? "";
}

const kindTag = (e: Entry) => (e.kind === "raw" ? "raw" : e.lua !== undefined ? "lua" : "rhs");
const tagColor = (t: string) => (t === "lua" ? "#A78BFA" : t === "raw" ? C.dim : C.grey);

export function modeBadges(modes: string[] | undefined, bg?: string): Row {
  const row: Row = [];
  for (const m of modes ?? []) row.push({ t: m, fg: modeColor(m), bold: true, bg });
  return row;
}

export function entryRows(s: State, l: Layout): Row[] {
  const list = entriesIn(s);
  const w = l.midW;
  const hits = s.ui.focus === "entries" ? matchSet(s) : new Set<number>();
  const sel = new Set(s.ui.anchor === null ? [] : selection(s));
  const top = scrollTop(s.ui.entIdx, list.length, l.listRows);
  const lhsW = Math.max(8, Math.min(24, Math.floor(w * 0.36)));
  const rows: Row[] = [];
  if (list.length === 0) {
    return [fit([{ t: " nothing here yet. Press m on entries in another category.", fg: C.dim, italic: true, bg: C.mid }], w, C.mid)];
  }
  for (let i = top; i < Math.min(list.length, top + l.listRows); i++) {
    const e = list[i] as Entry;
    const cursor = i === s.ui.entIdx;
    const bg = cursor ? (s.ui.focus === "entries" ? C.cursorFocus : C.cursorBlur) : sel.has(e.id) ? C.range : C.mid;
    const marked = s.ui.marks.has(e.id);
    const raw = e.kind === "raw";
    const tag = kindTag(e);
    const head: Row = [{ t: marked ? "● " : "  ", fg: C.ok, bold: true, bg }];
    const hit = hits.has(i);
    if (raw) {
      const first = (e.text ?? "").split("\n").find((x) => x.trim() !== "") ?? "";
      const text = pad(clip(first.trim(), w - 13), w - 13);
      rows.push(
        fit(
          [
            ...head,
            { t: "raw   ", fg: C.dim, bg },
            { t: text, fg: hit ? C.match : C.dim, italic: true, underline: hit, bg },
            { t: ` ${tag} `, fg: tagColor(tag), bg },
          ],
          w,
          bg,
        ),
      );
      continue;
    }
    const modes = modeBadges(e.modes, bg);
    const modeW = (e.modes ?? []).length;
    const rest = Math.max(0, w - 2 - 6 - lhsW - 1 - 5);
    rows.push(
      fit(
        [
          ...head,
          ...modes,
          { t: " ".repeat(Math.max(1, 6 - modeW)), bg },
          { t: pad(clip(e.lhs ?? "", lhsW), lhsW), fg: hit ? C.match : C.text, bold: true, underline: hit, bg },
          { t: " ", bg },
          { t: pad(clip(descOf(e), rest), rest), fg: C.grey, bg },
          { t: ` ${tag} `, fg: tagColor(tag), bg },
        ],
        w,
        bg,
      ),
    );
  }
  return rows;
}

/** Wrap to `w` columns, at spaces when there is one in reach, else mid-word. */
export function wrap(text: string, w: number): string[] {
  const out: string[] = [];
  for (const line of text.split("\n")) {
    let rest = line;
    while (width(rest) > w) {
      let cut = "";
      for (const ch of rest) {
        if (width(cut + ch) > w) break;
        cut += ch;
      }
      const sp = cut.lastIndexOf(" ");
      if (sp > w / 3) cut = cut.slice(0, sp + 1);
      out.push(cut.trimEnd());
      rest = rest.slice(cut.length);
    }
    out.push(rest);
  }
  return out;
}

function optionList(o: Entry["opts"], raw = false): string[] {
  if (!o || Array.isArray(o)) return [];
  return Object.entries(o).map(([k, v]) =>
    v === true && !raw ? k : `${k}=${typeof v === "string" && !raw ? JSON.stringify(v) : String(v)}`,
  );
}

/** Details of the entry under the cursor. The last block is the exact generated Lua. */
export function detailRows(s: State, l: Layout): Row[] {
  const w = l.rightW;
  const e = entryAt(s);
  const bg = C.right;
  const line = (label: string, value: Row | string, labelColor: string = C.grey): Row =>
    typeof value === "string"
      ? [
          { t: ` ${label} `, fg: labelColor, bg },
          { t: value, fg: C.text, bg },
        ]
      : [{ t: ` ${label} `, fg: labelColor, bg }, ...value];
  if (!e) {
    const c = categoryAt(s);
    const rows: Row[] = [];
    if (c) {
      rows.push(line("category", [{ t: c.title, fg: categoryColor(s, c.id), bold: true, bg }]));
      rows.push(line("entries", "none"));
      if (c.subtitle) rows.push(line("subtitle", c.subtitle));
    }
    return rows.map((r) => fit(r, w, bg));
  }
  const cat = categoryOf(docOf(s), e.category);
  const rows: Row[] = [];
  const catSeg: Row = [
    { t: cat?.title ?? e.category, fg: cat?.id === UNCATEGORIZED ? C.warn : categoryColor(s, e.category), bold: true, bg },
  ];
  if (e.kind === "raw") {
    rows.push(line("raw Lua", [{ t: "kept as written", fg: C.dim, italic: true, bg }]));
    rows.push(line("category", catSeg));
    rows.push([{ t: " it can be moved, not edited", fg: C.dim, bg }]);
    rows.push([{ t: " moving it changes when it runs", fg: C.warn, bg }]);
    for (const t of wrap(e.text ?? "", w - 2).slice(0, 40)) rows.push([{ t: ` ${t}`, fg: C.dim, bg }]);
    return rows.map((r) => fit(r, w, bg));
  }
  rows.push([{ t: ` ${e.lhs ?? ""}`, fg: C.text, bold: true, bg }]);
  rows.push(
    line(
      "modes   ",
      modeBadges(e.modes, bg).flatMap((m, i) => (i ? [{ t: " ", bg }, m] : [m])),
    ),
  );
  rows.push(line("category", catSeg));
  const desc = descOf(e);
  if (typeof (Array.isArray(e.opts) ? undefined : e.opts)?.desc === "string") rows.push(line("desc    ", desc));
  rows.push(
    line(
      "action  ",
      e.lua !== undefined
        ? [
            { t: "lua", fg: "#A78BFA", bold: true, bg },
            { t: ` ${(e.lua.split("\n")[0] ?? "").trim()}`, fg: C.grey, bg },
          ]
        : [
            { t: "rhs", fg: C.info, bold: true, bg },
            { t: ` ${e.rhs ?? ""}`, fg: C.grey, bg },
          ],
    ),
  );
  const opts = optionList(e.opts).filter((o) => !o.startsWith("desc="));
  const optsRaw = optionList(e.opts_raw, true);
  if (opts.length) rows.push(line("options ", opts.join(" ")));
  if (optsRaw.length) rows.push(line("lua opts", optsRaw.join(", ")));
  if (e.comment) rows.push(line("comment ", (e.comment.split("\n")[0] ?? "").replace(/^--+\s?/, "")));
  // Extension point: other tools write `_badges` (a list of short strings) on
  // an entry and the details pane shows them as chips here.
  const badges = Array.isArray(e._badges) ? e._badges.filter((b): b is string => typeof b === "string") : [];
  if (badges.length) {
    rows.push(
      line(
        "badges  ",
        badges.flatMap((b, i) => [...(i ? [{ t: " ", bg }] : []), { t: ` ${b} `, fg: C.page, bg: C.warn, bold: true }]),
      ),
    );
  }
  rows.push([{ t: " generated Lua", fg: C.dim, bg }]);
  const code = callsOf(s)[e.id] ?? "";
  const budget = Math.max(2, l.listRows - rows.length);
  const wrapped = wrap(code, w - 2);
  for (const t of wrapped.slice(0, budget)) rows.push([{ t: ` ${t}`, fg: C.ok, bg }]);
  if (wrapped.length > budget) rows.push([{ t: " …", fg: C.dim, bg }]);
  return rows.map((r) => fit(r, w, bg));
}

// ---- bars ----------------------------------------------------------------

export function topBar(s: State, w: number): Row {
  const dirty = isDirty(s);
  const right: Row = [];
  if (s.screen === "missing") right.push({ t: " no template ", fg: C.page, bg: C.warn, bold: true });
  else if (s.preview) right.push({ t: " PREVIEW keep_headers ", fg: C.page, bg: C.warn, bold: true });
  else if (dirty) right.push({ t: ` ● ${plural(changeCount(summaryOf(s)), "change")} `, fg: C.page, bg: C.warn, bold: true });
  else right.push({ t: " saved ", fg: C.ok, bg: C.bar });
  const left: Row = [
    { t: " keymap-helper ", fg: C.page, bg: C.info, bold: true },
    { t: ` ${s.info.template_name}`, fg: C.text, bg: C.bar },
    { t: ` -> ${relTo(s.info.root, s.info.target)}`, fg: C.grey, bg: C.bar },
  ];
  const rw = right.reduce((n, g) => n + width(g.t), 0);
  const lw = left.reduce((n, g) => n + width(g.t), 0);
  const gap = Math.max(1, w - lw - rw);
  return fit([...left, { t: " ".repeat(gap), bg: C.bar }, ...right], w, C.bar);
}

export function messageRow(s: State, w: number): Row {
  const o = s.ui.overlay;
  if (o?.kind === "input") {
    return fit(
      [
        { t: ` ${o.label}`, fg: C.warn, bold: true, bg: C.page },
        { t: o.text, fg: C.text, bg: C.page },
        { t: "█", fg: C.text, bg: C.page },
      ],
      w,
      C.page,
    );
  }
  if (o?.kind === "picker") return fit([{ t: " move to which category?", fg: C.info, bold: true, bg: C.page }], w, C.page);
  const m = s.ui.message;
  if (!m) return blank(w, C.page);
  return fit([{ t: ` ${m.text}`, fg: levelColor(m.level), bold: m.level !== "info", bg: C.page }], w, C.page);
}

export function legendItems(s: State): LegendItem[] {
  const o = s.ui.overlay;
  if (o?.kind === "picker") return L.PICKER;
  if (o?.kind === "input") return L.INPUT;
  if (o?.kind === "result") return L.ANY_KEY;
  if (o?.kind === "confirm") return o.purpose === "quit" ? L.QUIT : L.YES_NO;
  if (s.screen === "missing") return s.sourceExists ? L.MISSING : L.MISSING_NO_SOURCE;
  return s.preview ? L.PREVIEW : L.NORMAL;
}

export function legendRows(s: State, w: number, minRows: number): Row[] {
  const g = grid(legendItems(s), w, minRows);
  return g.cells.map((cells) => {
    const row: Row = [];
    for (const c of cells) {
      if (!c) {
        row.push({ t: " ".repeat(g.cell), bg: C.page });
        continue;
      }
      const [k, d] = c;
      row.push({ t: ` ${pad(k, g.keyWidth)} `, fg: C.key, bold: true, bg: C.page });
      row.push({ t: pad(d, g.cell - g.keyWidth - 2), fg: C.grey, bg: C.page });
    }
    return fit(row, w, C.page);
  });
}

// ---- overlays ------------------------------------------------------------

export interface Popup {
  title: string;
  color: string;
  width: number;
  rows: Row[];
}

export function popup(s: State, size: { w: number; h: number }): Popup | null {
  const o = s.ui.overlay;
  if (!o) return null;
  const maxW = Math.max(30, Math.min(72, size.w - 4));
  const innerW = maxW - 2;
  const line = (t: string, fg: string = C.text, bold = false): Row => fit([{ t: ` ${t}`, fg, bold, bg: C.bar }], innerW, C.bar);
  if (o.kind === "picker") {
    const items = pickItems(s, o.query);
    const rows: Row[] = [
      fit(
        [
          { t: " > ", fg: C.warn, bold: true, bg: C.bar },
          { t: o.query, fg: C.text, bg: C.bar },
          { t: "█", fg: C.text, bg: C.bar },
        ],
        innerW,
        C.bar,
      ),
    ];
    const room = Math.max(3, Math.min(items.length, size.h - 10));
    const top = scrollTop(o.sel, items.length, room);
    items.slice(top, top + room).forEach((it, k) => {
      const i = top + k;
      const bg = i === o.sel ? C.cursorFocus : C.bar;
      const text = it.kind === "cat" ? it.title : o.query.trim() ? `+ new category "${o.query.trim()}"` : "+ new category...";
      const fg = it.kind === "new" ? C.ok : C.text;
      const dot: Seg =
        it.kind === "cat" ? { t: "■ ", fg: it.id === UNCATEGORIZED ? C.warn : categoryColor(s, it.id), bg } : { t: "  ", bg };
      rows.push(fit([{ t: " ", bg }, dot, { t: text, fg, bold: i === o.sel, bg }], innerW, bg));
    });
    const n = selection(s).length;
    return { title: ` move ${n} ${n === 1 ? "entry" : "entries"} to `, color: C.info, width: maxW, rows };
  }
  if (o.kind === "confirm") {
    const color = levelColor(o.level);
    const rows = o.lines.flatMap((t) => wrap(t, innerW - 2)).map((t) => line(t, t.startsWith("  ") || t === "" ? C.grey : C.text, false));
    rows.push(line(""));
    rows.push(
      fit(
        [
          { t: " ", bg: C.bar },
          ...(o.purpose === "quit"
            ? [
                { t: "y", fg: C.error, bold: true, bg: C.bar },
                { t: " discard and quit   ", fg: C.grey, bg: C.bar },
                { t: "w", fg: C.ok, bold: true, bg: C.bar },
                { t: " save first   ", fg: C.grey, bg: C.bar },
                { t: "n", fg: C.key, bold: true, bg: C.bar },
                { t: " stay", fg: C.grey, bg: C.bar },
              ]
            : [
                { t: "y", fg: color, bold: true, bg: C.bar },
                { t: " yes   ", fg: C.grey, bg: C.bar },
                { t: "n", fg: C.key, bold: true, bg: C.bar },
                { t: " no", fg: C.grey, bg: C.bar },
              ]),
        ],
        innerW,
        C.bar,
      ),
    );
    const title = {
      delete: " delete category ",
      quit: " unsaved changes ",
      save: " save ",
      apply: " apply keep_headers import ",
      import: " import ",
    }[o.purpose];
    return { title, color, width: maxW, rows };
  }
  if (o.kind === "result") {
    const color = levelColor(o.level);
    const rows = o.lines.flatMap((t) => wrap(t, innerW - 2)).map((t) => line(t, t.startsWith("  ") ? C.grey : C.text));
    rows.push(line(""));
    rows.push(line("press any key", C.dim));
    return { title: o.level === "ok" ? " saved " : o.level === "error" ? " failed " : " done ", color, width: maxW, rows };
  }
  return null;
}

// ---- missing-template screen ----------------------------------------------

export function missingRows(s: State, h: number, w: number): Row[] {
  const i = s.info;
  const lines: Row[] = [
    [{ t: " There is no keymap template yet.", fg: C.warn, bold: true }],
    [{ t: "" }],
    [{ t: ` expected at ${i.template}`, fg: C.grey }],
  ];
  if (s.sourceExists) {
    lines.push([{ t: ` ${i.target} exists and can be imported.`, fg: C.text }]);
    lines.push([{ t: " The file is only read. The template is a new file next to it." }]);
    lines.push([{ t: "" }]);
    lines.push([
      { t: " y", fg: C.ok, bold: true },
      { t: "  import it, every entry starts as Uncategorized", fg: C.text },
    ]);
    lines.push([
      { t: " h", fg: C.ok, bold: true },
      { t: "  import it, keep its box headers as categories", fg: C.text },
    ]);
  } else {
    lines.push([{ t: ` ${i.target} does not exist either, so there is nothing to import.`, fg: C.error }]);
  }
  const rows = lines.map((r) =>
    fit(
      r.map((g) => ({ ...g, bg: C.page })),
      w,
      C.page,
    ),
  );
  const out: Row[] = [topBar(s, w)];
  out.push(...rows);
  while (out.length < h - 2) out.push(blank(w, C.page));
  out.push(messageRow(s, w));
  return out.slice(0, h - 1);
}
