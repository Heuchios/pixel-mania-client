extends RefCounted

# World-entry clicks/keys belong to the old screen, never to a newly exposed HUD.
static func is_blocked(world: Node) -> bool:
	if world == null:
		return false
	return bool(world.get_meta("world_transition_ui_blocked", false)) or bool(world.get_meta("world_entry_in_progress", false)) or bool(world.get_meta("world_loading_input_blocked", false)) or Time.get_ticks_msec() < int(world.get_meta("world_transition_ui_resume_msec", 0))

static func begin(world: Node) -> void:
	if world == null:
		return
	world.set_meta("world_transition_ui_blocked", true)
	clear_popups_and_focus(world)

static func finish(world: Node) -> void:
	if world == null:
		return
	clear_popups_and_focus(world)
	world.set_meta("world_transition_ui_blocked", false)
	# Drain the release/submit event that completed the transition.
	world.set_meta("world_transition_ui_resume_msec", Time.get_ticks_msec() + 200)

static func clear_popups_and_focus(world: Node) -> void:
	if world.is_inside_tree():
		world.get_viewport().gui_release_focus()
		world.get_viewport().set_input_as_handled()
	var save_manager = world.get("save_manager")
	if save_manager != null and save_manager.has_method("close_all_gameplay_popups"):
		save_manager.close_all_gameplay_popups()
	var input_manager = world.get("input_manager")
	if input_manager != null and input_manager.has_method("_stop_hold"):
		input_manager._stop_hold()
