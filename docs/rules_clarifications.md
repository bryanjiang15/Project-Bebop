# Project Bebop - Rules Clarifications and Addenda

**Source**: https://app.notion.com/p/3fa6a690fbd281cf8a1ac1fbe04baa59

**Note**: Notion is the source of truth. This file is a snapshot for local reference. Check Notion for the latest clarifications and design decisions.

---

## Design Decisions and Clarifications

This document records ambiguities resolved during Milestone 1 implementation.

### 1. Stun Delay Timing

**Question**: If an enemy is stunned after it has already acted this turn, when does the 1-turn stun delay take effect?

**Decision**: The stun delay is added to the enemy's countdown **after the turn-end reset**. This prevents the delay from being wasted. The amount is `stun.enemy_countdown_delay` in `config/game_config.json` (4).

**Example**:
- Enemy acts at countdown 0 (interrupts mid-turn)
- Player's next action fills enemy's stun meter past threshold
- Enemy is stunned, sets `stun_delay = 1`
- At turn end: enemy's countdown is reset to its next move's countdown, **then** `stun_delay` is added
- Next turn: enemy cannot act (stunned), and the delay is still active

### 2. Drone Turn-1 Countdown Stagger

**Question**: How do we prevent all three drones from interrupting together on turn 1?

**Decision**: Stagger their initial countdowns:
- D1 (Drone 1) starts at countdown 4
- D2 (Drone 2) starts at countdown 5  
- D3 (Drone 3) starts at countdown 6

After turn 1, all drones use their per-move countdowns (light attack: 5, medium attack: 7).

**Why**: This ensures they don't all reach 0 at the same time during the first few player actions, giving the player time to understand the interrupt flow.

### 3. Chain Bonus Rules

**Question**: Do blocks or movement actions between attacks break the chain?

**Decision**: No. Only **attacks** count toward the chain sequence (Light → Medium → Heavy). Blocks, movement, and enemy interrupts **do not** break the chain.

**Example of valid chain**:
1. Light attack
2. Block mid
3. Medium attack (chain still active)
4. Enemy interrupt
5. Heavy attack (chain completes, Heavy gets x1.5 damage multiplier)

**Example of broken chain**:
1. Light attack
2. Medium attack
3. Light attack (chain broken, because you didn't do Heavy after Medium)

### 4. Block Stacking and Guard Bonus

**Question**: If the player has multiple active blocks (different parts, different heights), how is damage reduction calculated?

**Decision**:
1. Find the **best single block** that covers the attack height
2. Add **Guard pilot bonus** (+15 points) if the Guard pilot's assigned part is one of the active blocks (regardless of height)
3. Cap final reduction at **90%**

**Example**:
- Player has: Torso block mid (60%), Left Arm block low (60%)
- Guard pilot assigned to Torso
- Enemy attacks mid height
- Calculation: 60% (best block for mid) + 15% (Guard bonus) = 75% reduction

**Example (Guard part not blocking)**:
- Player has: Right Arm block high (60%)
- Guard pilot assigned to Torso
- Enemy attacks high
- Calculation: 60% (only block covering high), no Guard bonus = 60% reduction

### 5. Movement State Changes and Leg Blocks

**Question**: If the player has an active leg block, what happens when they crouch or jump?

**Decision**: Any movement state change (Stand → Crouch, Stand → Jump, etc.) **clears an active leg block**.

**Why**: You cannot hold a blocking stance while transitioning between movement states. The leg is busy moving.

**Example**:
1. Player blocks low with legs (cost 1, legs.is_blocking = true)
2. Player jumps (cost 1, movement state = airborne, legs.is_blocking = false)
3. Low block is no longer active

### 6. Overhead Attack Targeting (Not Implemented in M1)

**Question**: The Brawler's Overhead attack targets the head. What if the mech has no head equipped?

**Decision**: Overhead attacks target the **head if equipped**, otherwise the **torso** (not an arm).

**Note**: The Brawler and Overhead attack are out of scope for Milestone 1 (Encounter E2), so this is not implemented yet. This clarification is recorded for M2.

### 7. Attack Height and Targeting

**Question**: Can the player choose which enemy part to target (head, torso, legs)?

**Decision**: No. Attacks target **the enemy as a whole**. The player chooses an attack height (low, mid, high), and the enemy is damaged if the attack is not blocked or whiffed.

**Why**: Simplified for M1. Part-specific targeting may be added in future milestones if needed.

### 8. Time Budget Sharing

**Question**: Is time budget per-part or shared?

**Decision**: **Shared across all parts**. The mech has one time budget (default: 10 per turn), and every action subtracts from it.

**Why**: This forces strategic choices about which parts to use and when. Using multiple parts in one turn is possible but expensive.

### 9. Enemy Interrupt Order

**Question**: If multiple enemies reach countdown 0 during the same player action, who acts first?

**Decision**: **Left-to-right** (lowest index first). The game processes enemies in array order.

**Example**:
- Player uses Heavy attack (cost 5)
- Before the attack, D1 has countdown 3, D2 has countdown 2
- Both reach countdown 0 after this action
- D1 interrupts first, then D2

### 10. One Action Per Enemy Per Turn

**Question**: If an enemy interrupts mid-turn and its countdown is reduced to 0 again by another player action, does it act again?

**Decision**: No. Enemies can act **at most once per turn**, even if their countdown reaches 0 multiple times.

**Implementation**: `enemy.has_acted_this_turn` is set to `true` after the enemy acts. This flag is reset at turn end.

### 11. Turn-End Action Order

**Question**: At the end of the player's turn, which enemies act and in what order?

**Decision**:
1. Process enemies **left-to-right**
2. Each enemy acts if:
   - `countdown > 0` (hasn't acted yet this turn)
   - Not destroyed
   - Not stunned
3. Enemy ticks its own countdown down to 0 and acts
4. After all enemies have acted (or skipped), reset for next turn

### 12. Focus Ability Timing

**Question**: When can the Commander use Focus?

**Decision**: Focus can be used **once per fight** and adds **+2 time** to the current turn's budget. It must be used before the turn ends (i.e., while time budget > 0).

**Note**: M1 implementation has Focus as a button in the UI. It does not cost an action slot.

### 13. Config Reload Behavior

**Question**: What happens when the player presses **R** to reload config?

**Decision**: The fight **restarts completely** with the new config values. Current state is discarded.

**Why**: This allows rapid iteration on balance without restarting the game or needing a debug panel.

### 14. Part Destruction and Move Availability

**Question**: If a part is destroyed, are its moves still available?

**Decision**: No. Destroyed parts (HP = 0) do not appear in the part selection UI and their moves cannot be used.

**Example**:
- Right Arm (Sword) is destroyed
- Sword's attack moves are no longer available
- Player must use moves from other parts

### 15. Whiff Conditions

**Question**: What happens if an attack whiffs?

**Decision**:
- **High attack** vs. **crouching target**: Whiff (no damage, no stun)
- **Low attack** vs. **airborne target**: Whiff (no damage, no stun)
- **Mid attack**: Never whiffs based on movement state (mid height is always valid)

**Damage Calculation**: If the attack whiffs, damage = 0 before block calculation (block doesn't matter).

### 16. Damage Order of Operations (Final Clarification)

The correct order for damage calculation:
1. **Base damage** (from attack level: light, medium, heavy)
2. **+ Weapon bonus** (Sword +2, Hammer +3, etc.)
3. **+ Gunner pilot bonus** (+2 if Gunner is assigned)
4. **x Chain multiplier** (x1.5 if Heavy completes Light → Medium → Heavy chain)
5. **x Stun multiplier** (x1.5 if target is stunned)
6. **- Block reduction** (best block %, + Guard bonus, cap 90%)
7. **Round down** to nearest integer

**Example**:
- Medium attack (base 7) with Sword (+2) and Gunner (+2) = 11
- Chain active, Heavy attack next (base 12 + 2 + 2 = 16)
- Heavy x1.5 chain = 24
- Target stunned: 24 x1.5 = 36
- Target blocking mid 60% + Guard 15% = 75% reduction → 36 x 0.25 = 9
- Final damage: 9
