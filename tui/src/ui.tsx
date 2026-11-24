// Draws the state. Every row of text comes from rows.ts; this file only places
// rows inside OpenTUI boxes and turns key and mouse events into state events.
import { useKeyboard, useTerminalDimensions } from "@opentui/react";
import { useCallback, useEffect, useRef, useState } from "react";
import type { Bridge } from "./bridge.ts";
import { keyName } from "./keys.ts";
import { layout, MIN_H, MIN_W } from "./layout.ts";
import { C } from "./palette.ts";
import {
  categoryRows,
  detailRows,
  entryRows,
  legendRows,
  messageRow,
  missingRows,
  paneHeader,
  popup,
  type Row,
  scrollTop,
  topBar,
} from "./rows.ts";
import { categoryAt, docOf, type Effect, type Event, entriesIn, init, type State, update } from "./state.ts";
import type { Loaded, Missing, Snapshot } from "./types.ts";

function Line({ row }: { row: Row }) {
  return (
    <text height={1} wrapMode="none">
      {row.map((g, i) => {
        let node = (
          <span key={i} fg={g.fg ?? C.text} bg={g.bg}>
            {g.t}
          </span>
        );
        if (g.underline) node = <u key={i}>{node}</u>;
        if (g.italic) node = <i key={i}>{node}</i>;
        if (g.bold) node = <b key={i}>{node}</b>;
        return node;
      })}
    </text>
  );
}

function Rows({ rows, onClickRow }: { rows: Row[]; onClickRow?: (i: number) => void }) {
  return (
    <>
      {rows.map((r, i) => (
        <box key={i} height={1} flexShrink={0} onMouseDown={onClickRow ? () => onClickRow(i) : undefined}>
          <Line row={r} />
        </box>
      ))}
    </>
  );
}

/** Run one side effect and report its outcome back to the state as an event. */
async function runEffect(fx: Effect, bridge: Bridge, send: (ev: Event) => void, onQuit: () => void) {
  try {
    if (fx.type === "quit") onQuit();
    else if (fx.type === "analyze") {
      try {
        send({ type: "analyzed", snapshot: await bridge.analyze() });
      } catch (e) {
        send({ type: "analysis-failed", message: e instanceof Error ? e.message : String(e) });
      }
    } else if (fx.type === "preview") send({ type: "previewed", loaded: await bridge.preview(fx.keepHeaders) });
    else if (fx.type === "reload") send({ type: "loaded", loaded: (await bridge.show()) as Loaded });
    else if (fx.type === "import") {
      const text = await bridge.importTemplate(fx.keepHeaders);
      send({ type: "loaded", loaded: (await bridge.show()) as Loaded, note: { text, level: "ok" } });
    } else if (fx.type === "save") {
      const result = await bridge.save(fx.plan);
      send({ type: "saved", result, loaded: (await bridge.show()) as Loaded });
    }
  } catch (e) {
    send({ type: "failed", message: e instanceof Error ? e.message : String(e) });
  }
}

export interface AppProps {
  initial: Loaded | Missing;
  bridge: Bridge;
  onQuit: () => void;
  /** A ready analysis; without one the app asks the bridge for it. */
  snapshot?: Snapshot | null;
}

export function App({ initial, bridge, onQuit, snapshot }: AppProps) {
  const { width, height } = useTerminalDimensions();
  const [state, setState] = useState<State>(() => init(initial, { w: width, h: height }));
  const ref = useRef(state);

  const send = useCallback(
    (ev: Event) => {
      const [next, effects] = update(ref.current, ev);
      ref.current = next;
      setState(next);
      for (const fx of effects) void runEffect(fx, bridge, send, onQuit);
    },
    [bridge, onQuit],
  );

  useKeyboard((e) => {
    const key = keyName(e);
    if (key) send({ type: "key", key });
  });

  useEffect(() => {
    send({ type: "resize", size: { w: width, h: height } });
  }, [width, height, send]);

  useEffect(() => {
    send(snapshot ? { type: "analyzed", snapshot } : { type: "analysis-start" });
  }, [snapshot, send]);

  const analysing = state.analysis.status === "running";
  useEffect(() => {
    if (!analysing) return;
    const t = setInterval(() => send({ type: "tick" }), 120);
    return () => clearInterval(t);
  }, [analysing, send]);

  const size = { w: width, h: height };
  if (width < MIN_W || height < MIN_H) {
    return (
      <box width={width} height={height} backgroundColor={C.page}>
        <text fg={C.warn}>{`terminal too small: ${width}x${height}, need ${MIN_W}x${MIN_H}`}</text>
      </box>
    );
  }
  const l = layout(size);
  const pop = popup(state, size);
  const top = <Line row={topBar(state, width)} />;
  const bottom = (
    <>
      <Line row={messageRow(state, width)} />
      <Rows rows={legendRows(state, width, l.legendRows)} />
    </>
  );
  const popupBox = pop && (
    <box
      position="absolute"
      left={Math.floor((width - pop.width) / 2)}
      top={Math.max(1, Math.floor((height - pop.rows.length - 2) / 3))}
      width={pop.width}
      height={pop.rows.length + 2}
      border
      borderStyle="rounded"
      borderColor={pop.color}
      title={pop.title}
      titleColor={pop.color}
      backgroundColor={C.bar}
    >
      <Rows rows={pop.rows} />
    </box>
  );

  if (state.screen === "missing") {
    return (
      <box flexDirection="column" width={width} height={height} backgroundColor={C.page}>
        <Rows rows={missingRows(state, height, width)} />
        <Rows rows={legendRows(state, width, l.legendRows)} />
      </box>
    );
  }

  const doc = docOf(state);
  const list = entriesIn(state);
  const cat = categoryAt(state);
  const catTop = scrollTop(state.ui.catIdx, doc.categories.length, l.listRows);
  const entTop = scrollTop(state.ui.entIdx, list.length, l.listRows);
  const wheel = (e: { scroll?: { direction?: string } }) => send({ type: "scroll", delta: e.scroll?.direction === "up" ? -1 : 1 });
  return (
    <box flexDirection="column" width={width} height={height} backgroundColor={C.page}>
      {top}
      <box flexDirection="row" height={l.paneH} flexShrink={0}>
        <box flexDirection="column" width={l.leftW} height={l.paneH} flexShrink={0} backgroundColor={C.left} onMouseScroll={wheel}>
          <Line row={paneHeader("Categories", String(doc.categories.length), l.leftW, state.ui.focus === "cats", C.left)} />
          <Rows rows={categoryRows(state, l)} onClickRow={(i) => send({ type: "select", pane: "cats", index: catTop + i })} />
        </box>
        <box flexDirection="column" width={l.midW} height={l.paneH} flexShrink={0} backgroundColor={C.mid} onMouseScroll={wheel}>
          <Line
            row={paneHeader(
              cat?.title ?? "",
              `${list.length ? state.ui.entIdx + 1 : 0}/${list.length}`,
              l.midW,
              state.ui.focus === "entries",
              C.mid,
            )}
          />
          <Rows rows={entryRows(state, l)} onClickRow={(i) => send({ type: "select", pane: "entries", index: entTop + i })} />
        </box>
        <box flexDirection="column" width={l.rightW} height={l.paneH} flexShrink={0} backgroundColor={C.right}>
          <Line row={paneHeader("Details", "", l.rightW, false, C.right)} />
          <Rows rows={detailRows(state, l)} />
        </box>
      </box>
      {bottom}
      {popupBox}
    </box>
  );
}
