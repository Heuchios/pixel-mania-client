extends SceneTree

# Run with a rendering driver and -- --render to verify opaque helmet pixels.
const Equipment = preload("res://Scripts/equipment_manager.gd")
const HELMETS := ["horse_mask", "welding_mask", "space_mask", "skull_mask", "burning_skull", "sack_mask", "bag_on_the_head", "flaming_skull"]
var failures := 0

class WorldFixture extends Node:
	var item_database := {}
	var hair_textures := {}
	var pants_textures := {}
	var shirt_textures := {}
	var shoes_textures := {}

class RemoteProbe extends "res://Scripts/player_manager.gd":
	var actual_equipment: Node
	func get_remote_equipment_manager(_player):
		return actual_equipment

func _init() -> void:
	call_deferred("run")

func make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport

func strip_scripts(node: Node) -> void:
	node.set_script(null)
	if node is AnimationPlayer:
		node.stop()
	if node is AnimatedSprite2D:
		node.stop()
	for child in node.get_children():
		strip_scripts(child)

func run() -> void:
	var database = load("res://Scripts/item_database.gd").new()
	var scene = load("res://Scenes/main.tscn").instantiate()
	var world := WorldFixture.new()
	for id in HELMETS + ["electric_goggles", "scrub_mask", "witch_hat", "black_spiky_hair"]:
		world.item_database[id] = database.get_item_data(id)
	var rigs := []
	for i in 2:
		var viewport := make_viewport()
		var actor := Node2D.new()
		var visual = scene.get_node("Player/PlayerVisual").duplicate()
		strip_scripts(visual)
		actor.add_child(visual)
		actor.position = Vector2(48, 54)
		actor.scale = Vector2(2, 2)
		viewport.add_child(actor)
		var equipment = Equipment.new()
		equipment.player = actor
		equipment.world = world
		equipment.setup_wearable_animated_parts()
		for part in equipment.wearable_part_nodes.values():
			part.hide()
		rigs.append({"viewport": viewport, "actor": actor, "equipment": equipment})
	var remote := RemoteProbe.new()
	remote.actual_equipment = rigs[0].equipment
	var mask_viewport := make_viewport()
	var mask := Sprite2D.new()
	mask_viewport.add_child(mask)
	var render := "--render" in OS.get_cmdline_user_args()
	var rendered_frames := 0
	var covered_pixels := 0
	var negative_control_pixels := 0
	for id in HELMETS:
		var slot: String = world.item_database[id].equipment_slot
		for facing in [1, -1]:
			var slots := {slot: id, "eyewear": "electric_goggles", "hair": "black_spiky_hair"}
			if slot == "hat":
				slots["beard"] = "scrub_mask"
			for rig in rigs:
				rig.actor.get_node("PlayerVisual").scale.x = facing
				rig.equipment.update_equipped_hat_visual("", facing)
				rig.equipment.update_equipped_beard_visual("", facing)
				rig.equipment.update_equipped_eyewear_visual("", facing)
			# Exercise the real remote appearance path, including repeated snapshots.
			rigs[0].actor.set_meta("equipment_slots", slots)
			rigs[0].actor.set_meta("facing", facing)
			rigs[0].actor.remove_meta("applied_equipment_slots_debug_key")
			check(remote.update_remote_shared_equipment_visuals(rigs[0].actor), id + " remote equip")
			check(remote.update_remote_shared_equipment_visuals(rigs[0].actor), id + " cached remote snapshot")
			rigs[1].equipment.call("update_equipped_%s_visual" % slot, id, facing)
			var helmet: AnimatedSprite2D = rigs[0].equipment.get_wearable_part(slot)
			var reference: AnimatedSprite2D = rigs[1].equipment.get_wearable_part(slot)
			var glasses: AnimatedSprite2D = rigs[0].equipment.get_wearable_part("eyewear")
			var hair: AnimatedSprite2D = rigs[0].equipment.get_wearable_part("hair")
			check(not hair.visible and rigs[0].equipment.wearable_part_item_ids.get("hair") == "black_spiky_hair", id + " hides but retains hair")
			check(rigs[0].actor.get_meta("equipment_slots").hair == "black_spiky_hair", id + " leaves equipped hair unchanged")
			check(helmet.z_index == 4 and helmet.z_index > glasses.z_index, id + " above eyewear")
			if slot == "hat":
				check(helmet.z_index > rigs[0].equipment.get_wearable_part("beard").z_index, id + " above face mask")
			for state in Equipment.STANDARD_WEARABLE_ANIMATIONS:
				rigs[0].equipment.play_wearable_part_animation(helmet, state)
				check(helmet.z_index == 4, id + " layer during " + state)
			for part in [helmet, reference, glasses]:
				part.animation = "idle"
				part.pause()
				part.frame = 0
			if render:
				for frame in helmet.sprite_frames.get_frame_count("idle"):
					helmet.frame = frame
					reference.frame = frame
					mask.texture = helmet.sprite_frames.get_frame_texture("idle", frame)
					mask.transform = helmet.global_transform
					await process_frame
					await RenderingServer.frame_post_draw
					var actual: Image = rigs[0].viewport.get_texture().get_image()
					var expected: Image = rigs[1].viewport.get_texture().get_image()
					var coverage: Image = mask_viewport.get_texture().get_image()
					var differences := compare_covered(actual, expected, coverage)
					check(differences == 0, "%s facing %d frame %d: %d eyewear pixels above helmet" % [id, facing, frame, differences])
					covered_pixels += count_opaque(coverage)
					# Prove the rendering check catches the reported bug.
					helmet.z_index = 2
					await process_frame
					await RenderingServer.frame_post_draw
					negative_control_pixels += compare_covered(rigs[0].viewport.get_texture().get_image(), expected, coverage)
					helmet.z_index = 4
					rendered_frames += 1
			# Swapping back must restore a small face accessory's normal layer.
			rigs[0].equipment.call("update_equipped_%s_visual" % slot, "witch_hat" if slot == "hat" else "scrub_mask", facing)
			check(helmet.z_index == 3, id + " normal item restores layer")
			check(hair.visible, id + " hair returns with normal headwear")
			rigs[0].equipment.call("update_equipped_%s_visual" % slot, "", facing)
			check(not helmet.visible and glasses.visible, id + " unequip reveals eyewear")
			check(hair.visible, id + " unequip reveals hair")
	# Covering both slots keeps hair hidden until both covers have been removed.
	var equipment = rigs[0].equipment
	equipment.update_equipped_beard_visual("space_mask", 1)
	equipment.update_equipped_hat_visual("flaming_skull", 1)
	equipment.update_equipped_hair_visual("black_spiky_hair", 1)
	check(not equipment.hair_item_animated.visible, "equipping hair after two covers stays hidden")
	equipment.update_equipped_beard_visual("", 1)
	check(not equipment.hair_item_animated.visible, "remaining hat cover keeps hair hidden")
	equipment.update_equipped_hat_visual("", 1)
	check(equipment.hair_item_animated.visible, "removing final cover restores hair")
	equipment.update_equipped_beard_visual("space_mask", 1)
	equipment.update_equipped_hair_visual("", 1)
	equipment.update_equipped_beard_visual("", 1)
	check(not equipment.hair_item_animated.visible, "actually unequipped hair stays hidden")
	if render:
		check(covered_pixels > 0 and negative_control_pixels > 0, "render check must cover helmet pixels and detect the old layering")
	for rig in rigs:
		rig.equipment.free()
	remote.free()
	world.free()
	scene.free()
	database.free()
	print("HELMET_LAYERING: 8 covers, local/remote, both facings, movement states, swap and unequip; rendered_frames=", rendered_frames, "; covered_pixels=", covered_pixels, "; negative_control_pixels=", negative_control_pixels, "; failures=", failures)
	quit(1 if failures else 0)

func compare_covered(actual: Image, expected: Image, coverage: Image) -> int:
	var differences := 0
	for y in coverage.get_height():
		for x in coverage.get_width():
			if coverage.get_pixel(x, y).a == 1.0 and not actual.get_pixel(x, y).is_equal_approx(expected.get_pixel(x, y)):
				differences += 1
	return differences

func count_opaque(coverage: Image) -> int:
	var count := 0
	for y in coverage.get_height():
		for x in coverage.get_width():
			if coverage.get_pixel(x, y).a == 1.0:
				count += 1
	return count

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("HELMET_LAYERING_FAIL: ", label)
