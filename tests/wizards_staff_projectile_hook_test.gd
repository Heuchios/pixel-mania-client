extends SceneTree

const WIZARD_PROJECTILE_SCENE := preload("res://Scenes/particles/WizardProjectileFX.tscn")
const WORLD_SCRIPT_PATH := "res://Scripts/world.gd"
const BLOCK_MANAGER_SCRIPT_PATH := "res://Scripts/block_manager.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var block_manager_source := FileAccess.get_file_as_string(BLOCK_MANAGER_SCRIPT_PATH)
	if block_manager_source == "":
		fail_test("Could not read block_manager.gd for wizard staff source coverage.")
		return
	if not block_manager_source.contains("\"wizards_staff\""):
		fail_test("Block manager does not preserve equipped wizards_staff as a hit source.")
		return

	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	if world_source == "":
		fail_test("Could not read world.gd for wizard staff hook coverage.")
		return
	if not world_source.contains("const WIZARD_PROJECTILE_FX_SCENE_PATH = \"res://Scenes/particles/WizardProjectileFX.tscn\""):
		fail_test("World is missing the wizard projectile scene path.")
		return
	if not world_source.contains("func get_wizard_projectile_fx_scene"):
		fail_test("World is missing get_wizard_projectile_fx_scene().")
		return
	if not world_source.contains("func spawn_wizards_staff_projectile_at"):
		fail_test("World is missing spawn_wizards_staff_projectile_at().")
		return
	if not world_source.contains("func spawn_wizards_staff_projectile_particles"):
		fail_test("World is missing spawn_wizards_staff_projectile_particles().")
		return
	if not world_source.contains("func is_wizards_staff_source_tool"):
		fail_test("World is missing is_wizards_staff_source_tool().")
		return
	if not world_source.contains("is_wizards_staff_source_tool(source_tool, false)"):
		fail_test("Remote source-tool routing is missing wizards_staff.")
		return

	var projectile := WIZARD_PROJECTILE_SCENE.instantiate()
	if projectile == null:
		fail_test("Could not instantiate WizardProjectileFX.")
		return
	if not projectile.has_method("launch_to"):
		fail_test("Spawned wizard projectile cannot launch to a target.")
		return

	projectile.free()
	print("[wizards-staff-projectile-hook] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[wizards-staff-projectile-hook] " + message)
	quit(1)
