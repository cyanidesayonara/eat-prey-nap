#!/usr/bin/env bash
# Exports the web and Windows builds for itch into build/web and build/win.
#
#   GODOT=path/to/godot bash tools/itch_export.sh [web] [win]
#
# With no argument, both. Export templates must be installed. An export with
# no import cache ships the icon as a missing dependency, so it imports first.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT to the Godot 4.7 editor binary}"
[ $# -gt 0 ] || set -- web win

"$GODOT" --headless --path . --import </dev/null
for what in "$@"; do
  rm -rf "build/$what"
  mkdir -p "build/$what"
  case "$what" in
    web)
      timeout 600 "$GODOT" --headless --path . --export-release "Web" build/web/index.html </dev/null
      # the loading screen's animation and the cat guard, which the page asks for
      for js in logo guard; do
        cp "site/$js.js" build/web/
        grep -q "src=\"$js.js\"" build/web/index.html
      done
      test -s build/web/index.wasm
      test -s build/web/index.pck
      ;;
    win)
      timeout 600 "$GODOT" --headless --path . --export-release "Windows Desktop" build/win/EatPreyNap.exe </dev/null
      # a packed single-file build is tens of MB, not a stub
      test "$(stat -c%s build/win/EatPreyNap.exe)" -gt 20000000
      ;;
    *)
      echo "unknown build: $what"
      exit 1
      ;;
  esac
  ls -l "build/$what"
done
