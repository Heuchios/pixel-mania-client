extends SceneTree


class PendingSaveManager:
	extends RefCounted

	var waiting_for_server_world_state := true
	var retry_count := 0
	var failure_count := 0

	func retry_server_world_entry(_reason: String) -> bool:
		retry_count += 1
		return true

	func handle_client_world_loading_failed(_reason: String, _message: String) -> bool:
		failure_count += 1
		return true


class PendingWorld:
	extends Node

	var applying_network_world_update := false
	var current_world_name := "START"
	var save_manager := PendingSaveManager.new()
	var in_world := true
	var blocks := {}
	var player = null
	var noclip_enabled := false


func _init() -> void:
	call_deferred("_run")


func _source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start_index: int = source.find(start_marker)
	assert(start_index >= 0, "Missing start marker: " + start_marker)
	var end_index: int = source.find(end_marker, start_index + start_marker.length())
	assert(end_index >= 0, "Missing end marker: " + end_marker)
	return source.substr(start_index, end_index - start_index)


func _run() -> void:
	var loading_script: Script = load("res://Scripts/world_loading_ui_manager.gd")
	assert(loading_script != null)
	var loading_manager: Node = loading_script.new()
	var pending_world := PendingWorld.new()
	pending_world.set_meta("world_entry_in_progress", true)
	pending_world.set_meta("world_bulk_load_in_progress", true)
	pending_world.set_meta("world_bulk_load_reason", "test_authoritative_pending")
	loading_manager.set("world", pending_world)
	loading_manager.set("waiting_for_server_state", false)
	loading_manager.set("loading_operation_id", 7)
	loading_manager.call("finish_smooth_world_load")
	assert(bool(loading_manager.get("waiting_for_server_state")), "Premature finish must resume server wait")
	assert(not bool(loading_manager.get("pending_finish_smooth_load")), "Premature finish must not start ready fade")
	assert(not bool(loading_manager.get("finish_wait_running")), "Premature finish must not enter ready loop")
	assert(str(loading_manager.call("_get_loading_stage_name")) != "waiting_for_client_ready")
	loading_manager.free()
	pending_world.free()

	var source: String = FileAccess.get_file_as_string("res://Scripts/world_loading_ui_manager.gd")
	assert(not source.is_empty(), "Could not read world loading manager")
	assert(source.contains("enum LoadingStage"))
	assert(source.contains("WORLD_LOADING_SERVER_RETRY_MAX_ATTEMPTS"))
	assert(source.contains("WORLD_READY_RETRY_MAX_ATTEMPTS"))
	assert(source.contains("var active_loading_world_name: String = \"\""))
	assert(source.contains("var loading_operation_id: int = 0"))
	assert(source.contains("var loading_stage"))

	var begin_section: String = _source_between(
		source,
		"func begin_smooth_world_load",
		"func update_title_for_world"
	)
	assert(begin_section.contains("same_active_operation"))
	assert(begin_section.contains("Reusing active loading operation"))
	assert(begin_section.contains("loading_operation_id += 1"))
	assert(begin_section.contains("last_world_ready_retry_msec = 0"))
	assert(begin_section.contains("world_ready_retry_attempt_count = 0"))

	var finish_load_section: String = _source_between(
		source,
		"func finish_smooth_world_load",
		"func _request_world_ready_snapshot_retry"
	)
	assert(finish_load_section.contains("_has_authoritative_world_entry_pending"))
	assert(finish_load_section.contains("client_world_finish_deferred_authoritative_pending"))
	assert(finish_load_section.contains("last_world_ready_retry_msec = 0"))
	assert(finish_load_section.contains("world_ready_retry_attempt_count = 0"))
	assert(source.contains("func _request_world_ready_snapshot_retry"))
	assert(source.contains("request_current_world_entry_snapshot_restart"))
	assert(source.contains("retry_server_world_entry"))
	assert(source.contains("func _fail_loading_operation"))
	assert(source.contains("client_world_loading_failed"))
	assert(source.contains("handle_client_world_loading_failed"))
	assert(not source.contains("hiding loading overlay anyway"))

	var finish_section: String = _source_between(
		source,
		"func _finish_smooth_world_load_when_ready",
		"func _fade_out_loading_overlay"
	)
	assert(finish_section.contains("operation_id != loading_operation_id"))
	assert(finish_section.contains("_finish_smooth_world_load_when_ready(operation_id)"))
	assert(finish_section.contains("keeping loading overlay visible"))
	assert(finish_section.contains("client_world_ready_timeout_retry"))
	assert(finish_section.contains("_request_world_ready_snapshot_retry(\"world_ready_timeout\")"))
	assert(finish_section.contains("WORLD_READY_RETRY_MAX_ATTEMPTS"))
	assert(finish_section.contains("_fail_loading_operation"))

	var fade_section: String = _source_between(
		source,
		"func _fade_out_loading_overlay",
		"func cancel_smooth_world_load"
	)
	assert(source.contains("const WORLD_LOADING_REVEAL_FADE_SECONDS := 0.34"))
	assert(fade_section.contains("set_trans(WORLD_LOADING_REVEAL_FADE_TRANS)"))
	assert(fade_section.contains("set_ease(WORLD_LOADING_REVEAL_FADE_EASE)"))
	assert(fade_section.contains("WORLD_LOADING_REVEAL_FADE_SECONDS"))
	assert(fade_section.contains("bind(operation_id)"))

	var cancel_section: String = _source_between(
		source,
		"func cancel_smooth_world_load",
		"func update_timeout"
	)
	assert(cancel_section.contains("loading_operation_id += 1"))
	assert(cancel_section.contains("last_world_ready_retry_msec = 0"))
	assert(cancel_section.contains("world_ready_retry_attempt_count = 0"))

	var timeout_section: String = _source_between(
		source,
		"func update_timeout",
		"func is_world_ready_for_player"
	)
	assert(timeout_section.contains("WORLD_LOADING_SERVER_RETRY_MAX_ATTEMPTS"))
	assert(timeout_section.contains("_fail_loading_operation"))

	var finalize_section: String = _source_between(
		source,
		"func _finalize_loading_operation",
		"func _hide_overlay_after_fade"
	)
	assert(finalize_section.contains("operation_id != loading_operation_id"))
	assert(finalize_section.contains("active_loading_world_name = \"\""))
	assert(finalize_section.contains("last_world_ready_retry_msec = 0"))
	assert(finalize_section.contains("world_ready_retry_attempt_count = 0"))

	print("[world-loading-operation] success")
	quit(0)
