# Eat Prey Nap: the plan

## Principle

**The player is the cat.** If a choice pleases humans but not cats, the cat
wins. Simple background, excellent chase.

The model is a favourite video of one cat's:
[real mice around a mouse hole](https://www.youtube.com/watch?v=6pbreU5ChmA)
(plain wall and floor, crumbs). We borrow its principles, not its set or footage:

- one plain surface, nothing else moving
- a few fixed hiding places a cat can stake out
- food that gives the mouse a reason to come out
- long stillness, then sudden movement

## The chase

`hidden > tell > peek > sniff > creep > freeze > dart > hide`

- Ears or a tail show (the tell) before every peek.
- Timing is irregular (log-normal), and movement comes in bursts: never
  constant gliding.
- It reacts to paws: a press close by makes it run after a short fright, one
  further off makes it freeze, a slow paw sliding near makes it freeze.
- A hit can pin it; then it wriggles free or is caught.
- Pawing at the mound it hides under makes it slip out of another one.
- **Difficulty follows recent catches.** A good try is a paw that lands on the
  mouse. It starts at 1 catch in 3 good tries and leans back towards that;
  after five misses in a row the next good try is a catch.
- **Boldness:** ignored for a while, it hides less, comes out further and
  feints more. Any paw makes it shy again.

## A session (M2)

Prey (hunt, ending in an easy catch) > eat (tell the human to give a treat) >
nap (the screen dims). Plus a watch mode that needs no touch (in M0 already).

## What a cat sees

Brightness contrast first, then blue against yellow. A cat's neutral point is
about 505 nm, so teal looks grey. No red/green cues, teal accents, flashes or
fine texture. Bold silhouettes, big ears and tail.

Compared in M1:

| | Field | Mouse |
|---|---|---|
| 1 (default) | straw | ink blue |
| 2 | ink blue | pale yellow |
| 3 | mid grey | near black |

Sizes, body without tail: 28, 40 (default) and 55 mm, limited to 30% of the
screen's short side.

The border is a faint looping mouse tail with paw prints. Not a blue-and-gold
board-game look.

`tests/test_palette.gd` checks contrast for daylight and for rods. Both
formulas are for human eyes, as an approximation; the cats decide.

Highest refresh rate available (90/120/144 Hz), and good at 60.

## Input

- Multi-touch, acts on press, generous hit area, ignores resting pads.
- The human leaves by holding two opposite corners for 2 s.
- Later: optional Android screen pinning.

## Scope of v1

Mouse, bug, fish. Android first, tablets above all (likely a Lenovo Idea Tab Pro, not
bought yet), landscape, minSdk 24, targetSdk 36, no internet permission.

Not in v1: laser dot, camera, ads, accounts, purchases, iOS.

## Milestones

- **M0 One mouse.** Playable with a mouse on a PC, with headless tests.
- **M1 Cat test.** Go only if 3 of 5 cats stalk or paw for 60 s on two days
  and none leaves the app.
- **M2 Full session.** Prey, eat, nap.
- **M3 Bug and fish.**
- **M4 Hardening.**
- **M5 itch.** First public release, the way Leash Resistance does it: CI
  pushes a channel per build on a version tag. See below.
- **M6 Play release.** New account, so probably 12 testers for 14 days. A
  trademark check on the title is still to do.

## Where it ships

itch first, then Google Play; the Microsoft Store only if it makes sense.

- **itch, Android APK:** the real game. Also where the 12 Play testers can be
  found. Needs the package ID and one signing key for good: an APK signed with
  another key than Play's cannot be updated from Play, only reinstalled.
- **Website:** GitHub Pages, with the web build to try. Same limits as below.
- **itch, web:** a try-out, not the game. A browser tab is easy for a cat to
  leave, does not know millimetres, and may cap the frame rate.
- **itch, Windows:** for touch laptops, where a cat can trigger edge swipes.
- **Microsoft Store:** doubtful. It wants its own packaging and listing, for
  few touch screens a cat may stand on. Decide on how the itch Windows
  download does.
- **Before any public page:** the trademark check on the title and the new
  privacy policy. M1 and M2 can use a password-protected itch page.

## Open

- **Package ID.** Neutral, without the title. `com.example.placeholder` until
  the owner chooses; `tools/android_export.sh` refuses to build a release
  with it. It can never change after the first upload.
- **Refresh rate on the tablet.** Nothing caps the frame rate, but whether
  Android gives the game more than 60 Hz has to be measured on the device. The
  start screen shows the frame rate.
- **Millimetres on the tablet.** Android reports a density bucket, so the ruler
  must be corrected once per device.
- **Privacy policy.** `PRIVACY_POLICY.md` is still the Flutter app's, under the
  old name, and says data is collected. The new game collects none. Rewrite it
  before M5 (itch); until then it does not describe this game.
- **Numbers.** Everything in the constants at the top of
  `src/sim/mouse_brain.gd` is a guess until a cat has played.

## How M1 is measured

The start screen shows the last session: time, paws, good tries, catches, and
seconds with a paw busy on the glass. Stalking without touch is not measured,
so a human times it. Note the cat, the day, palette, size, and whether the app
was left.
