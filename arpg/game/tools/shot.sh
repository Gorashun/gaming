#!/bin/bash
# Run the game under Xvfb and save screenshot(s). Usage: tools/shot.sh <out.png> [extra args...]
cd "$(dirname "$0")/.."
OUT=$1; shift
timeout ${TIMEOUT:-150} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -- --autostart --screenshot=$OUT "$@" 2>&1 \
 | grep -vE "^\s*$|V-Sync|OpenGL API|libpulse|ALSA|audio_driver_alsa|All audio drivers|audio_server.cpp|Condition \"status < 0\"|set_use_vsync|Godot Engine v"
