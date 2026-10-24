# Agent guide

Project Bebop is a turn-based terraforming 4X on a hex map. This repository is the Godot 4.7 prototype. New Game builds a seeded hex map, three players, one starting settler and one warrior each, and per-player fog of war. The human can move those units, attack a visible enemy, found a city, and run that city's yields, growth, borders, and production queue. Spells and AI are later tickets.

Notion is the source of truth for design. Copies live in `docs/`. If the brief and the design doc disagree, the design doc wins. `docs/agreed_defaults.md` is the approved engineering record and overrides the design doc's chance-based volcanic proposal with the brief's flat 10 damage.

## Layout

```
scenes/           main_menu.tscn, game.tscn, victory.tscn, defeat.tscn
scenes/ui/        menu_button.tscn (instanced buttons), queue_row.tscn
scenes/actors/    unit.tscn (instanced once per visible unit), hp_bar.tscn
scenes/view/      move_highlight.tscn, city_marker.tscn, border_segment.tscn, building_marker.tscn
scripts/core/     RefCounted rules: hex.gd, game_config.gd, map_state.gd, map_generator.gd, player_state.gd, fog_state.gd, game_setup.gd, pathfinder.gd, map_city.gd, city_rules.gd, combat.gd
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

## Window

The root viewport is **2560×1440**. Stretch mode is `canvas_items`, aspect is `expand`, scale mode is `fractional`, and `allow_hidpi` stays on. The window is resizable. A smaller window scales the whole canvas down, so panels stay inside the screen; a wider window keeps the anchored bars and panels on the edges and shows more of the map. The top bar is a full-width anchor. Corner panels stay on their anchors. `camera.default_zoom` is `0.72` so the 28×18 map fills that window the way `0.36` filled 1280×720. Hit tests go through the canvas transform. Do not hardcode the window size in scripts.

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

Each player in `players.count` is spawned at a passable tile (not water) with at least `map.start_quality_min` passable tiles inside radius `map.start_quality_radius`. Pairwise hex distance is at least `map.start_min_distance`. The human is `players.human_index`. Everyone else is a rival with no AI yet. `players.starting_units` is `["settler", "warrior"]`, spawned on that tile in order through `spawn_unit`. One civilian and one combatant share the start tile. Sprites are instances of `scenes/actors/unit.tscn` on the y-sorted `Actors` node, tinted with `players.colors` through `assets/art/team_tint.gdshader`. A unit whose tile is not currently visible to the human is not instanced. Units that share a tile are drawn side by side, 72 px between centers. A unit alone stays on the cell center. `scenes/actors/hp_bar.tscn` is a child of each sprite and is hidden when max HP is 0.

`GameSetup.spawn_unit(player, type, pos)` is the only way to create a unit. `pos` is an odd-r offset cell, the same space as `UnitState.cell`. It rejects an unknown type, a bad player, impassable land, and an illegal stack, then recomputes fog. Starting units go through it.

`FogState` keeps unrevealed / revealed / visible **per player** in core. At game start every tile is unrevealed, then each unit reveals a disk of `fog.unit_vision`. A city reveals a disk of its territory radius plus `fog.city_vision_beyond_border`. `FogState.recompute` drops visible tiles to revealed, then marks the current disks. The view draws the human's fog. An unrevealed cell is erased from the terrain `TileMapLayer`, so its atlas does not depend on the land type, and a neutral fill (`fog.hidden_color`) covers the hole. A revealed-but-not-visible cell keeps its land tile and is dimmed with `fog.dim_color`. Visible cells are uncovered. The hover tooltip shows the land id for revealed and visible tiles. An unrevealed tile shows axial coordinates and the word Unexplored, never the land id.

Rival units are drawn only while their tile is visible. A rival city is drawn once its tile has been explored, and a territory edge is drawn once that owned tile has been explored. Both stay as last-known information after they leave vision. The distance rule still sees cities that have never been explored; the reason text does not reveal them.

The camera starts centered on the human settler, at `camera.default_zoom`.

## Movement and founding

`Pathfinder.reachable` searches axial hexes and returns movement points left on arrival. The origin is omitted. `GameSetup.reachable_tiles` converts that result to offset cells. The cost is the land of the tile entered (`land.*.move_cost`). Water is impassable. When `movement.allow_enter_over_budget_if_mp_left` is true and any points remain, a costlier tile can still be entered; arrival leaves 0 points and the search does not continue. Another player's unit blocks the tile. `units.one_military_and_one_civilian_per_tile` allows one combatant and one non-combatant together and rejects a second of the same kind.

A left click selects the human unit on that tile. Several human units on one tile cycle, civilian first, and the human's city on that tile comes after the last unit. An empty tile clears the selection. Reachable tiles and the selected tile are instances of `scenes/view/move_highlight.tscn`, using `tile_highlight.png`. The sprite offset is read from the TileSet at runtime. Attackable tiles use the same scene tinted red. A right click on a visible enemy attacks and does not move. A right click on an empty highlighted tile moves the selected unit. A left click never moves. A left drag farther than 8 px still pans. Middle drag, arrow keys, and the wheel are unchanged. `End Turn` and the Enter key (`end_turn`) heal idle units, increment one global turn, and refill every unit from its config move. When a human unit still has movement and no order, the first press warns (`End anyway (Enter)`) and the second press confirms. Enter does nothing while the in-game menu is open, and a focused control still receives Enter first. Rivals do not act. Fog recomputes after each move and attack.

`%FoundCityButton` reads **Found City (B)**. The `found_city` input action is B. `%FoundCityReason` shows why the button is disabled:

- `Select a settler`
- `Cannot found on water`
- `Cannot found on another player's tile`
- `Too close to another city`
- `Cannot found off the map`

Distance is center to center. Less than `city.min_distance` rejects, including a city under fog. Exactly that distance accepts. Founding does not spend movement. It consumes the settler, stores population 1, and claims a disk of `city.border_start_radius`. Water is claimed only when `borders.can_claim_water` is true. An owned tile is left alone when `borders.can_claim_owned_tiles` is false. Own territory can be founded on when the distance rule passes. Names come from `players.city_names`, one non-empty list per player. Past the end of a list, the last name is reused with a number (`Only`, then `Only 2`).

Cities are instances of `scenes/view/city_marker.tscn` on `Actors`, tinted with the owner's color. Territory edges are instances of `scenes/view/border_segment.tscn` under `%Borders`, one segment per outer edge of an explored owned tile. `players.city_names` is one non-empty name list per player. Details of movement and founding live in `docs/movement_and_founding.md`.

## Combat and orders

`Combat.damage` is `30 × 1.04^(attack − defense)`, then `roundi`, then clamped to `combat.min_damage`..`combat.max_damage`. Hills (`combat.hills_defense_multiplier`) and Fortify (`1 + units.fortify_defense_bonus`) multiply the defender's strength and stack. HP does not change strength. Melee is adjacent and the defender strikes back. An archer shoots to `units.archer.range` with no counter, and uses defense 12 when struck in melee. A hit sets the attacker's movement to 0. A unit at 0 HP is removed and the attacker does not step onto that tile. A settler cannot be targeted. Only a currently visible enemy can.

Skip (`skip_unit`, S) and Fortify (`fortify_unit`, F) are orders. Fortify lasts until the unit moves. Healing is `units.heal` at the end of the global turn, after cities and before movement is refilled, only for a unit that did not move or attack, capped at max HP. `%CombatPreview` and the hover tooltip show predicted damage and counter-damage. The formula, reasons, and the End Turn confirm are in `docs/combat.md`.

## Cities

`CityRules` is the yield, growth, and border math. `GameSetup` stores the queue and the buildings and applies a turn. Every city resolves on the global End Turn, before the turn counter increments: growth, then production, then one border claim. Rivals have no turn of their own yet, so their cities use that same clock.

The center always adds its land yield plus `city.center_food` and `city.center_production`. Each population point works one other owned tile. The order is higher food + production, then higher food, then nearer the center, then smaller axial q, then smaller r. Building bonuses are city-wide and are not part of that choice. Mana on the panel is `city.mana_base + floor(population / city.mana_per_population_divisor)`, plus `buildings.mana_well_mana` for each Mana Well. It is this city's per-turn output. There is no player mana pool.

Surplus food fills a bar of `city.growth_base + city.growth_per_population * population`. Crossing it adds 1 population and subtracts the threshold; leftover food can cross the next threshold in the same turn. A shortfall drains the bar when `growth.shortfall_drains_bar` is true, and at 0 the city loses `growth.starve_population_loss` population, not below `growth.starve_population_min`.

Every `city.border_turns_per_growth` turns the city claims one tile, adjacent to its own territory, within `city.border_max_radius`, using the same yield order. Water and already-owned tiles follow `borders.can_claim_water` and `borders.can_claim_owned_tiles`. `city.radius` becomes the distance of the farthest owned tile, and city vision stays a disk of that radius plus `fog.city_vision_beyond_border`.

The queue spends stored production on its first item. Costs are `units.<type>.cost` and `buildings.costs.*`. Finishing a settler requires population at least `units.settler.min_city_size`, then subtracts `units.settler.population_cost` and spawns through `spawn_unit` (city center, otherwise the nearest free passable tile inside the borders). Other units spawn the same way with no population cost. A building is chosen onto a border tile that is not the center and has no building; the click stores that tile on the queue item. A Granary adds `buildings.granary_food`. A Lumber Mill adds `buildings.lumber_mill_production_per_adjacent_forest` for each forest on the six neighbors of its tile. Cancelling the front item discards stored production. An empty queue banks nothing.

`%CityPanel` opens on a left click of the human's city. If that tile also has the human's unit, the first click selects the unit and the next click selects the city. Right click still moves. Enter still ends the turn. Queue rows are `scenes/ui/queue_row.tscn`. Building markers are `scenes/view/building_marker.tscn`. The full rules and the placement reasons are in `docs/cities.md`.

No new config keys were added. The rules read the existing `city`, `growth`, `buildings`, `units`, and `borders` keys.

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

Play the game with `godot --path .`. Left-click the start tile to select the settler, and again to select the warrior. Right-click a green tile to move. Right-click a red enemy tile to attack. S skips and F fortifies. B or **Found City** founds a city. Left-click the city to open its panel, then click a build button (for a building, click a highlighted tile next). Enter or **End Turn** ends the turn. If units still have moves, that press warns and the next one confirms. The turn resolves healing, growth, production, and borders. F9 opens Victory, F10 opens Defeat, Escape toggles the in-game menu.

## Rules for agents

If you change architecture, conventions, or these commands, update `AGENTS.md`, `.cursor/rules/godot.mdc`, and `docs/` in the same change.

Commit `.import` and `.uid` files. Do not commit `.godot/` or `builds/`.
