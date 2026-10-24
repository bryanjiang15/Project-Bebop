# Movement and city founding

Engineering record for the settler-movement and founding rules. Design still lives in `design_doc.md`. Tunables stay in `config/game_config.json`.

## Who acts

Player ids are `0 .. players.count - 1`. The human is `players.human_index` (0). **End Turn** and the Enter key advance one global turn and refill every unit's movement from `units.<type>.move`. Enter does nothing while the in-game menu is open. Rivals do not take a turn.

`players.starting_units` is `["settler", "warrior"]`. The settler takes the start tile. The warrior takes the nearest free passable tile. Combat, healing, and Skip/Fortify are in `docs/combat.md`.

## Units

`GameSetup.spawn_unit(player, type, pos)` is the only constructor. `pos` is an odd-r offset cell. The call rejects an unknown type, a player id outside the match, a tile off the map, impassable land (water), and an illegal stack. It then recomputes fog.

A tile holds one unit when `units.one_unit_per_tile` is true. Another player's unit blocks entry either way. A tile the unit cannot stop on cannot be entered.

## Movement

`Pathfinder` searches in axial coordinates. `GameSetup` converts to offset cells at the boundary. The result maps each reachable cell to the movement points left on arrival. The origin is not included.

The cost is the land of the tile being entered. Water (`passable` false, `move_cost` -1) is impassable. When `movement.allow_enter_over_budget_if_mp_left` is true and the unit still has points, it may enter a more expensive tile, arrives with 0, and does not keep searching from there.

A move sets the unit as having acted and clears Fortify. A left click selects the human unit on that cell, or clears the selection when the cell is empty. The city on that cell comes after the unit. Highlight sprites mark the selected cell and every reachable cell. A right click on a reachable cell moves. A right click on a visible enemy attacks instead; see `docs/combat.md`. A left click does not move. A left drag farther than 8 px pans, as do middle drag and the arrow keys. Founding does not spend movement points. Fog recomputes after every move.

## Founding

The button and the B key call `GameSetup.found_city` for the selected unit. An empty reason means the action is legal. Otherwise the reason is one of:

- `Select a settler`
- `Cannot found on water`
- `Cannot found on another player's tile`
- `Too close to another city`
- `Cannot found off the map`

Distance is center to center against every city, including cities the founder has never seen. A distance below `city.min_distance` rejects. A distance equal to it accepts. The UI does not reveal the hidden city.

The new city has population 1 and territory radius `city.border_start_radius`. The claim is that disk. Water is included only when `borders.can_claim_water` is true. A tile that already has an owner is skipped when `borders.can_claim_owned_tiles` is false. Own territory can be founded on when the distance rule passes. The settler is removed.

Names are the next unused entry in `players.city_names[player]`. The loader requires one non-empty list per player. After the list ends, the last name is reused with a number.

## Sight

Unit vision is a disk of `fog.unit_vision`. City vision is a disk of territory radius plus `fog.city_vision_beyond_border`, not only the owned tiles plus a ring around them.

Unrevealed cells have no land atlas. Revealed cells that are not currently visible keep their land and are dimmed. Rival units are drawn only while visible. Rival cities and territory edges are drawn once the relevant tile has been explored, and they remain as last-known information.

## Follow-ups

Settler training and border growth are in `docs/cities.md`. The queue calls `spawn_unit`. Combat and capture are tickets 14 and 15. AI turns are later.
