// The key legend: [key, description] pairs, laid out in aligned columns.
export type LegendItem = readonly [key: string, desc: string];

export const NORMAL: LegendItem[] = [
  ["j k", "move"],
  ["h l", "pane"],
  ["gg G", "first, last"],
  ["^d ^u", "half page"],
  ["/ n N", "search"],
  ["space", "mark, next"],
  ["v", "mark"],
  ["V", "range"],
  ["A", "mark all"],
  ["esc", "clear marks"],
  ["m", "move to..."],
  ["c", "new category"],
  ["r", "rename"],
  ["d", "delete category"],
  ["J K", "reorder entry"],
  ["< >", "reorder category"],
  ["C", "category color"],
  ["u ^r", "undo, redo"],
  ["i", "keep_headers"],
  ["w", "save"],
  ["q", "quit"],
];

export const PREVIEW: LegendItem[] = [
  ["j k", "move"],
  ["h l", "pane"],
  ["gg G", "first, last"],
  ["/ n N", "search"],
  ["enter", "apply import"],
  ["i", "leave preview"],
  ["q", "quit"],
];

export const PICKER: LegendItem[] = [
  ["type", "filter"],
  ["^n ^p", "choose"],
  ["up down", "choose"],
  ["enter", "select"],
  ["esc", "cancel"],
];

export const INPUT: LegendItem[] = [
  ["type", "text"],
  ["enter", "accept"],
  ["esc", "cancel"],
];

export const YES_NO: LegendItem[] = [
  ["y", "yes"],
  ["n esc", "no"],
];

export const QUIT: LegendItem[] = [
  ["y", "discard and quit"],
  ["w", "save first"],
  ["n esc", "stay"],
];

export const ANY_KEY: LegendItem[] = [["any key", "close"]];

export const MISSING: LegendItem[] = [
  ["y", "import, all Uncategorized"],
  ["h", "import, keep headers"],
  ["q", "quit"],
];

export const MISSING_NO_SOURCE: LegendItem[] = [["q", "quit"]];

/** Width of one legend cell: padded key, a space, the longest description, two spaces of air. */
export function cellWidth(items: readonly LegendItem[]): number {
  const keyW = Math.max(...items.map(([k]) => k.length));
  return keyW + 1 + Math.max(...items.map(([, d]) => d.length)) + 2;
}

export interface LegendGrid {
  cols: number;
  rows: number;
  cell: number;
  /** rows[r][c] is the item shown there, or undefined for a blank cell. */
  cells: (LegendItem | undefined)[][];
  keyWidth: number;
}

/** Fill column by column so related keys stay together, like a vim :help list. */
export function grid(items: readonly LegendItem[], width: number, minRows = 0): LegendGrid {
  const cell = cellWidth(items);
  const cols = Math.max(1, Math.min(items.length, Math.floor(width / cell)));
  const rows = Math.max(Math.ceil(items.length / cols), minRows);
  const cells: (LegendItem | undefined)[][] = Array.from({ length: rows }, () => Array<LegendItem | undefined>(cols).fill(undefined));
  items.forEach((it, i) => {
    const r = i % rows;
    const c = Math.floor(i / rows);
    const row = cells[r];
    if (row && c < cols) row[c] = it;
  });
  return { cols, rows, cell, cells, keyWidth: Math.max(...items.map(([k]) => k.length)) };
}
