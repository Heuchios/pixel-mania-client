extends SceneTree

const Profiler = preload("res://Scripts/runtime_profiler.gd")

func _initialize(): call_deferred("run")

func run():
	Profiler.enabled = false
	Profiler.observe("ignored", 1.0)
	assert(Profiler.samples.is_empty())
	Profiler.enabled = true
	for i in range(1000): Profiler.observe("bounded_ms", float(i))
	assert(Profiler.samples.bounded_ms.values.size() == 512)
	assert(Profiler.samples.bounded_ms.count == 1000)
	for i in range(1000):
		Profiler.sent({"type": "world_block_update", "action": "break", "request_id": str(i)}, 64)
	assert(Profiler.pending.size() == 512)
	Profiler.acknowledged({"request_id": "999", "authoritative_pending": true})
	assert(Profiler.pending.has("999"))
	Profiler.acknowledged({"request_id": "999"})
	assert(not Profiler.pending.has("999"))
	assert(Profiler.samples.has("break_request_to_response_ms"))
	Profiler.sent({"type": "client_ping", "request_id": "ping"}, 32)
	Profiler.received({"type": "client_pong", "request_id": "ping"}, 32, 10)
	assert(Profiler.samples.has("application_rtt_request_to_response_ms"))
	Profiler.window_started_usec = Time.get_ticks_usec() - 5000001
	Profiler.frame(1.0 / 30.0, 3, 10)
	assert(Profiler.samples.is_empty() and Profiler.counters.is_empty())
	Profiler.enabled = false
	Profiler.pending.clear()
	print("RUNTIME_PROFILER_TEST_OK")
	quit()
