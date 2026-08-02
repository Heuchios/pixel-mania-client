extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start_index: int = source.find(start_marker)
	assert(start_index >= 0, "Missing start marker: " + start_marker)
	var end_index: int = source.find(end_marker, start_index + start_marker.length())
	assert(end_index >= 0, "Missing end marker: " + end_marker)
	return source.substr(start_index, end_index - start_index)


func _run() -> void:
	var source: String = FileAccess.get_file_as_string("res://Scripts/world_loading_ui_manager.gd")
	assert(not source.is_empty(), "Could not read world loading manager")
	assert(source.contains("var active_loading_world_name: String = \"\""))
	assert(source.contains("var loading_operation_id: int = 0"))

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
	assert(finish_load_section.contains("last_world_ready_retry_msec = 0"))
	assert(finish_load_section.contains("world_ready_retry_attempt_count = 0"))
	assert(source.contains("func _request_world_ready_snapshot_retry"))
	assert(source.contains("request_current_world_entry_snapshot_restart"))
	assert(source.contains("retry_server_world_entry"))
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

	var fade_section: String = _source_between(
		source,
		"func _fade_out_loading_overlay",
		"func cancel_smooth_world_load"
	)
	assert(fade_section.contains("bind(operation_id)"))

	var cancel_section: String = _source_between(
		source,
		"func cancel_smooth_world_load",
		"func update_timeout"
	)
	assert(cancel_section.contains("loading_operation_id += 1"))
	assert(cancel_section.contains("last_world_ready_retry_msec = 0"))
	assert(cancel_section.contains("world_ready_retry_attempt_count = 0"))

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
