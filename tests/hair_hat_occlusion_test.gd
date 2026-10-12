extends SceneTree

# GPU checks and preview: run with a rendering driver and -- --render.
const Equipment = preload("res://Scripts/equipment_manager.gd")
const Occlusion = preload("res://Scripts/hair_hat_occlusion.gd")
const ACCESSORIES := ["ruby_bow", "violet_bow", "red_headband", "red_headphones", "meowphones"]
var failures := 0
var checks := 0

class WorldFixture extends Node:
	var item_database := {}
	var hair_textures := {}
	var pants_textures := {}
	var shirt_textures := {}
	var shoes_textures := {}

class RemoteProbe extends "res://Scripts/player_manager.gd":
	var actual_equipment: Node
	func get_remote_equipment_manager(_actor): return actual_equipment

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func strip_scripts(node: Node):
	node.set_script(null)
	if node is AnimationPlayer: node.stop()
	if node is AnimatedSprite2D: node.stop()
	for child in node.get_children(): strip_scripts(child)

func run():
	var database = load("res://Scripts/item_database.gd").new()
	var world := WorldFixture.new()
	var hairs := []
	var hats := []
	for id in database.ITEMS:
		var data: Dictionary = database.get_item_data(id)
		world.item_database[id] = data
		if data.get("equipment_slot", "") == "hair": hairs.append(id)
		if data.get("equipment_slot", "") == "hat": hats.append(id)
	var scene = load("res://Scenes/main.tscn").instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 160)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var actor := Node2D.new()
	var visual = scene.get_node("Player/PlayerVisual").duplicate()
	strip_scripts(visual)
	actor.add_child(visual)
	actor.position = Vector2(80, 120)
	actor.scale = Vector2(3, 3)
	viewport.add_child(actor)
	var equipment = Equipment.new()
	equipment.player = actor
	equipment.world = world
	equipment.setup_wearable_animated_parts()
	var remote := RemoteProbe.new()
	remote.actual_equipment = equipment
	var pairs := 0
	for hair_id in hairs:
		for hat_id in hats:
			for facing in [1, -1]:
				visual.scale.x = facing
				equipment.update_equipped_hat_visual("", facing)
				equipment.update_equipped_hair_visual(hair_id, facing)
				var hair: AnimatedSprite2D = equipment.hair_item_animated
				var original: SpriteFrames = hair.sprite_frames
				var slots := {"hair": hair_id, "hat": hat_id}
				actor.set_meta("equipment_slots", slots)
				actor.set_meta("facing", facing)
				actor.remove_meta("applied_equipment_slots_debug_key")
				check(remote.update_remote_shared_equipment_visuals(actor), "Remote equip " + hat_id)
				check(remote.update_remote_shared_equipment_visuals(actor), "Cached remote appearance")
				check(hair.sprite_frames == original, "Must not replace original hair frames")
				check(equipment.wearable_part_item_ids.hair == hair_id, "Must retain equipped hair")
				if world.item_database[hat_id].get("hides_hair", false):
					check(not hair.visible, "Full helmet must still hide hair")
				elif hat_id in ACCESSORIES:
					check(hair.visible and hair.material == null, "Decorative accessory must retain full hair")
				else:
					check(hair.visible and hair.material is ShaderMaterial and hair.material.shader == Occlusion.CLIP_SHADER, "Hat/crown must tuck hair: " + hat_id)
					var material: Material = hair.material
					for state in ["idle", "walk", "jump", "fall", "punch"]:
						equipment.play_wearable_part_animation(hair, state)
						check(hair.material == material, "Hair clipping must survive animation changes")
				equipment.update_equipped_hat_visual("", facing)
				check(hair.visible and hair.material == null and hair.sprite_frames == original, "Unequip must restore full hair")
				pairs += 1
	var cached_bounds := Occlusion.texture_profiles.size()
	for i in 5:
		equipment.update_equipped_hat_visual("red_baseball_cap", 1)
		equipment.update_equipped_hat_visual("witch_hat", 1)
	check(Occlusion.texture_profiles.size() == cached_bounds, "Repeated swaps must reuse cached hat texture profiles")
	# Future catalog entries inherit the behavior without an item-ID allowlist.
	world.item_database["future_hat"] = world.item_database.red_baseball_cap.duplicate(true)
	world.item_database["future_hair"] = world.item_database.chestnut_curtains.duplicate(true)
	equipment.update_equipped_hat_visual("future_hat", 1)
	equipment.update_equipped_hair_visual("future_hair", 1)
	check(equipment.hair_item_animated.material is ShaderMaterial, "New hat and hair IDs must tuck automatically")
	equipment.update_equipped_hair_visual("", 1)
	equipment.update_equipped_hat_visual("", 1)
	check(not equipment.hair_item_animated.visible, "Actually unequipped hair must stay hidden")
	if "--render" in OS.get_cmdline_user_args():
		await check_rendered(viewport, actor, equipment)
	remote.free()
	equipment.free()
	world.free()
	scene.free()
	database.free()
	viewport.queue_free()
	print("HAIR_HAT_OCCLUSION: ", hairs.size(), " hairstyles, ", hats.size(), " head items, ", pairs, " facing/pair cases, ", checks, " checks, failures=", failures)
	quit(1 if failures else 0)

func picture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func freeze_parts(equipment):
	for part in equipment.wearable_part_nodes.values():
		if part.sprite_frames != null and part.sprite_frames.has_animation("idle"):
			part.animation = "idle"
		part.pause()
		part.frame = 0

func check_rendered(viewport: SubViewport, actor: Node2D, equipment):
	var examples := [
		["messy_brown_hair", "red_baseball_cap"],
		["crazy_hair", "royal_crown"],
		["black_spiky_hair", "royal_crown"],
		["chestnut_curtains", "neptune_crown"],
		["ginger_pigtails", "witch_hat"],
		["supernova_hair", "sunflower_cap"],
		["baby_hair", "chefs_hat"],
	]
	var preview := Image.create(480, examples.size() * 160, false, Image.FORMAT_RGBA8)
	preview.fill(Color("40364c"))
	var correction_preview := Image.create(480, 640, false, Image.FORMAT_RGBA8)
	correction_preview.fill(Color("40364c"))
	var removed_pixels := 0
	var preserved_pixels := 0
	var restored_corner_pixels := 0
	var visual: Node2D = actor.get_node("PlayerVisual")
	for row in examples.size():
		var pair: Array = examples[row]
		for facing in [1, -1]:
			visual.scale.x = facing
			equipment.update_equipped_hat_visual("", facing)
			equipment.update_equipped_hair_visual(pair[0], facing)
			freeze_parts(equipment)
			var full_portrait := await picture(viewport)
			equipment.update_equipped_hat_visual(pair[1], facing)
			freeze_parts(equipment)
			var hair: AnimatedSprite2D = equipment.hair_item_animated
			var hat: AnimatedSprite2D = equipment.hat_item_animated
			var clipped_material: Material = hair.material
			var profile := Occlusion.get_hat_profile(hat)
			var flat_bottom: float = profile.edge[0]
			for edge in profile.edge: flat_bottom = maxf(flat_bottom, edge)
			hair.material = null
			var before := await picture(viewport)
			hair.material = clipped_material
			var after := await picture(viewport)
			if row < 2:
				# Render the previous, flat cutoff as a negative control. The actual
				# portrait must regain temple/corner hair and the central front fringe.
				var flat_image := Image.create(profile.edge.size(), 1, false, Image.FORMAT_RF)
				flat_image.fill(Color(flat_bottom, 0.0, 0.0))
				clipped_material.set_shader_parameter("brim_profile", ImageTexture.create_from_image(flat_image))
				var old_flat := await picture(viewport)
				clipped_material.set_shader_parameter("brim_profile", profile.texture)
				var regained := 0
				for y in after.get_height():
					for x in after.get_width():
						var local := hat.to_local(Vector2(x + 0.5, y + 0.5)) - hat.offset
						var in_region := absf(local.x) > 7.0 if row == 0 else absf(local.x) <= 7.0
						if in_region and after.get_pixel(x, y) != old_flat.get_pixel(x, y): regained += 1
				check(regained > 0, "%s facing %d must visibly restore %s" % [pair[1], facing, "corner hair" if row == 0 else "front fringe"])
				var preview_y := (row * 2 + (1 if facing < 0 else 0)) * 160
				correction_preview.blend_rect(old_flat, Rect2i(0, 0, 160, 160), Vector2i(0, preview_y))
				correction_preview.blend_rect(after, Rect2i(0, 0, 160, 160), Vector2i(160, preview_y))
				correction_preview.blend_rect(full_portrait, Rect2i(0, 0, 160, 160), Vector2i(320, preview_y))
			if facing == 1:
				preview.blend_rect(before, Rect2i(0, 0, 160, 160), Vector2i(0, row * 160))
				preview.blend_rect(after, Rect2i(0, 0, 160, 160), Vector2i(160, row * 160))
				preview.blend_rect(full_portrait, Rect2i(0, 0, 160, 160), Vector2i(320, row * 160))
			# Isolate hair to verify that upper pixels disappear and lower pixels
			# remain exactly unchanged, including atlas UVs and mirrored sprites.
			var hidden := []
			for parent in visual.get_children():
				for child in parent.get_children():
					if child is CanvasItem and child != hair and child.visible:
						hidden.append(child)
						child.hide()
			var clipped := await picture(viewport)
			hair.material = null
			var full := await picture(viewport)
			var raised_edge_pixels := 0
			for y in full.get_height():
				for x in full.get_width():
					var pixel := full.get_pixel(x, y)
					var hat_pixel := hat.to_local(Vector2(x + 0.5, y + 0.5)) - hat.offset
					var column := clampi(floori(hat_pixel.x - profile.left), 0, profile.edge.size() - 1)
					if hat_pixel.y < profile.edge[column]:
						check(clipped.get_pixel(x, y).a == 0.0, "%s hair protrudes above hat" % pair[0])
						if pixel.a > 0: removed_pixels += 1
					else:
						check(clipped.get_pixel(x, y).is_equal_approx(pixel), "%s lower hair changed" % pair[0])
						if pixel.a > 0: preserved_pixels += 1
						if pixel.a > 0 and hat_pixel.y < flat_bottom:
							raised_edge_pixels += 1
			if pair[1] in ["red_baseball_cap", "royal_crown"]:
				check(raised_edge_pixels > 0, "%s/%s must preserve hair under the raised brim that the flat cutoff removed" % pair)
			restored_corner_pixels += raised_edge_pixels
			hair.material = clipped_material
			for child in hidden: child.show()
			equipment.update_equipped_hat_visual("", facing)
			var restored := await picture(viewport)
			check(restored.get_data() == full_portrait.get_data(), "Removing hat must restore exact original portrait: " + pair[0])
	check(removed_pixels > 0 and preserved_pixels > 0, "Render test must exercise both upper and lower hair")
	var preview_path := "user://hair_hat_preview.png"
	preview.save_png(preview_path)
	correction_preview.save_png("user://hair_hat_corner_correction.png")
	print("HAIR_HAT_RENDER: removed=", removed_pixels, "; preserved=", preserved_pixels, "; restored_corner_pixels=", restored_corner_pixels, "; preview=", ProjectSettings.globalize_path(preview_path))
