#!/usr/bin/env bash
# Headless unit tests. Optional argument: substring of a suite file name, e.g. ./tools/test.sh test_ui
exec "$(dirname "$0")/checked.sh" --headless --path . --script res://tests/run_tests.gd -- "$@"
