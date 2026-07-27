extends Node

var failures := 0
var player_manager_script: Script = null


func _ready() -> void:
	player_manager_script = _load_script("res://Scripts/player_manager.gd")
	_load_script("res://Scripts/world.gd")
	_load_script("res://Scripts/network_manager.gd")
	if player_manager_script != null:
		_test_action_sequence_ordering()
	_test_local_correction_is_presentation_only()
	if failures > 0:
		printerr("[movement-sync-load] failed assertions: ", failures)
		get_tree().quit(1)
		return
	print("[movement-sync-load] success")
	get_tree().quit(0)


func _load_script(path: String) -> Script:
	var resource := ResourceLoader.load(path)
	_expect(resource is Script, "%s should compile" % path)
	return resource as Script


func _test_action_sequence_ordering() -> void:
	var manager = player_manager_script.new()
	var base_event := {
		"attacker_player_id": "remote-a",
		"action_sequence": 10,
		"server_time": 1000
	}
	_expect(manager.accept_remote_action_event(base_event), "first action sequence should be accepted")
	_expect(not manager.accept_remote_action_event(base_event), "duplicate action sequence should be rejected")
	var stale_event := base_event.duplicate(true)
	stale_event["action_sequence"] = 9
	_expect(not manager.accept_remote_action_event(stale_event), "older action sequence should be rejected")
	var next_event := base_event.duplicate(true)
	next_event["action_sequence"] = 11
	_expect(manager.accept_remote_action_event(next_event), "newer action sequence should be accepted")
	var fallback_event := {
		"attacker_player_id": "remote-b",
		"server_time": 2000
	}
	_expect(manager.accept_remote_action_event(fallback_event), "first timestamped legacy action should be accepted")
	_expect(not manager.accept_remote_action_event(fallback_event), "duplicate timestamped legacy action should be rejected")
	var older_fallback_event := fallback_event.duplicate(true)
	older_fallback_event["server_time"] = 1999
	_expect(not manager.accept_remote_action_event(older_fallback_event), "older timestamped legacy action should be rejected")
	var newer_fallback_event := fallback_event.duplicate(true)
	newer_fallback_event["server_time"] = 2001
	_expect(manager.accept_remote_action_event(newer_fallback_event), "newer timestamped legacy action should be accepted")
	manager.free()


func _test_local_correction_is_presentation_only() -> void:
	var source := FileAccess.get_file_as_string("res://Scripts/world.gd")
	_expect(source.contains("player.global_position = target_position"), "authoritative correction should update the physics root immediately")
	_expect(not source.contains("tween_property(player, \"global_position\""), "authoritative correction must never tween the physics root")
	_expect(source.contains("tween_property(presentation_node, \"position\""), "small corrections should ease presentation children only")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("[movement-sync-load] ", message)
