#!/bin/bash
# Parse/compile-check every GDScript with autoloads loaded.
cd "$(dirname "$0")/.."
timeout 180 godot --headless --path . res://tests/check_all.tscn 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|  at: GDScript::reload|FAIL|CHECK DONE" | grep -v "depended scripts"
