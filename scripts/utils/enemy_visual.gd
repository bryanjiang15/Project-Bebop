## Visual representation of an enemy
extends Node3D
class_name EnemyVisual

@export var enemy_color: Color = Color.RED
@export var enemy_size: Vector3 = Vector3(0.6, 0.8, 0.4)

var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var enemy_state: EnemyState

func _ready():
	_create_mesh()

func _create_mesh():
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = enemy_size
	mesh_instance.mesh = box_mesh
	
	material = StandardMaterial3D.new()
	material.albedo_color = enemy_color
	mesh_instance.material_override = material
	
	add_child(mesh_instance)

func initialize_from_state(state: EnemyState):
	enemy_state = state

func update_health():
	if not enemy_state:
		return
	
	if enemy_state.is_destroyed():
		visible = false
	else:
		var health_percent = float(enemy_state.current_hp) / float(enemy_state.max_hp)
		material.albedo_color = enemy_color.lerp(Color.DIM_GRAY, 1.0 - health_percent)

func set_targeted(enabled: bool):
	if enabled:
		material.emission_enabled = true
		material.emission = Color.YELLOW * 0.3
	else:
		material.emission_enabled = false

func pulse_attack():
	var tween = create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * 1.2, 0.1)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.1)
