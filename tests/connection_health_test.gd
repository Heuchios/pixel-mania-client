extends SceneTree
const Health = preload("res://Scripts/networking/connection_health.gd")

func _initialize():
	var health = Health.new()
	health.start_attempt(1000)
	assert(health.timeout_reason(15999) == "")
	assert(health.timeout_reason(16000) == "connect_timeout")
	health.opened(16000)
	health.authenticating(16000)
	assert(health.timeout_reason(35999) == "")
	assert(health.timeout_reason(36000) == "authentication_timeout")
	health.authenticated(40000)
	assert(health.ping_due(40000))
	health.sent_ping("generation_1", 40000)
	assert(not health.ping_due(45000), "Only one heartbeat can be outstanding")
	assert(not health.received_pong("retired_generation", 40100))
	assert(health.received_pong("generation_1", 40100))
	assert(health.rtt_ms == 100)
	health.sent_ping("generation_2", 45000)
	assert(health.timeout_reason(74999) == "")
	assert(health.timeout_reason(75000) == "heartbeat_timeout")
	# Foreground after OS suspension starts a fresh probe, not an immediate kick.
	health.reset_probe(180000)
	assert(health.timeout_reason(180000) == "")
	assert(health.ping_due(180000))
	var previous := 0.0
	for i in range(20):
		var delay: float = health.retry_delay_seconds()
		assert(delay >= previous and delay <= 30)
		previous = delay
	health.authenticated(200000)
	assert(health.retry_attempt == 0)
	print("CONNECTION_HEALTH_OK: deadlines, one probe, stale pong, resume, bounded backoff")
	quit()
