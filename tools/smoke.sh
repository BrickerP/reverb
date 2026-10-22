#!/usr/bin/env bash
# Headless end-to-end run of the real Main scene (bot input, shop buttons, death, restart).
exec "$(dirname "$0")/checked.sh" --headless --path . --fixed-fps 60 --script res://tools/smoke.gd
