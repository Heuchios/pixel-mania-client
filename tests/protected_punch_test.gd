extends SceneTree

func _init(): call_deferred("run")

func run():
	var world = load("res://tests/fixtures/protected_punch_world.gd").new()
	root.add_child(world)
	world.in_world = true
	world.selected_item_type = "punch"
	world.selected_item_category = "tool"
	world.player = Node2D.new()
	world.add_child(world.player)
	world.player.position = Vector2(96, 128)
	world.item_database = load("res://Scripts/item_database.gd").ITEMS.duplicate(true)
	var blocks = load("res://tests/fixtures/protected_punch_blocks.gd").new()
	blocks.world = world
	world.block_manager = blocks
	var interaction = load("res://Scripts/interaction_manager.gd").new()
	interaction.world = world
	world.interaction_manager = interaction
	var grid: Vector2i = world.target
	for weapon in ["punch", "neptune_trident", "fire_staff", "serpent_staff", "void_saber", "blue_saber"]:
		world.equipped_tool = weapon
		for block in ["dirt", "bedrock", "water", "safe", "vending_machine", "fish_monger", "display_box", "fish_hanger", "anti_punch", "night_theme_machine", "chicken", "tackle_box", "magnet_machine", "crafting_station"]:
			world.blocks = {grid:{"type":block}}
			var before: int = world.swings.size()
			var animations: int = world.animation_count
			interaction.use_selected_item_at_mouse()
			assert(world.animation_count == animations + 1, "Protected click must animate: " + block)
			var expected_source: String = "punch" if weapon == "blue_saber" else weapon # Sabers use the animation's blade trail.
			assert(world.swings.size() == before + 1 and world.swings.back() == expected_source, "Protected click must emit its equipped effect: " + weapon + " / " + block)
			assert(world.notices.is_empty(), "Protected punch showed a warning: " + str(world.notices))
			assert(blocks.packets.is_empty(), "Protected block sent a mutation")
			assert(world.block_hit_progress.is_empty() and world.block_hit_timers.is_empty())
			assert(world.blocks[grid].type == block)
	world.blocks.clear()
	blocks.background_blocks[grid] = {"type":"wooden_background"}
	var before: int = world.swings.size()
	blocks.punch_grid_position(grid, true)
	assert(world.swings.size() == before + 1 and blocks.packets.is_empty())
	blocks.background_blocks.clear()
	for target_kind in ["tree", "electrical"]:
		world.tree = target_kind == "tree"
		world.electrical = target_kind == "electrical"
		before = world.swings.size()
		blocks.break_block_at_mouse()
		blocks.punch_grid_position(grid, true)
		assert(world.swings.size() == before + 2 and blocks.packets.is_empty(), target_kind)
		assert(world.notices.is_empty())
	world.tree = false
	world.electrical = false
	# Normal cadence and distance still gate denied-hit particles.
	world.blocks[grid] = {"type":"dirt"}
	before = world.swings.size()
	blocks.cadence = false
	blocks.hit_block_grid(grid, true)
	blocks.cadence = true
	world.near = false
	blocks.hit_block_grid(grid, true)
	world.near = true
	assert(world.swings.size() == before)
	# Keyboard punches must animate too, and selecting wrench must not punch.
	var input = load("res://Scripts/input_manager.gd").new()
	input.world = world
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	var animations: int = world.animation_count
	input.handle_unhandled_input(key)
	assert(world.animation_count == animations + 1 and world.swings.size() == before + 1)
	assert(world.notices.is_empty() and blocks.packets.is_empty())
	world.selected_item_type = "wrench"
	input.handle_unhandled_input(key)
	assert(world.animation_count == animations + 1 and world.swings.size() == before + 1)
	assert(world.notices == ["World locked by RAYAN."])
	world.notices.clear()
	input.free()
	# Wrench notices and public interactions remain distinct from punches.
	world.selected_item_type = "wrench"
	interaction.interact_with_mouse()
	assert(world.notices == ["World locked by RAYAN."])
	world.notices.clear()
	for public_block in ["fish_monger", "vending_machine"]:
		world.blocks[grid] = {"type":public_block}
		interaction.interact_with_mouse()
	assert(world.public_opened == 2 and world.notices.is_empty())
	# Real locks retain authoritative decay checks and their cosmetic swing.
	world.selected_item_type = "punch"
	world.blocks[grid] = {"type":"world_lock"}
	before = world.swings.size()
	blocks.hit_block_grid(grid, true)
	assert(blocks.packets.size() == 1 and blocks.packets[0].action == "hit")
	assert(world.swings.size() == before + 1 and world.block_hit_progress.is_empty())
	# Suppression is restricted to server-denied block damage, never placement,
	# wrench actions, connectivity failures, or an owner's storage warning.
	for reason in ["world_locked", "area_lock_permission_denied", "lock_not_decayed", "safe_owner_required"]:
		assert(blocks.handle_rejected_block_update({"action":"world_block_update","block_action":"hit","reason":reason,"x":grid.x,"y":grid.y}))
		assert(not blocks.handle_rejected_block_update({"action":"world_block_update","block_action":"place","reason":reason,"x":grid.x,"y":grid.y}))
	assert(not blocks.handle_rejected_block_update({"block_action":"hit","reason":"protected_storage_blocks"}))
	assert(not blocks.handle_rejected_block_update({"block_action":"hit","reason":"session_not_ready"}))
	# An authorized hit still reaches the normal authoritative damage path.
	world.allow_break = true
	world.blocks[grid] = {"type":"dirt"}
	blocks.hit_block_grid(grid, true)
	assert(blocks.packets.size() == 2 and int(world.block_hit_progress[grid]) > 0)
	blocks.free()
	interaction.free()
	world.queue_free()
	await process_frame
	print("PROTECTED_PUNCH_PASS: silent cosmetic hits, weapon source, mouse/facing targets, no mutations, cadence/reach, wrench/public behavior, lock decay and scoped server denials")
	quit()
