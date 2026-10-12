extends "res://Scripts/drop_manager.gd"

var sent_batches: Array = []
var fail_send := false
var full_scan_count := 0

func should_use_server_authoritative_world_actions() -> bool:
	return true

func is_queued_drop_pickup_still_reachable(drop_data: Dictionary) -> bool:
	return bool(drop_data.get("reachable", true))

func get_server_pickups_in_flight() -> int:
	full_scan_count += 1
	return super.get_server_pickups_in_flight()

func send_network_drop_pickup(drop_data: Dictionary) -> bool:
	if fail_send:
		return false
	drop_data["pickup_request_sent"] = true
	sent_batches.append([drop_data.drop_id])
	return true

func send_network_drop_pickup_bulk(entries: Array) -> bool:
	if fail_send:
		return false
	var ids: Array = []
	for entry in entries:
		entry["pickup_in_progress"] = true
		entry["pickup_request_sent"] = true
		ids.append(entry.drop_id)
	sent_batches.append(ids)
	return true

func restore_drop_pickup_visual(_drop_data: Dictionary) -> void:
	pass

func record_drop_pickup_debug(_reason: String, _drop_data: Dictionary = {}, _position: Vector2 = Vector2.ZERO, _range: float = 0.0, _extra: Dictionary = {}) -> void:
	pass
