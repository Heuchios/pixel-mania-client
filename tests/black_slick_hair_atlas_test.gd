extends SceneTree

const ATLAS_TEXTURE_FACTORY = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_DATABASE_SCRIPT_PATH := "res://Scripts/item_database.gd"
const ATLAS_CELL_SIZE := Vector2(32, 32)
const EXPECTED_ICON_CELL := Vector2i(12, 1)
const EXPECTED_HAIR_CELL := Vector2i(13, 1)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_database_script = load(ITEM_DATABASE_SCRIPT_PATH)
	assert(item_database_script is GDScript)
	var item_database_node = item_database_script.new()

	var item_data: Dictionary = item_database_node.get_item_data("black_slick_hair")
	_expect(str(item_data.get("texture", "")) == "black_slick_hair", "Black slick hair must reference the wearable atlas hair frame.")
	_expect(str(item_data.get("inventory_icon", "")) == "black_slick_hair_icon", "Black slick hair must reference the wearable atlas icon frame.")

	var texture = ATLAS_TEXTURE_FACTORY.load_texture(item_data.get("texture"))
	var inventory_icon = ATLAS_TEXTURE_FACTORY.load_texture(item_data.get("inventory_icon"))
	_expect(texture is AtlasTexture, "Black slick hair texture must resolve to an AtlasTexture.")
	_expect(inventory_icon is AtlasTexture, "Black slick hair icon texture must resolve to an AtlasTexture.")
	_expect((texture as AtlasTexture).region == _atlas_region(EXPECTED_HAIR_CELL), "Black slick hair must use atlas cell (13, 1).")
	_expect((inventory_icon as AtlasTexture).region == _atlas_region(EXPECTED_ICON_CELL), "Black slick hair icon must use atlas cell (12, 1).")

	print("[black-slick-hair-atlas] success")
	item_database_node.free()
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("[black-slick-hair-atlas] " + message)
	quit(1)


func _atlas_region(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(float(cell.x) * ATLAS_CELL_SIZE.x, float(cell.y) * ATLAS_CELL_SIZE.y), ATLAS_CELL_SIZE)
