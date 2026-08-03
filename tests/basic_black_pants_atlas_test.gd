extends SceneTree

const ATLAS_TEXTURE_FACTORY = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_DATABASE_SCRIPT_PATH := "res://Scripts/item_database.gd"
const ATLAS_CELL_SIZE := Vector2(32, 32)
const EXPECTED_ITEMS := {
	"basic_black_pants": {"icon_cell": Vector2i(6, 0), "pants_cell": Vector2i(7, 0)},
	"basic_light_gray_pants": {"icon_cell": Vector2i(6, 1), "pants_cell": Vector2i(7, 1)},
	"basic_navy_pants": {"icon_cell": Vector2i(6, 2), "pants_cell": Vector2i(7, 2)},
	"basic_brown_pants": {"icon_cell": Vector2i(6, 3), "pants_cell": Vector2i(7, 3)},
	"basic_green_pants": {"icon_cell": Vector2i(6, 4), "pants_cell": Vector2i(7, 4)},
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_database_script = load(ITEM_DATABASE_SCRIPT_PATH)
	assert(item_database_script is GDScript)
	var item_database_node = item_database_script.new()

	for item_id in EXPECTED_ITEMS:
		var expected: Dictionary = EXPECTED_ITEMS[item_id]
		var item_data: Dictionary = item_database_node.get_item_data(item_id)
		_expect(str(item_data.get("texture", "")) == item_id, "%s must reference the wearable atlas body frame." % item_id)
		_expect(str(item_data.get("inventory_icon", "")) == "%s_icon" % item_id, "%s must reference the wearable atlas icon frame." % item_id)

		var texture = ATLAS_TEXTURE_FACTORY.load_texture(item_data.get("texture"))
		var inventory_icon = ATLAS_TEXTURE_FACTORY.load_texture(item_data.get("inventory_icon"))
		_expect(texture is AtlasTexture, "%s body texture must resolve to an AtlasTexture." % item_id)
		_expect(inventory_icon is AtlasTexture, "%s icon texture must resolve to an AtlasTexture." % item_id)
		_expect((texture as AtlasTexture).region == _atlas_region(expected["pants_cell"]), "%s body must use atlas cell (%d, %d)." % [item_id, expected["pants_cell"].x, expected["pants_cell"].y])
		_expect((inventory_icon as AtlasTexture).region == _atlas_region(expected["icon_cell"]), "%s icon must use atlas cell (%d, %d)." % [item_id, expected["icon_cell"].x, expected["icon_cell"].y])

	print("[basic-pants-atlas] success")
	item_database_node.free()
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("[basic-pants-atlas] " + message)
	quit(1)


func _atlas_region(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(float(cell.x) * ATLAS_CELL_SIZE.x, float(cell.y) * ATLAS_CELL_SIZE.y), ATLAS_CELL_SIZE)
