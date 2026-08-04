extends SceneTree


class MockWorld:
	extends Node2D

	var item_database: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := MockWorld.new()
	root.add_child(world)
	var item_database_script := load("res://Scripts/item_database.gd")
	var atlas_database_script := load("res://Scripts/ItemAtlasDB.gd")
	assert(item_database_script != null and atlas_database_script != null, "Could not load item databases.")
	world.item_database = atlas_database_script.merge_item_database(
		item_database_script.ITEMS.duplicate(true)
	)
	world.item_database["server_only_state"] = {
		"category": "block",
		"placeable": true,
		"client_place_prediction": false
	}
	world.item_database["not_placeable"] = {
		"category": "block",
		"placeable": false
	}

	var block_manager_script := load("res://Scripts/block_manager.gd") as Script
	assert(block_manager_script != null, "Could not load BlockManager.")
	var block_manager = block_manager_script.new()
	block_manager.world = world

	for block_type in [
		"dirt",
		"password_door",
		"mail_box",
		"display_box",
		"vend_empty",
		"safe",
		"tackle_box",
		"chicken",
		"water_well",
		"dice_block",
		"anti_punch",
		"night_theme_machine",
		"cctv",
		"generator",
		"electric_pole",
		"oil_refinery",
		"battery_charger",
		"fish_monger"
	]:
		assert(
			block_manager.get_authoritative_place_prediction_rejection_reason(block_type, "foreground") == "",
			block_type + " should use reversible local placement prediction."
		)

	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("wooden_background", "background") == ""
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("wooden_background", "foreground") == "layer_mismatch"
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("world_lock", "foreground") == "lock_state_must_be_confirmed"
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("small_lock", "foreground") == "lock_state_must_be_confirmed"
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("water", "foreground") == "water_uses_bucket_flow"
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("server_only_state", "foreground") == "item_opted_out"
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("not_placeable", "foreground") == "item_not_placeable"
	)
	assert(
		block_manager.get_authoritative_place_prediction_rejection_reason("missing_block", "foreground") == "missing_item_definition"
	)

	block_manager.free()
	world.free()
	print("[authoritative-special-block-prediction] success")
	quit(0)
