extends SceneTree

class WorldFixture extends Node:
	var item_database: Dictionary = {}
	var back_textures: Dictionary = {}
	var body_accessory_textures: Dictionary = {}
	var equipped_back_item := ""
	func is_movement_locked() -> bool: return false

var world: WorldFixture
var source: Node
var actors: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func strip(node: Node) -> void:
	node.set_script(null)
	if node is AnimatedSprite2D:
		node.stop()
		node.frame = 0
		node.visible = str(node.name).begins_with("Base")
	for child in node.get_children():
		strip(child)

func run() -> void:
	var equipment = load("res://Scripts/equipment_manager.gd")
	var factory = load("res://Scripts/atlas_texture_factory.gd")
	world = WorldFixture.new()
	root.add_child(world)
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	source = load("res://Scenes/main.tscn").instantiate()
	var jump_probe = load("res://tests/fixtures/cape_jump_player_probe.gd").new()
	jump_probe.fixture_world = world
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/capes_20261013.json"))
	root.get_viewport().size = Vector2i(1100, 1000)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color(0.055, 0.075, 0.12))
	var row := 0
	for entry in cases:
		var id: String = entry.id
		var data: Dictionary = world.item_database[id]
		assert(data.category == "back" and data.equipment_slot == "back" and data.instance_tracked)
		assert(data.jump_type == "double")
		world.equipped_back_item = id
		var real_player = source.get_node("Player")
		real_player.cached_world_controller = world
		assert(real_player.get_extra_air_jumps_allowed() == 1, "Each cape must grant one extra airborne jump")
		jump_probe.air_jumps_used = 0
		jump_probe.accepted_jumps = 0
		jump_probe.coyote_timer = 0.1
		assert(jump_probe.try_jump(), "Ground jump must succeed")
		assert(jump_probe.try_jump(), "Cape must allow a second jump in the air")
		assert(not jump_probe.try_jump(), "Cape must not allow a third jump")
		assert(jump_probe.accepted_jumps == 2)
		var icon := factory.load_texture(data.inventory_icon) as AtlasTexture
		assert(icon.region == Rect2(0, (entry.row - 25) * 32, 32, 32))
		assert(not icon.get_image().is_invisible())
		for facing in [1, -1]:
			var actor := Node2D.new()
			root.add_child(actor)
			actors.append(actor)
			actor.position = Vector2(150 + (0 if facing == 1 else 520), 150 + row * 190)
			actor.scale = Vector2.ONE * 4.0
			var visual: Node2D = source.get_node("Player/PlayerVisual").duplicate()
			strip(visual)
			actor.add_child(visual)
			visual.scale.x = facing
			var manager = equipment.new()
			actor.add_child(manager)
			manager.set_process(false)
			manager.world = world
			manager.player = actor
			manager.setup_back_socket()
			manager.setup_wearable_animated_parts()
			manager.set_forced_animation_state("idle")
			manager.update_equipped_back_visual(id, facing)
			var cape: AnimatedSprite2D = manager.back_sprite
			cape.set_process_internal(false)
			var neck: AnimatedSprite2D = manager.get_wearable_part("cape_neck")
			assert(neck.visible and neck.get_parent() == visual.get_node("Body"))
			var head: Node2D = visual.get_node("Head")
			assert(neck.z_index + neck.get_parent().z_index > head.z_index + visual.get_node("Head/BaseHeadAnimated").z_index, "Tall cape collars must draw in front of the face")
			var rear_neck: AnimatedSprite2D = manager.get_wearable_part("cape_neck_behind")
			assert(rear_neck.visible and rear_neck.position == neck.position)
			assert(rear_neck.z_index + rear_neck.get_parent().z_index < head.z_index, "The right collar half must stay behind the face")
			assert(neck.material != rear_neck.material)
			assert(neck.material.get_shader_parameter("left_half") == true and rear_neck.material.get_shader_parameter("left_half") == false)
			var neck_texture := neck.sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
			assert(neck_texture.region == Rect2(0, (entry.row - 24) * 32, 32, 32))
			assert(not neck_texture.get_image().is_invisible())
			if id == "black_hero_cape" and facing == 1:
				for anchor_sprite in [visual.get_node("Head/BaseHeadAnimated"), visual.get_node("Body/BaseBodyAnimated"), neck, cape]:
					var anchor_texture: Texture2D = anchor_sprite.sprite_frames.get_frame_texture(anchor_sprite.animation, anchor_sprite.frame)
					var used: Rect2i = anchor_texture.get_image().get_used_rect()
					print("CAPE_ANCHOR ", anchor_sprite.name, " ", anchor_sprite.to_global(Vector2(used.position) - anchor_texture.get_size() / 2.0), " to ", anchor_sprite.to_global(Vector2(used.end) - anchor_texture.get_size() / 2.0))
				var body_sprite: AnimatedSprite2D = visual.get_node("Body/BaseBodyAnimated")
				var body_texture: Texture2D = body_sprite.sprite_frames.get_frame_texture(body_sprite.animation, body_sprite.frame)
				var body_used: Rect2i = body_texture.get_image().get_used_rect()
				var shoulder_y: float = body_sprite.to_global(Vector2(body_used.position) - body_texture.get_size() / 2.0).y
				var collar_used: Rect2i = neck_texture.get_image().get_used_rect()
				var collar_y: float = neck.to_global(Vector2(collar_used.position) - neck_texture.get_size() / 2.0).y
				var cape_texture: Texture2D = cape.sprite_frames.get_frame_texture("idle", 0)
				var cape_used: Rect2i = cape_texture.get_image().get_used_rect()
				var cape_y: float = cape.to_global(Vector2(cape_used.position) - cape_texture.get_size() / 2.0).y
				assert(is_equal_approx(collar_y, shoulder_y + 4) and is_equal_approx(cape_y, shoulder_y - 4), "The reference places the collar one pixel below and cape one pixel above the shoulder line at 4x scale")
				assert(data.cape_neck_offset == [2, 8] and data.back_pose_offsets.default == [-1, 12], "Preserve the reference's asymmetric jaw collar and centered cape")
			var frames := cape.sprite_frames
			for animation in ["idle", "walk", "jump", "fall"]:
				var columns: Array = [1, 3, 5, 7] if animation in ["idle", "walk"] else ([9] if animation == "jump" else [11])
				assert(frames.get_frame_count(animation) == columns.size())
				for frame in range(columns.size()):
					var texture := frames.get_frame_texture(animation, frame) as AtlasTexture
					assert(texture.region == Rect2(columns[frame] * 32, (entry.row - 25) * 32, 64, 64))
					assert(not texture.get_image().is_invisible())
				manager.set_forced_animation_state(animation)
				manager.update_back_item_animation(0.016)
				assert(cape.animation == animation)
				var expected_offset: Array = data.back_pose_offsets.get(animation, data.back_pose_offsets.default)
				assert(cape.position == manager.get_wearable_part_base_position("back", Vector2.ZERO) + Vector2(expected_offset[0], expected_offset[1]))
			var fx = manager.back_item_fx
			if id in ["vampire_cape", "dracula_cape"]:
				assert(is_instance_valid(fx) and fx.wings == cape)
				fx.set_process(false)
				fx.rng.seed = 12
				var pose_before := cape.animation
				for step in range(120): fx._process(1.0 / 60.0)
				assert(fx.particles.size() > 0 and fx.particles.size() <= fx.MAX_BATS)
				assert(cape.animation == pose_before)
				assert(fx.bat_color.r > 0.9 if id == "dracula_cape" else fx.bat_color.r < 0.3)
				manager.update_equipped_back_visual(id, facing)
				assert(manager.back_item_fx == fx)
			else:
				assert(fx == null)
			# A cape collar owns a separate visual, independent of an equipped necklace.
			var necklace: AnimatedSprite2D = manager.get_wearable_part("body_accessory")
			necklace.visible = true
			manager.update_equipped_back_visual("devil_wings", facing)
			assert(not neck.visible and necklace.visible)
			assert(not rear_neck.visible)
			assert(cape.position == manager.get_wearable_part_base_position("back", Vector2.ZERO), "Swapping to wings must restore the editor anchor")
			assert(manager.back_item_fx == null)
			manager.update_equipped_back_visual(id, facing)
			manager.hide_back_item()
			assert(not neck.visible and not cape.visible and necklace.visible)
			assert(not rear_neck.visible)
			assert(manager.back_item_fx == null)
			necklace.visible = false
			manager.update_equipped_back_visual(id, facing)
			manager.set_forced_animation_state("idle")
			manager.update_back_item_animation(0)
			var positioned_cape: Vector2 = cape.position
			var positioned_neck: Vector2 = neck.position
			manager.setup_wearable_animated_parts()
			manager.update_equipped_back_visual(id, facing)
			assert(cape.position == positioned_cape and neck.position == positioned_neck, "Rebinding the player must not accumulate cape offsets")
			assert(rear_neck.visible and rear_neck.position == positioned_neck)
			cape.set_process_internal(false)
			# Two extra pose actors make the render show idle / jump / fall for each facing.
			for animation in ["jump", "fall"]:
				var pose := visual.duplicate()
				pose.position.x = 38 if animation == "jump" else 76
				actor.add_child(pose)
				var pose_cape: AnimatedSprite2D = pose.get_node("BackSlot/BackItemAnimated")
				pose_cape.play(animation)
				var pose_offset: Array = data.back_pose_offsets.get(animation, data.back_pose_offsets.default)
				pose_cape.position = manager.get_wearable_part_base_position("back", Vector2.ZERO) + Vector2(pose_offset[0], pose_offset[1])
				pose_cape.set_process_internal(false)
				var pose_fx = pose.get_node_or_null("BackSlot/BackItemFX")
				if pose_fx != null: pose_fx.queue_free()
			if is_instance_valid(manager.back_item_fx):
				manager.back_item_fx.set_process(false)
				for step in range(60): manager.back_item_fx._process(1.0 / 60.0)
		row += 1
		var label := Label.new()
		label.text = entry.name + "     |     IDLE / JUMP / FALL     |     RIGHT / LEFT"
		label.position = Vector2(32, row * 190)
		label.add_theme_font_size_override("font_size", 14)
		root.add_child(label)
	if "--render" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("D:/Pixelmania/work/capes-preview.png")
	print("CAPES_PASS: five double jumps (third jump rejected), shoulder/collar anchors, 64x64 poses, both facings, necklace coexistence, rebind/swap/unequip, bounded purple/red bats")
	for actor in actors: actor.free()
	source.free()
	jump_probe.free()
	world.free()
	quit()
