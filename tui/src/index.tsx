// Entry point: bun run tui/src/index.tsx --root DIR [--template FILE]
import { createCliRenderer } from "@opentui/core";
import { createRoot } from "@opentui/react";
import { help, parseArgs } from "./args.ts";
import { createBridge } from "./bridge.ts";
import { App } from "./ui.tsx";

async function main(argv: string[]): Promise<number> {
  const parsed = parseArgs(argv);
  if (parsed.kind === "help") {
    process.stdout.write(help(process.stdout.isTTY === true && !process.env.NO_COLOR));
    return 0;
  }
  if (parsed.kind === "error") {
    process.stderr.write(`keymap-helper-tui: ${parsed.message}\ntry \`keymap-helper-tui --help\`\n`);
    return 2;
  }
  if (!process.stdout.isTTY) {
    process.stderr.write("keymap-helper-tui: needs a terminal\n");
    return 2;
  }
  const bridge = createBridge(parsed.args);
  let initial: Awaited<ReturnType<typeof bridge.show>>;
  try {
    initial = await bridge.show();
  } catch (e) {
    process.stderr.write(`keymap-helper-tui: ${e instanceof Error ? e.message : String(e)}\n`);
    return 1;
  }
  const renderer = await createCliRenderer({ exitOnCtrlC: false, useMouse: true });
  const done = new Promise<void>((resolve) => {
    renderer.once("destroy", () => resolve());
  });
  createRoot(renderer).render(<App initial={initial} bridge={bridge} onQuit={() => renderer.destroy()} />);
  await done;
  return 0;
}

process.exit(await main(process.argv.slice(2)));
