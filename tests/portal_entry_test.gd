extends SceneTree

class Fixture extends Node:
	var blocks := {
		Vector2i(2, 4): {"type": "portal"},
		Vector2i(3, 4): {"type": "portal"},
	}
	var item_database := {"portal": {"door_block": true, "portal_block": true}}

class Interaction extends "res://Scripts/interaction_manager.gd":
	var entries: Array[Vector2i] = []
	func try_enter_door_at(grid_pos: Vector2i, _force: bool = false, _password: String = "") -> bool:
		entries.append(grid_pos)
		return true

func _initialize():
	call_deferred("run")

func run():
	var world := Fixture.new()
	root.add_child(world)
	var interaction := Interaction.new()
	world.add_child(interaction)
	interaction.setup(world)
	var arrival := Vector2i(2, 4)
	var next_portal := Vector2i(3, 4)
	interaction.set_door_enter_cooldown()
	interaction.mark_door_arrival(arrival)
	for _frame in range(10):
		interaction.update_auto_door_entry(arrival)
	assert(interaction.entries.is_empty(), "Do not bounce back through the arrival portal")
	interaction.update_auto_door_entry(next_portal)
	assert(interaction.entries == [next_portal], "An adjacent portal must work immediately after arrival")
	interaction.mark_door_arrival(arrival)
	interaction.update_auto_door_entry(Vector2i(1, 4))
	interaction.update_auto_door_entry(arrival)
	assert(interaction.entries == [next_portal, arrival], "Stepping out must rearm the arrival portal")
	interaction.set_door_enter_cooldown()
	interaction.update_auto_door_entry(next_portal)
	assert(interaction.entries.size() == 2)
	interaction.door_enter_cooldown_until_msec = 0
	interaction.update_auto_door_entry(next_portal)
	assert(interaction.entries.size() == 3, "An in-flight request must not consume a new portal's entry")
	world.free()
	var travel = load("res://tests/portal_world_fixture.gd").new()
	root.add_child(travel)
	travel.current_world_name = "TEST"
	travel.player = load("res://tests/portal_player_fixture.gd").new()
	travel.add_child(travel.player)
	travel.player.global_position = Vector2(480, 128)
	travel.player.velocity = Vector2(200, 0)
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	visual.set_meta("server_correction_base_position", Vector2.ZERO)
	visual.position = Vector2(120, 0)
	travel.player.add_child(visual)
	travel.server_position_correction_tween = travel.create_tween()
	travel.server_position_correction_tween.tween_property(visual, "position", Vector2(200, 0), 1.0)
	travel.interaction_manager = Interaction.new()
	travel.add_child(travel.interaction_manager)
	travel.interaction_manager.setup(travel)
	Input.action_press("move_right")
	travel.apply_server_door_spawn({"world":"TEST", "x":64, "y":128})
	assert(travel.player.global_position == Vector2(64, 128), "Land at the exact linked portal")
	assert(travel.flushed_position == Vector2(64, 128), "Immediately acknowledge the destination")
	assert(travel.player.velocity == Vector2.ZERO)
	assert(visual.position == Vector2.ZERO, "Clear stale correction offsets on the visible player")
	assert(travel.server_position_correction_tween == null)
	assert(travel.interaction_manager.last_auto_door_grid == Vector2i(2, 4))
	assert(travel.interaction_manager.door_enter_cooldown_until_msec == 0)
	for _frame in range(60):
		var direction: float = travel.player.get_horizontal_input_direction()
		travel.player.apply_horizontal_movement(direction, 1.0 / 60.0)
		travel.player.global_position.x += travel.player.velocity.x / 60.0
	assert(travel.player.global_position.x == 64.0, "Held entry input must not move the landing off its tile during the fade")
	Input.action_release("move_right")
	assert(travel.player.get_horizontal_input_direction() == 0.0)
	Input.action_press("move_right")
	assert(travel.player.get_horizontal_input_direction() == 1.0, "A fresh press must move immediately")
	Input.action_release("move_right")
	Input.action_press("move_left")
	travel.apply_server_door_spawn({"world":"TEST", "x":768, "y":128})
	assert(travel.player.get_horizontal_input_direction() == 0.0, "Leftward entry must also stop")
	Input.action_release("move_left")
	Input.action_press("move_right")
	assert(travel.player.get_horizontal_input_direction() == 1.0, "Changing direction must not wait for a cooldown")
	Input.action_release("move_right")
	travel.free()
	print("PORTAL_ENTRY_OK: no arrival bounce, immediate chaining, exit/reentry, pending retry")
	quit()
