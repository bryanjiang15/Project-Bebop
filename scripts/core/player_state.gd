class_name PlayerState
extends RefCounted

class UnitState extends RefCounted:
	var id: int = 0
	var unit_type: String = ""
	var cell: Vector2i = Vector2i.ZERO
	var owner: int = 0
	var mp: int = 0
	var hp: int = 0
	var max_hp: int = 0
	## True after a move or an attack this turn. Skip and Fortify leave it false.
	var acted: bool = false
	## Persists until the unit moves. An attack does not clear it.
	var fortified: bool = false
	## "" , "skip", or "fortify". Skip lasts one turn. Fortify stays until a move.
	var order: String = ""

var index: int = 0
var human: bool = false
var color: String = ""
var units: Array[UnitState] = []
## Pooled mana. Cities add their mana yield at End Turn. Spells spend it.
var mana: int = 0
## Successful casts since this player's last turn tick.
var casts_this_turn: int = 0
## Spell id to turns remaining. Missing or 0 means the spell is ready.
## End Turn subtracts 1. A value of 2 cast this turn is ready again after two ticks.
var spell_cooldowns: Dictionary = {}
