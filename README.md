# Project Bebop

Turn-based terraforming 4X. This tree is the Godot 4.7 skeleton: main menu, in-game isometric map, victory and defeat placeholders, hex math, and one config file. Gameplay comes in later tickets.

Design sources, and the note that Notion wins over these copies, are in `docs/`.

## Run

Install [Godot 4.7 stable](https://github.com/godotengine/godot/releases/tag/4.7-stable) and open this folder, or from the repo root:

```bash
godot --path .
```

The main scene is the main menu. **New Game** opens the map. The top bar shows the turn. **End Turn** increments it. **Menu** has **Restart** (reloads config and the map) and **Main Menu**.

| Input | Action |
| --- | --- |
| Left drag or middle drag | Pan |
| Arrow keys | Pan |
| Mouse wheel | Zoom |
| Hover | Tile coordinates and land type |
| F9 | Victory placeholder |
| F10 | Defeat placeholder |
| Escape | Toggle the in-game menu |

The map is a fixed 28×18 stripe of plains, forest, hills, water, and volcanic ground. It is not a generated world. One test settler and one test city sit on it, tinted blue and red, so the art pipeline is visible.

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
