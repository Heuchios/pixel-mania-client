extends RefCounted
class_name CustomMovementProtocol

const ADDRESS := "127.0.0.1"
const PORT := 24571
const MAX_CLIENTS := 8
const PHYSICS_TICK_RATE := 60

const SPEED := 170.0
const ACCELERATION := 1800.0
const FRICTION := 2200.0
const GRAVITY := 1150.0
const JUMP_VELOCITY := -430.0
const FALL_GRAVITY_MULTIPLIER := 0.90
const JUMP_HOLD_FALL_PAUSE_TIME := 0.10
const MAX_FALL_SPEED := 680.0
const SNAPSHOT_RATE := 20
const INTERPOLATION_DELAY_MS := 80
const SMALL_CORRECTION_PIXELS := 2.0
const FAST_CORRECTION_PIXELS := 12.0
const SNAP_CORRECTION_PIXELS := 24.0
const HARD_SNAP_CORRECTION_PIXELS := 96.0
const LOCAL_SMOOTH_CORRECTION_BLEND := 0.18
const LOCAL_FAST_CORRECTION_BLEND := 0.48
const LOCAL_STRONG_CORRECTION_BLEND := 0.82
const REMOTE_RENDER_SMOOTH_RATE := 24.0
const REMOTE_RENDER_FAST_SMOOTH_RATE := 42.0
const REMOTE_RENDER_FAST_DISTANCE_PIXELS := 18.0
const REMOTE_RENDER_SNAP_PIXELS := 112.0
const REMOTE_RENDER_CLOSE_ENOUGH_PIXELS := 0.10

const SNAPSHOT_INTERVAL := 1.0 / float(SNAPSHOT_RATE)
const FIXED_DELTA := 1.0 / float(PHYSICS_TICK_RATE)
const MAX_INPUT_HISTORY := 180
const MAX_INPUT_QUEUE_PER_PEER := 120
const MAX_SNAPSHOT_BUFFER := 32
const DEAD_RECKON_MAX_SECONDS := 0.20
const REMOTE_SNAP_DISTANCE_PIXELS := 160.0


static func make_input(peer_id: int, input_sequence: int, move_x: float, jump_pressed: bool, facing_dir: int, client_tick: int, jump_held: bool = false) -> Dictionary:
	var clean_move_x: float = clamp(float(move_x), -1.0, 1.0)
	var clean_facing: int = 1 if int(facing_dir) >= 0 else -1
	return {
		"peer_id": int(peer_id),
		"input_sequence": max(0, int(input_sequence)),
		"move_x": clean_move_x,
		"jump_pressed": bool(jump_pressed),
		"jump_held": bool(jump_held),
		"facing_dir": clean_facing,
		"client_tick": max(0, int(client_tick)),
	}


static func sanitize_input(packet: Dictionary, fallback_peer_id: int = 0) -> Dictionary:
	var peer_id: int = int(packet.get("peer_id", fallback_peer_id))
	if peer_id <= 0:
		peer_id = fallback_peer_id

	return make_input(
		peer_id,
		int(packet.get("input_sequence", 0)),
		float(packet.get("move_x", 0.0)),
		bool(packet.get("jump_pressed", false)),
		int(packet.get("facing_dir", 1)),
		int(packet.get("client_tick", 0)),
		bool(packet.get("jump_held", packet.get("jump_pressed", false)))
	)


static func make_snapshot(peer_id: int, server_tick: int, position: Vector2, velocity: Vector2, facing_dir: int, movement_state: String, last_processed_input: int, jump_hold_fall_pause_timer: float = 0.0) -> Dictionary:
	var clean_facing: int = 1 if int(facing_dir) >= 0 else -1
	return {
		"peer_id": int(peer_id),
		"server_tick": max(0, int(server_tick)),
		"server_time_msec": server_tick_to_msec(server_tick),
		"position": position,
		"velocity": velocity,
		"facing_dir": clean_facing,
		"movement_state": str(movement_state),
		"last_processed_input": max(0, int(last_processed_input)),
		"jump_hold_fall_pause_timer": maxf(0.0, float(jump_hold_fall_pause_timer)),
	}


static func snapshot_position(snapshot: Dictionary) -> Vector2:
	var value = snapshot.get("position", Vector2.ZERO)
	if value is Vector2:
		return value

	return Vector2(float(snapshot.get("x", 0.0)), float(snapshot.get("y", 0.0)))


static func snapshot_velocity(snapshot: Dictionary) -> Vector2:
	var value = snapshot.get("velocity", Vector2.ZERO)
	if value is Vector2:
		return value

	return Vector2(float(snapshot.get("velocity_x", 0.0)), float(snapshot.get("velocity_y", 0.0)))


static func snapshot_jump_hold_fall_pause_timer(snapshot: Dictionary) -> float:
	return maxf(0.0, float(snapshot.get("jump_hold_fall_pause_timer", 0.0)))


static func movement_state_for(is_on_floor_value: bool, velocity: Vector2) -> String:
	if not is_on_floor_value:
		if velocity.y < 0.0:
			return "jump"
		return "fall"
	if absf(velocity.x) > 6.0:
		return "run"
	return "idle"


static func server_tick_to_msec(tick: int) -> int:
	return int(round(float(max(0, int(tick))) * 1000.0 / float(PHYSICS_TICK_RATE)))


static func snapshot_server_time_msec(snapshot: Dictionary) -> int:
	if snapshot.has("server_time_msec"):
		return max(0, int(snapshot.get("server_time_msec", 0)))
	return server_tick_to_msec(int(snapshot.get("server_tick", 0)))


static func config_summary() -> String:
	return "SPEED=%.1f ACCELERATION=%.1f FRICTION=%.1f GRAVITY=%.1f JUMP_VELOCITY=%.1f FALL_GRAVITY_MULTIPLIER=%.2f JUMP_HOLD_FALL_PAUSE_TIME=%.1f MAX_FALL_SPEED=%.1f PHYSICS_TICK_RATE=%d SNAPSHOT_RATE=%d INTERPOLATION_DELAY_MS=%d SMALL_CORRECTION_PIXELS=%.1f FAST_CORRECTION_PIXELS=%.1f SNAP_CORRECTION_PIXELS=%.1f HARD_SNAP_CORRECTION_PIXELS=%.1f LOCAL_SMOOTH_BLEND=%.2f LOCAL_FAST_BLEND=%.2f LOCAL_STRONG_BLEND=%.2f REMOTE_SMOOTH_RATE=%.1f REMOTE_FAST_SMOOTH_RATE=%.1f REMOTE_RENDER_SNAP_PIXELS=%.1f DEAD_RECKON_MAX_SECONDS=%.2f" % [
		SPEED,
		ACCELERATION,
		FRICTION,
		GRAVITY,
		JUMP_VELOCITY,
		FALL_GRAVITY_MULTIPLIER,
		JUMP_HOLD_FALL_PAUSE_TIME,
		MAX_FALL_SPEED,
		PHYSICS_TICK_RATE,
		SNAPSHOT_RATE,
		INTERPOLATION_DELAY_MS,
		SMALL_CORRECTION_PIXELS,
		FAST_CORRECTION_PIXELS,
		SNAP_CORRECTION_PIXELS,
		HARD_SNAP_CORRECTION_PIXELS,
		LOCAL_SMOOTH_CORRECTION_BLEND,
		LOCAL_FAST_CORRECTION_BLEND,
		LOCAL_STRONG_CORRECTION_BLEND,
		REMOTE_RENDER_SMOOTH_RATE,
		REMOTE_RENDER_FAST_SMOOTH_RATE,
		REMOTE_RENDER_SNAP_PIXELS,
		DEAD_RECKON_MAX_SECONDS,
	]
