extends SceneTree

class WorldFixture extends Node:
	var item_database: Dictionary = {}
	var back_textures: Dictionary = {}
	var body_accessory_textures: Dictionary = {}

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
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/capes_20261013.json"))
	root.get_viewport().size = Vector2i(1100, 1000)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color(0.055, 0.075, 0.12))
	var row := 0
	for entry in cases:
		var id: String = entry.id
		var data: Dictionary = world.item_database[id]
		assert(data.category == "back" and data.equipment_slot == "back" and data.instance_tracked)
		assert(data.jump_type == "none")
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
			var neck_texture := neck.sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
			assert(neck_texture.region == Rect2(0, (entry.row - 24) * 32, 32, 32))
			assert(not neck_texture.get_image().is_invisible())
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
			assert(manager.back_item_fx == null)
			manager.update_equipped_back_visual(id, facing)
			manager.hide_back_item()
			assert(not neck.visible and not cape.visible and necklace.visible)
			assert(manager.back_item_fx == null)
			necklace.visible = false
			manager.update_equipped_back_visual(id, facing)
			manager.set_forced_animation_state("idle")
			manager.update_back_item_animation(0)
			cape.set_process_internal(false)
			# Two extra pose actors make the render show idle / jump / fall for each facing.
			for animation in ["jump", "fall"]:
				var pose := visual.duplicate()
				pose.position.x = 38 if animation == "jump" else 76
				actor.add_child(pose)
				var pose_cape: AnimatedSprite2D = pose.get_node("BackSlot/BackItemAnimated")
				pose_cape.play(animation)
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
	print("CAPES_PASS: five previews, collars, 64x64 poses, four idle frames, jump/fall, both facings, necklace coexistence, swaps/unequip, bounded purple/red bats")
	for actor in actors: actor.free()
	source.free()
	world.free()
	quit()
