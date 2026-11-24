// Rendered frames through OpenTUI's test renderer, at the two sizes the UI is
// designed for. Checks that nothing overflows, the legend fits and the main
// screens look the way they should; snapshots pin the text.
import { afterEach, describe, expect, test } from "bun:test";
import type { KeyInput } from "@opentui/core/testing";
import { testRender } from "@opentui/react/test-utils";
import { act } from "react";
import type { Bridge } from "../src/bridge.ts";
import type { Loaded, SavePlan, SaveResult } from "../src/types.ts";
import { App } from "../src/ui.tsx";
import { doc, loaded, map, raw } from "./helpers.ts";

const entries = () => [
  map("a", "<leader>ff", "uncategorized", { opts: { desc: "find files", silent: true } }),
  map("b", "<leader>fg", "uncategorized", { modes: ["n", "v"], opts: { desc: "live grep" } }),
  raw("r", "local map = vim.keymap.set"),
  map("c", "gd", "lsp", {
    rhs: undefined,
    lua: "function()\n  vim.lsp.buf.definition()\nend",
    opts: { desc: "go to definition" },
    _badges: ["dup"],
  }),
  map("d", "<leader>x", "keys"),
  ...Array.from({ length: 40 }, (_, i) => map(`z${i}`, `<leader>z${i}`, "uncategorized")),
];
const fixture = (): Loaded => {
  const base = loaded(doc(entries(), ["lsp", "keys"]));
  base.calls.c = 'map("n", "gd", function()\n  vim.lsp.buf.definition()\nend, { desc = "go to definition" })';
  return base;
};

function fakeBridge(log: SavePlan[] = []): Bridge {
  return {
    show: async () => fixture(),
    preview: async () => ({ ...fixture(), status: "preview" }),
    save: async (plan) => {
      log.push(plan);
      const r: SaveResult = {
        template: "/r/lua/mappings.template.json",
        templateBackup: "/r/lua/mappings.template_2026_11_24_09:00:00.bak",
        target: "/r/lua/mappings.lua",
        targetStatus: "written",
        targetBackup: "/r/lua/mappings_2026_11_24_09:00:00.bak",
      };
      return r;
    },
    importTemplate: async () => "imported",
  };
}

let open: { renderer: { destroy(): void } } | null = null;
afterEach(() => open?.renderer.destroy());

async function mount(w: number, h: number, bridge = fakeBridge()) {
  const setup = await testRender(<App initial={fixture()} bridge={bridge} onQuit={() => {}} />, { width: w, height: h });
  open = setup;
  await setup.renderOnce();
  const frame = async () => {
    await act(async () => {
      await setup.renderOnce();
    });
    return setup.captureCharFrame().replace(/\n$/, "");
  };
  const press = async (...keys: string[]) => {
    for (const k of keys) {
      await act(async () => {
        const named: Record<string, KeyInput> = {
          return: "RETURN",
          escape: "ESCAPE",
          down: "ARROW_DOWN",
          up: "ARROW_UP",
          space: " ",
          backspace: "BACKSPACE",
        };
        if (k.startsWith("C-")) setup.mockInput.pressKey(k.slice(2), { ctrl: true });
        else setup.mockInput.pressKey(named[k] ?? k);
      });
      await act(async () => {
        await setup.renderOnce();
      });
    }
  };
  return { setup, frame, press };
}

const sizes: [number, number][] = [
  [80, 24],
  [140, 40],
];

describe.each(sizes)("frame at %ix%i", (w, h) => {
  test("fills the screen without overflow and shows all three panes and the legend", async () => {
    const { frame } = await mount(w, h);
    const text = await frame();
    const lines = text.split("\n");
    expect(lines.length).toBeLessThanOrEqual(h);
    for (const l of lines) expect(Bun.stringWidth(l)).toBeLessThanOrEqual(w);
    expect(text).toContain("Categories");
    expect(text).toContain("Details");
    expect(text).toContain("Uncategorized");
    expect(text).toContain("<leader>ff");
    // every key of the legend is on screen
    for (const k of [
      "move",
      "mark",
      "range",
      "move to...",
      "new category",
      "rename",
      "delete category",
      "reorder entry",
      "reorder category",
      "undo, redo",
      "keep_headers",
      "save",
      "quit",
      "search",
    ]) {
      expect(text).toContain(k);
    }
    // the legend is the last block and ends on the last row
    expect(lines.at(-1)?.trim()).not.toBe("");
    expect(text).toMatchSnapshot();
  });

  test("the move picker, the save summary and the result fit and close", async () => {
    const { frame, press } = await mount(w, h);
    await press("l", "m");
    let text = await frame();
    expect(text).toContain("move 1 entry to");
    expect(text).toContain("+ new category...");
    for (const l of text.split("\n")) expect(Bun.stringWidth(l)).toBeLessThanOrEqual(w);
    await press("return", "w");
    text = await frame();
    expect(text).toContain("moved 1 entry");
    expect(text).toContain("hand-written");
    expect(text).toMatchSnapshot();
    await press("y");
    await act(async () => {
      await Bun.sleep(30);
    });
    text = await frame();
    expect(text).toContain("mappings_2026_11_24_09:00:00.bak");
    expect(text).toContain("mappings.template_2026_11_24_09:00:00.bak");
    for (const l of text.split("\n")) expect(Bun.stringWidth(l)).toBeLessThanOrEqual(w);
  });
});

describe("rendered behaviour", () => {
  test("Uncategorized is marked as needing attention while it holds entries", async () => {
    const { frame } = await mount(100, 30);
    expect(await frame()).toMatch(/! Uncategorized\s+\d+/);
  });

  test("marking, moving and counting in the category pane", async () => {
    const { frame, press } = await mount(100, 30);
    await press("l", "space", "space", "m", "down", "return");
    const text = await frame();
    expect(text).toContain("moved 2 entries to");
    expect(text).toMatch(/Keys\s+3/);
    expect(text).toContain("2 changes");
  });

  test("details show the exact Lua line and the badge slot", async () => {
    const { frame, press } = await mount(140, 40);
    await press("j", "l");
    const text = await frame();
    expect(text).toContain("vim.lsp.buf.definition()");
    expect(text).toContain("generated Lua");
    expect(text).toContain("dup");
  });

  test("raw entries are shown as raw and move without being editable", async () => {
    const { frame, press } = await mount(100, 30);
    await press("l", "j", "j");
    const text = await frame();
    expect(text).toContain("raw Lua");
    expect(text).toContain("it can be moved, not edited");
  });

  test("a click picks a row and the wheel scrolls", async () => {
    const { frame, setup } = await mount(100, 30);
    await act(async () => {
      await setup.mockMouse.click(30, 4); // third row of the middle pane
    });
    let text = await frame();
    expect(text).toContain("3/43");
    await act(async () => {
      await setup.mockMouse.scroll(30, 6, "down");
    });
    text = await frame();
    expect(text).toContain("4/43");
    await act(async () => {
      await setup.mockMouse.click(3, 3); // Lsp in the category pane
    });
    text = await frame();
    expect(text).toContain("Lsp");
    expect(text).toContain("1/1");
  });

  test("a terminal that is too small says so", async () => {
    const { frame } = await mount(40, 10);
    expect(await frame()).toContain("terminal too small");
  });

  test("q with unsaved changes asks before leaving", async () => {
    const { frame, press } = await mount(100, 30);
    await press("l", "m", "return", "q");
    const text = await frame();
    expect(text).toContain("unsaved change");
    expect(text).toContain("discard and quit");
  });

  test("the save sends the plan to the bridge", async () => {
    const log: SavePlan[] = [];
    const { press } = await mount(100, 30, fakeBridge(log));
    await press("l", "m", "return", "w", "y");
    await act(async () => {
      await Bun.sleep(30);
    });
    expect(log).toHaveLength(1);
    expect(log[0]?.order.find((o) => o.id === "a")?.category).toBe("lsp");
  });
});
