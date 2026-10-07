extends RefCounted

# One presentation source for local rendering and multiplayer snapshots.
# The selected tool stays the remote so placement still spends machine stock.
static func resolve(world) -> Dictionary:
	var item_id := str(world.selected_item_type)
	var category := str(world.selected_item_category)
	if item_id == "magnet_machine_remote":
		if world.get_item_count(item_id, "tool") <= 0 or not world.has_method("get_magnet_machine_manager"):
			return {}
		var state: Dictionary = world.get_magnet_machine_manager().remote_state
		if str(state.get("world", "")) != str(world.current_world_name) or str(state.get("machine_id", "")) == "" or not bool(state.get("building", false)) or int(state.get("count", 0)) <= 0:
			return {}
		item_id = str(state.get("item_id", ""))
		category = str(state.get("item_category", ""))
	elif world.get_item_count(item_id, category) <= 0:
		return {}
	if category not in ["block", "seed"] or not world.item_database.has(item_id):
		return {}
	return {"item_id": item_id, "category": category}
