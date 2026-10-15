## Visual controller for the mech
extends Node3D
class_name MechVisual

var legs_node: Node3D
var hip_socket: Marker3D
var torso_node: Node3D
var head_socket: Marker3D
var arm_socket_l: Marker3D
var arm_socket_r: Marker3D

var part_visuals: Dictionary = {}
var mech_state: MechState

var standing_hip_height: float = 1.2
var crouch_hip_height: float = 0.7
var jump_height: float = 2.4

func _ready():
	_setup_hierarchy()

func _setup_hierarchy():
	legs_node = Node3D.new()
	legs_node.name = "Legs"
	add_child(legs_node)
	
	hip_socket = Marker3D.new()
	hip_socket.name = "HipSocket"
	hip_socket.position = Vector3(0, standing_hip_height, 0)
	legs_node.add_child(hip_socket)
	
	torso_node = Node3D.new()
	torso_node.name = "Torso"
	hip_socket.add_child(torso_node)
	
	head_socket = Marker3D.new()
	head_socket.name = "HeadSocket"
	head_socket.position = Vector3(0, 0.8, 0)
	torso_node.add_child(head_socket)
	
	arm_socket_l = Marker3D.new()
	arm_socket_l.name = "ArmSocket_L"
	arm_socket_l.position = Vector3(-0.5, 0.3, 0)
	torso_node.add_child(arm_socket_l)
	
	arm_socket_r = Marker3D.new()
	arm_socket_r.name = "ArmSocket_R"
	arm_socket_r.position = Vector3(0.5, 0.3, 0)
	torso_node.add_child(arm_socket_r)

func initialize_from_state(state: MechState):
	mech_state = state
	_load_parts()

func _load_parts():
	var part_scenes = {
		"legs": "res://scenes/mech/part_legs.tscn",
		"torso": "res://scenes/mech/part_torso.tscn",
		"left_arm": "res://scenes/mech/part_arm.tscn",
		"right_arm": "res://scenes/mech/part_arm.tscn",
		"head": "res://scenes/mech/part_head.tscn"
	}
	
	for part_name in mech_state.parts:
		var part_scene = load(part_scenes[part_name])
		var part_visual = part_scene.instantiate()
		part_visuals[part_name] = part_visual
		
		match part_name:
			"legs":
				legs_node.add_child(part_visual)
			"torso":
				torso_node.add_child(part_visual)
			"left_arm":
				arm_socket_l.add_child(part_visual)
			"right_arm":
				arm_socket_r.add_child(part_visual)
			"head":
				head_socket.add_child(part_visual)

func update_movement_state():
	if not mech_state:
		return
	
	var target_height = standing_hip_height
	var leg_scale = Vector3.ONE
	
	match mech_state.movement_state:
		MechState.MovementState.CROUCHING:
			target_height = crouch_hip_height
			leg_scale = Vector3(1.0, 0.6, 1.0)
		MechState.MovementState.AIRBORNE:
			target_height = jump_height
			leg_scale = Vector3(1.0, 0.8, 1.0)
		_:
			target_height = standing_hip_height
			leg_scale = Vector3.ONE
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hip_socket, "position:y", target_height, 0.3)
	if part_visuals.has("legs"):
		tween.tween_property(part_visuals["legs"], "scale", leg_scale, 0.3)

func update_part_health():
	if not mech_state:
		return
	
	for part_name in part_visuals:
		var part: MechPart = mech_state.parts.get(part_name)
		var visual: PartVisual = part_visuals[part_name]
		
		if part.is_destroyed():
			visual.set_destroyed()
		else:
			var health_percent = float(part.current_hp) / float(part.max_hp)
			visual.set_damaged(health_percent)

func highlight_part(part_name: String, enabled: bool):
	if part_visuals.has(part_name):
		part_visuals[part_name].set_highlight(enabled)
