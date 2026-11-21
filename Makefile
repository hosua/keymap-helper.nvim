.PHONY: test integration smoke fmt check

# Every target runs against a throwaway XDG tree: no user config or plugins on
# the runtimepath (so CI and local runs see the same thing), and a bug can
# never touch real user data.
XDG_TMP = tmp=$$(mktemp -d) && \
  XDG_CONFIG_HOME=$$tmp/config XDG_DATA_HOME=$$tmp/data XDG_STATE_HOME=$$tmp/state XDG_CACHE_HOME=$$tmp/cache

test:
	@$(XDG_TMP) nvim --headless -u NONE -l tests/run.lua spec; rc=$$?; rm -rf $$tmp; exit $$rc

integration:
	@$(XDG_TMP) nvim --headless -u NONE -l tests/run.lua integration; rc=$$?; rm -rf $$tmp; exit $$rc

smoke:
	@for t in tests/smoke/*_smoke.sh; do [ -e "$$t" ] || continue; echo "== $$t"; bash "$$t" || exit 1; done

fmt:
	stylua .

check:
	stylua --check .
