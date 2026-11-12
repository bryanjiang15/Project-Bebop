# Agreed engineering defaults

Source: approved by Design Scribe and Bryan, 2026-10-17. There is no separate Notion page for this list.

Notion is the source of truth for the prototype brief and the design doc. This file is the approved engineering decision record. If the brief and the design doc disagree, the design doc wins. These defaults are prototype rules, and every one of them is a value or a flag in `config/game_config.json`.

1. Buildings (Granary, Mana Well, Lumber Mill) are placed on a player-chosen tile inside the city's borders. One building per tile; not on the city center. Lumber Mill counts forests adjacent to its own tile. Turning that tile to water destroys the building. Flag: `buildings.buildings_on_worked_tiles`.
2. Combat strength: one strength per unit (scout 5, warrior 20); archer 25 when shooting, 12 when defending; city 15. Counter-damage uses the defender's strength vs the attacker's. HP doesn't reduce strength. Hills multiply the defender's strength by 1.25.
3. One unit per tile, civilian or military. Flag: `units.one_unit_per_tile`. An enemy military unit moving onto a lone settler captures it and it becomes the captor's settler.
4. City capture: archers can reduce cities to 0 HP. A melee unit then moves in to capture. The city keeps its buildings and borders, loses 1 population (minimum 1), and resets to 50% HP. (configurable) Per unit, `can_capture` is true for the warrior and false for the scout, the archer, and the settler.
5. Line spells: the line starts at the target tile and runs 3 more tiles in the chosen hex direction (direction from the target toward the cursor). Only the target must be in range. Off-map tiles are dropped.
6. Fog: units see 2 tiles; cities see 2 tiles beyond their border. Spells can only target revealed tiles (flag: `spells.spells_require_revealed_target`). Revealed means not unrevealed: a tile the caster can see now, or one they have already explored. The AI obeys the same fog rules. Each player has their own unrevealed / revealed / visible state in core. The view draws the human's fog.
7. Movement: entering a tile that costs more than the remaining AP is allowed if AP > 0; it ends the move. The config flag stays `movement.allow_enter_over_budget_if_mp_left`. The pool is `units.<type>.ap` (scout 3, every other unit 2).
8. Food shortfall drains the growth bar; at 0 the city loses 1 pop (min 1). The settler's 1-pop cost is taken when it is finished; the city must be size 2+.
9. A new unit spawns on the city center; if any unit is already there, it goes to the nearest free tile inside the borders.
10. Volcanic damage (flat 10) at the end of the owner's turn and can kill. Units heal +10 anywhere if they didn't move or fight. A city heals if it wasn't attacked since its owner's last turn.
11. Mana per turn = 2 + floor(pop/2) (+2 with Mana Well). Spell cooldowns count the caster's own turns. The global End Turn is that tick for every player until turns are sequential: a cooldown of 2 cast on turn N is castable again on turn N+2. See `docs/spells.md`.
12. Ties: more tiles, then more cities, then the human loses.
13. Spells never change tile ownership (flag: `spells.spells_change_tile_ownership`). Borders can claim water. Already-owned tiles can't be claimed.
14. Unit orders include Skip and Fortify (Fortify = +25% defense while not moving), so the End Turn warning about units with no orders is satisfiable. Skip needs no AP and sets AP to 0. Fortify and Found need at least 1 AP and then set AP to 0. Neither Skip nor Fortify sets `acted`, so idle healing is unchanged.
15. Abilities live in the top-level `abilities` table. Each unit lists ids in `units.<type>.abilities`. Strike (warrior, scout; melee, range 1), Shield Bash (warrior only), Shoot (archer; ranged, range 2), Volley (archer; radius 1), and Sprint (scout; move) ship. The settler list is empty. A damage ability requires its `ap_cost` (1) and then sets AP to 0. `effect` may be `damage`, `status`, `move`, or `terraform`. Status and terraform parse and return `Not available yet` without changing the board. A move ability adds `ap_bonus` and can set `movement_only`. The ability bar lists those abilities, then Skip, Fortify, and Found. The three orders stay orders: they end the turn, Fortify and Found need at least 1 AP, and Skip needs none. Right-click moves, including a capture, and does not attack. Attacks and other abilities come from the bar. `ability_area` is `single` or `radius`. `target` may be `enemy`, `tile`, or `self`. Sprint's movement-only gate stays in the ability gate and the order reasons.

16. Shield Bash (ticket 27). These are the spec gaps that were built:
    - D1. A damage ability requires `deals_counter` and `push_distance`. Strike is `true` / `0`, Shoot is `false` / `0`, Shield Bash is `false` / `1`. `deals_counter` is the no-counter flag. `push_distance` 0 means no push. There is no `shield_bash` name check in core. A missing key fails the load.
    - D2. "Directly away" is the one of the six axial steps that continues from the warrior through the target. Range 1 makes that step unique.
    - D3. A city takes the damage and never moves. A unit the hit removes is not pushed. A settler or a 0 HP city on the destination blocks the push. A push never captures.
    - D4. Blocked means occupied, not passable (water or `move_cost` below 0), off the map, or a city center. A building does not block. Forest, hills, volcanic, and plains do not block. Fog on the destination does not block.
    - D5. The combat line is `Damage N   Counter 0   Push` when the destination is open, and `Damage N   Counter 0   No push` when it is blocked or the target is a city. An open destination uses the place tint. A blocked destination uses the invalid tint.
    - D6. The bar's existing cooldown line is the only clock. After Shield Bash it reads `Cooldown 2`, then `Cooldown 1`, then ready.

17. Volley (ticket 28). These are the spec gaps that were built:
    - D1. `area` may be `radius`. Integer `radius` is required only then (Volley: 1). Single abilities omit it. Missing `abilities.volley.radius` fails the load. Core branches on `area`, not on the ability id.
    - D2. Volley aims at a tile, so `target` is `tile`. Shoot stays `enemy`.
    - D3. Range is hex distance 1 through `abilities.volley.range` (2) to the aimed cell. The archer's own tile is not a legal center. Tiles in the disk may fall outside that range. The center must be currently visible.
    - D4. A center with no hittable enemy unit or enemy city is illegal. Volley cannot be spent on empty ground or friendlies alone. A visible enemy city in the disk is a hit.
    - D5. The combat line is `Damage N   Counter 0` for one hit and `Damage N, N   Counter 0` for several, including an enemy city's damage. Skipped tiles use the skipped tint.
    - D6. The bar's existing cooldown line is the only clock. After Volley it reads `Cooldown 3`, then `Cooldown 2`, then `Cooldown 1`, then ready.

Bryan decided that Volley damages enemy cities in its radius. The damage is the same half-of-Shoot formula, counter 0, and the city does not move. Friendly units and friendly cities stay skipped. That decision lives in `_radius_hits`.

18. Sprint (ticket 29). These are the spec gaps that were built:
    - D1. A move ability requires `ap_bonus` (int) and `movement_only` (bool). Sprint is 2 and true. Damage abilities omit both keys. Missing either key fails the load. Core branches on `effect` and those fields, not on the ability id.
    - D2. `target` `self` is the caster's tile. Sprint is `self`, range 0, area `single`. The button arms it. The preview is `reachable_tiles` at AP plus `ap_bonus`, in the move tint, and AP is unchanged until confirm. Confirm is the scout's tile or the button again. Another tile keeps targeting and does not move. Right-click or Esc cancels.
    - D3. `ap_cost` is only the gate. It is not deducted. On use, AP becomes AP plus `ap_bonus`, with no cap. End Turn discards the bonus and refills to `units.scout.ap`.
    - D4. A capture of a lone settler is a move, so it still works after Sprint. Attacking is an ability and is refused. Scout `can_capture` stays false.
    - D5. Skip, Fortify, and Found stay refused after Sprint. The shared reason is `Can only move`. The player spends leftover AP by moving, or ends it with End Turn. There is no Done control, and Skip is not an exception.
    - D6. Sprint sets `acted`, so the scout does not idle-heal. The bar's existing cooldown line is the only clock. After Sprint it reads `Cooldown 3`, then `Cooldown 2`, then `Cooldown 1`, then ready.

Also: volcanic damage uses the brief's flat value, not the design doc's chance-based proposal.

Decided by Bryan: engine Godot (use 4.7 stable), art is isometric 2D (2D art that reads as 3D), Civ 6-style hex map. Bryan is on macOS and plays a downloadable macOS build each milestone.

Greybox art v0.2 lives in `assets/art/` (source note in that folder's `README.md`). The TileSet face is 128×108 with texture origin `(0, -4)`. The art is already isometric, so the project does not apply a second squash.
