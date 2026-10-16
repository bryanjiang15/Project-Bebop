extends SceneTree

# Smoke test: Verify combat_scene.tscn loads without errors
# Tests that all @onready paths are valid and scene initializes properly

var frame = 0

func _init():
	print("\n=== COMBAT SCENE SMOKE TEST ===")

func _initialize():
	# Load and instantiate scene
	var scene_resource = load("res://scenes/combat/combat_scene.tscn")
	if scene_resource == null:
		print("[FAIL] Failed to load combat_scene.tscn")
		quit(1)
		return
	
	var combat_scene = scene_resource.instantiate()
	if combat_scene == null:
		print("[FAIL] Failed to instantiate scene")
		quit(1)
		return
	
	root.add_child(combat_scene)
	print("  Scene instantiated and added to tree")

func _process(_delta):
	frame += 1
	
	# Wait a few frames for _ready() to complete
	if frame < 10:
		return
	
	# Get root scene
	var controller = root.get_child(0)
	
	# Verify controller methods exist
	if not controller.has_method("select_part"):
		print("[FAIL] Controller missing select_part method")
		quit(1)
		return
	
	# Verify combat state
	var combat = controller.combat
	if combat == null:
		print("[FAIL] Combat state is null")
		quit(1)
		return
	
	if combat.mech == null:
		print("[FAIL] Mech not initialized")
		quit(1)
		return
	
	if combat.enemies.size() == 0:
		print("[FAIL] No enemies loaded")
		quit(1)
		return
	
	# Verify visual components created
	if controller.camera == null:
		print("[FAIL] Camera not created")
		quit(1)
		return
	
	if controller.mech_visual == null:
		print("[FAIL] Mech visual not created")
		quit(1)
		return
	
	if controller.ui == null:
		print("[FAIL] UI not created")
		quit(1)
		return
	
	# Check UI panels exist
	if controller.ui.get_node_or_null("TimePanel") == null:
		print("[FAIL] TimePanel not found")
		quit(1)
		return
	
	if controller.ui.get_node_or_null("MechPanel") == null:
		print("[FAIL] MechPanel not found")
		quit(1)
		return
	
	if controller.ui.get_node_or_null("ActionPanel") == null:
		print("[FAIL] ActionPanel not found")
		quit(1)
		return
	
	print("  All components verified successfully")
	print("[PASS] CombatSceneSmoke")
	quit(0)
