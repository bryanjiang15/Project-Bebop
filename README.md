# Project Bebop - Milestone 1

A turn-based mech combat prototype built in Godot 4.7 with GDScript.

## Documentation

- **[AGENTS.md](AGENTS.md)** - Guide for AI agents and developers: repository structure, conventions, testing workflow
- **[.cursor/rules/godot.mdc](.cursor/rules/godot.mdc)** - GDScript and Godot 4.7 coding standards (auto-applied in Cursor)
- **[docs/prototype_brief.md](docs/prototype_brief.md)** - Milestone 1 requirements and scope
- **[docs/rules_clarifications.md](docs/rules_clarifications.md)** - Design decisions and edge case resolutions

## Overview

Project Bebop is a tactical mech combat game where players manage a time budget across their turn, choosing when to attack, block, and move while enemy countdowns tick down. Heavy attacks do more damage but give enemies more opportunities to interrupt mid-turn.

This is **Milestone 1**: a playable greybox prototype focused on proving the core combat mechanics.

**Requirements: Godot 4.7 stable**

## Quick Start

### Option 1: Download Prebuilt macOS Build (Easiest)

1. Go to the [Actions tab](../../actions) in this repository
2. Click the latest successful "Build and Test" workflow run
3. Download the `bebop-macos-4.7` artifact (universal binary: x86_64 + ARM64)
4. Unzip the downloaded file
5. **Important**: Remove macOS quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine Bebop.app
   ```
6. Double-click `Bebop.app` to run

**Note**: The build is unsigned, so macOS Gatekeeper will block it unless you remove the quarantine attribute.

### Option 2: Open in Godot Editor

### Requirements
- **Godot 4.7 stable** (or later 4.x version)
- Linux, Windows, or macOS

### Steps
1. Download and install Godot 4.7 from https://godotengine.org/
2. Open Godot and click "Import"
3. Navigate to this folder and select `project.godot`
4. Click "Import & Edit"

The project will open in the Godot editor. Press **F5** or click the Play button to run.

## Running the Game

### From Godot Editor
- Press **F5** or click the Play button in the top-right
- The combat scene will load with the default build vs. the Swarm encounter (3 drones)

### Controls
- **Mouse**: Click to select parts, moves, and targets
- **Space / Enter (Confirm)**: Execute selected action
- **Escape (Cancel)**: Cancel current selection and go back
- **E (End Turn)**: End turn early, unspent time is lost
- **R (Restart)**: Restart the current fight and reload config

All hotkeys are customizable in Project → Project Settings → Input Map.

### Flow
1. Click a mech part (torso, left arm, right arm, legs)
2. Click a move (attack, block, or movement)
   - Move preview shows: time cost and which enemies would interrupt (highlighted in red)
   - Time budget bar shows remaining time after the move
3. For attacks: click an enemy to target
4. Click Confirm or press Space/Enter to execute
5. Repeat until time budget is spent or End Turn (E key)

### UI Elements
- **Time Budget Bar**: Shows remaining time (blue) and preview after selected move (faded)
- **Mech Panel** (left): HP per part, active blocks, movement state, stun meter
- **Enemy Cards** (right): Countdown (red when at 0), next move, HP, stun meter
  - Highlighted in red border when they would interrupt after your selected move
- **Turn Log** (bottom center): Scrollable event log with color coding
- **Callouts**: Large on-screen messages for HIT, WHIFF, BLOCKED, STUNNED

## Running Tests

### From Godot Editor
1. Enable the GUT plugin: Project → Project Settings → Plugins → Enable "Gut"
2. Bottom panel: select "Gut" tab
3. Click "Run All"

### Headless (Command Line)
```bash
godot --headless --script tests/run_tests_simple.gd
godot --headless --script tests/verify_e1_playable.gd
```

Tests cover:
- Interrupt timing and left-to-right ordering
- One action per enemy per turn
- End-of-turn reset and stun delay carry-over
- Block math (best block, Guard bonus, 90% cap)
- Movement state whiffs (crouch blocks high, jump blocks low)
- Damage order of operations (base, weapon, Gunner, chain, stun, block, round down)
- Stun threshold and immunity
- Part destruction and torso loss

## Configuration

All tunable values are in `config/game_config.json`. Edit the JSON and press **R** in-game to reload.

Key values:
- `combat.time_budget_base`: Starting time per turn (default: 10)
- `attacks.light/medium/heavy`: Cost, damage, and stun per attack level
- `blocking.damage_reduction`: Base block percentage (default: 60%)
- `stun.mech_threshold`: Stun threshold for the player (default: 60)
- `parts`: HP and stats for each part variant
- `encounters`: Enemy HP, moves, and countdowns

## Turn Logs

Every fight exports a JSON log to the user data folder:
- **Linux**: `~/.local/share/godot/app_userdata/Project Bebop/`
- **Windows**: `%APPDATA%\Godot\app_userdata\Project Bebop\`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/Project Bebop/`

Logs include every move, interrupt, hit/whiff/block, stun trigger, and part destruction.

## Milestone 1 Scope

### Included
- ✅ Core combat rules (time budget, countdowns, interrupts, turn order)
- ✅ Light, medium, heavy attacks with different costs and damage
- ✅ Movement states (standing, crouching, airborne) with whiff rules
- ✅ Height-based blocking (low/mid/high) with best-block + Guard + 90% cap
- ✅ Simple chain bonus (light → medium → heavy gives heavy x1.5 damage)
- ✅ Stun meter with threshold, damage bonus, immunity, and delay carry-over
- ✅ Part HP and destruction, torso loss = defeat
- ✅ Encounter E1 (Swarm): 3 drones with staggered turn-1 countdowns
- ✅ Fixed default build (Balanced torso, Bare Hand left, Sword right, Standard legs)
- ✅ Commander Focus ability (+2 time, once per fight)
- ✅ Support pilots (Gunner: +damage, Guard: +block)
- ✅ Greybox 3D with orthographic side camera
- ✅ Modular mech with socket hierarchy (legs > hip > torso > head/arms)
- ✅ Crouch and jump poses via socket tweening
- ✅ Time budget bar with cost preview
- ✅ Enemy cards (countdown, telegraph, HP, stun meter)
- ✅ Turn log display and JSON export
- ✅ Win/loss screen with summary and Retry
- ✅ Restart button and hotkey (reloads config)
- ✅ Automated tests (GUT framework)
- ✅ JSON config system

### Not Included (Future Milestones)
- ❌ Setup screen with part pool and build customization
- ❌ Encounter E2 (Brawler mini-boss)
- ❌ Visual polish, VFX, audio
- ❌ Debug tuning panel for live value editing
- ❌ Multiple encounters and retry flow
- ❌ More pilot abilities or skill trees

## Known Issues & Ambiguities Resolved

### Design Decisions Made
1. **Stun delay timing**: If an enemy is stunned after it has already acted this turn, the delay is added to its countdown after the turn-end reset (for next turn). This prevents the delay from being wasted.

2. **Drone turn-1 stagger**: D1 starts at countdown 4, D2 at 5, D3 at 6. After turn 1, they use their per-move countdowns (light 5, medium 7). This prevents all three from interrupting together immediately.

3. **Chain rules**: Only attacks count toward the chain. Light → medium → heavy must be consecutive attacks in the same turn. Blocks, movement, and enemy interrupts between attacks do not break the chain.

4. **Block stacking**: Take the best single block covering the attack height, add Guard (+15 points) if the Guard pilot's part is one of the active blocks, then cap at 90%.

5. **Movement and leg blocks**: Any movement state change drops an active leg block. You cannot crouch and keep a low block in the same action. Jumping also clears the leg block.

6. **Overhead targeting**: The Brawler's Overhead targets the head if equipped, otherwise the torso (not an arm like other high attacks). This is not implemented in M1 since E2 is out of scope.

## Testing Checklist

Before submitting:
- [ ] Project opens in Godot 4.3 without errors
- [ ] E1 fight loads and is playable
- [ ] All part buttons work and show available moves
- [ ] Attacks deal correct damage (check chain and stun bonuses)
- [ ] Blocks reduce damage correctly (verify cap)
- [ ] Crouch blocks high attacks, jump blocks low attacks
- [ ] Enemy interrupts trigger at countdown 0
- [ ] Each enemy acts at most once per turn
- [ ] End Turn works and enemies act in order
- [ ] Stun triggers at threshold for both sides
- [ ] Part destruction removes moves
- [ ] Torso loss ends fight immediately
- [ ] Killing last enemy ends fight immediately
- [ ] Restart reloads config
- [ ] Turn log exports to user data folder
- [ ] All automated tests pass headless

## Building Exports (Optional)

If export templates are installed:

```bash
# Linux
godot --export-release "Linux/X11" builds/bebop_linux.x86_64

# Windows (from Linux)
godot --export-release "Windows Desktop" builds/bebop_windows.exe

# macOS (from macOS)
godot --export-release "macOS" builds/bebop_macos.zip
```

Builds will be placed in the `builds/` folder.

## Contact

For questions or feedback about this milestone, contact Bryan or the design team.

---

**Built with Godot 4.3**  
**Milestone 1 - October 2026**
