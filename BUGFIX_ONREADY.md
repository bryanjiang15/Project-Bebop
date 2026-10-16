# Fix: @onready Node Path Errors

## Problem
Bryan encountered runtime crashes when pressing F5 in Godot 4.7 on macOS:
```
Node not found: "Camera3D" (relative to "/root/CombatScene")
Node not found: "VBox/NameLabel" (relative to ...)
```

## Root Cause
The `@onready` decorator evaluates when a node enters the scene tree, expecting child nodes to exist in the `.tscn` file. However, our scene files (`combat_scene.tscn`, etc.) contain only single root nodes with scripts attached. All child nodes (Camera3D, UI, meshes, etc.) are created procedurally in `_ready()`.

**Timeline issue**: `@onready` runs during scene tree entry, **before** `_ready()` executes, so the programmatically created nodes don't exist yet.

## Solution
Removed all `@onready` decorators from:
- `scripts/combat_controller.gd`: Changed `@onready var camera = $Camera3D` to `var camera`
- `scripts/utils/enemy_card.gd`: Changed `@onready var enemy_name_label = $VBox/NameLabel` to `var enemy_name_label`, added lazy `_create_ui()` call in `initialize()`

All procedural node creation happens in `_ready()` and nodes are assigned to the plain variables at that time.

## Verification
- Scene loads: `godot --headless --quit-after 100 res://scenes/combat/combat_scene.tscn` → exit 0, no errors
- Unit tests: 36/36 passed
- Playability: E1 win/loss scenarios both verified

All tests run cleanly with zero node path errors.
