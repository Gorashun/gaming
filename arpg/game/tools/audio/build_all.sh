#!/bin/bash
# Regenerate every Wickwright sound from code. Run from anywhere; takes a few minutes.
# Requires: python3 with numpy, scipy, soundfile  (pip install numpy scipy soundfile)
set -e
cd "$(dirname "$0")/../.."
python3 tools/audio/sfx_gen.py
python3 tools/audio/import_cc0.py
printf '%s\n' title town graveyard crypt forest mine ice hush boss | xargs -P4 -I{} python3 tools/audio/music_gen.py {}
printf '%s\n' amb_bog amb_forest amb_mine amb_ice amb_hush | xargs -P4 -I{} python3 tools/audio/ambience_gen.py {}
du -sh assets/generated/sfx assets/generated/music
