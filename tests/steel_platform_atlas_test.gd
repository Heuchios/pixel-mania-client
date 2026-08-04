extends SceneTree


const EXPECTED_SINGLE_COORDS := Vector2i(6, 12)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_database_script := load("res://Scripts/item_database.gd")
	var atlas_database_script := load("res://Scripts/ItemAtlasDB.gd")
	assert(item_database_script != null, "Could not load the item database.")
	assert(atlas_database_script != null, "Could not load the atlas database.")

	var merged_database: Dictionary = atlas_database_script.merge_item_database(
		item_database_script.ITEMS.duplicate(true)
	)
	var steel_platform: Dictionary = merged_database.get("steel_platform", {})
	if to_atlas_coords(steel_platform.get("atlas_coords")) != EXPECTED_SINGLE_COORDS:
		fail_test("Single Steel Platform must use atlas cell (6, 12).")
		return

	var texture_data: Dictionary = steel_platform.get("texture", {})
	var inventory_icon_data: Dictionary = steel_platform.get("inventory_icon", {})
	if to_atlas_coords(texture_data.get("cell")) != EXPECTED_SINGLE_COORDS:
		fail_test("Placed Steel Platform texture must use atlas cell (6, 12).")
		return
	if to_atlas_coords(inventory_icon_data.get("cell")) != EXPECTED_SINGLE_COORDS:
		fail_test("Steel Platform inventory icon must use atlas cell (6, 12).")
		return
	if not steel_platform.has("platform_variant_textures"):
		fail_test("Connected Steel Platform variants must remain configured.")
		return

	print("[steel-platform-atlas] success")
	quit(0)


func to_atlas_coords(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func fail_test(message: String) -> void:
	push_error("[steel-platform-atlas] " + message)
	quit(1)
