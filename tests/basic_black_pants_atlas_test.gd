extends SceneTree

const ATLAS_TEXTURE_FACTORY = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_DATABASE_SCRIPT_PATH := "res://Scripts/item_database.gd"
const ATLAS_CELL_SIZE := Vector2(32, 32)
const EQUIPMENT = preload("res://Scripts/equipment_manager.gd")
var failed := false

class WorldFixture extends Node:
	var item_database: Dictionary = {}
	var pants_textures: Dictionary = {}

const EXPECTED_ITEMS := {
	"basic_black_pants": {"icon_cell": Vector2i(7, 0), "pants_cell": Vector2i(8, 0)},
	"basic_light_gray_pants": {"icon_cell": Vector2i(7, 1), "pants_cell": Vector2i(8, 1)},
	"basic_navy_pants": {"icon_cell": Vector2i(7, 2), "pants_cell": Vector2i(8, 2)},
	"basic_brown_pants": {"icon_cell": Vector2i(7, 3), "pants_cell": Vector2i(8, 3)},
	"basic_green_pants": {"icon_cell": Vector2i(7, 4), "pants_cell": Vector2i(8, 4)},
	"basic_pink_pants": {"icon_cell": Vector2i(7, 5), "pants_cell": Vector2i(8, 5)},
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

	var shorts: Dictionary = item_database_node.get_item_data("basic_black_pants")
	_expect(shorts.display_name == "Black Shorts", "The existing item must be renamed Black Shorts.")
	for side in ["left", "right"]:
		var leg = ATLAS_TEXTURE_FACTORY.load_texture(shorts["%s_pants_texture" % side])
		_expect(leg is AtlasTexture, "Each leg must resolve to an atlas frame.")
		_expect(leg.region == _atlas_region(Vector2i(9 if side == "left" else 10, 0)), "Leg atlas cell mismatch.")
	_test_equipped_parts(item_database_node)
	if failed:
		item_database_node.free()
		quit(1)
		return
	print("[basic-pants-atlas] success: atlas cells, three-piece attachment, facing, movement and unequip")
	item_database_node.free()
	quit(0)


func _test_equipped_parts(database: Node) -> void:
	var scene = load("res://Scenes/main.tscn").instantiate()
	var actor := Node2D.new()
	var visual = scene.get_node("Player/PlayerVisual").duplicate()
	_strip_scripts(visual)
	actor.add_child(visual)
	root.add_child(actor)
	var world := WorldFixture.new()
	for item_id in ["basic_black_pants", "basic_navy_pants"]:
		world.item_database[item_id] = database.get_item_data(item_id)
	# Exercise the legacy split layout with available textures; Void Pants' old
	# separate-leg source files are absent from this checkout.
	var legacy: Dictionary = database.get_item_data("basic_black_pants").duplicate(true)
	for key in ["pants_follow_feet", "left_pants_offset", "right_pants_offset"]:
		legacy.erase(key)
	world.item_database["legacy_split_pants"] = legacy
	var manager = EQUIPMENT.new()
	manager.player = actor
	manager.world = world
	manager.setup_wearable_animated_parts()
	var original_middle_position: Vector2 = manager.get_wearable_part("pants").position
	var original_middle_z: int = manager.get_wearable_part("pants").z_index
	for facing in [1, -1]:
		visual.scale.x = facing
		manager.update_equipped_pants_visual("basic_black_pants", facing)
		_expect(manager.get_wearable_part("pants").z_index > visual.get_node("Bottom/BaseBottomAnimated").z_index, "Shorts must render above the base underwear.")
		for key in ["pants", "pants_left_item", "pants_right_item"]:
			var part = manager.get_wearable_part(key)
			_expect(part.visible and part.position == original_middle_position, "All three pieces must use the same canvas origin.")
		for side in ["left", "right"]:
			var part = manager.get_wearable_part("pants_%s_item" % side)
			var foot = visual.get_node("%sFoot" % side.capitalize())
			_expect(part.get_parent() == foot, "Each shorts leg must follow its animated foot.")
			foot.position = Vector2(3, -2)
			foot.rotation = 0.15
			_expect(part.global_position.is_equal_approx(foot.to_global(original_middle_position)) and is_equal_approx(part.global_rotation, foot.global_rotation), "The leg must inherit foot movement and facing.")
			foot.position = Vector2.ZERO
			foot.rotation = 0.0
	manager.update_equipped_pants_visual("basic_navy_pants", 1)
	_expect(manager.get_wearable_part("pants").z_index == original_middle_z, "Legacy pants keep their editor draw order.")
	_expect(manager.get_wearable_part("pants").position == original_middle_position, "Legacy pants alignment must be restored.")
	for key in ["pants_left_item", "pants_right_item"]:
		_expect(not manager.get_wearable_part(key).visible, "Switching to legacy pants must hide both shorts legs.")
		_expect(manager.get_wearable_part(key).get_parent() == visual.get_node("Bottom"), "Legacy split pants retain their attachment.")
	manager.update_equipped_pants_visual("legacy_split_pants", 1)
	_expect(manager.get_wearable_part("pants_left_item").position == manager.DEFAULT_LEFT_PANTS_OFFSET, "Existing split pants keep their offsets.")
	manager.update_equipped_pants_visual("basic_black_pants", 1)
	manager.update_equipped_pants_visual("", 1)
	for key in ["pants", "pants_left_item", "pants_right_item"]:
		_expect(not manager.get_wearable_part(key).visible, "Unequip must hide all three shorts pieces.")
	manager.free()
	world.free()
	actor.free()
	scene.free()


func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("[basic-pants-atlas] " + message)
	failed = true


func _atlas_region(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(float(cell.x) * ATLAS_CELL_SIZE.x, float(cell.y) * ATLAS_CELL_SIZE.y), ATLAS_CELL_SIZE)
