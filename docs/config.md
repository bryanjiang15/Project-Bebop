# Config

One file: `config/game_config.json`. `scripts/core/game_config.gd` is the only loader. `GameConfig.required_paths()` lists every key. `GameConfig.load_file()` push_errors and quits when a key is missing or the type is wrong. There is no second file and no silent default. Restart calls `load_file()` again.

`tests/run_tests.gd` (`_test_config_inventory`) is the inventory. It fails when a required path is missing from the shipped file, when a brief section 5 row or an agreed-default flag in `_config_checklist()` has no path, and when the old rival-AI step, found-radius, and land-list constants come back. A new brief tunable is added to that checklist. The test stays red until the path is a required key.

## Keys

Brief section 5, the Oct 29 ability table in `docs/prototype_brief.md`, the flags in `docs/agreed_defaults.md`, and the `ai` object. Shipped balance numbers are not retuned here.

Ticket 18 moved the last AI search literals into that same object. The behavior is unchanged:

| Key | Shipped value | What it is |
| --- | --- | --- |
| `ai.max_unit_steps` | 8 | Actions one unit may take in its turn |
| `ai.found_radius` | 5 | How far a settler looks for a founding tile |
| `ai.improve_lands` | forest, hills, plains | Lands a spell result treats as an improvement |
| `ai.worsen_lands` | water, volcanic | Lands a spell result treats as a worsening |

`ai.explore_radius` is already 4. It is the explore disk, not the found search.

Combatant candidates are the unit table where `combatant` is true. The fill order is warrior, then archer, then scout, then any other combatant. Building candidates are `CityRules.BUILDING_IDS`. The placement order is granary, then lumber mill, then mana well. Those two orders are the policy. They are not a second copy of the unit or building stats.

## Not a key

These stay in code:

- Tile size and texture origin, on `assets/art/bebop_tileset.tres` only.
- Reject and reason strings, and the order ids `skip` and `fortify`. `MatchResult.REASON_SCORE` is the string `Turn 50 score`.
- Map-generator hash and noise constants, and the seed mix in `GameSetup`.
- Hex geometry that matches the TileMapLayer, including the stacked-row ratio in `Hex`.
- View-only numbers in `scripts/view/game_view.gd`: click slop, highlight and land tints, done-alpha 0.55, HP bar geometry, scene preloads.
- Control layout, which stays in `.tscn` files.
- The "at least 1 AP" gate on Found and Fortify. Each ability already has `abilities.<id>.ap_cost`. There is no second global minimum.
- One hex past `city.border_max_radius` in the AI's "near my city" spell check. That is the rule, not its own key.
- Sentinel distances, the six hex directions, and the production-loop guard.

## Two volcanic numbers

`land.volcanic.hazard_damage` and `volcanic.damage` are both required. Both ship at 10. End-of-turn damage reads `volcanic.damage`. The loader does not delete either key and does not copy one onto the other.
