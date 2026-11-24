# AGENTS.md -- Eat Prey Nap

For AI coding agents (https://agents.md). Read `PROJECT.md` before proposing
features: it holds the principle, the scope and the milestones.

## Rules

- The player is the cat. If a choice pleases humans but not cats, the cat wins.
- **No AI attribution** in commits or pull requests: no co-author lines, no
  "generated with". CI checks the whole history.
- Work on a branch and by pull request. Never push to `main`.
- Ask the owner before fixing the package ID, installing tools, or adding any
  Android permission. There is no internet permission, ever.
- No recreation of the reference video's set, and no footage from it.
- `../path-of-leash-resistance` is a read-only reference for the export
  script, CI, icon generator, Back/pause/safe-area handling, synthesized audio
  and the test runner. Do not copy its `game.gd`, menus or world code.

## Tech

- Godot 4.7, GDScript only, GL Compatibility.
- Art is drawn in `_draw()`; sound is synthesized in `src/audio/sfx.gd`. The
  only image files are the icons, made by `tools/make_icon.gd`. Never edit
  them by hand.
- Scripts `preload` each other; no `class_name`, so tests run without an import.

## Layout

```
main.gd, main.tscn      start screen <-> play; input, pause, Back, options
src/sim/                mouse_brain.gd (the chase), difficulty.gd. Pure: no nodes
src/input/paws.gd       touches -> paws, resting pads, the corner exit
src/view/               palettes, mouse, mounds, floor and border, start screen
src/audio/sfx.gd        synthesized sounds (autoload Sfx)
src/screen.gd           pixels <-> mm, safe area
src/settings.gd         the human's choices, user://settings.cfg
tests/                  test_*.gd, headless, all run by CI
tools/                  run_tests.sh, android_export.sh, itch_export.sh, site_build.sh, site_media.gd, make_icon.gd, make_ico.py, shots.gd
```

## Things that are easy to break

- **Millimetres.** The simulation is in mm of real screen. Input divides by
  `ppm`, the views multiply by it as they draw. Do not scale a node instead:
  that blows the one-pixel antialias feather up into a blur.
- **Act on press.** `brain.press()` runs inside the input event. Never queue a
  press for the next frame. `Input.use_accumulated_input` stays off.
- **No mouse/touch emulation.** Both project settings are off, or a touch would
  land twice. So Godot's `Button` does not see touches; the start screen hit
  tests its own rectangles.
- **Mounds are drawn over the mouse.** The tail is reeled out only as far as
  the mound covers it, and kept straight under there (`tail_out`, `_step_tail`).
- **Back does nothing during play**: cats swipe from the edges.
- **A good try is a hit.** Near misses do not count towards difficulty.
- **Pausing drops every touch**, because their releases may never arrive.
- `_set`, `_get` and `_notification` are engine virtuals; do not name your own
  functions that.

## itch

`tools/itch_export.sh` builds the web and Windows versions. `itch.yml` runs it
on pull requests that touch exports and launches the Windows exe; it publishes
on a `v*` tag only, and only once the owner has made a GitHub environment
`itch` with `BUTLER_API_KEY` and `ITCH_PROJECT`. Never push a tag unasked.

## Website

`site/` is plain HTML and CSS: no framework, no external requests, relative
links. `tools/site_build.sh` adds the web build at `/play` and checks the
links; `tools/site_media.gd` makes the images. `pages.yml` deploys from
`main`, only once the owner has set Pages to GitHub Actions and the
repository variable `SITE_LIVE` to `true`.

## Android builds on Windows

CI builds the APK (`android.yml`); a local build is optional. It needs JDK 17,
an SDK with platform 36 and build-tools 36.1.0, and Godot's Android templates.
A home path with a letter like "ä" breaks Java's sockets ("Unable to establish
loopback connection"). The owner's PC has the SDK and JDK under `C:\Android`
and builds with:

```bash
export JAVA_HOME='C:\Android\jdk-17' ANDROID_HOME='C:\Android\Sdk'
export JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\Android\tmp'
export GRADLE_USER_HOME='C:\Android\gradle'
```

Then `tools/android_export.sh`, with the variables its header lists.

## Checks before a pull request

```bash
GODOT=godot/Godot_v4.7-stable_win64_console.exe bash tools/run_tests.sh
godot/Godot_v4.7-stable_win64_console.exe --path . --script res://tools/shots.gd   # then look at shots/
```

Commit the `.uid` and `.import` files Godot makes. Keep tuning values in named
constants. The export's permission and SDK levels are checked on the built APK
by `.github/workflows/android.yml`.
