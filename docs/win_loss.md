# Win and loss

Score, elimination, conquest, and the turn limit live in `scripts/core/`. `ScoreRules` is the formula and the ranking. `GameSetup` counts tiles, cities, and population, applies elimination, and stores the outcome on `GameSetup.result`. `MatchResult.latest` carries that outcome to the victory or defeat scene. `GameSetup.start` clears it, so Restart and New Game begin with no ending.

## Score

`GameSetup.score(player)` is `tiles × score.per_tile + cities × score.per_city + population × score.per_population`. Tiles are every cell `owner_at` returns for that player, including the city center and claimed water. Cities are that player's cities. Population is the sum of those cities' population. The weights are the config keys. There is no literal in the formula.

The top bar shows one label per player, `%Score0`, `%Score1`, and `%Score2`, filled from `GameSetup.score_line`. The human is `You`. Each other player is `Rival N` with N one-based. The label color is that player's color. `_refresh_board` updates them with the mana line, including after a spell that does not change ownership.

## Elimination

A player with no cities and no settlers is eliminated. The check runs after a change that can cause it: a unit removed by combat, a settler captured, a city captured, or a volcanic death during End Turn. Founding spends a settler and adds a city, and it does not run the check. Game start gives every player a settler, so nobody starts eliminated.

An eliminated player's remaining units are removed. They take no further part. Their row on the end screen says `Eliminated`.

## How the game ends

If the human is eliminated, the game ends immediately as Defeat. If every rival of a player is eliminated and that player is still in, that player wins by conquest, immediately, including in the middle of a turn and before the turn limit. Conquest is checked before the turn-limit ranking, including when both would be true on the same End Turn.

Otherwise the game continues until End Turn resolves the turn numbered `turn_limit` (50). Cities, mana, healing, volcanic damage, and cooldowns all resolve first. The turn counter does not advance, so the top bar never shows 51 / 50, and that next turn is not playable. Players are ranked by score, then by `ties.order`: more tiles, then more cities, then the human loses. The human wins only by ranking strictly above every other player. Anything else is Defeat.

The score ending's reason text is `Turn 50 score`, including when `turn_limit` is tuned. Conquest's reason text is `Conquest`.

## Screens

`scenes/victory.tscn` and `scenes/defeat.tscn` are the only end screens. Each has a `%ScoreTable` and a hidden `%ScoreRow` template. The screen duplicates that row once per player and shows the name, color, score, tiles, cities, population, and reason. `%LogPath` shows the absolute path of this game's log (`MatchResult.log_path`). Restart loads the config again and opens a new game. Main Menu returns to the menu. The in-game menu's Restart does the same new game. Leaving either way before the match ends writes no `end` line. See `docs/game_log.md`.

Map input stops once `GameSetup.result` is set. End Turn, spells, and orders do nothing, and the view changes scene from `_refresh_board`.

F9 and F10 used to open the end scenes directly. Those actions are gone. The end screens open only from this result, so a debug key cannot show a victory that the rules did not produce.
