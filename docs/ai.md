# Simple rival AI

Ticket 16. Both non-human players play a normal turn after the human ends theirs. Win and loss are unchanged: conquest, human elimination, or the turn-50 ranking. Last-one-standing is a follow-up.

`scripts/core/rival_ai.gd` (`RivalAI`) is pure `RefCounted`. It only calls `GameSetup`. `GameSetup.play_rivals` runs it for each living non-human player, in index order, and stops if a result is set. The view calls that, then the existing `end_turn()`, from `_finish_end_turn`. Input is locked for that stretch. Headless play is the same instant path. There is no per-unit camera delay.

`ai.enabled` false makes `play_rivals` return immediately. Direct `end_turn()` from a unit test does not play rivals, so older tests stay idle.

## Turn order (D1)

Rivals spend the AP they already have. Then one global `end_turn()` resolves every city, pays snapshotted mana, heals cities and idle units, applies volcanic damage, ticks spell and ability cooldowns for every player, and either ends the match or increments the turn and refills AP. A cooldown of C cast on turn N is ready on turn N+C. Per-player clocks are a follow-up.

Inside one player: units (snapshot of ids, sorted), then one production item for each empty queue, including a city founded this turn, then at most one spell. A unit gets at most `ai.max_unit_steps` actions (8). A non-positive score fortifies, or skips when fortify is refused. A sprinted scout with leftover AP and nowhere to walk stops; End Turn clears `movement_only`. That is the same Skip refusal as the human. Fortify still lasts until the unit moves, and End Turn refills AP without clearing that order. The rival's next turn looks at the unit again anyway. AP is what ends its turn, so a unit that fortified last turn can walk or fight once its AP is back.

## Scores (D2, D3)

One ply. No search, personality, or diplomacy. A later candidate replaces the current one only when its score is strictly higher, so ties keep the earlier unit, the earlier ability, and the earlier axial `(q, r)`. The policy does not call `randf`.

An attack reads `ability_preview`: damage times `ai.weight_damage` for a unit, `ai.weight_city_damage` for a city, plus `ai.weight_kill` when the hit would remove the target, minus counter times `ai.weight_counter`, plus `ai.weight_open_push` when a push hex is open. With the shipped weights a full warrior-versus-warrior Strike is negative and Shield Bash is positive, so the bash is chosen. A healthy city is negative for Strike and positive for a shot that takes no counter.

A move scores `ai.weight_closer` times the hexes gained toward a goal, or `ai.weight_capture` when the step captures. Volcanic ground subtracts `ai.weight_volcanic`. Sprint scores only when the bonus reach is strictly closer than the current reach and that tile is not already reachable. Founding scores `ai.weight_found`.

Goals, in order: a legal found tile for a settler, searched within `ai.found_radius` (5); the nearest seen enemy combatant (closer, then lower HP, then cell); a 0 HP enemy city for a unit that can capture; any known enemy city; an unrevealed tile inside `ai.explore_radius` (4) when fog is on. The found radius and the explore radius are different keys. Unseen tiles at the same distance prefer the compass direction from that player's nearest city toward the middle of the map, then the earlier axial cell. A unit with no city uses a fixed direction from its id. That heading stays put after the unit passes the middle, so it does not turn around. The old axial-only tie sent every warrior west until it fortified on the map edge.

## Fog (D4)

`fog.ai_obeys_fog` true, the shipped value, limits units, cities, and spell targets to what that player can see or has already revealed. The AI may walk toward unrevealed tiles inside the explore radius. False lets goals use the whole map. Attacks and casts still go through core, so an unseen unit and an unrevealed spell target are still rejected.

## Hazards (D5)

Water is never entered or founded on. A volcanic step or a volcanic founding is refused when that End Turn's hit would kill the unit. A step sets `acted`, so it is not healed first. Settlers have no HP and are always refused. Staying on volcanic ground to attack is allowed. Carve River is refused when any affected tile holds a friendly unit or the caster's city, including a tile core would skip. Ignite is refused when a changed tile holds a friendly the hit would kill, counting idle healing when the unit has not acted. The land check uses the real tile, including under fog.

## Production and spells (D6)

An empty queue gets one item. While combat units plus queued combat items are under `ai.military_target` (3), the next missing combatant is warrior, then archer, then scout, then another warrior. That order is the fill policy. The candidates are the unit table's combatants, so a type that is not a combatant is skipped and a new combatant is added at the end. A settler is queued only when the player has exactly one city, no settler walking or queued, and that city's population is at least `units.settler.min_city_size`. Otherwise a Granary, a Lumber Mill when a border plot has an adjacent forest, or a Mana Well, in that placement order. Those ids come from `CityRules.BUILDING_IDS`. Buildings go through `placement_tiles` and `enqueue` with that cell.

Spells run in config order. Line spells try all six directions. The best score has to beat `ai.min_spell_score` and every earlier candidate. A result land in `ai.improve_lands` (forest, hills, plains) is an improvement. A result land in `ai.worsen_lands` (water, volcanic) is a worsening. Improving own land, or unowned land within `city.border_max_radius + 1` of an own city, adds `ai.weight_improve`. The same change on a rival subtracts it. Worsening a rival's land adds `ai.weight_worsen`. Worsening own land subtracts it. The extra hex past `city.border_max_radius` is that rule, not its own key. One cast per turn, the existing `spells.casts_per_turn`.

## Presentation (D7) and tunables (D8)

The live game and the tests apply every rival action immediately, refresh once, then run the existing start-of-turn unit pick. There is no extra pan and no 0.4s wait per rival unit.

Every number is a key under `ai` in `config/game_config.json`, including `ai.max_unit_steps`, `ai.found_radius`, `ai.improve_lands`, and `ai.worsen_lands`. A missing key fails the load. Shipped `ai.enabled` is true. The map of keys versus numbers that stay in code is `docs/config.md`.

## Soaks (D9)

`tests/soak_games.gd` still plays the five seeds and prints `SOAK OK`. Rivals act on the score seeds. Smoke lets them act on the opening turns, then sets `ai.enabled` false before the scripted heal and volcanic measurements so those HP numbers stay the human's. A restart loads the file again and the AI is back on. The conquest seed captures both rival settlers before their turn. The second capture refills the hunter's AP; that refill is only the fixture, because a capture spends AP and a living rival would walk away. `SceneDriver.spare_settlers` is unchanged.

`tests/soak_ai.gd` plays seed 16016 with `RivalAI` for every player, including the human, for 20 turns or until a result. It prints `AI SOAK OK`.

Behavior tests in `tests/run_tests.gd` cover founding, a volcanic walk, a too-close settler, a warrior enqueue, a single settler queue, a damage ability, cooldown, closing in, a blocked Shield Bash, Volley on a city, Sprint, one improving cast, a refused suicidal spell, fog, water, a lethal volcano, fortify when nothing is useful, a fortified unit that still acts after AP refills, explore that heads toward the middle instead of the west edge, a human elimination that stops the later rival, `ai.enabled` false, a logged cast, and the same four rounds from seed 12345 twice.

`tests/ai_end_turn.gd` starts from the main menu on the default config, with a rolled seed and no painted map. It ends turns through `%EndTurnButton` and through Enter, including the second "End anyway" press, and requires a rival unit to change cells within 8 turns. It also requires every drawn unit sprite to sit on that unit's cell, and a hidden unit to have no sprite. CI runs it as "Run AI end turn".
