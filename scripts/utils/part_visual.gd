## Visual representation of a mech part. Mesh lives in the part scene.
extends Node3D
class_name PartVisual

@export var part_color: Color = Color.GRAY

@onready var mesh_instance: MeshInstance3D = %Mesh
var material: StandardMaterial3D
var is_highlighted: bool = false
var is_damaged: bool = false

func _ready():
	material = StandardMaterial3D.new()
	material.albedo_color = part_color
	mesh_instance.material_override = material

func set_highlight(enabled: bool):
	is_highlighted = enabled
	_update_material()

func set_damaged(health_percent: float):
	is_damaged = health_percent < 1.0
	_update_material()

func _update_material():
	if is_highlighted:
		material.albedo_color = part_color.lightened(0.3)
		material.emission_enabled = true
		material.emission = Color.WHITE * 0.2
	elif is_damaged:
		material.albedo_color = part_color.lerp(Color.RED, 0.5)
		material.emission_enabled = false
	else:
		material.albedo_color = part_color
		material.emission_enabled = false

func set_destroyed():
	material.albedo_color = Color.DIM_GRAY
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.3
