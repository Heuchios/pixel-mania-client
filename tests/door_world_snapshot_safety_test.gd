extends SceneTree

const Guard = preload("res://Scripts/world_snapshot_guard.gd")

class Fixture extends Node:
	const INVALID_GRID_POS := Vector2i(-9999, -9999)
	const ENTRANCE_GATE_TYPE := "entrance_gate"
	var current_world_name := "SOURCE"
	var in_world := true
	var applying_network_world_update := false
	var blocks := {Vector2i(1, 1): {"type": "red_block"}}
	var save_manager
	var world_state_sync_manager = RefCounted.new()
	var clears := 0
	func update_smooth_world_load_message(_text): pass
	func clear_remote_players(): pass
	func is_smooth_world_load_visible(): return true
	func apply_network_world_state(_data): pass

const SAVE_PROBE := """
extends "res://Scripts/save_manager.gd"
var fade_callback: Callable
var use_fade := true
func begin_local_door_exit_fade(callback: Callable) -> bool:
	fade_callback = callback
	return use_fade
func show_world_entry_loading_overlay(_target: String, _wait: bool, _message: String = "") -> void: pass
func save_world(): pass
func clear_world():
	world.blocks.clear()
	world.clears += 1
func notify_netfox_world_entry_started(_target: String, _reason: String = "world-entry-started") -> void: pass
func close_all_gameplay_popups(): pass
func set_gameplay_ui_visible(_active: bool): pass
func set_gameplay_world_active(_active: bool, _sync: bool = true): pass
func should_use_server_world_state() -> bool: return true

"""

const NETWORK_PROBE := """
extends "res://Scripts/network_manager.gd"
var fixture: Node
func get_world_node(): return fixture

"""

var failures := 0
func check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _init(): call_deferred("run")
func run():
	var live_network := root.get_node_or_null("NetworkManager")
	if live_network != null:
		root.remove_child(live_network)
		live_network.free()
	var fixture := Fixture.new()
	root.add_child(fixture)
	var save_script := GDScript.new()
	save_script.source_code = SAVE_PROBE
	check(save_script.reload() == OK, 'Save probe compiles')
	var saver = save_script.new()
	fixture.add_child(saver)
	saver.world = fixture
	fixture.save_manager = saver
	var network_script := GDScript.new()
	network_script.source_code = NETWORK_PROBE
	check(network_script.reload() == OK, 'Network probe compiles')
	var network = network_script.new()
	network.fixture = fixture
	for with_fade in [true, false]:
		saver.use_fade = with_fade
		fixture.current_world_name = "SOURCE"
		fixture.blocks = {Vector2i(1, 1): {"type": "red_block"}}
		saver.begin_server_door_world_entry_with_transition({"world": "START"}, "START")
		check(network.is_world_state_apply_in_progress(), "Snapshot dispatch must stop synchronously on door_enter_ok")
		check(not network._world_node_can_apply_server_world_state(fixture), "Queued snapshot cannot bypass the door transition")
		if with_fade:
			await process_frame
			check(network.is_world_state_apply_in_progress(), "Snapshot stays blocked during the exit fade")
			saver.fade_callback.call()
		# Real overlay waits yield multiple frames before clear_world(). A fast
		# destination snapshot must stay queued through every one of those yields.
		for _frame in range(12):
			if not network.is_world_state_apply_in_progress(): break
			await process_frame
		check(not network.is_world_state_apply_in_progress(), "Transition releases packet processing after clear")
		check(network._world_node_can_apply_server_world_state(fixture), "Destination snapshot becomes eligible after cleanup")
		check(fixture.current_world_name == "START" and fixture.blocks.is_empty(), "Clear happens before destination construction")
		var clear_count := fixture.clears
		fixture.blocks = {Vector2i(49, 63): {"type": "entrance_gate"}, Vector2i(42, 57): {"type": "wood_platform"}}
		for _frame in range(8): await process_frame
		check(fixture.blocks.size() == 2 and fixture.clears == clear_count, "No delayed clear may delete destination blocks")

	var items := {"entrance_gate": {"category": "block"}, "dirt": {"category": "block"}, "wood_platform": {"category": "block"}}
	var snapshot := {"foreground": {"49,63": {"block_type": "entrance_gate"}, "42,57": {"block_type": "wood_platform"}, "1,65": 1}, "background": {}}
	var valid := Guard.validate(snapshot, items, 100, 70, Callable())
	check(valid.ok, "Mixed legacy string and compact numeric tiles load together")
	check(Guard.matches_loaded(valid.foreground, {Vector2i(49,63): {"type":"entrance_gate"}, Vector2i(42,57): {"type":"wood_platform"}, Vector2i(1,65): {"type":"dirt"}}), "Complete applied snapshot matches")
	check(not Guard.matches_loaded(valid.foreground, fixture.blocks), "Losing even one loaded tile is detected")
	for bad in [
		{"foreground": {}, "background": {}},
		{"foreground": {"1,2": {"block_type":"dirt"}}, "background": {}},
		{"foreground": {"49,63": {"block_type":"entrance_gate"}, "1,2": 999999}, "background": {}},
		{"foreground": {"49,63": {"block_type":"entrance_gate"}, "100,2": 1}, "background": {}},
		{"foreground": {"49,63": {"block_type":"entrance_gate", "x":7}}, "background": {}},
		{"foreground": [{"x":49,"y":63,"block_type":"entrance_gate"}, {"x":49,"y":63,"block_type":"dirt"}], "background": {}},
		{"foreground": snapshot.foreground},
	]:
		check(not Guard.validate(bad, items, 100, 70, Callable()).ok, "Incomplete, unknown or conflicting world data must fail closed")

	var environment = load("res://Scripts/environment_manager.gd").new()
	environment.world = fixture
	# This used to synthesize a gate, dirt and grass over the player's roof.
	fixture.blocks = {Vector2i(49,50): {"type":"red_block"}}
	var untouched := fixture.blocks.duplicate(true)
	environment.ensure_entrance_gate()
	check(fixture.blocks == untouched, "An online missing entrance cannot modify terrain")
	fixture.blocks[Vector2i(49,63)] = {"type":"entrance_gate"}
	untouched = fixture.blocks.duplicate(true)
	environment.ensure_entrance_gate()
	check(fixture.blocks == untouched, "An online existing gate cannot overwrite its support or remove neighboring bedrock")
	environment.free()
	network.free()
	fixture.free()
	print("DOOR_WORLD_SNAPSHOT_SAFETY: ", failures, " failures")
	quit(1 if failures else 0)
