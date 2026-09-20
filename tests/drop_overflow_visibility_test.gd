extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var fixture = load("res://tests/fixtures/drop_overflow_fixture.gd").new()
	var test_world := Node.new()
	fixture.world = test_world
	fixture.applying_server_drop_payload = true
	for total in [1900.0, 2000.0, 2400.0]:
		fixture.existing_total = total
		fixture.spawned.clear()
		fixture.create_item_drop("dirt", Vector2(160, 192), false, "block", 0.0, 400.0, "server_overflow", false)
		assert(fixture.spawned.size() == 1)
		assert(fixture.spawned[0].amount == 400.0)
		assert(fixture.spawned[0].id == "server_overflow")
		assert(not fixture.spawned[0].sync)
	fixture.spawned.clear()
	fixture.applying_server_drop_payload = false
	fixture.create_item_drop("dirt", Vector2.ZERO, false, "block", 0.0, 400.0, "fake", false)
	assert(fixture.spawned.is_empty(), "Untrusted local drops must still be rejected")
	fixture.free()
	test_world.free()
	print("DROP_OVERFLOW_VISIBILITY_PASS")
	quit()
