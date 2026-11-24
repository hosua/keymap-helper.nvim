.PHONY: test integration smoke fmt check tui-test

# Every target runs against a throwaway XDG tree: no user config or plugins on
# the runtimepath (so CI and local runs see the same thing), and a bug can
# never touch real user data.
XDG_TMP = tmp=$$(mktemp -d) && \
  XDG_CONFIG_HOME=$$tmp/config XDG_DATA_HOME=$$tmp/data XDG_STATE_HOME=$$tmp/state XDG_CACHE_HOME=$$tmp/cache

test:
	@$(XDG_TMP) nvim --headless -u NONE -l tests/run.lua spec; rc=$$?; rm -rf $$tmp; exit $$rc
	@$(MAKE) --no-print-directory tui-test

# The terminal UI (tui/): bun test, TypeScript and biome. It is part of `make test`, so
# gates.sh runs it. Without bun it prints why it skipped and passes.
tui-test:
	@if ! command -v bun >/dev/null 2>&1; then echo "tui-test: bun is not installed, skipping the terminal UI tests (https://bun.sh)"; exit 0; fi; \
	cd tui && bun install --frozen-lockfile >/dev/null && bun test && bunx tsc --noEmit && bunx biome check . && echo "tui-test: ok"

integration:
	@$(XDG_TMP) nvim --headless -u NONE -l tests/run.lua integration; rc=$$?; rm -rf $$tmp; exit $$rc

smoke:
	@for t in tests/smoke/*_smoke.sh; do [ -e "$$t" ] || continue; echo "== $$t"; bash "$$t" || exit 1; done

fmt:
	stylua .

check:
	stylua --check .
