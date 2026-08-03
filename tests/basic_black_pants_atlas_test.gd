extends SceneTree

const ATLAS_TEXTURE_FACTORY = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_DATABASE_SCRIPT_PATH := "res://Scripts/item_database.gd"
const EXPECTED_ICON_CELL := Vector2i(6, 0)
const EXPECTED_PANTS_CELL := Vector2i(7, 0)
const ATLAS_CELL_SIZE := Vector2(32, 32)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_database_script = load(ITEM_DATABASE_SCRIPT_PATH)
	assert(item_database_script is GDScript)
	var item_database_node = item_database_script.new()

	var item_data: Dictionary = item_database_node.get_item_data("basic_black_pants")
	_expect(str(item_data.get("texture", "")) == "basic_black_pants", "Black pants must reference the wearable atlas body frame.")
	_expect(str(item_data.get("inventory_icon", "")) == "basic_black_pants_icon", "Black pants must reference the wearable atlas icon frame.")

	var texture = ATLAS_TEXTURE_FACTORY.load_texture(item_data.get("texture"))
	var inventory_icon = ATLAS_TEXTURE_FACTORY.load_texture(item_data.get("inventory_icon"))
	_expect(texture is AtlasTexture, "Black pants body texture must resolve to an AtlasTexture.")
	_expect(inventory_icon is AtlasTexture, "Black pants icon texture must resolve to an AtlasTexture.")
	_expect((texture as AtlasTexture).region == Rect2(Vector2(float(EXPECTED_PANTS_CELL.x) * ATLAS_CELL_SIZE.x, float(EXPECTED_PANTS_CELL.y) * ATLAS_CELL_SIZE.y), ATLAS_CELL_SIZE), "Black pants body must use atlas cell (7, 0).")
	_expect((inventory_icon as AtlasTexture).region == Rect2(Vector2(float(EXPECTED_ICON_CELL.x) * ATLAS_CELL_SIZE.x, float(EXPECTED_ICON_CELL.y) * ATLAS_CELL_SIZE.y), ATLAS_CELL_SIZE), "Black pants icon must use atlas cell (6, 0).")

	print("[basic-black-pants-atlas] success")
	item_database_node.free()
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("[basic-black-pants-atlas] " + message)
	quit(1)
