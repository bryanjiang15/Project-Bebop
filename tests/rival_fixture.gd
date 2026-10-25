extends RefCounted

## Places a rival city and warrior next to the human city on a New Game.
## The human warrior stands on the human city's only plains plot, beside the
## rival warrior. Raise Hills on the rival warrior covers both worked plots
## and the first step of a two-step move, and leaves the second step plains.


static func place(setup: GameSetup) -> Dictionary:
	var human := setup.human_index
	var rival := 0 if human != 0 else 1
	var settler := _unit(setup, human, "settler")
	var warrior := _unit(setup, human, "warrior")
	var rival_settler := _unit(setup, rival, "settler")
	var defender := _unit(setup, rival, "warrior")
	if settler == null or warrior == null or rival_settler == null or defender == null:
		return {"ok": false, "reason": "missing a starting unit"}
	var city_cell := Vector2i(10, 8)
	var worked := _step(city_cell, Hex.EAST, 1)
	var target := _step(city_cell, Hex.EAST, 2)
	var rival_cell := _step(city_cell, Hex.EAST, 3)
	var near := _step(worked, Hex.SOUTHEAST, 1)
	var far := _step(near, Hex.SOUTHEAST, 1)
	if not _geometry_ok(city_cell, worked, target, rival_cell, near, far):
		return {"ok": false, "reason": "fixture geometry"}
	if not setup.map.in_bounds(far):
		return {"ok": false, "reason": "fixture left the map"}
	var reserved := {
		city_cell: true,
		worked: true,
		target: true,
		rival_cell: true,
		near: true,
		far: true,
	}
	var park := Vector2i.ZERO
	for player in setup.players:
		for unit in player.units:
			while reserved.has(park):
				park = _next_park(setup, park)
			unit.cell = park
			reserved[park] = true
			park = _next_park(setup, park)
	settler.cell = city_cell
	warrior.cell = worked
	rival_settler.cell = rival_cell
	defender.cell = target
	for hex in Hex.disk(Hex.offset_to_axial(city_cell), 5):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	var human_city := setup.found_city(settler)
	var rival_city := setup.found_city(rival_settler)
	if human_city == null or rival_city == null:
		return {"ok": false, "reason": "city did not found"}
	var spell_disk := {}
	for hex in Hex.disk(Hex.offset_to_axial(target), setup.config.spell("raise_hills").radius):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			spell_disk[cell] = true
	for cell in setup.territory_cells(human_city):
		if cell != city_cell and cell != worked:
			setup.map.set_land(cell, "water")
	for cell in setup.territory_cells(rival_city):
		if cell == rival_cell:
			setup.map.set_land(cell, "plains")
		elif spell_disk.has(cell):
			setup.map.set_land(cell, "plains")
		else:
			setup.map.set_land(cell, "water")
	setup.map.set_land(worked, "plains")
	setup.map.set_land(target, "plains")
	setup.map.set_land(near, "plains")
	setup.map.set_land(far, "plains")
	setup._refresh_fog()
	setup.players[human].mana = setup.config.spell("raise_hills").mana * 2
	return {
		"ok": true,
		"reason": "",
		"human_city": human_city,
		"rival_city": rival_city,
		"warrior": warrior,
		"defender": defender,
		"worked": worked,
		"target": target,
		"near": near,
		"far": far,
	}


static func _geometry_ok(city_cell: Vector2i, worked: Vector2i, target: Vector2i, rival_cell: Vector2i, near: Vector2i, far: Vector2i) -> bool:
	var city := Hex.offset_to_axial(city_cell)
	var rival := Hex.offset_to_axial(rival_cell)
	if Hex.distance(city, rival) != 3:
		return false
	if Hex.distance(Hex.offset_to_axial(worked), Hex.offset_to_axial(target)) != 1:
		return false
	if Hex.distance(Hex.offset_to_axial(target), Hex.offset_to_axial(near)) != 1:
		return false
	if Hex.distance(Hex.offset_to_axial(near), Hex.offset_to_axial(far)) != 1:
		return false
	if Hex.distance(Hex.offset_to_axial(target), Hex.offset_to_axial(far)) != 2:
		return false
	if Hex.distance(city, Hex.offset_to_axial(near)) <= 1:
		return false
	if Hex.distance(rival, Hex.offset_to_axial(near)) <= 1:
		return false
	return Hex.distance(Hex.offset_to_axial(worked), Hex.offset_to_axial(far)) == 2


static func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


static func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


static func _next_park(setup: GameSetup, park: Vector2i) -> Vector2i:
	var next := Vector2i(park.x + 1, park.y)
	if next.x >= setup.map.width:
		next = Vector2i(0, park.y + 1)
	return next
