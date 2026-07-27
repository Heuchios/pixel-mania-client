extends SceneTree

const SNAPSHOT_BUFFER = preload("res://Scripts/networking/websocket_snapshot_buffer.gd")

var failures := 0


func _initialize() -> void:
	_test_fixed_latency_does_not_change_buffer_delay()
	_test_jitter_loss_duplicates_and_reordering()
	_test_direction_changes_and_jump_arc()
	_test_extrapolation_stops()
	_test_teleport_reset()
	_test_many_player_cost_is_bounded()
	if failures > 0:
		printerr("[websocket-snapshot-buffer] failed assertions: ", failures)
		quit(1)
		return
	print("[websocket-snapshot-buffer] success")
	quit(0)


func _test_fixed_latency_does_not_change_buffer_delay() -> void:
	var measured_delays: Array[float] = []
	for latency_ms in [0, 50, 100, 200]:
		var result := _simulate_route(latency_ms, false, 60.0)
		measured_delays.append(float(result.get("delay_ms", 0.0)))
		print("[websocket-snapshot-buffer] fixed latency=%dms fps=60 delay=%.2fms max_step=%.3fpx" % [latency_ms, float(result.get("delay_ms", 0.0)), float(result.get("max_step", 0.0))])
		_expect(float(result.get("max_step", 999.0)) < 5.0, "fixed-latency movement should remain smooth at " + str(latency_ms) + "ms")
		_expect(bool(result.get("monotonic", false)), "fixed-latency movement should not move backward")
	_expect(absf(measured_delays[0] - measured_delays[3]) < 1.0, "fixed latency must not inflate the jitter buffer")


func _test_jitter_loss_duplicates_and_reordering() -> void:
	var result_60 := _simulate_route(100, true, 60.0)
	var result_30 := _simulate_route(100, true, 30.0)
	print("[websocket-snapshot-buffer] jitter fps=60 delay=%.2fms max_step=%.3fpx rejected=%d" % [float(result_60.get("delay_ms", 0.0)), float(result_60.get("max_step", 0.0)), int(result_60.get("rejected", 0))])
	print("[websocket-snapshot-buffer] jitter fps=30 delay=%.2fms max_step=%.3fpx rejected=%d" % [float(result_30.get("delay_ms", 0.0)), float(result_30.get("max_step", 0.0)), int(result_30.get("rejected", 0))])
	_expect(bool(result_60.get("monotonic", false)), "jittered 60 FPS movement should remain ordered")
	_expect(bool(result_30.get("monotonic", false)), "jittered 30 FPS movement should remain ordered")
	_expect(float(result_60.get("max_step", 999.0)) < 8.0, "jittered 60 FPS movement should have bounded visual steps")
	_expect(float(result_30.get("max_step", 999.0)) < 12.0, "jittered 30 FPS movement should have bounded visual steps")
	_expect(int(result_60.get("rejected", 0)) > 0, "duplicate and out-of-order snapshots should be rejected")
	_expect(float(result_60.get("delay_ms", 0.0)) > SNAPSHOT_BUFFER.MIN_INTERPOLATION_DELAY_MS, "measured jitter should add conservative buffer headroom")
	_expect(float(result_60.get("delay_ms", 999.0)) <= SNAPSHOT_BUFFER.MAX_INTERPOLATION_DELAY_MS, "adaptive delay must stay capped")


func _test_direction_changes_and_jump_arc() -> void:
	var events: Array[Dictionary] = []
	var jitter_pattern: Array[int] = [0, 8, -4, 15, -7, 4]
	var previous_position := Vector2.ZERO
	for index in range(91):
		var x_position := 0.0
		if index <= 30:
			x_position = float(index) * 2.0
		elif index <= 60:
			x_position = 60.0 - float(index - 30) * 2.0
		else:
			x_position = float(index - 60) * 2.0
		var y_position := 0.0
		if index >= 15 and index <= 45:
			var jump_alpha := float(index - 15) / 30.0
			y_position = -48.0 * 4.0 * jump_alpha * (1.0 - jump_alpha)
		var position := Vector2(x_position, y_position)
		var velocity := (position - previous_position) / 0.02 if index > 0 else Vector2.ZERO
		if index == 90:
			velocity = Vector2.ZERO
		var server_time := 1000 + index * 20
		var receive_time := server_time + 100 + jitter_pattern[index % jitter_pattern.size()]
		if index == 32:
			receive_time += 65
		events.append({
			"receive_time": receive_time,
			"server_time": server_time,
			"sequence": index + 1,
			"position": position,
			"velocity": velocity
		})
		previous_position = position
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("receive_time", 0)) < int(b.get("receive_time", 0)))

	var buffer = SNAPSHOT_BUFFER.new()
	var event_index := 0
	var now := 1100.0
	var end_time := 3100.0
	var previous_render_position := Vector2.ZERO
	var previous_direction := 0
	var direction_changes := 0
	var maximum_step := 0.0
	var minimum_render := Vector2(INF, INF)
	var maximum_render := Vector2(-INF, -INF)
	while now <= end_time:
		while event_index < events.size() and float(events[event_index].get("receive_time", 0)) <= now:
			var event := events[event_index]
			buffer.push_snapshot(
				int(event.get("server_time", 0)),
				int(event.get("receive_time", 0)),
				int(event.get("sequence", 0)),
				event.get("position", Vector2.ZERO),
				event.get("velocity", Vector2.ZERO)
			)
			event_index += 1
		var sample: Dictionary = buffer.sample(int(now))
		if not sample.is_empty():
			var render_position: Vector2 = sample.get("position", Vector2.ZERO)
			minimum_render.x = minf(minimum_render.x, render_position.x)
			minimum_render.y = minf(minimum_render.y, render_position.y)
			maximum_render.x = maxf(maximum_render.x, render_position.x)
			maximum_render.y = maxf(maximum_render.y, render_position.y)
			var delta_x := render_position.x - previous_render_position.x
			var direction := 1 if delta_x > 0.05 else (-1 if delta_x < -0.05 else 0)
			if previous_direction != 0 and direction != 0 and direction != previous_direction:
				direction_changes += 1
			if direction != 0:
				previous_direction = direction
			maximum_step = maxf(maximum_step, previous_render_position.distance_to(render_position))
			previous_render_position = render_position
		now += 1000.0 / 60.0

	print("[websocket-snapshot-buffer] direction+jump changes=%d max_step=%.3fpx bounds=(%.2f, %.2f)-(%.2f, %.2f)" % [direction_changes, maximum_step, minimum_render.x, minimum_render.y, maximum_render.x, maximum_render.y])
	_expect(direction_changes >= 2, "rapid authoritative reversals should remain visible in order")
	_expect(maximum_step < 8.0, "direction changes and jump/landing should keep bounded visual steps")
	_expect(minimum_render.x >= -2.1 and maximum_render.x <= 62.1, "velocity-aware interpolation must not overshoot horizontal authoritative bounds")
	_expect(minimum_render.y >= -50.1 and maximum_render.y <= 2.1, "jump interpolation must not overshoot vertical authoritative bounds")


func _test_extrapolation_stops() -> void:
	var buffer = SNAPSHOT_BUFFER.new()
	buffer.reset(1000, 1100, 1, Vector2.ZERO, Vector2(100.0, 0.0))
	buffer.push_snapshot(1020, 1120, 2, Vector2(2.0, 0.0), Vector2(100.0, 0.0))
	var late_sample: Dictionary = buffer.sample(1500)
	var much_later_sample: Dictionary = buffer.sample(2500)
	var late_position: Vector2 = late_sample.get("position", Vector2.ZERO)
	var much_later_position: Vector2 = much_later_sample.get("position", Vector2.ZERO)
	_expect(float(late_sample.get("extrapolation_ms", 0.0)) <= SNAPSHOT_BUFFER.MAX_EXTRAPOLATION_MS, "extrapolation time should be capped")
	_expect(late_position.is_equal_approx(much_later_position), "missing updates should settle instead of sliding forever")


func _test_teleport_reset() -> void:
	var buffer = SNAPSHOT_BUFFER.new()
	buffer.reset(1000, 1050, 1, Vector2(10.0, 20.0), Vector2.ZERO)
	buffer.push_snapshot(1020, 1070, 2, Vector2(12.0, 20.0), Vector2(100.0, 0.0))
	buffer.reset(2000, 2100, 1, Vector2(600.0, 300.0), Vector2.ZERO)
	var sample: Dictionary = buffer.sample(2100)
	var reset_position: Vector2 = sample.get("position", Vector2.ZERO)
	_expect(reset_position.is_equal_approx(Vector2(600.0, 300.0)), "teleport reset should discard the old timeline")
	_expect(int(buffer.get_stats().get("buffer_size", 0)) == 1, "teleport reset should leave one authoritative snapshot")


func _test_many_player_cost_is_bounded() -> void:
	const PLAYER_COUNT := 128
	const FRAME_COUNT := 600
	var buffers: Array = []
	for player_index in range(PLAYER_COUNT):
		var buffer = SNAPSHOT_BUFFER.new()
		buffer.reset(1000, 1100, 1, Vector2(0.0, float(player_index)), Vector2(100.0, 0.0))
		buffers.append(buffer)

	var started_usec := Time.get_ticks_usec()
	var maximum_frame_usec := 0
	var frame_times_usec: Array[int] = []
	for frame_index in range(1, FRAME_COUNT + 1):
		var frame_started_usec := Time.get_ticks_usec()
		var server_time := 1000 + frame_index * 20
		var receive_time := server_time + 100 + (frame_index % 7) * 2
		for player_index in range(PLAYER_COUNT):
			var buffer = buffers[player_index]
			buffer.push_snapshot(
				server_time,
				receive_time,
				frame_index + 1,
				Vector2(float(frame_index) * 2.0, float(player_index)),
				Vector2(100.0, 0.0)
			)
			buffer.sample(receive_time)
		var frame_elapsed_usec := Time.get_ticks_usec() - frame_started_usec
		maximum_frame_usec = maxi(maximum_frame_usec, frame_elapsed_usec)
		frame_times_usec.append(frame_elapsed_usec)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	frame_times_usec.sort()
	var p95_index := mini(frame_times_usec.size() - 1, int(floor(float(frame_times_usec.size()) * 0.95)))
	var average_frame_ms := float(elapsed_usec) / 1000.0 / float(FRAME_COUNT)
	var p95_frame_ms := float(frame_times_usec[p95_index]) / 1000.0
	var maximum_frame_ms := float(maximum_frame_usec) / 1000.0
	print("[websocket-snapshot-buffer] scale players=%d frames=%d average=%.3fms p95=%.3fms max=%.3fms snapshots<=%d" % [PLAYER_COUNT, FRAME_COUNT, average_frame_ms, p95_frame_ms, maximum_frame_ms, PLAYER_COUNT * SNAPSHOT_BUFFER.MAX_SNAPSHOT_HISTORY])
	_expect(average_frame_ms < 8.0, "128-player snapshot work should stay within an 8ms average CPU budget")


func _simulate_route(latency_ms: int, add_jitter: bool, render_fps: float) -> Dictionary:
	var events: Array[Dictionary] = []
	var jitter_pattern: Array[int] = [0, 7, -5, 13, -9, 3, 18, -12, 5, -2]
	var sequence := 1
	for index in range(101):
		if add_jitter and index > 0 and index % 17 == 0:
			sequence += 1
			continue
		var server_time := 1000 + index * 20
		var jitter: int = jitter_pattern[index % jitter_pattern.size()] if add_jitter else 0
		var receive_time: int = server_time + latency_ms + jitter
		if add_jitter and index % 23 == 8:
			receive_time += 70
		events.append({
			"receive_time": receive_time,
			"server_time": server_time,
			"sequence": sequence,
			"position": Vector2(float(index) * 2.0, 0.0)
		})
		if add_jitter and index == 35:
			events.append(events[events.size() - 1].duplicate(true))
		sequence += 1
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("receive_time", 0)) < int(b.get("receive_time", 0)))

	var buffer = SNAPSHOT_BUFFER.new()
	var event_index := 0
	var frame_step := 1000.0 / render_fps
	var now := float(1000 + latency_ms)
	var end_time := float(1000 + 2000 + latency_ms + 250)
	var previous_position := Vector2.ZERO
	var has_previous := false
	var maximum_step := 0.0
	var monotonic := true
	while now <= end_time:
		while event_index < events.size() and float(events[event_index].get("receive_time", 0)) <= now:
			var event := events[event_index]
			buffer.push_snapshot(
				int(event.get("server_time", 0)),
				int(event.get("receive_time", 0)),
				int(event.get("sequence", 0)),
				event.get("position", Vector2.ZERO),
				Vector2(100.0, 0.0)
			)
			event_index += 1
		var sample: Dictionary = buffer.sample(int(now))
		if not sample.is_empty():
			var position: Vector2 = sample.get("position", Vector2.ZERO)
			if has_previous:
				maximum_step = maxf(maximum_step, previous_position.distance_to(position))
				if position.x + 0.01 < previous_position.x:
					monotonic = false
			previous_position = position
			has_previous = true
		now += frame_step

	var stats: Dictionary = buffer.get_stats()
	return {
		"max_step": maximum_step,
		"monotonic": monotonic,
		"delay_ms": float(stats.get("interpolation_delay_ms", 0.0)),
		"rejected": int(stats.get("rejected_snapshot_count", 0))
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("[websocket-snapshot-buffer] ", message)
