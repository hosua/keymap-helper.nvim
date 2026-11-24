// The only place that touches the template: it runs the Lua scripts of the
// plugin (scripts/kh-template, kh-import, kh-generate) under `nvim -l` and
// reads their JSON. The TUI never opens a lua or template file itself, so the
// rules for reading, validating, backing up and generating exist once, in Lua.

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { Doc, Info, Loaded, Missing, SavePlan, SaveResult, Snapshot } from "./types.ts";

export interface Bridge {
  show(): Promise<Loaded | Missing>;
  preview(keepHeaders: boolean): Promise<Loaded>;
  /** Save the plan, then generate the mappings file; throws when the save fails. */
  save(plan: SavePlan): Promise<SaveResult>;
  /** Import the mappings file into the template (the caller already asked the user). */
  importTemplate(keepHeaders: boolean): Promise<string>;
  /** Who defines each key: starts the user's config in a scratch nvim (seconds, not milliseconds). */
  analyze(): Promise<Snapshot>;
}

export interface BridgeOptions {
  root?: string;
  template?: string;
  target?: string;
  /** Extra environment for the scripts, for tests. */
  env?: Record<string, string>;
  /** Plugin checkout holding scripts/; default: two levels above this file. */
  pluginRoot?: string;
  /** Seconds the analysis may take; the Lua side kills the scratch nvim after this. */
  timeout?: number;
}

/** Read a snapshot written by `:KeymapHelper edit`. */
export function readSnapshot(path: string): Snapshot {
  const snap = JSON.parse(readFileSync(path, "utf8")) as Snapshot;
  if (!Array.isArray(snap.keys)) throw new Error(`${path} is not an analysis snapshot`);
  return snap;
}

export const PLUGIN_ROOT = resolve(import.meta.dir, "../..");

interface Run {
  code: number;
  out: string;
  err: string;
}

async function run(script: string, args: string[], opts: BridgeOptions, stdin?: string): Promise<Run> {
  const path = resolve(opts.pluginRoot ?? PLUGIN_ROOT, "scripts", script);
  const proc = Bun.spawn([path, ...args], {
    stdin: stdin === undefined ? "ignore" : new TextEncoder().encode(stdin),
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1", ...opts.env },
  });
  const [out, err, code] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text(), proc.exited]);
  return { code, out, err };
}

function common(opts: BridgeOptions): string[] {
  const a: string[] = [];
  if (opts.root) a.push(`--root=${opts.root}`);
  if (opts.template) a.push(`--template=${opts.template}`);
  if (opts.target) a.push(`--target=${opts.target}`);
  return a;
}

function parse<T>(r: Run, what: string): T {
  if (r.code !== 0) throw new Error(r.err.trim() || `${what} failed (exit ${r.code})`);
  try {
    return JSON.parse(r.out) as T;
  } catch {
    throw new Error(`${what} printed something that is not JSON: ${r.out.slice(0, 200)}`);
  }
}

interface RawView extends Info {
  status: "ready" | "preview" | "missing";
  source_exists?: boolean;
  categories?: Doc["categories"];
  entries?: Doc["entries"];
  calls?: Loaded["calls"] | unknown[];
}

function toLoaded(v: RawView): Loaded | Missing {
  if (v.status === "missing") return { ...v, status: "missing", source_exists: v.source_exists === true };
  const calls = Array.isArray(v.calls) ? {} : (v.calls ?? {});
  const { categories, entries, ...info } = v;
  return { ...info, status: v.status, doc: { categories: categories ?? [], entries: entries ?? [] }, calls };
}

export function createBridge(opts: BridgeOptions = {}): Bridge {
  return {
    async show() {
      return toLoaded(parse<RawView>(await run("kh-template", ["show", ...common(opts)], opts), "kh-template show"));
    },
    async preview(keepHeaders) {
      const args = ["preview", ...common(opts), ...(keepHeaders ? [] : ["--drop-headers"])];
      return toLoaded(parse<RawView>(await run("kh-template", args, opts), "kh-template preview")) as Loaded;
    },
    async save(plan) {
      const saved = parse<{ template: string; backup?: string }>(
        await run("kh-template", ["save", ...common(opts)], opts, JSON.stringify(plan)),
        "kh-template save",
      );
      const result: SaveResult = { template: saved.template, templateBackup: saved.backup, target: "", targetStatus: "unchanged" };
      const gen = await run("kh-generate", ["--json", "--yes", ...common(opts)], opts);
      try {
        const g = parse<{ status: "written" | "unchanged"; target: string; backup?: string }>(gen, "kh-generate");
        return { ...result, target: g.target, targetStatus: g.status, targetBackup: g.backup };
      } catch (e) {
        return { ...result, target: opts.target ?? "", generateError: e instanceof Error ? e.message : String(e) };
      }
    },
    async analyze() {
      const args = ["analyze", ...common(opts), ...(opts.timeout ? [`--timeout=${opts.timeout}`] : [])];
      return parse<Snapshot>(await run("kh-template", args, opts), "kh-template analyze");
    },
    async importTemplate(keepHeaders) {
      const args = ["--json", "--yes", ...common(opts), ...(keepHeaders ? [] : ["--drop-headers"])];
      const r = parse<{ status: string; maps: number; raw: number }>(await run("kh-import", args, opts), "kh-import");
      return r.status === "in_sync"
        ? "the template already generates the file, nothing to import"
        : `imported ${r.maps} maps and ${r.raw} raw blocks`;
    },
  };
}
