# Agent Guide for Project Bebop

This guide helps local AI agents understand the codebase, make changes safely, and maintain consistency.

## What is Project Bebop?

Project Bebop is a turn-based tactical mech combat game built in Godot 4.7. The player manages a single mech with multiple parts (torso, arms, legs, head) against waves of enemies. Each turn, the player has a shared time budget to spend on attacks, blocks, and movement. Enemies have countdown timers that tick down with every action, and interrupt mid-turn when they reach zero. The core challenge is sequencing actions efficiently while managing interrupts, blocks, and positioning. This is Milestone 1: a greybox 3D prototype proving the core combat loop.

## Stack

- **Engine**: Godot 4.7 stable
- **Language**: GDScript
- **Rendering**: Greybox 3D with simple mesh primitives (boxes, cylinders)
- **Camera**: Orthographic, side view (left-to-right)
- **Assets**: Procedural materials only (body, accent, glow)

## Repository Layout

```
Project-Bebop/
├── scripts/
│   ├── core/               # Pure game logic (no Node dependencies)
│   │   ├── config_manager.gd
│   │   ├── combat_state.gd  # Main combat state machine
│   │   ├── mech_state.gd    # Player mech state
│   │   ├── mech_part.gd
│   │   ├── enemy_state.gd
│   │   ├── damage_calculator.gd
│   │   ├── block_calculator.gd
│   │   └── turn_log.gd
│   ├── combat_controller.gd  # Main scene controller (UI + visuals)
│   └── utils/              # UI and visual helpers
│       ├── mech_visual.gd
│       ├── part_visual.gd
│       ├── enemy_visual.gd
│       └── enemy_card.gd
├── scenes/
│   ├── combat/combat_scene.tscn  # Main combat scene
│   ├── mech/*.tscn               # Part visual templates
│   └── enemies/enemy.tscn        # Enemy visual template
├── tests/
│   ├── run_tests_simple.gd       # Unit tests (no GUT)
│   ├── verify_e1_playable.gd     # Playability verification
│   └── test_combat_scene_smoke.tscn/gd  # Smoke test
├── config/
│   └── game_config.json      # All tunables live here
└── docs/
    ├── prototype_brief.md
    └── rules_clarifications.md
```

**Core Principles**:
- `scripts/core/` contains pure GDScript classes with no `Node` or scene dependencies. They are instantiated directly with `.new()` and are fully unit-testable.
- `scripts/combat_controller.gd` and `scripts/utils/` handle all UI, input, visuals, and scene tree operations.
- All tunables (damage, costs, HP, countdowns) live in `config/game_config.json`.

## Core Combat Rules (Brief)

### Time Budget
- Player gets 10 time per turn (configurable in `combat.time_budget_base`).
- Attacks, blocks, and movement cost time.
- Time is shared across all mech parts (not per-part).
- Unused time is lost at turn end.

### Countdowns and Interrupts
- Each enemy has a countdown (set per move).
- Every player action ticks all enemy countdowns down by the action's cost.
- When an enemy's countdown reaches 0, it interrupts **immediately** and acts.
- **Turn order**: Enemies act left-to-right (lowest index first).
- Enemies act **at most once per turn**, even if countdown would reach 0 again.

### Height and Blocking
- Attacks and blocks have heights: low, mid, high.
- The player can have multiple active blocks at once (different parts, different heights).
- Damage reduction = best block covering the attack height, plus Guard pilot bonus (+15 points), capped at 90%.
- A crouch or jump **drops any active leg block** (movement state changes clear leg blocks).

### Chain Bonus
- Light → Medium → Heavy in sequence (no attacks skipped) multiplies Heavy damage by 1.5.
- Blocks and movement between attacks do not break the chain.
- Enemy interrupts do not break the chain.

### Stun
- Both mech and enemies have stun meters (0–100).
- When a stun meter reaches the threshold (60 for mech, varies for enemies), the unit is stunned for 1 turn.
- Stunned units take +50% damage and cannot act.
- After being stunned, the unit gains 2 turns of stun immunity.
- If stun is triggered after an enemy has already acted this turn, the stun delay (1 turn) is added to its countdown after turn-end reset.

### Damage and Destruction
- Attacks target a single enemy and a height (low, mid, high).
- Damage order: base damage → weapon bonus → Gunner pilot → chain → stun → block → round down.
- Each mech part has independent HP. When a part reaches 0 HP, it is destroyed and its moves are unavailable.
- If the torso is destroyed, the fight ends immediately (loss).
- If all enemies are destroyed, the fight ends immediately (win).

## Naming and Structure Conventions

### Part Naming
- Part slots: `torso`, `left_arm`, `right_arm`, `legs`, `head`.
- Part variant naming: `part_<slot>_<variant>` (e.g., `part_torso_balanced`, `part_arm_sword`).
- Config keys use the same naming.

### Socket Hierarchy
Mech visual structure (from root to leaves):
```
Mech (Node3D)
└─ Legs Socket (Node3D)
   └─ Hip Socket (Node3D)
      └─ Torso Socket (Node3D)
         ├─ Head Socket (Node3D)
         ├─ Left Arm Socket (Node3D)
         └─ Right Arm Socket (Node3D)
```
- Sockets are positioned at joint attachment points.
- Crouch/jump animations tween socket positions.

### Coordinate System
- **1 unit = 1 meter**.
- **Y-up** (Godot default).
- **+Z is forward** (into the screen in side view).
- Camera looks along +X axis (left to right).

### Materials
Each visual part has 3 material slots:
1. **Body** (main color)
2. **Accent** (secondary color)
3. **Glow** (emissive, used for highlights)

## Hotkeys

Default input actions (customizable in Project Settings → Input Map):
- **Confirm** (Space / Enter): Execute selected action
- **Cancel** (Escape): Go back one selection step
- **End Turn** (E): End turn early (unspent time is lost)
- **Restart** (R): Restart fight and reload config

Mouse is used for clicking parts, moves, and targets.

## Running and Testing

### Run the Game (Editor)
```bash
# Open in Godot Editor, then press F5
godot project.godot
```

### Run the Game (Headless, for testing scene load)
```bash
godot --headless --quit-after 120 res://scenes/combat/combat_scene.tscn
```

### Run Unit Tests
```bash
godot --headless --script tests/run_tests_simple.gd
```

### Run Playability Tests
```bash
godot --headless --script tests/verify_e1_playable.gd
```

### Run Smoke Test
```bash
godot --headless --quit-after 80 res://tests/test_combat_scene_smoke.tscn
```

**CI Pipeline**: All tests must pass before pushing. The GitHub Actions workflow (`.github/workflows/build.yml`) runs:
1. Unit tests
2. Playability tests  
3. Smoke test (drives one full turn through the controller)
4. Scene load verification (120 frames headless)
5. macOS export

### Local Testing Before Push
```bash
# Run all tests
godot --headless --script tests/run_tests_simple.gd
godot --headless --script tests/verify_e1_playable.gd
godot --headless --quit-after 80 res://tests/test_combat_scene_smoke.tscn

# Verify scene loads without errors
timeout 10 godot --headless --quit-after 120 res://scenes/combat/combat_scene.tscn 2>&1 | grep -E "SCRIPT ERROR|^ERROR:"
# (no output = success)
```

## Workflow Rules

1. **Never push directly to `main`**. All changes go through PRs from `cursor/*` branches.
2. **One PR per task**. Keep changes focused and scoped.
3. **Run tests before pushing**. CI must stay green.
4. **Update documentation when behavior changes**:
   - If you change core rules, update `docs/rules_clarifications.md`.
   - If you add features or change structure, update `AGENTS.md`.
   - If you add tunables, document them in comments near the config load site.
5. **Use the config for tunables**. Don't hardcode magic numbers as constants in GDScript.
6. **Keep `scripts/core/` free of Node dependencies**. This keeps the logic testable.
7. **Don't rely on headless tests alone** to prove something is playable. Open the editor and test interactively before claiming a feature works.

## Common Pitfalls

- **`@onready` and nodes created in `_ready()`**: Don't use `@onready` to reference nodes created procedurally in `_ready()`. The decorator runs before `_ready()`, so the node won't exist yet. Instead, assign references directly in `_ready()` after creating the node.
- **`$NodePath` for dynamic nodes**: Same issue. `$` syntax is compile-time and won't find nodes created at runtime. Use `get_node()` or direct references.
- **Forgetting to run the smoke test**: The smoke test exercises the full controller→combat→state flow. If you change action execution or turn logic, run it.
- **Assuming CI = playable**: Headless tests catch logic bugs but not visual bugs, missing UI updates, or interaction flows. Always test in the editor.

## Quick Reference

**Main entry point**: `scenes/combat/combat_scene.tscn` (uses `scripts/combat_controller.gd`)

**Core combat logic**: `scripts/core/combat_state.gd`

**Config loading**: `scripts/core/config_manager.gd`

**Unit test runner**: `tests/run_tests_simple.gd` (extends `SceneTree`)

**Smoke test**: `tests/test_combat_scene_smoke.tscn` (drives one turn, asserts state changes)

**Restart to reload config**: Press **R** in-game or call `controller._on_restart_pressed()`
