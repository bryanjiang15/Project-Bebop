# Unit combat, healing, and orders

Engineering record for ticket 14. Design still lives in `design_doc.md` and `prototype_brief.md`. Tunables stay in `config/game_config.json`. The formula is `scripts/core/combat.gd`. `GameSetup` applies it.

## Roster

`players.starting_units` is `["settler", "warrior"]`. Each player spawns that list, in order, through `spawn_unit`. The settler takes the start tile. The warrior takes the nearest free passable tile, because `units.one_unit_per_tile` allows one unit on a tile. `units.spawn_nearest_free_if_blocked` is still the city-production rule.

A unit stores current HP and max HP from `units.<type>.hp`. The settler's HP is 0. That unit is non-combat, so it has no HP bar and combat never removes it for being at 0.

| Unit | HP | Attack | Defense | AP | Abilities |
| --- | --- | --- | --- | --- | --- |
| Scout | 50 | 5 | 5 | 3 | Strike |
| Warrior | 100 | 20 | 20 | 2 | Strike, Shield Bash |
| Archer | 100 | 25 | 12 | 2 | Shoot, Volley |
| Settler | 0 | 0 | 0 | 2 | none |

Attack is the strength used when this unit strikes. Defense is the strength used when this unit is struck. An archer shoots with 25 and is struck with 12. Reach comes from the ability, not from the unit.

## Abilities

`abilities` is a top-level table. Each unit lists ids in `units.<type>.abilities`, in bar order. The shipped damage abilities are Strike, Shoot, Shield Bash, and Volley:

```json
"strike": {"name": "Strike", "target": "enemy", "range": 1, "area": "single", "ap_cost": 1, "cooldown": 0, "effect": "damage", "damage_multiplier": 1.0, "melee": true, "deals_counter": true, "push_distance": 0}
"shoot": {"name": "Shoot", "target": "enemy", "range": 2, "area": "single", "ap_cost": 1, "cooldown": 0, "effect": "damage", "damage_multiplier": 1.0, "melee": false, "deals_counter": false, "push_distance": 0}
"shield_bash": {"name": "Shield Bash", "target": "enemy", "range": 1, "area": "single", "ap_cost": 1, "cooldown": 2, "effect": "damage", "damage_multiplier": 0.5, "melee": true, "deals_counter": false, "push_distance": 1}
"volley": {"name": "Volley", "target": "tile", "range": 2, "area": "radius", "radius": 1, "ap_cost": 1, "cooldown": 3, "effect": "damage", "damage_multiplier": 0.5, "melee": false, "deals_counter": false, "push_distance": 0}
"sprint": {"name": "Sprint", "target": "self", "range": 0, "area": "single", "ap_cost": 1, "cooldown": 3, "effect": "move", "ap_bonus": 2, "movement_only": true}
```

Allowed `effect` values are `damage`, `status`, `move`, and `terraform`. Allowed `target` is `enemy` (one enemy unit or city), `tile` (an aimed cell), or `self` (the caster's own tile). Allowed `area` is `single` or `radius`. A `radius` area requires integer `radius`. Single abilities omit it. A `move` effect requires integer `ap_bonus` and bool `movement_only`, and omits the damage fields. `status` and `terraform` parse and `use_ability` returns `Not available yet` without changing AP, HP, or land. A damage ability's strike strength is `units.<type>.attack * damage_multiplier`. At 1.0 the numbers match the old formula. The multiplier also scales the opposing strength in the counter. A damage ability also requires `deals_counter` and `push_distance`.

`ap_cost` is the AP that must remain before the ability is legal. It is not deducted. A damage ability then sets AP to 0. A move ability adds `ap_bonus` instead, and that sum can exceed `units.<type>.ap` until End Turn refills the pool. `UnitState.ability_cooldowns` stores turns left. End Turn decrements each entry and drops it at 0, in the same gap as spell cooldowns. Strike and Shoot ship at cooldown 0. Shield Bash ships at cooldown 2. Volley and Sprint ship at cooldown 3.

`GameSetup.unit_abilities`, `can_use_ability`, `ability_preview`, and `use_ability` are the only ability path. `ability_preview` returns `{ok, reason, damage, counter, push, push_open, push_cell, hits, skipped}`. An empty reason means the cell is legal. `hits` is one entry per unit or enemy city that would take damage. `skipped` maps a tile to `friendly`, `city` (a friendly city), or `unseen`. `push` is true when `push_distance` is greater than 0. `push_open` is true when the target is a unit and `push_cell` is free. `ability_block_reason` is the gate, then the cooldown, then AP, with no cell, and that string is the bar tooltip. `ability_targets` lists every cell where `can_use_ability` is empty. For `single` damage those cells are enemy units and cities. For `self` the cell is the caster's own tile. For `radius` they are the legal aimed cells. `ability_area` is the tiles a targeted cell would affect. `single` returns that one cell. `radius` is `Hex.disk` around the aimed cell, including empty tiles, with off-map cells dropped. The push hex is not part of the area. `move_reach_preview` is the post-bonus reachable set for an armed move ability. It does not change AP.

## Damage

`30 × 1.04^(attacker strength − defender strength)`, then `roundi` (nearest integer, halves away from zero), then clamped to `combat.min_damage`..`combat.max_damage` (5..60). Strength is not rounded before the exponent. Current HP does not change strength.

The defender's strength is `units.<type>.defense`, multiplied by `combat.hills_defense_multiplier` (1.25) when the defender stands on hills, and by `1 + units.fortify_defense_bonus` (1.25) when the defender is fortified. The two multipliers stack. No other land changes defense. The attacker's tile and Fortify do not change the attack.

Strike is melee: only an adjacent tile (hex distance 1). `deals_counter` is true, so the defender strikes back with the same formula, using the modified defense as its strength and the attacker's strike strength as the opposing strength. Hills, Fortify, and a city defender are unchanged.

Shoot reaches hex distance 1 through `abilities.shoot.range` (2). Distance 1 is still a shot. Shoot ships with `deals_counter` false. A ranged ability deals counter when `deals_counter` is true, or when `combat.ranged_takes_no_counter` is false, so Shoot still follows that flag. There is no line-of-sight check.

## Shield Bash

Shield Bash is the warrior's second ability. The scout does not gain it. It is melee, range 1, costs 1 AP, and has cooldown 2. Strike strength is the warrior's attack times `damage_multiplier` (0.5), so the formula is the same one Strike uses at strength 10. That is weaker than Strike. It spends the turn the same way: AP becomes 0, `acted` is set, and the cooldown is stored on that unit. Another unit's Strike is not on that clock. A cooldown of 2 cast this turn is ready again after two End Turns. The bar reads `Cooldown 2`, then `Cooldown 1`, then the base `2` when it is ready.

`deals_counter` false is the exception to counter-damage on melee. Shield Bash never deals counter-damage, against a unit or a city, even though `melee` is true. The code reads the flag. It does not check the ability id.

`push_distance` 1 pushes a living unit one hex after the damage. The destination is the hex directly away from the attacker: from the target, one step in the axial direction that runs from the attacker to the target. Range 1 makes that step unique. `push_destination(unit, cell)` is that hex. `push_distance` 0, which Strike and Shoot ship with, does not push.

The push happens only when the target is still a unit after the hit. A city takes the damage and never moves. A unit the hit removes is not placed on the destination. The attacker never steps onto the emptied or vacated tile.

`push_blocked` rejects the destination when it is off the map, not passable (water, or `move_cost` below 0), occupied by any unit, or a city center (either player, including 0 HP). A building does not block. Forest, hills, volcanic, and plains do not block. Fog on the destination does not block. A blocked push still deals the damage and leaves the target where it is. The push is not a move: it does not spend the target's AP, does not clear Fortify or the target's order, does not capture a settler or a 0 HP city, and does not call `move_unit`.

A melee Shield Bash still rejects a settler with `Cannot attack a settler`.

While Shield Bash is armed, the target tile stays on the shared preview path. An open destination is painted with the place tint. A blocked destination that is on the map is painted with the invalid tint at a smaller scale. The combat line is `Damage N   Counter 0   Push` when the destination is open, and `Damage N   Counter 0   No push` when it is blocked or the target is a city. A hit that will remove the unit can still read `Push`; the apply path does not move that unit. Strike and Shoot keep `Damage N   Counter N` because `push` is false.

## Volley

Volley is the archer's second ability. Shoot is unchanged: same damage, range 2, cooldown 0, no counter, and it still damages a city, including the `archers_can_zero_city_hp` floor. Volley is ranged, range 2, radius 1, costs 1 AP, and has cooldown 3. Strike strength is the archer's attack times `damage_multiplier` (0.5), so the formula is Shoot's at strength 12.5. That is weaker than Shoot. It spends the turn once: AP becomes 0, `acted` is set, and the cooldown is stored on that unit. Shoot on a fresh archer is not on that clock. A cooldown of 3 cast this turn reads `Cooldown 3`, then `Cooldown 2`, then `Cooldown 1`, then ready after the third End Turn.

The player aims a tile, not an enemy body. The aimed cell has to be on the map, currently visible, and at hex distance 1 through `abilities.volley.range` (2). The archer's own tile is not a legal center. Tiles in the disk may sit outside that range. Only the center is checked. The center must be currently visible (`fog.unit_visible`). A center with no hittable enemy unit or enemy city in the disk is refused with `No enemy in that area`. An off-map center is `Cannot target off the map`. A center outside vision is `Cannot see that tile`. Distance 0 or past the range is `Out of range`.

`ability_area` is the radius-1 disk, seven tiles in the open. Every visible enemy unit in that disk takes the formula. A visible enemy city in that disk takes the same formula, `Combat.damage` at strength 12.5 against `city.defense`, counter 0. The city stays on its tile. While `combat.archers_can_zero_city_hp` is false, that ranged hit still leaves the city at 1 if it had HP. A military unit on the city tile is the hit instead, and the city under it is not also hit. Friendlies, including the archer, are not hit. A friendly city is not hit. An unseen enemy unit or unseen enemy city is skipped with the same `fog.unit_visible` check Shoot uses. A lone enemy settler is removed the way Shoot removes one. A settler sharing a tile with a military unit is not a separate target. There is no counter and no push. The archer does not step onto a tile this emptied. Damage is computed for every hit before any HP changes, then applied, then `_finish_ability` runs once.

While Volley is armed, the disk uses the shared preview path. A skipped tile is grey. An enemy city that will be hit uses the attack tint, and its damage is one of the numbers on the combat line. The combat line is `Damage N   Counter 0` for one hit and `Damage N, N   Counter 0` when several take damage. Each N is that defender's formula result, in disk order.

## Sprint

Sprint is the scout's second ability. Strike on the scout is unchanged: the shared melee Strike, strength 5, range 1, and the same counter. The settler does not gain Sprint. Found stays an order on the settler.

Sprint is `effect` `move`, `target` `self`, range 0, area `single`. It costs 1 AP as a gate and has cooldown 3. `ap_bonus` is 2 and `movement_only` is true. Those two fields are required on every move ability. Core reads the fields. It does not check the ability id. Confirming adds the bonus to the current AP and does not deduct `ap_cost`. A scout at 3 AP becomes 5. A scout that has 1 AP left becomes 3. There is no cap. `acted` and `used_ability` are set, so a scout that only Sprints does not idle-heal. The cooldown is the same clock as Shield Bash and Volley: `Cooldown 3`, then `Cooldown 2`, then `Cooldown 1`, then ready after the third End Turn.

While `UnitState.movement_only` is set, every ability and every order is refused with `Can only move`. That includes a second Sprint, Skip, Fortify, and Found. `move_unit` still walks and still spends AP, including a capture of a lone settler. Scout `can_capture` stays false, so a 0 HP city is still not a capture. The flag lasts until End Turn, even after AP reaches 0. End Turn discards leftover bonus and refills AP to `units.scout.ap` (3). Leftover Sprint AP is not done and does not advance the queue. The scout becomes done, and the sprite dims, only when a later move spends the last AP. That finish does advance the queue.

Arming Sprint previews `reachable_tiles` at the current AP plus `ap_bonus`, in the move highlight tint, without changing AP. That reach stays when the cursor leaves the map. Confirm by clicking the scout's tile or the Sprint button again. Another tile stays in targeting and does not move. Right-click or Esc cancels. After the confirm, `%AbilityApLabel` shows the real AP, which may read `AP 5 / 3`.

A unit at 0 HP is removed. The attacker does not step onto a tile this emptied. A resolved damage ability sets the attacker's AP to 0 and `acted` true. A move ability adds `ap_bonus` instead. A unit with less than `ap_cost` AP cannot use it. The reason is `Needs at least 1 AP`. The attack does not clear Fortify.

## Who can be attacked

The target has to be another player's unit or city on a tile the attacker can currently see. Own units are rejected. A melee strike rejects a settler with `Cannot attack a settler`. A ranged strike against a lone settler is legal and destroys that settler through `_remove_unit`, the same path volcanic damage uses, because a settler has no HP pool. A settler sharing a tile with a military unit is not a target until that unit is gone. A tile may hold one military unit and, after a capture, one civilian.

Other reasons, shown in the unit panel and the hover tooltip:

- `Select a combat unit`
- `Needs at least 1 AP`
- `On cooldown`
- `Not available yet`
- `Unknown ability`
- `Cannot attack your own unit`
- `Cannot see that unit`
- `Out of range`
- `Cannot attack your own city`
- `Cannot see that city`
- `A unit defends that city`
- `Cannot target off the map`
- `Cannot see that tile`
- `No enemy in that area`
- `Can only move`

An unseen unit is not named. The view does not offer it as a target.

## Cities

A city stores HP. Founding sets it to `city.hp` (100), which is also its max. Defense strength is `city.defense` (15). Hills multiply that strength the same way they multiply a unit. A city does not fortify and does not strike on its own turn. Melee against a city takes counter-damage when `deals_counter` is true. Strike does. Shield Bash does not, and the city does not move. A ranged attack takes none while Shoot's `deals_counter` is false and `combat.ranged_takes_no_counter` is true. Scouts use Strike, so they still take the city's counter.

The city's HP never drops below 0, and 0 does not remove the city. While `combat.archers_can_zero_city_hp` is false, a ranged hit that would reach 0 leaves the city at 1 if it still had HP. A military unit standing on the city tile is the target instead. The city attack is rejected with `A unit defends that city`.

`%CombatPreview` and the hover tooltip show `Damage N   Counter N` for a city the same way they do for a unit. The city marker draws `current / max` under the name. At 0 HP that line is red. `%CityPanel` shows `HP current / max` for the human's city.

## Capturing a city

`units.<type>.can_capture` is true for the warrior and false for the scout, the archer, and the settler. `combat.melee_captures_city` has to be true as well. With both, that unit may move onto an enemy city at 0 HP. The move has to be reachable, then AP is set to 0. That capture does not set `used_ability`. A scout or an archer cannot enter. A healthy city blocks movement. A military unit on the tile blocks the capture until that unit is dead.

On capture the city changes owner. Buildings stay. Every tile that city owns changes owner with it. Population drops by `city.capture_population_loss` and not below `city.capture_population_min`. HP becomes `roundi(max_hp × city.capture_hp_fraction)`, clamped to the max. The queue and the stored production are cleared. The food bar and the border clock stay. The attacked flag clears, so the new owner can heal it on a later End Turn. Fog recomputes in that same step: the capturer gains the city disk, and the previous owner loses it. `GameSetup.mana_per_turn` follows the new owner immediately. The top bar, borders, and markers refresh through `_refresh_board`. If the open city panel belonged to the previous owner, it closes. If that player has no settler left, they are eliminated and their remaining units are removed. The rule is in `docs/win_loss.md`.

## Capturing a settler

`units.capture_lone_settler` lets any military unit, including a scout, move onto a tile that holds only an enemy settler. The settler becomes the mover's unit and stays a civilian. The mover ends with 0 AP. The two share the tile. Spawn and ordinary movement still reject a second unit, so this stack is the capture exception, not a general stack rule.

A right click takes that capture when the tile is reachable. A ranged unit that cannot walk there destroys the settler by using Shoot from the ability bar. A settler on an enemy city is not walked onto unless the city itself is being captured in that same move. A right click on a living enemy city does nothing. Arm the city's ability and left-click the city to attack it.

## Healing

Healing runs inside `end_turn`, after every city resolves and after each player's mana pool is paid, and before volcanic damage. There is one global turn, so every player's idle units and cities heal on that clock. A unit heals `units.heal` (10) when `units.heal_only_if_idle` is true and the unit did not move or attack this turn. Skip and Fortify do not count as acting, so those units heal. The result is capped at max HP.

A city heals `city.heal` (10) in that same gap, capped at max HP. While `city.heals_if_not_attacked` is true, a city that was attacked since its owner's last turn does not heal. The flag then clears. The next End Turn heals it if nobody attacked it again. An attack that spends the attacker's movement therefore leaves the city at 0 through the following turn, which is the turn a capture move can be spent. Ending that following turn without a new attack lets the city heal off 0. With the flag off, a city heals even after an attack. Volcanic damage does not touch city HP.

## Volcanic ground

After that heal, every unit standing on volcanic ground takes `volcanic.damage` (flat 10). The land table's `land.volcanic.hazard_damage` stays 10 as well. The applied number is `volcanic.damage`, so tuning that key changes the hit. `volcanic.flat` false, or a `volcanic.timing` other than `end_of_owner_turn`, applies nothing. There is no chance roll.

The hit applies to every unit type and every player, including a unit standing on a city tile. The city itself is not damaged. Founding on volcanic ground is allowed. A spell that turns a tile volcanic does not damage on the cast; the next End Turn does. A unit that leaves the tile before End Turn takes none.

Healing runs first. An idle unit below max HP gains 10 and then loses 10, so it nets 0, including a unit at 5 HP that would have died if the hit came first. An idle unit already at max HP cannot heal, then loses 10. A unit that moved or attacked does not heal, then loses 10. At 10 HP or below, with no heal, it is removed. `volcanic.can_kill` false leaves a combat unit at 1 HP instead of removing it.

A settler has no HP pool. The hazard removes them when `volcanic.can_kill` is true, through the same unit-removal path combat uses. Their HP bar stays hidden. Cities resolve before this hit, so a settler completed onto a volcanic city center in the same End Turn is removed before the turn counter increments. The city stays. If that death leaves its owner with no cities and no settlers, the owner is eliminated in that same End Turn, before the turn-limit check. See `docs/win_loss.md`.

The selected unit's panel adds one line while they stand on volcanic ground: `Volcanic: -10 HP at end of turn`, using the tuned damage. That line is `%VolcanicWarning`, authored under the summary, and only that line is amber. HP, strength, AP, and order stay on `%SelectionDetail` in the summary color. The hover tooltip adds `AP current / max` for each unit on a visible tile. Move highlights and the End Turn confirm are unchanged.

## Orders

Skip (`skip_unit`, S), Fortify (`fortify_unit`, F), and Found are orders, not abilities. Skip needs no AP. It sets AP to 0 and does not set `acted`, so an idle unit still heals. Fortify needs at least 1 AP, then sets AP to 0 and `fortified`, and does not set `acted`. Fortify lasts until the unit moves. Skip lasts until the turn ends, then clears. A fortified unit that skips stays fortified; the skip clears and the Fortify order comes back. Found needs at least 1 AP and otherwise follows `docs/movement_and_founding.md`. After Sprint, Skip, Fortify, and Found are refused with `Can only move`. The player spends leftover AP by moving. If that scout cannot move, End Turn still has the two-press escape below. Skip is not an exception.

A unit is done for the turn when its AP is 0. `GameSetup.unit_turn_done` is that check and nothing else: it does not set `acted` and it does not change `order`. A move or a damage ability that leaves 0 AP is enough; the player does not click again. Skip and Fortify already set AP to 0, so they look done too, and they still leave `acted` false, so they still heal. Sprint does not finish the scout while bonus AP remains. The scout is done only after a later move spends the last of it. End Turn refills AP. A fortified unit with that refill is not done.

A human unit needs orders when its AP is above 0 and its order is empty. `GameSetup.units_needing_orders` is that list, in array order, rebuilt every time it is asked. Rivals are never in it. Skip and Fortify leave it this turn because they set AP to 0. There is no sentry order. Fortify persists after End Turn with AP refilled, so that unit stays out until a move clears Fortify. Skip does not persist, so a skipped unit is back in the list next turn. `has_unordered_moves` is that list being non-empty while `units.end_turn_warns_if_unordered` is true.

When the selected unit finishes — a move or damage ability that leaves AP at 0, a successful Skip or Fortify, or Found, which removes the settler — selection moves to the next unit in that list and the camera snaps to its tile. Zoom stays. Sprint with leftover AP does not finish the scout and does not advance. A move that leaves AP above 0 does not advance. Clicking a unit that is already done does not advance. If nothing else needs orders, selection stays on the finished unit. After Found, selection clears when nothing else needs orders. Spell and ability targeting cancel when the selection advances.

`%NextUnitButton` sits beside `%EndTurnButton`, labeled `Next Unit (.)`. Period is the `next_unit` action. It cycles to the next unit after the selection, wraps, and never ends the turn. With only the selected unit left, it stays there. The button is disabled when the list is empty. It does nothing while the in-game menu is open.

While any unit needs orders and `units.end_turn_warns_if_unordered` is true, `%EndTurnButton` and `%EndTurnWarning` read `N units need orders (Enter)` (`1 unit needs orders (Enter)` when the count is one). Enter and the button share `end_turn`. The first press jumps to the next unit that needs orders, centers the camera, and does not end the turn. The button then reads `End anyway (Enter)` and the warning reads `Units still have AP. End Turn again to continue.` A second press on that same unit, with no click, order, move, or attack in between, ends the turn. That second press is the escape for a Sprinted scout that cannot spend its leftover AP. A click or any other order clears the confirm, and the count comes back. When the count is 0, the button reads `End Turn (Enter)`, the warning is empty, and one press ends the turn. When the warning key is false, End Turn ends immediately and the count is not shown. Enter still does nothing while the in-game menu is open, and a focused control still receives Enter before the map.

After a successful End Turn, the first unit in list order that needs orders is selected and the camera centers on it. If every remaining unit is still fortified, the selection and the camera stay. If the selected unit was removed and nobody needs orders, the selection clears.

## View

`%AbilityBar` sits at the bottom center while one of the human's units is selected, and it hides otherwise. `%AbilityApLabel` reads `AP current / max`. The current value can be higher than the pool after Sprint, for example `AP 5 / 3`. `%AbilityButtons` instances `scenes/ui/ability_button.tscn` for each ability in config order, then Skip, Fortify, and Found after the authored `OrderGap`. Found appears only when the unit is a settler. An ability button shows the name, the AP cost, the cooldown, and `Ready`, `Targeting`, or the reason from `ability_block_reason`. An order shows the name, `No AP` or `1 AP`, an en dash instead of a cooldown, and the order reason. A disabled button is grey and its tooltip is that reason. S, F, and B still call the same order handlers.

Clicking a ready ability sets the target. Spell targeting and ability targeting cancel each other. Legal cells use the attack tint. Hovering paints `ability_area` with the shared spell preview: the hovered tile is red when `can_use_ability` returns a reason, and a skipped tile is grey. A radius preview passes that skipped set into the same paint path. A push hex is painted from `ability_preview` on that same highlight path, not as a second area. A move ability paints `move_reach_preview` in the move tint instead, and the combat line stays blank. `%CombatPreview` shows `Damage N   Counter N` from `ability_preview` only while a damage ability is targeted, `Damage N, N   Counter 0` when several targets are hit, and `Push` or `No push` when the ability pushes, including the reason when the hovered tile is illegal. With nothing targeted, a reachable capture still shows `Capture`, and the map shows the selected tile and the green reachable tiles only. Left-click a legal tile to call `use_ability`, then leave targeting. For `target` `self`, the legal tile is the unit's own tile, and clicking the same button again also confirms. Another tile keeps targeting and does not move. At 0 AP the ability and the AP orders are grey. After Sprint they are grey with `Can only move` even while AP remains, and the scout stays selected while that AP remains. A visible done unit is dimmed: the sprite's `self_modulate` alpha is 0.55. The team-tint shader multiplies by that canvas color, and the HP bar stays fully opaque because it is a child of that sprite. `%SelectionDetail` reads `Order Done` when the unit is done and the order is none. Skip and Fortify keep their own order lines. When that finish was the selected unit, selection jumps to the next unit that needs orders and the camera centers on it. A done unit can be selected again, and that click does not advance. Rivals use the same dim. `%NextUnitButton` and Period cycle the orders list. Right-click or Esc cancels targeting and does not move. A right click with nothing targeted moves onto a highlighted tile, including a capture, and does not attack. A left click still selects.

`%VolcanicWarning` is the amber hazard line under the unit summary. HP, strength, AP, and the order stay on `%SelectionDetail`.

A left click selects the unit on that tile. If the tile also has the human's city, the next click selects the city.

Each sprite sits on the cell center. `scenes/actors/hp_bar.tscn` is instanced on each unit and sits on the top of the sprite. It is hidden when max HP is 0. The fill width is the HP fraction.

## Out of scope

Stepping onto a tile emptied by a killing blow, rival AI, and a combat log. Elimination is in `docs/win_loss.md`.
