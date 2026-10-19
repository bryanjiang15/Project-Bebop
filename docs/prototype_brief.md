# Project Bebop — Prototype Brief (Terraforming 4X)

Source: https://app.notion.com/p/3fc6a690fbd28150bf35d7f1dcf0be1c

Notion is the source of truth. This file is a copy for the repo. If it disagrees with Notion, Notion wins. If this brief and the design doc disagree, the design doc wins.

> **What this is:** the requirements for the first playable prototype. It is based on https://app.notion.com/p/3fc6a690fbd2811c8fe2faa9845f5afb **v0.3.1**. If this brief and the design doc disagree, the design doc wins.
> **For:** the engineer building the prototype. Greybox is fine.
> **Rule for numbers:** anything marked **Prototype default (tunable / not final design)** is a starting guess so the build can run. It is not design data. All numbers live in **one config file**.

# 1. Hypothesis
A familiar Civ 6 loop (settle, explore, produce, expand, fight) becomes more interesting when players can cast **cheap, area-based terraforming spells** that reshape tiles, both their own and their rivals'.
We believe:
- Spells create real strategic choices: improve your own land, or damage a rival's.
- Land type visibly changes **yields, movement, and combat**, so reshaping the map changes what players do next.
- A 50-turn game with 2 AI rivals is enough to feel this.
# 2. Playable loop
**Turn to turn:**
1. **Settle:** found your first city with the starting settler; later, found more cities.
2. **Explore:** move units to reveal the map and rivals.
3. **Produce:** pick what each city builds; cities grow and their borders expand.
4. **Cast spells:** spend mana on a terraforming spell to reshape an area.
5. **Expand and fight:** found cities, attack rival units and cities, capture cities.
6. **Score:** watch your score against rivals.
**Feedback the player gets:** yields per tile, mana per turn, a spell preview of exactly which tiles change, before/after yield changes, combat previews, and a live score.
**Why they repeat:**
- Turn to turn: each spell opens new options (a forest to work, a hill to defend, a river to block an attack).
- Game to game: new random maps, a different spell plan, and a try at a conquest win instead of a score win.
# 3. Required behavior
## Controls (mouse-driven, Civ 6-like)
- Left-click to select a unit or city. Right-click a tile to move or attack. Hovering shows the move path and turn count.
- **End Turn** button. It warns if a unit has no orders.
- **City panel:** click a city to open it. It shows yields, growth, and the production queue. Click an item to add it to the queue.
- **Spell bar:** click a spell, then hover a target tile. A **targeting preview** highlights the affected tiles (a line or a radius) and shows their new land type. Click to cast; right-click or Esc to cancel. Line spells take a direction from the target tile (six hex directions).
- Camera: drag or arrow keys to pan; mouse wheel to zoom.
## Game states
- **Main menu / New game:** start a new game with a random map seed.
- **In game.**
- **Victory** and **Defeat** screens, each with final scores, then **Restart** (new game) or **Main menu**.
- Restart is also available from an in-game menu.
## Turns and players
- **Sequential turns**, like Civ 6: the human moves, then each AI moves.
- **3 players:** **Prototype default (tunable / not final design):** 1 human and 2 AI. The split is still a Proposal in the design doc.
- **Simple AI:** a normal, simple 4X AI.
	- **Prototype default (tunable / not final design):** it settles good nearby spots, keeps a few warriors, attacks weak nearby units and cities, and casts spells by simple rules: improve land near its own cities, and turn rival tiles near its borders into worse land.
## Map
- Civ 6-style **top-down hex grid**. Random map from a seed, using the 5 land types.
- Fog of war: unexplored tiles are hidden.
- Each player starts with a settler and a warrior, placed far apart.
- One land type per tile.
## Land types (from the design doc)

| Land type | Design doc | Prototype behavior |
| --- | --- | --- |
| Plains | Proposal: food | Food tile, easy to build on |
| Forest | Decided: production | Production tile; slower movement |
| Hills | Decided: movement and defense | Slower movement; defense bonus for units standing on it |
| Water | Proposal: blocks land units. Decided: rivers/lakes protect or destroy buildings | Land units cannot enter. Turning a tile with a building into water destroys the building. The "protect" side is open (see section 9). |
| Volcanic ground | Proposal: production with a hazard | High production; units that end their turn on it take damage |

Exact numbers are in section 5.
## Mana and spells
- Each city produces **mana** every turn; mana is pooled per player. Spells cost mana.
- Spells are **area-of-effect**: a **line** or a **radius** around a target tile. Each spell turns every affected tile into one land type.
- Starter spells (from the design doc Proposal): **Raise Hills** (radius), **Carve River** (line, makes water), **Grow Forest** (radius), **Ignite** (radius, makes volcanic ground).
	- **Prototype default (tunable / not final design):** add **Restore Plains** (radius), so any tile can be changed back to plains. The design doc says any tile can change to any type.
- Spells can target **any tile in range, including rival land**.
- Rules:
	- **Prototype default (tunable / not final design):** the target must be within cast range of a tile you own. One cast per player per turn. Each spell has its own cooldown.
	- **Prototype default (tunable / not final design):** city center tiles are never changed. Tiles with a land unit on them are skipped when the new type would be water.
- Changing a tile updates its yields, movement cost, and defense immediately. City yields refresh at once.
## Cities (Civ 6-like, simplified)
- The **settler** founds a city on its tile and is consumed. Players can train more settlers and found more cities.
	- **Prototype default (tunable / not final design):** no city within 3 tiles of another city.
- **Borders:** a new city claims the tiles around it. Borders grow over time, up to a maximum radius. Claimed tiles count for score.
- **Yields:** food, production, and mana. A city works one tile per population point, auto-assigned to the best food plus production. The city center has a fixed base yield.
- **Growth:** surplus food fills a growth bar; when full, population +1. The bar threshold rises with population.
- **Production queue:** production points go into the first item in the queue. Buildable items:
	- Units: settler, scout, warrior, archer.
	- **Prototype default (tunable / not final design):** three buildings that show land interaction: **Granary** (+food), **Mana Well** (+mana), and **Lumber Mill** (+production per adjacent forest).
	- Training a settler costs 1 population.
- **City HP:** cities have HP and heal each turn when not attacked.
## Units and combat

| Unit | Role |
| --- | --- |
| Settler | Founds a city. Cannot fight; captured or destroyed if attacked. |
| Scout | Fast; weak in combat. |
| Warrior | Melee; can capture cities. |
| Archer | Ranged attack from 2 tiles away; cannot capture cities. Weak when attacked in melee. |

- One military unit per tile (Civ 6-style). Units have HP, attack strength, movement points, and a production cost.
- **Movement:** each tile costs movement points by land type. Water blocks land units.
- **Combat:** **Prototype default (tunable / not final design):**
	- Damage = base damage × a multiplier from (attacker strength − defender strength), clamped to a minimum and maximum.
	- In melee, the defender also deals damage back to the attacker.
	- Ranged attacks take no damage back.
	- The defender's land type modifies its strength; hills give a defense bonus.
- **City capture:** attack a city to bring its HP to 0, then move a melee unit into it to capture it.
## Win and loss
- **Conquest:** a player who eliminates all rivals wins immediately, before turn 50.
- Otherwise, **at the end of turn 50**, the highest score wins.
- **Score:** tiles controlled + cities + population, with weights in the config. This is a Proposal in the design doc.
- **Elimination:** a player with no cities and no settlers is eliminated.
- **Loss:** the human is eliminated, or doesn't have the highest score at turn 50.
- **Ties:** **Prototype default (tunable / not final design):** more tiles wins.
## Visual style
- Civ 6-style **top-down hex view**: readable tiles by terrain, cities on tiles, city name banners, and colored territory borders.
- **Greybox is fine:** flat colored hexes, one color per land type, and simple icons for units and cities.
- **Reference:** the Civ 6 map screenshot in the design doc under Prototype scope → Visual style. Whether to use true 2D sprites or 3D with a fixed top-down camera is open.
# 4. Explicit exclusions
- Tomes, tech tree, civics tree.
- Land bosses; land fusion; special tiles with restricted changes.
- Terraforming by units or city structures. Spells are the only way to terraform.
- Natural disasters and events.
- Wetlands, storm, living land, and other magical land types.
- Districts, amenities, loyalty, great people, trade routes, religion.
- Diplomacy, city-states, barbarians.
- Multiplayer.
- Save and load.
- Audio, music, animation, and art polish; settings menus; tutorial beyond a short controls overlay.
- Any unit beyond settler, scout, warrior, and archer; any building beyond the three listed.
# 5. Tunable values
**Every value below is a Prototype default (tunable / not final design)**, except the turn limit, player count, and land-type list, which are decided in the design doc. Keep all values in one config file.

| Value | Starting default | Notes |
| --- | --- | --- |
| Turn limit | 50 | Decided |
| Players | 3 (1 human, 2 AI) | 3 is decided; the split is a Proposal |
| Map size | 28 × 18 hexes | Small; start positions at least 8 tiles apart |
| Map land mix | Plains 35%, water 25%, forest 20%, hills 15%, volcanic 5% | Random from seed |
| Plains: food / production / move cost / defense | 2 / 0 / 1 / 0% |  |
| Forest: food / production / move cost / defense | 1 / 2 / 2 / 0% |  |
| Hills: food / production / move cost / defense | 1 / 1 / 2 / +25% | Defense applies to the unit standing on the tile |
| Water: food / production / move cost | 1 / 0 / impassable | Land units cannot enter; destroys a building when created on its tile |
| Volcanic ground: food / production / move cost / hazard | 0 / 3 / 1 / 10 damage | Damage to a unit that ends its turn on the tile |
| City center yield | 2 food, 2 production | Plus the yield of the tile's land type |
| City mana per turn | 2 + 1 per 2 population | Mana Well adds +2 |
| Starting mana | 10 | Enough for one cheap spell early |
| Growth threshold | 10 + 6 × current population | Food per population: 2 per turn |
| Borders | Radius 1 at founding; +1 tile every 4 turns; max radius 3 | New tile picked by best yield |
| Minimum city distance | 3 tiles |  |
| Production costs | Settler 40, Scout 20, Warrior 30, Archer 45, Granary 50, Mana Well 60, Lumber Mill 50 | Settler also costs 1 population; city must be size 2+ |
| Building effects | Granary +2 food; Mana Well +2 mana; Lumber Mill +1 production per adjacent forest | Lumber Mill reacts to Grow Forest and Ignite |
| Spell: Grow Forest | Radius 1 (7 tiles), 15 mana, range 3, cooldown 2 | Makes forest |
| Spell: Raise Hills | Radius 1 (7 tiles), 20 mana, range 3, cooldown 3 | Makes hills |
| Spell: Carve River | Line of 4 tiles, 25 mana, range 3, cooldown 3 | Makes water |
| Spell: Ignite | Radius 1 (7 tiles), 35 mana, range 2, cooldown 5 | Makes volcanic ground |
| Spell: Restore Plains | Radius 1 (7 tiles), 10 mana, range 3, cooldown 2 | Makes plains; added so any tile can be reverted |
| Casts per turn | 1 | Design doc Proposal: 1 or 2 |
| Range measured from | Any tile you own |  |
| Scout: HP / attack / move / cost | 50 / 5 / 3 / 20 |  |
| Warrior: HP / attack / move / cost | 100 / 20 / 2 / 30 |  |
| Archer: HP / ranged attack / defense / range / move / cost | 100 / 25 / 12 / 2 / 2 / 45 | Defense used when attacked |
| Settler: HP / move / cost | Non-combat / 2 / 40 | Captured if a military unit moves onto it |
| Combat damage | 30 × 1.04\^(attacker − defender), clamped 5 to 60 | Melee defender deals the same formula back |
| Terrain combat modifiers | Hills +25% defense; all others 0% | Applied to the defender's strength |
| Unit healing | +10 HP per turn when not moving or fighting |  |
| City: HP / defense strength / heal | 100 / 15 / +10 per turn | Cities don't attack in the prototype |
| Score weights | 1 per tile, 10 per city, 3 per population | Formula itself is a Proposal in the design doc |

# 6. Completion criteria (before testing)
- [ ] New game from the main menu generates a random hex map with the 5 land types, fog of war, and 3 players.
- [ ] Settler founds a city; more settlers can be trained and found more cities; the city distance rule applies.
- [ ] Cities show yields, grow, expand borders, and build from a production queue.
- [ ] Mana accumulates from cities and shows in the top bar.
- [ ] All 5 spells work. The targeting preview shows the exact affected tiles for both line and radius shapes. Range, cost, cooldown, and one cast per turn are enforced.
- [ ] Spells can change rival land. Tile yields, movement, defense, and city yields update immediately.
- [ ] Water blocks land units. Creating water on a building destroys it. Volcanic ground damages units.
- [ ] Units move with land-based movement costs; melee, ranged, and counter-damage work; hills give defense.
- [ ] Cities can be attacked to 0 HP and captured by melee units; settlers can be captured.
- [ ] Both AIs settle, build, fight, and cast spells without stalling a turn.
- [ ] Conquest win ends the game immediately; otherwise the game ends after turn 50 with scores; victory, defeat, and restart work.
- [ ] All tunables load from one config file.
- [ ] A simple log per game records every spell cast (who, which spell, which tiles) and the final scores.
- [ ] 5 full games played without crashes or soft-locks.
# 7. Learning criteria
## What to observe
- Do players cast spells regularly, and for a reason they can explain?
- Do players terraform **rivals'** land, or only their own?
- Does a land change visibly change a decision: where to settle, where to attack, what to build?
- Is spell targeting readable: do players predict which tiles will change?
- Is a 50-turn game fun and finished in a reasonable session length?
- Does the AI create pressure: does it expand, attack, and terraform?
- Which spells get used most and least? How many games end by conquest vs. score?
## Continue, change, or stop
- **Continue if:**
	- Most players cast spells most turns once they have mana.
	- Players use spells against rivals at least sometimes.
	- Players describe land changes as part of their strategy.
	- Players want another game.
- **Change direction if:**
	- Spells are ignored, or one spell dominates.
	- Terraforming rival land never happens.
	- Land changes don't change decisions.
	- The AI offers no pressure.
	- Possible responses: tune costs and yields, change spell shapes, or strengthen the AI.
- **Stop or rethink the core if:**
	- After tuning, terraforming still feels like a side activity next to a plain Civ loop.
	- Players find the constantly changing map confusing rather than interesting.
# 8. Recommended UI readout
- **Top resource bar:** food, production, **mana** (with per-turn gain), turn number (e.g. "Turn 12 / 50"), and score for all players.
- **Minimap** at the bottom left, with borders and fog.
- **City panel** at the bottom right: yields, growth bar, borders, and the production queue.
- **Spell bar:** each spell with its mana cost, cooldown, and shape icon; spells you can't afford or that are on cooldown are greyed out.
- **Tile tooltip** on hover: land type, yields, movement cost, defense, owner, and any unit or building on it.
- **Previews:** the spell area with before/after land type and yield change, and the combat result.
# 9. Open questions for the engineer
- **Engine and platform:** not decided.
- Rendering: true 2D sprites, or 3D with a fixed top-down camera? Greybox works either way.
- Map generation: is a simple noise-based generator enough, and how should start positions be balanced?
- AI depth: how much AI is enough to create pressure in 50 turns? Flag the cost of anything beyond simple rules.
- Rivers and lakes "protect" buildings in the design doc, but the rule isn't defined. The prototype implements only "destroy". Should a protect rule be added (for example, defense for cities next to water)?
- Line spell targeting: is choosing one of the six hex directions from the target tile clear enough?
- Which defaults in sections 3 and 5 are expensive to build? Flag them so we can simplify.
