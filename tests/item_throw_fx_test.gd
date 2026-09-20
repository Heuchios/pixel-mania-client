extends SceneTree

const EFFECT := preload("res://Scenes/particles/BloodBattleaxeThrowFX.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_script: GDScript = load("res://Scripts/world.gd")
	assert(world_script.can_instantiate())
	var world = world_script.new()
	world.equipped_tool = "blood_battleaxe"
	assert(world.is_blood_battleaxe_source_tool("punch"))
	assert(not world.is_blood_battleaxe_source_tool("", false))
	assert(not world.is_blood_battleaxe_source_tool("fire_staff", false))
	assert(world.is_blood_battleaxe_source_tool("blood_battleaxe", false))
	world.item_database = {"blood_battleaxe": {"inventory_icon": "blood_battleaxe_icon", "category": "tool"}}
	var manager = load("res://Scripts/item_gameplay_manager.gd").new()
	manager.setup(world)
	world.item_gameplay_manager = manager
	assert(world.spawn_blood_battleaxe_throw_at(Vector2.ZERO, Vector2(120, 0)))
	assert(not world.spawn_blood_battleaxe_throw_at(Vector2(INF, 0), Vector2.ZERO))
	world.free()
	manager.free()
	for displacement in [Vector2(128, 0), Vector2(-128, 0), Vector2(0, -96), Vector2.ZERO]:
		var effect := EFFECT.instantiate()
		root.add_child(effect)
		effect.launch_to(Vector2(100, 100), Vector2(100, 100) + displacement, -1 if displacement.x < 0 else 1)
		effect.set_process(false)
		assert(effect.item_texture != null)
		assert(effect._flight_position(0.0).is_equal_approx(Vector2.ZERO))
		assert(effect._flight_position(effect._duration).is_equal_approx(displacement))
		effect._process(effect._duration * 0.5)
		assert(not effect.is_queued_for_deletion())
		effect._process(effect._duration * 0.5 + effect.FADE_TIME + 0.01)
		assert(effect.is_queued_for_deletion())
	await process_frame
	print("[item-throw-fx] PASS: both directions, vertical/zero range, endpoint and cleanup")
	quit(0)
