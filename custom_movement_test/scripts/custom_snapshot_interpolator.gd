extends RefCounted
class_name CustomSnapshotInterpolator

const Protocol = preload("res://custom_movement_test/scripts/custom_movement_protocol.gd")

var buffers: Dictionary = {}
var server_time_offsets: Dictionary = {}
var remote_debug: Dictionary = {}
var interpolation_delay_ms := Protocol.INTERPOLATION_DELAY_MS

var total_received_snapshots := 0
var received_snapshots_this_second := 0
var received_snapshots_per_second := 0.0
var dropped_snapshots := 0
var interval_sum_msec := 0.0
var interval_count := 0
var last_stats_msec := 0
var last_snapshot_received_msec: Dictionary = {}


func clear() -> void:
	buffers.clear()
	server_time_offsets.clear()
	remote_debug.clear()
	last_snapshot_received_msec.clear()
	total_received_snapshots = 0
	received_snapshots_this_second = 0
	received_snapshots_per_second = 0.0
	dropped_snapshots = 0
	interval_sum_msec = 0.0
	interval_count = 0
	last_stats_msec = 0


func clear_peer(peer_id: int) -> void:
	var clean_peer_id := int(peer_id)
	buffers.erase(clean_peer_id)
	server_time_offsets.erase(clean_peer_id)
	remote_debug.erase(clean_peer_id)
	last_snapshot_received_msec.erase(clean_peer_id)


func set_interpolation_delay_ms(value: int) -> void:
	interpolation_delay_ms = clampi(int(value), 0, 250)


func get_interpolation_delay_ms() -> int:
	return interpolation_delay_ms


func add_snapshot(snapshot: Dictionary) -> void:
	var peer_id := int(snapshot.get("peer_id", 0))
	if peer_id <= 0:
		return

	var now_msec := Time.get_ticks_msec()
	_update_receive_stats(now_msec, peer_id)

	var entry := snapshot.duplicate(true)
	entry["received_msec"] = now_msec
	entry["server_time_msec"] = Protocol.snapshot_server_time_msec(snapshot)

	var buffer: Array = buffers.get(peer_id, [])
	if not buffer.is_empty():
		var latest: Dictionary = buffer[buffer.size() - 1]
		var latest_server_time := int(latest.get("server_time_msec", 0))
		if int(entry.get("server_time_msec", 0)) <= latest_server_time:
			dropped_snapshots += 1
			return

		var latest_position := Protocol.snapshot_position(latest)
		var new_position := Protocol.snapshot_position(entry)
		if latest_position.distance_to(new_position) > Protocol.REMOTE_SNAP_DISTANCE_PIXELS:
			dropped_snapshots += buffer.size()
			buffer.clear()
			entry["teleport_snap"] = true

	buffer.append(entry)
	while buffer.size() > Protocol.MAX_SNAPSHOT_BUFFER:
		buffer.pop_front()
		dropped_snapshots += 1
	buffers[peer_id] = buffer

	var offset := float(now_msec - int(entry.get("server_time_msec", 0)))
	var previous_offset := float(server_time_offsets.get(peer_id, offset))
	server_time_offsets[peer_id] = lerpf(previous_offset, offset, 0.12)


func get_buffer_size(peer_id: int) -> int:
	var buffer: Array = buffers.get(int(peer_id), [])
	return buffer.size()


func get_total_buffer_size() -> int:
	var total := 0
	for peer_id in buffers.keys():
		var buffer: Array = buffers.get(peer_id, [])
		total += buffer.size()
	return total


func get_debug(peer_id: int) -> Dictionary:
	return remote_debug.get(int(peer_id), _empty_debug())


func get_all_debug() -> Dictionary:
	return remote_debug.duplicate(true)


func get_stats() -> Dictionary:
	var average_interval := 0.0
	if interval_count > 0:
		average_interval = interval_sum_msec / float(interval_count)

	return {
		"snapshot_rate": Protocol.SNAPSHOT_RATE,
		"received_snapshots_per_second": received_snapshots_per_second,
		"dropped_snapshots": dropped_snapshots,
		"average_snapshot_interval_ms": average_interval,
		"total_received_snapshots": total_received_snapshots,
	}


func get_render_state(peer_id: int) -> Dictionary:
	var clean_peer_id := int(peer_id)
	var buffer: Array = buffers.get(clean_peer_id, [])
	if buffer.is_empty():
		remote_debug[clean_peer_id] = _empty_debug()
		return {}

	var render_time_msec := _current_server_time_msec(clean_peer_id) - interpolation_delay_ms
	while buffer.size() > 2 and int(buffer[1].get("server_time_msec", 0)) <= render_time_msec:
		buffer.pop_front()
	buffers[clean_peer_id] = buffer

	var state: Dictionary = {}
	if buffer.size() == 1:
		state = _dead_reckon(buffer[0], render_time_msec)
	elif render_time_msec <= int(buffer[0].get("server_time_msec", 0)):
		state = _state_from_snapshot(buffer[0])
		state["previous_snapshot_tick"] = int(buffer[0].get("server_tick", 0))
		state["next_snapshot_tick"] = int(buffer[min(1, buffer.size() - 1)].get("server_tick", 0))
		state["interpolation_alpha"] = 0.0
	else:
		for i in range(buffer.size() - 1):
			var left: Dictionary = buffer[i]
			var right: Dictionary = buffer[i + 1]
			var left_time := int(left.get("server_time_msec", 0))
			var right_time := int(right.get("server_time_msec", 0))
			if left_time <= render_time_msec and render_time_msec <= right_time:
				var span: int = max(1, right_time - left_time)
				var alpha: float = clamp(float(render_time_msec - left_time) / float(span), 0.0, 1.0)
				state = _interpolate(left, right, alpha)
				break

		if state.is_empty():
			state = _dead_reckon(buffer[buffer.size() - 1], render_time_msec)

	_add_debug_fields(clean_peer_id, state, buffer, render_time_msec)
	remote_debug[clean_peer_id] = state.duplicate(true)
	return state


func _interpolate(left: Dictionary, right: Dictionary, alpha: float) -> Dictionary:
	var left_position := Protocol.snapshot_position(left)
	var right_position := Protocol.snapshot_position(right)
	var left_velocity := Protocol.snapshot_velocity(left)
	var right_velocity := Protocol.snapshot_velocity(right)
	var left_time := int(left.get("server_time_msec", 0))
	var right_time := int(right.get("server_time_msec", left_time))
	var segment_seconds: float = maxf(0.001, float(right_time - left_time) / 1000.0)
	var position: Vector2 = _hermite_position(left_position, left_velocity, right_position, right_velocity, alpha, segment_seconds)
	var linear_position: Vector2 = left_position.lerp(right_position, alpha)
	var segment_distance: float = left_position.distance_to(right_position)
	if position.distance_to(linear_position) > maxf(10.0, segment_distance * 0.35):
		position = linear_position
	var facing := int(right.get("facing_dir", left.get("facing_dir", 1)))
	var movement_state := str(right.get("movement_state", left.get("movement_state", "idle")))
	return {
		"position": position,
		"velocity": left_velocity.lerp(right_velocity, alpha),
		"facing_dir": facing,
		"movement_state": movement_state,
		"previous_snapshot_tick": int(left.get("server_tick", 0)),
		"next_snapshot_tick": int(right.get("server_tick", 0)),
		"interpolation_alpha": alpha,
		"dead_reckoning": false,
		"teleport_snap": false,
	}


func _hermite_position(left_position: Vector2, left_velocity: Vector2, right_position: Vector2, right_velocity: Vector2, alpha: float, segment_seconds: float) -> Vector2:
	var t: float = clampf(alpha, 0.0, 1.0)
	var t2 := t * t
	var t3 := t2 * t
	var h00 := (2.0 * t3) - (3.0 * t2) + 1.0
	var h10 := t3 - (2.0 * t2) + t
	var h01 := (-2.0 * t3) + (3.0 * t2)
	var h11 := t3 - t2
	return (
		(left_position * h00)
		+ (left_velocity * segment_seconds * h10)
		+ (right_position * h01)
		+ (right_velocity * segment_seconds * h11)
	)


func _dead_reckon(snapshot: Dictionary, render_time_msec: int) -> Dictionary:
	var snapshot_time := int(snapshot.get("server_time_msec", render_time_msec))
	var dt: float = clamp(float(render_time_msec - snapshot_time) / 1000.0, 0.0, Protocol.DEAD_RECKON_MAX_SECONDS)
	var position := Protocol.snapshot_position(snapshot)
	var velocity := Protocol.snapshot_velocity(snapshot)
	var state := _state_from_snapshot(snapshot)
	state["position"] = position + (velocity * dt)
	state["velocity"] = velocity
	state["previous_snapshot_tick"] = int(snapshot.get("server_tick", 0))
	state["next_snapshot_tick"] = -1
	state["interpolation_alpha"] = 1.0
	state["dead_reckoning"] = dt > 0.0
	state["dead_reckon_seconds"] = dt
	state["teleport_snap"] = bool(snapshot.get("teleport_snap", false))
	return state


func _state_from_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"position": Protocol.snapshot_position(snapshot),
		"velocity": Protocol.snapshot_velocity(snapshot),
		"facing_dir": int(snapshot.get("facing_dir", 1)),
		"movement_state": str(snapshot.get("movement_state", "idle")),
		"previous_snapshot_tick": int(snapshot.get("server_tick", 0)),
		"next_snapshot_tick": int(snapshot.get("server_tick", 0)),
		"interpolation_alpha": 0.0,
		"dead_reckoning": false,
		"teleport_snap": bool(snapshot.get("teleport_snap", false)),
	}


func _add_debug_fields(peer_id: int, state: Dictionary, buffer: Array, render_time_msec: int) -> void:
	var latest: Dictionary = buffer[buffer.size() - 1]
	var rendered_position: Vector2 = state.get("position", Protocol.snapshot_position(latest))
	state["buffer_size"] = buffer.size()
	state["interpolation_delay_ms"] = interpolation_delay_ms
	state["render_time_msec"] = render_time_msec
	state["latest_snapshot_tick"] = int(latest.get("server_tick", 0))
	state["latest_snapshot_distance"] = Protocol.snapshot_position(latest).distance_to(rendered_position)
	state["peer_id"] = peer_id


func _current_server_time_msec(peer_id: int) -> int:
	var offset := float(server_time_offsets.get(peer_id, 0.0))
	if offset == 0.0:
		var buffer: Array = buffers.get(peer_id, [])
		if not buffer.is_empty():
			var latest: Dictionary = buffer[buffer.size() - 1]
			return int(latest.get("server_time_msec", 0))
	return int(round(float(Time.get_ticks_msec()) - offset))


func _update_receive_stats(now_msec: int, peer_id: int) -> void:
	total_received_snapshots += 1
	received_snapshots_this_second += 1

	if last_stats_msec <= 0:
		last_stats_msec = now_msec
	elif now_msec - last_stats_msec >= 1000:
		var elapsed_seconds := float(now_msec - last_stats_msec) / 1000.0
		received_snapshots_per_second = float(received_snapshots_this_second) / max(0.001, elapsed_seconds)
		received_snapshots_this_second = 0
		last_stats_msec = now_msec

	if last_snapshot_received_msec.has(peer_id):
		var previous_msec: int = int(last_snapshot_received_msec.get(peer_id, now_msec))
		var interval: int = max(0, now_msec - previous_msec)
		interval_sum_msec += float(interval)
		interval_count += 1
	last_snapshot_received_msec[peer_id] = now_msec


func _empty_debug() -> Dictionary:
	return {
		"buffer_size": 0,
		"interpolation_delay_ms": interpolation_delay_ms,
		"render_time_msec": 0,
		"previous_snapshot_tick": -1,
		"next_snapshot_tick": -1,
		"interpolation_alpha": 0.0,
		"dead_reckoning": false,
		"latest_snapshot_distance": 0.0,
	}
