#!/usr/bin/env bash
# Runs Godot with the given arguments. Fails on a non-zero exit code or on any engine error in
# the output (GDScript runtime errors do not change Godot's exit code by themselves).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
out="$(mktemp)"
"$GODOT" "$@" >"$out" 2>&1
code=$?
cat "$out"
if grep -Eq 'SCRIPT ERROR|^ERROR:|Parse Error' "$out"; then
  echo "FAILED: engine errors found in output" >&2
  code=1
fi
rm -f "$out"
exit "$code"
