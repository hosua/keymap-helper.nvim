// In-memory undo/redo over whole documents. Documents share their unchanged
// entries, so a snapshot costs one array per edit.
import type { Doc } from "./types.ts";

export interface History {
  past: Doc[];
  present: Doc;
  future: Doc[];
}

const LIMIT = 200;

export const start = (doc: Doc): History => ({ past: [], present: doc, future: [] });

export function commit(h: History, doc: Doc): History {
  if (doc === h.present) return h;
  return { past: [...h.past, h.present].slice(-LIMIT), present: doc, future: [] };
}

export function undo(h: History): History {
  const prev = h.past[h.past.length - 1];
  if (!prev) return h;
  return { past: h.past.slice(0, -1), present: prev, future: [h.present, ...h.future] };
}

export function redo(h: History): History {
  const next = h.future[0];
  if (!next) return h;
  return { past: [...h.past, h.present], present: next, future: h.future.slice(1) };
}
