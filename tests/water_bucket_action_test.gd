extends SceneTree

class WorldFixture extends Node:
	const INVALID_GRID_POS := Vector2i(-999, -999)
	var selected_item_type := "water_bucket"
	var selected_item_category := "material"
	var material_inventory := {"water_bucket": 2}
	var inventory := {"water_bucket": 50}
	var blocks := {}
	var allowed := true
	var notices: Array = []
	func is_grid_inside_world(_grid): return true
	func can_reach_grid(_grid): return true
	func can_current_player_place_block_at(_type, _grid): return allowed
	func can_current_player_break_block_at(_type, _grid): return allowed
	func can_current_player_build_at(_grid): return allowed
	func show_notification(message): notices.append(message)
	func get_world_locked_message(): return "Locked"

func _initialize(): call_deferred("run")
func run():
	create_timer(15).timeout.connect(func(): quit(1))
	var world := WorldFixture.new()
	var bucket = load("res://tests/fixtures/water_bucket_action_fixture.gd").new()
	bucket.world = world
	var grid := Vector2i(3, 4)
	assert(bucket.is_water_bucket_selected())
	assert(bucket.get_water_bucket_inventory_count() == 2, "Count material inventory, never stale block inventory")
	assert(bucket.try_use_water_bucket_at_grid(grid))
	assert(bucket.requests.size() == 1 and bucket.requests[0].action == "place")
	assert(bucket.requests[0].extra.water_bucket_action == "pour")
	assert(world.material_inventory.water_bucket == 2 and world.blocks.is_empty(), "Wait for server commit")
	world.blocks[grid] = {"type": "water"}
	assert(bucket.try_use_water_bucket_at_grid(grid))
	assert(bucket.requests.size() == 2 and bucket.requests[1].action == "break")
	assert(bucket.requests[1].extra.water_bucket_action == "scoop")
	assert(world.material_inventory.water_bucket == 2 and world.blocks.has(grid))
	world.allowed = false
	bucket.try_use_water_bucket_at_grid(grid)
	bucket.try_use_water_bucket_at_grid(Vector2i(4, 4))
	assert(bucket.requests.size() == 2, "Area permissions apply to scoop and pour")
	world.allowed = true
	world.material_inventory.water_bucket = 0
	bucket.try_use_water_bucket_at_grid(grid)
	assert(bucket.requests.size() == 2, "Stale block-category buckets cannot authorize a scoop")
	bucket.free()
	world.free()
	print("WATER_BUCKET_ACTION_PASS")
	quit()
