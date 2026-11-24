import { describe, expect, test } from "bun:test";
import { toPlan } from "../src/plan.ts";
import { conflictsFor, docOf, entriesIn, entryAt, summaryOf, update } from "../src/state.ts";
import { conflictDoc, doc, ids, loaded, map, press, snapshot, start } from "./helpers.ts";

/** A started state whose analysis has finished. */
function analysed(snap = snapshot()) {
  const [s] = update(start(conflictDoc()), { type: "analyzed", snapshot: snap });
  return s;
}

describe("analysis lifecycle", () => {
  test("analysis-start asks for the analysis once and tick spins it", () => {
    const [s, fx] = update(start(conflictDoc()), { type: "analysis-start" });
    expect(fx).toEqual([{ type: "analyze" }]);
    expect(s.analysis).toEqual({ status: "running", frame: 0 });
    expect(update(s, { type: "analysis-start" })[1]).toEqual([]);
    const [t] = update(s, { type: "tick" });
    expect(t.analysis).toEqual({ status: "running", frame: 1 });
  });

  test("a failure keeps the local duplicates and says so", () => {
    const [s0] = update(start(conflictDoc()), { type: "analysis-start" });
    const [s] = update(s0, { type: "analysis-failed", message: "boom\nmore" });
    expect(s.analysis.status).toBe("failed");
    expect(s.ui.message?.text).toBe("analysis failed: boom");
    expect(s.ui.message?.level).toBe("dim");
    expect(conflictsFor(s).duplicates).toBe(1);
  });

  test("a partial snapshot warns", () => {
    const s = analysed(snapshot({ status: "partial", error: "the generated file stopped" }));
    expect(s.ui.message?.level).toBe("warn");
    expect(s.ui.message?.text).toContain("analysis incomplete");
  });

  test("a reload keeps the snapshot and does not analyse again", () => {
    const s = analysed();
    const [t, fx] = update(s, { type: "loaded", loaded: loaded(conflictDoc()) });
    expect(t.analysis.status).toBe("done");
    expect(fx).toEqual([]);
  });
});

describe("filter and jumping", () => {
  test("! shows only conflicted entries and ! again shows all", () => {
    let { s } = press(analysed(), "j", "l");
    expect(entriesIn(s).map((e) => e.id)).toEqual(["h1", "x1", "q1"]);
    ({ s } = press(s, "!"));
    expect(entriesIn(s).map((e) => e.id)).toEqual(["h1", "x1"]);
    ({ s } = press(s, "!"));
    expect(entriesIn(s)).toHaveLength(3);
  });

  test("]c and [c walk the conflicts across categories and wrap", () => {
    let { s } = press(analysed(), "]", "c");
    expect(entryAt(s)?.id).toBe("h1");
    ({ s } = press(s, "]", "c"));
    expect(entryAt(s)?.id).toBe("x1");
    ({ s } = press(s, "]", "c"));
    expect(entryAt(s)?.id).toBe("x2");
    expect(docOf(s).categories[s.ui.catIdx]?.id).toBe("git");
    ({ s } = press(s, "]", "c"));
    expect(entryAt(s)?.id).toBe("h1");
    ({ s } = press(s, "[", "c"));
    expect(entryAt(s)?.id).toBe("x2");
  });

  test("with no conflicts the jump says why", () => {
    const { s } = press(start(doc([map("a", "a")])), "]", "c");
    expect(s.ui.message?.text).toContain("still analysing");
  });
});

describe("duplicate actions", () => {
  test("o jumps to the other entry of the group", () => {
    let { s } = press(analysed(), "j", "l", "j", "o");
    expect(entryAt(s)?.id).toBe("x2");
    ({ s } = press(s, "o"));
    expect(entryAt(s)?.id).toBe("x1");
  });

  test("x on the shadowed entry asks, deletes on yes, and never touches the winner", () => {
    let { s } = press(analysed(), "j", "l", "j");
    ({ s } = press(s, "x"));
    expect(s.ui.overlay?.kind).toBe("confirm");
    expect(docOf(s).entries.some((e) => e.id === "x1")).toBe(true);
    ({ s } = press(s, "y"));
    expect(docOf(s).entries.map((e) => e.id)).toEqual(["h1", "q1", "x2", "z1"]);
    expect(conflictsFor(s).duplicates).toBe(0);
    expect(summaryOf(s).entriesDeleted).toEqual(["n <leader>x"]);
    expect(toPlan(s.h.present, s.base).delete).toEqual(["x1"]);
    expect(toPlan(s.h.present, s.base).order.map((o) => o.id)).not.toContain("x1");
  });

  test("x on the winner refuses and says what to do", () => {
    let { s } = press(analysed(), "]", "c", "]", "c", "]", "c");
    expect(entryAt(s)?.id).toBe("x2");
    ({ s } = press(s, "x"));
    expect(s.ui.overlay).toBeNull();
    expect(s.ui.message?.text).toContain("deletes the shadowed entry");
  });

  test("n at the confirm keeps everything, u undoes a delete", () => {
    let { s } = press(analysed(), "j", "l", "j", "x", "n");
    expect(docOf(s).entries).toHaveLength(5);
    ({ s } = press(s, "x", "y"));
    expect(docOf(s).entries).toHaveLength(4);
    ({ s } = press(s, "u"));
    expect(docOf(s).entries).toHaveLength(5);
  });

  test("P on the shadowed entry makes it win, and the warning follows at once", () => {
    let { s } = press(analysed(), "j", "l", "j", "P");
    expect(conflictsFor(s).byEntry.get("x1")?.dups[0]?.winner).toBe("x1");
    expect(docOf(s).entries.find((e) => e.id === "x1")?.category).toBe("git");
    expect(s.ui.message?.text).toContain("it moved to Git");
    ({ s } = press(s, "P"));
    expect(conflictsFor(s).byEntry.get("x2")?.dups[0]?.winner).toBe("x2");
    expect(ids(s, "git")).toEqual(["x1", "x2", "z1"]);
  });

  test("the preview is read-only for x and P", () => {
    const s = analysed();
    const withPreview = { ...s, preview: { doc: s.h.present, calls: {} } };
    const { s: t } = press(withPreview, "j", "l", "j", "x");
    expect(t.ui.overlay).toBeNull();
    expect(t.ui.message?.text).toContain("read-only");
  });
});

describe("removed defaults", () => {
  test("D lists them in a dim popup; with none it says so", () => {
    let { s } = press(analysed(), "D");
    expect(s.ui.overlay).toMatchObject({ kind: "result", level: "dim" });
    expect((s.ui.overlay as { lines: string[] }).lines.join("\n")).toContain("terminal vertical");
    ({ s } = press(analysed(snapshot({ keys: [] })), "D"));
    expect(s.ui.overlay).toBeNull();
    expect(s.ui.message?.text).toContain("removes no defaults");
  });
});

describe("startup warnings", () => {
  test("an error the config printed shows as a dim incomplete note", () => {
    const s = analysed(snapshot({ warnings: ["E5113: Error while calling lua chunk: boom"] }));
    expect(s.ui.message?.text).toBe("analysis incomplete: E5113: Error while calling lua chunk: boom");
    expect(s.ui.message?.level).toBe("dim");
  });
});
