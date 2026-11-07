# Stability soak

Ticket 20. Five full games, back to back, with no crash and no soft-lock. There is no AI yet, so a full game is the human playing until `GameSetup.result` is set: conquest, the human eliminated, or End Turn on turn `turn_limit` (50). Rivals do not take a turn. The same harness is what ticket 16 should re-run once rivals act, and what tickets 25–29 should re-run once abilities exist.

## What it plays

`tests/soak_games.gd` is one process. It loads a temp config (`GameConfig.path_override`, `log.directory` under `/tmp/bebop-soak-logs`, not `user://logs`), opens the main menu, and presses New Game. Each later game is Restart on the Victory or Defeat screen. That is the same scene change, `MatchResult.latest` clear, and new log file as a player restarting.

The scripted human is `tests/soak_policy.gd`. It uses the view handlers the smoke tests already call: left and right click, the spell buttons, Found City, Skip, Fortify, the build buttons, queue cancel and reorder, Cancel Place, End Turn, and the menu button. `tests/scene_driver.gd` holds those helpers. `tests/smoke_game.gd` and `tests/smoke_log.gd` use it too.

Three calls go to core because no handler exists for them:

- The conquest game moves the two rival settlers onto plains beside the human warrior. Rivals never walk, and the start-distance gap is too far for a short hunt. The captures themselves are right-clicks.
- Each score game founds one rival city at `city.min_distance` so a spell can target rival-owned land. The human cannot found a city for someone else.
- Ticket 30, below.

Seeds, in order, and the ending the run must produce:

| Seed | Mode | Ending |
| --- | --- | --- |
| 12345 | score | Turn 50 score |
| 12011 | score | Turn 50 score |
| 12023 | score | Turn 50 score |
| 12059 | conquest | Conquest |
| 12073 | score | Turn 50 score |

On a score seed the human founds, queues units and buildings, casts (including Carve River through a building, and a spell on the rival city), moves and sometimes attacks, and orders Skip or Fortify. One unit is left idle on odd turns so End Turn warns and the second press confirms. The menu is opened first: Enter must not end the turn, and the End Turn button must still end it. Spell targeting and building placement are left armed on some turns so those modes cannot block End Turn.

The conquest seed founds the human city, then the warrior captures both rival settlers. That is a conquest on turn 2.

These five seeds did not place a starting settler on volcanic ground, so the ticket 30 paint did not fire. The paint is still in the loop.

## Invariants

`tests/soak_invariants.gd` checks core state after every action and every End Turn. Nothing in `scripts/core/` exists only for this.

- The turn advances by 1 on a confirmed End Turn and never goes past `turn_limit`. A turn-limit ending stays on that turn.
- No land unit stands on water.
- A tile holds at most one military unit and one civilian unit.
- Every unit is in exactly one player's list, its `owner` matches that list, and its cell is on the map.
- An eliminated player has no units and no cities.
- City HP is in `[0, max]`, population is at least 1, and every mana pool is at least 0.
- Every unit's AP is in `[0, units.<type>.ap]`. A unit with `used_ability` set has 0 AP. Ticket 25 re-ran the soak after the move-to-AP rename.
- Every owned tile is in exactly one city's territory, and that city's owner is `owner_at`.
- After `result` is set, End Turn and a click do not change units, cities, mana, land, or the selection.

The top bar's turn, mana, and score labels are checked against core while the match is still going.

## Crash and soft-lock

A crash is a `SCRIPT ERROR`, an `ERROR:`, a null dereference, or the process exiting early. The soak prints `SOAK OK` only after all five games.

A soft-lock fails the run and prints the seed, the turn, and the last action:

- A confirmed End Turn that neither advances the turn nor ends the match.
- The Victory or Defeat scene not becoming current within 120 frames of the ending.
- Restart not showing `1 / 50` with core turn 1, no result, and `MatchResult.latest` cleared.
- Spell targeting, building placement, or the in-game menu left so the board cannot accept End Turn. Enter while the menu is open must not end the turn. That is the existing rule, not a soft-lock.
- Any scene wait in the harness going past the 120-frame budget.

Each finished game's log has exactly one `start` line and one `end` line, and the `end` rows match the score table on the end screen.

## Ticket 30

A settler can spawn on volcanic ground and die at the first End Turn, which eliminates a player who has not founded. That bug is ticket 30 and is out of scope here. Map generation, spawning, and volcanic damage are unchanged.

`SceneDriver.spare_settlers(setup, true)` paints plains under a settler whose owner has no city, and only then. The soak calls it before every End Turn. Smoke still paints every volcanic settler through the same helper (`only_without_city` false). Delete the call when ticket 30 lands.

## How to run

From the repo root, after `godot --headless --path . --import` on a fresh checkout:

```bash
godot --headless --path . --script res://tests/soak_games.gd
```

Exit 0 and a final `SOAK OK` line. Locally the five games take about 2.5 seconds plus engine startup. Three runs in a row produce the same `RESULT` lines (the log file names use the clock, so those differ). CI runs this as "Run stability soak" and greps the log like the other steps.

`tests/capture_ticket20.gd` is not in CI. It plays seed 12345 with the real renderer at 2560×1440 and writes `ticket20_turn1.png`, `ticket20_turn25.png`, `ticket20_turn50_board.png`, `ticket20_end_screen.png`, and `ticket20_after_restart.png`.
