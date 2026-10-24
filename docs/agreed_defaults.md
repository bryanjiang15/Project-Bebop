# Agreed engineering defaults

Source: approved by Design Scribe and Bryan, 2026-10-17. There is no separate Notion page for this list.

Notion is the source of truth for the prototype brief and the design doc. This file is the approved engineering decision record. If the brief and the design doc disagree, the design doc wins. These defaults are prototype rules, and every one of them is a value or a flag in `config/game_config.json`.

1. Buildings (Granary, Mana Well, Lumber Mill) are placed on a player-chosen tile inside the city's borders. One building per tile; not on the city center. Lumber Mill counts forests adjacent to its own tile. Turning that tile to water destroys the building. Flag: `buildings.buildings_on_worked_tiles`.
2. Combat strength: one strength per unit (scout 5, warrior 20); archer 25 when shooting, 12 when defending; city 15. Counter-damage uses the defender's strength vs the attacker's. HP doesn't reduce strength. Hills multiply the defender's strength by 1.25.
3. One unit per tile, civilian or military. Flag: `units.one_unit_per_tile`. An enemy military unit moving onto a lone settler captures it and it becomes the captor's settler.
4. City capture: archers can reduce cities to 0 HP. A melee unit then moves in to capture. The city keeps its buildings and borders, loses 1 population (minimum 1), and resets to 50% HP. (configurable)
5. Line spells: the line starts at the target tile and runs 3 more tiles in the chosen hex direction (direction from the target toward the cursor). Only the target must be in range. Off-map tiles are dropped.
6. Fog: units see 2 tiles; cities see 2 tiles beyond their border. Spells can only target revealed tiles (flag: `spells.spells_require_revealed_target`). The AI obeys the same fog rules. Each player has their own unrevealed / revealed / visible state in core. The view draws the human's fog.
7. Movement: entering a tile that costs more than the remaining MP is allowed if MP > 0; it ends the move.
8. Food shortfall drains the growth bar; at 0 the city loses 1 pop (min 1). The settler's 1-pop cost is taken when it is finished; the city must be size 2+.
9. A new unit spawns on the city center; if any unit is already there, it goes to the nearest free tile inside the borders.
10. Volcanic damage (flat 10) at the end of the owner's turn and can kill. Units heal +10 anywhere if they didn't move or fight. A city heals if it wasn't attacked since its owner's last turn.
11. Mana per turn = 2 + floor(pop/2) (+2 with Mana Well). Spell cooldowns count the caster's own turns.
12. Ties: more tiles, then more cities, then the human loses.
13. Spells never change tile ownership (flag: `spells.spells_change_tile_ownership`). Borders can claim water. Already-owned tiles can't be claimed.
14. Unit orders include Skip and Fortify (Fortify = +25% defense while not moving), so the End Turn warning about units with no orders is satisfiable.

Also: volcanic damage uses the brief's flat value, not the design doc's chance-based proposal.

Decided by Bryan: engine Godot (use 4.7 stable), art is isometric 2D (2D art that reads as 3D), Civ 6-style hex map. Bryan is on macOS and plays a downloadable macOS build each milestone.

Greybox art v0.2 lives in `assets/art/` (source note in that folder's `README.md`). The TileSet face is 128×108 with texture origin `(0, -4)`. The art is already isometric, so the project does not apply a second squash.
