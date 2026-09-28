extends Node

const Factory = preload("res://Scripts/atlas_texture_factory.gd")
var world
var states: Dictionary = {}
var visuals: Dictionary = {}
var ui = null
var remote_state: Dictionary = {}
var request_sequence := 0
var frames := SpriteFrames.new()
var seen_collection_effects: Dictionary = {}

func setup(owner_world):
	world = owner_world
	frames.add_animation("off")
	frames.add_frame("off", Factory.load_texture({"atlas": "res://image.png", "cell": [24, 14], "cell_size": [32, 32]}))
	frames.add_animation("on")
	frames.set_animation_speed("on", 5.0)
	for x in [25, 26]:
		frames.add_frame("on", Factory.load_texture({"atlas": "res://image.png", "cell": [x, 14], "cell_size": [32, 32]}))

func reset():
	seen_collection_effects.clear()
	states.clear()
	remote_state.clear()
	for grid in visuals.keys():
		remove(grid)
	if is_instance_valid(ui):
		ui.hide()

func remove(grid: Vector2i):
	states.erase(grid)
	if visuals.has(grid):
		visuals[grid].queue_free()
		visuals.erase(grid)
	if remote_state.get("x", -1) == grid.x and remote_state.get("y", -1) == grid.y:
		remote_state.clear()
	if is_instance_valid(ui) and ui.current_grid == grid:
		ui.hide()

func apply_state(data: Dictionary):
	if str(data.get("world", world.current_world_name)) != world.current_world_name:
		return
	var grid := Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	states[grid] = data.duplicate(true)
	states[grid].erase("collection_fx")
	if not remote_state.is_empty() and remote_state.get("machine_id") == data.get("machine_id"):
		remote_state = states[grid].duplicate(true)
	refresh_visual(grid)
	play_collection_effect(grid, data)
	if is_instance_valid(ui) and ui.visible and ui.current_grid == grid:
		ui.apply_state(data, false)

func play_collection_effect(grid: Vector2i, data: Dictionary):
	var effect = data.get("collection_fx", null)
	if not effect is Dictionary or not is_instance_valid(world.drop_manager):
		return
	var event_id := str(effect.get("event_id", ""))
	if event_id == "" or seen_collection_effects.has(event_id):
		return
	seen_collection_effects[event_id] = true
	if seen_collection_effects.size() > 512:
		seen_collection_effects.erase(seen_collection_effects.keys()[0])
	var machine: AnimatedSprite2D = visuals.get(grid)
	if not is_instance_valid(machine) or int(effect.get("amount", 0)) <= 0:
		return
	var origin := Vector2(float(effect.get("x", NAN)), float(effect.get("y", NAN)))
	if not origin.is_finite():
		return
	var id := str(data.get("item_id", ""))
	var category := str(data.get("item_category", "block"))
	var texture: Texture2D = world.get_inventory_icon_texture(id, category)
	if texture == null:
		return
	# Cosmetic only: stock is already committed; no collectible drop is created.
	var item := Sprite2D.new()
	item.texture = texture
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item.z_index = 40
	var metrics: Dictionary = world.vending_preview_manager.get_texture_visible_metrics(texture)
	var size: Vector2 = metrics.get("size", texture.get_size())
	item.offset = metrics.get("offset", Vector2.ZERO)
	item.scale = Vector2.ONE * (20.0 / maxf(1.0, maxf(size.x, size.y)))
	machine.add_child(item)
	item.global_position = world.to_global(origin)
	var target: Vector2 = machine.get_node("SelectedItem").global_position
	world.drop_manager.finish_drop_pickup_vacuum_node({"node": item, "item_type": id, "item_category": category}, target, false)

func refresh_visual(grid: Vector2i):
	if not world.blocks.has(grid) or str(world.blocks[grid].get("type", "")) != "magnet_machine":
		return
	var sprite: AnimatedSprite2D = visuals.get(grid)
	if not is_instance_valid(sprite):
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(grid) * float(world.BLOCK_SIZE)
		sprite.z_index = 6
		world.add_child(sprite)
		var preview := Sprite2D.new()
		preview.name = "SelectedItem"
		preview.position = Vector2(0, -7)
		preview.z_index = 1
		sprite.add_child(preview)
		visuals[grid] = sprite
	var state: Dictionary = states.get(grid, {})
	var animation := "on" if bool(state.get("building", false)) else "off"
	if sprite.animation != animation:
		sprite.play(animation)
	var preview: Sprite2D = sprite.get_node("SelectedItem")
	var id := str(state.get("item_id", ""))
	preview.visible = id != ""
	if id != "":
		preview.texture = world.get_inventory_icon_texture(id, str(state.get("item_category", "block")))
		if preview.texture != null:
			var metrics: Dictionary = world.vending_preview_manager.get_texture_visible_metrics(preview.texture)
			var size: Vector2 = metrics.get("size", preview.texture.get_size())
			preview.offset = metrics.get("offset", Vector2.ZERO)
			preview.scale = Vector2.ONE * minf(12.0 / maxf(1.0, size.x), 12.0 / maxf(1.0, size.y))

func open(grid: Vector2i):
	if not is_instance_valid(ui):
		ui = preload("res://Scripts/magnet_machine_ui.gd").new()
		world.ui_layer.add_child(ui)
		ui.setup(world, self)
	ui.open(grid)

func request(action: String, grid: Vector2i, extra: Dictionary = {}) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	var data := extra.duplicate(true)
	request_sequence += 1
	data["request_id"] = "magnet_%d_%d" % [Time.get_ticks_usec(), request_sequence]
	data.merge({"action": action, "world": world.current_world_name, "x": grid.x, "y": grid.y}, true)
	return bool(network.send_inventory_transaction_request(data))

func place(grid: Vector2i):
	if remote_state.is_empty():
		world.show_notification("Get a remote from a Magnet Machine in this world first.")
		return
	request("magnet_place", grid)

func handle_result(data: Dictionary) -> bool:
	if not str(data.get("action", "")).begins_with("magnet_"):
		return false
	var state: Dictionary = data.get("magnet_state", {})
	if not state.is_empty():
		apply_state(state)
		if bool(data.get("remote_bound", false)):
			remote_state = state.duplicate(true)
	if is_instance_valid(ui) and ui.visible:
		ui.pending = false
		if not state.is_empty() and ui.current_grid == Vector2i(int(state.x), int(state.y)):
			ui.apply_state(state, true)
	var message := str(data.get("message", ""))
	if message != "":
		world.show_notification(message)
	return true
