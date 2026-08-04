extends SceneTree


const TEST_GRID := Vector2i(4, 5)


class MockWorld:
	extends Node2D

	var blocks: Dictionary = {}
	var item_database: Dictionary = {
		"anti_punch": {
			"display_name": "Anti-Punch",
			"anti_punch_block": true,
			"block_health": 4,
			"break_return_to_inventory": true
		},
		"anti_talk": {
			"display_name": "Anti-Talk",
			"anti_talk_block": true,
			"block_health": 4,
			"break_return_to_inventory": true
		},
		"anti_gravity": {
			"display_name": "Anti-Gravity",
			"anti_gravity_block": true,
			"block_health": 4,
			"break_return_to_inventory": true
		},
		"night_theme_machine": {
			"display_name": "Night Theme Machine",
			"theme_machine_block": true,
			"theme_machine_theme": "night",
			"block_health": 4,
			"break_return_to_inventory": true
		}
	}
	const BLOCK_MAX_HITS := 5
	const BLOCK_DAMAGE_RESET_DELAY := 3.0
	var anti_punch_states: Dictionary = {}
	var anti_talk_states: Dictionary = {}
	var anti_gravity_states: Dictionary = {}
	var theme_machine_states: Dictionary = {}
	var block_hit_progress: Dictionary = {}
	var block_hit_timers: Dictionary = {}
	var crack_textures: Dictionary = {}
	var inventory: Dictionary = {}
	var applying_network_world_update := true
	var selected_item_category := "tool"
	var selected_item_type := "punch"
	var current_world_name := "PUNCHTOGGLE"
	var interaction_manager = null
	var allow_build_at := true
	var allow_toggle := true
	var allow_break := true
	var applied_actions: Array[String] = []
	var notifications: Array[String] = []
	var punch_sound_count := 0
	var swing_particle_count := 0
	var hit_particle_count := 0
	var break_particle_count := 0
	var saved_player_data_count := 0

	func should_use_server_authoritative_world_actions() -> bool:
		return false

	func can_reach_grid(_grid_pos: Vector2i) -> bool:
		return true

	func can_current_player_build_at(_grid_pos: Vector2i) -> bool:
		return allow_build_at

	func can_current_player_toggle_anti_punch() -> bool:
		return allow_toggle

	func can_current_player_toggle_anti_talk() -> bool:
		return allow_toggle

	func can_current_player_toggle_anti_gravity() -> bool:
		return allow_toggle

	func can_current_player_use_theme_machine_at(_grid_pos: Vector2i) -> bool:
		return allow_toggle

	func can_current_player_interact_with_block_at(_block_type: String, _grid_pos: Vector2i) -> bool:
		return allow_toggle

	func can_current_player_break_block_at(_block_type: String, _grid_pos: Vector2i) -> bool:
		return allow_break

	func is_theme_machine_block_type(block_type: String) -> bool:
		return block_type == "night_theme_machine"

	func is_world_lock_block_type(_block_type: String) -> bool:
		return false

	func is_area_lock_block_type(_block_type: String) -> bool:
		return false

	func is_entrance_gate_block(_block_type: String) -> bool:
		return false

	func is_sign_block(_block_type: String) -> bool:
		return false

	func get_block_center_world_position(grid_pos: Vector2i) -> Vector2:
		return Vector2(grid_pos) * 32.0 + Vector2(16.0, 16.0)

	func spawn_hand_item_swing_particles(_position: Vector2, _source_tool: String = "") -> bool:
		swing_particle_count += 1
		return true

	func play_sound_punch(_position: Vector2 = Vector2(INF, INF)) -> void:
		punch_sound_count += 1

	func play_sound_break(_position: Vector2 = Vector2(INF, INF)) -> void:
		punch_sound_count += 1

	func spawn_block_hit_particles(_grid_pos: Vector2i, _block_type: String, _layer := "foreground") -> void:
		hit_particle_count += 1

	func spawn_block_break_particles(_grid_pos: Vector2i, _block_type: String, _layer := "foreground") -> void:
		break_particle_count += 1

	func show_notification(message: String) -> void:
		notifications.append(message)

	func get_current_break_power(_block_type: String) -> int:
		return 1

	func get_item_display_name(item_type: String, _category := "block") -> String:
		return str(item_database.get(item_type, {}).get("display_name", item_type))

	func is_crafting_station_block(_block_type: String) -> bool:
		return false

	func get_stack_limit_for_item(_item_type: String, _category: String) -> int:
		return 200

	func add_item_to_inventory_stack(
		target_inventory: Dictionary,
		item_type: String,
		_category: String,
		amount: int
	) -> int:
		target_inventory[item_type] = int(target_inventory.get(item_type, 0)) + amount
		return amount

	func save_player_data() -> void:
		saved_player_data_count += 1

	func apply_world_background_theme(_theme: String) -> void:
		pass

	func apply_anti_punch_state(grid_pos: Vector2i, enabled: bool, _notify := false, _send_network := false) -> bool:
		_store_toggle_state(anti_punch_states, grid_pos, enabled)
		applied_actions.append("anti_punch:" + str(enabled))
		return true

	func apply_anti_talk_state(grid_pos: Vector2i, enabled: bool, _notify := false, _send_network := false) -> bool:
		_store_toggle_state(anti_talk_states, grid_pos, enabled)
		applied_actions.append("anti_talk:" + str(enabled))
		return true

	func apply_anti_gravity_state(grid_pos: Vector2i, enabled: bool, _notify := false, _send_network := false) -> bool:
		_store_toggle_state(anti_gravity_states, grid_pos, enabled)
		applied_actions.append("anti_gravity:" + str(enabled))
		return true

	func apply_theme_machine_state(
		grid_pos: Vector2i,
		enabled: bool,
		_notify := false,
		_send_network := false,
		theme_name := "night"
	) -> bool:
		if enabled:
			theme_machine_states[grid_pos] = {
				"state": {
					"enabled": true,
					"theme": theme_name
				}
			}
		else:
			theme_machine_states.erase(grid_pos)
		applied_actions.append("theme_machine:" + str(enabled))
		return true

	func try_punch_toggle_machine_at(grid_pos: Vector2i) -> bool:
		return bool(interaction_manager.try_punch_toggle_machine_at(grid_pos))

	func _store_toggle_state(states: Dictionary, grid_pos: Vector2i, enabled: bool) -> void:
		if enabled:
			states[grid_pos] = {"state": {"enabled": true}}
		else:
			states.erase(grid_pos)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := MockWorld.new()
	root.add_child(world)

	var interaction_script := load("res://Scripts/interaction_manager.gd") as Script
	var block_manager_script := load("res://Scripts/block_manager.gd") as Script
	var world_script := load("res://Scripts/world.gd") as Script
	assert(interaction_script != null, "Could not load InteractionManager.")
	assert(block_manager_script != null, "Could not load BlockManager.")
	assert(world_script != null, "Could not load World punch-toggle proxy.")

	var interaction_manager = interaction_script.new()
	world.add_child(interaction_manager)
	interaction_manager.setup(world)
	world.interaction_manager = interaction_manager

	var block_manager = block_manager_script.new()
	block_manager.world = world
	var tilemap_renderer := MockTilemapRenderer.new()
	world.add_child(tilemap_renderer)
	block_manager.tilemap_renderer = tilemap_renderer

	var expected_actions := {
		"anti_punch": "anti_punch:true",
		"anti_talk": "anti_talk:true",
		"anti_gravity": "anti_gravity:true",
		"night_theme_machine": "theme_machine:true"
	}
	for block_type: String in expected_actions:
		reset_machine_state(world, block_type)
		block_manager.hit_block_grid(TEST_GRID, true)
		assert(
			world.applied_actions == [expected_actions[block_type]],
			block_type + " did not toggle from a forced/mobile punch."
		)
		assert(int(world.block_hit_progress.get(TEST_GRID, 0)) == 1, block_type + " did not receive punch damage while toggling.")
		assert(world.block_hit_timers.has(TEST_GRID), block_type + " did not start a damage timer while toggling.")
		assert(world.swing_particle_count == 1, block_type + " did not show the punch response.")
		assert(world.punch_sound_count == 1, block_type + " did not play the punch sound.")
		assert(world.hit_particle_count == 1, block_type + " did not show block-hit particles.")

	reset_machine_state(world, "anti_punch")
	block_manager.hit_block_grid(TEST_GRID, false)
	assert(world.applied_actions == ["anti_punch:true"], "Selected bare punch did not toggle anti-punch.")
	assert(int(world.block_hit_progress.get(TEST_GRID, 0)) == 1, "Selected bare punch did not damage anti-punch.")

	reset_machine_state(world, "anti_talk")
	world.allow_toggle = false
	world.allow_break = false
	block_manager.hit_block_grid(TEST_GRID, true)
	assert(world.applied_actions.is_empty(), "Permission denial still changed anti-talk state.")
	assert(world.block_hit_progress.is_empty(), "Permission denial allowed machine damage.")
	assert(
		not world.notifications.is_empty()
		and str(world.notifications.back()).contains("Only the world owner or world admins"),
		"Permission denial did not explain who can toggle the machine."
	)

	reset_machine_state(world, "anti_talk")
	world.allow_build_at = false
	world.allow_break = false
	block_manager.hit_block_grid(TEST_GRID, true)
	assert(world.applied_actions.is_empty(), "A player without tile access changed anti-talk state.")
	assert(world.block_hit_progress.is_empty(), "A player without tile access damaged anti-talk.")
	assert(
		not world.notifications.is_empty()
		and str(world.notifications.back()) == "This area is locked.",
		"Tile access denial did not explain why the machine could not be toggled."
	)

	reset_machine_state(world, "anti_talk")
	world.allow_toggle = false
	world.allow_break = true
	block_manager.hit_block_grid(TEST_GRID, true)
	assert(world.applied_actions.is_empty(), "Break-only access changed anti-talk state.")
	assert(int(world.block_hit_progress.get(TEST_GRID, 0)) == 1, "Break-only access could not damage anti-talk.")

	for block_type: String in expected_actions:
		reset_machine_state(world, block_type)
		world.interaction_manager.interact_with_grid(TEST_GRID)
		assert(world.applied_actions.is_empty(), "Wrench interaction still toggled " + block_type + ".")
		assert(
			not world.notifications.is_empty()
			and str(world.notifications.back()).begins_with("Punch "),
			"Wrench interaction did not direct the player to punch " + block_type + "."
		)
	assert(
		not world.interaction_manager.is_theme_machine_confirm_open(),
		"Wrench interaction opened the old Theme Machine confirmation popup."
	)

	for block_type: String in expected_actions:
		reset_machine_state(world, block_type)
		seed_machine_enabled_state(world, block_type)
		for _hit_index in range(4):
			block_manager.hit_block_grid(TEST_GRID, true)
		assert(not world.blocks.has(TEST_GRID), block_type + " did not break after four punches.")
		assert(int(world.inventory.get(block_type, 0)) == 1, block_type + " was not returned to inventory after breaking.")
		assert(not has_machine_state(world, block_type), block_type + " left stale enabled state after breaking.")

	block_manager.free()
	world.free()
	print("[punch-toggle-machine] success")
	quit(0)


func reset_machine_state(world: MockWorld, block_type: String) -> void:
	world.blocks = {TEST_GRID: {"type": block_type}}
	world.anti_punch_states.clear()
	world.anti_talk_states.clear()
	world.anti_gravity_states.clear()
	world.theme_machine_states.clear()
	world.block_hit_progress.clear()
	world.block_hit_timers.clear()
	world.applied_actions.clear()
	world.notifications.clear()
	world.punch_sound_count = 0
	world.swing_particle_count = 0
	world.hit_particle_count = 0
	world.break_particle_count = 0
	world.saved_player_data_count = 0
	world.inventory.clear()
	world.allow_build_at = true
	world.allow_toggle = true
	world.allow_break = true


func seed_machine_enabled_state(world: MockWorld, block_type: String) -> void:
	match block_type:
		"anti_punch":
			world.anti_punch_states[TEST_GRID] = {"state": {"enabled": true}}
		"anti_talk":
			world.anti_talk_states[TEST_GRID] = {"state": {"enabled": true}}
		"anti_gravity":
			world.anti_gravity_states[TEST_GRID] = {"state": {"enabled": true}}
		"night_theme_machine":
			world.theme_machine_states[TEST_GRID] = {"state": {"enabled": true, "theme": "night"}}


func has_machine_state(world: MockWorld, block_type: String) -> bool:
	match block_type:
		"anti_punch":
			return world.anti_punch_states.has(TEST_GRID)
		"anti_talk":
			return world.anti_talk_states.has(TEST_GRID)
		"anti_gravity":
			return world.anti_gravity_states.has(TEST_GRID)
		"night_theme_machine":
			return world.theme_machine_states.has(TEST_GRID)
	return false


class MockTilemapRenderer:
	extends Node

	func erase_block_cell(_grid_pos: Vector2i, _background: bool) -> void:
		pass

	func erase_foreground_collision_cell(_grid_pos: Vector2i) -> void:
		pass
