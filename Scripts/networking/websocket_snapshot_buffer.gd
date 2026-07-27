extends RefCounted

const DEFAULT_INTERPOLATION_DELAY_MS := 70.0
const MIN_INTERPOLATION_DELAY_MS := 45.0
const MAX_INTERPOLATION_DELAY_MS := 140.0
const MAX_SNAPSHOT_HISTORY := 24
const MAX_EXTRAPOLATION_MS := 120.0
const FULL_SPEED_EXTRAPOLATION_MS := 80.0
const TIMELINE_RESET_GAP_MS := 500.0
const INTERVAL_EWMA_WEIGHT := 0.18
const JITTER_EWMA_WEIGHT := 0.14
const DELAY_INCREASE_WEIGHT := 0.35
const DELAY_DECREASE_WEIGHT := 0.05
const MIN_SERVER_INTERVAL_MS := 1.0
const MAX_SERVER_INTERVAL_MS := 250.0

var snapshots: Array[Dictionary] = []
var last_sequence := 0
var last_server_time_ms := 0
var last_receive_time_ms := 0
var interval_ewma_ms := 16.0
var jitter_ewma_ms := 0.0
var interpolation_delay_ms := DEFAULT_INTERPOLATION_DELAY_MS
var rejected_snapshot_count := 0
var accepted_snapshot_count := 0
var timeline_reset_count := 0
var last_render_time_ms := -1.0


func reset(server_time_ms: int, receive_time_ms: int, sequence: int, position: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	var safe_receive_time := maxi(0, receive_time_ms)
	var safe_server_time := server_time_ms if server_time_ms > 0 else safe_receive_time
	snapshots = [{
		"server_time_ms": safe_server_time,
		"receive_time_ms": safe_receive_time,
		"sequence": maxi(0, sequence),
		"position": position,
		"velocity": velocity
	}]
	last_sequence = maxi(0, sequence)
	last_server_time_ms = safe_server_time
	last_receive_time_ms = safe_receive_time
	interval_ewma_ms = 16.0
	jitter_ewma_ms = 0.0
	interpolation_delay_ms = DEFAULT_INTERPOLATION_DELAY_MS
	last_render_time_ms = float(safe_server_time) - interpolation_delay_ms
	timeline_reset_count += 1


func push_snapshot(server_time_ms: int, receive_time_ms: int, sequence: int, position: Vector2, velocity: Vector2 = Vector2.ZERO) -> bool:
	if snapshots.is_empty():
		reset(server_time_ms, receive_time_ms, sequence, position, velocity)
		accepted_snapshot_count += 1
		return true

	var safe_sequence := maxi(0, sequence)
	if safe_sequence > 0 and last_sequence > 0 and safe_sequence <= last_sequence:
		rejected_snapshot_count += 1
		return false
	if safe_sequence <= 0 and server_time_ms > 0 and server_time_ms <= last_server_time_ms:
		rejected_snapshot_count += 1
		return false

	var safe_receive_time := maxi(last_receive_time_ms, receive_time_ms)
	var safe_server_time := server_time_ms if server_time_ms > 0 else last_server_time_ms + maxi(1, safe_receive_time - last_receive_time_ms)
	if safe_server_time <= last_server_time_ms:
		# A newer sequence remains authoritative even if a server clock source moved
		# backward. Keep the interpolation timeline monotonic without reordering it.
		safe_server_time = last_server_time_ms + 1

	var server_interval := float(safe_server_time - last_server_time_ms)
	var receive_interval := float(safe_receive_time - last_receive_time_ms)
	if server_interval > TIMELINE_RESET_GAP_MS or receive_interval > TIMELINE_RESET_GAP_MS * 2.0:
		reset(safe_server_time, safe_receive_time, safe_sequence, position, velocity)
		accepted_snapshot_count += 1
		return true

	server_interval = clampf(server_interval, MIN_SERVER_INTERVAL_MS, MAX_SERVER_INTERVAL_MS)
	receive_interval = maxf(0.0, receive_interval)
	interval_ewma_ms = lerpf(interval_ewma_ms, server_interval, INTERVAL_EWMA_WEIGHT)
	var arrival_jitter := absf(receive_interval - server_interval)
	jitter_ewma_ms = lerpf(jitter_ewma_ms, arrival_jitter, JITTER_EWMA_WEIGHT)

	# Two normal broadcast intervals cover batching. Measured arrival jitter adds
	# headroom only when the route is uneven, so fixed latency adds no input lag.
	var target_delay := clampf(
		interval_ewma_ms * 2.0 + jitter_ewma_ms * 2.5 + 8.0,
		MIN_INTERPOLATION_DELAY_MS,
		MAX_INTERPOLATION_DELAY_MS
	)
	var delay_weight := DELAY_INCREASE_WEIGHT if target_delay > interpolation_delay_ms else DELAY_DECREASE_WEIGHT
	interpolation_delay_ms = lerpf(interpolation_delay_ms, target_delay, delay_weight)

	snapshots.append({
		"server_time_ms": safe_server_time,
		"receive_time_ms": safe_receive_time,
		"sequence": safe_sequence,
		"position": position,
		"velocity": velocity
	})
	while snapshots.size() > MAX_SNAPSHOT_HISTORY:
		snapshots.pop_front()

	last_sequence = safe_sequence if safe_sequence > 0 else last_sequence
	last_server_time_ms = safe_server_time
	last_receive_time_ms = safe_receive_time
	accepted_snapshot_count += 1
	return true


func sample(receive_time_ms: int) -> Dictionary:
	if snapshots.is_empty():
		return {}

	var estimated_server_now := last_server_time_ms + maxi(0, receive_time_ms - last_receive_time_ms)
	var proposed_render_time_ms := float(estimated_server_now) - interpolation_delay_ms
	var render_time_ms := proposed_render_time_ms if last_render_time_ms < 0.0 else maxf(last_render_time_ms, proposed_render_time_ms)
	last_render_time_ms = render_time_ms

	while snapshots.size() >= 3 and float(snapshots[1].get("server_time_ms", 0)) <= render_time_ms:
		snapshots.pop_front()

	var first := snapshots[0]
	if snapshots.size() == 1 or render_time_ms <= float(first.get("server_time_ms", 0)):
		return _sample_result(first.get("position", Vector2.ZERO), "hold", 0.0, render_time_ms, first, first, 0.0)

	for index in range(1, snapshots.size()):
		var previous := snapshots[index - 1]
		var next := snapshots[index]
		var previous_time := float(previous.get("server_time_ms", 0))
		var next_time := float(next.get("server_time_ms", previous_time + 1.0))
		if render_time_ms > next_time:
			continue
		var span := maxf(1.0, next_time - previous_time)
		var alpha := clampf((render_time_ms - previous_time) / span, 0.0, 1.0)
		return _sample_result(_interpolate_snapshots(previous, next, alpha, span), "interpolate", alpha, render_time_ms, previous, next, 0.0)

	var latest := snapshots[snapshots.size() - 1]
	var latest_position: Vector2 = latest.get("position", Vector2.ZERO)
	var latest_velocity: Vector2 = latest.get("velocity", Vector2.ZERO)
	var extrapolation_ms := clampf(render_time_ms - float(latest.get("server_time_ms", render_time_ms)), 0.0, MAX_EXTRAPOLATION_MS)
	var travel_ms := _get_decelerated_extrapolation_travel_ms(extrapolation_ms)
	var mode := "extrapolate" if extrapolation_ms > 0.0 and latest_velocity.length_squared() > 0.01 else "hold"
	return _sample_result(latest_position + latest_velocity * (travel_ms / 1000.0), mode, 1.0, render_time_ms, latest, latest, extrapolation_ms)


func get_stats() -> Dictionary:
	return {
		"buffer_size": snapshots.size(),
		"interpolation_delay_ms": interpolation_delay_ms,
		"interval_ewma_ms": interval_ewma_ms,
		"jitter_ewma_ms": jitter_ewma_ms,
		"accepted_snapshot_count": accepted_snapshot_count,
		"rejected_snapshot_count": rejected_snapshot_count,
		"timeline_reset_count": timeline_reset_count,
		"last_sequence": last_sequence
	}


func _interpolate_snapshots(previous: Dictionary, next: Dictionary, alpha: float, span_ms: float) -> Vector2:
	var p0: Vector2 = previous.get("position", Vector2.ZERO)
	var p1: Vector2 = next.get("position", p0)
	var v0: Vector2 = previous.get("velocity", Vector2.ZERO)
	var v1: Vector2 = next.get("velocity", v0)
	if span_ms > 100.0 or (v0.length_squared() <= 0.01 and v1.length_squared() <= 0.01):
		return p0.lerp(p1, alpha)

	var span_seconds := span_ms / 1000.0
	var alpha2 := alpha * alpha
	var alpha3 := alpha2 * alpha
	var candidate := (2.0 * alpha3 - 3.0 * alpha2 + 1.0) * p0
	candidate += (alpha3 - 2.0 * alpha2 + alpha) * v0 * span_seconds
	candidate += (-2.0 * alpha3 + 3.0 * alpha2) * p1
	candidate += (alpha3 - alpha2) * v1 * span_seconds

	# Network velocities can be noisy. Bound Hermite overshoot tightly around the
	# authoritative segment so interpolation cannot invent a large excursion.
	var minimum := Vector2(minf(p0.x, p1.x) - 2.0, minf(p0.y, p1.y) - 2.0)
	var maximum := Vector2(maxf(p0.x, p1.x) + 2.0, maxf(p0.y, p1.y) + 2.0)
	return Vector2(clampf(candidate.x, minimum.x, maximum.x), clampf(candidate.y, minimum.y, maximum.y))


func _get_decelerated_extrapolation_travel_ms(extrapolation_ms: float) -> float:
	if extrapolation_ms <= FULL_SPEED_EXTRAPOLATION_MS:
		return extrapolation_ms
	var deceleration_window := maxf(1.0, MAX_EXTRAPOLATION_MS - FULL_SPEED_EXTRAPOLATION_MS)
	var extra := minf(extrapolation_ms - FULL_SPEED_EXTRAPOLATION_MS, deceleration_window)
	return FULL_SPEED_EXTRAPOLATION_MS + extra - (extra * extra) / (2.0 * deceleration_window)


func _sample_result(position: Vector2, mode: String, alpha: float, render_time_ms: float, previous: Dictionary, next: Dictionary, extrapolation_ms: float) -> Dictionary:
	return {
		"position": position,
		"mode": mode,
		"alpha": alpha,
		"render_time_ms": render_time_ms,
		"previous_time_ms": int(previous.get("server_time_ms", 0)),
		"next_time_ms": int(next.get("server_time_ms", 0)),
		"extrapolation_ms": extrapolation_ms
	}
