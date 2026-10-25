# Project Bebop

Turn-based terraforming 4X. This tree is the Godot 4.7 prototype: main menu, a seeded isometric hex map, fog of war, unit movement and combat, city founding, city yields, growth, borders, a production queue, a player mana pool, and five terraforming spells, plus victory and defeat placeholders, and one config file. AI comes in a later ticket.

Design sources, and the note that Notion wins over these copies, are in `docs/`.

## Run

Install [Godot 4.7 stable](https://github.com/godotengine/godot/releases/tag/4.7-stable) and open this folder, or from the repo root:

```bash
godot --path .
```

The main scene is the main menu. **New Game** generates a hex map, three players, and a settler plus a warrior for each, then opens the map centered on the human settler. The top bar shows the human's mana (`Mana: N (+M/turn)`) and the turn (`Turn N / 50`). Each player starts with 10 mana. **End Turn** (or Enter) resolves every city's growth, production, and border claim, adds each city's snapshotted mana to that player's pool, heals idle units, ticks spell cooldowns, and refills movement. The spell bar under the top bar casts Grow Forest, Raise Hills, Carve River, Ignite, and Restore Plains. If a human unit still has movement and no order, the first press warns and the next press confirms. Enter does nothing while the in-game menu is open. **Menu** has **Restart** (reloads config and starts another game) and **Main Menu**. Left-click a unit, then right-click a green tile to move or a red enemy tile to attack. **Skip** (S) and **Fortify** (F) are orders. **Found City** (or B) founds a city on the settler's tile and removes the settler. The button stays disabled, with a reason, when the tile is water, too close to a city, or owned by someone else. Left-click the city to open its panel. Click a unit or building to queue it. A building then needs a click on a highlighted tile inside the borders, not the city center.

| Input | Action |
| --- | --- |
| Left click | Select the human unit on that tile. Another click selects the city on that tile |
| Right click | Attack a visible enemy in range, or move onto a green tile |
| Left drag or middle drag | Pan |
| Arrow keys | Pan |
| Mouse wheel | Zoom |
| Hover | Tile coordinates. Land type only after the tile has been revealed. Damage and counter-damage over an enemy |
| B | Found a city with the selected settler |
| S | Skip the selected unit |
| F | Fortify the selected unit |
| Enter | End the turn, unless the in-game menu is open. A second Enter confirms the unordered-unit warning |
| F9 | Victory placeholder |
| F10 | Defeat placeholder |
| Escape | Toggle the in-game menu |

`map.seed` of `0` in `config/game_config.json` rolls a new seed every New Game and prints `map seed: <n>` so that game can be replayed. Any other seed repeats the map and the start positions. Unrevealed tiles are hidden. Rival units outside the human's vision are not drawn. A rival city and its borders stay visible once explored. The starting unit list is `players.starting_units` (a settler on the start tile, and a warrior on the nearest free tile). City names are `players.city_names`.

## Tests

On a fresh checkout, import once so Godot builds `.godot/`:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/expect_missing_key.gd   # must exit non-zero
godot --headless --path . --quit-after 120 res://scenes/main_menu.tscn
godot --headless --path . --quit-after 120 res://scenes/game.tscn
godot --headless --path . --script res://tests/smoke_game.gd
```

GitHub Actions runs those checks and exports an unsigned universal macOS build (`builds/bebop_macos_4.7.zip`).

## Config and art

All tunables are in `config/game_config.json`. Tile size and texture origin live only on `assets/art/bebop_tileset.tres` (face 128×108, origin `(0, -4)`). The greybox art in `assets/art/` is already isometric. See `AGENTS.md`.
