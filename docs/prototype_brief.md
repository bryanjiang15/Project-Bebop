# Project Bebop - Milestone 1 Prototype Brief

**Source**: https://app.notion.com/p/3fa6a690fbd281cf8a1ac1fbe04baa59

**Note**: Notion is the source of truth. This file is a snapshot for local reference. Check Notion for the latest requirements and design decisions.

---

## Overview

Project Bebop is a turn-based tactical mech combat game. Milestone 1 is a greybox 3D prototype proving the core combat loop.

## Core Concept

The player controls a single mech with multiple parts (torso, left arm, right arm, legs, optional head). Each turn, the player has a **shared time budget** to spend across all actions. Enemies have **countdown timers** that tick down with every player action. When an enemy's countdown reaches 0, it **interrupts immediately** and acts mid-turn.

The core tension: do you spend time on heavy attacks (more damage, more countdown ticks) or lighter attacks (less damage, but less opportunity for interrupts)?

## Milestone 1 Scope

### Must Have (Playable Core)
- **Combat System**:
  - Time budget per turn (shared across all parts)
  - Enemy countdowns that tick down with each action
  - Interrupts when countdown reaches 0 (left-to-right order)
  - Enemies act at most once per turn
  - Turn-end processing (enemies act if countdown > 0)

- **Actions**:
  - **Attacks**: Light (cost 2), Medium (cost 3), Heavy (cost 5)
  - **Blocks**: Height-based (low, mid, high), cost 1 per block
  - **Movement**: Crouch, Jump, Stand (cost 1 for state changes)

- **Damage System**:
  - Base damage by attack level
  - Weapon bonuses (Sword, Hammer, Rifle, Bare Hand)
  - Chain bonus: Light → Medium → Heavy in sequence = Heavy x1.5 damage
  - Stun damage bonus: +50% when target is stunned
  - Block damage reduction: 60% base, 90% cap, stackable blocks (best one applies)
  - Guard pilot bonus: +15 points to block if Guard's part is blocking
  - Gunner pilot bonus: +2 damage to all attacks
  - Round down final damage

- **Height Rules**:
  - Crouch blocks high attacks (whiff)
  - Jump blocks low attacks (whiff)
  - Attacks and blocks have height (low, mid, high)

- **Stun System**:
  - Stun meter (0-100), fills with attack stun values
  - Threshold: 60 for player mech, varies for enemies
  - When threshold reached: target is stunned for 1 turn
  - Stunned unit takes +50% damage, cannot act
  - After stun ends: 2 turns of stun immunity
  - Stun delay: if stun triggers after enemy acted this turn, delay is added to countdown after turn-end reset

- **Part Destruction**:
  - Each part has independent HP
  - Part at 0 HP is destroyed, moves unavailable
  - Torso destruction = immediate loss
  - All enemies destroyed = immediate win

- **Fixed Build**:
  - Torso: Balanced (100 HP)
  - Left Arm: Bare Hand (50 HP, +0 damage)
  - Right Arm: Sword (50 HP, +2 damage)
  - Legs: Standard (75 HP)
  - No head (optional part, not in M1 default build)

- **Pilots**:
  - Commander: Focus ability (+2 time, once per fight)
  - Gunner: +2 damage to all attacks
  - Guard: +15 points to block when Guard's part is blocking

- **Encounter E1 (Swarm)**:
  - 3 drones
  - Turn 1 stagger: D1 countdown 4, D2 countdown 5, D3 countdown 6
  - After turn 1: use per-move countdowns (light 5, medium 7)
  - Each drone: 30 HP, light and medium attacks

### Greybox Visual Style
- 3D orthographic camera (side view, left-to-right)
- Simple mesh primitives (boxes, cylinders, spheres)
- Procedural materials (body, accent, glow)
- No textures, no sprites
- Modular mech with socket hierarchy
- Crouch and jump via socket position tweening

### UI
- Time budget bar with cost preview
- Part buttons (click to select part)
- Move buttons (click to select attack/block/movement)
- Enemy cards: countdown (red when at 0), next move telegraph, HP, stun meter
- Turn log (scrollable, color-coded events)
- Action panel (shows selected part, move, target, confirm/cancel buttons)
- Win/loss screen with summary and Retry

### Config System
- All tunables in `config/game_config.json`
- Press **R** in-game to reload config
- Covers: damage, costs, HP, countdowns, stun thresholds, block values

### Testing
- Automated unit tests (GUT framework or custom)
- Playability verification script (can E1 be won and lost?)
- Scene load smoke test (headless, 120 frames)

### Not in Scope for M1
- Setup screen (build customization, part pool)
- Encounter E2 (Brawler mini-boss)
- Visual polish, VFX, audio
- Debug tuning panel
- Multiple encounters, retry flow with progression
- Pilot skill trees

## Success Criteria

At the end of M1:
1. E1 Swarm encounter is **playable** from start to finish
2. Combat rules are **correct** (verified by tests)
3. UI clearly shows **time budget, countdowns, and interrupts**
4. Config reload works (press R to test balance changes)
5. Win and loss conditions trigger correctly
6. The game runs on macOS, Windows, and Linux
7. Codebase is **testable** and **well-structured** for future milestones
