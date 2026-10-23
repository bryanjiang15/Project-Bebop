class_name PlayerState
extends RefCounted

class UnitState extends RefCounted:
	var id: int = 0
	var unit_type: String = ""
	var cell: Vector2i = Vector2i.ZERO
	var owner: int = 0
	var mp: int = 0

var index: int = 0
var human: bool = false
var color: String = ""
var units: Array[UnitState] = []
