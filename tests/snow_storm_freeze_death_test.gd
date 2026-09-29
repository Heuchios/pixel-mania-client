extends SceneTree

class RespawnFixture extends "res://Scripts/player_manager.gd":
	var states: Array[String] = []
	func apply_respawn_animation_state(state: String) -> void:
		states.append(state)
	func refresh_local_respawn_animation_visuals(_state: String) -> void:
		pass
	func get_current_respawn_spawn_position() -> Vector2:
		return Vector2(96, 64)
	func flush_respawn_position_to_server() -> bool:
		return true

class TestWorld extends Node2D:
	var player: CharacterBody2D
	var player_health := 10
	var lava_damage_timer := 0.0
	var player_manager
	var damage_calls := 0
	func damage_player(amount: int) -> void:
		damage_calls += 1
		player_manager.damage_player(amount)
	func respawn_player() -> void:
		player_manager.respawn_player()
	func update_all_ui() -> void:
		pass
	func get_player_camera():
		return null


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world.player = CharacterBody2D.new()
	world.player.position = Vector2(320, 640)
	world.add_child(world.player)
	var manager := RespawnFixture.new()
	world.add_child(manager)
	manager.world = world
	manager.MovementMode = root.get_node("MovementMode")
	world.player_manager = manager
	var sync = load("res://tests/fixtures/snow_freeze_sync_fixture.gd").new()
	sync.world = world
	var update := {"world": "SNOW", "kill_reason": "snow_storm_freeze", "kill_event_id": "storm-1", "kill_player_ids": ["another-player"]}
	sync._apply_block_update_instant_death_if_targeted(update)
	assert(world.damage_calls == 0, "Another player's freeze must not kill us")
	update.kill_player_ids = ["local-player"]
	sync._apply_block_update_instant_death_if_targeted(update)
	assert(world.player_health == 0 and manager.respawn_sequence_running)
	assert(not world.player.is_physics_processing(), "Frozen player must stop moving during death")
	assert(manager.states == ["dead"])
	await create_timer(4.3).timeout
	assert(manager.states == ["dead", "dead_spirit"])
	assert(world.player_health == 10 and not manager.respawn_sequence_running)
	assert(world.player.global_position == Vector2(96, 64), "Death must complete at the spawn point")
	assert(world.player.is_physics_processing())
	sync._apply_block_update_instant_death_if_targeted(update)
	assert(world.damage_calls == 1 and world.player_health == 10, "Repeated event delivery must not kill again after respawn")
	update.kill_event_id = "storm-2"
	update.kill_player_ids = []
	update.kill_usernames = ["local"]
	assert(sync._block_update_targets_local_player_for_instant_death(update), "Account fallback must identify the target")
	sync.free()
	world.free()
	print("[snow-freeze-death] PASS: targeted death, death/spirit sequence, respawn, duplicate protection, account fallback")
	quit()
