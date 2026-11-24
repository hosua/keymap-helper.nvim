// Command line of tui/src/index.tsx, as a pure function so it can be tested.
export interface Args {
  root?: string;
  template?: string;
  target?: string;
}

export type Parsed = { kind: "run"; args: Args } | { kind: "help" } | { kind: "error"; message: string };

const FLAGS = new Map<string, keyof Args>([
  ["--root", "root"],
  ["--template", "template"],
  ["--target", "target"],
]);

export function parseArgs(argv: string[]): Parsed {
  const args: Args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i] as string;
    if (a === "-h" || a === "--help") return { kind: "help" };
    const eq = a.indexOf("=");
    const name = eq > 0 ? a.slice(0, eq) : a;
    const key = FLAGS.get(name);
    if (!key) return { kind: "error", message: `unknown option ${a}` };
    const value = eq > 0 ? a.slice(eq + 1) : argv[++i];
    if (!value) return { kind: "error", message: `${name} needs a value` };
    args[key] = value;
  }
  return { kind: "run", args };
}

export function help(color: boolean): string {
  const b = (t: string) => (color ? `\x1b[1m${t}\x1b[0m` : t);
  return `${[
    b("USAGE"),
    "  $ keymap-helper-tui [--root=DIR] [--template=FILE] [--target=FILE]",
    "  $ bun run tui/src/index.tsx --root DIR",
    "",
    "sort the keymaps of a keymap-helper template into categories",
    "",
    b("OPTIONS"),
    "  --root=DIR        config root, relative paths resolve against it (default: stdpath config)",
    "  --template=FILE   template path (default: lua/mappings.template.json)",
    "  --target=FILE     mappings file (default: the template's target)",
    "  -h, --help        show this help",
    "",
    b("EXAMPLES"),
    "  $ keymap-helper-tui --root=$HOME/.config/nvim",
    "  $ keymap-helper-tui --root=/tmp/try --template=lua/maps.json",
  ].join("\n")}\n`;
}
