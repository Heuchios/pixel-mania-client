extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	for path in ["res://Scripts/block_manager.gd", "res://Scripts/network_manager.gd", "res://Scripts/world_state_sync_manager.gd"]:
		var script = load(path)
		assert(script.can_instantiate(), path)
	print("BREAK_SCRIPTS_PARSE_OK")
	quit()
