#!/bin/sh
# Runtime smoke test for the generated bundle (version-1.luau).
#
# Assembles: stubs + bundle (wrapped in a function to keep `local` scoping) +
# assertions, writes it to a temp file, and runs it under the Luau CLI from
# PATH if available, else /tmp/luau.
#
# The wrapper-function trick keeps the bundle's line offsets intact, so the
# bundle's own error-line mapping still works if something fails inside.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$ROOT/version-1.luau"

if [ ! -f "$BUNDLE" ]; then
	echo "bundle missing: $BUNDLE" >&2
	exit 1
fi

LUAU_BIN="$(command -v luau || true)"
if [ -z "$LUAU_BIN" ]; then
	for candidate in /tmp/luau /usr/local/bin/luau; do
		if [ -x "$candidate" ]; then
			LUAU_BIN="$candidate"
			break
		fi
	done
fi
if [ -z "$LUAU_BIN" ]; then
	echo "luau CLI not found (looked in PATH, /tmp, /usr/local/bin)" >&2
	exit 2
fi

TMPDIR_LOCAL="${TMPDIR:-/tmp}"
SMOKE="$TMPDIR_LOCAL/mova_smoke_$$.luau"
trap 'rm -f "$SMOKE"' EXIT

{
	cat "$ROOT/scripts/smoke_stubs.luau"
	echo ""
	echo "Mova = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat <<'ASSERTIONS'
-- ===== smoke assertions =====
local function expect(cond, message)
	if not cond then
		error("SMOKE FAIL: " .. tostring(message), 0)
	end
end

expect(type(Mova) == "table", "bundle returned its API table, got " .. type(Mova))
expect(type(Mova.CreateWindow) == "function", "CreateWindow is a function")
expect(type(Mova.Icons) == "table", "Icons surface exists")
expect(Mova.Icons.Lucide == "lucide", "icon name constants intact")
expect(type(Mova.Icons.get) == "function", "Icons.get callable")

-- Internal service surface (added in the modular refactor)
expect(type(Mova.Core) == "table", "Mova.Core service surface exists")
expect(type(Mova.Core.state) == "table", "core state loaded")
expect(type(Mova.Settings) == "table", "Mova.Settings service surface exists")
expect(type(Mova.Settings.readPersisted) == "function", "settings readPersisted callable")

-- Lazy icon pack actually loads data
local lucidePack = Mova.Icons.getByPack("lucide", "house")
expect(type(lucidePack) == "string" and #lucidePack > 0, "lucide house icon resolves to a URL")
ASSERTIONS
} > "$SMOKE"

if "$LUAU_BIN" "$SMOKE"; then
	echo "SMOKE TEST PASSED"
	exit 0
else
	echo "SMOKE TEST FAILED (see above)" >&2
	exit 1
fi
