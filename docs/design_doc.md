# Project Bebop — Game Design Doc (Terraforming 4X)

Source: https://app.notion.com/p/3fc6a690fbd2811c8fe2faa9845f5afb

Notion is the source of truth. This file is a copy for the repo. If it disagrees with Notion, Notion wins. Where this design doc and the prototype brief disagree, this design doc wins.

> **Status: Draft v0.3.1** (2026-10-17). Based on Bryan's new pitch: a turn-based 4X game focused on terraforming. v0.2 adds Bryan's answers to the v0.1 open questions and a Prototype scope section. v0.2.1 adds a Visual style (prototype) subsection. v0.3 adds Bryan's answers to the prototype questions. v0.3.1 settles the early conquest win and leaves natural disasters out of the first prototype.
> - Plain text is **decided**: it comes from the pitch or Bryan's answers.
> - **Proposal** marks anything not from Bryan. These are suggestions to discuss, not final calls.
> - Unresolved items are listed in **Open questions** at the end.

# 1. One-page concept
**Pitch:** Project Bebop is a turn-based 4X civilization builder in the style of Civilization 6 and Age of Wonders 4, with a large focus on terraforming. Units can change the land type of hex tiles and are affected by the land they stand on. (v0.2: for now, terraforming is done by player spells; see section 7.) City structures affect the land and are affected by it. Land types range from familiar ones (forest, wetlands, hills) to wild and magical ones (rivers and lakes, volcanoes, storms, living land). Land types can be fused into new types, and a final-boss character can be challenged and controlled to gain control of a specific land type.
**Genre:** turn-based 4X strategy (explore, expand, exploit, exterminate) on a hex grid.
**Player fantasy:** **Proposal:** "I reshape the world itself to win." The player is a ruler who wins by bending the map, not only by out-building or out-fighting rivals.
## Inspirations

| Game | What we borrow (from the pitch) | What's different |
| --- | --- | --- |
| Civilization 6 | Hex grid; units that explore and fight; cities that produce; simple 4X features; land effects such as forest for production and hills for movement and defense | Land is not fixed: players constantly reshape it, including enemy land. **Proposal:** fewer systems overall so terraforming stays the focus. |
| Age of Wonders 4 | Tome system: specializations unlocked at different levels | **Proposal:** specializations tie into land types and the land boss, rather than races or magic schools. |

# 2. Pillars
1. **Terraforming.** The map is flexible and constantly changing. Units and cities have effects that depend on the land around them. Players are encouraged to terraform aggressively, including manipulating other players' land, while staying able to switch strategy.
	- *What this means for design:* terraforming must be cheap and frequent enough to matter every few turns. Most stats should read from the surrounding land. There must be tools to attack and defend land, and changes should be reversible enough that a plan can be adjusted. **Proposal**
2. **Expansion.** The player's main goal is to expand, in one of three ways: military strength to defeat all enemies, terraforming to control the vast majority of land, or powering up their land boss.
	- *What this means for design:* the three routes need to be viable and visibly different. Each one needs its own progress readout and its own win condition. **Proposal**
3. **Flexibility.** The player changes strategy based on the surrounding map, other players, and in-game events.
	- *What this means for design:* avoid locking players into one path early. Starting maps, opponents, and events should push different answers. Allow respecs or pivots at a cost. **Proposal**
4. **Replayability.** The game should play differently each time.
	- *What this means for design:* use procedural maps, different land bosses, different fusion combinations, and varied events. **Proposal**
# 3. Prototype scope
**Decided (v0.2):** the prototype is a Civ 6-style 4X loop: explore, start with one city, produce, and fight a simple battle.
**In:**
- Exploring the map with units.
- Civ 6-style cities (v0.3): a settler founds the first city, and players can found more cities.
- Prototype land types (v0.3): plains, forest, hills, water, volcanic ground.
- Sequential turns, like Civ 6 (v0.3).
- Simple combat between units and against cities.
- Terraforming by player spells (AoW4-style). Any tile can change to any land type.
- A simple, normal 4X AI for opponents.
- A small map with 3 players and a 50-turn limit. **Proposal:** 1 human and 2 AI.
**Out (future versions):**
- Tomes and tech tree.
- Land bosses.
- Land fusion.
- Special tiles with restricted changes.
- Terraforming by units and city structures.
- Wetlands, storm, and living land (v0.3).
- Natural disasters (v0.3.1; later versions).
**Decided (v0.3, v0.3.1):** eliminating all rivals wins before turn 50 (conquest ends the game early); otherwise the player with the highest score at turn 50 wins. **Open:** the score formula. See Open questions.
## Visual style (prototype)
**Decided (v0.2.1):** the prototype's view should look like Civ 6's map: a hexagon grid seen in a top-down, 2D-style view of hex tiles.
*Reference image lives on the Notion page (Civ 6 map view).*
**What the reference shows:**
- Colorful, clearly readable hex tiles by terrain: grassland, forest, hills and mountains, water, desert.
- Cities and buildings sitting on tiles.
- City name banners.
- Colored territory borders.
- A resource and yield bar at the top.
- A minimap at the bottom left.
- A city and production panel at the bottom right.
**Proposal / open:**
- **Rendering:** true 2D sprites, or 3D with a fixed top-down camera. Not decided.
- **Art fidelity:** greybox colored hexes (one color per land type) are acceptable early in the prototype; richer tile art can come later.
- **UI elements:** which ones the prototype needs. Suggested minimum: resource and yield bar, city banners, territory borders, and a city and production panel; minimap optional.
# 4. Core loop and turn structure
**Decided (v0.2), prototype:** explore, start with one city, produce, simple fight (Civ 6-style).
**Proposal** (the steps below are not decided):
1. **Explore:** scout with units and reveal tiles and land types.
2. **Expand:** grow cities and found new ones to claim tiles (decided v0.3: like Civ 6).
3. **Terraform:** cast terraforming spells to change tiles to suit your city and units, or to hurt rivals.
4. **Exploit:** your city produces resources from its land; spend them on units, structures, and spells.
5. **Exterminate / contest:** fight units and cities and contest land. (Land bosses come in later versions.)
**Decided (v0.3):** players take turns in sequence, like Civ 6. **Proposal: steps within a turn.** Each turn: resolve start-of-turn land and event effects → give unit orders (move, attack) → cast terraforming spells → manage the city (production, structures) → end turn. (Specialization choices come in later versions.)
# 5. Map and hex grid
- **Decided:** hex grid (from Civ 6). Every tile has a land type, which affects the units on it and the city structures near it.
- **Decided:** cities claim board space.
- **Decided (v0.2), prototype:** small map, 3 players, 50-turn limit. Exact size is open.
- **Proposal:** procedurally generated maps; fog of war. Later versions place land boss cities on the map.
- **Proposal:** a tile has one land type at a time, plus optional overlays such as a river edge or an active storm.
# 6. Land types

| Land type | Tier | Effect | Source |
| --- | --- | --- | --- |
| Forest | Base | Production | Pitch |
| Wetlands | Base | Growth | Pitch |
| Hills | Base | Movement and defense | Pitch |
| Rivers / lakes | Exotic | Protect or destroy buildings (confirmed v0.2) | Pitch |
| Volcano | Exotic | Not yet defined | Pitch |
| Storm | Exotic | Has active effects | Pitch |
| Living land | Magical | Not yet defined | Pitch |
| Other magical types | Magical | Not yet defined | Pitch |
| Plains | Base | **Proposal:** neutral default tile; easy to build on | Proposal |
| Desert or wasteland | Base | **Proposal:** low yields; cheap to terraform; result of over-terraforming or volcanic ash | Proposal |

- **Decided:** the pitch separates familiar land (forest, wetlands, hills) from "more crazy" ones. The Base / Exotic / Magical tier labels are a **Proposal**.
- **Decided (v0.2):** for now, any tile can change to any type. **Future:** special tiles that can only change to certain types, or can only be created from certain types.
- **Proposal (future):** tiers could later decide which tomes unlock which types.
- **Decided (v0.3):** the prototype uses five land types. Wetlands, storm, and living land are out of the prototype.

| Prototype land type | Effect | Status |
| --- | --- | --- |
| Plains | **Proposal:** food; neutral default tile, easy to build on | Type decided; effect is a Proposal |
| Forest | Production | Decided (pitch) |
| Hills | Movement and defense | Decided (pitch) |
| Water | **Proposal:** blocks land units. Rivers and lakes protect or destroy buildings (decided v0.2). | Type decided; effect partly a Proposal |
| Volcanic ground | **Proposal:** production with a hazard (e.g. a chance to damage units or buildings on or next to it) | Type decided; effect is a Proposal |

# 7. Terraforming system
- **Decided:** land affects units and city structures. Players are encouraged to terraform other players' land.
- **Decided (v0.2):** for now, terraforming is done by **player spells**, like AoW4 spells. **Future:** units and city structures may also terraform. (The pitch's unit terraforming moves to the future.)
- **Decided (v0.2):** any tile can change to any type, so every change can be reversed. Special tiles with limits are future.
- **Decided (v0.3):** spells cost **mana**, a resource that cities produce. Spells are **area-of-effect**: some hit a line of tiles, some a radius around a target point.
- **Starter spells:** **Proposal:** Raise Hills (radius), Carve River (line), Grow Forest (radius), Ignite (turns tiles into volcanic ground; radius).
- **Cost:** **Proposal:** mana cost scales with area size and land type; e.g. Grow Forest is cheap, Ignite is expensive. Exact costs are open.
- **Limits:** **Proposal:** a cast range measured from your cities or territory, and one or two casts per turn. Exact range and limits are open.
- **Adjacency effects:** **decided** that effects depend on surrounding land. **Proposal:** structures and units get bonuses from adjacent tiles, Civ 6 adjacency-style.
- **Terraforming enemy land:** **decided** that it is encouraged. **Proposal:** spells can target enemy tiles within range; defenders can counter-terraform.
# 8. Land fusion
- **Decided:** players can combine land types into a new fusion land type.
- **Decided (v0.2):** fusion is an **experimental idea for later**, not in the prototype. It happens when a tile is terraformed back and forth between two types many times, until it reaches a threshold and becomes a new fused land type.
- **Proposal:** example fusions: Forest ↔ Wetlands becomes Swamp; Hills ↔ Volcano becomes Lava ridge. Names and pairs are examples only.
- **Open (later):** the threshold, whether fused land can be changed again, and how many fusion types exist.
# 9. Land bosses
- **Decided:** a final-boss character exists that the player can challenge and then control, which gives control of a specific land type. This creates diversity in land types between players. Powering up your land boss is one route to expansion.
- **Decided (v0.2):** land bosses work like Civ 6 city-states and act as a city. The player must **capture** the city to control it, or **destroy** it to remove its influence. Future versions only, not the prototype.
- **Proposal:**
	- **Power up:** the boss grows stronger with the number of tiles of its land type the player controls.
	- **Tie to land type:** each boss unlocks one exclusive exotic or magical land type and its terraforming spell.
- **Open (later):** how many bosses exist, and how many one player can control.
# 10. Cities and structures
- **Decided:** cities produce resources and claim board space. City structures affect the land and are affected by it.
- **Decided (v0.2):** Rivers and lakes can protect or destroy buildings.
- **Decided (v0.3):** cities behave like Civ 6 for now, and the start is the same as Civ 6: a settler founds the first city, players can found more cities, and cities use a Civ-style production queue, yields, borders, and growth. Details follow Civ 6 conventions, simplified for the prototype. Cities also produce mana for spells.
- **Proposal:**
	- Cut from the prototype: districts, amenities, loyalty, great people, trade routes, and religion. Which systems are cut is open.
	- Tile yields come from land type: plains food, forest production, volcanic ground production.
	- Structures have land requirements and bonuses, e.g. a lumber mill must be next to forest.
	- Hostile land can damage structures: a flood or volcano can destroy buildings.
	- Later versions: structures can also change nearby land, e.g. a dam creates a lake (structure terraforming is future).
- **Open:** exact yields per land type, the prototype build list, and which Civ 6 systems are cut.
# 11. Units and combat
- **Decided:** units scout, move around the map, and fight other units and cities. Units are affected by the land they stand on: for example, hills affect movement and defense.
- **Decided (v0.2):** the prototype has a simple fight.
- **Proposal:**
	- Civ 6-style one unit per tile, with melee and ranged attacks.
	- Each land type modifies movement cost, attack, and defense.
	- Unit roles for the prototype: scout and military.
	- Later versions: some units can terraform, e.g. turning a defender's hill into wetland.
- **Open:** combat basics for the prototype.
# 12. Specialization
- **Decided:** there is some kind of skill tree (like Civ 6) or ability system (like AoW4 tomes). AoW4's tome system is an inspiration for specializations at different levels.
- **Decided (v0.2):** leading direction is **AoW4-style tomes**: the player picks tomes with different specializations. Not final, and **not in the prototype**.
- Options:

| Option | How it works | Fits pillars |
| --- | --- | --- |
| Tech tree (Civ 6) | One shared tree; research unlocks units, structures, terraforming | Familiar; less variety between runs |
| Tomes (AoW4) — **leading direction (v0.2)** | Pick themed books at each tier; each unlocks a set of abilities | Strong for Flexibility and Replayability. **Proposal:** tomes per land family (e.g. Tome of Water, Tome of Fire) |

# 13. Win conditions
**Decided** (the three routes from the Expansion pillar, for the full game):
1. **Conquest:** defeat all enemies by military strength.
2. **Land control:** control the vast majority of the map's land through terraforming.
3. **Land boss power:** power up your land boss (future; bosses are not in the prototype).
**Decided (v0.2), prototype:** a 50-turn limit. **Decided (v0.3):** the player with the highest score at turn 50 wins.
**Decided (v0.3.1):** conquest ends the game early: eliminating all rivals wins before turn 50.
**Proposal (prototype):** score = tiles controlled + cities + population. The formula is open.
**Proposal (full game):** land control means owning a set share of all tiles for a number of turns; land boss power means reaching a final boss level. Thresholds are open.
# 14. Events
- **Decided:** in-game events happen, and players adapt to them. Volcanoes and storms with active effects are named as land effects.
- **Proposal:**
	- Map events such as storms that move across tiles, eruptions that spread volcanic land, and floods.
	- Events are telegraphed a turn or more ahead.
	- Players can trigger some events with exotic terraforming.
- **Decided (v0.3):** events such as storms and volcano eruptions follow Civ 6's natural disasters approach.
- **Decided (v0.3.1):** natural disasters are **not** in the first prototype; they come in later versions.
# 15. Opponents
- **Decided:** there are other players, and players can manipulate each other's land.
- **Decided (v0.2):** the prototype uses a simple, normal 4X AI, with 3 players. **Proposal:** 1 human and 2 AI (still a Proposal as of v0.3).
- **Decided (v0.3):** sequential turns, like Civ 6.
- **Open (later):** multiplayer, and how many players per map in the full game.
# 16. Replayability
- **Decided:** a pillar; each game should play differently.
- **Proposal:** sources of variety are procedural maps, different land types and spells, random events, and later land bosses, tome choices, and fusion.
# 17. Decision log
- 2026-10-17 **Project restart.** Bryan scrapped the earlier mech concept and reset the board. All previous Bebop design content no longer applies. This doc (Draft v0.1) is written from the new terraforming 4X pitch.
- 2026-10-17 **v0.2: Bryan's answers to the open questions.**
	- Prototype scope: Civ 6-style loop (explore, one starting city, produce, simple fight). No tech tree or tomes.
	- Terraforming is done by player spells for now; units and structures may terraform later. This replaces the v0.1 Proposal of dedicated terraformer units.
	- Any tile can change to any type for now; special restricted tiles are future. This replaces the v0.1 Proposal that tiers gate who can create which types.
	- Land bosses work like Civ 6 city-states (capture to control, destroy to remove influence). Future only. This replaces the v0.1 Proposal of a boss lair and a boss that joins as a unit.
	- Fusion is experimental and for later: a tile terraformed back and forth between two types reaches a threshold and fuses. This replaces the v0.1 Proposal of fusing two adjacent tiles.
	- Specialization: AoW4-style tomes are the leading direction, not final, not in the prototype.
	- Opponents: simple normal 4X AI for the prototype (confirms the v0.1 Proposal).
	- Prototype size: small map, 3 players, 50-turn limit.
	- Rivers and lakes protect or destroy buildings ("present" meant "protect").
	- v0.2.1: the prototype's view should look like Civ 6's 2D-style hex map (top-down view of hex tiles). Reference image added under Prototype scope → Visual style.
- 2026-10-17 **v0.3: Bryan's answers to the prototype questions.**
	- Prototype land types: plains, forest, hills, water, volcanic ground. Forest and hills keep the pitch effects; plains, water, and volcanic ground effects are Proposals. Wetlands, storm, and living land are out of the prototype.
	- Spells cost mana, which cities produce. Spells are area-of-effect (line or radius). Starter list, costs, range, and limits are Proposals.
	- Win: highest score at turn 50. Early conquest win and the score formula are open.
	- Cities work like Civ 6, including the start (settler founds the first city; more cities allowed). This replaces the v0.2 "one starting city" wording. Which Civ 6 systems are cut is open.
	- Sequential turns, like Civ 6. Events follow Civ 6's natural disasters approach; whether they are in the first prototype is open.
	- 1 human + 2 AI stays a Proposal.
- 2026-10-17 **v0.3.1:** conquest ends the game early (eliminating all rivals wins before turn 50; otherwise highest score at turn 50 wins). Natural disasters are not in the first prototype (later).
# 18. Open questions
## v0.1 questions (resolved items struck through)
1. ~~The pitch says rivers or lakes "present or destroy buildings." Is "present" meant to be "protect", or something else?~~ **Resolved:** "protect". Rivers and lakes protect or destroy buildings.
2. ~~Specialization: Civ 6-style tech tree, AoW4-style tomes, or a mix?~~ **Leading direction:** AoW4-style tomes. Not final; not in the prototype.
3. Terraforming: ~~which units can terraform,~~ what does it cost, and what limits it? **Answered in part:** player spells for now; units and structures later. Cost and limits move to the prototype list.
4. ~~Can every land type be changed back, or are some permanent?~~ **Resolved:** any tile can change to any type for now. Special tiles are future.
5. ~~How does land fusion work: trigger,~~ cost, permanence, number of fusion types? **Answered in part:** repeated back-and-forth terraforming until a threshold. Experimental, for later.
6. ~~Land bosses: how are they challenged,~~ how many can a player control, ~~and can they be lost or stolen?~~ **Answered in part:** like Civ 6 city-states; capture to control, destroy to remove influence. Future.
7. What does "power up your land boss" need to reach for a win? (Later.)
8. What share of the land counts as "the vast majority" for a land-control win? (Later.)
9. What exactly do volcanoes, storms, living land, and the other magical types do? (Prototype types are in the list below.)
10. Opponents: ~~AI, multiplayer, or both? Sequential or simultaneous turns?~~ **Answered:** simple normal 4X AI for the prototype; multiplayer later. Sequential turns (v0.3).
11. Map: ~~size, generation, and number of players.~~ **Answered in part:** small, 3 players, 50 turns. Exact size and generation move to the prototype list.
12. Resource list: which resources do cities produce, and which land produces each? (Moves to the prototype list.)
## Open for the prototype
1. ~~Which land types are in the prototype,~~ and what exactly does each do? **Answered in part (v0.3):** plains, forest, hills, water, volcanic ground. Plains, water, and volcanic ground effects are still Proposals.
2. Terraforming spells: what do they cost, ~~which resource pays for them,~~ and what range or per-turn limits apply? **Answered in part (v0.3):** mana, produced by cities; spells are area-of-effect (line or radius). Starter list, costs, range, and limits are Proposals.
3. City production basics: which resources, yields per land type, what the city can build, ~~and whether players can found more cities.~~ **Answered in part (v0.3):** cities work like Civ 6 (settler start, more cities, production queue, yields, borders, growth). Still open: exact yields, the build list, and which Civ 6 systems are cut.
4. Combat basics: unit types and stats, how land modifies combat, and how cities are attacked and captured.
5. ~~What happens at turn 50: scoring, a winner, or something else?~~ ~~Can conquest end the game earlier?~~ What is the score formula? **Answered in part (v0.3, v0.3.1):** conquest ends the game early; otherwise highest score at turn 50 wins. **Proposal:** score = tiles controlled + cities + population.
6. Exact map size and how the map is generated.
7. ~~Turn order: sequential or simultaneous.~~ **Resolved (v0.3):** sequential, like Civ 6.
8. ~~Are events (storms, volcanoes) in the prototype?~~ **Resolved (v0.3.1):** not in the first prototype; later versions follow Civ 6's natural disasters approach.
9. Confirm the player split (**Proposal:** 1 human and 2 AI). Still a Proposal as of v0.3.
10. Visual style: true 2D sprites or 3D with a fixed top-down camera, the art fidelity for the prototype, and which UI elements it needs.
## Open for later versions
1. Final specialization system (tomes are the leading direction).
2. Land bosses: how many exist, how many one player can control, and how power-up works.
3. Land-control win threshold.
4. Fusion: threshold, permanence, number of fusion types.
5. Special tile rules.
6. How units and city structures terraform.
7. Multiplayer.
