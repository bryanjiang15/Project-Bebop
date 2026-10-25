# Terraforming spells

Engineering record for ticket 11. Design still lives in `design_doc.md` and `prototype_brief.md`. Tunables stay in `config/game_config.json`. The area, range, and reject reasons are `scripts/core/spells.gd` (`SpellRules`). `GameSetup` spends mana, changes land, and ticks cooldowns.

## Mana pool

The pool is the one from ticket 10: `PlayerState.mana`, set at New Game from `players.starting_mana` (10). `CityRules.city_mana` is the only per-city rate. `GameSetup.mana_per_turn` sums it. The city panel shows one city's number. The top bar shows the human pool as `Mana: N (+M/turn)`, beside the Turn caption and `%TurnLabel` (`N / 50`).

End Turn snapshots every city's mana with `city_yields` before growth, production, and the border claim. After every city has resolved, each player's pool gains the sum of those snapshots. A population gain or a Mana Well finished this turn is paid on the next End Turn. Spells spend that same pool. The spell bar's mana check reads `player.mana` through `GameSetup.spell_block_reason`. There is no second income function.

## The five spells

| Id | Name | Shape | Mana | Range | Cooldown | Land |
| --- | --- | --- | --- | --- | --- | --- |
| `grow_forest` | Grow Forest | radius 1 (7 tiles) | 15 | 3 | 2 | forest |
| `raise_hills` | Raise Hills | radius 1 | 20 | 3 | 3 | hills |
| `carve_river` | Carve River | line of 4 | 25 | 3 | 3 | water |
| `ignite` | Ignite | radius 1 | 35 | 2 | 5 | volcanic |
| `restore_plains` | Restore Plains | radius 1 | 10 | 3 | 2 | plains |

`spells.casts_per_turn` is 1. A radius uses the spell's `radius`. A line uses the spell's `length` (Carve River is 4, matching `spells.line_length`). Each entry also has a `name`.

## Affected tiles

A radius is the target plus every tile within `radius`. Radius 1 is 7 tiles in the open and fewer when the disk leaves the map. A line starts on the target and walks `length - 1` more tiles in one of the six hex directions. Off-map tiles are dropped (`spells.drop_off_map`). There is no cell past the map edge to keep.

The line direction is the sector of the cursor inside the hovered hex. The six sectors are the nearest hex direction, using the same neighbor positions as the TileMap. A cursor on the exact center casts east, so the click is stable. One click casts. The player does not pick a direction in a second step.

Only the target has to be in range when `spells.only_target_must_be_in_range` is true. Range is the hex distance from the target to the nearest tile that player owns. Rival land and unowned land are legal targets. A player who owns nothing is out of range everywhere. Turning the flag off requires every affected tile to be in range too.

## What a cast changes

Every affected tile whose land is different becomes the spell's land. Tiles already of that land stay as they are and are not counted as changed. Two tiles are skipped:

- A city center, when `city.center_never_terraformed` is true. Any city's center, not only the caster's.
- A tile with a unit on it, when the new land is water and `spells.skip_water_if_land_unit_present` is true. Any other land still changes under a unit.

The cast still spends mana, starts the cooldown, and counts as the player's cast for the turn when every tile is skipped or already the right land. Ownership does not change (`spells.spells_change_tile_ownership` is false). Buildings stay where they are. Water does not remove a building yet, and volcanic ground does not deal damage yet.

Food, production, movement cost, and hills defense read `MapState.land_at` when they are asked. Nothing caches a tile's yield, so a city's food, production, worked-tile choice, and a Lumber Mill's forest count change on the next read. That is true for a rival city as well as the caster's. Ownership is not written.

The view has one refresh after a successful cast, `_refresh_board`. It repaints the land, rebuilds the selected unit's move and attack highlights from `reachable_tiles`, and refills `%CombatPreview` from `preview_attack` using the tile that was just clicked. The city panel stays on the last human city the player opened, including while a unit is selected, and that same refresh rewrites its food, production, mana, growth surplus, and queue. Build buttons stay disabled until the city itself is selected again, because placement highlights give way to move highlights. There is no rival city panel. A cast does not change `CityRules.city_mana`, so the top bar's per-turn rate is unchanged unless a Mana Well is added or removed.

## Who can cast

The button is grey, and its tooltip is the first reason that applies:

1. `Not enough mana`
2. `On cooldown`
3. `Already cast this turn`

A click on the map checks those, then the target:

4. `Cannot cast off the map`
5. `Out of range`
6. `Tile not revealed`, when `spells.spells_require_revealed_target` is true

Revealed means the caster's fog is not unrevealed. A tile they can see and a tile they have explored both qualify. That is the same split the hover tooltip uses when it shows a land id. An unrevealed tile shows `Tile not revealed` and is not a target. Affected tiles past the target may be unrevealed; the cast still changes them, and they stay unrevealed until something sees them.

An illegal click shows the reason and does not spend mana or leave targeting.

## Cooldowns

Cooldowns count the caster's own turns. Until players take turns one at a time, the global End Turn is that tick for every player. It runs after the mana sum and idle healing, and before the turn counter increments.

A successful cast stores the spell's `cooldown` as the number of End Turns still to wait. Each End Turn subtracts 1, and 0 means ready. A spell with cooldown 2 cast on turn N is therefore blocked on turn N+1 and castable on turn N+2. The one-cast limit clears at the same tick. `spells.cooldown_uses_caster_turns` records this rule.

## Bar and targeting

`%SpellBar` in `scenes/game.tscn` sits under the top bar. `%SpellButtons` is filled with one instance of `scenes/ui/spell_button.tscn` per spell, in config order. A button shows the name, mana cost, shape (`Radius 1` or `Line 4`), and either `Ready`, `Targeting`, `Cooldown N`, or the reject reason. Spell buttons do not take keyboard focus, so Enter still ends the turn.

Clicking a spell that can be cast enters targeting. Hovering a tile outlines the affected tiles on the existing highlight sprites, tinted with the new land's color. The white hover cell stays hidden during targeting so it does not sit on top of that outline. A skipped tile is grey. An illegal target is red, and the other tiles keep the land color so the shape stays visible. The tooltip shows the spell name, the cost, and how many tiles will change. A line tooltip also names the direction. Right-click or Esc leaves targeting and does not move, attack, or open the menu. A second Esc opens the menu. Left-click casts when the target is legal. Outside targeting, left-click still selects, right-click still moves or attacks, B still founds a city, and S and F are still the orders.
