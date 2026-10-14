extends SceneTree

const PetSystem = preload("res://Scripts/pet_system.gd")
const Items = preload("res://Scripts/item_database.gd")
const Vending = preload("res://Scripts/vending_preview_manager.gd")
const Tiles = preload("res://Scripts/world_tilemap_renderer.gd")

class RemoteManager extends RefCounted:
	var remote_players := {}

class PetWorld extends Node2D:
	const BLOCK_SIZE := 32
	var item_database: Dictionary = Items.ITEMS
	var equipped_pet_item := ""
	var pet_inventory := {}
	var player := CharacterBody2D.new()
	var player_manager := RemoteManager.new()

var failures := 0
var checked_followers := 0
var expected_old_failure := "--old-layer" in OS.get_cmdline_user_args()


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func texture(color: Color) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func matching_pet_pixels(baseline: Image, actual: Image, follower: Node2D) -> Vector2i:
	var sprite: Sprite2D = follower.sprite
	if sprite.texture == null:
		return Vector2i.ZERO
	var mask := sprite.texture.get_image()
	var origin := Vector2i(follower.global_position) - mask.get_size() / 2
	var matched := 0
	var total := 0
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			if mask.get_pixel(x, y).a < 0.99:
				continue
			var point := origin + Vector2i(x, y)
			var before := baseline.get_pixelv(point)
			var after := actual.get_pixelv(point)
			total += 1
			if Vector3(before.r - after.r, before.g - after.g, before.b - after.b).length() < 0.02:
				matched += 1
	return Vector2i(matched, total)


func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 144)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := PetWorld.new()
	# Absolute follower order must also work under a differently ordered world root.
	world.z_index = -64
	viewport.add_child(world)
	world.add_child(world.player)
	var remote := CharacterBody2D.new()
	world.add_child(remote)
	world.player_manager.remote_players.other = remote
	var pets := PetSystem.new()
	pets.world = world
	world.add_child(pets)
	pets.set_process(false)
	var vending := Vending.new()
	vending.world = world
	world.add_child(vending)
	var blocks = load("res://Scripts/block_manager.gd").new()
	blocks.world = world
	world.add_child(blocks)
	blocks.set_process(false)
	var occluders: Array[CanvasItem] = []
	var cover_texture := texture(Color.MAGENTA)
	var positions := [Vector2(64, 64), Vector2(160, 64)]
	# Exercise production node block ordering, including over-player fences/water.
	for block_type in ["vending_machine", "wooden_fence", "white_fence", "city_fence", "water"]:
		var group := Node2D.new()
		group.name = block_type
		world.add_child(group)
		for pos in positions:
			var block := Sprite2D.new()
			block.texture = cover_texture
			block.position = pos
			group.add_child(block)
			blocks.apply_block_draw_order(block, block_type)
		group.hide()
		occluders.append(group)
	# Exact vending previews use absolute z, independently of their layer parent.
	for index in range(positions.size()):
		var preview := vending.get_or_create_exact_preview_sprite(Vector2i(index, 0))
		preview.texture = cover_texture
		preview.position = positions[index]
	var vend_layer := vending.get_exact_preview_layer()
	vend_layer.hide()
	occluders.append(vend_layer)
	# Tilemap paths use the renderer's real layer factory and production z values.
	var tiles := Tiles.new()
	tiles.world = world
	tiles.tile_set = TileSet.new()
	tiles.tile_set.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = cover_texture
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	var source_id: int = tiles.tile_set.add_source(atlas)
	world.add_child(tiles)
	tiles.set_physics_process(false)
	for spec in [["Foreground", Tiles.FOREGROUND_Z_INDEX], ["Entrance", Tiles.FOREGROUND_FEATURE_Z_INDEX], ["VendTiles", Tiles.VENDING_PREVIEW_Z_INDEX], ["FenceTiles", Tiles.FOREGROUND_OVER_PLAYER_Z_INDEX], ["WaterTiles", Tiles.WATER_Z_INDEX]]:
		var layer := tiles._ensure_layer(spec[0], spec[1])
		for pos in positions:
			layer.set_cell(Vector2i(pos / 32), source_id, Vector2i.ZERO)
		layer.hide()
		occluders.append(layer)
	var ui := CanvasLayer.new()
	ui.layer = 1
	world.add_child(ui)
	var panel := ColorRect.new()
	panel.size = Vector2(256, 144)
	panel.color = Color.MAGENTA
	panel.z_index = -32 # Hotbar order must still cover pets.
	ui.add_child(panel)
	panel.hide()
	var variants := 0
	for id in world.item_database:
		var definition: Dictionary = world.item_database[id]
		if not definition.has("pet_species"):
			continue
		variants += 1
		world.equipped_pet_item = id
		world.pet_inventory = {id: 1}
		remote.set_meta("equipment_slots", {"pet": id})
		pets.update_followers()
		check(pets.followers.size() == 2, "%s must spawn both local and remote followers" % id)
		var followers := [pets.followers.local, pets.followers.other]
		for index in range(followers.size()):
			var follower = followers[index]
			follower.set_physics_process(false)
			follower._physics_process(0.0)
			follower.global_position = positions[index]
			if expected_old_failure:
				follower.z_as_relative = true
				follower.z_index = 0
		var baseline := await capture(viewport)
		for cover in occluders:
			cover.show()
			var covered := await capture(viewport)
			for follower in followers:
				var result := matching_pet_pixels(baseline, covered, follower)
				if expected_old_failure and result.y > 20 and result.x < result.y:
					print("PET_OLD_LAYER_REPRODUCTION_PASS: ", id, " hidden by ", cover.name, "; visible pixels=", result)
					viewport.queue_free()
					await process_frame
					quit()
					return
				check(result.y > 20 and result.x == result.y, "%s (%s) covered pet pixels: %s" % [id, cover.name, result])
			cover.hide()
		panel.show()
		var ui_frame := await capture(viewport)
		for follower in followers:
			var result := matching_pet_pixels(baseline, ui_frame, follower)
			check(result.x == 0, "%s must stay behind the UI" % id)
		panel.hide()
		checked_followers += followers.size()
	check(variants >= 18, "Exercise all six species and their three levels")
	check(not expected_old_failure, "Old layer must reproduce hidden pet pixels")
	viewport.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	print("PET_DRAW_ORDER_PASS: ", checked_followers, " local/remote followers, node and tilemap blocks, vending previews, water and UI; failures=", failures)
	quit(1 if failures else 0)
