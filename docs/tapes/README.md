# README media

Regenerate every image and GIF in `docs/media/` with `bash docs/tapes/capture.sh` (or name
shots: `bash docs/tapes/capture.sh custom hint`). Needs `vhs` (with `ttyd`, `ffmpeg`,
chromium) and Neovim >= 0.11; no display is needed. Each shot runs against the throwaway
demo configs in `docs/tapes/demo/` under `/tmp/kmh-demo`, never your own config.
`FEATURES.md` lists every feature and which shot shows it.
