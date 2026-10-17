#!/bin/sh
# End-to-end tests for the unsigned loader: valid bundle loads, while fetch,
# compile, and execution failures quietly return the no-op stub.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOADER="$ROOT/loader.luau"
LUAU_BIN="$(command -v luau || true)"
if [ -z "$LUAU_BIN" ]; then
  for candidate in /tmp/luau /usr/local/bin/luau; do
    if [ -x "$candidate" ]; then LUAU_BIN="$candidate"; break; fi
  done
fi
if [ -z "$LUAU_BIN" ]; then
  echo "luau CLI not found (looked in PATH, /tmp, /usr/local/bin)" >&2
  exit 2
fi
WORK="${TMPDIR:-/tmp}/mova_loader_unsigned_$$.luau"
trap 'rm -f "$WORK"' EXIT

run_case() {
  name="$1"
  response="$2"
  expect_real="$3"
  {
    cat <<LUA
HttpGet = function(url)
  if url ~= "https://raw.githubusercontent.com/Kira762/astra-library/main/version-1.luau" then error("unexpected URL") end
  $response
end
local Mova = (function()
LUA
    cat "$LOADER"
    cat <<LUA
end)()
if $expect_real then
  assert(type(Mova.CreateWindow) == "function", "$name: expected real API")
else
  assert(type(Mova.CreateWindow) == "table", "$name: expected quiet stub")
  assert(pcall(function() Mova:CreateWindow({}):CreateTab({}):Select() end), "$name: stub chain raised")
end
print("$name: ok")
LUA
  } > "$WORK"
  "$LUAU_BIN" "$WORK"
}

run_case valid 'return "return { CreateWindow = function() end }"' true
run_case fetch_failure 'error("offline")' false
run_case compile_failure 'return "this is not valid Luau !!!"' false
run_case runtime_failure 'return "error(\"bundle failed\")"' false

echo "LOADER UNSIGNED TEST PASSED"
