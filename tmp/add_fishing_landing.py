from pathlib import Path
p=Path('Scripts/fishing_manager.gd');t=p.read_text();t=t.replace('var current_lure_id', 'var landing_origin := Vector2(INF, INF)\nvar landing_generation := 0\nvar landing_fx: Node2D\n\nvar current_lure_id',1)
t=t.replace('func start_local_cast(target_grid: Vector2i, lure_id: String, spend_lure: bool = true, session_id: String = "", fish_data: Dictionary = {}):','''func start_local_cast(target_grid: Vector2i, lure_id: String, spend_lure: bool = true, session_id: String = "", fish_data: Dictionary = {}):
	landing_generation += 1
	landing_origin = Vector2(INF, INF)
	if is_instance_valid(landing_fx):
		landing_fx.queue_free()''')
t=t.replace('\tplay_bobber_anim("bite")','\t_update_hooked_bobber()\n\tplay_bobber_anim("bite")',1)
t=t.replace('\tif server_fishing_session_id != "":\n\t\tif request_server_fishing_complete(true):','\tlanding_origin = bobber.global_position if is_instance_valid(bobber) else Vector2(INF, INF)\n\tif server_fishing_session_id != "":\n\t\tif request_server_fishing_complete(true):',1)
t=t.replace('\t\t\tplay_bobber_anim("reel_success")','\t\t\t# The confirmed reward drives the landing presentation.',1)
t=t.replace('\t\tplay_bobber_anim("reel_success")','\t\t# Landing presentation replaces the old bait pop.',1).replace('\tplay_bobber_anim("reel_success")','\t# Landing presentation replaces the old bait pop.',1)
old='\tfishing_ui.show_catch_result(_build_catch_result_data(fish_id, was_new, catch_weight, category))'
new='''	var result := _build_catch_result_data(fish_id, was_new, catch_weight, category)
	if not landing_origin.is_finite():
		fishing_ui.show_catch_result(result)
		return
	var origin := landing_origin
	landing_origin = Vector2(INF, INF)
	var generation := landing_generation
	var origin_world := str(world.current_world_name)
	fishing_ui.hide_fishing_state()
	if is_instance_valid(bobber):
		bobber.hide()
	landing_fx = load("res://Scripts/fishing_landing_fx.gd").new()
	world.add_child(landing_fx)
	landing_fx.global_position = origin
	landing_fx.z_index = 240
	landing_fx.setup(_hooked_artwork(get_reward_texture(fish_id, category)), fishing_ui.get_rarity_color(str(result.get("rarity", "common"))))
	landing_fx.landed.connect(func():
		if generation == landing_generation and str(world.current_world_name) == origin_world and not world.fishing_active and not awaiting_cast_ack:
			fishing_ui.show_catch_result(result)
	, CONNECT_ONE_SHOT)'''
assert old in t;t=t.replace(old,new)
t+='''

func _hooked_artwork(texture: Texture2D) -> Texture2D:
	if texture == null: return null
	var image := texture.get_image()
	if image == null: return texture
	var bounds := image.get_used_rect()
	if not bounds.has_area(): return texture
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(bounds)
	cropped.filter_clip = true
	return cropped


func _update_hooked_bobber() -> void:
	if not is_instance_valid(bobber): return
	var sprite := bobber.get_node_or_null("Sprite2D") as Sprite2D
	var texture := _hooked_artwork(get_reward_texture(pending_fish_id, get_pending_reward_category()))
	if sprite == null or texture == null: return
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (36.0 / maxf(texture.get_width(), texture.get_height()))
'''
p.write_text(t)
p=Path('tests/run_fishing_tests.ps1');t=p.read_text().replace("'Scripts/fishing_manager.gd',", "'Scripts/fishing_landing_fx.gd', 'Scripts/fishing_manager.gd',");p.write_text(t)
p=Path('tests/fishing_minigame_test.gd');t=p.read_text().replace('check(manager.fishing_ui.catch_card.visible, "Local catch card was not shown")','check(not manager.fishing_ui.catch_card.visible, "Card must wait for the landing reveal")\n\tawait create_timer(1.15).timeout\n\tcheck(manager.fishing_ui.catch_card.visible, "Local catch card was not shown after landing")');p.write_text(t)
