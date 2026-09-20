extends "res://Scripts/world.gd"

func get_pending_join_world_name_early() -> String:
	return ""

func load_player_data():
	pass

func exit_to_main_menu(_save_current_world: bool = true):
	pass

func _load_item_database():
	var started := Time.get_ticks_usec()
	super._load_item_database()
	print("SETUP_TIMING _load_item_database ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_netfox_real_manager():
	var started := Time.get_ticks_usec()
	super.setup_netfox_real_manager()
	print("SETUP_TIMING setup_netfox_real_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_background_manager():
	var started := Time.get_ticks_usec()
	super.setup_background_manager()
	print("SETUP_TIMING setup_background_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_reach_indicator_manager():
	var started := Time.get_ticks_usec()
	super.setup_reach_indicator_manager()
	print("SETUP_TIMING setup_reach_indicator_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_sound_manager():
	var started := Time.get_ticks_usec()
	super.setup_sound_manager()
	print("SETUP_TIMING setup_sound_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_world_loading_ui_manager():
	var started := Time.get_ticks_usec()
	super.setup_world_loading_ui_manager()
	print("SETUP_TIMING setup_world_loading_ui_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_item_database():
	var started := Time.get_ticks_usec()
	super.setup_item_database()
	print("SETUP_TIMING setup_item_database ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_drop_manager():
	var started := Time.get_ticks_usec()
	super.setup_drop_manager()
	print("SETUP_TIMING setup_drop_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_world_generation_manager():
	var started := Time.get_ticks_usec()
	super.setup_world_generation_manager()
	print("SETUP_TIMING setup_world_generation_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_block_manager():
	var started := Time.get_ticks_usec()
	super.setup_block_manager()
	print("SETUP_TIMING setup_block_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_electricity_manager():
	var started := Time.get_ticks_usec()
	super.setup_electricity_manager()
	print("SETUP_TIMING setup_electricity_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_particle_manager():
	var started := Time.get_ticks_usec()
	super.setup_particle_manager()
	print("SETUP_TIMING setup_particle_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_water_surface_manager():
	var started := Time.get_ticks_usec()
	super.setup_water_surface_manager()
	print("SETUP_TIMING setup_water_surface_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_block_shadow_manager():
	var started := Time.get_ticks_usec()
	super.setup_block_shadow_manager()
	print("SETUP_TIMING setup_block_shadow_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_interaction_manager():
	var started := Time.get_ticks_usec()
	super.setup_interaction_manager()
	print("SETUP_TIMING setup_interaction_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_player_manager():
	var started := Time.get_ticks_usec()
	super.setup_player_manager()
	print("SETUP_TIMING setup_player_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_custom_authoritative_movement_manager():
	var started := Time.get_ticks_usec()
	super.setup_custom_authoritative_movement_manager()
	print("SETUP_TIMING setup_custom_authoritative_movement_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_gameplay_ui_manager():
	var started := Time.get_ticks_usec()
	super.setup_gameplay_ui_manager()
	print("SETUP_TIMING setup_gameplay_ui_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_ui_layers():
	var started := Time.get_ticks_usec()
	super.setup_ui_layers()
	print("SETUP_TIMING setup_ui_layers ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_fishing_manager():
	var started := Time.get_ticks_usec()
	super.setup_fishing_manager()
	print("SETUP_TIMING setup_fishing_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_fish_monger_manager():
	var started := Time.get_ticks_usec()
	super.setup_fish_monger_manager()
	print("SETUP_TIMING setup_fish_monger_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_item_gameplay_manager():
	var started := Time.get_ticks_usec()
	super.setup_item_gameplay_manager()
	print("SETUP_TIMING setup_item_gameplay_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_vending_preview_manager():
	var started := Time.get_ticks_usec()
	super.setup_vending_preview_manager()
	print("SETUP_TIMING setup_vending_preview_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_environment_manager():
	var started := Time.get_ticks_usec()
	super.setup_environment_manager()
	print("SETUP_TIMING setup_environment_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_input_manager():
	var started := Time.get_ticks_usec()
	super.setup_input_manager()
	print("SETUP_TIMING setup_input_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_mobile_controls():
	var started := Time.get_ticks_usec()
	super.setup_mobile_controls()
	print("SETUP_TIMING setup_mobile_controls ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_account_manager():
	var started := Time.get_ticks_usec()
	super.setup_account_manager()
	print("SETUP_TIMING setup_account_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_world_lock_manager():
	var started := Time.get_ticks_usec()
	super.setup_world_lock_manager()
	print("SETUP_TIMING setup_world_lock_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_area_lock_highlight_overlay():
	var started := Time.get_ticks_usec()
	super.setup_area_lock_highlight_overlay()
	print("SETUP_TIMING setup_area_lock_highlight_overlay ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_world_state_sync_manager():
	var started := Time.get_ticks_usec()
	super.setup_world_state_sync_manager()
	print("SETUP_TIMING setup_world_state_sync_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_username_label_manager():
	var started := Time.get_ticks_usec()
	super.setup_username_label_manager()
	print("SETUP_TIMING setup_username_label_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_water_animation():
	var started := Time.get_ticks_usec()
	super.setup_water_animation()
	print("SETUP_TIMING setup_water_animation ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_crack_textures():
	var started := Time.get_ticks_usec()
	super.setup_crack_textures()
	print("SETUP_TIMING setup_crack_textures ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_seed_system():
	var started := Time.get_ticks_usec()
	super.setup_seed_system()
	print("SETUP_TIMING setup_seed_system ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_equipment_manager():
	var started := Time.get_ticks_usec()
	super.setup_equipment_manager()
	print("SETUP_TIMING setup_equipment_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_player_animation_manager():
	var started := Time.get_ticks_usec()
	super.setup_player_animation_manager()
	print("SETUP_TIMING setup_player_animation_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_inventory_manager():
	var started := Time.get_ticks_usec()
	super.setup_inventory_manager()
	print("SETUP_TIMING setup_inventory_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_save_manager():
	var started := Time.get_ticks_usec()
	super.setup_save_manager()
	print("SETUP_TIMING setup_save_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_command_manager():
	var started := Time.get_ticks_usec()
	super.setup_command_manager()
	print("SETUP_TIMING setup_command_manager ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_chat_ui():
	var started := Time.get_ticks_usec()
	super.setup_chat_ui()
	print("SETUP_TIMING setup_chat_ui ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_notification_ui():
	var started := Time.get_ticks_usec()
	super.setup_notification_ui()
	print("SETUP_TIMING setup_notification_ui ", (Time.get_ticks_usec() - started) / 1000.0)

func setup_landfill_race_hud():
	var started := Time.get_ticks_usec()
	super.setup_landfill_race_hud()
	print("SETUP_TIMING setup_landfill_race_hud ", (Time.get_ticks_usec() - started) / 1000.0)

func update_all_ui():
	var started := Time.get_ticks_usec()
	super.update_all_ui()
	print("SETUP_TIMING update_all_ui ", (Time.get_ticks_usec() - started) / 1000.0)


var detail_timings := {}

func load_texture_spec(texture_spec) -> Texture2D:
	var started := Time.get_ticks_usec()
	var result = super.load_texture_spec(texture_spec)
	detail_timings["load_texture_spec"] = detail_timings.get("load_texture_spec",0) + Time.get_ticks_usec()-started
	return result

func get_block_atlas_icon_texture(block_type: String, block_data: Dictionary = {}, atlas_tile_set: TileSet = null) -> Texture2D:
	var started := Time.get_ticks_usec()
	var result = super.get_block_atlas_icon_texture(block_type, block_data, atlas_tile_set)
	detail_timings["get_block_atlas_icon_texture"] = detail_timings.get("get_block_atlas_icon_texture",0) + Time.get_ticks_usec()-started
	return result

func get_seed_growth_tree_textures(block_type: String) -> Array:
	var started := Time.get_ticks_usec()
	var result = super.get_seed_growth_tree_textures(block_type)
	detail_timings["get_seed_growth_tree_textures"] = detail_timings.get("get_seed_growth_tree_textures",0) + Time.get_ticks_usec()-started
	return result
