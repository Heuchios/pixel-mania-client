extends SceneTree

class FakeWorld extends Node:
	var blocks := {}
	var item_database := {}
	var near := true
	var block_hit_progress := {}
	var block_hit_timers := {}
	func can_reach_grid(_grid: Vector2i) -> bool:
		return near
	func can_current_player_break_block_at(_type: String, _grid: Vector2i) -> bool:
		return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := FakeWorld.new()
	var fixture = load("res://tests/fixtures/lock_decay_block_fixture.gd")
	var blocks = fixture.new()
	blocks.world = world
	var grid := Vector2i(1, 2)
	for lock_type in ["small_lock", "medium_lock", "big_lock", "world_lock", "super_world_lock"]:
		world.blocks[grid] = {"type": lock_type}
		blocks.hit_block_grid(grid, true)
		if blocks.sent_hits.is_empty() or blocks.sent_hits.back().block_type != lock_type:
			printerr("Protected lock punch did not reach the server: ", lock_type)
			quit(1)
			return
		if not world.blocks.has(grid) or not world.block_hit_progress.is_empty():
			printerr("Lock was changed locally before server authorization")
			quit(1)
			return
	world.near = false
	blocks.hit_block_grid(grid, true)
	world.near = true
	blocks.allowed_cadence = false
	blocks.hit_block_grid(grid, true)
	if blocks.sent_hits.size() != 5:
		printerr("Distance or cadence check was bypassed")
		quit(1)
		return
	for hit in blocks.sent_hits:
		if hit.action != "hit" or hit.extra.has("lock_decay"):
			quit(1)
			return
	blocks.free()
	world.free()
	print("[lock-decay-punch] All five lock types ask the server; no local removal, bypass, or decay flag")
	quit(0)
