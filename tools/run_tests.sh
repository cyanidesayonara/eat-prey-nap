#!/usr/bin/env bash
# Runs every tests/test_*.gd headless, the way CI does. Any script error fails.
#
#   GODOT=path/to/godot bash tools/run_tests.sh [FILTER]
set -uo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT to the Godot 4.7 editor binary}"
TIMEOUT="${TIMEOUT:-180}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
pass=0
failed=()
for f in tests/test_*.gd; do
  name="$(basename "$f" .gd)"
  [ -n "${1:-}" ] && [[ "$name" != *"$1"* ]] && continue
  # stdin from /dev/null: Windows Godot drains what the shell reads
  if timeout "$TIMEOUT" bash tools/godot_ci.sh "$GODOT" --headless --path . --script "res://$f" >"$log" 2>&1 </dev/null; then
    pass=$((pass + 1))
    echo "ok    $name ($(grep -oE '^[0-9]+ checks' "$log"))"
  else
    failed+=("$name")
    echo "FAIL  $name"
    cat "$log"
  fi
done
echo "$pass passed, ${#failed[@]} failed"
[ "${#failed[@]}" -eq 0 ] && [ "$pass" -gt 0 ]
