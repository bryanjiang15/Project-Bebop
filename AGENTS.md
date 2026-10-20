# Agent guide

Project Bebop is a turn-based terraforming 4X on a hex map. This repository is the Godot 4.7 prototype. New Game builds a seeded hex map, three players, one starting settler each, and per-player fog of war. The human can move that settler and found a city. Spells, production, combat, and AI are later tickets.

Notion is the source of truth for design. Copies live in `docs/`. If the brief and the design doc disagree, the design doc wins. `docs/agreed_defaults.md` is the approved engineering record and overrides the design doc's chance-based volcanic proposal with the brief's flat 10 damage.

## Layout

```
scenes/           main_menu.tscn, game.tscn, victory.tscn, defeat.tscn
scenes/ui/        menu_button.tscn (instanced buttons)
scenes/actors/    unit.tscn (instanced once per visible unit)
scenes/view/      move_highlight.tscn, city_marker.tscn, border_segment.tscn
scripts/core/     RefCounted rules: hex.gd, game_config.gd, map_state.gd, map_generator.gd, player_state.gd, fog_state.gd, game_setup.gd, pathfinder.gd, map_city.gd
scripts/view/     rendering and input, including fog_overlay.gd
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

## Map, starts, and fog

`GameSetup.start` reads `map.seed`. **0 rolls a new non-zero seed** on every New Game and Restart. Any other value is used as-is. The seed that actually built the map is printed to stdout as `map seed: N`. Putting that N back into `map.seed` replays the map and the starts. If a seed cannot place fair starts, the next try uses a derived seed, at most `map.generation_attempts` maps and `map.start_attempts` shuffles each. The printed seed is the one that worked, and it replays on the first try.

`MapGenerator` builds clusters with integer value noise, then assigns exact tile counts (largest remainder on `map.land_mix`). Low noise is water, then plains, forest, hills, volcanic. The counts are integer math so the same seed matches on macOS and Linux.

Each player in `players.count` is spawned at a passable tile (not water) with at least `map.start_quality_min` passable tiles inside radius `map.start_quality_radius`. Pairwise hex distance is at least `map.start_min_distance`. The human is `players.human_index`. Everyone else is a rival with no AI yet. `players.starting_units` is the list spawned on that tile, in order. It is currently `["settler"]`. A later ticket adds the warrior by appending to that list. Sprites are instances of `scenes/actors/unit.tscn` on the y-sorted `Actors` node, tinted with `players.colors` through `assets/art/team_tint.gdshader`. A unit whose tile is not currently visible to the human is not instanced. Two units that share a tile are offset from each other; a unit on its own tile is not.

`GameSetup.spawn_unit(player, type, pos)` is the only way to create a unit. `pos` is an odd-r offset cell, the same space as `UnitState.cell`. It rejects an unknown type, a bad player, impassable land, and an illegal stack, then recomputes fog. Starting units go through it.

`FogState` keeps unrevealed / revealed / visible **per player** in core. At game start every tile is unrevealed, then each unit reveals a disk of `fog.unit_vision`. A city reveals a disk of its territory radius plus `fog.city_vision_beyond_border`. `FogState.recompute` drops visible tiles to revealed, then marks the current disks. The view draws the human's fog. An unrevealed cell is erased from the terrain `TileMapLayer`, so its atlas does not depend on the land type, and a neutral fill (`fog.hidden_color`) covers the hole. A revealed-but-not-visible cell keeps its land tile and is dimmed with `fog.dim_color`. Visible cells are uncovered. The hover tooltip shows the land id for revealed and visible tiles. An unrevealed tile shows axial coordinates and the word Unexplored, never the land id.

Rival units are drawn only while their tile is visible. A rival city is drawn once its tile has been explored, and a territory edge is drawn once that owned tile has been explored. Both stay as last-known information after they leave vision. The distance rule still sees cities that have never been explored; the reason text does not reveal them.

The camera starts centered on the human settler.

## Movement and founding

`Pathfinder.reachable` searches axial hexes and returns movement points left on arrival. The origin is omitted. `GameSetup.reachable_tiles` converts that result to offset cells. The cost is the land of the tile entered (`land.*.move_cost`). Water is impassable. When `movement.allow_enter_over_budget_if_mp_left` is true and any points remain, a costlier tile can still be entered; arrival leaves 0 points and the search does not continue. Another player's unit blocks the tile. `units.one_military_and_one_civilian_per_tile` allows one combatant and one non-combatant together and rejects a second of the same kind.

A left click selects the human unit on that tile. Reachable tiles and the selected tile are instances of `scenes/view/move_highlight.tscn`, using `tile_highlight.png`. The sprite offset is read from the TileSet at runtime. Click a highlighted tile to move. A left drag farther than 8 px still pans. Middle drag, arrow keys, and the wheel are unchanged. `End Turn` increments one global turn and refills every unit from its config move. Rivals do not act. Fog recomputes after each move.

`%FoundCityButton` reads **Found City (B)**. The `found_city` input action is B. `%FoundCityReason` shows why the button is disabled:

- `Select a settler`
- `Cannot found on water`
- `Cannot found on another player's tile`
- `Too close to another city`
- `Cannot found off the map`

Distance is center to center. Less than `city.min_distance` rejects, including a city under fog. Exactly that distance accepts. Founding does not spend movement. It consumes the settler, stores population 1, and claims a disk of `city.border_start_radius`. Water is claimed only when `borders.can_claim_water` is true. An owned tile is left alone when `borders.can_claim_owned_tiles` is false. Own territory can be founded on when the distance rule passes. Names come from `players.city_names`, one non-empty list per player. Past the end of a list, the last name is reused with a number (`Only`, then `Only 2`).

Cities are instances of `scenes/view/city_marker.tscn` on `Actors`, tinted with the owner's color. Territory edges are instances of `scenes/view/border_segment.tscn` under `%Borders`, one segment per outer edge of an explored owned tile. The new config key is `players.city_names`. The other founding and movement numbers were already in `game_config.json`. Settler training is not in this tree; ticket 9 calls `spawn_unit`. Details live in `docs/movement_and_founding.md`.

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

Play the game with `godot --path .`. Click a settler, then click a highlighted tile to move it. B or **Found City** founds a city on that tile. F9 opens Victory, F10 opens Defeat, Escape toggles the in-game menu.

## Rules for agents

If you change architecture, conventions, or these commands, update `AGENTS.md`, `.cursor/rules/godot.mdc`, and `docs/` in the same change.

Commit `.import` and `.uid` files. Do not commit `.godot/` or `builds/`.
