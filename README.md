# Eat Prey Nap

A free tablet game for cats, formerly Trivial Purrsuit. The player is the cat.

A mouse hides, shows its ears, peeks, sniffs about, freezes and bolts. The cat
stalks and pounces. No ads, no accounts, no purchases, no internet.

This is a new game made with Godot. The Flutter prototype is kept at the tag
[`flutter-legacy`](https://github.com/cyanidesayonara/eat-prey-nap/tree/flutter-legacy).

**State:** M0, a one-mouse prototype to try with cats. Not on any store yet.
The plan is in [PROJECT.md](PROJECT.md).

## Run it

A portable [Godot 4.7](https://godotengine.org/download) (the standard build)
lives in `godot/` locally (gitignored).

```bash
godot/Godot_v4.7-stable_win64.exe --path .
```

On a PC:

| Do | What it is |
|---|---|
| Left click, or drag fast | A paw |
| Right click | A second paw that stays there; right click again lifts it |
| Esc | Back to the start screen |

On a touch screen every finger is a paw. **To leave the game, hold two opposite
corners for 2 seconds.** Back does nothing while a cat is playing.

The start screen has the three palettes, the three mouse sizes and a 50 mm
ruler. Hold a real ruler against it and correct it, or the sizes are off.

Options go after a `--`: `--play`, `--watch`, `--palette=0..2`, `--size=0..2`,
`--dpi=N`, `--seed=N`.

## Test it

```bash
GODOT=godot/Godot_v4.7-stable_win64_console.exe bash tools/run_tests.sh
```

## With a cat

Put the tablet flat on the floor, on something that does not slide. Clean the
screen. Stay in the room, keep sessions short, and end on a catch with a real
treat: a cat that can never catch anything gets frustrated.

## License

MIT, see [LICENSE](LICENSE).
