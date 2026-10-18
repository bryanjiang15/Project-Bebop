# Agent guide

Project Bebop is a turn-based terraforming 4X on a hex map. This repository is the Godot 4.7 skeleton: menus, config, hex math, and an isometric art view. Map generation, cities, spells, units, and AI are later tickets. Do not add them here.

The in-game scene places one test settler and one test city so the art pipeline can be seen. They are fixtures, not gameplay.

Notion is the source of truth for design. Copies live in `docs/`. If the brief and the design doc disagree, the design doc wins. `docs/agreed_defaults.md` is the approved engineering record and overrides the design doc's chance-based volcanic proposal with the brief's flat 10 damage.

## Layout

```
scenes/           main_menu.tscn, game.tscn, victory.tscn, defeat.tscn
scenes/ui/        menu_button.tscn (instanced buttons)
scripts/core/     RefCounted rules: hex.gd, game_config.gd
scripts/view/     rendering and input
config/game_config.json
assets/art/       greybox art v0.2, bebop_tileset.tres, team_tint.gdshader
tests/            unit tests, missing-key check, smoke test
docs/
```

## Architecture

- `scripts/core/` has no `Node`, scene, `get_node`, or `Input` dependency. Tests construct it with `load` / `class_name` and no scene.
- `scripts/view/` owns rendering and input. It reads config and calls core.
- Layout is in `.tscn` files. Scripts use `%UniqueName` and `@onready`. They do not build controls.
- Repeated buttons are instances of `scenes/ui/menu_button.tscn`.
- Every tunable from brief section 5 and every agreed default is a key in `config/game_config.json`. `GameConfig.load_file()` push_errors and quits on a missing or mistyped key. There are no silent defaults.
- Restart on the in-game menu and on the victory and defeat screens calls `GameConfig.load_file()` and then opens the game scene, whose `_ready` loads the file again.

## Hexes and art

Axial `(q, r)`, pointy top. `+q` east, `+r` southeast. Six directions, in order: east, northeast, northwest, west, southwest, southeast.

The map is an odd-r rectangle (`map.width` by `map.height`). `Hex.axial_to_offset` matches a `TileMapLayer` with hexagon shape, stacked layout, and horizontal offset axis. `Hex.line` walks `length` tiles from the target and drops tiles outside that rectangle. Radius 1 is the center plus six neighbors (7 tiles).

Tile size and texture origin live only on `assets/art/bebop_tileset.tres`. The art is already isometric. Do not squash it, and do not copy those numbers into config or scripts.

- Shape hexagon, layout stacked, offset axis horizontal (pointy-top).
- `tile_size` is the face, `(128, 108)`.
- Terrain atlas `tile_sheet.png` (768×116). Region `(128, 116)`, margins 0, separation 0. Columns: plains, forest, hills, water, volcanic.
- Hover uses a second source, `tile_highlight.png`, on the Highlight layer.
- `texture_origin` is `(0, -4)` on every tile. Checked with the GL Compatibility renderer: the 108 px face is centered on the cell and the 8 px side hangs below. The sign was not flipped.

Hover calls `TileMapLayer.local_to_map` on that TileSet. `Hex.pixel_to_hex` / `pixel_to_offset` match `local_to_map` for the same `tile_size`. The unit tests load the art TileSet and compare the two.

The stripe map is not a generator. Columns 0–5 plains, 6–11 forest, 12–16 hills, 17–22 water, 23–27 volcanic.

`Actors` is a `Node2D` with `y_sort_enabled`. The test settler (offset cell `(9, 6)`, sprite offset `(0, -20)`, blue `#3D7EDB`) and the test city (cell `(14, 9)`, offset `(0, -10)`, red `#D94A3D`) sit at `map_to_local`. Both use `assets/art/team_tint.gdshader`.

## Commands

From the repo root, with Godot 4.7 stable on `PATH`. Import first on a checkout that has no `.godot/` directory:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/expect_missing_key.gd
godot --headless --path . --quit-after 120 res://scenes/main_menu.tscn
godot --headless --path . --quit-after 120 res://scenes/game.tscn
godot --headless --path . --script res://tests/smoke_game.gd
```

`expect_missing_key.gd` must exit non-zero and report `game_config.json missing key: players.count`. The others must exit 0. CI greps every log for `SCRIPT ERROR` and `ERROR:` (`set -o pipefail`) except the missing-key step, which requires that specific error.

Play the game with `godot --path .`. F9 opens Victory, F10 opens Defeat, Escape toggles the in-game menu.

## Rules for agents

If you change architecture, conventions, or these commands, update `AGENTS.md`, `.cursor/rules/godot.mdc`, and `docs/` in the same change.

Commit `.import` and `.uid` files. Do not commit `.godot/` or `builds/`.
