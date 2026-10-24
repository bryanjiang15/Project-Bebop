# City yields, growth, borders, and production

Engineering record for ticket 9. Design still lives in `design_doc.md` and `prototype_brief.md`. Tunables stay in `config/game_config.json`. The rules are `scripts/core/city_rules.gd`, applied by `GameSetup`.

## When a city resolves

End Turn and the Enter key are still one global clock. Rivals do not take a turn of their own, so **every city resolves on that End Turn**, before the turn counter increments and before movement points refill. For each city, in id order:

1. Snapshot food, production, and mana from the current population, territory, and buildings.
2. Growth uses that food.
3. Production uses that production. A settler sees the population after growth.
4. The border clock ticks once.

A newly finished building changes yields on the next turn. The same turn's snapshot was taken before it existed.

## Yields

The city center always contributes its land yield plus `city.center_food` and `city.center_production`. It is not a citizen-worked tile.

Each population point works one other owned tile. The choice is the best land yield, and only the land yield: building bonuses are added to the city afterward and do not change which tiles are worked. The order is:

1. Higher food + production.
2. Higher food.
3. Nearer the city center.
4. Smaller axial q, then smaller axial r.

Water can be worked. It still cannot hold a unit.

Mana from this city is `city.mana_base + floor(population / city.mana_per_population_divisor)`. A Mana Well adds `buildings.mana_well_mana`. This is a per-turn display. There is no player mana pool yet.

A Granary adds `buildings.granary_food` to the city. A Lumber Mill adds `buildings.lumber_mill_production_per_adjacent_forest` for each of the six neighbors of **its** tile that is forest. The mill's own tile does not count. Two copies of a building on different tiles both apply.

## Growth

Surplus is food minus `city.food_per_population * population`. The threshold is `city.growth_base + city.growth_per_population * population`. Surplus is added to the stored bar. Each time the bar reaches the threshold, population increases by 1 and that threshold is subtracted, then the threshold is read again for the new population. Leftover food can cross more than one threshold in the same turn.

When `growth.shortfall_drains_bar` is true, a negative surplus drains the bar. If the bar would go below 0, it becomes 0 and the city loses `growth.starve_population_loss` population, not below `growth.starve_population_min`. That loss happens once per turn. A settler's population cost is separate and is taken when the settler finishes.

## Borders

Founding still claims the disk of `city.border_start_radius`. After that, every `city.border_turns_per_growth` End Turns the city claims **one** tile, up to `city.border_max_radius` from the center. The tile has to share an edge with this city's territory. It is the best land yield under the same order as worked tiles. `borders.can_claim_water` and `borders.can_claim_owned_tiles` still apply, so water can be claimed and an owned tile is not taken.

`city.radius` becomes the distance of the farthest tile this city owns. City vision stays a disk of that radius plus `fog.city_vision_beyond_border`, and it is recomputed after the claim. If nothing legal is left, the panel says the borders are full.

## Production queue

`GameSetup.enqueue` adds a unit or a building. Production stored on the city is spent on the first item. When the stored amount reaches `units.<type>.cost` or `buildings.costs.<id>`, that item finishes and the remainder stays for the next item, including later items in the same turn. An empty queue stores nothing.

Cancelling the item in front discards the stored production. Cancelling a later item does not. Moving an item keeps the stored production and applies it to whichever item is now first.

A settler can be queued and can finish only when the population is at least `units.settler.min_city_size`. When `growth.settler_population_taken_when_finished` is true, finishing subtracts `units.settler.population_cost` and the result is not allowed to pass below `growth.starve_population_min`. If the city is too small, or no legal spawn tile exists, the item stays in front and stored production stops at its cost until it can finish.

Units spawn through `GameSetup.spawn_unit`. The tile is the city center when `units.spawn_on_city_center` allows it and the tile is empty. Otherwise, when `units.spawn_nearest_free_if_blocked` is true, the nearest passable tile inside this city's borders is used (distance, then smaller q, then smaller r). Water is not a spawn tile. A tile already holding a unit is not empty.

## Buildings

A building is placed on a tile the player picks. The tile is inside this city's borders, not the city center when `buildings.not_on_city_center` is true, and empty when `buildings.one_per_tile` is true. A queued building reserves its tile the same way. The same building can be built twice on two tiles.

The panel button starts placement. The next left click on a legal tile enqueues it. An illegal tile leaves placement on and shows one of:

- `Cannot build on the city center`
- `Not in city borders`
- `Tile already has a building`
- `Cannot build off the map`

`buildings.water_destroys_building` is not applied yet. Turning a tile into water does not remove its building.

## Panel

`%CityPanel` in `scenes/game.tscn` opens when the human left-clicks their city. Food, production, mana, the growth bar, the border line, and the queue are filled from core. The build buttons are instances of `scenes/ui/menu_button.tscn`. Each queue row is an instance of `scenes/ui/queue_row.tscn`. A finished building is an instance of `scenes/view/building_marker.tscn` on `Actors`, drawn once its tile has been explored.

A left click still selects a human unit, and a right click still moves it or attacks a visible enemy. If the tile has the human's unit and the human's city, the first click selects the unit and the next click selects the city. Enter still ends the turn, and it does nothing while the in-game menu is open. City actions also do nothing while that menu is open.

While a city is selected, gold highlights mark the worked tiles. During building placement, cyan highlights mark the legal tiles.
