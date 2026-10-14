extends SceneTree

const PetSystem = preload("res://Scripts/pet_system.gd")
const ItemDatabase = preload("res://Scripts/item_database.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	# Use the real world script; a substitute TILE_SIZE constant hid this crash.
	var world = load("res://Scripts/world.gd").new()
	var pos := Vector2i(22, 57)
	world.fast_block_place_grid_override_active = true
	world.fast_block_place_grid_override = pos
	world.blocks = {pos: {"type": "incubator"}}
	world.item_database = ItemDatabase.ITEMS.duplicate(true)
	var pets := PetSystem.new()
	pets.world = world
	world.add_child(pets)
	var now := int(Time.get_unix_time_from_system() * 1000)
	pets.states[pos] = {"input_item": "golden_egg", "started_at_ms": now, "ready_at_ms": now + 60000}
	pets.update_incubators()
	assert(pets.overlays.has(pos))
	var visual: Sprite2D = pets.overlays[pos]
	assert(visual.position == world.grid_to_world_center(pos))
	assert(visual.position == Vector2(704, 1824))
	assert(visual.get_node("Input").texture != null)
	assert(visual.get_node("Timer").text.ends_with("s left"))
	# Reuse the same overlay across pet deposits, upgrading and completed hatch.
	pets.states[pos] = {"input_item": "frog_pet", "chunks": 250, "upgrade_cost": 250}
	pets.update_incubators()
	assert(pets.overlays[pos] == visual)
	assert(visual.texture.region.position == Vector2(640, 512))
	pets.states[pos] = {"input_item": "golden_egg", "started_at_ms": now - 60000, "ready_at_ms": now - 1}
	pets.update_incubators()
	assert(visual.get_node("Timer").text == "Ready!")
	world.blocks.clear()
	pets.update_incubators()
	assert(pets.overlays.is_empty())
	assert(pets.states.is_empty())
	world.free()
	print("PET_INCUBATOR_COORDINATES_PASS: real world grid conversion, hovering egg, upgrade frames, hover timer, ready state and removed station")
	quit()
