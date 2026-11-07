# Unit combat, healing, and orders

Engineering record for ticket 14. Design still lives in `design_doc.md` and `prototype_brief.md`. Tunables stay in `config/game_config.json`. The formula is `scripts/core/combat.gd`. `GameSetup` applies it.

## Roster

`players.starting_units` is `["settler", "warrior"]`. Each player spawns that list, in order, through `spawn_unit`. The settler takes the start tile. The warrior takes the nearest free passable tile, because `units.one_unit_per_tile` allows one unit on a tile. `units.spawn_nearest_free_if_blocked` is still the city-production rule.

A unit stores current HP and max HP from `units.<type>.hp`. The settler's HP is 0. That unit is non-combat, so it has no HP bar and combat never removes it for being at 0.

| Unit | HP | Attack | Defense | AP | Abilities |
| --- | --- | --- | --- | --- | --- |
| Scout | 50 | 5 | 5 | 3 | Strike |
| Warrior | 100 | 20 | 20 | 2 | Strike |
| Archer | 100 | 25 | 12 | 2 | Shoot |
| Settler | 0 | 0 | 0 | 2 | none |

Attack is the strength used when this unit strikes. Defense is the strength used when this unit is struck. An archer shoots with 25 and is struck with 12. Reach comes from the ability, not from the unit.

## Abilities

`abilities` is a top-level table. Each unit lists ids in `units.<type>.abilities`, in bar order. This ticket ships two damage abilities:

```json
"strike": {"name": "Strike", "target": "enemy", "range": 1, "area": "single", "ap_cost": 1, "cooldown": 0, "effect": "damage", "damage_multiplier": 1.0, "melee": true}
"shoot": {"name": "Shoot", "target": "enemy", "range": 2, "area": "single", "ap_cost": 1, "cooldown": 0, "effect": "damage", "damage_multiplier": 1.0, "melee": false}
```

Allowed `effect` values are `damage`, `status`, `move`, and `terraform`. Allowed `target` is `enemy` (one enemy unit or city). Allowed `area` is `single`. `status`, `move`, and `terraform` parse and `use_ability` returns `Not available yet` without changing AP, HP, or land. A damage ability's strike strength is `units.<type>.attack * damage_multiplier`. At 1.0 the numbers match the old formula. The multiplier also scales the opposing strength in the counter.

`ap_cost` is the AP that must remain before the ability is legal. Using it still sets AP to 0. `UnitState.ability_cooldowns` stores turns left. End Turn decrements each entry and drops it at 0, in the same gap as spell cooldowns. Strike and Shoot ship at cooldown 0.

`GameSetup.unit_abilities`, `can_use_ability`, `ability_preview`, and `use_ability` are the only attack path. `ability_preview` returns `{ok, reason, damage, counter}`. An empty reason means the cell is legal. `ability_block_reason` is the gate, then the cooldown, then AP, with no cell, and that string is the bar tooltip. `ability_targets` lists every cell where `can_use_ability` is empty. `ability_area` is the tiles a targeted cell would affect. `single` returns that one cell. A radius is ticket 28.

## Damage

`30 × 1.04^(attacker strength − defender strength)`, then `roundi` (nearest integer, halves away from zero), then clamped to `combat.min_damage`..`combat.max_damage` (5..60). Strength is not rounded before the exponent. Current HP does not change strength.

The defender's strength is `units.<type>.defense`, multiplied by `combat.hills_defense_multiplier` (1.25) when the defender stands on hills, and by `1 + units.fortify_defense_bonus` (1.25) when the defender is fortified. The two multipliers stack. No other land changes defense. The attacker's tile and Fortify do not change the attack.

Strike is melee: only an adjacent tile (hex distance 1). The defender strikes back with the same formula, using the modified defense as its strength and the attacker's strike strength as the opposing strength.

Shoot reaches hex distance 1 through `abilities.shoot.range` (2). Distance 1 is still a shot: no counter-damage while `combat.ranged_takes_no_counter` is true. There is no line-of-sight check.

A unit at 0 HP is removed. The attacker does not step onto a tile this emptied. A resolved ability sets the attacker's AP to 0 and `acted` true. A unit with less than `ap_cost` AP cannot use it. The reason is `Needs at least 1 AP`. The attack does not clear Fortify.

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

An unseen unit is not named. The view does not offer it as a target.

## Cities

A city stores HP. Founding sets it to `city.hp` (100), which is also its max. Defense strength is `city.defense` (15). Hills multiply that strength the same way they multiply a unit. A city does not fortify and does not strike on its own turn. Melee against a city takes counter-damage from that strength. A ranged attack takes none while `combat.ranged_takes_no_counter` is true. Scouts use the same rule.

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

Skip (`skip_unit`, S), Fortify (`fortify_unit`, F), and Found are orders, not abilities. Skip needs no AP. It sets AP to 0 and does not set `acted`, so an idle unit still heals. Fortify needs at least 1 AP, then sets AP to 0 and `fortified`, and does not set `acted`. Fortify lasts until the unit moves. Skip lasts until the turn ends, then clears. A fortified unit that skips stays fortified; the skip clears and the Fortify order comes back. Found needs at least 1 AP and otherwise follows `docs/movement_and_founding.md`.

`End Turn` and Enter ask for confirmation when `units.end_turn_warns_if_unordered` is true and any human unit still has AP and no order. The top bar reads `Units still have AP. End Turn again to continue.` and the button reads `End anyway (Enter)`. The next End Turn or Enter, with no other order, move, attack, or selection in between, ends the turn. A click, Skip, Fortify, move, attack, or founding clears the pending confirm. Enter still does nothing while the in-game menu is open, including a pending confirm. A focused control still receives Enter before the map.

## View

`%AbilityBar` sits at the bottom center while one of the human's units is selected, and it hides otherwise. `%AbilityApLabel` reads `AP current / max`. `%AbilityButtons` instances `scenes/ui/ability_button.tscn` for each ability in config order, then Skip, Fortify, and Found after the authored `OrderGap`. Found appears only when the unit is a settler. An ability button shows the name, the AP cost, the cooldown, and `Ready`, `Targeting`, or the reason from `ability_block_reason`. An order shows the name, `No AP` or `1 AP`, an en dash instead of a cooldown, and the order reason. A disabled button is grey and its tooltip is that reason. S, F, and B still call the same order handlers.

Clicking a ready ability sets the target. Spell targeting and ability targeting cancel each other. Legal cells use the attack tint. Hovering paints `ability_area` with the shared spell preview: the hovered tile is red when `can_use_ability` returns a reason, and a skipped tile is grey. `%CombatPreview` shows `Damage N   Counter N` from `ability_preview` only while an ability is targeted, including the reason when the hovered tile is illegal. With nothing targeted, a reachable capture still shows `Capture`, and the map shows the selected tile and the green reachable tiles only. Left-click a legal tile to call `use_ability`, then leave targeting. The unit stays selected. At 0 AP the ability and the AP orders are grey. Right-click or Esc cancels targeting and does not move. A right click with nothing targeted moves onto a highlighted tile, including a capture, and does not attack. A left click still selects.

`%VolcanicWarning` is the amber hazard line under the unit summary. HP, strength, AP, and the order stay on `%SelectionDetail`.

A left click selects the unit on that tile. If the tile also has the human's city, the next click selects the city.

Each sprite sits on the cell center. `scenes/actors/hp_bar.tscn` is instanced on each unit and sits on the top of the sprite. It is hidden when max HP is 0. The fill width is the HP fraction.

## Out of scope

Stepping onto a tile emptied by a killing blow, rival AI, and a combat log. Elimination is in `docs/win_loss.md`.
