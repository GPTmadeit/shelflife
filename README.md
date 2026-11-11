# Shelf Life

An R-rated grocery store comedy. A 2.5D story platformer about Baker, the
thirteenth egg in a carton of twelve: no cup, no slot, and no place in the
Planogram, the sacred shelf layout the food of Grocerama worships.

The faithful believe that when you're **Chosen** (bought) and hear **the Beep**
(scanned), you come back at the next **Restock**, same shelf, forever. Tonight
is the night before the store's Grand Re-Opening, when a new Planogram arrives
and everyone gets an eternal Facing. Baker sets out across the store at night
to find out if there's a place in it for a packing error.

It does not go well for anyone's faith.

> **Content:** strong language, crude humor, religious satire and food in mortal peril.

## Status

**Act One: Unplanned** is playable start to finish (about 20 minutes): the
dairy case, the main aisle and the Narc, the bakery, and the Employees Only
doors. Act Two is not written yet.

## Play

From source, with [Godot 4.7](https://godotengine.org):

```sh
godot --path .
```

Or export a build: `godot --headless --path . --export-release Linux build/linux/ShelfLife.x86_64`
(presets for Linux and Windows are in `export_presets.cfg`).

| | Keyboard | Gamepad |
|---|---|---|
| Move | A / D or ← / → | Left stick / D-pad |
| Jump (hold for higher) | Space, W or ↑ | A |
| Talk / advance dialogue | E or Enter (Space advances too) | X / A |
| Pause | Esc | Start |

Eggs crack. A short drop is fine; jump off anything tall and you'll crack your
shell. Three cracks and you're done. Bread and other soft things are safe to
land on.

Graphics quality (Settings) defaults to Low on older Intel integrated GPUs.

## How it's made

Everything is generated in code at startup: every character, prop and shelf
is built from procedural meshes (`scripts/gfx/meshes.gd`), faces are drawn from
distance functions (`scripts/gfx/face_tex.gd`), and every sound, voice blip and
the store muzak is synthesized (`scripts/core/synth.gd`). No audio or texture
files ship with the game except two fonts.

| Path | What |
|---|---|
| `dialogue/act1.dlg` | the whole Act One script (format in `scripts/dialogue/dlg_parser.gd`) |
| `scripts/world/act1.gd` | the level: layout, cast, triggers, cutscene events |
| `scripts/actors/` | Baker (`player.gd`), the food characters (`food_rig.gd`), the Narc, the humans |
| `scripts/ui/` | dialogue box, HUD, title, pause and settings |

### Dev tools

```sh
godot --headless --path . --script tests/check.gd   # scripts compile, dialogue is consistent
tests/shot.sh out.png 8 --cp narc --flags intro_done,sermon_done   # screenshot (Hyprland, hidden workspace)
```

Flags after `--`: `--cp <checkpoint>`, `--flags a,b`, `--dlg <node>`, `--auto`
(reads dialogue by itself), `--bot` (walks right and hops), `--godmode`,
`--quality 0|1|2`, `--act action@t0-t1,...`, `--shot <png> <s>`, `--burst <n> <step>`, `--trace`.

## Credits

Fonts: [Lilita One](https://fonts.google.com/specimen/Lilita+One) by Juan Montoreano and
[Nunito](https://fonts.google.com/specimen/Nunito) by Vernon Adams, both under the SIL Open
Font License (see `assets/fonts/`). Built with Godot Engine.
