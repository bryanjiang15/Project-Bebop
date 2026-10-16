# Agent Guide for Project Bebop

This guide helps local AI agents understand the codebase, make changes safely, and maintain consistency.

## What is Project Bebop?

Project Bebop is a turn-based tactical mech combat game built in Godot 4.7. The player manages a single mech with multiple parts (torso, arms, legs, head) against waves of enemies. Each turn, the player has a shared time budget to spend on attacks, blocks, and movement. Enemies have countdown timers that tick down with every action, and interrupt mid-turn when they reach zero. The core challenge is sequencing actions efficiently while managing interrupts, blocks, and positioning. This is Milestone 1: a greybox 3D prototype proving the core combat loop.

## Stack

- **Engine**: Godot 4.7 stable
- **Language**: GDScript
- **Rendering**: Greybox 3D. Parts and enemies are box meshes
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
│   ├── combat_controller.gd  # Reads scene nodes, fills combat data
│   └── utils/              # Visual and card scripts
│       ├── mech_visual.gd
│       ├── part_visual.gd
│       ├── enemy_visual.gd
│       └── enemy_card.gd
├── scenes/
│   ├── combat/combat_scene.tscn  # Camera, lights, anchors, full UI
│   ├── ui/                       # part_button, move_button, enemy_card
│   ├── mech/*.tscn               # Socket hierarchy and part meshes
│   └── enemies/enemy.tscn        # Enemy mesh and click area
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
- `scripts/combat_controller.gd` connects signals and writes combat data into nodes that already exist in `combat_scene.tscn`. It references them with `@onready var x: Type = %UniqueName`.
- Repeated widgets (`part_button`, `move_button`, `enemy_card`) are separate scenes, instanced into `PartList`, `MoveList`, and `EnemyCardRow`.
- Renaming or moving a `%UniqueName` node requires the matching script update.
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
- Thresholds are `stun.mech_threshold` (60), `stun.drone_threshold` (20), and `stun.miniboss_threshold` (60).
- Stunned units take `stun.damage_multiplier` (1.5) damage.
- `add_stun` sets `stun_immunity_turns` to `stun.immunity_duration_turns` + 1 (config is 1, so the counter starts at 2). Turn reset decrements it.
- If an enemy is stunned after it has already acted, `stun.enemy_countdown_delay` (4) is stored and added to its countdown when the countdown resets.

### Damage and Destruction
- Attacks target a single enemy and a height (low, mid, high).
- Damage order: base damage → weapon bonus → Gunner pilot → chain → stun → block → round down.
- Each mech part has independent HP. When a part reaches 0 HP, it is destroyed and its moves are unavailable.
- If the torso is destroyed, the fight ends immediately (loss).
- If all enemies are destroyed, the fight ends immediately (win).

## Naming and Structure Conventions

### Part Naming
- Runtime part slots: `torso`, `left_arm`, `right_arm`, `legs`, `head`.
- Config variants live under `parts.<slot>.<variant>`: `parts.torso.balanced`, `parts.arm.sword`, `parts.arm.bare_hand`, `parts.legs.standard`. Left and right arms both use the `arm` slot.
- Scene files: `scenes/mech/part_torso.tscn`, `part_arm.tscn`, `part_legs.tscn`, `part_head.tscn`.

### Socket Hierarchy
Mech visual structure (from root to leaves):
```
Mech (Node3D)
└─ Legs (Node3D)
   └─ HipSocket (Marker3D)
      └─ Torso (Node3D)
         ├─ HeadSocket (Marker3D)
         ├─ ArmSocket_L (Marker3D)
         └─ ArmSocket_R (Marker3D)
```
- Sockets are positioned at joint attachment points.
- Crouch/jump animations tween socket positions.

### Coordinate System
- **1 unit = 1 meter**.
- **Y-up**.
- `Camera3D` is orthographic, size 8, at `(-5, 3, 8)`, rotated `-15°` on X, so it looks down `-Z`.
- `MechAnchor` is at `(-2, 0, 0)`. `EnemyAnchor` is at `(3, 1, 0)`; enemies are spaced on Z.

### Materials
Each part and enemy mesh uses one `StandardMaterial3D`. Color comes from the `part_color` / `enemy_color` export. Highlight and targeting turn emission on.

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

- **Building layout in code**: Static nodes belong in the `.tscn`. `@onready` / `%UniqueName` only sees nodes that are already in the scene when it enters the tree. Buttons and cards created with `instantiate()` are held in the variable `instantiate()` returns.
- **Renaming a unique node**: `%TimeLabel` is the node name. Renaming it in the editor without updating the script makes the scene fail at ready.
- **Forgetting to run the smoke test**: The smoke test drives one turn through the controller. Run it after changes to action execution or scene node names.
- **Assuming CI = playable**: Headless tests catch logic bugs, not layout or input. Open the editor and play the change.

## Quick Reference

**Main entry point**: `scenes/combat/combat_scene.tscn` (uses `scripts/combat_controller.gd`)

**Core combat logic**: `scripts/core/combat_state.gd`

**Config loading**: `scripts/core/config_manager.gd`

**Unit test runner**: `tests/run_tests_simple.gd` (extends `SceneTree`)

**Smoke test**: `tests/test_combat_scene_smoke.tscn` (drives one turn, asserts state changes)

**Restart to reload config**: Press **R** in-game or call `controller._on_restart_pressed()`
