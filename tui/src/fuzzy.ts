// Small subsequence matcher for the category picker. Higher is better, null
// means no match. Consecutive letters and word starts score more.
export function score(query: string, text: string): number | null {
  const q = query.toLowerCase();
  const t = text.toLowerCase();
  if (q === "") return 0;
  let ti = 0;
  let s = 0;
  let prev = -2;
  for (const ch of q) {
    const at = t.indexOf(ch, ti);
    if (at < 0) return null;
    s += 1;
    if (at === prev + 1) s += 3;
    if (at === 0 || /[^a-z0-9]/.test(t[at - 1] ?? "")) s += 2;
    prev = at;
    ti = at + 1;
  }
  return s - t.length * 0.01;
}

export function rank<T>(query: string, items: T[], text: (item: T) => string): T[] {
  return items
    .map((item, i) => ({ item, i, s: score(query, text(item)) }))
    .filter((x): x is { item: T; i: number; s: number } => x.s !== null)
    .sort((a, b) => b.s - a.s || a.i - b.i)
    .map((x) => x.item);
}
