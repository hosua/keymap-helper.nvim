// Shapes shared by the model, the bridge and the views. They mirror what
// scripts/kh-template prints; the Lua side (lua/keymap-helper/template/) owns
// the schema, so nothing here validates beyond what the screens need.

export interface Category {
  id: string;
  title: string;
  subtitle?: string;
  /** Made in this session; the Lua side gives it a real id on save. */
  isNew?: boolean;
}

export interface Entry {
  id: string;
  kind: "map" | "raw";
  category: string;
  modes?: string[];
  lhs?: string;
  rhs?: string;
  lua?: string;
  // Lua encodes an empty table as [], so an empty options object arrives as one.
  opts?: Record<string, unknown> | unknown[];
  opts_raw?: Record<string, unknown> | unknown[];
  comment?: string;
  trailing?: string;
  call?: string;
  text?: string;
  /** Keys that start with "_" belong to other tools and are carried along. */
  [extra: string]: unknown;
}

export interface Doc {
  categories: Category[];
  entries: Entry[];
}

export interface Info {
  root: string;
  template: string;
  template_name: string;
  target: string;
  backups: boolean;
  target_exists: boolean;
  target_generated: boolean;
}

export interface Loaded extends Info {
  status: "ready" | "preview";
  doc: Doc;
  calls: Record<string, string>;
}

export interface Missing extends Info {
  status: "missing";
  source_exists: boolean;
}

export interface SavePlan {
  categories: { id: string; title: string; new?: boolean }[];
  order: { id: string; category: string }[];
  /** Map entries to drop from the template. They are not in `order`. */
  delete?: string[];
}

/** One definition of a key, as `kh-template analyze` reports it. */
export interface Def {
  /** `default:nvchad`, `template:<entry id>`, `template:raw`, `plugin:<name>`, `config:<file>` */
  source: string;
  desc?: string;
  summary?: string;
  /** Set on a removed definition: who deleted it. */
  by?: string;
}

export interface KeyDefs {
  mode: string;
  lhs: string;
  defs: Def[];
  removed: Def[];
}

/** What `kh-template analyze` prints, and what `:KeymapHelper edit` hands over. */
export interface Snapshot {
  status: "ok" | "partial";
  source: "replay" | "static";
  leader?: string;
  keys: KeyDefs[];
  error?: string;
  /** Errors the config printed while it loaded in the scratch nvim. */
  warnings?: string[];
  note?: string;
}

export interface SaveResult {
  template: string;
  templateBackup?: string;
  target: string;
  targetBackup?: string;
  targetStatus: "written" | "unchanged";
  /** Set when the template was saved but the mappings file was not generated. */
  generateError?: string;
}

export type Level = "info" | "ok" | "warn" | "error" | "dim";

export const UNCATEGORIZED = "uncategorized";
