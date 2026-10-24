# Unit combat, healing, and orders

Engineering record for ticket 14. Design still lives in `design_doc.md` and `prototype_brief.md`. Tunables stay in `config/game_config.json`. The formula is `scripts/core/combat.gd`. `GameSetup` applies it.

## Roster

`players.starting_units` is `["settler", "warrior"]`. Each player spawns that list, in order, through `spawn_unit`. The settler takes the start tile. The warrior takes the nearest free passable tile, because `units.one_unit_per_tile` allows one unit on a tile. `units.spawn_nearest_free_if_blocked` is still the city-production rule.

A unit stores current HP and max HP from `units.<type>.hp`. The settler's HP is 0. That unit is non-combat, so it has no HP bar and combat never removes it for being at 0.

| Unit | HP | Attack | Defense | Range | Move |
| --- | --- | --- | --- | --- | --- |
| Scout | 50 | 5 | 5 | 0 | 3 |
| Warrior | 100 | 20 | 20 | 0 | 2 |
| Archer | 100 | 25 | 12 | 2 | 2 |
| Settler | 0 | 0 | 0 | 0 | 2 |

Attack is the strength used when this unit strikes. Defense is the strength used when this unit is struck. An archer shoots with 25 and is struck with 12.

## Damage

`30 × 1.04^(attacker strength − defender strength)`, then `roundi` (nearest integer, halves away from zero), then clamped to `combat.min_damage`..`combat.max_damage` (5..60). Strength is not rounded before the exponent. Current HP does not change strength.

The defender's strength is `units.<type>.defense`, multiplied by `combat.hills_defense_multiplier` (1.25) when the defender stands on hills, and by `1 + units.fortify_defense_bonus` (1.25) when the defender is fortified. The two multipliers stack. No other land changes defense. The attacker's tile and Fortify do not change the attack.

Melee is a unit whose `range` is 0, and only against an adjacent tile (hex distance 1). The defender strikes back with the same formula, using the modified defense as its strength and the attacker's attack as the opposing strength.

An archer shoots at hex distance 1 through `range` (2). Distance 1 is still a shot: no counter-damage while `combat.ranged_takes_no_counter` is true. There is no line-of-sight check.

A unit at 0 HP is removed. The attacker does not step onto a tile this emptied. A shot or a melee strike sets the attacker's movement to 0. A unit with 0 movement cannot attack. The attack does not clear Fortify.

## Who can be attacked

The target has to be another player's unit on a tile the attacker can currently see. Own units are rejected. A settler is rejected with `Cannot attack a settler`. Cities are not targets. A tile holds one unit, so that unit is the target.

Other reasons, shown in the unit panel and the hover tooltip:

- `Select a combat unit`
- `No moves left`
- `Cannot attack your own unit`
- `Cannot see that unit`
- `Out of range`

An unseen unit is not named. The view does not offer it as a target.

## Healing

Healing runs inside `end_turn`, after every city resolves and before movement is refilled. There is one global turn, so every player's idle units heal on that clock. A unit heals `units.heal` (10) when `units.heal_only_if_idle` is true and the unit did not move or attack this turn. Skip and Fortify do not count as acting, so those units heal. The result is capped at max HP. Volcanic damage and city healing are not applied.

## Orders

Skip (`skip_unit`, S) and Fortify (`fortify_unit`, F) are the orders. Fortify sets a +25% defense that lasts until the unit moves. Skip lasts until the turn ends, then clears. A fortified unit that skips stays fortified; the skip clears and the Fortify order comes back.

`End Turn` and Enter ask for confirmation when `units.end_turn_warns_if_unordered` is true and any human unit still has movement and no order. The top bar reads `Units still have moves. End Turn again to continue.` and the button reads `End anyway (Enter)`. The next End Turn or Enter, with no other order, move, attack, or selection in between, ends the turn. A click, Skip, Fortify, move, attack, or founding clears the pending confirm. Enter still does nothing while the in-game menu is open, including a pending confirm. A focused control still receives Enter before the map.

## View

`%SkipButton` and `%FortifyButton` sit in the unit panel with the HP, strength, moves, and order lines. `%CombatPreview` and the hover tooltip show `Damage N   Counter N` over a legal target. Attackable tiles use the move-highlight scene tinted red. Reachable tiles stay green. A right click on a visible enemy attacks and does not move. A right click on an empty reachable tile still moves. A left click still selects.

A left click selects the unit on that tile. If the tile also has the human's city, the next click selects the city.

Each sprite sits on the cell center. `scenes/actors/hp_bar.tscn` is instanced on each unit and sits on the top of the sprite. It is hidden when max HP is 0. The fill width is the HP fraction.

## Out of scope

City attacks, capturing a city or a settler, stepping onto a killed unit's tile, volcanic damage, and rival AI.
