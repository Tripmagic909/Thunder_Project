#!/bin/sh
# 使い方: tools/mame/run.sh <ROM> <スナップ出力先> "<SCRIPT>"
ROM="$1"; OUT="$2"; export SCRIPT="$3"
rm -rf "$OUT"; mkdir -p "$OUT"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL 600 /usr/games/mame megadrij -cart "$ROM" \
  -video soft -window -sound none -nothrottle -skip_gameinfo \
  -autoboot_script "$(dirname "$0")/script.lua" -snapshot_directory "$OUT" -seconds_to_run 3000 \
  < /dev/null 2>&1 | grep -v ALSA
