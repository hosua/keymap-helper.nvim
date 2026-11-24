// Colors. Everything sits on a dark page and reads on any theme-neutral
// terminal; yellow is reserved for "needs attention" so a category never
// borrows it.
export const C = {
  page: "#0F172A",
  left: "#111A2E",
  mid: "#0F172A",
  right: "#0B1220",
  bar: "#1E293B",
  text: "#F1F5F9",
  grey: "#94A3B8",
  dim: "#64748B",
  cursorFocus: "#1E3A5F",
  cursorBlur: "#1E293B",
  range: "#162B4A",
  error: "#F87171",
  warn: "#FBBF24",
  ok: "#4ADE80",
  info: "#60A5FA",
  key: "#E2E8F0",
  match: "#22D3EE",
  danger: "#F87171",
} as const;

/** One slot per category; the same slot is the same color everywhere. */
export const CATEGORY_COLORS = [
  "#60A5FA",
  "#2DD4BF",
  "#4ADE80",
  "#A3E635",
  "#FB923C",
  "#F472B6",
  "#A78BFA",
  "#22D3EE",
  "#FB7185",
  "#38BDF8",
  "#818CF8",
  "#E879F9",
] as const;

const MODE_COLORS: Record<string, string> = {
  n: "#60A5FA",
  i: "#4ADE80",
  v: "#C084FC",
  x: "#C084FC",
  s: "#C084FC",
  o: "#FB923C",
  t: "#2DD4BF",
  c: "#F472B6",
  l: "#FBBF24",
};

export const modeColor = (m: string): string => MODE_COLORS[m] ?? C.grey;

export const levelColor = (l: "info" | "ok" | "warn" | "error" | "dim"): string =>
  l === "ok" ? C.ok : l === "warn" ? C.warn : l === "error" ? C.error : l === "dim" ? C.dim : C.info;
