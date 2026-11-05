class_name PlayerState
extends RefCounted

class UnitState extends RefCounted:
	var id: int = 0
	var unit_type: String = ""
	var cell: Vector2i = Vector2i.ZERO
	var owner: int = 0
	## Action points left this turn. Land movement spends them. An ability sets this to 0.
	var ap: int = 0
	var hp: int = 0
	var max_hp: int = 0
	## True after a move or an ability this turn. Skip and Fortify leave it false.
	var acted: bool = false
	## True after an ability resolved this turn. End Turn clears it. AP is 0 while this is set.
	var used_ability: bool = false
	## Ability id to turns remaining. Missing or 0 means the ability is ready.
	## End Turn subtracts 1, the same tick as PlayerState.spell_cooldowns.
	var ability_cooldowns: Dictionary = {}
	## Persists until the unit moves. An attack does not clear it.
	var fortified: bool = false
	## "" , "skip", or "fortify". Skip lasts one turn. Fortify stays until a move.
	var order: String = ""

var index: int = 0
var human: bool = false
var color: String = ""
## Set when this player has no cities and no settlers. Their units are removed.
var eliminated: bool = false
## Pooled mana for this player. GameSetup sets it from players.starting_mana.
## Spells spend it. End Turn adds the snapshotted city rates.
var mana: int = 0
var units: Array[UnitState] = []
## Successful casts since this player's last turn tick.
var casts_this_turn: int = 0
## Spell id to turns remaining. Missing or 0 means the spell is ready.
## End Turn subtracts 1. A value of 2 cast this turn is ready again after two ticks.
var spell_cooldowns: Dictionary = {}
