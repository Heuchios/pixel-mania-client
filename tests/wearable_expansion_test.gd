extends SceneTree

const DB_PATH := "res://Scripts/item_database.gd"
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
const Equipment = preload("res://Scripts/equipment_manager.gd")
var failures := 0

class WorldFixture extends Node:
	var item_database: Dictionary = {}
	var pants_textures: Dictionary = {}
	var shirt_textures: Dictionary = {}
	var shoes_textures: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var database = load(DB_PATH).new()
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/wearable_expansion_20261012.json"))
	var scene = load("res://Scenes/main.tscn").instantiate()
	var world := WorldFixture.new()
	var exported := {}
	for c in cases:
		world.item_database[c.id] = database.get_item_data(c.id)
		exported[c.id] = world.item_database[c.id]
	var render := "--render" in OS.get_cmdline_user_args()
	var output_dir := OS.get_environment("PIXELMANIA_TEST_OUTPUT_DIR")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1020)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	for i in cases.size():
		var c: Dictionary = cases[i]
		var item: Dictionary = world.item_database[c.id]
		check(item.display_name == c.name and item.category == c.slot and item.equipment_slot == c.slot, c.id + " identity")
		check(item.equipable and item.instance_tracked and item.starting_count == 0, c.id + " equipment rules")
		check_cell(item.inventory_icon, c.icon, c.id + " icon")
		check_cell(item.texture, c.icon if c.slot == "shoes" else c.body, c.id + " base")
		var actor := Node2D.new()
		var visual = scene.get_node("Player/PlayerVisual").duplicate()
		strip_scripts(visual)
		actor.add_child(visual)
		viewport.add_child(actor)
		actor.position = Vector2((i % 8) * 200 + 60, (i / 8) * 170 + 115)
		actor.scale = Vector2(3, 3)
		var manager = Equipment.new()
		manager.player = actor
		manager.world = world
		manager.setup_wearable_animated_parts()
		for part in manager.wearable_part_nodes.values():
			part.hide()
		visual.get_node("Head/FaceExpressionAnimated").show()
		for facing in [1, -1]:
			visual.scale.x = facing
			manager.call("update_equipped_%s_visual" % c.slot, c.id, facing)
			var pieces := {c.slot: c.body}
			if c.slot == "shirt":
				check_cell(item.shirt_body_texture, c.body, c.id + " shirt body")
				var expected_shift := Vector2(-2, 4) if c.get("outfit", false) else Vector2.ZERO
				check(manager.shirt_item_animated.position == manager.get_wearable_part_base_position("shirt", Vector2.ZERO) + expected_shift, c.id + " body alignment")
				if c.has("right_arm"):
					pieces["right_sleeve"] = c.right_arm
					pieces["left_sleeve"] = c.left_arm
					for side in ["right", "left"]:
						var sleeve = manager.get_wearable_part(side + "_sleeve")
						var shift := Vector2(-8 if side == "left" else 0, 4) if c.get("outfit", false) else Vector2.ZERO
						check(sleeve.position == manager.get_wearable_part_base_position(side + "_sleeve", Vector2.ZERO) + shift, c.id + " sleeve alignment")
				else:
					check(not manager.get_wearable_part("right_sleeve").visible and not manager.get_wearable_part("left_sleeve").visible, c.id + " sleeveless")
			if c.slot == "pants":
				pieces["pants_left_item"] = c.left_leg
				pieces["pants_right_item"] = c.right_leg
				for side in ["left", "right"]:
					var part = manager.get_wearable_part("pants_%s_item" % side)
					var foot = visual.get_node("%sFoot" % side.capitalize())
					check(part.get_parent() == foot and part.position == Vector2(0, 11), c.id + " leg attachment")
					foot.position = Vector2(3, -2)
					foot.rotation = 0.2
					check(part.global_position.is_equal_approx(foot.to_global(Vector2(0, 11))) and is_equal_approx(part.global_rotation, foot.global_rotation), c.id + " moving leg")
					foot.position = Vector2.ZERO
					foot.rotation = 0
			if c.slot == "shoes":
				pieces = {"left_foot_item": c.body, "right_foot_item": c.right_foot}
				check(item.left_shoe_offset == [0, 0] and item.right_shoe_offset == [0, 0], c.id + " original shoe alignment")
			for part_key in pieces:
				var part = manager.get_wearable_part(part_key)
				check(part.visible, c.id + " visible " + part_key)
				for state in Equipment.STANDARD_WEARABLE_ANIMATIONS:
					manager.play_wearable_part_animation(part, state)
					var count: int = int(c.frames) if part_key == c.slot else 1
					check(part.sprite_frames.get_frame_count(state) == count, c.id + " frame count " + state)
					if count > 1:
						check(part.sprite_frames.get_animation_loop(state) and part.sprite_frames.get_animation_speed(state) == 6.0, c.id + " loop/speed " + state)
					for frame in count:
						check_cell(part.sprite_frames.get_frame_texture(state, frame), [pieces[part_key][0] + frame, pieces[part_key][1]], c.id + " equipped " + part_key)
				manager.play_wearable_part_animation(part, "idle")
			manager.call("update_equipped_%s_visual" % c.slot, "", facing)
			for part_key in pieces:
				check(not manager.get_wearable_part(part_key).visible, c.id + " unequip " + part_key)
		visual.scale.x = 1
		if c.get("outfit", false):
			manager.update_equipped_shirt_visual("scrub_top", 1)
			for part_key in ["shirt", "right_sleeve", "left_sleeve"]:
				check(manager.get_wearable_part(part_key).position == manager.get_wearable_part_base_position(part_key, Vector2.ZERO), c.id + " restore ordinary shirt alignment")
		manager.call("update_equipped_%s_visual" % c.slot, c.id, 1)
		if render:
			var label := Label.new()
			label.text = c.name
			label.position = Vector2((i % 8) * 200 + 6, (i / 8) * 170 + 10)
			label.add_theme_font_size_override("font_size", 16)
			viewport.add_child(label)
			var icon := Sprite2D.new()
			icon.texture = Factory.load_texture(item.inventory_icon)
			icon.position = Vector2((i % 8) * 200 + 148, (i / 8) * 170 + 77)
			icon.scale = Vector2(2, 2)
			viewport.add_child(icon)
		manager.free()
	if render:
		await process_frame
		await RenderingServer.frame_post_draw
		if output_dir != "":
			viewport.get_texture().get_image().save_png(output_dir.path_join("wearables-20261012-preview.png"))
	if output_dir != "":
		var output := FileAccess.open(output_dir.path_join("wearables-20261012-client.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(exported))
		output.close()
	scene.free()
	world.free()
	database.free()
	print("WEARABLE_EXPANSION: 44 items, atlas cells, icons, sleeves, legs, shoes, animation states, both facings and unequip; failures=", failures)
	quit(1 if failures else 0)

func strip_scripts(node: Node) -> void:
	node.set_script(null)
	if node is AnimationPlayer:
		node.stop()
	for child in node.get_children():
		strip_scripts(child)

func check_cell(spec, cell: Array, label: String) -> void:
	var texture := Factory.load_texture(spec) as AtlasTexture
	check(texture != null and texture.region == Rect2(cell[0] * 32, cell[1] * 32, 32, 32), label + " atlas cell")
	if texture != null:
		check(not texture.get_image().is_invisible(), label + " nonempty artwork")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("WEARABLE_EXPANSION_FAIL: ", label)
