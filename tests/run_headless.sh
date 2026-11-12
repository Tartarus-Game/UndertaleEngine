#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

run_godot() {
    local exit_code=0
    timeout 180 "$godot_bin" --headless --path . "$@" 2>&1 | tee "$log_file" || exit_code=${PIPESTATUS[0]}
    if (( exit_code != 0 )) || grep -Eq '^(SCRIPT ERROR|ERROR):' "$log_file"; then
        return 1
    fi
}

run_godot --editor --quit
run_godot res://tests/test_runner.tscn
run_godot res://tests/extended_runner.tscn
run_godot res://tests/battle_physics_runner.tscn
