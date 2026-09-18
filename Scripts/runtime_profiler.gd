extends RefCounted
## Opt-in, bounded aggregate telemetry. No packet bodies, identities or tokens.
## Enable with --runtime-profile or PIXELMANIA_RUNTIME_PROFILE=1.
static var enabled: bool = OS.get_environment("PIXELMANIA_RUNTIME_PROFILE") == "1" or "--runtime-profile" in OS.get_cmdline_user_args()
static var samples: Dictionary = {}
static var counters: Dictionary = {}
static var pending: Dictionary = {}
static var window_started_usec: int = 0
static var last_ping_usec: int = 0
const SAMPLE_LIMIT := 512
const PENDING_LIMIT := 512

static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(metric: String, started: int) -> void:
	if enabled and started > 0:
		observe(metric, float(Time.get_ticks_usec() - started) / 1000.0)

static func observe(metric: String, value: float) -> void:
	if not enabled:
		return
	var bucket: Dictionary = samples.get(metric, {"values": [], "count": 0, "sum": 0.0, "max": 0.0})
	var values: Array = bucket.values
	if values.size() < SAMPLE_LIMIT:
		values.append(value)
	else:
		values[int(bucket.count) % SAMPLE_LIMIT] = value
	bucket.count += 1
	bucket.sum += value
	bucket.max = maxf(float(bucket.max), value)
	samples[metric] = bucket

static func count(metric: String, amount: int = 1) -> void:
	if enabled:
		counters[metric] = int(counters.get(metric, 0)) + amount

static func sent(data: Dictionary, bytes: int) -> void:
	if not enabled:
		return
	count("tx_messages")
	count("tx_bytes", bytes)
	var kind := str(data.get("type", ""))
	if kind == "player_position":
		count("movement_tx")
	if kind != "world_block_update" and kind != "client_ping":
		return
	var request_id := str(data.get("request_id", ""))
	if request_id == "" or pending.has(request_id):
		return
	if pending.size() >= PENDING_LIMIT:
		pending.erase(pending.keys()[0])
		count("operation_samples_evicted")
	pending[request_id] = {"started": Time.get_ticks_usec(), "action": "application_rtt" if kind == "client_ping" else str(data.get("action", "unknown"))}

static func ping_due() -> bool:
	if not enabled or Time.get_ticks_usec() - last_ping_usec < 5000000:
		return false
	last_ping_usec = Time.get_ticks_usec()
	return true

static func received(data: Dictionary, bytes: int, parse_usec: int) -> void:
	if not enabled:
		return
	count("rx_messages")
	count("rx_bytes", bytes)
	observe("json_parse_ms", float(parse_usec) / 1000.0)
	acknowledged(data)

static func acknowledged(data: Dictionary) -> void:
	if not enabled:
		return
	var request_id := str(data.get("request_id", data.get("action_id", "")))
	if pending.has(request_id) and not bool(data.get("authoritative_pending", false)):
		var operation: Dictionary = pending[request_id]
		finish(str(operation.action) + "_request_to_response_ms", int(operation.started))
		pending.erase(request_id)

static func frame(delta: float, queued_packets: int, queued_tiles: int) -> void:
	if not enabled:
		return
	observe("frame_ms", delta * 1000.0)
	observe("engine_process_ms", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	observe("engine_physics_ms", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	observe("queued_packets", float(queued_packets))
	observe("queued_event_tiles", float(queued_tiles))
	var now := Time.get_ticks_usec()
	if window_started_usec == 0:
		window_started_usec = now
	if now - window_started_usec < 5000000:
		return
	var summary := {"window_seconds": float(now - window_started_usec) / 1000000.0, "metrics": {}, "counts": counters.duplicate(), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "pending_operations": pending.size()}
	for key in samples:
		var bucket: Dictionary = samples[key]
		var values: Array = bucket.values.duplicate()
		values.sort()
		summary.metrics[key] = {"count": bucket.count, "mean": float(bucket.sum) / maxi(1, int(bucket.count)), "p95_recent": values[mini(values.size() - 1, int(values.size() * 0.95))], "max": bucket.max}
	print("[RUNTIME_PROFILE] ", JSON.stringify(summary))
	samples.clear()
	counters.clear()
	window_started_usec = now
