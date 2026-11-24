#!/usr/bin/env bash
# Assembles the website in _site/: site/ at the root and the web build, from
# this commit, at /play. The deploy and a local preview both use it.
#
#   GODOT=path/to/godot bash tools/site_build.sh
#   python -m http.server 8000 -d _site
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?set GODOT to the Godot 4.7 editor binary}"

bash tools/itch_export.sh web
rm -rf _site
mkdir -p _site/play
touch _site/.gdignore
cp -r site/. _site/
cp build/web/* _site/play/
rm -f _site/play/*.import
for f in index.html privacy/index.html style.css logo.js theme.js play/logo.js play/guard.js play/index.html play/index.wasm play/index.pck; do
  test -s "_site/$f"
done

# every relative link and image on the pages is really there
for page in index.html privacy/index.html; do
  dir="_site/$(dirname "$page")"
  for ref in $(grep -oE '(href|src)="[^"#]+"' "_site/$page" | cut -d'"' -f2 | grep -vE '^https?:'); do
    target="$dir/$ref"
    case "$ref" in */) target="${target}index.html" ;; esac
    test -s "$target" || { echo "$page links to $ref, which is missing"; exit 1; }
  done
done

# GitHub Pages refuses any file over 100 MB
test -z "$(find _site -type f -size +95M)"
du -sh _site
