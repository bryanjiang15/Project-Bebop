# Game log

One JSON Lines file per game records every successful spell cast and, when the match ends, the final scores. The questions it answers from the file alone are which spells are used, whether a game ended by conquest or by score or by elimination, and whether a cast changed the caster's land or someone else's.

`scripts/core/game_log.gd` builds the dictionaries. It does not touch the disk. `GameLog.Writer` is the only writer. `GameSetup.open_log` runs from `GameSetup.start_with_seed` and appends `start`. `GameSetup.cast_spell` appends `cast` only after the cast succeeds. `GameSetup._finish` appends `end` from the `MatchResult` it just built. Nothing in `scripts/view/` writes a line.

## Where the file is

`log.enabled` defaults to true. `log.directory` defaults to `user://logs`. Both keys are required. A missing or mistyped key quits through the same loader as every other config key.

The file name is `game_<YYYYMMDD-HHMMSS>_<seed>.jsonl`. The stamp is the local wall clock at the moment the file opens. The seed is the seed that built the map, the same number printed as `map seed: N`. If that name already exists (a second game in the same second with the same seed), the name gains `_2`, then `_3`, before the extension.

New Game and Restart each open a new file. stdout prints the absolute path on the next line after the seed:

```
map seed: 12345
game log: /Users/bryan/Library/Application Support/Godot/app_userdata/Project Bebop/logs/game_20261031-160345_12345.jsonl
```

On macOS, `user://` is `~/Library/Application Support/Godot/app_userdata/Project Bebop/`. The log folder is the `logs` directory inside that. The project name in `project.godot` is `Project Bebop`, space included. Victory and Defeat show the same absolute path in `%LogPath`.

A directory that cannot be created, or a file that cannot be opened or written, calls `push_warning` and leaves the match running. No later line is attempted after a write fails. Logging never quits the game.

Each line is flushed as it is written, so a crash keeps every event up to the last successful line. A game left by Restart or Main Menu before `_finish` has no `end` line. A missing `end` means the game was abandoned.

## Lines

Every line is one JSON object. `event` is `start`, `cast`, or `end`. Cells are odd-r offset coordinates, the same `Vector2i` as `UnitState.cell`: `col` is x, `row` is y. An owner of `-1` means nobody owns the tile. Names are `MatchResult.player_name`: `You` for the human, `Rival N` with N one-based for everyone else (player 1 is `Rival 2`).

`start`:

```json
{"event":"start","timestamp":"2026-10-31T16:03:45","seed":12345,"map":{"width":28,"height":18},"turn_limit":50,"players":[{"index":0,"name":"You","color":"#3D7EDB","human":true},{"index":1,"name":"Rival 2","color":"#D94A3D","human":false},{"index":2,"name":"Rival 3","color":"#E2A23A","human":false}],"score":{"per_tile":1,"per_city":10,"per_population":3}}
```

`timestamp` is local ISO-8601. `score` is the config weights, not a player's points. `players` is in index order.

`cast` (one per successful cast, any player; rejected casts are omitted):

```json
{"event":"cast","turn":1,"player":0,"player_name":"You","spell":"carve_river","spell_name":"Carve River","shape":"line","target":{"col":11,"row":8},"direction":"east","mana":25,"tiles":[{"col":11,"row":8,"from":"plains","to":"water","owner":0,"skip":"","building":"granary","queue_dropped":""}]}
```

`direction` is the hex direction name (`east`, `northeast`, `northwest`, `west`, `southwest`, `southeast`) for a line, and JSON `null` for a radius. `mana` is the amount spent. `tiles` is `spell_preview`'s affected list, in that order, snapshotted before the land changes:

- `from` is the land before the cast. `to` is the land after. A skipped tile and a tile that was already the spell's land keep `to` equal to `from`.
- `skip` is empty, `City center`, or `Unit on tile`. Those are `SpellRules.SKIP_CENTER` and `SpellRules.SKIP_UNIT`.
- `owner` is `owner_at` at cast time. It does not change when the land changes.
- `building` is the kind of a finished building the cast removes (`granary`, `mana_well`, `lumber_mill`), or empty. That is the preview's `destroyed` list, which follows `buildings.water_destroys_building`.
- `queue_dropped` is the item id of a queued building aimed at a tile that becomes water, or empty. The queue drop happens even when the finished-building flag is off. Nothing is refunded; the log only records the id.

`end`:

```json
{"event":"end","turn":50,"ending":"Turn 50 score","human_won":false,"rows":[{"player":0,"name":"You","color":"#3D7EDB","human":true,"score":20,"tiles":7,"cities":1,"population":1,"eliminated":false,"reason":"Turn 50 score"}]}
```

`ending` is `Conquest`, `Turn 50 score`, or `Eliminated`, the same strings as `MatchResult`. `rows` are copied from `MatchResult.rows`. Scores are not computed again. Nothing is appended after `end`.

## Tests

Unit tests either set `log.enabled` false or point `log.directory` at `/tmp/bebop-ticket19/...`. `tests/smoke_game.gd` sets `GameLog.directory_override` so its restarts stay out of `user://logs`. `tests/smoke_log.gd` writes a temp config (`turn_limit` 1, enough mana, two casts per turn, `log.directory` under `/tmp`) and sets `GameConfig.path_override` so New Game and Restart load that file. It casts Grow Forest and Carve River through the spell bar, ends the turn, checks `%LogPath`, and checks that Restart opens a second file.
