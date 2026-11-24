// The rows of the options screen. A row is a title plus the values left and
// right cycle through; adding an option means adding one entry here and one
// field to Settings.
export interface Settings {
  /** Draw with 24-bit colour; false snaps every colour to the xterm-256 palette. */
  truecolor: boolean;
}

export interface OptionRow {
  id: keyof Settings;
  title: string;
  values: readonly string[];
  get(s: Settings): string;
  set(s: Settings, value: string): Settings;
}

export const OPTIONS: readonly OptionRow[] = [
  {
    id: "truecolor",
    title: "Truecolor",
    values: ["True", "False"],
    get: (s) => (s.truecolor ? "True" : "False"),
    set: (s, v) => ({ ...s, truecolor: v === "True" }),
  },
];

/** Next or previous value of a row, wrapping around at both ends. */
export function cycle(s: Settings, row: OptionRow, dir: 1 | -1): Settings {
  const i = Math.max(0, row.values.indexOf(row.get(s)));
  const next = row.values[(i + dir + row.values.length) % row.values.length] as string;
  return row.set(s, next);
}
