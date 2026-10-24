class_name MapCity
extends RefCounted

class Item extends RefCounted:
	var item_id: String = ""
	var is_building: bool = false
	var cell: Vector2i = Vector2i.ZERO


class Building extends RefCounted:
	var kind: String = ""
	var cell: Vector2i = Vector2i.ZERO


var id: int
var player: int
var city_name: String
var cell: Vector2i
var population: int
var radius: int
var food_stored: int = 0
var production_stored: int = 0
var border_turns: int = 0
var queue: Array[Item] = []
var buildings: Array[Building] = []
