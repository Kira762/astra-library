#!/bin/sh
# Exercises named-icon downloads with only the filesystem capabilities the
# image cache actually needs, executor globals stored in getgenv(), the
# getsynasset alias, and no executor request function.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${ASTRA_BUNDLE:-$ROOT/version-1.luau}"

if [ ! -f "$BUNDLE" ]; then
	echo "bundle missing: $BUNDLE" >&2
	exit 1
fi

LUAU_BIN="$(command -v luau || true)"
if [ -z "$LUAU_BIN" ]; then
	for candidate in "$ROOT/.tools/bin/luau" /tmp/luau /usr/local/bin/luau; do
		if [ -x "$candidate" ]; then
			LUAU_BIN="$candidate"
			break
		fi
	done
fi
if [ -z "$LUAU_BIN" ]; then
	echo "luau CLI not found (looked in PATH, .tools/bin, /tmp, /usr/local/bin)" >&2
	exit 2
fi

TMPDIR_LOCAL="${TMPDIR:-/tmp}"
OUT="$TMPDIR_LOCAL/astra_image_remote_$$.luau"
trap 'rm -f "$OUT"' EXIT

{
	cat "$ROOT/scripts/sidebar_sizing_stubs.luau"
	cat "$ROOT/scripts/image_remote_pipeline_stubs.luau"
	echo ""
	echo "Astra = (function()"
	echo ""
	cat "$BUNDLE"
	echo ""
	echo "end)()"
	echo ""
	cat "$ROOT/scripts/image_remote_pipeline_test.luau"
} > "$OUT"

if "$LUAU_BIN" "$OUT"; then
	echo "IMAGE REMOTE PIPELINE TEST PASSED"
	exit 0
else
	echo "IMAGE REMOTE PIPELINE TEST FAILED (see above)" >&2
	exit 1
fi
