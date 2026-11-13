# Movement and city founding

Engineering record for the settler-movement and founding rules. Design still lives in `design_doc.md`. Tunables stay in `config/game_config.json`.

## Who acts

Player ids are `0 .. players.count - 1`. The human is `players.human_index` (0). **End Turn** and the Enter key advance one global turn and refill every unit's AP from `units.<type>.ap`. Scout is 3. Every other unit is 2. Enter does nothing while the in-game menu is open. Rivals do not take a turn.

`players.starting_units` is `["settler", "warrior"]`. The settler takes the start tile. The warrior takes the nearest free passable tile. Combat, healing, Skip/Fortify, and Sprint are in `docs/combat.md`. End Turn refills every unit from `units.<type>.ap` and discards Sprint's leftover bonus.

## Units

`GameSetup.spawn_unit(player, type, pos)` is the only constructor. `pos` is an odd-r offset cell. The call rejects an unknown type, a player id outside the match, a tile off the map, impassable land (water), and an illegal stack. It then recomputes fog.

A tile holds one unit when `units.one_unit_per_tile` is true. Another player's unit blocks entry either way. A tile the unit cannot stop on cannot be entered.

## Movement

`Pathfinder` searches in axial coordinates. `GameSetup` converts to offset cells at the boundary. The result maps each reachable cell to the AP left on arrival. The origin is not included.

The cost is the land of the tile being entered. Water (`passable` false, `move_cost` -1) is impassable for the settler, scout, warrior, and archer. They cannot enter it, path through it, or see it in the move highlights. A spell that would turn their tile into water skips that tile, so the unit is not stranded. Forest, hills, volcanic ground, and plains still change under a unit, and the unit stays on that tile. When `movement.allow_enter_over_budget_if_mp_left` is true and the unit still has AP, it may enter a more expensive tile, arrives with 0, and does not keep searching from there. The flag name is unchanged.

A move sets the unit as having acted and clears Fortify. A move that leaves AP at 0 marks the unit done for the turn (`GameSetup.unit_turn_done`). The view dims that sprite, and the selection line reads `Done` when the order is none. If that unit was selected, selection jumps to the next human unit that still needs orders and the camera snaps to its tile without changing zoom. A move that leaves AP above 0 does not mark it done and does not jump, including the steps after Sprint while bonus AP remains. When nothing else needs orders, the finished unit stays selected. Found removes the settler and uses that same jump; the selection clears when no other unit needs orders. `%NextUnitButton` and Period cycle the list by hand. Enter and End Turn jump first, then the existing End anyway confirm can end the turn. The count, the button, and the start of the next turn are in `docs/combat.md`. A left click selects the human unit on that cell, or clears the selection when the cell is empty. The city on that cell comes after the unit. Highlight sprites mark the selected cell and every reachable cell. A right click on a reachable cell moves, including a capture. It does not use an ability. Attacks come from the ability bar; see `docs/combat.md`. A left click does not move. A left drag farther than 8 px pans, as do middle drag and the arrow keys. Found needs at least 1 AP. The settler is then removed, so a settler at 0 AP is refused before the distance check. After Sprint the scout can still move, and a capture of a lone settler is still that move. Fog recomputes after every move.

## Founding

Found sits on `%AbilityBar` with Skip and Fortify. The button and the B key call `GameSetup.found_city` for the selected unit. The button tooltip is the reason while it is disabled. An empty reason means the action is legal. Otherwise the reason is one of:

- `Can only move`
- `Select a settler`
- `Cannot found on water`
- `Cannot found on another player's tile`
- `Needs at least 1 AP`
- `Too close to another city`
- `Cannot found off the map`

`Can only move` is the movement-only reason, shared with abilities, Skip, and Fortify. It wins over the settler check, so a scout that has Sprinted and is asked to found gets that reason. A settler who has not Sprinted never sees it. Found still needs at least 1 AP, still rejects a city closer than `city.min_distance`, and still removes the settler.

Distance is center to center against every city, including cities the founder has never seen. A distance below `city.min_distance` rejects. A distance equal to it accepts. The UI does not reveal the hidden city. Volcanic ground can be founded on. A unit that later stands on that city tile still takes volcanic damage; the city is not.

The new city has population 1 and territory radius `city.border_start_radius`. The claim is that disk. Water is included only when `borders.can_claim_water` is true. A tile that already has an owner is skipped when `borders.can_claim_owned_tiles` is false. Own territory can be founded on when the distance rule passes. The settler is removed.

Names are the next unused entry in `players.city_names[player]`. The loader requires one non-empty list per player. After the list ends, the last name is reused with a number.

## Sight

Unit vision is a disk of `fog.unit_vision`. City vision is a disk of territory radius plus `fog.city_vision_beyond_border`, not only the owned tiles plus a ring around them.

Unrevealed cells have no land atlas. Revealed cells that are not currently visible keep their land and are dimmed. Rival units are drawn only while visible. Rival cities and territory edges are drawn once the relevant tile has been explored, and they remain as last-known information.

## Capture moves

A healthy enemy city blocks entry. At 0 HP, a unit with `can_capture` may enter, and that step ends movement. Any military unit may enter a tile that holds only an enemy settler when `units.capture_lone_settler` is true. That step also ends movement. The rules are in `docs/combat.md`.

## Follow-ups

Settler training and border growth are in `docs/cities.md`. The queue calls `spawn_unit`. AI turns are later.
